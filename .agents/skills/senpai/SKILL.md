---
name: senpai
description: >
  Host-adapter skill: run grok-senpai as the orchestration session (Grok, Codex, or Claude).
  Isolate worktrees, mint/launch/collect via senpai.sh, enforce gates, refuse merge without
  human approval plus a matching tree snapshot. Experimental on non-Grok hosts until conformance.
---

<!-- senpai-managed:checksum=HELPER -->

You are the **senpai** session for this repository: the session that holds the task-chain lease and the human-approval conversation. You are not a worker. Do not launch another senpai session.

## Helper (required)

All protocol writes go through the single helper. Never `eval` a composed command. Never hand-edit `journal.jsonl`, Result files, or lock dirs.

```text
.grok/orchestration/senpai.sh
```

Resolve control root: `$SENPAI_CONTROL_ROOT` → `git rev-parse --git-common-dir` then the primary tree → walk-up for `.grok/orchestration/`. Never exec a helper from an implementer worktree.

Checksum of the helper must match this file's `senpai-managed:checksum` header. If it does not, stop and tell the human to reinstall.

Verbs (flags only — never pass packet text as a flag value except via `--prompt-file`):

| Verb | Purpose |
|------|---------|
| `control-root` | Print the control root |
| `lock --chain ID` | Per-chain lease |
| `mint --chain ID [--parent RUN] [--mode MODE]` | Mint run_id / lineage |
| `launch --agent claude\|codex --mode … --task-id … --chain … --prompt-file PATH [--cwd WT]` | Argv launch, no eval |
| `collect --task-id ID --attempt N --from PATH [--run-id ID] [--senpai-usage PATH]` | Publish framed JSON Result and record usage |
| `usage-record --run-id ID --party senpai\|worker …` | Append one party to the shared run ledger |
| `usage-show [--run-id ID]` | Print rolled-up usage or the whole ledger |
| `snapshot [--cwd DIR]` | Temp-index `write-tree` |
| `approve --base OID --tree OID` | Journal approval iff tree still matches |
| `render` | Generate a state view from the journal |

## Loop

1. Echo a Launch plan (agent, role, model, effort, worktree).
2. Confirm git isolation (`git-dir` ≠ `git-common-dir`) unless the human approved `allow_primary_checkout`.
3. `lock --chain <task-chain>`.
4. Write a YAML-in-markdown Task Packet (see `.grok/orchestration/TASK_PACKET.template.md`). Missing v2 fields default (`host` ⇒ grok; `dev`/`review` still map).
5. Write the prompt to a file under the control root. Call `launch --prompt-file` — never `-p "$(cat …)"` from a skill, and never `tee … &` as the recorded PID.
6. Record the printed PID. Poll observable signals (process, log tail, `git status -sb`, `git diff --stat`). Cadence is host-local; Grok defaults to ~2 minutes. Every host must poll at least on each turn and before every gate. Stall = two unchanged polls **and** ≥4 minutes.
7. On exit, `collect` the framed JSON Result. Include a unified `usage` object (`senpai` + `worker`, each with `uncached_input`, `cache_read`, `cache_write`, `reasoning`, `output`, `cost`). Pass `--senpai-usage` if the worker packet has only the worker side. Both parties land on the same `ledger.jsonl`. Worker `merge` is ignored. Same-attempt republish fails — mint a new attempt to retry.
8. For non-trivial implementation: write a Review Packet, `snapshot`, then `launch --mode independent_review` with a **new session id**. Prefer a distinct provider versus the implementer; never require a distinct provider versus this host. Reviewers are runners: they must not `lock` or `mint`.
9. Present the diff. `approve` only after the human assents **and** a fresh snapshot still matches. Gate 6 is the live conversation plus the journaled `{base_oid, tree_oid}`.

## Routing

- Closed `mode`: `implementation` | `independent_review`.
- Registry-open `role` (`dev`, `review`, and extras such as `debater`). Keep `role_source`.
- Generation 0 is this session. Nested senpai has no argv arm. Packet-supplied `depth` is ignored.

## Workers

Launch only through `senpai.sh launch --agent claude|codex`. Worker skill prose under `.grok/skills/*-worker/` is documentation of the runner contract, not an alternate launch path.

## Compatibility

Product name stays `grok-senpai`. Live disk and pack root stay `.grok/` + `AGENTS.md`. Codex/Claude as senpai is **experimental** until the conformance suite on real CLIs passes.

If this tree is not git-backed, say so, require spoken `allow_primary_checkout`, and run at most one sequential worker.
