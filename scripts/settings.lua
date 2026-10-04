local _, addon = ...
local L = addon.L
local Settings = {}
addon.Settings = Settings
Settings.categories = {
    {
        "general",
        L["General"],
        L["Settings are shared across all your characters. Choose how Chatter opens and behaves while you play."],
    },

    { "messages", L["Messages"], L["Control message formatting, previews and typing indicators."] },
    { "appearance", L["Appearance"], L["Adjust readability, transparency and animations."] },
    { "themes", L["Themes"], L["Choose a palette, then fine-tune individual colors."] },
    { "notifications", L["Notifications"], L["Choose the sound for incoming whispers."] },
    { "history", L["History"], L["Manage how much conversation history Chatter keeps."] },
    { "extensions", L["Extensions"], L["Enable extensions here. Open their pages in the menu to adjust settings."] },
    { "debug", L["Debug"], L["Test messages, notifications and typing locally."] },
}

local function option(kind, name, order, description)
    return { type = kind, name = name, order = order, desc = description, width = kind == "toggle" and "full" or nil }
end

local function refreshMessages()
    addon.Media:Refresh()
end

local function refreshCards()
    addon.Window:RefreshList()
    for _, window in pairs(addon.Window.popouts or {}) do
        window:RefreshList()
    end
end

function Settings:Options()
    local profile = Chatter.db.global
    local general = {
        showAllCharacters = option(
            "toggle",
            L["Show conversations from all characters"],
            1.3,
            L["Combine saved conversations with the same person across characters. Outgoing messages identify the character who sent them."]
        ),
        separateWindows = option(
            "toggle",
            L["Separate conversation windows"],
            1,
            L["Open each conversation in its own window."]
        ),
        autoOpenConversations = option(
            "toggle",
            L["Automatically open conversations"],
            1.1,
            L["Open hidden conversation windows when a whisper arrives. Turn off to keep messages in the background."]
        ),
        autoSelectIncoming = option(
            "toggle",
            L["Automatically select incoming conversations"],
            1.2,
            L["Switch to the sender only when the current message input does not have keyboard focus. While the input is focused, keep the current conversation selected, even when it is empty."]
        ),
        suppressWhispers = option(
            "toggle",
            L["Keep whispers in Chatter"],
            2,
            L["Hide duplicate whispers in normal chat. Delivery errors stay visible."]
        ),
        hideInCombat = option(
            "toggle",
            L["Hide when entering combat"],
            4,
            L["Hide open windows when combat starts and restore them when combat ends. You can still open a window manually during combat."]
        ),
        dontHideWhenTyping = option(
            "toggle",
            L["Don't hide when typing"],
            4.5,
            L["Keep a window open if its message input has keyboard focus when combat starts. An unfocused saved draft does not keep it open."]
        ),
        noOpenInCombat = option(
            "toggle",
            L["Keep new whispers in the background"],
            5,
            L["Messages are still saved. Existing windows remain visible."]
        ),
    }

    general.showAllCharacters.set = function(_, value)
        profile.showAllCharacters = value
        addon.History.Invalidate()

        local function update(window)
            window.firstMessageID = nil
            window.messageRows = nil
            if window.frame then
                if window.active and not addon.History.Get(window.active) then
                    window:Select(nil)
                end

                window:RefreshList()
                window:RefreshMessages(true)
            end
        end

        update(addon.Window)
        for _, window in pairs(addon.Window.popouts or {}) do
            update(window)
        end
    end

    general.separateWindows.set = function(_, value)
        addon.Window:SetSeparateMode(value)
    end

    general.autoSelectIncoming.disabled = function()
        return profile.separateWindows
    end

    general.dontHideWhenTyping.disabled = function()
        return not profile.hideInCombat
    end

    for _, key in ipairs({ "hideInCombat", "dontHideWhenTyping", "noOpenInCombat" }) do
        local setting = key
        general[key].set = function(_, value)
            profile[setting] = value
            addon.Window:CombatChanged(InCombatLockdown())
        end
    end

    local messages = {
        timestamps = option("toggle", L["Message times"], 2, L["Show when each message was sent."]),
        outgoingOnRight = option(
            "toggle",
            L["Outgoing messages on the right"],
            2.5,
            L["Turn off to align every message on the left. Sender names and colors still distinguish replies."]
        ),
        showMessagePreviews = option(
            "toggle",
            L["Conversation previews"],
            3,
            L["Show the latest message below each conversation name."]
        ),
        typingIndicators = option(
            "toggle",
            L["Share and show typing indicators"],
            5,
            L["Only Chatter peers receive typing status. Draft text is never sent."]
        ),
    }

    messages.showMessagePreviews.set = function(_, v)
        profile.showMessagePreviews = v
        refreshCards()
    end

    messages.typingIndicators.set = function(_, v)
        profile.typingIndicators = v
        if v then
            addon.Typing:Enable()
        else
            addon.Typing:Disable()
        end
    end

    local allAppearance = addon.Theme:Options().args
    local appearance = {
        typography = {
            type = "group",
            name = L["Text"],
            inline = true,
            order = 1,
            args = {
                chatFont = {
                    type = "select",
                    name = L["Font"],
                    order = 1,
                    values = function()
                        return addon.Media:Fonts()
                    end,
                },

                chatFontSize = { type = "range", name = L["Text size"], min = 10, max = 28, step = 1, order = 2 },
                chatShadow = option("toggle", L["Text shadow"], 3),
                chatShadowColor = {
                    type = "color",
                    name = L["Shadow color"],
                    hasAlpha = true,
                    order = 4,
                    disabled = function()
                        return not profile.chatShadow
                    end,

                    get = function()
                        return unpack(profile.chatShadowColor)
                    end,

                    set = function(_, r, g, b, a)
                        profile.chatShadowColor = { r, g, b, a }
                        refreshMessages()
                    end,
                },
            },

            set = function(info, v)
                profile[info[#info]] = v
                refreshMessages()
            end,
        },

        windows = {
            type = "group",
            name = L["Windows"],
            inline = true,
            order = 2,
            args = {},
            set = function(info, v)
                profile[info[#info]] = v
                addon.Theme:Refresh()
            end,
        },
    }

    for _, key in ipairs({
        "backgroundOpacity",
        "windowOpacity",
        "fadeWhenIdle",
        "idleOpacity",
        "idleFadeDelay",
        "animateWindows",
    }) do
        appearance.windows.args[key] = allAppearance[key]
    end

    local themes = {
        themePreset = {
            type = "select",
            name = L["Theme preset"],
            order = 1,
            width = "double",
            values = function()
                return addon.Theme:Values()
            end,

            get = function()
                return addon.Theme:CurrentPreset()
            end,

            set = function(_, id)
                if id ~= "custom" then
                    addon.Theme:Apply(id)
                end
            end,
        },

        hint = {
            type = "description",
            order = 2,
            name = L["Presets change colors only. Your fonts, opacity and chat behavior stay as they are. Changing an individual color creates a custom palette."],
        },

        colors = { type = "group", name = L["Customize colors"], inline = true, order = 3, args = {} },
        resetAppearance = allAppearance.resetAppearance,
    }

    themes.resetAppearance.order = 4
    for key in pairs(addon.Theme.defaults) do
        themes.colors.args[key] = allAppearance[key]
    end

    local notifications = {
        notificationSoundEnabled = option(
            "toggle",
            L["Play notification sounds"],
            0.5,
            L["Play a sound when a whisper arrives. Preview still plays sounds when this is off."]
        ),
        notificationSound = {
            type = "select",
            name = L["Incoming whisper sound"],
            order = 1,
            width = "double",
            values = function()
                return addon.Sounds.labels
            end,

            set = function(_, v)
                profile.notificationSound = v
                Chatter:PlayMessageSound(true)
            end,
        },

        previewSound = {
            type = "execute",
            name = L["Play preview"],
            order = 2,
            func = function()
                Chatter:PlayMessageSound(true)
            end,
        },
    }

    local history = {
        maxPeople = { type = "range", name = L["Conversations to keep"], min = 1, max = 200, step = 1, order = 1 },
        maxMessages = {
            type = "range",
            name = L["Messages per conversation"],
            min = 10,
            max = 1000,
            step = 10,
            order = 2,
        },

        retention = {
            type = "description",
            order = 3,
            name = L["Lowering these limits immediately removes the oldest saved history. Opening a conversation still loads only 20 messages at a time."],
        },
    }

    local function section(name, order, source, keys)
        local args = {}
        for _, key in ipairs(keys) do
            args[key] = source[key]
        end

        return { type = "group", name = name, inline = true, order = order, args = args }
    end

    general = {
        conversations = section(L["Conversations"], 1, general, {
            "separateWindows",
            "autoOpenConversations",
            "autoSelectIncoming",
            "showAllCharacters",
            "suppressWhispers",
        }),

        combat = section(L["During combat"], 2, general, { "hideInCombat", "dontHideWhenTyping", "noOpenInCombat" }),
        separateSize = {
            type = "group",
            name = L["Separate window size"],
            inline = true,
            order = 3,
            args = {
                hint = {
                    type = "description",
                    order = 0,
                    name = L["Default size for new undocked and separate conversation windows. Existing saved sizes are preserved."],
                },

                separateWindowWidth = {
                    type = "range",
                    name = L["Default width"],
                    min = 360,
                    max = 1600,
                    step = 10,
                    order = 1,
                },

                separateWindowHeight = {
                    type = "range",
                    name = L["Default height"],
                    min = 280,
                    max = 1200,
                    step = 10,
                    order = 2,
                },

                apply = {
                    type = "execute",
                    name = L["Apply to open separate windows"],
                    order = 3,
                    width = "full",
                    func = function()
                        addon.Window:ApplySeparateSize()
                    end,
                },
            },
        },
    }

    messages = {
        layout = section(
            L["Layout and previews"],
            1,
            messages,
            { "outgoingOnRight", "timestamps", "showMessagePreviews" }
        ),
        presence = section(L["Typing indicators"], 3, messages, { "typingIndicators" }),
    }

    local options = {
        type = "group",
        name = "Chatter",
        childGroups = "tree",
        get = function(info)
            return profile[info[#info]]
        end,

        set = function(info, v)
            profile[info[#info]] = v
        end,

        args = {
            general = { type = "group", name = L["General"], order = 1, args = general },
            messages = {
                type = "group",
                name = L["Messages"],
                order = 2,
                args = messages,
                set = function(info, v)
                    profile[info[#info]] = v
                    refreshMessages()
                end,
            },

            appearance = { type = "group", name = L["Appearance"], order = 3, args = appearance },
            themes = { type = "group", name = L["Themes"], order = 4, args = themes },
            notifications = { type = "group", name = L["Notifications"], order = 5, args = notifications },
            history = {
                type = "group",
                name = L["History"],
                order = 6,
                args = history,
                set = function(info, v)
                    profile[info[#info]] = v
                    addon.History.Trim(Chatter.db.char, profile)
                    addon.Window:Refresh(addon.Window.active)
                end,
            },

            extensions = addon.Extensions:Options(),
            debug = addon.Debug:Options(),
        },
    }

    options.args.extensions.order = 7
    for _, category in ipairs(self.categories) do
        options.args[category[1]].args.categoryDescription = {
            type = "description",
            name = category[3],
            order = 0,
            fontSize = "medium",
        }
    end

    return options
end

function Settings:Initialize()
    if self.panels then
        return
    end

    LibStub("AceConfig-3.0"):RegisterOptionsTable("Chatter", function()
        return self:Options()
    end)

    local dialog = LibStub("AceConfigDialog-3.0")
    dialog:SetDefaultSize("Chatter", 840, 580)
    -- Keep Blizzard's AddOns list compact; the full tree belongs to our window.
    LibStub("AceConfig-3.0"):RegisterOptionsTable("ChatterLauncher", {
        type = "group",
        name = "Chatter",
        args = {
            open = {
                type = "execute",
                name = L["Open settings"],
                order = 1,
                width = "double",
                func = function()
                    if SettingsPanel and SettingsPanel:IsShown() then
                        HideUIPanel(SettingsPanel)
                    end

                    if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
                        HideUIPanel(InterfaceOptionsFrame)
                    end

                    self:Show()
                end,
            },
        },
    })

    local panel, id = dialog:AddToBlizOptions("ChatterLauncher", "Chatter")
    self.panels = { launcher = { frame = panel, id = id } }
end

function Settings:Refresh()
    if self.panels then
        LibStub("AceConfigRegistry-3.0"):NotifyChange("Chatter")
    end
end

function Settings:Show()
    self:Initialize()
    local focused = addon.Window.focusedWindow
    if focused then
        focused:SetWindowFocus(false)
    end

    LibStub("AceConfigDialog-3.0"):Open("Chatter")
end

-- Resolve the active widget each time: AceGUI releases and pools closed frames.
function Settings:IsShown()
    local widget = LibStub("AceConfigDialog-3.0").OpenFrames.Chatter
    return widget and widget.frame:IsShown() or false
end
