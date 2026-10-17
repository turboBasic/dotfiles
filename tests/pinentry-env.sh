#!/bin/sh

is_totp=0
printf '%s\n' "OK Pleased to meet you"
while IFS= read -r cmd; do
    case "$cmd" in
        # cspell:disable-next-line
        SETDESC*[Cc]ode*|SETDESC*[Tt]oken*|SETDESC*[Tt]wo*|SETDESC*TOTP*|SETDESC*2FA*|SETDESC*[Aa]uthenticator*)
            is_totp=1
            printf '%s\n' "OK"
            ;;
        GETPIN)
            if [ "$is_totp" -eq 1 ]; then
                totp=$(oathtool --totp -b "$RBW_TOTP_SEED") || exit 1
                printf 'D %s\n' "$totp"
            else
                printf 'D %s\n' "$RBW_PASSWORD"
            fi
            printf '%s\n' "OK"
            ;;
        BYE)
            printf '%s\n' "OK closing connection"
            exit 0
            ;;
        *)
            printf '%s\n' "OK"
            ;;
    esac
done
