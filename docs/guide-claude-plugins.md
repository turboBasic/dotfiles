# Claude Code plugins: what a fresh machine needs

Claude Code skills and agents are distributed as **plugins** from **marketplaces**, rather than copied
into each project. Two marketplaces are in play:

| Marketplace  | Repository                   | Visibility | Holds                                                                                       |
| ------------ | ---------------------------- | ---------- | ------------------------------------------------------------------------------------------- |
| `turbobasic` | `turboBasic/claude-plugins`  | public     | Generic roles — planning, review, hygiene, stacks — and one plugin per documentation corpus |
| work         | named by `.claude_work_repo` | private    | Internal-facing skills for work repositories                                                |

`private_dot_claude/private_settings.json.tmpl` renders `~/.claude/settings.json` with the marketplaces
registered and the user-scope plugins enabled.

## Fresh machine

1. `chezmoi init --apply` as usual. It prompts for the work marketplace — answer the first prompt
   **blank** on a machine with no work tooling, and the settings template renders without it.
2. **Install each plugin once per clone.** This is the step that is easy to miss:

   ```sh
   # user scope — available in every directory
   claude plugin install <plugin>@turbobasic --scope user

   # per repository, from its root
   claude plugin install <plugin>@turbobasic --scope local
   ```

3. Verify with `claude plugin list` — each entry should show `Status: ✔ enabled`.

## Three mechanics that are not obvious

**Declaring a plugin is not installing it.** A plugin named in `enabledPlugins` is fetched but does not
load until `claude plugin install` runs. Folder trust does not do it. Every clone costs one command per
plugin.

**Declaring a marketplace does not register it either.** Hand-writing `extraKnownMarketplaces` into a
settings file leaves the marketplace absent from `~/.claude/plugins/known_marketplaces.json`, and the
install then fails with `Plugin "x" not found in marketplace "x"`. `claude plugin marketplace add <source>`
is what registers it, and it writes that same block itself.

**Every one of those commands defaults to `--scope user`, which writes `~/.claude/settings.json` — the
file this repository owns.** Two consequences:

- Prefer `--scope local` for anything private. A default-scope `marketplace add` puts whatever it names
  into this public repository at the next `chezmoi re-add`.
- A user-scope install only survives because `private_settings.json` is a **template**. When it was a
  plain managed file, the next `chezmoi apply` overwrote the destination and silently removed the install.
  After any user-scope install, check that `chezmoi diff ~/.claude/settings.json` is empty.

## Skills are plugins now, not symlinks

Documentation-lookup skills used to be symlinks from `~/.claude/skills` into project checkouts, created by
`symlink_*.tmpl` files here. Those are gone: each documentation corpus is published as its own plugin from
the repository where it is edited, so a fresh machine gets them from the marketplace instead of needing
every project cloned first.

**`raindrop` is one exception and keeps its symlink.** It is not a documentation lookup — it resolves a
vault through that symlink and writes into the live vault, which a read-only plugin cache is not.

**`triage` is the other, and the file itself is not a symlink** — a real file here, applied to
`~/.claude/skills/triage/`. It names two GitHub owners, an inline token and a project number, which the
marketplace's generic-skill invariant keeps out of a plugin; and being asked from any directory, it has no
consuming repository whose `.claude/skills/` could hold it instead. A skill in that position belongs at
account scope. **A second harness reaches the same file through a symlink of its own:**
`private_dot_config/opencode/skill/symlink_triage.tmpl` points OpenCode's global skill directory
(`~/.config/opencode/skill/`) at the applied Claude Code skill, so there is still one file, not two copies.

## Reuse from Codex and Copilot

The Claude files remain the source of truth. Chezmoi installs thin global adapters at
`~/.codex/AGENTS.md` and `~/.copilot/copilot-instructions.md`. Both direct the harness to read
`~/.claude/CLAUDE.md`, resolve its imports relative to `~/.claude/`, and consult the existing
`task-runners` rule for files matching its `paths`. This rule is loaded by instruction rather
than by a native path-scoped rule engine in these adapters.

Individual links under `~/.agents/skills/` expose `triage` and `raindrop` to Codex, preserving
other installed skills. Copilot discovers `~/.claude/skills/` directly. Edit the Claude skill
source; the links contain no skill instructions. The `raindrop` link still depends on its
vault checkout being present.

These adapters expose instructions and local skills. Claude plugin installations, shell
settings, hooks and MCP registrations remain specific to their harness. In particular,
discovering the `raindrop` skill does not register its MCP server.

After applying the adapters, start a fresh session. Check Codex's `/skills` list or Copilot's
Agent Customizations editor for the skills, and ask the harness to identify the global
instruction source it read. Copilot CLI also provides `/instructions` for discovery checks.

### Plugin-skill pilot: Zinit

Codex's `~/.agents/skills/zinit` and Copilot's `~/.copilot/skills/zinit` link to the same
installed `zinit-docs@turbobasic` skill. The shared `claude-plugin-skill-path` chezmoi template
reads the user-scope entry in `~/.claude/plugins/installed_plugins.json`; no cache version or
skill body is copied into this repository. The instruction adapters explain how to resolve
the skill's `${CLAUDE_SKILL_DIR}` paths through the symlink to its real directory.

When the user-scope plugin or its skill is absent, `.chezmoiignore` skips both links. Install
the plugin with Claude first, then apply the two links. After a Claude plugin update, reapply
the links so they follow the newly recorded installation path. Project-only plugin installs
are not exposed globally. Ignoring a link leaves any existing destination untouched.

### MCP pilot: Context7

`home/private_dot_config/claude/mcp.json` owns the Context7 server definition. Chezmoi derives
the URL for Codex's `~/.codex/config.toml` and the HTTP registration for
`~/.copilot/mcp-config.json`, shared by Copilot CLI and Copilot harness sessions in VS Code.
Edit the Claude JSON, then reapply the derived configurations.

The Codex template currently maps Context7's URL; Copilot's generated JSON reuses the HTTP
definition. Authentication and additional transport fields need an explicit adapter update
if they are added later. Native configuration locations and schemas are documented by
[Codex](https://developers.openai.com/codex/mcp),
[Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-mcp-servers),
and [VS Code](https://code.visualstudio.com/docs/agent-customization/mcp-servers).

The other documentation plugins (`chezmoi-docs`, `mise-docs`, `1password-docs`, `uv-docs`,
`aws-sso-cli-docs`) and workflow plugins (`planning`, `hygiene`, `scaffold`, `stacks`) remain
in Claude's existing setup. Claude's language-server plugins and hooks require native
integration in each harness. The Docker gateway, 1Password, Raindrop and AWS MCP servers also
remain in the Claude MCP configuration; this pilot exposes Context7 only.

## Scope reference

| Scope     | Written to                           | Committed?                              |
| --------- | ------------------------------------ | --------------------------------------- |
| `user`    | `~/.claude/settings.json`            | yes — by this repository                |
| `project` | `<repo>/.claude/settings.json`       | yes — by that repository                |
| `local`   | `<repo>/.claude/settings.local.json` | no — ignored via `~/.config/git/ignore` |
