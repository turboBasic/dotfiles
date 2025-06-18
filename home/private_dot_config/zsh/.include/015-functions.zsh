### Functions template begin

function cz-cd() {
    cd "$(command chezmoi source-path)"
}

function dotfiles-debug() {
    local timeOfDay=$(strftime -r %Y-%m-%d $(strftime %Y-%m-%d $EPOCHSECONDS))
    if [[ -n "$DOTFILES_DEBUG" ]]; then
        printf "%d. dotfiles-time: %.3f\n" $(( DOTFILES_DEBUG++ )) $(( EPOCHREALTIME-timeOfDay ))
    fi
}

function dotfiles-restart() {
    [[ -n "$DOTFILES_DEBUG" ]] && DOTFILES_DEBUG=0
    dotfiles-debug
    exec env -i PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin \
                TERM=$TERM \
                DOTFILES_DEBUG=$DOTFILES_DEBUG \
                zsh
}

function parent-process() {
    (( PPID > 0 )) && command ps -p $PPID -o pid,ppid,comm || echo "I am the parent process"
}

### Functions template end
