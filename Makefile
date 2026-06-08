PREFIX ?= /usr/local
WRAPPER := $(abspath scripts/swiftui-ctx)
CATALOG := $(abspath catalog)

.PHONY: build build-universal install uninstall test validate refresh clean help

help:                ## Show targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*##/ —/'

build:               ## Build the release CLI (needs Xcode / Swift 6 toolchain)
	cd swiftui-scan && swift build -c release --product swiftui-ctx

build-universal:     ## Build a universal (arm64+x86_64) swiftui-ctx → ./swiftui-ctx (what CI ships)
	cd swiftui-scan && swift build -c release --product swiftui-ctx --arch arm64 --arch x86_64
	cp swiftui-scan/.build/apple/Products/Release/swiftui-ctx ./swiftui-ctx && file ./swiftui-ctx

install: build       ## Symlink `swiftui-ctx` onto PATH ($(PREFIX)/bin)
	@mkdir -p $(PREFIX)/bin
	@chmod +x $(WRAPPER)
	@ln -sf $(WRAPPER) $(PREFIX)/scripts/swiftui-ctx
	@echo "installed: $(PREFIX)/scripts/swiftui-ctx"
	@SWIFTUI_CTX_CATALOG=$(CATALOG) $(PREFIX)/scripts/swiftui-ctx stats >/dev/null && echo "catalog OK"

uninstall:           ## Remove the symlink
	@rm -f $(PREFIX)/scripts/swiftui-ctx && echo "removed $(PREFIX)/scripts/swiftui-ctx"

test: build          ## Scanner regression test + CLI smoke test
	cd swiftui-scan && swift build -c release --product swiftui-scan
	python3 swiftui-scan/fixtures/check.py
	@SWIFTUI_CTX_CATALOG=$(CATALOG) swiftui-scan/.build/release/swiftui-ctx lookup searchable --json | python3 -c 'import sys,json;assert json.load(sys.stdin)["ok"];print("cli OK")'

validate:            ## Validate all skills against the Agent Skills spec (needs skills-ref / npx)
	@for s in skills/*/; do \
	  if command -v skills-ref >/dev/null; then skills-ref validate "$$s"; \
	  elif command -v npx >/dev/null; then npx -y @agentskills/skills-ref validate "$$s"; \
	  else echo "no skills-ref/npx — manual check: $$s"; fi; done
	@python3 -c 'import json;[json.load(open(f)) for f in (".claude-plugin/plugin.json",".claude-plugin/marketplace.json")];print("manifests: valid JSON")'

refresh:             ## Rebuild the whole catalog from scratch (long; see RUN.md)
	@echo "see RUN.md — runs scripts/00..08 (clones repos, ~hours)"

clean:
	cd swiftui-scan && swift package clean
