# feedback-loops

Encode your verification processes as skills so Claude Code **self-verifies** and finishes ambitious tasks with less babysitting.

Based on Anthropic's [_Feedback loops: Help Claude Code complete ambitious tasks with less babysitting_](https://www.anthropic.com/engineering). Core idea: the more Claude can self-verify, the more independently it works, the higher the quality, and the fewer back-and-forths it takes.

## Skills

| Skill | Run | Does |
|---|---|---|
| `setup-feedback-loop` | once per project | Auto-detects the stack, finds the real verify commands (matching CI), writes a reusable `docs/verification.md`, and adds a prose pointer to it in `CLAUDE.md`/`AGENTS.md`. |
| `green-loop` | every change, before "done" | Runs the recorded checks, fixes failures, re-runs until green, then reports honestly. |

Both trigger automatically from context, or invoke by name.

## The loop

```
setup-feedback-loop  →  docs/verification.md  →  green-loop (run→observe→fix→repeat until green)
```

Three layers of verification:
1. **Internal checks** — typecheck, lint, test, build (fast, every change).
2. **End-to-end** — drive the running app and observe real behavior (feature changes).
3. **Pre-merge review** — a separate agent (`/code-review`) before PR/merge.

`docs/verification.md` is a human-readable, committable doc (referenced from `CLAUDE.md` by a prose pointer, not a context-heavy `@import`), so every future session and teammate inherits the same verification contract — and it renders on GitHub.

## Install

```bash
claude plugin marketplace add ddalgrande/feedback-loops-plugin
claude plugin install feedback-loops@feedback-loops
```

## Principles

- **Honest over complete** — only records checks that actually run; never fakes a green.
- **Match CI** — the loop mirrors what merge gates on.
- **Surgical** — writes one file; doesn't reconfigure your project.
