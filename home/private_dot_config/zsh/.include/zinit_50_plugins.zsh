### Zinit generic plugins template begin

# Zinit ice modifiers
#
#      pick Select the file to source, or the file to set as command (when using snippet --command
#           or the ice as"program"); it is a pattern, alphabetically first matched file is being chosen;
#           e.g. zinit ice pick"*.plugin.zsh"; zinit load ….
#       src Specify additional file to source after sourcing main file or after setting up command (via as"program").
#           It is not a pattern but a plain file name.
#   compile Pattern (+ possible {...} expansion, like {a/*,b*}) to select additional files to compile,
#           e.g. `compile="(pure|async).zsh"
# nocompile Don't try to compile pick-pointed files. If passed the exclamation mark (i.e. nocompile'!'),
#           then do compile, but after make'' and atclone'' (useful if Makefile installs some scripts, to point
#           pick'' at the location of their installation).
#
#           Order of execution of related Ice-mods:
#               atinit -> atpull! -> make'!!' -> mv -> cp -> make! ->
#               atclone/atpull -> make -> (plugin script loading) ->
#               src -> multisrc -> atload
#
#   See     https://github.com/zdharma-continuum/zinit?tab=readme-ov-file#ice-modifiers


##  Zinit lightweight plugins, loaded without Turbo mode
zinit --light-mode --lucid for \
    zdharma-continuum/z-a-meta-plugins \
    zdharma-continuum/zinit-annex-unscope \
    zdharma-continuum/zinit-annex-readurl \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-submods \
    zdharma-continuum/zinit-annex-bin-gem-node \
    @sharkdp \
    --compile='(pure|async).zsh' pick='async.zsh' src='pure.zsh' \
    sindresorhus/pure \
    --as='null' \
    --id-as='idea' \
    --if='[[ -d "$HOME/Library/Application Support/JetBrains/Toolbox/scripts" ]]' \
    --sbin='idea' \
    --sbin='pycharm' \
    --atclone='
        local idea_scripts_path="$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
        cp "$idea_scripts_path"/* ./ || {
            +zi-log "{b}{u-warn}ERROR{b-warn}:{rst} Failed to copy from {cmd}$idea_scripts_path/{rst}"
            false
        }
        mv -vf idea{1,} || true
        mv -vf pycharm{1,} || true
    ' \
    --run-atpull \
    --atpull='%atclone' \
    zdharma-continuum/null \
    --id-as='zsh-diff-so-fancy' \
    --sbin='bin/git-dsf -> git-dsf' \
    --sbin='bin/diff-so-fancy -> diff-so-fancy' \
    --atload='path=( ${path:#${ZINIT[PLUGINS_DIR]}/zsh-diff-so-fancy/bin} )' \
    zdharma-continuum/zsh-diff-so-fancy \
    --as='null' \
    --id-as='getoptions' \
    --make='install PREFIX=$ZPFX' \
    --run-atpull \
    --atpull='%atclone' \
    ko1nksm/getoptions \
    \
    # last line ;)


## Zinit snippets
zinit --lucid --wait for \
    --id-as='tb::aws-helpers' \
    https://gist.githubusercontent.com/turboBasic/02cf7612109d6d1434364bb7bf2d3ac6/raw/aws.zsh \
    --id-as='tb::git-commit-size' \
    https://gist.githubusercontent.com/turboBasic/7b5ac4b1524f19b4520ff61a4a9e78ed/raw/git-commit-size \
    --id-as='tb::locale-demo' \
    https://gist.githubusercontent.com/turboBasic/00d416619ed3fd8f20161c3449574c69/raw/locale-demo.zsh \
    --id-as='tb::ls-colors' \
    --nocompile='!' \
    --atclone='zsh --no-rcs tb::ls-colors molokai > colors.sh' \
    --pick='colors.sh' \
    --atpull='%atclone' \
    --atload='zstyle ":completion:*" list-colors "${(s.:.)LS_COLORS}"' \
    https://gist.githubusercontent.com/turboBasic/26d0b94957864767a07f18e7c689a0ce/raw/generate.sh \
    --id-as='sqids' \
    --as='null' \
    --sbin='sqids' \
    --atclone='chmod +x sqids' \
    --atpull='%atclone' \
    https://raw.githubusercontent.com/sqids/sqids-bash/refs/heads/main/src/sqids \
    OMZL::clipboard.zsh \
    --atload='unfunction uninstall_oh_my_zsh upgrade_oh_my_zsh' \
    OMZL::functions.zsh \
    OMZL::git.zsh \
    --atload='fpath=( ${fpath:#${ZINIT[SNIPPETS_DIR]}/OMZP::z} )' \
    OMZP::z \
    OMZP::zsh-interactive-cd \
    \
    # last line ;)


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
    \
    # last line

### Zinit generic plugins template end
