# Task Packet — Independent Review

```yaml
task_id: clamp-002-review
agent: claude
mode: independent_review
worktree_path: /Users/keng/Workspaces/grok-orchrestration/.worktrees/orch-clamp-polish-codex
branch: orch/clamp-polish-codex
implements_task_id: clamp-002
created_by: grok-orchestrator

goal: |
  Independent adversarial code review of the clamp polish produced by Codex
  for task clamp-002. Do NOT implement features. Review only. Do not edit files.

original_goal: |
  Polish clamp.py: rename min/max → min_value/max_value; add short docstring
  documenting ValueError when min_value > max_value; add tests for equal bounds,
  negatives, and floats.

files_under_review:
  - clamp.py
  - test_clamp.py

review_focus:
  - Whether the parameter rename (min/max → min_value/max_value) was done cleanly
  - Quality of the new docstring
  - Whether the new tests (min == max, negatives, floats) are correct and sufficient
  - Any remaining issues

scope:
  in_scope:
    - Read AGENTS.md and the implementation/test files
    - Run verification_commands
    - Produce findings on rename, docstring, new tests, remaining issues
    - Recommend merge | needs_review | iterate | escalate_to_human | discard
  out_of_scope:
    - Editing any files
    - Expanding scope
    - Merging or committing

acceptance_criteria:
  - Complete Result Packet in required JSON format
  - Findings address rename cleanliness, docstring quality, new tests, remaining issues
  - files_changed is []
  - recommended_next_action is one of the allowed values

verification_commands:
  - command: python3 -m unittest discover -s . -p "test_*.py" -v
    expect: pass

constraints:
  - Stay strictly inside the worktree
  - Do not edit any files
  - Treat Codex output as a proposal only
  - Output ONLY a Result Packet (JSON preferred) with no extra commentary outside it
```
