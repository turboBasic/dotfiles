#!/bin/sh

# shellcheck disable=SC2154
grep --silent "xerxischer-chamäleon" < "$CHEZMOI_CONFIG_DIR"/accounts.json
