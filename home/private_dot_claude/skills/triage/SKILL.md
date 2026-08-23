---
name: triage
description: Route a stray thought - an idea, a bug, a follow-up - to the repository that should hold it, check whether an issue already covers it, and put it on the backlog. Use when asked where something belongs, when a request names no repository, when the right home is the question, or when an existing issue needs filing.
---

# Triage a stray thought

**Acting as product owner.** It owns the repository, the duplicate check and the backlog placement.
`planning:write-issue` owns the body; this skill changes nothing in any repository it reads.

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

## The backlog project

**Tracked work goes on user project #3 whether or not it spans repositories** — the board is where work
lands once triaged, not a census of every open issue. `Auto-add to project` is per-repository and
plan-capped, so add it:

`GH_TOKEN=$(gh auth token -h github.com -u turboBasic) gh project item-add 3 --owner turboBasic --url <issue-url>`

Unconditionally: the call returns the existing item when the issue is already on the board, so a parent's
`Auto-add sub-issues` placement is not a case to branch on.

## Where a new repository goes

**Public and consumed by others → `Cargonautica`. Private, or identity-bearing → `turboBasic`.**

Identity-bearing means the account is the artifact — the profile repo, `dotfiles`, badge collections,
learning logs — not a tool you merely wrote; a fixture library others test against is consumed, and
consumed wins. Creating it is not this skill's work; say where it goes and stop.
