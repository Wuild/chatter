securecallfunction = function(fn, ...)
    return fn(...)
end

local addon = {}
assert(loadfile("tests/support/locale.lua"))(addon)

local function load(name)
    assert(loadfile("scripts/" .. name .. ".lua"))("Chatter", addon)
end

assert(loadfile("scripts/libraries/LibStub/LibStub.lua"))()
assert(loadfile("scripts/libraries/CallbackHandler-1.0/CallbackHandler-1.0.lua"))()
assert(loadfile("scripts/libraries/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua"))()
local aceAddon = LibStub:NewLibrary("AceAddon-3.0", 1)

function aceAddon:NewAddon()
    return {}
end

local registry = LibStub("AceConfigRegistry-3.0")
local aceConfig = LibStub:NewLibrary("AceConfig-3.0", 1)

function aceConfig:RegisterOptionsTable(...)
    return registry:RegisterOptionsTable(...)
end

local function copy(t)
    local result = {}
    for k, v in pairs(t) do
        result[k] = type(v) == "table" and copy(v) or v
    end

    return result
end

load("config")
Chatter.db = { global = copy(addon.defaults.global), char = { conversations = {} } }
Chatter.db.global.maxMessages = 350
Chatter.db.global.chatFontSize = 19
Chatter.db.global.windowColor = { 0.15, 0.12, 0.1 }
local trims, refreshes, cardRefreshes, mode, combat, typing, sounds = 0, 0, 0, nil, nil, false, 0
addon.History = {
    Trim = function()
        trims = trims + 1
    end,
}

addon.Media = {
    Fonts = function()
        return { default = "Default" }
    end,

    Refresh = function()
        refreshes = refreshes + 1
    end,
}

addon.Window = {
    RefreshList = function()
        cardRefreshes = cardRefreshes + 1
    end,

    Refresh = function()
        refreshes = refreshes + 1
    end,

    SetSeparateMode = function(_, v)
        mode = v
    end,

    CombatChanged = function(_, v)
        combat = v
    end,
}

addon.Typing = {
    Enable = function()
        typing = true
    end,

    Disable = function()
        typing = false
    end,
}

addon.Sounds = { labels = { test = "Test" } }

function Chatter:PlayMessageSound()
    sounds = sounds + 1
end

InCombatLockdown = function()
    return true
end

load("theme")
load("extensions")
assert(loadfile("extensions/notification/module.lua"))("Chatter", addon)
assert(loadfile("extensions/keywords/module.lua"))("Chatter", addon)
assert(loadfile("extensions/character-names/module.lua"))("Chatter", addon)
load("debug")
load("settings")
local panels, opened = {}, nil
local dialog = LibStub:NewLibrary("AceConfigDialog-3.0", 1)

function dialog:AddToBlizOptions(app, name, parent, path, child)
    assert(app == "ChatterLauncher")
    panels[#panels + 1] = { app = app, name = name, parent = parent, path = path, child = child }
    return {}, 100 + #panels
end

function dialog:SetDefaultSize(app, width, height)
    assert(app == "Chatter" and width == 840 and height == 580)
end

function dialog:Open(app, container)
    assert(app == "Chatter" and container == nil, "AceConfig owns the whole window")
    opened = "standard"
end

addon.Settings:Initialize()
assert(#panels == 1, "only one native launcher page")
assert(
    panels[1].name == "Chatter" and panels[1].parent == nil and panels[1].path == nil,
    "launcher has no subcategory paths"
)
local launcher = registry:GetOptionsTable("ChatterLauncher")("dialog", "AceConfigDialog-3.0")
registry:ValidateOptionsTable(launcher, "ChatterLauncher")
local controls = 0
for _, control in pairs(launcher.args) do
    assert(control.type == "execute")
    controls = controls + 1
end

assert(controls == 1, "native page contains only the open button")
local hidden
SettingsPanel = {
    IsShown = function()
        return true
    end,
}

HideUIPanel = function(frame)
    hidden = frame
end

launcher.args.open.func()
assert(hidden == SettingsPanel and opened == "standard", "launcher closes native settings and opens standalone window")
SettingsPanel = nil
addon.Settings:Show()
assert(opened == "standard", "cog opens standard AceConfig window")
assert(#panels == 1, "reopening does not duplicate registrations")
local notified = 0
registry.RegisterCallback({}, "ConfigTableChange", function(_, name)
    assert(name == "Chatter")
    notified = notified + 1
end)

addon.Settings:Refresh()
assert(notified == 1, "extensions and theme changes notify native options")
local options = registry:GetOptionsTable("Chatter")("dialog", "AceConfigDialog-3.0")
registry:ValidateOptionsTable(options, "Chatter")
local count = 0
for key, group in pairs(options.args) do
    assert(group.type == "group" and not group.inline, key .. " must be a category")
    count = count + 1
end

assert(count == 8, "eight distinct categories")
assert(
    Chatter.db.global.maxMessages == 350 and Chatter.db.global.chatFontSize == 19,
    "opening settings preserves existing preferences"
)
assert(addon.Theme:CurrentPreset() == "custom", "legacy custom colors remain custom")
options.args.general.args.conversations.args.separateWindows.set(nil, true)
assert(mode, "mode setting retains live behavior")
local combatOptions = options.args.general.args.combat.args
assert(combatOptions.hideInCombat.name == "Hide when entering combat", "combat label describes entry behavior")
assert(combatOptions.dontHideWhenTyping.disabled(), "typing exception unavailable when combat hiding is off")
combatOptions.hideInCombat.set(nil, true)
assert(combat, "combat setting applies immediately")
assert(not combatOptions.dontHideWhenTyping.disabled(), "typing exception enabled with combat hiding")
combatOptions.dontHideWhenTyping.set(nil, true)
assert(Chatter.db.global.dontHideWhenTyping, "typing exception saved")
options.args.messages.args.presence.args.typingIndicators.set(nil, true)
assert(typing, "typing toggle still enables protocol")
options.args.messages.args.layout.args.showMessagePreviews.set(nil, false)
assert(cardRefreshes == 1, "preview setting refreshes cards")
options.args.messages.set({ "messages", "smileys" }, false)
assert(refreshes == 1, "format settings rerender messages")
options.args.appearance.args.typography.set({ "appearance", "typography", "chatFontSize" }, 22)
assert(Chatter.db.global.chatFontSize == 22, "nested font controls write correct preference")
options.args.notifications.args.notificationSound.set(nil, "test")
assert(sounds == 1, "sound selection previews sample")
assert(trims == 0, "visual and behavioral settings never trim history")
options.args.history.set({ "history", "maxMessages" }, 60)
assert(trims == 1, "only history settings apply retention")
options.args.themes.args.themePreset.set(nil, "forest")
assert(addon.Theme:CurrentPreset() == "forest", "preset applies through settings")
assert(
    Chatter.db.global.chatFontSize == 22 and Chatter.db.global.maxMessages == 60,
    "theme leaves non-color preferences intact"
)
options.args.themes.args.colors.args.accentColor.set(nil, 0.9, 0.1, 0.2)
assert(addon.Theme:CurrentPreset() == "custom", "custom color override updates preset label")
addon.Extensions:Start()
assert(Chatter.API.RegisterExtension("pack", {
    name = "Theme pack",
    onEnable = function(ctx)
        ctx.RegisterTheme("violet", { name = "Violet", colors = { accentColor = { 0.7, 0.3, 0.8 } } })
    end,
}))

options = addon.Settings:Options()
registry:ValidateOptionsTable(options, "Chatter")
assert(options.args.extensions.args.extension_pack, "registered extension appears in category")
assert(options.args.extensions.childGroups == "tree", "extension navigation is nested inside Extensions")
for _, panel in ipairs(panels) do
    assert(not panel.child, "no native panel uses the broken multi-segment path")
    assert(panel.name ~= "Notification" and panel.name ~= "Theme pack", "extensions are not native siblings")
end

addon.Settings:Refresh()
addon.Settings:Refresh()
assert(#panels == 1, "late extension registration and refresh add no sibling categories")
local notification = options.args.extensions.args.extension_notification
assert(notification and not notification.inline, "notification gets its own detail page")
assert(notification.args.enabled == nil, "detail page does not duplicate activation toggle")
local parentToggle = options.args.extensions.args.overview.args.enable_notification
assert(parentToggle and parentToggle.name == "Notification" and parentToggle.get(), "parent page controls activation")
parentToggle.set(nil, false)
assert(
    not addon.Extensions:IsEnabled("notification") and notification.args.settings.disabled(),
    "parent toggle disables module and its options"
)
parentToggle.set(nil, true)
assert(addon.Extensions:IsEnabled("notification"), "parent toggle reenables module")
assert(
    notification.order < options.args.extensions.args.extension_pack.order,
    "bundled features appear before integrations"
)
assert(
    notification.args.settings.args.anchor and notification.args.settings.args.preview,
    "notification settings include anchor and preview"
)
assert(notification.args.settings.disabled() == false, "active notification options enabled")
addon.Extensions:SetEnabled("notification", false)
assert(notification.args.settings.disabled() == true, "disabled extension controls unavailable")
assert(options.args.themes.args.themePreset.values().pack_violet == "Violet", "extension preset appears in selector")
print("Real AceConfig schema, categories, retained settings, live controls and extension theme discovery passed.")

-- Reproduce the reported Open() path with the real bundled AceConfigDialog.
-- Widget rendering is outside this test; path resolution must reach FeedGroup.
table.wipe = function(t)
    for key in pairs(t) do
        t[key] = nil
    end

    return t
end

local function mockFrame()
    local frame = {}
    for method in
        ("SetScript Hide Show SetFrameStrata EnableMouse SetPoint SetSize SetFrameLevel SetAllPoints SetFixedFrameStrata SetFixedFrameLevel SetNormalFontObject SetHighlightFontObject SetNormalTexture SetPushedTexture SetHighlightTexture SetText SetTexCoord"):gmatch(
            "%S+"
        )
    do
        frame[method] = function() end
    end

    frame.CreateFontString = mockFrame
    frame.GetNormalTexture = mockFrame
    frame.GetPushedTexture = mockFrame
    frame.GetHighlightTexture = mockFrame
    frame.GetScript = function() end
    return frame
end

CreateFrame = mockFrame
LibStub:NewLibrary("AceGUI-3.0", 1)
assert(loadfile("scripts/libraries/AceConfig-3.0/AceConfigDialog-3.0/AceConfigDialog-3.0.lua"))()
local realDialog = LibStub("AceConfigDialog-3.0")
local fed = 0
realDialog.FeedGroup = function(_, app, opts, container, root, path)
    local group = opts
    for _, key in ipairs(path) do
        group = assert(group.args[key], "registered option path exists")
    end

    assert(group.type == "group")
    if path[1] == "extensions" then
        assert(group.args.overview.args.enable_notification, "parent contains activation controls")
        assert(group.args.extension_notification.args.settings, "nested notification settings available")
        assert(group.args.extension_pack, "late registered extension included")
    end

    fed = fed + 1
end

local container = {
    type = "BlizOptionsGroup",
    ReleaseChildren = function() end,
    SetUserData = function() end,
    SetTitle = function() end,
    Show = function() end,
}

local ok, err = pcall(realDialog.Open, realDialog, "Chatter", container, "extensions", "overview")
assert(not ok and tostring(err):find("option", 1, true), "old nested path reproduces nil-option failure")
for _, panel in ipairs(panels) do
    realDialog:Open(panel.app, container)
end

assert(fed == #panels, "every native settings path opens without nil option")
print("Real AceConfigDialog regression: old path fails, launcher opens without a nested path.")

assert(options.args.extensions.args.overview.inline, "activation controls render on Extensions itself")

realDialog.OpenFrames.Chatter = { frame = {
    IsShown = function()
        return true
    end,
} }

assert(addon.Settings:IsShown(), "standard AceConfig window suppresses idle fade")
realDialog.OpenFrames.Chatter.frame.IsShown = function()
    return false
end

assert(not addon.Settings:IsShown(), "hidden settings is inactive")
realDialog.OpenFrames.Chatter = nil
assert(not addon.Settings:IsShown(), "released or reused AceGUI frames are not Chatter settings")
print("Standard window visibility follows the active AceConfig frame registry.")
