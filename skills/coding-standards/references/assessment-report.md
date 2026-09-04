# Assessment report template

The structure of `<docs_root>/audits/YYYY-MM-DD-standards.md`, written by `coding-standards` in
assess mode. Nothing in an assessment modifies what is being assessed, and `standards.md` is never
edited. The mode makes no network request and runs no command that changes the project. **A probe
that needed a change in order to run was not run**: it belongs under "Not covered" by its real name
rather than in the findings. Probe, not check: every check runs every time, and it is an
individual probe inside one of them that gets dropped. Without that clause the sentence before it is
unenforceable, because a probe can be made to pass and then honestly reported as passing.

Two runs against the same repository must be comparable without re-reading either tree, so the
section order, the counts and the vocabulary below are fixed rather than suggested.

## Header

```markdown
# Standards assessment: <repo or service name>

| | |
|---|---|
| Commit | `<sha>` on branch `<branch>` |
| Document | `<docs_root>/standards.md`, <N> lines, derived at `<sha>` on YYYY-MM-DD |
| Commits since derivation | <N>, <M> files changed |
| Date | YYYY-MM-DD |
| Findings | coverage <n>, house defaults <n>, backlog <n>, sample <n>, departures <n> |
| Not covered | Named explicitly. See the last section |
```

`Commits since derivation` earns its row because it is the single number that predicts how much of
the document is stale, and it costs one `git rev-list --count` and one `git diff --stat`.

Each of the five `Findings` counts is defined, so that two reports mean the same thing by them.
**Coverage** is rules in the `Omitted` column, plus each reference skipped whole counted once more.
**House defaults** is the `house-defaults.md` sections `standards.md` omits, out of the sections
check 1b counts. **Backlog** is items not `closed`. **Sample** is rules whose verdict is not
`observed`. **Departures** is rows in `needs an ADR`, `stale reason` or `unclassifiable`, which is
what the `A finding?` column of check 4's category table marks yes.

## Section order, fixed

1. Summary, three sentences and the counts
2. Check 1, house-defaults coverage
3. Check 1b, house-defaults coverage as its own number
4. Check 2, the follow-up backlog
5. Check 3, the judgement sample
6. Check 4, the departures ledger
7. Trend, where a previous assessment exists
8. Not covered, explicit

That is the ranked order, highest-yield first, which is not cheapest first: check 1 costs the most
on a first run, because ten topic references have to be read before a single rule can be disposed
of. Every check runs every time, so report every one even where it found nothing. A check that comes
back clean is a result, and a reader who cannot see that it ran cannot tell it from a check that was
skipped.

**Check 1 and check 1b are never added together.** They have different denominators and different
sources, and a reader who sees one combined coverage figure cannot tell which of the two failed.
Report both, name both, and let the reader do any arithmetic they want.

## Check 1, house-defaults coverage

State the counting unit before any number. Without it two runs produce different denominators from
the same corpus and nothing is comparable.

**The unit:** one house rule is one H2 section of a topic reference, excluding any trailing
checklist heading. Three names are in use, `Testing it`, `What review looks for` and `What good
looks like`, and no file carries all three, so exclude by name rather than subtracting a fixed
number. Count every other H2, with no judgement about whether it reads like a rule, because that
judgement is what makes a denominator irreproducible.

```markdown
| Reference | Applies | Decided by | Rules | Folded | Adapted | Departed | Omitted | Skipped whole |
|---|---|---|---|---|---|---|---|---|
| `observability.md` | yes | Always, per the index | 8 | 5 | 1 | 0 | 2 | no |
| `resilience.md` | yes | Calls a partner API over HTTP | 6 | 0 | 0 | 0 | 6 | **yes** |
| `frontend.md` | no | `profile.stack.has_ui` is false | 4 | n/a | n/a | n/a | n/a | n/a |
```

**`Folded` plus `Adapted` plus `Departed` plus `Omitted` must equal `Rules`** on every applicable
row. A row that does not add up is a check that lost track of its own corpus, and the header's
coverage count is derived from the `Omitted` column, so an unbalanced row makes that count
meaningless.

The four dispositions:

| Disposition | Means |
|---|---|
| `Folded` | The rule appears in `standards.md`, substantially as written |
| `Adapted` | It appears, changed to fit this project, and the change is visible |
| `Departed` | It does not apply here and a departure row says so, with a reason |
| `Omitted` | It appears nowhere, and no departure row accounts for it. **This is the coverage failure** |

**One row per reference the index lists, all ten**, including the ones that do not apply. A report
that lists only the applicable ones cannot be compared against a run that judged applicability
differently. `Decided by` is required on every row, applicable or not: nine of the ten index rows
are prose predicates rather than profile fields, so without the deciding fact a second run can reach
a different verdict and nobody can see why.

A reference whose every rule is `Omitted` is also **skipped whole**, and is reported as such. It is
a different finding from a scatter of omissions: an omitted rule may have been considered and
dropped, a skipped reference was never opened.

## Check 1b, house-defaults coverage as its own number

**The counting unit.** One house rule is one `##` section of
[house-defaults.md](house-defaults.md), excluding exactly two by name: "The other references, and
when each applies", which is an index, and "What is deliberately not here", which is a statement of
scope. Nothing else is excluded from the count. No fixed number is subtracted, and no judgement is
made about whether a heading reads like a rule. The denominator is 12, measured 2026-09-02.

**What it reports.** For each of those sections, whether `standards.md` folds it in, adapts it,
departs from it with a reason, or omits it, on the same four dispositions check 1 uses. Report it
immediately after check 1 and before check 2.

## Check 2, the follow-up backlog

**What counts as an item.** Any row or bullet in `standards.md` naming work not yet done, whatever
the document calls it: a "Not yet mechanical" list, a follow-up table, or a known inconsistency.
`skills/coding-standards/references/standards-template.md` prescribes no numbering, so where the
document numbers its items use its numbers, and where it does not, identify each by its first clause
and **say so in the report**, because the trend section then has no stable key to match on.

Every item gets exactly one of three states.

| State | Means |
|---|---|
| `closed` | The item's full scope is satisfied in the tree at HEAD |
| `partially covered` | Some of it is. The row names what is not |
| `open` | None of it is |

```markdown
| Item | Document says | Tree at HEAD says | State |
|---|---|---|---|
| F-1 | done | The fix covered `src/*.ts`, 100 files. `test/` and one `.sql` file still carry the pattern, and the lint rule the item also asked for was never added | partially covered |
```

**Establish state from the tree, never from a commit message.** A fix's stated scope and its actual
scope differ often enough that the difference is the finding. Where an item asked for both a fix and
a mechanism, report the two separately: a fix shipped without its mechanism regresses silently, and
a row that says only "done" hides that.

## Check 3, the judgement sample

The only check that *samples* project source, and it reads it only for the rules it sampled. Check 4
may also open source, but only to re-verify a basis one of its rows actually asserts, which is a
narrower allowance than this one.

**The unit.** A judgement rule is one `**Rule:**` entry where the document marks them that way, and
the section itself where a section states a single rule. Say which of the two shapes the document
uses, because they give different denominators. `standards-template.md` permits both.

**Choosing the sample, deterministically, because two runs must pick the same rules.** Where the
document has **eight or more** judgement sections, take the first rule of each of the first eight,
in document order, and take nothing else. Where it has **fewer than eight**, take every rule it
holds, in document order, until you reach eight or run out. The two branches do not overlap, so
there is exactly one reading for any document. **Name the sections you did not
reach**, and where the document holds fewer than six rules in total, sample all of them and say how
many existed: six is a target, not a floor a short document can be made to meet.

| Verdict | Means |
|---|---|
| `observed` | Every site conforms |
| `near-fully observed` | Isolated exceptions, each named |
| `drifting` | A pattern of exceptions, or one on a path that matters |
| `not observed` | The rule describes something the code does not do |

```markdown
**Pre-derivation proportion:** 303 of 388 files (78%) predate the commit the document was derived
from, so this sample substantially measures the corpus the rules were read off rather than
adherence to them.

**Sampled:** the first rule of sections 1 to 8, of 20. **Not reached:** sections 9 to 20.

| Rule | Location of the exception | Verdict | Ratio | Reachable |
|---|---|---|---|---|
| Money quantisation (`standards.md:694`) | `product-repository.service.ts:684,690` | drifting | 8 of 9 conforming | yes, settlement path |
| `sql.raw` allowlist (`standards.md:663`) | `partition.service.ts:356,367` | near-fully observed | 29 of 32 conforming | no, cron-driven only |
```

`Ratio` is always conforming-to-total in the same form, so two runs can be compared. `Location` is
the offending file and line, never the rule's own line, because a finding a reader cannot navigate
to is a finding nobody acts on.

Two rules keep this check honest:

- **A match count is not a finding.** Open every imprecise match before reporting it, and report
  only what you opened. In one assessment all seven apparent leaks were conforming once read, and a
  sweep that reported the count would have filed seven false findings.
- **State reachability, and do not exceed it.** A rule violated only on a path nothing can reach is
  a style deviation, not a vulnerability. Writing it up as one costs the whole report its
  credibility.

## Check 4, the departures ledger

Every departure lands in exactly one category.

| Category | Means | A finding? |
|---|---|---|
| `closed` | No longer a departure | no |
| `tracked` | Temporary, with a tracking reference that exists | no |
| `kept, basis holds` | Permanent, its ADR exists, and its stated basis re-verifies as still true, or there was no corpus to re-verify it against and the ledger's last column says so | no |
| `needs an ADR` | Permanent, and the ADR it requires does not exist | yes |
| `stale reason` | Kept, on a reason the tree no longer supports | yes |
| `unclassifiable` | Fits none of the above. Name what it carries instead | yes |

`kept, basis holds` is the row an earlier draft of this template omitted, and omitting it is not
harmless. `standards-template.md` says a departure is "either temporary with a tracking reference,
or permanent with an ADR", so a permanent departure with a live ADR and a basis that still holds is
the healthy end state, not a defect. With no row for it, it falls to `unclassifiable` and is counted
as a finding. In the assessment this template was derived from, four of fifteen departures were in
exactly that state, which would have tripled the reported departure count.

**Identifying a departure.** `standards-template.md`'s departures table carries no identifier
column, so a `D-` number is positional and adding one departure renumbers every row after it. Where
the document numbers its departures, use its numbers. Where it does not, identify each by its
`Default` cell and say so, for the same reason check 2 says it: the trend section has no stable key
otherwise.

The ledger, one row per departure. The example below is an excerpt, so its rows do not total the
counts that follow:

```markdown
| # | Departure | Category | Basis re-verified against the tree |
|---|---|---|---|
| D-2 | Repository services return a result rather than throwing | tracked | Still 17 of 17 services, no competing pattern. Holds |
| D-3 | Structured logging to a collector | needs an ADR | `docs/decisions/` holds no ADR naming this |
```

Then the counts, **with every category present even at zero**, because a per-departure ledger cannot
show an empty category and the empty ones are the result:

```markdown
| Category | Count |
|---|---|
| closed | 3 |
| tracked | 6 |
| kept, basis holds | 4 |
| needs an ADR | 1 |
| **stale reason** | **0** |
| unclassifiable | 1 |
```

**In a real report the counts must total the ledger's rows**, for the same reason check 1's
dispositions must sum to its `Rules`: two tables that can disagree will.

Re-verify the stated factual basis of every departure the document rules as kept, whichever of
`kept, basis holds` or `stale reason` it then lands in, and record the result in the ledger's last
column, including where it still holds. That re-verification is the only thing separating those two
rows. An empty `stale reason` count is the most useful line in this check, and dropping the row
makes a clean result indistinguishable from a check that never ran.

## Trend

Only where a previous report exists. The prior report is the highest-sorting
`<docs_root>/audits/*-standards.md` **other than the one being written**, which matters on a
same-day re-run. Match items on the identifier the assessed `standards.md` itself uses, or on the
first clause where it numbers nothing, as check 2 records. Three lines: what closed since the last
report, what is new, and what has been open longest. This is what makes a second assessment worth
running.

## Not covered

```markdown
## Not covered

- Checks 1, 1b, 2, 3 and 4 only. Nothing outside them was assessed.
- The judgement sample read the first rule of 8 of the document's 20 judgement sections.
  Sections 9 to 20 were not read, and nor were any later rules inside sections 1 to 8.
- No test was run, and nothing was executed against a running instance. The only commands run
  against the repository were the read-only `git` queries this report's own header and check 3
  require.
```

An assessment that implies completeness it does not have is worse than a narrow one, because it
stops the next person looking.
