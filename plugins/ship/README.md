# ship

Take a **green** change out the door: feature branch → rebase onto the latest
base → `/code-review` → push → PR → watch to green. Delivery only — it does
**not** define or run your project's checks. Those live once in
`docs/verification.md` and are run by the [`feedback-loops`](../feedback-loops/)
plugin's `green-loop`. Ship calls that loop; it never re-implements it.

> **Single source of truth.** `feedback-loops` answers *"is it correct?"* (checks
> in `docs/verification.md`, run by `green-loop`). `ship` answers *"is it
> delivered?"* (branch, rebase, review, push, PR, watch). No check command is
> duplicated across the two.

## What it does

| Piece | Kind | Does |
|---|---|---|
| `ship` | skill (`/ship`) | verify green (delegates to `green-loop`) → feature branch → rebase (**re-run Layer 1 when the base moved**) → `/code-review` → push → open PR → watch to green |
| `ship-gate` | Stop hook | opt-in, fail-open gate that refuses "done" while delivery is incomplete — **no lint/tests, delivery state only** |

## The rebase → re-verify rule

After rebasing onto the latest base, if the base moved (or you resolved a
conflict), the earlier green is stale — `ship` re-runs Layer 1 via `green-loop`
before continuing. Code proven green against the old base is not proven green
against the new one.

## Closing review threads

Pushing the fix isn't enough. For each review comment `ship` addresses, it
*replies on the thread* with what changed and **marks the thread resolved**, so
the review loop is visibly closed — the commit closes the code, the reply +
resolved thread closes the conversation. Delivery isn't done while a thread is
left silently open.

## The gate

The `Stop` hook (`hooks/ship-gate.sh`) enforces the delivery half
deterministically. It checks, in order:

1. working tree clean (tracked files; untracked-only is fine)
2. not stranded on a protected branch (`main`/`master`/`develop`/`release/*`)
3. branch pushed with an upstream, nothing unpushed
4. PR checks green *(needs `gh`)*
5. PR not conflicted *(needs `gh`)*
6. a review requested *(needs `gh`)*

It runs **no** lint, tests, typecheck, or build — that is `feedback-loops`'
job, and duplicating it here would create a second source of truth.

### Fail-open by design

- **Opt-in:** does nothing unless `.claude/ship.config.json` exists.
- Missing `jq` *and* `python3` → allows (a `python3` fallback covers the no-`jq`
  case).
- No `gh` / `gh` not authenticated → the GitHub-dependent checks are skipped
  (a pushed branch is allowed to stop).
- Detached HEAD, not a git repo, unreadable state → allows.
- Gives up after `gate.max_blocks` **consecutive** blocks, so a genuinely stuck
  delivery never traps the session.

### Config — `.claude/ship.config.json`

```json
{
  "gate": {
    "enabled": true,
    "max_blocks": 3
  }
}
```

| Key | Default | Meaning |
|---|---|---|
| `gate.enabled` | `true` | `false` disables the gate without deleting the file. |
| `gate.max_blocks` | `3` | Consecutive blocks before the gate gives up and fails open. |

The gate is invoked as `bash "${CLAUDE_PLUGIN_ROOT}/hooks/ship-gate.sh"`, so a
missing execute bit on the script does not matter.

## Install

```bash
claude plugin marketplace add ddalgrande/claude-plugins
claude plugin install ship@ddalgrande-plugins
```

Pairs with `feedback-loops`:

```bash
claude plugin install feedback-loops@ddalgrande-plugins
```

> **Migrating from `ship@ship-tools`?** Uninstall the old plugin first
> (`claude plugin uninstall ship@ship-tools`) — otherwise both register a `Stop`
> hook and the gate runs twice. The config schema also changed: the old
> `gates`/`paths` keys are gone; only `gate.enabled` and `gate.max_blocks`
> remain.

## Principles

- **Delivery, not quality.** Never re-runs the checks; delegates to `green-loop`.
- **Fail open.** A delivery gate that blocks on its own missing dependencies is
  worse than no gate.
- **Rebase then re-verify.** A moved base invalidates the old green.
