### Homebrew installation template begin

() {
    zinit for \
        --light-mode \
        --lucid \
        --id-as='brew' \
        --pick='brew.zsh' \
        --nocompile='!' \
        --atclone='
            local homebrew_prefix=$(_homebrew_prefix)
            if [[ ! -x "$homebrew_prefix/bin/brew" ]]; then
                NONINTERACTIVE=1 /bin/bash -c "$(
                    curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
                )"
            fi
            local homebrew=(
                $homebrew_prefix/bin/brew
                /home/linuxbrew/.linuxbrew/bin/brew
                /opt/homebrew/bin/brew
                /usr/local/bin/brew
            )
            homebrew=( ${^homebrew}(-*N) )
            "${homebrew[1]}" shellenv > brew.zsh
            unset homebrew_prefix homebrew
        ' \
        --run-atpull \
        --atpull='brew update' \
        zdharma-continuum/null

    # On Linux it is not needed as native GNU packages are used, not Homebrew versions
    [[ "$(uname)" == "Linux" ]] && return

    ##  Homebrew: modify paths to GNU packages
    (( $+commands[brew] )) &&
    zinit for \
        --light-mode \
        --lucid \
        --id-as='brew-essential-formulae' \
        --nocompile='!' \
        --atclone=$'
            local i j files symlinks

            # install symlinks to Homebrew versions of utilities
            symlinks=(
                $HOMEBREW_PREFIX/opt/*/libexec/gnubin/*(-*N)
                $HOMEBREW_PREFIX/opt/man-db/libexec/bin/*(-*N)
                $HOMEBREW_PREFIX/opt/curl/bin/*(-*N)
            )
            for j in $symlinks; do
                ln -sfv "$j" $HOME/.local/bin/"$(basename "$j")"
            done

            # update Man path
            echo "
                man_paths=(
                    \$HOMEBREW_PREFIX/opt/*/libexec/gnuman(N)
                    \$HOMEBREW_PREFIX/opt/curl/share/man(N)
                )
                for i in \$man_paths; do
                    manpath=( \$i \$manpath )
                done
            " > brew-essential-formulae.zsh

            # create symlinks for autocompletion
            symlinks=(
                $HOMEBREW_PREFIX/opt/curl/share/zsh/site-functions/_curl
            )
            for i in $symlinks; do
                ln -svf "$i" ~/.local/share/zinit/completions/
            done
            unset i j files symlinks
        ' \
        --atpull='%atclone' \
        --run-atpull \
        zdharma-continuum/null
}

##  Initialization of Homebrew & GNU utils paths

() {
    local homebrew_prefix=$(_homebrew_prefix)
    [[ -n "$homebrew_prefix" ]] && export HOMEBREW_PREFIX=$homebrew_prefix

    _path_to_gnu_utils_in_homebrew
    typeset -aU gnu_utils=( "${reply[@]}" )

    path=(
        ${ZPFX:+"$ZPFX/bin"}
        ${homebrew_prefix:+"$homebrew_prefix/bin"}  # Homebrew GNU utils will have priority over system's
        ${homebrew_prefix:+"$homebrew_prefix/sbin"}
        $path
        $gnu_utils                                  # …but also place them in the end system utils so that
                                                    # when system utils require priority GNU utils can be
                                                    # removed from beginning ans still be available with
                                                    # 'g' prefix: gls, gmkdir, …
    )
    path=( ${^path}(-N/) )  # only directories and symlinks to directories

    # Put Homebrew's completions before the system ones
    fpath=(
        ${homebrew_prefix:+"$homebrew_prefix/share/zsh/site-functions"}
        $fpath
    )
    fpath=( ${^fpath}(-N/) )
}

### Homebrew installation template end
