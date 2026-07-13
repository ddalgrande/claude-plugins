---
name: ship
description: Use to take a finished, green change out the door — when the user says "ship it", "ship this", "open a PR", "get this merged", "deliver this", or asks you to finish delivery. Runs the delivery loop — verify green → feature branch → rebase onto the latest base (re-running Layer 1 when the base moved) → /code-review → push → open the PR → watch it to green. Delivery only; it does NOT define or run the project's checks (that is feedback-loops' green-loop, reading docs/verification.md).
---

# Ship

Take a change that is already **green** and deliver it: onto a feature branch,
rebased on the latest base, reviewed, pushed, and up as a PR that stays watched
until it is mergeable. This skill owns **delivery**. It does **not** own code
quality — the checks live once in `docs/verification.md` and are run by the
`feedback-loops` plugin's `green-loop` skill. Ship *calls* that loop; it never
re-defines lint/test/build commands of its own.

> Split, so there is a single source of truth:
> **feedback-loops** = "is it correct?" (checks in `docs/verification.md`, run by `green-loop`).
> **ship** = "is it delivered?" (branch, rebase, review, push, PR, watch).

## The delivery loop

### 1. Verify green (delegate — do not re-implement)
Delivery starts only from a green tree. Run the `green-loop` skill
(`feedback-loops@ddalgrande-plugins`) to execute Layer 1 (and Layer 2 for
feature changes) from `docs/verification.md`. Do not hardcode or duplicate the
check commands here — if `green-loop` reports red, stop and fix; you are not
shipping a red change.

### 2. Get onto a feature branch
Delivery never happens as a direct commit to a protected branch (`main`,
`master`, `develop`, `release/*`).
- On a protected branch with un-shipped commits → create a feature branch
  (`git switch -c <type>/<slug>`) so those commits move with you, or cherry-pick
  them over. Never push work straight to a protected branch.
- Already on a feature branch → continue.

### 3. Rebase onto the latest base — and re-verify if the base moved
Fetch and rebase onto the current base branch so the PR is not stale:

```
git fetch origin
git rebase origin/<base>        # e.g. origin/main
```

**If the rebase pulled in new base commits (the base moved) or you resolved any
conflict, the earlier green is stale — re-run Layer 1 via `green-loop` before
continuing.** Code that was green against the old base is not proven green
against the new one. A clean rebase that fast-forwards nothing new does not need
a re-run. On conflicts, resolve them, `git rebase --continue`, then re-verify.

### 4. Pre-merge review (separate agent)
Run `/code-review` (Layer 3) for a fresh-context second pair of eyes before the
change goes up. Address findings, and if you changed code in response, loop back
to step 1 (re-verify) — a review fix is a change like any other.

### 5. Push
```
git push -u origin <branch>
```

### 6. Open the PR
Open a PR into the base branch. Use the repo's PR template if one exists
(`.github/pull_request_template.md` and the usual locations); fill its sections
from the actual diff. Write a body that states what changed and how it was
verified. Do not open a PR unless delivery is the user's intent (they asked to
ship / open a PR).

### 7. Watch to green
After the PR is up, keep an eye on CI and reviews until it is mergeable
(subscribe to PR activity if the environment supports it). A red or conflicted
PR is not delivered. On CI failure: re-diagnose, fix (via `green-loop`), push,
let CI re-run. On merge conflict: rebase (step 3, which re-triggers re-verify),
push.

## The Stop-hook gate (optional, opt-in)
This plugin also ships a `Stop` hook (`hooks/ship-gate.sh`) that enforces the
*delivery* half deterministically: it refuses to let the session declare done
while the tree is dirty, work is stranded on a protected branch, the branch is
unpushed, or (when `gh` is available) the PR is red, conflicted, or unreviewed.

- **Opt-in:** it does nothing unless `.claude/ship.config.json` exists in the repo.
- **Delivery only:** it runs **no** lint/tests/build — it never duplicates
  `green-loop`. It only inspects git/PR state.
- **Fails open:** missing config, no `jq`/`python3`, no `gh`, or detached HEAD →
  it allows the stop. It also gives up after `gate.max_blocks` consecutive
  blocks so a genuinely stuck delivery never traps the session.

Minimal config:

```json
{ "gate": { "enabled": true, "max_blocks": 3 } }
```

Set `"enabled": false` to turn it off without deleting the file.

## Report
End with the delivery state the user can trust: branch, base it was rebased on,
whether a re-verify ran (and why), review outcome, push status, and the PR URL +
its CI state. Say plainly if anything is still red or needs manual follow-up.

## Composition
- **feedback-loops → ship.** After `green-loop` reports green, hand off to
  `/ship`. `green-loop` proves correctness; `ship` delivers it. The two never
  duplicate each other's job.
