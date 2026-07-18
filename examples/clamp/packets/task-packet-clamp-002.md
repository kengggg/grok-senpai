# Task Packet

```yaml
task_id: clamp-002
agent: codex
worktree_path: /Users/keng/Workspaces/grok-orchrestration/.worktrees/orch-clamp-polish-codex
branch: orch/clamp-polish-codex
created_by: grok-orchestrator
mode: implementation
parent_task_id: clamp-001

goal: |
  Polish clamp.py based on independent review findings from clamp-001-review.
  Rename parameters to avoid shadowing builtins, document the contract, and
  extend unit tests for equal bounds, negatives, and floats.

scope:
  in_scope:
    - Rename clamp parameters min/max → min_value/max_value (and update error message accordingly)
    - Add a short docstring documenting contract including ValueError when min_value > max_value
    - Add tests for: min_value == max_value, negative numbers, floats
    - Update any call sites/tests that use the old parameter names if needed
  out_of_scope:
    - NaN handling changes
    - Type hints (optional; do not require)
    - Packaging, CLI, unrelated refactors
    - Performance work

language: Python 3, stdlib unittest only

acceptance_criteria:
  - Signature is clamp(value, min_value, max_value) — no parameters named min or max
  - Docstring states the clamp contract and that ValueError is raised when min_value > max_value
  - Existing behavior preserved: below min → min_value; above max → max_value; in-range → value
  - min_value > max_value still raises ValueError
  - Tests cover at least: min_value == max_value, negative numbers, floats
  - Existing tests still pass (updated for any signature/message changes as needed)
  - verification_commands all pass inside the worktree

verification_commands:
  - command: python3 -m unittest discover -s . -p "test_*.py" -v
    expect: pass

constraints:
  - Stay strictly inside the worktree path above
  - Prefer minimal, high-quality changes
  - Do not expand scope
  - Treat this as a proposal; orchestrator will review independently

deliverables:
  - Updated clamp.py
  - Updated test_clamp.py
  - Result Packet in the codex-worker format
```
