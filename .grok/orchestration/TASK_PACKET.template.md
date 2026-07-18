# Task Packet Template

Copy this file (or paste into the worker prompt) when launching a claude-worker or codex-worker.

```yaml
task_id: <short-id>                 # e.g. feat-auth-001
agent: codex | claude
mode: implementation | independent_review
worktree_path: <absolute path>
branch: orch/<short-task>-<agent>
created_by: grok-orchestrator
parent_task_id: <optional>

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
  - Treat output as a proposal; orchestrator reviews independently

deliverables:
  - <files / Result Packet>
```
