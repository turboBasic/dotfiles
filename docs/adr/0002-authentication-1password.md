# 0002. 1Password authentication strategy

- Status: Proposed
- Date: 2026-06-27
- Deciders: turboBasic (owner)

## Context

Secrets are resolved from 1Password via the `op` CLI — used directly and by chezmoi
`onepasswordRead`/`op://` references (see [[0001-accounts-and-profiles-data-format]]). The CLI
prompts for authentication often enough to disrupt agent-driven and shell-startup workflows. This
ADR records why the prompts happen, what was tried, the service-account assets already provisioned,
and the remaining design choice for wiring a service-account token into the shell.

Environment facts (account `my.1password.eu`, account id `HMU2XK2PP5EQ5AVZW6BKAUDFHM`):

- `op` CLI 2.34.1 at `/opt/homebrew/bin/op`, desktop-app integration enabled.
- Vaults: `Personal`, `work-daimler-truck`, `work-dxc`, `work-luxoft`, `work-mercedes-benz`,
  `work-vw`, and the new `chezmoi` vault.
- Dotfiles already decrypt bootstrap secrets from `.secrets/*.age` into `~/.config/chezmoi/` via
  `run_onchange_before_decrypt-chezmoi-secrets.sh`, using an on-disk age key — **no prompt, no
  1Password involvement**.

### Why the prompts happen

`op read` delegates auth to the desktop app. The desktop app tracks authorization per OS
session/TTY — all processes sharing the same session inherit authorization from each other.
However, **each Claude Code Bash tool call runs in its own independent OS session**: no shared
TTY, no shared session, no inheritance. Every tool call is a fresh session from the app's
perspective, so each one prompts independently.

### What was tried (all rejected)

- **Extending desktop auto-lock** (Settings → Security → longer idle timeout, disable lock on
  sleep/screensaver). Helps a human running `op` repeatedly in one terminal (all in one session);
  does **not** eliminate prompts for Claude Code Bash tool calls. Confirmed insufficient.
- **CLI session token** (`eval $(op signin)`): the desktop integration overrides the
  `OP_SESSION_<account>` path while enabled, so it is unreliable.
- **Claude Code `SessionStart` hook running `op read`.** Hypothesis: the hook runs in the same
  session as Bash tool calls, so one authorization at startup covers all. **Refuted by
  experiment**: each Bash tool call still prompted independently. The hook runs in its own session,
  separate from tool-call sessions.
- **Pre-launch authorization in the terminal before starting Claude.** Hypothesis: authorizing in
  the parent terminal session before `claude` is launched covers all descendant tool calls via TTY
  inheritance. **Refuted by experiment**: tool calls still prompted independently. Claude Code
  spawns each Bash tool call in an isolated session (via `setsid` or equivalent), severing TTY
  inheritance from the parent terminal entirely.

### Experimental findings (authorization scope)

Three experiments to map exactly where authorization is and is not inherited:

1. **Parent → child (inherited).** Parent subshell (pid 66887) authorized via one prompt; child
   `zsh` (pid 66889, ppid 66887) read silently. Authorization flows down a process tree.

2. **Sibling processes in one tool call (inherited).** Two `zsh` subprocesses spawned sequentially
   within a single Bash tool call both share the same session. One prompt covered both siblings.
   Authorization is session-scoped, not just PID-ancestry-scoped.

3. **Separate Bash tool calls (NOT inherited).** Two consecutive Claude Code Bash tool calls each
   prompted independently. Each tool call is a fresh OS session — there is nothing to inherit from.
   The `SessionStart` hook is also a separate session and does not bridge to tool calls.

**Conclusion:** the only way to eliminate prompts for Claude Code Bash tool calls is to avoid the
desktop integration entirely — i.e., use a service-account token via `OP_SERVICE_ACCOUNT_TOKEN`.

### Service-account assets provisioned

A read-only service account was created to bypass the desktop app for non-interactive reads:

- **Vault** `chezmoi` (`hy5zw37n565stdjlugwfdnxlp4`), `USER_CREATED`, for automation/chezmoi use.
- **Service account** `chezmoi` (read-only `read_items`) scoped to **6 vaults**: `chezmoi` plus all
  five `work-*` vaults.
- **Token** stored at `op://Personal/rbcvlawhbstklfig7ziwhju734/chezmoi-service-account`. With
  `OP_SERVICE_ACCOUNT_TOKEN` set to this value, reads from the 6 vaults succeed in a clean
  environment (`env -i … op read op://chezmoi/…`) with **zero prompts**.
- The `accounts` item was copied (not moved) from `Personal` into `chezmoi` so it is reachable by
  the SA; the original remains in `Personal`.

### Service-account constraints (hard limits, verified)

- **No Personal/Private vault access.** `op service-account create` states plainly: *"You can't
  grant a service account access to your Personal or Private vault."* Anything under `op://Personal/…`
  is unreachable by any SA — the reason the `accounts` item had to be copied into `chezmoi`.
- **Vault access is fixed at creation.** *"After you create a service account, you can't add
  additional vaults or edit any vault permissions."* Expanding scope means creating a new SA.
- **Token is shown once** and the SA cannot be modified after creation.

### Three landmines for shell integration

The naive "read the token at every shell start and export it" approach breaks things:

1. **A globally exported `OP_SERVICE_ACCOUNT_TOKEN` routes *every* `op` in that shell through the
   SA — which cannot read `Personal`.** Verified: with the token set, `op read "op://Personal/…"`
   fails with *"Personal isn't a vault in this account."* Interactive Personal reads stop working
   everywhere the var is set.
2. **chezmoi's default `account` mode errors if `OP_SERVICE_ACCOUNT_TOKEN` is set.** A globally
   exported token collides with chezmoi's own 1Password reads during `chezmoi apply`.
3. **Reading the token from `Personal` needs the desktop app = a prompt.** Doing that at every
   shell start reintroduces the very prompt being eliminated. The value must be **baked once** to a
   cached file, not read live per shell.

The real task is therefore: *resolve the token once, cache it to a private (mode 600) file, source
that file*, while keeping the var out of `.zshenv`/global scope and out of chezmoi's `apply` run.

## Decision

**Proposed (pending owner choice on delivery + scope).** Adopt a service-account token
(`OP_SERVICE_ACCOUNT_TOKEN`) as the only viable mechanism for prompt-free `op` reads from Claude
Code Bash tool calls. The desktop integration cannot be used — it prompts per tool-call session and
has no bridging mechanism.

Continue to use the **desktop integration** for interactive `op://Personal/…` reads in a human
terminal — the SA cannot serve those, so the two mechanisms coexist by design.

### Delivery mechanism (how the token reaches the shell)

- **A — chezmoi bakes it from 1Password at `apply` time.** A template file holds only the reference
  `{{ onepasswordRead "op://Personal/…/chezmoi-service-account" }}`; chezmoi resolves it during
  `chezmoi apply` (one prompt then) and writes the literal token into a generated `600` file the
  shell sources. Requires wrapping chezmoi to avoid landmine #2, e.g.
  `alias chezmoi='env -u OP_SERVICE_ACCOUNT_TOKEN command chezmoi'`. Token lands as plaintext (600).
- **B — age-encrypt the token into the existing `.secrets/` pipeline (recommended).** Drop
  `op-service-account.age` into `.secrets/`; the existing
  `run_onchange_before_decrypt-chezmoi-secrets.sh` decrypts it to `~/.config/chezmoi/` at apply time
  using the on-disk age key — **no prompt, no 1Password call, no `account`-mode collision**. The
  shell sources the decrypted file. Sidesteps all three landmines and matches how bootstrap secrets
  already flow in this repo.

### Activation scope (where the var is live)

- **Global** — export in shell startup. Simplest, but breaks `op read op://Personal/…` everywhere
  (landmine #1). Mitigate with a passthrough helper that strips the var:
  `op-personal() { env -u OP_SERVICE_ACCOUNT_TOKEN op "$@"; }`.
- **Scoped (recommended)** — make the token live only where it is needed (e.g. `direnv` in project
  directories, or a function that sets it for a single command). Interactive `op://Personal/…` reads
  keep working in normal shells because the var is absent there.

Placement notes for implementation: the async/sourcing step must run **after** zinit loads
`zsh-async` (i.e. alongside or after `.include/zinit_99_last.zsh`); the existing autoloaded
`set_env_var_async` helper is a fit if an async path is wanted. Do **not** put the export in
`private_dot_zshenv` (it is sourced for all shells, including chezmoi's own invocations).

### Security ranking of the candidate mechanisms

Before settling on a delivery, the five candidate mechanisms were ranked by
credential exposure (most → least secure). This is the security lens behind the
"service account" decision above:

| Rank | Mechanism | Credential at rest | Exposure while active | Exposure ends when |
| ---- | --------- | ------------------ | --------------------- | ------------------ |
| 1 | Desktop app-integration tuning | none new | single terminal, single account, 10-min refreshing session | app locks / 12 h hard cap |
| 2 | Mounted `.env` (1Password Environments, beta) | none (FIFO, never on disk) | every local process can read the file after one authorization | app locks / destination disabled |
| 3 | Shell-cached env var | none on disk | plaintext in shell env/memory; visible to same-user processes; survives app lock | shell exits |
| 4 | **Service-account token (chosen)** | long-lived bearer token on machine | any holder reads the vault from anywhere, no device binding | token revoked manually |
| 5 | Connect server | `1password-credentials.json` + access tokens | vault cache served over local REST to any token holder | server torn down |

Convenience ranks roughly inverse. The service-account token (rank 4) is the
only mechanism that removes per-tool-call prompts entirely *and* works headless;
the rank-4 theft risk is accepted and mitigated by read-only single-vault scope,
Keychain/1Password storage, and never exporting the token globally.

## Considered Options

- **A — Desktop auto-lock tuning only.** Rejected — does not stop per-tool-call prompts.
- **B — `SessionStart` hook running `op read`.** Rejected — hook and tool calls are in separate OS
  sessions; prompts continue.
- **C — Pre-launch `op read` in terminal before starting Claude.** Rejected — Claude Code severs
  TTY inheritance by spawning tool calls in isolated sessions; prompts continue.
- **D — Service account, token from 1Password at apply time (delivery A).** Honors `op://` as the
  source of truth. Cost: chezmoi wrapper to dodge `account`-mode collision; plaintext 600 file;
  one prompt per `apply`.
- **E — Service account, token age-encrypted via `.secrets/` (delivery B) + scoped activation
  (chosen/recommended).** Reuses the existing prompt-free decrypt pipeline; no `account`-mode
  collision; Personal reads stay intact. Cost: token also stored age-encrypted in the repo (in
  addition to 1Password), and SA scope is frozen at creation.

## Consequences

- **+** With `OP_SERVICE_ACCOUNT_TOKEN` set, reads from `chezmoi` + `work-*` vaults are
  completely prompt-free regardless of desktop app state.
- **+** Delivery B/scoped introduces **no new prompt** (decrypt uses the on-disk age key) and
  **no** chezmoi `account`-mode collision.
- **+** Interactive `op://Personal/…` reads continue to work via the desktop integration in human
  terminal sessions; the two mechanisms coexist by design.
- **−** No solution exists for prompt-free `op://Personal/…` reads from Claude Code tool calls —
  the SA cannot access Personal and the desktop integration always prompts per tool-call session.
- **−** A second copy of secrets to manage: the `accounts` item lives in both `Personal` and
  `chezmoi` and must be kept in sync.
- **−** SA vault scope is fixed at creation — adding vaults later means a new SA and token rotation.
- **−** A globally activated SA token would shadow `Personal` reads (landmine #1); scoped
  activation or an `op-personal` passthrough helper is required to avoid surprise failures.

## Implementation

The operational runbook for the chosen approach — creating the scoped
`shell-work-vw` service account, the authenticate-once-per-shell flow for
Claude Code, the ad-hoc `opw` Keychain wrapper, and the verification probes —
lives in [../guide-work-vw-service-account.md](../guide-work-vw-service-account.md).
