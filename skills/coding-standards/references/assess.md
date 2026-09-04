# Assess mode

The checks assess mode runs, in the order it runs them. Step 0 of `SKILL.md` routes here; this
file is the mode.

The report's shape, its fixed section order, its counting units and its four disposition names are
in [assessment-report.md](assessment-report.md). Read that too: this file says which checks run and
in what order, and that one says what the document they produce has to look like.

## The checks

Write `<docs_root>/audits/YYYY-MM-DD-standards.md`, following
[assessment-report.md](assessment-report.md). Change nothing else, run nothing that alters the
project, never edit `standards.md`. **The report is one numbered section per check, in this
order:**

1. **House-defaults coverage.** `standards.md` against all ten references the index lists,
   applicable or not, each row saying what decided it. Those predicates are prose, not profile
   fields. No code read.
   - **The house defaults themselves, reported as check 1b.** `standards.md` against
     all 12 house defaults, which is every `##` section of `house-defaults.md` bar its index and
     its scope statement. Reported immediately after check 1, as its own number.
2. **The backlog.** Follow-ups and inconsistencies against HEAD, not the document's own status text.
3. **A judgement sample.** Up to eight rules, all of them where fewer exist, source read for those
   only, every imprecise match opened.
4. **The departures ledger.** Each departure into one of six categories, three of which are
   findings. Re-verify every kept departure's basis.

## Where the document exists and there is no code

Step 0 routes here and **every check still runs**, because `assessment-report.md` fixes that every
check runs every time and it is a probe inside one that gets dropped. **Check 1 and check 1b run
normally**, since both read `standards.md` against the references and neither opens a source file.

**Check 4's ledger structure is assessed**, and a kept departure whose basis cannot be re-verified
stays `kept, basis holds` with its last column reading "not re-verified, no corpus". It is not
`unclassifiable`: with no tree to check against, neither that row nor `stale reason` is earned, and
`unclassifiable` is counted as a finding.

**Checks 2 and 3 run and report "no corpus" and the reason, in the section each already has.** Their
header cells, `backlog` and `sample`, read `n/a` rather than `0`, because a zero reads as a clean
result and there was nothing to be clean. An empty repository is not a document that has been
ignored.

**The header does not imply completeness.** Name checks 2 and 3 in the "Not covered" section, by
number and by reason, as checks that ran with no corpus to run against.
