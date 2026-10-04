local addon, entries = {}, {}
assert(loadfile("tests/support/locale.lua"))(addon)
assert(loadfile("scripts/actions.lua"))("Chatter", addon)
local person = { key = "person", name = "First Last-Realm", character = { guid = "Player-1-2" } }
Chatter = { db = { char = { conversations = { person = person } } } }
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
Chatter.db.char.conversations.person = nil
invited = nil
entries["Invite to group"].callback()
assert(not invited, "stale menu cannot invite removed conversation")
local id = 7
local bn = { key = "bnet:test", name = "Test", transport = "bnet" }
Chatter.db.char.conversations[bn.key] = bn
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
Chatter.db.char.conversations[person.key] = person
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
