STYLUA ?= stylua
LUACHECK ?= luacheck
LUA ?= luajit
PYTHON ?= python3
LUA_PATHS = scripts extensions themes locales tests
VERSION ?=
CHANGELOG ?=
ENV_FILE ?= .env

# Quote paths (including spaces and apostrophes) as literal shell arguments.
shell_quote = '$(subst ','"'"',$(1))'
PUBLISH_ARGS = --version $(call shell_quote,$(VERSION)) --env-file $(call shell_quote,$(ENV_FILE)) $(if $(strip $(CHANGELOG)),--changelog $(call shell_quote,$(CHANGELOG)))

.PHONY: check format format-check lint test require-version publish-dry-run package publish

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
	$(PYTHON) -m unittest discover -s tools -p 'test_*.py'
	@set -e; for test in tests/*.lua; do $(LUA) "$$test"; done

require-version:
	@test -n $(call shell_quote,$(strip $(VERSION))) || { echo "Set VERSION, for example: make publish VERSION=0.1.0" >&2; exit 1; }

publish-dry-run: require-version
	$(PYTHON) tools/publish.py $(PUBLISH_ARGS) --dry-run

package: require-version
	$(PYTHON) tools/publish.py $(PUBLISH_ARGS) --package-only

publish: require-version
	$(MAKE) format
	$(MAKE) check
	$(PYTHON) tools/publish.py $(PUBLISH_ARGS)
