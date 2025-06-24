### Zinit Install template begin

ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [ ! -d $ZINIT_HOME/.git ]; then
    mkdir -p "$ZINIT_HOME"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source $ZINIT_HOME/zinit.zsh

path=(
    $ZPFX/bin(-N/)
    $path
)
manpath+=(
    "$ZPFX/man"(-N/)
    /usr/share/man(-N/)
)
typeset -g ZIPL=$ZINIT[PLUGINS_DIR]
typeset -g ZISN=$ZINIT[SNIPPETS_DIR]

### Zinit Install template end
