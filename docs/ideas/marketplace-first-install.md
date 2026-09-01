# Idea: document install from the marketplace, not from a clone

| | |
|---|---|
| Raised by | Bernard, 2026-08-16 |
| Status | **built 2026-08-16**, via `docs/plans/2026-08-16-done-conditions-model-pins-and-install-docs.md`, fully ticked. `docs/03-install-and-distribution.md` documents the marketplace-first install. Status corrected 2026-08-30 |
| Recommendation | Build it. The current documents state something that is no longer true |
| Next | `docs/plans/2026-08-16-done-conditions-model-pins-and-install-docs.md`, tasks 1 and 2 |

## The problem

The install documents tell a new user to clone the repository and symlink `bin/keel`, and justify it
with a claim about Claude Code that is now false. At release, an external user has no clone, so the
documented path does not describe the install they will actually perform.

**Evidence.** `README.md:12-14` and `docs/03-install-and-distribution.md:23,40` both state that
plugins do not extend PATH. Checked 2026-08-16 against the plugins reference and against this
session: a plugin's `bin/` directory is added to the Bash tool's PATH, and this session's PATH ends
with the keel repo's `bin`, where `keel version` prints `0.6.1`.

## What was asked for

> Documentation should be updated to consider plugin installation directly from the marketplace, not
> symlinking a repo. This is in preparation for actual release.

## The case against

**Strongest argument for not building this at all.** Nothing is broken for anyone currently using
keel. Both existing users have clones, so the documented path works for them, and the wrong sentence
costs them nothing. Rewriting Install and Upgrading now means rewriting them again if the release
shape changes. That argument is weak, and it is the strongest available: the sentence is false, it
is load-bearing (it is the stated reason for a manual step), and it is in the first fifteen lines a
new user reads.

There is one real complication, and it is a reason to be careful rather than to wait. The plugin's
`bin/` goes on PATH **for Claude Code's Bash tool**, not for the user's login shell. So the symlink
is not obsolete; its justification is. It survives as an optional step for anyone who wants to run
`keel doctor` in their own terminal, and the documents must not overcorrect into implying the
marketplace install puts `keel` on the system PATH.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Nothing today | Ships a false statement to the first external user |
| Do it manually | Explain it in the announcement | An announcement is read once. The README is read every time |
| Buy it | Not applicable | |
| Build something smaller | Fix the one false sentence, leave the structure | Tempting, but Upgrading is built on the same assumption and would still be wrong |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| A plugin's `bin/` reaches the Bash tool PATH | The plugins reference says so and it is observable | Documented, and observed in this session | Yes |
| It does **not** reach the login shell | Nothing outside Claude Code sees it | Not directly tested. Follows from the documented scope | Documented, not tested |
| `bin/keel` works from the plugin cache | It resolves `HERE` correctly from the cache copy | `bin/keel:35` has an `incomplete install` guard for exactly this. Untested against a cache copy | No |
| The CLI and plugin versions match after a marketplace install | There is no clone to drift from | This session already shows drift: cache holds `0.6.0`, working tree `0.6.1`, PATH points at the working tree | Partly, and it currently drifts |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| The stated reason for the symlink is false | `README.md:13-14`; `docs/03-install-and-distribution.md:40` | The claim, not just the step, has to change |
| The symlink is documented as a first-class install step | `docs/03-install-and-distribution.md:44-47` | It becomes optional, and needs a new and narrower justification |
| Upgrading assumes the CLI lives in a clone updated by `git pull` | `README.md:52-82`, the three-layer table | Under a marketplace install there is no clone. The table collapses from three layers to two |
| `bin/keel` guards against a partial install | `bin/keel:35` | The guard exists. Whether it passes from a cache copy is untested and is the one real risk here |
| Distribution is already declared as the marketplace | `.keel/profile.json`, `deploy.target` and `deploy.note` | The profile already says what the documents do not |
| Version drift between CLI and plugin is real and observable | Cache `0.6.0` against working tree `0.6.1` in this session | A `doctor` check comparing the running CLI to the loaded plugin has something to catch |

## Open questions

1. **Does `bin/keel` run correctly from the plugin cache?** This is the one thing that must be tested
   before the documents promise it. If the cache copy is complete, it works; if the marketplace
   install prunes anything `bin/keel` sources from `lib/`, the guard fires and the whole
   marketplace-first story fails.
2. **Does the symlink stay in the README, or move?** It is now a minority case (using `keel` outside
   Claude Code) and putting it second is part of the point.
3. **Should `keel doctor` compare the running CLI against the loaded plugin version?** The drift is
   real, and under a marketplace install it should be impossible, which makes it a good check.

## Recommendation

**Build it.** Rewrite Install and Upgrading marketplace-first: two `/plugin` lines are the install,
the symlink drops to an optional step for running `keel` in your own terminal, and the Upgrading
table loses the `git pull` row. Correct the false PATH claim in both `README.md` and
`docs/03-install-and-distribution.md`, replacing it with the accurate narrower one.

Test that `bin/keel` runs from a plugin cache copy **before** the documents say it does. That test is
the actual work; the prose is an hour.

## Not decided here

Whether `doctor` gains the version-comparison check; whether the symlink instructions move to a
separate page; what the release announcement says.
