local _, addon = ...
local L = addon.L
local Sounds = {}
addon.Sounds = Sounds
Sounds.labels = {
    ["linux-message"] = L["Soft Ping"],
    ["linux-instant"] = L["Chime"],
    ["linux-bell"] = L["Bell"],
    ["linux-complete"] = L["All Done"],
    ["linux-information"] = L["Tick"],
    ["linux-attention"] = L["Heads Up"],
    ["linux-login"] = L["Welcome"],
    wim = L["WIM — Whisper"],
    ["wim-chat"] = L["WIM — Chat Blip"],
    supplied = L["Supplied notification"],
}

-- Keep saved selection IDs stable while asset names match the sound picker.
local filenames = {
    ["linux-message"] = "soft-ping",
    ["linux-instant"] = "chime",
    ["linux-bell"] = "bell",
    ["linux-complete"] = "all-done",
    ["linux-information"] = "tick",
    ["linux-attention"] = "heads-up",
    ["linux-login"] = "welcome",
    wim = "wim-whisper",
    ["wim-chat"] = "wim-chat-blip",
    supplied = "supplied-notification",
}

function Sounds:Path(key)
    if not self.labels[key] then
        key = "linux-message"
    end

    return "Interface\\AddOns\\Chatter\\assets\\sounds\\" .. filenames[key] .. ".ogg"
end
