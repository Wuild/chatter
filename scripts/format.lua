local _, addon = ...
local Format = {}
addon.Format = Format

function Format.InputAutoSpace(token)
    return addon.Filters:Apply("INPUT_AUTO_SPACE", false, token)
end

local function encode(text)
    return (text:gsub(".", function(char)
        return string.format("%02x", string.byte(char))
    end))
end

function Format.Decode(text)
    if #text % 2 ~= 0 or text:find("[^%x]") then
        return
    end

    return (text:gsub("%x%x", function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

local function inputLink(raw, display)
    return "|cff68bfff|Hchatterinput:" .. encode(raw) .. "|h" .. display .. "|h|r"
end

-- Native chat markers are independent of the optional emoji extension.
local raidMarkers = { star = 1, circle = 2, diamond = 3, triangle = 4, moon = 5, square = 6, cross = 7, skull = 8 }

local function renderRaidMarkers(text, fontSize, inputMode)
    return (
        text:gsub("{([^{}]+)}", function(tag)
            local key = (strlower or string.lower)(tag)
            local index = ICON_TAG_LIST and ICON_TAG_LIST[key] or raidMarkers[key] or tonumber(key:match("^rt([1-8])$"))
            if not index or index < 1 or index > 8 then
                return
            end

            local size = math.floor(fontSize or 12) + 2
            local texture = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_"
                .. index
                .. ":"
                .. size
                .. ":"
                .. size
                .. "|t"
            return inputMode and inputLink("{" .. tag .. "}", texture) or texture
        end)
    )
end

local function plain(text, enabled, fontSize, inviteKey, inputMode)
    return (
        text:gsub("%S+", function(token)
            if token:match("^https?://") or token:match("^www%.") then
                local url, suffix = token:match("^(.-)([.,!?;]*)$")
                if inputMode then
                    return inputLink(url, url) .. suffix
                end

                return "|cff68bfff|Hchatterurl:" .. encode(url) .. "|h" .. url .. "|h|r" .. suffix
            end

            if enabled then
                local rendered = addon.Filters:Apply(
                    inputMode and "FORMAT_INPUT_TOKEN" or "FORMAT_MESSAGE_TOKEN",
                    token,
                    fontSize,
                    inputMode and inputLink
                )
                if rendered ~= token then
                    return rendered
                end
            end

            if inviteKey and not inputMode then
                return addon.Filters:Apply("FORMAT_KEYWORD_TOKEN", token, inviteKey)
            end

            return token
        end)
    )
end

local function mapPlain(text, transform)
    -- Treat native links, textures, atlases and color escapes as opaque spans.
    -- A link's label can contain emoticons or URLs; never rewrite its payload.
    local result, cursor, scan = {}, 1, 1
    while scan <= #text do
        local start = text:find("|", scan, true)
        if not start then
            break
        end

        local tail = text:sub(start)
        local protected = tail:match("^|H.-|h.-|h")
            or tail:match("^|T.-|t")
            or tail:match("^|A.-|a")
            or tail:match("^|c%x%x%x%x%x%x%x%x")
            or tail:match("^|r")
        if protected then
            result[#result + 1] = transform(text:sub(cursor, start - 1))
            result[#result + 1] = protected
            cursor = start + #protected
            scan = cursor
        else
            scan = start + 1
        end
    end

    result[#result + 1] = transform(text:sub(cursor))
    return table.concat(result)
end

function Format.Message(text, enabled, fontSize, inviteKey, inputMode)
    local rendered = mapPlain(text, function(span)
        return plain(span, enabled, fontSize, inviteKey, inputMode)
    end)

    if enabled then
        rendered = mapPlain(rendered, function(span)
            return addon.Filters:Apply("FORMAT_NAME_TEXT", span, inputMode, inputLink)
        end)
    end

    return mapPlain(rendered, function(span)
        return renderRaidMarkers(span, fontSize, inputMode)
    end)
end

-- Visit plain tokens only; actions must never trigger from link payloads/labels,
-- textures or URLs (including forged Chatter action links in received text).
function Format.VisitTokens(text, callback)
    mapPlain(text, function(span)
        for token in span:gmatch("%S+") do
            if not token:match("^https?://") and not token:match("^www%.") then
                callback(token)
            end
        end

        return span
    end)
end

Format.Encode = encode

-- Only unwrap our composer decorations. Native item/player links remain intact.
-- Positions are byte offsets, matching EditBox cursor APIs (including UTF-8).
function Format.InputPlain(text)
    local result, spans, cursor, rawLength = {}, {}, 1, 0
    while cursor <= #text do
        local first, last, payload = text:find("|Hchatterinput:(%x+)|h.-|h", cursor)
        if not first then
            break
        end

        -- EditBox edits can remove or change the color wrapper independently
        -- of the link. Decode our payload regardless of its display color.
        local colorStart = first - 10
        if colorStart >= cursor and text:sub(colorStart, first - 1):match("^|c%x%x%x%x%x%x%x%x$") then
            first = colorStart
        end

        if text:sub(last + 1, last + 2) == "|r" then
            last = last + 2
        end

        local raw = Format.Decode(payload)
        if not raw then
            break
        end

        local prefix = text:sub(cursor, first - 1)
        result[#result + 1] = prefix
        rawLength = rawLength + #prefix
        spans[#spans + 1] =
            { rawStart = rawLength, rawEnd = rawLength + #raw, displayStart = first - 1, displayEnd = last }
        result[#result + 1] = raw
        rawLength = rawLength + #raw
        cursor = last + 1
    end

    result[#result + 1] = text:sub(cursor)
    return table.concat(result), spans
end

function Format.InputCursor(position, spans, toDisplay)
    local source, target = toDisplay and "raw" or "display", toDisplay and "display" or "raw"
    local delta = 0
    for _, span in ipairs(spans) do
        if position <= span[source .. "Start"] then
            return position + delta
        end

        if position < span[source .. "End"] then
            return span[target .. "End"]
        end

        delta = span[target .. "End"] - span[source .. "End"]
    end

    return position + delta
end

function Format.Input(text, enabled, size)
    return Format.Message(text, enabled, size, nil, true)
end

-- Validate the transport text separately from the editable display. Keep native
-- links intact, but never send local UI links or texture escape sequences.
function Format.Outgoing(text)
    text = Format.InputPlain(text)
    local result, scan = {}, 1
    while scan <= #text do
        local first = text:find("|", scan, true)
        if not first then
            result[#result + 1] = text:sub(scan)
            break
        end

        result[#result + 1] = text:sub(scan, first - 1)
        local tail = text:sub(first)
        local escape = tail:match("^||") or tail:match("^|c%x%x%x%x%x%x%x%x") or tail:match("^|r")
        local link = tail:match("^|H.-|h.-|h")
        if link and not link:match("^|Hchatter") then
            escape = link
        end

        if escape then
            result[#result + 1] = escape
            scan = first + #escape
        elseif tail:match("^|[HTAcrha]") then
            return nil
        else
            result[#result + 1] = "||"
            scan = first + 1
        end
    end

    return table.concat(result)
end

function Format.Preview(text)
    return (
        text:gsub("|H.-|h(.-)|h", "%1")
            :gsub("|c%x%x%x%x%x%x%x%x", "")
            :gsub("|r", "")
            :gsub("|T.-|t", "")
            :gsub("|A.-|a", "")
            :gsub("[\r\n]", " ")
    )
end
