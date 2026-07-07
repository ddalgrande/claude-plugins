# feedback-loops-plugin

Claude Code plugin marketplace with a single plugin: **feedback-loops** — encode your verification processes as skills so Claude Code self-verifies and finishes ambitious tasks with less babysitting.

Based on Anthropic's [_Feedback loops: Help Claude Code complete ambitious tasks with less babysitting_](https://www.anthropic.com/engineering).

## Skills

| Skill | Run | Does |
|---|---|---|
| `setup-feedback-loop` | once per project | Auto-detects the stack, finds the real verify commands (matching CI), writes a reusable `docs/verification.md`, and adds a prose pointer to it in `CLAUDE.md`/`AGENTS.md`. |
| `green-loop` | every change, before "done" | Runs the recorded checks, fixes failures, re-runs until green, then reports honestly. |

## Install

```bash
claude plugin marketplace add ddalgrande/feedback-loops-plugin
claude plugin install feedback-loops@feedback-loops
```

Or from a local clone:

```bash
claude plugin marketplace add /path/to/feedback-loops-plugin
claude plugin install feedback-loops@feedback-loops
```

See [plugins/feedback-loops/README.md](plugins/feedback-loops/README.md) for full plugin docs.

## Repository layout

```
.claude-plugin/marketplace.json   # marketplace manifest
plugins/feedback-loops/           # the plugin
├── .claude-plugin/plugin.json    # plugin manifest
├── README.md
└── skills/
    ├── setup-feedback-loop/SKILL.md
    └── green-loop/
        ├── SKILL.md
        └── references/e2e-recipes.md
```

## License

MIT
