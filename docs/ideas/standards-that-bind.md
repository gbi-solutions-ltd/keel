# Idea: standards that bind

| | |
|---|---|
| Raised by | Bernard, 2026-09-01 |
| Status | shaped. A is unparked on a named instance; B is unchanged |
| Recommendation | Ship the four zero-word edits for B. Build the assessment mode for A, re-ranked and re-costed against the instance below |
| Next | `write-prd` for the assessment mode. The four B edits need no PRD |

## The problem

Two problems, not one. See question 1 below for why they are separated and stay separated.

**A.** Somebody inherits a repository that already has a `standards.md` and wants to know whether the
code follows it. Nothing in keel answers that. `coding-standards` writes the document
(`skills/coding-standards/SKILL.md:16-79`, five authoring steps, no assessment branch), and
`review-code` is the only reader, over a diff (`skills/review-code/SKILL.md:21`,
`skills/review-code/references/rubric.md:61-63`).

**B.** keel's catalogue calls row 9 "Coding standards enforcement" (`docs/02-skill-catalog.md:69`)
and nothing enforces them during coding.

**Evidence.** Different for each, and this is still the whole finding.

For **A**, an instance now exists and is measured below. The earlier reading of this record said
"structural only, no named victim", and that is what parked A. It is superseded.

For **B**, an instance exists and it points the other way.
`tests/evals/results.md:2345-2493` ran exactly this experiment on 2026-08-20 and scored "code
produced follows the standards" as **"Met, unprompted, both coding arms"**, adding that
"`skills/tdd/SKILL.md` mentions standards nowhere in its directory, and both arms found
`docs/standards.md` and complied" (`tests/evals/results.md:2433`). The behaviour keel does not
instruct happened anyway. Nothing in the instance below contradicts this, and the instance's own
sample agrees with it.

## What was asked for

> keel claims coding standards are part of the pipeline, and two things it implies are not true
> today. A. There is no way to assess an existing codebase against an already-written
> `standards.md`. B. Nothing makes standards bind during coding.

Both claims were checked line by line and both are true as stated. The reading below adds three
things the brief did not have: the binding gap has a measured counter-example, the one path where
standards genuinely cannot be found was never tested, and the assessment gap now has an instance
that says the useful check is not the one anybody expected.

## The instance: payments-api, 2026-09-01

Called `payments-api` here: a NestJS payments service on Postgres, 388 TypeScript files under
`src/`, branch `postgres-migration`, HEAD `a8af77d`, read only throughout. keel 0.16.1, profile
schema 2 (`.keel/profile.json:2-3`). The real name is withheld per
`tests/no-internal-leaks.sh`.

This is the named case that questions 1 and 2 were blocked on: a repository with a real
`standards.md` (1,271 lines, 12,348 words), written by `coding-standards`, whose owner did not know
whether the code still followed it.

**How stale it was.** The header says "Derived from ~45 files ... at commit `5fb8b81`"
(`standards.md:5`) and is dated 2026-08-23 (`:6`). `5fb8b81` is itself dated 2026-08-09, two weeks
earlier, but it was the tip on 2026-08-23 (`git rev-list --count 5fb8b81..HEAD --before=2026-08-23`
is 0), so the document pinned correctly to a tip that was already old. Since derivation: 169
commits, 325 files changed.

**The derivation confound, which is a finding in its own right.** 388 `.ts` files under `src/`
today; 303 of them existed at `5fb8b81`. So 78% of the tree is the corpus the rules were read off.
`skills/coding-standards/SKILL.md:18` says "Read the code before writing anything. The conventions
that matter are the ones already in use", which means a compliance sweep over all of `src/`
substantially measures the source of the rules rather than adherence to them. This weakens "the
code complies" as evidence in both directions, and it turns out to cut the other way too: see the
money finding below.

### Finding 1. House-defaults coverage, and this is the headline

The check that found the largest gap reads two documents and a profile and touches no source code
at all. **That is what made it look cheapest, and it is not.** A second instance on 2026-09-01
measured it the most expensive of the four, because ten topic references have to be read before a
single rule can be disposed of. Corrected in full in the Recommendation section below.

Nine of ten topic references in `skills/coding-standards/references/house-defaults.md` apply to this
project; only `frontend.md` does not (`has_ui` false, `house-defaults.md:27`). The index itself says
"Do not read them all: most projects need four or five" (`:13-14`), so nine is already unusual.

**The unit, settled 2026-09-01, because the first version of this finding used one that cannot be
reproduced.** One house rule is one H2 section of a topic reference that states a rule, excluding
each file's trailing checklist sections (`Testing it`, `What review looks for`, `What good looks
like`). Counted by `/usr/bin/grep -c '^## '` per file, less
`/usr/bin/grep -cE '^## (Testing it|What review looks for|What good looks like)$'`.

On that unit the nine applicable references hold **65 rules**, and all ten hold 69:

| Reference | Rules | Applies because |
|---|---|---|
| `observability.md` | 8 | Always (`house-defaults.md:18`) |
| `time-and-dates.md` | 6 | Always (`:19`) |
| `resilience.md` | 6 | Calls a payment processor and partner webhooks over HTTP |
| `async-work.md` | 7 | `bullmq` in deps, four processors and two tasks in `src/` |
| `authorisation.md` | 7 | More than one kind of user |
| `rate-limiting.md` | 8 | Exposes an API |
| `api-contracts.md` | 8 | Has consumers it cannot deploy |
| `caching.md` | 8 | `cache-manager` in deps, and a cache read on a money-repair path |
| `data-protection.md` | 7 | Stated to hold personal data |
| `frontend.md` | 4 | **Does not apply**, `has_ui` false (`:27`) |

**The earlier tally is withdrawn rather than restated.** This finding previously read "76 house
rules assessed: 9 folded in, 9 adapted, 1 departed, 58 silently omitted", with per-reference ratios
of 7 of 7, 8 of 8, 6 of 14 and so on. Three things are wrong with it. Its parts sum to 77, not 76.
Its denominators match no counting unit in the files: at section granularity the nine applicable
references hold 65, and the finer granularity it appears to have used, counting individual rows of
the field tables inside a section such as `observability.md:34-45`, is not a unit that can be
applied consistently across files where most sections have no such table. And the numerators cannot
be re-derived now at any granularity, because doing so needs the project's own `standards.md`, which
is out of scope for this repository.

So the ratios are gone. What survives is the part that rests on evidence recorded here rather than
on a count.

**Four applicable references were skipped wholesale**, with no rule-level content anywhere in
`standards.md` and no departure number in section 14 recording the choice. That is 28 of the 65
applicable rules, by the unit above, with nothing written about them at all:

| Reference | Rules, none folded in | Why it applies to this project |
|---|---|---|
| `resilience.md` | all 6 | Calls a payment processor and partner webhooks over HTTP |
| `async-work.md` | all 7 | `bullmq` in deps, four processors and two tasks in `src/` |
| `caching.md` | all 8 | `cache-manager` in deps, and a cache read on a money-repair path |
| `data-protection.md` | all 7 | Stated to hold personal data |

Verified independently with `/usr/bin/grep -ic` over the document. Occurrences of "circuit breaker",
"backoff", "outbox", "personal data", "GDPR", "anonymi", "webhook", "deprecat" and "dead letter":
**zero each**. The apparent counter-hits are all unrelated: the two "timeout" hits are Jest config
(`standards.md:562,585`), the two "retry" hits are idempotency semantics (`:872,889`), all 36 "TTL"
hits are throttler constants (`:503-505` and around), and both "cache" hits are incidental
(`:582`, `:794-795`).

Structural confirmation: the document's section list has no section for resilience, caching, data
protection or async work. There is nowhere to put them.

This is the rule `skills/coding-standards/SKILL.md:69-71` states, which requires including the house
defaults "noting any this project deliberately departs from". Four references skipped whole, 28 of
the 65 applicable rules with nothing written about them, breach it, and
nothing in keel would ever notice.

### Finding 2. The follow-up backlog decayed, and one hand fix was never finished

Sections 11 to 13 of the instance's document, checked against the tree at HEAD rather than trusted.

**Section 11, known inconsistencies: all four still true.** Two controller error shapes across 16
sites (`standards.md:1103`), 44 of 46 controllers on the interceptor form. 30 commits with no
conventional prefix (`:1120`), all pre-derivation, and zero of the 169 new commits non-conforming.
36 `Co-Authored-By` commits (`:1133`), none new. `configs.module.ts` still dead (`:1140`).

**Section 12, not yet mechanical: nothing became mechanical.** Verified line by line:
`.eslintrc.js` still declares 6 rules and no `no-restricted-syntax`; `.husky/` contains only
`pre-commit`, no `commit-msg`; `package.json:20` is still `eslint ... --fix` with no `lint:check`;
`.keel/profile.json:10` still points `verify.lint` at the `--fix` variant; `permissions.guard.ts`
still returns `true` when no permissions are declared, at the same lines `:30-32` the document
cites.

**Section 13, F-1 to F-15: 4 closed (F-6, F-7, F-10, F-11), 1 partial (F-1), 10 open.** F-9 has
grown rather than held: the 3 named non-bootstrap `process.env` reads are unmoved and fourteen more
appeared since, in `legacy-agent-reference.util.ts:97`, `http-log.util.ts` (6),
`gateway-throttle.util.ts` (2) and `app-encryption.util.ts` (5).

**F-1 is the sharpest item, and its shape is not what was first reported.** F-1 asked for two things
in one commit: a mechanical ban on em and en dashes, and a fix of the 95 affected files. The fix
shipped as `4a9f6bb` on 2026-08-24. The ESLint rule and the `commit-msg` hook were never added, and
`.husky/` proves it.

An earlier read of this instance recorded that the drift had **already recurred** after the
cleanup. **That is wrong and the correction matters more than the original claim.** `git blame`
puts the three surviving dash lines (`test/integration/helpers.ts:256`,
`test/integration/global-setup.ts:18,36`) at 2026-08-07 and 2026-07-05, both **before** the
2026-08-24 cleanup. `4a9f6bb` touched 100 files, every one of them under `src/`. The three lines
were never in scope. A fourth site survives inside `src/` itself:
`src/drizzle/migrations/0001_partitioning.sql` carries three, because the cleanup swept `.ts` and
not `.sql`.

So this is not a hand fix regressing. It is a hand fix that covered less than its own follow-up item
asked for, in a repository where nothing can tell the difference, because the mechanism that would
have told the difference is the half of F-1 that was never built. That is a weaker claim than
"it regressed" and a better one for this record: the failure is invisible by construction, and only
a check that re-derives the item against the tree would surface it.

### Finding 3. A judgement sample found a money bug that six prior documents missed

Six judgement rules from sections 1 to 10, measured across `src/`, every imprecise grep
hand-verified before being reported.

| Rule | Verdict | Ratio |
|---|---|---|
| `sql.raw` allowlist (`standards.md:663-665`) | Near-fully observed | 29 of 32 to the letter, 3 deviate in form, no injection risk |
| Money quantisation (`standards.md:694-698`) | **Genuinely drifting** | ~8 conforming sites against 1 unquantised write path |
| Never return an upstream error (`:245-263`) | Near-fully observed | All 7 raw hits conforming; 3 real leaks by a different pattern |
| One logger, no `console.*` (`:322-333`) | Fully observed | 0 console violations, 44 of 48 canonical declarations |
| Dashboard deny by default (`:428-436`) | Fully observed | 144/144 and 22/22, verified per file |
| Transaction boundaries (`:110-112`) | Fully observed | 37/37, brace-matched rather than grepped |

Five of six fully or near-fully observed. The sample's own summary: "this codebase does
substantially follow its own written judgement rules, with isolated, identifiable exceptions rather
than broad drift."

**The new finding.** `src/drizzle/services/product-repository.service.ts:684` and `:690`, inside
`updateCommissions` (declared `:650`), write `String(params.agentCommission)` and
`String(params.parentCommission)` straight into `numeric(18,4)` columns
(`src/drizzle/schema/transactions.schema.ts:128`) with no `toFixed`. The values are computed
unrounded at `src/common/utils/helpers/transaction.util.ts:815-816`, a plain
`(netCommission * rate) / 100`. `applyPurchaseSettlement` later re-quantises `netProfit` and
`agentCommission` at `product-repository.service.ts:1153`, in code whose own comment explains the
binary-versus-decimal half-cent problem, and **never touches `parentCommission`**. The unquantised
value persists.

This is exactly the failure class `standards.md:696` warns about, on a path the document's own audit
trail at `:694-720` treats as closed. It appears in none of the four audits in
`docs/keel/audits/`, neither review in `docs/keel/reviews/`, and no section of `standards.md`.

**And `product-repository.service.ts` existed at `5fb8b81`.** So does `transaction.util.ts`. The
violating sites were inside the 303-file corpus the rules were derived from. The derivation pass
wrote the correct rule and left the violating sites unreported. That is the single strongest
argument in this record for an assessment mode: the authoring pass is not a substitute for a
compliance pass, even over the same files on the same day.

**A second instance of the same pattern, and a correction to how it should be read.**
`src/partition/partition.service.ts` interpolates unguarded identifiers into `sql.raw` at `:356`,
`:367`, `:388` and `:392`, while its own guarded siblings at `:182-187` and `:324-325` call
`assertPartitionName` first. The file existed at `5fb8b81`, added 2026-03-23, so this too predates
the document that forbids it. **It is not attacker-reachable and must not be written up as an
injection bug**: `PartitionService` has no controller anywhere in `src/`, it is driven only by
`partition.processor.ts` on cron schedules registered at `partition.module.ts:33-37`, `tableName`
traces to a hardcoded array in `src/common/config/partitioned-tables.config.ts`, and
`listPartitions` (declared `:351`) is called from nowhere at all. This is a style deviation from the
rule's stated form. Read against `skills/coding-standards/SKILL.md:29-32`, the "counting decides
style, never correctness" carve-out whose worked example is SQL injection, and against `:78-79`,
where step 5 is supposed to report "any inconsistency you found but did not resolve".

**A discipline result worth keeping.** The seven `error: err.message` grep hits were all conforming
once opened: each guards on an exact literal message before returning it. A sweep that reported the
grep count would have filed seven false findings. The three real leaks are a different pattern,
`createResponse(..., err, ...)` at `transaction.util.ts:220`, `:681`, `:709`. An assessment mode that
does not require hand-verification of every grep will generate more noise than signal.

### Finding 4. The departures ledger came back clean, and the record says so plainly

Section 14, D-1 to D-15, classified four ways per
`skills/coding-standards/references/standards-template.md:85-87`.

| Category | Count | Items |
|---|---|---|
| Closed | 3 | D-2, D-11, D-15 |
| Open with a tracking reference | 6 | D-4, D-7, D-8, D-12, D-13, D-14 |
| Requires an ADR that does not exist | 1 | D-1 |
| **Kept on a reason the tree no longer supports** | **0** | none |
| Kept, reason re-checked and still holding | 4 | D-5, D-6, D-9, D-10 |
| Fits none of the four: names a skill, not an item or an ADR | 1 | D-3 |

**The brief called the fourth category "the dangerous one and nothing checks it". It was checked and
it is empty.** Every Keep ruling's stated factual basis survived re-verification against the tree:
D-5's "17 of 17 repository services" is still exactly 17; D-6's "nine production files exceed 1,000
lines, largest 2,640" is still nine, now largest 2,643; D-10's "no clock abstraction" still holds
and the call-site counts have grown from 166 and 57 to 307 and 81, which strengthens the departure
rather than falsifying its reason.

D-1 is the one ADR gap, and it is real: `tsconfig.json:14-16` still has `strictNullChecks`,
`noImplicitAny` and `strictBindCallApply` all false, and `docs/keel/decisions/` holds only
`ADR-0000-template.md` and `ADR-0001-application-level-encryption-key.md`, which is about the TOTP
key and unrelated. The ruling that requires the ADR is at `standards.md:1196`, not `:1194` as the
brief had it. Incidentally the document's own citation in that row is off by one: it cites
`tsconfig.json:15-17` for flags that sit at `:14-16`.

This finding does not weaken the case for the mode. It relocates it. The decay is in the follow-up
backlog and in house-defaults coverage, not in stale departure reasoning.

### What the instance costs, stated honestly

**The demonstrated cost is an information gap, not a quality gap.** The owner believed the code was
out of compliance. The sample says it broadly is not: five of six judgement rules fully or
near-fully observed. What decayed is the mechanical and house-defaults backlog. That matches
`tests/evals/results.md:2433` rather than contradicting it, and the record should not oversell it.

What the instance does establish is that four different checks, run against one document, return
four different verdicts, and that one of them found far more than the other three. Nobody would have guessed the
ranking in advance, which is the argument for writing it down.

## The case against

**Strongest argument for not building this at all.** keel already ran this experiment and wrote down
the answer, and the answer was that the rule keel *did* write down and *did* load changed nothing,
while the rule it never wrote down was followed anyway. Arm 3 read the surgical-changes rule from the
managed block and edited adjacent code regardless; arm 1, which had not read it, "behaved identically
and disclosed just as much" (`tests/evals/results.md:2420-2422`). The entry draws the conclusion
itself: "Adding a third copy, to a body 93 words over its target, would restate a sentence the agent
has already read and reasoned past" (`tests/evals/results.md:2426-2427`), and closes with the
prerequisite: "the question to answer first is not 'where should the rule go' but **'why does a
loaded rule not bind'**, because the second question decides whether any wording change is worth
making" (`tests/evals/results.md:2450-2452`). Every prose-shaped option for B is a fourth copy of a
sentence with a measured hit rate of zero, and this repository has already priced it.

**This argument survives the instance, and only applies to B.** The assessment mode is not a rule
told to a model that already complies. It is a procedure that reads a document and a tree and
returns findings, and the instance shows it returns findings nobody had.

Against that, the honest cheapest fix for B is to stop claiming the thing. Two of keel's own
documents assert an enforcement that does not exist: `docs/02-skill-catalog.md:69` says
"Coding standards enforcement", and `docs/02-skill-catalog.md:382` says `refactor`
"**Reads:** the target code, tests, `<docs_root>/standards.md`" while `skills/refactor/` contains no
occurrence of the word (`/usr/bin/grep -rn -i standard skills/refactor/` returns nothing). The claim
is the defect. Deleting a claim costs no words at all.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Nothing | Two documents keep asserting an enforcement that does not exist, and the payments-api instance shows what nobody notices: four house-defaults references skipped whole, 10 open follow-ups after 169 commits, and an unquantised money write inside the corpus the rules were derived from |
| Do it manually | The user pastes `standards.md` into the prompt each time | This works for B. `tests/evals/results.md:2433` shows it works without even being pasted. It does not work for A: the payments-api owner had the document, had read it, and still did not know which of its four sections had decayed |
| Buy it | Nothing available | `tests/evals/results.md:2456-2461` checked the closest candidate on paper: the `code-review` plugin "has **no input that accepts a project's conventions**", and asking it for standards findings would make it infer them, which `rubric.md:63-65` forbids in as many words |
| Build only the small thing | Two lines in two reference files, plus deleting two false claims | Still the whole of B, and still recommended. It does nothing for A, which now has an instance |

**Variants of building A**

| Variant | Note |
|---|---|
| Assessment mode inside `coding-standards` | Re-costed at 150 to 236 body words below, not the ~95 first estimated. The 150-word version fits; the 236-word version does not. **Recommended** |
| Widened `review-code` | Cheapest in words (52) and the only one that contradicts its own skill's core principle |
| A new 26th skill | Affordable on description tokens, nearly out of budget on the SessionStart roster: its name may be at most 19 characters |
| Standards block in the delegated implementer prompt | Zero body words. This is a B fix, not an A fix. Ship it either way |
| A standards line in the plan template's Global constraints | Zero body words. Carries into every task and every dispatch |
| A `gates.coding_standards` read in each coding skill | 7 words each. `write-plan` cannot afford 7 words |
| A ninth `ship` checklist item | ~17 words. Crosses the 700 target and buys an eval arm |
| A hook | Zero words and nothing decidable to check. See question 3 |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| Somebody actually wants an existing codebase assessed | A real inherited repo with a `standards.md` and an unanswered compliance question | Named 2026-09-01: payments-api, 1,271-line document, 169 commits past its derivation point | **Yes. This was the blocking gap and it is closed** |
| An agent will not find `standards.md` on its own in a large tree | The 2026-08-20 result does not generalise | An agent located and applied `docs/keel/standards.md` in a 388-file tree without a path in its brief | **Checked, and it came out no.** It found it |
| A delegated implementer is worse off than an inline one | The subagent's brief is the only context it gets | `skills/execute-plan/references/subagent-prompts.md:17-18` says so; `tests/evals/results.md:2491-2493` says this path "was not tested here at all" | Asserted by the prompt, never measured |
| Prose in a skill body changes behaviour | Not established, and one measurement says no | `tests/evals/results.md:2420-2422` | **Measured, and it came out no** |
| `coding-standards` re-run on a repo that already has a `standards.md` rewrites rather than assesses | Step 1 says "Read the code before writing anything" (`skills/coding-standards/SKILL.md:18`) and step 4 says "Write `<docs_root>/standards.md`" (`:63`) with no branch for an existing file | Read, not run | Read only |
| The authoring pass catches the violations it writes rules about | The derived rule and the compliant tree are the same evidence | payments-api: the unquantised money write and the unguarded `sql.raw` sites both sit **inside** the 303-file derivation corpus | **Checked, and it came out no.** This is the case for the mode |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| `coding-standards` authors and never assesses | `skills/coding-standards/SKILL.md:16-79`; step 4 writes the doc at `:63`, step 5 verifies the linter at `:75`, no branch reads an existing doc | Claim A is true |
| Nothing checks house-defaults coverage, ever | `skills/coding-standards/SKILL.md:69-71` requires folding the applicable defaults in "noting any this project deliberately departs from"; no skill, test or hook reads back whether that happened | The highest-yield check in the mode is the one with no reader today. payments-api: four applicable references skipped whole, 28 of 65 rules with nothing written |
| `review-code` is the only reader and is diff-scoped | `skills/review-code/SKILL.md:21`; `references/rubric.md:61-63`; scope defined over changed lines at `rubric.md:104-106` | Claim A is true. Widening this means widening a skill whose section 7 is literally about changed lines |
| The snapshot only covers the *missing* case | `skills/repo-snapshot/references/section-templates.md:147` lists "Coding standards" under **Missing**, produced by `coding-standards`; `:227-228` recommends it "to establish what this repository's conventions are, and where they are **not written down anywhere**" | There is no route for "the doc exists and nobody knows if the code follows it" |
| `security-audit` is the precedent for a whole-repo mode and for its output path | `skills/security-audit/SKILL.md:18-21`, a two-row `--diff` / `--full` scope table, costing 52 words including the gate line at `:23`; `:63` writes `<docs_root>/audits/YYYY-MM-DD-security.md` | A mode is a proven shape here, it is cheap, and its output convention answers question 4 |
| `tdd`, `write-plan` and `refactor` never mention standards | No occurrence of "standard" or "convention" in `skills/tdd/`, `skills/write-plan/`, `skills/refactor/` | Claim B is true for three of the four skills named |
| `execute-plan` mentions them once, in the wrong prompt | `skills/execute-plan/references/subagent-prompts.md:105-106` puts `=== PROJECT STANDARDS ===` in the **quality review** prompt; the implementer prompt at `:20-61` has no such block | The reviewer is told the conventions; the agent writing the code is not. This is an inconsistency, not a missing rule |
| `gates.coding_standards` is inert in code | `templates/profile.schema.json:254`; `docs/profile-keys.md:45`; a repo-wide grep finds it only in the schema, generated docs, an example file, this repo's own profile, a `printf` template in `bin/keel:430`, and eval prose. No hook, skill, lib or CLI path reads it | Claim B is true |
| One gate *is* read by a skill | `skills/security-audit/SKILL.md:23`: "Read `.keel/profile.json` for `gates.security_audit` and any `hard_block_paths`", 7 words | "A gate the skills read" is a shape that already exists and costs 7 words per site |
| keel says this about itself in its release notes | `CHANGELOG.md:288`: "seven declared profile keys are read by nothing (`gates.tdd`, `gates.coding_standards`, `gates.review`, ...)" | The gap is admitted, not hidden. Nothing here is news to keel |
| `ship` has no standards item | `skills/ship/SKILL.md:16-30`, eight items, none naming standards; items 5 and 6 are prose with no command behind them | Claim B is true |
| Two documents claim an enforcement that does not exist | `docs/02-skill-catalog.md:69` "Coding standards enforcement"; `:382` says `refactor` reads `standards.md` | The false claim is fixable for free and is arguably the whole of B |
| Hooks cannot decide this | `hooks/done-guard:127` works by substring-matching the configured test command in a `Bash` call; `hooks/done-guard:34-36` says outright "It cannot see the exit code, and does not pretend to" | There is no observable event whose presence proves standards were followed. A hook is not available for B |
| A model acted on the inert gate unprompted | `tests/evals/results.md:2470-2474`: "arm 2 read the key out of the profile itself and used it to set severity" | See question 5 |

## 1. Are A and B separate problems, or one?

**Separate, and the instance sharpens the separation rather than closing it.**

The shared root is that `docs/standards.md` is written once and read by exactly one skill, over a
diff. That is one sentence and it is true of both.

They separate on evidence and on fix. A is a capability that does not exist and now has one named
case, with four measured findings and a ranking nobody predicted. B is a capability keel *claims* in
`docs/02-skill-catalog.md:69` and whose absence a measurement failed to detect
(`tests/evals/results.md:2433`), and the payments-api sample independently reproduces that result: the
code broadly does follow its own judgement rules. Fusing them would let A's now-evidenced hole carry
B's unevidenced fix through on its coat-tails.

They also cost differently. A is a body-words problem with an eval arm attached, and the instance
made it more expensive, not less. B, done well, costs zero body words, because the two places it
belongs are reference files and references are explicitly unbounded
(`tests/validate-skills.sh:161-162`, `docs/05-token-and-memory-design.md:49`).

## 2. For A: mode, widened `review-code`, or new skill?

| Option | Body-word cost | Description cost | Other cost | Verdict |
|---|---|---|---|---|
| **Mode in `coding-standards`** | **150 measured**, landing 833. The four-check version at full length is 236, landing 919 and **over the ceiling** | 32 of the 35 spare chars (181 of 216 at `skills/coding-standards/SKILL.md:3`) | Crosses the 700 target, so ADR-0001 buys an eval arm; one router row reworded at `skills/keel/SKILL.md:28` | **Recommended, at the 150-word length** |
| **Widened `review-code`** | 52 on a 611 body, landing 663 | None | None | **Cheapest and wrong.** It contradicts `skills/review-code/SKILL.md:16-22`, "A review without the intent is proofreading", and makes `rubric.md:104-106`'s scope section, which is defined over changed lines, meaningless |
| **New skill** | A fresh body of 500 to 700 words | ~48 tokens of the 199 spare | A router row, a `README.md` count claim (`tests/test-doc-claims.sh:45-47`), and a SessionStart roster entry with **21 characters of headroom** | **Costs the most for the least** |

### The costing, re-measured

> **Superseded by what shipped, 2026-09-01.** Every figure in this section is the shaping estimate.
> The mode shipped at 193 body words landing `coding-standards` at 876, with 24 words of headroom
> rather than the 67 computed here. The estimate was low because it was measured against a draft
> carrying neither FR-03, FR-04 and FR-05 nor NFR-04's link. Left as written, because a costing that
> is quietly corrected after the fact stops being evidence about estimating.


The parked estimate in the previous version of this record was **~95 body words**. It was an
estimate and it was wrong. **Superseded, kept here so the error is visible:**

> Assessment mode inside `coding-standards`: costed at ~95 body words below. Affordable, triggers an
> eval arm, needs a named instance first.

The instance changed what the mode has to say, because the ranking of its four checks is the finding
and a mode that does not carry the ranking is not worth building. Two drafts were written and
counted with `wc -w`:

| Draft | Words | `coding-standards` lands at | Verdict |
|---|---|---|---|
| Four checks with their rationale | 236 | 919 | **Over the 900 ceiling. Does not fit** |
| Four checks, rationale stripped to one clause each | **150** | **833** | Fits. 67 under the ceiling, 133 over the target |

So the mode is affordable, at roughly 1.6 times its parked estimate, and only in its terse form. The
900 ceiling is what forces the terseness, not a judgement about how much explanation the mode
deserves. If the rationale is wanted, it belongs in
`skills/coding-standards/references/`, which is unbounded.

The description cost holds: appending a 32-character clause such as
`, or assessing code against them` lands the description at 213 of the 216 cap
(`tests/validate-skills.sh`), using 32 of the 35 spare characters.

**Against the router's "One skill" rule** (`skills/keel/SKILL.md:42-44`): the rule says that when two
skills fit, the process skill goes first and may invoke the other. A separate assessment skill would
fit alongside `coding-standards` on almost every phrasing that reaches row 28,
"what are our conventions, set up linting". That is the ambiguity the rule exists to resolve, and
resolving it means either a fourth line of router prose or a user who is asked which of two skills
they meant. A mode inside `coding-standards` never presents the choice.

**Against the description ceiling** (`tests/validate-skills.sh:54`, `DESC_TOTAL_MAX_TOKENS=1320`,
measured at 1,121 today, so 199 tokens spare): a new skill is affordable here. The average skill
description costs 44 tokens and the largest, `design-architecture`, costs 58. The description budget
is not what blocks a new skill.

**What does nearly block it is the SessionStart roster.** `tests/validate-skills.sh:323-327` requires
every skill to be named in `hooks/session-start`, and `:364-366` caps that injection at 356 tokens
per NFR-01 with a 400 hard ceiling. Measured across all four `response_style` and `explain_level`
combinations, the worst case today is **1,266 characters, 351 tokens**: five tokens, or twenty-one
characters, of headroom. Simulated by inserting a 26th name into the Verify line:
`standards-audit` (15 chars) lands at 356 and passes; `assess-standards` (16) lands at 356 and
passes; `standards-compliance` (20) lands at 357 and **fails the check**. A new skill for this must
therefore be named in nineteen characters or fewer, or somebody trims the roster first. A mode costs
nothing here at all.

## 2a. What the mode checks, and in what order

The order is the instance's result, not a guess. It is ranked by what each check found against what
it cost to run.

**1. House-defaults coverage.** The document against `references/house-defaults.md` against
`.keel/profile.json`. No code is read at all. On payments-api it found four applicable references
skipped wholesale with no departure recorded, 28 of the 65 applicable rules. Cheapest check, largest finding.

**2. The follow-up backlog.** Sections for known inconsistencies and follow-up items, re-derived
against the tree at HEAD rather than trusted. On payments-api: 10 of 15 follow-ups still open after 169
commits, nothing on the "not yet mechanical" list became mechanical, and F-1's fix covered `src/*.ts`
while its own item said 95 files and a mechanism, so the residue in `test/` and in a `.sql`
migration is invisible to everything. **Check what a fix actually covered, not what its commit
message claims.** That distinction is the whole of the F-1 finding.

**3. A judgement sample from the body.** Six to eight rules, measured across the tree, every
imprecise grep hand-verified before it is reported. Third on cost, but it earned its place: on
payments-api it found an unquantised write into a `numeric(18,4)` money column that four security audits,
two code reviews and the document itself had all missed. Two things it must state to be honest: how
much of the tree predates the document (78% here), and that a raw grep count is not a finding (7 of
7 apparent leaks were conforming once opened).

**4. The departures ledger.** Each departure classified as closed, open with a tracking reference,
needing an ADR that does not exist, or kept on a reason the tree no longer supports, per
`standards-template.md:85-87`. Ranked last because on payments-api it found the least: one missing ADR,
and the dangerous category empty. Keep it anyway. **A check that comes back clean is a result**, and
this record's job is to say that a check ranked fourth is still a check, not to quietly drop it.

The output is a dated report at `<docs_root>/audits/YYYY-MM-DD-standards.md`, following
`skills/security-audit/SKILL.md:63`. It never edits `standards.md`.

## 3. For B: which of a hook, a read gate, a `ship` line, or a sentence per skill would change behaviour?

Ranked. The ordering is by whether the thing is structural, because
`tests/evals/results.md:2420-2427` measured what prose is worth here and the answer was nothing.

**The ranking is unchanged by the instance, but the rationale for first place is not.** Open
question 2 was "does an agent find `standards.md` in a large tree", and the instance answers **yes**:
an agent located and applied a 1,271-line `docs/keel/standards.md` in a 388-file tree. So "a path in
the brief beats a search" is no longer why the implementer-prompt block ranks first. It ranks first
because `skills/execute-plan/references/subagent-prompts.md:17-18` is about **what the subagent is
sent**, not about what it could find if it looked. A subagent that could have found the document is
not the same as a subagent that was given it, and the plan-template line at second place carries the
same correction.

**1. The `=== PROJECT STANDARDS ===` block in the delegated implementer prompt.** Zero body words.
`skills/execute-plan/references/subagent-prompts.md:105-106` already puts this block in the quality
review prompt; the implementer prompt at `:20-61` does not have it. So keel tells the reviewer the
conventions and does not tell the writer. This is the only option on the list that is not a new rule:
it is an existing rule applied to the one context where the model provably cannot compensate, because
"the subagent sees only what you send. It has no conversation, no plan file loaded, and no memory of
the previous task, so anything omitted is unavailable rather than merely unmentioned"
(`:17-18`). It is also the exact path `tests/evals/results.md:2491-2493` names as untested:
"the coding arms were dispatched with `tdd` injected, not through `execute-plan`". Highest leverage,
lowest cost, and it closes an inconsistency rather than opening an argument.

**2. A standards line in the plan template's Global constraints.** Zero body words.
`skills/write-plan/references/plan-template.md:28` says the block is "Copied verbatim from the
stories, ADRs, and profile" and `:37-38` says "Copy the constraints in full rather than linking. A
task executed by a fresh agent that reads only its own section must still obey them." The standards
document is not in that list, and it is precisely a thing a fresh agent reading only its own section
must obey. Ten words in a reference file, and it reaches every task and every dispatch.

**3. A `gates.coding_standards` read, in the skills that can afford one.** Seven words per site, the
measured length of `skills/security-audit/SKILL.md:23`, which is the only gate any skill reads today.
This would make the schema's own admission at `templates/profile.schema.json:254` false in the good
direction. Ranked third rather than higher because it is still a sentence, and because
`tests/evals/results.md:2470-2474` shows an agent already reading that key out of the profile and
setting severity by it, unprompted, without being told to.

**4. A ninth `ship` checklist item.** About 17 words, the average of items 1 to 8
(`skills/ship/SKILL.md:20-30`, 135 words over 8 items). It fires only when the user says ship, and it
would join items 5 and 6 as prose with no command behind it, in a list whose working items name a
command from the profile. It also crosses `ship` from 695 to about 712 and buys an eval arm.

**5. A hook. Not available.** `hooks/done-guard` works because "did this turn run the test command"
is a substring match over a `Bash` tool call (`hooks/done-guard:127`), and the file says plainly it
"cannot see the exit code, and does not pretend to" (`:34-36`). "Did this edit follow the
conventions" has no equivalent observable. The only hook-shaped check available is that
`standards.md` exists when `gates.coding_standards` is `required`, and that belongs in `keel doctor`,
whose `fail`/`warn`/`good` idiom (`bin/keel:1318-1320`) makes it about four lines of bash and zero
skill words. Worth doing on its own merits; it is not enforcement.

**6. A sentence in each coding skill. Ranked last and partly unaffordable.** See question 4.

## 4. The word-budget reality, measured

Measured by running `tests/validate-skills.sh` and reproducing its own arithmetic
(`CEILING_WORDS=900` at `:23`, `TARGET_WORDS=700` at `:24`, `wc -w` over everything after the second
`---` at `:85` and `:121`, no exclusions for code blocks or tables).

| Skill | Body words | Spare to the 700 target | Spare to the 900 ceiling |
|---|---|---|---|
| `write-plan` | 897 | over by 197 | **3** |
| `execute-plan` | 884 | over by 184 | **16** |
| `tdd` | 793 | over by 93 | 107 |
| `ship` | 695 | 5 | 205 |
| `coding-standards` | 683 | 17 | **217** |
| `review-code` | 611 | 89 | 289 |
| `keel` | 553 | 147 | 347 |
| `refactor` | 489 | 211 | 411 |

ADR-0001's rule, verbatim from `docs/decisions/ADR-0001-skill-body-word-ceiling.md:48-51`: "A skill
body over 700 words requires a passing eval arm at that length, recorded in
`tests/evals/results.md`, so the room is taken against observed behaviour rather than against an
assertion."

**Affordable with no eval arm and no cuts:**

- The implementer-prompt block and the plan-template line. Both are reference files, and references
  are unbounded by explicit statement (`tests/validate-skills.sh:161-162`,
  `docs/05-token-and-memory-design.md:49`). Zero.
- The `keel doctor` check. Bash, not a skill body. Zero.
- Deleting the two false claims in `docs/02-skill-catalog.md`. Negative.
- A 7-word gate read in `refactor` (411 spare) or `tdd` (107 spare, though `tdd` is already over the
  target and already carries an arm).
- Widening `review-code` by 52 words to 663. Affordable, and rejected on coherence, not cost.

**Affordable but buys an eval arm:**

- The assessment mode in `coding-standards` at its measured 150 words, landing 833. That is 133 over
  the target and 67 under the ceiling. The 236-word version does not fit and must not be attempted;
  its rationale goes to a reference file instead.
- A ninth `ship` item: ~17 words lands it near 712, five words past the target.
- A new skill, if its body exceeds 700.

**Not affordable without cutting words first:**

- A sentence in `write-plan`. It has **three words** of room. The 7-word gate-read sentence does not
  fit. Nothing fits.
- A sentence in `execute-plan` beyond about sixteen words. The 7-word version fits with nine to
  spare, which is not a margin anybody should spend deliberately.
- A new skill named in more than nineteen characters, on the SessionStart roster's 21 characters of
  headroom.

So "a sentence in each coding skill", option 6 in question 3, is not merely the weakest option. For
`write-plan` it is arithmetically impossible today, and for `execute-plan` it consumes the last of
the margin. That is a second, independent reason to prefer the reference-file route, which has no
ceiling at all.

## 5. What the eval entry implies about the size of the fix

`tests/evals/results.md:2470-2474` records that arm 2 "read the key out of the profile itself and
used it to set severity", unprompted, for a gate that
`templates/profile.schema.json:254` said had "no effect". Three things follow, and all three make the
fix for **B** smaller. None of them shrinks A.

**The behaviour was already there.** The model found `docs/standards.md` with no skill pointing at
it, complied with it, and read the gate out of the raw profile to set severity. keel was not adding
a capability; it was documenting one it did not know it had. The correction that shipped was
one line of schema wording plus a regenerated `docs/profile-keys.md` (`tests/evals/results.md:2479`).
That is the size of the fix the evidence actually supports for B: a documentation correction.

**The gap is in the claim, not the behaviour.** What the run falsified was keel's description of
itself, twice in the same file. Two more such claims are still live and uncorrected:
`docs/02-skill-catalog.md:69` and `:382`. Fixing those costs nothing and makes keel's self-description
true, which is the whole of B as measured.

**And it makes the prose options worse, not better.** The same entry showed that the rule keel *had*
written and the model *had* loaded produced no behavioural difference at all
(`tests/evals/results.md:2420-2422`), and instructed that "why does a loaded rule not bind" be
answered before any wording change is made (`:2450-2452`). A run where the unwritten rule was
obeyed and the written rule was not is an argument for structural edits and against sentences.

**What it does not license.** `tests/evals/results.md:2488-2493` states its own limits: one run per
arm, one fixture, one language, "one small repo where `standards.md` sits at a path an arm will find
without trying", `refactor` and `debug` never exercised, and the delegated `execute-plan` path "not
tested here at all". So the evidence supports shrinking B to a documentation fix plus the delegated
path, and it says nothing about A in either direction. A's evidence is the payments-api instance and
nothing else.

## Open questions

1. ~~**Who inherited a repository with a `standards.md` and could not find out whether the code
   followed it?**~~ **Answered 2026-09-01.** The `payments-api` instance above: a
   1,271-line document derived at `5fb8b81`, 169 commits and 325 changed files later, with four
   sections that decayed at four different rates. A is unparked.
2. ~~**Does an agent find `standards.md` in a large tree?**~~ **Answered: yes.** An agent located and
   applied `docs/keel/standards.md` in a 388-file tree with no path in its brief. This does **not**
   demote the plan-template constraint line, and question 3 above carries the rewritten rationale:
   the delegated case is about what a subagent is *sent*, not what it could find.
3. **Why does a loaded rule not bind?** Still open, and still keel's own precondition for any wording
   change (`tests/evals/results.md:2450-2452`). Every option in question 3 ranked below third is
   blocked on it; the two ranked above are not, because neither is a rule. The instance does not
   touch this question.
4. ~~**Should the assessment write a dated report or amend `standards.md`?**~~ **Answered: a dated
   report.** `skills/security-audit/SKILL.md:63` writes `<docs_root>/audits/YYYY-MM-DD-security.md`,
   so an assessment writes `<docs_root>/audits/YYYY-MM-DD-standards.md`. payments-api already follows that
   directory shape, with four files in `docs/keel/audits/`, though two of the four do not use the
   `-security.md` suffix. That drift was the argument for stating the convention, which
   `docs/prd/standards-assessment.md` section 14, decision 2 now does.
5. **New: does the ranking hold on a second instance?** The order in section 2a is one repository's
   result. House-defaults coverage ranking first is the most surprising part of it and the most
   likely to be an artefact of payments-api specifically, whose document skipped four applicable
   references whole.
   A second instance would either confirm the order or reduce it to "run all four".
   **Answered 2026-09-01 by a second instance, and it splits.** The order holds on yield, where
   check 1 found 51 of 76, and fails on cost, where check 1 is the most expensive of the four and
   the backlog is the cheapest. So it is a yield ranking, not the cost ranking this record claimed.
   The decision it was thought to threaten is untouched: all four still run together, and the fixed
   order is what makes two reports comparable. Figures and six defects the run found in the shipped
   mode are in `docs/prd/standards-assessment.md` section 16.

## Recommendation

**Two things, and they are independent.**

**For B, ship the four small edits.** None is a new sentence of prose telling the model something it
already does: add the `=== PROJECT STANDARDS ===` block to the implementer prompt in
`skills/execute-plan/references/subagent-prompts.md` to match the one already at `:105-106`; add a
standards line to the Global constraints in `skills/write-plan/references/plan-template.md:28`;
delete the enforcement claim at `docs/02-skill-catalog.md:69` and correct the false `refactor` read
at `:382`. All four cost zero body words, none touches a skill body, none needs an eval arm, and each
fixes something inconsistent inside keel today rather than adding a rule whose measured effect on
this exact question was zero (`tests/evals/results.md:2420-2427`).

**For A, build the assessment mode.** It was parked for want of a named instance; the instance
exists and is measured above. Build it inside `coding-standards` as a scope branch, at the measured
~~150 body words landing the skill at 833, with a 32-character description addition landing at 213
of 216~~, **superseded 2026-09-01: it shipped at 193 words landing 876, and a 31-character addition
landing 212.** The 150 was measured against a draft that carried neither the three mode-selection
branches nor the link to the reference file, and a further 11 words were added after the first
ADR-0001 arm failed. See `tests/evals/results.md`.
One router row reworded at `skills/keel/SKILL.md:28`, and one eval arm under ADR-0001. The four
checks go in the order section 2a gives, and that order is the substance: ~~the cheapest check found
the most~~, and a mode that lists the checks without ranking them throws away the only thing this
instance taught.

**"The cheapest check found the most" was half wrong, and a second instance on 2026-09-01 said so.**
Check 1 found the most, decisively, 51 findings of 76. It is not the cheapest: reading ten topic
references costs about 1,500 lines before a single disposition can be assigned, and it came out most
expensive of the four, tied with the judgement sample. The cheapest is check 2, the backlog. The
ranking survives as a yield order and not as a cost order, and this record should not be read as
evidence for the latter. Full figures and six defects the run found in the shipped mode are in
`docs/prd/standards-assessment.md` section 16.

**What the instance did not show, stated plainly.** It did not show that the code had drifted from
its judgement rules. Five of six sampled rules were fully or near-fully observed, which agrees with
`tests/evals/results.md:2433` rather than contradicting it. It did not find a stale departure
ruling; that category came back empty against a brief that predicted it would be the dangerous one.
The cost this instance demonstrates is an **information gap**: four checks with four different
answers and no way to know which one to run. That is a smaller claim than the brief made and it is
the one the evidence supports.

## Not decided here

Two of these were closed by `docs/prd/standards-assessment.md` on 2026-09-01 and are struck rather
than deleted, so the decision keeps its trace.

1. ~~Whether the mode's four checks should be independently selectable or always run together, which
   question 5 turns on.~~ **Answered: always together, in the ranked order.** Lives at
   `docs/prd/standards-assessment.md` section 14, decision 1, and as FR-25 and CON-02. The deciding
   reason is that selectable checks would leave everyone running the one the record ranks first, so
   open question 5 could never be answered. **The clause "which question 5 turns on" was wrong** and
   is corrected by that decision: it does not turn on question 5, and would only be reopened by a
   cost finding. **The cost finding arrived on 2026-09-01 and did not reopen it.** Check 1 is the
   most expensive of the four, not the cheapest, and the decision is unaffected: what running all
   four together buys is two comparable reports, which a cost ranking neither supports nor
   threatens.
2. ~~Whether the `-standards.md` versus `-security.md` suffix convention under `<docs_root>/audits/`
   wants stating in `write-docs` or left to each skill.~~ **Answered: stated, in one place, and not
   in `write-docs`.** `<docs_root>/audits/YYYY-MM-DD-<kind>.md`, where `<kind>` is the noun of the
   skill that wrote it. Lives at `docs/prd/standards-assessment.md` section 14, decision 2, stated
   in `docs/02-skill-catalog.md` rather than in a skill body.

Still undecided: whether `refactor` and `debug` should read the standards doc at all, since neither
was ever exercised (`tests/evals/results.md:2490`); whether the other four "read by nothing" gate
descriptions in `templates/profile.schema.json` should be reworded, which
`tests/evals/results.md:2483-2484` explicitly leaves open on the grounds that "one run against two
keys is not the evidence for rewriting five"; and whether `keel doctor` should warn when
`gates.coding_standards` is `required` and no `standards.md` exists.
