local _, addon = ...
local L = addon.L
local Debug = {}
addon.Debug = Debug

function Debug:Conversation()
    if not addon.developmentMode then
        return
    end

    local data, key = Chatter.db.char, "demo:chatter"
    local conversation = data.conversations[key]
    if not conversation then
        conversation = {
            key = key,
            name = L["Chatter Demo"],
            demo = true,
            unread = 0,
            messages = {},
            updated = data.sequence or 0,
        }

        data.conversations[key] = conversation
        if addon.Extensions then
            addon.Extensions:ConversationEvent("CONVERSATION_CREATED", conversation)
        end
    end

    return conversation
end

function Debug:Incoming()
    if not addon.developmentMode then
        return
    end

    local conversation = self:Conversation()
    local data, window = Chatter.db.char, addon.Window
    data.sequence = (data.sequence or 0) + 1
    local message = {
        id = data.sequence,
        text = L["This is a simulated incoming whisper. Hello from Chatter! :)"],
        time = time(),
        outgoing = false,
    }

    conversation.messages[#conversation.messages + 1] = message
    conversation.updated = data.sequence
    conversation.unread = window:IsReading(conversation.key) and 0 or (conversation.unread or 0) + 1
    -- Limit only the demo; simulation must never evict real conversation history.
    while #conversation.messages > 200 do
        table.remove(conversation.messages, 1)
    end

    conversation.unread = math.min(conversation.unread, #conversation.messages)
    window:Refresh(conversation.key)
    Chatter:PlayMessageSound()
    window:Receive(conversation.key)
    if addon.Extensions then
        addon.Extensions:ConversationEvent("MESSAGE_RECEIVED", conversation, { message = message, simulated = true })
    end
end

function Debug:Typing()
    if not addon.developmentMode then
        return
    end

    local conversation = self:Conversation()
    local hub = addon.Window
    hub:Open(conversation.key)
    local window = hub.detached and hub.detached[conversation.key] or hub
    window.demoTypingKey, window.demoTypingUntil = conversation.key, GetTime() + 8
    window:UpdateTyping()
end

function Debug:Notification()
    if not addon.developmentMode then
        return
    end

    if not addon.Extensions:IsEnabled("notification") then
        return
    end

    addon.Notification:Receive({
        key = "preview",
        name = L["Chatter Demo"],
        transport = "whisper",
        message = { text = L["This is a simulated incoming whisper. Hello from Chatter! :)"] },
    }, true)
end

function Debug:Options()
    return {
        type = "group",
        name = L["Debug"],
        hidden = not addon.developmentMode,
        order = 8,
        args = {
            description = {
                type = "description",
                order = 1,
                name = L["Local simulations only. No whispers or typing packets are sent to other players. Real conversation history is preserved."],
            },

            incoming = {
                type = "execute",
                name = L["Simulate incoming message"],
                order = 2,
                width = "full",
                desc = L["Adds a message to Chatter Demo and uses your normal window, sound and notification visibility settings."],
                func = function()
                    self:Incoming()
                end,
            },

            notification = {
                type = "execute",
                name = L["Preview notification"],
                order = 3,
                width = "full",
                disabled = function()
                    return not addon.Extensions:IsEnabled("notification")
                end,

                func = function()
                    self:Notification()
                end,
            },

            typing = {
                type = "execute",
                name = L["Simulate typing"],
                order = 4,
                width = "full",
                desc = L["Opens Chatter Demo and shows typing dots for eight seconds."],
                func = function()
                    self:Typing()
                end,
            },

            screenshots = {
                type = "execute",
                name = L["Load screenshot conversations"],
                order = 6,
                width = "full",
                desc = L["Creates ten fictional characters and conversations without replacing real history."],
                func = function()
                    addon.Screenshots:Create()
                end,
            },

            demo = {
                type = "execute",
                name = L["Open 100-message demo"],
                order = 5,
                width = "full",
                func = function()
                    Chatter:CreateDemoConversation()
                end,
            },
        },
    }
end
