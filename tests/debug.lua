local addon = {}
addon.developmentMode = true
assert(loadfile("tests/support/locale.lua"))(addon)
time = function()
    return 10
end

GetTime = function()
    return 20
end

local original = { messages = { { text = "real history" } } }
Whispr = {
    db = { char = { sequence = 1, conversations = { friend = original } }, global = { maxMessages = 1, maxPeople = 1 } },
}

local sent, sound, events = 0, 0, {}
C_ChatInfo = {
    SendChatMessage = function()
        sent = sent + 1
    end,

    SendAddonMessage = function()
        sent = sent + 1
    end,
}

function Whispr:PlayMessageSound()
    sound = sound + 1
end

addon.Window = {
    IsReading = function()
        return false
    end,

    Refresh = function() end,
    Receive = function(self, key)
        self.received = key
    end,

    Open = function(self, key)
        self.active = key
    end,

    UpdateTyping = function(self)
        self.typingUpdated = true
    end,
}

addon.Extensions = {
    IsEnabled = function()
        return true
    end,

    ConversationEvent = function(_, event, payload, extra)
        events[event] = extra or payload
    end,
}

addon.Notification = {
    Receive = function(self, payload, preview)
        self.payload, self.preview = payload, preview
    end,
}

assert(loadfile("scripts/debug.lua"))("Whispr", addon)
addon.Debug:Incoming()
local demo = Whispr.db.char.conversations["demo:whispr"]
assert(demo.demo and #demo.messages == 1 and demo.unread == 1, "incoming simulation is local demo history")
assert(
    addon.Window.received == demo.key and sound == 1 and events.MESSAGE_RECEIVED.message == demo.messages[1],
    "incoming follows routing, sound and event path"
)
assert(events.MESSAGE_RECEIVED.simulated == true, "incoming event identifies local simulation")
for i = 1, 205 do
    addon.Debug:Incoming()
end

assert(
    #demo.messages == 200 and Whispr.db.char.conversations.friend == original,
    "simulation bounded without evicting real history"
)
addon.Debug:Typing()
assert(addon.Window.demoTypingUntil == 28 and addon.Window.typingUpdated, "typing simulation is local and expires")
addon.Debug:Notification()
assert(addon.Notification.preview and addon.Notification.payload.message.text, "notification simulation includes text")
assert(sent == 0, "debug actions never call transport APIs")
print("Local debug messages, bounded history, notifications, typing and no transport sends passed.")
