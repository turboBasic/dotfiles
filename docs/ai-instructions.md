# AI Instructions

@ARCHITECTURE.md

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

| Tool                  | Notes                                        |
| --------------------- | -------------------------------------------- |
| Configuration manager | chezmoi                                      |
| Shell                 | Zsh                                          |
| Templating            | Go templates (chezmoi)                       |
| Encryption            | age (symmetric + asymmetric)                 |
| Package management    | Homebrew, apt-get                            |
| Secret management     | rbw (Bitwarden CLI)                          |
| Task runner           | just (Makefile for rbw only)                 |
| Linting               | prek (markdownlint-cli2, shellcheck, cspell) |

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
├── 00-projects/personal/        ← VS Code workspace files for ~/00-projects/personal
│   ├── *.code-workspace         ← plain (relative paths only)
│   └── *.code-workspace.tmpl   ← templated (contain absolute paths via .chezmoi.homeDir / .projectDir)
├── private_Library/             ← macOS ~/Library (ignored on Linux)
├── symlink_dot_bashrc
├── symlink_dot_zshenv
└── README.md.tmpl
justfile                         ← task entry point (test, rbw, clean, update-accounts)
Makefile                         ← rbw build graph only; `just rbw` delegates here
mise.toml                        ← pins chezmoi, just and prek for this repo
.pre-commit-config.yaml          ← prek hooks: markdownlint-cli2, shellcheck, cspell
.markdownlint-cli2.jsonc         ← markdownlint rules, ignores and per-path overrides
install.sh                       ← POSIX bootstrap (also chezmoi hook)
tests/                           ← integration test suite
├── integration/                 ← individual test scripts (*.sh)
├── integration-tests-runner.zsh ← test runner (install + execute tests)
├── test-macos.sh                ← macOS test driver (UTM VM over SSH)
├── README-macos.md              ← macOS VM setup instructions
├── bin/<arch>/                  ← pre-built rbw binaries per platform
├── Dockerfile.ubuntu            ← test container image
└── Dockerfile.rbw-ubuntu        ← builds rbw binaries for linux/<arch>
op-export-accounts               ← 1Password account export helper
op-update-accounts               ← Full pipeline: export → commit → chezmoi init --apply
docs/
├── ai-instructions.md           ← you are here
├── ZINIT.md                     ← Zinit plugin manager conventions and reference
├── adr/                         ← Architecture Decision Records (NNNN-title.md + template.md)
├── zinit/                       ← Zinit Knowledge Base submodule
│   ├── cards/                   ← ~500 KB cards (ices, commands, concepts, annexes, packages, recipes, troubleshooting, installation, migration)
│   └── mcp/                     ← MCP server exposing search_cards / get_card / list_cards tools
└── chezmoi/                     ← chezmoi reference documentation corpus
```

## Zinit Reference

**Use the `zinit-kb` MCP server as the primary source for all Zinit questions.** It is
registered in `.mcp.json` and available as the `zinit-kb` server. Prefer it over reading
raw files or relying on training knowledge — Zinit has had forks and breaking changes.

MCP tools available:

- `search_cards` — keyword/tag/concept search across all KB cards; start here
- `get_card` — fetch a full card by id (e.g. `wait`, `lucid`, `cmd-load`)
- `list_cards` — list cards in a category or show category counts

Typical lookup flow:

1. Call `search_cards` with relevant terms (e.g. `"wait turbo"`, `"from'gh-r'"`, `"annex rust"`)
2. Call `get_card` on the most relevant result(s) for full details
3. For convention and file-architecture questions specific to this repo, also read `docs/ZINIT.md`

Before generating any Zinit config, confirm ices and commands via the MCP server — do not
rely solely on training knowledge.

## Chezmoi Reference

**Use the `chezmoi` skill (Claude Code global skill) as the primary source for all chezmoi questions.** Invoke it with the `/chezmoi` skill or via the `chezmoi` skill tool. Prefer it over reading raw files or relying on training knowledge.

The local corpus at `docs/chezmoi/` is available as a fallback for offline or deeper lookups. If you use it directly, read `docs/chezmoi/CLAUDE.md` first to orient, then read specific files as needed.

Key lookups in the local corpus:

- File naming / source attributes: `docs/chezmoi/src/reference/source-state-attributes.md`
- Template functions: `docs/chezmoi/src/reference/templates/functions/<function>.md`
- Config file options: `docs/chezmoi/src/reference/configuration-file/`
- CLI commands: `docs/chezmoi/src/reference/commands/<command>.md`
- Special dirs/files: `docs/chezmoi/src/reference/special-directories/`, `docs/chezmoi/src/reference/special-files/`

### Applying chezmoi while skipping conflicted files

`chezmoi apply` is non-interactive in this environment (no `/dev/tty`), so any target
with local drift (e.g. `~/.claude/settings.json` edited outside chezmoi) aborts the
whole run with `could not open a new TTY` instead of prompting.

To apply everything except known-conflicting targets:

1. List every managed target, NUL-delimited (handles paths with spaces, e.g. under
   `~/Library/Application Support/`):
   `chezmoi managed -0 --path-style=absolute`
2. Filter out the conflicting file **and its parent directory**. The parent directory
   is itself a managed target, and applying it recurses into all children — so
   excluding only the file is not enough; the directory entry re-triggers the same
   conflict.
3. Pipe the filtered list into `xargs -0 chezmoi apply -v`.

```sh
chezmoi managed -0 --path-style=absolute \
  | tr '\0' '\n' \
  | grep -vE '^/Users/aamelnyk/\.claude$|^/Users/aamelnyk/\.claude/settings\.json$' \
  | tr '\n' '\0' \
  | xargs -0 chezmoi apply -v
```

Skipped files stay diverged from the repo until the user resolves them explicitly —
do not use `--force` to silently overwrite local changes.

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
