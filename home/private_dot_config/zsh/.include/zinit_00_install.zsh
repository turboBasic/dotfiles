### Zinit Install template begin

# shellcheck disable=SC1072,SC1073~/.loca
() {
    ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
    if [ ! -d $ZINIT_HOME/.git ]; then
        mkdir -p "$ZINIT_HOME"
        git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
    fi

    path=( $reply $path ) source $ZINIT_HOME/zinit.zsh
    path=(
        $ZPFX/bin(-N/)
        $path
    )
    manpath+=( "$ZPFX/man"(-N/) /usr/share/man(-N/) )
}

function lzipl() {
    command ls --color=auto --time-style=long-iso --group-directories-first \
                --classify --format=long --almost-all \
                ${ZINIT[PLUGINS_DIR]}/${1:-}
}

function lzisn() {
    command ls --color=auto --time-style=long-iso --group-directories-first \
                --classify --format=long --almost-all \
                ${ZINIT[SNIPPETS_DIR]}/${1:-}
}

ZIPL=$ZINIT[PLUGINS_DIR]
ZISN=$ZINIT[SNIPPETS_DIR]

### Zinit Install template end
