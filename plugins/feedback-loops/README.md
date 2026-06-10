# feedback-loops

Encode your verification processes as skills so Claude Code **self-verifies** and finishes ambitious tasks with less babysitting.

Based on Anthropic's [_Feedback loops: Help Claude Code complete ambitious tasks with less babysitting_](https://www.anthropic.com/engineering). Core idea: the more Claude can self-verify, the more independently it works, the higher the quality, and the fewer back-and-forths it takes.

## Skills

| Skill | Run | Does |
|---|---|---|
| `setup-feedback-loop` | once per project | Auto-detects the stack, finds the real verify commands (matching CI), and writes a reusable `.claude/feedback-loop.md`. |
| `verify-loop` | every change, before "done" | Runs the recorded checks, fixes failures, re-runs until green, then reports honestly. |

Both trigger automatically from context, or invoke by name.

## The loop

```
setup-feedback-loop  →  .claude/feedback-loop.md  →  verify-loop (run→observe→fix→repeat until green)
```

Three layers of verification:
1. **Internal checks** — typecheck, lint, test, build (fast, every change).
2. **End-to-end** — drive the running app and observe real behavior (feature changes).
3. **Pre-merge review** — a separate agent (`/code-review`) before PR/merge.

`.claude/feedback-loop.md` is committable, so every future session and teammate inherits the same verification contract.

## Install

```bash
claude plugin marketplace add ~/.claude/feedback-loops-plugin
claude plugin install feedback-loops@feedback-loops
```

## Principles

- **Honest over complete** — only records checks that actually run; never fakes a green.
- **Match CI** — the loop mirrors what merge gates on.
- **Surgical** — writes one file; doesn't reconfigure your project.
