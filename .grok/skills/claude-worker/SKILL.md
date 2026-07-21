name: claude-worker
description: >
  Deep-reasoning worker for architecture, complex multi-file changes, high-stakes
  planning, and independent review in grok-senpai. Always runs headlessly inside
  a dedicated worktree. Defaults: Claude Fable + effort max (overridable via Task Packet).

You are launching Claude Code as a specialized deep-reasoning worker under the
**grok-senpai** Grok orchestrator. Follow AGENTS.md playbook rules.

## Defaults (unless Task Packet overrides)

| Setting | Default | Config key |
|---------|---------|------------|
| Model | `fable` (Claude Fable; aliases: `claude-fable-5`, `claude-fable-5[1m]`) | `.grok/orchestration/worker-config.toml` → `[claude].model` |
| Effort | `max` | `[claude].effort` (`low` \| `medium` \| `high` \| `xhigh` \| `max`) |

Read `.grok/orchestration/worker-config.toml` if present. Task Packet fields win when policy allows:

```yaml
worker_model: fable         # optional override (e.g. claude-fable-5)
worker_effort: high         # optional override (see AGENTS.md effort routing)
```

If `policy.enforce_floors` is true, do not set effort below `min_effort_claude` (default `high`).

## Preconditions

- A dedicated worktree has already been prepared (prefer Grok-native). **Refuse** if Worktree Path is missing or is the primary checkout for non-trivial work.
- You have a complete Task Packet (see `.grok/orchestration/TASK_PACKET.template.md`).
- For **independent_review** mode: a Review Packet must exist (`.grok/orchestration/reviews/<task_id>.md` or path in Task Packet). Refuse review without it for non-trivial tasks.

## Worktree hard rules

Before any edit, verify isolation (example):

```bash
cd "<Worktree Path>"
# Linked worktree: git-dir != git-common-dir (and not a submodule)
git rev-parse --git-dir
git rev-parse --git-common-dir
```

If not isolated and the Task Packet did not mark `allow_primary_checkout: true`, stop and return `failed` with open_questions.

## How to invoke

Always use headless mode with safety rails. **Always pass model + effort explicitly.**

### Implementation mode

```bash
MODEL="${WORKER_MODEL:-fable}"
EFFORT="${WORKER_EFFORT:-max}"

cd "<Worktree Path>" && claude \
  --model "$MODEL" \
  --effort "$EFFORT" \
  -p "$(cat <<'EOF'
[Insert full Task Packet here]
Additional instructions:

First read AGENTS.md / CLAUDE.md if present.
Stay strictly within the stated scope and acceptance criteria.
Prefer minimal, high-quality changes that follow existing patterns.
Run the verification_commands listed in the Task Packet.
When finished, write a Review Packet to .grok/orchestration/reviews/<task_id>.md
(see REVIEW_PACKET.template.md) including git status, git diff --stat, and verification table.
Then output ONLY a Result Packet in the exact format below.
Do not add extra commentary outside the packet.
EOF
)" \
  --output-format json \
  --max-turns 40 \
  --permission-mode acceptEdits \
  --allowedTools "Read,Edit,Write,Bash,Glob,Grep"
```

### Independent review mode (read-only intent)

```bash
MODEL="${WORKER_MODEL:-fable}"
EFFORT="${WORKER_EFFORT:-max}"

cd "<Worktree Path>" && claude \
  --model "$MODEL" \
  --effort "$EFFORT" \
  -p "$(cat <<'EOF'
[Insert Task Packet + full Review Packet here]
Additional instructions:

You are the independent reviewer (opposite model of the implementer).
Do NOT implement features. Prefer not to edit production code.
Read the Review Packet, run git diff / listed verification if needed.
Focus on the reviewer checklist in the Review Packet.
When finished, output ONLY a Result Packet (review findings in summary/risks/open_questions).
EOF
)" \
  --output-format json \
  --max-turns 40 \
  --permission-mode acceptEdits \
  --allowedTools "Read,Bash,Glob,Grep"
```

**Default one-liner (no overrides):**

```bash
cd "<Worktree Path>" && claude --model fable --effort max -p "..." \
  --output-format json --max-turns 40 \
  --permission-mode acceptEdits \
  --allowedTools "Read,Edit,Write,Bash,Glob,Grep"
```

## Required Result Packet Format

Return a structured Result Packet (JSON preferred):

```json
{
  "task_id": "...",
  "status": "success | partial | failed",
  "summary": "1-3 sentence overview of what was done",
  "files_changed": ["path1", "path2"],
  "tests_run": [
    {"command": "...", "outcome": "pass | fail", "notes": "..."}
  ],
  "confidence": 1,
  "open_questions": [],
  "risks": [],
  "recommended_next_action": "merge | needs_review | iterate | escalate_to_human | discard",
  "worker_model": "fable",
  "worker_effort": "max"
}
```

(`confidence` is an integer 1–5. Include the model/effort actually used.)

Also see `.grok/orchestration/RESULT_PACKET.template.md`.

## Rules

- Never edit outside the assigned worktree.
- Never omit `--model` / `--effort` (do not rely on global CLI defaults alone).
- Implementation success without a Review Packet for non-trivial tasks is incomplete — write the Review Packet before finishing.
- If the task is ambiguous or out of scope, stop and return `partial` / `failed` with clear `open_questions`.
- Always prefer reading existing patterns over inventing new ones.
- Treat this as a proposal only. The grok-senpai orchestrator will perform independent review and enforce merge gates from AGENTS.md.
