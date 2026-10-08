local _, addon = ...
local Theme = addon.Theme
local L = addon.L

addon.Locale:OnReady(function()
    Theme:Register("slate", {
        name = L["Slate"],
        colors = {
            windowColor = { 0.0706, 0.0784, 0.0863 },
            headerColor = { 0.1412, 0.1569, 0.1725 },
            sidebarColor = { 0.0980, 0.1098, 0.1216 },
            conversationColor = { 0.1255, 0.1412, 0.1569 },
            incomingColor = { 0.1647, 0.1843, 0.2039 },
            outgoingColor = { 0.2196, 0.2667, 0.3098 },
            accentColor = { 0.5451, 0.6706, 0.7255 },
            selectedColor = { 0.2039, 0.2510, 0.2902 },
            focusedBorderColor = { 0.6980, 0.7922, 0.8353 },
            unfocusedBorderColor = { 0.2549, 0.2941, 0.3255 },
            inputColor = { 0.1529, 0.1765, 0.1961 },
            footerColor = { 0.1137, 0.1294, 0.1451 },
            buttonColor = { 0.2392, 0.2824, 0.3176 },
        },
    })
end)
