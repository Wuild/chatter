-- Load the real English catalog without changing each harness's library mocks.
local addon = ...
local savedStub, savedLocale = LibStub, GetLocale
LibStub = nil
GetLocale = function()
    return "enUS"
end

assert(loadfile("scripts/libraries/LibStub/LibStub.lua"))()
assert(loadfile("scripts/libraries/AceLocale-3.0/AceLocale-3.0.lua"))()
assert(loadfile("scripts/locale.lua"))("Whispr", addon)
assert(loadfile("locales/enUS.lua"))("Whispr", addon)
addon.Locale:Initialize({})
LibStub, GetLocale = savedStub, savedLocale
assert(loadfile("scripts/filters.lua"))("Whispr", addon)
