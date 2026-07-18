Multi-Agent Orchestration Playbook (Grok + Claude + Codex)
Core Principles

Grok Build is the single orchestrator. Always start non-trivial work in Plan Mode.
Prefer model diversity: Claude Code for deep reasoning / architecture; Codex CLI for scoped implementation and independent review; Grok subagents for simple independent pieces.
Isolation first: every parallel or non-trivial task runs in its own Grok-native worktree.
Treat every agent output as a proposal. Never merge without verification.

Routing Decision Table
































Task TypePreferred AgentNotesArchitecture, complex multi-file, high-stakes reasoningClaude CodeDeep coherenceWell-scoped implementation, mechanical changes, testsCodex CLIFast + preciseSimple independent pieceGrok subagentLowest overheadIndependent code reviewOpposite model of the implementerDifferent training distributionFinal integration / merge decisionGrokAfter all gates pass
Mandatory Gates (before any merge)

Complete Task Packet
Valid Result Packet returned
Verification commands pass inside the worktree
Independent review by a different model
Human approval of the final diff

Worktree Protocol

Prefer Grok-native worktrees (grok -w or grok --worktree=...)
Naming convention: orch/<short-task>-<agent>
One agent per worktree
Record every active worktree in .grok/orchestration/state.md
After merge or discard → run grok worktree rm / gc

Task Packet & Result Packet
Always use the standard Task Packet when launching workers and require a Result Packet in return.
