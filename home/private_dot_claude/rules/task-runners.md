---
paths:
  - "**/justfile"
  - "**/Justfile"
  - "**/*.just"
  - "**/Makefile"
  - "**/GNUmakefile"
  - "**/mise.toml"
  - "**/.mise.toml"
  - "**/mise/config.toml"
---

# Where a task belongs

**mise owns the environment and the engine. Just owns the names a human types.**

| Concern                                                           | Home                            |
| ----------------------------------------------------------------- | ------------------------------- |
| Tool versions, `PATH`, env vars, secret injection                 | `mise.toml` `[tools]` / `[env]` |
| A name a human types                                              | `justfile`                      |
| Per-task env or secrets, a task-scoped tool, use outside any repo | mise `[tasks.*]`                |
| File-based staleness — run only when inputs changed               | mise task `sources` / `outputs` |
| A multi-target dependency graph                                   | `Makefile`                      |

- **Just is an interface, not an engine.** mise tasks have `depends` (parallel by default),
  `--jobs`, per-task `env` and `tools`, `dir`, `shell` and `mise watch` — anything Just does as a
  runner, mise does. What Just has is parameters with defaults, shebang recipes, readable
  multi-line bodies and a `--list` a human reads. The split is by audience, not by capability.
- **A task goes in mise when it needs something Just cannot give it** — per-task env or secret
  injection, a task-scoped tool version, file-based staleness, or availability with no repo in
  sight. The `claude-*` tasks in `~/.config/mise/config.toml` qualify twice over: they inject a
  secret-backed token and they are user-level, not project-level.
- **A mise task a human runs gets a just recipe fronting it**, and calls go `just` → `mise run`,
  never the reverse. Bidirectional wrapping leaves no owner for a task name.
- **One owner and one lister per name.** A name appearing in both `just --list` and `mise tasks`
  makes both listings lie about what exists.
- **Staleness is not a reason to reach for `make`.** `sources` plus `outputs` on a mise task skips
  it when every output is newer than every source, and because `outputs` takes globs, a recipe
  producing many files needs no stamp target to hang itself on. A `Makefile` earns its place only
  for a real graph — intermediate artifacts that are themselves prerequisites, pattern rules, a
  build where asking for one target is a meaningful request.
- **The dotfiles `Makefile` stays as it is** — decided 2026-09-20. It gates the rbw docker build on
  a stamp file, it predates this rule, and it works; do not propose migrating it.
- **Recipes carry no `mise exec --` prefix**, relying on mise being activated. That holds in an
  interactive shell and in CI through `jdx/mise-action`. For a non-interactive or GUI-launched
  process — a hook runner fired from a GUI git client, a cron job — the backstop is the shims
  directory on `PATH`, which on this machine is incidental rather than declared. A tool missing
  there is an environment bug to fix in the environment, never papered over per recipe.
