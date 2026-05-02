# dotfiles 2025

## Install

### Dependencies

- macOS or Ubuntu Linux
- age, curl, expect, git, grep, sed, tar, uname, unzip, zsh

### Command

```shell
# in Zsh shell:
AGE_PASSPHRASE="$(read -rs "p?Enter passphrase: "; printf '%s' "$p")" \
    sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init turboBasic/dotfiles
chezmoi apply
```

## Install using bootstrap script

<!-- markdownlint-disable MD024 -->
### Dependencies

- macOS or Ubuntu Linux
- curl, expect, git, grep, sed, tar, uname, unzip

### Command

```shell
sh -c "$(curl -fsSL "https://raw.githubusercontent.com/turboBasic/dotfiles/refs/heads/main/install.sh?$(date +%s)")" -- init turboBasic/dotfiles
```

## Updating accounts

When account data changes in Bitwarden (new account added, email updated, etc.), run:

```shell
./bw-update-accounts
```

This exports accounts from Bitwarden, encrypts and commits the result, then runs `chezmoi init --apply` to propagate changes to all templated files (gitconfigs, etc.). See [ARCHITECTURE.md](docs/ARCHITECTURE.md#updating-accounts-data) for details.
