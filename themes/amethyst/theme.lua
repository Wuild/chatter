local _, addon = ...
local Theme = addon.Theme
local L = addon.L

addon.Locale:OnReady(function()
    Theme:Register("amethyst", {
        name = L["Amethyst"],
        colors = {
            windowColor = { 0.0941, 0.0706, 0.1294 },
            headerColor = { 0.1647, 0.1255, 0.2118 },
            sidebarColor = { 0.1137, 0.0902, 0.1569 },
            conversationColor = { 0.1451, 0.1137, 0.1922 },
            incomingColor = { 0.1882, 0.1451, 0.2392 },
            outgoingColor = { 0.2824, 0.1961, 0.3725 },
            accentColor = { 0.6118, 0.4706, 0.7686 },
            selectedColor = { 0.2392, 0.1765, 0.3176 },
            focusedBorderColor = { 0.7451, 0.6000, 0.8863 },
            unfocusedBorderColor = { 0.2980, 0.2392, 0.3765 },
            inputColor = { 0.1725, 0.1333, 0.2235 },
            footerColor = { 0.1294, 0.0980, 0.1725 },
            buttonColor = { 0.2980, 0.2353, 0.3765 },
        },
    })
end)
