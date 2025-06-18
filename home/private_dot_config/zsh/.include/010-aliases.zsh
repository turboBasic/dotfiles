### Aliases template begin

# Conditionally set alias from zstyle with fallback
#
# Usage example:
#   zstyle ':dotfiles:alias' builtin_ls true
#       ...
#   set-builtin-command-alias ls '/bin/ls' 'command gls'
function set-builtin-command-alias() {
    local name=$1 true_cmd=$2 false_cmd=$3 default=${4:-false} value

    # Try to read the value from zstyle, or fall back
    if ! zstyle -s ':dotfiles:alias' "builtin_$name" value; then
        value=$default
    fi

    alias $name="$( [[ $value == true ]] && echo "$true_cmd" || echo "$false_cmd" )"
}

function zstyle-value() {
    local context=$1 setting=$2
    zstyle -s "$context" "$setting" REPLY
    print $REPLY
}

alias cz='command chezmoi'

# Usage: docker image ls --image-short-format
alias -g -- --image-short-format='--format="{{.ID}}・\
{{if gt (len .Repository) 45}}…{{slice .Repository (slice .Repository 44|len)}}\
{{else}}{{printf \"%-45s\" .Repository}}{{end}}・\
{{if gt (len .Tag) 20}}{{slice .Tag 19}}…{{else}}{{.Tag}}{{end}}"'

alias history='builtin fc -il'
# editorconfig-checker-disable-next-line
set-builtin-command-alias ls '/bin/ls --color=auto' 'command ls --color=auto --time-style=long-iso --group-directories-first'
alias  l='ls --classify --format=long --almost-all -v'
alias ll='l --all'
alias se=$'s'$(echo ud)'o se'$(echo cur)$'it'$'y'

alias -s jpg=open
alias -s jpeg=open
alias -s md=open
alias -s pdf=open
alias -s png=open
alias -s txt=open

### Aliases template end
