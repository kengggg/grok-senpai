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

### How to use this template
1. Ensure the repo is a git repository (worktrees require git).
2. Keep `.grok/skills/`, `.grok/orchestration/`, and `AGENTS.md` at the project root (or merge into an existing project).
3. For each non-trivial task: create a worktree → fill a Task Packet → invoke the matching worker skill → record state → independent review → human merge approval.
4. Reset `.grok/orchestration/state.md` between major efforts if desired.

### Example
See `examples/clamp/` for a complete walkthrough of implementation → review → polish using this playbook.
