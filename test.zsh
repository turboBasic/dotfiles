#!/usr/bin/env zsh
# shellcheck disable=SC1071

# Usage:
#   zsh -c "$(curl -fsLS "https://raw.githubusercontent.com/turboBasic/dotfiles/refs/heads/main/test.zsh?$(date +%s)")"

if [ -z "$ZSH_VERSION" ]; then
    echo "❌ This script should be run in Zsh." >&2
    return 1 &>/dev/null || exit 1
fi

function main test_main () {
    set_global_vars
    if [[ "$1" == "--local" ]]; then
        shift
        FLAG_LOCAL=true
    fi
    install_dotfiles
    execute_tests
}

function execute_tests() {
    printf '\n%s\n\n' "## Executing tests..."
    (
        cd "$CHEZMOI_DATA_DIR" || exit
        for t in tests/*.sh; do
            test_short_name=${${t##*/}%.sh}
            log "▫️ Execute test $test_short_name ($REPO_TEST_URL/$t):"

            if CHEZMOI_CONFIG_DIR="$CHEZMOI_CONFIG_DIR" CHEZMOI_DATA_DIR="$CHEZMOI_DATA_DIR" /bin/sh -e "$t"; then
                result=SUCCESS
            else
                result=FAILURE
            fi
            printf '%s %-40s (%s)\n' $result $test_short_name $CHEZMOI_DATA_DIR/tests/$t
        done
    )
}

function set_global_vars() {
    CHEZMOI_CONFIG_DIR="$HOME/.config/chezmoi"
    CHEZMOI_DATA_DIR="$HOME/.local/share/chezmoi"

    local dotfiles_repo="turboBasic/dotfiles"
    REPO_URL="https://github.com/$dotfiles_repo"

    local repo_test_url_base="https://raw.githubusercontent.com/$dotfiles_repo"
    local repo_branch="main"
    REPO_TEST_URL="$repo_test_url_base/refs/heads/$repo_branch"

    FLAG_LOCAL=""
}

function install_dotfiles() {
    if [[ "$FLAG_LOCAL" != "true" ]]; then
        source <(curl -fsSL "$REPO_TEST_URL/install.zsh?$(date +%s)")
        log "▫️ install_main() init $REPO_URL.git"
        install_main --cleanup init $REPO_URL.git
    else
        source "$CHEZMOI_DATA_DIR"/install.zsh
        log "▫️ install_main() init"
        install_main init
    fi
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


if [[ "$(is_sourced)" == "true" ]]; then
    echo "❌ This script should be run by Zsh, not sourced." >&2
    return 1
else
    test_main "$@"
fi
