# Dotfiles Architecture

This repository is a [chezmoi](https://www.chezmoi.io)-managed dotfiles setup. The chezmoi source directory is `home/`, declared via `.chezmoiroot`.

---

## Repository layout

```plaintext
dotfiles/
├── home/                        ← chezmoi source dir (--source flag target)
│   ├── .chezmoi.toml.tmpl       ← config template, runs on init
│   ├── .chezmoidata/
│   │   └── packages.yaml        ← package manifest for macOS/Linux
│   ├── .chezmoiignore
│   ├── .chezmoiscripts/
│   │   ├── run_onchange_before_decrypt-chezmoi-secrets.sh  ← decrypts secrets
│   │   └── run_onchange_01-install-packages.sh.tmpl        ← installs packages
│   ├── .chezmoitemplates/       ← reusable template snippets (empty)
│   ├── .chezmoiexternals/       ← external resources (empty)
│   ├── .secrets/
│   │   ├── accounts.json.age    ← encrypted accounts (passphrase or key)
│   │   └── age-00-chezmoi.key.age  ← encrypted main age private key (passphrase)
│   ├── dot_local/bin/
│   │   ├── executable_age-passphrase          ← age wrapper for passphrase ops
│   │   └── executable_install-heavy-packages.tmpl
│   ├── private_dot_config/
│   │   ├── private_git/         ← per-account gitconfigs (templated, some encrypted)
│   │   ├── zsh/                 ← zsh config, zinit, functions, profiles
│   │   ├── mise/config.toml.tmpl
│   │   ├── atuin/, bat/, cspell/, ripgrep/, tmux/
│   │   └── private_Code/        ← VS Code config (Linux path, macOS-excluded via .chezmoiignore)
│   ├── private_Library/         ← macOS Library/Application Support (ignored on Linux)
│   ├── symlink_dot_bashrc        ← ~/.bashrc → .config/bash/bashrc
│   ├── symlink_dot_zshenv        ← ~/.zshenv → .config/zsh/.zshenv
│   └── README.md.tmpl
├── install.sh                   ← POSIX bootstrap (also called as chezmoi hook)
├── install.zsh                  ← Zsh bootstrap (preferred entry point)
├── tests/                       ← integration test suite (7 scripts)
├── _symlinks/                   ← convenience symlinks to ~/.config dirs
├── bw-export-accounts           ← Bitwarden account export helper
└── bw-update-accounts           ← Full pipeline: export → commit → chezmoi init --apply
```

---

## Installation process

### Prerequisites

`AGE_PASSPHRASE` must be set in the environment before the first run. This passphrase decrypts the main age key (`age-00-chezmoi.key.age`) and — as a fallback — `accounts.json.age`.

### Bootstrap (install.sh / install.zsh)

Both scripts are functionally equivalent; `install.zsh` uses Zsh idioms and is the preferred entry point. `install.sh` is POSIX sh and also serves as the chezmoi `read-source-state.pre` hook (see below).

**Invocation for a fresh machine:**

```sh
# POSIX sh (curl bootstrap)
AGE_PASSPHRASE=... sh -c "$(curl -fsSL 'https://raw.githubusercontent.com/turboBasic/dotfiles/refs/heads/main/install.sh')" -- init turboBasic/dotfiles

# Zsh
AGE_PASSPHRASE=... zsh -c "$(curl -fsSL 'https://raw.githubusercontent.com/turboBasic/dotfiles/refs/heads/main/install.zsh')" -- init turboBasic/dotfiles

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
10. `unlock_rbw` — configure rbw email, lock_timeout (86400 s), pinentry; run `rbw unlock`.
11. If `--cleanup` flag: wipe contents of `~/.cache/chezmoi`, `~/.config/chezmoi`, `~/.local/share/chezmoi`, `~/.local/state/chezmoi`.
12. If `init` subcommand: call `_install_dotfiles` with the repo argument.

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

When Bitwarden account entries change, run from the repo root:

```sh
./bw-update-accounts
```

This wrapper script runs the full pipeline: exports accounts from Bitwarden, encrypts, commits the change, and runs `chezmoi init --apply`. It prompts for `AGE_PASSPHRASE` if not already set and unlocks `rbw` if needed.

Under the hood it calls `bw-export-accounts`, which:

1. Syncs the local rbw cache (`rbw sync`).
2. Fetches account entries listed in the `accounts` Bitwarden item.
3. Transforms them into chezmoi data format (JSON).
4. Writes plaintext to `tmp/accounts.json` (for inspection, not committed).
5. Encrypts and writes to `home/.secrets/accounts.json.age`.

### Why `chezmoi init --apply` (not just `chezmoi apply`)

`chezmoi apply` only re-decrypts `accounts.json` into `~/.config/chezmoi/` (via the `run_onchange_` script). However, `.accounts` and `.aliases` in template data live in `chezmoi.toml` — a static file generated from `.chezmoi.toml.tmpl` **only during `chezmoi init`**. A plain `chezmoi apply` does not re-render the config, so templates referencing new accounts (e.g. a new gitconfig) will render empty.

`chezmoi init --apply` re-renders `chezmoi.toml` (picking up the new accounts/aliases) and then applies all targets in one step.

### How the change propagates

```plaintext
bw-export-accounts
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

## Test suite

Seven integration tests in `tests/`, run via `test.zsh`:

| Test                                  | What it checks                                 |
| ------------------------------------- | ---------------------------------------------- |
| `accounts-file-is-decrypted.sh`       | `accounts.json` exists in `~/.config/chezmoi/` |
| `chezmoi-config-has-accounts.sh`      | `accounts.json` contains expected account key  |
| `chezmoi-data-are-available.sh`       | chezmoi template data is populated             |
| `chezmoi-private-key-is-deployed.sh`  | age private key file exists                    |
| `git-account-configs-are-deployed.sh` | per-account gitconfig files deployed           |
| `git-default-config.sh`               | default git config is correct                  |
| `readme-is-deployed.sh`               | `~/README.md` was generated from template      |
