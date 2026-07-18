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

Ensure the project is a **git** repository, then open **Grok Build** in that directory.

### Who does what

| You (human) | Grok (orchestrator) |
|-------------|---------------------|
| Describe the goal in plain language | Reads **AGENTS.md** and follows the playbook |
| Approve (or reject) final diffs when asked | Creates worktrees, Task Packets, launches workers |
| That’s it — no need to micromanage steps | Runs verification, opposite-model review, updates `state.md`, merges after your approval |

**You should not** invent worktree names, fill Task Packets, or pick Claude vs Codex yourself. **Grok does the job** you described, using this pack as its operating manual.

### What you actually type

```text
Implement rate limiting on the login endpoint and add tests.
Follow the grok-senpai playbook.
```

Grok then owns the full loop below (you only weigh in at human-approval gates).

## Orchestration loop (Grok runs this)

```
You: state the goal
  → Grok: Plan
  → Grok: Worktree (orch/<task>-<agent>)
  → Grok: Task Packet
  → Grok: Worker skill (Claude or Codex)
  → Grok: Result Packet + verification
  → Grok: Independent review (opposite model)
  → You: approve or reject the final diff
  → Grok: Merge + worktree cleanup
```

The playbook in **AGENTS.md** and the worker skills are instructions **for Grok**, not a checklist for you.

## Example

`examples/clamp/` is a small pure-function walkthrough (implement → review → polish) used to validate grok-senpai. It is optional teaching material, not required runtime.

```bash
cd examples/clamp
python3 -m unittest discover -s . -p "test_*.py" -v
```

## License

MIT — see [LICENSE](./LICENSE).
