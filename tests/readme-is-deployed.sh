#!/bin/sh

# shellcheck disable=SC2154
grep "dotfiles sourceDir" <"$HOME"/README.md \
| grep --silent "$CHEZMOI_DATA_DIR/home"
