# Read `work-vw` secrets in a Claude Code session

Export a read-only, vault-scoped 1Password service-account token before starting Claude Code.
The process and its child shells inherit the token, so `op` reads from `work-vw` without
repeated desktop authentication. The token is available to every process launched from that
shell; use this only for work you trust.

The rationale for using a scoped service account rather than the desktop integration is in
[ADR 0002](adr/0002-authentication-1password.md).

## Create and store the token (once)

Create a read-only service account limited to `work-vw`:

```sh
op service-account create shell-work-vw --expires-in 90d --vault work-vw:read_items
```

The token is shown once. Store it as a concealed field on the existing token item in the
Personal vault, then clear the shell variable:

```sh
tok=$(op service-account create shell-work-vw --expires-in 90d --vault work-vw:read_items --raw)
op item edit rbcvlawhbstklfig7ziwhju734 "work-vw-service-account[concealed]=$tok"
unset tok
```

The item title contains `@`, so reference it by ID.

## Start a session

In the shell where Claude Code will run:

```sh
export OP_SERVICE_ACCOUNT_TOKEN=$(op read "op://Personal/rbcvlawhbstklfig7ziwhju734/work-vw-service-account")
op whoami
claude
```

Confirm `op whoami` identifies a service account. Within Claude Code, child shells can read
the allowed vault:

```sh
op read "op://work-vw/devstack-jira-pat/credential"
op run --env-file=./work.env -- some-tool
```

Unset the variable or close the shell to restore normal personal-account behavior:

```sh
unset OP_SERVICE_ACCOUNT_TOKEN
```

## Limits

- The service account can access only `work-vw`; other vaults are unavailable while its
  token is exported.
- Do not export the token globally in `.zshrc`; that would override personal-account
  access for every `op` invocation.
- Rotate or revoke the token in 1Password Developer settings when it expires or is no
  longer needed.
