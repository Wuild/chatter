local _, addon = ...
local L = addon.L
local Media = {}
addon.Media = Media
local shared = LibStub("LibSharedMedia-3.0")

function Media:Fonts()
    local fonts = { ["Game default"] = L["Game default"] }
    for name in pairs(shared:HashTable("font")) do
        fonts[name] = name
    end

    local selected = Whispr.db.global.chatFont
    if selected and not fonts[selected] then
        fonts[selected] = string.format(L["%s (unavailable)"], selected)
    end

    return fonts
end

function Media:Apply(text, metadata)
    local settings = Whispr.db.global
    local fallback = GameFontHighlight:GetFont()
    local path = settings.chatFont ~= "Game default" and shared:Fetch("font", settings.chatFont, true) or fallback
    local size = settings.chatFontSize or 14
    if metadata then
        size = math.max(10, size - 3)
    end

    if not text:SetFont(path or fallback, size, "") then
        text:SetFont(fallback, size, "")
    end

    text:SetShadowColor(unpack(settings.chatShadowColor or { 0, 0, 0, 1 }))
    text:SetShadowOffset(settings.chatShadow and 1 or 0, settings.chatShadow and -1 or 0)
    return size
end

function Media:Refresh()
    local function update(window)
        if not window.frame then
            return
        end

        self:Apply(window.input)
        window.layout = true
        window:Layout()
        window:RefreshMessages()
    end

    update(addon.Window)
    for _, window in pairs(addon.Window.popouts or {}) do
        update(window)
    end
end

function Media:Initialize()
    shared:Register("sound", "Whispr", addon.Sounds:Path("linux-message"))
    for key, label in pairs(addon.Sounds.labels) do
        shared:Register("sound", "Whispr: " .. label, addon.Sounds:Path(key))
    end

    shared.RegisterCallback(self, "LibSharedMedia_Registered", function(_, kind)
        if kind ~= "font" then
            return
        end

        LibStub("AceConfigRegistry-3.0"):NotifyChange("Whispr")
        self:Refresh()
    end)
end
