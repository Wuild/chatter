local function boot(locale)
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
    assert(loadfile("locales/enUS.lua"))()
    local addon = {}
    assert(loadfile("scripts/locale.lua"))("Whispr", addon)
    return addon
end

for _, locale in ipairs({ "enUS", "enGB", "deDE", "frFR", "koKR", "zhCN" }) do
    local addon = boot(locale)
    assert(addon.L["Settings"] == "Settings", "English fallback on " .. locale)
    assert(string.format(addon.L["Message %s..."], "Player") == "Message Player...", "name placeholders")
    assert(string.format(addon.L["Unread messages: %d"], 3) == "Unread messages: 3", "count placeholders")
end

local addon = boot("deDE")
local translated = LibStub("AceLocale-3.0"):NewLocale("Whispr", "deDE")
translated["Messages"] = "Nachrichten"
translated["Forest"] = "Wald"
translated["Emoji"] = "Emojis"
translated["Game default"] = "Spielstandard"
assert(
    addon.L["Messages"] == "Nachrichten" and addon.L["Themes"] == "Themes",
    "partial locale overrides with English fallback"
)
Whispr = { db = { global = { chatFont = "Game default" } } }
assert(loadfile("scripts/theme.lua"))("Whispr", addon)
assert(loadfile("scripts/extensions.lua"))("Whispr", addon)
assert(loadfile("extensions/emoji/emotes.lua"))("Whispr", addon)
assert(loadfile("extensions/emoji/renderer.lua"))("Whispr", addon)
assert(loadfile("extensions/emoji/module.lua"))("Whispr", addon)
assert(loadfile("scripts/debug.lua"))("Whispr", addon)
assert(loadfile("scripts/settings.lua"))("Whispr", addon)
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

-- Every lookup in a TOC-loaded module must have an explicit English entry.
local english = boot("enUS").L
local toc = assert(io.open("Whispr.toc")):read("*a")
local seen, count = {}, 0
for path in toc:gmatch("[^\r\n]+") do
    if path:match("^scripts\\.*%.lua$") or path:match("^extensions\\.*%.lua$") then
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
