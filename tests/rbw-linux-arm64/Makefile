RBW_VERSION ?= 1.15.0
IMAGE_NAME := rbw-builder-arm64
PLATFORM := linux/arm64
BINARIES := rbw rbw-agent

.PHONY: build clean

build: $(BINARIES)

$(BINARIES):
	docker buildx build \
		--platform $(PLATFORM) \
		--build-arg RBW_VERSION=$(RBW_VERSION) \
		--file Dockerfile.rbw-arm64 \
		--output type=local,dest=. \
		.
	@echo "Built rbw + rbw-agent (arm64) successfully"
	@file rbw rbw-agent

clean:
	rm -f $(BINARIES)
