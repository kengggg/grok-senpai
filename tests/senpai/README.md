# senpai tests

```bash
bash tests/senpai/run.sh          # PR 1 + PR 2 acceptance (fake runners)
bash tests/senpai/conformance.sh  # PR 3 matrix + real-CLI probes
```

No live model calls. Real Claude/Codex binaries, if present, are probed (they reject `--prompt-file`; helper feeds stdin) and never fail the suite.
