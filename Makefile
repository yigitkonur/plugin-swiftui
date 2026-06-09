PREFIX ?= /usr/local
WRAPPER := $(abspath scripts/swiftui-ctx)
CATALOG := $(abspath catalog)

.PHONY: build build-universal install uninstall test audit-selftest eval validate refresh clean help

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
	@ln -sf $(WRAPPER) $(PREFIX)/bin/swiftui-ctx
	@echo "installed: $(PREFIX)/bin/swiftui-ctx"
	@SWIFTUI_CTX_CATALOG=$(CATALOG) $(PREFIX)/bin/swiftui-ctx doctor >/dev/null && echo "catalog OK"

uninstall:           ## Remove the symlink
	@rm -f $(PREFIX)/bin/swiftui-ctx && echo "removed $(PREFIX)/bin/swiftui-ctx"

test: build          ## Scanner regression test + CLI smoke test
	cd swiftui-scan && swift build -c release --product swiftui-scan
	python3 swiftui-scan/fixtures/check.py
	@SWIFTUI_CTX_CATALOG=$(CATALOG) swiftui-scan/.build/release/swiftui-ctx lookup searchable --json | python3 -c 'import sys,json;assert json.load(sys.stdin)["ok"];print("cli OK")'

audit-selftest:      ## Regression-test the audit lint engine against known-violation fixtures
	bash scripts/audit-selftest.sh

eval:                ## Proof-of-value: generate SwiftUI with vs without swiftui-ctx, score deterministically (see eval/README.md)
	bash eval/run.sh && python3 eval/score.py

validate:            ## Validate every skill against the Agent Skills spec (dependency-free)
	python3 scripts/validate-skills.py

refresh:             ## Regenerate the hook's deprecated-names.txt from catalog/insights.json (full 00..08 rebuild is manual; see RUN.md)
	python3 scripts/gen_deprecated_list.py   # keep the hook's deprecated-names.txt in sync with the catalog
	@echo "deprecated-names.txt synced. For a full catalog rebuild, run scripts/00..08_*.py manually — see RUN.md."

clean:
	cd swiftui-scan && swift package clean
