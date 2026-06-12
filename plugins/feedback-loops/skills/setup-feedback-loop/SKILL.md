---
name: setup-feedback-loop
description: Use when a project has no documented self-verification process, or the user asks to "set up a feedback loop", "make Claude self-verify", "what checks should I run here", "encode verification as a skill", or before starting ambitious multi-step work in an unfamiliar repo. Auto-detects the stack and writes a reusable .claude/feedback-loop.md that the verify-loop skill runs after every change.
---

# Setup Feedback Loop

Run **once per project**. Goal: discover the checks that prove a change is correct, and record them so every future change can be self-verified without the user babysitting.

> The more Claude can self-verify, the more independently it works on long-running tasks, the higher the final quality, and the fewer back-and-forths it takes. This skill writes down the verification process; `verify-loop` executes it.

## When NOT to use
- `.claude/feedback-loop.md` already exists and is accurate → skip straight to `verify-loop`.
- The user only wants a one-off check right now → use `verify-loop` directly.

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
Unit tests alone don't prove a feature works. Record how to drive the **running** app for the kind of change this project ships (the `verify-loop` skill's `references/e2e-recipes.md` has concrete, MCP-agnostic recipes for each):
- **Web UI** → start dev server, then drive it (Playwright / chrome-devtools MCP, or the project's e2e command). Note the URL/port. For animated or visually sensitive UI, note that the flow should be **video-recorded** and reviewed for jank/flicker/layout-shift.
- **Backend/service** → start command + a representative request (curl/httpie) on happy + error paths, or the integration-test command. Note where logs go (check them for stack traces).
- **CLI** → the invocation that exercises the changed path.
- **Mobile** → simulator boot + launch command (screen-record the flow for visual changes).

### 4. Confirm, then write the loop file
Briefly show the user the detected checks and ask only if something is ambiguous (cheap confirmation beats a wrong loop). Then write `.claude/feedback-loop.md` using this template:

```markdown
# Feedback loop

Checks the agent runs to self-verify a change. Ordered fast → slow.
Run via the `verify-loop` skill. Keep in sync with CI.

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

### 5. Make it always-on (CLAUDE.md pointer)
A skill only fires when its description matches the moment; a CLAUDE.md line is read every turn. So the loop is more reliable as an always-on instruction than as something that depends on `verify-loop` triggering. Add a short pointer to the project's agent instructions file — `CLAUDE.md` (or `AGENTS.md` if that's what the repo uses), in the root or the relevant package:

```markdown
## Verification
Before declaring any change done, run the feedback loop in
`.claude/feedback-loop.md` — Layer 1 must pass; run the matching
Layer 2 leg for feature changes. Don't report done off Layer 1 alone.
```

Rules:
- **Don't duplicate.** If CLAUDE.md/AGENTS.md already has a verification section, add a one-line pointer to `.claude/feedback-loop.md` there instead of a second section — or skip it if the existing guidance already covers the loop.
- **Respect repo git rules.** If the project forbids direct edits to its default branch (check CLAUDE.md), make this change on a branch + PR, not in place.
- Keep the pointer to ~3 lines — the detail lives in `feedback-loop.md`, not CLAUDE.md.

### 6. Hand off
Tell the user it's recorded, the CLAUDE.md pointer is in place, and that `verify-loop` (or just the CLAUDE.md instruction) will run it. Suggest committing `.claude/feedback-loop.md` and the pointer so future sessions and teammates inherit the same contract.

## Principles
- **Honest over complete** — only record checks that actually run.
- **Match CI** — the loop should mirror what merge gates on.
- **Surgical** — write the one file; don't reconfigure the project.
