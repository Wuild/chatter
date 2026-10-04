local function equal(a, b, label)
    assert(a == b, label .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end

WOW_PROJECT_MAINLINE = 1
WOW_PROJECT_CLASSIC = 2
WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5
WOW_PROJECT_WRATH_CLASSIC = 11
WOW_PROJECT_CATACLYSM_CLASSIC = 14
WOW_PROJECT_MISTS_CLASSIC = 19
strtrim = function(text)
    return text:match("^%s*(.-)%s*$")
end

local cases = {
    { 16001, 2, "forever", true },
    { 120100, 1, "retail", false },
    { 11509, 2, "era", false },
    { 20506, 5, "tbc", false },
    { 38002, 11, "wrath", false },
    { 40402, 14, "cata", false },
    { 50504, 19, "mists", false },
    { 99999, 99, "standard", false },
}

for _, case in ipairs(cases) do
    GetBuildInfo = function()
        return "version", "build", "date", case[1], "additional build data"
    end

    WOW_PROJECT_ID = case[2]
    local addon = {}
    assert(loadfile("tests/support/locale.lua"))(addon)
    assert(loadfile("scripts/client.lua"))("Chatter", addon)
    local client = addon.Client
    equal(client.flavor, case[3], "client detection")
    equal(client.hasLastNames, case[4], "only Forever enables last names")
    local name, draft = client.ParseCommand("  First Last hello there  ")
    equal(name, case[4] and "First Last" or "First", "flavor-aware name")
    equal(draft, case[4] and "hello there" or "Last hello there", "message is not consumed as name")
    name, draft = client.ParseCommand(case[4] and "First Last-Realm hello" or "First-Realm hello")
    equal(name, case[4] and "First Last-Realm" or "First-Realm", "realm suffix retained")
    equal(draft, "hello", "draft separated")
    equal(client.ParseCommand("  "), nil, "empty command")
    equal(client.ParseCommand("Élodie"), "Élodie", "UTF-8 name preserved")

    local opened, queue
    addon.Window = {
        Open = function(_, n, d)
            opened = { n, d }
        end,
    }

    addon.History = {}
    Chatter = {}
    assert(loadfile("scripts/main.lua"))("Chatter", addon)
    Chatter:Command(case[4] and "First Last hello there" or "First-Realm hello there")
    equal(opened[1], case[4] and "First Last" or "First-Realm", "slash command uses flavor parser")
    equal(opened[2], "hello there", "slash command preserves draft")
    C_Timer = {
        After = function(_, f)
            queue = f
        end,
    }

    local target = case[4] and "First Last-Realm" or "First-Realm"
    local box = { attributes = { chatType = "WHISPER", tellTarget = target }, text = "hello from /w" }

    function box:GetAttribute(key)
        return self.attributes[key]
    end

    function box:SetAttribute(key, value)
        self.attributes[key] = value
    end

    function box:GetText()
        return self.text
    end

    function box:SetText(text)
        self.text = text
    end

    function box:ClearFocus() end

    function box:Hide() end

    Chatter:RouteEditBox(box)
    queue()
    equal(opened[1], target, "native resolved name is never split")
    equal(opened[2], "hello from /w", "native draft preserved")
end

print("Forever, Retail, Era, Anniversary/TBC, Wrath, Cata and Mists name routing passed.")
