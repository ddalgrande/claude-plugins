# claude-plugins

Daniele Dal Grande's Claude Code plugin marketplace.

## Plugins

| Plugin | Owns | Does |
|---|---|---|
| [feedback-loops](plugins/feedback-loops/) | **Code quality** ("is it correct?") | Encode your verification process as skills so Claude Code self-verifies. Skills: `setup-feedback-loop` (once per project — detects the stack, writes `docs/verification.md`), `green-loop` (every change — runs the recorded checks until green). Based on Anthropic's [_Feedback loops_](https://www.anthropic.com/engineering) post. |
| [ship](plugins/ship/) | **Delivery** ("is it delivered?") | Take a green change out the door. Skill: `ship` (`/ship`) — verify → feature branch → rebase → `/code-review` → push → PR → watch. Plus an opt-in, fail-open `Stop`-hook gate that refuses "done" while delivery is incomplete. |

## The split — one source of truth for checks

The two plugins are deliberately separate, with **no duplicated check commands**:

- **feedback-loops owns code quality.** The verification checks are defined
  **once** in the project's `docs/verification.md` and run by `green-loop`
  (run → observe → fix until green).
- **ship owns delivery only.** `/ship` takes an *already-green* change through
  feature branch → rebase onto the latest base → `/code-review` → push → PR →
  watch. It **delegates** the actual checks back to `green-loop`; it never
  re-implements lint/test/build commands.
- **The `ship-gate` Stop hook checks delivery state only** — tree clean → not on
  a protected branch → pushed → PR green → not conflicted → review requested —
  and runs **no** lint/tests. It **fails open** (missing config / `jq` /
  `python3` / `gh` → allow) and is **opt-in** via `.claude/ship.config.json`.

```
green-loop  →  (green)  →  /ship  →  branch → rebase → review → push → PR → watch
   ▲                                    │
   └──── re-run Layer 1 if the ─────────┘
         rebase moved the base
```

The **rebase → re-verify** rule: when the rebase pulls in new base commits (or
you resolve a conflict), the old green is stale, so `/ship` re-runs Layer 1 via
`green-loop` before continuing.

## Install

```bash
claude plugin marketplace add ddalgrande/claude-plugins
claude plugin install feedback-loops@ddalgrande-plugins
claude plugin install ship@ddalgrande-plugins
```

Or from a local clone:

```bash
claude plugin marketplace add /path/to/claude-plugins
claude plugin install feedback-loops@ddalgrande-plugins
claude plugin install ship@ddalgrande-plugins
```

> **Migrating from `ship@ship-tools`?** Uninstall it first
> (`claude plugin uninstall ship@ship-tools`) — otherwise both plugins register
> a `Stop` hook and the gate runs twice. The config schema also changed: the old
> `gates`/`paths` keys are removed; the gate now reads only `gate.enabled` and
> `gate.max_blocks` from `.claude/ship.config.json`.

See each plugin's README for full docs:
[feedback-loops](plugins/feedback-loops/README.md) ·
[ship](plugins/ship/README.md).

## Repository layout

```
.claude-plugin/marketplace.json       # marketplace manifest (lists both plugins)
plugins/feedback-loops/               # code-quality plugin
├── .claude-plugin/plugin.json
├── README.md
└── skills/
    ├── setup-feedback-loop/SKILL.md
    └── green-loop/
        ├── SKILL.md
        └── references/e2e-recipes.md
plugins/ship/                         # delivery plugin
├── .claude-plugin/plugin.json
├── README.md
├── skills/ship/SKILL.md
└── hooks/
    ├── hooks.json                    # registers the Stop-hook gate
    └── ship-gate.sh                  # delivery-state gate (fail-open, opt-in)
```

## License

MIT
