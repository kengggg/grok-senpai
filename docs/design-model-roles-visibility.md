# Design: Model selection, per-turn roles, and worker visibility

**Status:** approved  
**Date:** 2026-07-25  
**Approval amendment (2026-07-25):** Claude’s default was `opus` + `max`.  
**Later amendment (2026-07-29):** Claude’s default is `fable` + `high` (Fable High). Opus remains an available alias for explicit per-turn overrides.  
**Scope:** grok-senpai orchestrator playbook + worker skills + orchestration state  
**Non-goals:** changing Claude/Codex product CLIs; building a separate UI; worker self-reporting heartbeats

---

## Problem

Today grok-senpai already supports:

- Per-worker defaults in `worker-config.toml` (Claude Fable/high, Codex Sol/ultra)
- Per-task overrides via Task Packet `worker_model` / `worker_effort`
- Modes `implementation | independent_review`

Gaps:

1. **Human UX** — users want natural language (“use claude Opus 5 max”, “codex sol ultra”), not only YAML.
2. **Per-turn roles** — users want to force assignment when needed (“claude dev, codex review this turn”) while keeping smart defaults.
3. **Visibility** — workers run headless; the human gets silence until a Result Packet. Grok should periodically report what subordinates are doing.

---

## Decisions (locked from clarification)

| Topic | Choice |
|-------|--------|
| Model/effort UX | Natural language; Grok parses → Task Packet → CLI flags |
| Role assignment | **Default routing** from AGENTS.md; **override when human asks** |
| Progress cadence | ~**every 2 minutes** while a worker is running |
| Progress source | **Grok polls** worker I/O + worktree signals (workers stay mostly unchanged) |
| Progress sinks | **Chat** (human) + **`state.md`** (durable) |
| Progress content | **Short heartbeat** (not rich digests) |
| Model names | **Friendly alias map** → CLI ids; unknown → ask human |
| Delivery | **Design first, then implement** (this doc) |
| Claude default | **Fable** (`fable`) at `high` effort (2026-07-29 amendment; Opus available as override) |

---

## Goals

1. Any human phrase that clearly names agent + model + effort becomes resolved, echoed, and enforced on the worker invoke.
2. Roles (`dev` / `review` / …) can be overridden per turn without rewriting the whole playbook.
3. While a worker runs, Grok posts a short heartbeat ~q2m and keeps `state.md` current.
4. Resolution is deterministic and logged (no silent “wrong model” launches).

---

## 1. Natural-language model & effort

### 1.1 Grammar (informal)

```
[<agent>] [<model-alias> [<version>]] [<effort>]
```

Examples humans may say:

| Phrase | Resolved (intent) |
|--------|-------------------|
| `use claude Opus 5 max` | agent=claude, model alias=opus, effort=max |
| `codex sol ultra` | agent=codex, model=gpt-5.6-sol, effort=ultra |
| `claude fable max` | claude + fable + max |
| `review with sonnet high` | mode=review, model=sonnet, effort=high (agent from routing/override) |
| `claude dev, codex review` | roles only; models = defaults or prior NL |

Rules:

- Agent tokens: `claude`, `codex` (and skill names `claude-worker` / `codex-worker`).
- Effort tokens (case-insensitive): `low`, `medium`, `high`, `xhigh`, `max`, `ultra`.
  - `ultra` is **Codex-only**. If applied to Claude → clamp to `max` and note it in the echo.
  - If effort omitted → config default (Claude `max`, Codex `ultra`), subject to floors.
- Model tokens match the alias table (§1.2). Optional bare version (`5`, `5.6`) is advisory for disambiguation; prefer CLI latest aliases when the user says “Opus 5” / “Sol”.
- If ambiguous or unknown model → **do not launch**; ask human once with candidates.
- Echo before launch:

  ```text
  Launch plan
  - agent: claude | role: dev
  - model: opus  (cli: opus)
  - effort: max
  - worktree: …
  ```

  For non-interactive / already-approved runs, still write the same block into Task Packet / state notes.

### 1.2 Friendly alias map

**Source of truth file (new):** `.grok/orchestration/model-aliases.toml`  
(shipped + example; install preserves local overrides if present, same pattern as `worker-config.toml`)

Claude Code (`claude --model`):

| Alias (human) | CLI value | Notes |
|---------------|-----------|--------|
| `opus` | `opus` | optional high-stakes override; “Opus 5” / “claude opus” → this |
| `claude-opus-5` | `claude-opus-5` | full id pass-through |
| `claude-opus-5[1m]` | `claude-opus-5[1m]` | long-context variant when available |
| `fable` | `fable` | default worker (Fable High) |
| `sonnet` | `sonnet` | |
| `claude-fable-5` | `claude-fable-5` | full id pass-through |
| `claude-fable-5[1m]` | `claude-fable-5[1m]` | long-context variant |

Codex (`codex exec -m`):

| Alias (human) | CLI value | Notes |
|---------------|-----------|--------|
| `sol` | `gpt-5.6-sol` | default worker; “codex sol” |
| `gpt-5.6-sol` | `gpt-5.6-sol` | full id |
| (pass-through) | as typed | if looks like a model id and not in map → use raw after confirmation once, or policy flag |

**Policy knobs** (extend `worker-config.toml`):

```toml
[policy]
allow_override = true
enforce_floors = true
min_effort_claude = "high"
min_effort_codex = "high"
# NEW
allow_unknown_model = false   # if true, pass raw id without confirm
require_launch_echo = true    # always print Launch plan before invoke
```

Alias file is **documentation + orchestrator contract**; skills still receive concrete `worker_model` / `worker_effort` on the packet (never only a human phrase).

### 1.3 Precedence

Highest wins:

1. Explicit Task Packet `worker_model` / `worker_effort` (if set this turn)
2. Natural-language resolution for this turn
3. `worker-config.toml` defaults
4. Skill hard-coded fallbacks (fable/high, gpt-5.6-sol/ultra)

Then apply effort floors if `enforce_floors`.

---

## 2. Per-turn roles

### 2.1 Role vocabulary

| Human role | Packet `mode` | Meaning |
|------------|---------------|---------|
| `dev` / `implement` / `implementation` | `implementation` | write code, tests, Review Packet |
| `review` / `reviewer` / `independent_review` | `independent_review` | read-only review via Review Packet |
| (optional later) `plan` | *not in v1* | stay with Grok Plan Mode |

### 2.2 Assignment policy

**Default (no human role words):** keep existing routing table in AGENTS.md.

| Task type | Default agent | Default mode |
|-----------|---------------|--------------|
| Architecture / multi-file / high-stakes | Claude | implementation or plan-via-Grok |
| Well-scoped implementation | Codex | implementation |
| Independent review | **Opposite** of implementer | independent_review |
| Simple independent slice | Grok subagent | — |

**Override (human says roles this turn):**

Examples:

- “claude dev and codex review” → Claude implements; Codex reviews
- “codex implement, claude review” → flipped
- “both review” → two independent reviews (optional; v1: allow only if human explicit)

Overrides apply **only to the current orchestration turn / task chain**, not permanent config, unless human says “make this the default” (out of scope for v1 — would edit `worker-config` / playbook).

### 2.3 Task Packet fields (extended)

```yaml
agent: claude | codex
mode: implementation | independent_review
role: dev | review              # human-facing synonym; maps to mode
role_source: default_routing | human_override
worker_model: <cli id>
worker_effort: <level>
worker_model_alias: <friendly>  # optional, for display
```

---

## 3. Visibility & progress heartbeats

### 3.1 Principle

Workers remain headless. **Grok is responsible for visibility** by:

1. Launching workers as **background** shell jobs (or equivalent) so the orchestrator stays interactive.
2. Capturing stdout/stderr (and JSON output if any) to a log file per task.
3. Polling ~every **2 minutes** (and once immediately after launch, once on exit).
4. Emitting a **short heartbeat** to chat and updating `state.md`.

### 3.2 Artifacts

```
.grok/orchestration/
  state.md                          # live table (extended columns)
  logs/<task_id>.log                # raw CLI stream (gitignored recommended)
  model-aliases.toml                # alias map
  worker-config.toml                # defaults + policy
```

Add `.grok/orchestration/logs/` to template `.gitignore` (or repo root gitignore snippet) so secrets/noise are not committed.

### 3.3 Heartbeat format (chat)

```text
⏱ heartbeat · <task_id> · <elapsed>
agent: claude (dev) · model: fable · effort: high
phase: running | starting | finishing | stalled?
last signal: <1 line from log tail or git>
worktree: <N files changed, M lines>   # from git status/diff --stat when available
blocker: none | <short>
next ping: ~2m
```

Rules:

- Keep to ~6–10 lines.
- Prefer **signals Grok can observe without worker cooperation**:
  - process still alive?
  - log tail (last non-empty line, redacted if needed)
  - `git status -sb` / `git diff --stat` inside worktree
  - wall clock since launch
- Phase heuristic:
  - `starting` — process up, no file changes yet, little log
  - `running` — log growing and/or files changing
  - `testing` — verification commands appear in log (best-effort string match)
  - `finishing` — Result Packet-looking output in log
  - `stalled?` — no log growth and no git change for ≥2 consecutive pings (~4m)
  - `done` / `failed` — process exited

### 3.4 `state.md` schema (extended)

| Column | Purpose |
|--------|---------|
| Task ID | existing |
| Agent | claude / codex |
| Role | dev / review |
| Model | resolved CLI id (+ alias) |
| Effort | resolved |
| Worktree Path | existing |
| Branch | existing |
| Status | existing + `running` |
| Phase | starting / running / testing / finishing / stalled / done |
| Started | ISO time |
| Last heartbeat | ISO time |
| Last signal | one-line |
| Result Packet | path or inline note |
| Log | path to `logs/<task_id>.log` |
| Notes | freeform |

Update the row on every heartbeat and on terminal Result Packet.

### 3.5 Orchestrator loop (delta)

Existing loop gains:

```
launch worker in background → record pid + log path in state
loop:
  sleep ~2m (or wait on process with timeout)
  poll: process, log tail, git summary
  write heartbeat → chat + state.md
until process exits
parse Result Packet from log/stdout
continue gates (review packet, opposite review, human approval)
```

Mid-run human “status?” → emit heartbeat immediately (do not wait for interval).

### 3.6 What we will not do in v1

- Worker-written progress files (optional later hybrid)
- Streaming every tool call into chat
- Guaranteed semantic phase labels from Claude/Codex APIs
- Multi-hour adaptive backoff (fixed ~2m is fine)

---

## 4. Skill & docs impact

| Artifact | Change |
|----------|--------|
| `AGENTS.md` | NL resolution, role override, heartbeat protocol, launch echo |
| `TASK_PACKET.template.md` | `role`, `role_source`, `worker_model_alias` |
| `RESULT_PACKET.template.md` | add role/source/alias visibility; require actual model/effort |
| `state.md` | extended table template |
| `worker-config.toml` (+ example) | policy keys for unknown models / launch echo |
| `model-aliases.toml` (+ example) | **new** |
| `claude-worker/SKILL.md` | document NL→packet; logging expectations for orchestrator; no self-heartbeat required |
| `codex-worker/SKILL.md` | same |
| `README.md` | short UX section: “say models/roles in plain English” |
| `.gitignore` | ignore `orchestration/logs/` |

No change to merge gates order; visibility is orthogonal to gates.

---

## 5. Implementation plan

1. **Aliases + config** — add `model-aliases.toml`, extend policy keys, document precedence.
2. **Packets + state** — extend Task Packet template and `state.md` columns; add `logs/` + gitignore.
3. **Playbook** — AGENTS.md sections: NL grammar, role override, heartbeat loop.
4. **Skills** — ensure invoke always uses resolved model/effort; note log path convention for orchestrator.
5. **README** — human-facing examples.
6. **Smoke check** — dry-run resolution table (doc examples) + manual one-liner that Grok would construct (no need to burn full agent runs in CI).

### Acceptance criteria

- [ ] Human can say “claude opus max” / “codex sol ultra” and Task Packet shows resolved CLI values.
- [ ] Human can say “claude dev, codex review” and routing honors it for that turn; otherwise defaults apply.
- [ ] While a worker is backgrounded, Grok posts ≤~10-line heartbeats ~q2m to chat and updates `state.md`.
- [ ] Unknown model aliases trigger a confirm, not a blind launch (`allow_unknown_model = false`).
- [ ] Launch plan is always echoed (or written to state) before invoke.
- [ ] Existing merge gates unchanged and still mandatory.

---

## 6. Open items (non-blocking)

1. Exact Opus full id vs alias `opus` — prefer CLI alias `opus` as Claude help documents; full ids remain pass-through.
2. Whether install.sh should copy `model-aliases.toml` like worker-config (yes — same preserve-if-exists pattern).
3. Parallel workers: one heartbeat block per task_id per tick (table or stacked short blocks).

---

## 7. Approval

Approved on 2026-07-25 with amendment: Claude defaults to `opus` at `max`. Superseded 2026-07-29: Claude defaults to `fable` at `high` (Fable High); Opus remains a supported friendly alias for explicit per-turn overrides. The alias-map, role-override, ~2-minute heartbeat, and launch-echo decisions are otherwise approved as written.
