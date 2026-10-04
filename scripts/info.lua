local _, addon = ...
local L = addon.L
local Info = { patreonURL = "https://www.patreon.com/Wuild" }
addon.Info = Info

function Info.Version()
    local metadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    return metadata and metadata(addon.name or "Whispr", "Version") or L["Unknown"]
end

Info.about = table.concat({
    L["A little closer, even in Azeroth."],
    "",
    L["A dedicated home for your whispers, with saved conversations, smileys and live typing indicators."],
    "",
    L["Created by Wuild. Your support helps Whispr grow."],
}, "\n")

function Info.Layout(window)
    local box = window.info
    if not box then
        return
    end

    box:SetSize(math.min(440, window.frame:GetWidth() - 24), math.min(340, window.frame:GetHeight() - 24))
    box.title:SetWidth(box:GetWidth() - 118)
    box.version:SetWidth(box:GetWidth() - 108)
    box.support:SetWidth(box:GetWidth() - 32)
    box.text:SetWidth(box:GetWidth() - 48)
    box.text:SetHeight(0)
    box.scroll.content:SetHeight(math.max(1, box.text:GetStringHeight() + 12))
    box.scroll:RefreshContent()
    box.scroll:SetVerticalScroll(math.min(box.scroll:GetVerticalScroll(), box.scroll:GetVerticalScrollRange()))
end

function Info.Show(window)
    local UI = addon.UI
    if not window.info then
        local shade = CreateFrame("Button", nil, window.frame)
        shade:SetAllPoints()
        shade:SetFrameLevel(window.frame:GetFrameLevel() + 50)
        UI.Background(shade, 0, 0, 0, 0.78)
        if shade.SetIgnoreParentAlpha then
            shade:SetIgnoreParentAlpha(true)
        end

        local box = CreateFrame("Frame", nil, shade)
        window.info = box
        box:SetPoint("CENTER")
        box:SetFrameLevel(shade:GetFrameLevel() + 1)
        box:EnableMouse(true)
        box.surface = UI.ModalSurface(box)
        box.logo = box:CreateTexture(nil, "ARTWORK")
        box.logo:SetTexture("Interface\\AddOns\\Whispr\\assets\\whispr-icon.tga")
        box.logo:SetSize(56, 56)
        box.logo:SetPoint("TOPLEFT", 16, -16)
        box.title = UI.Text(box, "Whispr", "GameFontHighlightLarge")
        box.title:SetPoint("TOPLEFT", 84, -22)
        box.version = UI.Text(box, "", "GameFontHighlightSmall")
        box.version:SetPoint("TOPLEFT", 84, -48)
        box.version:SetTextColor(unpack(UI.colors.muted))
        box.close = UI.IconButton(box, "close", L["Close addon info"], 24, function()
            box:Hide()
        end)

        box.close:SetPoint("TOPRIGHT", -8, -8)
        box.scroll = UI.Scroll(box)
        box.scroll:SetPoint("TOPLEFT", 20, -88)
        box.scroll:SetPoint("BOTTOMRIGHT", -20, 88)
        box.text = UI.Text(box.scroll.content, Info.about, "GameFontHighlightSmall")
        box.text:SetPoint("TOPLEFT", 0, -4)
        box.text:SetSpacing(4)
        box.text:SetWordWrap(true)
        box.support = UI.Button(box, L["Support on Patreon"], 180, function()
            window:ShowCopyText(Info.patreonURL, L["Support Wuild on Patreon"])
        end)

        box.support:SetPoint("BOTTOMLEFT", 16, 16)
        box.support:SetHeight(36)
        -- A distinct brand treatment keeps the support action easy to find.
        addon.Theme.surfaces[box.support.surface] = nil
        box.support.surface:SetColorTexture(0.72, 0.20, 0.16, 1)
        box.support:SetScript("OnEnter", function()
            box.support.surface:SetColorTexture(0.84, 0.26, 0.21, 1)
        end)

        box.support:SetScript("OnLeave", function()
            box.support.surface:SetColorTexture(0.72, 0.20, 0.16, 1)
        end)

        box.support.logo = box.support:CreateTexture(nil, "OVERLAY")
        box.support.logo:SetTexture("Interface\\AddOns\\Whispr\\assets\\icons\\patreon.tga")
        box.support.logo:SetSize(20, 20)
        box.support.logo:SetPoint("LEFT", 14, 0)
        local supportHint = UI.Text(box, L["Enjoying Whispr? Support its development."], "GameFontHighlightSmall")
        supportHint:SetPoint("BOTTOMLEFT", 20, 64)
        supportHint:SetTextColor(unpack(UI.colors.muted))
        box.shade = shade
        shade:SetScript("OnClick", function()
            box:Hide()
        end)

        box:SetScript("OnHide", function()
            shade:Hide()
        end)
    end

    window:SetWindowFocus(true)
    window.input:ClearFocus()
    local box = window.info
    box.version:SetText(string.format(L["Version %s  |  By Wuild"], Info.Version()))
    box.shade:Show()
    box:Show()
    Info.Layout(window)
    box.scroll:SetVerticalScroll(0)
end
