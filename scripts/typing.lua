local _, addon = ...
local Typing = { prefix = "ChatterTyping1", peers = {}, outgoing = {}, incoming = {} }
addon.Typing = Typing

local function secret(...)
    return HasAnySecretValues and HasAnySecretValues(...)
end

local function enabled()
    return Typing.enabled and Chatter.db.global.typingIndicators ~= false
end

-- Battle.net addon packets address game accounts, not whisper account IDs.
local function gameAccounts(info)
    local result = {}
    if info and info.gameAccountInfo then
        result[1] = info.gameAccountInfo
    end

    return result
end

function Typing:Endpoint(conversation)
    if not conversation or conversation.demo then
        return
    end

    if conversation.transport ~= "bnet" then
        local key = addon.Characters.NameKey(conversation.name)
        if key and addon.Characters.online[key] == false then
            return
        end

        return conversation.name
    end

    local id = addon.BattleNet.AccountID(conversation)
    local info = id and addon.BattleNet.Info(id)
    for _, game in ipairs(gameAccounts(info)) do
        if
            not secret(game.gameAccountID, game.clientProgram, game.isOnline)
            and game.clientProgram == "WoW"
            and game.isOnline
        then
            return game.gameAccountID
        end
    end
end

function Typing:Transmit(target, payload)
    if not target then
        return false
    end

    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
        return false
    end

    local send, ok, result
    if type(target) == "number" then
        send = C_BattleNet and C_BattleNet.SendGameData or BNSendGameData
        if send then
            ok, result = pcall(send, target, self.prefix, payload)
        end
    else
        local characters = addon.Characters
        local key = characters.NameKey(target)
        if key and characters.online[key] == false then
            return false
        end

        send = C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
        if send then
            ok, result = pcall(send, self.prefix, payload, "WHISPER", target)
        end
    end

    local success = Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success
    return ok and result ~= false and (type(result) ~= "number" or not success or result == success)
end

function Typing:Discover(key)
    if not enabled() then
        return
    end

    local target = self:Endpoint(Chatter.db.char.conversations[key])
    if not target then
        return
    end

    local peer = self.peers[key]
    local sameTarget = peer
        and (
            peer.target == target
            or (
                type(target) == "string"
                and type(peer.target) == "string"
                and addon.Characters.SameName(peer.target, target)
            )
        )
    if not sameTarget then
        peer = { target = target }
        self.peers[key] = peer
    end

    local now = GetTime()
    if peer.expires and peer.expires > now then
        return peer
    end

    if not peer.probed or now - peer.probed >= 60 then
        peer.probed = now
        self:Transmit(target, "H")
    end

    return peer
end

function Typing:Stop(key)
    local state = key and self.outgoing[key]
    if state and state.sent then
        self:Transmit(state.target, "S")
    end

    if key then
        self.outgoing[key] = nil
    end
end

function Typing:Changed(window)
    if not enabled() or not window.active or not window.frame:IsShown() then
        return
    end

    local key = window.active
    if not window.input:GetText():find("%S") then
        self:Stop(key)
        return
    end

    local peer = self:Discover(key)
    if not peer then
        return
    end

    local state = self.outgoing[key] or {}
    state.edited, state.window, state.target = GetTime(), window, peer.target
    self.outgoing[key] = state
    self:Tick()
end

function Typing:SetIncoming(key, expiry)
    if not key then
        return
    end

    local wasTyping = self.incoming[key] ~= nil
    self.incoming[key] = expiry
    if wasTyping ~= (expiry ~= nil) and addon.Extensions then
        addon.Extensions:ConversationEvent(
            "TYPING_CHANGED",
            Chatter.db.char.conversations[key],
            { typing = expiry ~= nil }
        )
    end
end

function Typing:Clear(key)
    self:SetIncoming(key, nil)
end

function Typing:IsTyping(key)
    return enabled() and key and self.incoming[key] and self.incoming[key] > GetTime() or false
end

function Typing:Tick()
    local now = GetTime()
    for key, state in pairs(self.outgoing) do
        local window = state.window
        if
            not enabled()
            or now - state.edited >= 4
            or not Chatter.db.char.conversations[key]
            or window.active ~= key
            or not window.frame:IsShown()
        then
            self:Stop(key)
        else
            local peer = self.peers[key]
            if peer and peer.expires and peer.expires > now and (not state.sent or now - state.sent >= 2) then
                if self:Transmit(state.target, "T") then
                    state.sent = now
                end
            end
        end
    end

    for key, expiry in pairs(self.incoming) do
        if expiry <= now then
            self:Clear(key)
        end
    end

    for key, peer in pairs(self.peers) do
        if not self.outgoing[key] and now - (peer.expires or peer.probed or 0) > 300 then
            self.peers[key] = nil
        end
    end
end

function Typing:Receive(event, prefix, payload, channel, sender)
    if
        not enabled()
        or secret(prefix, payload, channel, sender)
        or prefix ~= self.prefix
        or (payload ~= "H" and payload ~= "A" and payload ~= "T" and payload ~= "S")
    then
        return
    end

    local key
    if event == "BN_CHAT_MSG_ADDON" then
        if
            type(sender) ~= "number"
            or not BNGetNumFriends
            or not C_BattleNet
            or not C_BattleNet.GetFriendAccountInfo
        then
            return
        end

        for index = 1, BNGetNumFriends() do
            local info = C_BattleNet.GetFriendAccountInfo(index)
            if info and not secret(info.battleTag) and type(info.battleTag) == "string" then
                local games = gameAccounts(info)
                if C_BattleNet.GetFriendNumGameAccounts and C_BattleNet.GetFriendGameAccountInfo then
                    for gameIndex = 1, C_BattleNet.GetFriendNumGameAccounts(index) do
                        games[#games + 1] = C_BattleNet.GetFriendGameAccountInfo(index, gameIndex)
                    end
                end

                for _, game in ipairs(games) do
                    if not secret(game.gameAccountID) and game.gameAccountID == sender then
                        key = "bnet:" .. info.battleTag:lower()
                        break
                    end
                end
            end

            if key then
                break
            end
        end
    else
        if channel ~= "WHISPER" or type(sender) ~= "string" or sender == "" then
            return
        end

        for id, conversation in pairs(Chatter.db.char.conversations) do
            if
                not conversation.demo
                and conversation.transport ~= "bnet"
                and addon.Characters.SameName(conversation.name, sender)
            then
                key = id
                break
            end
        end
    end

    -- A greeting may precede the first actual whisper. Reply without creating
    -- history, unread badges or windows, and bound replies to unknown senders.
    local now = GetTime()
    if not key or not Chatter.db.char.conversations[key] then
        if payload == "H" and (not self.unknownReply or now - self.unknownReply >= 2) then
            self.unknownReply = now
            self:Transmit(sender, "A")
        end

        return
    end

    local peer = self.peers[key] or { target = sender }
    self.peers[key] = peer
    if payload == "H" or payload == "A" then
        peer.target, peer.expires = sender, now + 300
        if payload == "H" and (not peer.replied or now - peer.replied >= 2) then
            peer.replied = now
            self:Transmit(sender, "A")
        end

        self:Tick()
    elseif peer.expires and peer.expires > now and peer.target == sender then
        self:SetIncoming(key, payload == "T" and now + 8 or nil)
    end
end

function Typing:Disable()
    for key in pairs(self.outgoing) do
        self:Stop(key)
    end

    self.enabled = false
    for key in pairs(self.incoming) do
        self:Clear(key)
    end

    self.incoming, self.peers = {}, {}
    if self.frame then
        self.frame:Hide()
    end
end

function Typing:Enable()
    if Chatter.db.global.typingIndicators == false then
        return
    end

    local register = C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix or RegisterAddonMessagePrefix
    if register and not self.registered then
        local ok, result = pcall(register, self.prefix)
        local success = Enum and Enum.RegisterAddonMessagePrefixResult and Enum.RegisterAddonMessagePrefixResult.Success
        if not ok or result == false or (type(result) == "number" and success and result ~= success) then
            return
        end

        self.registered = true
    end

    self.enabled = true
    if not self.frame then
        local frame = CreateFrame("Frame")
        self.frame = frame
        frame:RegisterEvent("CHAT_MSG_ADDON")
        if (C_BattleNet and C_BattleNet.SendGameData) or BNSendGameData then
            pcall(frame.RegisterEvent, frame, "BN_CHAT_MSG_ADDON")
        end

        frame:SetScript("OnEvent", function(_, event, ...)
            self:Receive(event, ...)
        end)

        local elapsed = 0
        frame:SetScript("OnUpdate", function(_, delta)
            elapsed = elapsed + delta
            if elapsed < 0.25 then
                return
            end

            elapsed = 0
            self:Tick()
        end)
    end

    self.frame:Show()
end
