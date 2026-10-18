# Claude plugins and cross-harness skills

`private_settings.json.tmpl` owns Claude's registered marketplaces and enabled user plugins.
The work marketplace is optional; leave its init prompt blank on machines without work
tooling.

## Install plugins

Marketplace registration and plugin installation are separate: `claude plugin install` only
works after its marketplace is registered. Use the intended scope explicitly:

```sh
claude plugin marketplace add <source> --scope user
claude plugin install <plugin>@<marketplace> --scope user
```

Use `--scope local` for repository-specific plugins. User scope writes
`~/.claude/settings.json`, which this repository manages as a template; after user-scope
changes, check `chezmoi diff ~/.claude/settings.json` and preserve the source of truth.
Verify installations with `claude plugin list`.

## Cross-harness configuration

Claude files remain the source of truth:

- Codex and Copilot global instruction files point to `~/.claude/CLAUDE.md`.
- Copilot discovers `~/.claude/skills/`; Codex uses links under `~/.agents/skills/`.
- The Zinit and Codex scaffold/stack skill links resolve the installed user-scope plugin path. Apply them after
  installing or updating the Claude plugin; project-scoped installs are not exposed globally.
- `home/private_dot_config/claude/mcp.json` owns Context7's server configuration. Chezmoi
  derives Codex and Copilot registrations from it; edit the Claude JSON, then apply.

These adapters share instructions, skills and the Context7 registration only. They do not
install Claude plugins or transfer Claude-specific settings, hooks or MCP servers. In
particular, discovering a skill does not register its MCP server.

Codex exposes `scaffold:modern-python`, `scaffold:new-project`, `stacks:shell`, `stacks:go`
and `stacks:terraform` as `modern-python`, `new-project`, `shell`, `go` and `terraform` in
`~/.agents/skills/`, matching each skill's existing `name` metadata. Its global `AGENTS.md`
maps the shared instructions' plugin-qualified names to these catalog names. Chezmoi omits
links when the corresponding user-scope plugin or `SKILL.md` is absent, so machines without
those plugins do not get broken links. The plugin directories remain the source of truth,
including any bundled references or scripts.

## Exceptions

- `raindrop` remains a symlink because it accesses a live bookmark vault; its checkout must
  exist. Its MCP server still needs its own harness registration.
- `triage` is an account-scope skill shared with OpenCode through a link; it is not a generic
  marketplace skill.

After changing adapters, start a fresh session to verify discovery. Use the harness's skill
list or instruction-discovery command where available.

## Claude Code through OpenRouter

`claude-openrouter` (global mise task + alias) runs Claude Code against OpenRouter
instead of a claude.ai subscription, reusing the usual settings, plugins and MCP config.
It clears provider env vars and API-key helpers for this process rather than logging out,
so `claude-…` launchers keep their own credentials. Verify with `/status`.

The key comes from `OPENROUTER_API_KEY`, else the OpenRouter key saved by
`opencode auth login` (`${XDG_DATA_HOME:-~/.local/share}/opencode/auth.json`); it is never
embedded in the dotfiles.

`claude-openrouter [--model sonnet|haiku|opus|fable] [--continue]` — `sonnet` is the default;
inside Claude Code, `/model` switches for the session (press `s` in the picker to leave the
saved default untouched).

Model IDs are pinned to native Anthropic models for tool-use, thinking and prompt-cache
compatibility rather than protocol translation. View prices on the
[OpenRouter catalog](https://openrouter.ai/models) and actual charges on the
[Activity Dashboard](https://openrouter.ai/activity).

Only Anthropic's first-party provider is guaranteed compatible; prefer it in your
[OpenRouter provider preferences](https://openrouter.ai/settings/preferences). See the
[OpenRouter Claude Code guide](https://openrouter.ai/docs/cookbook/coding-agents/claude-code-integration).
