#!/bin/sh

# shellcheck disable=SC2154
[   "true" = "$(
        chezmoi data \
        |   jq --raw-output 'any(.packages.darwin.bootstrap.formulae[]; . == "yq")'
    )" \
]
