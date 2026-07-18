# Task Packet

```yaml
task_id: clamp-003
agent: codex
worktree_path: /Users/keng/Workspaces/grok-orchrestration/.worktrees/orch-clamp-nits-codex
branch: orch/clamp-nits-codex
created_by: grok-orchestrator
mode: implementation
parent_task_id: clamp-002

goal: |
  Add two small test improvements for clamp:
  1. In the equal-bounds test, also assert a value below the bound returns the bound
     (e.g. clamp(0, 4, 4) == 4)
  2. Add a simple keyword-argument smoke test:
     clamp(3, min_value=2, max_value=5) == 3

scope:
  in_scope:
    - Update or add tests in test_clamp.py for the two cases above
    - Keep changes minimal (tests only unless something is clearly broken)
  out_of_scope:
    - Changing clamp.py behavior
    - Packaging, docs, unrelated refactors
    - NaN handling

language: Python 3, stdlib unittest only

acceptance_criteria:
  - Equal-bounds coverage includes a value below the collapsed bound (e.g. clamp(0, 4, 4) == 4)
  - A keyword-argument test exists with at least clamp(3, min_value=2, max_value=5) == 3
  - All existing tests still pass
  - If these assertions already exist, do not rewrite unnecessarily; confirm coverage and report success
  - verification_commands pass inside the worktree

verification_commands:
  - command: python3 -m unittest discover -s . -p "test_*.py" -v
    expect: pass

constraints:
  - Stay strictly inside the worktree path above
  - Prefer minimal, high-quality changes
  - Do not expand scope
  - Treat this as a proposal; orchestrator will review independently

deliverables:
  - Updated test_clamp.py if changes needed
  - Result Packet in the codex-worker format
```
