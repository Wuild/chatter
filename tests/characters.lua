SOUNDKIT = { TELL_MESSAGE = 1 }
PlaySoundFile = function() end
local addon = {}
assert(loadfile("tests/support/locale.lua"))(addon)

local function load(name)
    assert(loadfile("scripts/" .. name .. ".lua"))("Chatter", addon)
end

local function equal(a, b, label)
    assert(a == b, label .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end

HasAnySecretValues = function(...)
    for index = 1, select("#", ...) do
        if select(index, ...) == "SECRET" then
            return true
        end
    end
end

LOCALIZED_CLASS_NAMES_MALE = { MAGE = "Mage", WARRIOR = "Warrior" }
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
GetNormalizedRealmName = function()
    return "HomeRealm"
end

GetPlayerInfoByGUID = function(guid)
    if guid == "Player-1-remote" then
        return "Mage", "MAGE", "Human"
    end
end

load("history")
load("characters")
local Characters = addon.Characters
local person = { name = "First Last" }
Characters.Update(person, "Player-1-remote")
equal(Characters.Label(person), "Human · Mage", "GUID supplies race and class")
equal(Characters.Color(person), RAID_CLASS_COLORS.MAGE, "class color lookup")
Characters.Merge(person, { race = "SECRET", class = "", level = 60 })
equal(Characters.Label(person), "Human · Mage", "partial or restricted updates preserve known details")
equal(person.character.level, 60, "known levels are stored")
Characters.Update(person, "SECRET")
equal(Characters.Label(person), "Human · Mage", "secret GUID is not queried")
equal(Characters.Label({ name = "Unknown" }), "", "unknown details stay blank")
local friend = { name = "Friend Name" }
C_FriendList = {
    GetNumFriends = function()
        return 1
    end,

    GetFriendInfoByIndex = function()
        return { name = "Friend Name-HomeRealm", className = "Warrior" }
    end,
}

Characters.RefreshSources({ conversations = { friend = friend } })
equal(Characters.Label(friend), "Warrior", "local realm friend matching")
equal(friend.character.classFile, "WARRIOR", "localized class resolves token")
local otherRealm = { name = "Friend Name-OtherRealm" }
Characters.Update(otherRealm)
equal(Characters.Label(otherRealm), "", "different realms are not conflated")
UnitExists = function(unit)
    return unit == "target"
end

UnitIsPlayer = function()
    return true
end

UnitFullName = function()
    return "Target Person", "HomeRealm"
end

UnitGUID = function()
    return "Player-1-target"
end

UnitClass = function()
    return "Mage", "MAGE"
end

UnitRace = function()
    return "Gnome"
end

local target = { name = "Target Person" }
Characters.Update(target)
equal(Characters.Label(target), "Gnome · Mage", "target whisper has immediate details")
GetGuildInfo = function()
    return "Test Guild"
end

Characters.Update(target)
equal(target.character.guild, "Test Guild", "unit guild is stored")
GetGuildInfo = function()
    return nil
end

Characters.Update(target)
equal(target.character.guild, nil, "leaving a guild clears cached membership")

local updatedGUID
local actualUpdate = Characters.Update
Characters.Update = function(_, guid)
    updatedGUID = guid
end

addon.Window = {
    IsReading = function()
        return false
    end,

    Refresh = function() end,
    Receive = function() end,
    RefreshCharacters = function() end,
}

Chatter = { db = { char = { conversations = {}, sequence = 0 }, global = { maxPeople = 5, maxMessages = 10 } } }
time = function()
    return 1
end

load("sounds")
load("main")
Chatter:Whisper("CHAT_MSG_WHISPER", "hello", "First Last", "", "", "", "", 0, 0, "", 0, 1, "Player-1-remote")
equal(updatedGUID, "Player-1-remote", "whisper event GUID position")
Chatter:Whisper("CHAT_MSG_WHISPER_INFORM", "reply", "First Last", "", "", "", "", 0, 0, "", 0, 1, "Player-1-self")
equal(updatedGUID, nil, "outgoing sender cannot overwrite remote identity")
Chatter:WhisperStatus("CHAT_MSG_AFK", "AFK", "First Last")
local messages = Chatter.db.char.conversations["first last"].messages
equal(messages[#messages].text, "Away: AFK", "away reply goes into the same conversation")
equal(messages[#messages].status, "Away", "away reply is labeled as automatic")
equal(messages[#messages].outgoing, false, "away reply is incoming")
Chatter:WhisperStatus("CHAT_MSG_DND", "In a dungeon", "First Last")
equal(messages[#messages].text, "Do not disturb: In a dungeon", "DND text preserved")
local count = #messages
Chatter:WhisperStatus("CHAT_MSG_AFK", "SECRET", "First Last")
equal(#messages, count, "restricted status text is ignored")
Characters.Update = actualUpdate
print("Race/class lookup, partial data, realm identity, and whisper GUID checks passed.")
for _, race in ipairs({ "Skyborn", "Skyborne", "High Order Skyborne", "Low Order Skyborne" }) do
    local c = { character = { race = race, class = "Druid" } }
    equal(Characters.Label(c), "Skyborn · Druid", "Skyborn variants share display label")
    equal(c.character.race, race, "original race is retained")
end

UnitLevel = function()
    return 42
end

Characters.Update(target)
equal(target.character.level, 42, "visible unit level without Who")
C_FriendList.GetFriendInfoByIndex = function()
    return { name = "Friend Name-HomeRealm", className = "Warrior", level = 35, area = "Stormwind" }
end

GetGuildInfo = function()
    return "Test Guild"
end

GetNumGuildMembers = function()
    return 1
end

GetGuildRosterInfo = function()
    return "Guild Friend-HomeRealm", nil, nil, 50, "Mage", "Ironforge", nil, nil, nil, nil, "MAGE"
end

local guildFriend = { name = "Guild Friend" }
Characters.RefreshSources({ conversations = { friend = friend, guildFriend = guildFriend } })
equal(friend.character.level, 35, "friend level without Who")
equal(friend.character.area, "Stormwind", "friend location without Who")
equal(guildFriend.character.guild, "Test Guild", "guild roster membership without Who")
equal(guildFriend.character.level, 50, "guild roster level without Who")
equal(guildFriend.character.area, "Ironforge", "guild roster location without Who")
print("Unit, friend and guild metadata works without Who queries.")

addon.Client = { hasLastNames = true }
UnitNameUnmodified = function()
    return "Lamp", "Post"
end

UnitFullName = function()
    return "Lamp", "Post"
end

local lamp = { name = "Lamp Post" }
Characters.Update(lamp)
equal(lamp.character.race, "Gnome", "Forever surname matches saved conversation")
equal(lamp.character.guild, "Test Guild", "Forever unit guild reaches conversation")
equal(Characters.SameName("Lamp-Post", "Lamp Post"), true, "Forever hyphen surname matches")
equal(Characters.SameName("Lamp-Post-HomeRealm", "Lamp Post"), true, "Forever surname and local realm")
addon.Client.hasLastNames = false
equal(Characters.SameName("Lamp-Post", "Lamp Post"), false, "official realm names remain distinct")

-- Offline selections preserve all last-known metadata, including class colors.
UnitExists = function()
    return false
end

local offline = {
    name = "Offline Friend",
    character = {
        guid = "Player-1-offline",
        race = "Human",
        class = "Mage",
        classFile = "MAGE",
        guild = "Old Guild",
        level = 60,
        area = "Stormwind",
    },
}

local guidQueries = 0
UNKNOWN = "Inconnu"
GetPlayerInfoByGUID = function()
    guidQueries = guidQueries + 1
    return "Inconnu", "UNKNOWN", "Unknown"
end

Characters.sources = {}
Characters.online = {}
Characters.Update(offline)
equal(guidQueries, 0, "selecting saved conversation does not query stale GUID")
equal(Characters.Label(offline), "Human · Mage", "offline label retained")
Characters.Merge(offline, { race = "Inconnu", class = "Unknown", classFile = "UNKNOWN", area = "Offline", level = 0 })
equal(Characters.Label(offline), "Human · Mage", "localized placeholders never erase known class/race")
equal(offline.character.area, "Stormwind", "offline placeholder preserves location")
equal(Characters.Color(offline), RAID_CLASS_COLORS.MAGE, "cached class color retained")
C_FriendList.GetFriendInfoByIndex = function()
    return {
        name = "Offline Friend",
        connected = false,
        guid = "Player-1-offline",
        className = "Warrior",
        level = 10,
        area = "Elsewhere",
    }
end

GetGuildRosterInfo = function()
    return "Offline Friend", nil, nil, 10, "Warrior", "Elsewhere", nil, nil, false, nil, "WARRIOR"
end

Characters.RefreshSources({ conversations = { offline = offline } })
equal(offline.character.class, "Mage", "offline roster data not merged")
equal(offline.character.guild, "Old Guild", "offline roster does not change guild")
equal(offline.character.level, 60, "offline roster does not change level")
equal(guidQueries, 0, "offline roster does not trigger GUID refresh")
Characters.Update(offline)
equal(guidQueries, 0, "repeated offline selection remains read-only")
GetPlayerInfoByGUID = function()
    guidQueries = guidQueries + 1
    return "Warrior", "WARRIOR", "Orc"
end

Characters.Update(offline, "Player-1-offline")
equal(offline.character.race, "Orc", "fresh whisper GUID overrides stale offline flag")
equal(offline.character.classFile, "WARRIOR", "fresh data updates class normally")
C_FriendList.GetFriendInfoByIndex = function()
    return {
        name = "Offline Friend",
        connected = true,
        guid = "Player-1-offline",
        className = "Warrior",
        level = 61,
        area = "Orgrimmar",
    }
end

Characters.RefreshSources({ conversations = { offline = offline } })
equal(offline.character.level, 61, "connected friend updates cached metadata")
equal(offline.character.area, "Orgrimmar", "connected location refreshes normally")
UnitExists = function(unit)
    return unit == "target"
end

UnitIsConnected = function()
    return false
end

UnitFullName = function()
    return "Offline Friend", "HomeRealm"
end

Characters.sources = {}
Characters.online = {}
GetGuildInfo = function()
    return nil
end

Characters.Update(offline)
equal(offline.character.guild, "Old Guild", "disconnected unit cannot clear cached guild")
print("Offline metadata retention, placeholder rejection and reconnect updates passed.")
