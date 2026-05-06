# dotfiles 2025

## Prerequisites

- macOS (Apple Silicon) or Ubuntu Linux
- `AGE_PASSPHRASE` — the symmetric passphrase that decrypts the main age key.
  Obtain it from the password manager entry named "dotfiles age passphrase".

## Install

### Dependencies

- Zsh, age, curl, git, grep, sed, tar, uname, unzip

### Command

```zsh
# Zsh required (uses read -rs):
AGE_PASSPHRASE="$(read -rs "p?Enter passphrase: "; printf '%s' "$p")" \
    sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init turboBasic/dotfiles
chezmoi apply
```

## Install using bootstrap script

<!-- markdownlint-disable MD024 -->
### Dependencies

- curl, git, grep, sed, tar, uname, unzip (Zsh is installed automatically)

### Command

```shell
sh -c "$(curl -fsSL "https://raw.githubusercontent.com/turboBasic/dotfiles/refs/heads/main/install.sh?$(date +%s)")" -- init turboBasic/dotfiles
```

The bootstrap script prompts for `AGE_PASSPHRASE` interactively if not set.

## Updating accounts

When account data changes in Bitwarden (new account added, email updated, etc.), run:

```shell
./bw-update-accounts
```

This exports accounts from Bitwarden, encrypts and commits the result, then runs `chezmoi init --apply` to propagate changes to all templated files (gitconfigs, etc.). See [ARCHITECTURE.md](docs/ARCHITECTURE.md#updating-accounts-data) for details.
