#!/usr/bin/env zsh
# shellcheck disable=SC1071

# This script might be executed by default version of Bash in macOS, which is Bash 3.x,
# so only appropriate Bash features should be used.

# Usage:
#
#   - install all requirements of Chezmoi:
#     install.zsh
#
#   - install dotfiles: install all requirements of chezmoi and execute Chezmoi init <git-repo-url>:
#     install.zsh init turboBasic/dotfiles
#
#   - install dotfiles on completely empty machine:
#     zsh -c "$(curl -fsSL "https://raw.githubusercontent.com/turboBasic/dotfiles/refs/heads/main/install.zsh?$(date +%s)")" -- init turboBasic/dotfiles
#
#   - remove all previously-installed chezmoi directories and install dotfiles:
#     install.zsh --cleanup init turboBasic/dotfiles
#   or
#     zsh -c "$(curl -fsSL "https://raw.githubusercontent.com/turboBasic/dotfiles/refs/heads/main/install.zsh?$(date +%s)")" -- --cleanup init turboBasic/dotfiles

if [ -z "$ZSH_VERSION" ]; then
    echo "❌ This script should be run in Zsh." >&2
    return 1 &>/dev/null || exit 1
fi

function main install_main () {
    local CHEZMOI_OS=${CHEZMOI_OS:-$(_os)}
    local CHEZMOI_ARCH=${CHEZMOI_ARCH:-$(_arch)}

    log "🔹 Installing dependencies of Dotfiles..."
    check_utils || { log "❌ Error: check_utils failed."; return 1 }
    install_bin_dir || { log "❌ Error: install_bin_dir failed."; return 1 }
    install_age || { log "❌ Error: install_age failed."; return 1 }
    install_chezmoi || { log "❌ Error: install_chezmoi failed."; return 1 }
    install_homebrew || { log "❌ Error: install_homebrew failed."; return 1 }
    install_pinentry || { log "❌ Error: install_pinentry failed."; return 1 }
    install_rbw || { log "❌ Error: install_rbw failed."; return 1 }
    unlock_rbw || { log "❌ Error: unlock_rbw failed."; return 1 }

    if [[ "$1" == "--cleanup" ]]; then
        shift
        log "🔸 Chezmoi dirs will be cleaned up..."
        _cleanup_chezmoi_dirs
    fi
    if [[ "$1" == "init" ]]; then
        shift
        log "🔹 Dotfiles will be installed..."
        _install_dotfiles "$@"
    fi
}

function _install_dotfiles() {
    local passphrase
    if [[ -z "${passphrase:=$AGE_PASSPHRASE}" ]]; then
        read -r -s "passphrase?[install_main] Enter passphrase: "
        echo
    fi
    [[ -n "$passphrase" ]] || { log "❌ Error: AGE_PASSPHRASE is missing"; return 1; }
    AGE_PASSPHRASE="$passphrase" $chezmoi init "$@" || { log "❌ Error: $chezmoi init $@ failed."; return 1 }
    AGE_PASSPHRASE="$passphrase" $chezmoi init --apply || { log "❌ Error: $chezmoi init --apply failed."; return 1 }
    unset passphrase
}

function _cleanup_chezmoi_dirs() {
    local d
    _get_chezmoi_dirs
    for d in $reply; do
        [[ "$d" == $HOME/*/* ]] || { log "❌ Error: $d is not 2 levels deeper than HOME, will not be deleted"; return 1 }
        [[ "$d" == */chezmoi/* || "$d" == */chezmoi ]] || { log "❌ Error: $d does not contain 'chezmoi', will not be deleted"; return 1 }
        log "▫️ Removing contents of $d"
        find "$d" -mindepth 1 -delete
    done
}

function _get_chezmoi_dirs() {
    local chezmoi_cache_dir="${CHEZMOI_CACHE_DIR:-$HOME/.cache/chezmoi}"
    local chezmoi_config_dir="$(dirname "${CHEZMOI_CONFIG_FILE:-$HOME/.config/chezmoi/chezmoi.toml}")"
    local chezmoi_data_dir="${CHEZMOI_WORKING_TREE:-$HOME/.local/share/chezmoi}"
    local chezmoi_state_dir="$HOME/.local/state/chezmoi"

    reply=($chezmoi_cache_dir $chezmoi_config_dir $chezmoi_data_dir $chezmoi_state_dir)
    reply=( ${^reply}(N/:A) ) # Leave only existing directories converted to absolute paths
}

function _os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "darwin"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        echo "$OSTYPE"
    fi
}

function _arch() {
    case "$(uname -m)" in
        x86_64) echo "amd64" ;;
        aarch64) echo "arm64" ;;
        *) uname -m ;;
    esac
}

function is_sourced() {
    # script is sourced, do nothing
    #
    # See https://unix.stackexchange.com/a/594786/65837
    # See http://zsh.sourceforge.net/Doc/Release/Parameters.html#Parameters-Set-By-The-Shell
    # See https://zsh.sourceforge.io/Doc/Release/Parameters.html#Array-Subscripts

    if (( zsh_eval_context[(I)file] )); then
        echo "true"
    else
        echo "false"
    fi
}

function _jq_field() {
    grep '^\s*"'$1'":\s*' \
    |   sed --regexp-extended '
            s/^[^:]+:\s*//
            s/,\s*$//
            s/^\s*"//
            s/"\s*$//
        '
}

function log() {
    if [[ "${1[1,1]}" == "❌" ]]; then
        echo "$*" >&2
    elif [[ -n "$CHEZMOI_DEBUG" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

function check_utils() {
    local utils=(curl expect grep sed tar uname unzip)
    for util in "${utils[@]}"; do
        if ! command -v "$util" &> /dev/null; then
            log "❌ Error: $util is not installed."
            return 1
        fi
    done
}

function install_bin_dir() {
    bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"
    if [[ :$PATH: != *":$bin_dir:"* ]]; then
        PATH="$PATH:$bin_dir"
        log "✅ $bin_dir is added to PATH."
    fi
}

function install_chezmoi() {
    log "▫️ Installing Chezmoi..."
    if ! (( $+commands[chezmoi] )); then
        if [[ ! -x "$bin_dir/chezmoi" ]]; then
            sh -c "$(curl -fsLS get.chezmoi.io/lb)"
        fi
        chezmoi="$bin_dir/chezmoi"
        log "✅ Chezmoi is installed as $chezmoi."
    else
        chezmoi="chezmoi"
        log "▫️ Chezmoi is already installed."
    fi
}

function install_age() {
    log "▫️ Installing Age..."
    if ! command -v age &> /dev/null; then
        if [[ ! -x "$bin_dir/age" ]]; then
            curl --location --output age.tar.gz \
                "https://dl.filippo.io/age/v1.1.1?for=$CHEZMOI_OS/$CHEZMOI_ARCH"
            tar --strip-components=1 -xvf age.tar.gz age/age age/age-keygen
            mv age age-keygen "$bin_dir"
            rm -f age.tar.gz
        fi
        age="$bin_dir/age"
        log "✅ Age is installed as $age"
    else
        age="age"
        log "▫️ Age is already installed."
    fi
}

function _path_to_homebrew() {
    declare -a homebrew_locations=(
        "$(command -v brew)"
        /usr/local/bin/brew
        /opt/homebrew/bin/brew
        /home/linuxbrew/.linuxbrew/bin/brew
    )
    reply=()
    for f in "${homebrew_locations[@]}"; do
        if [[ -f "$f" && -x "$f" ]]; then
            reply+=("$f")
        fi
    done
    set -- "${reply[@]}"
    echo "$1"
}

function install_homebrew() {
    log "▫️ Installing Homebrew..."
    brew=$(_path_to_homebrew)
    if [[ -z "$brew" ]]; then
        NONINTERACTIVE=1 /bin/bash -c "$(
            curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
        )"
        brew=$(_path_to_homebrew)
        if [[ -z "$brew" ]]; then
            log "❌ Homebrew not found even after installation."
            return 1
        fi
        log "✅ Homebrew is installed as $brew"
    else
        log "▫️ Homebrew is already installed."
    fi
    eval "$($brew shellenv zsh)"
}

function install_pinentry() {
    log "▫️ Installing pinentry-tty..."
    if ! command -v pinentry-tty &> /dev/null; then
        if [[ "$CHEZMOI_OS" == "linux" ]]; then
            sudo apt-get install --yes pinentry-tty
            pinentry="pinentry-tty"
        elif [[ "$CHEZMOI_OS" == "darwin" ]]; then
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

function install_rbw() {
    log "▫️ Installing Rbw..."
    if ! command -v rbw &> /dev/null; then
        local url_prefix="https://git.tozt.net/rbw/releases/deb/"
        if [[ "$CHEZMOI_OS" == "linux" ]]; then
            local latest_rbw latest_version current_version
            latest_rbw=$(
                curl --silent --location "$url_prefix" \
                |   grep --only-matching --extended-regexp 'href="rbw_[^"]+_amd64\.deb"' \
                |   sed 's/href="//; s/"$//' \
                |   sort --version-sort \
                |   tail --lines=1
            )
            latest_version=$(
                echo "$latest_rbw" \
                |   grep --only-matching --extended-regexp '_(\d+\.)+\d_' \
                |   sed 's/_//g'
            )
            current_version=$(dpkg-query --showformat='${Version}' --show rbw 2> /dev/null || echo 0.0.0)
            if dpkg --compare-versions "$latest_version" lt "$current_version"; then
                curl --location --output "$latest_rbw" "$url_prefix/$latest_rbw"
                sudo apt-get install --yes ./"$latest_rbw"
                rm -f "$latest_rbw"
            fi
            rbw="rbw"
        elif [[ "$CHEZMOI_OS" == "darwin" ]]; then
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

# shellcheck disable=SC2015,SC2155
function unlock_rbw() {
    log "▫️ Unlocking Rbw..."

    if [[ -z "$($rbw config show | _jq_field email)" ]]; then
        local bw_login
        read "bw_login?Enter your Bitwarden login: "
        $rbw config set email "$bw_login"
    fi
    if [[ "$($rbw config show | _jq_field lock_timeout)" != $(( 60*60*24 )) ]]; then
        $rbw config set lock_timeout $(( 60*60*24 ))
    fi

    if [[ -z "$($rbw config show | _jq_field pinentry)" ]]; then
        local pinentry
        if command -v pinentry-mac &> /dev/null; then
            pinentry="pinentry-mac"
        elif command -v pinentry-gnome3 &> /dev/null; then
            pinentry="pinentry-gnome3"
        elif command -v pinentry-qt &> /dev/null; then
            pinentry="pinentry-qt"
        elif command -v pinentry-tty &> /dev/null; then
            pinentry="pinentry-tty"
        elif command -v pinentry &> /dev/null; then
            pinentry="pinentry"
        elif command -v pinentry-curses &> /dev/null; then
            pinentry="pinentry-curses"
        fi
        if [[ -n "$pinentry" ]]; then
            $rbw config set pinentry "$pinentry"
        fi
    fi

    $rbw unlock && log "▫️ Rbw is unlocked" || return 1
}


if [[ "$(is_sourced)" == "true" ]]; then
    :
else
    install_main "$@"
fi
