# Whispr extension API (version 2)

Create a named extension object, then define colon-method lifecycle hooks, as
with Ace modules. Whispr manages initialization, saved activation preferences,
message subscriptions and failures. Built-in Emoji, Notification, Keyword actions
and Character names modules live in their own directories under `extensions/`;
each has a `module.lua`.

External extensions remain separate WoW addons with `## Dependencies: Whispr`
in their TOC. Use a unique, stable ID containing letters, digits, underscores or
hyphens. Translate display names and option labels in your own locale table.

```lua
local module = Whispr:NewExtension("my_theme_pack", {
    name = "My theme pack",
    version = "1.0.0",
    description = "A violet palette and a conversation counter.",
})

module:RegisterDefaults({ opened = 0 })

function module:OnInitialize()
    self:RegisterOptions({
        type = "group", name = "Preferences",
        args = {
            opened = {
                type = "range", name = "Conversation counter",
                min = 0, max = 10000, step = 1,
            },
        },
    })
end

function module:OnEnable()
    self:RegisterTheme("violet", {
        name = "Violet",
        colors = { accentColor = { 0.60, 0.35, 0.80 } },
    })
    self:RegisterMessage("CONVERSATION_OPENED", "OnConversationOpened")
end

function module:OnConversationOpened(event, conversation)
    local settings = self:GetSettings()
    settings.opened = settings.opened + 1
end

function module:OnDisable()
    -- Cancel your own timers, hide frames and remove external hooks here.
    -- Whispr removes its message subscriptions automatically.
end
```

## Lifecycle and discovery

`OnInitialize()` runs once after Whispr's database exists, including for disabled
modules. `OnEnable()` runs when the parent is running and the extension is enabled.
`OnDisable()` runs on disable or parent shutdown. A later enable does not repeat
successful initialization. A module created after initialization is initialized
on the next UI tick, giving its declaring Lua chunk time to define methods.

- `Whispr:NewExtension(id, metadata)` returns a module; invalid or duplicate IDs
  raise an error. Metadata supports `name`, `description`, `version`, `builtin`.
- `Whispr:GetExtension(id[, silent])` returns a module, or nil for an unknown ID
  when `silent` is true; otherwise an unknown ID raises an error.
- `Whispr:IterateExtensions()` yields `id, module` for object-style extensions.
- `Whispr:EnableExtension(id)` / `DisableExtension(id)` save the user's choice.
- `module:GetName()` returns its stable ID; `IsEnabled()` reports active state.
- `module:Enable()` / `Disable()` change and persist activation.
- `module:SetEnabledState(boolean)` sets the default before activation, typically
  at declaration or in `OnInitialize`. An explicit saved choice takes precedence.
- `Whispr.API.NewExtension` and `GetExtension` offer the same operations with dot
  syntax. `Whispr.API.version` is `2`.

Lifecycle and Whispr message errors are isolated and shown in Extensions settings.
A failed initialization requires an explicit enable to retry. A failed enable or
message callback triggers cleanup and removes subscriptions. Other extensions
continue running. Register message handlers in `OnEnable` so they are restored
after re-enabling.

These objects follow Ace's method conventions but have a Whispr-managed lifecycle;
they are not registered as AceAddon child modules. They do not automatically embed
Ace libraries. Use your own addon for native WoW event, timer or hook facilities,
and release those resources in `OnDisable`.

## Settings and messages

- `RegisterDefaults(table)` copies defaults; `GetSettings()` returns this module's
  saved account-wide settings table. Missing nested defaults are filled without replacing
  existing values, including `false`. Storage uses the existing
  `global.extensionSettings[id]` namespace. Existing profile-based settings migrate
  once with the rest of Whispr’s preferences.
- `RegisterOptions(group)` accepts an AceConfig group. Default get/set callbacks
  read/write the option's final key in `GetSettings()`. Nested groups should use
  unique leaf keys or explicit accessors. The module is the AceConfig `handler`,
  so string method names for callbacks receive module `self`.
- `RegisterMessage(event[, method])` accepts a method name or function. Omitting
  the method uses the event name. Handlers receive `(self, event, payload)`.
  Registering the same event again replaces the previous handler for this module.
- `UnregisterMessage(event)` and `UnregisterAllMessages()` remove subscriptions.
- `Whispr.API.GetEvents()` returns a fresh sorted list of supported events.

All event payloads are copies. Mutating them cannot modify Whispr's history or
another extension's payload. Settings → Extensions lists enable/disable toggles, with bundled modules first.
Each extension has a nested page under Extensions in the standard AceConfig window.
The native WoW AddOns page only launches this window; extension pages are
not registered as Blizzard categories.
Disabled extensions keep their page, with their controls disabled. Modules
registered later automatically receive a settings page.

## Rendering filters

Use filters to change displayed text, and messages to observe changes. Receipt
notifications alone do not cover restored history or input edits. Emoji owns its
parser in `extensions/emoji/renderer.lua` and registers its filters in `OnEnable`.
The core formatter has no built-in emoji matcher.

`module:RegisterFilter(filter, method)` accepts a method name or function, using
`(self, filter, value, ...)`. Return a replacement value or nil to leave it unchanged.
`UnregisterFilter(filter)` / `UnregisterAllFilters()` remove them explicitly;
disabling a module automatically removes every filter. Filters run in stable
extension-ID order. Errors or a return value of the wrong type disable the faulty
extension and preserve the prior value.

| Filter | Arguments after `self, filter` | Return |
| --- | --- | --- |
| `FORMAT_MESSAGE_TOKEN` | `token, fontSize` | Rendered token string, or nil. Applied to messages including saved history. |
| `FORMAT_INPUT_TOKEN` | `token, fontSize, wrap` | Rendered token string, or nil. Use `wrap(raw, display)` for each atomic decorated span so deletion, cursor mapping and sending retain the raw text. |
| `FORMAT_KEYWORD_TOKEN` | `token, conversationKey` | Rendered action token. Runs only for incoming character message text outside protected links/URLs. |
| `FORMAT_NAME_TEXT` | `text, inputMode, wrap` | Rendered plain span after token processing. Native/generated links stay protected; use `wrap(raw, display)` for composer decorations. |
| `INPUT_AUTO_SPACE` | `shouldSpace, rawToken` | Boolean indicating whether a newly decorated input token needs a trailing space. |

URL recognition and native links are protected by the core formatter before token
filters run. Filters only affect display; they must not change saved message text.

## Available events

Conversation payloads contain `key`, `name`, `transport` (`whisper` or `bnet`).
New conversation-scoped events also include a boolean `demo` field.

| Event | Payload and timing |
| --- | --- |
| `CONVERSATION_CREATED` | Conversation identity after a new record is created, including an empty chat or a newly created demo. |
| `CONVERSATION_OPENED` | Conversation identity after it is selected in a window. May repeat when the conversation is selected again. |
| `CONVERSATION_DELETED` | Removed conversation identity after manual deletion. Retention trimming is not manual deletion. |
| `WINDOW_OPENED` | `{window, key, separate}` when a frame becomes visible. `window` is its stable frame name; `key` is the current selection and may be nil or change afterward. |
| `WINDOW_CLOSED` | Same shape when the frame is hidden, including combat hiding. |
| `DRAFT_CHANGED` | Conversation identity plus raw `text` after a user edit, or an empty string after sending. Formatting refreshes and switching drafts do not emit this. |
| `TYPING_CHANGED` | Conversation identity plus `typing` boolean for a peer's start/stop, expiry, clearing on receipt, or protocol disable. Keepalive packets do not repeat the event. Demo animation is local and does not emit this peer event. |
| `MESSAGE_RECEIVED` | Conversation identity plus `message`, after incoming whisper routing. |
| `MESSAGE_SENT` | Conversation identity plus `message`, after dispatch; this does not mean server confirmation. |
| `MESSAGE_DELIVERY_CHANGED` | Conversation identity plus `message` and `status` (`confirmed` or `unconfirmed`) when a local outgoing record receives an echo or times out. A synchronous echo may arrive before `MESSAGE_SENT`. |
| `CHARACTERS_UPDATED` | No arguments. Character roster metadata has refreshed; cached name rendering may be invalidated. |
| `THEME_CHANGED` | Applied preset ID as a string. |

Message snapshots include `id`, `text`, `time`, `outgoing` and delivery flags.
Draft events expose unsent text to enabled local extensions; Whispr never sends
that draft text through its typing protocol. Extensions run as trusted WoW addon
code, with the same access as other installed addons.

## Themes

`module:RegisterTheme(id, definition)` returns a namespaced theme ID (`module_id`),
or `nil, error`. Registering the same theme again on re-enable is safe. A definition
contains `name` and a `colors` table. Each color is three numbers from 0 to 1:

`windowColor`, `headerColor`, `sidebarColor`, `conversationColor`, `incomingColor`,
`outgoingColor`, `accentColor`, `selectedColor`, `inputColor`, `buttonColor`,
`footerColor`, `focusedBorderColor`, `unfocusedBorderColor`.

Omitted colors use Whispr defaults. Presets preserve fonts, opacity, history,
sounds and behavior. Disabling an extension hides its themes while retaining an
already applied palette as Custom colors. `Whispr.API.RegisterTheme(id, definition)`
also supports standalone presets, returning `true` or `nil, error`.

## Version 1 compatibility

`Whispr.API.RegisterExtension(id, spec)` still accepts the original callback
specification and returns `true` or `nil, error`. Its `onEnable(context)` and
`onDisable(context)` hooks and dot-style `context.GetSettings()`,
`context.On(event, callback)`, and `context.RegisterTheme()` remain supported.
Legacy callbacks receive the payload alone, and support the expanded event list.
`Whispr.API.IsExtensionEnabled(id)` works with both API versions.

To migrate, replace registration with `Whispr:NewExtension`, define `OnInitialize`,
`OnEnable`, and `OnDisable` methods on the returned object, and use its colon-method
helpers. Keep the same ID to retain saved settings, enable state, and theme IDs.
