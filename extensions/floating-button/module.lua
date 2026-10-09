local _, addon = ...
local L = addon.L

addon.Locale:OnReady(function()
    local Button = Whispr:NewExtension("floating_button", {
        name = L["Floating button"],
        version = "1.0.0",
        builtin = true,
        description = L["A draggable Whispr button with an unread message badge. Left-click to open Whispr; right-click for the menu."],
    })

    Button:SetEnabledState(false)
    Button:RegisterDefaults({ size = 40, style = "rounded" })

    local function number(value, fallback)
        value = tonumber(value)
        if not value or value ~= value or math.abs(value) == math.huge then
            return fallback
        end

        return value
    end

    function Button:ApplyStyle()
        if not self.frame then
            return
        end

        local style = self:GetSettings().style
        if style ~= "orb" and style ~= "minimal" then
            style = "rounded"
        end

        self.surface:SetShown(style == "rounded")
        self.orb:SetShown(style == "orb")
        local color = Whispr.db.global[self.hovered and "accentColor" or "windowColor"]
            or (self.hovered and { 0.15, 0.43, 0.58 } or { 0.075, 0.085, 0.095 })
        self.surface:SetColorTexture(color[1], color[2], color[3], 1)
        local tint = self.hovered and 1 or 0.8
        self.orb:SetVertexColor(tint, tint, tint, 1)
        self.icon:SetAlpha(self.hovered and 1 or 0.9)
        local padding = self.frame:GetWidth() * (style == "orb" and 0.18 or style == "minimal" and 0.04 or 0.10)
        self.icon:ClearAllPoints()
        self.icon:SetPoint("TOPLEFT", padding, -padding)
        self.icon:SetPoint("BOTTOMRIGHT", -padding, padding)
    end

    function Button:Position()
        local settings = self:GetSettings()
        local size = math.max(24, math.min(96, number(settings.size, 40)))
        self.frame:SetSize(size, size)
        self.frame:ClearAllPoints()
        local x, y = number(settings.x), number(settings.y)
        if x and y then
            self.frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
        else
            self.frame:SetPoint("RIGHT", Minimap, "LEFT", -12, 0)
        end

        self:ApplyStyle()
        addon.Extensions:Emit("FLOATING_BUTTON_CHANGED")
    end

    function Button:SavePosition()
        self.frame:StopMovingOrSizing()
        local x, y = self.frame:GetCenter()
        local px, py = UIParent:GetCenter()
        local ratio = self.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local settings = self:GetSettings()
        settings.x, settings.y = x * ratio - px, y * ratio - py
        self:Position()
    end

    function Button:UpdateUnread(_, total)
        if total == nil then
            total = 0
            for _, conversation in pairs(addon.History.DisplayData().conversations) do
                total = total + (conversation.unread or 0)
            end
        end

        self.unread = total
        self.badgeCount:SetText(total > 99 and "99+" or tostring(total))
        self.badge:SetWidth(math.max(16, self.badgeCount:GetStringWidth() + 6))
        self.badge:SetShown(total > 0)
    end

    function Button:Create()
        if self.frame then
            return
        end

        local frame = CreateFrame("Button", "WhisprFloatingButton", UIParent)
        self.frame = frame
        frame:SetFrameStrata("MEDIUM")
        frame:SetClampedToScreen(true)
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        self.surface = addon.UI.Round(frame, 8, 0.075, 0.085, 0.095, 1)
        self.orb = frame:CreateTexture(nil, "BACKGROUND")
        self.orb:SetAllPoints()
        self.orb:SetTexture("Interface\\AddOns\\Whispr\\assets\\minimap-background.tga")
        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetTexture("Interface\\AddOns\\Whispr\\assets\\whispr-icon.tga")
        self.icon = icon
        frame:SetScript("OnMouseDown", function()
            self.dragged = false
        end)

        frame:SetScript("OnDragStart", function()
            self.dragged, self.moving = true, true
            GameTooltip:Hide()
            frame:StartMoving()
        end)

        frame:SetScript("OnDragStop", function()
            self:SavePosition()
            self.moving = false
        end)

        frame:SetScript("OnClick", function(owner, mouseButton)
            if not self.dragged then
                addon.Minimap:Click(owner, mouseButton)
            end
        end)

        frame:SetScript("OnEnter", function(owner)
            self.hovered = true
            self:ApplyStyle()
            GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
            GameTooltip:AddLine("Whispr")
            if self.unread > 0 then
                GameTooltip:AddLine(string.format(L["Unread messages: %d"], self.unread), 1, 0.65, 0.4)
            end

            GameTooltip:AddLine(
                Whispr.db.global.separateWindows and L["Left-click: recent conversations"]
                    or L["Left-click: toggle Whispr"],
                1,
                1,
                1
            )
            GameTooltip:AddLine(L["Right-click: menu and recent conversations"], 1, 1, 1)
            GameTooltip:AddLine(L["Drag: move button"], 1, 1, 1)
            GameTooltip:Show()
        end)

        frame:SetScript("OnLeave", function()
            self.hovered = false
            self:ApplyStyle()
            GameTooltip:Hide()
        end)

        self.badge = CreateFrame("Frame", nil, frame)
        self.badge:SetSize(16, 16)
        self.badge:SetPoint("TOPRIGHT", 2, 2)
        self.badge:SetFrameLevel(frame:GetFrameLevel() + 10)
        self.badge:EnableMouse(false)
        addon.UI.Round(self.badge, 7, 0.78, 0.18, 0.13, 1)
        self.badgeCount = addon.UI.Text(self.badge, "", "GameFontHighlightSmall")
        self.badgeCount:SetPoint("CENTER", 0, 0)
        self.badgeCount:SetTextColor(1, 1, 1, 1)
    end

    function Button:OnInitialize()
        local saved = self:GetSettings()
        -- Replace the former default while retaining custom dragged positions.
        if saved.x == 0 and saved.y == -180 then
            saved.x, saved.y = nil, nil
        end

        self:RegisterOptions({
            type = "group",
            name = L["Floating button"],
            args = {
                style = {
                    type = "select",
                    name = L["Button style"],
                    order = 0,
                    values = {
                        rounded = L["Rounded"],
                        orb = L["Orb"],
                        minimal = L["Minimal"],
                    },

                    set = function(_, value)
                        self:GetSettings().style = value
                        self:ApplyStyle()
                    end,
                },

                size = {
                    type = "range",
                    name = L["Button size"],
                    order = 1,
                    min = 24,
                    max = 96,
                    step = 1,
                    set = function(_, value)
                        self:GetSettings().size = value
                        self:Position()
                    end,
                },

                reset = {
                    type = "execute",
                    name = L["Reset position"],
                    order = 2,
                    func = function()
                        local settings = self:GetSettings()
                        settings.x, settings.y = nil, nil
                        self:Position()
                    end,
                },
            },
        })
    end

    function Button:OnEnable()
        self:Create()
        self:Position()
        self:UpdateUnread()
        self:RegisterMessage("UNREAD_CHANGED", "UpdateUnread")
        self:RegisterMessage("THEME_CHANGED", "ApplyStyle")
        self.frame:Show()
    end

    function Button:OnDisable()
        self.hovered = false
        if self.frame then
            if self.moving then
                self:SavePosition()
                self.moving = false
            end

            if GameTooltip:IsOwned(self.frame) then
                GameTooltip:Hide()
            end

            self.frame:Hide()
            addon.Extensions:Emit("FLOATING_BUTTON_CHANGED")
        end
    end
end)
