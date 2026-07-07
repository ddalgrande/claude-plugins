# claude-plugins

Daniele Dal Grande's Claude Code plugin marketplace.

## Plugins

| Plugin | Does |
|---|---|
| [feedback-loops](plugins/feedback-loops/) | Encode your verification processes as skills so Claude Code self-verifies and finishes ambitious tasks with less babysitting. Skills: `setup-feedback-loop` (once per project — detects the stack, writes `docs/verification.md`), `green-loop` (every change — runs the recorded checks until green). Based on Anthropic's [_Feedback loops_](https://www.anthropic.com/engineering) post. |

## Install

```bash
claude plugin marketplace add ddalgrande/claude-plugins
claude plugin install feedback-loops@ddalgrande-plugins
```

Or from a local clone:

```bash
claude plugin marketplace add /path/to/claude-plugins
claude plugin install feedback-loops@ddalgrande-plugins
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
