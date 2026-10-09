local addon = {}
assert(loadfile("tests/support/locale.lua"))(addon)
LibStub = function()
    return {
        NewAddon = function()
            return {}
        end,
    }
end

assert(loadfile("scripts/config.lua"))("Whispr", addon)
assert(loadfile("scripts/theme.lua"))("Whispr", addon)
assert(loadfile("tests/support/themes.lua"))(addon)
local defaults = addon.defaults.global
local conversation = { messages = { { text = "keep" } } }
Whispr.db = {
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
local profile = Whispr.db.global
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
assert(Whispr.db.char.conversations.friend == conversation, "history retained")
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

assert(count == 10, "ten built-in themes")
print("All ten themes apply and preserve extension preferences.")

assert(addon.Theme:Apply("classic"))
assert(addon.Theme:GetSkin(), "Classic selects the textured skin")
addon.Theme:ResetAppearance()
assert(not addon.Theme:GetSkin(), "appearance reset restores the flat skin")

local ids, values = addon.Theme:SortedIDs(), addon.Theme:Values()
assert(ids[1] == "default" and values.default == "Default", "Default is first by name")
for index = 3, #ids do
    assert(values[ids[index - 1]]:lower() <= values[ids[index]]:lower(), "remaining themes sort by display name")
end

local released, styled, textureReleased = 0, 0, 0
local skin = {
    StyleWindow = function(_, window)
        window.customArtwork = true
        styled = styled + 1
    end,

    ReleaseWindow = function(_, window)
        window.customArtwork = nil
        released = released + 1
    end,

    PaintTexture = function(_, texture, key)
        if key == "headerColor" then
            texture.artwork = "custom-header"
            return true
        end
    end,

    ReleaseTexture = function(_, texture)
        texture.artwork = nil
        textureReleased = textureReleased + 1
    end,
}

assert(addon.Theme:Register("test-skin", { name = "Test skin", colors = {}, skin = skin }))
assert(not addon.Theme:Register("broken-skin", { name = "Invalid", colors = {}, skin = { StyleWindow = true } }))
local window, texture = {}, { SetColorTexture = function() end }
assert(addon.Theme:Apply("test-skin"))
addon.Theme:StyleWindow(window)
addon.Theme:Paint(texture, "headerColor")
assert(
    styled == 1 and window.customArtwork and texture.artwork == "custom-header",
    "theme modules can replace window and panel artwork"
)
addon.Theme:Options().args.headerColor.set(nil, 0.2, 0.3, 0.4)
assert(addon.Theme:GetSkin() == skin, "custom colors retain module hooks")
assert(addon.Theme:Apply("default"))
addon.Theme:StyleWindow(window)
assert(released == 1 and not window.customArtwork, "switching themes releases previous window skin")
assert(textureReleased > 0 and not texture.artwork, "switching themes removes custom textures")
print("Theme module hooks, validation, cleanup, custom colors and name sorting passed.")
