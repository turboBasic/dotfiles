# Zinit — Plugin Manager Reference

> **AI assistants**: before generating or modifying Zinit configuration, run
> `zinit help` in a Zsh shell to get the current list of commands and ice modifiers.
> Use it as a **starting point** for available ices and commands — always cross-check
> against actual behavior rather than relying on training data alone.
>
> **Caveat:** `zinit help` and `zinit man` can be outdated relative to the actual
> codebase (see [zdharma-continuum/zinit#670](https://github.com/zdharma-continuum/zinit/issues/670)).
> For example, `zinit ls` is listed in help but removed — replaced by `zinit snippets`
> and `zinit plugins`. When help output contradicts observed behavior, trust the
> behavior. Cross-reference with the shell completions (`_zinit`) and the source
> code in `~/.local/share/zinit/zinit.git/` as needed.

---

## Authoritative Sources

| Source                  | How to access                                                                    | Reliability            |
| ----------------------- | -------------------------------------------------------------------------------- | ---------------------- |
| `zinit help`            | Lists commands + available ice modifiers                                         | Can be stale (see #670)|
| `zinit man`             | Opens the manpage (`doc/zinit.1`)                                                | Can be stale           |
| Shell completions       | `~/.local/share/zinit/zinit.git/_zinit` or `zinit completions`                   | Most up-to-date        |
| Zinit source code       | `~/.local/share/zinit/zinit.git/zinit*.zsh`                                      | Ground truth           |
| Zinit README            | `~/.local/share/zinit/zinit.git/README.md` (local copy)                          | Good for ice reference |
| Zinit Wiki              | <https://zdharma-continuum.github.io/zinit/wiki/>                                | Good for examples      |
| Annexes                 | <https://github.com/zdharma-continuum> (org repos starting with `zinit-annex-*`) | Per-annex READMEs      |

**When in doubt, read the local README first** — it contains the full ice modifier
table with descriptions, the order of execution, and usage examples. If `zinit help`
contradicts observed behavior, check the source or completions file.

---

## File Architecture

Zinit configuration is split across numbered files sourced in order by
`private_dot_zshrc.tmpl`. Each file handles one concern:

| File                         | Purpose                                                                                   | Turbo?     |
| ---------------------------- | ----------------------------------------------------------------------------------------- | ---------- |
| `zinit_00_install.zsh`       | Bootstrap: clone zinit, set `$ZINIT_HOME`, `$ZIPL`, `$ZISN`, configure `$path`/`$manpath` | No         |
| `zinit_10_homebrew.zsh`      | Load Homebrew environment via `turboBasic/zsh-homebrew` plugin                            | No         |
| `zinit_20_macos.zsh`         | macOS-only plugins (conditionally included by `.zshrc.tmpl`)                              | Yes (wait) |
| `zinit_20_linux.zsh`         | Linux-only plugins (conditionally included by `.zshrc.tmpl`)                              | —          |
| `zinit_30_profiles.zsh.tmpl` | Profile-conditional sourcing (chezmoi template includes profile file)                     | —          |
| `zinit_50_plugins.zsh`       | Main plugins: annexes, prompt, tools, snippets, heavy/turbo plugins                       | Mixed      |
| `zinit_90_completions.zsh`   | Completion-only plugins and snippets                                                      | Yes (wait) |
| `zinit_99_last.zsh`          | Must-be-last: autosuggestions, syntax highlighting, `compinit`                            | Yes (wait) |

### Numbering Convention

- `00`–`09`: Bootstrap (no plugins loaded yet)
- `10`–`19`: Foundation (shell environment, package manager)
- `20`–`29`: Platform-specific (OS-gated)
- `30`–`39`: Profile-specific (user profile-gated via chezmoi)
- `50`–`59`: Main plugin declarations
- `90`–`99`: Finalization (completions, syntax highlighting, compinit)

### Adding a New File

If a new concern doesn't fit an existing file, create `zinit_<NN>_<name>.zsh` with
the appropriate number range. Update `private_dot_zshrc.tmpl` to `{{ include }}` it
in the correct position.

---

## Syntax Conventions Used in This Config

### The `for` loop syntax

All plugin declarations use the **`for` loop form** — never the legacy
`zinit ice ...; zinit load/light` two-line form:

```zsh
zinit [flags] for \
    [--ice='value'] \
    plugin-spec \
    [--ice='value'] \
    another-plugin-spec \
    \
    # last line ;)
```

**Key points:**
- Flags like `--lucid`, `--wait`, `--light-mode` apply to ALL plugins in the block
  unless overridden per-plugin with `--flag='value'` prefix.
- Per-plugin ices use `--` prefix notation: `--pick='file.zsh'`, `--sbin='bin -> name'`.
- The trailing `# last line ;)` comment after a backslash-newline is a deliberate
  pattern — it allows appending new entries without modifying the previous line's
  trailing backslash.

### Ice modifier notation

This config exclusively uses the **double-dash form** for ices:

```zsh
--ice-name='value'    # correct (this config's style)
ice-name'value'       # legacy form — do NOT use
```

### Grouping by loading strategy

Plugins within `zinit_50_plugins.zsh` are grouped into three `zinit ... for` blocks:

1. **Lightweight / synchronous** (`zinit --light-mode --lucid for`)
   - Annexes, prompt theme, small utilities
   - No `--wait` — loads immediately during shell startup

2. **Snippets** (`zinit --lucid --wait for`)
   - URL-based snippets (gists, OMZL/OMZP)
   - Deferred via turbo mode

3. **Heavy / turbo** (`zinit --lucid --wait for`)
   - Binary tools installed from GitHub Releases (`--from='gh-r'`)
   - Tools requiring compilation or make steps
   - Deferred via turbo mode with optional `--wait='1'` for lower priority

---

## Turbo Mode

Turbo mode (`--wait` / `wait` ice) defers plugin loading until after the prompt
appears. This is the primary mechanism for fast shell startup.

| Wait value          | Meaning                                                    |
| ------------------- | ---------------------------------------------------------- |
| `--wait` (no value) | Load after first prompt (≈0ms delay, next event loop tick) |
| `--wait='1'`        | Load ~1 second after prompt                                |
| `--wait='1c'`       | Load ~1 second after prompt, trigger `compinit` replay     |

**Rules for this config:**
- Annexes and prompt theme: **never** turbo (needed before first prompt)
- Homebrew plugin: **never** turbo (provides `$HOMEBREW_PREFIX` for later plugins)
- Most tools and snippets: turbo with default `--wait`
- `fast-syntax-highlighting`: turbo with `--wait='1c'` + `compinit` (must be last)
- `zsh-autosuggestions`: turbo with `--wait` + `atload='!_zsh_autosuggest_start'`

---

## Common Patterns

### Installing a binary from GitHub Releases

```zsh
--from='gh-r' \
--bpick='<glob-for-asset>' \       # which release asset to download
--sbin='binary -> name' \          # symlink into $ZPFX/bin
--atclone='<post-install commands>' \
--run-atpull \
--atpull='%atclone' \              # re-run atclone on updates
plugin-org/plugin-name
```

### Installing a tool with `make`

```zsh
--as='null' \                      # don't source any file
--make='install PREFIX=$ZPFX' \    # run make install
--run-atpull \
--atpull='%atclone' \
plugin-org/tool-name
```

### Generating completions at install time

```zsh
--atclone='./tool completion zsh > _tool' \
--nocompile='!' \                  # compile AFTER atclone
--run-atpull \
--atpull='%atclone' \
```

### Loading a snippet as completion only

```zsh
--as='completion' \
--is-snippet \
--id-as='_toolname' \
URL-to-completion-file
```

### Conditional loading (platform/tool check)

```zsh
--if='[[ -d "/some/path" ]]' \     # load only if condition is true
--has='binary-name' \              # load only if binary exists in PATH
```

### Idempotent atclone/atpull

The pattern `--atpull='%atclone'` combined with `--run-atpull` ensures:
- `atclone` runs on first install
- Same commands re-run on every `zinit update`
- No separate `atpull` logic needed

---

## Key Variables

| Variable      | Value                            | Purpose                                        |
| ------------- | -------------------------------- | ---------------------------------------------- |
| `$ZINIT_HOME` | `~/.local/share/zinit/zinit.git` | Zinit installation directory                   |
| `$ZPFX`       | `~/.local/share/zinit/polaris`   | Prefix for `make install` (bin/, man/, share/) |
| `$ZIPL`       | `$ZINIT[PLUGINS_DIR]`            | Shortcut to plugins directory                  |
| `$ZISN`       | `$ZINIT[SNIPPETS_DIR]`           | Shortcut to snippets directory                 |

---

## Order of Execution of Ice Modifiers

When a plugin is cloned or updated, ices execute in this **exact** sequence:

```
atinit → atpull'!' → make'!!' → mv → cp → make'!' →
atclone/atpull → make → (plugin script loading) →
src → multisrc → atload
```

| Step | Ice                    | When it fires                                     |
| ---- | ---------------------- | ------------------------------------------------- |
| 1    | `atinit`               | After directory setup, before anything else        |
| 2    | `atpull'!'`            | Early pull hook (only the `!`-prefixed variant)    |
| 3    | `make'!!'`             | Earliest make (double-`!` prefix)                  |
| 4    | `mv`                   | File move/rename operations                        |
| 5    | `cp`                   | File copy operations                               |
| 6    | `make'!'`              | Early make (single-`!` prefix)                     |
| 7    | `atclone` / `atpull`   | Standard clone/pull hooks (without `!` prefix)     |
| 8    | `make`                 | Final make (no prefix)                             |
| 9    | *(loading)*            | Main `.plugin.zsh` / `init.zsh` sourcing           |
| 10   | `src`                  | Additional single file to source                   |
| 11   | `multisrc`             | Multiple additional files to source                |
| 12   | `atload`               | Post-load commands                                 |

This sequence matters when `atclone` generates files that `pick`/`src` need to find,
or when `make` installs binaries that `sbin` shims need to wrap.

---

## Ice Modifiers Reference

> Run `zinit help` to get the **current** list of available ices. The table below
> covers ices used in this config and common additions.

### Loading mode

| Ice                             | Description                                                |
| ------------------------------- | ---------------------------------------------------------- |
| `as"program"` / `as"command"`   | Treat as binary; add plugin dir to `$PATH`                 |
| `as"completion"`                | Treat as a completion file                                 |
| `as"null"`                      | Disable sourcing and completion detection entirely         |
| `id-as"name"`                   | Assign a custom identifier (overrides repo-derived name)   |
| `light-mode`                    | Equivalent to `zinit light` (no tracking/reporting)        |
| `depth`                         | Limits `git clone --depth`                                 |

### Conditional loading

| Ice              | Description                                                           |
| ---------------- | --------------------------------------------------------------------- |
| `wait`           | Turbo mode: `wait'0'` = after prompt; `wait'1'` = 1s after           |
| `wait` suffixes  | `a`, `b`, `c` control order within same time-slot (`a` loads first)  |
| `lucid`          | Suppress "Loaded ..." message for turbo-loaded plugins               |
| `if`             | Load only when condition is true: `if'[[ -d /path ]]'`               |
| `has`            | Load only when command exists in `$PATH`: `has"git"`                  |
| `trigger-load`   | Create a function stub that loads the plugin on first call            |

### Source/file selection

| Ice              | Description                                                           |
| ---------------- | --------------------------------------------------------------------- |
| `pick"pattern"`  | Select file to source (pattern, first alphabetical match wins)        |
| `src"file"`      | Additional file to source after main file                             |
| `multisrc"..."`  | Source multiple files (space-separated, brace-expansion, globs)       |
| `from`           | Clone source: `github` (default), `gh-r`, `gitlab`, `bitbucket`      |
| `bpick"pattern"` | Select which GitHub Release asset to download                         |
| `extract`        | Auto-extract archives. `!` = flatten 1 level. `!!` = flatten 2.      |

### Command execution hooks

| Ice              | Description                                                                                    |
| ---------------- | ---------------------------------------------------------------------------------------------- |
| `atinit"code"`   | Run after directory setup, before loading                                                      |
| `atclone"code"`  | Run after cloning, within plugin directory                                                     |
| `atpull"code"`   | Run after update (only if new commits, unless `run-atpull`). `%atclone` = copy atclone content |
| `atload"code"`   | Run after loading. `!` prefix enables unload tracking                                          |
| `run-atpull`     | Always run atpull hook, even without new commits                                               |
| `make"args"`     | Run make. `!` prefix = before atclone/atpull. `!!` = earliest                                 |

### File manipulation

| Ice              | Description                                                    |
| ---------------- | -------------------------------------------------------------- |
| `mv"from -> to"` | Move/rename file after clone/update                           |
| `cp"from -> to"` | Copy file after clone/update (runs after `mv`)                |
| `compile"pat"`   | Additional files to zcompile                                   |
| `nocompile`      | Don't zcompile picked files at all                             |
| `nocompile'!'`   | **DO** compile, but **after** `make` and `atclone` (delayed)  |

### `nocompile` vs `nocompile'!'`

- **`nocompile`** (no value): disables zcompile entirely for this plugin.
- **`nocompile'!'`** (with `!`): **reverses** meaning — enables compilation but
  delays it until after `make` and `atclone` complete. Use when `atclone` generates
  files that should be compiled (completions, init scripts).

### `atpull='%atclone'` and `run-atpull` interaction

- **`atpull'%atclone'`**: copies the `atclone` command into `atpull`. Same operations
  run on both clone AND update.
- **`run-atpull`**: forces `atpull` to run on EVERY update regardless of new commits.
- **Combined**: `atclone` runs on first install; same commands re-run on every
  `zinit update`, even without new commits. Without `run-atpull`, `atpull'%atclone'`
  only fires when `git pull` fetches new commits.

---

## The `sbin` Ice (from zinit-annex-bin-gem-node)

Creates **shim wrapper scripts** in `$ZPFX/bin` that forward execution to the
actual binary inside the plugin directory.

### Syntax

```
sbin'[{flags}:]{path-to-binary}[ -> {shim-name}]'
```

Multiple entries separated by `;`:

```zsh
--sbin='bin/tool1 -> tool1; bin/tool2 -> tool2'
```

### How shims work

The generated script at `$ZPFX/bin/<name>` delegates to the real binary:

```zsh
#!/usr/bin/env zsh
function toolname {
    local bindir="$ZINIT[PLUGINS_DIR]/org---repo"
    "$bindir"/"toolname" "$@"
}
toolname "$@"
```

### Flags

| Flag | Effect                                                              |
| ---- | ------------------------------------------------------------------- |
| `g`  | Export `$GEM_HOME` pointing to plugin directory                     |
| `n`  | Export `$NODE_PATH` to `{plugin-dir}/node_modules`                  |
| `p`  | Export `$VIRTUALENV` to `{plugin-dir}/venv`                         |
| `c`  | `cd` into plugin directory before execution                         |
| `N`  | Redirect stdout+stderr to `/dev/null`                               |
| `E`  | Redirect stderr to `/dev/null`                                      |
| `O`  | Redirect stdout to `/dev/null`                                      |
| `!`  | Use `#!/usr/bin/env -S zsh -fd` (skip zshenv/zshrc, faster start)  |

### Empty `sbin`

When no argument is given, auto-detects binary by checking: trailing component of
`id_as`, plugin name, snippet URL trailing component, or first executable file.

### The `fbin` ice

Same syntax as `sbin` but creates **functions** (not script files). Lighter weight
but only available in the current Zsh session — not visible to subprocesses.

---

## Annexes in Use

Loaded synchronously in `zinit_50_plugins.zsh`:

| Annex                      | Purpose                                                                        |
| -------------------------- | ------------------------------------------------------------------------------ |
| `z-a-meta-plugins`         | Meta-plugin groups (e.g. `@sharkdp` = bat + fd + hexyl + hyperfine + vivid)    |
| `zinit-annex-unscope`      | Short plugin names without org prefix; resolves via static DB or GitHub API     |
| `zinit-annex-readurl`      | Download latest versions from non-GitHub pages; provides `dlink`/`dlink0` ices |
| `zinit-annex-patch-dl`     | Additional file downloads (`dl` ice) and patch application (`patch` ice)       |
| `zinit-annex-submods`      | Clone additional repos as submodules (`submods` ice); auto-update with parent  |
| `zinit-annex-bin-gem-node` | `sbin`, `fbin`, `gem`, `node`, `pip` ices for binary/package management        |

### Meta-Plugin Groups (z-a-meta-plugins)

Groups available via `zinit for @group-name`:

| Group             | Contents                                                                       |
| ----------------- | ------------------------------------------------------------------------------ |
| `@sharkdp`        | fd, bat, hexyl, hyperfine, vivid                                               |
| `@zsh-users`      | zsh-syntax-highlighting, zsh-autosuggestions, zsh-completions                   |
| `@zsh-users+fast` | fast-syntax-highlighting, zsh-autosuggestions, zsh-completions                  |
| `@zdharma`        | fast-syntax-highlighting, history-search-multi-word, zsh-diff-so-fancy          |
| `@console-tools`  | dircolors-material, sharkdp group, exa, ripgrep, tig                           |
| `@fuzzy`          | fzf, fzy, skim, peco                                                           |
| `@ext-git`        | git-recall, git-open, git-recent, git-my, git-quick-stats, git-extras, git-cal |

The `@` prefix prevents names from colliding with ice modifiers (e.g. without `@`,
`sharkdp` could be parsed as the `sh` emulation ice).

Exclude sub-plugins with `skip`:

```zsh
zinit skip'ripgrep fd' for @console-tools
```

---

## Adding a New Plugin — Checklist

1. **Decide the loading group**: synchronous (lightweight, no `--wait`) or turbo?
2. **Decide the file**: which `zinit_*.zsh` file does it belong in?
3. **Use the `for` loop syntax** with `--` prefix ices — never the two-line form.
4. **Preserve the trailing comment pattern** (`# last line ;)`) — add your entry
   before it, ending with `\`.
5. **If it installs a binary**: use `--sbin` (provided by `zinit-annex-bin-gem-node`).
6. **If it needs post-install commands**: use `--atclone` + `--run-atpull` + `--atpull='%atclone'`.
7. **If it provides completions**: generate in `--atclone`, use `--nocompile='!'` to
   compile after generation.
8. **If platform-specific**: put in `zinit_20_macos.zsh` or `zinit_20_linux.zsh`.
9. **If profile-specific**: put in the relevant `profiles/*.zsh` file.
10. **Test**: run `zinit delete <id>` then re-source `.zshrc` or start a new shell.

---

## Common Mistakes to Avoid

| Mistake                                                         | Why it's wrong                                                                              |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| Using `zinit ice ...; zinit light ...` form                     | This config uses `for` syntax exclusively — mixing forms is inconsistent                    |
| Omitting `--run-atpull` with `--atpull='%atclone'`              | Without `--run-atpull`, `atpull` only runs on `zinit update`, not on pull-triggered updates |
| Putting syntax highlighting before other plugins                | `fast-syntax-highlighting` must be last (`zinit_99_last.zsh`)                               |
| Loading a binary tool without `--as='null'`                     | Zinit will try to `source` a binary, causing errors                                         |
| Using `--wait` on annexes or prompt                             | Annexes must be available before turbo plugins load; prompt must render before first prompt |
| Adding ices without `--` prefix                                 | This config's convention; legacy `ice'value'` form is not used here                         |
| Forgetting `--nocompile='!'` when generating files in `atclone` | Without the `!`, zinit compiles before `atclone` runs — the generated file won't exist yet  |
| Putting `$ZPFX/bin` in sbin path                                | `sbin` already targets `$ZPFX/bin` — the syntax is `source -> target-name`, not full paths  |

---

## Debugging

```zsh
# Show plugin load times
zinit times

# Show load order (moments)
zinit times -m

# Show what a plugin set up (aliases, functions, path entries)
zinit report <plugin-spec>

# Show all reports
zinit report --all

# Check if a plugin is loaded
zinit loaded | grep <pattern>

# List installed snippets / plugins (note: `zinit ls` is removed despite being in help)
zinit snippets
zinit plugins

# Recall the ices used for a plugin
zinit recall <plugin-spec>

# Delete and reinstall a plugin
zinit delete <plugin-spec>
# then restart shell or re-source zinit configs
```
