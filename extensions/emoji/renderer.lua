local _, addon = ...
local Renderer = {}
addon.EmojiRenderer = Renderer
local smileys, aliases = addon.Emotes, {}
for alias in pairs(smileys) do
    aliases[#aliases + 1] = alias
end

table.sort(aliases, function(a, b)
    if #a == #b then
        return a < b
    end

    return #a > #b
end)

function Renderer.Render(token, fontSize, wrap)
    local result, cursor = {}, 1
    while cursor <= #token do
        local matched
        for _, alias in ipairs(aliases) do
            if token:sub(cursor, cursor + #alias - 1) == alias then
                local textSize = math.floor(fontSize or 12)
                local size = textSize + 2
                -- Align the icon with the text baseline instead of floating
                -- above lowercase letters. Scale the descent with the font.
                local offset = -math.floor(textSize / 7)
                local texture = "|TInterface\\AddOns\\Whispr\\assets\\emotes\\"
                    .. smileys[alias]
                    .. ".tga:"
                    .. size
                    .. ":"
                    .. size
                    .. ":0:"
                    .. offset
                    .. ":32:32:4:28:4:28|t"
                result[#result + 1] = wrap and wrap(alias, texture) or texture
                cursor = cursor + #alias
                matched = true
                break
            end
        end

        if not matched then
            local suffix = token:sub(cursor)
            if #result > 0 and suffix:match("^[!?,.;]+$") then
                return table.concat(result) .. suffix
            end

            return -- Require a whole token; leave ordinary words alone.
        end
    end

    return table.concat(result)
end

function Renderer.AutoSpace(value, token)
    return value or addon.Emotes[token] ~= nil
end
