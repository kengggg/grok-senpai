# Orchestration State (grok-senpai)

Track active multi-agent work here. One row per task / worktree.

| Task ID | Agent | Role | Model | Effort | Worktree Path | Branch | Status | Phase | Started | Last heartbeat | Last signal | Result Packet | Log | PID | Notes |
|---------|-------|------|-------|--------|---------------|--------|--------|-------|---------|----------------|-------------|---------------|-----|-----|-------|
|         |       |      |       |        |               |        |        |       |         |                |             |               |     |     |       |

## Status values

`pending` · `running` · `in_progress` · `success` · `partial` · `failed` · `merged` · `discarded`

## Phase values

`starting` · `running` · `testing` · `finishing` · `stalled` · `done` · `failed`

## Protocol

- Record every active worktree when launching a worker (see **AGENTS.md**).
- Update `Phase`, `Last heartbeat`, `Last signal`, and `PID` on every heartbeat.
- Record the terminal Result Packet and log path when the worker exits.
- After merge or discard, clear the row (or mark completed) and remove the worktree.
