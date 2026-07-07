---
name: setup-feedback-loop
description: Use when a project has no documented self-verification process, or the user asks to "set up a feedback loop", "make Claude self-verify", "what checks should I run here", "encode verification as a skill", or before starting ambitious multi-step work in an unfamiliar repo. Auto-detects the stack and writes a reusable docs/verification.md (referenced from CLAUDE.md) that the green-loop skill runs after every change.
---

# Setup Feedback Loop

Run **once per project**. Goal: discover the checks that prove a change is correct, and record them so every future change can be self-verified without the user babysitting.

> The more Claude can self-verify, the more independently it works on long-running tasks, the higher the final quality, and the fewer back-and-forths it takes. This skill writes down the verification process; `green-loop` executes it.

## When NOT to use
- `docs/verification.md` already exists and is accurate → skip straight to `green-loop`.
- The user only wants a one-off check right now → use `green-loop` directly.

## Scope — what this skill does and does NOT do
This skill writes exactly **two** things: `docs/verification.md` and a short
prose pointer in `CLAUDE.md` (or `AGENTS.md`). That is the whole job.

It MUST NOT, as part of setup:
- add or edit **hooks**, or touch `.claude/settings.json`
- install a **Stop-hook gate** (`green-loop-gate.sh` or any enforcement hook)
- create a per-project skill — the `green-loop` skill already exists in this
  plugin and is the runner; setup only writes the contract it reads

**Optional, separate opt-in — an enforcement hook.** A Stop-hook that runs
Layer 1 and blocks "done" until green is a heavier, deliberate choice
(deterministic enforcement layered on top of the advisory skill). Offer it
**only if the user explicitly asks** for unskippable enforcement, and add it as
its own clearly-flagged step — never bundle it into setup. The default setup is
**skill + `docs/verification.md`, no hook.**

If the user does want enforcement, **prefer a maintained gate plugin over a
hand-rolled hook.** A tested, config-driven Stop-hook (e.g. `ship@ship-tools`'s
`ship-gate` — fails open, reads per-repo config, no hardcoded paths) beats a
bespoke script every time: point its quality/test gate commands at this repo's
`docs/verification.md` Layer 1, and let its web/e2e verifier cover Layer 2.
Authoring the contract (this skill) and enforcing it (the plugin) stay separate
layers — don't hand-roll a Stop hook when a tested one already exists.

## Where this lives (and why)
The verification checklist is a **human-readable doc at `docs/verification.md`**, referenced from `CLAUDE.md` by a short prose pointer — not a bespoke `.claude/` file (Claude Code doesn't auto-load arbitrary `.claude/*.md`) and not a `@import` (imports load into context every session; a verification checklist only needs to load when a change is being verified). This matches the standard "lean CLAUDE.md → `docs/` for detail" pattern. If the repo keeps agent docs elsewhere (e.g. `agent_docs/`, or a path-scoped `.claude/rules/testing.md`), follow that convention instead. **Default to `docs/verification.md`** — do not drop it loose in `.claude/` (less discoverable, doesn't render on GitHub) unless the repo clearly keeps its agent docs there.

## Procedure

### 1. Detect the stack
Look for these signals in the project root (check the actual files; don't guess). Use the project's lockfile to pick the right package manager.

| Signal file | Stack | Typecheck | Lint/format | Test | Build | Dev / smoke |
|---|---|---|---|---|---|---|
| `package.json` + `pnpm-lock.yaml` | Node (pnpm) | `pnpm typecheck` or `pnpm tsc --noEmit` | `pnpm lint` | `pnpm test` | `pnpm build` | `pnpm dev` |
| `package.json` + `yarn.lock` | Node (yarn) | `yarn tsc --noEmit` | `yarn lint` | `yarn test` | `yarn build` | `yarn dev` |
| `package.json` + `bun.lockb` | Node (bun) | `bun x tsc --noEmit` | `bun run lint` | `bun test` | `bun run build` | `bun dev` |
| `package.json` (npm) | Node (npm) | `npm run typecheck` / `npx tsc --noEmit` | `npm run lint` | `npm test` | `npm run build` | `npm run dev` |
| `pyproject.toml` + `uv.lock` | Python (uv) | `uv run mypy .` / `uv run pyright` | `uv run ruff check .` | `uv run pytest -q` | — | `uv run <app>` |
| `pyproject.toml` / `requirements.txt` | Python | `mypy .` / `pyright` | `ruff check .` | `pytest -q` | — | start the service |
| `Cargo.toml` | Rust | `cargo check` | `cargo clippy` | `cargo test` | `cargo build` | `cargo run` |
| `go.mod` | Go | `go vet ./...` | `gofmt -l .` | `go test ./...` | `go build ./...` | `go run .` |
| `Makefile` | any | — | `make lint` | `make test` | `make build` | `make run` |

Always read `package.json` `"scripts"` / `pyproject.toml` `[tool]` sections to use the **project's real script names** — prefer those over the generic guesses above. Also note any CI config (`.github/workflows/*.yml`) and copy the exact commands CI runs; matching CI is the highest-value loop.

### 2. Probe what actually exists
Don't trust the table — verify each candidate command resolves before recording it (e.g. the script exists in `package.json`, the tool is installed). Drop checks that aren't real. A loop full of failing-because-missing commands is worse than a short honest one.

### 3. Identify the real-app leg (highest-signal check)
Unit tests alone don't prove a feature works. Record how to drive the **running** app for the kind of change this project ships (the `green-loop` skill's `references/e2e-recipes.md` has concrete, MCP-agnostic recipes for each):
- **Web UI** → start dev server, then drive it (Playwright / chrome-devtools MCP, or the project's e2e command). Note the URL/port. For animated or visually sensitive UI, note that the flow should be **video-recorded** and reviewed for jank/flicker/layout-shift.
- **Backend/service** → start command + a representative request (curl/httpie) on happy + error paths, or the integration-test command. Note where logs go (check them for stack traces).
- **CLI** → the invocation that exercises the changed path.
- **Mobile** → simulator boot + launch command (screen-record the flow for visual changes).

### 4. Confirm, then write the doc
Briefly show the user the detected checks and ask only if something is ambiguous (cheap confirmation beats a wrong loop). Create `docs/` if it doesn't exist, then write `docs/verification.md` using this template:

```markdown
# Verification

Checks to self-verify a change before declaring it done. Ordered fast → slow.
Run via the `green-loop` skill. Keep in sync with CI.

## Layer 1 — internal checks (every change)
- [ ] typecheck: `<command>`
- [ ] lint:      `<command>`
- [ ] test:      `<command>`
- [ ] build:     `<command>`

## Layer 2 — end-to-end (feature changes)
- start: `<command>`  (URL/port: <...>)
- exercise: <how to drive the real app and what to observe>
- logs: <where service logs go — check for stack traces>
- record: <video/trace for visually sensitive UI — review for jank/flicker/layout-shift; omit if N/A>

## Layer 3 — pre-merge review (before PR/merge)
- separate-agent review: `/code-review` (or `/review`)

## Success criteria
Done = every Layer 1 check passes AND the Layer 2 leg shows the intended
behavior in the real app. Never report done off Layer 1 alone.
```

### 5. Reference it from CLAUDE.md (prose pointer)
So Claude finds the doc, add a short **prose pointer** to the project's agent instructions file — `CLAUDE.md` (or `AGENTS.md` if that's what the repo uses). Use a prose pointer, not `@docs/verification.md` — an `@import` would load the whole checklist into context every session, whereas a pointer lets Claude read the doc on demand when verifying:

```markdown
## Verification
Before declaring any change done, verify against `docs/verification.md`
— Layer 1 checks must pass; run the matching Layer 2 leg for feature
changes. Never silently ship "I think this works".
```

Rules:
- **Don't duplicate.** If CLAUDE.md/AGENTS.md already has a verification section, fold its content into `docs/verification.md` and replace the section with the pointer — don't leave two copies. This also trims CLAUDE.md (target < 200 lines).
- **Respect repo git rules.** If the project forbids direct edits to its default branch (check CLAUDE.md), make these changes on a branch + PR, not in place.
- Keep the pointer to ~3 lines — the detail lives in `docs/verification.md`, not CLAUDE.md.

### 6. Hand off
Tell the user it's recorded, the CLAUDE.md pointer is in place, and that `green-loop` (or just the CLAUDE.md instruction) will run it. Suggest committing `docs/verification.md` and the pointer so future sessions and teammates inherit the same contract.

## Principles
- **Honest over complete** — only record checks that actually run.
- **Match CI** — the loop should mirror what merge gates on.
- **Surgical** — write `docs/verification.md` + the pointer; nothing else. Do **not** add hooks, edit `.claude/settings.json`, or install a Stop-hook gate (see *Scope*). Enforcement hooks are a separate, explicit opt-in.
