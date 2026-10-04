local addon = {}
assert(loadfile("tests/support/locale.lua"))(addon)

local function equal(a, b, label)
    assert(a == b, label .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end

securecallfunction = function(callback, ...)
    return callback(...)
end

GetLocale = function()
    return "enUS"
end

C_UIFileAsset = {
    IsKnownFile = function()
        return true
    end,
}

geterrorhandler = function()
    return error
end

assert(loadfile("scripts/libraries/LibStub/LibStub.lua"))()
assert(loadfile("scripts/libraries/CallbackHandler-1.0/CallbackHandler-1.0.lua"))()
assert(loadfile("scripts/libraries/LibSharedMedia-3.0/LibSharedMedia-3.0.lua"))()
local registry = LibStub:NewLibrary("AceConfigRegistry-3.0", 1)
local notifications = 0
registry.NotifyChange = function()
    notifications = notifications + 1
end

GameFontHighlight = {
    GetFont = function()
        return "Fonts/Game.ttf", 14
    end,
}

Chatter = {
    db = {
        global = {
            chatFont = "Game default",
            chatFontSize = 18,
            chatShadow = true,
            chatShadowColor = { 0.1, 0.2, 0.3, 0.8 },
        },
    },
}

local function text()
    return {
        SetFont = function(self, path, size)
            self.path, self.size = path, size
            return path ~= "bad.ttf"
        end,

        SetShadowColor = function(self, ...)
            self.shadow = { ... }
        end,

        SetShadowOffset = function(self, x, y)
            self.x, self.y = x, y
        end,
    }
end

local refreshed = 0

local function window()
    return {
        frame = {},
        input = text(),
        Layout = function() end,
        RefreshMessages = function()
            refreshed = refreshed + 1
        end,
    }
end

addon.Window = window()
addon.Window.popouts = { first = window(), second = window() }
assert(loadfile("scripts/sounds.lua"))("Chatter", addon)
assert(loadfile("scripts/media.lua"))("Chatter", addon)
local media, shared = addon.Media, LibStub("LibSharedMedia-3.0")
media:Initialize()
assert(media:Fonts()["Friz Quadrata TT"], "includes built-in game font")
local label = text()
media:Apply(label)
equal(label.path, "Fonts/Game.ttf", "default follows client font")
equal(label.size, 18, "selected font size")
equal(label.shadow[4], 0.8, "shadow opacity applied")
equal(label.y, -1, "shadow enabled")
Chatter.db.global.chatFont = "Third Party"
shared:Register("font", "Third Party", "Interface/AddOns/Other/font.ttf")
equal(notifications, 1, "late font registration refreshes settings")
equal(refreshed, 3, "late font registration updates main and all popouts")
equal(media:Fonts()["Third Party"], "Third Party", "other addon font listed")
media:Apply(label)
equal(label.path, "Interface/AddOns/Other/font.ttf", "other addon font selected")
Chatter.db.global.chatFont = "Missing Font"
Chatter.db.global.chatShadow = false
media:Apply(label)
equal(label.path, "Fonts/Game.ttf", "missing font safely falls back")
equal(label.x, 0, "shadow disabled")
assert(media:Fonts()["Missing Font"]:find("unavailable"), "missing selection is explained")
shared:Register("font", "Broken Font", "bad.ttf")
Chatter.db.global.chatFont = "Broken Font"
media:Apply(label)
equal(label.path, "Fonts/Game.ttf", "failed font load safely falls back")
media:Apply(label, true)
equal(label.size, 15, "metadata scales with text size")
print("Shared media fonts, live registration, fallback, shadows and window refresh passed.")
