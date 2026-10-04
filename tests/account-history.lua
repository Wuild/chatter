local addon = {}
assert(loadfile("scripts/history.lua"))("Whispr", addon)
local first = {
    sequence = 2,
    conversations = {
        friend = {
            key = "friend",
            name = "Friend",
            updated = 2,
            unread = 1,
            messages = {
                { id = 1, time = 20, text = "first character", outgoing = true },
                { id = 2, time = 30, text = "reply", outgoing = false },
            },
        },
    },
}

local second = {
    sequence = 2,
    conversations = {
        friend = {
            key = "friend",
            name = "Friend",
            updated = 2,
            unread = 2,
            messages = {
                { id = 1, time = 10, text = "second character", outgoing = true },
            },
        },

        ["bnet:friend#1"] = {
            key = "bnet:friend#1",
            name = "Battle Friend",
            transport = "bnet",
            battleTag = "Friend#1",
            updated = 2,
            unread = 0,
            messages = { { id = 2, time = 40, text = "battle chat" } },
        },
    },
}

Whispr = {
    db = {
        global = { showAllCharacters = false },
        char = first,
        keys = { char = "First - Realm" },
        sv = { char = { ["First - Realm"] = first, ["Second - Realm"] = second } },
    },
}

local h = addon.History
assert(
    h.Get("friend") == first.conversations.friend and not h.Get("bnet:friend#1"),
    "default view is current character only"
)
Whispr.db.global.showAllCharacters = true
h.Invalidate()
local merged = h.Get("friend")
assert(#merged.messages == 3 and merged.messages[1].text == "second character", "all history combined chronologically")
assert(merged.messages[1].sourceCharacter == "Second - Realm", "outgoing history identifies source character")
assert(merged.messages[1].id ~= merged.messages[2].id, "same per-character sequence IDs do not collide")
assert(merged.unread == 3, "combined unread count")
local stableID = merged.messages[2].id
local localBnet = h.EnsureCurrent("bnet:friend#1")
assert(
    localBnet.transport == "bnet" and localBnet.battleTag == "Friend#1",
    "opening archived Battle.net chat retains routing identity"
)
assert(
    #localBnet.messages == 0 and #second.conversations["bnet:friend#1"].messages == 1,
    "opening foreign history never copies messages"
)
h.MarkRead("friend")
assert(
    first.conversations.friend.unread == 0 and second.conversations.friend.unread == 0,
    "reading combined history marks source records read"
)
h.Add(first, { maxPeople = 10, maxMessages = 20 }, "Friend", "new", true, 50, false)
assert(
    #h.Get("friend").messages == 4 and h.Get("friend").messages[2].id == stableID,
    "new message keeps prior display IDs stable"
)
first.conversations.friend.messages[1].pending = true
assert(h.Get("friend").messages[2].pending, "delivery flags reflect original records")
h.Confirm(first, "friend", "first character")
assert(not h.Get("friend").messages[2].pending, "confirmation updates combined view")
Whispr.db.global.showAllCharacters = false
h.Invalidate()
assert(#h.Get("friend").messages == 3, "switching back restores current-character history")
h.Delete("friend")
assert(second.conversations.friend, "local delete preserves other character")
Whispr.db.global.showAllCharacters = true
h.Invalidate()
h.Delete("friend")
assert(not second.conversations.friend, "combined delete removes all source records")
print("Combined history, stable identities, character labels, Battle.net routing, unread and deletion scope passed.")

-- Opening offline history from another character must retain its card identity.
local saved = {
    key = "chain pants",
    name = "Chain Pants",
    updated = 4,
    unread = 0,
    character = {
        guid = "Player-1-chain",
        race = "Dwarf",
        class = "Shaman",
        classFile = "SHAMAN",
        guild = "Guild",
        level = 60,
        area = "Ironforge",
    },

    messages = { { id = 4, time = 60, text = "Away: AFK" } },
}

second.conversations[saved.key] = saved
h.Invalidate()
assert(h.Get(saved.key).character.race == "Dwarf", "foreign history initially includes identity")
local localChat = h.EnsureCurrent(saved.key)
assert(
    localChat.character.race == "Dwarf" and localChat.character.classFile == "SHAMAN",
    "selection copies saved metadata into routing record"
)
assert(#localChat.messages == 0 and #saved.messages == 1, "metadata copy never duplicates history")
assert(localChat.character ~= saved.character, "characters do not share mutable metadata")
h.MarkRead(saved.key)
assert(h.Get(saved.key).character.class == "Shaman", "read refresh retains class label")
localChat.character = nil
h.Invalidate()
assert(h.Get(saved.key).character.race == "Dwarf", "old empty local record falls back to other character metadata")
h.EnsureCurrent(saved.key)
assert(localChat.character.classFile == "SHAMAN", "existing routing record repaired on selection")
localChat.character = { classFile = "SHAMAN" }
h.Invalidate()
assert(h.Get(saved.key).character.race == "Dwarf", "partial identity filled in projection")
assert(localChat.character.race == nil, "building projection never mutates source records")
h.EnsureCurrent(saved.key)
assert(localChat.character.race == "Dwarf", "selection preserves recovered identity on current character")
assert(localChat.character.guild == nil, "cleared guild not resurrected from older history")
localChat.character.race = "Gnome"
h.Invalidate()
assert(h.Get(saved.key).character.race == "Gnome", "current known identity retains priority")
assert(saved.character.race == "Dwarf", "updates do not mutate other character metadata")
print("Offline account-history identity survives selection, read refresh and existing empty routing records.")
