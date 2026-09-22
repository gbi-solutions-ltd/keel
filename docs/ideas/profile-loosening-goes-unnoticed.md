# Idea: nothing stops a profile being weakened after the fact

| | |
|---|---|
| Raised by | Bernard, 2026-09-19, "plan the work that makes keel enforceable outside the agent" |
| Status | shaped |
| Recommendation | Extend `keel guard`'s pre-push hook to diff `.keel/profile.json` between old and new sha and refuse on loosening. Add a `CODEOWNERS` entry over `.keel/` as a config-only companion. Do not build a second, doctor-only ratchet |
| Next | `write-plan`, as one increment of the outside-the-agent plan |

## The problem

Every key in `.keel/profile.json` now declares who reads it and is honest about it
(`docs/ideas/declared-profile-keys-take-effect.md`). Nothing stops someone setting `verify.test` to
a literal `true`, emptying `hard_block_paths`, or turning `gates.commit_guard` off, after which every
gate passes forever and `keel doctor` reports no problems. The profile is honest; it is not guarded.

## What actually sees the edit

**Evidence, ranked by whether the surface sees a raw `git push`, including a human pushing directly
from a terminal, outside any Claude Code or Codex session.**

1. **`keel guard`'s pre-push hook** (`bin/keel:1697-1745`, `guard_hook_body`, installed by `keel
   guard install` into `.githooks/`) is the only surface that fires on an actual push regardless of
   what produced the commit. It already reads old-sha/new-sha pairs per ref off stdin
   (`bin/keel:1754`) and currently discards both. Diffing `.keel/profile.json` between the two shas
   (`git show $old:.keel/profile.json` vs `$new:...`) and refusing on a short allow-list of
   loosening moves (`hard_block_paths` shrinking, a `gates.*` value moving toward `off`, a
   `verify.*` command becoming null or a non-string) is a natural, cheap extension of a hook that
   already parses the inputs it needs.
2. **`keel doctor`** (`bin/keel:1268`) runs inside a session or CI, after the fact. It can warn, not
   block, and today has no git-diff-based check against `.keel/profile.json` anywhere (confirmed:
   no `git diff`/`git show` against that path exists in `bin/keel` or `lib/`). Advisory only.
3. **Claude Code hooks** (`session-start`, `done-guard`, `sensitive-guard`, `context-watch`) only
   fire inside a Claude Code or Codex session. **They cannot see or stop a bare `git push
   origin main` from a terminal, a CI job, or another tool.** A ratchet built only here protects an
   AI-driven edit inside a session and nothing else. It does not close the gap as stated.
4. **CODEOWNERS.** None exists at the repo root today. A `.keel/` entry costs one to three lines,
   but has zero effect unless the hosting platform's branch protection ("require review from code
   owners") is turned on for the default branch, a repository-settings change outside this
   codebase and not something `keel init` or `doctor` can enforce or verify from inside the tree.

## Recommendation

Build the pre-push ratchet in `keel guard` (medium cost, real LOC, the only mechanism that sees a
raw push) and add the `CODEOWNERS` entry as a near-zero-cost companion, documented as needing the
platform setting flipped by hand. Do not build a separate doctor-only ratchet as its own increment:
share the detection logic between the blocking pre-push check and `doctor --json`'s fleet-facing
surface (see `docs/ideas/fleet-view-for-doctor.md`) rather than writing it twice.

## What this does not close, stated plainly

Even fully built, this remains: opt-in per repository (`keel guard install` must have been run);
bypassable with `--no-verify`; blind to a change landed through the hosting platform's web UI or API
rather than `git push`; and blind to any repository that never ran `keel guard install` at all. It
is a friction layer, not an authority layer. CODEOWNERS-plus-branch-protection is the actual
authority fix, and it lives partly outside this codebase.

## Open questions

1. Which loosening moves belong on the allow-list, and should it be a fixed table in `bin/keel` or
   itself a small declarative block (so it can be shared with `doctor --json`)?
2. Should the pre-push refusal be a hard block or a `warn`-then-`required` escalation, consistent
   with the house posture in Decision 3 (`docs/07-open-decisions.md:163-236`, "enforced with escape
   hatches")?
3. Does `keel guard install` need to become a stronger recommendation (e.g. checked by `doctor`) now
   that it is the one mechanism doing real work here?
