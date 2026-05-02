# Claude Code instructions

@docs/ai-instructions.md
@README.md

---

## Claude Code — Additional Instructions

The shared instructions above apply to all AI tools. The notes below are Claude Code-specific.

### Memory & context

- Project memory is stored in `~/.claude/projects/…/memory/`. Update it when discovering
  new stable patterns.
- For code-change behavior and repository conventions, follow `docs/ai-instructions.md`.

### Tool preferences

- Use the built-in Read/Edit/Glob/Grep tools over shell equivalents (cat, grep, find).

### Commits & PRs

- Do not commit or push unless explicitly asked.
- For commit message format, follow `docs/ai-instructions.md` (Conventional Commits).
