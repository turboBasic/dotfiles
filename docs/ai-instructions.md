# AI Instructions

Project rules for every harness. `CLAUDE.md`, `AGENTS.md` and `.github/copilot-instructions.md`
only point here — edit this file, not them.

chezmoi-managed dotfiles; the source dir is `home/` (`.chezmoiroot`). Read on demand:

- [ARCHITECTURE.md](ARCHITECTURE.md) — install flow, encryption, template data, hooks, tests
- [ZINIT.md](ZINIT.md) — Zinit conventions in this repo
- [README.md](../README.md) — user workflows

## References

Check chezmoi and Zinit behaviour against docs, not training data — both have changed across
versions and forks. chezmoi: the `chezmoi` skill, else `chezmoi-local`. Zinit: the `zinit` skill.

## Rules

- Do not commit or push unless asked. Commit subject: `type(scope): subject`, imperative.
- Shell scripts are Zsh with `set -euo pipefail`; `install.sh` stays POSIX because it runs
  before Zsh exists.
- In templates, switch delimiters (`chezmoi:template:left-delimiter`) only where content
  clashes with `{{ }}`.
- New secrets follow the [two-key model](ARCHITECTURE.md#encryption-model).
- Gate platform-specific paths in `.chezmoiignore`, never inside the file.
- Never hand-edit generated files; regenerate them:
  `home/.chezmoidata/vscode-extensions.yaml` and VS Code profile `settings.json`
  (`./vscode-import-profiles`), `docker-mcp/profile.yaml` (`docker mcp profile export`).
- `.claude/skills/` is canonical; `.agents/skills` is a symlink to it.

## `chezmoi apply` without a TTY

A drifted target aborts the whole run with `could not open a new TTY`. Apply the rest by
excluding the file **and its parent directory** — a directory target recurses into it. Never
`--force`; the user resolves drift.

```sh
chezmoi managed -0 --path-style=absolute | tr '\0' '\n' \
  | grep -vE '^/path/dir$|^/path/dir/file$' | tr '\n' '\0' | xargs -0 chezmoi apply -v
```
