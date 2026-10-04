local function scenario(legacy, saved, expected)
    local addon = {}
    assert(loadfile("tests/support/locale.lua"))(addon)
    Whispr = { db = { global = { smileys = legacy, extensions = { emoji = saved } } } }

    local function load(name)
        assert(loadfile("scripts/" .. name .. ".lua"))("Whispr", addon)
    end

    load("extensions")
    assert(loadfile("extensions/emoji/emotes.lua"))("Whispr", addon)
    assert(loadfile("extensions/emoji/renderer.lua"))("Whispr", addon)
    assert(loadfile("extensions/emoji/module.lua"))("Whispr", addon)
    addon.Extensions:Start()
    assert(addon.Extensions:IsEnabled("emoji") == expected, "migration preserves preference")
    assert(Whispr.db.global.smileys == expected, "render flag matches extension on startup")
    assert(addon.Extensions.entries.emoji.spec.builtin, "extension identified as bundled")
    addon.Extensions:Stop()
    addon.Extensions:Start()
    assert(addon.Extensions:IsEnabled("emoji") == expected, "restart preserves extension preference")
    addon.Extensions:SetEnabled("emoji", not expected)
    assert(Whispr.db.global.smileys == not expected, "extension owns renderer switch")
end

scenario(true, nil, true)
scenario(false, nil, false)
scenario(true, false, false)
scenario(false, true, true)
print("Emoji legacy migration, saved extension precedence and restart passed.")
