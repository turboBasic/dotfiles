---
name: cross-repo
description: Route a stray thought - an idea, a bug, a follow-up - to the repository that should hold it, then check whether an issue already covers it. Use when asked where something belongs, when a request names no repository, or when the right home is the question.
---

# Route a stray thought to the right repository

**Acting as product owner.** It owns which repository holds a deliverable and whether that deliverable is
already tracked. It does not write the issue body — `planning:write-issue` owns that — and it changes
nothing in any repository it reads.

## The catalogue

**Every command that runs on its own carries the token inline.** Shell state does not persist between
invocations, so an `export` in one block reaches nothing in the next. Never `gh auth switch`: it mutates
global state that work repos depend on.

```bash
export GH_TOKEN=$(gh auth token -h github.com -u turboBasic)
[ "$(gh api /user --jq .login)" = turboBasic ] || echo 'WRONG ACCOUNT — every answer below is wrong'
JQ='.[]|[.name,.pushedAt[0:10],(.primaryLanguage.name//"-"),([(.repositoryTopics//[])[].name]|join(",")),(.description//"-")]|@tsv'
for o in turboBasic Cargonautica; do
  gh repo list "$o" --no-archived --source -L 200 \
    --json name,pushedAt,primaryLanguage,repositoryTopics,description --jq "$JQ"
done
```

**A wrong token is silent, never an error** — under a work account the private repos are simply absent,
which is why the login is asserted rather than eyeballed. `--source --no-archived` drop forks and archived
repos, neither of which can take an issue.

## Routing

1. **Rank on name, description, topics and language,** in that order of weight. A name that already
   states the concern outranks a description that merely touches it.
2. **Prefer a repository pushed since 2025, without foreclosing an older one.** An old repository that
   owns the concern beats a live one that only neighbours it.
3. **Where nothing fits, say nothing fits.** The nearest repository is not the right one, and a new
   repository is the answer often enough to be worth proposing — see the last section.

**Report the choice and the runner-up, one line each with its reason** — never the choice alone; where the
runner-up is weak, say it is weak.

## Whether it already exists

**Search is lexical only,** and relevance is weak enough to bury an exact match under a loose one.

1. **Two or three term variants, never one** — the concern's noun, the tool's name, the symptom.
2. **Both owners, `--state open` first, then `--state closed`.** `gh search issues` rejects
   `--state all`.

   ```bash
   GH_TOKEN=$(gh auth token -h github.com -u turboBasic) \
     gh search issues --owner turboBasic --owner Cargonautica "<terms>" --state open --limit 20 \
     --json repository,number,title --jq '.[]|[.repository.nameWithOwner,(.number|tostring),.title]|@tsv'
   ```

3. **Read every hit; do not trust the order.** A duplicate found here means editing that issue and
   commenting what changed, not opening a second one.

**Confirm the repository out loud and wait for the answer before anything is written.** Then
`planning:write-issue` owns the body, the labels and the relationships.

## Labels

`GH_TOKEN=$(gh auth token -h github.com -u turboBasic) gh label list -R <owner>/<repo>` on the chosen
repository, and pick only from what is there. No label is created from this skill.

## The cross-repo project

Work spanning more than one repository belongs in user project #3, and the one automated route in is its
`Auto-add sub-issues` workflow.

- **A parent already tracked in #3** → wire the new issue as that parent's sub-issue and the workflow
  places it.
- **No such parent** → say plainly that the issue is in no project. Never `gh project item-add`.

## Where a new repository goes

**Public and consumed by others → `Cargonautica`. Private, or identity-bearing → `turboBasic`.**

Identity-bearing means the account is the artifact — the profile repo, `dotfiles`, badge collections,
learning logs — not a tool you merely wrote; a fixture library others test against is consumed, and
consumed wins. Creating it is not this skill's work; say where it goes and stop.
