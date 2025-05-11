# Dotfiles, 2025

This repo contains dotfile managed by [Chezmoi].

## Install

- Install [Chezmoi] as described in their [installation guide](https://www.chezmoi.io/install/).
- Apply these dotfiles:

  ```bash
  chezmoi init --apply --verbose https://github.com/turboBasic/dotfiles.git
  echo "Your Bitwarden password" > ~/.ssh/bw_password
  chmod 600 ~/.ssh/bw_password
  ```

### Alternative installation
You can install both Chezmoi and these Dotfiles using the following oneliner:
```bash
sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply turboBasic
```


<!-- Links -->
[Chezmoi]: https://www.chezmoi.io/
