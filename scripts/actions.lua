local _, addon = ...
local L = addon.L
local Actions = { chatLines = {} }
addon.Actions = Actions

function Actions:RememberChat(key, lineID)
    if HasAnySecretValues and HasAnySecretValues(lineID) then
        return
    end

    if type(lineID) == "number" and lineID > 0 then
        self.chatLines[key] = lineID
    end
end

function Actions:Context(conversation)
    local context = {
        name = conversation.name,
        guid = conversation.character and conversation.character.guid,
        chatType = conversation.transport == "bnet" and "BN_WHISPER" or "WHISPER",
        chatTarget = conversation.name,
        lineID = self.chatLines[conversation.key],
    }

    if conversation.transport == "bnet" then
        context.bnetIDAccount = addon.BattleNet.AccountID(conversation)
        context.accountInfo = context.bnetIDAccount and addon.BattleNet.Info(context.bnetIDAccount)
    end

    return context
end

function Actions:CanInvite(conversation)
    if conversation.transport ~= "bnet" then
        return (C_PartyInfo and C_PartyInfo.InviteUnit or InviteUnit) ~= nil
    end

    local context = self:Context(conversation)
    local game = context.accountInfo and context.accountInfo.gameAccountInfo
    return BNInviteFriend ~= nil
        and game ~= nil
        and game.gameAccountID ~= nil
        and game.clientProgram == "WoW"
        and game.isOnline == true
end

function Actions:Invite(conversation)
    if not self:CanInvite(conversation) then
        return
    end

    if conversation.transport == "bnet" then
        local context = self:Context(conversation)
        BNInviteFriend(context.accountInfo.gameAccountInfo.gameAccountID)
    else
        local invite = C_PartyInfo and C_PartyInfo.InviteUnit or InviteUnit
        invite(conversation.name)
    end
end

function Actions:Entries(conversation)
    local entries = {}
    if not conversation then
        return entries
    end

    local function add(key, label, enabled, action)
        entries[#entries + 1] = {
            key = key,
            label = label,
            enabled = not not enabled,
            run = function()
                if Chatter.db.char.conversations[conversation.key] == conversation then
                    action()
                end
            end,
        }
    end

    add("invite", L["Invite to group"], self:CanInvite(conversation), function()
        self:Invite(conversation)
    end)

    if conversation.transport == "bnet" then
        add("block", L["Block Battle.net account"], BNSetBlocked and addon.BattleNet.AccountID(conversation), function()
            local id = addon.BattleNet.AccountID(conversation)
            if id and BNSetBlocked then
                BNSetBlocked(id, true)
            end
        end)
    else
        local ignored = C_FriendList
            and C_FriendList.IsOnIgnoredList
            and C_FriendList.IsOnIgnoredList(conversation.name)
        local action
        if ignored then
            action = C_FriendList and C_FriendList.DelIgnore or DelIgnore
        else
            action = C_FriendList and C_FriendList.AddIgnore or AddIgnore
        end

        add("block", ignored and L["Unignore character"] or L["Ignore character"], action, function()
            if action then
                action(conversation.name)
            end
        end)

        local addFriend = C_FriendList and C_FriendList.AddFriend or AddFriend
        add("friend", L["Add friend"], addFriend, function()
            if addFriend then
                addFriend(conversation.name)
            end
        end)
    end

    local context = self:Context(conversation)
    local canReport = Enum
        and Enum.ReportType
        and Enum.ReportType.Chat ~= nil
        and ((ReportFrame and ReportFrame.InitiateReport) or (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn)
        and (conversation.transport ~= "bnet" or context.bnetIDAccount)
    add("report", L["Report player…"], canReport, function()
        if not canReport then
            return
        end

        if not ReportFrame or not ReportInfo then
            local load = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
            if load then
                load("Blizzard_ReportFrame")
            end
        end

        if not ReportFrame or not ReportFrame.InitiateReport or not ReportInfo then
            Chatter:Print(L["The client report dialog is unavailable."])
            return
        end

        local fresh = self:Context(conversation)
        local location = UnitPopupSharedUtil
            and UnitPopupSharedUtil.TryCreatePlayerLocation
            and UnitPopupSharedUtil.TryCreatePlayerLocation(fresh)
        if conversation.transport == "bnet" and not location then
            Chatter:Print(
                L["The client could not resolve this Battle.net report target. Try reporting a recent message in Blizzard chat."]
            )
            return
        end

        local info = ReportInfo:CreateReportInfoFromType(Enum.ReportType.Chat)
        if not info then
            Chatter:Print(L["The client could not create a chat report."])
            return
        end

        -- Classic's shared location helper can return nil. Supply an explicit
        -- character target so the native dialog can still identify the report.
        if info.SetReportTarget and conversation.transport ~= "bnet" then
            info:SetReportTarget(fresh.guid or conversation.name)
        end

        -- Always open the native dialog: no report is submitted by this action.
        ReportFrame:InitiateReport(info, conversation.name, location, fresh.bnetIDAccount ~= nil)
    end)

    return entries
end

function Actions:AddMenu(menu, conversation)
    for _, entry in ipairs(self:Entries(conversation)) do
        menu:CreateButton(entry.label, entry.run):SetEnabled(entry.enabled)
    end
end

function Actions:Run(key, conversation)
    -- Resolve again at click time, including live Battle.net account IDs and
    -- ignore state, rather than keeping an old header/menu target.
    for _, entry in ipairs(self:Entries(conversation)) do
        if entry.key == key and entry.enabled then
            entry.run()
            return
        end
    end
end
