local _, addon = ...
local L = addon.L

local Emoji = Whispr:NewExtension("emoji", {
    name = L["Emoji"],
    version = "1.0.0",
    builtin = true,
    description = L["An emoji picker and inline text smileys in messages and drafts. Disabling shows the original text and hides the picker; messages and drafts are preserved."],
})

addon.Emoji = Emoji

function Emoji:Migrate()
    local profile = Whispr.db.global
    profile.extensions = profile.extensions or {}
    if profile.extensions.emoji == nil then
        profile.extensions.emoji = profile.smileys ~= false
    end

    profile.smileys = profile.extensions.emoji == true
end

function Emoji:SetEnabled(enabled)
    -- Keep the existing formatting flag as the renderer's compatibility switch.
    Whispr.db.global.smileys = enabled

    local function refresh(window)
        if not window or not window.frame then
            return
        end

        window.emoteButton:SetShown(enabled)
        window.input:SetTextInsets(14, enabled and 48 or 14, 0, 0)
        if not enabled and window.emotePicker then
            window.emotePicker:Hide()
        end

        window.input:RefreshFormatting()
        window:RefreshMessages()
    end

    refresh(addon.Window)
    for _, window in pairs(addon.Window and addon.Window.popouts or {}) do
        refresh(window)
    end
end

function Emoji.Toggle(window)
    if not Whispr.db.global.smileys then
        return
    end

    local self, UI = window, addon.UI
    if not self.active then
        return
    end

    if self.emotePicker and self.emotePicker:IsShown() then
        self.emotePicker:Hide()
        return
    end

    if not self.emotePicker then
        local picker = CreateFrame("Frame", nil, self.frame)
        self.emotePicker = picker
        picker:SetSize(216, 148)
        picker:SetPoint("BOTTOMRIGHT", self.input, "TOPRIGHT", 0, 6)
        picker:SetFrameLevel(self.frame:GetFrameLevel() + 40)
        picker:SetClampedToScreen(true)
        picker:EnableMouse(true)
        picker.surface = UI.Round(picker, 4, 0.13, 0.16, 0.18)
        if addon.Theme then
            addon.Theme:Paint(picker.surface, "headerColor")
        end

        picker.buttons = {}
        for index, emote in ipairs(addon.EmotePicker) do
            local button = UI.EmoteButton(picker, emote.asset, emote.text, 30, function()
                if self.active ~= picker.conversation then
                    picker:Hide()
                    return
                end

                local cursor = self.input:GetCursorPosition()
                self.input:SetFocus()
                self.input:SetCursorPosition(cursor)
                self.input:Insert(emote.text .. " ")
            end)

            button:SetPoint("TOPLEFT", 8 + ((index - 1) % 6) * 34, -8 - math.floor((index - 1) / 6) * 34)
            picker.buttons[index] = button
        end

        picker:RegisterEvent("GLOBAL_MOUSE_DOWN")
        picker:SetScript("OnEvent", function()
            if not picker:IsShown() or picker:IsMouseOver() or self.emoteButton:IsMouseOver() then
                return
            end

            for _, button in ipairs(picker.buttons) do
                if button:IsMouseOver() then
                    return
                end
            end

            picker:Hide()
        end)
    end

    self.emotePicker.conversation = self.active
    self.emotePicker:Show()
end

function Emoji:OnInitialize()
    self:Migrate()
end

function Emoji:RenderToken(_, token, fontSize, wrap)
    return addon.EmojiRenderer.Render(token, fontSize, wrap)
end

function Emoji:AutoSpace(_, value, token)
    return addon.EmojiRenderer.AutoSpace(value, token)
end

function Emoji:OnEnable()
    self:RegisterFilter("FORMAT_MESSAGE_TOKEN", "RenderToken")
    self:RegisterFilter("FORMAT_INPUT_TOKEN", "RenderToken")
    self:RegisterFilter("INPUT_AUTO_SPACE", "AutoSpace")
    self:SetEnabled(true)
end

function Emoji:OnDisable()
    self:SetEnabled(false)
end
