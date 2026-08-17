arch := "arm64"
tests_dir := "tests"
log_file := "docker.log"

bin_dir := tests_dir / "bin" / arch
platform := "linux/" + arch
image_name := "dotfiles-test-" + arch

[private]
default:
    @just --list --unsorted

# Run all lint hooks over every tracked file
lint *args:
    prek run --all-files {{ args }}

# Install prek as the git pre-commit hook
lint-install:
    prek install

# Run all integration tests
test: test-ubuntu test-macos

# Run integration tests in Docker
test-ubuntu: (_require "AGE_PASSPHRASE")
    docker buildx build \
        --platform {{ platform }} \
        --load \
        --tag {{ image_name }} \
        --file {{ tests_dir }}/Dockerfile.ubuntu \
        --build-arg RBW_DIR={{ bin_dir }} .
    docker run --interactive --tty --rm \
        --platform {{ platform }} \
        --env AGE_PASSPHRASE \
        --env NONINTERACTIVE=1 \
        --volume "$PWD":/repo \
        {{ image_name }} \
        zsh -c "cp -a /repo ~/.local/share/chezmoi && cd ~/.local/share/chezmoi && zsh tests/integration-tests-runner.zsh --local" 2>&1 \
    | tee {{ log_file }}

# Run integration tests on macOS via UTM VM
test-macos: (_require "AGE_PASSPHRASE" "RBW_EMAIL" "RBW_PASSWORD" "RBW_TOTP_SEED")
    zsh {{ tests_dir }}/test-macos.sh

# Build rbw binaries for arch (override with `just arch=amd64 rbw`)
rbw:
    make rbw ARCH={{ arch }}

# Remove built binaries
clean:
    make clean ARCH={{ arch }}

# Export accounts from secrets manager, encrypt, commit, and apply to chezmoi
update-accounts:
    ./op-update-accounts

[private]
_require +vars:
    #!/usr/bin/env bash
    set -euo pipefail
    for var in {{ vars }}; do
        if [[ -z "${!var:-}" ]]; then
            echo "error: $var must be set" >&2
            exit 1
        fi
    done
