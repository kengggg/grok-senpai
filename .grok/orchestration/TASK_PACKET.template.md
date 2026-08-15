# Task Packet Template (grok-senpai)

Copy this file (or paste into the worker prompt) when launching a **claude-worker** or **codex-worker**. See **AGENTS.md** for gates, routing, and thinking-level policy.

```yaml
# v2 fields. Missing keys default: host=grok; created_by=grok-senpai-orchestrator.
# Explicit malformed v2 (protocol_version set but invalid) must fail closed.
protocol_version: 2                 # optional; omit for versionless v1
task_id: <short-id>                 # e.g. feat-auth-001
host: grok | claude | codex         # senpai session; default grok
executor:
  agent_id: claude | codex
  adapter: claude-code | codex-cli
agent: codex | claude               # v1 alias of executor.agent_id
mode: implementation | independent_review
role: dev | review                  # registry-open; extras such as debater allowed
role_source: default_routing | human_override
run_id: <minted by senpai.sh>       # do not invent; helper mints
attempt: 1
session_id: <host session>
parent_run_id: <optional>
max_delegation_depth: 0             # runners cannot mint
worktree_path: <absolute path>      # required isolated worktree for non-trivial work
branch: orch/<short-task>-<agent>
created_by: grok-senpai-orchestrator
parent_task_id: <optional>
allow_primary_checkout: false       # true only if human approved in-place trivial work
review_packet_path: <optional>      # required for independent_review; e.g. .grok/orchestration/reviews/<task_id>.md

# Worker model & effort (optional — defaults from worker-config.toml)
# Defaults: claude → fable + high | codex → gpt-5.6-sol + ultra
# Natural-language choices are resolved before launch; worker_model is the CLI value.
worker_model: <optional>            # e.g. fable | opus | sonnet | gpt-5.6-sol
worker_effort: <optional>           # claude: low|medium|high|xhigh|max
                                    # codex:  low|medium|high|xhigh|max|ultra
worker_model_alias: <optional>      # friendly display value, e.g. fable | sol
# Omit both fields to use high/ultra defaults. Only lower when policy + task shape allow.

goal: |
  <what to accomplish>

scope:
  in_scope:
    - <item>
  out_of_scope:
    - <item>

acceptance_criteria:
  - <criterion>
  - verification_commands all pass inside the worktree

verification_commands:
  - command: <shell command>
    expect: pass

constraints:
  - Stay strictly inside the worktree
  - Prefer minimal, high-quality changes
  - Do not expand scope
  - Treat output as a proposal; the senpai host reviews independently

deliverables:
  - <files / Result Packet>
```

After launch, record the task in `.grok/orchestration/state.md`.
