###  Zinit Zsh completion plugins template begin

() {
    declare -a completions=(
        "$HOMEBREW_PREFIX/opt/curl/share/zsh/site-functions/_curl"(-N.)
    )
    local c
    for c in $completions; do
        zinit --light-mode \
            --lucid \
            --wait \
            --as='completion' \
            --is-snippet \
            --id-as="$(basename "$c")" \
            for "$c"
    done

    zinit --light-mode --lucid --wait --as='completion' --is-snippet for \
        --id-as='_bw' \
        --nocompile='!' \
        --pick='_bw' \
        --atclone='
            touch _bw
            if (( $+commands[bw] )); then
                bw completion --shell zsh >| _bw
            fi
        ' \
        --run-atpull \
        --atpull='%atclone' \
        /dev/null \
        --id-as='_chezmoi' \
        https://raw.githubusercontent.com/twpayne/chezmoi/refs/heads/master/completions/chezmoi.zsh \
        --id-as='_docker' \
        https://raw.githubusercontent.com/docker/cli/master/contrib/completion/zsh/_docker \
        --id-as='_gpg' \
        https://raw.githubusercontent.com/johan/zsh/master/Completion/Unix/Command/_gpg \
        --id-as='_kubectl' \
        --nocompile='!' \
        --pick='_kubectl' \
        --atclone='
            touch _kubectl
            if (( $+commands[kubectl] )); then
                kubectl completion zsh >| _kubectl
            fi
        ' \
        --run-atpull \
        --atpull='%atclone' \
        /dev/null
}

###  Zinit Zsh completion plugins template end
