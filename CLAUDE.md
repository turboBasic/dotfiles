# Dotfiles (chezmoi)

This project is managed by [chezmoi](https://www.chezmoi.io). The source directory is `home/`.

For architecture details (install flow, encryption, hooks, test suite), see `ARCHITECTURE.md`.

## Chezmoi reference

For any chezmoi question, read `docs/chezmoi/CLAUDE.md` first to orient, then read specific files as needed. Use that corpus as the primary source of truth — do not rely solely on training knowledge.

Key lookups:

- File naming / source attributes: `reference/source-state-attributes.md`
- Template functions: `reference/templates/functions/<function>.md`
- Config file options: `reference/configuration-file/`
- CLI commands: `reference/commands/<command>.md`
- Special dirs/files: `reference/special-directories/`, `reference/special-files/`

## Source directory conventions

Files under `home/` follow standard chezmoi naming:

- `dot_` → `.` prefix in target
- `private_` → mode 0600
- `symlink_` → symlink in target
- `executable_` → mode +x
- `*.tmpl` → processed as Go template
- `modify_` → modify script
- `run_` / `run_once_` / `run_onchange_` → scripts in `.chezmoiscripts/`
