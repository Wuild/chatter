local _, addon = ...
local Theme = addon.Theme
local L = addon.L

addon.Locale:OnReady(function()
    Theme:Register("forest", {
        name = L["Forest"],
        colors = {
            windowColor = { 0.045, 0.07, 0.06 },
            headerColor = { 0.09, 0.14, 0.12 },
            sidebarColor = { 0.06, 0.10, 0.08 },
            conversationColor = { 0.08, 0.13, 0.10 },
            incomingColor = { 0.11, 0.17, 0.14 },
            outgoingColor = { 0.12, 0.25, 0.19 },
            accentColor = { 0.27, 0.58, 0.42 },
            selectedColor = { 0.12, 0.23, 0.17 },
            focusedBorderColor = { 0.39, 0.69, 0.50 },
            unfocusedBorderColor = { 0.19, 0.30, 0.24 },
            inputColor = { 0.10, 0.16, 0.13 },
            footerColor = { 0.065, 0.11, 0.085 },
            buttonColor = { 0.17, 0.26, 0.21 },
        },
    })
end)
