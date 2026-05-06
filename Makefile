ARCH ?= arm64
PLATFORM := linux/$(ARCH)
TESTS_DIR := tests
BIN_DIR := $(TESTS_DIR)/bin/$(ARCH)
BINARIES := $(BIN_DIR)/rbw $(BIN_DIR)/rbw-agent

IMAGE_NAME := dotfiles-test-$(ARCH)
LOG_FILE := docker.log

.PHONY: help test test-ubuntu test-macos rbw clean

help:
	@echo "Targets:"
	@echo "  test          Run all integration tests"
	@echo "  test-ubuntu   Run integration tests in Docker (requires AGE_PASSPHRASE)"
	@echo "  test-macos    Run integration tests on macOS"
	@echo "  rbw           Build rbw binaries for ARCH (default: arm64)"
	@echo "  clean         Remove built binaries"

test: test-ubuntu test-macos

test-ubuntu:
ifndef AGE_PASSPHRASE
	$(error AGE_PASSPHRASE must be set)
endif
	docker buildx build \
		--platform $(PLATFORM) \
		--load \
		--tag $(IMAGE_NAME) \
		--file $(TESTS_DIR)/Dockerfile.ubuntu \
		--build-arg RBW_DIR=$(BIN_DIR) .
	docker run --interactive --tty --rm \
		--platform $(PLATFORM) \
		--env AGE_PASSPHRASE \
		--env NONINTERACTIVE=1 \
		--volume "$(CURDIR)":/repo \
		$(IMAGE_NAME) \
		zsh -c "cp -a /repo ~/.local/share/chezmoi && cd ~/.local/share/chezmoi && zsh tests/integration-tests-runner.zsh --local" 2>&1 \
	| tee $(LOG_FILE)

test-macos:
ifndef AGE_PASSPHRASE
	$(error AGE_PASSPHRASE must be set)
endif
ifndef RBW_EMAIL
	$(error RBW_EMAIL must be set)
endif
ifndef RBW_PASSWORD
	$(error RBW_PASSWORD must be set)
endif
ifndef RBW_TOTP_SEED
	$(error RBW_TOTP_SEED must be set)
endif
	zsh tests/test-macos.sh

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
