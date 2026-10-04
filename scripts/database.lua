local _, addon = ...
local Database = {}
addon.Database = Database

local function copy(value)
    if type(value) ~= "table" then
        return value
    end

    local result = {}
    for key, entry in pairs(value) do
        result[key] = copy(entry)
    end

    return result
end

function Database:MigrateSettings(db)
    local settings = db.global
    if settings.settingsVersion then
        return
    end

    -- AceDB resolves the current character's old profile mapping. Import once;
    -- later characters must not overwrite the shared settings with old values.
    local previous = db.profile
    for key, value in pairs(previous) do
        settings[key] = copy(value)
    end

    settings.settingsVersion = 1
end

-- Run before retention and window restoration, across all saved characters.
function Database:RemoveDemoConversations(db)
    local function clean(data)
        for key, conversation in pairs(data.conversations or {}) do
            if conversation.demo or (type(key) == "string" and key:match("^demo:")) then
                data.conversations[key] = nil
            end
        end
    end

    clean(db.char)
    for _, data in pairs(db.sv and db.sv.char or {}) do
        clean(data)
    end
end
