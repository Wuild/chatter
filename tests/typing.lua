local addon, now, packets = {}, 100, {}
assert(loadfile("tests/support/locale.lua"))(addon)
GetTime = function()
    return now
end

GetNormalizedRealmName = function()
    return "Home"
end

local function load(name)
    assert(loadfile("scripts/" .. name .. ".lua"))("Whispr", addon)
end

local function equal(a, b, label)
    assert(a == b, label .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end

CreateFrame = function()
    return {
        scripts = {},
        RegisterEvent = function() end,
        SetScript = function(self, k, v)
            self.scripts[k] = v
        end,

        Show = function(self)
            self.shown = true
        end,

        Hide = function(self)
            self.shown = false
        end,
    }
end

local locked = false
C_ChatInfo = {
    RegisterAddonMessagePrefix = function(prefix)
        equal(prefix, "WhisprTyping1", "versioned prefix")
        return true
    end,

    InChatMessagingLockdown = function()
        return locked
    end,

    SendAddonMessage = function(prefix, payload, channel, target)
        packets[#packets + 1] = { payload = payload, target = target, channel = channel }
    end,
}

Whispr = {
    db = {
        global = {},
        char = {
            conversations = {
                friend = { key = "friend", name = "Friend", messages = {} },
                demo = {
                    key = "demo",
                    name = "Demo",
                    demo = true,
                },
            },
        },
    },
}

load("history")
load("characters")
load("battlenet")
load("typing")
local t = addon.Typing
local input = {
    text = "draft contents never shared",
    GetText = function(self)
        return self.text
    end,
}

local frame = {
    shown = true,
    IsShown = function(self)
        return self.shown
    end,
}

local window = { active = "friend", input = input, frame = frame }
t:Enable()
t:Changed(window)
equal(#packets, 1, "first edit only probes support")
equal(packets[1].payload, "H", "handshake before status")
t:Changed(window)
equal(#packets, 1, "probe throttled")
t:Receive("CHAT_MSG_ADDON", t.prefix, "A", "WHISPER", "Friend-Home")
equal(packets[2].payload, "T", "acknowledged peer receives pending typing status")
t:Changed(window)
equal(#packets, 2, "local realm normalization retains peer and throttles typing")
now = 102.1
t:Changed(window)
equal(#packets, 3, "continued editing sends bounded heartbeat")
equal(packets[3].payload, "T", "heartbeat carries only status")
now = 106.2
t:Tick()
equal(packets[4].payload, "S", "idle sends stop")
now = 110
t:Receive("CHAT_MSG_ADDON", t.prefix, "T", "WHISPER", "Friend-Home")
assert(t:IsTyping("friend"), "typing appears for capable peer")
equal(#Whispr.db.char.conversations.friend.messages, 0, "typing is not history")
t:Receive("CHAT_MSG_ADDON", t.prefix, "S", "WHISPER", "Friend-Home")
assert(not t:IsTyping("friend"), "explicit stop clears badge")
t:Receive("CHAT_MSG_ADDON", t.prefix, "T", "WHISPER", "Friend-Home")
now = 119
t:Tick()
assert(not t:IsTyping("friend"), "missing stop expires")
local count = #packets
t:Receive("CHAT_MSG_ADDON", "Other", "H", "WHISPER", "Friend-Home")
t:Receive("CHAT_MSG_ADDON", t.prefix, "H", "PARTY", "Friend-Home")
t:Receive("CHAT_MSG_ADDON", t.prefix, "unexpected", "WHISPER", "Friend-Home")
equal(#packets, count, "unrelated channels prefixes and malformed payloads ignored")
t:Receive("CHAT_MSG_ADDON", t.prefix, "H", "WHISPER", "Stranger")
equal(packets[#packets].payload, "A", "first contact can discover addon without saved history")
assert(not Whispr.db.char.conversations.stranger, "discovery never creates chats")
t:Receive("CHAT_MSG_ADDON", t.prefix, "T", "WHISPER", "Stranger")
assert(not t:IsTyping("stranger"), "unknown sender cannot open typing badge")
now = 120
t:Changed(window)
input.text = ""
t:Changed(window)
equal(packets[#packets].payload, "S", "clearing draft stops typing")
input.text = "hello"
now = 123
t:Changed(window)
window.active = "demo"
t:Tick()
equal(packets[#packets].payload, "S", "conversation switch stops previous target")
count = #packets
t:Changed(window)
equal(#packets, count, "demo never sends packets")
window.active = "friend"
locked = true
now = 125
t:Changed(window)
equal(#packets, count, "lockdown does not send or throw")
locked = false
t:Tick()
equal(packets[#packets].payload, "T", "typing resumes when transport available")
t:Disable()
equal(packets[#packets].payload, "S", "disable clears remote status")
assert(not t.frame.shown and not t:IsTyping("friend"), "disable stops ticker and badges")
Whispr.db.global.typingIndicators = false
count = #packets
t:Enable()
t:Changed(window)
equal(#packets, count, "opt-out blocks discovery and typing")
Whispr.db.global.typingIndicators = true
local gameID = 901
BNGetNumFriends = function()
    return 1
end

local function friendInfo()
    return {
        battleTag = "Friend#1234",
        bnetAccountID = 42,
        gameAccountInfo = { gameAccountID = gameID, clientProgram = "WoW", isOnline = true },
    }
end

C_BattleNet = {
    GetFriendAccountInfo = friendInfo,
    GetAccountInfoByID = friendInfo,
    SendGameData = function(id, prefix, payload)
        packets[#packets + 1] = { target = id, payload = payload }
    end,
}

local bn = { key = "bnet:friend#1234", name = "Friend", battleTag = "Friend#1234", transport = "bnet", messages = {} }
Whispr.db.char.conversations[bn.key] = bn
window.active = bn.key
t:Enable()
now = 130
t:Changed(window)
equal(packets[#packets].target, 901, "Battle.net uses game account ID not whisper account ID")
t:Receive("BN_CHAT_MSG_ADDON", t.prefix, "A", "WHISPER", 901)
equal(packets[#packets].payload, "T", "Battle.net support handshake enables typing")
t:Receive("BN_CHAT_MSG_ADDON", t.prefix, "T", "WHISPER", 901)
assert(t:IsTyping(bn.key), "Battle.net sender maps to saved BattleTag")
t:Clear(bn.key)
assert(not t:IsTyping(bn.key), "received whisper clears typing immediately")
gameID = 902
now = 133
t:Changed(window)
equal(packets[#packets].payload, "H", "session ID change requires fresh discovery")
equal(packets[#packets].target, 902, "new session resolves fresh endpoint")
print("Typing handshake, throttling, privacy, expiry, lifecycle, opt-out and Battle.net IDs passed.")

-- Offline roster evidence blocks probes, heartbeats and stop packets alike.
window.active = "friend"
addon.Characters.online.friend = false
count = #packets
t:Discover("friend")
t:Changed(window)
assert(not t:Transmit("Friend-Home", "S"), "offline stop packet rejected")
assert(not t:Transmit("Friend", "T"), "offline heartbeat rejected")
equal(#packets, count, "known offline character receives no addon traffic")
addon.Characters.online.friend = true
now = 500
t:Changed(window)
assert(#packets > count, "typing can discover support once friend is online again")
print("Offline characters receive no typing probes, heartbeats or stop packets.")
