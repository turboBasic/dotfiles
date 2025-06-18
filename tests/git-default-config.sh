#!/bin/sh

# shellcheck disable=SC2154

dummy_repo=$(mktemp --directory)
git -C "$dummy_repo" init --quiet
chezmoi_account_username=$(
    chezmoi data |   jq --raw-output '.accounts | fromjson | ."accounts.personal".git_username.value'
)

if [ "$(git -C "$dummy_repo" config get user.name)" = "$chezmoi_account_username" ]; then
    rm -rf "$dummy_repo"
    true
else
    rm -rf "$dummy_repo"
    false
fi
