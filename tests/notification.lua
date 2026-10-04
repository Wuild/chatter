local addon = {}
assert(loadfile("tests/support/locale.lua"))(addon)

local function load(name)
    assert(loadfile("scripts/" .. name .. ".lua"))("Whispr", addon)
end

local function equal(a, b, label)
    assert(a == b, label .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end

local clock, combat, created = 0, false, 0
GetTime = function()
    return clock
end

InCombatLockdown = function()
    return combat
end

UnitName = function()
    return "Preview Player"
end

local methods = {}

local function noop() end

for method in
    ("SetSize SetFrameStrata SetClampedToScreen SetMovable RegisterForDrag EnableMouse SetPoint ClearAllPoints SetWidth SetHeight SetWordWrap RegisterForClicks SetAlpha SetTexture SetTexCoord SetColorTexture SetVertexColor SetJustifyH SetTextColor SetShadowOffset"):gmatch(
        "%S+"
    )
do
    methods[method] = noop
end

function methods:SetScript(event, callback)
    self.scripts[event] = callback
end

function methods:SetTexture(texture)
    self.texture = texture
end

function methods:SetColorTexture(...)
    self.color = { ... }
end

function methods:SetTextColor(...)
    self.textColor = { ... }
end

function methods:SetTexCoord(...)
    self.texCoords = { ... }
end

function methods:SetText(text)
    self.text = text
end

function methods:SetAlpha(value)
    self.alpha = value
end

function methods:SetShown(shown)
    self.shown = shown
end

function methods:Show()
    self.shown = true
end

function methods:Hide()
    self.shown = false
end

function methods:IsShown()
    return self.shown
end

function methods:GetCenter()
    return self.x or 0, self.y or 0
end

function methods:GetEffectiveScale()
    return 1
end

function methods:StartMoving()
    self.moving = true
end

function methods:StopMovingOrSizing()
    self.moving = false
end

local function frame()
    return setmetatable({ scripts = {}, shown = false }, { __index = methods })
end

CreateFrame = function()
    created = created + 1
    return frame()
end

UIParent = frame()

function methods:CreateTexture()
    return frame()
end

function methods:CreateFontString()
    return frame()
end

function methods:GetFont()
    return "font", 13
end

function methods:SetFont(font, size)
    self.fontSize = size
end

function methods:GetStringWidth()
    return #(self.text or "") * 7
end

function methods:SetSize(width, height)
    self.width, self.height = width, height
end

load("ui")
load("format")
addon.Window = {
    frame = frame(),
    detached = {},
    Open = function(self, key)
        self.opened = key
        self.frame:Show()
    end,
}

Whispr =
    { db = { global = { extensions = { notification = false } }, char = { conversations = { alice = {}, bob = {} } } } }
load("extensions")
assert(loadfile("extensions/notification/module.lua"))("Whispr", addon)
local n = addon.Notification
local opts = addon.Extensions:Options().args.extension_notification.args.settings
-- Disabled extensions still have readable option values before their first activation.
equal(opts.args.duration.get(), 6, "duration default before activation")
addon.Extensions:Start()
equal(addon.Extensions:IsEnabled("notification"), false, "saved disabled preference respected")
addon.Extensions:Emit("MESSAGE_RECEIVED", { key = "alice", name = "Alice", message = { text = "PRIVATE" } })
equal(created, 0, "disabled extension allocates no frames")
addon.Extensions:SetEnabled("notification", true)

local function receive(key, name)
    addon.Extensions:Emit(
        "MESSAGE_RECEIVED",
        { key = key, name = name, transport = "whisper", message = { text = "PRIVATE" } }
    )
end

addon.Window.frame:Show()
receive("alice", "Alice")
equal(#n.notices, 0, "visible inbox suppresses alerts")
addon.Window.frame:Hide()
addon.Window.detached.alice = { frame = frame() }
addon.Window.detached.alice.frame:Show()
receive("alice", "Alice")
equal(#n.notices, 0, "visible sender popout suppresses alert")
addon.Window.detached.alice.frame:Hide()
combat = true
receive("alice", "Alice")
equal(#n.notices, 1, "hidden combat conversation alerts")
equal(n.frames[1].sender.text, "Alice", "only sender displayed")
equal(n.frames[1].title.text, "Whisper received", "generic title")
assert(n.frames[1].logo.texture:find("whispr-icon.tga", 1, true), "notification shows Whispr icon")
equal(n.frames[1].details.text, "Whisper · 1 unread", "notification shows transport and unread count")
n.frames[1].scripts.OnEnter()
assert(n.frames[1].hovered, "hover highlights notification")
n.frames[1].scripts.OnLeave()
assert(not n.frames[1].hovered, "leaving restores normal surface")
equal(n.notices[1].message, nil, "full message object is not retained")
equal(n.frames[1].preview.text, "PRIVATE", "message preview displayed")
clock = 2
receive("alice", "Alice")
equal(#n.notices, 1, "same sender refreshes one notification")
equal(n.notices[1].expires, 8, "repeat extends expiration")
equal(n.frames[1].details.text, "Whisper · 2 unread", "repeat updates count")
for i = 1, 5 do
    receive("sender" .. i, "Sender " .. i)
end

equal(#n.notices, 3, "burst bounded to three latest senders")
equal(#n.frames, 3, "at most three reusable alert frames")
local capacity = created
clock = 20
n.anchor.scripts.OnUpdate(n.anchor, 0.2)
equal(#n.notices, 0, "notifications expire")
equal(n.anchor:IsShown(), false, "idle frame hides and stops updates")
receive("alice", "Alice")
equal(created, capacity, "later notification reuses frames")
n.frames[1].close.scripts.OnClick()
equal(#n.notices, 0, "close button dismisses immediately")
equal(addon.Window.opened, nil, "close button never opens conversation")
receive("alice", "Alice")
n.frames[1].scripts.OnClick(n.frames[1], "RightButton")
equal(#n.notices, 0, "right click dismisses")
equal(addon.Window.opened, nil, "dismiss never opens window")
receive("alice", "Alice")
n.frames[1].scripts.OnClick(n.frames[1], "LeftButton")
equal(addon.Window.opened, "alice", "explicit click opens sender even in combat")
equal(#n.notices, 0, "click consumes alert")
addon.Window.frame:Hide()
receive("alice", "Alice")
addon.Window.frame:Show()
n.anchor.scripts.OnUpdate(n.anchor, 0.2)
equal(#n.notices, 0, "automatic window visibility dismisses existing alerts")
addon.Window.frame:Hide()
receive("alice", "Alice")
addon.Window.detached.alice.frame:Show()
addon.Extensions:Emit("CONVERSATION_OPENED", { key = "alice" })
equal(#n.notices, 0, "opening sender popout clears matching alert")
addon.Window.detached.alice.frame:Hide()
opts.set({ "onlyCombat" }, true)
combat = false
receive("alice", "Alice")
equal(#n.notices, 0, "combat-only preference suppresses out-of-combat alert")
opts.set({ "onlyCombat" }, false)
opts.set({ "duration" }, 10)
receive("alice", "Alice")
equal(n.notices[1].expires, 30, "duration uses extension settings")
equal(Whispr.db.global.duration, nil, "settings isolated from core profile")
opts.args.anchor.set(nil, true)
assert(n.anchor:IsShown() and n.moving, "anchor visible when unlocked")
n.anchor.scripts.OnDragStart()
assert(n.anchor.moving, "unlocked anchor drags")
n.anchor.x, n.anchor.y = 130, -80
n.anchor.scripts.OnDragStop()
equal(n:Settings().x, 130, "anchor horizontal position saved")
equal(n:Settings().y, -80, "anchor vertical position saved")
opts.args.anchor.set(nil, false)
assert(not n.moving, "anchor locked")
n.anchor.scripts.OnDragStart()
assert(not n.anchor.moving, "locked anchor cannot drag")
opts.args.reset.func()
equal(n:Settings().x, nil, "reset clears saved anchor position")
addon.Window.frame:Hide()
opts.args.preview.func()
equal(n.frames[1].sender.text, "Preview Player", "preview works with inbox hidden")
n.frames[1].scripts.OnClick(n.frames[1], "LeftButton")
equal(addon.Window.opened, "alice", "preview cannot open fake conversation")
opts.args.anchor.set(nil, true)
addon.Extensions:SetEnabled("notification", false)
equal(n.anchor:IsShown(), false, "disable hides anchor and alerts")
equal(#n.notices, 0, "disable clears notifications")
equal(n.moving, false, "disable locks anchor")
addon.Window.frame:Hide()
addon.Extensions:SetEnabled("notification", true)
receive("bob", "Bob")
equal(#n.notices, 1, "reenable restores exactly one subscription")
addon.Extensions:Stop()
equal(n.anchor:IsShown(), false, "shutdown cleans up frames")
print("Sender-only notifications, visibility, combat, expiry, bounded reuse, anchor, settings and lifecycle passed.")

addon.Extensions:Start()
addon.Window.frame:Hide()
opts.set({ "width" }, 500)
opts.set({ "height" }, 130)
opts.set({ "textSize" }, 16)
opts.set({ "previewLength" }, 20)
n:Receive({ key = "alice", name = "Alice", transport = "bnet", message = { text = string.rep("é", 40) } }, true)
equal(n.frames[1].width, 500, "notification width configurable")
equal(n.frames[1].height, 130, "notification height configurable")
equal(n.frames[1].preview.fontSize, 16, "notification text size configurable")
equal(n.frames[1].preview.text, string.rep("é", 20) .. "…", "preview truncates characters without splitting UTF-8")
opts.set({ "showPreview" }, false)
assert(not n.frames[1].preview:IsShown(), "preview visibility changes live")
opts.set({ "showPreview" }, true)
n:Receive({ key = "alice", name = "Alice", message = { text = "|cff00ff00|Hitem:1|h[Item]|h|r\nhello" } }, true)
equal(n.frames[1].preview.text, "[Item] hello", "preview strips link/color markup and line breaks")
opts.set({ "width" }, 260)
n:Receive({ key = "alice", name = "Alice", message = { text = string.rep("W", 100) } }, true)
assert(n.frames[1].measure:GetStringWidth() <= 204, "preview fits narrow notification")
print("Notification live dimensions, text size, preview visibility, UTF-8 and markup-safe truncation passed.")

-- Compact defaults migrate once, while custom dimensions stay user-controlled.
local settings = n:Settings()
settings.compactLayout = nil
settings.width = 360
settings.height = 104
settings.textSize = 13
n:OnInitialize()
equal(settings.width, 280, "old default width becomes compact")
equal(settings.height, 72, "old default height becomes compact")
equal(settings.textSize, 12, "old default text becomes compact")
settings.width = 310
n:OnInitialize()
equal(settings.width, 310, "migration does not override later customization")
settings.width = 280
settings.showPreview = true
addon.Extensions:SetEnabled("notification", true)
addon.Window.frame:Hide()
settings.onlyCombat = false
RAID_CLASS_COLORS = { SHAMAN = { r = 0, g = 0.44, b = 0.87 } }
CLASS_ICON_TCOORDS = { SHAMAN = { 0.25, 0.5, 0.25, 0.5 } }
Whispr.db.char.conversations.alice.character = { classFile = "SHAMAN" }
n:Receive({ key = "alice", name = "Alice", message = { text = "Hello" } })
local noticeFrame = n.frames[1]
equal(noticeFrame.width, 280, "compact width applied")
equal(noticeFrame.height, 72, "compact height applied")
assert(noticeFrame.logo.texture:find("UI-CHARACTERCREATE-CLASSES", 1, true), "sender class icon displayed")
equal(noticeFrame.sender.textColor[3], 0.87, "sender name uses class color")
n:Receive({ key = "bob", name = "Bob" })
assert(n.frames[1].logo.texture:find("whispr-icon.tga", 1, true), "pooled unknown sender resets class icon")
equal(n.frames[1].sender.textColor[1], addon.UI.colors.text[1], "pooled unknown sender resets class color")
equal(n.frames[1].logo.texCoords[2], 1, "fallback restores full texture coordinates")
load("theme")
addon.Window.UpdateOpacity = function() end
Whispr.db.global.windowColor = { 0.2, 0.3, 0.4 }
Whispr.db.global.accentColor = { 0.7, 0.6, 0.5 }
Whispr.db.global.buttonColor = { 0.3, 0.4, 0.5 }
Whispr.db.global.backgroundOpacity = 0.6
n:Render()
equal(addon.Theme.surfaces[n.frames[1].surface][1], "windowColor", "notification background follows theme")
equal(addon.Theme.surfaces[n.frames[1].surface][3], nil, "notification honors theme opacity")
equal(addon.Theme.surfaces[n.frames[1].close.surface][1], "buttonColor", "close control follows theme")
n.frames[1].close.scripts.OnEnter()
equal(addon.Theme.surfaces[n.frames[1].close.surface][2], true, "close hover uses themed highlight")
addon.Theme:Refresh()
equal(addon.Theme.surfaces[n.frames[1].surface][1], "selectedColor", "theme refresh preserves hover styling")
print("Compact defaults, class icons/colors, pooled fallback and themed controls/opacity passed.")

addon.Window.frame:Show()
settings.onlyCombat = false
combat = false
n.notices = {}
n:Render()
addon.Extensions:Emit(
    "MESSAGE_RECEIVED",
    { key = "alice", name = "Alice", simulated = true, message = { text = "Debug message" } }
)
equal(#n.notices, 0, "debug incoming obeys main-window visibility")
opts.args.preview.func()
equal(#n.notices, 0, "explicit preview also obeys main-window visibility")
addon.Window.frame:Hide()
addon.Extensions:Emit(
    "MESSAGE_RECEIVED",
    { key = "alice", name = "Alice", simulated = true, message = { text = "Debug message" } }
)
equal(#n.notices, 1, "debug incoming shows with inbox hidden")
addon.Window.frame:Show()
addon.Extensions:Emit("WINDOW_OPENED", {})
equal(#n.notices, 0, "opening main window immediately clears existing debug notification")
addon.Window.frame:Hide()
opts.args.preview.func()
equal(#n.notices, 1, "preview appears with inbox hidden")
addon.Window.frame:Show()
n.anchor.scripts.OnUpdate(n.anchor, 0.2)
equal(#n.notices, 0, "existing previews disappear when inbox becomes visible")
addon.Extensions:SetEnabled("notification", false)
addon.Extensions:Emit(
    "MESSAGE_RECEIVED",
    { key = "alice", name = "Alice", simulated = true, message = { text = "Debug message" } }
)
equal(#n.notices, 0, "disabled extension remains disabled for debug")
print("Real, simulated and preview notifications all respect visible windows.")

addon.Extensions:SetEnabled("notification", true)
addon.Window.frame:Hide()
n:Receive({ key = "preview", name = "Preview" }, true)
opts.set({ "opacity" }, 0.45)
equal(n.frames[1].alpha, 0.45, "opacity setting updates existing notification live")
n:Receive({ key = "another", name = "Another" }, true)
equal(n.frames[1].alpha, 0.45, "new or recycled notifications inherit opacity")
opts.set({ "opacity" }, 0)
equal(n.frames[1].alpha, 0.2, "notification cannot become entirely invisible")
opts.set({ "opacity" }, 1)
equal(n.frames[1].alpha, 1, "full opacity restored")
print("Notification opacity updates live and survives frame reuse.")
