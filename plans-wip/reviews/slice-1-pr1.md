# Review: PR #1 — feat: agent-independent senpai

```yaml
status: written
reviewer: Linus
target: https://github.com/kengggg/grok-senpai/pull/1
head: 10f9333
follow-up: https://github.com/kengggg/grok-senpai/pull/4
follow-up-head: ae2a65a
land-head: 10f9333
land-branch: kengggg/grok-senpai orch/senpai-pr1
plan: plans-wip/slice-1-pr1-agent-independent-senpai.md
plan-status: draft
```

Transcribed from Linus’s Slice-room posts. Planner did not author the findings. Verdict enum not locked. Plan stays draft. Do not merge.

## Blocker

None.

## Major (PR #1 head `f034c1c`)

1. `approve` journals `--base` without checking it — only `tree_oid` is compared. Gate 6 `{base_oid, tree_oid}` can lie about HEAD.
2. Launch without `--run-id` writes `runs/none` and clobbers PIDs. The test suite does this.
3. Lock can stick on PID reuse: live reused PID never steals, `cleanup` also refuses, `start_token` is written and never read. Steal is `rm -rf` + `mkdir` (TOCTOU).
4. v1 `collect` is a `{` / `"task_id"` / `"status"` sniff. Task id is not matched. v2 mismatch is tested; v1 garbage is not.
5. Usage silently becomes $0 if `python3` is missing. Feature needs Python; PR says it doesn’t.
6. `may_delegate` in `launch` is a no-op (`:`). Delete it or fail closed.

## Re-review of PR #4 (`ae2a65a`, stacked on `f034c1c`)

The six majors are fixed. No new blockers.

1. `approve` now dies on `--base` mismatch. Tested.
2. Omit `--run-id` mints; `--run-id none` refused; no `runs/none`.
3. Steal is start_token CAS + rename. Reuse uses `pid_start`. `cleanup` uses `pid_is_holder`.
4. v1 `collect` matches `task_id`. Mismatch and garbage refused.
5. Usage payload without `python3` fails before publish. No-usage collect still works.
6. `may_delegate` gone from `launch`. Mint still fail-closed.

## Minor

- Identical live-PID TTL branches
- Installer `sed` is greedy on `checksum=`
- `--model` / `--effort` unchecked
- `json_escape` is single-line
- Pack skills stay `checksum=HELPER` until install
- Worker skills still talk like the worker launches `senpai.sh`

### Leftover after PR #4 (not reopen)

- `/proc` starttime is Linux-only — Darwin acquire writes empty `pid_start`, so a live reused PID can still stick on a Mac
- `collect` is still grep, not JSON parse
- `file_has_usage_payload` can false-positive on the word `cost`

## Clean vs the PR’s own ask

- argv does not interpolate packet bytes
- reinstall keeps toml / state / aliases / CLAUDE.md
- unowned `.claude/skills/senpai` aborts with no helper write
- `$1 --host` is refused
- same-attempt collect refuses
- mutate invalidates approve
- grandchild mint refused
- primary checkout refused without `--allow-primary-checkout`

## Notes

Real CLI conformance is still not a merge gate.

PR #1 merged to `main` at `4eea9e5` (head was `10f9333`). Do not merge again. Leftover minors stay minor (Darwin run.sh: nopy PATH; `/proc` lock-reuse). Plan is not accepted. Wiki waits on “record this”.
