# magic — Omarchy spellbook. Full clone. No worktrees.
GO := $(abspath .tools/go/bin/go)
ifeq ($(wildcard $(GO)),)
GO := go
endif

.PHONY: magic test install noworktrees

magic:
	mkdir -p bin
	$(GO) build -o bin/magic ./cmd/magic

test:
	$(GO) test ./...

install: magic
	install -m 0755 bin/magic $(HOME)/.local/bin/magic
	ln -sfn $(HOME)/.local/bin/magic $(HOME)/.local/bin/noworktrees

noworktrees: install
