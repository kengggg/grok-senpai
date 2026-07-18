# Task Packet

```yaml
task_id: clamp-001
agent: codex
worktree_path: /Users/keng/Workspaces/grok-orchrestration/.worktrees/orch-clamp-util-codex
branch: orch/clamp-util-codex
created_by: grok-orchestrator
mode: implementation

goal: |
  Create a simple pure utility function clamp(value, min, max) that returns
  the value constrained between min and max, plus a basic unit test.

scope:
  in_scope:
    - Add a pure clamp(value, min, max) utility function
    - Add a basic unit test covering the main cases
    - Minimal project scaffolding only if required to run the tests
  out_of_scope:
    - CLI, packaging, publishing
    - Performance optimizations
    - Type-system overhauls beyond what the chosen language needs
    - Unrelated refactors or documentation beyond the minimum

language_preference: |
  Greenfield repo with no existing app code. Prefer Python 3 with the
  standard library only (unittest). Keep the layout minimal.

acceptance_criteria:
  - A function named clamp(value, min, max) exists and is importable
  - Behavior: if value < min return min; if value > max return max; else return value
  - When min > max is invalid, either document/raise or define a clear simple behavior
    (prefer raising ValueError)
  - At least one unit test file exercises: below min, above max, within range,
    and equal to boundaries
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
  - Source file(s) implementing clamp
  - Unit test file(s)
  - Result Packet in the codex-worker format
```
