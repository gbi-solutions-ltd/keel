# ADR-0002: Delegated execution is the default, and plans declare concurrency

| | |
|---|---|
| Status | accepted |
| Date | 2026-08-19 |
| Deciders | Bernard Tebandeke |
| Requirements | none; this governs how keel's build skills execute work |
| Supersedes | none |

## Context

Four rules were proposed for keel on 2026-08-19: use subagents for research and for plan review,
never implement inline where delegation is possible, parallelise independent work, and act as
coordinator when delegating. Each was baselined against the skills as they stood, on a fixture
project with a five-task plan whose dependency graph is `{1,2,3} -> 4 -> 5`.

The baselines are in the session record. Four findings drive this decision.

**1. The mode table read as a free choice, and inline won.** Asked to execute the fixture plan, a
run chose Inline and justified it soundly: 15 dispatches to write about 50 lines. It also reported
the table's asymmetry, that step 3 elaborates delegated mode in four sentences and inline in none,
with a 6KB reference file for one and nothing for the other. The document was built for delegation
and did not say so.

**2. The Delegated row advertised a benefit the skill then denied.** Its trigger column says
"independent tasks", and `subagent-prompts.md` forbids dispatching task N+1 while N is unreviewed.
The run named this directly: *"If the skill had permitted parallel dispatch of the three independent
leaf tasks, the 'independent tasks' criterion would have bought something real. It explicitly does
not."*

**3. Independence of content is not independence of state.** A run asked to go as fast as it
reasonably could correctly identified tasks 1-3 as independent from their `Files` and `Interfaces`
blocks, and refused to overlap them anyway. Its reason was not file conflicts. Every task's
`Done when:` gates on the whole suite, and task 2's step 1 writes a failing test on purpose, so
*"three concurrent agents each waiting for a green whole-suite cannot all pass."* Worse, with a
sibling's failing test in the suite each agent's step 2 sees red for the wrong reason and ticks the
box: *"the TDD gate silently stops proving anything."*

**4. No rule stopped a coordinator writing code.** The word "coordinator" did not appear in the
skill. `allowed-tools` granted `Write` and `Edit` unqualified by mode, and the closest rule,
"Delegate mechanical execution. Keep for yourself: ...", is a positive enumeration that a reader
under pressure hears as the whole boundary.

## Decision

**Delegated becomes the default mode of `execute-plan`.** Inline remains available and must be
named as an exception with its reason, in one line.

**Plans declare concurrency, and `execute-plan` honours only what is declared.** Every task carries
a `Depends on:` line. A concurrent batch is eligible on five conditions, not the obvious three:
declared in the header, dependencies satisfied, no shared file, `Done when:` scoped to the task's
own test with the suite gate held at the join, and no shared config touched. Batch agents run with
`isolation: worktree`.

**The coordinator writes no production code**, at any size, with the reason attached: both review
passes are fed the subagent's diff, so a coordinator's edit is the only change in the run that
neither pass sees.

## Alternatives considered

**Leave the choice free and mark Delegated as preferred.** Rejected on the skills' own authoring
guidance, which holds that soft guidance fails under the pressure it exists to survive. The baseline
supports this: the run already felt the pull toward delegation and chose against it anyway, on a
defensible reading of a neutral table.

**Infer concurrency from disjoint `Files` and absent `Consumes`, needing no plan change.** Rejected
on the baseline's own reasoning: *"absence of a line is also what an incompletely-written task looks
like."* It would make an incomplete plan indistinguishable from a parallelisable one, in the
direction that loses work.

**Declared dependencies and disjoint files alone, without the other three conditions.** Rejected as
the most dangerous option available: it passes review, runs, and produces a fully ticked plan whose
TDD gate proved nothing. This was the shape originally proposed, and the baseline is what changed it.

**Require inline for everything, on the grounds that delegation costs more.** Rejected. It is right
for small plans, which is why inline survives as a named exception, and wrong for the plans keel
exists to execute.

## Consequences

Bodies grow: `execute-plan` 700 to 850 words, `write-plan` 696 to 897 against a 900 ceiling.
`write-plan` is now the tightest body in the repository and the next addition to it must displace
something. Per ADR-0001 both need a passing eval arm at this length.

A plan written before this ADR has no `Depends on:` lines, so every task runs alone. That is the
safe direction, and it means the change is backwards compatible without a migration.

Token cost rises for small plans where a coordinator takes the default rather than thinking. The
named-exception requirement is the mitigation and it is weaker than a mechanical check, because
nothing can measure whether a plan was short.

`write-plan` gains `Agent` and `AskUserQuestion` in `allowed-tools`. It was already instructing
`AskUserQuestion` in step 1 without listing it, so that half is a bug fix.

## Verification

**Closed. All four items pass**, re-run on 2026-08-19 per `create-skill` step 4. The evidence,
including the method's limitation and the loopholes the re-run closed, is in
`../audits/2026-08-19-delegation-rules-baselines.md`.

1. The C1 scenario, unchanged, must now produce Delegated, or Inline with a named reason.
   **Delegated, named in one line.**
2. The C2 scenario, unchanged but with a plan carrying `Depends on:` lines and a declared batch,
   must dispatch tasks 1-3 together in worktrees and hold the suite gate to the join. **Three
   implementers in one message with `isolation: worktree`, suite run once at the join.**
3. The C3 scenario must re-dispatch rather than fix, and cite a sentence when asked why.
   **Re-dispatched to a fresh implementer, no production code written, sentence cited.**
4. A plan whose declared batch violates one of the five conditions must be stopped, not run.
   **Refused, naming conditions 4 and 5.**

Item 4 was called the one most likely to fail, because it requires refusing a plan that says it is
fine. It passed, and it is also what settles the open question in Consequences: conditions 1 to 3
passed cleanly on the ineligible plan and nearly carried it, so the two conditions this ADR added
over the approved shape are the two that did the work. The widening stands on evidence rather than
on the argument that produced it.

The re-run found seven loopholes in the amended text, all closed in the same change. Three findings
outside this ADR's scope were recorded in the audit and left alone, the first being that the
precondition on verify commands tests their presence in the profile rather than whether they run.
