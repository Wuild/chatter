local _, addon = ...
local Theme = addon.Theme
local L = addon.L

addon.Locale:OnReady(function()
    Theme:Register("rosewood", {
        name = L["Rosewood"],
        colors = {
            windowColor = { 0.1255, 0.0706, 0.0824 },
            headerColor = { 0.2118, 0.1294, 0.1529 },
            sidebarColor = { 0.1529, 0.0902, 0.1137 },
            conversationColor = { 0.1882, 0.1255, 0.1529 },
            incomingColor = { 0.2314, 0.1490, 0.1804 },
            outgoingColor = { 0.3608, 0.1882, 0.2471 },
            accentColor = { 0.7608, 0.4627, 0.5647 },
            selectedColor = { 0.2980, 0.1804, 0.2314 },
            focusedBorderColor = { 0.8902, 0.6039, 0.6980 },
            unfocusedBorderColor = { 0.3765, 0.2392, 0.2863 },
            inputColor = { 0.2000, 0.1333, 0.1686 },
            footerColor = { 0.1686, 0.1020, 0.1294 },
            buttonColor = { 0.3412, 0.2196, 0.2627 },
        },
    })
end)
