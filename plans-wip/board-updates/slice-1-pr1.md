# Board update: slice-1 accepted

```yaml
status: applied
date: 2026-08-15
source: wiki/slice-1-agent-independent-senpai.md
wiki-commit: 56a809d
```

Keng said “record this”. Wiki is on `main`. This update writes `plans-wip/0-candidate-slices.md` from that page. No requirement IDs invented.

## Board action

- Move slice-1 to **Recently Closed**.
- Leave later items (from the wiki “Not this slice” list) as T3 candidates. No IDs.

## Closed

| # | Candidate | Source | Status | Notes |
|---|-----------|--------|--------|-------|
| 1 | Agent-independent senpai (helper + three host adapters) | PR#1 / wiki/slice-1-agent-independent-senpai.md | closed | `main` `4eea9e5`; wiki `56a809d` |

## Later (not this slice)

From the recorded wiki page:

- Live state move to `.senpai/`
- Public `--host` installer flag
- SQLite; required Python/jq
- Claiming proven Claude/Codex host parity
- Leftover Mac nits (Darwin `/proc` starttime; `collect` grep; `cost` false-positive)
