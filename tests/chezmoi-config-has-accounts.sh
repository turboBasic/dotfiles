#!/bin/sh

# shellcheck disable=SC2154
[ "$(chezmoi data | jq --raw-output '.accounts | fromjson | ."accounts.personal".name')" = "accounts.personal" ]
[ "$(chezmoi data | jq --raw-output '.aliases | fromjson | ."10-personal"')" = "accounts.personal" ]
