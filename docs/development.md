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

English is the base language in `locales/enUS.lua`. Untranslated locales and
missing translations fall back to English through AceLocale.

To add a language:

1. Create `locales/<locale>.lua` and register it with
   `LibStub("AceLocale-3.0"):NewLocale("Whispr", "<locale>")`.
2. Return immediately if registration returns nil, then assign translations to
   the existing English keys.
3. Add the file to `Whispr.toc` after `locales/enUS.lua` and before
   `scripts/locale.lua`.

Keep `%s` and `%d` placeholders and their argument order intact. `%H:%M` and
`%B %d, %Y` are date formats. Keep saved keys, extension IDs, commands, asset paths,
and proper names unchanged. Modules read translations through `addon.L`.

Run `luajit tests/locales.lua` to check coverage, fallback behavior, and stable
identifiers. Extensions provide their own translated labels when registering.
