local addon = {}
assert(loadfile("tests/support/locale.lua"))(addon)

local function load(name)
    assert(loadfile("scripts/" .. name .. ".lua"))("Whispr", addon)
end

local function equal(a, b, label)
    assert(a == b, label .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end

Whispr = { db = { global = { extensions = {}, chatFontSize = 19, maxMessages = 350 }, char = { conversations = {} } } }
load("theme")
load("extensions")
local api = Whispr.API
local activated, disabled, seen = 0, 0, 0
local themeID
assert(api.RegisterExtension("test", {
    name = "Test integration",
    version = "1.0",
    description = "Example",
    onEnable = function(context)
        activated = activated + 1
        context.GetSettings().enabledBefore = true
        themeID =
            assert(context.RegisterTheme("violet", { name = "Violet", colors = { accentColor = { 0.7, 0.3, 0.8 } } }))
        assert(context.On("MESSAGE_RECEIVED", function(payload)
            payload.message.text = "changed"
            seen = seen + 1
        end))
    end,

    onDisable = function()
        disabled = disabled + 1
    end,

    options = {
        type = "group",
        name = "Options",
        args = {
            maxMessages = { type = "range", name = "Own setting", min = 1, max = 5, step = 1 },
        },
    },
}))

equal(activated, 0, "registration before start defers activation")
addon.Extensions:Start()
equal(activated, 1, "start activates registered integration")
assert(api.IsExtensionEnabled("test"), "active extension discoverable")
assert(addon.Theme:Available(themeID), "enabled extension theme available")
local message = { message = { text = "original" } }
addon.Extensions:Emit("MESSAGE_RECEIVED", message)
equal(seen, 1, "enabled extension gets events")
equal(message.message.text, "original", "event payload cannot mutate core history")
local options = addon.Extensions:Options().args.extension_test.args.settings
options.set({ "maxMessages" }, 4)
equal(options.get({ "maxMessages" }), 4, "extension controls default to isolated settings")
equal(Whispr.db.global.maxMessages, 350, "extension option cannot overwrite same-named core preference")
addon.Theme:Apply(themeID)
equal(Whispr.db.global.accentColor[1], 0.7, "extension preset applied")
addon.Extensions:SetEnabled("test", false)
equal(disabled, 1, "disable cleanup called")
assert(not addon.Theme:Available(themeID), "disabled extension themes not selectable")
equal(addon.Theme:CurrentPreset(), "custom", "disabled theme becomes custom while retaining colors")
equal(Whispr.db.global.accentColor[1], 0.7, "disabling pack does not discard applied colors")
addon.Extensions:Emit("MESSAGE_RECEIVED", message)
equal(seen, 1, "disabled event hooks removed")
addon.Extensions:SetEnabled("test", true)
equal(activated, 2, "reenable works without duplicate theme failure")
addon.Extensions:Emit("MESSAGE_RECEIVED", message)
equal(seen, 2, "reenable does not duplicate hooks")
assert(not api.RegisterExtension("test", { name = "Duplicate" }), "duplicate extension ID rejected")
assert(
    not api.RegisterTheme("bad", { name = "Invalid", colors = { accentColor = { 2, 0, 0 } } }),
    "out-of-range theme rejected"
)
assert(
    not api.RegisterTheme("bad", { name = "Invalid", colors = { notAColor = { 0, 0, 0 } } }),
    "unknown theme field rejected"
)
assert(
    not api.RegisterTheme("bad", { name = "Invalid", colors = { accentColor = { 0 / 0, 0, 0 } } }),
    "NaN color rejected"
)
local palette = { name = "Snapshot", colors = { accentColor = { 0.1, 0.2, 0.3 } } }
assert(api.RegisterTheme("snapshot", palette))
palette.colors.accentColor[1] = 1
addon.Theme:Apply("snapshot")
equal(Whispr.db.global.accentColor[1], 0.1, "registry copies theme colors")
equal(Whispr.db.global.chatFontSize, 19, "theme preserves font preference")
equal(Whispr.db.global.maxMessages, 350, "theme preserves retention")
Whispr.db.global.accentColor[1] = 0.9
equal(addon.Theme:CurrentPreset(), "custom", "manual colors identify custom palette")
addon.Theme:Apply("snapshot")
equal(Whispr.db.global.accentColor[1], 0.1, "applied colors do not mutate preset")
assert(api.RegisterExtension("broken", {
    name = "Broken",
    onEnable = function(context)
        context.On("MESSAGE_RECEIVED", function()
            error("should not run")
        end)

        error("activation failure")
    end,
}))

assert(not api.IsExtensionEnabled("broken"), "activation failures isolated")
assert(
    addon.Extensions.entries.broken.error:find("activation failure", 1, true),
    "activation error available in settings"
)
assert(api.RegisterExtension("event_error", {
    name = "Event error",
    onEnable = function(context)
        context.On("MESSAGE_RECEIVED", function()
            error("callback failure")
        end)
    end,
}))

addon.Extensions:Emit("MESSAGE_RECEIVED", message)
assert(not api.IsExtensionEnabled("event_error"), "faulty listener automatically stopped")
assert(api.IsExtensionEnabled("test"), "other extensions continue after callback failure")
addon.Extensions:Stop()
assert(not api.IsExtensionEnabled("test"), "addon shutdown deactivates extensions")
print("Extension lifecycle, isolated settings/events, failures, theme validation and palette persistence passed.")
