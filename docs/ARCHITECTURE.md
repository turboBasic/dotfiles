# Dotfiles Architecture

This repository is a [chezmoi](https://www.chezmoi.io)-managed dotfiles setup. The chezmoi source directory is `home/`, declared via `.chezmoiroot`.

---

## Repository layout

See [docs/ai-instructions.md § "Project Structure"](ai-instructions.md#project-structure) for the full directory tree.
Key top-level paths relevant to this document:

- `home/` — chezmoi source dir (declared via `.chezmoiroot`)
- `install.sh` — POSIX bootstrap (single source of truth; also chezmoi hook)
- `Makefile` — development tasks (test, rbw, clean)
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

**Bootstrap sequence** (`main` / `install_main`):

1. Detect OS (`darwin` / `linux`) and arch (`amd64` / `arm64`).
2. `check_utils` — verify `curl`, `expect`, `git`, `grep`, `sed`, `tar`, `uname`, `unzip`, `zsh` are present; on Linux, also installs `rbw` via apt-get.
3. `install_bin_dir` — ensure `~/.local/bin` exists and is on `PATH`.
4. `install_age` — download age v1.1.1 binary to `~/.local/bin` if not present.
5. `install_chezmoi` — download chezmoi via `get.chezmoi.io/lb` to `~/.local/bin` if not present.
6. `install_rozetta` — on Apple Silicon, install Rosetta 2 if not running.
7. `install_homebrew` — install Homebrew if absent; run `eval "$(brew shellenv)"`.
8. `install_pinentry` — install `pinentry-tty` (apt on Linux, brew on macOS).
9. `install_rbw` — install rbw (latest .deb on Linux, brew on macOS).
10. `install_oathtool` — install oath-toolkit (brew on macOS, apt on Linux).
11. If subcommand is `init`, `unlock_rbw` runs — configures rbw email, lock_timeout (86400 s), pinentry; runs `rbw unlock`.
12. If `--cleanup` flag: wipe contents of `~/.cache/chezmoi`, `~/.config/chezmoi`, `~/.local/share/chezmoi`, `~/.local/state/chezmoi`.
13. If `init` subcommand: call `_install_dotfiles` with the repo argument.

**`_install_dotfiles`:**

```bash
AGE_PASSPHRASE=... chezmoi init turboBasic/dotfiles
AGE_PASSPHRASE=... chezmoi init --apply
```

Both invocations pass `AGE_PASSPHRASE` so that config template processing and secret decryption can access it without interactive prompts.

---

### chezmoi init — config template (`.chezmoi.toml.tmpl`)

Executed during `chezmoi init`. Steps in template order:

1. **Guard** — fail immediately if `AGE_PASSPHRASE` is not set and this is a first run (no `profile` key in existing data).
2. **Prompt once** for `dotfiles_key_name` (default: `age-00-chezmoi.key`) and `dotfiles_public_key` (the age recipient public key).
3. Derive `$configDir` from `CHEZMOI_CONFIG_FILE` env var (`~/.config/chezmoi/`).
4. Write `chezmoi.toml` with:
   - `encryption = "age"`, identity = `$configDir/<key_name>`, recipient = public key.
   - `[scriptEnv] DOTFILES_KEY_NAME` — passed to scripts as env var.
   - `[hooks.read-source-state.pre] command = "install.sh"` — re-runs install.sh before every source state read.
   - `[data]` block: `dotfiles_id`, `dotfiles_key_name`, `dotfiles_public_key`, `profile`.
5. **Prompt once** for `profile` choice: `personal` or `work.2025.05`.
6. **Execute inline** `run_onchange_before_decrypt-chezmoi-secrets.sh` (via `output "zsh" "-c" ...`) to decrypt secrets into `~/.config/chezmoi/` before the template finishes.
7. If `accounts.json` now exists in `$configDir`, read and embed it into `[data]` as `accounts` (JSON string) and `aliases` (alias→account-key map).

---

### Secret decryption (`run_onchange_before_decrypt-chezmoi-secrets.sh`)

This script runs both:

- **During config template rendering** (via `output` call in `.chezmoi.toml.tmpl`)
- **On every `chezmoi apply`** when `.secrets/*.age` content changes (the `run_onchange_` prefix re-triggers on hash change; the hash is embedded as a comment in line 3)

Sequence:

1. Set `DEST_DIR = ~/.config/chezmoi/`, `SOURCE_DIR = <source>/.secrets/`.
2. Build the list of secret files: always includes `$DOTFILES_KEY_NAME` (the main key), plus every `*.age` file in `.secrets/` stripped of the `.age` suffix.
3. For each secret:
   a. If an existing decrypted file is present, rename to `.old`.
   b. Try `decrypt_using_chezmoi_key` — `age --decrypt --identity $DOTFILES_PRIVATE_KEY`.
   c. On failure, try `decrypt_using_passphrase` — calls `dot_local/bin/executable_age-passphrase --decrypt` with `AGE_PASSPHRASE`.
   d. Set permissions 600 on the output file.

**Two-key design:** The main key (`age-00-chezmoi.key`) is always encrypted symmetrically (passphrase). Other secrets (`accounts.json`) may be encrypted either symmetrically or asymmetrically using the main key — the script tries the key first, falls back to passphrase.

---

### Package installation (`run_onchange_01-install-packages.sh.tmpl`)

Triggered on every `chezmoi apply` when `packages.yaml` changes (hash in comment, `run_onchange_` prefix).

- **macOS:** `brew bundle` with `darwin.bootstrap` formulae and casks from `packages.yaml`.
- **Linux:** `sudo apt-get install` for `linux.apts` packages, then `brew bundle` with `linux.bootstrap` formulae. Skips brew bundle inside Docker (detected via `/.dockerenv`).

The template uses custom delimiters `#{` / `}#` (declared via `chezmoi:template:left-delimiter` / `right-delimiter` directives) to avoid conflicts with heredoc content.

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

The `.chezmoiignore` file gates platform-specific paths:

```go
{{ if ne .chezmoi.os "darwin" }}
Library          ← macOS ~/Library (VS Code, etc.) excluded on Linux
{{ end }}
{{ if ne .chezmoi.os "linux" }}
.config/Code     ← Linux VS Code path excluded on macOS
{{ end }}
```

macOS-only: Rosetta install, `private_Library/` (VS Code settings at `~/Library/Application Support/Code`).
Linux-only: apt-get package installation, `.config/Code/` path.

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
  ├─► .chezmoi.toml.tmpl (line 36-37): executes decrypt script inline via `output`
  │     └─► decrypts accounts.json into ~/.config/chezmoi/
  ├─► .chezmoi.toml.tmpl (line 39-48): reads decrypted accounts.json
  │     └─► populates [data] accounts + aliases in chezmoi.toml
  └─► apply phase: templates resolve .accounts/.aliases with fresh data
        └─► e.g. 60-vergnügte-wanze.gitconfig.tmpl renders correctly
```

The decrypt script (`run_onchange_before_decrypt-chezmoi-secrets.sh.tmpl`) is a **template** — the `.tmpl` suffix is critical. Line 3 contains:

```go
# accounts.json.age hash: {{ include ".secrets/accounts.json.age" | sha256sum }}
```

Because the script is a template, chezmoi evaluates this directive on every apply. When `accounts.json.age` changes, the rendered script content changes, and `run_onchange_` fires. The script then:

1. Renames existing `~/.config/chezmoi/accounts.json` to `.old`.
2. Decrypts `accounts.json.age` using the main age key (falls back to `AGE_PASSPHRASE` for symmetric decryption).
3. Writes the result to `~/.config/chezmoi/accounts.json`.

### Important notes

- The `AGE_PASSPHRASE` env var is needed because the script decrypts the main age key (`age-00-chezmoi.key.age`) first, which uses symmetric encryption. Without it (and without an interactive terminal), decryption fails silently and chezmoi still marks the script as executed — requiring `chezmoi state delete-bucket --bucket=entryState` to re-trigger.
- If decryption fails (no passphrase, no terminal), chezmoi records the script hash in `entryState` regardless of exit code. A subsequent `chezmoi apply` will not re-run the script. To force a re-run: `chezmoi state delete-bucket --bucket=entryState` (this also resets state for `run_onchange_01-install-packages.sh`).
- The config template (`.chezmoi.toml.tmpl` line 35-37) calls the decrypt script by its **literal filesystem path** (including `.tmpl` suffix), not by its chezmoi target name.

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
  `.vscode/extensions.json`) — generated settings across profiles contribute roughly 150
  marketplace publisher IDs and no prose.
- **age recipient keys and 1Password 26-char IDs** are dropped by `ignoreRegExpList`
  rather than being listed word by word.

`docs/chezmoi/` and `docs/zinit/` are vendored submodules and are excluded from every hook.

Project vocabulary lives in `.cspell/project-words.txt`, grouped by origin. A term that
recurs across every repo belongs in the user dictionary
(`~/.config/cspell/user-words-dictionary.txt`) instead.

## Test suite

Seven integration tests in `tests/integration/`, run via `just test`:

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
build graph — `$(BIN_DIR)/.stamp` gates an expensive docker build on input timestamps,
which just cannot express — and `just rbw` / `just clean` delegate to it.

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
