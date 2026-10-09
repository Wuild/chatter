local _, addon = ...
local L = addon.L
local Theme = { surfaces = setmetatable({}, { __mode = "k" }) }
Theme.grains = setmetatable({}, { __mode = "k" })
addon.Theme = Theme
Theme.textureSkins = setmetatable({}, { __mode = "k" })
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

function Theme:GetSkin()
    local id = Whispr.db and Whispr.db.global.themeSkin
    local preset = self.presets[id]
    return preset and self:Available(id) and preset.skin or nil
end

function Theme:HidesGrain()
    local skin = self:GetSkin()
    return skin and skin.hideGrain
end

function Theme:StyleWindow(window)
    local skin = self:GetSkin()
    if window.themeSkin ~= skin and window.themeSkin and window.themeSkin.ReleaseWindow then
        window.themeSkin:ReleaseWindow(window)
    end

    window.themeSkin = skin
    if skin and skin.StyleWindow then
        skin:StyleWindow(window)
    end
end

function Theme:Paint(surface, key, highlight, opaque)
    self.surfaces[surface] = { key, highlight, opaque }
    local profile = Whispr.db and Whispr.db.global or {}
    local color = profile[key] or self.defaults[key]
    local brighten = highlight and 0.05 or 0
    local red, green, blue =
        math.min(1, color[1] + brighten), math.min(1, color[2] + brighten), math.min(1, color[3] + brighten)
    local alpha = opaque and 1 or (profile.backgroundOpacity or 1)
    local skin = self:GetSkin()
    if surface.SetSkin then
        surface:SetSkin(skin, key)
    else
        local previous = self.textureSkins[surface]
        if previous and previous.ReleaseTexture then
            previous:ReleaseTexture(surface)
        end

        self.textureSkins[surface] = nil
        if skin and skin.PaintTexture and skin:PaintTexture(surface, key, red, green, blue, alpha) then
            self.textureSkins[surface] = skin
            return
        end
    end

    surface:SetColorTexture(red, green, blue, alpha)
end

function Theme:Refresh()
    for texture in pairs(self.grains) do
        texture:SetAlpha(self:HidesGrain() and 0 or (Whispr.db.global.backgroundOpacity or 1))
    end

    for surface, style in pairs(self.surfaces) do
        self:Paint(surface, style[1], style[2], style[3])
    end

    local hub = addon.Window
    if not hub then
        return
    end

    if hub.frame then
        hub:UpdateTheme()
        hub:UpdateOpacity()
    end

    for _, window in pairs(hub.popouts or {}) do
        if window.frame then
            window:UpdateTheme()
            window:UpdateOpacity()
        end
    end
end

function Theme:ResetAppearance()
    local profile = Whispr.db.global
    profile.themePreset = "default"
    profile.themeSkin = "flat"
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
                return unpack(Whispr.db.global[key] or self.defaults[key])
            end,

            set = function(_, r, g, b)
                Whispr.db.global[key] = { r, g, b }
                Whispr.db.global.themePreset = "custom"
                self:Refresh()
            end,
        }
    end

    args.footerColor = {
        type = "color",
        name = L["Input footer"],
        order = 9.5,
        get = function()
            return unpack(Whispr.db.global.footerColor or self.defaults.footerColor)
        end,

        set = function(_, r, g, b)
            Whispr.db.global.footerColor = { r, g, b }
            Whispr.db.global.themePreset = "custom"
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
            return not Whispr.db.global.fadeWhenIdle
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
            return not Whispr.db.global.fadeWhenIdle
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
            Whispr.db.global[info[#info]] = value
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

    if definition.skin ~= nil then
        if type(definition.skin) ~= "table" then
            return nil, L["Invalid theme skin"]
        end

        for _, hook in ipairs({
            "ApplySurface",
            "ReleaseSurface",
            "LayoutSurface",
            "ColorSurface",
            "ShowSurface",
            "ButtonState",
            "PaintTexture",
            "ReleaseTexture",
            "StyleWindow",
            "LayoutWindow",
            "ReleaseWindow",
        }) do
            if definition.skin[hook] ~= nil and type(definition.skin[hook]) ~= "function" then
                return nil, string.format(L["%s must be a function"], hook)
            end
        end
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

    self.presets[id] = { name = definition.name, colors = colors, owner = owner, skin = definition.skin }
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

function Theme:SortedIDs()
    local values, ids = self:Values(), {}
    for id in pairs(values) do
        ids[#ids + 1] = id
    end

    table.sort(ids, function(a, b)
        if a == "default" or b == "default" then
            return a == "default"
        end

        local first, second = values[a]:lower(), values[b]:lower()
        return first == second and a < b or first < second
    end)

    return ids
end

function Theme:CurrentPreset()
    local id = Whispr.db.global.themePreset or "default"
    local preset = self.presets[id]
    if not preset or not self:Available(id) then
        return "custom"
    end

    for key, fallback in pairs(self.defaults) do
        local actual, expected = Whispr.db.global[key] or fallback, preset.colors[key] or fallback
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

    local profile, preset = Whispr.db.global, self.presets[id]
    for key, fallback in pairs(self.defaults) do
        local color = preset.colors[key] or fallback
        profile[key] = { color[1], color[2], color[3] }
    end

    profile.themeSkin = preset.skin and id or "flat"
    profile.themePreset = id
    self:Refresh()
    if addon.Extensions then
        addon.Extensions:Emit("THEME_CHANGED", id)
    end

    return true
end
