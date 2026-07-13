#!/usr/bin/env bash
#
# ship-gate — Stop hook for the `ship` plugin.
#
# Checks DELIVERY STATE ONLY. It never runs lint, tests, typecheck or build —
# that is the feedback-loops plugin's job (green-loop, driven by
# docs/verification.md). This gate answers a different question: "is the work
# actually delivered?" — tree clean → not stranded on a protected branch →
# pushed → PR green → not conflicted → review requested.
#
# FAIL OPEN. Anything uncertain (no config, no JSON reader, no gh, detached
# HEAD, unreadable state) exits 0 and lets Claude stop. A delivery gate that
# blocks on its own missing dependencies is worse than no gate.
#
# OPT-IN. Does nothing unless the repo contains .claude/ship.config.json.
#
# Config keys (all optional):
#   gate.enabled     (bool, default true)  — false disables the gate entirely.
#   gate.max_blocks  (int,  default 3)     — after this many CONSECUTIVE blocks,
#                                            give up and fail open, so a genuinely
#                                            stuck delivery never traps the session.
#
# Invoked as:  bash "${CLAUDE_PLUGIN_ROOT}/hooks/ship-gate.sh"
# (so a missing execute bit does not matter).

set -u

# --- must be inside a git work tree; otherwise there is nothing to deliver ---
repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$repo_root" 2>/dev/null || exit 0

config="$repo_root/.claude/ship.config.json"

# --- OPT-IN: no config file => gate is off ---
[ -f "$config" ] || exit 0

# --- need a JSON reader; prefer jq, fall back to python3; neither => fail open ---
JQ=$(command -v jq 2>/dev/null || true)
PY=$(command -v python3 2>/dev/null || true)
if [ -z "$JQ" ] && [ -z "$PY" ]; then
  exit 0
fi

# Read a dotted key from a JSON *file*. Prints the value, or the default when
# the key is absent/null. Booleans normalise to lowercase true/false.
json_file_get() {
  local file="$1" path="$2" default="$3" val=""
  if [ -n "$JQ" ]; then
    # getpath + explicit null check: never use `// empty`, which would also
    # swallow a literal `false` (jq treats false as a fallback trigger).
    val=$("$JQ" -r --arg p "$path" \
      'try (getpath($p | split("."))) catch null | if . == null then "" else . end' \
      "$file" 2>/dev/null)
  else
    val=$("$PY" - "$file" "$path" <<'PYEOF' 2>/dev/null
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
cur = d
for k in sys.argv[2].split("."):
    cur = cur.get(k) if isinstance(cur, dict) else None
    if cur is None:
        break
if cur is None:
    print("")
elif isinstance(cur, bool):
    print("true" if cur else "false")
elif isinstance(cur, (dict, list)):
    print(json.dumps(cur))
else:
    print(cur)
PYEOF
)
  fi
  if [ -z "$val" ]; then
    printf '%s' "$default"
  else
    printf '%s' "$val"
  fi
}

# Extract a dotted key from a JSON string on stdin (used for `gh` output).
json_stdin_get() {
  local path="$1"
  if [ -n "$JQ" ]; then
    "$JQ" -r --arg p "$path" \
      'try (getpath($p | split("."))) catch null | if . == null then "" else . end' \
      2>/dev/null
  else
    "$PY" - "$path" <<'PYEOF' 2>/dev/null
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
cur = d
for k in sys.argv[1].split("."):
    cur = cur.get(k) if isinstance(cur, dict) else None
    if cur is None:
        break
if cur is None:
    print("")
elif isinstance(cur, bool):
    print("true" if cur else "false")
elif isinstance(cur, (dict, list)):
    print(json.dumps(cur))
else:
    print(cur)
PYEOF
  fi
}

# JSON-encode an arbitrary string (for the block reason).
json_string() {
  if [ -n "$JQ" ]; then
    printf '%s' "$1" | "$JQ" -Rs .
  else
    printf '%s' "$1" | "$PY" -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
  fi
}

# --- config-driven kill switches ---
enabled=$(json_file_get "$config" "gate.enabled" "true")
[ "$enabled" = "false" ] && exit 0

max_blocks=$(json_file_get "$config" "gate.max_blocks" "3")
case "$max_blocks" in
  ''|*[!0-9]*) max_blocks=3 ;;
esac

# --- consecutive-block counter (per git dir) ---
git_dir=$(git rev-parse --git-dir 2>/dev/null) || exit 0
state="$git_dir/ship-gate.blocks"

count=0
if [ -f "$state" ]; then
  count=$(cat "$state" 2>/dev/null)
  case "$count" in
    ''|*[!0-9]*) count=0 ;;
  esac
fi

# Allow the stop: reset the counter and exit 0.
allow() {
  rm -f "$state" 2>/dev/null || true
  exit 0
}

# Block the stop: bump the counter and hand Claude a reason to keep going.
block() {
  count=$((count + 1))
  printf '%s' "$count" > "$state" 2>/dev/null || true
  printf '{"decision":"block","reason":%s}\n' "$(json_string "$1")"
  exit 0
}

# Give up (fail open) once we have blocked max_blocks times in a row.
if [ "$count" -ge "$max_blocks" ]; then
  allow
fi

# =========================================================================
# Delivery-state checks (fast, local first; GitHub-dependent ones last and
# only when gh is usable). NO lint / tests / build here — by design.
# =========================================================================

# 1. Working tree clean (tracked files only — untracked-only is fine to stop on).
if [ -n "$(git status --porcelain --untracked-files=no 2>/dev/null)" ]; then
  block "ship-gate: uncommitted changes to tracked files. Commit or stash them before finishing (delivery is not done with a dirty tree)."
fi

# Current branch (detached HEAD => nothing to deliver => fail open).
branch=$(git symbolic-ref --short HEAD 2>/dev/null) || allow
[ -n "$branch" ] || allow

# Upstream + how far ahead of it we are.
upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
ahead=0
if [ -n "$upstream" ]; then
  ahead=$(git rev-list --count "$upstream"..HEAD 2>/dev/null || echo 0)
  case "$ahead" in ''|*[!0-9]*) ahead=0 ;; esac
fi

# 2. Not stranded on a protected branch.
is_protected=false
case "$branch" in
  main|master|develop|release|release/*) is_protected=true ;;
esac

if $is_protected; then
  # Clean + in sync with upstream => nothing to ship => let it stop.
  if [ -z "$upstream" ] || [ "$ahead" -eq 0 ]; then
    allow
  fi
  # Local commits on a protected branch that were never pushed: the work was
  # committed to the wrong place. Move it to a feature branch.
  block "ship-gate: $ahead unpushed commit(s) on protected branch '$branch'. Delivery goes through a feature branch + PR, not a direct commit to '$branch' — create a branch and open a PR (/ship does this)."
fi

# 3. Pushed: feature branch must have an upstream and no unpushed commits.
if [ -z "$upstream" ]; then
  block "ship-gate: branch '$branch' has no upstream and is not pushed. Push it (git push -u origin '$branch') before finishing (/ship does this)."
fi
if [ "$ahead" -gt 0 ]; then
  block "ship-gate: $ahead commit(s) on '$branch' not yet pushed to $upstream. Push before finishing (/ship does this)."
fi

# ---- GitHub-dependent checks. No usable gh => fail open (already pushed). ----
GH=$(command -v gh 2>/dev/null || true)
[ -z "$GH" ] && allow
"$GH" auth status >/dev/null 2>&1 || allow

pr=$("$GH" pr view --json state,mergeStateStatus,reviewRequests,reviewDecision,statusCheckRollup 2>/dev/null || true)
if [ -z "$pr" ]; then
  block "ship-gate: no pull request found for '$branch'. Open one before finishing (/ship does this)."
fi

pr_state=$(printf '%s' "$pr" | json_stdin_get "state")
# Merged/closed => delivery finished => stop is fine.
case "$pr_state" in
  MERGED|CLOSED) allow ;;
esac

# 4. PR green: no failing/pending required checks.
if [ -n "$JQ" ]; then
  failing=$(printf '%s' "$pr" | "$JQ" -r \
    '[.statusCheckRollup[]? | select((.conclusion // .state // "") | test("FAILURE|ERROR|CANCELLED|TIMED_OUT"; "i"))] | length' 2>/dev/null)
  pending=$(printf '%s' "$pr" | "$JQ" -r \
    '[.statusCheckRollup[]? | select((.status // .state // "") | test("QUEUED|IN_PROGRESS|PENDING|WAITING"; "i"))] | length' 2>/dev/null)
  case "$failing" in ''|*[!0-9]*) failing=0 ;; esac
  case "$pending" in ''|*[!0-9]*) pending=0 ;; esac
  if [ "$failing" -gt 0 ]; then
    block "ship-gate: PR for '$branch' has $failing failing check(s). Fix them (feedback-loops green-loop), push, and let CI re-run before finishing."
  fi
  if [ "$pending" -gt 0 ]; then
    block "ship-gate: PR for '$branch' still has $pending check(s) running. Wait for CI to finish (green) before finishing."
  fi
fi

# 5. Not conflicted.
merge_state=$(printf '%s' "$pr" | json_stdin_get "mergeStateStatus")
if [ "$merge_state" = "DIRTY" ] || [ "$merge_state" = "CONFLICTING" ]; then
  block "ship-gate: PR for '$branch' has merge conflicts (mergeStateStatus=$merge_state). Rebase onto the base branch, re-run Layer 1 checks (green-loop), and push."
fi

# 6. Review requested.
review_decision=$(printf '%s' "$pr" | json_stdin_get "reviewDecision")
review_requests=$(printf '%s' "$pr" | json_stdin_get "reviewRequests")
if [ -z "$review_decision" ] && { [ -z "$review_requests" ] || [ "$review_requests" = "[]" ]; }; then
  block "ship-gate: PR for '$branch' has no review requested and no review decision yet. Request a review (/code-review, or a reviewer on the PR) before finishing."
fi

# Everything delivered.
allow
