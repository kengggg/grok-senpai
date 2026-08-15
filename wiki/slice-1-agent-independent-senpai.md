# Slice 1 — Agent-independent senpai

Recorded 2026-08-15 after Keng said “record this”.
This page is what landed on `kengggg/grok-senpai` `main` at `4eea9e5`. It is not a plan.

```yaml
status: recorded
slice: slice-1
landed: 4eea9e5
via:
  - https://github.com/kengggg/grok-senpai/pull/1
  - https://github.com/kengggg/grok-senpai/pull/4
land-commit: 10f9333
compiled-from:
  - plans-wip/slice-1-pr1-agent-independent-senpai.md
  - plans-wip/reviews/slice-1-pr1.md
  - exploration/sessions/2026-08-15-pr-1-agent-independent-senpai.md
```

No requirement IDs were on the board. None are invented here.

## Landed

`4eea9e5` is the merge of write-lane `e05adc5` and `10f9333`. `10f9333` is PR #1 (`f034c1c`) plus the six review majors from PR #4.

### Session role

Senpai is a session role: the session that holds the task-chain lease and the human-approval conversation. It is not a product or model name. Product name stays `grok-senpai`. Live disk and pack root stay `.grok/` + `AGENTS.md`.

| Role | Who | Skill |
|------|-----|--------|
| Senpai host (default / proven) | Grok Build | `.grok/skills/senpai/` |
| Senpai host (experimental) | Claude Code / Codex CLI | `.claude/skills/senpai/` · `.agents/skills/senpai/` |
| Worker (deep reasoning / architecture / high-stakes review) | Claude Code runner | `.grok/skills/claude-worker/` |
| Worker (scoped implementation / mechanical review) | Codex CLI runner | `.grok/skills/codex-worker/` |

Claude/Codex as senpai host stay experimental until a human labels a host proven. Real-CLI conformance is not a merge gate.

### Helper

Pack-floor helper: `.grok/orchestration/senpai.sh`. Flags only. No `eval`. No packet-byte interpolation on argv. Launch uses `--prompt-file`. Do not record `tee … &` as the worker PID. Launch refuses `--agent senpai`.

Verbs in the landed `usage()`:

`control-root`, `checksum`, `import`, `lock`, `mint`, `launch`, `collect`, `usage-record`, `usage-show`, `snapshot`, `approve`, `render`, `doctor`, `status`, `cleanup`

Isolation: `git-dir` ≠ `git-common-dir` unless `--allow-primary-checkout`.

### Three host adapters

Installer writes the same managed host skill to:

- `.grok/skills/senpai/SKILL.md`
- `.agents/skills/senpai/SKILL.md`
- `.claude/skills/senpai/SKILL.md`

Checksum-bound to the helper (`senpai-managed:checksum=`). Unowned skill at a destination (missing the marker) aborts with no writes. Live worker PID recorded in `state.md` refuses overwrite unless `GROK_SENPAI_FORCE=1`. `$1` is the target directory; a leading `--*` including `--host` is refused.

Reinstall keeps existing `worker-config.toml`, `state.md`, `model-aliases.toml`, and `CLAUDE.md`.

Worker skills are runner-contract docs. Workers launch only through the helper (`--agent claude|codex`).

### Packets and usage

Task Packet v2 fields are additive. Missing keys default (`host` ⇒ grok; `created_by` ⇒ grok-senpai-orchestrator). Malformed explicit v2 fails closed. `run_id` is minted by the helper. Same-attempt republish fails. Worker `merge` is ignored.

One framed JSON Result. Publish via `collect` (stdout is logs, not the contract). Versionless results are legacy v1 and must match `task_id`. v1 garbage is refused.

Unified `usage` object, both parties, same shape: `uncached_input`, `cache_read`, `cache_write`, `reasoning`, `output`, `cost`. Written to `.grok/orchestration/ledger.jsonl` and rolled up at `.grok/orchestration/runs/<run_id>/usage.json`. Collect with a usage payload and no `python3` fails closed (does not record `$0`). Collect with no usage payload still works.

### Approval (Gate 6)

`approve --base OID --tree OID` journals only when a fresh snapshot matches **both** `base_oid` and `tree_oid`. Human assent plus that journaled pair is Gate 6.

### Six majors that landed with this slice (PR #4 onto `10f9333`)

1. `approve` checks `--base` as well as `--tree`.
2. Launch without `--run-id` mints a real run. `--run-id none` is refused. No `runs/none`.
3. Stale locks recover via recorded `pid_start` / `start_token`. Steal is rename compare-and-swap.
4. v1 `collect` matches `task_id`. Mismatch and garbage are refused.
5. Usage payload without `python3` fails closed. No-usage collect still works.
6. `may_delegate` is gone from `launch`. `mint` still fail-closed on delegation.

Linus review: no blockers after these six. PR #4 body reported `bash tests/senpai/run.sh` 74/74 and `bash tests/senpai/conformance.sh` 9/9 (fake runners). Those counts were not re-run for this wiki page.

### Routing as landed in `AGENTS.md`

Independent review is a distinct session. Prefer a different provider than the implementer, not than the host. Reviewers are runners: they must not `lock` or `mint`. Nested senpai has no argv arm.

The same file’s mandatory-gates list still says “Independent review by a different model”. Both sentences are on `main`. This page does not pick one.

## Not this slice

These were out of scope on PR #1 and stay later work:

- Moving live state to `.senpai/`
- Public `--host` installer flag
- SQLite; required Python/jq
- Claiming proven Claude/Codex host parity

Leftover review nits after PR #4 (Linus: not reopen for this slice), including Darwin `/proc` starttime / live reused PID on Mac, `collect` still grep rather than JSON parse, and `file_has_usage_payload` false-positive on the word `cost`. Later, not this page.

## Sources

- https://github.com/kengggg/grok-senpai/pull/1 (merged)
- https://github.com/kengggg/grok-senpai/pull/4 (merged; six majors)
- `main` `4eea9e5` / land commit `10f9333`
