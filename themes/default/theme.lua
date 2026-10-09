local _, addon = ...
local Theme = addon.Theme
local L = addon.L

addon.Locale:OnReady(function()
    Theme:Register("default", { name = L["Default"], colors = {} })
end)
