local addon = { Window = {}, History = {} }
addon.developmentMode = true
assert(loadfile("tests/support/locale.lua"))(addon)
local opened, pending
C_Timer = {
    After = function(_, callback)
        pending = callback
    end,
}

addon.Window.frame = {
    IsShown = function()
        return true
    end,
}

addon.Window.scroll = {
    GetVerticalScrollRange = function()
        return 1000
    end,

    SetVerticalScroll = function(self, offset)
        self.offset = offset
    end,
}

addon.Window.latest = {
    Show = function(self)
        self.shown = true
    end,
}

function addon.Window:RefreshList()
    self.refreshed = true
end

function addon.Window:Open(key)
    opened = key
    self.active = key
    self.following = true
end

strtrim = function(text)
    return text:match("^%s*(.-)%s*$")
end

time = function()
    return 1791108000
end

local original = { messages = { { id = 1, text = "Keep me" } } }
Chatter = {
    db = {
        char = { sequence = 1, conversations = { friend = original } },
        global = {
            maxMessages = 20,
            maxPeople = 1,
        },
    },
}

assert(loadfile("scripts/main.lua"))("Chatter", addon)
Chatter:Command("demo")
local demo = Chatter.db.char.conversations[opened]
assert(demo.demo and #demo.messages == 100, "command creates one hundred local messages")
pending()
assert(
    demo.unread == 3 and addon.Window.following == false,
    "demo simulates three unread messages while reading above bottom"
)
assert(addon.Window.scroll.offset == 820 and addon.Window.latest.shown, "demo scrolls above latest messages")
assert(addon.Window.refreshed, "demo updates conversation card unread indicator")
assert(Chatter.db.char.conversations.friend == original, "demo preserves real history even with low retention")
assert(Chatter.db.global.maxMessages == 20, "demo does not change retention settings")
local days, directions = {}, {}
for index, message in ipairs(demo.messages) do
    assert(message.text:find("[" .. index .. "/100]", 1, true), "messages are numbered")
    days[os.date("%Y-%m-%d", message.time)] = true
    directions[tostring(message.outgoing)] = true
    if index > 1 then
        assert(message.time > demo.messages[index - 1].time, "chronological timestamps")
        assert(message.id > demo.messages[index - 1].id, "unique ordered IDs")
    end
end

local count = 0
for _ in pairs(days) do
    count = count + 1
end

assert(count >= 5 and directions["true"] and directions["false"], "multiple days and both message directions")
local lastID = demo.messages[100].id
Chatter:Command("demo")
demo = Chatter.db.char.conversations[opened]
assert(#demo.messages == 100 and demo.messages[1].id > lastID, "repeat command resets instead of duplicating")
local unreadCallback = pending
addon.Window.active = "friend"
unreadCallback()
assert(demo.unread == 0, "switching before callback does not alter another viewport")
local notice

function Chatter:Print(text)
    notice = text
end

C_ChatInfo = {
    SendChatMessage = function()
        error("demo must never send a whisper")
    end,
}

Chatter:Send({ active = opened, input = {
    GetText = function()
        return "hello"
    end,
} })

assert(notice and #demo.messages == 100, "sending in demo stays local")
print("Demo creation, date coverage, reset, history preservation and send guard passed.")
