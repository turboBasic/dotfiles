# Herdr test pilot

Herdr owns persistent terminals; the existing `just test-ubuntu` and `just test-macos`
recipes still own test execution. The pilot creates two test panes and a third shell
for a read-only analyst. It does not install Herdr, start an AI agent, retry tests,
edit code, or provide recovery from host sleep, reboot, or runtime crashes.

## Prerequisites

- [Herdr](https://herdr.dev/) is an optional macOS Homebrew formula recorded under
  `packages.darwin.manual.formulae`, installed on demand by `install-heavy-packages`
  (or individually with `brew install herdr`), not during bootstrap. Its managed config
  is
  `~/.config/herdr/config.toml`: login Zsh panes inherit their working directory,
  notifications stay inside Herdr, and sounds are disabled. Homebrew owns binary
  updates (`brew upgrade herdr`); Herdr's background version check is disabled.
  Runtime state, logs, and sockets are not managed by chezmoi.
- Run `herdr` in your terminal to start or attach to its persistent runtime. Detach
  with `Ctrl+B`, release, then `Q`; run `herdr` again to reattach. No login service
  or automatic test launch is installed.
- Docker must be running. UTM needs the stopped macOS base VM described in
  [README-macos.md](../tests/README-macos.md).
- Sign in to 1Password CLI using the 1Password app integration. Both test panes resolve
  `AGE_PASSPHRASE` from `op://chezmoi/chezmoi/age-passphrase`. The macOS test also
  resolves `RBW_EMAIL`, `RBW_PASSWORD`, and `RBW_TOTP_SEED` from the `com.bitwarden`
  item using a private reference-only env file and `op run`. It does not unlock or
  query the local `rbw` vault. Secret values are available only in each runner
  process's environment and are not written to the snapshot or pilot logs.

## Prepare and launch

```sh
just pilot-prepare
# Use the absolute run directory printed by prepare:
just pilot-launch /absolute/path/to/tmp/herdr-tests/run-...
```

Preparation copies tracked files as they currently exist, including tracked worktree
changes, but excludes deleted files, submodule contents, and untracked/ignored files.
Tracked symlinks are preserved as links, never followed to copy host files.
Include an intentional untracked input explicitly with
`just pilot-prepare --include relative/path`. Review `manifest.json` before launching:
it lists the selected files, base commit, content fingerprint, and expected assertions.
Both platforms use this same snapshot; do not edit it during execution.

Artifacts live under ignored `tmp/herdr-tests/`, outside the snapshot. Run directories
are private and artifact files use a restrictive umask. The launcher's `age.env` and
`op.env` contain only 1Password references and are mode 0600. Raw logs can contain
account identities or authentication diagnostics: do not send them to an agent or
external service without reviewing and redacting them first.

The launcher prints the test pane IDs and the analyst shell ID. Use Herdr's workspace
UI to view the workspace, disconnect your client while both tests are running, and
reattach to the same runtime. This is the persistence check; pane creation alone does
not prove it. Closing the test panes or stopping the runtime is not a disconnect test.

## Results and diagnosis

```sh
just pilot-report /absolute/path/to/tmp/herdr-tests/run-...
```

The report prints no raw log bodies. Each platform has its own log, start marker,
and completion record. It reports process status, expected assertion count, observed
successes/failures, completeness, input integrity, and assertion log-line references.
Its exit status is zero only when both platforms passed.

- A completed nonzero process or any failed assertion is a failure.
- Missing completion, missing/duplicate assertion results, or changed inputs cannot pass.
- A nonzero process with incomplete assertions may indicate bootstrap/infrastructure
  failure; it does not establish a root cause.

The third pane is deliberately an ordinary shell. Start your preferred agent there
only after deciding what evidence is safe to share. Give it the structured report
and reviewed/redacted excerpts, not unrestricted access to raw logs or credentials.
Require a report separating observations from hypotheses, citing platform, test name,
and log line. Do not authorize edits, retries, secret access, or additional cleanup.

An interrupted run remains unknown if no completion record was written. Preserve it
and prepare a new run rather than deleting start markers to force a retry. There is
no overall test deadline or automatic cancellation in this pilot.

## Isolation limits

Docker uses an unnamed disposable container with its own home. The repository bind
mount is read-only, the checkout is copied into the container before installation, and
test-only credentials configure rbw's non-interactive pinentry inside the container.
The image includes CA certificates for verified HTTPS downloads. macOS clones a
disposable VM. These are different guest environments, not competing installs into
the host home.

The macOS test checks for passwordless SSH to the stopped base VM before cloning. Fix
the host key setup described in [README-macos.md](../tests/README-macos.md) if that
preflight fails.

The pilot locks each platform across its own runs on this host. It permits one Docker
run alongside one macOS run, but not two runs of the same platform. Direct invocations
outside the pilot do not honor those locks: do not start those concurrently. macOS
still uses a fixed VM name and hostname; the Docker image tag is also shared.

The legacy recipes also write `docker.log`/`macos.log` at the snapshot root. These
two generated files alone are excluded from fingerprint checks. Authoritative pilot
logs are the separate platform logs beside `manifest.json`.

The pilot succeeds only when reattachment recovers both outcomes and the analyst can
distinguish assertion failure, incomplete execution, and suspected infrastructure
failure using preserved evidence. Run `just test-pilot` for isolated artifact checks.
