# Idea: the repo layout omits its own executable

| | |
|---|---|
| Raised by | Bernard, 2026-09-03, while correcting the two stale figures on `docs/06-repo-layout.md:3` |
| Status | **closed by `7e06e95`, 2026-09-04.** The four entries are in the tree, each with a comment, and `tests/test-doc-claims.sh` fails if `git ls-files` produces a top-level entry the tree does not show. All three open questions were decided; see below |
| Recommendation | The smallest version: add the four missing top-level entries by hand, then one assertion in `tests/test-doc-claims.sh` that every top-level entry `git ls-files` produces appears in the tree. Not a generator |
| Next | nothing. What is still hand-maintained is listed under "Not decided here", unchanged by the close |

## The problem

**Every figure in this section holds at `e191674`,** the last commit before the round that closed
this. They are a record of what was found, not a claim about now. `7e06e95` added the four entries, so the
tree shows 23 today, and the commands below read the document out of the named commit rather than
out of the working tree so that they keep returning what this section says they return.

[`docs/06-repo-layout.md`](../06-repo-layout.md) opens by saying what it is: "The `keel` repo as it
actually is". Six lines later it says how it stays that way, and that sentence is what makes this a
defect rather than an editorial choice:

> Regenerated from `git ls-files` on 2026-09-01, which is the only way it stays true

`git ls-files` produces 23 top-level entries. The tree in that document shows 19. Four are absent,
and one of them holds the CLI.

```
git ls-tree -r --name-only e191674 | awk -F/ '{if (NF==1) print $0; else print $1"/"}' | sort -u
                                                                             # 23 entries
git show e191674:docs/06-repo-layout.md \
  | awk '/^```$/{n++; next} n==1' | grep -oE '^(├|└)── [^ ]+'                # 19 entries
```

The second command takes the tree by fence rather than by line range on purpose. The range this
document first carried, `sed -n '15,209p'`, returned 10 within a day of being written: adding four
entries pushed the end of the fence past 209. A line range is a citation into a file that is about
to be edited, which is the same mistake in miniature as the live figure this whole document is
about.

| Absent from the tree | Tracked files | What it holds |
|---|---|---|
| `bin/` | 1 | [`bin/keel`](../../bin/keel), 2,020 lines. The CLI, and the fourth largest tracked file in the repository |
| `.github/` | 1 | [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml), the file that makes "runs on every commit" true |
| `.keel/` | 1 | [`.keel/profile.json`](../../.keel/profile.json), which the CI job reads to get the lint command rather than restating it |
| `.claude/` | 2 | `.claude/settings.json`, which enables the five plugins the wiring map depends on, and `.claude/keel-nudge`, the SessionStart hook it registers |

`.claude/settings.json` is named rather than linked, unlike the three rows above it.
`tests/export-public.sh` excludes `.claude/` from the published tree, so the link resolved here and
was broken for every reader outside this repository. The export's own suite is what caught it, on
the 0.18.0 release.

**The omission was in the regenerated output, not drift since.** All five files were tracked at the
commit that regenerated the tree:

```
git ls-tree -r --name-only 90cd8b0 | grep -E '^(bin/|\.keel/|\.claude/|\.github/)'
```

returns all five. `90cd8b0` is "docs: regenerate the repo layout tree, and correct two live stale
figures", 2026-09-01, and its message says the tree "is now generated from git ls-files rather than
maintained by hand". The four entries were absent from that output on the day it was written.

**The document already knows about two of the four, in its other tree.** "What lands in an installed
project", the second fenced tree in that document, shows `.keel/profile.json` and
`.claude/settings.json`.
keel is installed into itself and carries both files with real content, so the document shows for
every other project exactly what it omits for this one.

**The Testing strategy section describes a pipeline whose file is not in the tree.** It says tier 1
and tier 2 run "on every commit". What makes that true is `.github/workflows/ci.yml`, and that file
is written so the pipeline does not restate the lint command: it reads `.keel/profile.json`, with a
comment saying that restating it "is how the pipeline came to run a stricter check than anyone ran
locally". Both halves of that coupling are absent from the layout.

## The figures have gone stale three times

Line 3 has carried a version and a file count since 2026-08-11, and both have now been corrected by
hand three times, each time by someone who happened to look.

| Commit | Date | What line 3 said | State |
|---|---|---|---|
| `7077b5f` | 2026-08-11 | "as it should exist when Phase 6 is done. Roughly 55 files" | a plan, not yet a claim |
| `4bdc86e` | 2026-08-13 | "at 0.5.0. 121 files, excluding `resources/` and `zips/`" | true when written |
| `057f4d1` | 2026-09-01 | "at 0.16.1. 293 tracked files" | true when written, after 19 days wrong |
| `6e70f82` | 2026-09-03 | "at 0.17.0. 330 tracked files" | **false in the commit that wrote it.** 330 was the count at `54f1dfd`; this commit added two files |
| `6e70f82`, corrected | 2026-09-03 | "at 0.17.0. 330 tracked files at `54f1dfd`" | a dated measurement, and no longer a live claim |

Between the second and third the count drifted by 172 files and the version from 0.5.0 to 0.16.1.
Between the third and now it drifted by 37 files and one minor version in two days. That is the
argument for generating rather than maintaining: not that a human writes the line badly, but that
nothing tells the human when it has gone wrong, and the interval in which it is wrong is set by
when someone next happens to read it.

**The third correction is the one that settles the shape.** `6e70f82` measured 330, wrote it, and
then added `docs/ideas/bodies-over-the-target-with-no-arm.md` and this file to its own tree, so
`git ls-tree -r --name-only 6e70f82 | wc -l` returns 332. The line was wrong at the commit that
fixed it, and it had been wrong twice before on a longer clock. Three corrections is enough evidence
that the interval is not the problem: a live count of tracked files is stale on almost every commit,
including the ones that touch nothing the document describes.

```
git ls-tree -r --name-only 54f1dfd | wc -l   # 330
git ls-tree -r --name-only 6e70f82 | wc -l   # 332
```

**Anchored, not asserted.** The line now reads "330 tracked files at `54f1dfd`". An assertion in
`tests/test-doc-claims.sh` was the obvious other move and is the wrong one: the count changes on
nearly every commit, so the suite would go red on every file anyone adds, and the fix for each red
would be to retype a number nobody reads. Naming the commit converts the sentence from a live claim
into a dated measurement, and dated measurements do not move. That is the same rule that governs
every audit and eval record in this repository: a record says what was true at a named point, and it
stays correct by never claiming anything about now.

This also draws the line for the recommendation below. The top-level tree is slow moving and is a
claim about structure, so it is worth asserting. The file count is fast moving and is a claim about
a moment, so it is worth anchoring. The two figures on line 3 are not the same kind of thing, and
the version is a third: it is neither, and is still maintained by hand.

## The case against

**A generated tree is churn in every diff.** 330 files are tracked and 159 of them have a basename
that appears nowhere in the document. A raw rendering would put every eval fixture and every plan in the
document, and every commit that adds a plan would change it.

**The document's value is partly that a human chose what to show.** The tree carries judgement a
generator does not have. `tests/fixtures/` and `tests/evals/` are collapsed to one line each with a
comment saying what is inside. `skills/` is expanded in full, because the skill set is what a reader
came for. `.claude-plugin/` gets a comment on each of its two files, one of which ("its version keys
the install cache") is the fact that explains the whole distribution model. That is the difference
between a layout document and `tree` output, and a generator that flattened it would be a real loss.

**And a reader is not stranded by the four absences.** `bin/keel` is documented at length in
`docs/03-install-and-distribution.md`, and the CI workflow is the kind of file a reader looks for by
convention rather than by index.

**Where that argument fails.** The document does not present itself as a curated view. It claims to
be regenerated from `git ls-files`, and it makes that claim in the same paragraph as an account of
what hand maintenance had already lost once: a whole skill, a hook, nine test files and the docs
root. A reader who believes the sentence reads the absence of `bin/` as evidence there is no `bin/`.
The curation argument defends the interior of the tree, which nobody is proposing to generate. It
does not defend the top level, which is small, slow moving, and the part the claim is checkable at.

### Alternatives

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | nothing today | Leaves a false sentence in the one document whose subject is a tree that went false once already |
| Do it manually | four lines, once | Correct, and it is where the recommendation starts. On its own it fixes today and not the next drift |
| Generate the whole tree | a script, and the comments and collapsed directories go | Turns a document into `tree` output, and puts every new plan in the diff |
| Generate the top level, check the rest | one assertion in `tests/test-doc-claims.sh` | Nothing. This is the smallest version that would have caught this |

## What the system says

Every measurement and every citation in this table holds at `e191674`, the last commit before the
round that closed this. The line numbers have moved since, and the third row is about a sentence
`7e06e95` rewrote.

| Finding | Evidence | What it means for the idea |
|---|---|---|
| The tree shows 19 top-level entries; `git ls-files` produces 23 | measured this session, both commands above | Four entries absent, `bin/` among them |
| All five files were tracked when the tree was regenerated | `git ls-tree -r --name-only 90cd8b0` returns all five | Not drift since 2026-09-01. An omission in the regenerated output |
| The document claims regeneration from `git ls-files` | `docs/06-repo-layout.md:10-12` | The claim is what turns an omission into a defect |
| Two of the four appear in the document's second tree | `docs/06-repo-layout.md`, under "What lands in an installed project" | The document describes keel's install shape for others and not for itself |
| The CI file and the profile it reads are both absent | `.github/workflows/ci.yml`, and the Testing strategy section | The section that says when tests run omits the file that decides when they run |
| This document is already under claim testing | `tests/test-doc-claims.sh:63` asserts its eval scenario count | The pattern and the harness already exist. One more assertion is a small addition |
| The validator already walks every file under `docs/` | `tests/validate-skills.sh:267` | Either harness can host the check; `test-doc-claims.sh` is the one whose subject is figures |
| Nothing tests the tree | none of the claim assertions mentions it | The tree is the largest unchecked claim in a document that is entirely a claim |

## Open questions

1. **Should `.claude/` and `.keel/` appear in the repo tree at all**, given both also appear in the
   installed-project tree below it? Showing them twice invites a reader to conflate keel's own
   install with what `keel init` writes into someone else's project. The answer may be to show them
   with a comment naming which is which, rather than to leave them out.
2. **What exactly does the check assert?** That every top-level entry appears, or that every tracked
   path is either shown or sits under a directory the tree explicitly collapses? The second is
   stricter and would also catch the `tests/evals/run.sh` class of absence. It is also the version
   that needs a list of sanctioned collapses, which is a second thing to keep true.
3. **Does the "Regenerated on 2026-09-01" sentence survive a hand edit?** If the four entries are
   added by hand, the date is no longer the date the tree was produced, and the sentence needs to
   say what it now means.

### How they were decided

All three, in `7e06e95`.

1. **Both appear in the repo tree, each with a comment naming which tree it belongs to.** Leaving
   them out was the other option and it loses more than it saves: a reader of a tree that claims to
   be the repository should not have to know that two of its directories were held back because
   they resemble something shown later. The conflation the question worries about is real, so it is
   answered where it arises. `.keel/` carries "keel's own install of itself, not the tree below"
   and `.claude/` carries "the other half, written by `keel init` as in any project".
2. **The looser form: top-level entries only.** The stricter version would also catch the
   `tests/evals/run.sh` class of absence, and it buys that by adding a list of sanctioned collapses
   to keep true. A check that needs its own maintained input has the same failure mode as the
   figure it replaces, and it would go stale in the same silence. The top level is small and slow
   moving, so the loose check fires rarely and is informative when it does.
3. **No, the sentence does not survive, and it is replaced rather than redated.** Redating it would
   keep a claim of generation that is no longer true of a tree with four hand-written lines in it.
   The document now says what is actually the case: the top level is asserted by the suite and the
   interior is curated. That splits the claim along the line the rest of this file argues for,
   which is that the top level is checkable and the interior is judgement.

## Recommendation

**The smallest useful version, in two steps, and not the largest.**

First, add the four entries to the tree by hand, each with the one comment that earns its place:
`bin/keel` as the CLI, `.github/workflows/ci.yml` as the pipeline that reads the profile rather than
restating it, and `.keel/` and `.claude/` as keel's own install of itself. Four lines of judgement,
which is the kind of content the tree is already made of.

Second, add one assertion to `tests/test-doc-claims.sh`: every top-level entry `git ls-files`
produces appears in the fenced tree of `docs/06-repo-layout.md`. It does not generate anything, does
not touch the interior, and fires only when a new top-level entry appears, which happens rarely
enough that the failure will be informative every time.

**Explicitly not recommended here:** generating the tree, generating line 3, or asserting the file
count. Each is defensible and each is a larger argument, and none of them is needed to make the
sentence at the top of that document true. The file count is handled instead by the anchor, for
the reason under "The figures have gone stale three times" above.

## Not decided here

Whether the version on line 3 should be asserted rather than maintained; whether the tree's interior
is ever generated; whether the collapsed directories stay collapsed; where the check lives if
`test-doc-claims.sh` turns out to be the wrong home for it. The file count is decided: anchored to
`54f1dfd`, not asserted, for the reason given above.
