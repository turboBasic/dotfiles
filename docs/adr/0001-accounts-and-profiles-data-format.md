# 0001. Accounts and profiles data format

- Status: Accepted
- Date: 2026-06-27
- Deciders: turboBasic (owner)

## Context

Identity data lives in `accounts.json`, decrypted into `~/.config/chezmoi/` and embedded into
`chezmoi.toml` `[data]` as `accounts` and `aliases` during `chezmoi init`. Templates (per-account
gitconfigs, default `[user]`, remote overrides) read it.

The current format is a direct mirror of Bitwarden custom fields. Each value is wrapped as
`{ "name", "value", "type" }`, and nested data is smuggled in as JSON-encoded strings:

```json
"git_remote_override": { "name": "git_remote_override",
  "value": "{\"github.com/turboBasic/**\": \"10-personal\"}", "type": "text" }
```

This has three concrete problems:

1. **Noise.** Every scalar carries a redundant `name`/`type` wrapper; templates dig three levels
   (`dig "alias" "value" …`) to reach one string. Nested objects must be `fromJson`-decoded inside
   templates.
2. **Secrets are modeled ad hoc.** `accounts.mercedes-benz*` inline a full SSL cert + private key,
   and scatter `bw_*_item_name` pointers to Bitwarden items. There is no single secret-reference
   convention.
3. **Profiles are not linked to accounts.** `profile` is a free string in `chezmoi.toml`
   (`personal` / `work.2025.05`) chosen via `promptChoiceOnce`, but nothing maps it to accounts.
   The default git identity is hardcoded to `accounts.personal` (`private_config.tmpl:113`)
   regardless of the active profile — so switching profiles does not switch the default account.

`accounts.vw` already deviates toward the desired shape: a clean nested `data` block with
`op://` 1Password secret references instead of the flat Bitwarden wrappers. This ADR ratifies
that direction as the target format and defines the profile→accounts link.

[[0002-authentication-1password]] governs how `op://` references resolve in practice. Key findings
that constrain this schema:

- The desktop integration prompts whenever there is no interactive user session — automated and
  non-interactive use requires `OP_SERVICE_ACCOUNT_TOKEN` instead.
- The SA cannot access the `Personal` vault (hard 1Password limit); `op://Personal/…` references
  always require the desktop app.
- Therefore `secretsInline` exists for values the SA cannot reach and that cannot be moved to a
  service-account-readable vault.

See [[0002-authentication-1password]] for full rationale.

## Decision

Adopt a **versioned, nested schema** with native types, `op://` references for all secrets, and
**first-class profiles** that select accounts.

```json
{
  "version": 2,
  "accounts": {
    "personal": {
      "id": "848e104f-…",
      "alias": "10-personal",
      "email": "andrii7melnyk@proton.me",
      "username": "turboBasic",
      "gitName": "turboBasic ⚡️💀",
      "gitRemoteOverrides": {
        "github.com/turboBasic/**": "10-personal"
      },
      "secrets": {},
      "data": {}
    },
    "vw": {
      "id": "6ae95030-…",
      "alias": "60-vergnügte-wanze",
      "email": "andrii.melnyk@dxc.com",
      "gitName": "Andrii Melnyk 🪐",
      "gitRemoteOverrides": {
        "github.com/vw-admt/**": "60-vergnügte-wanze",
        "github.com/moia-dev/**": "60-vergnügte-wanze"
      },
      "secrets": {
        "jiraPat": "op://work-vw/devstack-jira-pat/credential",
        "confluencePat": "op://work-vw/devstack-confluence-pat/credential"
      },
      "secretsInline": {},
      "data": {
        "jira": { "baseUrl": "https://devstack.vwgroup.com/jira" },
        "confluence": { "baseUrl": "https://devstack.vwgroup.com/confluence" }
      }
    }
  },
  "profiles": {
    "personal": {
      "defaultAccount": "personal",
      "accounts": ["personal"]
    },
    "work.2025.05": {
      "defaultAccount": "dxc",
      "accounts": ["dxc", "luxoft", "mercedes-benz", "mercedes-benz-china",
                   "mercedes-benz-civic", "daimler-truck", "vw"]
    },
    "work.2026": {
      "defaultAccount": "dxc",
      "accounts": ["dxc", "luxoft", "moia", "vw"]
    }
  }
}
```

Rules:

- **Native types, no wrappers.** Scalars are stored directly. Maps (`gitRemoteOverrides`, `data`)
  are real JSON objects, never JSON-encoded strings. The Bitwarden `{name,value,type}` shape is an
  export-time concern and MUST NOT appear in the stored format.
- **Account keys drop the `accounts.` prefix.** Keys live under the `accounts` map; the prefix is
  redundant.
- **`alias` is the privacy-preserving public identifier.** It is an opaque `NN-slug` (numeric
  prefix + random German words, e.g. `20-leuchtender-xenoceratops`) used wherever an account must
  be referenced in non-encrypted contexts: gitconfig filenames in the repo, `gitRemoteOverrides`
  values, and `hasconfig:remote.*.url` include paths in the rendered config. Company names never
  appear in repo-visible files — they exist only in the age-encrypted `accounts.json.age` and in
  locally-rendered files on disk. The numeric prefix controls gitconfig include precedence.
- **Secrets prefer `op://` references; inline is the documented exception.** The `secrets` block
  holds named `op://vault/item/field` references, resolved at use time (1Password CLI/MCP). The
  Bitwarden `bw_*_item_name` pointer convention is dropped. However, per [[0002-authentication-1password]],
  a pure-reference rule is not achievable:
  - **References must target a service-account-readable vault** (`chezmoi` or a `work-*` vault).
    `op://Personal/…` requires the desktop app and always prompts in automated contexts — move such
    items into `chezmoi` vault before referencing them. See [[0002-authentication-1password]].
  - **`secretsInline` holds values the SA cannot reach at all** and that cannot be moved to a
    service-account-readable vault (e.g. the SSL cert/key on `accounts.mercedes-benz*`). Acceptable
    because the file is age-encrypted via `.secrets/` (on-disk key, prompt-free). Keep empty
    whenever a reference works; every entry is a deliberate exception.

  See [[0002-authentication-1password]] for the service-account model and the global-token landmines.
- **Profiles select accounts.** A profile declares `defaultAccount` (drives the default `[user]`
  identity, replacing the hardcoded `accounts.personal`) and `accounts` (the set active under that
  profile). `chezmoi.toml` continues to store the chosen profile name; templates resolve identity
  through `profiles[<profile>].defaultAccount`.
- **`version` is mandatory.** Bump on any breaking schema change; consumers branch on it.

## Considered Options

- **A — Keep the Bitwarden-mirror flat format (status quo).** Zero migration, but locks in the
  three problems above and offers no secret or profile model. Rejected.
- **B — Clean nested schema + `op://` refs (with inline exception) + first-class profiles (chosen).**
  One coherent shape, matches the `accounts.vw` direction, fixes the profile link. References target
  service-account-readable vaults; a `secretsInline` escape hatch covers values the SA cannot reach
  (see [[0002-authentication-1password]]). Cost: a migration and an export-time transform in
  `bw-export-accounts`.
- **C — Split accounts and profiles into separate files.** Cleaner separation, but doubles the
  decrypt/embed plumbing in `.chezmoi.toml.tmpl` for little gain at this scale. Rejected; revisit if
  profiles grow independent lifecycles.
- **D — Pure `op://` references, no inline secrets.** Cleanest in principle, but rejected:
  [[0002-authentication-1password]] proves the service account cannot read `Personal` and some material
  must be present without a live 1Password call, so a no-inline rule is unimplementable.

## Consequences

- **+** Templates read native values (`account.alias` vs `dig "alias" "value" …`); no in-template
  `fromJson`.
- **+** One primary secret convention (`op://`) with a single, explicit exception (`secretsInline`);
  the ad-hoc `bw_*_item_name` pointers are gone.
- **+** Switching profiles switches the default identity and active account set — the link is real,
  not implied.
- **+** `version` gives a clean migration seam for future ADRs.
- **−** `bw-export-accounts` must transform Bitwarden fields into this schema (wrapper-stripping,
  `op://` mapping, and routing references to a service-account-readable vault move into the exporter).
- **−** A one-time migration of existing `accounts.json` and any template that digs the old shape
  (`private_config.tmpl`, gitconfig templates). Tracked separately; this ADR defines the target, not
  the migration steps.
- **−** Non-interactive `op://` resolution requires the SA token; references must target
  SA-readable vaults (`chezmoi`/`work-*`). `Personal` items must be copied to `chezmoi` vault.
  `secretsInline` values need manual sync with their 1Password source.
  See [[0002-authentication-1password]].
- **−** `secretsInline` keeps secret material in the (age-encrypted) account file; it is a deliberate
  escape hatch, not the norm, and must stay empty wherever a reference works.
