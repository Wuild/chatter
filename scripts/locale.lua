local _, addon = ...
local Locale = { catalogs = {}, callbacks = {}, selected = GetLocale() }
addon.Locale = Locale

function Locale:Register(code)
    local ace = LibStub("AceLocale-3.0")
    local name = "Whispr_" .. code
    local catalog = ace:NewLocale(name, code, true)
    self.catalogs[code] = ace:GetLocale(name)
    return catalog
end

-- Keep one lookup table so modules can retain it across initialization.
addon.L = setmetatable({}, {
    __index = function(_, key)
        local selected = Locale.catalogs[Locale.selected]
        local english = Locale.catalogs.enUS
        local value = selected and rawget(selected, key) or english and rawget(english, key)
        if value == nil then
            error("Whispr: missing locale key: " .. tostring(key))
        end

        return value
    end,
})

function Locale:OnReady(callback)
    if self.ready then
        callback()
    else
        self.callbacks[#self.callbacks + 1] = callback
    end
end

function Locale:Initialize(settings)
    if self.ready then
        return
    end

    local selected = settings.locale
    if selected ~= "enUS" and selected ~= "deDE" then
        selected = GetLocale()
    end

    self.selected = self.catalogs[selected] and selected or "enUS"
    self.ready = true
    local callbacks = self.callbacks
    self.callbacks = {}
    for _, callback in ipairs(callbacks) do
        callback()
    end
end
