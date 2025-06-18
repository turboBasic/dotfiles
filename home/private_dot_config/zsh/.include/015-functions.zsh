### Functions template begin

function cz-cd() {
    cd "$(command chezmoi source-path)"
}

function parent-process() {
    (( PPID > 0 )) && command ps -p $PPID -o pid,ppid,comm || echo "I am the parent process"
}

# Find path to Homebrew binary, empty if not found
#
# shellcheck disable=SC1036
function _path_to_homebrew() {
    typeset -aU homebrew=(
        $commands[brew]
        $HOMEBREW_PREFIX/bin/brew
        /home/linuxbrew/.linuxbrew/bin/brew
        /opt/homebrew/bin/brew
        /usr/local/bin/brew
    )
    reply=( ${^homebrew}(-*N) )  # only executable files, including symlinks to them
}

# Find Homebrew prefix without executing Homebrew, empty if not found
function _homebrew_prefix() {
    if [[ -n "$HOMEBREW_PREFIX" ]]; then
        echo $HOMEBREW_PREFIX
    elif (( $+commands[brew] )); then
        echo ${${commands[brew]%/*}%/*} # /opt/homebrew/bin/brew → /opt/homebrew
    else
        _path_to_homebrew
        echo ${${reply[1]%/*}%/*}
    fi
}

# Find path to Homebrew's GNU Coreutils package, empty if not found
#
# shellcheck disable=SC1036
function _path_to_gnu_utils_in_homebrew() {
    local homebrew_prefix=$(_homebrew_prefix)
    if [[ -n "$homebrew_prefix" ]]; then
        reply=( $homebrew_prefix/opt/coreutils/libexec/gnubin(-N/) )
        reply=( ${^reply}(-N/) )  # only directories and symlinks to directories
    else
        reply=()
    fi
}

### Functions template end
