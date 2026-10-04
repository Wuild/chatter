local function scenario(legacy, saved, expected)
    local addon = {}
    assert(loadfile("tests/support/locale.lua"))(addon)
    Chatter = { db = { global = { smileys = legacy, extensions = { emoji = saved } } } }

    local function load(name)
        assert(loadfile("scripts/" .. name .. ".lua"))("Chatter", addon)
    end

    load("extensions")
    assert(loadfile("extensions/emoji/emotes.lua"))("Chatter", addon)
    assert(loadfile("extensions/emoji/renderer.lua"))("Chatter", addon)
    assert(loadfile("extensions/emoji/module.lua"))("Chatter", addon)
    addon.Extensions:Start()
    assert(addon.Extensions:IsEnabled("emoji") == expected, "migration preserves preference")
    assert(Chatter.db.global.smileys == expected, "render flag matches extension on startup")
    assert(addon.Extensions.entries.emoji.spec.builtin, "extension identified as bundled")
    addon.Extensions:Stop()
    addon.Extensions:Start()
    assert(addon.Extensions:IsEnabled("emoji") == expected, "restart preserves extension preference")
    addon.Extensions:SetEnabled("emoji", not expected)
    assert(Chatter.db.global.smileys == not expected, "extension owns renderer switch")
end

scenario(true, nil, true)
scenario(false, nil, false)
scenario(true, false, false)
scenario(false, true, true)
print("Emoji legacy migration, saved extension precedence and restart passed.")
