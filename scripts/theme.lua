local _, addon = ...
local L = addon.L
local Theme = { surfaces = setmetatable({}, { __mode = "k" }) }
Theme.grains = setmetatable({}, { __mode = "k" })
addon.Theme = Theme
Theme.defaults = {
    focusedBorderColor = { 0.15, 0.43, 0.58 },
    unfocusedBorderColor = { 0.24, 0.29, 0.32 },
    windowColor = { 0.075, 0.085, 0.095 },
    headerColor = { 0.14, 0.16, 0.18 },
    sidebarColor = { 0.10, 0.115, 0.13 },
    incomingColor = { 0.14, 0.16, 0.18 },
    outgoingColor = { 0.10, 0.24, 0.31 },
    accentColor = { 0.15, 0.43, 0.58 },
    conversationColor = { 0.12, 0.14, 0.16 },
    selectedColor = { 0.15, 0.21, 0.25 },
    inputColor = { 0.13, 0.16, 0.18 },
    buttonColor = { 0.20, 0.24, 0.27 },
    footerColor = { 0.105, 0.13, 0.15 },
}

function Theme:Paint(surface, key, highlight, opaque)
    self.surfaces[surface] = { key, highlight, opaque }
    local profile = Chatter.db and Chatter.db.global or {}
    local color = profile[key] or self.defaults[key]
    local brighten = highlight and 0.05 or 0
    surface:SetColorTexture(
        math.min(1, color[1] + brighten),
        math.min(1, color[2] + brighten),
        math.min(1, color[3] + brighten),
        opaque and 1 or (profile.backgroundOpacity or 1)
    )
end

function Theme:Refresh()
    for texture in pairs(self.grains) do
        texture:SetAlpha(Chatter.db.global.backgroundOpacity or 1)
    end

    for surface, style in pairs(self.surfaces) do
        self:Paint(surface, style[1], style[2], style[3])
    end

    local hub = addon.Window
    if not hub then
        return
    end

    if hub.frame then
        hub:UpdateOpacity()
    end

    for _, window in pairs(hub.popouts or {}) do
        if window.frame then
            window:UpdateOpacity()
        end
    end
end

function Theme:ResetAppearance()
    local profile = Chatter.db.global
    profile.themePreset = "default"
    for key in pairs(self.defaults) do
        profile[key] = nil
    end

    for _, key in ipairs({
        "backgroundOpacity",
        "windowOpacity",
        "fadeWhenIdle",
        "idleOpacity",
        "idleFadeDelay",
        "animateWindows",
        "chatFont",
        "chatFontSize",
        "chatShadow",
        "chatShadowColor",
        "timestamps",
        "showMessagePreviews",
        "outgoingOnRight",
    }) do
        local value = addon.defaults.global[key]
        if type(value) == "table" then
            local copy = {}
            for index, entry in pairs(value) do
                copy[index] = entry
            end

            value = copy
        end

        profile[key] = value
    end

    self:Refresh()
    if addon.Media then
        addon.Media:Refresh()
    end

    local hub = addon.Window
    if hub then
        hub:RefreshList()
        for _, window in pairs(hub.popouts or {}) do
            window:RefreshList()
        end
    end
end

function Theme:Options()
    local args = {}
    local labels = {
        { "windowColor", L["Window background"] },
        { "headerColor", L["Headers"] },
        { "sidebarColor", L["Conversation sidebar"] },
        { "incomingColor", L["Incoming messages"] },
        { "outgoingColor", L["Outgoing messages"] },
        { "accentColor", L["Accent and badges"] },
        { "conversationColor", L["Conversation cards"], 6.5 },
        { "selectedColor", L["Selected conversation"], 7 },
        { "inputColor", L["Message input"], 8 },
        { "buttonColor", L["Buttons"], 9 },
        { "focusedBorderColor", L["Focused window border"], 9.6 },
        { "unfocusedBorderColor", L["Unfocused window border"], 9.7 },
    }

    for index, entry in ipairs(labels) do
        local key, label = entry[1], entry[2]
        args[key] = {
            type = "color",
            name = label,
            order = entry[3] or index,
            get = function()
                return unpack(Chatter.db.global[key] or self.defaults[key])
            end,

            set = function(_, r, g, b)
                Chatter.db.global[key] = { r, g, b }
                Chatter.db.global.themePreset = "custom"
                self:Refresh()
            end,
        }
    end

    args.footerColor = {
        type = "color",
        name = L["Input footer"],
        order = 9.5,
        get = function()
            return unpack(Chatter.db.global.footerColor or self.defaults.footerColor)
        end,

        set = function(_, r, g, b)
            Chatter.db.global.footerColor = { r, g, b }
            Chatter.db.global.themePreset = "custom"
            self:Refresh()
        end,
    }

    args.backgroundOpacity = {
        type = "range",
        name = L["Background opacity"],
        min = 0,
        max = 1,
        step = 0.05,
        isPercent = true,
        order = 10,
        desc = L["Transparency of window surfaces, keeping text readable."],
    }

    args.windowOpacity = {
        type = "range",
        name = L["Active window opacity"],
        min = 0.2,
        max = 1,
        step = 0.05,
        isPercent = true,
        order = 11,
    }

    args.fadeWhenIdle = { type = "toggle", name = L["Fade unfocused windows"], order = 12 }
    args.idleOpacity = {
        type = "range",
        name = L["Idle window opacity"],
        min = 0.05,
        max = 1,
        step = 0.05,
        isPercent = true,
        order = 13,
        desc = L["Opacity of an unfocused window when the mouse is away. Click outside a window to release its focus."],
        disabled = function()
            return not Chatter.db.global.fadeWhenIdle
        end,
    }

    args.idleFadeDelay = {
        type = "range",
        name = L["Delay before fading (seconds)"],
        min = 0,
        max = 30,
        step = 0.5,
        order = 14,
        desc = L["Wait this long after leaving a window or opening it without focus before applying idle opacity."],
        disabled = function()
            return not Chatter.db.global.fadeWhenIdle
        end,
    }

    args.animateWindows = { type = "toggle", name = L["Animate windows"], order = 15 }
    args.resetAppearance = {
        type = "execute",
        name = L["Reset appearance"],
        order = 16,
        desc = L["Restore default colors, opacity, animations, fonts, timestamps and conversation previews. Keeps conversations and behavior settings."],
        func = function()
            self:ResetAppearance()
        end,
    }

    return {
        type = "group",
        name = L["Window appearance"],
        order = 9,
        inline = true,
        args = args,
        set = function(info, value)
            Chatter.db.global[info[#info]] = value
            self:Refresh()
        end,
    }
end

Theme.presets = {}

function Theme:Register(id, definition, owner)
    if type(id) ~= "string" or not id:match("^[%w_-]+$") or id == "custom" then
        return nil, L["Invalid theme ID"]
    end

    if self.presets[id] then
        return nil, L["Theme ID already registered"]
    end

    if
        type(definition) ~= "table"
        or type(definition.name) ~= "string"
        or definition.name == ""
        or type(definition.colors) ~= "table"
    then
        return nil, L["A theme needs a name and colors"]
    end

    local colors = {}
    for key, value in pairs(definition.colors) do
        if not self.defaults[key] or type(value) ~= "table" then
            return nil, string.format(L["Unknown color: %s"], tostring(key))
        end

        colors[key] = {}
        for index = 1, 3 do
            local component = value[index]
            if type(component) ~= "number" or component ~= component or component < 0 or component > 1 then
                return nil, L["Colors must contain three numbers between 0 and 1"]
            end

            colors[key][index] = component
        end
    end

    self.presets[id] = { name = definition.name, colors = colors, owner = owner }
    if addon.Settings then
        addon.Settings:Refresh()
    end

    return true
end

function Theme:Available(id)
    local preset = self.presets[id]
    return preset and (not preset.owner or (addon.Extensions and addon.Extensions:IsEnabled(preset.owner)))
end

function Theme:Values()
    local values = { custom = L["Custom colors"] }
    for id, preset in pairs(self.presets) do
        if self:Available(id) then
            values[id] = preset.name
        end
    end

    return values
end

function Theme:CurrentPreset()
    local id = Chatter.db.global.themePreset or "default"
    local preset = self.presets[id]
    if not preset or not self:Available(id) then
        return "custom"
    end

    for key, fallback in pairs(self.defaults) do
        local actual, expected = Chatter.db.global[key] or fallback, preset.colors[key] or fallback
        for index = 1, 3 do
            if actual[index] ~= expected[index] then
                return "custom"
            end
        end
    end

    return id
end

function Theme:Apply(id)
    if not self:Available(id) then
        return nil, L["Theme unavailable"]
    end

    local profile, preset = Chatter.db.global, self.presets[id]
    for key, fallback in pairs(self.defaults) do
        local color = preset.colors[key] or fallback
        profile[key] = { color[1], color[2], color[3] }
    end

    profile.themePreset = id
    self:Refresh()
    if addon.Extensions then
        addon.Extensions:Emit("THEME_CHANGED", id)
    end

    return true
end

Theme:Register("default", { name = "Chatter", colors = {} })
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
