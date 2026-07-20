# grok-senpai

![grok-senpai cover](docs/cover.jpg)

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
│       ├── worker-config.toml           # model + effort defaults (Opus/max, Sol/ultra)
│       ├── worker-config.example.toml
│       ├── TASK_PACKET.template.md
│       ├── RESULT_PACKET.template.md
│       ├── REVIEW_PACKET.template.md    # implementer → reviewer handoff
│       └── reviews/                     # written Review Packets per task
├── examples/
│   └── clamp/                 # optional worked example
├── install.sh                 # install into another project
├── AGENTS.md                  # playbook (project instructions for Grok)
├── README.md
└── LICENSE
```

## Quick start

### One-liner install (easiest)

From **inside your project** directory:

```bash
curl -sL https://raw.githubusercontent.com/kengggg/grok-senpai/main/install.sh | bash
```

Or pass a target path:

```bash
curl -sL https://raw.githubusercontent.com/kengggg/grok-senpai/main/install.sh | bash -s -- /path/to/your-app
```

Pin a branch or tag:

```bash
GROK_SENPAI_REF=main curl -sL https://raw.githubusercontent.com/kengggg/grok-senpai/main/install.sh | bash
```

### Local clone + install.sh

```bash
git clone https://github.com/kengggg/grok-senpai.git
/path/to/grok-senpai/install.sh /path/to/your-app
# or, from inside your app:
/path/to/grok-senpai/install.sh .
```

### Manual copy (fallback)

```bash
cp -R path/to/grok-senpai/.grok .
# Merge the playbook into AGENTS.md yourself — prefer install.sh
```

### What gets installed

- `.grok/skills/` — `claude-worker`, `codex-worker` (**always refreshed** on re-run)
- `.grok/orchestration/` — Task/Result/**Review** packet templates + `worker-config.example.toml` (refreshed)
- `worker-config.toml` — created once with defaults; **not overwritten** on re-run
- `state.md` — created once; **kept** on re-run
- `AGENTS.md` — Multi-Agent Orchestration Playbook merged or created (idempotent markers)

**Handoff flow:** Task Packet → implementer Result Packet → **Review Packet** (summary + diff) → opposite-model review → human approval.

### Worker defaults (thinking level)

| Worker | Model | Effort |
|--------|-------|--------|
| Claude | **Opus** (`opus`) | **`max`** |
| Codex | **Sol** (`gpt-5.6-sol`) | **`ultra`** |

Grok may lower effort per Task Packet (`worker_effort`) when the playbook allows; floors default to `high`. Edit `.grok/orchestration/worker-config.toml` to change project defaults.

### Upgrade an existing project

Re-run the installer to pull new skills + playbook (keeps your `state.md` and `worker-config.toml`):

```bash
curl -sL https://raw.githubusercontent.com/kengggg/grok-senpai/main/install.sh | bash
```

To reset worker defaults to stock Opus/max + Sol/ultra:

```bash
cp .grok/orchestration/worker-config.example.toml .grok/orchestration/worker-config.toml
```

### After install — just talk to Grok

You do **not** run worktrees, Task Packets, or workers yourself.

1. Open **Grok Build** in the project (git repo recommended).
2. Describe the goal in plain language (optionally: “follow the grok-senpai playbook”).
3. **Grok** reads `AGENTS.md`, routes to Claude/Codex, verifies, and reviews.
4. **You** only approve or reject the final diff when asked.

```text
Implement rate limiting on the login endpoint and add tests.
Follow the grok-senpai playbook.
```

### Who does what

| You (human) | Grok (orchestrator) |
|-------------|---------------------|
| Describe the goal in plain language | Reads **AGENTS.md** and follows the playbook |
| Approve (or reject) final diffs when asked | Creates worktrees, Task Packets, launches workers |
| That’s it — no need to micromanage steps | Runs verification, opposite-model review, updates `state.md`, merges after your approval |

**You should not** invent worktree names, fill Task Packets, or pick Claude vs Codex yourself. **Grok does the job** you described, using this pack as its operating manual.

## Orchestration loop (Grok runs this)

```
You: state the goal
  → Grok: Plan
  → Grok: Worktree (orch/<task>-<agent>) — mandatory isolation
  → Grok: Task Packet
  → Grok: Worker skill (Claude or Codex)
  → Grok: Result Packet + verification
  → Grok: Review Packet (summary + diff handoff)
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
