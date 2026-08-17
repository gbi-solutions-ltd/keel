# Designing against a system that already runs

Everything here was found on the first `--existing` run, on a project whose PRD, stories, design,
ADRs and plan were all written by keel a day earlier. That is the common case for this mode and it
is the one the skill was least prepared for.

## What to read

Read the PRD and the stories first, as in every mode. Then:

| If | Read |
|---|---|
| A snapshot exists at `<docs_root>/snapshot.md` | The snapshot, then the code it points at |
| No snapshot exists | The existing design, its ADRs, and the code itself |

**A missing snapshot is normal, not an omission to fix first.** `repo-snapshot` is for onboarding
onto an unfamiliar codebase. A project keel built from an idea has never needed one, so `--existing`
on keel's own output will usually find nothing there. Do not stop, and do not run `repo-snapshot`
just to satisfy this step: the design and the ADRs already say what a snapshot would, in more detail
and with the reasoning attached.

Read the code as well as the documents, whatever the documents say. In this mode the code is the
requirement: it is what "established patterns win" actually refers to, and a pattern you have only
read about in a design is one you may be about to contradict.

## Where the design goes, and what it must link to

Write to `<docs_root>/architecture/<slug>.md`, named for the change rather than the product. A
second file named after the product is the mistake: `bureau-rate-board.md` and
`bureau-rate-board-v2.md` are two documents nobody can order.

**Both directions must be linked, and this is the step most easily skipped.**

- The new design's header carries an `Extends` row naming the design it extends.
- The existing design gains an `Extended by` row naming the new one and its ADRs.
- Every component, section or coverage row in the existing design that the new one changes is
  updated in place, not left to be contradicted silently.

An `auth` component whose responsibility column still reads "identify a rate setter" after a
document has been written designing exactly that is a document nobody will find. This is the same
defect the greenfield run recorded as finding 1, arriving one step further down the chain: a skill
that reads an artifact and does not write back to it.

## Requirement coverage for a scoped design

The template's rule that every requirement appears is written for `new` mode, where the design
covers the whole product. A scoped `existing` design covers a slice.

Cover the requirements the design touches, then close the table with a row pointing at the design
that covers the rest:

```markdown
| Everything else | Main design section 10 | Not touched by this design |
```

Copying the full table into every subsequent design guarantees the copies drift apart, and the
reader then has two coverage tables disagreeing with each other and no way to tell which is current.

## Look for the requirement that is missing

Step 6 asks which requirements the design fails to address. In this mode ask the question the other
way round as well: **which requirement should exist and does not.**

Requirements written before a system existed describe what it must do. They routinely omit what must
happen when something is taken away: an account revoked, a device retired, a customer offboarded, a
feature turned off. Nobody notices while the system is imaginary, because nothing has been granted
yet.

Found this way on the first run: the PRD required that setting a rate be authenticated and said
nothing about removing that access, so a departed manager kept the ability to change every branch's
displayed rate until somebody telephoned the vendor. The gap had survived a PRD, a revision of that
PRD, 19 stories and a full design.

A missing requirement is the PRD's to add, not the design's to assume. Put it to the user as a
choice, and when the answer is yes, add the requirement, add the story, and trace both.
