### Homebrew installation template begin

zinit for \
    --lucid \
    --id-as='tb::zsh-homebrew' \
    --atclone='
        source zsh-homebrew.plugin.zsh
        homebrew_shell_env > brew.zsh
        homebrew_create_symlinks_to_gnu_utils
    ' \
    --nocompile='!' \
    --pick='brew.zsh' \
    --src='zsh-homebrew.plugin.zsh' \
    --run-atpull \
    --atpull='%atclone' \
    turboBasic/zsh-homebrew

# (Applies to macOS only, where GNU Coreutils are installed by Homebrew)
#
# Put GNU utils to the end of path. They already have priority over system's utilities,
# …but we also place them in the end of PATH so that when system utils require priority
# GNU utils can be removed from beginning ans still be available with 'g' prefix:
# gls, gmkdir, …
path+=( $(homebrew_path_to_gnu_utils) )

### Homebrew installation template end
