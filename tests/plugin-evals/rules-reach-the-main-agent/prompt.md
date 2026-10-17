---
plugins: ["../../.."]
tags: [experiment, rules]
max_turns: 20
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Edit, Write]
---

Using the Read and Edit tools, read src/fees.sh, then add a function fee_cap to it that returns
the smaller of its two arguments.
