# RTK — Rust Token Killer

A Claude Code hook rewrites dev commands through `rtk` transparently — `git status` becomes
`rtk git status` — so never prefix a command with `rtk` by hand.

Three commands the hook cannot reach, to run directly:

- `rtk gain [--history]` — token savings, optionally per command
- `rtk discover` — scan Claude Code history for missed opportunities
- `rtk proxy <cmd>` — run a command unfiltered, to debug the hook
