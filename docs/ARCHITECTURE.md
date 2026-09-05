# Dotfiles Architecture

This repository is a [chezmoi](https://www.chezmoi.io)-managed dotfiles setup. The chezmoi source directory is `home/`, declared via `.chezmoiroot`.

---

## Repository layout

See [docs/ai-instructions.md § "Project Structure"](ai-instructions.md#project-structure) for the full directory tree.
Key top-level paths relevant to this document:

- `home/` — chezmoi source dir (declared via `.chezmoiroot`)
- `install.sh` — POSIX bootstrap (single source of truth; also chezmoi hook)
- `Makefile` — the rbw build graph only; `just` is the task entry point
- `tests/` — integration test suite (Docker for Linux, UTM VM for macOS)

---

## Installation process

### Prerequisites

`AGE_PASSPHRASE` must be set in the environment before the first run. This passphrase decrypts the main age key (`age-00-chezmoi.key.age`) and — as a fallback — `accounts.json.age`.

### Bootstrap (install.sh)

`install.sh` is the single source of truth for bootstrap behavior. `install.sh` also serves as the chezmoi `read-source-state.pre` hook (see below).

**Invocation for a fresh machine:**

```sh
# POSIX sh (curl bootstrap)
AGE_PASSPHRASE=... sh -c "$(curl -fsSL 'https://raw.githubusercontent.com/turboBasic/dotfiles/refs/heads/main/install.sh')" -- init turboBasic/dotfiles

# With cleanup of existing chezmoi dirs:
... -- --cleanup init turboBasic/dotfiles
```

**What it guarantees on exit.** Every step is a no-op once satisfied, which is what makes it
safe to re-run as a hook on every source state read (see below):

- `~/.local/bin` exists, is on `PATH`, and holds `age` and `chezmoi`
- Homebrew is installed and on `PATH`; on Apple Silicon, Rosetta 2 is present
- `rbw`, a TTY pinentry and `oath-toolkit` are installed (brew on macOS, apt on Linux)
- the utilities the rest of the install assumes are present, or it fails naming what is
  missing rather than part-way through
- with the `init` subcommand only: `rbw` is configured and unlocked, then `chezmoi init`
  and `chezmoi init --apply` run with `AGE_PASSPHRASE` in the environment, so config
  rendering and secret decryption never need an interactive prompt

`--cleanup` wipes chezmoi's cache, config, data and state directories before init — for
reproducing a fresh-machine install on a machine that already has one.

Pinned tool versions, download sources and the order of the steps are `install.sh`'s own
business — read `main()` for the sequence rather than reasoning from this section.

---

### chezmoi init — config template (`.chezmoi.toml.tmpl`)

Rendered during `chezmoi init`, and the only thing that ever writes `chezmoi.toml`. It:

- **fails immediately when `AGE_PASSPHRASE` is unset on a first run** — nothing downstream
  can decrypt anything without it, so this is a guard rather than a confusing later failure
- **prompts once, and remembers**, for the age key name, the age recipient public key and
  the profile; subsequent inits are silent unless a stored answer is removed
- **writes the age encryption settings, the script environment, the
  `read-source-state.pre` hook and the `[data]` block** that every other template reads
  (see "Template data")
- **runs the secret-decryption script inline, before finishing**, so `accounts.json` is
  already decrypted in `~/.config/chezmoi/` in time to be read into `[data]` as
  `.accounts` and `.aliases` during the same render

That last point is the load-bearing one: `[data]` is baked into a static `chezmoi.toml`, so
anything templates need must be decrypted *before* the config is written, not during the
apply that follows. It is also why account changes require `chezmoi init --apply` and not a
plain apply (see "Updating accounts data").

---

### Secret decryption (`run_onchange_before_decrypt-chezmoi-secrets.sh`)

This script runs in two places:

- **during config template rendering**, called inline by `.chezmoi.toml.tmpl`
- **on every `chezmoi apply` where the encrypted sources changed** — it is a
  `run_onchange_` script whose rendered body carries the ciphertext hashes, so a changed
  `*.age` file changes the script and re-triggers it

It decrypts the main age key and every `*.age` file in `.secrets/` into
`~/.config/chezmoi/` at mode 600, keeping any previous plaintext alongside as `.old`.

**Two-key design:** The main key (`age-00-chezmoi.key`) is always encrypted symmetrically (passphrase). Other secrets (`accounts.json`) may be encrypted either symmetrically or asymmetrically using the main key — the script tries the key first, falls back to passphrase.

---

### Package installation (`run_onchange_01-install-packages.sh.tmpl`)

Triggered on every `chezmoi apply` when `packages.yaml` changes (hash in comment, `run_onchange_` prefix).

- **macOS:** `brew bundle` with `darwin.bootstrap` formulae and casks from `packages.yaml`.
- **Linux:** `sudo apt-get install` for `linux.apts` packages, then `brew bundle` with `linux.bootstrap` formulae. Brew is skipped inside a container, so the Docker test image installs apt packages only.

---

### VS Code extension installation (`run_onchange_02-install-vscode-extensions.sh.tmpl`)

#### Intent: Default is the baseline, every other profile is a delta

- **`Default` holds what every profile gets** — both extensions and settings. Its
  extension list is reproduced into every other profile.
- **Every other profile lists only its own extensions**, on top of Default's. This holds
  **regardless of whether the profile inherits extensions from Default in VS Code or keeps
  a fully independent list** — the YAML records the delta either way, and the install
  script is what makes the inherited case true on a fresh machine.
- **Settings work the opposite way round.** A profile's settings may legitimately differ
  from Default's, but a newly created profile inherits them
  (`useDefaultFlags.settings: true`, see `docs/guide-vscode-profiles.md`), so Default's
  settings are the baseline until a profile is deliberately given its own.

Triggered on every `chezmoi apply` when `vscode-extensions.yaml` changes, by the same
`run_onchange_` mechanism as package installation above.

- **macOS only** (skips with a message if the `code` CLI isn't on `PATH`).
- Reads `vscodeExtensions: {<profile name>: [<extension id>, ...]}` from
  `.chezmoidata/vscode-extensions.yaml`.
- **Every profile also gets Default's list.** Promoting an extension to Default therefore
  reaches every profile without editing any other list — which is what makes the baseline
  rule above hold for profiles that keep an independent extension list in VS Code rather
  than mirroring Default's.
- **Only missing extensions are installed, in one `code` invocation per profile.**
  Installing is idempotent, so the diffing buys nothing in correctness — it is purely
  about cost: an invocation per extension boots Electron hundreds of times and buries the
  run in "already installed" output.
- Keyed by **profile name**, not folder — the name is what `code --profile` accepts, and
  the name↔folder mapping exists only in live VS Code state, which this script does not
  read (see `docs/guide-vscode-profiles.md`).

`vscode-extensions.yaml` is **generated** — `./vscode-import-profiles` rewrites it from
scratch on every run out of live VS Code state, so hand edits are lost; change the profile
in VS Code and re-import. Default is imported for its extensions only: it has no profile
folder, and its settings are the root `Code/User/settings.json`, managed separately.

The same run regenerates the chezmoi-managed profile `settings.json` copies, which carry
nothing but a header comment — each profile's extension list lives in the YAML and nowhere
else, so there is no second copy to drift. Import is safe to repeat: `chezmoi apply` writes
the annotated copy back over the live file, so the importer must recognise and replace its
own previous output while leaving hand-written comments intact.

The install script only ever adds. An extension installed into a profile by hand and
never imported stays there, so the YAML describes a floor, not the exact set.
`./vscode-import-profiles --prune` reports what a profile has beyond the YAML, and
`--prune --yes` uninstalls it — kept out of `chezmoi apply` deliberately, so a stale YAML
can never strip a machine's extensions unattended.

---

## Encryption model

| Secret                                  | Encrypted with                          | Decrypted by                   |
| --------------------------------------- | --------------------------------------- | ------------------------------ |
| `age-00-chezmoi.key.age`                | AGE_PASSPHRASE (symmetric)              | passphrase only                |
| `accounts.json.age`                     | Main age key (asymmetric) or passphrase | key first, passphrase fallback |
| `private_git/encrypted_private_cookies` | chezmoi age (asymmetric, main key)      | chezmoi natively via config    |

After decryption, files land in `~/.config/chezmoi/` (mode 600, directory mode 700).

---

## Template data

All `.tmpl` files have access to chezmoi's standard variables plus the `[data]` block from `chezmoi.toml`:

| Variable               | Description                             |
| ---------------------- | --------------------------------------- |
| `.profile`             | `personal` or `work.2025.05`            |
| `.dotfiles_id`         | `dotfiles-2025`                         |
| `.dotfiles_key_name`   | age key filename                        |
| `.dotfiles_public_key` | age recipient public key                |
| `.accounts`            | JSON string of all account configs      |
| `.aliases`             | JSON string mapping alias → account key |
| `.packages`            | entire `packages.yaml` tree             |

Three more are **optional** — present only where `chezmoi init` was answered for them, and absent on a
machine with no work tooling. `private_dot_claude/private_settings.json.tmpl` guards each with `hasKey`,
so it renders valid JSON either way. See [guide-claude-plugins.md](guide-claude-plugins.md).

| Variable                    | Description                                          |
| --------------------------- | ---------------------------------------------------- |
| `.claude_work_marketplace`  | Work Claude marketplace name                         |
| `.claude_work_plugin`       | Work Claude plugin name within it                    |
| `.claude_work_repo`         | `owner/name` of the private repo hosting it          |

Profile-conditional logic (e.g. `zsh/.include/zinit_30_profiles.zsh.tmpl`, `zsh/private_dot_zshrc.tmpl`, git configs) uses `{{ if eq .profile "personal" }}` / `{{ if eq .profile "work.2025.05" }}`.

### Profiles

Available profiles: `personal`, `work.2025.05`.

The profile is selected once during `chezmoi init` (via `promptChoiceOnce`) and stored in
`~/.config/chezmoi/chezmoi.toml` under `[data] profile = "..."`.

**What the profile affects:**

- Zsh plugin sets and shell aliases (zinit profile-specific configs)
- Default git identity (which account is used for `user.name`/`user.email`)
- Which optional packages are installed

**Switching profiles:**

```shell
chezmoi init
```

Since the value is stored via `promptChoiceOnce`, re-running `chezmoi init` will
re-prompt for the profile. Alternatively, edit `~/.config/chezmoi/chezmoi.toml`
directly and change the `profile` value, then run `chezmoi apply`.

---

## Platform differences

`.chezmoiignore` is templated on `.chezmoi.os`, and is where every platform-specific path
exclusion belongs — the same target lives at a different path per platform, and the choice
is made there rather than inside each file. VS Code is the standing example: its config lives
under `~/Library` on macOS and `~/.config/Code` on Linux, so each is ignored on the other.
Only the macOS side has managed files today — the Linux guard is kept for when it does.

macOS-only: Rosetta install, `private_Library/`. Linux-only: apt-get package installation.

---

## chezmoi hook: `read-source-state.pre`

`install.sh` is registered as a pre-hook for every source state read:

```toml
[hooks.read-source-state.pre]
    command = "<worktree>/install.sh"
```

This ensures bootstrap dependencies (age, chezmoi, homebrew, rbw) remain present and up to date on every `chezmoi apply`, not just on initial install.

---

## Updating accounts data

When 1Password account entries change, run from the repo root:

```sh
just update-accounts
```

This runs `./op-update-accounts`, which drives the full pipeline: exports accounts from 1Password, encrypts, commits the change, and runs `chezmoi init --apply`. It prompts for `AGE_PASSPHRASE` if not already set and verifies `op` is authenticated (`op whoami`) first.

Under the hood it calls `op-export-accounts`, which:

1. Fetches account entries listed in the `accounts` item (`chezmoi` vault).
2. Transforms them into chezmoi data format (JSON).
3. Writes plaintext to `tmp/accounts.json` (for inspection, not committed).
4. Encrypts and writes to `home/.secrets/accounts.json.age` (via `env -u OP_SERVICE_ACCOUNT_TOKEN chezmoi encrypt`, since chezmoi errors in its default `account` mode when `OP_SERVICE_ACCOUNT_TOKEN` is set).

### Why `chezmoi init --apply` (not just `chezmoi apply`)

`chezmoi apply` only re-decrypts `accounts.json` into `~/.config/chezmoi/` (via the `run_onchange_` script). However, `.accounts` and `.aliases` in template data live in `chezmoi.toml` — a static file generated from `.chezmoi.toml.tmpl` **only during `chezmoi init`**. A plain `chezmoi apply` does not re-render the config, so templates referencing new accounts (e.g. a new gitconfig) will render empty.

`chezmoi init --apply` re-renders `chezmoi.toml` (picking up the new accounts/aliases) and then applies all targets in one step.

### How the change propagates

```plaintext
op-export-accounts
  └─► home/.secrets/accounts.json.age (encrypted, committed)

chezmoi init --apply
  ├─► .chezmoi.toml.tmpl: runs the decrypt script inline
  │     └─► decrypts accounts.json into ~/.config/chezmoi/
  ├─► .chezmoi.toml.tmpl: reads the decrypted accounts.json
  │     └─► populates [data] accounts + aliases in chezmoi.toml
  └─► apply phase: templates resolve .accounts/.aliases with fresh data
        └─► e.g. 60-vergnügte-wanze.gitconfig.tmpl renders correctly
```

The decrypt script's `.tmpl` suffix is what makes the re-trigger work: because it is a
template, the ciphertext hash it embeds is re-evaluated on every apply, so a changed
`accounts.json.age` changes the rendered script and `run_onchange_` fires. Drop the suffix
and the script becomes static — it would never re-run after new account data lands.

### Important notes

- The `AGE_PASSPHRASE` env var is needed because the script decrypts the main age key (`age-00-chezmoi.key.age`) first, which uses symmetric encryption. Without it (and without an interactive terminal), decryption fails silently and chezmoi still marks the script as executed — requiring `chezmoi state delete-bucket --bucket=entryState` to re-trigger.
- If decryption fails (no passphrase, no terminal), chezmoi records the script hash in `entryState` regardless of exit code. A subsequent `chezmoi apply` will not re-run the script. To force a re-run: `chezmoi state delete-bucket --bucket=entryState` (this also resets state for `run_onchange_01-install-packages.sh`).
- The config template calls the decrypt script by its **literal filesystem path** — `.tmpl` suffix and all — not by its chezmoi target name. Renaming the script therefore breaks `chezmoi init`, not just the apply-time re-trigger.

---

## Linting

`prek` runs the hooks declared in `.pre-commit-config.yaml`:

```sh
just lint                   # all hooks over every tracked file
just lint markdownlint-cli2 # a single hook
just lint-install           # install prek as the git pre-commit hook
```

| Hook              | Scope                                                                  |
| ----------------- | ---------------------------------------------------------------------- |
| markdownlint-cli2 | tracked `*.md`, rules and file selection in `.markdownlint-cli2.jsonc` |
| shellcheck        | `*.sh` with an `sh`/`bash` shebang                                     |
| cspell            | all tracked text, config in `.cspell.config.yaml`                      |

`markdownlint-cli2` rather than `markdownlint-cli`: its config owns both the rule set and
which files are linted, and its `overrides` block scopes a rule to a path glob. MD029 and
MD041 are switched off only under `.claude/skills/`, where skill files open with YAML
frontmatter instead of an H1 and interleave fenced blocks between numbered items — the rest
of the repo still gets both rules.

Exclusions that are deliberate and must be preserved:

- **`*.tmpl` is hidden from markdownlint and shellcheck, but not from cspell.** Templates
  are Go-template source, so they are neither valid markdown nor valid shell — but
  `.cspell.config.yaml` has `overrides` mapping `*.toml.tmpl`, `*zsh*.tmpl` and friends to
  their real syntax, so cspell reads them correctly and should keep seeing them.
- **Zsh is out of shellcheck's reach.** shellcheck has no zsh dialect, so `*.zsh` and
  `tests/test-macos.sh` (zsh despite the extension) are not checked.
- **VS Code user config is excluded from cspell** (`**/Code/User/**`,
  `.vscode/extensions.json`, `home/.chezmoidata/vscode-extensions.yaml`) — generated
  settings and the generated per-profile extension lists contribute roughly 150
  marketplace publisher IDs and no prose.
- **age recipient keys and 1Password 26-char IDs** are dropped by `ignoreRegExpList`
  rather than being listed word by word.

`docs/chezmoi/` and `docs/zinit/` are vendored submodules and are excluded from every hook.

Project vocabulary lives in `.cspell/project-words.txt`, grouped by origin. A term that
recurs across every repo belongs in the user dictionary
(`~/.config/cspell/user-words-dictionary.txt`) instead.

## Test suite

Integration tests live in `tests/integration/`, one script per assertion, run via `just test`:

```sh
just                        # list all recipes
just test                   # runs test-ubuntu + test-macos
just test-ubuntu            # Docker-based Ubuntu tests (requires AGE_PASSPHRASE)
just test-macos             # macOS tests via UTM VM (requires AGE_PASSPHRASE, RBW_EMAIL, RBW_PASSWORD, RBW_TOTP_SEED)
just rbw                    # build rbw binaries (default: arm64)
just arch=amd64 rbw         # build rbw binaries for amd64
just update-accounts        # export accounts, encrypt, commit, apply
```

Missing environment variables are reported by name before any work starts.

`just` is the entry point for every task. The `Makefile` is retained solely for the rbw
build graph, the one place with genuine file-based staleness: a stamp file gates an
expensive docker build on input timestamps, which just cannot express. `just rbw` and
`just clean` delegate to it, and calls only ever go that way round.

### macOS tests

The `test-macos` target clones a base UTM VM, connects over SSH, and runs
the full install + test suite non-interactively. A custom `pinentry-env` script
provides Bitwarden credentials, and `oathtool` generates fresh TOTP codes
at unlock time. See `tests/README-macos.md` for base VM setup instructions.

| Test                                  | What it checks                                 |
| ------------------------------------- | ---------------------------------------------- |
| `accounts-file-is-decrypted.sh`       | `accounts.json` exists in `~/.config/chezmoi/` |
| `chezmoi-config-has-accounts.sh`      | `accounts.json` contains expected account key  |
| `chezmoi-data-are-available.sh`       | chezmoi template data is populated             |
| `chezmoi-private-key-is-deployed.sh`  | age private key file exists                    |
| `git-account-configs-are-deployed.sh` | per-account gitconfig files deployed           |
| `git-default-config.sh`               | default git config is correct                  |
| `readme-is-deployed.sh`               | `~/README.md` was generated from template      |
