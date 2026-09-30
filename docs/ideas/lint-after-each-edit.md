# Idea: lint after each edit

| | |
|---|---|
| Raised by | `docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md`, "Not in this plan" row 1, the maintainer, 2026-09-25 |
| Status | declined 2026-09-27: `verify.lint_one` is not worth adding for now |
| Recommendation | Do not build it |
| Next | Nothing. Revisit on a named instance of an agent skipping the per-edit lint |

## The problem

An engineer working under keel is told, in the managed CLAUDE.md block, to lint after each file
edit rather than at the end of a task, and nothing in a session checks whether that happened, so
the rule depends entirely on the model choosing to keep following it turn after turn.

**Evidence.** Unknown, and nobody could name one. Neither `docs/audits/2026-09-25-standards.md`
nor `docs/audits/2026-09-26-security.md` names a lint-skipping incident, and no eval entry in
`tests/evals/results.md` measured whether an agent actually lints per edit rather than at the end
of a task. What is not in question is the structural gap: the rule is written once, in
`templates/project-claude-md-block.md:37` (rendered into every project's `CLAUDE.md` and
`AGENTS.md`), and nothing anywhere reads back whether it was followed.

## What was asked for

Not a request in the user's own words. This record's source is a line item a plan already wrote
down as out of scope for itself, and its whole content is the row:

> Run `verify.lint` after each edit in a session, through a PostToolUse hook | The injected block
> says "lint after each file edit" and nothing enforces it. A hook costs a lint run per edit, open
> decision 4 already weighed that cost for commits, and ADR-0003 needs an evidence row for the
> primitive | `design-architecture`, an ADR

(`docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md`, "Not in this plan"
table). `docs/snapshot.md:148` carries the same item under "Missing documentation": "An ADR on
in-session lint, whether a PostToolUse hook runs `verify.lint` after an edit."

## The case against

**Strongest argument for not building this at all.** keel already has a working, harness-agnostic
place for this exact rule, and it deliberately does not run at every edit.
`docs/01-architecture.md`'s own rule table names the commit-time `keel guard` pre-commit hook as
the mechanism for "format, lint and typecheck pass before a commit", marks it optional and off by
default, and says outright "it can be slow", pointing straight at open decision 4 for the
reasoning. That decision already rejected running the full verify suite on every commit in favour
of a fast subset, and even then left `verify.test_one` out of the shipped guard for want of a
file-to-test mapping, so the guard runs `verify.lint` in full and unscoped, not per changed file. A
`PostToolUse` hook moves that same unscoped command from once per commit to once per edit, an
order of magnitude more often, with no scoping mechanism to shrink it: the profile schema has a
`test_one` template for exactly this problem and no equivalent `lint_one`, so the hook can only
invoke the full, fixed-file `shellcheck` command keel already ships. Measured against this
repository's own command on 2026-09-26 (`shellcheck -x bin/keel bin/keel-fleet lib/*.sh
lib/harness/*.sh tests/*.sh tests/evals/run.sh tests/evals/stage.sh hooks/session-start
hooks/context-watch hooks/sensitive-guard hooks/done-guard`), it takes 12.3 seconds wall clock,
comfortably over the 10-second timeout every other hook in `hooks/hooks.json` uses. Built as asked,
on the very repository whose `CLAUDE.md` states the rule, it would time out on its own first edit.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Nothing | The instruction stays prose only, exactly where decision 4 and `docs/01-architecture.md`'s rule table already put lint enforcement: at commit time, opt-in. No named instance of harm exists to weigh against that |
| Do it manually | The user re-reminds the model after specific edits, or reads the transcript afterward | Moves the saved effort back onto the person the rule exists to save it for |
| Buy it | Nothing available | The nearest thing, the `security-guidance` plugin's `PostToolUse` hook (`docs/01-architecture.md`, "Edits get a security pattern check"), checks a pattern match with no external process, not a full multi-file lint command with no per-file scoping |
| Build something smaller | See variants below | The likely shape if this proceeds at all |

**Variants of building it**

| Variant | Note |
|---|---|
| A `PostToolUse` hook running the full `verify.lint` command after every `Edit`, `Write` or `NotebookEdit`, as literally asked | Measured 12.3 seconds against keel's own command, over the 10-second convention every hook in `hooks/hooks.json` uses today. No evidence row exists in `lib/harness/capabilities` for the primitive it needs, so ADR-0003 treats it as unsupported until one is added and probed on both harnesses |
| A new `verify.lint_one` profile key, templated like `test_one`, and a hook that lints only the file just edited | Needs a schema change (decision 4 already notes that making `test_one` required moved the schema) and a per-language convention for scoping a lint command to one path, which several stacks, this repository's own fixed-file `shellcheck` invocation included, cannot express at all |
| Make `keel guard`'s existing pre-commit hook fire more often | Stays a git hook, harness-agnostic the way `docs/01-architecture.md`'s row already values it, but there is no git hook point between individual edits and a commit to attach it to; listed to show it was considered and has nowhere to go |
| Leave the CLAUDE.md instruction as prose and add the check to `keel doctor` or `ship` instead, at commit or ship time | Avoids the timeout, scoping and ADR-0003 evidence problems entirely, but it is decision 4's existing answer restated |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| A `PostToolUse` hook is a primitive keel's own manifest already trusts | `lib/harness/capabilities` carries a `provides` row naming it, with a source, version and date | ADR-0003: "a primitive with no evidence is treated as not provided" | **Checked, and it is false.** No such row exists for either harness, though `docs/01-architecture.md` shows Claude Code itself supports the event via the `security-guidance` plugin |
| The lint command can be scoped to the one file a `PostToolUse` event names | `templates/profile.schema.json` has a `lint_one` key the way it has `test_one` | Read the schema directly | **Checked, and it is false.** Only `test_one` exists (`templates/profile.schema.json:119,135`); lint has no equivalent anywhere in the file |
| Running the full lint command per edit fits inside a hook's timeout | Every hook in `hooks/hooks.json` runs at `timeout: 10` except `SessionStart` at 30 | Time the real command | **Checked, and it is false.** Measured 12.3 seconds against this repository's own `verify.lint`, 2026-09-26 |
| The per-commit cost decision 4 weighed generalises to per-edit frequency | Decisions about commits, which happen far less often than edits, carry over unchanged | `docs/07-open-decisions.md` decision 4 | Not checked. Decision 4 states the direction (a more frequent event costs more) but never measures an edits-per-commit ratio |
| A hook firing on every edit stays useful rather than becoming the thing people disable | Compare `hooks/done-guard`'s own stated design principle, that a guard which cries wolf gets switched off | No per-edit hook has shipped yet to observe | Not checked, reasoned by analogy to `done-guard`'s header rather than measured for this hook specifically |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| keel already has a designed, harness-agnostic place for this rule, running at commit time rather than per edit | `docs/01-architecture.md`, rule table row: "Format, lint and typecheck pass before a commit ... optional `keel guard` `pre-commit` git hook ... See open decision 4, it can be slow" | The idea proposes moving an already-placed control to a much higher-frequency point without revisiting why it was placed where it is |
| Decision 4 already rejected the full verify suite on every commit for cost reasons, and left even the scoped `test_one` out of the shipped guard for want of a file-to-test mapping | `docs/07-open-decisions.md` decision 4, "Shipped 2026-08-14, partly" | The same cost reasoning applies with more force at per-edit frequency, and lint has the same missing-mapping problem `test_one` had, with no `lint_one` at all |
| No hook in `hooks.json` registers `PostToolUse` today | `hooks/hooks.json`, six event blocks: SessionStart, UserPromptSubmit, PreToolUse, Stop, SubagentStop, PreCompact | This would be a new event class for keel's own hooks, not an extension of an existing one |
| The capability manifest carries no primitive for it, on either harness | `lib/harness/capabilities`, 23 `provides` rows, none naming a PostToolUse-shaped primitive | ADR-0003's rule, "absent evidence fails, never passes," applies directly: nothing can ship until a row is added and probed on both harnesses |
| ADR-0003 was written for exactly this kind of claim | `docs/decisions/ADR-0003-gate-availability-from-a-capability-manifest.md`, "a primitive with no evidence is treated as not provided" | Confirms the source row's own framing: this needs an ADR-shaped evidence row, not just a hook script |
| The schema has a file-scoping template for tests and none for lint | `templates/profile.schema.json:119,135` (`test_one`); no `lint_one` anywhere in the file | Any hook built today can only run the full, unscoped lint command, never just the edited file |
| The full lint command is measurably slow against this exact repository | Measured 2026-09-26 against `.keel/profile.json`'s own `verify.lint` string, 12.3 seconds wall clock | Over the 10-second timeout every hook in `hooks/hooks.json` uses |
| keel has twice already declined a `PostToolUse` hook for a rarer event, on budget grounds | `docs/prd/profile-sync.md` CON-04 and `docs/ideas/snapshot-records-its-own-path.md`, both citing a 400-token hook budget and an event that "happens a few times per repository" | Lint-after-edit fires far more often than either rejected case, though the cited 400-token ceiling (`tests/validate-skills.sh`) measures `SessionStart`'s injected context specifically and would need restating for a `PostToolUse` hook, whose real cost is wall-clock time and failure output, not injected tokens |
| The nearest working precedent for a `PostToolUse` hook checks a different, cheaper thing | `docs/01-architecture.md`, "Edits get a security pattern check ... `security-guidance` plugin `PostToolUse` hook ... Runs on every edit, no invocation needed ... Claude Code only" | A pattern match with no external process is not the same cost profile as invoking an unscoped, multi-file lint command; the precedent supports the event existing, not this specific cost |
| That precedent is Claude Code only | Same row, "Claude Code only, it is a Claude Code plugin" | A `PostToolUse`-based lint gate would likely start Tier A only, the asymmetry ADR-0003 exists to state plainly rather than hide |
| A related but distinct question, whether an edit followed written conventions, was already found to have no hook-shaped answer | `docs/ideas/standards-that-bind.md`, "5. A hook. Not available ... 'Did this edit follow the conventions' has no equivalent observable" | Different from "did lint pass", which is a real exit code a hook can read directly; this idea does not inherit that specific objection |
| The nearest existing hook infers completion from a transcript rather than running a command, and cannot see an exit code at all | `hooks/done-guard`, its own header: "It cannot see the exit code, and does not pretend to" | A dedicated lint hook is different in kind and stronger here: it would run the command itself and read a real exit code, a genuine capability gain over `done-guard`'s pattern, weighed against everything above that still makes it expensive |

## Open questions

Question 2 was answered on 2026-09-27, and its answer leaves questions 1 and 3 with nothing to
decide, since both assume a hook that is now not being built.

1. ~~Should the hook block the edit or only warn afterward?~~ **Not reached: no hook is being
   built.** `PostToolUse` fires after the tool has
   already run, so "block" cannot mean "prevent the edit"; it can only mean surfacing a failure
   before the turn ends, which changes what it is worth. This is exactly the design question the
   source row's own "Next" points at `design-architecture` and an ADR for.
2. ~~Does keel want a `verify.lint_one` profile key at all, given that several stacks, this
   repository's own fixed multi-file `shellcheck` invocation included, cannot express "lint just
   this one file"?~~ **Answered 2026-09-27 by Bernard, asked as a choice: not for now.** No lint
   skipping incident is on record, and several stacks, keel's own included, could not fill the key.
3. ~~Is Tier A only (Claude Code only) enforcement acceptable for a rule stated identically to every
   harness in the rendered `CLAUDE.md`/`AGENTS.md` block, or does `docs/harness-support.md` need to
   say the rule goes unenforced on Codex the way it already says that for `sensitive-guard`?~~
   **Not reached: with no hook, the rule is unenforced on every harness alike.**

## Recommendation

**Do not build it.** Decided 2026-09-27, when open question 2 was answered: `verify.lint_one` is
not worth adding for now. The rule stays in the managed block, unenforced. Revisit on a named
instance of an agent skipping the per-edit lint.

What this record said before that answer: **undecided pending a named question**, whether
`verify.lint_one` is worth adding to the profile schema. The literal ask, a `PostToolUse` hook running the full `verify.lint` command, is measurably
infeasible today: it times out on keel's own repository, carries no ADR-0003 evidence row, and has
no scoping mechanism, so every cheaper variant this record can name depends on that schema question
being answered first. It goes to `design-architecture`, on the blocking question above, not
directly to `write-prd`.

## Not decided here

Whether the hook, if built, blocks or only warns. What shape `verify.lint_one` would take, if it is
ever revisited, for stacks with no natural single-file lint invocation. Whether
Tier A only enforcement is acceptable for a rule the rendered CLAUDE.md block states without
naming a harness. Whether the 400-token `SessionStart` hook-budget check even applies to a
`PostToolUse` hook's cost, which is wall-clock time and failure output rather than injected
context.
