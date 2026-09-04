# VS Code profiles: folder naming, name lookup, and settings resolution

Findings from reverse-engineering VS Code's profile system while building the
`profiles/` import tooling under `home/private_Library/private_Application Support/Code/User/`.
Source references are line-for-line from the installed app's bundled source
(`/Applications/Visual Studio Code.app/Contents/Resources/app/out/vs/workbench/workbench.desktop.main.js`),
confirmed against this machine's actual `~/Library/Application Support/Code/User/` state.

## Folder names (`profiles/451b20d1`, `profiles/-548e617c`, …) are opaque hashes

A profile's folder name is **not** derived from its display name, icon, or creation
order. It's the hex encoding of a hash of a random id generated once at profile
creation:

```js
// creating a profile:
this.createProfile(Wr(st()).toString(16), name, ...)   // st() = generateUuid()

// the hash itself — a djb2-style string hash forced to a signed 32-bit int:
function zQ(s, o) { return (o << 5) - o + s | 0 }
```

The `| 0` truncates to a **signed** 32-bit integer, and JavaScript's
`Number.prototype.toString(16)` on a negative number prints a literal `-` followed by
the hex digits of the magnitude (not two's-complement hex). A signed 32-bit hash is
roughly 50/50 positive/negative, which is why folders like `-548e617c`, `-5b384f0`,
`-158228ab`, `-48dfce3f`, `-46c02fca` start with `-` while others
(`451b20d1`, `7ba910e7`, `73029c16`, `6ff9ea05`, `2223344d`) don't. It's arbitrary —
carries no meaning beyond "which half of the hash space this profile's random id
landed in."

**Consequence:** renaming a profile in VS Code never changes its folder. The folder
is permanent from creation; only the display name can change.

## The name lives in one place: `globalStorage/storage.json`

`~/Library/Application Support/Code/User/globalStorage/storage.json`, key
`userDataProfiles`, is an array of
`{location, name, icon?, useDefaultFlags?}`. `location` is the folder name above.
This is the **only** file mapping folder → human name — nothing under
`profiles/<location>/` itself records the profile's own name.

```json
{"location": "-548e617c", "name": "Java", "icon": "coffee",
 "useDefaultFlags": {"settings": true, "keybindings": true}}
```

A `location` of `builtin/agents` is VS Code's own built-in "Agents" profile, not
user data — skip it when enumerating profiles.

## `useDefaultFlags` controls which file a profile actually reads — per resource type

This is the part most easily gotten wrong: a profile's own `settings.json` existing
on disk does **not** mean VS Code reads it. Confirmed directly in source
(`workbench.desktop.main.js`, profile resource resolution):

```js
settingsResource: n && i?.useDefaultFlags?.settings
  ? n.settingsResource            // n = the Default profile
  : We(e, "settings.json"),       // e = this profile's own folder
keybindingsResource: n && i?.useDefaultFlags?.keybindings ? n.keybindingsResource : We(e, "keybindings.json"),
snippetsHome:        n && i?.useDefaultFlags?.snippets    ? n.snippetsHome        : We(e, "snippets"),
// ...same pattern for tasks, prompts, extensions, mcp, languageModels
```

For each resource type independently:

- **`useDefaultFlags.<type>: true`** → this profile has **no** file of its own for
  that resource. VS Code reads/writes the Default profile's file directly (the root
  `~/Library/Application Support/Code/User/<type>`). Whatever exists at
  `profiles/<location>/<type>` is **not consulted at all**.
- **absent / `false`** → this profile owns `profiles/<location>/<type>` as the
  complete resource for that type. The root file is not consulted; a key missing
  from the profile's file falls back to VS Code's built-in default, not to root.

This is **exclusive file selection, not merging** — never "root settings.json,
overridden by profile settings.json." Exactly one file is read for a given
(profile, resource type) pair.

### Confirmed on this machine (2026-09-04)

| Profile | `useDefaultFlags.settings` | Effective `settings.json` |
| --- | --- | --- |
| ai-infra (`6ff9ea05`), 00-common (`-48dfce3f`), Terraform (`73029c16`), Shell (`7ba910e7`), tb-shared-repos (`2223344d`), Java (`-548e617c`) | `true` | root `Code/User/settings.json` — their own `profiles/<location>/settings.json` is **not read** |
| Go (`-5b384f0`), Python (`-158228ab`), Node.js (`451b20d1`), VW.ADMT (`-46c02fca`) | absent | their own `profiles/<location>/settings.json` |

Six of the ten non-builtin profiles are currently reading the root settings file, not
their own. `6ff9ea05`'s own file still carries real content (font, theme, terminal
settings) and a stale comment ("Visual settings copied from the Default profile") —
almost certainly a leftover from before the profile was switched to "use Default
profile settings" in the VS Code UI, which flips the flag without deleting the old
file. Treat any chezmoi-tracked `profiles/<location>/settings.json` as **potentially
inert**: check `useDefaultFlags.settings` for that `location` before assuming the
file reflects what's actually active.

## Where this sits in the wider settings precedence

Outside this profile-vs-root question, normal VS Code precedence still applies as a
real per-key override chain: **Default (built-in) → Policy → User (the file resolved
above) → Remote → Workspace → Workspace Folder.** One exception: settings marked
`scope: "application"` in VS Code's contribution schema (e.g. `update.mode`,
telemetry, workspace-trust) always read from the Default profile's `settings.json`
regardless of active profile or its `useDefaultFlags`, and are greyed out in the
Settings UI unless the Default profile is active.

## For future tooling

Before writing or trusting a chezmoi-managed `profiles/<location>/settings.json`,
cross-check `globalStorage/storage.json` → `userDataProfiles[].useDefaultFlags.settings`
for that `location`. If `true`, that profile's real settings live in the root
`Code/User/settings.json` — either skip importing the profile-local file, or clearly
annotate the header comment so a reader doesn't mistake it for the active config. See
the import script's own plan for how this is applied:
`tmp/plans/vscode-import-profiles.plan.md` (scratch, not committed).
