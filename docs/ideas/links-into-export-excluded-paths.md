# Idea: the validator resolves links against this tree, not the one that ships

| | |
|---|---|
| Raised by | Bernard, 2026-09-04, from the 0.18.0 release. Carried out of `.keel/handoff.md` before it was discarded |
| Status | **recorded, not planned.** The release step that catches this class already exists and worked; this is about catching it earlier |
| Recommendation | Do nothing yet. One occurrence in the repository's life, caught by the gate built for it. Revisit on the second |
| Next | nothing |

## The problem

`tests/validate-skills.sh:285` resolves every markdown link in `docs/` and the root against the
filesystem it is run on:

```sh
[ -e "$ddir/$target" ] || report "$f: broken link to $target"
```

That is the right check for this repository and the wrong one for the repository people read.
`tests/export-public.sh:42-47` drops three paths on the way out:

```sh
case "$1" in
    docs/audits/*|.claude/*|.keel/handoff.md) return 0 ;;
```

A link from a shipped file into one of those three resolves on every internal run, for everyone who
has the whole tree, and is broken for every public reader. **The validator cannot see the failure
because it never looks at the tree that has the hole in it.**

## What happened

`docs/ideas/repo-layout-omits-its-own-executable.md` linked `.claude/settings.json`. It passed the
validator on every run and on the pull request. The export's own suite, section 4 step 2 of
[`../runbooks/cutting-a-release.md`](../runbooks/cutting-a-release.md), failed on the exported copy
during the 0.18.0 release, which is the step that exists for exactly this and is the second time it
has earned its place. Fixed by naming the path rather than linking it, with the reason written into
the document so it is not repaired back.

The gap is the distance between those two runs: **commit time against release time.** A defect that
lands on `main` and sits there until someone cuts a release is cheap here, where releases are
frequent and the export suite is not skippable, and it would not be cheap in a repository where
either of those changed.

## What a rule would cost

The check itself is small. In the docs link loop, when a resolved target is a path the export
excludes, report it. The cost is not the check, it is the list.

| Way to get the list | Cost |
|---|---|
| A second copy of the `case` in `tests/validate-skills.sh` | Two lists that must not drift, and nothing that fails when they do. This is the shape the repository already rejects elsewhere |
| Source `excluded()` from `tests/export-public.sh` | Not sourceable. The script parses its argument, refuses a non-empty destination and runs `mkdir` at load time, so sourcing it does work |
| Move `excluded()` into a shared file both read | Correct, and it is a third file plus a test for it, for one function of six lines |
| Grep the `case` line out of `export-public.sh` at validate time | One list, no new file, and a parse of a shell script by a shell script that breaks silently when the case is reformatted |

None of the four is obviously right at one occurrence, which is most of why this is recorded rather
than built.

## What it would and would not catch

**Would:** a link from a shipped file into `docs/audits/`, `.claude/` or `.keel/handoff.md`, at the
commit that writes it.

**Would not:** anything else the export changes. The export is a file subset and nothing rewrites
content, so a broken link is the only class it can introduce, but the same reasoning says a fourth
exclusion added later inherits the rule for free only if the list is genuinely shared.

Links **out of** an excluded file need no rule. `docs/audits/` does not ship, so where its links
point is not a public reader's problem.
