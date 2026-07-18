# Result Packet Templates

Workers must end with a Result Packet. Formats differ slightly by agent.

## Codex (structured text)

```
Result Packet
Task ID: <same as Task Packet>
Status: success | partial | failed
Agent: codex
Worktree Path: ...
Branch: ...
Summary
<2-5 sentences>
Files Changed
path (added|modified|deleted)
Tests & Verification
Command: ... → pass | fail
Notes: ...
Confidence
<1-5> (short justification)
Open Questions / Risks
...
Recommended Next Action
merge | needs-review | iterate | discard | escalate-to-human
```

## Claude (JSON preferred)

```json
{
  "task_id": "...",
  "status": "success | partial | failed",
  "summary": "1-3 sentence overview",
  "files_changed": ["path1", "path2"],
  "tests_run": [
    {"command": "...", "outcome": "pass | fail", "notes": "..."}
  ],
  "confidence": 1,
  "open_questions": [],
  "risks": [],
  "recommended_next_action": "merge | needs_review | iterate | escalate_to_human | discard"
}
```

## Orchestrator rules
- Treat every Result Packet as a **proposal**.
- Do not merge until mandatory gates pass (see `AGENTS.md`).
