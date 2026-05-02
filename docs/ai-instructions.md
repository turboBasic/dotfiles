# AI Instructions

> **Single source of truth for AI coding instructions.**
>
> - **Claude Code** reads this via `CLAUDE.md` (`@docs/ai-instructions.md`).
> - **GitHub Copilot** reads `.github/copilot-instructions.md`, which links to this file.
> - **Edit only this file.** Keep Copilot instructions as a thin pointer.

---

## Project Overview

**dotfiles**: Personal workstation configuration managed by [chezmoi](https://www.chezmoi.io). The chezmoi source directory is `home/`.

For architecture details (install flow, encryption, hooks, test suite), see `docs/ARCHITECTURE.md`.
For typical user workflows (installation, account updates), see `README.md`.

## Tech Stack

| Tool | Notes |
| --- | --- |
| Configuration manager | chezmoi |
| Shell | Zsh |
| Templating | Go templates (chezmoi) |
| Encryption | age (symmetric + asymmetric) |
| Package management | Homebrew, apt-get |
| Secret management | rbw (Bitwarden CLI) |

## Project Structure

> **Keep this section current.** When adding a new directory, update the tree below in the
> same change. Remove entries for deleted directories at the same time.

```plaintext
home/                            ← chezmoi source dir (declared via .chezmoiroot)
├── .chezmoi.toml.tmpl           ← config template, runs on init
├── .chezmoidata/
│   └── packages.yaml            ← package manifest for macOS/Linux
├── .chezmoiignore
├── .chezmoiscripts/
│   ├── run_onchange_before_decrypt-chezmoi-secrets.sh  ← decrypts secrets
│   └── run_onchange_01-install-packages.sh.tmpl        ← installs packages
├── .chezmoitemplates/           ← reusable template snippets
├── .chezmoiexternals/           ← external resources
├── .secrets/
│   ├── accounts.json.age        ← encrypted accounts
│   └── age-00-chezmoi.key.age   ← encrypted main age private key
├── dot_local/bin/               ← scripts installed to ~/.local/bin
├── private_dot_config/
│   ├── private_git/             ← per-account gitconfigs (templated, some encrypted)
│   ├── zsh/                     ← zsh config, zinit, functions, profiles
│   ├── mise/config.toml.tmpl
│   ├── atuin/, bat/, cspell/, ripgrep/, tmux/
│   └── private_Code/            ← VS Code config (Linux path)
├── private_Library/             ← macOS ~/Library (ignored on Linux)
├── symlink_dot_bashrc
├── symlink_dot_zshenv
└── README.md.tmpl
install.sh                       ← POSIX bootstrap (also chezmoi hook)
tests/                           ← integration test suite
bw-export-accounts               ← Bitwarden account export helper
bw-update-accounts               ← Full pipeline: export → commit → chezmoi init --apply
docs/
├── ai-instructions.md           ← you are here
└── chezmoi/                     ← chezmoi reference documentation corpus
```

## Chezmoi Reference

For any chezmoi question, read `docs/chezmoi/CLAUDE.md` first to orient, then read specific files as needed. Use that corpus as the primary source of truth — do not rely solely on training knowledge.

Key lookups:

- File naming / source attributes: `docs/chezmoi/src/reference/source-state-attributes.md`
- Template functions: `docs/chezmoi/src/reference/templates/functions/<function>.md`
- Config file options: `docs/chezmoi/src/reference/configuration-file/`
- CLI commands: `docs/chezmoi/src/reference/commands/<command>.md`
- Special dirs/files: `docs/chezmoi/src/reference/special-directories/`, `docs/chezmoi/src/reference/special-files/`

## Source Directory Conventions

Files under `home/` follow standard chezmoi naming:

- `dot_` → `.` prefix in target
- `private_` → mode 0600
- `symlink_` → symlink in target
- `executable_` → mode +x
- `*.tmpl` → processed as Go template
- `modify_` → modify script
- `run_` / `run_once_` / `run_onchange_` → scripts in `.chezmoiscripts/`

## Code Style & Conventions

### Formatting

- Follow `.editorconfig` in the repository root for formatting rules (charset, line endings,
  indentation, trailing whitespace, final newline).
- If a formatting rule here conflicts with `.editorconfig`, `.editorconfig` wins.

### Shell scripts

- Target Zsh unless POSIX portability is required (e.g. `install.sh`).
- Use `set -euo pipefail` in Zsh scripts.
- Quote all variable expansions.

### Chezmoi templates

- Use standard Go template delimiters `{{` / `}}` unless the file content conflicts
  (e.g. heredocs); in that case use custom delimiters declared via
  `chezmoi:template:left-delimiter` / `right-delimiter` directives.

### Commit messages

- Use Conventional Commits format: `type(scope): subject`
  (e.g. `feat(zsh): add fzf integration`), with an imperative subject and no trailing period.

## AI Behaviour Guidelines

- **Minimal changes**: prefer targeted edits over large refactors unless explicitly asked.
- **Follow existing patterns**: read the surrounding code before suggesting changes.
- **No secrets**: never generate tokens, passwords, or credentials.
- **Encryption**: when adding new secret files, follow the two-key encryption model
  documented in `docs/ARCHITECTURE.md`.
- **Platform awareness**: check `.chezmoiignore` when adding platform-specific files;
  gate paths appropriately for `darwin` / `linux`.
