#!/bin/sh

# This script is POSIX sh compatible and can be executed by any POSIX-compliant shell.

# Usage:
#
#   - install all requirements of Chezmoi:
#     install.sh
#
#   - install dotfiles: install all requirements of chezmoi and execute Chezmoi init <git-repo-url>:
#     install.sh init turboBasic/dotfiles
#
#   - install dotfiles on completely empty machine:
#     sh -c "$(curl -fsSL "https://raw.githubusercontent.com/turboBasic/dotfiles/refs/heads/main/install.sh?$(date +%s)")" -- init turboBasic/dotfiles
#
#   - remove all previously-installed chezmoi directories and install dotfiles:
#     install.sh --cleanup init turboBasic/dotfiles
#   or
#     sh -c "$(curl -fsSL "https://raw.githubusercontent.com/turboBasic/dotfiles/refs/heads/main/install.sh?$(date +%s)")" -- --cleanup init turboBasic/dotfiles

# cspell:ignore oahd

age=""
bin_dir=""
brew=""
chezmoi=""
pinentry=""
rbw=""

main() {
    CHEZMOI_OS=${CHEZMOI_OS:-$(_os)}
    CHEZMOI_ARCH=${CHEZMOI_ARCH:-$(_arch)}
    export CHEZMOI_OS CHEZMOI_ARCH

    log "🔹 Installing dependencies of Dotfiles..."
    check_utils || { log "❌ Error: check_utils failed."; return 1; }
    install_bin_dir || { log "❌ Error: install_bin_dir failed."; return 1; }
    install_age || { log "❌ Error: install_age failed."; return 1; }
    install_chezmoi || { log "❌ Error: install_chezmoi failed."; return 1; }
    install_rozetta || { log "❌ Error: install_rozetta failed."; return 1; }
    install_homebrew || { log "❌ Error: install_homebrew failed."; return 1; }
    install_pinentry || { log "❌ Error: install_pinentry failed."; return 1; }
    install_rbw || { log "❌ Error: install_rbw failed."; return 1; }

    if [ "${1:-}" = "--cleanup" ]; then
        shift
        log "🔸 Chezmoi dirs will be cleaned up..."
        _cleanup_chezmoi_dirs || return 1
    fi
    if [ "${1:-}" = "init" ]; then
        shift
        unlock_rbw || { log "❌ Error: unlock_rbw failed."; return 1; }
        log "🔹 Dotfiles will be installed..."
        _install_dotfiles "$@"
    fi
}

# Backward-compatible alias used by test.zsh
install_main() { main "$@"; }

_install_dotfiles() {
    passphrase=""
    if [ -z "${AGE_PASSPHRASE:-}" ]; then
        printf "[install_main] Enter passphrase: "
        stty -echo 2>/dev/null
        read -r passphrase
        stty echo 2>/dev/null
        echo
    else
        passphrase="$AGE_PASSPHRASE"
    fi
    [ -n "$passphrase" ] || { log "❌ Error: AGE_PASSPHRASE is missing"; return 1; }
    AGE_PASSPHRASE="$passphrase" $chezmoi init "$@" || { log "❌ Error: $chezmoi init $* failed."; return 1; }
    AGE_PASSPHRASE="$passphrase" $chezmoi init --apply || { log "❌ Error: $chezmoi init --apply failed."; return 1; }
    unset passphrase
}

_cleanup_chezmoi_dirs() {
    _dirs=$(_get_chezmoi_dirs)
    [ -z "$_dirs" ] && return 0

    while IFS= read -r d; do
        case "$d" in
            "$HOME"/*/*) ;;
            *) log "❌ Error: $d is not 2 levels deeper than HOME, will not be deleted"; return 1 ;;
        esac
        case "$d" in
            */chezmoi/*|*/chezmoi) ;;
            *) log "❌ Error: $d does not contain 'chezmoi', will not be deleted"; return 1 ;;
        esac
        log "▫️ Removing contents of $d"
        find "$d" -mindepth 1 -delete
    done <<EOF
$_dirs
EOF
}

_get_chezmoi_dirs() {
    _chezmoi_cache_dir="${CHEZMOI_CACHE_DIR:-$HOME/.cache/chezmoi}"
    _chezmoi_config_file="${CHEZMOI_CONFIG_FILE:-$HOME/.config/chezmoi/chezmoi.toml}"
    _chezmoi_config_dir="$(dirname "$_chezmoi_config_file")"
    _chezmoi_data_dir="${CHEZMOI_WORKING_TREE:-$HOME/.local/share/chezmoi}"
    _chezmoi_state_dir="$HOME/.local/state/chezmoi"

    for d in "$_chezmoi_cache_dir" "$_chezmoi_config_dir" "$_chezmoi_data_dir" "$_chezmoi_state_dir"; do
        if [ -d "$d" ]; then
            # Resolve to absolute path
            (cd "$d" && pwd -P)
        fi
    done
}

_os() {
    case "$(uname -s)" in
        Darwin*) echo "darwin" ;;
        Linux*)  echo "linux" ;;
        *)       uname -s | tr '[:upper:]' '[:lower:]' ;;
    esac
}

_arch() {
    case "$(uname -m)" in
        x86_64)  echo "amd64" ;;
        aarch64) echo "arm64" ;;
        *)       uname -m ;;
    esac
}

_jq_field() {
    grep "^[[:space:]]*\"$1\"[[:space:]]*:" \
    | sed 's/^[^:]*:[[:space:]]*//; s/,[[:space:]]*$//; s/^[[:space:]]*"//; s/"[[:space:]]*$//'
}

log() {
    case "$1" in
        "❌"*)
            echo "$*" >&2
            ;;
        *)
            if [ -n "${CHEZMOI_DEBUG:-}" ]; then
                echo "[DEBUG] $*" >&2
            fi
            ;;
    esac
}

check_utils() {
    if [ "$CHEZMOI_OS" = "linux" ]; then
        sudo apt-get update || { log "❌ Error: apt-get update failed."; return 1; }
    fi
    for util in curl git grep sed tar uname unzip zsh; do
        if ! command -v "$util" >/dev/null 2>&1; then
            if [ "$CHEZMOI_OS" = "linux" ]; then
                sudo apt-get install --yes "$util" || {
                    log "❌ Error: Failed to install $util using apt-get."
                    return 1
                }
            else
                log "❌ Error: $util is not installed."
                return 1
            fi
        fi
    done
}

install_bin_dir() {
    bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"
    case ":$PATH:" in
        *":$bin_dir:"*) ;;
        *)
            PATH="$PATH:$bin_dir"
            export PATH
            log "✅ $bin_dir is added to PATH."
            ;;
    esac
}

install_chezmoi() {
    log "▫️ Installing Chezmoi..."
    if ! command -v chezmoi >/dev/null 2>&1; then
        if [ ! -x "$bin_dir/chezmoi" ]; then
            BINDIR="$bin_dir" sh -c "$(curl -fsLS get.chezmoi.io/lb)"
        fi
        chezmoi="$bin_dir/chezmoi"
        log "✅ Chezmoi is installed as $chezmoi."
    else
        chezmoi="chezmoi"
        log "▫️ Chezmoi is already installed."
    fi
}

install_age() {
    log "▫️ Installing Age..."
    if ! command -v age >/dev/null 2>&1; then
        if [ ! -x "$bin_dir/age" ]; then
            curl --location --output age.tar.gz \
                "https://dl.filippo.io/age/latest?for=$CHEZMOI_OS/$CHEZMOI_ARCH"
            tar --strip-components=1 -xvf age.tar.gz age/age age/age-keygen age/age-plugin-batchpass
            mv age age-keygen age-plugin-batchpass "$bin_dir"
            rm -f age.tar.gz
        fi
        age="$bin_dir/age"
        log "✅ Age is installed as $age"
    else
        age="age"
        log "▫️ Age is already installed."
    fi
}

_path_to_homebrew() {
    for f in \
        "$(command -v brew 2>/dev/null || true)" \
        /usr/local/bin/brew \
        /opt/homebrew/bin/brew \
        /home/linuxbrew/.linuxbrew/bin/brew
    do
        if [ -n "$f" ] && [ -f "$f" ] && [ -x "$f" ]; then
            echo "$f"
            return 0
        fi
    done
}

install_homebrew() {
    log "▫️ Installing Homebrew..."
    brew=$(_path_to_homebrew)
    if [ -z "$brew" ]; then
        /bin/bash -c "$(
            curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
        )"
        brew=$(_path_to_homebrew)
        if [ -z "$brew" ]; then
            log "❌ Homebrew not found even after installation."
            return 1
        fi
        log "✅ Homebrew is installed as $brew"
    else
        log "▫️ Homebrew is already installed."
    fi
    eval "$($brew shellenv)"
}

install_pinentry() {
    log "▫️ Installing pinentry-tty..."
    if ! command -v pinentry-tty >/dev/null 2>&1; then
        if [ "$CHEZMOI_OS" = "linux" ]; then
            sudo apt-get install --yes pinentry-tty || { log "❌ Error: Failed to install pinentry-tty."; return 1; }
            pinentry="pinentry-tty"
        elif [ "$CHEZMOI_OS" = "darwin" ]; then
            $brew install pinentry
            pinentry="$($brew --prefix)/bin/pinentry-tty"
        else
            echo "❌ Unsupported OS: $CHEZMOI_OS" >&2
            return 1
        fi
        log "✅ pinentry-tty is installed as $pinentry."
    else
        pinentry="pinentry-tty"
        log "▫️ Pinentry-tty is already installed."
    fi
}

install_rozetta() {
    log "▫️ Installing Rosetta..."
    if [ "$CHEZMOI_OS" = "darwin" ] && [ "$CHEZMOI_ARCH" = "arm64" ]; then
        if ! /usr/bin/pgrep oahd >/dev/null 2>&1; then
            log "▫️ Rosetta is not installed. Installing Rosetta..."
            /usr/sbin/softwareupdate --install-rosetta --agree-to-license
            log "✅ Rosetta is installed."
        else
            log "▫️ Rosetta is already installed."
        fi
    fi
}

install_rbw() {
    log "▫️ Installing Rbw..."
    if ! command -v rbw >/dev/null 2>&1; then
        if [ "$CHEZMOI_OS" = "linux" ]; then
            case "$CHEZMOI_ARCH" in
                amd64) deb_arch="amd64" ;;
                arm64) deb_arch="arm64" ;;
                *)     deb_arch="$CHEZMOI_ARCH" ;;
            esac
            url_prefix="https://git.tozt.net/rbw/releases/deb/"
            latest_rbw=$(
                curl --silent --location "$url_prefix" \
                | grep -oE "href=\"rbw_[^\"]+_${deb_arch}\.deb\"" \
                | sed 's/href="//; s/"$//' \
                | sort --version-sort \
                | tail -n 1
            )
            latest_version=$(
                echo "$latest_rbw" \
                | grep -oE '_([0-9]+\.)+[0-9]+_' \
                | sed 's/_//g'
            )
            current_version=$(dpkg-query --showformat='${Version}' --show rbw 2>/dev/null || echo 0.0.0)
            if dpkg --compare-versions "$latest_version" gt "$current_version"; then
                curl --location --output "$latest_rbw" "$url_prefix/$latest_rbw"
                sudo apt-get install --yes ./"$latest_rbw"
                rm -f "$latest_rbw"
            fi
            rbw="rbw"
        elif [ "$CHEZMOI_OS" = "darwin" ]; then
            $brew install rbw
            rbw="$($brew --prefix)/bin/rbw"
        else
            log "❌ Unsupported OS: $CHEZMOI_OS"
            return 1
        fi
        log "✅ Rbw is installed as $rbw"
    else
        rbw="rbw"
        log "▫️ Rbw is already installed."
    fi
}

# shellcheck disable=SC2015
unlock_rbw() {
    log "▫️ Unlocking Rbw..."

    if [ -z "$($rbw config show | _jq_field email)" ]; then
        printf "Enter your Bitwarden login: "
        read -r bw_login
        $rbw config set email "$bw_login"
    fi
    if [ "$($rbw config show | _jq_field lock_timeout)" != "86400" ]; then
        $rbw config set lock_timeout 86400
    fi

    if [ -z "$($rbw config show | _jq_field pinentry)" ]; then
        pinentry=""
        for p in pinentry-mac pinentry-gnome3 pinentry-qt pinentry-tty pinentry pinentry-curses; do
            if command -v "$p" >/dev/null 2>&1; then
                pinentry="$p"
                break
            fi
        done
        if [ -n "$pinentry" ]; then
            $rbw config set pinentry "$pinentry"
        fi
    fi

    $rbw unlock && log "▫️ Rbw is unlocked" || return 1
}


# TODO: Detect if the script is being sourced

main "$@"
