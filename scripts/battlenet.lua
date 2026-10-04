local _, addon = ...
local BattleNet = {}
addon.BattleNet = BattleNet

local function secret(...)
    return HasAnySecretValues and HasAnySecretValues(...)
end

function BattleNet.Info(id)
    if secret(id) or type(id) ~= "number" or id <= 0 then
        return
    end

    return C_BattleNet and C_BattleNet.GetAccountInfoByID and C_BattleNet.GetAccountInfoByID(id)
end

function BattleNet.Resolve(target)
    if secret(target) then
        return
    end

    if type(target) ~= "number" and type(target) ~= "string" then
        return
    end

    local id = type(target) == "number" and target or nil
    if not id and BNet_GetBNetIDAccount then
        id = BNet_GetBNetIDAccount(target)
    end

    local info = BattleNet.Info(id)
    if not info or secret(info.battleTag) then
        return
    end

    local tag = info.battleTag
    if type(tag) ~= "string" or tag == "" then
        return
    end

    local name = tag:match("^(.-)#") or tag
    return { key = "bnet:" .. string.lower(tag), name = name, battleTag = tag, accountID = id, transport = "bnet" }
end

function BattleNet.Ensure(identity)
    local data = Whispr.db.char
    local conversation = data.conversations[identity.key]
    if not conversation then
        data.sequence = data.sequence + 1
        conversation = { key = identity.key, name = identity.name, updated = data.sequence, unread = 0, messages = {} }
        data.conversations[identity.key] = conversation
    end

    conversation.transport, conversation.battleTag = "bnet", identity.battleTag
    conversation.name = identity.name
    -- Presence IDs are session-scoped; resolve the BattleTag again when sending.
    addon.History.Trim(data, Whispr.db.global)
    return conversation
end

function BattleNet.AccountID(conversation)
    if not BNGetNumFriends or not C_BattleNet or not C_BattleNet.GetFriendAccountInfo then
        return
    end

    for index = 1, BNGetNumFriends() do
        local info = C_BattleNet.GetFriendAccountInfo(index)
        if
            info
            and not secret(info.battleTag, info.bnetAccountID)
            and type(info.battleTag) == "string"
            and string.lower(info.battleTag) == string.lower(conversation.battleTag)
        then
            return info.bnetAccountID
        end
    end
end
