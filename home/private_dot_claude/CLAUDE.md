# Global Claude Code Instructions

Rules that apply to every project regardless of language or domain.

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

## Tone and Responses

- Terse responses. End with a one-sentence summary of what changed — no multi-paragraph recaps.
- No emojis unless explicitly requested.
- Prefer direct statements over hedging.

---

## Tool Invocation

The hierarchy for running tools (highest priority first):

1. **Project Makefile/Justfile** — if a `lint`, `test`, or `fmt` target exists, use it.
2. **Pre-commit** — for linting/formatting: `mise exec -- pre-commit run`.
3. **`uv run`** — for Python project-local tools (pytest, pyright, ruff directly).
4. **`mise exec --`** — for system-level tools managed by mise (terraform, go, node).
5. **Direct invocation** — only if none of the above apply.

Before running tools, check if the project has `mise.toml`/`.mise.toml`. If it does,
use `mise exec --` for tools it manages. If not, use tools directly.
Never assume mise is present in foreign or unfamiliar projects — look first.

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

## Linting and Pre-commit

- **Pre-commit is the linting entry point.** Never call linters (`ruff`, `mypy`,
  `gofmt`, `biome`, etc.) directly — use `mise exec -- pre-commit run` or the
  project's Makefile/Justfile lint target.
- When adding a new linter or formatter, wire it through pre-commit (not a standalone
  script or CI-only step).
- Fix lint errors immediately when they appear — do not defer to a later step.
- **Auto-fix hooks are normal.** When pre-commit reformats files (ruff, trailing
  whitespace, etc.), re-stage the fixed files and retry — this is expected behavior,
  not an error to investigate.

---

## Python Projects

- **Modern tooling only:** `pyproject.toml` (no `setup.py`, `setup.cfg`, `requirements.txt`).
- **Package manager:** `uv` for dependency management and virtual environments.
  Run tools via `uv run <tool>` within the project (not `pip install`, not `mise exec -- python`
  for project-local tools).
- **Linting/formatting:** `ruff` (lint + format). No `black`, `isort`, `flake8`, `pylint`.
- **Type checking:** `pyright` (strict mode preferred).
- **Testing:** `pytest`. No `unittest` classes unless extending existing code that uses them.
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

- Use the project's Makefile/Justfile `test` target when available.
- For Python: `uv run pytest` (not `python -m pytest`, not `mise exec -- pytest`).
- For Go: `go test ./...` (or `mise exec -- go test ./...` if mise-managed).
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

- Use **pinned action versions** (full SHA or explicit tag, not `@main` or `@master`).
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
5. `.pre-commit-config.yaml` with language-appropriate hooks
6. `docs/ai-instructions.md` following the pattern above
7. `CLAUDE.md` referencing `@docs/ai-instructions.md`

---

## Decision-Making Principles

- **Verify before assuming.** Read the code, check the diff, run the tool. Don't guess
  at project structure, conventions, or current state.
- **Match existing patterns.** Before writing new code, read surrounding files for style,
  naming, and structural patterns. Consistency over personal preference.
- **Scope to the request.** Don't refactor adjacent code, add features, or "improve"
  things that weren't asked about.
- **When ambiguous, ask.** One clarifying question is cheaper than a wrong implementation.
