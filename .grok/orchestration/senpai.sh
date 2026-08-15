#!/usr/bin/env bash
# senpai.sh — pack-floor helper (flags only; never eval; never parse packets).
# Verbs: control-root | checksum | lock | mint | launch | collect | snapshot | approve | render
set -euo pipefail

usage() {
  cat <<'EOF' >&2
usage: senpai.sh <verb> [flags]

verbs:
  control-root
  checksum
  import
  lock    --chain ID
  mint    --chain ID [--parent RUN] [--mode MODE] [--role ROLE]
  launch  --agent claude|codex --mode implementation|independent_review
          --task-id ID --chain ID --prompt-file PATH [--cwd DIR]
          [--run-id ID] [--attempt N] [--model M] [--effort E]
          [--allow-primary-checkout]
  collect --task-id ID --attempt N --from PATH
          [--run-id ID] [--usage PATH] [--senpai-usage PATH]
  usage-record --run-id ID --party senpai|worker
          [--task-id ID] [--attempt N]
          [--uncached-input N] [--cache-read N] [--cache-write N]
          [--reasoning N] [--output N] [--cost N]
  usage-show [--run-id ID]
  snapshot [--cwd DIR]
  approve --base OID --tree OID [--host-session SID]
  render
  doctor
  status
  cleanup --chain ID
EOF
  exit 2
}

die() { echo "error: $*" >&2; exit 1; }

json_escape() {
  # POSIX-ish escape for a single line value
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# --- control root -----------------------------------------------------------

find_primary_from_common() {
  local common="$1" gitdir candidate
  gitdir="${common%/}"
  if [[ "$(basename "$gitdir")" == ".git" ]]; then
    dirname "$gitdir"
    return 0
  fi
  # worktree common dir is <repo>/.git
  if [[ -d "${gitdir}" && -f "${gitdir}/HEAD" ]]; then
    dirname "$gitdir"
    return 0
  fi
  return 1
}

resolve_control_root() {
  local start common primary dir
  if [[ -n "${SENPAI_CONTROL_ROOT:-}" ]]; then
    [[ -d "${SENPAI_CONTROL_ROOT}/.grok/orchestration" ]] \
      || die "SENPAI_CONTROL_ROOT missing .grok/orchestration: $SENPAI_CONTROL_ROOT"
    printf '%s\n' "$(cd "$SENPAI_CONTROL_ROOT" && pwd)"
    return 0
  fi

  if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    common="$(git rev-parse --git-common-dir)"
    # make absolute
    case "$common" in
      /*) ;;
      *) common="$(pwd)/$common" ;;
    esac
    if primary="$(find_primary_from_common "$common")"; then
      if [[ -d "${primary}/.grok/orchestration" ]]; then
        printf '%s\n' "$primary"
        return 0
      fi
    fi
  fi

  dir="$(pwd)"
  while true; do
    if [[ -d "${dir}/.grok/orchestration" && -f "${dir}/AGENTS.md" ]]; then
      printf '%s\n' "$dir"
      return 0
    fi
    if [[ -x "${dir}/.grok/orchestration/senpai.sh" ]]; then
      printf '%s\n' "$dir"
      return 0
    fi
    if [[ "$dir" == "/" ]]; then
      break
    fi
    dir="$(dirname "$dir")"
  done
  die "cannot resolve control root (set SENPAI_CONTROL_ROOT)"
}

orch_dir() { printf '%s/.grok/orchestration\n' "$CONTROL_ROOT"; }

ensure_dirs() {
  mkdir -p "$(orch_dir)/locks" "$(orch_dir)/runs" "$(orch_dir)/results" \
    "$(orch_dir)/prompts" "$(orch_dir)/logs"
}

journal_append() {
  local line="$1"
  ensure_dirs
  printf '%s\n' "$line" >>"$(orch_dir)/journal.jsonl"
}

helper_checksum() {
  # cksum is POSIX; first field is the CRC
  cksum "$0" | awk '{print $1}'
}

# --- lock -------------------------------------------------------------------

LOCK_TTL="${SENPAI_LOCK_TTL:-60}"

lock_dir_for() { printf '%s/locks/%s\n' "$(orch_dir)" "$1"; }

pid_alive() {
  local pid="$1"
  [[ -n "$pid" ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

# Starttime distinguishes a recorded holder from a later process that reused the PID.
pid_starttime() {
  local pid="$1"
  [[ -n "$pid" ]] || return 1
  if [[ -r "/proc/${pid}/stat" ]]; then
    awk '{
      line = $0
      sub(/.*\) /, "", line)
      n = split(line, a, / /)
      print a[20]
    }' "/proc/${pid}/stat"
    return 0
  fi
  return 1
}

pid_is_holder() {
  local pid="$1" recorded="${2:-}"
  pid_alive "$pid" || return 1
  if [[ -n "$recorded" ]]; then
    local cur
    cur="$(pid_starttime "$pid" 2>/dev/null || true)"
    [[ -n "$cur" && "$cur" == "$recorded" ]]
    return
  fi
  return 0
}

write_lock_files() {
  local d="$1" token="$2"
  local st=""
  st="$(pid_starttime "$$" 2>/dev/null || true)"
  printf '%s\n' "$$" >"$d/pid"
  printf '%s\n' "$token" >"$d/start_token"
  printf '%s\n' "$st" >"$d/pid_start"
}

lock_age() {
  local d="$1" now m
  now="$(date +%s)"
  if stat -f %m "$d" >/dev/null 2>&1; then
    m="$(stat -f %m "$d")"
  else
    m="$(stat -c %Y "$d")"
  fi
  echo $((now - m))
}

cmd_lock() {
  local chain="" steal=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --chain) chain="${2:-}"; shift 2 ;;
      *) die "lock: unknown flag $1" ;;
    esac
  done
  [[ -n "$chain" ]] || die "lock: --chain required"
  case "$chain" in
    *[!A-Za-z0-9._-]*) die "lock: invalid chain id" ;;
  esac
  ensure_dirs
  local d token
  d="$(lock_dir_for "$chain")"
  token="tok-${RANDOM}-$$-$(date +%s)"

  if mkdir "$d" 2>/dev/null; then
    write_lock_files "$d" "$token"
    journal_append "{\"ts\":\"$(now_iso)\",\"event\":\"lock\",\"chain\":\"$(json_escape "$chain")\",\"pid\":$$,\"start_token\":\"$(json_escape "$token")\",\"action\":\"acquire\"}"
    printf '%s\n' "$token"
    return 0
  fi

  local old_pid old_token old_start age cur_start reused=0
  old_pid="$(cat "$d/pid" 2>/dev/null || true)"
  old_token="$(cat "$d/start_token" 2>/dev/null || true)"
  old_start="$(cat "$d/pid_start" 2>/dev/null || true)"
  age="$(lock_age "$d")"

  if pid_is_holder "$old_pid" "$old_start"; then
    die "lock: chain $chain held by live pid $old_pid"
  fi

  # Alive PID whose starttime does not match the recorded holder is reuse, not ownership.
  if pid_alive "$old_pid" && [[ -n "$old_start" ]]; then
    cur_start="$(pid_starttime "$old_pid" 2>/dev/null || true)"
    if [[ -n "$cur_start" && "$cur_start" != "$old_start" ]]; then
      reused=1
    fi
  fi

  steal=0
  if [[ "$reused" -eq 1 ]]; then
    steal=1
  elif [[ "$age" -gt "$LOCK_TTL" ]]; then
    steal=1
  else
    die "lock: chain $chain stale but TTL ${LOCK_TTL}s not elapsed (age=${age}s)"
  fi

  if [[ "$steal" -eq 1 ]]; then
    # Compare-and-swap on start_token, then rename the old dir aside (no rm -rf + mkdir).
    local cur_token claim stale
    cur_token="$(cat "$d/start_token" 2>/dev/null || true)"
    [[ "$cur_token" == "$old_token" ]] || die "lock: steal lost the race (start_token changed)"
    claim="$(lock_dir_for ".${chain}.claim.$$")"
    stale="$(lock_dir_for ".${chain}.stale.$$")"
    rm -rf "$claim"
    mkdir "$claim" || die "lock: steal claim failed"
    write_lock_files "$claim" "$token"
    if ! mv "$d" "$stale" 2>/dev/null; then
      rm -rf "$claim"
      die "lock: steal lost the race"
    fi
    if ! mv "$claim" "$d" 2>/dev/null; then
      mv "$stale" "$d" 2>/dev/null || true
      rm -rf "$claim"
      die "lock: steal lost the race"
    fi
    rm -rf "$stale"
    journal_append "{\"ts\":\"$(now_iso)\",\"event\":\"lock\",\"chain\":\"$(json_escape "$chain")\",\"pid\":$$,\"start_token\":\"$(json_escape "$token")\",\"action\":\"steal\",\"prev_pid\":\"$(json_escape "$old_pid")\"}"
    printf '%s\n' "$token"
    return 0
  fi
  die "lock: failed"
}

# --- mint -------------------------------------------------------------------

cmd_mint() {
  local chain="" parent="" mode="implementation" role="dev"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --chain) chain="${2:-}"; shift 2 ;;
      --parent) parent="${2:-}"; shift 2 ;;
      --mode) mode="${2:-}"; shift 2 ;;
      --role) role="${2:-}"; shift 2 ;;
      *) die "mint: unknown flag $1" ;;
    esac
  done
  [[ -n "$chain" ]] || die "mint: --chain required"
  case "$mode" in
    implementation|independent_review) ;;
    *) die "mint: mode must be implementation|independent_review" ;;
  esac
  ensure_dirs

  local depth=0 may_delegate=1 parent_may=1 parent_depth=0
  if [[ -n "$parent" ]]; then
    local pmeta
    pmeta="$(orch_dir)/runs/${parent}/meta"
    [[ -f "$pmeta" ]] || die "mint: unknown parent $parent"
    # shellcheck disable=SC1090
    parent_depth="$(awk -F= '/^depth=/{print $2}' "$pmeta")"
    parent_may="$(awk -F= '/^may_delegate=/{print $2}' "$pmeta")"
    if [[ "${parent_may}" != "1" ]]; then
      die "mint: parent $parent may not delegate (packet depth ignored)"
    fi
    depth=$((parent_depth + 1))
    may_delegate=0
  fi

  local run_id
  run_id="run-$(date +%s)-${RANDOM}"
  mkdir -p "$(orch_dir)/runs/${run_id}"
  cat >"$(orch_dir)/runs/${run_id}/meta" <<EOF
run_id=${run_id}
chain=${chain}
parent=${parent}
depth=${depth}
may_delegate=${may_delegate}
attempt=1
mode=${mode}
role=${role}
EOF
  journal_append "{\"ts\":\"$(now_iso)\",\"event\":\"mint\",\"run_id\":\"${run_id}\",\"chain\":\"$(json_escape "$chain")\",\"parent\":\"$(json_escape "$parent")\",\"depth\":${depth},\"may_delegate\":${may_delegate},\"mode\":\"$(json_escape "$mode")\"}"
  printf '%s\n' "$run_id"
}

# --- isolation --------------------------------------------------------------

isolation_ok() {
  local cwd="$1"
  (
    cd "$cwd" || exit 1
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 1
    local gd cdn
    gd="$(git rev-parse --git-dir)"
    cdn="$(git rev-parse --git-common-dir)"
    [[ "$gd" != "$cdn" ]]
  )
}

# --- launch -----------------------------------------------------------------

cmd_launch() {
  local agent="" mode="" task_id="" chain="" prompt_file="" cwd="" run_id="" attempt="1"
  local model="" effort="" allow_primary=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent) agent="${2:-}"; shift 2 ;;
      --mode) mode="${2:-}"; shift 2 ;;
      --task-id) task_id="${2:-}"; shift 2 ;;
      --chain) chain="${2:-}"; shift 2 ;;
      --prompt-file) prompt_file="${2:-}"; shift 2 ;;
      --cwd) cwd="${2:-}"; shift 2 ;;
      --run-id) run_id="${2:-}"; shift 2 ;;
      --attempt) attempt="${2:-}"; shift 2 ;;
      --model) model="${2:-}"; shift 2 ;;
      --effort) effort="${2:-}"; shift 2 ;;
      --allow-primary-checkout) allow_primary=1; shift ;;
      *) die "launch: unknown flag $1" ;;
    esac
  done
  [[ -n "$agent" && -n "$mode" && -n "$task_id" && -n "$chain" && -n "$prompt_file" ]] \
    || die "launch: --agent --mode --task-id --chain --prompt-file required"
  case "$agent" in
    claude|codex) ;;
    senpai) die "launch: refusing to launch senpai as a worker" ;;
    *) die "launch: agent must be claude|codex" ;;
  esac
  case "$mode" in
    implementation|independent_review) ;;
    *) die "launch: bad mode" ;;
  esac
  case "$task_id" in
    *[!A-Za-z0-9._-]*) die "launch: invalid task id" ;;
  esac
  [[ -f "$prompt_file" ]] || die "launch: prompt file missing"
  cwd="${cwd:-$(pwd)}"
  [[ -d "$cwd" ]] || die "launch: cwd missing"

  if [[ "$allow_primary" -ne 1 ]]; then
    if command -v git >/dev/null 2>&1 && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      isolation_ok "$cwd" || die "launch: worktree is not isolated (git-dir == git-common-dir); pass --allow-primary-checkout"
    else
      die "launch: cwd is not a git worktree; pass --allow-primary-checkout for sequential primary-checkout"
    fi
  fi

  if [[ -z "$run_id" ]]; then
    run_id="$(cmd_mint --chain "$chain" --mode "$mode")"
  else
    case "$run_id" in
      none) die "launch: refusing run id 'none' (pass --run-id or omit to mint)" ;;
      *[!A-Za-z0-9._-]*) die "launch: invalid run id" ;;
    esac
    [[ -d "$(orch_dir)/runs/${run_id}" ]] || die "launch: unknown run-id $run_id"
  fi

  ensure_dirs
  local stored_prompt bytes
  stored_prompt="$(orch_dir)/prompts/${task_id}.${attempt}.txt"
  cp "$prompt_file" "$stored_prompt"
  bytes="$(wc -c < "$stored_prompt" | tr -d ' ')"

  if [[ -z "$model" ]]; then
    if [[ "$agent" == "claude" ]]; then model="fable"; else model="gpt-5.6-sol"; fi
  fi
  if [[ -z "$effort" ]]; then
    if [[ "$agent" == "claude" ]]; then effort="high"; else effort="ultra"; fi
  fi

  local bin log_out log_err pid
  log_out="$(orch_dir)/logs/${task_id}.${attempt}.stdout"
  log_err="$(orch_dir)/logs/${task_id}.${attempt}.stderr"

  local -a argv
  if [[ "$agent" == "claude" ]]; then
    bin="${SENPAI_CLAUDE_BIN:-claude}"
    argv=("$bin" --model "$model" --effort "$effort" --output-format json --max-turns 40)
    if [[ "$mode" == "implementation" ]]; then
      argv+=(--permission-mode acceptEdits --allowedTools "Read,Edit,Write,Bash,Glob,Grep")
    else
      argv+=(--permission-mode plan --allowedTools "Read,Bash,Glob,Grep")
    fi
    # Always pass a path. Never interpolate packet bytes into the helper shell.
    argv+=(--prompt-file "$stored_prompt")
  else
    bin="${SENPAI_CODEX_BIN:-codex}"
    argv=("$bin" exec -m "$model" -c "model_reasoning_effort=${effort}")
    if [[ "$mode" == "implementation" ]]; then
      argv+=(--sandbox workspace-write)
    else
      argv+=(--sandbox read-only)
    fi
    argv+=(--prompt-file "$stored_prompt")
  fi

  command -v "$bin" >/dev/null 2>&1 || [[ -x "$bin" ]] || die "launch: binary not found: $bin"

  # argv dump for tests (NUL-delimited), never eval
  if [[ -n "${SENPAI_ARGV_OUT:-}" ]]; then
    : >"$SENPAI_ARGV_OUT"
    local a
    for a in "${argv[@]}"; do
      printf '%s\0' "$a" >>"$SENPAI_ARGV_OUT"
    done
  fi

  (
    cd "$cwd"
    "${argv[@]}" >"$log_out" 2>"$log_err"
  ) &
  pid=$!
  local start_token
  start_token="start-${pid}-$(date +%s)-${RANDOM}"
  mkdir -p "$(orch_dir)/runs/${run_id}"
  printf '%s\n' "$pid" >"$(orch_dir)/runs/${run_id}/pid"
  printf '%s\n' "$start_token" >"$(orch_dir)/runs/${run_id}/start_token"

  journal_append "{\"ts\":\"$(now_iso)\",\"event\":\"launch\",\"run_id\":\"$(json_escape "$run_id")\",\"task_id\":\"$(json_escape "$task_id")\",\"attempt\":${attempt},\"agent\":\"$(json_escape "$agent")\",\"mode\":\"$(json_escape "$mode")\",\"pid\":${pid},\"start_token\":\"$(json_escape "$start_token")\",\"prompt_bytes\":${bytes},\"cwd\":\"$(json_escape "$cwd")\"}"
  printf '%s\n' "$pid"
}

# --- collect ----------------------------------------------------------------

num_or_zero() {
  local v="${1:-0}"
  case "$v" in
    ''|*[!0-9.]*) echo 0 ;;
    *) echo "$v" ;;
  esac
}

usage_blank_party() {
  printf '%s\n' "uncached_input=0" "cache_read=0" "cache_write=0" "reasoning=0" "output=0" "cost=0"
}

usage_write_party_file() {
  local dest="$1"
  shift
  local uncached_input=0 cache_read=0 cache_write=0 reasoning=0 output=0 cost=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --uncached-input) uncached_input="$(num_or_zero "${2:-}")"; shift 2 ;;
      --cache-read) cache_read="$(num_or_zero "${2:-}")"; shift 2 ;;
      --cache-write) cache_write="$(num_or_zero "${2:-}")"; shift 2 ;;
      --reasoning) reasoning="$(num_or_zero "${2:-}")"; shift 2 ;;
      --output) output="$(num_or_zero "${2:-}")"; shift 2 ;;
      --cost) cost="$(num_or_zero "${2:-}")"; shift 2 ;;
      *) die "usage-record: unknown field $1" ;;
    esac
  done
  mkdir -p "$(dirname "$dest")"
  cat >"$dest" <<EOF
uncached_input=${uncached_input}
cache_read=${cache_read}
cache_write=${cache_write}
reasoning=${reasoning}
output=${output}
cost=${cost}
EOF
}

usage_field() {
  local file="$1" key="$2"
  if [[ -f "$file" ]]; then
    awk -F= -v k="$key" '$1==k {print $2; found=1} END {if (!found) print 0}' "$file"
  else
    echo 0
  fi
}

usage_add() {
  awk -v a="$1" -v b="$2" 'BEGIN { printf "%.10g\n", a+b }'
}

usage_rewrite_rollup() {
  local run_id="$1" task_id="$2" attempt="$3"
  local dir sfile wfile out
  dir="$(orch_dir)/runs/${run_id}"
  sfile="${dir}/party-senpai.env"
  wfile="${dir}/party-worker.env"
  [[ -f "$sfile" ]] || usage_write_party_file "$sfile"
  [[ -f "$wfile" ]] || usage_write_party_file "$wfile"
  out="${dir}/usage.json"
  local su sr sw srs so sc wu wr ww wrs wo wc
  su="$(usage_field "$sfile" uncached_input)"
  sr="$(usage_field "$sfile" cache_read)"
  sw="$(usage_field "$sfile" cache_write)"
  srs="$(usage_field "$sfile" reasoning)"
  so="$(usage_field "$sfile" output)"
  sc="$(usage_field "$sfile" cost)"
  wu="$(usage_field "$wfile" uncached_input)"
  wr="$(usage_field "$wfile" cache_read)"
  ww="$(usage_field "$wfile" cache_write)"
  wrs="$(usage_field "$wfile" reasoning)"
  wo="$(usage_field "$wfile" output)"
  wc="$(usage_field "$wfile" cost)"
  cat >"$out" <<EOF
{"run_id":"$(json_escape "$run_id")","task_id":"$(json_escape "$task_id")","attempt":$(num_or_zero "$attempt"),"currency":"USD","token_unit":"tokens","senpai":{"uncached_input":$(num_or_zero "$su"),"cache_read":$(num_or_zero "$sr"),"cache_write":$(num_or_zero "$sw"),"reasoning":$(num_or_zero "$srs"),"output":$(num_or_zero "$so"),"cost":$(num_or_zero "$sc")},"worker":{"uncached_input":$(num_or_zero "$wu"),"cache_read":$(num_or_zero "$wr"),"cache_write":$(num_or_zero "$ww"),"reasoning":$(num_or_zero "$wrs"),"output":$(num_or_zero "$wo"),"cost":$(num_or_zero "$wc")},"total":{"uncached_input":$(usage_add "$su" "$wu"),"cache_read":$(usage_add "$sr" "$wr"),"cache_write":$(usage_add "$sw" "$ww"),"reasoning":$(usage_add "$srs" "$wrs"),"output":$(usage_add "$so" "$wo"),"cost":$(usage_add "$sc" "$wc")}}
EOF
  printf '%s\n' "$out"
}

cmd_usage_record() {
  local run_id="" party="" task_id="" attempt="1"
  local uncached_input=0 cache_read=0 cache_write=0 reasoning=0 output=0 cost=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --run-id) run_id="${2:-}"; shift 2 ;;
      --party) party="${2:-}"; shift 2 ;;
      --task-id) task_id="${2:-}"; shift 2 ;;
      --attempt) attempt="${2:-}"; shift 2 ;;
      --uncached-input) uncached_input="$(num_or_zero "${2:-}")"; shift 2 ;;
      --cache-read) cache_read="$(num_or_zero "${2:-}")"; shift 2 ;;
      --cache-write) cache_write="$(num_or_zero "${2:-}")"; shift 2 ;;
      --reasoning) reasoning="$(num_or_zero "${2:-}")"; shift 2 ;;
      --output) output="$(num_or_zero "${2:-}")"; shift 2 ;;
      --cost) cost="$(num_or_zero "${2:-}")"; shift 2 ;;
      *) die "usage-record: unknown flag $1" ;;
    esac
  done
  [[ -n "$run_id" ]] || die "usage-record: --run-id required"
  case "$party" in
    senpai|worker) ;;
    *) die "usage-record: --party must be senpai|worker" ;;
  esac
  ensure_dirs
  mkdir -p "$(orch_dir)/runs/${run_id}"
  usage_write_party_file "$(orch_dir)/runs/${run_id}/party-${party}.env" \
    --uncached-input "$uncached_input" --cache-read "$cache_read" \
    --cache-write "$cache_write" --reasoning "$reasoning" \
    --output "$output" --cost "$cost"
  local line
  line="{\"ts\":\"$(now_iso)\",\"event\":\"usage\",\"run_id\":\"$(json_escape "$run_id")\",\"task_id\":\"$(json_escape "$task_id")\",\"attempt\":$(num_or_zero "$attempt"),\"party\":\"${party}\",\"uncached_input\":$(num_or_zero "$uncached_input"),\"cache_read\":$(num_or_zero "$cache_read"),\"cache_write\":$(num_or_zero "$cache_write"),\"reasoning\":$(num_or_zero "$reasoning"),\"output\":$(num_or_zero "$output"),\"cost\":$(num_or_zero "$cost")}"
  printf '%s\n' "$line" >>"$(orch_dir)/ledger.jsonl"
  journal_append "$line"
  usage_rewrite_rollup "$run_id" "$task_id" "$attempt" >/dev/null
}

cmd_usage_show() {
  local run_id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --run-id) run_id="${2:-}"; shift 2 ;;
      *) die "usage-show: unknown flag $1" ;;
    esac
  done
  ensure_dirs
  if [[ -n "$run_id" ]]; then
    [[ -f "$(orch_dir)/runs/${run_id}/usage.json" ]] || die "usage-show: no usage for $run_id"
    cat "$(orch_dir)/runs/${run_id}/usage.json"
    echo
    return 0
  fi
  [[ -f "$(orch_dir)/ledger.jsonl" ]] || die "usage-show: ledger empty"
  cat "$(orch_dir)/ledger.jsonl"
}

file_has_usage_payload() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  grep -qE '"usage"[[:space:]]*:|"uncached_input"[[:space:]]*:|"cost"[[:space:]]*:' "$f"
}

require_python_for_usage() {
  command -v python3 >/dev/null 2>&1 \
    || die "collect: usage present but python3 is missing; refusing to record \$0"
}

extract_usage_party() {
  # stdin unused; args: result.json party outfile
  local src="$1" party="$2" dest="$3"
  if ! command -v python3 >/dev/null 2>&1; then
    if file_has_usage_payload "$src"; then
      die "collect: usage present but python3 is missing; refusing to record \$0"
    fi
    return 1
  fi
  python3 - "$src" "$party" "$dest" <<'PY'
import json, sys
src, party, dest = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    data = json.load(open(src, encoding="utf-8"))
except Exception:
    sys.exit(1)
usage = data.get("usage") if isinstance(data.get("usage"), dict) else None
if usage is None and any(k in data for k in (
    "senpai", "worker", "uncached_input", "cache_read", "cache_write",
    "reasoning", "output", "cost",
)):
    usage = data
if not isinstance(usage, dict):
    sys.exit(2)
block = None
if isinstance(usage.get(party), dict):
    block = usage[party]
elif any(k in usage for k in (
    "uncached_input", "cache_read", "cache_write", "reasoning", "output", "cost"
)) and not isinstance(usage.get("senpai"), dict) and not isinstance(usage.get("worker"), dict):
    block = usage
else:
    sys.exit(3)
keys = ("uncached_input", "cache_read", "cache_write", "reasoning", "output", "cost")
with open(dest, "w", encoding="utf-8") as fh:
    for k in keys:
        v = block.get(k, 0)
        if v is None or v == "":
            v = 0
        fh.write(f"{k}={v}\n")
PY
}

cmd_collect() {
  local task_id="" attempt="" from="" run_id="" usage_path="" senpai_usage=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --task-id) task_id="${2:-}"; shift 2 ;;
      --attempt) attempt="${2:-}"; shift 2 ;;
      --from) from="${2:-}"; shift 2 ;;
      --run-id) run_id="${2:-}"; shift 2 ;;
      --usage) usage_path="${2:-}"; shift 2 ;;
      --senpai-usage) senpai_usage="${2:-}"; shift 2 ;;
      *) die "collect: unknown flag $1" ;;
    esac
  done
  [[ -n "$task_id" && -n "$attempt" && -n "$from" ]] || die "collect: --task-id --attempt --from required"
  [[ -f "$from" ]] || die "collect: source missing"
  ensure_dirs

  # framing only — no semantic schema parser. v1 and v2 both match task_id.
  grep -q '{' "$from" || die "collect: not JSON-shaped"
  grep -q '"task_id"' "$from" || die "collect: missing task_id"
  grep -q '"status"' "$from" || die "collect: missing status"
  if ! grep -Eq '"task_id"[[:space:]]*:[[:space:]]*"'"$task_id"'"' "$from"; then
    die "collect: task_id mismatch"
  fi
  if grep -q '"protocol_version"' "$from"; then
    if grep -q '"attempt"' "$from"; then
      grep -Eq '"attempt"[[:space:]]*:[[:space:]]*'"${attempt}"'([^0-9]|$)' "$from" \
        || die "collect: attempt mismatch (malformed v2)"
    fi
  fi

  if file_has_usage_payload "$from" \
    || { [[ -n "$usage_path" ]] && file_has_usage_payload "$usage_path"; } \
    || { [[ -n "$senpai_usage" ]] && file_has_usage_payload "$senpai_usage"; }; then
    require_python_for_usage
  fi

  local dest
  dest="$(orch_dir)/results/${task_id}.${attempt}.json"
  if [[ -e "$dest" ]]; then
    die "collect: result already published for ${task_id}.${attempt}; mint a new attempt"
  fi
  # atomic publish
  local tmp
  tmp="$(mktemp "$(orch_dir)/results/.tmp.XXXXXX")"
  cp "$from" "$tmp"
  mv "$tmp" "$dest"
  journal_append "{\"ts\":\"$(now_iso)\",\"event\":\"collect\",\"task_id\":\"$(json_escape "$task_id")\",\"attempt\":${attempt},\"path\":\"$(json_escape "$dest")\"}"

  # Same run ledger for senpai + worker usage.
  if [[ -z "$run_id" ]]; then
    run_id="task-${task_id}"
  fi
  local tmpu
  tmpu="$(mktemp "${TMPDIR:-/tmp}/senpai-usage.XXXXXX")"
  if [[ -n "$usage_path" && -f "$usage_path" ]]; then
    extract_usage_party "$usage_path" worker "${tmpu}.w" && cmd_usage_record \
      --run-id "$run_id" --party worker --task-id "$task_id" --attempt "$attempt" \
      --uncached-input "$(usage_field "${tmpu}.w" uncached_input)" \
      --cache-read "$(usage_field "${tmpu}.w" cache_read)" \
      --cache-write "$(usage_field "${tmpu}.w" cache_write)" \
      --reasoning "$(usage_field "${tmpu}.w" reasoning)" \
      --output "$(usage_field "${tmpu}.w" output)" \
      --cost "$(usage_field "${tmpu}.w" cost)"
    extract_usage_party "$usage_path" senpai "${tmpu}.s" && cmd_usage_record \
      --run-id "$run_id" --party senpai --task-id "$task_id" --attempt "$attempt" \
      --uncached-input "$(usage_field "${tmpu}.s" uncached_input)" \
      --cache-read "$(usage_field "${tmpu}.s" cache_read)" \
      --cache-write "$(usage_field "${tmpu}.s" cache_write)" \
      --reasoning "$(usage_field "${tmpu}.s" reasoning)" \
      --output "$(usage_field "${tmpu}.s" output)" \
      --cost "$(usage_field "${tmpu}.s" cost)"
  else
    extract_usage_party "$from" worker "${tmpu}.w" && cmd_usage_record \
      --run-id "$run_id" --party worker --task-id "$task_id" --attempt "$attempt" \
      --uncached-input "$(usage_field "${tmpu}.w" uncached_input)" \
      --cache-read "$(usage_field "${tmpu}.w" cache_read)" \
      --cache-write "$(usage_field "${tmpu}.w" cache_write)" \
      --reasoning "$(usage_field "${tmpu}.w" reasoning)" \
      --output "$(usage_field "${tmpu}.w" output)" \
      --cost "$(usage_field "${tmpu}.w" cost)"
    extract_usage_party "$from" senpai "${tmpu}.s" && cmd_usage_record \
      --run-id "$run_id" --party senpai --task-id "$task_id" --attempt "$attempt" \
      --uncached-input "$(usage_field "${tmpu}.s" uncached_input)" \
      --cache-read "$(usage_field "${tmpu}.s" cache_read)" \
      --cache-write "$(usage_field "${tmpu}.s" cache_write)" \
      --reasoning "$(usage_field "${tmpu}.s" reasoning)" \
      --output "$(usage_field "${tmpu}.s" output)" \
      --cost "$(usage_field "${tmpu}.s" cost)"
  fi
  if [[ -n "$senpai_usage" && -f "$senpai_usage" ]]; then
    extract_usage_party "$senpai_usage" senpai "${tmpu}.hs" || \
      extract_usage_party "$senpai_usage" worker "${tmpu}.hs"
    if [[ -f "${tmpu}.hs" ]]; then
      cmd_usage_record \
        --run-id "$run_id" --party senpai --task-id "$task_id" --attempt "$attempt" \
        --uncached-input "$(usage_field "${tmpu}.hs" uncached_input)" \
        --cache-read "$(usage_field "${tmpu}.hs" cache_read)" \
        --cache-write "$(usage_field "${tmpu}.hs" cache_write)" \
        --reasoning "$(usage_field "${tmpu}.hs" reasoning)" \
        --output "$(usage_field "${tmpu}.hs" output)" \
        --cost "$(usage_field "${tmpu}.hs" cost)"
    fi
  fi
  rm -f "$tmpu" "${tmpu}.w" "${tmpu}.s" "${tmpu}.hs"
  printf '%s\n' "$dest"
}

# --- snapshot / approve -----------------------------------------------------

cmd_snapshot() {
  local cwd="${PWD}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cwd) cwd="${2:-}"; shift 2 ;;
      *) die "snapshot: unknown flag $1" ;;
    esac
  done
  [[ -d "$cwd" ]] || die "snapshot: cwd missing"
  git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die "snapshot: not a git repository"
  local base idx tree
  base="$(git -C "$cwd" rev-parse HEAD 2>/dev/null || echo "UNBORN")"
  idx="$(mktemp "${TMPDIR:-/tmp}/senpai-index.XXXXXX")"
  # start from HEAD if it exists so we don't lose committed files
  if git -C "$cwd" rev-parse --verify HEAD >/dev/null 2>&1; then
    GIT_INDEX_FILE="$idx" git -C "$cwd" read-tree HEAD
  fi
  GIT_INDEX_FILE="$idx" git -C "$cwd" add -A
  tree="$(GIT_INDEX_FILE="$idx" git -C "$cwd" write-tree)"
  rm -f "$idx"
  printf '%s %s\n' "$base" "$tree"
  journal_append "{\"ts\":\"$(now_iso)\",\"event\":\"snapshot\",\"base_oid\":\"$(json_escape "$base")\",\"tree_oid\":\"$(json_escape "$tree")\"}"
}

cmd_approve() {
  local base="" tree="" host_session="" cwd="${PWD}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --base) base="${2:-}"; shift 2 ;;
      --tree) tree="${2:-}"; shift 2 ;;
      --host-session) host_session="${2:-}"; shift 2 ;;
      --cwd) cwd="${2:-}"; shift 2 ;;
      *) die "approve: unknown flag $1" ;;
    esac
  done
  [[ -n "$base" && -n "$tree" ]] || die "approve: --base and --tree required"
  # recompute
  local got_base got_tree
  read -r got_base got_tree < <(cmd_snapshot --cwd "$cwd" | tail -n 1)
  # cmd_snapshot also journals; compare both halves of Gate 6
  if [[ "$got_base" != "$base" ]]; then
    die "approve: base mismatch (recorded ${base}, current ${got_base})"
  fi
  if [[ "$got_tree" != "$tree" ]]; then
    die "approve: tree mismatch (recorded ${tree}, current ${got_tree})"
  fi
  journal_append "{\"ts\":\"$(now_iso)\",\"event\":\"approve\",\"base_oid\":\"$(json_escape "$base")\",\"tree_oid\":\"$(json_escape "$tree")\",\"host_session\":\"$(json_escape "$host_session")\"}"
  printf 'approved %s %s\n' "$base" "$tree"
}

cmd_import() {
  local src dest_bak
  src="$(orch_dir)/state.md"
  [[ -f "$src" ]] || die "import: no state.md"
  ensure_dirs
  dest_bak="$(orch_dir)/state.md.pre-v2"
  if [[ ! -f "$dest_bak" ]]; then
    cp "$src" "$dest_bak"
  fi
  local task agent role model pid
  # shellcheck disable=SC2034
  while IFS='|' read -r _ task agent role model _ _ _ status _ _ _ _ _ _ pid _; do
    task="$(printf '%s' "$task" | sed 's/^ *//;s/ *$//')"
    agent="$(printf '%s' "$agent" | sed 's/^ *//;s/ *$//')"
    role="$(printf '%s' "$role" | sed 's/^ *//;s/ *$//')"
    model="$(printf '%s' "$model" | sed 's/^ *//;s/ *$//')"
    pid="$(printf '%s' "$pid" | sed 's/^ *//;s/ *$//')"
    status="$(printf '%s' "$status" | sed 's/^ *//;s/ *$//')"
    [[ -n "$task" && "$task" != "Task ID" && "$task" != "---------" ]] || continue
    mkdir -p "$(orch_dir)/runs/legacy-${task}"
    cat >"$(orch_dir)/runs/legacy-${task}/meta" <<EOF
run_id=legacy-${task}
chain=${task}
parent=
depth=0
may_delegate=0
legacy=1
resumable=0
attempt=1
mode=implementation
role=${role}
agent=${agent}
model=${model}
pid=${pid}
status=${status}
EOF
    journal_append "{\"ts\":\"$(now_iso)\",\"event\":\"import\",\"task_id\":\"$(json_escape "$task")\",\"legacy\":true,\"resumable\":false,\"agent\":\"$(json_escape "$agent")\",\"role\":\"$(json_escape "$role")\"}"
  done <"$src"
  printf 'journal\n' >"$(orch_dir)/sot"
  journal_append "{\"ts\":\"$(now_iso)\",\"event\":\"sot\",\"value\":\"journal\"}"
  echo "imported; source of truth is journal; backup $dest_bak"
}

cmd_doctor() {
  local root sum skill
  root="$(resolve_control_root)"
  CONTROL_ROOT="$root"
  [[ -x "$(orch_dir)/senpai.sh" ]] || die "doctor: helper missing"
  sum="$(cksum "$(orch_dir)/senpai.sh" | awk '{print $1}')"
  echo "control-root: $root"
  echo "helper-checksum: $sum"
  local ok=0
  for skill in \
    "$root/.grok/skills/senpai/SKILL.md" \
    "$root/.agents/skills/senpai/SKILL.md" \
    "$root/.claude/skills/senpai/SKILL.md"
  do
    if [[ -f "$skill" ]] && grep -q "senpai-managed:checksum=${sum}" "$skill"; then
      echo "ok  $skill"
    else
      echo "BAD $skill"
      ok=1
    fi
  done
  return "$ok"
}

cmd_status() { cmd_render; }

cmd_cleanup() {
  local chain=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --chain) chain="${2:-}"; shift 2 ;;
      *) die "cleanup: unknown flag $1" ;;
    esac
  done
  [[ -n "$chain" ]] || die "cleanup: --chain required"
  local d
  d="$(lock_dir_for "$chain")"
  [[ -d "$d" ]] || { echo "no lock"; return 0; }
  local pid
  local start
  pid="$(cat "$d/pid" 2>/dev/null || true)"
  start="$(cat "$d/pid_start" 2>/dev/null || true)"
  if pid_is_holder "$pid" "$start"; then
    die "cleanup: pid $pid still live"
  fi
  rm -rf "$d"
  journal_append "{\"ts\":\"$(now_iso)\",\"event\":\"cleanup\",\"chain\":\"$(json_escape "$chain")\"}"
  echo "removed lock $chain"
}

cmd_render() {
  ensure_dirs
  local out
  out="$(orch_dir)/state.generated.md"
  {
    echo "# Orchestration State (generated)"
    echo
    echo "<!-- generated by senpai.sh render; do not edit -->"
    echo
    if [[ -f "$(orch_dir)/sot" ]]; then
      echo "Source of truth: \`$(cat "$(orch_dir)/sot")\`"
    else
      echo "Source of truth: \`state.md\` (journal is shadow evidence until \`senpai.sh import\`)."
    fi
    echo
    echo "| run_id | chain | role | depth | legacy | resumable |"
    echo "|--------|-------|------|-------|--------|-----------|"
    local d rid chain role depth legacy resumable
    for d in "$(orch_dir)"/runs/*/meta; do
      [[ -f "$d" ]] || continue
      rid="$(awk -F= '/^run_id=/{print $2}' "$d")"
      chain="$(awk -F= '/^chain=/{print $2}' "$d")"
      role="$(awk -F= '/^role=/{print $2}' "$d")"
      depth="$(awk -F= '/^depth=/{print $2}' "$d")"
      legacy="$(awk -F= '/^legacy=/{print $2}' "$d")"
      resumable="$(awk -F= '/^resumable=/{print $2}' "$d")"
      echo "| ${rid} | ${chain} | ${role} | ${depth:-0} | ${legacy:-0} | ${resumable:-1} |"
    done
    echo
    if [[ -f "$(orch_dir)/journal.jsonl" ]]; then
      echo "## Journal tail"
      echo
      echo '```'
      tail -n 20 "$(orch_dir)/journal.jsonl"
      echo '```'
    fi
  } >"$out"
  if [[ -f "$(orch_dir)/sot" && "$(cat "$(orch_dir)/sot")" == "journal" ]]; then
    cp "$out" "$(orch_dir)/state.md"
  fi
  printf '%s\n' "$out"
}

# --- main -------------------------------------------------------------------

[[ $# -ge 1 ]] || usage
VERB="$1"
shift

case "$VERB" in
  control-root)
    CONTROL_ROOT="$(resolve_control_root)"
    printf '%s\n' "$CONTROL_ROOT"
    ;;
  checksum)
    helper_checksum
    ;;
  lock|mint|launch|collect|snapshot|approve|render|import|doctor|status|cleanup)
    CONTROL_ROOT="$(resolve_control_root)"
    export CONTROL_ROOT
    "cmd_${VERB}" "$@"
    ;;
  usage-record)
    CONTROL_ROOT="$(resolve_control_root)"
    export CONTROL_ROOT
    cmd_usage_record "$@"
    ;;
  usage-show)
    CONTROL_ROOT="$(resolve_control_root)"
    export CONTROL_ROOT
    cmd_usage_show "$@"
    ;;
  -h|--help|help) usage ;;
  *) die "unknown verb: $VERB" ;;
esac
