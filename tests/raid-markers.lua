local addon = {}
assert(loadfile("scripts/filters.lua"))("Whispr", addon)
assert(loadfile("scripts/format.lua"))("Whispr", addon)
local F = addon.Format
local names = { "star", "circle", "diamond", "triangle", "moon", "square", "cross", "skull" }
for i, name in ipairs(names) do
    local texture = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i .. ":16:16|t"
    assert(F.Message("{" .. name .. "}", false, 14) == texture, "native marker independent of emojis")
    assert(F.Message("{rt" .. i .. "}", true, 14) == texture, "numeric marker alias")
    assert(F.Message("{" .. name:upper() .. "}", true, 14) == texture, "case insensitive")
    local raw = "Target {" .. name .. "}!"
    local input = F.Input(raw, true, 14)
    local plain, spans = F.InputPlain(input)
    assert(plain == raw and #spans == 1, "editable marker preserves raw text")
    assert(F.Outgoing(input) == raw, "send brace token without texture escapes")
    assert(F.InputCursor(spans[1].rawEnd, spans, true) == spans[1].displayEnd, "cursor maps around icon")
end

ICON_TAG_LIST = { totenkopf = 8 }
assert(F.Message("{totenkopf}", false):find("Icon_8", 1, true), "client localized marker aliases")
local adjacent = F.Message("a{skull}{cross}!", false)
assert(
    adjacent:find("Icon_8", 1, true) and adjacent:find("Icon_7", 1, true) and adjacent:sub(-1) == "!",
    "adjacent markers and punctuation"
)
assert(F.Message("{unknown} {rt9} {skull", true) == "{unknown} {rt9} {skull", "unknown and incomplete tags preserved")
local link = "|Hitem:1|h[{skull}]|h"
assert(F.Message(link, true) == link, "native link payload and label untouched")
local url = "https://example.com/{skull}"
assert(not F.Message(url, true):find("UI-RaidTargeting", 1, true), "URL text and payload untouched")
assert(F.Outgoing(F.Input(url, true)) == url, "URL input remains raw")
print("Raid marker aliases, localized tags, composer round trips and protected spans passed.")
