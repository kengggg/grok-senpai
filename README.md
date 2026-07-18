# grok-senpai

**Multi-agent orchestration pack for Grok Build** — run Claude Code and Codex CLI as specialized workers under a single Grok orchestrator, with isolated worktrees, Task Packets, Result Packets, and hard merge gates.

## Why

Solo agents blur planning, coding, and review. **grok-senpai** makes the workflow explicit:

| Role | Who |
|------|-----|
| Orchestrator | Grok Build |
| Deep reasoning / architecture / adversarial review | Claude Code (`claude-worker`) |
| Scoped implementation / mechanical review | Codex CLI (`codex-worker`) |
| Simple independent slices | Grok subagents |

Every non-trivial change is a **proposal** until verification, cross-model review, and human approval.

## Prerequisites

- [Grok Build](https://x.ai/) (orchestrator)
- [Claude Code](https://claude.ai/code) CLI (optional, for `claude-worker`)
- [Codex CLI](https://github.com/openai/codex) (optional, for `codex-worker`)
- Git (required for worktrees)

## Layout

```
grok-senpai/
├── .grok/
│   ├── skills/
│   │   ├── claude-worker/SKILL.md
│   │   └── codex-worker/SKILL.md
│   └── orchestration/
│       ├── state.md
│       ├── TASK_PACKET.template.md
│       └── RESULT_PACKET.template.md
├── examples/
│   └── clamp/                 # worked example (optional)
├── AGENTS.md                  # playbook (project instructions)
├── README.md
└── LICENSE
```

## Quick start

### Use as a new project

```bash
git clone <this-repo> my-project
cd my-project
# rename remote, start building — keep AGENTS.md and .grok/
```

### Drop into an existing project

```bash
# from your app repo
cp -R path/to/grok-senpai/.grok .
cp path/to/grok-senpai/AGENTS.md .   # or merge into existing AGENTS.md
```

Ensure the project is a git repo, then:

1. Read **AGENTS.md** (routing + gates).
2. Create a worktree: `orch/<short-task>-<agent>`.
3. Fill a **Task Packet** from `.grok/orchestration/TASK_PACKET.template.md`.
4. Invoke **codex-worker** or **claude-worker** inside the worktree.
5. Collect the **Result Packet**, run independent review, update `state.md`.
6. Merge only after all mandatory gates pass.

## Orchestration loop

```
Plan (Grok)
  → Worktree (orch/<task>-<agent>)
  → Task Packet
  → Worker skill (Claude or Codex)
  → Result Packet
  → Independent review (opposite model)
  → Human approval
  → Merge + worktree cleanup
```

## Example

`examples/clamp/` is a small pure-function walkthrough (implement → review → polish) that was used to validate this pack. Run:

```bash
cd examples/clamp
python3 -m unittest discover -s . -p "test_*.py" -v
```

## License

MIT — see [LICENSE](./LICENSE).
