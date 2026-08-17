# Current-state prose

A document describes what is true now. It is not a record of the review, the correction, or the
argument that produced it. This applies to every document keel writes, to code comments, and to
user-visible copy.

## Where the residue comes from

Review history enters a document mainly when the document is **patched after a correction**, not
when it is first written. Amending the sentences that carried the wrong claim keeps their frame, so
the correction is layered onto the mistake rather than replacing it. The result argues with a
reader who never saw the exchange.

The fix is structural, not stylistic. You cannot edit your way out of a wrong frame.

## The three rules

1. **Rewrite the affected section from the current state of the code.** Delete it and write it
   again. Do not edit around the wrong sentence.
2. **Do not carry the correction into the text.** The document says what is true. It does not
   record that it used to say something else, or why that was reasonable at the time.
3. **Keep tradeoffs in Alternatives considered**, stated as properties of the option rather than
   as an account of what happened when it was tried.

## Reread for these tells

Before finishing, read the changed section back and look for:

- Past-tense narration of the work: "proved", "turned out", "was used briefly", "initially",
  "originally".
- A sentence explaining why something is **not** the case, or contrasting the real cause with a
  wrong one.
- A rejected option described by what happened to it instead of by what it is.
- Any sentence that only makes sense to someone who saw the correction.

Each of these is a sentence the reader has to decode before they can use the document. The reader
is the person who has to act on it, at the moment they have least context.

## Rewrites

| Residue | Current state |
|---|---|
| "The worker initially used a shared connection pool, which turned out to deadlock under load, so it now opens its own." | "The worker opens its own connection pool. A shared pool deadlocks once concurrent jobs exceed the pool size." |
| "Note that the timeout is not the cause of the retry storm, as was first assumed." | Delete it. Say what causes the retry storm. |
| "We tried a materialised view briefly and it did not work out." | "A materialised view refreshed on write adds roughly 80ms to each write and still serves a stale balance to a read inside the refresh window." |
| "This section was rewritten after review to clarify the ordering guarantee." | Delete the sentence. Keep the clarified ordering guarantee. |

## Where history does belong

History is not banned, it is filed:

| Record | Holds |
|---|---|
| `CHANGELOG.md` | What changed, when, and what it fixed |
| A superseding ADR | What was decided before, what changed, and why it no longer holds |
| An incident record | What happened, in order, with timestamps |
| Git history and the PR | The exchange itself, including the review |

A superseded ADR is kept rather than edited, for the same reason: it shows what was believed and
when. That is the record's whole value, and it is a different job from the document describing the
system today.

## A note on scar rules

A rule stating the failure that produced it is not residue. "Every rule carries its reason, and its
reason is usually a scar" is how keel writes standards, and an unexplained rule gets relitigated
under pressure. The distinction is whether the sentence tells the reader something they can act on:

- **Keep:** "A committed coverage report said 1.94% where the truth was 23.29%, so the figure is
  read from the tool's own output." The number is what makes the rule stick.
- **Delete:** "This rule was added after review feedback." Nothing follows from it.
