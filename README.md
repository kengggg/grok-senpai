# grok-senpai

![grok-senpai cover](docs/cover.jpg)

**Multi-agent orchestration template for [Grok Build](https://x.ai/)** — orchestrate **Claude Code** and **Codex CLI** as specialized workers with isolated worktrees, Task Packets, Result Packets, live progress heartbeats, and hard merge gates.

GitHub: [kengggg/grok-senpai](https://github.com/kengggg/grok-senpai)

**Defaults:** Claude **Opus** (`opus`) at **`max`** · Codex **Sol** (`gpt-5.6-sol`) at **`ultra`**. Override in plain English any time.

## Why grok-senpai?

Solo agents blur planning, coding, and review. **grok-senpai** makes the workflow explicit:

| Role | Who |
|------|-----|
| Orchestrator | Grok Build |
| Deep reasoning / architecture / adversarial review | Claude Code (`claude-worker`) |
| Scoped implementation / mechanical review | Codex CLI (`codex-worker`) |
| Simple independent slices | Grok subagents |

Every non-trivial change is a **proposal** until verification, cross-model review, and human approval. See **[AGENTS.md](./AGENTS.md)** for the full playbook, or **[docs/design-model-roles-visibility.md](./docs/design-model-roles-visibility.md)** for model selection, roles, and visibility design.

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
│       ├── model-aliases.toml           # friendly name → CLI model
│       ├── model-aliases.example.toml
│       ├── TASK_PACKET.template.md
│       ├── RESULT_PACKET.template.md
│       ├── REVIEW_PACKET.template.md    # implementer → reviewer handoff
│       ├── reviews/                     # written Review Packets per task
│       └── logs/                        # gitignored worker I/O
├── examples/
│   └── clamp/                 # optional worked example
├── install.sh                 # install into another project
├── AGENTS.md                  # playbook (project instructions for Grok)
├── docs/
│   ├── cover.jpg              # 16:9 README hero
│   ├── og-image.jpg           # 1280×640 (2:1) social preview, safe margins
│   └── design-model-roles-visibility.md
├── README.md
└── LICENSE
```

**Assets**
- `docs/cover.jpg` — 16:9 README
- `docs/og-image.jpg` — 1280×640 (2:1) Social preview with safe margins

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
- `.grok/orchestration/` — Task/Result/**Review** packet templates + config/alias examples (refreshed)
- `worker-config.toml` — created once with defaults; **not overwritten** on re-run
- `model-aliases.toml` — created once with friendly aliases; **not overwritten** on re-run
- `logs/` — created for worker output used by progress heartbeats; ignore rules are added idempotently
- `state.md` — created once; **kept** on re-run
- `AGENTS.md` — Multi-Agent Orchestration Playbook merged or created (idempotent markers)

**Handoff flow:** Task Packet → implementer Result Packet → **Review Packet** (summary + diff) → opposite-model review → human approval.

### Worker defaults (thinking level)

| Worker | Model | Effort |
|--------|-------|--------|
| Claude | **Opus** (`opus`) | **`max`** |
| Codex | **Sol** (`gpt-5.6-sol`) | **`ultra`** |

Grok may lower effort per Task Packet (`worker_effort`) when the playbook allows; floors default to `high`. Edit `.grok/orchestration/worker-config.toml` to change project defaults.

Friendly aliases (edit `.grok/orchestration/model-aliases.toml`):

| You say | CLI model |
|---------|-----------|
| `opus` / Opus 5 | `opus` |
| `claude-opus-5` | `claude-opus-5` |
| `fable` / `sonnet` | same alias |
| `sol` | `gpt-5.6-sol` |

### Choose models and roles in plain English

You never need to edit a Task Packet. Add a model, effort, or one-turn role override when you want one:

```text
Use claude Opus 5 max for the architecture.
Codex sol ultra, implement the approved slice.
Claude dev, codex review this turn.
Codex implement, claude review.
```

What Grok does with that:

1. Resolves aliases via `model-aliases.toml` and writes concrete `worker_model` / `worker_effort` on the Task Packet  
2. Echoes a **Launch plan** (agent, role, model, effort, worktree) before invoke  
3. Confirms unknown aliases instead of launching blindly  
4. Honors role overrides **for that task chain only**; otherwise uses the routing table in `AGENTS.md`

### Live progress (heartbeats)

While a worker runs, Grok:

- Captures worker I/O to `.grok/orchestration/logs/<task_id>.log` (gitignored)
- Records PID + log path in `.grok/orchestration/state.md`
- Posts a short **heartbeat** about every **2 minutes** (and on “status?”)
- Reports phase, last signal, and worktree churn — not a full tool stream

### Upgrade an existing project

Re-run the installer to pull new skills + playbook (keeps your `state.md`, `worker-config.toml`, and `model-aliases.toml`):

```bash
curl -sL https://raw.githubusercontent.com/kengggg/grok-senpai/main/install.sh | bash
```

To adopt stock **Opus/max + Sol/ultra** (overwrites your worker-config):

```bash
cp .grok/orchestration/worker-config.example.toml .grok/orchestration/worker-config.toml
# optional: refresh aliases too
cp .grok/orchestration/model-aliases.example.toml .grok/orchestration/model-aliases.toml
```

### After install — just talk to Grok

You do **not** run worktrees, Task Packets, or workers yourself.

1. Open **Grok Build** in the project (git repo recommended).
2. Describe the goal in plain language; optionally name a model, effort, or per-turn role.
3. **Grok** reads `AGENTS.md`, routes to Claude/Codex, verifies, and reviews.
4. **You** only approve or reject the final diff when asked.

```text
Implement rate limiting on the login endpoint and add tests.
Follow the grok-senpai playbook.
```

### Who does what

| You (human) | Grok (orchestrator) |
|-------------|---------------------|
| Describe the goal; optionally override models or roles | Reads **AGENTS.md** and follows the playbook |
| Approve (or reject) final diffs when asked | Creates worktrees, Task Packets, launches workers |
| That’s it — no need to micromanage steps | Runs verification, opposite-model review, updates `state.md`, merges after your approval |

**You do not need to** invent worktree names, fill Task Packets, or choose Claude vs Codex. Grok routes by default, while still honoring an explicit model or role override for the current task.

## Orchestration loop (Grok runs this)

```
You: state the goal
  → Grok: Plan
  → Grok: Worktree (orch/<task>-<agent>) — mandatory isolation
  → Grok: Task Packet + resolved Launch plan
  → Grok: Worker skill (Claude or Codex) + ~2m heartbeats
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
