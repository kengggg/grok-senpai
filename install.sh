#!/usr/bin/env bash
# install.sh — install grok-senpai into an existing project
#
# Usage:
#   ./install.sh                 # install into current directory
#   ./install.sh /path/to/app    # install into target project
#
# Safe to re-run (idempotent). Bash + coreutils only.

set -euo pipefail

MARKER_START="<!-- grok-senpai:playbook:start -->"
MARKER_END="<!-- grok-senpai:playbook:end -->"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
SOURCE_GROK="${SCRIPT_DIR}/.grok"
SOURCE_AGENTS="${SCRIPT_DIR}/AGENTS.md"

TARGET_ARG="${1:-.}"
if [[ ! -d "$TARGET_ARG" ]]; then
  echo "error: target directory does not exist: $TARGET_ARG" >&2
  exit 1
fi
TARGET="$(cd "$TARGET_ARG" && pwd)"

if [[ ! -d "$SOURCE_GROK" ]]; then
  echo "error: cannot find .grok next to install.sh (${SOURCE_GROK})" >&2
  echo "       run this script from a grok-senpai checkout." >&2
  exit 1
fi
if [[ ! -f "$SOURCE_AGENTS" ]]; then
  echo "error: cannot find AGENTS.md next to install.sh (${SOURCE_AGENTS})" >&2
  exit 1
fi

SUMMARY=()
summary() { SUMMARY+=("$*"); }

# Playbook body: from "## Multi-Agent Orchestration Playbook" to EOF
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

install_grok() {
  local dest="${TARGET}/.grok"
  mkdir -p "${dest}/skills" "${dest}/orchestration"

  if [[ -d "${SOURCE_GROK}/skills" ]]; then
    cp -R "${SOURCE_GROK}/skills/." "${dest}/skills/"
    summary "Updated .grok/skills/ (claude-worker, codex-worker)"
  fi

  for f in TASK_PACKET.template.md RESULT_PACKET.template.md; do
    if [[ -f "${SOURCE_GROK}/orchestration/${f}" ]]; then
      cp "${SOURCE_GROK}/orchestration/${f}" "${dest}/orchestration/${f}"
    fi
  done
  summary "Updated .grok/orchestration packet templates"

  if [[ -f "${dest}/orchestration/state.md" ]]; then
    summary "Kept existing .grok/orchestration/state.md"
  else
    if [[ -f "${SOURCE_GROK}/orchestration/state.md" ]]; then
      cp "${SOURCE_GROK}/orchestration/state.md" "${dest}/orchestration/state.md"
    else
      cat > "${dest}/orchestration/state.md" <<'EOF'
# Orchestration State (grok-senpai)

| Task ID | Agent | Worktree Path | Branch | Status | Result Packet | Notes |
|---------|-------|---------------|--------|--------|---------------|-------|
|         |       |               |        |        |               |       |
EOF
    fi
    summary "Created .grok/orchestration/state.md"
  fi
}

# Replace lines between markers (inclusive) with new block; print rest unchanged.
replace_marked_block() {
  local src="$1"
  local block_file="$2"
  local out="$3"
  awk -v start="$MARKER_START" -v end="$MARKER_END" -v bf="$block_file" '
    BEGIN {
      while ((getline line < bf) > 0) {
        blk = blk line ORS
      }
      close(bf)
    }
    $0 == start { print blk; skip = 1; next }
    skip && $0 == end { skip = 0; next }
    skip { next }
    { print }
  ' "$src" > "$out"
}

# Drop from playbook heading through EOF (unmarked prior install).
strip_unmarked_playbook() {
  local src="$1"
  local out="$2"
  awk '/^## Multi-Agent Orchestration Playbook/ { exit } { print }' "$src" > "$out"
}

merge_agents() {
  local agents="${TARGET}/AGENTS.md"
  local claude="${TARGET}/CLAUDE.md"
  local block_file
  local tmp rest

  block_file="$(mktemp)"
  tmp="$(mktemp)"
  rest="$(mktemp)"
  # shellcheck disable=SC2064
  trap 'rm -f "$block_file" "$tmp" "$rest"' RETURN

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
        # Ensure separation if file had content before the heading
        if [[ -s "$rest" ]] && [[ -n "$(tail -c1 "$rest" 2>/dev/null || true)" ]]; then
          printf '\n'
        fi
        cat "$block_file"
      } > "$tmp"
      mv "$tmp" "$agents"
      summary "Replaced unmarked playbook in AGENTS.md and added markers"
      return
    fi

    # Exists, no playbook yet: prepend marked block
    {
      cat "$block_file"
      printf '\n'
      cat "$agents"
    } > "$tmp"
    mv "$tmp" "$agents"
    summary "Prepended playbook to existing AGENTS.md"
    return
  fi

  # No AGENTS.md
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
echo "  source: $SCRIPT_DIR"
echo "  target: $TARGET"
echo

install_grok
merge_agents

echo
echo "=== Summary ==="
for line in "${SUMMARY[@]}"; do
  echo "  • $line"
done
echo
echo "Next: open Grok Build in the target project and describe your goal."
echo "      You approve final diffs; Grok runs the playbook."
