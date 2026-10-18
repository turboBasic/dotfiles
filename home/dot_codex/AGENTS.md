# Global Codex instructions

Read `~/.claude/CLAUDE.md` and follow its shared authoring defaults.
Read its `@` imports relative to `~/.claude/`.
Use this harness's available tools; Claude Code shell settings, hooks and plugin registrations are harness-specific.
In reused skills, resolve `${CLAUDE_SKILL_DIR}` to the real directory containing `SKILL.md` before using its paths.

Claude plugin-qualified skill names map to Codex's catalog names:
`scaffold:modern-python` -> `modern-python`, `scaffold:new-project` -> `new-project`,
`stacks:shell` -> `shell`, `stacks:go` -> `go`, and `stacks:terraform` -> `terraform`.
Load the corresponding Codex skill whenever the shared instructions require the Claude skill.

When working with files matching `paths` in `~/.claude/rules/task-runners.md`, read and follow that rule.
