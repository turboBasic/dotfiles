# VS Code profiles

This guide records the profile behavior the importer must account for. Profile metadata is in
`globalStorage/storage.json`; profile files and extension installation are managed separately.
See [ARCHITECTURE.md](ARCHITECTURE.md#vs-code-extension-installation-run_onchange_02-install-vscode-extensionsshtmpl)
for this repository's generated files and apply behavior.

## Profile identity

`userDataProfiles[]` entries map opaque `location` folder names to display `name`s. The folder
name is generated from a random ID at profile creation; renaming a profile does not change it.
The built-in `location: "builtin/agents"` is not a user profile.

Use `./vscode-import-profiles --list` to inspect the live name, location and settings inheritance
for this machine. Do not infer a profile's display name from its folder.

## Settings inheritance

For each resource type, `useDefaultFlags.<type>` determines which file VS Code uses:

- `true`: the profile uses the Default profile's resource directly. Its own file, if present,
  is inert and is not merged with the Default file.
- `false` or absent: the profile uses its own resource. Missing keys fall back to VS Code's
  built-in defaults, not the Default profile's file.

This applies independently to settings, keybindings, snippets, tasks, prompts, extensions,
MCP and language models. Application-scoped settings always come from the Default profile.
Beyond profile selection, normal precedence is built-in defaults → policy → user → remote →
workspace → workspace folder.

Before editing or trusting a profile-local `settings.json`, check
`userDataProfiles[].useDefaultFlags.settings` for its location. The VS Code UI can leave an
old profile file in place after switching to Default settings, so a plausible-looking file
may not be active.

Use `./vscode-import-profiles` rather than hand-editing generated profile copies.
