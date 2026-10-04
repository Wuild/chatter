local _, addon = ...
local Selection = {}
addon.Selection = Selection

-- Native hit tests return byte positions in the rendered string. Strip markup
-- after slicing visible spans, so a partial item label never copies a link payload.
function Selection.CopyText(text, first, last)
    local result, cursor = {}, 1
    while cursor <= #text do
        local tail = text:sub(cursor)
        local hidden = tail:match("^|c%x%x%x%x%x%x%x%x")
            or tail:match("^|r")
            or tail:match("^|H.-|h")
            or tail:match("^|h")
        local texture = tail:match("^|T.-|t") or tail:match("^|A.-|a")
        local literal = tail:match("^||")
        local token = hidden or texture or literal or tail:match("^[%z\1-\127\194-\244][\128-\191]*") or tail:sub(1, 1)
        local stop = cursor + #token - 1
        if not hidden and stop >= first and cursor <= last then
            if texture then
                local asset = texture:match("emotes\\([^\\:]+)%.tga")
                for _, entry in ipairs(addon.EmotePicker or {}) do
                    if entry.asset == asset then
                        result[#result + 1] = entry.text
                        break
                    end
                end
            else
                result[#result + 1] = literal and "|" or token
            end
        end

        cursor = stop + 1
    end

    return table.concat(result)
end

function Selection.Clear(window)
    local state = window.messageSelection
    if not state then
        return
    end

    window.messageSelection = nil
    state.bubble.selectionDragging = nil
    for _, texture in ipairs(state.bubble.selectionHighlights or {}) do
        texture:Hide()
    end

    if window.copyBridge then
        window.copyBridge:ClearFocus()
    end
end

local function hit(bubble)
    local scale = bubble:GetEffectiveScale()
    local x, y = GetCursorPosition()
    return bubble.text:FindCharacterIndexAtCoordinate(x / scale, y / scale)
end

function Selection.Paint(window, endpoint)
    local state = window.messageSelection
    if not state or not endpoint then
        return
    end

    local bubble = state.bubble
    state.finish = endpoint
    local first, last = math.min(state.start, endpoint), math.max(state.start, endpoint)
    local areas = first ~= last and bubble.text:CalculateScreenAreaFromCharacterSpan(first, last) or {}
    bubble.selectionHighlights = bubble.selectionHighlights or {}
    for index, area in ipairs(areas or {}) do
        local texture = bubble.selectionHighlights[index]
        if not texture then
            texture = bubble:CreateTexture(nil, "ARTWORK", nil, -1)
            texture:SetColorTexture(0.2, 0.55, 0.85, 0.45)
            bubble.selectionHighlights[index] = texture
        end

        texture:ClearAllPoints()
        texture:SetPoint("BOTTOMLEFT", bubble.text, "BOTTOMLEFT", area.left, area.bottom)
        texture:SetSize(area.width, area.height)
        texture:Show()
    end

    for index = #(areas or {}) + 1, #bubble.selectionHighlights do
        bubble.selectionHighlights[index]:Hide()
    end

    state.selected = Selection.CopyText(bubble.selectionRendered, first, last - 1)
end

local function copyBridge(window)
    if window.copyBridge then
        return window.copyBridge
    end

    -- WoW only exposes unrestricted clipboard copying through its native edit
    -- control. This invisible bridge contains just the selection, never renders
    -- message text, and never changes the visible FontString or saved history.
    local bridge = CreateFrame("EditBox", nil, window.frame)
    window.copyBridge = bridge
    bridge:SetSize(1, 1)
    bridge:SetPoint("TOPLEFT")
    bridge:SetAutoFocus(false)
    bridge:SetFontObject(GameFontHighlight)
    bridge:SetAlpha(0)
    bridge:EnableMouse(false)
    bridge:SetScript("OnTextChanged", function(editor)
        local state = window.messageSelection
        if state and editor:GetText() ~= state.selected then
            editor:SetText(state.selected)
            editor:HighlightText()
        end
    end)

    bridge:SetScript("OnEscapePressed", function()
        Selection.Clear(window)
    end)

    bridge:SetScript("OnEnterPressed", function()
        Selection.Clear(window)
    end)

    bridge:SetScript("OnEditFocusLost", function()
        Selection.Clear(window)
    end)

    bridge:SetScript("OnHide", function()
        Selection.Clear(window)
    end)

    bridge:RegisterEvent("GLOBAL_MOUSE_DOWN")
    bridge:SetScript("OnEvent", function()
        local state = window.messageSelection
        if state and not state.bubble:IsMouseOver() then
            Selection.Clear(window)
        end
    end)

    return bridge
end

function Selection.Attach(window, bubble)
    if not bubble.text.FindCharacterIndexAtCoordinate or not bubble.text.CalculateScreenAreaFromCharacterSpan then
        return
    end

    bubble:EnableMouse(true)
    bubble:HookScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then
            return
        end

        Selection.Clear(window)
        local index, inside = hit(bubble)
        if not index or not inside then
            return
        end

        window.messageSelection = { bubble = bubble, start = index, finish = index, selected = "" }
        bubble.selectionDragging = true
        window.input:ClearFocus()
    end)

    local function finish()
        if not bubble.selectionDragging then
            return
        end

        Selection.Paint(window, hit(bubble))
        bubble.selectionDragging = nil
        local state = window.messageSelection
        if not state or state.selected == "" then
            Selection.Clear(window)
            return
        end

        -- Avoid following a link when the gesture was a drag across its label.
        bubble.selectionClickSuppressed = true
        C_Timer.After(0, function()
            bubble.selectionClickSuppressed = nil
        end)

        local bridge = copyBridge(window)
        bridge:SetText(state.selected)
        bridge:SetFocus()
        bridge:HighlightText()
    end

    bubble:HookScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            finish()
        end
    end)

    bubble:HookScript("OnUpdate", function()
        if not bubble.selectionDragging then
            return
        end

        if IsMouseButtonDown("LeftButton") then
            Selection.Paint(window, hit(bubble))
        else
            finish()
        end
    end)

    bubble:HookScript("OnHide", function()
        if window.messageSelection and window.messageSelection.bubble == bubble then
            Selection.Clear(window)
        end
    end)
end

function Selection.Update(window, bubble, rendered, width, messageID)
    if bubble.selectionRendered ~= rendered or bubble.selectionWidth ~= width or bubble.messageID ~= messageID then
        if window.messageSelection and window.messageSelection.bubble == bubble then
            Selection.Clear(window)
        end
    end

    bubble.selectionRendered, bubble.selectionWidth = rendered, width
end
