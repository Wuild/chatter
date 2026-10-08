local _, addon = ...
local Theme = addon.Theme
local L = addon.L

addon.Locale:OnReady(function()
    Theme:Register("midnight", {
        name = L["Midnight"],
        colors = {
            windowColor = { 0.035, 0.045, 0.075 },
            headerColor = { 0.08, 0.10, 0.16 },
            sidebarColor = { 0.045, 0.06, 0.10 },
            conversationColor = { 0.065, 0.085, 0.13 },
            incomingColor = { 0.10, 0.12, 0.19 },
            outgoingColor = { 0.14, 0.16, 0.30 },
            accentColor = { 0.43, 0.46, 0.82 },
            selectedColor = { 0.16, 0.18, 0.30 },
            focusedBorderColor = { 0.54, 0.57, 0.92 },
            unfocusedBorderColor = { 0.18, 0.20, 0.31 },
            inputColor = { 0.09, 0.11, 0.18 },
            footerColor = { 0.055, 0.075, 0.12 },
            buttonColor = { 0.20, 0.23, 0.35 },
        },
    })
end)
