#!/bin/sh

# shellcheck disable=SC2154

os=$(chezmoi data | jq --raw-output '.chezmoi.os')
[ "true" = "$(
    chezmoi data \
    | jq --raw-output --arg os "$os" 'any(.packages[$os].bootstrap.formulae[]; . == "jq")'
)" ]
