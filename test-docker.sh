#!/bin/sh
set -eu

ARCH="${1:-arm64}"
IMAGE_NAME="dotfiles-test-${ARCH}"
PLATFORM="linux/${ARCH}"
DOCKERFILE="Dockerfile.test"
LOG_FILE="docker.log"
RBW_DIR="tests/rbw-linux-${ARCH}"

if [ ! -f "$RBW_DIR/rbw" ] || [ ! -f "$RBW_DIR/rbw-agent" ]; then
    echo "Error: rbw binaries not found in $RBW_DIR. Build them first:" >&2
    echo "  make -C $RBW_DIR" >&2
    exit 1
fi

if [ -z "${AGE_PASSPHRASE:-}" ]; then
    printf 'Enter AGE_PASSPHRASE: '
    stty -echo
    read AGE_PASSPHRASE
    stty echo
    printf '\n'
    export AGE_PASSPHRASE
fi

echo "Building $IMAGE_NAME for $PLATFORM..."
docker buildx build \
    --platform "$PLATFORM" \
    --load \
    --tag "$IMAGE_NAME" \
    --file "$DOCKERFILE" \
    --build-arg "RBW_DIR=$RBW_DIR" .

echo "Running test.zsh --local..."
ENV_FILE=$(mktemp)
printf 'AGE_PASSPHRASE=%s\n' "$AGE_PASSPHRASE" > "$ENV_FILE"
docker run -it --rm \
    --platform "$PLATFORM" \
    --env-file "$ENV_FILE" \
    -e NONINTERACTIVE=1 \
    -v "$PWD":/repo \
    "$IMAGE_NAME" \
    zsh -c "cp -a /repo ~/.local/share/chezmoi && cd ~/.local/share/chezmoi && zsh test.zsh --local" 2>&1 \
| tee "$LOG_FILE"
rm -f "$ENV_FILE"
