local _, addon = ...
local Theme = addon.Theme
local L = addon.L

local Skin = { hideGrain = true }

local texturedPanels = {
    headerColor = true,
    footerColor = true,
}

-- Inset templates supply the same recessed corners and edges as Blizzard panels.
local function inset(parent)
    local panel = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
    panel:SetFrameLevel(parent:GetFrameLevel())
    panel:EnableMouse(false)
    panel.Bg:Hide()
    if panel.NineSlice then
        panel.NineSlice:SetFrameLevel(parent:GetFrameLevel())
    end

    return panel
end

function Skin:ApplySurface(surface, key)
    if not surface.native then
        surface.native = CreateFrame("Frame", nil, surface.parent, "BackdropTemplate")
        surface.native:SetFrameLevel(surface.parent:GetFrameLevel())
        surface.native:EnableMouse(false)
        surface.nativeFill = surface.parent:CreateTexture(nil, "BACKGROUND", nil, 1)
        surface.nativeFill:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble", "REPEAT", "REPEAT")
        surface.nativeFill:SetHorizTile(true)
        surface.nativeFill:SetVertTile(true)
    end

    if surface.native then
        if surface.nativeKey ~= key then
            local window = key == "windowColor"
            surface.native:SetBackdrop({
                edgeFile = window and "Interface\\DialogFrame\\UI-DialogBox-Border"
                    or "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true,
                tileSize = 32,
                edgeSize = window and 24 or 12,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            })

            if surface.isButton then
                surface.nativeFill:SetTexture("Interface\\Buttons\\SquareButtonTextures")
                surface.nativeFill:SetHorizTile(false)
                surface.nativeFill:SetVertTile(false)
                surface.nativeFill:SetTexCoord(0.015625, 0.421875, 0.234375, 0.640625)
            end

            if surface.windowChrome or surface.isButton or surface.role == "message" or surface.role == "input" then
                surface.native:SetBackdrop(nil)
            end

            if surface.role == "input" and not surface.inputEdges then
                surface.inputEdges = {}
                for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
                    local edge = surface.native:CreateTexture(nil, "BORDER")
                    if side == "TOP" or side == "BOTTOM" then
                        edge:SetPoint(side .. "LEFT")
                        edge:SetPoint(side .. "RIGHT")
                        edge:SetHeight(1)
                    else
                        edge:SetPoint("TOP" .. side)
                        edge:SetPoint("BOTTOM" .. side)
                        edge:SetWidth(1)
                    end

                    surface.inputEdges[#surface.inputEdges + 1] = edge
                end
            end

            surface.nativeKey = key
        end

        surface.native:SetShown(surface.shown)
        surface.nativeFill:SetShown(surface.shown)
    end
end

function Skin:LayoutSurface(surface, top, left, right)
    if surface.native then
        local outset = surface.nativeKey == "windowColor" and 5 or 0
        surface.nativeFill:ClearAllPoints()
        surface.nativeFill:SetPoint("TOPLEFT", surface.parent, "TOPLEFT", left, -top)
        surface.nativeFill:SetPoint("BOTTOMRIGHT", surface.parent, "BOTTOMRIGHT", -right, 0)
        surface.native:ClearAllPoints()
        surface.native:SetPoint("TOPLEFT", surface.parent, "TOPLEFT", left - outset, -top + outset)
        surface.native:SetPoint("BOTTOMRIGHT", surface.parent, "BOTTOMRIGHT", -right + outset, -outset)
    end
end

function Skin:ColorSurface(surface, red, green, blue, alpha)
    if surface.windowChrome then
        surface.nativeFill:SetDrawLayer("BACKGROUND", -7)
        surface.nativeFill:SetColorTexture(0.035, 0.03, 0.025, 1)
    elseif surface.isButton then
        surface.nativeFill:SetVertexColor(1, 1, 1, alpha or 1)
    elseif surface.role == "input" then
        -- Focus changes the square border, not the field's background brightness.
        local color = Whispr.db.global[surface.nativeKey] or Theme.defaults[surface.nativeKey]
        surface.nativeFill:SetColorTexture(color[1], color[2], color[3], alpha or 1)
        local style = Theme.surfaces[surface]
        local focused = style and style[2]
        for _, edge in ipairs(surface.inputEdges) do
            edge:SetColorTexture(
                focused and 0.44 or 0.25,
                focused and 0.36 or 0.22,
                focused and 0.22 or 0.17,
                alpha or 1
            )
        end
    else
        -- Keep chat and entry fields quiet; texture belongs to the window chrome.
        local opacity = surface.role == "message" and math.max(0.9, alpha or 1) or (alpha or 1)
        surface.nativeFill:SetColorTexture(red, green, blue, opacity)
        if surface.role ~= "message" and surface.role ~= "input" then
            surface.native:SetBackdropBorderColor(0.45, 0.42, 0.36, alpha or 1)
        end
    end
end

function Skin:PaintTexture(surface, key, red, green, blue, alpha)
    if key == "buttonColor" then
        surface:SetColorTexture(0.34, 0.29, 0.21, alpha)
        return true
    end

    if key == "sidebarColor" then
        surface:SetColorTexture(0, 0, 0, 0)
        return true
    end

    if not texturedPanels[key] then
        return false
    end

    surface:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock", "REPEAT", "REPEAT")
    surface:SetHorizTile(true)
    surface:SetVertTile(true)
    surface:SetVertexColor(math.min(1, red * 3), math.min(1, green * 3), math.min(1, blue * 3), alpha)
    return true
end

function Skin:ReleaseTexture(surface)
    surface:SetHorizTile(false)
    surface:SetVertTile(false)
    surface:SetVertexColor(1, 1, 1, 1)
end

function Skin:ShowSurface(surface, shown)
    surface.native:SetShown(shown)
    surface.nativeFill:SetShown(shown)
end

function Skin:ReleaseSurface(surface)
    self:ShowSurface(surface, false)
end

function Skin:ButtonState(surface, state)
    surface.nativeFill:SetTexture("Interface\\Buttons\\SquareButtonTextures")
    if state == "down" then
        surface.nativeFill:SetTexCoord(0.453125, 0.859375, 0.234375, 0.640625)
    else
        surface.nativeFill:SetTexCoord(0.015625, 0.421875, 0.234375, 0.640625)
    end

    local icon = surface.parent.icon
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", state == "down" and -1 or 0, state == "down" and -1 or 0)
    end
end

-- Use Blizzard's complete window artwork instead of approximating it with a tooltip border.
function Skin:StyleWindow(window)
    if not window.themeTitleParts then
        return
    end

    if not window.classicChrome then
        -- Forever ContainerFrameCombinedBags uses this template and HeldBagLayout.
        -- Older Classic clients retain their native portrait frame as a fallback.
        local bagStyle = PortraitFrameFlatBaseMixin ~= nil
        local chrome =
            CreateFrame("Frame", nil, window.frame, bagStyle and "PortraitFrameFlatTemplate" or "PortraitFrameTemplate")
        window.classicChrome = chrome
        chrome:SetPoint("TOPLEFT", window.frame, "TOPLEFT", 9, 0)
        chrome:SetPoint("BOTTOMRIGHT", window.frame, "BOTTOMRIGHT", -2, 1)
        chrome:SetFrameLevel(window.frame:GetFrameLevel() + 30)
        chrome:EnableMouse(false)
        chrome.nativeBagStyle = bagStyle
        if bagStyle then
            chrome:SetBorder("HeldBagLayout")
            chrome:SetPortraitTextureSizeAndOffset(36, -4, 1)
            chrome:SetTitleOffsets(35, -108)
            local red, green, blue = PANEL_BACKGROUND_COLOR:GetRGB()
            chrome:SetBackgroundColor(CreateColor(red, green, blue, 1))
            chrome.Bg:SetFrameLevel(window.frame:GetFrameLevel())
            chrome.Bg:Show()
        else
            chrome.Bg:Hide()
        end

        local portrait = chrome.GetPortrait and chrome:GetPortrait() or chrome.portrait
        portrait:SetTexture("Interface\\AddOns\\Whispr\\assets\\whispr-icon.tga")

        local title = chrome.TitleText or chrome.TitleContainer.TitleText
        title:SetText("Whispr")

        chrome.CloseButton:SetScript("OnClick", function()
            window:Close()
        end)

        local drag = CreateFrame("Frame", nil, chrome)
        drag:SetPoint("TOPLEFT", 60, 0)
        drag:SetPoint("TOPRIGHT", -108, 0)
        drag:SetHeight(22)
        drag:EnableMouse(true)
        drag:RegisterForDrag("LeftButton")
        drag:SetScript("OnDragStart", function()
            window.frame:StartMoving()
        end)

        drag:SetScript("OnDragStop", function()
            window.frame:StopMovingOrSizing()
            window:SaveGeometry()
        end)
    end

    if window.classicChrome then
        window.classicChrome:Show()
    end

    for _, region in ipairs(window.themeTitleParts) do
        region:Hide()
    end

    if not window.classicInsets then
        window.classicInsets = { sidebar = inset(window.sidebar), messages = inset(window.frame) }
        window.classicInsets.sidebar:SetAllPoints(window.sidebar)
        window.classicInsets.messages:SetPoint("TOPLEFT", window.divider, "BOTTOMLEFT", 0, -4)
        window.classicInsets.messages:SetPoint("BOTTOMRIGHT", window.input, "TOPRIGHT", 0, 4)
    end

    local profile = Whispr.db.global
    for name, panel in pairs(window.classicInsets) do
        local key = name == "sidebar" and "sidebarColor" or "windowColor"
        local color = profile[key] or Theme.defaults[key]
        panel.Bg:Show()
        panel.Bg:SetDrawLayer("BACKGROUND", 1)
        panel.Bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock", "REPEAT", "REPEAT")
        panel.Bg:SetHorizTile(true)
        panel.Bg:SetVertTile(true)
        panel.Bg:SetVertexColor(math.min(1, color[1] * 5), math.min(1, color[2] * 5), math.min(1, color[3] * 5), 1)
        if not panel.shade then
            panel.shade = panel:CreateTexture(nil, "BACKGROUND", nil, 2)
            panel.shade:SetPoint("BOTTOMLEFT", 3, 3)
            panel.shade:SetPoint("BOTTOMRIGHT", -3, 3)
            panel.shade:SetTexture("Interface\\Buttons\\WHITE8X8")
            if panel.shade.SetGradient and CreateColor then
                panel.shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.8), CreateColor(0, 0, 0, 0))
            else
                panel.shade:SetGradientAlpha("VERTICAL", 0, 0, 0, 0.8, 0, 0, 0, 0)
            end
        end
    end

    self:LayoutWindow(window)
    window.background.nativeBagStyle = window.classicChrome.nativeBagStyle
    self:ShowSurface(window.background, window.background.shown)

    window.classicInsets.sidebar:Show()
    window.classicInsets.messages:Show()

    window.themeContentTop = 27
    window.themeContentLeft, window.themeContentRight, window.themeContentBottom = 12, 8, 8
    window.background:SetInsets(20, 12, 8)
    window.background.nativeFill:SetPoint("BOTTOMRIGHT", window.frame, "BOTTOMRIGHT", -8, 8)
    window.themePortraitInset = 0
    window.themeSearchInset = 16
    local chrome = window.classicChrome
    -- Native title/border frames have their own levels; controls must sit above them.
    local controlLevel = math.max(
        chrome:GetFrameLevel(),
        chrome.CloseButton:GetFrameLevel(),
        chrome.NineSlice and chrome.NineSlice:GetFrameLevel() or 0,
        chrome.TitleContainer and chrome.TitleContainer:GetFrameLevel() or 0
    ) + 1
    window.settingsButton:SetParent(chrome)
    window.settingsButton:SetFrameLevel(controlLevel)
    window.settingsButton:Show()
    window.settingsButton:SetSize(22, 22)
    window.settingsButton:ClearAllPoints()
    window.settingsButton:SetPoint("RIGHT", chrome.CloseButton, "LEFT", -2, 0)
    window.infoButton:SetParent(chrome)
    window.infoButton:SetFrameLevel(controlLevel)
    window.infoButton:Show()
    window.infoButton:SetSize(22, 22)
    window.infoButton:ClearAllPoints()
    window.infoButton:SetPoint("RIGHT", window.settingsButton, "LEFT", -4, 0)
    window.drawerToggle:SetParent(chrome)
    window.drawerToggle:SetFrameLevel(controlLevel)
    window.drawerToggle:SetSize(22, 22)
    window.drawerToggle:ClearAllPoints()
    local portrait = chrome.GetPortrait and chrome:GetPortrait() or chrome.portrait
    window.drawerToggle:SetPoint("LEFT", portrait, "RIGHT", 8, 2)

    window.themeHidesBorder = true
    window:UpdateBorder()
end

function Skin:LayoutWindow(window)
    for _, panel in pairs(window.classicInsets or {}) do
        if panel.shade then
            panel.shade:SetHeight(math.max(80, window.frame:GetHeight() * 0.3))
        end
    end
end

function Skin:ReleaseWindow(window)
    if window.classicChrome then
        window.classicChrome:Hide()
    end

    for _, region in ipairs(window.themeTitleParts or {}) do
        region:Show()
    end

    for _, panel in pairs(window.classicInsets or {}) do
        panel:Hide()
    end

    window.themeContentTop, window.themePortraitInset, window.themeSearchInset = nil, nil, nil
    window.themeContentLeft, window.themeContentRight, window.themeContentBottom = nil, nil, nil
    window.background:SetInsets(0, 0, 0)
    window.settingsButton:SetParent(window.titlebar)
    window.settingsButton:SetFrameLevel(window.titlebar:GetFrameLevel() + 1)
    window.settingsButton:SetSize(24, 24)
    window.settingsButton:ClearAllPoints()
    window.settingsButton:SetPoint("RIGHT", window.themeTitleParts[6], "LEFT", -6, 0)
    window.infoButton:SetParent(window.titlebar)
    window.infoButton:SetFrameLevel(window.titlebar:GetFrameLevel() + 1)
    window.infoButton:SetSize(24, 24)
    window.infoButton:ClearAllPoints()
    window.infoButton:SetPoint("RIGHT", window.settingsButton, "LEFT", -6, 0)
    window.drawerToggle:SetParent(window.titlebar)
    window.drawerToggle:SetFrameLevel(window.titlebar:GetFrameLevel() + 1)
    window.drawerToggle:SetSize(26, 26)
    window.drawerToggle:ClearAllPoints()
    window.drawerToggle:SetPoint("LEFT", 8, 0)
    window.themeHidesBorder = nil
end

addon.Locale:OnReady(function()
    Theme:Register("classic", {
        name = L["Classic"],
        skin = Skin,
        colors = {
            windowColor = { 0.12, 0.11, 0.10 },
            headerColor = { 0.16, 0.145, 0.12 },
            sidebarColor = { 0.10, 0.09, 0.08 },
            conversationColor = { 0.12, 0.11, 0.09 },
            incomingColor = { 0.17, 0.155, 0.13 },
            outgoingColor = { 0.23, 0.19, 0.13 },
            accentColor = { 0.85, 0.65, 0.22 },
            selectedColor = { 0.20, 0.17, 0.12 },
            focusedBorderColor = { 0.85, 0.70, 0.38 },
            unfocusedBorderColor = { 0.40, 0.36, 0.29 },
            inputColor = { 0.14, 0.13, 0.11 },
            footerColor = { 0.13, 0.12, 0.10 },
            buttonColor = { 0.45, 0.12, 0.10 },
        },
    })
end)
