---
name: analyze-docker-log
description: Analyze docker.log from the latest test-docker.sh run. Filters apt-get noise, Homebrew download progress, and other verbose output to surface only meaningful results (errors, test outcomes, chezmoi execution steps).
---

Analyze `docker.log` in the project root. This file is overwritten on every `test-docker.sh` run — always read it fresh, never rely on cached content.

## Steps

1. Run a filtered extraction of meaningful lines, excluding noise:

```bash
perl -ne '
  next if /^\s*$/;
  next if /^\s*#/;
  next if /^\s+[a-z0-9][\w.-]+\s*$/;
  next if /^\s*(Get|Hit):\d+/;
  next if /^\s*(Inst|Conf) /;
  next if /^\s*(Setting up|Preparing to unpack|Unpacking|Selecting previously)/;
  next if /^\d+%\s*\[/;
  next if /^==> (Downloading|Pouring|Installing)/;
  next if /^Fetched \d/;
  next if /^The following (NEW|additional|packages)/;
  next if /^Total \d/;
  next if /^remote:/;
  next if /After this operation/;
  next if /Already on/;
  next if /Building dependency tree/;
  next if /(Receiving|Resolving|Enumerating|Counting|Compressing) objects/;
  next if /Reading package lists/;
  next if /Reading state information/;
  next if /Need to get/;
  next if /Pouring /;
  next if /Processing triggers/;
  next if /Suggested packages:/;
  next if /Updating files/;
  next if /created directory/;
  next if /download progress/;
  next if /dpkg-preconfigure/;
  next if /update-alternatives:/;
  print;
' docker.log | head -200
```

2. Separately extract test results:

```bash
grep -E "^(SUCCESS|FAILURE)" docker.log
```

3. Extract errors and warnings (excluding benign apt/alternatives warnings):

```bash
perl -ne '
  next if /update-alternatives: warning/;
  next if /warning.*skip creation/;
  print if /error|fail|unable to|❌|warning/i;
' docker.log
```

## Reporting

- Lead with a summary: how many tests passed/failed.
- List any FAILURE tests with their script paths.
- List any real errors (not benign warnings like the initial `rbw config show` failure or Homebrew PATH warning on fresh install).
- Only show relevant context lines if needed to explain a failure.

## Noise patterns to always filter

These produce hundreds of lines that waste context and obscure real issues:

- `Setting up <package> ...`
- `Preparing to unpack ./<package>.deb ...`
- `Unpacking <package> ...`
- `Reading package lists... N%`
- `Building dependency tree... N%`
- `Reading state information... N%`
- `Processing triggers for ...`
- `Get:N http://... <package> [size]`
- `Hit:N http://...`
- `Fetched N MB in Ns`
- `N% [Working]`, `N% [Waiting for headers]`, download progress bars
- `The following NEW packages will be installed:`
- `The following additional packages will be installed:`
- `Suggested packages:`
- Package list lines (indented package names)
- `update-alternatives: warning: skip creation of ...`
- `Selecting previously unselected package ...`
- `dpkg-preconfigure: ...`
- Homebrew download/pour progress (`###...`, `Pouring ...`, `Downloading ...`)
- Git clone progress (`remote:`, `Receiving objects`, `Resolving deltas`, `Enumerating objects`)
- Blank lines and lines that are only whitespace

$ARGUMENTS
