#!/usr/bin/env bash
# PR 3 — conformance. Fake matrix always runs. Real CLI probes are informational
# and do not fail the suite (UNKNOWN until a human labels a host proven).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SENPAI="$ROOT/.grok/orchestration/senpai.sh"
FAKE_CLAUDE="$ROOT/tests/senpai/fakes/claude"
FAKE_CODEX="$ROOT/tests/senpai/fakes/codex"
chmod +x "$SENPAI" "$FAKE_CLAUDE" "$FAKE_CODEX"

PASS=0
FAIL=0
assert() {
  local name="$1"; shift
  if "$@"; then echo "PASS  $name"; PASS=$((PASS+1))
  else echo "FAIL  $name" >&2; FAIL=$((FAIL+1)); fi
}

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/senpai-conf.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

PROJ="$WORKDIR/proj"
mkdir -p "$PROJ"
git -C "$PROJ" init -q
git -C "$PROJ" config user.email t@t
git -C "$PROJ" config user.name t
: >"$PROJ/README"
git -C "$PROJ" add README
git -C "$PROJ" commit -qm init
"$ROOT/install.sh" "$PROJ" >/dev/null

# three host skills, identical managed checksum
SUM="$(cksum "$PROJ/.grok/orchestration/senpai.sh" | awk '{print $1}')"
for p in \
  "$PROJ/.grok/skills/senpai/SKILL.md" \
  "$PROJ/.agents/skills/senpai/SKILL.md" \
  "$PROJ/.claude/skills/senpai/SKILL.md"
do
  assert "skill $p" grep -q "senpai-managed:checksum=${SUM}" "$p"
done

export SENPAI_CONTROL_ROOT="$PROJ"
export SENPAI_CLAUDE_BIN="$FAKE_CLAUDE"
export SENPAI_CODEX_BIN="$FAKE_CODEX"
export SENPAI_LOCK_TTL=1

WT="$WORKDIR/wt"
git -C "$PROJ" worktree add -q -b orch/conf "$WT"
PROMPT="$WORKDIR/p.txt"
echo 'do the thing' >"$PROMPT"

# implement then review on both fake hosts
for agent in claude codex; do
  ARGV="$WORKDIR/argv-$agent.nul"
  SENPAI_ARGV_OUT="$ARGV" "$SENPAI" launch --agent "$agent" --mode implementation \
    --task-id "impl-$agent" --chain "c-$agent" --prompt-file "$PROMPT" --cwd "$WT" >/dev/null
  SENPAI_ARGV_OUT="$WORKDIR/argv-$agent-rev.nul" "$SENPAI" launch --agent "$agent" \
    --mode independent_review --task-id "rev-$agent" --chain "c-$agent" \
    --prompt-file "$PROMPT" --cwd "$WT" >/dev/null
  assert "matrix $agent implement+review launched" test -s "$WORKDIR/argv-$agent-rev.nul"
  if python3 - "$ARGV" <<'PY'
import sys
parts=open(sys.argv[1],"rb").read().split(b"\0")
parts=[p.decode() for p in parts if p]
sys.exit(0 if "--prompt-file" not in parts else 1)
PY
  then
    echo "PASS  $agent runner argv has no --prompt-file"
    PASS=$((PASS+1))
  else
    echo "FAIL  $agent runner argv still has --prompt-file" >&2
    FAIL=$((FAIL+1))
  fi
done
assert "launch: matrix did not write runs/none" test ! -e "$PROJ/.grok/orchestration/runs/none"

# parallel chains
"$SENPAI" lock --chain p1 >/dev/null
"$SENPAI" lock --chain p2 >/dev/null
assert "parallel: two chains" test -d "$PROJ/.grok/orchestration/locks/p1" \
  -a -d "$PROJ/.grok/orchestration/locks/p2"
if "$SENPAI" lock --chain p1 >/dev/null 2>&1; then
  echo "FAIL  parallel: same chain double lock" >&2; FAIL=$((FAIL+1))
else
  echo "PASS  parallel: same chain refused"; PASS=$((PASS+1))
fi

# crash / resume: dead pid + TTL steal
echo 1 >"$PROJ/.grok/orchestration/locks/p1/pid"
sleep 2
"$SENPAI" lock --chain p1 >/dev/null
assert "crash-resume: steal" test $? -eq 0

# Real CLI probes (do not fail the suite; never start a live model session)
echo
echo "## Real CLI probes (UNKNOWN — not a merge gate)"
echo "probe: helper launch feeds the stored prompt on stdin (no runner --prompt-file)"
echo "probe: skill files exist after install (discovery fire still UNKNOWN)"
assert "probe: project .claude/skills/senpai present" \
  test -f "$PROJ/.claude/skills/senpai/SKILL.md"
assert "probe: project .agents/skills/senpai present" \
  test -f "$PROJ/.agents/skills/senpai/SKILL.md"

if command -v claude >/dev/null 2>&1; then
  echo "probe: claude is on PATH ($(claude --version 2>/dev/null | head -1))"
  if claude --help 2>/dev/null | grep -q -- '--prompt-file'; then
    echo "probe: claude help mentions --prompt-file"
  else
    echo "probe: claude help did not mention --prompt-file (UNKNOWN)"
  fi
  if claude --help 2>/dev/null | grep -q -- '--system-prompt'; then
    echo "probe: claude help mentions --system-prompt (not a Result prompt-file)"
  fi
  set +e
  claude --prompt-file "$PROMPT" </dev/null >"$WORKDIR/claude-pf.out" 2>"$WORKDIR/claude-pf.err"
  _ce=$?
  set -e
  if grep -qi 'unknown option' "$WORKDIR/claude-pf.err"; then
    echo "probe: claude rejects --prompt-file (helper no longer passes it; uses --print + stdin)"
  else
    echo "probe: claude --prompt-file exit=${_ce} (UNKNOWN; $(head -1 "$WORKDIR/claude-pf.err"))"
  fi
  echo "probe: review-sandbox fence of git-common-dir is UNKNOWN (no live session)"
else
  echo "probe: claude not installed (UNKNOWN)"
fi
if command -v codex >/dev/null 2>&1; then
  echo "probe: codex is on PATH ($(codex --version 2>/dev/null | head -1))"
  if codex exec --help 2>/dev/null | grep -q -- '--prompt-file'; then
    echo "probe: codex exec help mentions --prompt-file"
  else
    echo "probe: codex exec --help did not mention --prompt-file (UNKNOWN)"
  fi
  if codex exec --help 2>/dev/null | grep -qi 'stdin'; then
    echo "probe: codex exec documents stdin / '-' for the prompt (not --prompt-file)"
  fi
  if codex exec --help 2>/dev/null | grep -q 'read-only'; then
    echo "probe: codex exec lists sandbox read-only; git-common-dir fence is UNKNOWN"
  fi
  set +e
  codex exec --prompt-file "$PROMPT" -h >"$WORKDIR/codex-pf.out" 2>"$WORKDIR/codex-pf.err"
  _xe=$?
  set -e
  if grep -qi 'unexpected argument' "$WORKDIR/codex-pf.err"; then
    echo "probe: codex exec rejects --prompt-file (helper no longer passes it; uses stdin / '-')"
  else
    echo "probe: codex exec --prompt-file exit=${_xe} (UNKNOWN; $(head -1 "$WORKDIR/codex-pf.err"))"
  fi
else
  echo "probe: codex not installed (UNKNOWN)"
fi

echo
echo "passed=$PASS failed=$FAIL"
[[ "$FAIL" -eq 0 ]]
