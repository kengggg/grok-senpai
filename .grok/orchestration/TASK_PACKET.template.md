# Task Packet Template (grok-senpai)

Copy this file (or paste into the worker prompt) when launching a **claude-worker** or **codex-worker**. See **AGENTS.md** for gates, routing, and thinking-level policy.

```yaml
task_id: <short-id>                 # e.g. feat-auth-001
agent: codex | claude
mode: implementation | independent_review
worktree_path: <absolute path>
branch: orch/<short-task>-<agent>
created_by: grok-senpai-orchestrator
parent_task_id: <optional>

# Worker model & effort (optional — defaults from worker-config.toml)
# Defaults: claude → opus + max | codex → gpt-5.6-sol + ultra
worker_model: <optional>            # e.g. opus | gpt-5.6-sol
worker_effort: <optional>           # claude: low|medium|high|xhigh|max
                                    # codex:  low|medium|high|xhigh|max|ultra
# Omit both fields to use max/ultra defaults. Only lower when policy + task shape allow.

goal: |
  <what to accomplish>

scope:
  in_scope:
    - <item>
  out_of_scope:
    - <item>

acceptance_criteria:
  - <criterion>
  - verification_commands all pass inside the worktree

verification_commands:
  - command: <shell command>
    expect: pass

constraints:
  - Stay strictly inside the worktree
  - Prefer minimal, high-quality changes
  - Do not expand scope
  - Treat output as a proposal; grok-senpai orchestrator reviews independently

deliverables:
  - <files / Result Packet>
```

After launch, record the task in `.grok/orchestration/state.md`.
