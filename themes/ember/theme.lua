local _, addon = ...
local Theme = addon.Theme
local L = addon.L

addon.Locale:OnReady(function()
    Theme:Register("ember", {
        name = L["Ember"],
        colors = {
            windowColor = { 0.085, 0.055, 0.045 },
            headerColor = { 0.16, 0.11, 0.09 },
            sidebarColor = { 0.11, 0.075, 0.06 },
            conversationColor = { 0.14, 0.095, 0.075 },
            incomingColor = { 0.18, 0.13, 0.11 },
            outgoingColor = { 0.30, 0.17, 0.10 },
            accentColor = { 0.78, 0.39, 0.18 },
            selectedColor = { 0.25, 0.15, 0.10 },
            focusedBorderColor = { 0.90, 0.49, 0.24 },
            unfocusedBorderColor = { 0.33, 0.23, 0.18 },
            inputColor = { 0.17, 0.12, 0.10 },
            footerColor = { 0.12, 0.08, 0.065 },
            buttonColor = { 0.29, 0.20, 0.15 },
        },
    })
end)
