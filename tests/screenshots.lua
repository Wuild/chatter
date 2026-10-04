local addon = {}
addon.developmentMode = true
assert(loadfile("tests/support/locale.lua"))(addon)
local original = { messages = { { text = "Private history" } } }
Chatter = {
    db = { char = { sequence = 1, conversations = { real = original } }, global = { maxPeople = 1, maxMessages = 1 } },
}

time = function()
    return 1791108000
end

strtrim = function(text)
    return text
end

local invalidated = false
addon.History = {
    Invalidate = function()
        invalidated = true
    end,
}

addon.Window = {
    Open = function(self, key)
        self.active = key
    end,

    RefreshList = function() end,
}

C_ChatInfo = {
    SendChatMessage = function()
        error("Screenshot samples must not send whispers")
    end,
}

assert(loadfile("scripts/screenshots.lua"))("Chatter", addon)
assert(loadfile("scripts/main.lua"))("Chatter", addon)
Chatter:Command("screenshots")
assert(invalidated and addon.Window.active == "demo:screenshot:aeloria", "command opens the leading sample")
local count, unread, ids = 0, 0, {}
for key, conversation in pairs(Chatter.db.char.conversations) do
    if key ~= "real" then
        count = count + 1
        assert(conversation.demo and #conversation.messages == 8, "fictional local-only conversations")
        assert(conversation.character.classFile and conversation.character.race, "class icon and identity metadata")
        unread = unread + conversation.unread
        for index, message in ipairs(conversation.messages) do
            assert(not ids[message.id], "unique message IDs")
            ids[message.id] = true
            if index > 1 then
                assert(message.time > conversation.messages[index - 1].time, "chronological messages")
            end

            if index > #conversation.messages - conversation.unread then
                assert(not message.outgoing, "unread messages are incoming")
            end
        end
    end
end

assert(count == 10 and unread > 0, "ten samples with unread badges")
assert(
    Chatter.db.char.conversations.real == original and Chatter.db.global.maxPeople == 1,
    "real history and settings preserved"
)
local sequence = Chatter.db.char.sequence
Chatter:Command("screenshots")
assert(Chatter.db.char.sequence == sequence + 80, "repeat command replaces the same ten samples")
local notice

function Chatter:Print(text)
    notice = text
end

Chatter:Send({ active = addon.Window.active, input = {
    GetText = function()
        return "hello"
    end,
} })

assert(notice, "existing demo send guard protects screenshot samples")
print("Ten screenshot conversations, metadata, unread state, repeatability and send protection passed.")

addon.developmentMode = false
local before = Chatter.db.char.sequence
Chatter:Command("screenshots")
Chatter:Command("demo")
addon.Screenshots:Create()
Chatter:CreateDemoConversation()
assert(Chatter.db.char.sequence == before, "disabled commands and direct calls cannot recreate demos")
assert(loadfile("scripts/debug.lua"))("Chatter", addon)
assert(addon.Debug:Options().hidden, "debug settings hidden in normal builds")
assert(addon.Debug:Conversation() == nil, "disabled debug cannot create conversations")
addon.Debug:Incoming()
addon.Debug:Typing()
addon.Debug:Notification()
assert(Chatter.db.char.sequence == before, "disabled debug actions do nothing")
