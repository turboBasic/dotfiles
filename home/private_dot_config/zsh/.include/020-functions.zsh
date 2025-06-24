### Functions template begin

() {
    # capture all files in functions/ dir including those starting with dot
    typeset -a function_files=( $ZDOTDIR/functions/*(.D) )
    typeset function_files_str=${(F)function_files}

    # Leave only basenames
    typeset -a function_names=( ${^function_files:t} )
    typeset function_names_str=${(F)function_names}

    # Remove existing functions which conflict with our function_names
    typeset -a existing_functions=( ${${(k)functions}:*function_names} )
    (( $#existing_functions )) && unfunction $existing_functions

    # Now when all conflicting functiones are removed we can autoload our functions
    builtin autoload -Uz $function_files
}

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
