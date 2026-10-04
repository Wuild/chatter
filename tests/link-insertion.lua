local addon = {}
assert(loadfile("tests/support/locale.lua"))(addon)
local focused, hooks, timers
addon.Window = {
    FocusedInput = function()
        return focused
    end,
}

Whispr = {}
assert(loadfile("scripts/main.lua"))("Whispr", addon)
C_Timer = {
    After = function(_, callback)
        timers[#timers + 1] = callback
    end,
}

hooksecurefunc = function(owner, method, callback)
    if type(owner) == "table" then
        hooks.modern = callback
    else
        hooks.legacy = method
    end
end

local function editor()
    return {
        text = "",
        Insert = function(self, text)
            self.text = self.text .. text
        end,

        GetText = function(self)
            return self.text
        end,
    }
end

local function flush()
    for _, callback in ipairs(timers) do
        callback()
    end

    timers = {}
end

local spell = "|cff71d5ff|Hspell:116|h[Frostbolt]|h|r"
local talent = "|cff4e96f7|Htalent:123:1|h[Talent]|h|r"
for _, flavor in ipairs({ "modern", "legacy", "both" }) do
    hooks, timers = {}, {}
    ChatFrameUtil = flavor ~= "legacy" and { InsertLink = function() end } or nil
    ChatEdit_InsertLink = flavor ~= "modern" and function() end or nil
    Whispr:HookWhispers()
    focused = editor()
    local insert = hooks.modern or hooks.legacy
    insert(spell)
    assert(focused.text == spell, "spell payload is inserted intact on " .. flavor)
    if hooks.modern and hooks.legacy then
        hooks.legacy(spell)
        assert(focused.text == spell, "forwarding through both APIs does not duplicate links")
    end

    flush()
    insert(talent)
    assert(focused.text == spell .. talent, "talent payload is inserted intact on " .. flavor)
    flush()
    insert(talent)
    assert(focused.text == spell .. talent .. talent, "separate repeat clicks remain valid")
    insert(nil)
    insert(123)
    local previous = focused
    focused = nil
    insert(spell)
    assert(previous.text == spell .. talent .. talent, "other editors do not send links into Whispr")
end

print("Modern and legacy spell/talent insertion, forwarding deduplication and inactive input isolation passed.")
