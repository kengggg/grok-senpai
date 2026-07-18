# Task Packet — Independent Review

```yaml
task_id: clamp-001-review
agent: claude
mode: independent_review
worktree_path: /Users/keng/Workspaces/grok-orchrestration/.worktrees/orch-clamp-util-codex
branch: orch/clamp-util-codex
implements_task_id: clamp-001
created_by: grok-orchestrator

goal: |
  Independent adversarial code review of the clamp implementation produced by
  Codex for task clamp-001. Do NOT implement features. Review only.

original_goal: |
  Create a pure utility clamp(value, min, max) that constrains value between
  min and max, plus basic unit tests.

files_under_review:
  - clamp.py
  - test_clamp.py

review_focus:
  - Correctness of clamp behavior (especially edge cases and when min > max)
  - Quality and coverage of the tests
  - Simplicity and cleanliness of the code
  - Any risks or missing edge cases

scope:
  in_scope:
    - Read AGENTS.md and the implementation/test files
    - Run verification_commands
    - Produce findings on correctness, tests, simplicity, risks
    - Recommend merge | needs_review | iterate | escalate_to_human | discard
  out_of_scope:
    - Editing production code or tests (review-only; do not modify files)
    - Expanding scope with new features
    - Merging or committing

acceptance_criteria:
  - Complete Result Packet returned in the required JSON format
  - Findings explicitly address: correctness (incl. min>max), test quality/coverage,
    simplicity, risks/missing edge cases
  - recommended_next_action is one of the allowed values
  - files_changed should be [] because this is review-only

verification_commands:
  - command: python3 -m unittest discover -s . -p "test_*.py" -v
    expect: pass

constraints:
  - Stay strictly inside the worktree
  - Do not edit any files
  - Treat Codex output as a proposal only
  - Output ONLY a Result Packet (JSON preferred) with no extra commentary outside it
```
