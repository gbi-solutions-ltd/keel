---
type: tool_used
tool: Agent
input_match: '"subagent_type"\s*:\s*"(?:keel:)?keel-reviewer"'
---

The rubric pass runs as `keel-reviewer`, the agent type `hooks/review-guard` holds to its git
rules. Claude Code may report the plugin's agent as `keel:keel-reviewer`, so the prefix is optional.
