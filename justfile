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
test: test-runner test-pilot test-ubuntu test-macos

# Check integration runner failure reporting without installing dotfiles
test-runner:
    zsh {{ tests_dir }}/test-integration-runner.zsh

# Check pilot artifacts and result classification without Docker, UTM or Herdr
test-pilot:
    python3 -m unittest discover -s {{ tests_dir }} -p 'test_herdr_pilot.py'

# Freeze tracked worktree inputs; explicitly include any untracked files needed
pilot-prepare *args:
    python3 {{ tests_dir }}/herdr-pilot.py prepare {{ args }}

# Create Herdr test panes and an analyst shell for a prepared run
pilot-launch run:
    python3 {{ tests_dir }}/herdr-pilot.py launch {{ quote(run) }}

# Report outcomes without printing potentially sensitive log content
pilot-report run:
    python3 {{ tests_dir }}/herdr-pilot.py report {{ quote(run) }}

# Run integration tests in Docker
test-ubuntu: (_require "AGE_PASSPHRASE" "RBW_EMAIL" "RBW_PASSWORD" "RBW_TOTP_SEED")
    #!/usr/bin/env bash
    set -euo pipefail
    docker buildx build \
        --platform {{ platform }} \
        --load \
        --tag {{ image_name }} \
        --file {{ tests_dir }}/Dockerfile.ubuntu \
        --build-arg RBW_DIR={{ bin_dir }} .
    docker run --interactive --tty --rm \
        --platform {{ platform }} \
        --env AGE_PASSPHRASE \
        --env RBW_EMAIL \
        --env RBW_PASSWORD \
        --env RBW_TOTP_SEED \
        --env NONINTERACTIVE=1 \
        --volume "$PWD":/repo:ro \
        {{ image_name }} \
        zsh -c "rbw config set email \"\$RBW_EMAIL\" && rbw config set lock_timeout 86400 && rbw config set pinentry /usr/local/bin/pinentry-env && cp -a /repo ~/.local/share/chezmoi && cd ~/.local/share/chezmoi && zsh tests/integration-tests-runner.zsh --local" 2>&1 \
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
