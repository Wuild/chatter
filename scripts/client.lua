local _, addon = ...
local Client = {}
addon.Client = Client

function Client.Detect()
    local interface = GetBuildInfo and tonumber((select(4, GetBuildInfo()))) or 0
    -- Forever uses its own 1.6 interface version, even when the underlying
    -- project constant identifies it as Classic. Check it before project IDs.
    if interface >= 16000 and interface < 17000 then
        return "forever", true
    end

    local projects = {
        { "WOW_PROJECT_MAINLINE", "retail" },
        { "WOW_PROJECT_CLASSIC", "era" },
        { "WOW_PROJECT_BURNING_CRUSADE_CLASSIC", "tbc" },
        { "WOW_PROJECT_WRATH_CLASSIC", "wrath" },
        { "WOW_PROJECT_CATACLYSM_CLASSIC", "cata" },
        { "WOW_PROJECT_MISTS_CLASSIC", "mists" },
    }

    for _, project in ipairs(projects) do
        if _G[project[1]] and WOW_PROJECT_ID == _G[project[1]] then
            return project[2], false
        end
    end

    -- Unknown official/new clients use single-token character names by default.
    return "standard", false
end

Client.flavor, Client.hasLastNames = Client.Detect()

function Client.ParseCommand(text)
    text = (text or ""):match("^%s*(.-)%s*$")
    if text == "" then
        return
    end

    if Client.hasLastNames then
        local first, last, draft = text:match("^(%S+)%s+(%S+)%s*(.*)$")
        if first then
            return first .. " " .. last, draft ~= "" and draft or nil
        end
    end

    local name, draft = text:match("^(%S+)%s*(.*)$")
    -- Keep Name-Realm intact. Battle.net and native tellTarget names are already
    -- resolved by the client and must never pass through this command parser.
    return name, draft ~= "" and draft or nil
end
