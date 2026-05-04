#!/bin/sh
set -eu

ARCH="${1:-amd64}"
IMAGE_NAME="dotfiles-test-${ARCH}"
PLATFORM="linux/${ARCH}"
DOCKERFILE="Dockerfile.test"

if [ -z "${AGE_PASSPHRASE:-}" ]; then
    printf 'Enter AGE_PASSPHRASE: '
    stty -echo
    read AGE_PASSPHRASE
    stty echo
    printf '\n'
    export AGE_PASSPHRASE
fi

echo "Building $IMAGE_NAME for $PLATFORM..."
docker buildx build --platform "$PLATFORM" --load -t "$IMAGE_NAME" -f "$DOCKERFILE" .

echo "Running test.zsh --local..."
ENV_FILE=$(mktemp)
printf 'AGE_PASSPHRASE=%s\n' "$AGE_PASSPHRASE" > "$ENV_FILE"
docker run -it --rm \
    --platform "$PLATFORM" \
    --env-file "$ENV_FILE" \
    -e NONINTERACTIVE=1 \
    -v "$PWD":/repo \
    "$IMAGE_NAME" \
    zsh -c "cp -a /repo ~/.local/share/chezmoi && cd ~/.local/share/chezmoi && zsh test.zsh --local"
rm -f "$ENV_FILE"
