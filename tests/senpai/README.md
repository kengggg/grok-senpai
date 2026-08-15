# senpai tests

```bash
bash tests/senpai/run.sh          # PR 1 + PR 2 acceptance (fake runners)
bash tests/senpai/conformance.sh  # PR 3 matrix + real-CLI probes
```

No live implement/review sessions. If `claude` / `codex` are on PATH, conformance **fails** when they cannot see the installed senpai skill (`claude plugin validate`, `codex debug prompt-input`). Sandbox fencing of `git-common-dir` stays UNKNOWN.
