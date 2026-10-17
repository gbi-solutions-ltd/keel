---
type: tool_used
tool: Read
input_match: 'rubric\.md'
---

The driver reads `rubric-pass.md` and is told never to read `rubric.md`, so a Read of `rubric.md`
can only be the subagent's, and it passes only if a subagent's own calls reach the transcript.
