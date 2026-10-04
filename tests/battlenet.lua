SOUNDKIT = { TELL_MESSAGE = 1 }
PlaySoundFile = function() end
local addon, queue = {}, {}
assert(loadfile("tests/support/locale.lua"))(addon)

local function load(name)
    assert(loadfile("scripts/" .. name .. ".lua"))("Chatter", addon)
end

local function equal(a, b, label)
    assert(a == b, label .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end

local function flush()
    local pending = queue
    queue = {}
    for _, callback in ipairs(pending) do
        callback()
    end
end

HasAnySecretValues = function(...)
    for index = 1, select("#", ...) do
        if select(index, ...) == "SECRET" then
            return true
        end
    end
end

local account = { bnetAccountID = 7, battleTag = "Friend#1234", accountName = "SECRET" }
local sentID, sentText
C_BattleNet = {
    GetAccountInfoByID = function(id)
        if id == account.bnetAccountID then
            return account
        end
    end,

    GetFriendAccountInfo = function()
        return account
    end,

    SendWhisper = function(id, text)
        sentID, sentText = id, text
    end,
}

BNGetNumFriends = function()
    return 1
end

BNet_GetBNetIDAccount = function(name)
    if name == "|Kfriend|k" then
        return account.bnetAccountID
    end
end

C_Timer = {
    After = function(_, callback)
        queue[#queue + 1] = callback
    end,
}

time = function()
    return 1
end

local opened, refreshed
addon.Window = {
    IsReading = function()
        return false
    end,

    Refresh = function(_, key)
        refreshed = key
    end,

    Receive = function() end,
    RefreshCharacters = function() end,
    Open = function(_, name, draft)
        opened = { name, draft }
    end,
}

Chatter = {
    db = { char = { conversations = {}, sequence = 0 }, global = { maxPeople = 50, maxMessages = 200 } },
    Print = function() end,
}

assert(loadfile("extensions/emoji/emotes.lua"))("Chatter", addon)
assert(loadfile("extensions/emoji/renderer.lua"))("Chatter", addon)
assert(loadfile("tests/support/emoji-filters.lua"))(addon)
load("format")
load("history")
load("battlenet")
load("sounds")
load("main")
local routed = false
addon.Window.Receive = function()
    routed = true
end

addon.Extensions = {
    ConversationEvent = function() end,
    Emit = function(_, event, payload)
        if event == "MESSAGE_RECEIVED" then
            assert(routed, "incoming event emitted after automatic window routing")
            routed = false
        end
    end,
}

local identity = addon.BattleNet.Resolve(7)
equal(identity.key, "bnet:friend#1234", "stable BattleTag identity")
equal(addon.BattleNet.Resolve(nil), nil, "unknown account safely ignored")
addon.History.Add(Chatter.db.char, Chatter.db.global, "Friend", "character message", false, 1)
Chatter:BattleNetWhisper("CHAT_MSG_BN_WHISPER", "hello", "SECRET", "", "", "", "", 0, 0, "", 0, 1, "", 7)
local conversation = Chatter.db.char.conversations[identity.key]
equal(conversation.messages[1].text, "hello", "Battle.net event account ID position")
equal(conversation.transport, "bnet", "transport retained")
equal(refreshed, identity.key, "correct conversation refreshed")
equal(#addon.History.Sorted(Chatter.db.char), 2, "same named character remains separate")
Chatter:BattleNetWhisper("CHAT_MSG_BN_WHISPER_INFORM", "reply", "SECRET", "", "", "", "", 0, 0, "", 0, 1, "", 7)
equal(conversation.messages[2].outgoing, true, "outgoing confirmation stored")
account.bnetAccountID = 99
local input = { text = "new session" }

function input:GetText()
    return self.text
end

function input:SetText(value)
    self.text = value
end

function input:SetFocus() end

local window = { active = identity.key, input = input, drafts = {} }
Chatter:Send(window)
equal(sentID, 99, "send resolves current account ID")
equal(sentText, "new session", "send uses Battle.net transport")
equal(#conversation.messages, 3, "pending message shown immediately")
equal(conversation.messages[3].pending, true, "pending is not presented as confirmed")
Chatter:BattleNetWhisper("CHAT_MSG_BN_WHISPER_INFORM", "new session", "SECRET", "", "", "", "", 0, 0, "", 0, 1, "", 99)
equal(#conversation.messages, 3, "confirmation reconciles without a duplicate")
equal(conversation.messages[3].pending, nil, "server echo confirms pending message")
equal(input.text, "", "successful send clears draft")
BNGetNumFriends = function()
    return 0
end

input.text = "keep this"
Chatter:Send(window)
equal(input.text, "keep this", "unavailable account preserves draft")
local box = { attributes = { chatType = "BN_WHISPER", tellTarget = "|Kfriend|k" }, text = "draft" }

function box:GetAttribute(k)
    return self.attributes[k]
end

function box:SetAttribute(k, v)
    self.attributes[k] = v
end

function box:GetText()
    return self.text
end

function box:SetText(v)
    self.text = v
end

function box:ClearFocus() end

function box:Hide() end

Chatter:RouteEditBox(box)
flush()
equal(opened[1], identity.key, "friends-menu handoff uses account identity")
equal(opened[2], "draft", "Battle.net handoff preserves draft")
print("Battle.net identity, events, replies, session ID changes and native handoff passed.")
