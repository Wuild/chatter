# Developing Whispr

## Local checks

See [code style and tool setup](code-style.md) for the pinned tools and formatting
rules. From the repository root:

```sh
make format
make check
```

The checks cover formatting, Lua lint, the spacing and publishing tools, and every Lua test
harness in `tests/`. Run one harness with, for example, `luajit tests/window.lua`.

The harnesses mock the game environment. They do not replace in-game verification
of rendering, protected actions, or client-specific behavior. Check incoming and
outgoing whispers, Battle.net, item links, text copying, scrolling, combat behavior,
and saved history after `/reload` on the client you are targeting.

## Publishing to CurseForge

The Python publishing tools are adapted from GatherLite and use only the standard
library. Copy `.env.example` to `.env` on a new checkout and set the upload token.
The project ID is **1727008**. `.env` is ignored by Git and excluded from release ZIPs.
Keep `CURSEFORGE_GAME_VERSION` set to the exact, comma-separated CurseForge game
versions you have tested. The default targets are Forever `1.60.1`, Burning
Crusade Anniversary `2.5.6`, and Retail `12.1.0`, matching `Whispr.toc`.
The uploader tags the single release ZIP with all configured versions.

Run checks, preview, and build without uploading:

```sh
make check
make publish-dry-run VERSION=0.1.0
make package VERSION=0.1.0
```

The package is `dist/Whispr-0.1.0.zip`, with a `.zip.sha256` checksum beside it.
`package-rules.json` controls its contents. The builder validates the TOC/XML load
chain, includes bundled libraries and licenses, and replaces `@project-version@`
in the packaged TOC with the requested version without changing the checkout.
The source TOC keeps the placeholder for repository-based CurseForge packaging.
Direct ZIP uploads use the locally stamped version.

When ready to release, supply Markdown release notes and run:

```sh
make publish VERSION=0.1.0 CHANGELOG=/path/to/release-notes.md
```

`make publish` applies formatting, then runs formatting verification, linting,
and tests before uploading a **release** to CurseForge. A failure stops the upload.
`VERSION` is required; `CHANGELOG` is optional, and
`ENV_FILE` defaults to `.env`. These options also work with `make package` and
`make publish-dry-run`. Quote paths containing spaces, for example
`CHANGELOG="docs/release notes.md"`.
Check the author dashboard for approval and correct game-version classification.
After an upload timeout, check the dashboard before retrying to avoid duplicates.

## Local demo conversations

Demo commands and the Debug category are disabled in normal builds. Startup
removes saved demo conversations from all character histories before retention
and detached-window restoration. Real conversations are preserved.

For local development only, set `addon.developmentMode = true` in
`scripts/config.lua` and reload to enable the tools below. Leave it `false` in
distributed builds. Setting it back to `false` and reloading removes the samples.

- `/whispr screenshots` creates or refreshes ten fictional characters with
  conversations, class metadata, and unread badges. Real chats remain below them
  in the inbox, so check the visible content before capturing a screenshot.
- `/whispr demo` creates or resets a 100-message conversation spanning several
  days, with simulated unread messages for scrolling and layout checks.
- **Settings → Debug** also provides incoming-message, typing, and notification
  simulations. Notifications follow normal visibility rules and stay hidden
  while the inbox or the sender's window is open.

Demo conversations cannot send whispers or typing packets. Creating samples does
not evict real history or change retention preferences. Normal history retention
applies afterward. Delete samples through their conversation menus.

README screenshots live in `docs/screenshots/`. Their absolute GitHub image URLs
point to the `main` branch and become available when those files are pushed.

## Extensions

See the [extension API guide](extensions.md) for lifecycle hooks, settings,
events, rendering filters, and theme registration. Bundled modules live under
`extensions/`; third-party libraries live under `scripts/libraries/` and retain
upstream formatting and license notices.

## Localization

English is the base language in `locales/enUS.lua`; `locales/deDE.lua` provides
the complete German translation and loads automatically on German clients. Untranslated locales and
missing translations fall back to English through AceLocale.

To add a language:

1. Create `locales/<locale>.lua`, obtain the addon namespace with
   `local _, addon = ...`, then register it with `addon.Locale:Register("<locale>")`.
2. Fill the returned table using existing English keys. Registration loads every
   bundled catalog, allowing language selection independent of the game client.
3. Add the file to `Whispr.toc` after `scripts/locale.lua` and `locales/enUS.lua`,
   before other scripts. Add its native display name to the language selector and
   include the locale in the supported choices in `Locale:Initialize`.

General → Language selects Automatic, English or Deutsch. The choice is saved
account-wide and applies after a UI reload. `Locale:Initialize` runs after AceDB
loads saved settings; localized module/theme registration and eager label tables
use `addon.Locale:OnReady` so they use the selected language. Runtime lookups keep
the same `addon.L` table. Other addons' AceLocale state and game locale are unchanged.

Keep `%s` and `%d` placeholders and their argument order intact. German uses
informal singular address (du/dein), localized WoW class/race labels, and
day–month–year dates. `%H:%M` and
`%B %d, %Y` are date formats. Keep saved keys, extension IDs, commands, asset paths,
and proper names unchanged. Modules read translations through `addon.L`.

Run `luajit tests/locales.lua` to check coverage, fallback behavior, and stable
identifiers. The check rejects missing, duplicate and unused English entries,
and exercises the newer extension settings and localized sample dialogue.
Keep the English catalog alphabetized. Fictional character and guild names,
class tokens and sample IDs remain stable; sample dialogue and race/class display
labels belong in the locale catalog. Extensions provide their own translated
labels when registering.

## Theme modules

Themes live in `themes/<id>/theme.lua` and register with
`addon.Theme:Register(id, { name = ..., colors = {}, skin = ... })`. Add the file
to `Whispr.toc` after the theme manager. The build, formatter, lint and locale
checks include this folder. Default appears first in settings; other entries
sort by their translated display names.

Colors are optional overrides of the shared palette. The optional `skin` table
can replace artwork and change UI elements through these methods (called with
`skin` as `self`):

- `StyleWindow(window)` / `LayoutWindow(window)` / `ReleaseWindow(window)`: customize and restore the
  window, title, controls, and other elements. Applies to combined and separate windows.
- `ApplySurface(surface, colorKey)` / `ReleaseSurface(surface)`: install and
  remove custom surface artwork. `surface.parent` is the owning frame; `role`
  identifies `window`, `message`, `input`, `button`, or `panel`.
- `ColorSurface(surface, r, g, b, alpha)`: apply palette colors and opacity.
- `LayoutSurface(surface, top, left, right)`: follow changing message/body insets.
- `ShowSurface(surface, shown)`: respect hidden and pooled elements.
- `ButtonState(surface, state)`: handle `down` and `up` button states.
- `PaintTexture(texture, colorKey, r, g, b, alpha)`: return true when replacing a
  simple panel texture; return false/nil to use the palette's solid color.
- `ReleaseTexture(texture)`: restore texture state before repainting.

Set `hideGrain = true` when the skin provides its own panel texture. Hooks are
optional, but every replacement must supply its matching cleanup/visibility
hooks. Surfaces and windows are reused: retain custom textures/frames for reuse,
restore the original elements on release, and do not create frames on every
repaint. Custom colors retain the selected skin; choosing Default restores the
flat UI. Classic is a complete example using Blizzard artwork and templates.

Classic's bag styling follows the Forever UI source at commit
`15666a6e67938a1ab5caf041406464251db111ca`:

- [Combined bag template and HeldBagLayout selection](https://github.com/Gethe/wow-ui-source/blob/15666a6e67938a1ab5caf041406464251db111ca/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/ContainerFrame.xml)
- [36px portrait offsets and title setup](https://github.com/Gethe/wow-ui-source/blob/15666a6e67938a1ab5caf041406464251db111ca/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua)
- [HeldBagLayout artwork](https://github.com/Gethe/wow-ui-source/blob/15666a6e67938a1ab5caf041406464251db111ca/Interface/AddOns/Blizzard_SharedXML/Mainline/NineSliceLayouts.lua)
- [Forever border adjustments](https://github.com/Gethe/wow-ui-source/blob/15666a6e67938a1ab5caf041406464251db111ca/Interface/AddOns/Blizzard_SharedXML/Camelot/NineSliceLayoutOverrides.lua)

Whispr instantiates the shared portrait template and calls its native styling
methods. It does not instantiate the inventory frame or register bag events.
