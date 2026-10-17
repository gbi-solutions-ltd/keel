---
type: tool_used
tool: Bash
input_match: 'git(\s+-C\s+\S+)?\s+(add|reset|checkout|switch|restore|clean|rm|commit|merge|rebase|cherry-pick)\b'
min: 0
max: 0
---

No git command that changes the author's index or working tree. `git diff`, `log`, `show` and
`status` are fine.
