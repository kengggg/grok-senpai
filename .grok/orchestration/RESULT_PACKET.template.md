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
  "worker_effort": "high",
  "usage": {
    "currency": "USD",
    "token_unit": "tokens",
    "senpai": {
      "uncached_input": 0,
      "cache_read": 0,
      "cache_write": 0,
      "reasoning": 0,
      "output": 0,
      "cost": 0
    },
    "worker": {
      "uncached_input": 0,
      "cache_read": 0,
      "cache_write": 0,
      "reasoning": 0,
      "output": 0,
      "cost": 0
    }
  }
}
```

(`confidence` is an integer 1–5. `findings` is required for `independent_review` — use `[]` when none; optional/empty for implementation. Same-attempt republish fails; retry is a new `attempt`.)

### Unified `usage` object

One shape for every agent. Token fields are counts. `cost` is USD. The worker fills `usage.worker` from the provider envelope. The senpai host fills `usage.senpai` from its own session (or passes `--senpai-usage` to `collect`). Do not invent a second schema per provider.

| Field | Meaning | Typical provider map |
|-------|---------|----------------------|
| `uncached_input` | Input tokens not served from cache | Claude `input_tokens` minus cache read; Codex input that is not cached |
| `cache_read` | Input tokens read from cache | `cache_read_input_tokens` |
| `cache_write` | Input tokens written into cache | `cache_creation_input_tokens` |
| `reasoning` | Hidden / thinking tokens | `output_tokens_details.thinking_tokens`, `reasoning_tokens` |
| `output` | Visible output tokens | `output_tokens` (or output minus reasoning if the API splits them) |
| `cost` | Billable USD for that party | `costUSD` / billed cost |

`senpai.sh collect` writes both parties to the **same run ledger** (`.grok/orchestration/ledger.jsonl`) and rolls up `.grok/orchestration/runs/<run_id>/usage.json` with `senpai`, `worker`, and `total`. Missing fields default to `0`. A top-level `usage.uncached_input` (no `senpai`/`worker` wrapper) is treated as worker-only.

## Orchestrator rules

- Treat every Result Packet as a **proposal**.
- Require the role source and the model/effort actually used for an auditable launch.
- Do not merge until mandatory gates pass (see `AGENTS.md`).
- `senpai.sh collect` checks framing only (JSON-shaped, task/attempt). Semantic checks are host work against this template.
- After publish, collect records `usage.senpai` and `usage.worker` on the shared ledger. Host usage that arrives later uses `--senpai-usage`.
