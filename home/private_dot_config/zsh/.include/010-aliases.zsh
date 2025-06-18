### Aliases template begin

# Usage: docker image ls --image-short-format
alias -g -- --image-short-format='--format="{{.ID}}・\
{{if gt (len .Repository) 45}}…{{slice .Repository (slice .Repository 44|len)}}\
{{else}}{{printf \"%-45s\" .Repository}}{{end}}・\
{{if gt (len .Tag) 20}}{{slice .Tag 19}}…{{else}}{{.Tag}}{{end}}"'

alias cz='=chezmoi'
alias history='builtin fc -il'
alias ls='=ls --color=auto --time-style=long-iso --group-directories-first'
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
