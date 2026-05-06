#!/usr/bin/env zsh
set -euo pipefail

# Integration tests for macOS using UTM disposable VM over SSH.
# Requires: utmctl, AGE_PASSPHRASE, a base macOS VM with SSH enabled.

readonly SCRIPT_DIR="${0:A:h}"
readonly REPO_DIR="${SCRIPT_DIR:h}"
readonly LOG_FILE="${REPO_DIR}/macos.log"

readonly VM_BASE="${UTM_VM_BASE:-base: Tahoe 26.2}"
readonly VM_TEST="test: dotfiles"   # -$(date +%s)"
readonly VM_USER="${UTM_VM_USER:-tester}"
readonly VM_BASE_HOST="${UTM_VM_HOST:-tahoe26base.local}"
readonly VM_TEST_HOST="dotfiles-test.local"
readonly VM_HOME="/Users/${VM_USER}"

readonly REMOTE_REPO_DIR="${VM_HOME}/.local/share/chezmoi"

readonly SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=10)

: "${AGE_PASSPHRASE:?AGE_PASSPHRASE must be set}"
: "${RBW_EMAIL:?RBW_EMAIL must be set}"
: "${RBW_PASSWORD:?RBW_PASSWORD must be set}"
: "${RBW_TOTP_SEED:?RBW_TOTP_SEED must be set}"


main() {
    echo "## Cloning VM '${VM_BASE}' -> '${VM_TEST}'..."
    utmctl clone "$VM_BASE" --name "$VM_TEST"
    trap cleanup EXIT INT TERM

    echo "## Starting VM..."
    utmctl start "$VM_TEST"
    wait_for_ssh "$VM_BASE_HOST"

    set_vm_hostname
    echo "## Waiting for mDNS to propagate..."
    sleep 3
    wait_for_ssh "$VM_TEST_HOST"

    deploy_pinentry
    wait_for_network
    transfer_repo
    run_tests
}

cleanup() {
    local exit_code=$?
    if ((exit_code != 0)); then
        echo "## Dumping pinentry debug log..."
        remote "cat ${VM_HOME}/.local/share/pinentry-debug.log" 2>/dev/null || true
    fi
    echo "## Cleaning up VM..."
    utmctl stop "$VM_TEST" --kill 2>/dev/null || true
    sleep 2
    utmctl delete "$VM_TEST" 2>/dev/null || true
    exit $exit_code
}

wait_for_ssh() {
    local host="$1" timeout="${2:-120}" elapsed=0
    echo "## Waiting for SSH on ${host} (timeout: ${timeout}s)..."
    while ! ssh "${SSH_OPTS[@]}" "${VM_USER}@${host}" /usr/bin/true 2>/dev/null; do
        sleep 5
        elapsed=$((elapsed + 5))
        if ((elapsed >= timeout)); then
            echo "ERROR: SSH not available after ${timeout}s" >&2
            return 1
        fi
    done
    echo "## SSH ready (${elapsed}s)"
}

remote_base() {
    ssh "${SSH_OPTS[@]}" "${VM_USER}@${VM_BASE_HOST}" "$@"
}

remote() {
    ssh "${SSH_OPTS[@]}" "${VM_USER}@${VM_TEST_HOST}" "$@"
}

set_vm_hostname() {
    local hostname="${VM_TEST_HOST%.local}"
    echo "## Setting VM hostname to '${hostname}'..."
    remote_base "sudo scutil --set HostName ${hostname} && sudo scutil --set LocalHostName ${hostname} && sudo scutil --set ComputerName ${hostname}"
}

wait_for_network() {
    local timeout=60 elapsed=0
    echo "## Waiting for network connectivity (timeout: ${timeout}s)..."
    while ! remote curl -sS --max-time 5 -o /dev/null https://identity.bitwarden.com 2>/dev/null; do
        sleep 5
        elapsed=$((elapsed + 5))
        if ((elapsed >= timeout)); then
            echo "ERROR: Network not available after ${timeout}s" >&2
            return 1
        fi
    done
    echo "## Network ready (${elapsed}s)"
}

deploy_pinentry() {
    echo "## Deploying non-interactive pinentry..."
    local secrets_file="${VM_HOME}/.local/share/rbw-test-secrets"

    remote "mkdir -p ${VM_HOME}/.local/bin ${VM_HOME}/.local/share"
    remote "cat > ${secrets_file} && chmod 600 ${secrets_file}" <<EOF
RBW_PASSWORD='${RBW_PASSWORD}'
RBW_TOTP_SEED='${RBW_TOTP_SEED}'
EOF

    remote "cat > ${VM_HOME}/.local/bin/pinentry-env && chmod +x ${VM_HOME}/.local/bin/pinentry-env" <<PINENTRY
#!/bin/sh
# Non-interactive pinentry that reads secrets from file.
# Detects whether rbw is asking for password or TOTP via SETDESC.
. ${secrets_file}
debug_log="${VM_HOME}/.local/share/pinentry-debug.log"
is_totp=0
echo "OK Pleased to meet you"
while IFS= read -r cmd; do
    echo "\$cmd" >> "\$debug_log"
    case "\$cmd" in
        SETDESC*[Cc]ode*|SETDESC*[Tt]oken*|SETDESC*[Tt]wo*|SETDESC*TOTP*|SETDESC*2FA*|SETDESC*[Aa]uthenticator*)
            is_totp=1
            echo "OK"
            ;;
        GETPIN)
            if [ "\$is_totp" -eq 1 ]; then
                totp=\$(/opt/homebrew/bin/oathtool --totp -b "\${RBW_TOTP_SEED}")
                echo "D \${totp}"
            else
                echo "D \${RBW_PASSWORD}"
            fi
            echo "OK"
            ;;
        BYE) echo "OK closing connection"; exit 0 ;;
        *)   echo "OK" ;;
    esac
done
PINENTRY

    echo "## Pre-configuring rbw to use pinentry-env..."
    remote "mkdir -p '${VM_HOME}/Library/Application Support/rbw' && cat > '${VM_HOME}/Library/Application Support/rbw/config.json'" <<EOF
{
  "email": "${RBW_EMAIL}",
  "lock_timeout": 86400,
  "pinentry": "${VM_HOME}/.local/bin/pinentry-env"
}
EOF

    echo "## Pre-seeding chezmoi config to avoid TTY prompts..."
    remote "mkdir -p ${VM_HOME}/.config/chezmoi && cat > ${VM_HOME}/.config/chezmoi/chezmoi.toml" <<EOF
[data]
    dotfiles_key_name = "age-00-chezmoi.key"
    dotfiles_public_key = "age1m4vlfsmhefw77rdm4m8y9fjfvy9ym794pfp7939r76myvfxjl33sv94f28"
    profile = "${CHEZMOI_PROFILE:-work.2025.05}"
EOF
}

transfer_repo() {
    echo "## Transferring repository to VM..."
    remote /bin/mkdir -p "$REMOTE_REPO_DIR"

    tar -C "$REPO_DIR" \
        --exclude='.git' \
        --exclude='docker.log' \
        --exclude='macos.log' \
        --exclude='tests/bin' \
        -czf - . \
    | remote /usr/bin/tar -xzf - -C "$REMOTE_REPO_DIR"
}

run_tests() {
    echo "## Running integration tests..."
    remote "AGE_PASSPHRASE='${AGE_PASSPHRASE}' RBW_PASSWORD='${RBW_PASSWORD}' RBW_TOTP_SEED='${RBW_TOTP_SEED}' NONINTERACTIVE=1 /bin/zsh -c 'cd ${REMOTE_REPO_DIR} && zsh tests/integration-tests-runner.zsh --local'"
}

main "$@" 2>&1 | tee "$LOG_FILE"
