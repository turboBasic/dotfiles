# Global Instructions

Authoring defaults for repositories under `~/00-projects/`. Elsewhere — client code, vendored
or open-source repos — the repo's conventions win; suggest rather than act. Prohibitions below
constrain what you write; they never mandate migrating existing tooling. A project's own rules
override these.

## This Machine

- macOS, Zsh with Zinit, chezmoi-managed from `~/00-projects/personal/turboBasic/dotfiles/`
  (see its `docs/`). Aliases, functions and `PATH`
  come from there — look there first when a command surprises.
- GNU coreutils shadow BSD ones on `PATH`, so BSD-only flags fail; use `/usr/bin/sed` etc.
  when BSD behaviour is needed.
- Claude Code's Bash tool is pinned to bash 5 via the undocumented `CLAUDE_CODE_SHELL`, which
  can lapse silently to zsh. When a command behaves impossibly, check `ps -p $$ -o comm=`; put
  bash-dependent code in `bash -c '…'`.

## How I Work

- Terse; end with a one-sentence summary. No emojis. No hedging.
- Verify before assuming; match existing patterns; scope to the request; ask when ambiguous.
- Never touch remote or shared state (Terraform state, live databases, deployed environments)
  without explicit instruction — hand back the command and what it would change.
- Never `sleep` to wait for a background agent: completion is push-notified, so sleeping only
  adds idle time. Launch independent agents together, as soon as their input is known. Never
  predict a pending agent's result.

## Tool Invocation

Single source of truth for running anything, linting and tests included.

1. **Entry point first:** `justfile`, then `Makefile`, then `mise run` (`mise tasks` lists,
   including user-level ones). Never reimplement a target that exists. Where a new task
   belongs is owned by the `task-runners` rule (`~/.claude/rules/task-runners.md`).
2. **No entry point:** `uv run <tool>` in Python projects, `mise exec -- <tool>` for tools a
   present `mise.toml` manages, else direct.

### Linting

- Linters run through prek (or lefthook where `lefthook.yml` exists — never migrate between
  them unasked); never call one directly. Pass a single hook name when only one applies.
- Wire a new linter into the existing runner, not a script or CI-only step.
- Fix lint errors immediately. A failing generated file is a generator bug.
- Never disable a rule silently: turn it off in the linter config with a reason, and report it.
- When a hook auto-fixes files, re-stage only those files and retry.

### Tests

Run targeted tests for what you changed; the full suite only when asked or verifying a fix.
Fix failures your change caused before reporting done.

## Writing Code

- Every project has an `.editorconfig`; obey it. A new file type updates `.editorconfig`,
  `.gitattributes` and `.gitignore` in the same change.
- Conventional Commits. Comments only for a non-obvious why.
- Load the stack skill before the first line: `scaffold:modern-python`, `stacks:shell`,
  `stacks:go`, `stacks:terraform`. New project: `scaffold:new-project`.
- Library docs: a docs skill if one exists, else Context7 with pinned IDs — `just` →
  `/websites/just_systems_man_en`, Claude Code → `/websites/code_claude`, Terraform →
  `/websites/developer_hashicorp_terraform`. Zsh: man pages.

## Instructions

Before adding a document or rule, find the one that owns the concern; update it and link to it.

@RTK.md
