local _, addon = ...
local Theme = addon.Theme
local L = addon.L

addon.Locale:OnReady(function()
    Theme:Register("sandstone", {
        name = L["Sandstone"],
        colors = {
            windowColor = { 0.1255, 0.1059, 0.0745 },
            headerColor = { 0.2118, 0.1882, 0.1412 },
            sidebarColor = { 0.1569, 0.1333, 0.0980 },
            conversationColor = { 0.1882, 0.1647, 0.1255 },
            incomingColor = { 0.2314, 0.2000, 0.1529 },
            outgoingColor = { 0.3176, 0.2706, 0.1725 },
            accentColor = { 0.7412, 0.6392, 0.4157 },
            selectedColor = { 0.2745, 0.2353, 0.1686 },
            focusedBorderColor = { 0.8706, 0.7569, 0.5412 },
            unfocusedBorderColor = { 0.3686, 0.3216, 0.2510 },
            inputColor = { 0.2000, 0.1765, 0.1373 },
            footerColor = { 0.1647, 0.1412, 0.1059 },
            buttonColor = { 0.3216, 0.2784, 0.2078 },
        },
    })
end)
