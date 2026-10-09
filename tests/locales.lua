local function boot(locale, englishOnly, settings, deferred)
    LibStub = nil
    GetLocale = function()
        return locale
    end

    geterrorhandler = function()
        return function(message)
            error(message)
        end
    end

    assert(loadfile("scripts/libraries/LibStub/LibStub.lua"))()
    assert(loadfile("scripts/libraries/AceLocale-3.0/AceLocale-3.0.lua"))()
    local addon = {}
    assert(loadfile("scripts/locale.lua"))("Whispr", addon)
    assert(loadfile("locales/enUS.lua"))("Whispr", addon)
    if not englishOnly then
        assert(loadfile("locales/deDE.lua"))("Whispr", addon)
    end

    if not deferred then
        addon.Locale:Initialize(settings or {})
    end

    return addon
end

for _, locale in ipairs({
    "enUS",
    "enGB",
    "deDE",
    "frFR",
    "esES",
    "esMX",
    "itIT",
    "ptBR",
    "ruRU",
    "koKR",
    "zhCN",
    "zhTW",
}) do
    local addon = boot(locale)
    local german = locale == "deDE"
    assert(addon.L["Settings"] == (german and "Einstellungen" or "Settings"), "locale selection on " .. locale)
    assert(
        string.format(addon.L["Message %s..."], "Player")
            == (german and "Nachricht an Player..." or "Message Player..."),
        "name placeholders"
    )
    assert(
        string.format(addon.L["Unread messages: %d"], 3)
            == (german and "Ungelesene Nachrichten: 3" or "Unread messages: 3"),
        "count placeholders"
    )
    if german then
        assert(addon.L["%B %d, %Y"] == "%d. %B %Y", "German day-month-year order")
        assert(addon.L["Attach to HUD"] == "Am HUD befestigen", "German HUD setting")
        assert(addon.L["Keep windows on screen"] == "Fenster auf dem Bildschirm halten", "German clamp setting")
    end
end

-- Isolate a partial catalog to test fallback independently of the complete German file.
local addon = boot("deDE", true)
local translated = addon.Locale:Register("deDE")
addon.Locale.selected = "deDE"
translated["Messages"] = "Nachrichten"
translated["Forest"] = "Wald"
translated["Emoji"] = "Emojis"
translated["Game default"] = "Spielstandard"
translated["Floating button"] = "Schwebende Schaltfläche"
translated["Rounded"] = "Abgerundet"
translated["Attach to HUD"] = "Am HUD befestigen"
translated["Keep windows on screen"] = "Fenster auf dem Bildschirm halten"
translated["Hey! Still up for a dungeon tonight? :)"] = "Heute Abend noch Lust auf einen Dungeon? :)"
translated["%s (%d)"] = "%s: %d ungelesen"
assert(
    addon.L["Messages"] == "Nachrichten" and addon.L["Themes"] == "Themes",
    "partial locale overrides with English fallback"
)
Whispr = { db = { global = { chatFont = "Game default" } } }
assert(loadfile("scripts/theme.lua"))("Whispr", addon)
assert(loadfile("tests/support/themes.lua"))(addon)
assert(loadfile("scripts/extensions.lua"))("Whispr", addon)
assert(loadfile("extensions/emoji/emotes.lua"))("Whispr", addon)
assert(loadfile("extensions/emoji/renderer.lua"))("Whispr", addon)
assert(loadfile("extensions/emoji/module.lua"))("Whispr", addon)
assert(loadfile("scripts/debug.lua"))("Whispr", addon)
assert(loadfile("scripts/settings.lua"))("Whispr", addon)
assert(loadfile("extensions/notification/module.lua"))("Whispr", addon)
assert(loadfile("extensions/floating-button/module.lua"))("Whispr", addon)
addon.Extensions:Initialize()
local floating = Whispr:GetExtension("floating_button")
assert(floating.name == "Schwebende Schaltfläche", "floating button name translates")
assert(floating.options.args.style.values.rounded == "Abgerundet", "style label translates while saved ID stays stable")
assert(floating:GetSettings().style == "rounded", "translated style does not change saved default")
assert(
    Whispr:GetExtension("notification").options.args.attachToHUD.name == "Am HUD befestigen",
    "HUD attachment option translates"
)
assert(
    addon.Settings:Options().args.general.args.conversations.args.clampWindowsToScreen.name
        == "Fenster auf dem Bildschirm halten",
    "screen clamping option translates"
)
assert(
    string.format(addon.L["%s (%d)"], "Friend", 3) == "Friend: 3 ungelesen",
    "unread label supports translated format"
)
assert(addon.Theme:Values().forest == "Wald", "theme label translates while preset ID stays stable")
assert(
    addon.Settings:Options().args.messages.name == "Nachrichten",
    "settings category translates while path stays stable"
)
assert(
    addon.Extensions.entries.emoji.spec.name == "Emojis",
    "built-in extension label translates while ID stays stable"
)
local realStub = LibStub
LibStub = function(name)
    if name == "LibSharedMedia-3.0" then
        return {
            HashTable = function()
                return {}
            end,
        }
    end

    return realStub(name)
end

assert(loadfile("scripts/media.lua"))("Whispr", addon)
assert(
    addon.Media:Fonts()["Game default"] == "Spielstandard",
    "font label translates while saved font key stays stable"
)
LibStub = realStub
addon.developmentMode = true
Whispr.db.char = { conversations = {}, sequence = 0 }
addon.History = { Invalidate = function() end }
addon.Window = { Open = function() end, RefreshList = function() end }
time = function()
    return 10000
end

assert(loadfile("scripts/screenshots.lua"))("Whispr", addon)
addon.Screenshots:Create()
local sample = Whispr.db.char.conversations["demo:screenshot:aeloria"]
assert(sample.name == "Aeloria" and sample.character.classFile == "DRUID", "sample identities remain stable")
assert(sample.messages[1].text == "Heute Abend noch Lust auf einen Dungeon? :)", "sample dialogue translates")

-- Every lookup in a TOC-loaded module must have an explicit English entry.
local english = boot("enUS").Locale.catalogs.enUS
local catalog = assert(io.open("locales/enUS.lua"))
local declarations = {}
for literal in catalog:read("*a"):gmatch('L%[(".-")%]%s*=') do
    local key = assert(loadstring("return " .. literal))()
    assert(not declarations[key], "duplicate English entry: " .. key)
    declarations[key] = true
end

catalog:close()
local toc = assert(io.open("Whispr.toc")):read("*a")
local seen, count = {}, 0
for path in toc:gmatch("[^\r\n]+") do
    if path:match("^scripts\\.*%.lua$") or path:match("^extensions\\.*%.lua$") or path:match("^themes\\.*%.lua$") then
        path = path:gsub("\\", "/")
        local file = assert(io.open(path))
        local source = file:read("*a")
        file:close()
        for literal in source:gmatch('L%[(".-")%]') do
            local key = assert(loadstring("return " .. literal))()
            assert(rawget(english, key) ~= nil, path .. ": missing English locale entry: " .. key)
            if not seen[key] then
                seen[key] = true
                count = count + 1
            end
        end
    end
end

assert(count > 190, "catalog covers core UI, settings, themes and extensions")
for key in pairs(english) do
    assert(seen[key], "obsolete English entry: " .. key)
end

print("AceLocale English fallback, partial translations, stable IDs and " .. count .. " catalog lookups passed.")

-- Capture declarations separately from AceLocale's fallback table so missing
-- translations cannot silently pass as English, and duplicate keys are rejected.
local function catalogEntries(path, locale)
    local entries = {}
    local capture = setmetatable({}, {
        __newindex = function(_, key, value)
            assert(entries[key] == nil, path .. ": duplicate key " .. key)
            assert(type(value) == "string" and value ~= "", path .. ": translation must be nonempty")
            entries[key] = value
        end,
    })

    local namespace = {
        Locale = {
            Register = function(_, code)
                assert(code == locale, "locale registration")
                return capture
            end,
        },
    }

    assert(loadfile(path))("Whispr", namespace)
    return entries
end

local german = catalogEntries("locales/deDE.lua", "deDE")

local function formats(text)
    local parts = {}
    for specifier in text:gmatch("%%[%-+ #0%d%.]*[cdeEfgGiouXxqs]") do
        parts[#parts + 1] = specifier
    end

    return table.concat(parts, ",")
end

for key in pairs(english) do
    assert(german[key], "missing German translation: " .. key)
    if key ~= "%B %d, %Y" and key ~= "%H:%M" then
        assert(formats(key) == formats(german[key]), "German format placeholder mismatch: " .. key)
    end

    local _, sourceNewlines = key:gsub("\n", "")
    local _, translatedNewlines = german[key]:gsub("\n", "")
    assert(sourceNewlines == translatedNewlines, "German newline mismatch: " .. key)
end

for key in pairs(german) do
    assert(rawget(english, key) ~= nil, "obsolete German translation: " .. key)
end

assert(toc:find("locales\\enUS.lua", 1, true) < toc:find("locales\\deDE.lua", 1, true), "base locale loads first")
assert(
    toc:find("scripts\\locale.lua", 1, true) < toc:find("locales\\enUS.lua", 1, true),
    "locale registry loads before catalogs"
)
print("Complete German catalog, placeholders, newlines and TOC order passed.")

for _, case in ipairs({
    { "enUS", "deDE", "Einstellungen", "deDE" },
    { "deDE", "enUS", "Settings", "enUS" },
    { "deDE", "auto", "Einstellungen", "deDE" },
    { "frFR", "auto", "Settings", "enUS" },
    { "deDE", "invalid", "Einstellungen", "deDE" },
}) do
    local chosen = boot(case[1], false, nil, true)
    Whispr = { db = { global = { locale = case[2], chatFont = "Game default" } } }
    assert(loadfile("scripts/theme.lua"))("Whispr", chosen)
    assert(loadfile("tests/support/themes.lua"))(chosen)
    assert(loadfile("scripts/extensions.lua"))("Whispr", chosen)
    assert(loadfile("extensions/floating-button/module.lua"))("Whispr", chosen)
    assert(loadfile("extensions/notification/module.lua"))("Whispr", chosen)
    assert(loadfile("scripts/sounds.lua"))("Whispr", chosen)
    assert(loadfile("scripts/debug.lua"))("Whispr", chosen)
    assert(loadfile("scripts/settings.lua"))("Whispr", chosen)
    assert(chosen.Extensions.entries.floating_button == nil, "localized registration waits for saved settings")
    chosen.Locale:Initialize(Whispr.db.global)
    chosen.Extensions:Initialize()
    assert(
        chosen.L["Settings"] == case[3] and chosen.Locale.selected == case[4],
        "saved language overrides game locale"
    )
    assert(chosen.Theme.presets.forest.name == chosen.L["Forest"], "theme uses selected locale")
    assert(chosen.Sounds.labels["linux-message"] == chosen.L["Soft Ping"], "sounds use selected locale")
    assert(
        chosen.Extensions.entries.floating_button.spec.name == chosen.L["Floating button"],
        "extension uses selected locale"
    )
    assert(chosen.Settings.categories[1][2] == chosen.L["General"], "category uses selected locale")
    local language = chosen.Settings:Options().args.general.args.language.args
    language.locale.set(nil, case[4] == "deDE" and "enUS" or "deDE")
    assert(chosen.L["Settings"] == case[3], "language change waits for reload")
    local saved = Whispr.db.global.locale
    language.locale.set(nil, "unsupported")
    assert(Whispr.db.global.locale == saved, "unsupported choices cannot replace saved language")
    local reloads = 0
    ReloadUI = function()
        reloads = reloads + 1
    end

    language.reload.func()
    assert(reloads == 1, "reload action uses native UI reload")
    local reloaded = boot(case[1], false, { locale = saved })
    assert(reloaded.Locale.selected == saved, "saved language is restored on reload")
end

print("Manual locale selection, automatic fallback, deferred labels and reload persistence passed.")
