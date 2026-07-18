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

install_grok
merge_agents

echo
echo "=== Summary ==="
for line in "${SUMMARY[@]}"; do
  echo "  • $line"
done
echo
echo "Next steps:"
echo "  1. Open Grok Build in: $TARGET"
echo "  2. Describe your goal in plain language."
echo "  3. Grok follows the playbook; you only approve final diffs."
