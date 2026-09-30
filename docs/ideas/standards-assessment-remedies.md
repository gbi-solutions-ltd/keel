# Idea: the 2026-09-25 standards-assessment remedies

| | |
|---|---|
| Raised by | The 2026-09-25 plan's "Not in this plan" table, row "The standards assessment's remedies", 2026-09-25 |
| Status | declined as a build. Agreed as direct work for `coding-standards` |
| Recommendation | Do not build anything. Run `coding-standards` directly against `docs/standards.md` |
| Next | `coding-standards`, on the three items named below; the APEX schema identifier gets a code fix (open question 2, answered 2026-09-27). No `write-prd` |

## The problem

`docs/standards.md` carries three unresolved items the 2026-09-25 standards assessment found and
`docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md` explicitly left undone
rather than silently decided: five house topic references skipped whole, an unescaped SQL
identifier in `lib/apex_export.py` that the document's own Data section exists to prevent, and two
departures (D-2, D-4) whose written basis no longer matches the tree.

**Evidence.** `docs/audits/2026-09-25-standards.md`, dated 2026-09-25, commit `6d67084` on
`sandbox`: coverage 41 (36 rules omitted plus 5 references skipped whole), house defaults 9 omitted
of 12, departures reclassified from 3 findings to 4. The plan's own "Not in this plan" table names
this row and routes it: "Folding in or departing from five house references, the APEX schema
identifier, and departures D-2 and D-4 are judgement about the standards document, which
`coding-standards` owns" (`docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md`,
"Not in this plan").

## What was asked for

The plan's own "Not in this plan" row, verbatim in substance: three judgement items about
`docs/standards.md`, named by the audit, owned by `coding-standards`, with "Next" already naming
that skill rather than a design task or an ADR (contrast the two rows above it in the same table,
both routed to `design-architecture, an ADR`). Nothing else was asked; there is no separate feature
request behind this row, which is itself worth stating plainly before the case against.

## The case against

**Strongest argument for not building anything here at all.** Every one of the three items is a
judgement call inside a document, using a mechanism `coding-standards` already has. Step 4 of the
skill's own body says to "include the house defaults ... noting any this project deliberately
departs from" (`skills/coding-standards/SKILL.md`, Step 4), and
`skills/coding-standards/references/standards-template.md:85` already states the rule a departure
must satisfy: "Every departure is either temporary with a tracking reference, or permanent with an
ADR." Folding in or departing from five reference files, deciding what the Data section says about
one unescaped identifier, and correcting two departures' stated basis are three instances of
exactly that existing mechanism, not a missing one. Wrapping this in a plan or a PRD would impose
requirements, sequencing and acceptance criteria on a task that is a single sitting of the judgement
the skill was written to hold, which is the identical anti-pattern the plan's own table names for
the two rows above this one: "a decision before it is work; a plan task for any of them would pick
the answer silently."

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Nothing | `docs/standards.md` keeps five house references skipped whole with no departure recorded, `lib/apex_export.py:438-441` keeps building an unescaped identifier into a quoted SQL string with no written decision either way, and two departures keep citing a `CHANGELOG.md` reference and a scope claim the tree no longer supports |
| Do it manually | The same judgement, done by hand, editing `docs/standards.md` prose directly | Works for the words on the page, but skips the departure ledger's own required shape (tracking reference or ADR, `standards-template.md:85`) and the skill's own record of what was derived from what, which is what let this assessment be run and compared a second time |
| Buy it | Nothing available | This is a private document about this repository's own code; no vendor holds an opinion on `lib/apex_export.py`'s SQL construction or which of keel's ten house references apply to a bash-and-Python CLI plugin |
| Build something smaller | A short note recording "five references reviewed, applicability unchanged" without actually reading them | Worse than doing nothing: the audit already establishes all five apply (`docs/audits/2026-09-25-standards.md`, check 1, "Applies: yes" for all five), so a note that stops short of reading them would launder a compliance claim the work never did |

**Variants of routing it**

| Variant | Note |
|---|---|
| Run `coding-standards` directly on the three items | Zero new capability, zero body words, no ADR. **Recommended**, and what the plan's own "Next" column already names |
| A `design-architecture` task with an ADR | The pattern used for the two rows above this one in the same table, both of which are genuine architecture decisions (a hook, a way to call `keel` from generated CI). This row differs from both: nothing here changes what keel ships or how it runs, only what one document says about code that already exists |
| A new `coding-standards` mode for "close audit findings" | Unnecessary: Step 4 (fold in house defaults) and the departures table already cover "fold in, depart, or correct a departure," which is the entire shape of all three items here |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| `coding-standards`'s existing steps already cover "fold in a topic reference," "record a departure," and "correct a departure's stated basis," with no new mode needed | Step 4 and the departures template describe exactly those three actions | Read `skills/coding-standards/SKILL.md` Step 4 and `references/standards-template.md:85` | **Yes** |
| The APEX schema-identifier gap is a documentation judgement call, not an active, externally-reachable injection | `schema` in `fetch_db_objects` comes from a live database probe of the app's own metadata, not from untrusted external input | `lib/apex_export.py:779` sets `schema = probe_info.get("parsing_schema")`, itself read at `:354` from `apps[0].get("OWNER")`, a row from the target Oracle instance's own APEX catalog, queried by the operator running the export | **Checked. Reachability is narrow: the value comes from the same database session being exported, not a request argument**, but the standards document still has no rule or departure covering it either way |
| D-2's tracking reference and D-4's scope claim can be corrected without also deciding whether the underlying departures stay, change category, or close | Both audit rows classify the *reason* as stale, not the departure itself | `docs/audits/2026-09-25-standards.md`, departures ledger, D-2 and D-4 rows | **Not fully.** The audit reclassifies the *basis* as stale; whether D-2 becomes `tracked` again (with a real reference), `kept, basis holds`, or something else, and whether D-4's permanent ruling stays as-is or gets a narrower scope statement, is exactly the judgement being routed to `coding-standards`, not answered here |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| All five applicable house references are skipped whole, unchanged since the prior assessment | `docs/audits/2026-09-25-standards.md`, check 1: `observability.md`, `time-and-dates.md`, `resilience.md`, `api-contracts.md` and `caching.md` each show 0 folded, 0 adapted, 0 departed, all rules in `Omitted`; `git diff --stat dc9fcff..HEAD -- docs/standards.md` shows 79 insertions and 49 deletions over 23 days, none touching these five topics | The fold-in-or-depart decision for these five is real, current, and entirely inside `docs/standards.md`; nothing elsewhere in the tree needs to change for this part |
| `coding-standards` already has the mechanism this needs | `skills/coding-standards/SKILL.md`, Step 4: "Include the house defaults ... noting any this project deliberately departs from. It opens with an index of the topic references and when each applies. Read the ones that do, no more" | Confirms no new mode or capability is missing; this is ordinary use of Step 4 against five specific files |
| The Data section's own rule is unaddressed and a matching instance sits in the tree | `skills/coding-standards/references/house-defaults.md:163`, "Parameterised queries only ... Where a column or table name must vary, use an allowlist, since placeholders cannot bind identifiers"; `lib/apex_export.py:438-441` builds `owner = '%s'` by interpolating `schema.upper()` unescaped into a quoted SQL string literal, with no allowlist | This is the "APEX schema identifier" item: a live instance of exactly the gap the rule exists to prevent, inside the one file that talks to a real database at all |
| The same file escapes a different value the same query family needs, one function away | `lib/apex_export.py:500` escapes table names with `t.replace("'", "''")` in `fetch_trigger_names`, three lines above `:503` which interpolates `schema.upper()` unescaped, the same pattern as `:438` | The inconsistency is inside one file, not a project-wide habit; whatever `coding-standards` decides (fold in the rule and flag both sites, or record a scoped departure) has a narrow, named target rather than an open-ended sweep |
| `docs/standards.md`'s Data-section departure covers one bullet and leaves the rest silent | `docs/standards.md:285`, "Migrations forward-only \| Not applicable \| No database", against `skills/coding-standards/references/house-defaults.md:161-177`, which also states parameterised queries, table ownership, expand-migrate-contract, backfill and indexing rules that the existing departure row says nothing about | The existing departure was written for one bullet ("no database" for migrations) and never revisited when `lib/apex_export.py` started running live queries against a customer's database; the document has not caught up with the code |
| D-2's tracking reference no longer resolves and its stated blocker no longer exists | `docs/standards.md:284`, "needs the Phase 6 harness ... Recorded as a real gap in `CHANGELOG.md`"; `tests/evals/run.sh` was added 2026-08-11 (`git log --diff-filter=A -- tests/evals/run.sh`), the same day the document itself was derived; `grep -n "Phase 6" CHANGELOG.md` returns nothing today | The row's basis is verifiably stale, independent of the audit's own re-verification; `coding-standards` has to decide the row's new category, not just its wording |
| D-4's scope claim is contradicted by the current tree, more so than the audit found | `docs/standards.md:290`, "scoped to one command; nothing else in `bin/keel` gained a hard dependency"; `bin/keel#the profile cannot be read or written safely` dies with no `python3`, and `have_python` gates at least fifteen other sites in `bin/keel` today (verified 2026-09-26 by direct grep, more than the seven the audit's own commit-`6d67084` line numbers named, because `bin/keel` gained 307 lines between that commit and the current tree) | The scope claim is false and has grown more false since the audit itself ran; whatever `coding-standards` writes needs to describe the dependency as it is now, not re-cite the audit's own now-shifted line numbers |
| The other two departures in the same ledger (D-1, D-3, D-6) are not part of this row | `docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md`, "Not in this plan" row names only "departures D-2 and D-4" | D-1 (stale, needs an ADR for strict typing) and D-3 (needs an ADR for migrations) are out of scope for this item on the plan's own wording, even though the audit discusses all of them in the same section |

## Open questions

None block a recommendation. Left for `coding-standards` to answer while doing the work, since each
is exactly the judgement this row routes to it:

1. For each of the five house references, does keel's own tree fold in real content, or does it
   record a departure with a reason? The audit's own "Applies: yes" column (check 1) has already
   settled applicability; what remains is content, which is judgement over `lib/`, `bin/keel`,
   `hooks/` and `.keel/profile.json`, not a question this record can answer without duplicating that
   work.
2. ~~Does the APEX schema identifier gap get fixed in `lib/apex_export.py` (escape or allowlist the
   value the way `:500` already does for table names), recorded as a departure with a reason, or
   both?~~ **Answered 2026-09-27 by Bernard, asked as a choice: fixed in code, with no departure.**
   A departure with no code change would be recording a known gap in the one house-default
   rule whose worked example, in the skill's own Step 1, is exactly this shape of defect.
3. Does D-2 become `tracked` again with a real reference, or does its category change now that the
   harness it names has existed since the document's own derivation date? And does D-4 stay a
   permanent departure with a corrected scope statement, or does the scope itself change?

## Recommendation

**Do not build anything.** All three items are judgement calls inside `docs/standards.md`, and
`coding-standards` already has the exact mechanism each needs: Step 4 for folding in or departing
from a house reference, and the departures template's tracking-reference-or-ADR rule for correcting
D-2 and D-4. Building a plan, a PRD, or a new skill mode around this would impose process on work
that is one sitting of existing judgement, the same reasoning the plan's own table already applied
to route this row here rather than to `design-architecture`. Next: run `coding-standards` directly
against the three items above; no `write-prd`.

## Not decided here

Which specific content each of the five house references contributes to `docs/standards.md`, or
what wording the Data section, D-2 and D-4 end up with: that is the judgement being routed to
`coding-standards`, not a decision this record can make without duplicating the skill's own steps.
Also not decided: whether the fix escapes or allowlists the schema identifier. And not decided: the
broader `house-defaults.md`
check-1b coverage gap (9 of 12 sections omitted, of which Data is only one) beyond the one named
instance, since the plan's "Not in this plan" row names the APEX schema identifier specifically and
not the full check-1b count.
