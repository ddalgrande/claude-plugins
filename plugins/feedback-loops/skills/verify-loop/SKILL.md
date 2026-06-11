---
name: verify-loop
description: Use after editing code and before declaring a task done, or when the user asks to "verify", "run the feedback loop", "is it green", "self-verify", or "make sure it actually works". Runs the project's recorded checks, fixes failures, and re-runs until everything is green — then reports honestly. Reads .claude/feedback-loop.md (runs setup-feedback-loop first if it is missing).
---

# Verify Loop

Execute the project's feedback loop: run each check, observe, fix failures, re-run until green. This is the loop that lets you finish ambitious work without the user babysitting every step.

## 0. Load the loop definition
- Read `.claude/feedback-loop.md`.
- **Missing?** Invoke the `setup-feedback-loop` skill once to create it, then continue. (If the user wants a quick one-off and won't persist anything, detect the obvious checks ad hoc — typecheck, lint, test — and run those instead.)

## 1. Define success criteria first
State, in one line, what "done" means for *this* change before running anything — e.g. "all Layer 1 checks pass and the new endpoint returns 200 with the expected body." Weak criteria ("make it work") make the loop unverifiable; concrete criteria let it run independently.

## 2. The loop — Layer 1 (internal checks)
Run checks in the recorded order (fast → slow: typecheck → lint → test → build). For each:

```
run check
 ├─ pass → next check
 └─ fail → read the actual error → form a hypothesis → make the smallest fix
           → re-run THAT check → continue the loop
```

Loop discipline:
- **Re-run after every fix.** A fix isn't done until its check is green.
- **Read real output.** Quote the actual error to yourself; don't pattern-match a guess.
- **Bound the retries.** If the same check fails ~3 times with no progress, stop looping. Summarize what you tried, the current error, and ask the user — that's a real `needs input:`, not a failure to grind harder.
- **Don't move the goalposts.** Never weaken a check, skip a failing test, add `|| true`, or mark a box done to make the loop pass. A green loop you faked is worse than a red one you reported.

## 3. Layer 2 — end-to-end (feature changes)
Unit tests passing ≠ the feature works. If the change is user-facing, run the recorded real-app leg and **observe actual behavior** — seeing it work, not inferring it from tests. Follow the concrete recipes in `references/e2e-recipes.md` (relative to this skill):
- **Backend** → boot the service, hit the changed endpoint (happy + error + auth paths), assert status/body, and grep the logs — a 200 with a stack trace is still a bug.
- **Web UI** → start the dev server, drive the flow with Playwright (or chrome-devtools MCP), screenshot key states, and assert zero console errors / no failed network requests — not just that pixels look right.
- **Video / glitch capture** → for animated or visually sensitive changes, record the flow (Playwright `recordVideo`, chrome-devtools performance trace, or mobile-mcp screen recording) and **review the recording** for jank, flicker, layout shift, and broken transitions that a static screenshot can't show. Never claim "no glitches" off a recording you didn't actually inspect.

Use whichever MCP/tool the environment has (preference order in the recipes file); save artifacts to a temp dir, not the repo. If a leg can't run here (no device, external dependency), say so explicitly and list what the user must verify manually — don't silently claim it works.

## 4. Layer 3 — pre-merge review (before PR/merge)
When the change is headed for a PR or merge, get a **second pair of eyes from a separate agent**: run `/code-review` (or `/review`). A fresh-context reviewer catches what the author-context agent rationalized past. Address findings, then re-run Layer 1.

## 5. Report
End with a tight status the user can trust:
- ✅ each check that passed (with the command), so it's auditable.
- ⚠️ anything skipped and why (e.g. "e2e: no simulator in this env — verify manually").
- The success criteria from step 1, marked met / not met.

State results plainly. If something failed, say so with the output. Only write a completion headline once the loop is actually green against the criteria you set.

## Composition
- Pair with `setup-feedback-loop` (defines the loop) — this skill (runs it).
- For unattended/background runs, this loop is the safety rail: it keeps working until green or until it hits a real blocker worth surfacing.
