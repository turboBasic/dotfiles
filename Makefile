# Build graph for the pre-built rbw binaries only.
# Every other task lives in the justfile — see the mise/Just/Make boundary in
# ~/.claude/CLAUDE.md. This stays a Makefile because the .stamp target gates an
# expensive docker build on input timestamps, which just cannot express.

ARCH ?= arm64
PLATFORM := linux/$(ARCH)
TESTS_DIR := tests
BIN_DIR := $(TESTS_DIR)/bin/$(ARCH)
BINARIES := $(BIN_DIR)/rbw $(BIN_DIR)/rbw-agent

.PHONY: help rbw clean

help:
	@echo "Targets:"
	@echo "  rbw           Build rbw binaries for ARCH (default: arm64)"
	@echo "  clean         Remove built binaries"
	@echo ""
	@echo "All other tasks live in the justfile — run 'just' to list them."

rbw: $(BINARIES)

$(BINARIES): $(BIN_DIR)/.stamp

$(BIN_DIR)/.stamp: Makefile $(TESTS_DIR)/Dockerfile.rbw-ubuntu | $(BIN_DIR)
	docker buildx build \
		--platform $(PLATFORM) \
		--file $(TESTS_DIR)/Dockerfile.rbw-ubuntu \
		--output type=local,dest=$(BIN_DIR) \
		$(TESTS_DIR)
	@echo "Built rbw + rbw-agent ($(ARCH)) successfully"
	@file $(BINARIES)
	@touch $@

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

clean:
	rm -rf $(BIN_DIR)
