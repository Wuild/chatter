local addon = {}
assert(loadfile("tests/support/locale.lua"))(addon)
assert(loadfile("extensions/emoji/emotes.lua"))("Chatter", addon)
assert(loadfile("extensions/emoji/renderer.lua"))("Chatter", addon)
assert(loadfile("tests/support/emoji-filters.lua"))(addon)
assert(loadfile("scripts/selection.lua"))("Chatter", addon)
local Selection = addon.Selection

local function equal(a, b, label)
    assert(a == b, (label or "") .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end

local queue = {}
C_Timer = {
    After = function(_, callback)
        queue[#queue + 1] = callback
    end,
}

local function flush()
    for _, f in ipairs(queue) do
        f()
    end

    queue = {}
end

local function frame()
    local f = { scripts = {}, text = "", shown = true }

    function f:SetScript(event, callback)
        self.scripts[event] = callback
    end

    function f:HookScript(event, callback)
        self:SetScript(event, callback)
    end

    function f:SetSize(w, h)
        self.width, self.height = w, h
    end

    function f:SetPoint(...)
        self.point = { ... }
    end

    function f:SetAlpha(a)
        self.alpha = a
    end

    function f:EnableMouse(value)
        self.mouse = value
    end

    function f:SetAutoFocus(value)
        self.autoFocus = value
    end

    function f:SetFontObject() end

    function f:RegisterEvent() end

    function f:SetColorTexture(...)
        self.color = { ... }
    end

    function f:ClearAllPoints() end

    function f:CreateTexture()
        return frame()
    end

    function f:GetEffectiveScale()
        return 2
    end

    function f:GetText()
        return self.text
    end

    function f:SetText(text)
        self.text = text
        if self.scripts.OnTextChanged then
            self.scripts.OnTextChanged(self)
        end
    end

    function f:SetFocus()
        self.focus = true
    end

    function f:ClearFocus()
        local was = self.focus
        self.focus = false
        if was and self.scripts.OnEditFocusLost then
            self.scripts.OnEditFocusLost(self)
        end
    end

    function f:HasFocus()
        return self.focus
    end

    function f:HighlightText()
        self.highlighted = true
    end

    function f:Show()
        self.shown = true
    end

    function f:Hide()
        self.shown = false
    end

    return f
end

CreateFrame = function(kind)
    equal(kind, "EditBox", "only clipboard bridge uses editor")
    return frame()
end

GameFontHighlight = {}
local x, y, index, inside, down = 40, 80, 1, true, true
GetCursorPosition = function()
    return x, y
end

IsMouseButtonDown = function()
    return down
end

local window = { frame = frame(), input = frame() }
window.input:SetFocus()
local bubble = frame()
bubble.text = frame()
local message = "hello world"
bubble.text:SetText(message)

function bubble.text:FindCharacterIndexAtCoordinate(px, py)
    equal(px, 20, "scaled pointer x")
    equal(py, 40, "scaled pointer y")
    return index, inside
end

function bubble.text:CalculateScreenAreaFromCharacterSpan(first, last)
    equal(first, 1, "span starts at first byte")
    equal(last, 6, "exclusive end boundary")
    return { { left = 0, bottom = 16, width = 24, height = 14 }, { left = 0, bottom = 0, width = 10, height = 14 } }
end

Selection.Attach(window, bubble)
Selection.Update(window, bubble, message, 100, 1)
bubble.messageID = 1
bubble.scripts.OnMouseDown(bubble, "LeftButton")
equal(window.input:HasFocus(), false, "selection releases composer")
index = 6
bubble.scripts.OnUpdate()
equal(window.messageSelection.selected, "hello", "selected visible text")
equal(#bubble.selectionHighlights, 2, "wrapped span draws both rectangles")
bubble.scripts.OnMouseUp(bubble, "LeftButton")
equal(window.copyBridge:GetText(), "hello", "clipboard contains selection only")
equal(window.copyBridge.alpha, 0, "clipboard has no visible text or caret")
equal(window.copyBridge.mouse, false, "clipboard cannot intercept clicks")
window.copyBridge:SetText("typing or paste")
equal(window.copyBridge:GetText(), "hello", "clipboard remains selected text")
equal(bubble.text:GetText(), message, "typing never changes visible message")
Selection.Update(window, bubble, message, 100, 1)
assert(window.messageSelection, "unchanged render preserves selection")
Selection.Update(window, bubble, message, 80, 1)
equal(window.messageSelection, nil, "resize clears stale highlight geometry")
equal(bubble.selectionHighlights[1].shown, false, "highlights clear")
equal(window.copyBridge:HasFocus(), false, "clipboard releases keyboard")
flush()
index = 6
Selection.Update(window, bubble, message, 80, 1)
bubble.scripts.OnMouseDown(bubble, "LeftButton")
index = 1
bubble.scripts.OnUpdate()
equal(window.messageSelection.selected, "hello", "reverse drag copies same range")
bubble.scripts.OnMouseUp(bubble, "LeftButton")
window.copyBridge.scripts.OnEscapePressed()
equal(window.messageSelection, nil, "Escape clears selection")
index = 1
bubble.scripts.OnMouseDown(bubble, "LeftButton")
bubble.scripts.OnMouseUp(bubble, "LeftButton")
equal(window.messageSelection, nil, "simple click does not take copy focus")
equal(Selection.CopyText("é漢字", 1, 5), "é漢", "UTF-8 byte spans remain intact")
local link = "|cffabcdef|Hitem:123|h[Sword]|h|r"
equal(Selection.CopyText(link, 1, #link), "[Sword]", "copies item label without markup")
local a = assert(link:find("Sword", 1, true))
equal(Selection.CopyText(link, a, a + 2), "Swo", "partial hyperlink label")
local smile = "|TInterface\\AddOns\\Chatter\\assets\\emotes\\happy.tga:18|t"
equal(Selection.CopyText(smile, 1, #smile), ":)", "smiley selection copies a text face")
equal(Selection.CopyText("a||b\nc", 1, 6), "a|b\nc", "pipes and line breaks survive")
print("Read-only drag selection, wrapping, reverse selection, UTF-8, link labels and hidden clipboard passed.")
