STYLUA ?= stylua
LUACHECK ?= luacheck
LUA ?= luajit
PYTHON ?= python3
LUA_PATHS = scripts extensions locales tests

.PHONY: check format format-check lint test

check: format-check lint test

format:
	$(STYLUA) --verify $(LUA_PATHS) .luacheckrc
	$(PYTHON) tools/lua_spacing.py

format-check:
	$(STYLUA) --check --verify $(LUA_PATHS) .luacheckrc
	$(PYTHON) tools/lua_spacing.py --check

lint:
	$(LUACHECK) $(LUA_PATHS)

test:
	$(PYTHON) tools/test_lua_spacing.py
	@set -e; for test in tests/*.lua; do $(LUA) "$$test"; done
