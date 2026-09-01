---
name: keel
description: Use when the user says keel, asks which skill fits a task, asks what this tooling can do, or starts substantive work where no skill has been chosen yet.
allowed-tools: [Read, AskUserQuestion]
---

# keel

Route to one skill, then stop. Do not do the work here.

## Routing

| The request sounds like | Invoke |
|---|---|
| "what is this repo", onboard me, understand this codebase | `repo-snapshot` |
| export an APEX app, read an Oracle APEX application, here is an app id and a connection | `apex-export` |
| should we port this APEX app, scope an APEX migration, what would it cost to replace it | `apex-port-plan` |
| should we port this service, scope a rewrite, move this off its stack, what would migrating cost | `port-assess` |
| I have an idea, is this worth building, help me think this through, talk this through with me | `shape-idea` |
| I want to build X, write requirements, spec this out, we need a PRD | `write-prd` |
| break this down, create tickets, write epics or stories | `write-user-stories` |
| how should we build this, what stack, which database, record a decision | `design-architecture` |
| write the implementation plan, plan this out | `write-plan` |
| execute the plan, start building, go | `execute-plan` |
| implement X, add feature Y, fix bug Z | `tdd` |
| **production is down right now**, on call, outage, customers affected | `incident-response` |
| this is broken, why does X fail, this test is flaky | `debug` |
| what are our conventions, set up linting, does the code still follow our standards | `coding-standards` |
| review my changes, look at this diff, check this PR | `review-code` |
| is this secure, security audit, check for vulnerabilities | `security-audit` |
| clean this up, reduce duplication, this file is a mess | `refactor` |
| this is slow, reduce latency, optimise X | `optimize-performance` |
| set up CI, dockerise this, how do we deploy | `setup-deployment` |
| ship it, open a PR, let's land this | `ship` |
| write the README, document this, draw the flow, write a runbook | `write-docs` |
| make this a skill, we do this every time | `create-skill` |
| too many tokens, context audit, sessions keep compacting | `context-budget` |
| design a schema, review this database, normalise these tables | `design-database` |

## Rules

**One skill.** If two fit, the process skill goes first: it sets the approach and may invoke the
other itself. `debug` before `tdd` for a bug; `shape-idea` before `write-prd` when the idea is still
rough; `write-prd` before `design-architecture` once it is not.
**`incident-response` before `debug`** when it is happening now: restoring outranks explaining.

**Announce it in one line**, then follow that skill exactly.

**When nothing fits, answer directly.** Not every request needs a skill, and forcing one is worse
than answering.

**When two fit equally, ask.** One `AskUserQuestion`, not a guess.

**Every question any skill here asks follows**
[references/asking-questions.md](references/asking-questions.md). The rule most often got wrong:
a multi-select question marks no option `(Recommended)`, because with several valid answers the
label reads either as "pick this one" or "include this one" and implies the rest are wrong. Put
the most appropriate option first and let the order carry it. Unresolved questions in any artifact
are surfaced as choices, not left in a section to be read past.

The same table, with prompting guidance for users, ships to each project at
`<docs_root>/prompting.md`.
