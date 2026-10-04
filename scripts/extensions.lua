local _, addon = ...
local L = addon.L
local Extensions = { entries = {}, listeners = {}, started = false }
addon.Extensions = Extensions
local Module = {}
local events = {
    CHARACTERS_UPDATED = true,
    CONVERSATION_CREATED = true,
    CONVERSATION_OPENED = true,
    CONVERSATION_DELETED = true,
    WINDOW_OPENED = true,
    WINDOW_CLOSED = true,
    DRAFT_CHANGED = true,
    TYPING_CHANGED = true,
    MESSAGE_RECEIVED = true,
    MESSAGE_SENT = true,
    MESSAGE_DELIVERY_CHANGED = true,
    THEME_CHANGED = true,
}

local function copy(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] then
        return seen[value]
    end

    local result = {}
    seen[value] = result
    for key, entry in pairs(value) do
        result[key] = copy(entry, seen)
    end

    return result
end

local function mergeDefaults(settings, defaults)
    for key, value in pairs(defaults or {}) do
        if settings[key] == nil then
            settings[key] = copy(value)
        elseif type(settings[key]) == "table" and type(value) == "table" then
            mergeDefaults(settings[key], value)
        end
    end
end

local function changed()
    if addon.Settings then
        addon.Settings:Refresh()
    end
end

function Module:GetName()
    return self.id
end

function Module:IsEnabled()
    return Extensions:IsEnabled(self.id)
end

function Module:Enable()
    return Extensions:SetEnabled(self.id, true)
end

function Module:Disable()
    return Extensions:SetEnabled(self.id, false)
end

function Module:SetEnabledState(enabled)
    self.defaultEnabled = enabled == true
end

function Module:GetSettings()
    local settings = Extensions:Context(self.id).GetSettings()
    mergeDefaults(settings, self.defaults)
    return settings
end

function Module:RegisterDefaults(defaults)
    assert(type(defaults) == "table", L["Extension defaults must be a table"])
    self.defaults = copy(defaults)
    if Chatter.db then
        self:GetSettings()
    end
end

function Module:RegisterOptions(options)
    assert(
        type(options) == "table" and options.type == "group" and type(options.args) == "table",
        L["Extension options must be an AceConfig group"]
    )
    self.options = copy(options)
    changed()
end

function Module:RegisterTheme(id, definition)
    return Extensions:Context(self.id).RegisterTheme(id, definition)
end

function Module:RegisterFilter(event, method)
    method = method or event
    assert(
        addon.Filters.supported[event]
            and (type(method) == "function" or (type(method) == "string" and type(self[method]) == "function")),
        L["Unsupported event or callback"]
    )
    addon.Filters:Register(self.id, event, function(value, ...)
        if not self:IsEnabled() then
            return value
        end

        local callback = type(method) == "string" and self[method] or method
        local ok, result = pcall(callback, self, event, value, ...)
        if ok and (result == nil or type(result) == type(value)) then
            return result
        end

        Extensions:Deactivate(self.id)
        Extensions.entries[self.id].error = ok and L["Invalid render filter result"] or tostring(result)
        changed()
        return value
    end)
end

function Module:UnregisterFilter(event)
    addon.Filters:Remove(self.id, event)
end

function Module:UnregisterAllFilters()
    addon.Filters:Remove(self.id)
end

function Module:RegisterMessage(event, method)
    method = method or event
    assert(
        events[event]
            and (type(method) == "function" or (type(method) == "string" and type(self[method]) == "function")),
        L["Unsupported event or callback"]
    )
    Extensions.listeners[event] = Extensions.listeners[event] or {}
    -- Like AceEvent, one method per message per module; registering replaces it.
    Extensions.listeners[event][self.id] = {
        function(...)
            local callback = type(method) == "string" and self[method] or method
            callback(self, event, ...)
        end,
    }
end

function Module:UnregisterMessage(event)
    if Extensions.listeners[event] then
        Extensions.listeners[event][self.id] = nil
    end
end

function Module:UnregisterAllMessages()
    for _, listeners in pairs(Extensions.listeners) do
        listeners[self.id] = nil
    end
end

function Extensions:NewModule(id, metadata)
    assert(type(id) == "string" and id:match("^[%w_-]+$"), L["Invalid extension ID"])
    assert(not self.entries[id], L["Extension ID already registered"])
    assert(metadata == nil or type(metadata) == "table", L["Extension metadata must be a table"])
    local module = setmetatable({ id = id, name = id, defaultEnabled = true }, { __index = Module })
    for _, key in ipairs({ "name", "description", "version", "builtin" }) do
        if metadata and metadata[key] ~= nil then
            module[key] = metadata[key]
        end
    end

    assert(type(module.name) == "string" and module.name ~= "", L["An extension needs a name"])
    local entry = { spec = module, module = module, active = false }
    self.entries[id] = entry
    -- Give the caller's Lua chunk time to define its lifecycle methods.
    if self.initialized then
        C_Timer.After(0, function()
            self:InitializeEntry(id)
            self:Activate(id)
            changed()
        end)
    end

    changed()
    return module
end

function Extensions:GetModule(id, silent)
    local entry = self.entries[id]
    if entry and entry.module then
        return entry.module
    end

    if not silent then
        error(L["Unknown extension"], 2)
    end
end

function Extensions:InitializeEntry(id)
    local entry = self.entries[id]
    if not entry or entry.initialized then
        return true
    end

    if entry.initializing or entry.initFailed then
        return false
    end

    entry.initializing = true
    entry.context = entry.context or self:Context(id)
    if entry.module then
        entry.module:GetSettings()
        local callback = entry.module.OnInitialize
        if callback then
            local ok, err = pcall(callback, entry.module)
            if not ok then
                entry.error = tostring(err)
                entry.initializing, entry.initFailed = nil, true
                self:RemoveListeners(id)
                return false
            end
        end
    end

    entry.initialized, entry.initializing = true, nil
    return true
end

function Extensions:Initialize()
    if self.initialized then
        return
    end

    self.initialized = true
    for id in pairs(self.entries) do
        self:InitializeEntry(id)
    end
end

function Extensions:IsEnabled(id)
    local entry = self.entries[id]
    return entry and entry.active == true or false
end

function Extensions:RemoveListeners(id)
    if addon.Filters then
        addon.Filters:Remove(id)
    end

    for _, listeners in pairs(self.listeners) do
        listeners[id] = nil
    end
end

function Extensions:Context(id)
    return {
        version = 1,
        GetSettings = function()
            local profile = Chatter.db.global
            profile.extensionSettings = profile.extensionSettings or {}
            profile.extensionSettings[id] = profile.extensionSettings[id] or {}
            return profile.extensionSettings[id]
        end,

        On = function(event, callback)
            if not events[event] or type(callback) ~= "function" then
                return nil, L["Unsupported event or callback"]
            end

            self.listeners[event] = self.listeners[event] or {}
            self.listeners[event][id] = self.listeners[event][id] or {}
            local list = self.listeners[event][id]
            list[#list + 1] = callback
            return true
        end,

        RegisterTheme = function(name, definition)
            if type(name) ~= "string" or not name:match("^[%w_-]+$") then
                return nil, L["Invalid theme ID"]
            end

            local themeID = id .. "_" .. name
            local current = addon.Theme.presets[themeID]
            if current and current.owner == id then
                return themeID
            end

            local ok, err = addon.Theme:Register(themeID, definition, id)
            return ok and themeID or nil, err
        end,
    }
end

function Extensions:Activate(id)
    local entry = self.entries[id]
    if not entry or entry.active or entry.transitioning or not self.started then
        return
    end

    if not self:InitializeEntry(id) then
        return
    end

    local profile = Chatter.db.global
    local enabled = profile.extensions and profile.extensions[id]
    if enabled == false or (enabled == nil and entry.module and entry.module.defaultEnabled == false) then
        return
    end

    entry.error = nil
    entry.transitioning = true
    entry.active = true
    local callback = entry.module and entry.module.OnEnable or entry.spec.onEnable
    local ok, err = true, nil
    if callback then
        ok, err = pcall(callback, entry.module or entry.context)
    end

    entry.transitioning = nil
    if ok then
        if not self.started or (profile.extensions and profile.extensions[id] == false) then
            self:Deactivate(id)
        end
    else
        entry.active = false
        entry.error = tostring(err)
        self:RemoveListeners(id)
        local cleanup = entry.module and entry.module.OnDisable or entry.spec.onDisable
        if cleanup then
            pcall(cleanup, entry.module or entry.context)
        end

        self:RemoveListeners(id)
    end
end

function Extensions:Deactivate(id)
    local entry = self.entries[id]
    if not entry then
        return
    end

    local wasActive = entry.active
    entry.active = false
    self:RemoveListeners(id)
    local callback = entry.module and entry.module.OnDisable or entry.spec.onDisable
    if wasActive and callback then
        local ok, err = pcall(callback, entry.module or entry.context)
        if not ok then
            entry.error = tostring(err)
        end
    end

    self:RemoveListeners(id)
end

function Extensions:SetEnabled(id, value)
    if not self.entries[id] then
        return nil, L["Unknown extension"]
    end

    local profile = Chatter.db.global
    profile.extensions = profile.extensions or {}
    profile.extensions[id] = value == true
    if not self.entries[id].transitioning then
        if value then
            self.entries[id].initFailed = nil
            self:Activate(id)
        else
            self:Deactivate(id)
        end
    end

    if addon.Settings then
        addon.Settings:Refresh()
    end

    return true
end

function Extensions:Register(id, spec)
    if type(id) ~= "string" or not id:match("^[%w_-]+$") then
        return nil, L["Invalid extension ID"]
    end

    if self.entries[id] then
        return nil, L["Extension ID already registered"]
    end

    if type(spec) ~= "table" or type(spec.name) ~= "string" or spec.name == "" then
        return nil, L["An extension needs a name"]
    end

    for _, key in ipairs({ "onEnable", "onDisable" }) do
        if spec[key] ~= nil and type(spec[key]) ~= "function" then
            return nil, string.format(L["%s must be a function"], key)
        end
    end

    if
        spec.options ~= nil
        and (type(spec.options) ~= "table" or spec.options.type ~= "group" or type(spec.options.args) ~= "table")
    then
        return nil, L["Extension options must be an AceConfig group"]
    end

    self.entries[id] = { spec = copy(spec), active = false }
    self:Activate(id)
    if addon.Settings then
        addon.Settings:Refresh()
    end

    return true
end

function Extensions:ConversationEvent(event, conversation, extra)
    if not conversation then
        return
    end

    local payload = {
        key = conversation.key,
        name = conversation.name,
        transport = conversation.transport or (conversation.key:match("^bnet:") and "bnet" or "whisper"),
        demo = conversation.demo == true,
    }

    for key, value in pairs(extra or {}) do
        payload[key] = value
    end

    self:Emit(event, payload)
end

function Extensions:Emit(event, ...)
    local listeners = self.listeners[event]
    if not listeners then
        return
    end

    -- Each extension gets its own snapshot, not mutable conversation history.
    local arguments, count = { ... }, select("#", ...)
    for id, callbacks in pairs(listeners) do
        local entry = self.entries[id]
        if entry and entry.active then
            for _, callback in ipairs(callbacks) do
                local ok, err = pcall(callback, unpack(copy(arguments), 1, count))
                if not ok then
                    self:Deactivate(id)
                    entry.error = tostring(err)
                    if addon.Settings then
                        addon.Settings:Refresh()
                    end

                    break
                end

                if not entry.active then
                    break
                end
            end
        end
    end
end

function Extensions:Start()
    self:Initialize()
    self.started = true
    for id in pairs(self.entries) do
        self:Activate(id)
    end
end

function Extensions:Stop()
    self.started = false
    for id in pairs(self.entries) do
        self:Deactivate(id)
    end
end

function Extensions:Options()
    local args = {
        intro = {
            type = "description",
            order = 0,
            fontSize = "medium",
            name = L["Manage built-in features and integrations here. Built-in extensions come with Chatter; other extensions are installed as separate WoW addons."],
        },
    }

    local ids = {}
    for id in pairs(self.entries) do
        ids[#ids + 1] = id
    end

    table.sort(ids, function(a, b)
        local left, right = self.entries[a].spec, self.entries[b].spec
        if (left.builtin == true) ~= (right.builtin == true) then
            return left.builtin == true
        end

        if left.name == right.name then
            return a < b
        end

        return left.name < right.name
    end)

    args.summary = {
        type = "description",
        order = 0.5,
        name = function()
            local active = 0
            for _, entry in pairs(self.entries) do
                if entry.active then
                    active = active + 1
                end
            end

            return string.format(
                L["%d available · %d enabled. Select an extension to view its settings."],
                #ids,
                active
            )
        end,
    }

    if #ids == 0 then
        args.empty = {
            type = "description",
            order = 1,
            name = L["No extensions registered. Theme packs and integrations will appear here when installed."],
        }
    end

    for index, id in ipairs(ids) do
        local extensionID, entry = id, self.entries[id]
        local spec = entry.spec
        local controls = {
            description = {
                type = "description",
                order = 1,
                name = (spec.builtin and L["Included with Chatter.\n"] or "")
                    .. (spec.description or "")
                    .. (spec.version and ("\n" .. string.format(L["Version %s"], tostring(spec.version))) or ""),
            },

            enabled = {
                type = "toggle",
                name = L["Enable extension"],
                order = 2,
                width = "full",
                get = function()
                    return self:IsEnabled(extensionID)
                end,

                set = function(_, value)
                    self:SetEnabled(extensionID, value)
                end,
            },

            status = {
                type = "description",
                order = 3,
                name = function()
                    return entry.error and string.format(L["Extension stopped: %s"], entry.error)
                        or (entry.active and L["Active"] or L["Disabled"])
                end,
            },
        }

        if spec.options then
            controls.settings = copy(spec.options)
            controls.settings.order, controls.settings.inline = 4, true
            if entry.module then
                controls.settings.handler = entry.module
            end

            controls.settings.get = controls.settings.get
                or function(info)
                    return (entry.module and entry.module:GetSettings() or self:Context(extensionID).GetSettings())[info[#info]]
                end

            controls.settings.set = controls.settings.set
                or function(info, value)
                    local settings = entry.module and entry.module:GetSettings()
                        or self:Context(extensionID).GetSettings()
                    settings[info[#info]] = value
                end

            local original = controls.settings.disabled
            controls.settings.disabled = function(info)
                if not entry.active then
                    return true
                end

                if type(original) == "string" and entry.module then
                    return entry.module[original](entry.module, info)
                end

                return type(original) == "function" and original(info) or original == true
            end
        end

        args["extension_" .. id] = { type = "group", name = spec.name, order = index, args = controls }
    end

    local overviewControls = {}
    for index, id in ipairs(ids) do
        local group = args["extension_" .. id]
        local toggle = group.args.enabled
        toggle.name = self.entries[id].spec.name
        toggle.desc = self.entries[id].spec.description
        toggle.order = index + 3
        overviewControls[id] = toggle
        group.args.enabled = nil
    end

    args.overview = {
        type = "group",
        inline = true,
        name = L["Extensions"],
        order = -1,
        args = {
            intro = args.intro,
            summary = args.summary,
            empty = args.empty,
            navigation = {
                type = "description",
                order = 2,
                name = L["Select an extension in the navigation here to adjust its settings."],
            },
        },
    }

    for id, toggle in pairs(overviewControls) do
        args.overview.args["enable_" .. id] = toggle
    end

    args.intro, args.summary, args.empty = nil, nil, nil
    return { type = "group", name = L["Extensions"], childGroups = "tree", args = args }
end

-- Available to dependent addons once Chatter's files have loaded.
Chatter.API = {
    version = 2,
    NewExtension = function(id, metadata)
        return Extensions:NewModule(id, metadata)
    end,

    GetExtension = function(id, silent)
        return Extensions:GetModule(id, silent)
    end,

    GetEvents = function()
        local names = {}
        for event in pairs(events) do
            names[#names + 1] = event
        end

        table.sort(names)
        return names
    end,

    RegisterExtension = function(id, spec)
        return Extensions:Register(id, spec)
    end,

    RegisterTheme = function(id, definition)
        return addon.Theme:Register(id, definition)
    end,

    IsExtensionEnabled = function(id)
        return Extensions:IsEnabled(id)
    end,
}

-- Colon-method entry points mirror the AceAddon module workflow without sharing
-- AceAddon's automatic lifecycle (Chatter settings own extension activation).
function Chatter:NewExtension(id, metadata)
    return Extensions:NewModule(id, metadata)
end

function Chatter:GetExtension(id, silent)
    return Extensions:GetModule(id, silent)
end

function Chatter:EnableExtension(id)
    return Extensions:SetEnabled(id, true)
end

function Chatter:DisableExtension(id)
    return Extensions:SetEnabled(id, false)
end

function Chatter:IterateExtensions()
    local id
    return function()
        repeat
            id = next(Extensions.entries, id)
            if not id then
                return
            end
        until Extensions.entries[id].module
        return id, Extensions.entries[id].module
    end
end
