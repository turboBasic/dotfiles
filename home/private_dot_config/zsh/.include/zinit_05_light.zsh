### Zinit light plugins template begin

##  Zinit lightweight plugins, loaded synchronously
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
    ko1nksm/getoptions

### Zinit light plugins template end
