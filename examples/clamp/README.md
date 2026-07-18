# Example: clamp utility (grok-senpai walkthrough)

This folder is a **worked example** of using [grok-senpai](../../README.md) end-to-end — not part of the core template runtime.

## What it demonstrates

| Task | Agent | Outcome |
|------|-------|---------|
| Implement `clamp(value, min_value, max_value)` + unit tests | Codex (`codex-worker`) | Merged |
| Independent review | Claude (`claude-worker`) | Approved merge |
| Polish (rename params, docstring, more tests) | Codex + Claude review | Merged |

Archived Task Packets from that run live in `packets/`.

## Files

- `clamp.py` — pure utility
- `test_clamp.py` — stdlib `unittest` suite
- `packets/` — historical Task Packets (reference only)

## Run tests

```bash
cd examples/clamp
python3 -m unittest discover -s . -p "test_*.py" -v
```

## How this maps to the playbook

1. Worktrees named `orch/clamp-*-codex` (isolated from `main`)
2. Complete Task Packets before each worker launch
3. Result Packets required; verification inside the worktree
4. Opposite-model review before merge
5. Human approval of the final diff
