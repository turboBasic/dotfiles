# Global Claude Code Instructions

Rules that apply to every project regardless of language or domain.

---

## Scope of These Rules

These are **authoring defaults for repositories the user owns** — those under
`~/00-projects/`. In a repo the user did not set up (client code, a vendored dependency,
an open-source contribution), the conventions already in the repo win: match them, and
raise a suggestion rather than acting on it.

A rule below phrased as a prohibition — "no `requirements.txt`", "no `black`", "every
project must have an `.editorconfig`" — constrains what you **write**. It is not a mandate
to migrate what is already there. Never convert a foreign repo's build tooling, package
manager, task runner, or lint configuration without being asked.

---

## Environment Context

- Projects live in `~/00-projects/` with subdirectories for personal and work contexts.
- Dotfiles are chezmoi-managed from `~/00-projects/personal/turboBasic/dotfiles/`.
  That repo contains full documentation on the shell environment, including the Zinit
  plugin manager setup (`docs/ZINIT.md`) and architecture (`docs/ARCHITECTURE.md`).
- The shell is Zsh with Zinit for plugin management (turbo mode, annexes, numbered
  config files). Refer to the dotfiles repo for conventions before modifying shell config.
- If commands behave unexpectedly (aliases, PATH issues, missing tools), check the
  dotfiles repo — shell aliases, functions, and PATH manipulation are defined there.
- **macOS with GNU coreutils:** GNU versions of `grep`, `sed`, `awk`, `find`, etc.
  have higher priority in PATH than BSD variants. This means BSD-specific flags will
  fail silently or error. When portability matters or behavior is surprising, use
  absolute paths (e.g. `/usr/bin/sed` for BSD sed). Modern alternatives are also
  available: `rg` (ripgrep), `fd`, `bat`, `eza`, etc.

---

## Shell Commands — the Bash tool's shell is pinned to bash

The `Bash` tool spawns whatever `CLAUDE_CODE_SHELL` names; `settings.json` pins it to
`/opt/homebrew/bin/bash` (5.x) so the tool runs real bash. **That variable is
undocumented and may lapse silently on upgrade**, dropping the tool back to `/bin/zsh`
5.9 with no rc sourced — no error, just zsh semantics again. When a command fails or
returns something impossible, confirm the interpreter with `ps -p $$ -o comm=` before
debugging the command. Under zsh, the failure modes are:

- **An unmatched glob aborts the command** (`nomatch`), and `2>/dev/null` does not rescue
  it. Prefer handing the pattern quoted to the tool that expands it: `rg --glob '*.md'`.
- **Unquoted `$var` does not word-split** — `for f in $files` iterates once over the whole
  string, a silent wrong answer. Unquoted `$(cmd)` does split. Use `${(f)files}`.
- **Arrays are 1-indexed** — `${a[0]}` is empty.
- **No `mapfile` or `shopt`**; `${v,,}` → `${v:l}`, `${!n}` → `${(P)n}`.

Escape hatch under either shell: put anything bash-dependent in `bash -c '…'`.

---

## Tone and Responses

- Terse responses. End with a one-sentence summary of what changed — no multi-paragraph recaps.
- No emojis unless explicitly requested.
- Prefer direct statements over hedging.

---

## Tool Invocation

**This section is the single source of truth for how to run anything.** Other sections
name which tool to use for a job; none of them restate this ordering.

Two separate questions — answer them in that order.

### 1. Which entry point?

Prefer the project's own entry point over invoking a tool yourself. If a `lint`, `test`,
or `fmt` target exists, use it; do not reimplement what it does.

1. **`justfile`** — the preferred task runner. `just` with no arguments lists recipes.
2. **`Makefile`** — equal standing where one exists; the correct choice in repos with real
   file-based staleness (see the boundary below).
3. **`mise` tasks** — `mise run <task>`; `mise tasks` lists what exists, including
   user-level tasks defined in `~/.config/mise/config.toml`.
4. **No entry point covers the job** — fall through to question 2.

### 2. How to resolve the binary?

Only once no entry point covers it:

1. **`uv run <tool>`** — Python project-local tools (pytest, pyright, ruff) in any repo
   with a `pyproject.toml`.
2. **`mise exec -- <tool>`** — tools mise manages (terraform, go, node, prek).
3. **Direct invocation** — only when neither of the above applies.

Check for `mise.toml` / `.mise.toml` before reaching for `mise exec --`, and use it only
for tools mise actually manages. Never assume mise is present in a foreign or unfamiliar
project — look first.

### The boundary: mise / Just / Make

**mise owns the environment. Just owns the workflows. Make owns file staleness.**

| Concern                                                     | Home                            |
| ----------------------------------------------------------- | ------------------------------- |
| Tool versions, `PATH`, env vars, secret injection           | `mise.toml` `[tools]` / `[env]` |
| Named workflows a human types                               | `justfile`                      |
| Tasks needing mise's env engine, or that must work anywhere | mise `[tasks.*]`                |
| Artifacts with genuine file-based staleness                 | `Makefile`                      |

- **A task belongs in mise only when it needs something Just cannot give it** — per-task
  env or secret injection, a task-scoped tool version, or availability outside any repo.
  The `claude-*` tasks in `~/.config/mise/config.toml` qualify on two counts: they inject
  a secret-backed token and they are user-level, not project-level.
- **Keep a `Makefile` where the dependency graph is load-bearing.** Just has no
  file-based staleness checking, only recipe-to-recipe dependencies. A Makefile whose
  targets gate an expensive rebuild on input timestamps must not be converted to a
  justfile to satisfy a preference.
- **Calls go one way: `just` → `mise run`, never the reverse.** Bidirectional wrapping
  leaves no clear owner of a task name. One owner per name.
- **Recipes carry no `mise exec --` prefix.** If mise is activated the tools are already
  on `PATH`; if it is not, that is an environment bug to fix, not to paper over per recipe.
- **When a task could live in either, put it in the justfile** and let it rely on mise's
  activated environment.

---

## Subagents and Background Tasks

- **Never `sleep` to wait for a background agent or task.** Completion is push-notified,
  and a notification cannot interrupt a running Bash call — so every second of sleep past
  the task's actual duration is guaranteed idle time, and the guess is usually wrong by
  minutes. Launch, then do unrelated work or end the turn.
- Where a result is genuinely blocking, `TaskOutput` with `block: true` returns the instant
  the task completes. Prefer just letting the notification arrive.
- **Launch independent agents in one message** so they run concurrently, and launch each one
  as soon as its input is known rather than at the step that consumes its output.
- Never predict a pending agent's result. If asked before its notification arrives, say it
  is still running.

---

## Editor and Formatting

- Vim mode is active (`editorMode: vim` in settings).
- **`.editorconfig` is mandatory.** Every project must have one. Respect its rules for
  indent style, line endings, charset, trailing whitespace, and final newline in every
  file touched or created.
- When introducing a new file type, language, or framework to a project, update
  `.editorconfig`, `.gitattributes`, and `.gitignore` in the same change.

---

## Code Style

- Conventional Commits for all commit messages (`feat:`, `fix:`, `chore:`, etc.).
- No comments unless the WHY is non-obvious.
- No docstrings or multi-line comment blocks.

---

## Linting and Git Hooks

- **Prek is the linting entry point, and the default for new projects.** Never call
  linters (`ruff`, `mypy`, `gofmt`, `biome`, etc.) directly. Reach it the way
  *Tool Invocation* says — the project's `lint` target if it has one, otherwise
  `mise exec -- prek run`.
- **Lefthook is also allowed where a project is already set up with it.** If the repo has
  a `lefthook.yml`, that is the hook runner — use it (`mise exec -- lefthook run
  pre-commit`) rather than introducing a parallel prek config. Do not migrate between the
  two runners without being asked. Absent an existing choice, use prek.
- **CSpell is the spell checker, and belongs in every new project.** Wire it into the
  project's hook runner like any other linter.
- When adding a new linter or formatter, wire it into whichever runner the project already
  uses — `.pre-commit-config.yaml` for prek, `lefthook.yml` for lefthook — not a
  standalone script or a CI-only step.
- Fix lint errors immediately when they appear — do not defer to a later step.
- **Never disable a rule to make a run pass** without saying so. If a rule has to go, turn
  it off in the linter's own config with a comment giving the reason, and report it.
- **Auto-fix hooks are normal.** When a hook reformats files (ruff, trailing whitespace,
  etc.), re-stage the fixed files and retry — this is expected behavior, not an error to
  investigate.

---

## Python Projects

- **Modern tooling only:** `pyproject.toml` (no `setup.py`, `setup.cfg`, `requirements.txt`).
- **Package manager:** `uv` for dependency management and virtual environments.
  Run tools via `uv run <tool>` within the project (not `pip install`, not `mise exec -- python`
  for project-local tools).
- **Linting/formatting:** `ruff` (lint + format). No `black`, `isort`, `flake8`, `pylint`.
- **Type checking:** `pyright` (strict mode preferred).
- **Testing:** `pytest`. No `unittest` classes unless extending existing code that uses them.
- **Pydantic** for defining and validating data at application boundaries.
- **Typer** for parsing and validating CLI arguments and options.
- **Dynaconf** for loading and validating application configuration
- **structlog** for structured application logging
- **Rich** for rich, human-friendly terminal output
- **Structure:** `src/<package_name>/` layout with `__init__.py`. Tests in `tests/` at
  project root.
- **No legacy patterns:** no `__future__` imports, no `typing.Optional` (use `X | None`),
  no `typing.Dict`/`List` (use built-in `dict`/`list`), no `TYPE_CHECKING` guard unless
  absolutely necessary for circular imports.

---

## Go Projects

- **Module layout:** one `go.mod` per deployable unit or library.
- **Formatting:** `gofmt`/`goimports` (enforced via pre-commit). No custom style.
- **Linting:** `golangci-lint` with the project's `.golangci.yml` config.
- **Testing:** standard `go test ./...`. Table-driven tests preferred.
- **Error handling:** return errors, don't panic. Wrap with `fmt.Errorf("...: %w", err)`.
- **No global state.** Pass dependencies via constructor or function parameters.

---

## Terraform Projects

- **Formatting:** `terraform fmt` (enforced via pre-commit).
- **Validation:** `terraform validate` after structural changes.
- **Naming:** snake_case for resources, variables, outputs. Descriptive names over short.
- **Provider versions:** pinned with `~>` constraint in `required_providers`.
- **State:** never touch state files or backend config without explicit instruction.
- **Modules:** prefer flat structure; extract to `modules/` only when reuse is real.

---

## Shell Scripts

- **Shebang:** `#!/usr/bin/env bash` for bash, `#!/usr/bin/env zsh` for zsh,
  `#!/bin/sh` only for POSIX-portable scripts.
- **Strict mode:** `set -euo pipefail` in all bash/zsh scripts.
- **Linting:** `shellcheck` (enforced via pre-commit). Fix all warnings.
- **Naming:** snake_case for functions and variables. UPPER_CASE for exported env vars.
- **Quoting:** always quote variable expansions unless intentionally splitting.

---

## Running Tests

- Find the test command via *Tool Invocation*. Where no entry point defines one, it is
  `uv run pytest` for Python (not `python -m pytest`) and `go test ./...` for Go.
- **Do not run tests automatically** after every change — only when asked or when
  verifying a fix.
- If tests fail after your change, investigate and fix immediately before reporting done.

---

## AI Instructions Pattern

### Instruction hierarchy (highest priority first)

1. **This file** (`~/.claude/CLAUDE.md`) — global defaults and user preferences.
2. **Project `CLAUDE.md`** — project-specific overrides, references `docs/ai-instructions.md`.
3. **`docs/ai-instructions.md`** — the single source of truth shared by all AI tools.
4. **`.github/copilot-instructions.md`** — thin pointer to `docs/ai-instructions.md`.

Project-level instructions override global ones where they conflict. Per-project
`CLAUDE.md` can add constraints or relax global rules for that context.

### File structure

Every project should converge on:

```text
CLAUDE.md                      ← entry point, references docs/ai-instructions.md
docs/ai-instructions.md        ← single source of truth for ALL AI tools
.github/copilot-instructions.md ← thin pointer to docs/ai-instructions.md
```

- `docs/ai-instructions.md` is the **authoritative** file. Claude Code reads it via
  `@docs/ai-instructions.md` in `CLAUDE.md`; GitHub Copilot reads it via a pointer
  in `.github/copilot-instructions.md`.
- Edit only `docs/ai-instructions.md`. Keep other pointers as thin redirects.
- The file should contain: project overview, tech stack, project structure tree,
  code generation rules, and AI behaviour guidelines.
- **Keep the structure tree current** — update it in the same PR that adds/removes
  directories.
- **Documentation hygiene:** before adding new docs, check for duplication. Prefer
  updating the single source of truth and linking to it over creating parallel content.

### New projects: AI instructions first

**When creating a new project, begin by gathering context and writing AI instructions
before writing code.** Ask about:

- Project purpose, domain, and key constraints
- Tech stack choices (language, framework, infrastructure)
- Team context (solo? shared? open-source?)
- Any non-obvious conventions or integrations

Then create `CLAUDE.md` and `docs/ai-instructions.md` as the first files in the repo,
immediately after scaffolding (`.editorconfig`, `.gitignore`, etc.). This ensures all
subsequent AI-assisted work is grounded in correct project context from the start.

---

## GitHub Actions / CI

- Use **pinned action versions** for 3rd party deps (full SHA or explicit tag, not `@main`).
- For in-house workflows and actions `@main` or `@v2` are allowed.
- Prefer reusable workflows and composite actions over copy-pasted job definitions.
- Keep workflows minimal: lint, test, build. Don't over-engineer.
- Use `mise` in CI for consistent tool versions (via `jdx/mise-action`).
- Secrets via GitHub environment secrets or OIDC — never hardcoded.

---

## Project Bootstrapping Defaults

When starting a new project or asked to scaffold one, include by default:

1. `.editorconfig` with sensible defaults for the language
2. `.gitattributes` with LF normalization and binary detection
3. `.gitignore` appropriate for the language/framework
4. `mise.toml` pinning language runtimes
5. `justfile` with at least `lint`, `test`, and `fmt` recipes
6. `.pre-commit-config.yaml` with language-appropriate hooks, including CSpell
7. `.cspell.config.yaml` importing the user config, plus `.cspell/project-words.txt`
8. `docs/ai-instructions.md` following the pattern above
9. `CLAUDE.md` referencing `@docs/ai-instructions.md`

---

## Decision-Making Principles

- **Verify before assuming.** Read the code, check the diff, run the tool. Don't guess
  at project structure, conventions, or current state.
- **Match existing patterns.** Before writing new code, read surrounding files for style,
  naming, and structural patterns. Consistency over personal preference.
- **Scope to the request.** Don't refactor adjacent code, add features, or "improve"
  things that weren't asked about.
- **When ambiguous, ask.** One clarifying question is cheaper than a wrong implementation.

@RTK.md
