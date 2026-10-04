# Lua code style and checks

Chatter follows my default layout: four spaces per indent,
expanded functions and control-flow blocks, one statement per line, and blank
lines between functions and logical sections. Avoid compressing callbacks or
chaining several statements with semicolons.

StyLua owns indentation, spacing, quotes, and wrapping. The additional
`tools/lua_spacing.py` pass adds blank lines around named functions and after
closing `end` and `}` blocks when another statement follows. Consecutive closing
lines and `else`/`elseif`/`until` continuations stay together. Both passes run in
`make format` and are verified by `make format-check` and CI. Use double quotes by default,
parentheses for calls, LF line endings, and a 120-column wrapping target. Long
strings may exceed that target. These rules apply to core code, extensions,
locales, and tests. Bundled code in `scripts/libraries` keeps its upstream style
and is excluded from both formatting and linting.

## Tools

Install **StyLua 2.3.1**, **Luacheck 1.2.0**, **LuaJIT**, and **Python 3.9+**. With Cargo and LuaRocks
available, install the pinned formatter and linter using:

```sh
cargo install stylua --version 2.3.1 --locked
luarocks install luacheck 1.2.0
```

Run these commands from the repository root:

```sh
make format       # Apply formatting and verify the parsed code stays equivalent
make format-check # Check formatting without changing files
make lint         # Check Lua 5.1 syntax, globals, unused locals, and other mistakes
make test         # Run every top-level tests/*.lua harness with LuaJIT
make check        # Run all three checks
```

Tool paths can be overridden, for example `make check STYLUA=/path/to/stylua`.
The GitHub workflow runs the same formatter, linter, and test suite on pushes
and pull requests. `.editorconfig` supplies matching defaults to editors.

## Lint rules

`.luacheckrc` explicitly lists the WoW and Ace globals used by the addon.
Add a real API there when introducing a new dependency; do not disable global
checks to hide a misspelling. Unused callback arguments are allowed because WoW
supplies fixed callback signatures. StyLua handles line length.

Test harnesses may define mock globals and reuse local names between scenarios;
their globals are often consumed indirectly by `loadfile`. These exceptions
apply only to tests. Production code still checks accidental globals, unused
locals, shadowed names, unreachable code, and other Luacheck diagnostics.
