local addon, entries = {}, {}
assert(loadfile("tests/support/locale.lua"))(addon)
assert(loadfile("scripts/actions.lua"))("Whispr", addon)
local person = { key = "person", name = "First Last-Realm", character = { guid = "Player-1-2" } }
Whispr = { db = { char = { conversations = { person = person } } } }
local menu = {
    CreateButton = function(_, label, callback)
        local entry = {
            callback = callback,
            SetEnabled = function(self, value)
                self.enabled = value
            end,
        }

        entries[label] = entry
        return entry
    end,
}

local invited, ignored, reported
C_PartyInfo = {
    InviteUnit = function(name)
        invited = name
    end,
}

C_FriendList = {
    AddIgnore = function(name)
        ignored = name
    end,

    AddFriend = function() end,
}

ReportFrame = {
    InitiateReport = function(_, ...)
        reported = { ... }
    end,
}

ReportInfo = {
    CreateReportInfoFromType = function(_, kind)
        return { kind = kind }
    end,
}

Enum = { ReportType = { Chat = 1 } }
UnitPopupSharedUtil = {
    TryCreatePlayerLocation = function(context)
        return { guid = context.guid }
    end,
}

addon.Actions:AddMenu(menu, person)
assert(not invited and not ignored and not reported, "menu construction does not perform actions")
entries["Invite to group"].callback()
assert(invited == person.name, "invite exact full name")
entries["Ignore character"].callback()
assert(ignored == person.name, "ignore exact full name")
entries["Report player…"].callback()
assert(
    reported[2] == person.name
        and reported[3].guid == person.character.guid
        and reported[4] == false
        and reported[5] == nil,
    "report dialog uses identity and never auto-submits"
)
Whispr.db.char.conversations.person = nil
invited = nil
entries["Invite to group"].callback()
assert(not invited, "stale menu cannot invite removed conversation")
local id = 7
local bn = { key = "bnet:test", name = "Test", transport = "bnet" }
Whispr.db.char.conversations[bn.key] = bn
addon.BattleNet = {
    AccountID = function()
        return id
    end,

    Info = function()
        return { gameAccountInfo = { gameAccountID = id + 100, clientProgram = "WoW", isOnline = true } }
    end,
}

BNInviteFriend = function(gameID)
    invited = gameID
end

BNSetBlocked = function(accountID, value)
    ignored = { accountID, value }
end

addon.Actions:AddMenu(menu, bn)
id = 8
entries["Invite to group"].callback()
assert(invited == 108, "BNet invite resolves current game account")
entries["Block Battle.net account"].callback()
assert(ignored[1] == 8 and ignored[2], "BNet block resolves current account")
print("Header invite, ignore, block, native report dialog and stale target checks passed.")
Whispr.db.char.conversations[person.key] = person
UnitPopupSharedUtil.TryCreatePlayerLocation = function()
    return nil
end

ReportInfo.CreateReportInfoFromType = function(_, kind)
    return {
        kind = kind,
        SetReportTarget = function(self, target)
            self.target = target
        end,
    }
end

reported = nil
addon.Actions:Run("report", person)
assert(
    reported and reported[1].target == person.character.guid and reported[3] == nil,
    "Classic report works without PlayerLocation"
)
person.character = nil
reported = nil
addon.Actions:Run("report", person)
assert(reported and reported[1].target == person.name, "name-only conversation opens report dialog")
addon.Actions:RememberChat(person.key, 123)
assert(addon.Actions:Context(person).lineID == 123, "recent incoming line id is passed to native location helper")
local reportFrame = ReportFrame
ReportFrame = nil
C_AddOns = {
    LoadAddOn = function(name)
        assert(name == "Blizzard_ReportFrame")
        ReportFrame = reportFrame
    end,
}

addon.Actions:Run("report", person)
assert(ReportFrame == reportFrame, "report frame loads at click time")
print("Classic nil-location, explicit report targets and on-demand dialog loading passed.")

addon.History = {
    Get = function(key)
        return Whispr.db.char.conversations[key]
    end,
}

local nativeMenu
UnitPopup_OpenMenu = function(which, context)
    nativeMenu = { which = which, context = context }
end

person.character = { guid = "Player-1-2" }
UnitGUID = function(unit)
    return unit == "target" and "Player-someone-else" or nil
end

assert(addon.Actions:OpenPlayerMenu(person.key), "native player menu available")
assert(
    nativeMenu.which == "FRIEND" and nativeMenu.context.name == person.name,
    "name-based menu targets the conversation, not current target"
)
UnitGUID = function(unit)
    return unit == "focus" and person.character.guid or nil
end

addon.Actions:OpenPlayerMenu(person.key)
assert(nativeMenu.which == "PLAYER" and nativeMenu.context.unit == "focus", "matching unit enables full player actions")
addon.Actions:OpenPlayerMenu(bn.key)
assert(
    nativeMenu.which == "BN_FRIEND" and nativeMenu.context.bnetIDAccount == id,
    "Battle.net menu uses fresh account ID"
)
assert(nativeMenu.context.accountInfo == nil, "native menu owns account lookup")
assert(not addon.Actions:OpenPlayerMenu("removed"), "missing conversations cannot open stale menus")
person.demo = true
assert(not addon.Actions:OpenPlayerMenu(person.key), "demo conversations do not open real player actions")
person.demo = nil
UnitPopup_OpenMenu = nil
assert(not addon.Actions:OpenPlayerMenu(person.key), "older clients retain custom action fallback")
print("Native conversation player menus, correct targets, Battle.net and fallback passed.")

local modifiers, registrations, appended, dividers = {}, 0, 0, 0
Menu = {
    ModifyMenu = function(tag, callback)
        modifiers[tag] = callback
        registrations = registrations + 1
    end,
}

menu.CreateDivider = function()
    dividers = dividers + 1
end

UnitPopup_OpenMenu = function(which, context)
    assert(context.chatType == nil and context.chatTarget == nil, "Whispr menu omits native whisper popout context")
    assert(context.name ~= nil, "native whisper and player actions retain their target")
    if which == "BN_FRIEND" then
        assert(context.bnetIDAccount == id, "Battle.net actions retain their account target")
    end

    modifiers["MENU_UNIT_" .. which](nil, menu, context)
end

local function appendEntries(description)
    assert(description == menu, "append to native root menu")
    appended = appended + 1
end

assert(addon.Actions:OpenPlayerMenu(person.key, appendEntries), "extended native menu opens")
assert(appended == 1 and dividers == 1, "native menu gets conversation actions after divider")
assert(addon.Actions:Context(person).chatType == "WHISPER", "reporting keeps character whisper context")
assert(addon.Actions:Context(bn).chatType == "BN_WHISPER", "reporting keeps Battle.net whisper context")
addon.Actions:OpenPlayerMenu(person.key, appendEntries)
assert(appended == 2 and registrations == 1, "register modifier once per menu type")
modifiers.MENU_UNIT_PLAYER(nil, menu, {})
assert(appended == 2 and dividers == 2, "ordinary player menus are unchanged")
addon.Actions:OpenPlayerMenu(bn.key, appendEntries)
assert(appended == 3 and registrations == 2, "Battle.net menus also receive conversation actions")
Menu = nil
assert(not addon.Actions:OpenPlayerMenu(person.key, appendEntries), "missing extension API uses complete fallback")
print("Native menu extensions remain scoped to Whispr and preserve fallback support.")
