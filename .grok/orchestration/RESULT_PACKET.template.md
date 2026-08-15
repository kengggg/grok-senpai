# Result Packet Templates (grok-senpai)

Workers must end with a framed JSON Result. One schema for every agent. Publish via `senpai.sh collect` (stdout is logs, not the contract). Versionless Claude JSON / Codex structured text is accepted only as legacy v1.

## Recommended next actions (shared)

`merge` · `needs_review` · `iterate` · `discard` · `escalate_to_human`

Worker `merge` is ignored by the helper. Human approval plus a matching tree snapshot is Gate 6.

## Framed JSON (v2)

```json
{
  "protocol_version": 2,
  "task_id": "...",
  "attempt": 1,
  "status": "success | partial | failed",
  "agent": "claude | codex",
  "mode": "implementation | independent_review",
  "role": "dev | review",
  "role_source": "default_routing | human_override",
  "summary": "1-3 sentence overview",
  "files_changed": ["path1", "path2"],
  "tests_run": [
    {"command": "...", "outcome": "pass | fail", "notes": "..."}
  ],
  "confidence": 1,
  "open_questions": [],
  "risks": [],
  "recommended_next_action": "merge | needs_review | iterate | escalate_to_human | discard",
  "findings": [
    {"severity": "blocker | major | minor | nit", "title": "...", "detail": "..."}
  ],
  "worker_model_alias": "fable",
  "worker_model": "fable",
  "worker_effort": "high"
}
```

(`confidence` is an integer 1–5. `findings` is required for `independent_review` — use `[]` when none; optional/empty for implementation. Same-attempt republish fails; retry is a new `attempt`.)

## Orchestrator rules

- Treat every Result Packet as a **proposal**.
- Require the role source and the model/effort actually used for an auditable launch.
- Do not merge until mandatory gates pass (see `AGENTS.md`).
- `senpai.sh collect` checks framing only (JSON-shaped, task/attempt). Semantic checks are host work against this template.
