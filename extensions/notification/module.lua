-- Bundled whisper alerts with plain-text message previews.
local _, addon = ...
local L = addon.L
local Notification = Whispr:NewExtension("notification", {
    name = L["Notification"],
    version = "1.0.0",
    builtin = true,
    description = L["Shows whispers with a short message preview when Whispr stays hidden. Click to open the conversation, or use the close button to dismiss."],
})

Notification.notices, Notification.frames = {}, {}
Notification:RegisterDefaults({
    duration = 6,
    onlyCombat = false,
    opacity = 1,
    width = 280,
    height = 72,
    textSize = 12,
    previewLength = 100,
    showPreview = true,
})

addon.Notification = Notification

function Notification:Settings()
    return self:GetSettings()
end

local function bounded(value, fallback, minimum, maximum)
    value = tonumber(value)
    if not value or value ~= value then
        value = fallback
    end

    return math.max(minimum, math.min(maximum, value))
end

function Notification:PreviewText(frame, text, width)
    local characters = {}
    for character in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        characters[#characters + 1] = character
    end

    local count = math.min(#characters, math.floor(bounded(self:Settings().previewLength, 100, 20, 240)))
    local result
    repeat
        result = table.concat(characters, "", 1, count) .. (count < #characters and "…" or "")
        -- Escape remaining literal pipes so truncation cannot create chat markup.
        result = result:gsub("|", "||")
        frame.measure:SetText(result)
        if frame.measure:GetStringWidth() <= width or count == 0 then
            break
        end

        count = count - 1
    until false
    return result
end

function Notification:ShouldNotify(key, preview)
    local window = addon.Window
    if window.frame and window.frame:IsShown() then
        return false
    end

    local conversation = window.detached and window.detached[key]
    if conversation and conversation.frame and conversation.frame:IsShown() then
        return false
    end

    return preview or not self:Settings().onlyCombat or InCombatLockdown()
end

function Notification:Position()
    local settings = self:Settings()
    local x, y = tonumber(settings.x) or 0, tonumber(settings.y) or 180
    if x ~= x or math.abs(x) == math.huge then
        x = 0
    end

    if y ~= y or math.abs(y) == math.huge then
        y = 180
    end

    self.anchor:ClearAllPoints()
    self.anchor:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

function Notification:Create()
    if self.anchor then
        return
    end

    local UI = addon.UI
    local anchor = CreateFrame("Frame", nil, UIParent)
    self.anchor = anchor
    anchor:SetSize(280, 72)
    anchor:SetFrameStrata("DIALOG")
    anchor:SetClampedToScreen(true)
    anchor:SetMovable(true)
    anchor:RegisterForDrag("LeftButton")
    anchor.surface = UI.Round(anchor, 5, 0.10, 0.24, 0.31)
    if addon.Theme then
        addon.Theme:Paint(anchor.surface, "accentColor")
    end

    anchor.label = UI.Text(anchor, L["Notification anchor"], "GameFontNormal")
    anchor.label:SetPoint("TOP", 0, -12)
    anchor.hint = UI.Text(anchor, L["Drag to move · toggle off to lock"], "GameFontDisableSmall")
    anchor.hint:SetPoint("TOP", 0, -32)
    anchor:SetScript("OnDragStart", function()
        if self.moving then
            anchor:StartMoving()
        end
    end)

    anchor:SetScript("OnDragStop", function()
        anchor:StopMovingOrSizing()
        local x, y = anchor:GetCenter()
        local px, py = UIParent:GetCenter()
        local ratio = anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local settings = self:Settings()
        settings.x, settings.y = x * ratio - px, y * ratio - py
        self:Position()
    end)

    anchor:SetScript("OnUpdate", function(_, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < 0.1 then
            return
        end

        self.elapsed = 0
        local changed = false
        for index = #self.notices, 1, -1 do
            local notice = self.notices[index]
            if notice.expires <= GetTime() or not self:ShouldNotify(notice.key, notice.preview) then
                table.remove(self.notices, index)
                changed = true
            end
        end

        if changed then
            self:Render()
        end
    end)

    self:Position()
    anchor:Hide()
end

function Notification:Dismiss(notice)
    for index, current in ipairs(self.notices) do
        if current == notice then
            table.remove(self.notices, index)
            break
        end
    end

    self:Render()
end

function Notification:Highlight(frame, hovered)
    frame.hovered = hovered
    if addon.Theme then
        addon.Theme:Paint(frame.surface, hovered and "selectedColor" or "windowColor")
    else
        frame.surface:SetColorTexture(
            hovered and 0.15 or 0.075,
            hovered and 0.21 or 0.085,
            hovered and 0.25 or 0.095,
            1
        )
    end
end

function Notification:Identity(frame, notice, conversation)
    local classFile = conversation and conversation.character and conversation.character.classFile
    if (notice.preview or notice.simulated) and UnitClass then
        local _, playerClass = UnitClass("player")
        if not HasAnySecretValues or not HasAnySecretValues(playerClass) then
            classFile = playerClass
        end
    end

    local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    local coords = classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
    frame.sender:SetTextColor(unpack(color and { color.r, color.g, color.b } or addon.UI.colors.text))
    if coords then
        frame.logo:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        frame.logo:SetTexCoord(unpack(coords))
    else
        frame.logo:SetTexture("Interface\\AddOns\\Whispr\\assets\\whispr-icon.tga")
        frame.logo:SetTexCoord(0, 1, 0, 1)
    end
end

function Notification:Render()
    self:Create()
    local anchor, UI = self.anchor, addon.UI
    local settings = self:Settings()
    local width = bounded(settings.width, 280, 220, 600)
    local textSize = bounded(settings.textSize, 12, 10, 18)
    local showPreview = settings.showPreview ~= false
    local minimumHeight = (showPreview and 3 or 2) * textSize + 24
    local height = math.max(minimumHeight, bounded(settings.height, 72, 52, 180) - (showPreview and 0 or textSize + 6))
    local spacing = height + 6
    anchor:SetSize(width, height)
    anchor.surface:SetShown(self.moving == true)
    anchor.label:SetShown(self.moving == true)
    anchor.hint:SetShown(self.moving == true)
    anchor:EnableMouse(self.moving == true)
    local _, centerY = anchor:GetCenter()
    local stackHeight = #self.notices * spacing + (self.moving and spacing or 0)
    local upward = centerY and centerY + height / 2 < stackHeight
    for index, notice in ipairs(self.notices) do
        local frame = self.frames[index]
        if not frame then
            frame = CreateFrame("Button", nil, anchor)
            self.frames[index] = frame
            frame:SetSize(280, 72)
            frame:SetClampedToScreen(true)
            frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            frame.surface = UI.Round(frame, 5, 0.075, 0.085, 0.095)
            if addon.Theme then
                addon.Theme:Paint(frame.surface, "windowColor")
            end

            frame.accent = frame:CreateTexture(nil, "ARTWORK")
            frame.accent:SetPoint("TOPLEFT", 0, -5)
            frame.accent:SetPoint("BOTTOMLEFT", 0, 5)
            frame.accent:SetWidth(2)
            if addon.Theme then
                addon.Theme:Paint(frame.accent, "accentColor")
            end

            frame.title = UI.Text(frame, L["Whisper received"], "GameFontDisableSmall")
            frame.title:SetPoint("TOPLEFT", 56, -11)
            frame.title:SetWidth(244)
            frame.title:SetWordWrap(false)
            frame.sender = UI.Text(frame, "", "GameFontHighlight")
            frame.sender:SetPoint("TOPLEFT", 44, -9)
            frame.sender:SetWidth(246)
            frame.sender:SetWordWrap(false)
            frame.logo = frame:CreateTexture(nil, "ARTWORK")
            frame.logo:SetTexture("Interface\\AddOns\\Whispr\\assets\\whispr-icon.tga")
            frame.logo:SetSize(24, 24)
            frame.logo:SetPoint("TOPLEFT", 10, -10)
            frame.details = UI.Text(frame, "", "GameFontDisableSmall")
            frame.details:SetPoint("TOPLEFT", 56, -53)
            frame.details:SetWidth(270)
            frame.details:SetWordWrap(false)
            frame.preview = UI.Text(frame, "", "GameFontHighlightSmall")
            frame.preview:SetPoint("TOPLEFT", 56, -52)
            frame.preview:SetWordWrap(false)
            frame.measure = UI.Text(frame, "", "GameFontHighlightSmall")
            frame.measure:SetWidth(0)
            frame.measure:Hide()
            frame.close = CreateFrame("Button", nil, frame)
            frame.close:SetSize(18, 18)
            frame.close:SetPoint("TOPRIGHT", -6, -6)
            frame.close.surface = UI.Round(frame.close, 3, 0.20, 0.24, 0.27)
            frame.close.icon = frame.close:CreateTexture(nil, "OVERLAY")
            frame.close.icon:SetTexture("Interface\\AddOns\\Whispr\\assets\\icons\\close.tga")
            frame.close.icon:SetSize(12, 12)
            frame.close.icon:SetPoint("CENTER")
            frame.close:SetScript("OnClick", function()
                if frame.notice then
                    self:Dismiss(frame.notice)
                end
            end)

            frame:SetScript("OnEnter", function()
                self:Highlight(frame, true)
            end)

            frame:SetScript("OnLeave", function()
                self:Highlight(frame, false)
            end)

            frame.close:SetScript("OnEnter", function()
                self:Highlight(frame, true)
                if addon.Theme then
                    addon.Theme:Paint(frame.close.surface, "buttonColor", true)
                end
            end)

            frame.close:SetScript("OnLeave", function()
                self:Highlight(frame, false)
                if addon.Theme then
                    addon.Theme:Paint(frame.close.surface, "buttonColor")
                end
            end)

            frame:SetScript("OnClick", function(owner, button)
                local current = owner.notice
                if not current then
                    return
                end

                self:Dismiss(current)
                if button == "LeftButton" and not current.preview and Whispr.db.char.conversations[current.key] then
                    addon.Window:Open(current.key)
                end
            end)
        end

        frame:SetSize(width, height)
        frame:SetAlpha(bounded(settings.opacity, 1, 0.2, 1))
        frame.title:Hide() -- Sender is the compact heading; context lives in the footer.
        frame.sender:SetWidth(width - 76)
        frame.preview:SetWidth(width - 56)
        frame.details:SetWidth(width - 56)
        frame.preview:ClearAllPoints()
        frame.preview:SetPoint("TOPLEFT", 44, -(textSize + 16))
        frame.details:ClearAllPoints()
        frame.details:SetPoint("BOTTOMLEFT", 44, 8)
        if addon.Media then
            for _, label in ipairs({ frame.sender, frame.preview, frame.measure, frame.details }) do
                addon.Media:Apply(label)
            end
        end

        local font = frame.sender:GetFont()
        frame.details:SetFont(font, math.max(10, textSize - 2), "")
        frame.details:SetTextColor(unpack(UI.colors.muted))
        frame.sender:SetFont(font, textSize, "")
        frame.preview:SetFont(font, textSize, "")
        frame.measure:SetFont(font, textSize, "")
        frame.preview:SetText(self:PreviewText(frame, notice.text or "", width - 56))
        frame.preview:SetShown(settings.showPreview ~= false)
        frame.notice = notice
        frame.sender:SetText(notice.name)
        local conversation = addon.History and addon.History.Get(notice.key) or Whispr.db.char.conversations[notice.key]
        self:Identity(frame, notice, conversation)
        local unread = math.max(1, conversation and conversation.unread or notice.count or 1)
        frame.details:SetText(
            (notice.preview or notice.simulated) and L["Preview notification"]
                or string.format(
                    notice.transport == "bnet" and L["Battle.net · %d unread"] or L["Whisper · %d unread"],
                    unread
                )
        )
        self:Highlight(frame, false)
        if addon.Theme then
            addon.Theme:Paint(frame.close.surface, "buttonColor")
        end

        frame:ClearAllPoints()
        local offset = (index - 1) * spacing + (self.moving and spacing or 0)
        frame:SetPoint(
            upward and "BOTTOMLEFT" or "TOPLEFT",
            anchor,
            upward and "BOTTOMLEFT" or "TOPLEFT",
            0,
            upward and offset or -offset
        )
        frame:Show()
    end

    for index = #self.notices + 1, #self.frames do
        local frame = self.frames[index]
        frame:Hide()
        frame.notice = nil
        frame.sender:SetText("")
        frame.details:SetText("")
        frame.preview:SetText("")
        frame.measure:SetText("")
    end

    anchor:SetShown(self.moving == true or #self.notices > 0)
end

function Notification:Receive(payload, preview)
    if not self:ShouldNotify(payload.key, preview) then
        return
    end

    if type(payload.key) ~= "string" or type(payload.name) ~= "string" then
        return
    end

    local count = 1
    for index = #self.notices, 1, -1 do
        if self.notices[index].key == payload.key then
            count = (self.notices[index].count or 1) + 1
            table.remove(self.notices, index)
        end
    end

    local duration = tonumber(self:Settings().duration) or 6
    duration = math.max(2, math.min(15, duration))
    local text = payload.message and type(payload.message.text) == "string" and payload.message.text or ""
    text = addon.Format.Preview(text):gsub("||", "|"):gsub("%s+", " ")
    table.insert(self.notices, 1, {
        text = text,
        key = payload.key,
        name = payload.name,
        preview = preview,
        simulated = payload.simulated == true,
        count = count,
        transport = payload.transport,
        expires = GetTime() + duration,
    })

    while #self.notices > 3 do
        table.remove(self.notices)
    end

    self:Render()
end

function Notification:SetAnchor(shown)
    self.moving = shown == true
    if self.anchor then
        self.anchor:StopMovingOrSizing()
    end

    self:Render()
end

function Notification:OnInitialize()
    local settings = self:Settings()
    if not settings.compactLayout then
        if settings.width == 360 then
            settings.width = 280
        end

        if settings.height == 104 then
            settings.height = 72
        end

        if settings.textSize == 13 then
            settings.textSize = 12
        end

        settings.compactLayout = true
    end
end

function Notification:OnEnable()
    self:RegisterMessage("MESSAGE_RECEIVED", "OnWhisper")
    self:RegisterMessage("CONVERSATION_OPENED", "OnConversationOpened")
    self:RegisterMessage("WINDOW_OPENED", "OnConversationOpened")
end

function Notification:OnWhisper(_, payload)
    self:Receive(payload)
end

function Notification:OnConversationOpened()
    for index = #self.notices, 1, -1 do
        local notice = self.notices[index]
        if not self:ShouldNotify(notice.key, notice.preview) then
            table.remove(self.notices, index)
        end
    end

    if self.anchor then
        self:Render()
    end
end

function Notification:OnDisable()
    self.notices, self.moving = {}, false
    if self.anchor then
        self.anchor:StopMovingOrSizing()
        self:Render()
    end
end

Notification:RegisterOptions({
    type = "group",
    name = L["Notification settings"],
    set = function(info, value)
        Notification:Settings()[info[#info]] = value
        if Notification.anchor then
            Notification:Render()
        end
    end,

    args = {
        width = { type = "range", name = L["Notification width"], min = 220, max = 600, step = 10, order = 2.1 },
        height = { type = "range", name = L["Notification height"], min = 52, max = 180, step = 2, order = 2.2 },
        textSize = { type = "range", name = L["Notification text size"], min = 10, max = 18, step = 1, order = 2.3 },
        opacity = {
            type = "range",
            name = L["Notification opacity"],
            desc = L["Transparency of the whole notification, including text and the class icon."],
            min = 0.2,
            max = 1,
            step = 0.05,
            isPercent = true,
            order = 2.35,
        },

        showPreview = { type = "toggle", name = L["Show message preview"], order = 2.4, width = "full" },
        previewLength = {
            type = "range",
            name = L["Maximum preview characters"],
            min = 20,
            max = 240,
            step = 10,
            order = 2.5,
            disabled = function()
                return Notification:Settings().showPreview == false
            end,
        },

        duration = {
            type = "range",
            name = L["Display duration"],
            desc = L["Seconds before an alert disappears."],
            min = 2,
            max = 15,
            step = 1,
            order = 1,
            get = function()
                return Notification:Settings().duration or 6
            end,
        },

        onlyCombat = { type = "toggle", name = L["Only during combat"], order = 2, width = "full" },
        anchor = {
            type = "toggle",
            name = L["Show movable anchor"],
            order = 3,
            width = "full",
            desc = L["Drag the anchor to position alerts, then turn this off to lock it."],
            get = function()
                return Notification.moving == true
            end,

            set = function(_, value)
                Notification:SetAnchor(value)
            end,
        },

        preview = {
            type = "execute",
            name = L["Preview notification"],
            order = 4,
            func = function()
                Notification:Receive({
                    key = "preview",
                    name = UnitName("player") or L["You"],
                    message = {
                        text = L["Hey! Ready for tonight’s adventure? This is a preview of a Whispr notification."],
                    },
                }, true)
            end,
        },

        reset = {
            type = "execute",
            name = L["Reset position"],
            order = 5,
            func = function()
                local settings = Notification:Settings()
                settings.x, settings.y = nil, nil
                Notification:Create()
                Notification:Position()
            end,
        },
    },
})
