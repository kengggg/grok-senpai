#!/usr/bin/env bash
# install.sh — install grok-senpai into a project
#
# Usage (local checkout):
#   ./install.sh                 # install into current directory
#   ./install.sh /path/to/app    # install into target project
#
# Usage (one-liner, no clone needed):
#   curl -sL https://raw.githubusercontent.com/kengggg/grok-senpai/main/install.sh | bash
#   curl -sL https://raw.githubusercontent.com/kengggg/grok-senpai/main/install.sh | bash -s -- /path/to/project
#
# Optional:
#   GROK_SENPAI_REF=main   # branch or tag when downloading (default: main)
#
# Safe to re-run (idempotent). Needs bash, curl, tar, and common coreutils.

set -euo pipefail

MARKER_START="<!-- grok-senpai:playbook:start -->"
MARKER_END="<!-- grok-senpai:playbook:end -->"

REPO_SLUG="kengggg/grok-senpai"
REF="${GROK_SENPAI_REF:-main}"

TARGET_ARG="${1:-.}"
if [[ "$TARGET_ARG" == --* ]]; then
  echo "error: installer does not take flags; pass a target directory (got ${TARGET_ARG})" >&2
  echo "hint: --host is reserved until option parsing lands; today \$1 is the target path" >&2
  exit 1
fi
if [[ ! -d "$TARGET_ARG" ]]; then
  echo "error: target directory does not exist: $TARGET_ARG" >&2
  exit 1
fi
TARGET="$(cd "$TARGET_ARG" && pwd)"

SUMMARY=()
summary() { SUMMARY+=("$*"); }

DOWNLOAD_DIR=""
TEMP_FILES=()

cleanup() {
  local f
  for f in "${TEMP_FILES[@]:-}"; do
    rm -f "$f" 2>/dev/null || true
  done
  if [[ -n "${DOWNLOAD_DIR}" && -d "${DOWNLOAD_DIR}" ]]; then
    rm -rf "${DOWNLOAD_DIR}"
  fi
}
trap cleanup EXIT

mktemp_tracked() {
  local t
  t="$(mktemp)"
  TEMP_FILES+=("$t")
  printf '%s\n' "$t"
}

# Set SOURCE_ROOT to a directory that contains .grok/ and AGENTS.md
resolve_source() {
  local script_dir candidate

  # 1) Local execution with pack beside the script
  if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -d "${script_dir}/.grok" && -f "${script_dir}/AGENTS.md" ]]; then
      SOURCE_ROOT="$script_dir"
      summary "Using local pack at ${SOURCE_ROOT}"
      return 0
    fi
  fi

  # 2) Remote: download pack tarball (curl one-liner / missing local assets)
  if ! command -v curl >/dev/null 2>&1; then
    echo "error: curl is required to download grok-senpai" >&2
    exit 1
  fi
  if ! command -v tar >/dev/null 2>&1; then
    echo "error: tar is required to unpack grok-senpai" >&2
    exit 1
  fi

  DOWNLOAD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/grok-senpai.XXXXXX")"
  echo "Downloading grok-senpai@${REF} …"

  if ! curl -fsSL "https://github.com/${REPO_SLUG}/archive/refs/heads/${REF}.tar.gz" \
      | tar -xz -C "$DOWNLOAD_DIR" 2>/dev/null; then
    if ! curl -fsSL "https://github.com/${REPO_SLUG}/archive/refs/tags/${REF}.tar.gz" \
        | tar -xz -C "$DOWNLOAD_DIR"; then
      echo "error: failed to download pack for ref '${REF}'" >&2
      exit 1
    fi
  fi

  candidate="$(find "$DOWNLOAD_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  if [[ -z "$candidate" || ! -d "${candidate}/.grok" || ! -f "${candidate}/AGENTS.md" ]]; then
    echo "error: downloaded archive missing .grok/ or AGENTS.md" >&2
    exit 1
  fi

  SOURCE_ROOT="$candidate"
  summary "Downloaded pack ${REPO_SLUG}@${REF}"
}

SOURCE_ROOT=""
resolve_source
SOURCE_GROK="${SOURCE_ROOT}/.grok"
SOURCE_AGENTS="${SOURCE_ROOT}/AGENTS.md"

extract_playbook() {
  awk '
    /^## Multi-Agent Orchestration Playbook/ { found = 1 }
    found { print }
  ' "$SOURCE_AGENTS"
}

build_playbook_block() {
  printf '%s\n\n' "$MARKER_START"
  extract_playbook
  printf '\n%s\n' "$MARKER_END"
}

ensure_ignore_line() {
  local ignore_file="$1" pattern="$2"
  if ! grep -qxF "$pattern" "$ignore_file"; then
    printf '%s\n' "$pattern" >>"$ignore_file"
    return 0
  fi
  return 1
}

ensure_logs_ignored() {
  local ignore_file="${TARGET}/.gitignore"
  local changed=false

  if [[ ! -f "$ignore_file" ]]; then
    : > "$ignore_file"
  fi
  [[ -s "$ignore_file" ]] || true
  local p
  for p in \
    ".grok/orchestration/logs/*" \
    "!.grok/orchestration/logs/.gitkeep" \
    ".grok/orchestration/journal.jsonl" \
    ".grok/orchestration/ledger.jsonl" \
    ".grok/orchestration/locks/" \
    ".grok/orchestration/runs/" \
    ".grok/orchestration/results/" \
    ".grok/orchestration/prompts/" \
    ".grok/orchestration/state.generated.md"
  do
    if ensure_ignore_line "$ignore_file" "$p"; then
      changed=true
    fi
  done

  if [[ "$changed" == true ]]; then
    summary "Added helper/journal ignore rules to .gitignore"
  else
    summary "Kept existing helper/journal ignore rules in .gitignore"
  fi
}

helper_checksum() {
  cksum "${SOURCE_GROK}/orchestration/senpai.sh" | awk '{print $1}'
}

is_managed_skill() {
  local f="$1"
  [[ -f "$f" ]] && grep -q '<!-- senpai-managed:checksum=' "$f"
}

preflight() {
  local dest skill
  if [[ -z "${GROK_SENPAI_FORCE:-}" && -f "${TARGET}/.grok/orchestration/state.md" ]]; then
    local pid
    while IFS= read -r pid; do
      if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        echo "error: live worker pid $pid recorded in state.md; refuse to overwrite (GROK_SENPAI_FORCE=1 to override)" >&2
        exit 1
      fi
    done < <(awk -F'|' 'NR>3 { pid=$16; gsub(/ /,"",pid); if (pid ~ /^[0-9]+$/) print pid }' \
      "${TARGET}/.grok/orchestration/state.md")
  fi

  for dest in \
    "${TARGET}/.grok/skills/senpai/SKILL.md" \
    "${TARGET}/.agents/skills/senpai/SKILL.md" \
    "${TARGET}/.claude/skills/senpai/SKILL.md"
  do
    if [[ -e "$dest" ]] && ! is_managed_skill "$dest"; then
      echo "error: unowned skill at $dest (missing senpai-managed marker); aborting with no writes" >&2
      exit 1
    fi
  done
}

install_senpai_skills() {
  local sum src dest dests
  [[ -f "${SOURCE_GROK}/orchestration/senpai.sh" ]] || return 0
  sum="$(helper_checksum)"
  src="${SOURCE_GROK}/skills/senpai/SKILL.md"
  [[ -f "$src" ]] || return 0
  dests=(
    "${TARGET}/.grok/skills/senpai/SKILL.md"
    "${TARGET}/.agents/skills/senpai/SKILL.md"
    "${TARGET}/.claude/skills/senpai/SKILL.md"
  )
  local d
  for d in "${dests[@]}"; do
    mkdir -p "$(dirname "$d")"
    sed "s/checksum=HELPER/checksum=${sum}/g; s/checksum=[A-Za-z0-9]*/checksum=${sum}/" \
      "$src" >"$d"
  done
  summary "Installed senpai host skill at three discovery roots (checksum ${sum})"
}

ensure_claude_md() {
  local claude="${TARGET}/CLAUDE.md"
  if [[ -f "$claude" ]]; then
    summary "Kept existing CLAUDE.md"
    return 0
  fi
  cat >"$claude" <<'EOF'
# CLAUDE.md

This project uses **grok-senpai**. The canonical playbook lives in `AGENTS.md`.

Claude Code may be the senpai **host** (experimental until conformance) via `.claude/skills/senpai/`, or a **worker** via `.grok/skills/claude-worker/`. Launch workers only through `.grok/orchestration/senpai.sh` — never `eval`.
EOF
  summary "Created CLAUDE.md pointing at AGENTS.md"
}

install_grok() {
  local dest="${TARGET}/.grok"
  local keep_dir
  mkdir -p "${dest}/skills" "${dest}/orchestration"

  if [[ -f "${SOURCE_GROK}/orchestration/senpai.sh" ]]; then
    cp "${SOURCE_GROK}/orchestration/senpai.sh" "${dest}/orchestration/senpai.sh"
    chmod +x "${dest}/orchestration/senpai.sh"
    summary "Updated .grok/orchestration/senpai.sh"
  fi

  if [[ -d "${SOURCE_GROK}/skills" ]]; then
    cp -R "${SOURCE_GROK}/skills/." "${dest}/skills/"
    summary "Updated .grok/skills/ (senpai, claude-worker, codex-worker)"
  fi
  install_senpai_skills

  for f in TASK_PACKET.template.md RESULT_PACKET.template.md REVIEW_PACKET.template.md; do
    if [[ -f "${SOURCE_GROK}/orchestration/${f}" ]]; then
      cp "${SOURCE_GROK}/orchestration/${f}" "${dest}/orchestration/${f}"
    fi
  done
  # Ensure durable handoff and gitignored worker-log directories exist.
  mkdir -p "${dest}/orchestration/reviews" "${dest}/orchestration/logs"
  for keep_dir in reviews logs; do
    if [[ ! -f "${dest}/orchestration/${keep_dir}/.gitkeep" ]]; then
      : > "${dest}/orchestration/${keep_dir}/.gitkeep"
    fi
  done
  summary "Updated .grok/orchestration packet templates (Task/Result/Review)"
  summary "Ensured .grok/orchestration reviews/ and logs/ directories"
  ensure_logs_ignored

  # Always refresh documented example config
  if [[ -f "${SOURCE_GROK}/orchestration/worker-config.example.toml" ]]; then
    cp "${SOURCE_GROK}/orchestration/worker-config.example.toml" \
      "${dest}/orchestration/worker-config.example.toml"
    summary "Updated .grok/orchestration/worker-config.example.toml"
  fi

  # Always refresh the documented alias example.
  if [[ -f "${SOURCE_GROK}/orchestration/model-aliases.example.toml" ]]; then
    cp "${SOURCE_GROK}/orchestration/model-aliases.example.toml" \
      "${dest}/orchestration/model-aliases.example.toml"
    summary "Updated .grok/orchestration/model-aliases.example.toml"
  fi

  # Project model-aliases.toml: create if missing; never overwrite local mappings.
  if [[ -f "${dest}/orchestration/model-aliases.toml" ]]; then
    summary "Kept existing .grok/orchestration/model-aliases.toml (project aliases win)"
  else
    if [[ -f "${SOURCE_GROK}/orchestration/model-aliases.toml" ]]; then
      cp "${SOURCE_GROK}/orchestration/model-aliases.toml" \
        "${dest}/orchestration/model-aliases.toml"
    elif [[ -f "${SOURCE_GROK}/orchestration/model-aliases.example.toml" ]]; then
      cp "${SOURCE_GROK}/orchestration/model-aliases.example.toml" \
        "${dest}/orchestration/model-aliases.toml"
    fi
    summary "Created .grok/orchestration/model-aliases.toml"
  fi

  # Project worker-config.toml: create if missing; never overwrite (project customizations)
  if [[ -f "${dest}/orchestration/worker-config.toml" ]]; then
    summary "Kept existing .grok/orchestration/worker-config.toml (edit to change defaults)"
  else
    if [[ -f "${SOURCE_GROK}/orchestration/worker-config.toml" ]]; then
      cp "${SOURCE_GROK}/orchestration/worker-config.toml" \
        "${dest}/orchestration/worker-config.toml"
    elif [[ -f "${SOURCE_GROK}/orchestration/worker-config.example.toml" ]]; then
      cp "${SOURCE_GROK}/orchestration/worker-config.example.toml" \
        "${dest}/orchestration/worker-config.toml"
    fi
    summary "Created .grok/orchestration/worker-config.toml (Fable/high, Sol/ultra)"
  fi

  if [[ -f "${dest}/orchestration/state.md" ]]; then
    summary "Kept existing .grok/orchestration/state.md"
  else
    if [[ -f "${SOURCE_GROK}/orchestration/state.md" ]]; then
      cp "${SOURCE_GROK}/orchestration/state.md" "${dest}/orchestration/state.md"
    else
      cat > "${dest}/orchestration/state.md" <<'EOF'
# Orchestration State (grok-senpai)

| Task ID | Agent | Role | Model | Effort | Worktree Path | Branch | Status | Phase | Started | Last heartbeat | Last signal | Result Packet | Log | PID | Notes |
|---------|-------|------|-------|--------|---------------|--------|--------|-------|---------|----------------|-------------|---------------|-----|-----|-------|
|         |       |      |       |        |               |        |        |       |         |                |             |               |     |     |       |
EOF
    fi
    summary "Created .grok/orchestration/state.md"
  fi
}

replace_marked_block() {
  local src="$1" block_file="$2" out="$3"
  awk -v start="$MARKER_START" -v end="$MARKER_END" -v bf="$block_file" '
    BEGIN {
      while ((getline line < bf) > 0) blk = blk line ORS
      close(bf)
    }
    $0 == start { print blk; skip = 1; next }
    skip && $0 == end { skip = 0; next }
    skip { next }
    { print }
  ' "$src" > "$out"
}

strip_unmarked_playbook() {
  awk '/^## Multi-Agent Orchestration Playbook/ { exit } { print }' "$1" > "$2"
}

merge_agents() {
  local agents="${TARGET}/AGENTS.md"
  local claude="${TARGET}/CLAUDE.md"
  local block_file tmp rest

  block_file="$(mktemp_tracked)"
  tmp="$(mktemp_tracked)"
  rest="$(mktemp_tracked)"

  build_playbook_block > "$block_file"

  if [[ -f "$agents" ]]; then
    if grep -qF "$MARKER_START" "$agents" && grep -qF "$MARKER_END" "$agents"; then
      replace_marked_block "$agents" "$block_file" "$tmp"
      mv "$tmp" "$agents"
      summary "Refreshed playbook block in existing AGENTS.md (markers)"
      return
    fi

    if grep -qE '^## Multi-Agent Orchestration Playbook' "$agents"; then
      strip_unmarked_playbook "$agents" "$rest"
      {
        cat "$rest"
        if [[ -s "$rest" ]]; then printf '\n'; fi
        cat "$block_file"
      } > "$tmp"
      mv "$tmp" "$agents"
      summary "Replaced unmarked playbook in AGENTS.md and added markers"
      return
    fi

    # Exists, no playbook: prepend (near top)
    {
      cat "$block_file"
      printf '\n'
      cat "$agents"
    } > "$tmp"
    mv "$tmp" "$agents"
    summary "Prepended playbook to existing AGENTS.md"
    return
  fi

  if [[ -f "$claude" ]]; then
    {
      cat <<'EOF'
# Project agents

> **Note:** This project also has `CLAUDE.md`. Grok Build loads **AGENTS.md** for project instructions; Claude Code may still use `CLAUDE.md`. Keep them complementary, or point one at the other.

EOF
      cat "$block_file"
      printf '\n'
    } > "$agents"
    summary "Created AGENTS.md with playbook (noted existing CLAUDE.md)"
  else
    {
      cat <<'EOF'
# AGENTS.md

EOF
      cat "$block_file"
      printf '\n'
    } > "$agents"
    summary "Created fresh AGENTS.md with playbook"
  fi
}

echo "grok-senpai install"
echo "  target: $TARGET"
echo

preflight
install_grok
merge_agents
ensure_claude_md

echo
echo "=== Summary ==="
for line in "${SUMMARY[@]}"; do
  echo "  • $line"
done
echo
echo "Next steps:"
echo "  1. Open Grok Build, Claude Code, or Codex CLI in: $TARGET"
echo "  2. Describe your goal in plain language."
echo "  3. The senpai host follows the playbook; you only approve final diffs."
echo "  4. Non-Grok hosts are experimental until the conformance suite passes."
