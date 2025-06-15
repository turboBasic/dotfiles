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
- curl, expect, git, grep, sed, tar, uname, unzip, zsh

### Command

```shell
zsh -c "$(curl -fsSL "https://raw.githubusercontent.com/turboBasic/dotfiles/refs/heads/main/install.zsh?$(date +%s)")" -- init turboBasic/dotfiles
```
