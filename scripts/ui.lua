local _, addon = ...
local UI = {}
addon.UI = UI
UI.colors = {
    text = { 0.91, 0.93, 0.94 },
    muted = { 0.53, 0.59, 0.62 },
    accent = { 0.15, 0.43, 0.58 },
    panel = { 0.075, 0.085, 0.095 },
}

function UI.Text(parent, text, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    label:SetText(text or "")
    label:SetJustifyH("LEFT")
    label:SetTextColor(unpack(UI.colors.text))
    label:SetShadowOffset(0, 0)
    return label
end

function UI.Background(parent, r, g, b, a)
    local texture = parent:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints()
    texture:SetColorTexture(r, g, b, a or 1)
    return texture
end

-- A faint, tiled grain stays at the same scale when a panel is resized.
function UI.Grain(parent)
    local texture = parent:CreateTexture(nil, "BACKGROUND", nil, 2)
    texture:SetAllPoints()
    texture:SetTexture("Interface\\AddOns\\Whispr\\assets\\panel-grain.tga", "REPEAT", "REPEAT")

    local function resize()
        texture:SetTexCoord(0, math.max(1, parent:GetWidth()) / 64, 0, math.max(1, parent:GetHeight()) / 64)
    end

    parent:HookScript("OnSizeChanged", resize)
    resize()
    texture:SetAlpha(Whispr.db.global.backgroundOpacity or 1)
    if addon.Theme then
        addon.Theme.grains[texture] = true
    end

    return texture
end

-- Seven texture regions keep the corner radius fixed at every panel size.
-- The bundled corner is a tiny antialiased quarter-circle, not stretched art.
function UI.Round(parent, radius, r, g, b, a)
    local parts = {}

    local function part()
        local texture = parent:CreateTexture(nil, "BACKGROUND", nil, 1)
        parts[#parts + 1] = texture
        return texture
    end

    for _, point in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        local corner = part()
        corner:SetTexture("Interface\\AddOns\\Whispr\\assets\\corner.tga")
        corner:SetSize(radius, radius)
        corner:SetPoint(point)
        local right, bottom = point:find("RIGHT"), point:find("BOTTOM")
        corner:SetTexCoord(right and 1 or 0, right and 0 or 1, bottom and 1 or 0, bottom and 0 or 1)
    end

    local center = part()
    center:SetPoint("TOPLEFT", radius, 0)
    center:SetPoint("BOTTOMRIGHT", -radius, 0)
    for _, side in ipairs({ "LEFT", "RIGHT" }) do
        local strip = part()
        strip:SetWidth(radius)
        strip:SetPoint("TOP" .. side, 0, -radius)
        strip:SetPoint("BOTTOM" .. side, 0, radius)
    end

    local shape = {}

    function shape:SetInsets(top, left, right)
        parts[1]:SetPoint("TOPLEFT", left, -top)
        parts[2]:SetPoint("TOPRIGHT", -right, -top)
        parts[3]:SetPoint("BOTTOMLEFT", left, 0)
        parts[4]:SetPoint("BOTTOMRIGHT", -right, 0)
        center:SetPoint("TOPLEFT", left + radius, -top)
        center:SetPoint("BOTTOMRIGHT", -right - radius, 0)
        parts[6]:SetPoint("TOPLEFT", left, -radius - top)
        parts[6]:SetPoint("BOTTOMLEFT", left, radius)
        parts[7]:SetPoint("TOPRIGHT", -right, -radius - top)
        parts[7]:SetPoint("BOTTOMRIGHT", -right, radius)
    end

    function shape:SetColorTexture(red, green, blue, alpha)
        for index, texture in ipairs(parts) do
            if index <= 4 then
                texture:SetVertexColor(red, green, blue, alpha or 1)
            else
                texture:SetColorTexture(red, green, blue, alpha or 1)
            end
        end
    end

    function shape:SetShown(shown)
        for _, texture in ipairs(parts) do
            texture:SetShown(shown)
        end
    end

    function shape:Hide()
        self:SetShown(false)
    end

    shape:SetColorTexture(r, g, b, a)
    return shape
end

-- Modal surfaces stay readable even when normal window backgrounds are translucent.
function UI.ModalSurface(box)
    if box.SetIgnoreParentAlpha then
        box:SetIgnoreParentAlpha(true)
    end

    local surface = UI.Round(box, 6, 0.14, 0.16, 0.18)
    if addon.Theme then
        addon.Theme:Paint(surface, "headerColor", false, true)
    end

    local accent = box:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", 8, 0)
    accent:SetPoint("TOPRIGHT", -8, 0)
    accent:SetHeight(2)
    if addon.Theme then
        addon.Theme:Paint(accent, "accentColor", false, true)
    else
        accent:SetColorTexture(unpack(UI.colors.accent))
    end

    return surface
end

function UI.Button(parent, text, width, action, accent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 32)
    local color = accent and UI.colors.accent or { 0.20, 0.24, 0.27 }
    local themeKey = accent and "accentColor" or "buttonColor"
    button.surface = UI.Round(button, 4, unpack(color))
    if addon.Theme then
        addon.Theme:Paint(button.surface, themeKey)
    end

    local label = UI.Text(button, text, "GameFontHighlightSmall")
    label:SetPoint("CENTER")
    button.label = label
    button:SetFontString(label)
    button:SetText(text)
    button:SetScript("OnClick", action)
    button:SetScript("OnEnter", function()
        if addon.Theme then
            addon.Theme:Paint(button.surface, themeKey, true)
        else
            button.surface:SetColorTexture(color[1] + 0.07, color[2] + 0.07, color[3], 1)
        end
    end)

    button:SetScript("OnLeave", function()
        if addon.Theme then
            addon.Theme:Paint(button.surface, themeKey)
        else
            button.surface:SetColorTexture(unpack(color))
        end
    end)

    button:SetScript("OnEnable", function()
        button:SetAlpha(1)
    end)

    button:SetScript("OnDisable", function()
        button:SetAlpha(0.35)
    end)

    return button
end

function UI.Input(parent, width, flat, colorKey)
    local themeKey = colorKey or "inputColor"
    local input = CreateFrame("EditBox", nil, parent)
    input:SetSize(width, 40)
    input:SetFontObject(GameFontHighlight)
    input:SetTextInsets(14, 14, 0, 0)
    if flat then
        input.surface = UI.Background(input, 0.13, 0.16, 0.18)
    else
        input.surface = UI.Round(input, 4, 0.13, 0.16, 0.18)
    end

    if addon.Theme then
        addon.Theme:Paint(input.surface, themeKey)
    end

    input:SetAutoFocus(false)
    input:SetScript("OnEditFocusGained", function()
        if addon.Theme then
            addon.Theme:Paint(input.surface, themeKey, true)
        else
            input.surface:SetColorTexture(0.17, 0.22, 0.25)
        end
    end)

    input:SetScript("OnEditFocusLost", function()
        if addon.Theme then
            addon.Theme:Paint(input.surface, themeKey)
        else
            input.surface:SetColorTexture(0.13, 0.16, 0.18)
        end
    end)

    input:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    return input
end

function UI.IconButton(parent, icon, tooltip, size, action, accent)
    local button = UI.Button(parent, "", size, action, accent)
    button:SetHeight(size)
    local glyph = button:CreateTexture(nil, "OVERLAY")
    button.icon = glyph
    glyph:SetSize(math.min(18, size - 4), math.min(18, size - 4))
    glyph:SetPoint("CENTER")
    glyph:SetVertexColor(0.90, 0.94, 0.96, 1)
    -- A single antialiased texture avoids the gaps and uneven joins produced by
    -- separate one-pixel Line regions, especially with fractional UI scaling.
    if glyph.SetSnapToPixelGrid then
        glyph:SetSnapToPixelGrid(false)
    end

    if glyph.SetTexelSnappingBias then
        glyph:SetTexelSnappingBias(0)
    end

    function button:SetIcon(name, hint)
        self.tooltip = hint
        self.icon:SetTexture("Interface\\AddOns\\Whispr\\assets\\icons\\" .. name .. ".tga")
    end

    button:SetIcon(icon, tooltip)
    button:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltip)
        GameTooltip:Show()
    end)

    button:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:HookScript("OnHide", function()
        if GameTooltip:IsOwned(button) then
            GameTooltip:Hide()
        end
    end)

    return button
end

function UI.EmoteButton(parent, asset, tooltip, size, action)
    local button = UI.Button(parent, "", size, action)
    button:SetHeight(size)
    local texture = button:CreateTexture(nil, "ARTWORK")
    texture:SetSize(size - 8, size - 8)
    texture:SetPoint("CENTER")
    texture:SetTexture("Interface\\AddOns\\Whispr\\assets\\emotes\\" .. asset .. ".tga")
    texture:SetTexCoord(4 / 32, 28 / 32, 4 / 32, 28 / 32)
    button:HookScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_TOP")
        GameTooltip:SetText(tooltip)
        GameTooltip:Show()
    end)

    button:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:HookScript("OnHide", function()
        if GameTooltip:IsOwned(button) then
            GameTooltip:Hide()
        end
    end)

    return button
end

local classAssets = {
    WARRIOR = "warrior",
    MAGE = "mage",
    ROGUE = "rogue",
    DRUID = "druid",
    HUNTER = "hunter",
    SHAMAN = "shaman",
    PRIEST = "priest",
    WARLOCK = "warlock",
    PALADIN = "paladin",
    DEATHKNIGHT = "deathknight",
    MONK = "monk",
    DEMONHUNTER = "demonhunter",
}

function UI.SetClassIcon(texture, classFile)
    if classAssets[classFile] then
        texture:SetTexture("Interface\\AddOns\\Whispr\\assets\\classes\\" .. classAssets[classFile] .. ".tga")
        texture:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        return true
    end

    local coords = classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
    if not coords then
        return false
    end

    -- Crop within the class's atlas tile, never into a neighbouring class.
    local xInset = (coords[2] - coords[1]) * 0.08
    local yInset = (coords[4] - coords[3]) * 0.08
    texture:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
    texture:SetTexCoord(coords[1] + xInset, coords[2] - xInset, coords[3] + yInset, coords[4] - yInset)
    return true
end

function UI.Avatar(parent, size)
    local avatar = CreateFrame("Frame", nil, parent)
    avatar:SetSize(size, size)
    avatar.surface = UI.Round(avatar, 3, 0.25, 0.29, 0.48)
    avatar.icon = avatar:CreateTexture(nil, "ARTWORK")
    avatar.icon:SetPoint("TOPLEFT", 1, -1)
    avatar.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    avatar.icon:Hide()
    avatar.label = UI.Text(avatar, "", "GameFontHighlight")
    avatar.label:SetPoint("CENTER")

    function avatar:SetName(name)
        local hash = 0
        for index = 1, #name do
            hash = (hash + name:byte(index)) % 5
        end

        local colors = {
            { 0.29, 0.26, 0.48 },
            { 0.18, 0.36, 0.39 },
            { 0.37, 0.26, 0.34 },
            { 0.25, 0.32, 0.48 },
            {
                0.37,
                0.31,
                0.23,
            },
        }

        self.surface:SetColorTexture(unpack(colors[hash + 1]))
        -- Match a complete UTF-8 character so non-Latin names remain valid.
        local initial = name:match("^[%z\1-\127\194-\244][\128-\191]*") or "?"
        self.label:SetText(string.upper(initial))
    end

    function avatar:SetCharacter(conversation)
        self.surface:SetShown(true)
        local color = addon.Characters.Color(conversation)
        self.surface:SetColorTexture(
            color and color.r * 0.6 or 0.22,
            color and color.g * 0.6 or 0.25,
            color and color.b * 0.6 or 0.34
        )
        self.label:Hide()
        self.icon:Show()
        if conversation and conversation.transport == "bnet" then
            self.icon:SetTexture("Interface\\FriendsFrame\\Battlenet-Battleneticon")
            self.icon:SetTexCoord(0.125, 0.875, 0.125, 0.875)
            return
        end

        local info = conversation and conversation.character
        if UI.SetClassIcon(self.icon, info and info.classFile) then
            self.surface:Hide()
        else
            self.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            self.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
    end

    return avatar
end

function UI.Scroll(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    scroll:SetClipsChildren(true)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll.content = content
    -- Keep the external thumb outside the clipped message viewport.
    local bar = CreateFrame("Slider", nil, parent)
    bar:SetWidth(4)
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 3, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 3, 0)
    bar:SetOrientation("VERTICAL")
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    bar:SetValue(0)
    local thumb = bar:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(0.43, 0.49, 0.52, 0.7)
    thumb:SetSize(4, 40)
    bar:SetThumbTexture(thumb)
    scroll.ScrollBar = bar
    local syncing = false

    local function update()
        local range = math.max(0, scroll:GetVerticalScrollRange())
        local height = math.max(1, scroll:GetHeight())
        syncing = true
        bar:SetMinMaxValues(0, range)
        thumb:SetHeight(math.min(height, math.max(24, height * height / (height + range))))
        bar:SetValue(math.min(scroll:GetVerticalScroll(), range))
        syncing = false
        bar:SetShown(range > 1)
    end

    bar:SetScript("OnValueChanged", function(_, value)
        if not syncing then
            scroll:SetVerticalScroll(value)
        end
    end)

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll(
            math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 36))
        )
    end)

    scroll:HookScript("OnVerticalScroll", function(_, offset)
        syncing = true
        bar:SetValue(offset)
        syncing = false
    end)

    function scroll:RefreshContent()
        if self.refreshingContent then
            return
        end

        local width = self:GetWidth()
        if width <= 0 then
            return
        end

        self.refreshingContent = true
        content:SetWidth(width)
        self:UpdateScrollChildRect()
        update()
        self.refreshingContent = nil
    end

    scroll:HookScript("OnSizeChanged", function(_, width)
        -- Hidden/transitioning parents can report zero bounds. Do not collapse
        -- the child; restore its rectangle once the viewport is visible again.
        if width > 0 then
            content:SetWidth(width)
        end

        update()
    end)

    scroll:HookScript("OnScrollRangeChanged", update)
    scroll:HookScript("OnShow", function()
        scroll:RefreshContent()
    end)

    bar:Hide()
    return scroll
end
