### Zinit heavy plugins template begin

##  Heavy Zinit plugins, loaded asynchronously in Turbo mode
zinit --lucid --wait for \
    --from='gh-r' \
    --dl='
        https://raw.githubusercontent.com/junegunn/fzf/master/shell/completion.zsh -> _fzf_completion;
        https://raw.githubusercontent.com/junegunn/fzf/master/shell/key-bindings.zsh -> key-bindings.zsh;
        https://raw.githubusercontent.com/junegunn/fzf/master/man/man1/fzf-tmux.1 -> $ZPFX/man/man1/fzf-tmux.1;
        https://raw.githubusercontent.com/junegunn/fzf/master/man/man1/fzf.1 -> $ZPFX/man/man1/fzf.1
    ' \
    --sbin='fzf -> fzf' \
    --compile='(_fzf_completion|key-bindings.zsh)' \
    --nocompile='!' \
    --pick='key-bindings.zsh' \
    --atpull='%atclone' \
    @junegunn/fzf \
    --from='gh-r' \
    --bpick='atuin-*.tar.gz' \
    --cp='atuin*/atuin -> atuin' \
    --sbin='atuin -> atuin' \
    --compile='(init_disable_up_arrow.zsh|_atuin)' \
    --nocompile='!' \
    --atclone='
        ./atuin init zsh --disable-up-arrow > init_disable_up_arrow.zsh
        ./atuin gen-completions --shell zsh > _atuin
        ./atuin import zsh
    ' \
    --pick='init_disable_up_arrow.zsh' \
    --run-atpull \
    --atpull='%atclone' \
    atuinsh/atuin \
    --as='null' \
    --has='pkg-config' \
    --pick='misc/quitcd/quitcd.bash_sh_zsh' \
    --make='install PREFIX=$ZPFX MANPREFIX=$ZPFX/man' \
    jarun/nnn \
    mattmc3/zman \
    --from='gh-r' \
    --mv='mise-v* -> mise' \
    --cp='mise -> $ZPFX/bin/mise' \
    --sbin='mise -> mise' \
    --atclone='
        mise completion zsh > _mise
        mise activate zsh > mise.zsh
    ' \
    --nocompile='!' \
    --compile='(mise.zsh|_mise)' \
    --src='mise.zsh' \
    --run-atpull \
    --atpull='%atclone' \
    --atload='path=( ${path:#$ZINIT[PLUGINS_DIR]/jdx---mise} )' \
    jdx/mise \
    --as='null' \
    --from='gh-r' \
    --fbin \
    jdx/usage \
    --wait='1' \
    --id-as='rbw' \
    --atclone=$'
        if [[ "$(uname)" == "Darwin" ]]; then
            #echo "rbw config set pinentry rbw-pinentry-macos-keychain-simple" > rbw.zsh
            echo \'[[ "$(rbw config show | jq -r .pinentry)" == "pinentry-tty" ]] || rbw config set pinentry pinentry-tty\' > rbw.zsh
        elif [[ "$(uname)" == "Linux" ]]; then
            echo \'[[ "$(rbw config show | jq -r .pinentry)" == "pinentry-tty" ]] || rbw config set pinentry pinentry-tty\' > rbw.zsh
        fi
    ' \
    --nocompile='!' \
    --run-atpull \
    --atpull='%atclone' \
    --src='rbw.zsh' \
    zdharma-continuum/null \
    # last line

### Zinit heavy plugins template end
