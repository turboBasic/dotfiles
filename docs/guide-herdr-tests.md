# Herdr test pilot

Herdr keeps test panes alive across client disconnects; existing `just test-ubuntu` and
`just test-macos` recipes still run the tests. The pilot snapshots tracked inputs, launches
both platforms in separate panes, and reports their results. It does not edit code, retry
tests, or recover from host sleep, reboot or runtime failure.

## Prerequisites

- macOS with Herdr installed and its runtime started (`herdr` attaches; `Ctrl+B`, then `Q`
  detaches). Herdr is optional and is not installed during bootstrap.
- Docker running, plus the stopped macOS base VM configured by
  [README-macos.md](../tests/README-macos.md).
- 1Password CLI signed in through the desktop app. Test panes resolve credentials from
  1Password references at runtime; secrets are not copied into the snapshot or pilot logs.

## Run

```sh
just pilot-prepare
just pilot-launch /absolute/path/printed/by/prepare
just pilot-report /absolute/path/printed/by/prepare
```

Review `manifest.json` before launch. It records the selected tracked files, base commit,
content fingerprint and expected assertions. Tracked worktree changes are included;
untracked, ignored and deleted files are not. To include an intentional untracked input,
pass `--include relative/path` to `pilot-prepare`. Do not edit the snapshot while tests run.

The launcher prints pane IDs. Disconnect the client while tests are running, then reattach
to verify persistence; closing panes or stopping the runtime is not a disconnect test.

## Safety and results

Run artifacts are under ignored `tmp/herdr-tests/`. Raw logs may contain account identities
or authentication diagnostics: review and redact them before sharing. Give an analyst the
structured report and reviewed excerpts, not unrestricted log or credential access.

The report omits raw log bodies and passes only when both platform processes and all expected
assertions completed successfully and the inputs remained unchanged. Missing or duplicate
assertions, missing completion records, changed inputs or any failed assertion cannot pass.
An interrupted run without a completion record remains unknown; preserve it and prepare a
new run rather than altering its markers.

The pilot permits one Docker and one macOS run concurrently, but not overlapping runs for
the same platform. Direct test invocations do not use the pilot's locks; do not run them
concurrently with the pilot.

Run `just test-pilot` for isolated artifact and result-classification checks.
