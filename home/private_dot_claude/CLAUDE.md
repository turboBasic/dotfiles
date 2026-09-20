# Global Claude Code Instructions

Rules that apply to every project regardless of language or domain.

These are **authoring defaults for repositories the user owns** — those under
`~/00-projects/`. In a repo the user did not set up (client code, a vendored dependency,
an open-source contribution), the conventions already in the repo win: match them, and
raise a suggestion rather than acting on it.

A rule below phrased as a prohibition — "no `requirements.txt`", "no `black`", "every
project must have an `.editorconfig`" — constrains what you **write**. It is not a mandate
to migrate what is already there. Never convert a foreign repo's build tooling, package
manager, task runner, or lint configuration without being asked, and never introduce one
where the repo has none.

---

## This Machine

### Environment

- Projects live in `~/00-projects/` with subdirectories for personal and work contexts.
- Dotfiles are chezmoi-managed from `~/00-projects/personal/turboBasic/dotfiles/`.
  That repo contains full documentation on the shell environment, including the Zinit
  plugin manager setup (`docs/ZINIT.md`) and architecture (`docs/ARCHITECTURE.md`).
- The shell is Zsh with Zinit for plugin management (turbo mode, annexes, numbered
  config files); aliases, functions and `PATH` all come from that repo. Read its
  conventions before changing shell config, and look there first when a command surprises.
- **macOS with GNU coreutils:** GNU versions of `grep`, `sed`, `awk`, `find`, etc.
  have higher priority in PATH than BSD variants. This means BSD-specific flags will
  fail silently or error. When portability matters or behavior is surprising, use
  absolute paths (e.g. `/usr/bin/sed` for BSD sed). Modern alternatives are also
  available: `rg` (ripgrep), `fd`, `bat`, `eza`, etc.

### The Bash tool's shell

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

## How I Work

### Tone and responses

- Terse responses. End with a one-sentence summary of what changed — no multi-paragraph recaps.
- No emojis unless explicitly requested.
- Prefer direct statements over hedging.

### Decision-making

- **Verify before assuming.** Read the code, check the diff, run the tool. Don't guess
  at project structure, conventions, or current state.
- **Match existing patterns.** Before writing new code, read surrounding files for style,
  naming, and structural patterns. Consistency over personal preference.
- **Scope to the request.** Don't refactor adjacent code, add features, or "improve"
  things that weren't asked about.
- **When ambiguous, ask.** One clarifying question is cheaper than a wrong implementation.
- **Never touch remote or shared state without explicit instruction** — Terraform state files
  and backend config, a live database, a deployed environment. Hand the command back with what
  it would change instead of running it.

### Subagents and background tasks

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

## Tool Invocation

**This section is the single source of truth for how to run anything**, linting and tests
included. Two separate questions — answer them in that order.

### 1. Which entry point?

Prefer the project's own entry point over invoking a tool yourself. If a `lint`, `test`,
or `fmt` target exists, use it; do not reimplement what it does.

1. **`justfile`** — the preferred task runner. `just` with no arguments lists recipes.
2. **`Makefile`** — equal standing where one exists.
3. **`mise` tasks** — `mise run <task>`; `mise tasks` lists what exists, including
   user-level tasks defined in `~/.config/mise/config.toml`.
4. **No entry point covers the job** — fall through to question 2.

### 2. How to resolve the binary?

Only once no entry point covers it:

1. **`uv run <tool>`** — Python project-local tools (pytest, pyright, ruff) in any repo
   with a `pyproject.toml`.
2. **`mise exec -- <tool>`** — tools mise manages (terraform, go, node, prek).
3. **Direct invocation** — only when neither of the above applies.

Check for `mise.toml` before reaching for `mise exec --`, and only for tools mise actually
manages. Never assume mise is present in an unfamiliar project — look first.

### Where a task belongs

**mise owns the environment and the engine; Just owns the names a human types.** A task
belongs in mise when it needs env or secret injection, a task-scoped tool, file-based
staleness (`sources` / `outputs`), or must work outside any repo — and a mise task a human
runs gets a just recipe fronting it. Calls go `just` → `mise run`, never the reverse, one
owner and one lister per name, and a `Makefile` only for a real multi-target graph. The
`task-runners` rule holds the rest and loads when a task-runner file is read.

### Linting and git hooks

- **Never call a linter (`ruff`, `mypy`, `gofmt`, `biome`) directly** — prek runs them.
  Reach prek by the ordering above, and pass it a single hook name rather than running the
  whole suite when only one hook applies.
- **Where a repo has `lefthook.yml`, lefthook is its hook runner** — use it rather than
  adding a parallel prek config, and never migrate between the two without being asked.
- When adding a linter or formatter, wire it into whichever runner the project already
  uses — not a standalone script and not a CI-only step.
- Fix lint errors immediately when they appear — do not defer to a later step.
- **A generated file failing lint is a generator bug.** Fix what emits it, never the output.
- **Never disable a rule to make a run pass** without saying so. If a rule has to go, turn
  it off in the linter's own config with a comment giving the reason, and report it.
- **Auto-fix hooks are normal.** When a hook reformats files (ruff, trailing whitespace,
  etc.), re-stage those files and retry — never `git add -A`, never anything the hook did
  not touch. This is expected behavior, not an error to investigate.

### Tests

- Find the test command by the ordering above; failing that, the stack's skill names it.
- **Do not run the full suite automatically** after every change — only when asked or when
  verifying a fix. A targeted test over what you just changed is fine.
- If tests fail after your change, investigate and fix immediately before reporting done.

---

## Writing Code

### Formatting

- **`.editorconfig` is mandatory.** Every project must have one. Respect its rules for
  indent style, line endings, charset, trailing whitespace, and final newline in every
  file touched or created.
- When introducing a new file type, language, or framework to a project, update
  `.editorconfig`, `.gitattributes`, and `.gitignore` in the same change.

### Style and commits

- Conventional Commits for all commit messages (`feat:`, `fix:`, `chore:`, etc.).
- No comments unless the WHY is non-obvious; no docstrings or comment blocks.

### Language stacks

Stack conventions live in skills rather than here. Load the skill before writing the first line:

- **Python** — `scaffold:modern-python` (uv, ruff, Pyright, pytest, layout, runtime libraries)
- **Shell** — `stacks:shell` (`.sh`, `.bash`, `.zsh`: shebang, strict mode, `main()` layout, naming, quoting)
- **Go** — `stacks:go` (module layout, error wrapping, no global state, table-driven tests)
- **Terraform** — `stacks:terraform` (naming, provider pinning, flat modules, and what not to run)

---

## Where Instructions Live

### Instruction layers

1. **The project's own rules** — authored in `docs/ai-instructions.md`, with `CLAUDE.md` and
   `.github/copilot-instructions.md` as thin pointers to it.
2. **This file** (`~/.claude/CLAUDE.md`) — global authoring defaults, applying wherever the
   project says nothing.

A project rule wins over a global one where the two conflict: a project can add constraints
or relax a global default for its own context.

- **Before adding a document, check what already covers it.** Update the owner and link to it
  rather than writing a parallel page.

### New projects

- **Standing up a new project** — load `scaffold:new-project` before the first file: it owns the
  file floor, the instruction layer, the CI shape, and the order the work happens in.

---

@RTK.md
