# grok-senpai

**Multi-agent orchestration template for [Grok Build](https://x.ai/)** — orchestrate **Claude Code** and **Codex CLI** as specialized workers with isolated worktrees, Task Packets, Result Packets, and hard merge gates.

GitHub: [kengggg/grok-senpai](https://github.com/kengggg/grok-senpai)

## Why grok-senpai?

Solo agents blur planning, coding, and review. **grok-senpai** makes the workflow explicit:

| Role | Who |
|------|-----|
| Orchestrator | Grok Build |
| Deep reasoning / architecture / adversarial review | Claude Code (`claude-worker`) |
| Scoped implementation / mechanical review | Codex CLI (`codex-worker`) |
| Simple independent slices | Grok subagents |

Every non-trivial change is a **proposal** until verification, cross-model review, and human approval. See **[AGENTS.md](./AGENTS.md)** for the full playbook.

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
│   │   ├── claude-worker/
│   │   │   └── SKILL.md
│   │   └── codex-worker/
│   │       └── SKILL.md
│   └── orchestration/
│       ├── state.md
│       ├── TASK_PACKET.template.md
│       └── RESULT_PACKET.template.md
├── examples/
│   └── clamp/                 # optional worked example
├── AGENTS.md                  # playbook (project instructions for Grok)
├── README.md
└── LICENSE
```

## Quick start

### Clone as a template

```bash
git clone https://github.com/kengggg/grok-senpai.git
cd grok-senpai
```

### Drop into an existing project

```bash
# from your app repo
cp -R path/to/grok-senpai/.grok .
cp path/to/grok-senpai/AGENTS.md .   # or merge into existing AGENTS.md
```

Ensure the project is a **git** repository, then:

1. Read **AGENTS.md** (routing table + mandatory gates).
2. Create a worktree: `orch/<short-task>-<agent>`.
3. Fill a **Task Packet** from `.grok/orchestration/TASK_PACKET.template.md`.
4. Invoke **codex-worker** or **claude-worker** inside the worktree (see skills).
5. Collect the **Result Packet**, run independent review (opposite model), update `state.md`.
6. Merge only after all mandatory gates pass (including human approval).

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

This loop matches the playbook in **AGENTS.md** and the invocation contracts in the worker skills.

## Example

`examples/clamp/` is a small pure-function walkthrough (implement → review → polish) used to validate grok-senpai. It is optional teaching material, not required runtime.

```bash
cd examples/clamp
python3 -m unittest discover -s . -p "test_*.py" -v
```

## License

MIT — see [LICENSE](./LICENSE).
