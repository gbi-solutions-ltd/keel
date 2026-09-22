# The standards gate

Read from `skills/ship/SKILL.md`, gate item 5. What `gates.coding_standards` in
`.keel/profile.json` does to a ship, and which `review-code` findings it acts on.

## What counts as a standards violation

`review-code` ranks every finding `Blocking`, `Should fix` or `Consider`
(`skills/review-code/SKILL.md`, "Step 4: Rank, and say what blocks"), and files a standards
breach under `Should fix`, beside "will cost real time later". Gate item 5 already refuses on
`Blocking`; this file is about the `Should fix` row, and only part of it.

A `Should fix` finding is a **standards violation** when its text cites a file under
`skills/coding-standards/references/`, in any form: a bare `caching.md`, a "See `resilience.md`,
'Isolate'", a `path:line` into that directory. Every bullet in
`skills/review-code/references/rubric.md` that comes from a reference file names that file, so a
finding that quotes its bullet carries the citation; one that plainly restates a rubric bullet and
drops the file is read as citing that bullet's file. Nothing is added to the finding.

Three things it is not:

- A `Blocking` finding. It stays `Blocking` whatever it cites, and item 5 refuses on it whether or
  not this gate is on.
- A `Should fix` finding that cites nothing under `skills/coding-standards/references/`. Reuse of
  something the codebase already has, a name, a test asserting something adjacent: real findings,
  not this gate's.
- A finding that cites nothing and restates no rubric bullet. It is not a standards violation
  here. Say in the ship report when a finding looks rubric-sourced and no bullet can be matched to
  it: that is a defect in the review, not a reason to guess.

## What the gate does with one

Read `gates.coding_standards` from `.keel/profile.json` before item 5. The three values mean what
they mean for every other gate in the profile.

| Value | An unaddressed standards violation |
|---|---|
| `required` | Refuses the ship. Report it the way any failed check is reported, under "When something is red": which finding, its citation, and stop |
| `warn` | Reported in the same words, then the ship continues |
| `off` | Not read. Item 5 requires only that `review-code` has run and nothing blocking remains |

A profile with no `gates.coding_standards` key reads as `off`. `keel init` writes `required` on
every profile it creates.

**Addressed** means one of two things. Fixed: the diff no longer carries what the finding
described. Accepted: the user names the finding under "Overrides" in the skill body, and it goes in
the PR body. "Ship it anyway" names nothing and is not an acceptance.
