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

**`raindrop` is the one exception and keeps its symlink.** It is not a documentation lookup — it resolves a
vault through that symlink and writes into the live vault, which a read-only plugin cache is not.

## Scope reference

| Scope     | Written to                           | Committed?                              |
| --------- | ------------------------------------ | --------------------------------------- |
| `user`    | `~/.claude/settings.json`            | yes — by this repository                |
| `project` | `<repo>/.claude/settings.json`       | yes — by that repository                |
| `local`   | `<repo>/.claude/settings.local.json` | no — ignored via `~/.config/git/ignore` |
