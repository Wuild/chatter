local addon, queue = {}, {}
assert(loadfile("tests/support/locale.lua"))(addon)
C_Timer = {
    After = function(_, callback)
        queue[#queue + 1] = callback
    end,
}

local function flush()
    while #queue > 0 do
        local work = queue
        queue = {}
        for _, fn in ipairs(work) do
            fn()
        end
    end
end

local function load(name)
    assert(loadfile("scripts/" .. name .. ".lua"))("Whispr", addon)
end

Whispr = {}
load("theme")
assert(loadfile("tests/support/themes.lua"))(addon)
load("extensions")
local module = Whispr:NewExtension("example", { name = "Example" })
local initialized, enabled, disabled, received = 0, 0, 0, 0
module:RegisterDefaults({ count = 2, nested = { amount = 3 }, flag = true })

function module:OnInitialize()
    initialized = initialized + 1
    assert(self == module and self:GetName() == "example")
    self:RegisterOptions({
        type = "group",
        name = "Options",
        args = {
            count = { type = "range", name = "Count", min = 0, max = 10, step = 1 },
        },
    })
end

function module:OnEnable()
    assert(self:IsEnabled(), "module is enabled during OnEnable")
    enabled = enabled + 1
    self:RegisterMessage("MESSAGE_RECEIVED", "OnMessage")
    self:RegisterMessage("MESSAGE_RECEIVED", "OnMessage")
    assert(self:RegisterTheme("sample", { name = "Sample", colors = { accentColor = { 0.2, 0.4, 0.6 } } }))
end

function module:OnDisable()
    disabled = disabled + 1
end

function module:OnMessage(event, payload)
    assert(event == "MESSAGE_RECEIVED" and self == module)
    received = received + 1
    payload.message.text = "modified"
end

assert(initialized == 0, "database is not accessed at module declaration")
Whispr.db = { global = { extensions = {}, extensionSettings = { example = { count = 7, flag = false } } } }
addon.Extensions:Initialize()
assert(initialized == 1 and enabled == 0, "initialization happens once, before activation")
assert(
    module:GetSettings().count == 7 and module:GetSettings().flag == false and module:GetSettings().nested.amount == 3,
    "defaults fill gaps and preserve saved values"
)
addon.Extensions:Start()
addon.Extensions:Start()
assert(initialized == 1 and enabled == 1, "repeated startup does not duplicate lifecycle")
local payload = { message = { text = "original" } }
addon.Extensions:Emit("MESSAGE_RECEIVED", payload)
assert(
    received == 1 and payload.message.text == "original",
    "method registration replaces duplicate and isolates payload"
)
local options = addon.Extensions:Options().args.extension_example.args.settings
assert(options.handler == module, "AceConfig method handlers use module self")
options.set({ "count" }, 8)
assert(module:GetSettings().count == 8, "option defaults use module settings")
module:UnregisterMessage("MESSAGE_RECEIVED")
addon.Extensions:Emit("MESSAGE_RECEIVED", payload)
assert(received == 1, "unregister removes message subscription")
module:Disable()
assert(disabled == 1 and not module:IsEnabled())
module:Enable()
addon.Extensions:Emit("MESSAGE_RECEIVED", payload)
assert(enabled == 2 and initialized == 1 and received == 2, "reenable hooks once without reinitializing")
assert(Whispr:GetExtension("example") == module and Whispr.API.GetExtension("example") == module)
assert(Whispr:GetExtension("missing", true) == nil and not pcall(Whispr.GetExtension, Whispr, "missing"))
assert(not pcall(Whispr.NewExtension, Whispr, "example"), "duplicate module rejected")
local late = Whispr:NewExtension("late")
local lateInit = 0

function late:OnInitialize()
    lateInit = lateInit + 1
end

late:SetEnabledState(false)
assert(lateInit == 0, "late declaration waits until methods can be defined")
flush()
assert(lateInit == 1 and not late:IsEnabled(), "default-disabled modules still initialize")
Whispr:EnableExtension("late")
assert(late:IsEnabled())
Whispr:DisableExtension("late")
assert(not late:IsEnabled())
local found = {}
for id, value in Whispr:IterateExtensions() do
    found[id] = value
end

assert(found.example == module and found.late == late, "module discovery returns objects")
local broken = Whispr:NewExtension("broken")
local attempts = 0

function broken:OnInitialize()
    attempts = attempts + 1
    error("initialization failure")
end

flush()
assert(attempts == 1 and not broken:IsEnabled(), "failed initialization isolated without repeated automatic retry")

function broken:OnInitialize()
    attempts = attempts + 1
end

broken:Enable()
assert(attempts == 2 and broken:IsEnabled(), "explicit enable retries failed initialization")
local failing = Whispr:NewExtension("failing")
local cleaned = 0

function failing:OnEnable()
    self:RegisterMessage("MESSAGE_RECEIVED", function()
        error("message failure")
    end)
end

function failing:OnDisable()
    cleaned = cleaned + 1
end

flush()
addon.Extensions:Emit("MESSAGE_RECEIVED", payload)
assert(not failing:IsEnabled() and cleaned == 1 and module:IsEnabled(), "listener failure disables only failing module")
local selfDisabling = Whispr:NewExtension("self_disabling")

function selfDisabling:OnEnable()
    self:Disable()
end

flush()
assert(not selfDisabling:IsEnabled(), "disable during activation is honored")
addon.Extensions:Stop()
addon.Extensions:Start()
assert(initialized == 1 and enabled == 3, "parent restart reenables without reinitializing")
assert(not late:IsEnabled(), "saved disabled preference survives parent restart")
print("Module lifecycle, defaults, discovery, method messages, late loading, retry and cleanup passed.")

-- Exercise new events at their real history and peer-status sources.
local captured = {}
local observer = Whispr:NewExtension("observer")

function observer:OnEnable()
    for _, event in ipairs(Whispr.API.GetEvents()) do
        self:RegisterMessage(event, function(_, name, payload)
            captured[name] = captured[name] or {}
            table.insert(captured[name], payload)
            if payload.message then
                payload.message.text = "extension copy"
            end
        end)
    end
end

flush()
load("history")
load("typing")
local data = { sequence = 0, conversations = {} }
Whispr.db.char = data
local settings = { maxPeople = 20, maxMessages = 20 }
local conversation = addon.History.Add(data, settings, "Friend", "original", true, 10, false)
addon.History.Add(data, settings, "Friend", "second", false, 11, false)
assert(#captured.CONVERSATION_CREATED == 1, "created fires once per new history record")
conversation.messages[1].pending = true
addon.History.Confirm(data, conversation.key, "original")
assert(captured.MESSAGE_DELIVERY_CHANGED[1].status == "confirmed", "confirmation event carries delivery status")
assert(conversation.messages[1].text == "original", "delivery event snapshot cannot alter history")
GetTime = function()
    return 0
end

addon.Typing:SetIncoming(conversation.key, 8)
addon.Typing:SetIncoming(conversation.key, 9)
assert(#captured.TYPING_CHANGED == 1, "typing keepalive does not repeat state-change events")
GetTime = function()
    return 10
end

addon.Typing:Tick()
assert(#captured.TYPING_CHANGED == 2 and not captured.TYPING_CHANGED[2].typing, "expiry emits typing stopped")
addon.Typing:SetIncoming(conversation.key, 18)
addon.Typing:Disable()
assert(
    #captured.TYPING_CHANGED == 4 and not captured.TYPING_CHANGED[4].typing,
    "protocol disable clears typing with notification"
)
observer:Disable()
addon.Typing:SetIncoming(conversation.key, 30)
assert(#captured.TYPING_CHANGED == 4, "disabled modules receive none of the new events")
print("Event discovery, conversation creation, delivery snapshots and typing transitions passed.")

load("format")
assert(addon.Format.Message(":)", true) == ":)", "core has no built-in emoji parser")
local formatter = Whispr:NewExtension("formatter")

function formatter:OnEnable()
    self:RegisterFilter("FORMAT_MESSAGE_TOKEN", function(_, event, token)
        assert(event == "FORMAT_MESSAGE_TOKEN")
        if token == "hello" then
            return "HELLO"
        end
    end)
end

flush()
assert(addon.Format.Message("hello world", true) == "HELLO world", "module filters participate in actual formatting")
formatter:UnregisterAllMessages()
assert(addon.Format.Message("hello", true) == "HELLO", "message cleanup does not remove render filters")
formatter:Disable()
assert(addon.Format.Message("hello", true) == "hello", "disable removes render filters")
local badFilter = Whispr:NewExtension("bad_filter")

function badFilter:OnEnable()
    self:RegisterFilter("FORMAT_INPUT_TOKEN", function()
        return {}
    end)
end

flush()
assert(addon.Format.Input("hello", true) == "hello", "invalid filter preserves raw text")
assert(not badFilter:IsEnabled(), "invalid filter disables faulty extension")
print("Rendering hooks, no core emoji parser, cleanup and filter failure isolation passed.")
