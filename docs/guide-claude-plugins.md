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

## Claude Code through OpenRouter

`claude-openrouter` is a global mise task and shell alias, alongside `claude-dxc`. It uses
OpenRouter credits, the usual Claude settings/plugins and `~/.config/claude/mcp.json`, without
logging out of the saved claude.ai account. The gateway token takes precedence for this
process only; `claude-dxc` continues using the enterprise subscription.

The task reads `OPENROUTER_API_KEY` first. Otherwise it reuses the API key saved by
`opencode auth login` in `${XDG_DATA_HOME:-~/.local/share}/opencode/auth.json`. No key is
embedded in the dotfiles or printed. Missing or invalid stored credentials abort startup.

```sh
claude-openrouter                    # Sonnet: everyday coding
claude-openrouter --model haiku      # Lowest cost
claude-openrouter --model opus       # Harder reasoning
claude-openrouter --continue         # Continue the latest session, using OpenRouter
```

Inside Claude Code, use `/model` to switch models for the session (press `s` in the picker
to avoid changing the saved default used by other launchers). Defaults are pinned to native
Anthropic models for tool-use, thinking and prompt-cache compatibility, rather than relying
on protocol translation to cheaper non-Claude models.

| Selection | OpenRouter model | Input / output per million tokens |
| --- | --- | --- |
| `sonnet` (default) | `anthropic/claude-sonnet-5.5` | $2 / $10 |
| `haiku` | `anthropic/claude-haiku-5.5` | $0.10 / $0.50 |
| `opus` | `anthropic/claude-opus-5.5` | $4 / $20 |
| `fable` (premium, opt-in) | `anthropic/claude-fable-5.1` | $10 / $50 |

Prices checked against the [OpenRouter catalog](https://openrouter.ai/models) on 2026-10-18;
cache pricing and provider rates can differ. The configured IDs include `[1m]` so Claude
Code recognizes their million-token context windows; OpenRouter strips this marker before
routing. Claude Code's own cost estimates can differ from OpenRouter billing; use the
[OpenRouter Activity Dashboard](https://openrouter.ai/activity) for actual charges.
Subagents inherit the selected model unless
their own definition selects another class; quick background queries use Haiku. Fast mode
is disabled at launch to avoid premium pricing.

The endpoint is `https://openrouter.ai/api` (not `/api/v1`), with bearer-token authentication
and an explicitly empty `ANTHROPIC_API_KEY`. Other provider switches, inherited OAuth tokens
and API-key helpers are cleared for this launch. The saved claude.ai login is not deleted.
Use `/status` to confirm `ANTHROPIC_AUTH_TOKEN` and the OpenRouter base URL.

OpenRouter only guarantees Claude Code compatibility with the Anthropic first-party
provider. Prefer Anthropic in your [OpenRouter provider preferences](https://openrouter.ai/settings/preferences);
the launcher does not change account-wide routing. See the
[OpenRouter Claude Code guide](https://openrouter.ai/docs/cookbook/coding-agents/claude-code-integration).
