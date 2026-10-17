# Deciding whether the diff touches `hard_block_paths`

Read from `skills/security-audit/SKILL.md` step 1, `skills/review-code/SKILL.md` step 3 and
`skills/ship/SKILL.md` check 4. The answer is `keel plan risk`'s, not a reading of the profile,
because `plan risk` reads every profile the hook could read and treats an edit to a profile as
sensitive, and the same command already decides the review loop. A diff that edits the list that
judges it must not be able to relax its own audit. Where `keel` cannot answer, the model makes the
same match itself by `keel`'s rule, [below](#the-match-by-hand), because a tool that did not run has
decided nothing about the change.

## The command

`<base>` is the branch the change is measured against: for the audit, the default branch, which
`ship` opens the pull request against; for `review-code`, the review's base, the one the request
names, else the default branch. Run, from the repository root,

```bash
b=$(git merge-base <base> HEAD) && { git diff -z --no-renames --name-only "$b"; git ls-files -z --others --exclude-standard; } | xargs -0 keel plan risk --
```

It covers the commits since the merge-base, the uncommitted edits and the untracked files together.
`ship` runs this gate before it commits and the other two may run on work in the tree, so a commit
range would miss that work, and `git diff` lists no untracked file, so a new file under a sensitive
path would otherwise read as `loop: light`. Run it from the root because `git ls-files` lists only
the current directory, relative to it. Diff from the merge-base, never the branch name: the branch
tip carries the default branch's own later commits, which are not this change.

An empty list means no sensitive files, because nothing changed: `keel plan risk` with no paths
would fall back to `--staged`. GNU `xargs` still runs it once on an empty list, it exits non-zero,
and the line exits 123. That means none only when the list (the part before the `|`, run alone) is
empty; with any path in it, 123 is a `keel` failure. BSD `xargs` runs nothing on an empty list and
prints no `loop:` line. With the `&&` form, a failed `git merge-base` stops the line with a non-zero
exit before `keel` runs. Each is read by the rules below.

Read stdout only; `keel` writes its notes to stderr.

## Reading the result

- Exit 0 and `loop: full`: the diff touches `hard_block_paths`, and the paths printed before the
  `loop:` line are the sensitive ones.
- Exit 0 and `loop: light`: it does not.
- A printed `.keel/profile.json`, or a path ending `.keel`: every changed file is sensitive, because
  a change cannot lower its own audit by editing the list that judges it.
- `keel` not installed, any other exit, or no `loop:` line: make the match by hand, below. Reading
  a tool that did not run as touching makes every finding block, so `warn` could no longer differ
  from `required`.

The report says which way the match was made, by `keel` or by hand, and for a match by hand why
`keel` did not make it, so the next reader can tell the command's answer from the model's.

`gates.security_audit` is still read from the default branch where the diff changes it, so a branch
cannot switch off its own audit.

## The match by hand

It is `keel plan risk`'s rule applied by the model, from the repository root, so the two agree.

1. **The changed files.** Run the list before the `|` above on its own. An empty list means none,
   because nothing changed. If no list can be had, because this is not a git repository or
   `git merge-base` fails, read as touching and say why: nothing can then show the change stays
   clear of those paths, and failing to decide is never a reason to audit or review less.
2. **The patterns.** Read `hard_block_paths` from `.keel/profile.json` on the default branch
   (`git show <default>:.keel/profile.json`) and in the working tree, and use both lists, because a
   change cannot relax its own list. Add the patterns of any nested `.keel/profile.json`, used as
   written, because the hook reads the nearest profile to wherever it runs. A profile missing from
   either, a missing key or `[]` adds nothing. A profile that is not valid JSON, or a list that is
   not strings, gives no patterns to clear a file with, so it is read as touching, as `keel` reads
   it.
3. **A changed profile.** A changed `.keel/profile.json`, or a changed path ending `.keel`, makes
   every changed file sensitive, for the reason above.
4. **Each file against each pattern.** With a trailing `/` dropped from the pattern `p`, a file
   matches when Python's `fnmatch(file, p)` or `fnmatch(file, p + "/*")` is true, the file being its
   path relative to the root. `*` crosses directory separators, so `src/*` matches
   `src/client/config.ts`, and the second form makes a bare directory such as `src/auth` match
   everything under it. Run it in `python3` where there is one rather than judging by eye, because
   a shell glob reads `*` and `**` differently. The files that match are the sensitive ones; none
   matching means the diff does not touch `hard_block_paths`.

## A finding's path

A finding is on a sensitive path when its file is among the sensitive files the match found, by
`keel` or by hand, or when the match made every changed file sensitive or was read as touching. Do
not call `keel plan risk <path>` per finding: it reads only the working tree's profile, which the
change under audit may have relaxed.
