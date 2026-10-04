local _, addon = ...
local Composer, Format = {}, addon.Format
addon.Composer = Composer

function Composer.Attach(input)
    local getText, setText, insert = input.GetText, input.SetText, input.Insert
    local getCursor, setCursor = input.GetCursorPosition, input.SetCursorPosition
    local changing, previous, previousCursor = false, "", 0
    -- Decorations are longer than the message. Enforce the limit on the raw
    -- draft below, so texture paths never consume the user's 255-byte allowance.
    input:SetMaxBytes(0)

    function input:GetText()
        local text = Format.InputPlain(getText(self))
        return text
    end

    function input:GetCursorPosition()
        local _, spans = Format.InputPlain(getText(self))
        return Format.InputCursor(getCursor(self), spans, false)
    end

    function input:SetCursorPosition(position)
        local _, spans = Format.InputPlain(getText(self))
        setCursor(self, Format.InputCursor(position, spans, true))
    end

    function input:RefreshFormatting(userEdited)
        if changing then
            return
        end

        local raw, existingSpans = Format.InputPlain(getText(self))
        local cursor = self:GetCursorPosition()
        local existingAtomicTokens = {}
        for _, span in ipairs(existingSpans) do
            if Format.InputAutoSpace(raw:sub(span.rawStart + 1, span.rawEnd)) then
                existingAtomicTokens[span.rawStart] = span.rawEnd
            end
        end

        if #raw > 255 then
            raw, cursor = previous, previousCursor
        end

        local profile = Whispr.db.global
        local rendered = Format.Input(raw, true, profile.chatFontSize or 14)
        local _, spans = Format.InputPlain(rendered)
        -- Space newly decorated atomic tokens only. Existing links must stay
        -- untouched so deleting their trailing space does not recreate it.
        -- Work backwards so the original byte offsets remain valid.
        for index = #spans, 1, -1 do
            local span = spans[index]
            local alias = raw:sub(span.rawStart + 1, span.rawEnd)
            if
                Format.InputAutoSpace(alias)
                and existingAtomicTokens[span.rawStart] ~= span.rawEnd
                and not raw:sub(span.rawEnd + 1, span.rawEnd + 1):match("%s")
                and #raw < 255
            then
                raw = raw:sub(1, span.rawEnd) .. " " .. raw:sub(span.rawEnd + 1)
                if cursor >= span.rawEnd then
                    cursor = cursor + 1
                end
            end
        end

        rendered = Format.Input(raw, true, profile.chatFontSize or 14)
        local edited = userEdited and raw ~= previous
        previous, previousCursor = raw, math.min(cursor, #raw)
        if rendered == getText(self) then
            if edited and self.onDraftEdited then
                self.onDraftEdited()
            end

            return
        end

        changing = true
        setText(self, rendered)
        self:SetCursorPosition(previousCursor)
        changing = false
        if edited and self.onDraftEdited then
            self.onDraftEdited()
        end
    end

    function input:SetText(text)
        changing = true
        setText(self, text)
        setCursor(self, #text)
        changing = false
        self:RefreshFormatting()
    end

    function input:Insert(text)
        -- Native insertion preserves selections and treats formatted links as
        -- atomic units for replacement/deletion, just like ordinary item links.
        changing = true
        insert(self, text)
        changing = false
        self:RefreshFormatting(true)
    end

    input:HookScript("OnTextChanged", function(_, userInput)
        input:RefreshFormatting(userInput)
    end)

    input:RefreshFormatting()
end
