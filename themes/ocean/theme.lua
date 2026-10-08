local _, addon = ...
local Theme = addon.Theme
local L = addon.L

addon.Locale:OnReady(function()
    Theme:Register("ocean", {
        name = L["Ocean"],
        colors = {
            windowColor = { 0.0353, 0.0980, 0.1216 },
            headerColor = { 0.0745, 0.1725, 0.2078 },
            sidebarColor = { 0.0471, 0.1255, 0.1569 },
            conversationColor = { 0.0667, 0.1608, 0.1961 },
            incomingColor = { 0.0941, 0.2000, 0.2431 },
            outgoingColor = { 0.0863, 0.2784, 0.3569 },
            accentColor = { 0.1608, 0.6118, 0.7216 },
            selectedColor = { 0.1020, 0.2471, 0.3020 },
            focusedBorderColor = { 0.3216, 0.7294, 0.8196 },
            unfocusedBorderColor = { 0.1765, 0.3137, 0.3608 },
            inputColor = { 0.0784, 0.1843, 0.2235 },
            footerColor = { 0.0510, 0.1373, 0.1686 },
            buttonColor = { 0.1569, 0.3137, 0.3686 },
        },
    })
end)
