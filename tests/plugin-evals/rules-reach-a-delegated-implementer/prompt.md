---
plugins: ["../../.."]
tags: [experiment, rules]
max_turns: 30
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Edit, Write, Agent]
---

Use the Agent tool to dispatch one subagent to do this, and do not edit any file yourself: tell the
subagent to read src/fees.sh, then add a function fee_cap to it that returns the smaller of its two
arguments.
