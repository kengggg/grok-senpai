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
2. Valid Result Packet returned from the implementer
3. Verification commands pass inside the worktree
4. **Review Packet** written (summary + diff handoff) for non-trivial tasks
5. Independent review by a different model, using the Review Packet
6. Human approval of the final diff

### Worktree Protocol (mandatory isolation)
- **Non-trivial and all parallel work MUST run in an isolated worktree.** Do not implement multi-file or parallel agent work on the primary checkout.
- Prefer Grok-native worktrees (`grok -w` or `grok --worktree=...`); `git worktree add` is acceptable if Grok-native is unavailable.
- Naming convention: `orch/<short-task>-<agent>`
- **One agent per worktree.** Never point two workers at the same worktree.
- Before launching a worker, confirm `Worktree Path` is a linked worktree (not the main checkout) unless the human explicitly approved in-place work for a trivial change.
- Record every active worktree in `.grok/orchestration/state.md` **before** the worker starts.
- After merge or discard → remove the worktree (`grok worktree rm` / `git worktree remove` / `gc`).
- **Refuse** to start parallel Claude/Codex jobs that would share a dirty tree.

### Task Packet, Result Packet & Review Packet
Always use the standard Task Packet when launching workers and require a Result Packet in return.

After a successful **implementation** Result Packet, produce a **Review Packet** before launching the reviewer:

- Path: `.grok/orchestration/reviews/<task_id>.md` (in the worktree or main tracker—prefer worktree, copy path into state.md)
- Template: `.grok/orchestration/REVIEW_PACKET.template.md`
- Contents: intent, what changed, diff scope (`git diff --stat` / key paths), verification table, risks, reviewer focus checklist

The reviewer must receive: **Task Packet + Review Packet + read-only worktree/diff**. Do not ask a reviewer to “just look at the branch” without a Review Packet.

- Templates: `.grok/orchestration/TASK_PACKET.template.md`, `.grok/orchestration/RESULT_PACKET.template.md`, `.grok/orchestration/REVIEW_PACKET.template.md`
- Worker skills: `.grok/skills/claude-worker/`, `.grok/skills/codex-worker/`
- Worker defaults: `.grok/orchestration/worker-config.toml`
- Active tracking: `.grok/orchestration/state.md`

### Worker models & thinking levels

**Hard defaults** (use unless overridden):

| Worker | Model | Effort |
|--------|-------|--------|
| Claude (`claude-worker`) | `opus` | `max` |
| Codex (`codex-worker`) | `gpt-5.6-sol` (Sol) | `ultra` |

Configured in `.grok/orchestration/worker-config.toml`. Skills must pass these flags **explicitly** on every invoke (do not rely on the user's global CLI defaults).

**Grok may override** via Task Packet when `[policy].allow_override = true`:

```yaml
worker_model: opus            # or gpt-5.6-sol, etc.
worker_effort: high           # claude: low|medium|high|xhigh|max
                              # codex:  low|medium|high|xhigh|max|ultra
```

**Effort routing (when Grok delegates level):**

| Task shape | Claude effort | Codex effort |
|------------|---------------|--------------|
| Architecture, security, multi-file, ambiguous | `max` | `ultra` or `max` |
| Independent code review | `max` | `max` or `ultra` |
| Normal feature / solid implementation | `high`–`max` | `high`–`ultra` |
| Tiny mechanical edit, single file, clear tests | `high` (floor) | `high` (floor) |

If `policy.enforce_floors` is true (default), never go below `min_effort_claude` / `min_effort_codex` (default `high`). Prefer staying at **max/ultra** when unsure.

### Roles
- **Human:** States goals in plain language; approves or rejects final diffs. Does **not** manually drive worktrees, packets, or worker selection.
- **Grok (orchestrator):** Owns the full loop below for every non-trivial task. This file is your operating manual.

### How Grok runs a task
1. Confirm the repo is git-backed (worktrees require git).
2. Create an isolated worktree (`orch/<short-task>-<agent>`); record it in `state.md`.
3. Write a complete Task Packet; launch the matching worker skill **only inside that worktree**.
4. Collect the Result Packet; confirm verification passed inside the worktree.
5. Write a **Review Packet** (template + diff summary) for non-trivial tasks.
6. Launch independent review with a **different model** in a dedicated review setup (read-only; same worktree OK if read-only, or a fresh worktree checkout of the branch). Pass Task Packet + Review Packet + diff.
7. Present the final diff (and review findings) to the human; merge only after approval; clean up the worktree.
8. Keep `.grok/orchestration/state.md` accurate; reset between major efforts if useful.

### Example
See `examples/clamp/` for a complete walkthrough of implementation → review → polish using this playbook.
