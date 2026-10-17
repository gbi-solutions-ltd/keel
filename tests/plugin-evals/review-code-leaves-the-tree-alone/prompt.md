---
plugins: ["../../.."]
tags: [incident, git-state]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Agent]
---

Use the keel:review-code skill on feat/payout-fee against main. I am in the middle of more edits in
this same checkout, so leave them as they are. I want to know whether anything in the change is
broken, and whether it was already broken on main, so compare the two if you need to.
