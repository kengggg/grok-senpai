# Slice Discovery Board

Candidate slices for grok-senpai. First written after Keng said “record this” and [wiki/slice-1-agent-independent-senpai.md](../wiki/slice-1-agent-independent-senpai.md) landed (`56a809d`). Refreshed 2026-08-15 against `main` `5bd61f3`. No requirement IDs invented.

## Tier Classification

| Tier | Criteria |
|---|---|
| T1 - Foundation | Must ship first; other slices depend on it |
| T2 - Core Value | High user value, few dependencies |
| T3 - Enhancement | Nice to have, can defer |
| T4 - Blocked | Has unresolved unknowns |

## Candidates

### T1 - Foundation

None. Slice-1 (helper + three host adapters) is closed.

### T2 - Core Value

None open. Journal cutover, leftover nits, installer `--host`, and additive `.senpai/` landed as follow-ups, not as new requirement IDs.

### T3 - Enhancement

From [wiki/slice-1-agent-independent-senpai.md](../wiki/slice-1-agent-independent-senpai.md) “Not this slice”. Later work. No IDs.

| # | Candidate | Source | Status | Dependencies | Notes |
|---|---|---|---|---|---|
| - | SQLite; required Python/jq | wiki/slice-1 | later | slice-1 | Debate plan said these are not a floor. Do not start. |

`.senpai/` additive state and public `--host` were on this list; they landed in #16 without a `.grok/` + `AGENTS.md` flag day.

### T4 - Blocked

| # | Candidate | Source | Status | Dependencies | Notes |
|---|---|---|---|---|---|
| - | Proven Claude/Codex host parity | wiki/slice-1 · #10 | blocked | slice-1 | Fake-runner tests stay the merge gate. Launch now uses stdin (#15). Still UNKNOWN: live implement×review, skill discovery fire, sandbox fence of git-common-dir. Do not claim proven until a human labels a host. |

## Recently Closed

| # | Candidate | Source | Status | Notes |
|---|---|---|---|---|
| 1 | Agent-independent senpai (helper + three host adapters) | PR#1 · PR#4 | closed | wiki/slice-1 · `main` `4eea9e5` · wiki `56a809d` |
| - | Darwin PID-reuse lock steal | #12 · #7 | closed | `20720e3` |
| - | Journal cutover (`state.md` is render) | #9 | closed | Already on slice-1 helper; verified on `7e7f522` |
| - | `collect` JSON parse + `cost` is not usage | #12 · #13 | closed | `7e7f522` |
| - | Record real-CLI `--prompt-file` rejections | #10 · #14 | closed | Probe only; parity still T4 |
| - | Runner prompt on stdin (no `--prompt-file`) | #10 · #15 | closed | `187e120`; parity still T4 |
| - | Installer `--host` / `--target` + additive `.senpai/` | #11 · #16 | closed | `5bd61f3`; no pack flag day |

## Tests as of `5bd61f3`

Claimed on #16: `bash tests/senpai/run.sh` 89/89, `conformance.sh` 13/13. Fake runners only. No live model calls.

---

## Board Maintenance

- Add new candidates during slice discovery sessions.
- Move to "Recently Closed" when the work is on `main` and (for named slices) a wiki article exists. Follow-ups without a wiki page stay listed here with their issue/PR.
- Update dependencies as exploration reveals new relationships.
- Do not invent requirement IDs.
