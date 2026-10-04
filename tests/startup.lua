-- An invalid event aborts AceAddon OnEnable before whisper hooks are installed.
local addon = { Window = {}, Minimap = { Enable = function() end } }
assert(loadfile("tests/support/locale.lua"))(addon)
assert(loadfile("scripts/history.lua"))("Whispr", addon)
Whispr = {
    db = {
        char = {
            conversations = {
                empty = { messages = {} },
                sent = { messages = { { text = "hello", outgoing = true } } },
                received = { messages = { { text = "hi" } } },
            },
        },
    },
}

assert(loadfile("scripts/main.lua"))("Whispr", addon)
local supported = {
    PLAYER_LOGOUT = true,
    PLAYER_REGEN_DISABLED = true,
    PLAYER_REGEN_ENABLED = true,
    CHAT_MSG_WHISPER = true,
    CHAT_MSG_WHISPER_INFORM = true,
    CHAT_MSG_BN_WHISPER = true,
    CHAT_MSG_BN_WHISPER_INFORM = true,
    CHAT_MSG_AFK = true,
    CHAT_MSG_DND = true,
    PLAYER_ENTERING_WORLD = true,
    PLAYER_TARGET_CHANGED = true,
    UPDATE_MOUSEOVER_UNIT = true,
    GROUP_ROSTER_UPDATE = true,
    FRIENDLIST_UPDATE = true,
    GUILD_ROSTER_UPDATE = true,
    PLAYER_FOCUS_CHANGED = true,
    UNIT_LEVEL = true,
    UNIT_NAME_UPDATE = true,
}

local registered, refreshed, hooked = {}, false, false

function Whispr:RegisterEvent(event, handler)
    assert(supported[event], "Unsupported startup event: " .. event)
    registered[event] = handler
end

function Whispr:InstallChatFilters() end

function Whispr:RefreshCharacters()
    refreshed = true
end

function Whispr:HookWhispers()
    hooked = true
end

Whispr:OnEnable()
assert(Whispr.running and refreshed and hooked, "startup must reach metadata refresh and whisper hooks")
assert(registered.GUILD_ROSTER_UPDATE, "guild metadata still refreshes on roster changes")
print("Startup event validation and whisper hook installation passed.")

local geometrySaved = false
addon.Window.SaveAllGeometry = function()
    assert(Whispr.db.char.conversations.empty, "empty chats remain until persistence cleanup")
    geometrySaved = true
end

registered.PLAYER_LOGOUT()
assert(geometrySaved, "window geometry saved before history cleanup")
assert(not Whispr.db.char.conversations.empty, "empty chats discarded on reload/logout")
assert(Whispr.db.char.conversations.sent and Whispr.db.char.conversations.received, "both message directions persist")
print("Reload/logout retains message history and discards empty conversations.")

local restored = false
addon.Window.RestoreUndocked = function()
    restored = true
end

registered.PLAYER_ENTERING_WORLD()
assert(restored, "world entry restores saved undocked state")
