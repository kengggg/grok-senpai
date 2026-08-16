# Slice 1: Agent-independent senpai (helper + three host adapters)

```yaml
status: accepted
tier: T1
source: PR#1
land-head: 10f9333
merged-to-main: 4eea9e5
wiki: wiki/slice-1-agent-independent-senpai.md
wiki-commit: 56a809d
land-branch: kengggg/grok-senpai orch/senpai-pr1
depends-on: []
blocks: []
```

**Accepted** after Keng said “record this” and [wiki/slice-1-agent-independent-senpai.md](../wiki/slice-1-agent-independent-senpai.md) landed on `main` (`56a809d`). No requirement IDs invented.

## Role pin

| Role | Who |
|------|-----|
| Coordinator | Keng (decisions) / Samantha (routing only) |
| Planner / author | Planner |
| Phase writer | Claude Code — standby; implement only accepted phases if Keng asks |
| Reviewer | Linus — blocking review of PR #1 |
| Integrator / committer | Keng |

## Sources traced

| Source | Status | Used as |
|--------|--------|---------|
| [wiki/](../wiki/README.md) | empty shell — “nobody promotes here unless the human said record this” | no compiled articles |
| `plans-wip/0-candidate-slices.md` | **missing** | no board rows |
| Analyst `exploration/sessions/` | empty shell | no exploration to cite |
| [PR #1](https://github.com/kengggg/grok-senpai/pull/1) | **merged** to `main` at `4eea9e5` (head was `10f9333`) | named slice source |
| kengggg `orch/senpai-pr1` | same commit `10f9333` | land head |

PR #1 landed on `main` at `4eea9e5`. That is not wiki truth. Plan stays draft. Nobody promotes until Keng says “record this”.

## Scope

### Included (what PR #1 claims to land)

- Senpai as a **session role**, not a product/model name. Grok is the proven host; Claude/Codex hosts stay experimental.
- Pack-floor helper `.grok/orchestration/senpai.sh` (flags only; no `eval`; no packet-byte interpolation on argv).
  Verbs named in the helper usage: `control-root`, `checksum`, `import`, `lock`, `mint`, `launch`, `collect`, `usage-record`, `usage-show`, `snapshot`, `approve`, `render`, `doctor`, `status`, `cleanup`.
- Three discovery-root host skills, installer-managed, checksum-bound to the helper:
  `.grok/skills/senpai/`, `.agents/skills/senpai/`, `.claude/skills/senpai/`.
- Installer copies the helper; `$1` is the target directory; a leading `--*` (including `--host`) is refused. Unowned skill collisions abort with no writes. Live PIDs in `state.md` refuse overwrite unless `GROK_SENPAI_FORCE=1`. Reinstall keeps existing `worker-config.toml` / `state.md` / `model-aliases.toml` / `CLAUDE.md`.
- Worker launch only through the helper (`--agent claude|codex`). Worker skills are runner-contract docs, not an alternate launch path. No `tee … &` as recorded PID. Isolation: `git-dir` ≠ `git-common-dir` unless `--allow-primary-checkout`.
- One framed JSON Result (`protocol_version: 2`). Task Packet gains additive v2 fields; missing keys default (`host` ⇒ grok). Same-attempt republish fails. Worker `merge` is ignored.
- Unified `usage` object (`senpai` + `worker`: `uncached_input`, `cache_read`, `cache_write`, `reasoning`, `output`, `cost`) on the shared run ledger (`.grok/orchestration/ledger.jsonl`) and `runs/<id>/usage.json`.
- Snapshot-bound approval: `approve` journals only if a fresh tree still matches.
- Docs: `AGENTS.md` / `CLAUDE.md` / README — Grok proven; others experimental.
- Fake-runner tests only: `bash tests/senpai/run.sh`, `bash tests/senpai/conformance.sh`.

### Excluded (PR #1 out of scope — do not treat as this slice)

- Moving live state to `.senpai/`
- Public `--host` installer flag (today `$1` is the target directory)
- SQLite; required Python/jq
- Claiming proven Claude/Codex host parity
- Real `claude` / `codex --prompt-file` conformance (PR marks UNKNOWN; not a merge gate)
- Merge of PR #1
- Promote anything to `wiki/`

## Phases

Work is already on `orch/senpai-pr1`. Phases are independently verifiable review/land chunks, not a rewrite. Claude Code does not implement unless Keng accepts this plan and asks.

### Phase 1: Helper contract

- [ ] Confirm helper argv never interpolates packet bytes (`--prompt-file` only; metacharacters stay in the file).
- [ ] Confirm verbs above; lock/mint/launch/collect/snapshot/approve/import/render behave as the PR asks reviewers to check.
- [ ] Confirm launch refuses `--agent senpai`, refuses non-isolated cwd without `--allow-primary-checkout`, and does not record `tee` as PID.

### Phase 2: Installer + three host adapters

- [ ] Confirm installer writes helper + three host skills with matching `senpai-managed:checksum`.
- [ ] Confirm unowned `.claude/skills/senpai` (or sibling) aborts with no writes.
- [ ] Confirm live PID refuses overwrite; `GROK_SENPAI_FORCE=1` is the escape.
- [ ] Confirm reinstall leaves `worker-config.toml` / `state.md` byte-identical.

### Phase 3: Packet + usage ledger

- [ ] Confirm Task Packet v2 fields are additive with v1 defaults; malformed explicit v2 fails closed.
- [ ] Confirm one framed JSON Result; same-attempt republish refused.
- [ ] Confirm `usage.senpai` and `usage.worker` land on the same ledger and roll up.

### Phase 4: Verification + land decision

- [ ] Re-run claimed suites on the PR head (see Exit Criteria).
- [ ] Linus blocking review lands at `plans-wip/reviews/slice-1-pr1.md`.
- [ ] Keng accepts or rejects this plan. **Do not mark `accepted` without that.**
- [x] PR #1 merged to `main` (`4eea9e5`). Do not merge again. Wiki waits on “record this”.

## Exit Criteria

- [ ] `bash tests/senpai/run.sh` — PR claims 48/48 (fake runners; no live model calls)
- [ ] `bash tests/senpai/conformance.sh` — PR claims 8/8 (fake matrix; real-CLI probes informational / UNKNOWN)
- [ ] Reviewer ask from the PR body still holds: helper argv never interpolates packet bytes; existing toml/state survive reinstall; unowned skill aborts with no writes
- [ ] Docs do not claim proven Claude/Codex host parity
- [ ] Linus review written; no merge without Keng

Smoke (optional, not a merge gate per the PR): real `claude` / `codex --prompt-file` remains UNKNOWN.

## Risks

- **One PR, four planned slices.** The PR says it lands them together because they share `senpai.sh` and the harness. Review surface is large (+1952/−259). Mitigation: phase the review; do not split the branch unless Keng asks.
- **Fake runners only.** Suites do not prove host parity. Mitigation: keep experimental labeling; do not gate merge on real CLIs unless Keng changes that.
- **No wiki / no board / no Analyst session.** This draft is not compiled truth. Mitigation: wait for Analyst exploration and Keng’s “record this” before treating any of this as board rows or wiki articles.
- **PR head vs current `main`.** `orch/senpai-pr1` does not contain `wiki/`, `plans-wip/`, `coordination/`, `exploration/` (those exist on `main` as shells). GitHub reports `mergeable_state: clean`; still confirm a merge would not drop the KB folders.

## Open Questions

- Keng: accept this plan, reject, or wait for Linus?
- Should later slices (not this one) cover `.senpai/` move, public `--host`, SQLite, proven host parity?
- Test harness comments mention “PR 1 + PR 2 acceptance” and “PR 3” *inside* this one GitHub PR. Those are file comments, not requirement IDs and not extra GitHub PRs.

## Stop

Do not set `status: accepted`. Do not invent requirement IDs. Do not merge PR #1. Do not promote to `wiki/`.
