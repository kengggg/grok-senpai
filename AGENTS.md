# grok-senpai

**grok-senpai** is a reusable multi-agent orchestration template for Grok Build.

Copy this pack into any project (or start from this repo) so Grok can orchestrate **Claude Code** and **Codex CLI** workers in isolated worktrees with explicit Task Packets, Result Packets, and merge gates.

| Role | Who | Skill |
|------|-----|--------|
| Orchestrator | Grok Build | — |
| Deep reasoning / architecture / high-stakes review | Claude Code | `.grok/skills/claude-worker/` |
| Scoped implementation / mechanical review | Codex CLI | `.grok/skills/codex-worker/` |
| Simple independent slices | Grok subagents | builtin |

Application code lives in *your* project. This template provides the playbook, worker skills, and orchestration state — plus an optional worked example under `examples/`.

---

## Multi-Agent Orchestration Playbook (Grok + Claude + Codex)

### Core Principles
- Grok Build is the single orchestrator. Always start non-trivial work in Plan Mode.
- Prefer model diversity: Claude Code for deep reasoning / architecture; Codex CLI for scoped implementation and independent review; Grok subagents for simple independent pieces.
- Isolation first: every parallel or non-trivial task runs in its own Grok-native worktree.
- Treat every agent output as a proposal. Never merge without verification.

### Routing Decision Table

| Task Type | Preferred Agent | Notes |
|-----------|-----------------|-------|
| Architecture, complex multi-file, high-stakes reasoning | Claude Code | Deep coherence |
| Well-scoped implementation, mechanical changes, tests | Codex CLI | Fast + precise |
| Simple independent piece | Grok subagent | Lowest overhead |
| Independent code review | Opposite model of the implementer | Different training distribution |
| Final integration / merge decision | Grok | After all gates pass |

### Mandatory Gates (before any merge)
1. Complete Task Packet
2. Valid Result Packet returned
3. Verification commands pass inside the worktree
4. Independent review by a different model
5. Human approval of the final diff

### Worktree Protocol
- Prefer Grok-native worktrees (`grok -w` or `grok --worktree=...`)
- Naming convention: `orch/<short-task>-<agent>`
- One agent per worktree
- Record every active worktree in `.grok/orchestration/state.md`
- After merge or discard → run `grok worktree rm` / `gc` (or `git worktree remove`)

### Task Packet & Result Packet
Always use the standard Task Packet when launching workers and require a Result Packet in return.

- Templates: `.grok/orchestration/TASK_PACKET.template.md`, `.grok/orchestration/RESULT_PACKET.template.md`
- Worker skills: `.grok/skills/claude-worker/`, `.grok/skills/codex-worker/`
- Active tracking: `.grok/orchestration/state.md`

### Roles
- **Human:** States goals in plain language; approves or rejects final diffs. Does **not** manually drive worktrees, packets, or worker selection.
- **Grok (orchestrator):** Owns the full loop below for every non-trivial task. This file is your operating manual.

### How Grok runs a task
1. Confirm the repo is git-backed (worktrees require git).
2. Create an isolated worktree (`orch/<short-task>-<agent>`).
3. Write a complete Task Packet; launch the matching worker skill.
4. Collect the Result Packet; run verification inside the worktree.
5. Run independent review with a different model when required.
6. Present the final diff to the human; merge only after approval; clean up the worktree.
7. Keep `.grok/orchestration/state.md` accurate; reset between major efforts if useful.

### Example
See `examples/clamp/` for a complete walkthrough of implementation → review → polish using this playbook.
