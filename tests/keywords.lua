local addon = {}
assert(loadfile("tests/support/locale.lua"))(addon)

local function load(name)
    assert(loadfile("scripts/" .. name .. ".lua"))("Chatter", addon)
end

local now, combat, inGroup, leader, full = 0, false, false, false, false
GetTime = function()
    return now
end

InCombatLockdown = function()
    return combat
end

IsInGroup = function()
    return inGroup
end

UnitIsGroupLeader = function()
    return leader
end

GetNumGroupMembers = function()
    return full and 5 or 2
end

GetNormalizedRealmName = function()
    return "Home"
end

Chatter = { db = { global = { extensions = {}, inviteLinks = false } } }
local chats = {
    alice = { key = "alice", name = "Alice-Home" },
    stranger = { key = "stranger", name = "Alice-Away" },
    guildmate = { key = "guildmate", name = "Guildmate" },
    bnet = { key = "bnet", name = "Battle Friend", transport = "bnet" },
    demo = { key = "demo", name = "Demo", demo = true },
}

addon.History = {
    Key = function(name)
        return name:lower()
    end,

    Get = function(key)
        return chats[key]
    end,
}

load("characters")
load("format")
load("extensions")
local invited, added = {}, {}
addon.Actions = {
    CanInvite = function()
        return true
    end,

    Invite = function(_, chat)
        invited[#invited + 1] = chat.name
    end,
}

C_FriendList = {
    GetNumFriends = function()
        return 1
    end,

    GetFriendInfoByIndex = function()
        return { name = "Alice" }
    end,

    AddFriend = function(name)
        added[#added + 1] = name
    end,
}

GetNumGuildMembers = function()
    return 1
end

GetGuildRosterInfo = function()
    return "Guildmate-Home"
end

assert(loadfile("extensions/keywords/module.lua"))("Chatter", addon)
addon.Extensions:Start()
local k = addon.KeywordActions
assert(not k:IsEnabled() and Chatter.db.global.inviteLinks == nil, "legacy disabled preference migrated")
addon.Extensions:SetEnabled("keywords", true)
local rendered = addon.Format.Message("INV! invite, (invites) inventory invitation [inv]", true, 14, "alice")
local _, count = rendered:gsub("|Hchatterkeyword:", "")
assert(
    count == 4 and rendered:find("|cffffff00", 1, true) and rendered:find("|h[INV]|h", 1, true),
    "yellow bracketed whole-word actions"
)
assert(not rendered:find("[[inv]]", 1, true), "existing brackets not doubled")
assert(addon.Format.Message("inv", true) == "inv", "outgoing messages not parsed")
for _, text in ipairs({ "https://site/invite", "www.invite.com", "|Hitem:1|h[invite]|h", "|Tinv:12|t" }) do
    assert(
        addon.Format.Message(text, true, 14, "alice"):find("chatterkeyword", 1, true) == nil,
        "protected spans do not become keyword actions"
    )
end

local link = addon.Format.Message("inv", true, 14, "alice"):match("|H(.-)|h")
k:Click({}, link, "RightButton", "alice")
k:Click({}, link, "LeftButton", "stranger")
assert(#invited == 0, "right-click and mismatched sender rejected")
k:Click({}, link, "LeftButton", "alice")
assert(#invited == 1 and invited[1] == "Alice-Home", "manual click invites sender")
local settings = k:GetSettings()
assert(not settings.autoInvite, "automatic invites off by default")

local function receive(key, text, extra)
    local message = extra or {}
    message.text = text
    addon.Extensions:Emit(
        "MESSAGE_RECEIVED",
        { key = key, transport = chats[key].transport or "whisper", message = message }
    )
end

receive("alice", "inv")
assert(#invited == 1, "default never auto-invites")
settings.autoInvite = true
receive("stranger", "inv")
assert(#invited == 1, "same-name foreign realm is not trusted")
receive("alice", "|Hitem:1|h[inv]|h https://site/inv " .. "|H" .. link .. "|h[inv]|h")
assert(#invited == 1, "no auto-invites from URLs, native labels or forged keyword links")
receive("alice", "inv", { outgoing = true })
receive("alice", "inv", { status = true })
receive("bnet", "inv")
receive("demo", "inv")
assert(#invited == 1, "outgoing, auto-replies, Battle.net and demo excluded")
settings.friends = false
settings.guild = false
receive("alice", "inv")
assert(#invited == 1, "empty allowlist invites nobody")
settings.friends = true
combat = true
receive("alice", "inv")
combat = false
assert(#invited == 1, "combat skips auto-invite")
inGroup = true
leader = false
receive("alice", "inv")
leader = true
full = true
receive("alice", "inv")
inGroup = false
full = false
assert(#invited == 1, "insufficient group permissions and full groups skipped")
receive("alice", "Please INV!")
assert(#invited == 2, "known friend matching keyword auto-invited")
receive("alice", "inv invite")
assert(#invited == 2, "repeat sender cooldown")
settings.guild = true
receive("guildmate", "inv")
assert(#invited == 2, "global rate limit")
now = 3
receive("guildmate", "invite")
assert(#invited == 3, "live guild roster allows invite")
now = 31
receive("alice", "inv")
assert(#invited == 4, "sender cooldown expires")
assert(k:Validate("hello-world") ~= true and k:Validate("INV") ~= true, "invalid and duplicate words rejected")
local options = k.options.args
options.add.args.words.set(nil, "buddy, pal")
options.add.args.action.set(nil, "friend")
options.add.args.add.func()
local friendLink = addon.Format.Message("PAL", true, 14, "alice"):match("|H(.-)|h")
k:Click({}, friendLink, "LeftButton", "alice")
assert(added[1] == "Alice-Home", "custom add-friend rule")
now = 62
receive("alice", "buddy")
assert(#invited == 4, "auto-invite ignores non-invite actions")
k.options.args.rule2.args.action.set(nil, "copy")
local copied
k:Click({
    ShowCopyText = function(_, text)
        copied = text
    end,
}, friendLink, "LeftButton", "alice")
assert(copied == "pal", "changed rule action used at click time")
k.options.args.rule2.args.remove.func()
k:Click({}, friendLink, "LeftButton", "alice")
assert(#added == 1, "removed rule cannot act through stale link")
addon.Extensions:SetEnabled("keywords", false)
assert(addon.Format.Message("inv", true, 14, "alice") == "inv", "disable removes parsing filter")
k:Click({}, link, "LeftButton", "alice")
assert(#invited == 4, "disabled old links inert")
addon.Extensions:SetEnabled("keywords", true)
for i = #settings.rules, 1, -1 do
    k.options.args["rule" .. i].args.remove.func()
end

addon.Extensions:SetEnabled("keywords", false)
addon.Extensions:SetEnabled("keywords", true)
assert(#settings.rules == 0, "empty rules are not reseeded on re-enable")
print("Keyword rendering/rules/actions, migration, guarded auto-invite, trust and throttling passed.")
