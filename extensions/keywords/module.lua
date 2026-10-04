local _, addon = ...
local L, Format = addon.L, addon.Format
local Keywords = Whispr:NewExtension("keywords", {
    name = L["Keyword actions"],
    version = "1.0.0",
    builtin = true,
    description = L["Turn words in incoming character whispers into clickable actions. Optional auto-invites are restricted to friends or guild members."],
})

addon.KeywordActions = Keywords
local actions = { invite = L["Invite to group"], friend = L["Add friend"], copy = L["Copy word"] }

local function wordParts(token)
    return token:match("^(%p*)(%w+)(%p*)$")
end

local function words(text)
    local result = {}
    for word in text:gmatch("[^,%s]+") do
        result[#result + 1] = word:lower()
    end

    return result
end

function Keywords:Refresh()
    local function refresh(window)
        if window and window.frame then
            window:RefreshMessages()
        end
    end

    refresh(addon.Window)
    for _, window in pairs(addon.Window and addon.Window.popouts or {}) do
        refresh(window)
    end
end

function Keywords:Compile()
    self.lookup = {}
    for _, rule in ipairs(self:GetSettings().rules or {}) do
        if actions[rule.action] then
            for _, word in ipairs(words(rule.words or "")) do
                self.lookup[word] = rule.action
            end
        end
    end
end

function Keywords:Validate(text, except)
    if type(text) ~= "string" or #text > 500 then
        return L["Enter up to 500 characters of words separated by commas."]
    end

    local list, seen = words(text), {}
    if #list == 0 then
        return L["Enter at least one word."]
    end

    for _, word in ipairs(list) do
        if not word:match("^[a-z0-9]+$") or #word > 48 then
            return L["Use single words with letters A–Z or digits, up to 48 characters each."]
        end

        if seen[word] then
            return L["Each word can appear in only one rule."]
        end

        seen[word] = true
    end

    for _, rule in ipairs(self:GetSettings().rules or {}) do
        if rule ~= except then
            for _, word in ipairs(words(rule.words)) do
                if seen[word] then
                    return L["Each word can appear in only one rule."]
                end
            end
        end
    end

    return true
end

function Keywords:Changed()
    self:Compile()
    self:BuildOptions()
    self:Refresh()
end

function Keywords:RenderToken(_, token, key)
    local prefix, word, suffix = wordParts(token)
    if not word or not self.lookup[word:lower()] then
        return token
    end

    if prefix:sub(-1) == "[" and suffix:sub(1, 1) == "]" then
        prefix, suffix = prefix:sub(1, -2), suffix:sub(2)
    end

    return prefix
        .. "|cffffff00|Hwhisprkeyword:"
        .. Format.Encode(key)
        .. ":"
        .. Format.Encode(word:lower())
        .. "|h["
        .. word
        .. "]|h|r"
        .. suffix
end

function Keywords:Resolve(link, key)
    if not self:IsEnabled() or not key then
        return
    end

    local encodedKey, encodedWord = link:match("^whisprkeyword:(%x+):(%x+)$")
    if not encodedKey or Format.Decode(encodedKey) ~= key then
        return
    end

    local word = Format.Decode(encodedWord)
    local action = self.lookup[word]
    local conversation = addon.History.Get(key)
    if not action or not conversation or conversation.demo or conversation.transport == "bnet" then
        return
    end

    return conversation, action, word
end

function Keywords:Click(window, link, button, key)
    if button ~= "LeftButton" then
        return
    end

    local conversation, action, word = self:Resolve(link, key)
    if not conversation then
        return
    end

    if action == "invite" then
        addon.Actions:Invite(conversation)
    elseif action == "friend" then
        local add = C_FriendList and C_FriendList.AddFriend or AddFriend
        if add then
            add(conversation.name)
        end
    elseif action == "copy" then
        window:ShowCopyText(word, L["Copy word"])
    end
end

function Keywords:Tooltip(link, key)
    local conversation, action = self:Resolve(link, key)
    if conversation then
        return actions[action] .. " · " .. conversation.name
    end
end

-- Query current rosters, never inferred/cached conversation metadata. SameName
-- preserves foreign realms, so a same-named stranger cannot inherit trust.
function Keywords:Trusted(conversation)
    local settings = self:GetSettings()

    local function same(name)
        return addon.Characters.SameName(name, conversation.name)
    end

    if settings.friends then
        if C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex then
            for index = 1, C_FriendList.GetNumFriends() do
                local friend = C_FriendList.GetFriendInfoByIndex(index)
                if friend and same(friend.name) then
                    return true
                end
            end
        elseif GetNumFriends and GetFriendInfo then
            for index = 1, GetNumFriends() do
                if same(GetFriendInfo(index)) then
                    return true
                end
            end
        end
    end

    if settings.guild and GetNumGuildMembers and GetGuildRosterInfo then
        for index = 1, GetNumGuildMembers() do
            if same(GetGuildRosterInfo(index)) then
                return true
            end
        end
    end

    return false
end

function Keywords:OnMessage(_, payload)
    local settings = self:GetSettings()
    if not settings.autoInvite or not (settings.friends or settings.guild) then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    local message = payload.message
    local conversation = addon.History.Get(payload.key)
    if
        not conversation
        or conversation.demo
        or payload.demo
        or payload.transport == "bnet"
        or conversation.transport == "bnet"
        or not message
        or message.outgoing
        or message.status
        or type(message.text) ~= "string"
    then
        return
    end

    if IsInGroup and IsInGroup() then
        if
            not (
                (UnitIsGroupLeader and UnitIsGroupLeader("player"))
                or (UnitIsGroupAssistant and UnitIsGroupAssistant("player"))
            )
        then
            return
        end

        local capacity = IsInRaid and IsInRaid() and 40 or 5
        if GetNumGroupMembers and GetNumGroupMembers() >= capacity then
            return
        end
    end

    if (UnitInParty and UnitInParty(conversation.name)) or (UnitInRaid and UnitInRaid(conversation.name)) then
        return
    end

    local match = false
    Format.VisitTokens(message.text, function(token)
        local _, word = wordParts(token)
        if word and self.lookup[word:lower()] == "invite" then
            match = true
        end
    end)

    if not match or not self:Trusted(conversation) or not addon.Actions:CanInvite(conversation) then
        return
    end

    local now = GetTime()
    for key, sent in pairs(self.cooldowns) do
        if now - sent >= 30 then
            self.cooldowns[key] = nil
        end
    end

    if self.cooldowns[payload.key] or (self.lastInvite and now - self.lastInvite < 2) then
        return
    end

    self.cooldowns[payload.key], self.lastInvite = now, now
    addon.Actions:Invite(conversation)
end

function Keywords:BuildOptions()
    local settings = self:GetSettings()
    local args = {
        help = {
            type = "description",
            order = 0,
            name = L["Match whole words, ignoring case. Separate words with commas. Links, URLs and outgoing messages are left untouched."],
        },

        automatic = {
            type = "group",
            name = L["Auto invite"],
            inline = true,
            order = 1,
            args = {
                autoInvite = { type = "toggle", name = L["Auto invite"], width = "full", order = 1 },
                guard = {
                    type = "description",
                    order = 2,
                    hidden = function()
                        return not settings.autoInvite
                    end,

                    name = L["Safety guard: only the selected groups can receive automatic invites. With neither selected, nobody is invited. Combat, unknown senders and Battle.net whispers are skipped. Requests are limited to once per sender every 30 seconds."],
                },

                friends = {
                    type = "toggle",
                    name = L["Allow friends"],
                    order = 3,
                    hidden = function()
                        return not settings.autoInvite
                    end,
                },

                guild = {
                    type = "toggle",
                    name = L["Allow guild members"],
                    order = 4,
                    hidden = function()
                        return not settings.autoInvite
                    end,
                },
            },
        },

        add = {
            type = "group",
            name = L["Add a rule"],
            inline = true,
            order = 100,
            args = {
                words = {
                    type = "input",
                    name = L["Words"],
                    order = 1,
                    width = "full",
                    get = function()
                        return self.newWords or ""
                    end,

                    set = function(_, v)
                        self.newWords = v
                    end,
                },

                action = {
                    type = "select",
                    name = L["Click action"],
                    order = 2,
                    values = actions,
                    get = function()
                        return self.newAction or "invite"
                    end,

                    set = function(_, v)
                        self.newAction = v
                    end,
                },

                add = {
                    type = "execute",
                    name = L["Add rule"],
                    order = 3,
                    disabled = function()
                        return #settings.rules >= 20 or self:Validate(self.newWords or "") ~= true
                    end,

                    func = function()
                        if
                            #settings.rules >= 20
                            or self:Validate(self.newWords or "") ~= true
                            or not actions[self.newAction or "invite"]
                        then
                            return
                        end

                        settings.rules[#settings.rules + 1] =
                            { words = self.newWords, action = self.newAction or "invite" }
                        self.newWords = ""
                        self:Changed()
                    end,
                },

                hint = {
                    type = "description",
                    order = 4,
                    name = function()
                        if #settings.rules >= 20 then
                            return L["Up to 20 rules are supported."]
                        end

                        local valid = self:Validate(self.newWords or "")
                        return valid == true and "" or valid
                    end,
                },
            },
        },
    }

    for index, rule in ipairs(settings.rules) do
        local current = rule
        args["rule" .. index] = {
            type = "group",
            name = current.words,
            inline = true,
            order = index + 1,
            args = {
                words = {
                    type = "input",
                    name = L["Words"],
                    order = 1,
                    width = "full",
                    get = function()
                        return current.words
                    end,

                    validate = function(_, v)
                        return self:Validate(v, current)
                    end,

                    set = function(_, v)
                        if self:Validate(v, current) == true then
                            current.words = v
                            self:Changed()
                        end
                    end,
                },

                action = {
                    type = "select",
                    name = L["Click action"],
                    order = 2,
                    values = actions,
                    get = function()
                        return current.action
                    end,

                    set = function(_, v)
                        if actions[v] then
                            current.action = v
                            self:Changed()
                        end
                    end,
                },

                remove = {
                    type = "execute",
                    name = L["Remove rule"],
                    order = 3,
                    func = function()
                        for i, item in ipairs(settings.rules) do
                            if item == current then
                                table.remove(settings.rules, i)
                                break
                            end
                        end

                        self:Changed()
                    end,
                },
            },
        }
    end

    self:RegisterOptions({ type = "group", name = L["Keyword settings"], args = args })
end

function Keywords:OnInitialize()
    self:RegisterDefaults({ autoInvite = false, friends = true, guild = true })
    local settings = self:GetSettings()
    if settings.rules == nil then
        settings.rules = { { words = "inv, invite, invites", action = "invite" } }
    end

    local global = Whispr.db.global
    global.extensions = global.extensions or {}
    if global.extensions.keywords == nil then
        global.extensions.keywords = global.inviteLinks ~= false
    end

    global.inviteLinks = nil
    self:Compile()
    self:BuildOptions()
end

function Keywords:OnEnable()
    self.cooldowns = {}
    self.lastInvite = nil
    self:RegisterFilter("FORMAT_KEYWORD_TOKEN", "RenderToken")
    self:RegisterMessage("MESSAGE_RECEIVED", "OnMessage")
    self:Refresh()
end

function Keywords:OnDisable()
    self.cooldowns = {}
    self:Refresh()
end
