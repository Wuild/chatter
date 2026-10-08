local addon = {}
LibStub = nil
assert(loadfile("scripts/libraries/LibStub/LibStub.lua"))()
assert(loadfile("scripts/libraries/CallbackHandler-1.0/CallbackHandler-1.0.lua"))()
UnitFactionGroup = function()
    return "Alliance"
end

UnitClass = function()
    return "Mage", "MAGE"
end

UnitRace = function()
    return "Human", "Human"
end

GetLocale = function()
    return "enUS"
end

GetRealmName = function()
    return "Realm"
end

UnitNameUnmodified = function()
    return "First"
end

GetCurrentRegionName = function()
    return "EU"
end

GetCurrentRegion = function()
    return 3
end

strlenutf8 = function(value)
    return #value
end

CreateFrame = function()
    return { RegisterEvent = function() end, SetScript = function() end }
end

assert(loadfile("scripts/libraries/AceDB-3.0/AceDB-3.0.lua"))()
assert(loadfile("scripts/database.lua"))("Whispr", addon)
local saved = {
    profileKeys = { ["First - Realm"] = "Custom" },
    profiles = {
        Custom = {
            chatFontSize = 22,
            autoOpenConversations = false,
            extensions = { emoji = false },
            extensionSettings = { notification = { width = 480 } },
        },
    },

    char = { ["First - Realm"] = { conversations = { friend = { messages = { { text = "keep" } } } } } },
}

local defaults = { global = { chatFontSize = 14, autoOpenConversations = true }, char = { conversations = {} } }
local db = LibStub("AceDB-3.0"):New(saved, defaults, true)
addon.Database:MigrateSettings(db)
assert(
    db.global.chatFontSize == 22 and db.global.autoOpenConversations == false,
    "legacy active profile preferences migrate"
)
assert(db.global.extensionSettings.notification.width == 480, "extension preferences migrate")
assert(db.char.conversations.friend.messages[1].text == "keep", "character history untouched")
db.global.extensionSettings.notification.width = 500
assert(saved.profiles.Custom.extensionSettings.notification.width == 480, "migration copies nested settings")
local another = { global = db.global, profile = { chatFontSize = 10 }, char = { conversations = {} } }
addon.Database:MigrateSettings(another)
assert(another.global.chatFontSize == 22, "later character never overwrites shared settings")
another.global.chatFontSize = 18
assert(db.global.chatFontSize == 18, "settings changes shared across characters")
assert(another.char.conversations.friend == nil, "character histories remain separate")
print("Real AceDB global storage, legacy migration, nested copies and character isolation passed.")

local real = { name = "Aeloria", messages = { { text = "Real conversation" } } }
local current = { conversations = { real = real, sample = { demo = true }, ["demo:whispr"] = { undocked = true } } }
local other = { conversations = { ["demo:screenshot:aeloria"] = { demo = true }, real = real } }
addon.Database:RemoveDemoConversations({ char = current, sv = { char = { current = current, other = other } } })
assert(
    current.conversations.real == real and other.conversations.real == real,
    "cleanup preserves real history, including matching names"
)
assert(
    next(current.conversations, "real") == nil and next(other.conversations, "real") == nil,
    "cleanup removes demos across characters"
)
assert(
    current.conversations.sample == nil and current.conversations["demo:whispr"] == nil,
    "legacy and undocked demos removed"
)
print("Saved demo cleanup across characters preserves real history.")

local located = { character = { area = "Westfall", class = "Druid" }, messages = { { text = "keep" } } }
local archived = { character = { area = "Ironforge", guild = "Guild" } }
local locations = {
    char = { conversations = { located = located, unknown = {} } },
    sv = { char = { other = { conversations = { archived = archived } } } },
}

addon.Database:RemoveCharacterLocations(locations)
addon.Database:RemoveCharacterLocations(locations)
assert(located.character.area == nil and archived.character.area == nil, "locations removed across saved characters")
assert(located.character.class == "Druid" and archived.character.guild == "Guild", "identity metadata preserved")
assert(located.messages[1].text == "keep", "location cleanup preserves message history")
print("Obsolete location cleanup is idempotent and covers all characters.")
