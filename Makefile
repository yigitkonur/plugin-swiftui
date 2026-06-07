PREFIX ?= /usr/local
WRAPPER := $(abspath swiftui-examples/scripts/swiftui-ctx)
CATALOG := $(abspath catalog)

.PHONY: build install uninstall test validate refresh clean help

help:                ## Show targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*##/ —/'

build:               ## Build the release CLI (needs Xcode / Swift 6 toolchain)
	cd swiftui-scan && swift build -c release --product swiftui-ctx

install: build       ## Symlink `swiftui-ctx` onto PATH ($(PREFIX)/bin)
	@mkdir -p $(PREFIX)/bin
	@chmod +x $(WRAPPER)
	@ln -sf $(WRAPPER) $(PREFIX)/bin/swiftui-ctx
	@echo "installed: $(PREFIX)/bin/swiftui-ctx"
	@SWIFTUI_CTX_CATALOG=$(CATALOG) $(PREFIX)/bin/swiftui-ctx stats >/dev/null && echo "catalog OK"

uninstall:           ## Remove the symlink
	@rm -f $(PREFIX)/bin/swiftui-ctx && echo "removed $(PREFIX)/bin/swiftui-ctx"

test: build          ## Scanner regression test + CLI smoke test
	cd swiftui-scan && swift build -c release --product swiftui-scan
	python3 swiftui-scan/fixtures/check.py
	@SWIFTUI_CTX_CATALOG=$(CATALOG) swiftui-scan/.build/release/swiftui-ctx lookup searchable --json | python3 -c 'import sys,json;assert json.load(sys.stdin)["ok"];print("cli OK")'

validate:            ## Validate the skill against the Agent Skills spec (needs skills-ref)
	@command -v skills-ref >/dev/null && skills-ref validate ./swiftui-examples || echo "skills-ref not installed — see https://github.com/agentskills/agentskills"

refresh:             ## Rebuild the whole catalog from scratch (long; see RUN.md)
	@echo "see RUN.md — runs scripts/00..08 (clones repos, ~hours)"

clean:
	cd swiftui-scan && swift package clean
