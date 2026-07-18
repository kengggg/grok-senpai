# Example: clamp utility (grok-senpai walkthrough)

This folder is a **worked example** of using [grok-senpai](../../README.md) end-to-end. It is teaching material, not part of the core template runtime.

## What it demonstrates

| Phase | Agent | Outcome |
|-------|-------|---------|
| Implement `clamp(value, min_value, max_value)` + unit tests | Codex (`codex-worker`) | Proposal |
| Independent review | Claude (`claude-worker`) | Approve merge |
| Polish (docs, extra edge-case tests) | Codex + Claude review | Merged |

Follows the playbook in **[AGENTS.md](../../AGENTS.md)** (Task Packet → worktree → Result Packet → opposite-model review → human approval).

## Files

| File | Purpose |
|------|---------|
| `clamp.py` | Pure `clamp` utility |
| `test_clamp.py` | stdlib `unittest` suite |

## Run tests

```bash
cd examples/clamp
python3 -m unittest discover -s . -p "test_*.py" -v
```

## How this maps to the playbook

1. Isolated worktrees named `orch/<task>-codex` / review in place or opposite agent
2. Complete Task Packets before each worker launch
3. Result Packets required; verification inside the worktree
4. Opposite-model review before merge
5. Human approval of the final diff
