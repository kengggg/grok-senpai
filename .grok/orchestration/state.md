# Orchestration State

Track active multi-agent work here. One row per task / worktree.

| Task ID | Agent | Worktree Path | Branch | Status | Result Packet | Notes |
|---------|-------|---------------|--------|--------|---------------|-------|
|         |       |               |        |        |               |       |

## Status values
`pending` · `in_progress` · `success` · `partial` · `failed` · `merged` · `discarded`

## Protocol
- Record every active worktree when launching a worker.
- After merge or discard, clear the row (or mark completed) and remove the worktree.
