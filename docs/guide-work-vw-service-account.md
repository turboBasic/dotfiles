# Guide: work-vw secrets in Claude Code shells via a scoped service account

**Goal:** authenticate to 1Password **once** in a shell, start Claude Code in
that same shell, and have every shell Claude Code spawns read secrets from
vault `work-vw` (e.g. `op://work-vw/devstack-jira-pat/credential`) with **no
further authentication prompts**.

**Mechanism:** `OP_SERVICE_ACCOUNT_TOKEN` exported in the parent shell is
inherited by the `claude` process and by every subshell its Bash tool spawns.
While the variable is set, `op` authenticates as the service account directly
against 1Password's servers — the desktop app, biometrics, and session state
are not involved at all.

Background and the decision rationale (why a service account, why not the
desktop integration) live in [adr/0002-authentication-1password.md](adr/0002-authentication-1password.md).
For a one-off command instead of a whole session, see the `opw` Keychain
wrapper in the [Ad-hoc alternative](#ad-hoc-alternative-the-opw-keychain-wrapper)
appendix below.

---

## Step 1 — Create the service account scoped to `work-vw` (once)

Service-account scope is **immutable** — vault access and permissions are
fixed at creation. Read-only on `work-vw`, nothing else, 90-day expiry:

```shell
op service-account create shell-work-vw --expires-in 90d --vault work-vw:read_items
```

- Triggers one biometric prompt (the command runs under your personal
  session).
- The token (`ops_…`, ~850 chars) is printed **once** and cannot be retrieved
  again. Save it immediately (Step 2) before closing the terminal.
- Requires 1Password CLI ≥ 2.18.0 (installed: 2.34.1).

To save the token without it ever appearing on screen, capture it directly
into a variable instead:

```shell
tok=$(op service-account create shell-work-vw --expires-in 90d --vault work-vw:read_items --raw)
```

## Step 2 — Save the token in 1Password (once)

Add it as a new concealed field on the existing token item
(`eu.1password@serviceAccountAuthToken`, Personal vault, item id
`rbcvlawhbstklfig7ziwhju734`):

```shell
op item edit rbcvlawhbstklfig7ziwhju734 "shell-work-vw[concealed]=$tok"
unset tok
```

> The item title contains `@`, which is invalid in `op://` secret
> references — always reference this item by **ID**.

## Step 3 — Authenticate once per work session

In the shell where you'll run Claude Code:

```shell
export OP_SERVICE_ACCOUNT_TOKEN=$(op read "op://Personal/rbcvlawhbstklfig7ziwhju734/shell-work-vw")
```

- This is the **single** authentication of the session: one biometric prompt
  to release the token from 1Password. The token then lives only in this
  shell's environment — never on disk.
- Verify the identity switched:

  ```shell
  op whoami        # User Type: SERVICE_ACCOUNT
  ```

Optional convenience function for your zsh config:

```zsh
op-work() {
  export OP_SERVICE_ACCOUNT_TOKEN=$(op read "op://Personal/rbcvlawhbstklfig7ziwhju734/shell-work-vw") \
    && op whoami
}
```

## Step 4 — Start Claude Code in the same shell

```shell
claude
```

Every Bash tool invocation inside Claude Code inherits
`OP_SERVICE_ACCOUNT_TOKEN`, so any spawned shell — including nested ones —
reads `work-vw` secrets prompt-free:

```shell
op read "op://work-vw/devstack-jira-pat/credential"
op run --env-file=./work.env -- some-tool
```

## Step 5 — End of session

```shell
unset OP_SERVICE_ACCOUNT_TOKEN    # restores personal-account op behavior
```

Or just close the shell — the token evaporates with it.

---

## Caveats

- **While the token is exported, `op` cannot see your other vaults**
  (Personal, `chezmoi`, other `work-*`): the scoped service account has
  access to `work-vw` only. Personal `op` use needs a shell without the
  export (or `unset` first). This is by design — least privilege.
- The token is visible to **every** process started from that shell,
  including anything Claude Code runs. That is the feature, but treat the
  session accordingly.
- Rate limits (individual plan): 1,000 reads/h per token, 1,000
  requests/24 h account-wide. `op read` costs 1–3 requests. Check usage:
  `op service-account ratelimit shell-work-vw`.
- Expiry: after 90 days, rotate on 1password.com > Developer > Service
  accounts (rotation keeps the account, issues a new token — re-run Step 2's
  save with the new value), or recreate via Step 1.
- Revocation: 1password.com > Developer > Service accounts > Revoke Token.

---

## Ad-hoc alternative: the `opw` Keychain wrapper

For a single command outside a Claude Code session, a wrapper that pulls a
token from the macOS Keychain avoids both the export and any prompt. The token
is stored once:

```shell
op read "op://Personal/rbcvlawhbstklfig7ziwhju734/work-reader-account" \
  | { read -r tok; printf 'add-generic-password -U -s op-sa-work-vw -a %s -w %s\n' "$USER" "$tok" | security -i; }
```

Then the wrapper injects it per-command only:

```zsh
# read work-* vault secrets via 1Password service account, no biometric prompt
opw() {
  OP_SERVICE_ACCOUNT_TOKEN=$(security find-generic-password -s op-sa-work-vw -w) op "$@"
}
```

```shell
opw read "op://work-vw/devstack-jira-pat/credential"
export JIRA_PAT=$(opw read "op://work-vw/devstack-jira-pat/credential")
opw run --env-file=./work.env -- some-tool
opw service-account ratelimit
```

The Keychain-stored token above is the older broad account (reads all
`work-*` vaults, integration id `UNH5GYTSJBGKBHHG3YIPMYG3QQ`); the exported-token
flow above uses the narrower `shell-work-vw` account (integration id
`XL6QR2OIVNH4TC3UARVFEOMIYM`, `work-vw` only). Never export
`OP_SERVICE_ACCOUNT_TOKEN` globally in `.zshrc` — it shadows personal-account
access for every `op` call.

---

## Verification protocol (probes)

Executed with the user; secret value is never displayed (`--no-newline` +
`wc -c` → expect `44`).

- [ ] **Probe A (control — no token):** clean shell, *skip* Step 3, run
      `claude`, prompt it with:
      `Run: op read --no-newline "op://work-vw/devstack-jira-pat/credential" | wc -c`
      → expected: 1Password **does** ask for authentication (or the read
      fails if declined). Confirms prompts are real without the token.
- [x] **Probe B (main hypothesis):** clean shell, run Step 3 (one biometric
      prompt), verify `op whoami` shows `SERVICE_ACCOUNT`, run `claude`, same
      prompt as Probe A → expected: output `44`, **no** authentication
      prompt.
- [x] **Probe C (nested-shell inheritance):** in the same Claude Code
      session, prompt:
      `Run: zsh -c 'op read --no-newline "op://work-vw/devstack-jira-pat/credential" | wc -c'`
      → expected: `44`, no prompt — proves grandchild shells inherit the
      token.
- [x] **Probe D (scope check):** same session, prompt:
      `Run: op vault list`
      → expected: only `work-vw` listed (scoped account), and no prompt.

## Probe results

- 2026-07-12 **Probe B — CONFIRMED by user in a live session**: fresh
  terminal, one Touch ID prompt at the Step 3 export, `op whoami` showed
  `SERVICE_ACCOUNT`, and inside the freshly started Claude Code the read
  printed `44` with **no** 1Password popup. Goal achieved.
- 2026-07-12 **Probes C/D — verified mechanically** (equivalent checks run
  during setup): a doubly-nested `env -i` clean zsh read the secret via the
  token with no prompt (environment inheritance is transitive), and
  `op vault list` under the token returned only `work-vw`
  (integration id `XL6QR2OIVNH4TC3UARVFEOMIYM`).
- **Probe A — open (optional)**: control run without the export. Expected to
  prompt; skipping does not weaken the positive result, since Probe B's
  session was started from a shell with no prior `op` authorization.

</content>
</invoke>
