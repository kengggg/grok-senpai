#!/usr/bin/env bash
# PR 1 acceptance suite — fake runners only; no live model calls.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SENPAI="$ROOT/.grok/orchestration/senpai.sh"
FAKE_CLAUDE="$ROOT/tests/senpai/fakes/claude"
FAKE_CODEX="$ROOT/tests/senpai/fakes/codex"
PASS=0
FAIL=0

assert() {
  local name="$1"
  shift
  if "$@"; then
    echo "PASS  $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL  $name" >&2
    FAIL=$((FAIL + 1))
  fi
}

assert_eq() {
  local name="$1" got="$2" want="$3"
  if [[ "$got" == "$want" ]]; then
    echo "PASS  $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL  $name (got='$got' want='$want')" >&2
    FAIL=$((FAIL + 1))
  fi
}

chmod +x "$SENPAI" "$FAKE_CLAUDE" "$FAKE_CODEX"

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/senpai-test.XXXXXX")"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

# --- 1. fresh install into a git repo ---------------------------------------
PROJ="$WORKDIR/proj"
mkdir -p "$PROJ"
git -C "$PROJ" init -q
git -C "$PROJ" config user.email t@t
git -C "$PROJ" config user.name t
: >"$PROJ/README"
git -C "$PROJ" add README
git -C "$PROJ" commit -qm init

"$ROOT/install.sh" "$PROJ" >/dev/null

assert "install: helper exists" test -x "$PROJ/.grok/orchestration/senpai.sh"
assert "install: grok skill" test -f "$PROJ/.grok/skills/senpai/SKILL.md"
assert "install: agents skill" test -f "$PROJ/.agents/skills/senpai/SKILL.md"
assert "install: claude skill" test -f "$PROJ/.claude/skills/senpai/SKILL.md"

SUM1="$(cksum "$PROJ/.grok/orchestration/senpai.sh" | awk '{print $1}')"
grep -q "senpai-managed:checksum=${SUM1}" "$PROJ/.grok/skills/senpai/SKILL.md"
assert "install: grok skill checksum" test $? -eq 0
# re-grep for the other two
assert "install: agents checksum" grep -q "senpai-managed:checksum=${SUM1}" "$PROJ/.agents/skills/senpai/SKILL.md"
assert "install: claude checksum" grep -q "senpai-managed:checksum=${SUM1}" "$PROJ/.claude/skills/senpai/SKILL.md"
assert "install: toml created" test -f "$PROJ/.grok/orchestration/worker-config.toml"
assert "install: state created" test -f "$PROJ/.grok/orchestration/state.md"
assert "install: CLAUDE.md created" test -f "$PROJ/CLAUDE.md"

# --- 2. reinstall preserves project files -----------------------------------
echo 'custom = true' >>"$PROJ/.grok/orchestration/worker-config.toml"
echo '# keep-me' >>"$PROJ/.grok/orchestration/state.md"
echo 'alias-keep' >>"$PROJ/.grok/orchestration/model-aliases.toml"
printf 'keep-claude\n' >"$PROJ/CLAUDE.md"
HASH_TOML="$(cksum "$PROJ/.grok/orchestration/worker-config.toml" | awk '{print $1}')"
HASH_STATE="$(cksum "$PROJ/.grok/orchestration/state.md" | awk '{print $1}')"
HASH_ALIAS="$(cksum "$PROJ/.grok/orchestration/model-aliases.toml" | awk '{print $1}')"
HASH_CLAUDE="$(cksum "$PROJ/CLAUDE.md" | awk '{print $1}')"
"$ROOT/install.sh" "$PROJ" >/dev/null
assert_eq "reinstall: toml byte-identical" "$(cksum "$PROJ/.grok/orchestration/worker-config.toml" | awk '{print $1}')" "$HASH_TOML"
assert_eq "reinstall: state byte-identical" "$(cksum "$PROJ/.grok/orchestration/state.md" | awk '{print $1}')" "$HASH_STATE"
assert_eq "reinstall: aliases byte-identical" "$(cksum "$PROJ/.grok/orchestration/model-aliases.toml" | awk '{print $1}')" "$HASH_ALIAS"
assert_eq "reinstall: CLAUDE.md byte-identical" "$(cksum "$PROJ/CLAUDE.md" | awk '{print $1}')" "$HASH_CLAUDE"
assert "reinstall: gitignore has journal" grep -q ".grok/orchestration/journal.jsonl" "$PROJ/.gitignore"

# --- 3. unowned collision aborts --------------------------------------------
COLLIDE="$WORKDIR/collide"
mkdir -p "$COLLIDE"
git -C "$COLLIDE" init -q
mkdir -p "$COLLIDE/.claude/skills/senpai"
echo 'unowned' >"$COLLIDE/.claude/skills/senpai/SKILL.md"
if "$ROOT/install.sh" "$COLLIDE" >/dev/null 2>"$WORKDIR/collide.err"; then
  echo "FAIL  collision: installer succeeded" >&2
  FAIL=$((FAIL + 1))
else
  echo "PASS  collision: installer aborted"
  PASS=$((PASS + 1))
fi
assert "collision: no helper written" test ! -e "$COLLIDE/.grok/orchestration/senpai.sh"
assert "collision: unowned file untouched" grep -qx unowned "$COLLIDE/.claude/skills/senpai/SKILL.md"

# --- 4. live PID refuses overwrite ------------------------------------------
LIVE="$WORKDIR/live"
mkdir -p "$LIVE"
git -C "$LIVE" init -q
"$ROOT/install.sh" "$LIVE" >/dev/null
# plant a live pid in state.md
{
  echo "# Orchestration State (grok-senpai)"
  echo
  echo "| Task ID | Agent | Role | Model | Effort | Worktree Path | Branch | Status | Phase | Started | Last heartbeat | Last signal | Result Packet | Log | PID | Notes |"
  echo "|---------|-------|------|-------|--------|---------------|--------|--------|-------|---------|----------------|-------------|---------------|-----|-----|-------|"
  echo "| live-1 | grok | debater | grok-4.6 | default | x | y | running | running | t | t | t | | | $$ | live |"
} >"$LIVE/.grok/orchestration/state.md"
if GROK_SENPAI_FORCE= "$ROOT/install.sh" "$LIVE" >/dev/null 2>"$WORKDIR/live.err"; then
  # default FORCE unset
  :
fi
if "$ROOT/install.sh" "$LIVE" >/dev/null 2>"$WORKDIR/live.err"; then
  echo "FAIL  live-pid: installer succeeded" >&2
  FAIL=$((FAIL + 1))
else
  echo "PASS  live-pid: installer refused"
  PASS=$((PASS + 1))
fi
if GROK_SENPAI_FORCE=1 "$ROOT/install.sh" "$LIVE" >/dev/null 2>"$WORKDIR/live-force.err"; then
  echo "PASS  live-pid: FORCE=1 allowed"
  PASS=$((PASS + 1))
else
  echo "FAIL  live-pid: FORCE=1 refused" >&2
  FAIL=$((FAIL + 1))
fi

# --- helper tests in PROJ ---------------------------------------------------
export SENPAI_CONTROL_ROOT="$PROJ"
export SENPAI_CLAUDE_BIN="$FAKE_CLAUDE"
export SENPAI_CODEX_BIN="$FAKE_CODEX"
export SENPAI_LOCK_TTL=1

# isolation: primary checkout should fail without flag
PROMPT="$WORKDIR/prompt.txt"
printf 'hello $(true) `uname` "quotes"\nsecond line\n' >"$PROMPT"
if "$SENPAI" launch --agent claude --mode implementation --task-id t-inj --chain c1 \
    --prompt-file "$PROMPT" --cwd "$PROJ" >/dev/null 2>&1; then
  echo "FAIL  isolation: primary checkout allowed" >&2
  FAIL=$((FAIL + 1))
else
  echo "PASS  isolation: primary checkout refused"
  PASS=$((PASS + 1))
fi

# add a linked worktree
WT="$WORKDIR/wt-impl"
git -C "$PROJ" worktree add -q -b orch/t-impl "$WT"
ARGV="$WORKDIR/argv.nul"
export SENPAI_ARGV_OUT="$ARGV"

PID="$("$SENPAI" launch --agent claude --mode implementation --task-id t-inj --chain c1 \
  --prompt-file "$PROMPT" --cwd "$WT")"
assert "launch: recorded pid is numeric" test -n "$PID"

python3 - "$ARGV" "$PROJ" "$PROMPT" <<'PY'
import sys, os
path, proj, prompt = sys.argv[1], sys.argv[2], sys.argv[3]
parts = open(path, "rb").read().split(b"\0")
parts = [p.decode("utf-8", "replace") for p in parts if p]
blob = "\n".join(parts)
assert "--prompt-file" in parts, parts
assert "--model" in parts, parts
assert "eval" not in blob
assert not any("$(true)" in p for p in parts)
text = open(prompt, encoding="utf-8").read()
assert "$(true)" in text
assert not os.path.exists(os.path.join(proj, "PWNED"))
print("ok")
PY
assert "launch: metacharacters stay in the prompt file, not argv" test $? -eq 0

# review mode: no acceptEdits / Edit,Write
ARGV2="$WORKDIR/argv-review.nul"
SENPAI_ARGV_OUT="$ARGV2" "$SENPAI" launch --agent claude --mode independent_review \
  --task-id t-rev --chain c-rev --prompt-file "$PROMPT" --cwd "$WT" >/dev/null
python3 - "$ARGV2" <<'PY'
import sys
parts=open(sys.argv[1],"rb").read().split(b"\0")
parts=[p.decode() for p in parts if p]
blob=" ".join(parts)
assert "acceptEdits" not in blob, blob
assert "Edit,Write" not in blob and "Write,Edit" not in blob
assert "--permission-mode" in parts
print("ok")
PY
assert "review: no acceptEdits/write tools" test $? -eq 0

# codex review sandbox
ARGV3="$WORKDIR/argv-codex.nul"
SENPAI_ARGV_OUT="$ARGV3" "$SENPAI" launch --agent codex --mode independent_review \
  --task-id t-codex --chain c-cx --prompt-file "$PROMPT" --cwd "$WT" >/dev/null
python3 - "$ARGV3" <<'PY'
import sys
parts=open(sys.argv[1],"rb").read().split(b"\0")
parts=[p.decode() for p in parts if p]
assert "--sandbox" in parts
assert "read-only" in parts
print("ok")
PY
assert "review: codex read-only sandbox" test $? -eq 0

# refuse senpai agent
if "$SENPAI" launch --agent senpai --mode implementation --task-id x --chain y \
    --prompt-file "$PROMPT" --cwd "$WT" >/dev/null 2>&1; then
  echo "FAIL  launch senpai agent" >&2
  FAIL=$((FAIL + 1))
else
  echo "PASS  launch: refuse senpai worker"
  PASS=$((PASS + 1))
fi

# oversized prompt uses --prompt-file
BIG="$WORKDIR/big.txt"
python3 - <<PY
open("$BIG","wb").write(b"X"*(100000+10))
PY
ARGV4="$WORKDIR/argv-big.nul"
SENPAI_ARGV_OUT="$ARGV4" "$SENPAI" launch --agent claude --mode implementation \
  --task-id t-big --chain c-big --prompt-file "$BIG" --cwd "$WT" >/dev/null
python3 - "$ARGV4" <<'PY'
import sys
parts=open(sys.argv[1],"rb").read().split(b"\0")
parts=[p.decode() for p in parts if p]
assert "--prompt-file" in parts, parts
# the huge payload must not be an argv element
assert not any(len(p) > 50000 for p in parts)
print("ok")
PY
assert "launch: oversized prompt is a path" test $? -eq 0

# collect
RES="$WORKDIR/result.json"
cat >"$RES" <<'JSON'
{"protocol_version":2,"task_id":"t-col","attempt":1,"status":"success","agent":"claude","mode":"implementation"}
JSON
DEST="$("$SENPAI" collect --task-id t-col --attempt 1 --from "$RES")"
assert "collect: published" test -f "$DEST"
if "$SENPAI" collect --task-id t-col --attempt 1 --from "$RES" >/dev/null 2>&1; then
  echo "FAIL  collect republish" >&2
  FAIL=$((FAIL + 1))
else
  echo "PASS  collect: same-attempt republish refused"
  PASS=$((PASS + 1))
fi
# unified usage → shared ledger
RESU="$WORKDIR/result-usage.json"
cat >"$RESU" <<'JSON'
{"protocol_version":2,"task_id":"t-use","attempt":1,"status":"success","agent":"claude","mode":"implementation","usage":{"senpai":{"uncached_input":10,"cache_read":20,"cache_write":5,"reasoning":3,"output":7,"cost":0.02},"worker":{"uncached_input":100,"cache_read":200,"cache_write":50,"reasoning":30,"output":70,"cost":0.4}}}
JSON
RUNU="$("$SENPAI" mint --chain c-use --mode implementation)"
"$SENPAI" collect --task-id t-use --attempt 1 --from "$RESU" --run-id "$RUNU" >/dev/null
assert "usage: ledger exists" test -f "$PROJ/.grok/orchestration/ledger.jsonl"
assert "usage: both parties in ledger" test "$(grep -c '"event":"usage"' "$PROJ/.grok/orchestration/ledger.jsonl")" -ge 2
assert "usage: senpai party row" grep -q '"party":"senpai"' "$PROJ/.grok/orchestration/ledger.jsonl"
assert "usage: worker party row" grep -q '"party":"worker"' "$PROJ/.grok/orchestration/ledger.jsonl"
SHOW="$("$SENPAI" usage-show --run-id "$RUNU")"
echo "$SHOW" | python3 -c 'import json,sys; u=json.load(sys.stdin); assert u["total"]["uncached_input"]==110; assert u["total"]["cache_read"]==220; assert u["total"]["cache_write"]==55; assert u["total"]["reasoning"]==33; assert u["total"]["output"]==77; assert abs(u["total"]["cost"]-0.42)<1e-9'
assert "usage: rollup totals senpai+worker" test $? -eq 0
echo '{"uncached_input":11,"cache_read":0,"cache_write":0,"reasoning":1,"output":2,"cost":0.05}' >"$WORKDIR/senpai-only.json"
RESU2="$WORKDIR/result-use2.json"
sed 's/"task_id":"t-use"/"task_id":"t-use2"/' "$RESU" >"$RESU2"
"$SENPAI" collect --task-id t-use2 --attempt 1 --from "$RESU2" --run-id "$RUNU" --senpai-usage "$WORKDIR/senpai-only.json" >/dev/null
SHOW2="$("$SENPAI" usage-show --run-id "$RUNU")"
echo "$SHOW2" | python3 -c 'import json,sys; u=json.load(sys.stdin); assert u["senpai"]["uncached_input"]==11; assert u["senpai"]["cost"]==0.05'
assert "usage: --senpai-usage overwrites host party" test $? -eq 0

BAD="$WORKDIR/bad.json"
echo '{"protocol_version":2,"task_id":"other","status":"success"}' >"$BAD"
if "$SENPAI" collect --task-id t-col --attempt 2 --from "$BAD" >/dev/null 2>&1; then
  echo "FAIL  collect accepted mismatched v2" >&2
  FAIL=$((FAIL + 1))
else
  echo "PASS  collect: malformed/mismatched v2 refused"
  PASS=$((PASS + 1))
fi

# snapshot + approve
read -r BASE TREE < <(SENPAI_CONTROL_ROOT="$PROJ" "$SENPAI" snapshot --cwd "$PROJ")
assert "snapshot: tree oid" test -n "$TREE"
"$SENPAI" approve --base "$BASE" --tree "$TREE" --cwd "$PROJ" >/dev/null
echo dirty >>"$PROJ/README"
if "$SENPAI" approve --base "$BASE" --tree "$TREE" --cwd "$PROJ" >/dev/null 2>&1; then
  echo "FAIL  approve after mutate" >&2
  FAIL=$((FAIL + 1))
else
  echo "PASS  approve: mutation invalidates old tree"
  PASS=$((PASS + 1))
fi
read -r BASE2 TREE2 < <("$SENPAI" snapshot --cwd "$PROJ")
"$SENPAI" approve --base "$BASE2" --tree "$TREE2" --cwd "$PROJ" >/dev/null
assert "approve: fresh snapshot accepted" test $? -eq 0

# lock
"$SENPAI" lock --chain lock-a >/dev/null
if "$SENPAI" lock --chain lock-a >/dev/null 2>&1; then
  echo "FAIL  double lock" >&2
  FAIL=$((FAIL + 1))
else
  echo "PASS  lock: second acquire refused"
  PASS=$((PASS + 1))
fi
# steal: dead pid + ttl
LOCKDIR="$PROJ/.grok/orchestration/locks/lock-a"
echo 999999 >"$LOCKDIR/pid"
sleep 2
"$SENPAI" lock --chain lock-a >/dev/null
assert "lock: steal after dead pid + TTL" test $? -eq 0

# mint + no-delegate child
RUN="$("$SENPAI" mint --chain ch-m --mode implementation)"
assert "mint: run id" test -n "$RUN"
# mark as runner (may_delegate=0) then child mint must fail
# first mint is generation 0 (may_delegate=1). Create a child:
CHILD="$("$SENPAI" mint --chain ch-m --parent "$RUN" --mode independent_review)"
assert "mint: child run" test -n "$CHILD"
if "$SENPAI" mint --chain ch-m --parent "$CHILD" --mode implementation >/dev/null 2>&1; then
  echo "FAIL  grandchild mint" >&2
  FAIL=$((FAIL + 1))
else
  echo "PASS  mint: runner cannot mint grandchild"
  PASS=$((PASS + 1))
fi

# copied pack without git
COPY="$WORKDIR/copy-pack"
mkdir -p "$COPY"
cp -R "$ROOT/.grok" "$COPY/.grok"
cp "$ROOT/AGENTS.md" "$COPY/AGENTS.md"
chmod +x "$COPY/.grok/orchestration/senpai.sh"
# walk-up from a subdir
mkdir -p "$COPY/nested"
GOT="$(cd "$COPY/nested" && SENPAI_CONTROL_ROOT= "$COPY/.grok/orchestration/senpai.sh" control-root)"
WANT="$(cd "$COPY" && pwd)"
assert_eq "copy-pack: walk-up finds root" "$GOT" "$WANT"
if SENPAI_CONTROL_ROOT="$COPY" "$COPY/.grok/orchestration/senpai.sh" launch \
    --agent claude --mode implementation --task-id t-copy --chain c-copy \
    --prompt-file "$PROMPT" --cwd "$COPY" >/dev/null 2>&1; then
  echo "FAIL  copy-pack launch without allow" >&2
  FAIL=$((FAIL + 1))
else
  echo "PASS  copy-pack: launch without git requires allow-primary-checkout"
  PASS=$((PASS + 1))
fi
SENPAI_CONTROL_ROOT="$COPY" SENPAI_CLAUDE_BIN="$FAKE_CLAUDE" \
  "$COPY/.grok/orchestration/senpai.sh" launch \
  --agent claude --mode implementation --task-id t-copy --chain c-copy \
  --prompt-file "$PROMPT" --cwd "$COPY" --allow-primary-checkout >/dev/null
assert "copy-pack: sequential launch with spoken allow" test $? -eq 0

# --- PR 2: journal import ---------------------------------------------------
cat >"$PROJ/.grok/orchestration/state.md" <<EOF
# Orchestration State (grok-senpai)

| Task ID | Agent | Role | Model | Effort | Worktree Path | Branch | Status | Phase | Started | Last heartbeat | Last signal | Result Packet | Log | PID | Notes |
|---------|-------|------|-------|--------|---------------|--------|--------|-------|---------|----------------|-------------|---------------|-----|-----|-------|
| debate-vax-mod | grok | moderator | grok-4.6 | default | x | n/a | success | done | t | t | t | yes | log | 1 | note |
EOF
"$SENPAI" import >/dev/null
assert "import: backup exists" test -f "$PROJ/.grok/orchestration/state.md.pre-v2"
assert "import: sot is journal" grep -qx journal "$PROJ/.grok/orchestration/sot"
assert "import: legacy meta" test -f "$PROJ/.grok/orchestration/runs/legacy-debate-vax-mod/meta"
assert "import: not resumable" grep -q 'resumable=0' "$PROJ/.grok/orchestration/runs/legacy-debate-vax-mod/meta"
assert "import: may not delegate" grep -q 'may_delegate=0' "$PROJ/.grok/orchestration/runs/legacy-debate-vax-mod/meta"
"$SENPAI" render >/dev/null
assert "render: generated" test -f "$PROJ/.grok/orchestration/state.generated.md"
assert "render: watermark" grep -q "generated by senpai.sh render" "$PROJ/.grok/orchestration/state.md"

echo
echo "passed=$PASS failed=$FAIL"
[[ "$FAIL" -eq 0 ]]
