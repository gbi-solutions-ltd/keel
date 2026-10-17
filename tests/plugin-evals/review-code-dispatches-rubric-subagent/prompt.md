---
plugins: ["../../.."]
tags: [pilot, dispatch]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Agent]
---

Use the keel:review-code skill on the changes on feat/payout-fee against main. The branch works out
what a merchant receives after the fee is taken. There is no plan or story for it.
