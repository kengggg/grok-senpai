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
done

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

# Real CLI probes (do not fail)
echo
echo "## Real CLI probes (UNKNOWN — not a merge gate)"
if command -v claude >/dev/null 2>&1; then
  echo "probe: claude is on PATH"
  if claude --help 2>/dev/null | grep -qi 'prompt-file\|--p '; then
    echo "probe: claude help mentions a prompt flag"
  else
    echo "probe: claude help did not mention --prompt-file (UNKNOWN)"
  fi
else
  echo "probe: claude not installed (UNKNOWN)"
fi
if command -v codex >/dev/null 2>&1; then
  echo "probe: codex is on PATH"
  if codex exec --help 2>/dev/null | grep -qi 'prompt-file'; then
    echo "probe: codex mentions --prompt-file"
  else
    echo "probe: codex exec --help did not mention --prompt-file (UNKNOWN)"
  fi
else
  echo "probe: codex not installed (UNKNOWN)"
fi

echo
echo "passed=$PASS failed=$FAIL"
[[ "$FAIL" -eq 0 ]]
