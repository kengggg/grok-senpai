# Exploration session 2026-08-15-pr-1

Session id: `2026-08-15-pr-1`
Who writes: Analyst
Lane: `exploration/sessions/` only. This is not wiki. Nothing here is accepted project truth.

Opened: 2026-08-15 (Asia/Bangkok)
Human ask: open an exploration session on GitHub PR #1.

## Source

- GitHub PR: https://github.com/kengggg/grok-senpai/pull/1
- Title (as filed): feat: agent-independent senpai (helper + three host adapters)
- State when read: OPEN
- Base: `kengggg/grok-senpai` `main`
- Head: `alphygogo/grok-senpai` `orch/senpai-pr1` @ `f034c1cd256a564a6173ee8cc270044a15f3cd95` (cross-repo)
- Author on GitHub: alphygogo (alphy)
- Created: 2026-08-15 07:07 ICT
- Last push on the PR: 2026-08-15 07:15 ICT
- Reviews / issue comments when read: none
- CI / status checks when read: none reported on the head branch

Commits on the PR (headlines only):

1. `41f2132` feat: agent-independent senpai helper and host adapters
2. `4e4c03a` feat: unified usage object on the shared run ledger
3. `f034c1c` docs: require usage.senpai and usage.worker on the run ledger

Companion `PLAN.md` is named in the PR body (“debate plan in the companion playground”). It was not found in `kengggg/grok-senpai` on `main` or via code search in that repo. Not treated as present.

GitHub PR #2 on the same repo (`docs: add write-lane folder skeleton`) is a different change, already merged to `main` on 2026-08-15 10:28 ICT. It is not this PR.

## What the PR body claims

Quoted/paraphrased from the PR description, not adopted as decisions:

- Make senpai a **session role** so Grok, Claude, or Codex can host.
- Implementation “follows the debate plan in the companion playground (`PLAN.md`)”: helper on the pack floor, three discovery roots, no `eval`, one framed JSON Result, snapshot-bound approval.
- Lands “four planned slices in one reviewable PR” because they share `senpai.sh` and the test harness.
- Non-Grok hosts stay **experimental** until real-CLI conformance.
- Helper verbs listed in the PR body: `lock mint launch collect snapshot approve import render doctor status cleanup`
- Installer copies the helper, writes managed skills to `.grok/skills/senpai`, `.agents/skills/senpai`, `.claude/skills/senpai`, refuses unowned collisions and live PIDs, never treats `--host` as a flag.
- Worker skills launch only through the helper (no `eval`, no `tee` PID).
- One JSON Result contract; Task Packet gains additive v2 fields with v1 defaults.
- `AGENTS.md` / `CLAUDE.md` / README: Grok is the proven host; others experimental.
- Verification table in the PR: `bash tests/senpai/run.sh` pass (48/48); `bash tests/senpai/conformance.sh` pass (8/8); real `claude` / `codex --prompt-file` UNKNOWN (probed, not a merge gate).
- Out of scope (PR body): moving live state to `.senpai/`; public `--host` installer flag (today `$1` is the target directory); SQLite, required Python/jq; claiming proven Claude/Codex host parity.
- Reviewer asks in the PR: helper argv never interpolates packet bytes; existing `worker-config.toml` / `state.md` survive reinstall; unowned `.claude/skills/senpai` aborts with no writes.

This session does not accept or reject those claims.

## Files on the PR (as listed by `gh pr diff --name-only`)

- `.agents/skills/senpai/SKILL.md` (new)
- `.claude/skills/senpai/SKILL.md` (new)
- `.grok/skills/senpai/SKILL.md` (new)
- `.grok/orchestration/senpai.sh` (new)
- `.grok/orchestration/TASK_PACKET.template.md`
- `.grok/orchestration/RESULT_PACKET.template.md`
- `.grok/orchestration/worker-config.toml`
- `.grok/skills/claude-worker/SKILL.md`
- `.grok/skills/codex-worker/SKILL.md`
- `.gitignore`
- `AGENTS.md`
- `CLAUDE.md` (new)
- `README.md`
- `install.sh`
- `tests/senpai/README.md`
- `tests/senpai/conformance.sh`
- `tests/senpai/fakes/claude`
- `tests/senpai/fakes/codex`
- `tests/senpai/run.sh`

Stat from GitHub when read: +1952 / −259.

The three host `SKILL.md` files read as the same host-adapter text (checksum header `senpai-managed:checksum=HELPER`).

## What the branch text actually says (read, not decided)

### Senpai as a role

`AGENTS.md` on the PR head opens: senpai is a *session role* (the session that holds the task-chain lease and the human-approval conversation), not a product or model name. Product name stays `grok-senpai`. Live disk and pack root stay `.grok/` + `AGENTS.md`.

Role table on the PR head:

- Senpai host (default / proven): Grok Build — `.grok/skills/senpai/`
- Senpai host (experimental): Claude Code / Codex CLI — `.claude/skills/senpai/` · `.agents/skills/senpai/`
- Workers remain Claude Code and Codex CLI runners, launched only through `.grok/orchestration/senpai.sh`

`CLAUDE.md` on the PR head: Claude Code may be the senpai host (experimental) or a worker. Launch workers only through the helper. Never `eval`.

### Helper

`.grok/orchestration/senpai.sh` header: pack-floor helper; flags only; never eval; never parse packets.

Header comment verbs: `control-root | checksum | lock | mint | launch | collect | snapshot | approve | render`

Skill verb table also lists `usage-record`, `usage-show`. The script also defines `import`, `doctor`, `status` (alias of `render`), `cleanup`. The PR body lists a third set (includes `import render doctor status cleanup`, omits `control-root` / `checksum` / `usage-*`).

Launch path in `AGENTS.md` on the PR head replaces the old `tee … &` canonical launch with `senpai.sh launch --agent … --prompt-file …`. Skill text: never `-p "$(cat …)"` from a skill; never record `tee … &` as the PID.

`install.sh` on the PR head: if argv looks like `--host`, prints that `--host` is reserved until option parsing lands; today `$1` is the target path. Refuses overwrite when a live worker pid is recorded in `state.md` unless `GROK_SENPAI_FORCE=1`. Aborts with no writes if a destination skill exists without the `senpai-managed` marker.

### Packets and usage

Task Packet template: additive v2 fields; missing keys default `host=grok`, `created_by=grok-senpai-orchestrator`; malformed explicit v2 must fail closed. `run_id` minted by the helper. `max_delegation_depth: 0`. `role` called registry-open (extras such as `debater` allowed). `allow_primary_checkout: false` unless the human approved in-place trivial work.

Result Packet template: one framed JSON schema; publish via `collect` (stdout is logs, not the contract). Versionless Claude JSON / Codex structured text accepted only as legacy v1. Worker `merge` is ignored. Same-attempt republish fails. Unified `usage` with `senpai` and `worker` parties (`uncached_input`, `cache_read`, `cache_write`, `reasoning`, `output`, `cost`). Ledger path named: `.grok/orchestration/ledger.jsonl` and `.grok/orchestration/runs/<run_id>/usage.json`.

`.gitignore` on the PR adds `.grok/orchestration/journal.jsonl`.

### Gates / review (as written on the branch)

Skill: `approve` only after the human assents **and** a fresh snapshot still matches. Gate 6 described as the live conversation plus the journaled `{base_oid, tree_oid}`.

Routing table on the PR head: independent review is a distinct session; prefer a different provider than the implementer (not than the host).

Skill: reviewers are runners; they must not `lock` or `mint`. Prefer a distinct provider versus the implementer; never require a distinct provider versus this host. Nested senpai has no argv arm. Packet-supplied `depth` is ignored. Generation 0 is this session.

`AGENTS.md` “How the senpai host runs a task” step 7 on the same branch still says: launch independent review with a **different model**.

Stall rule on the PR head: two unchanged polls **and** ≥4 minutes. Grok default poll cadence remains ~2 minutes; every host must also poll on each turn and before every gate.

### Tests (as written)

`tests/senpai/README.md`:

```text
bash tests/senpai/run.sh          # PR 1 + PR 2 acceptance (fake runners)
bash tests/senpai/conformance.sh  # PR 3 matrix + real-CLI probes
```

Those “PR 1 / PR 2 / PR 3” labels are inside the test comments. They do not match GitHub PR numbers on `kengggg/grok-senpai` (GitHub #1 is this change; GitHub #2 is the write-lane skeleton).

`run.sh` section comments include: fresh install, reinstall preserves toml/state/aliases/CLAUDE.md, unowned collision aborts, live PID refuses overwrite, launch records numeric pid, metacharacters stay in the prompt file not argv, review launch has no acceptEdits/write tools, Codex review uses read-only sandbox, oversized prompt is a path, collect/usage ledger both parties, snapshot + approve, lock steal after dead pid + TTL, mint parent/child, copy-pack walk-up, sequential launch with spoken allow, then a block titled “PR 2: journal import” (import backup, sot=journal, legacy meta resumable=0 / may_delegate=0, render watermark).

`conformance.sh` header: “PR 3 — conformance. Fake matrix always runs. Real CLI probes are informational and do not fail the suite (UNKNOWN until a human labels a host proven).”

This session did not re-run the suites. Author-claimed 48/48 and 8/8 are unverified here. No GitHub checks were attached to the head branch when read.

## Observations that are not decisions

These are tensions or gaps in the source. No resolution is recorded.

1. In-repo test labels “PR 1 + PR 2” / “PR 3” vs GitHub PR #1 / already-merged GitHub PR #2. Companion `PLAN.md` was not in this repo when searched.
2. Reviewer constraint is not one sentence across the branch: routing table + skill vs “How the senpai host runs a task” step 7 (“different model”).
3. Helper verb lists are not identical across PR body, skill table, and `senpai.sh` header (see Helper above).
4. Real Claude/Codex as senpai host: PR and conformance script both mark UNKNOWN / experimental. No human label of “proven” was found in-repo.
5. PR #1 head is a fork branch from before write-lane folders landed on `main`. Whether that merge is clean was not checked here.
6. `role` extras such as `debater` appear in the Task Packet template. No registry file for those extras was in the PR file list.
7. `import` exists in the helper and in `run.sh` (“PR 2: journal import”) while the skill verb table omits it.
8. Author of the PR is not the repo owner. No review thread yet.

## Out of scope (copied from the PR body, not expanded)

- Moving live state to `.senpai/`
- Public `--host` installer flag
- SQLite, required Python/jq
- Claiming proven Claude/Codex host parity

## Stop

Do not promote this file to `wiki/`.
Do not treat any row above as an accepted requirement, slice, or merge decision.
Do not invent requirement IDs or HTTP codes.

Wiki or board truth only after the human says “record this”.
