local addon = {}
assert(loadfile("tests/support/locale.lua"))(addon)
LibStub = function()
    return {
        NewAddon = function()
            return {}
        end,
    }
end

assert(loadfile("scripts/config.lua"))("Chatter", addon)
assert(loadfile("scripts/theme.lua"))("Chatter", addon)
local defaults = addon.defaults.global
local conversation = { messages = { { text = "keep" } } }
Chatter.db = {
    global = {
        maxMessages = 350,
        notificationSound = "linux-bell",
        typingIndicators = false,
        separateWindows = true,
        focusedBorderColor = { 1, 0, 0 },
        windowColor = { 1, 1, 1 },
        conversationColor = { 0.8, 0.8, 0.8 },
        chatFont = "custom",
        chatFontSize = 28,
        chatShadow = true,
        backgroundOpacity = 0.2,
        showMessagePreviews = false,
    },

    char = { conversations = { friend = conversation } },
}

local refreshed, lists = 0, 0
addon.Media = {
    Refresh = function()
        refreshed = refreshed + 1
    end,
}

addon.Window = {
    RefreshList = function()
        lists = lists + 1
    end,

    popouts = { {
        RefreshList = function()
            lists = lists + 1
        end,
    } },
}

local button = addon.Theme:Options().args.resetAppearance
assert(button.type == "execute", "settings exposes reset button")
button.func()
local profile = Chatter.db.global
assert(
    not profile.windowColor and not profile.focusedBorderColor and not profile.conversationColor,
    "all theme overrides removed"
)
assert(profile.chatFont == defaults.chatFont and profile.chatFontSize == defaults.chatFontSize, "fonts reset")
assert(profile.backgroundOpacity == 1 and profile.showMessagePreviews == true, "opacity and card previews reset")
assert(profile.chatShadowColor ~= defaults.chatShadowColor, "mutable default colors copied")
assert(
    profile.maxMessages == 350
        and profile.notificationSound == "linux-bell"
        and profile.typingIndicators == false
        and profile.separateWindows == true,
    "behavior preferences retained"
)
assert(Chatter.db.char.conversations.friend == conversation, "history retained")
assert(refreshed == 1 and lists == 2, "main and popout appearance refresh immediately")
print("Appearance reset restores visual defaults and preserves behavior and history.")
profile.smileys = false
profile.extensions = { emoji = false }
addon.Theme:ResetAppearance()
assert(
    profile.smileys == false and profile.extensions.emoji == false,
    "appearance reset preserves emoji extension state"
)
local count = 0
for id, preset in pairs(addon.Theme.presets) do
    count = count + 1
    assert(addon.Theme:Apply(id))
    assert(addon.Theme:CurrentPreset() == id, "preset round trip: " .. id)
    for key in pairs(addon.Theme.defaults) do
        local color = profile[key]
        for i = 1, 3 do
            assert(color[i] >= 0 and color[i] <= 1, "valid palette color")
        end
    end
end

assert(count == 9, "nine built-in palettes")
print("All nine palettes apply and preserve extension preferences.")
