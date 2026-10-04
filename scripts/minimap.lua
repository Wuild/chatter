local _, addon = ...
local L = addon.L
local Icon = {}
addon.Minimap = Icon

function Icon:UpdateUnread(total)
    if total == nil then
        total = 0
        for _, conversation in pairs(addon.History.DisplayData().conversations) do
            total = total + (conversation.unread or 0)
        end
    end

    self.unread = total
    if not self.badge then
        return
    end

    self.badgeCount:SetText(total > 99 and "99+" or tostring(total))
    self.badge:SetWidth(math.max(16, self.badgeCount:GetStringWidth() + 6))
    self.badge:SetShown(total > 0)
end

function Icon:Click(button, mouseButton)
    if mouseButton == "RightButton" then
        self:Menu(button)
    elseif mouseButton == "LeftButton" then
        if Whispr.db.global.separateWindows then
            self:Menu(button, true)
            return
        end

        local window = addon.Window
        if window.frame and window.frame:IsShown() and not window.closing then
            window:Close()
        else
            window:Open()
        end
    end
end

function Icon:Menu(button, recentOnly)
    MenuUtil.CreateContextMenu(button, function(_, menu)
        if not recentOnly then
            if not Whispr.db.global.separateWindows then
                menu:CreateButton(L["Open Whispr"], function()
                    addon.Window:Open()
                end)
            end

            menu:CreateButton(L["Settings"], function()
                Whispr:ShowSettings()
            end)

            menu:CreateDivider()
        end

        local conversations = addon.History.Sorted(addon.History.DisplayData())
        for index = 1, math.min(10, #conversations) do
            local conversation = conversations[index]
            local key = conversation.key
            local label = conversation.name
            if (conversation.unread or 0) > 0 then
                label = label .. " (" .. conversation.unread .. ")"
            end

            menu:CreateButton(label, function()
                -- The menu may outlive an evicted or deleted conversation.
                if addon.History.Get(key) then
                    addon.Window:Open(key)
                end
            end)
        end

        if #conversations == 0 then
            menu:CreateButton(L["No recent conversations"], function() end):SetEnabled(false)
        end
    end)
end

function Icon:Enable()
    local broker = LibStub("LibDataBroker-1.1")
    local dbIcon = LibStub("LibDBIcon-1.0")
    local profile = Whispr.db.global
    profile.minimap = profile.minimap or { hide = false, minimapPos = 225 }
    if profile.minimapAngle then
        profile.minimap.minimapPos = profile.minimapAngle
        profile.minimapAngle = nil
    end

    self.dataObject = self.dataObject
        or broker:NewDataObject("Whispr", {
            type = "launcher",
            label = "Whispr",
            icon = "Interface\\AddOns\\Whispr\\assets\\whispr-icon.tga",
            OnClick = function(button, mouseButton)
                self:Click(button, mouseButton)
            end,

            OnTooltipShow = function(tooltip)
                tooltip:AddLine("Whispr")
                if (self.unread or 0) > 0 then
                    tooltip:AddLine(string.format(L["Unread messages: %d"], self.unread), 1, 0.65, 0.4)
                end

                tooltip:AddLine(
                    Whispr.db.global.separateWindows and L["Left-click: recent conversations"]
                        or L["Left-click: toggle Whispr"],
                    1,
                    1,
                    1
                )
                tooltip:AddLine(L["Right-click: menu and recent conversations"], 1, 1, 1)
                tooltip:AddLine(L["Drag: move button"], 1, 1, 1)
            end,
        })

    if not dbIcon:IsRegistered("Whispr") then
        dbIcon:Register("Whispr", self.dataObject, profile.minimap)
    else
        dbIcon:Refresh("Whispr", profile.minimap)
    end

    self.button = dbIcon:GetMinimapButton("Whispr")
    -- Bundle the backing instead of relying on a retail texture file ID that
    -- may not resolve in Forever. LibDBIcon still positions it inside its ring.
    if self.button and self.button.background then
        self.button.background:SetTexture("Interface\\AddOns\\Whispr\\assets\\minimap-background.tga")
        self.button.background:Show()
    end

    if self.button and not self.badge then
        self.badge = CreateFrame("Frame", nil, self.button)
        self.badge:SetSize(16, 16)
        self.badge:SetPoint("TOPRIGHT", 2, 2)
        self.badge:SetFrameLevel(self.button:GetFrameLevel() + 10)
        self.badge:EnableMouse(false)
        -- Stay legible even when chat backgrounds are transparent or faded.
        addon.UI.Round(self.badge, 7, 0.78, 0.18, 0.13, 1)
        self.badgeCount = addon.UI.Text(self.badge, "", "GameFontHighlightSmall")
        self.badgeCount:SetPoint("CENTER", 0, 0)
        self.badgeCount:SetTextColor(1, 1, 1, 1)
    end

    self:UpdateUnread()
    if profile.minimap.hide then
        dbIcon:Hide("Whispr")
    else
        dbIcon:Show("Whispr")
    end
end

function Icon:Disable()
    LibStub("LibDBIcon-1.0"):Hide("Whispr")
end
