# How to prompt so the right skill fires

Installed at `docs/prompting.md` in every project. This is also the source of the
router skill's routing table, so the two cannot drift.

<!-- `keel init` substitutes docs from profile.docs_root, default "docs/keel".
     Do not hardcode a docs path in this file; `keel doctor` fails on a literal one. -->


## The short version

You do not need to memorise skill names. Say what you want in plain language and the
trigger words below will route it. When you do know the skill, naming it is faster and
removes all ambiguity: **"use write-prd for this"**.

If nothing fires and you expected it to, say `/keel` and describe the task.

## Trigger map

| Say something like | Fires | Produces |
|---|---|---|
| "what is this repo", "help me understand this codebase", "onboard me" | `repo-snapshot` | `docs/snapshot.md` |
| "export APEX app 100", "read this Oracle APEX application" | `apex-export` | `docs/apex/APP-<id>/` |
| "should we port this APEX app", "scope the APEX migration" | `apex-port-plan` | `docs/apex/APP-<id>/PORT-ASSESSMENT.md` |
| "should we port this service", "scope a rewrite", "move this off Spring Boot" | `port-assess` | `docs/port/<service>-assessment.md` |
| "I have an idea", "is this worth building", "help me think this through" | `shape-idea` | `docs/ideas/<slug>.md` |
| "I want to build X", "write requirements", "we need a PRD", "spec this out" | `write-prd` | `docs/prd/<slug>.md` |
| "break this into stories", "create tickets", "write epics" | `write-user-stories` | `docs/stories/<slug>.md` |
| "how should we build this", "what stack", "which database", "design the system" | `design-architecture` | architecture doc plus ADRs |
| "write the implementation plan", "plan this out" | `write-plan` | `docs/plans/<date>-<slug>.md` |
| "execute the plan", "start building", "go" | `execute-plan` | code and commits |
| "implement X", "add feature Y", "fix bug Z" | `tdd` | failing test first, then code |
| "what are our conventions", "set up linting", "enforce style" | `coding-standards` | `docs/standards.md` plus lint config |
| "production is down", "we have an outage", "customers are affected" | `incident-response` | a restored service, then an incident record |
| "this is broken", "why does X fail", "this test is flaky", "wtf" | `debug` | root cause, then a failing test, then the fix |
| "review my changes", "look at this diff", "check this PR" | `review-code` | ranked findings |
| "is this secure", "security audit", "check for vulnerabilities" | `security-audit` | `docs/audits/<date>-security.md` |
| "clean this up", "this file is a mess", "reduce duplication" | `refactor` | same behaviour, better structure |
| "this is slow", "optimise X", "reduce latency" | `optimize-performance` | benchmark first, then the change |
| "set up CI", "dockerise this", "how do we deploy" | `setup-deployment` | workflows, Dockerfile, deploy runbook |
| "ship it", "open a PR", "let's land this" | `ship` | gate checks, then a PR |
| "write the README", "document this", "draw the flow", "write a runbook" | `write-docs` | the relevant doc, mermaid diagrams |
| "make this a skill", "we do this every time" | `create-skill` | a new skill, as a PR to keel |
| "this session is using too many tokens", "context audit" | `context-budget` | `docs/context-audit.md` |

## Prompts that work well

**Point at artifacts instead of re-explaining.** The pipeline writes files precisely so
you do not have to carry context in your head or in the conversation.

> Read `docs/plans/2026-08-11-payout-retries.md` and execute tasks 4 through 7.

is better than three paragraphs describing the same thing, and it costs a fraction of the
tokens.

**Give success criteria, not instructions.** Models loop reliably against a check and
poorly against a description.

> Weak: "add validation to the payout endpoint"
>
> Strong: "write tests covering a negative amount, a zero amount, an unknown currency, and
> a missing idempotency key on the payout endpoint, then make them pass"

**Say when you are deliberately skipping a step.** The skills are built to push back on
skipped gates, which is the point, but they will accept an explicit decision.

> This is a throwaway spike to check whether the provider API supports partial refunds.
> Skip TDD, we are deleting this branch either way.

**One task per session.** Then `/clear`. Nothing is lost because the artifacts are on disk.
A session carrying three unrelated tasks is slower, more expensive, and more confused.

**Name the skill when you want a specific one.** Especially useful when two could apply:

> Use `refactor`, not `optimize-performance`. I do not care about speed here, the file is
> just unreadable.

## Prompts that do not work well

| Don't | Why | Instead |
|---|---|---|
| "make it better" | No success criterion, so nothing can verify completion | Name the property: faster, smaller, testable, clearer |
| Pasting a large file into chat | It is already on disk and it now sits in context forever | Give the path |
| "fix all the issues" after a long review | Bundles unrelated changes into one unreviewable diff | Fix them in batches, commit between |
| "also, while you're in there..." | Produces the sprawling diffs the surgical-changes rule exists to prevent | A separate task |
| Continuing a session after compaction twice | Quality degrades and cost climbs | `/clear`, then point at the artifact |
| "did you test it?" after the fact | Tests written after the code pass immediately and prove nothing | Ask for the test first |

## Escape hatches

The gates exist to stop expensive mistakes, not to block you. Each has a stated way out,
and using it is a normal thing to do.

| Gate | How to pass it deliberately |
|---|---|
| PRD required before building | "Skip the PRD, this is a one-line config change" |
| Test before code | "Throwaway spike, no tests, I will delete this branch" |
| Security audit before ship | "Docs-only change, skip the audit" |
| Review before PR | "Self-review only, this is a revert of my own commit" |

The skill will note the exception in its output. That is deliberate: the record of what
was skipped is often what you want three weeks later.

Two gates are hooks rather than skills, so they are not passed by saying something. They
have switches instead.

| Gate | How to pass it deliberately |
|---|---|
| The context pause at 85% | Write the handoff it asks for, which lifts the block. To turn it off for a shell, `KEEL_CONTEXT_WATCH=off`. For the project, `gates.context_watch: false` in `.keel/profile.json`. To move the thresholds, `gates.context_warn_pct` and `gates.context_stop_pct` |
| The pre-push supply chain scan | `git push --no-verify` for one push. For a line the scan is wrong about, append `supply-chain-scan: allow <reason>` to it; the suppression prints on every run afterwards. `keel guard uninstall` removes the hook |

## When the session pauses at 85%

You will see a message saying the context is nearly full and asking for a handoff. What is
worth knowing:

- It is not an error and nothing is lost. `Write`, `Edit` and `Read` still work.
- Let it write `.keel/handoff.md` first, then read what it wrote. The last section is
  the one that needs your eye: what is unfinished and what comes next.
- That file is git-ignored on purpose: it is session state, not project knowledge. Anything in it
  worth keeping goes to an ADR or the artifact it belongs to before the file is thrown away.
- Then `/clear`, and start the next session with "read `.keel/handoff.md` and carry on".
  That costs a few hundred tokens instead of the tens of thousands a compaction leaves behind.
- If it fires far too early, the window was probably detected wrong. Set
  `KEEL_CONTEXT_WINDOW` to the real size rather than turning the watchdog off.
