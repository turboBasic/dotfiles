#!/usr/bin/env zsh
# shellcheck disable=SC1071
# accounts.json.age hash: {{ include ".secrets/accounts.json.age" | sha256sum }}

# This file decrypts secrets required by Chezmoi during initialization.
# Secrets are taken from .secrets/ source dir

function main() {
    set_global_vars
    mkdir -p "$DEST_DIR"
    chmod 700 "$DEST_DIR"

    local secret_file
    get_secret_files
    for secret_file in $reply; do
        if [[ -s "$DEST_DIR/$secret_file" ]]; then
            log "▫️ Rename $DEST_DIR/$secret_file to $DEST_DIR/$secret_file.old"
            mv -f "$DEST_DIR/$secret_file" "$DEST_DIR/$secret_file.old"
        fi

        # Main key used by Chezmoi is encrypted using symmetric encryption while other
        # secret might be encrypted either symmetrically or using main Chezmoi key,
        # that's why we try both methods for decryption.
        # `chezmoi age decrypt` does not support symmetric encryption so we have to use
        # `age` tool preinstalled at the host.
        if ! decrypt_using_chezmoi_key "$secret_file" > /dev/null; then
            decrypt_using_passphrase "$secret_file"
        fi
        [[ -f "$DEST_DIR/$secret_file" ]] && chmod 600 "$DEST_DIR/$secret_file"
    done
    unset passphrase
}

function get_secret_files() {
    typeset -aU result=($DOTFILES_KEY_NAME)
    local secret_file secret_short_name
    for secret_file in "$SOURCE_DIR"/*.age; do
        secret_short_name="${secret_file##*/}"
        secret_short_name="${secret_short_name%.age}"
        result+=("$secret_short_name")
    done
    typeset -ag reply=( $result )
}

function decrypt_using_chezmoi_key() {
    local secret_file="$1"
    log "▫️ Decrypting $secret_file.age using key $DOTFILES_PRIVATE_KEY"
    age --decrypt \
        --identity "$DOTFILES_PRIVATE_KEY" \
        --output "$DEST_DIR/$secret_file" \
        "$SOURCE_DIR/$secret_file.age" 2>&1
    local result=$?
    if (( result != 0)); then
        log "🔸 Cannot decrypt secret $secret_file.age using Chezmoi key $DOTFILES_PRIVATE_KEY"
    else
        log "✅ Successfully decrypted $secret_file.age"
    fi
    return $result
}

function decrypt_using_passphrase() {
    local secret_file="$1"

    if [[ -z "${passphrase:=$AGE_PASSPHRASE}" ]]; then
        read -r -s "passphrase?[decrypt-chezmoi-secrets] Enter passphrase: "
        echo
    fi
    if [[ -z "$passphrase" ]]; then
        echo "⚠️ [decrypt-chezmoi-secrets] When executed by chezmoi init, passphrase can't be read from terminal and should be provided in AGE_PASSPHRASE env var" >&2
        log "❌ Passphrase is missing."
        return 1
    fi

    log "▫️ Decrypting $secret_file.age using passphrase"
    AGE_PASSPHRASE="$passphrase" \
    "${age_passphrase_decrypt_cmd[@]}" \
        --decrypt \
        "$SOURCE_DIR/$secret_file.age" \
        "$DEST_DIR/$secret_file"

    local result=$?
    if (( result != 0)); then
        log "🔸 Cannot decrypt secret $secret_file.age using passphrase"
    else
        log "✅ Successfully decrypted $secret_file.age"
    fi
    return $result
}

function set_global_vars() {
    DEST_DIR=$(dirname "$CHEZMOI_CONFIG_FILE")
    SOURCE_DIR="$CHEZMOI_SOURCE_DIR/.secrets"
    DOTFILES_PRIVATE_KEY="$DEST_DIR/$DOTFILES_KEY_NAME"
    age_passphrase_decrypt_cmd=(/bin/sh "$CHEZMOI_SOURCE_DIR/dot_local/bin/executable_age-passphrase")
    declare -g passphrase=""
}

function log() {
    if [[ "${1[1,1]}" == "❌" ]]; then
        echo "$*" >&2
    elif [[ -n "$CHEZMOI_DEBUG" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}


main "$@"
