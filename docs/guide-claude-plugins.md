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
- The Zinit skill links resolve the installed user-scope plugin path. Apply them after
  installing or updating the Claude plugin; project-scoped installs are not exposed globally.
- `home/private_dot_config/claude/mcp.json` owns Context7's server configuration. Chezmoi
  derives Codex and Copilot registrations from it; edit the Claude JSON, then apply.

These adapters share instructions, skills and the Context7 registration only. They do not
install Claude plugins or transfer Claude-specific settings, hooks or MCP servers. In
particular, discovering a skill does not register its MCP server.

## Exceptions

- `raindrop` remains a symlink because it accesses a live bookmark vault; its checkout must
  exist. Its MCP server still needs its own harness registration.
- `triage` is an account-scope skill shared with OpenCode through a link; it is not a generic
  marketplace skill.

After changing adapters, start a fresh session to verify discovery. Use the harness's skill
list or instruction-discovery command where available.
