#!/bin/sh

# shellcheck disable=SC2154

set +e

DUMMY_REPO=dummy-4aaO6plAj
result="SUCCESS"
for account in $(chezmoi data | jq --raw-output '.accounts | fromjson | keys[]'); do
    account_short="${account#accounts.}"
    echo "$account_short" | grep --silent --extended-regexp --regexp '-.+-' && continue

    dummy_repo="$HOME/projects/$account_short/$DUMMY_REPO"
    rm -rf "$dummy_repo"
    mkdir -p "$dummy_repo"
    git -C "$dummy_repo" init --quiet

    chezmoi_account_username=$(
        chezmoi data \
        |   jq --raw-output ' .accounts | fromjson | ."'"$account"'".git_username.value '
    )
    [ "$(git -C "$dummy_repo" config get user.name)" = "$chezmoi_account_username" ] || result="FAILURE"
    printf "repo: %-50s git user.name: %-15s git user.email: %s\n" \
        "$dummy_repo" \
        "$(git -C "$dummy_repo" config get user.name)" \
        "$(git -C "$dummy_repo" config get user.email)"
    rm -rf "$dummy_repo"
done

[ "$result" = 'SUCCESS' ]
