# Idea: the push guard scans the working tree, not the commits being pushed

| | |
|---|---|
| Raised by | The 2026-09-26 code review of sandbox, finding 6 |
| Status | built via docs/plans/2026-09-27-push-scan-reads-pushed-commits.md |
| Recommendation | Build something smaller: scan the commits being pushed, with the installed keel's scanner only |
| Next | Nothing |

## The problem

Whoever runs `git push` on a repository with `keel guard install` in place is told the scan
covered what they are about to publish. It does not: it covers whatever is sitting on disk at the
moment the hook runs, which can differ from the commits the push actually moves to the remote.

**Evidence.** The 2026-09-26 code review of sandbox is the instance: it read `guard_hook_body` and
filed this as finding 6, which the same day's guard-hooks plan
(`docs/plans/2026-09-26-guard-hooks-outside-the-working-tree.md`) records as decided out of that
plan ("the review's finding 6, the pre-push scan reading the working tree rather than the pushed
commits, is filed as an idea and is not in this plan") and the same day's
`docs/audits/2026-09-26-security.md` lists as "already decided and not re-reported".
No report of it firing against a real secret exists; the finding is a reading of the hook, not an
incident.

## What was asked for

Not a feature request. A code review flagged that the push guard's scan target does not match its
stated job, and the maintainer chose to file it rather than fix it inside the guard-hooks plan.

## The case against

**Strongest argument for not building this at all.** The hook is advisory by construction:
`git push --no-verify` skips it, it runs only where someone chose `keel guard install`, and its
scanner is a pattern denylist that misses whatever its rules do not name. Anyone who means to
publish a secret walks straight past it, so hardening it helps only the honest mistake. That is
not nothing, since an honest mistake is how most secrets reach a remote, but it is the ceiling on
what this can be worth.

A tempting argument against does not hold, and is recorded so it is not reached for again: CI is
not the backstop. keel's own workflow runs on pushes to `main` and on pull requests only
(`.github/workflows/ci.yml:3-6`), so a push to any other branch is never scanned there, and a
secret is public on the remote the moment the push lands, before any merge. A target project's
generated CI runs no supply chain scan at all (see `docs/ideas/keel-checks-in-target-ci.md`).

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Nothing | The hook keeps telling a pusher their push was scanned when it was not, and a committed-then-deleted key reaches the remote unflagged |
| Do it manually | A reviewer or the pusher rereads the diff of what is about to be pushed before running `git push` | No record of anyone doing this today, and it is exactly the discipline a pre-push hook exists to not depend on |
| Buy it | Nothing evaluated | Not assessed: the scan itself is a small, house-owned denylist (`tests/supply-chain-scan.sh`'s own header names its limits), and the gap here is which content it points at, not the scanning technology |
| Build something smaller | Point the hook's scan at `git show $lsha:` for each changed file instead of the working tree, for the pre-push hook only | Considered below, in "What the system says", against the concurrent fallback-scanner problem it does not touch |

## Assumptions this rests on

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| CI backstops the hook | CI scans every pushed branch before its content is readable on the remote | `.github/workflows/ci.yml:3-6`: CI runs on pushes to `main` and on pull requests only, and a push is readable on the remote as soon as it lands | Checked: false |
| Nobody relies on the pre-push hook as their only supply-chain check | No project runs `keel guard install` without also running the CI workflow | Unknown, and nobody could name one | No |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| The hook reads two shas per ref off stdin for the profile-loosening check, then scans with no reference to either | `while read -r _lref lsha rref rsha; do` in `bin/keel` at `f0b6d44` (now `bin/keel#while IFS= read -r line; do`, taking the fields from the right) reads `lsha`/`rsha` and diffs `.keel/profile.json` between them; the scan that follows, `if command -v keel >/dev/null 2>&1; then` through `if $SCAN; then` in `bin/keel` at `f0b6d44`, passes `$lsha` to neither `keel scan` nor the fallback script | The hook already has the exact commit being pushed in hand for one check and does not reuse it for the other. A committed-then-locally-deleted key: committed in an earlier commit, `rm`ed from disk without a further commit, is absent from the working tree the scanner walks (`tests/supply-chain-scan.sh#git ls-files --cached --others --exclude-standard`, `git ls-files --cached --others --exclude-standard`) but still present in `$lsha`, the commit the push moves to the remote |
| The scanner's own file list is documented as tracked-plus-untracked-on-disk, and its author already reasoned about the mismatch in the other direction | `tests/supply-chain-scan.sh#git ls-files --cached --others --exclude-standard` (`git ls-files --cached --others --exclude-standard`) with the comment above `list_files` in `tests/supply-chain-scan.sh` at `f0b6d44` ("the pre-push hook can flag something not actually being pushed, which is a false stop rather than a false pass") | The false-stop direction (scanning something not being pushed) was reasoned about and accepted; the false-pass direction (not scanning something that is being pushed, this idea's case) is not mentioned there, so this is a gap in that reasoning, not an oversight this idea is inventing |
| `git push origin other-branch` scans whatever is checked out locally, not `other-branch`'s content, when the two differ | The hook runs `$SCAN` with no argument identifying which ref it is scanning; `list_files` (`tests/supply-chain-scan.sh#list_files() {`) reads the working tree unconditionally | A push naming a branch that is not the current checkout (a second worktree, or `git push origin local:remote-name`) is scanned against the wrong tree entirely, not merely a stale one |
| When `keel` is not on PATH, the hook runs `tests/supply-chain-scan.sh` from the repository being pushed, i.e. the branch under review supplies its own checker | `elif [ -x tests/supply-chain-scan.sh ]; then` in `bin/keel` at `f0b6d44` | A branch that weakens or deletes rules from its own copy of the scanner (the file this same push is publishing) is judged by the weakened copy, not by a fixed external standard. The profile-loosening check above has no equivalent rule for this file, since it only diffs `.keel/profile.json` |
| When `keel` is on PATH, the hook prefers it over the repository's own scanner, and that `keel`'s scan command runs the scanner bundled with *that* installation, not the one in the repository being pushed | `if command -v keel >/dev/null 2>&1; then` in `bin/keel` at `f0b6d44` orders `SCAN="keel scan"` ahead of the `tests/supply-chain-scan.sh` branch; `bin/keel#cmd_scan() {` runs `"$SCANNER" "$@"` where `SCANNER` is set from `$HERE`, itself derived from the running binary's own install location (`HERE="$(cd "$(dirname "$SELF")/.." && pwd)"`), not the pushed repository's path | An older globally-installed `keel` plugin on PATH is preferred over a repository's own, possibly newer, `tests/supply-chain-scan.sh`, so a rule added to this repository's scanner after that global install does not run against this repository's own pushes until the global copy is upgraded |
| CI scans only pull requests and `main`, after the push | `.github/workflows/ci.yml:3-6` | A branch push with no pull request is never scanned server-side, and nothing server-side runs before the content is on the remote. The hook is the only check at the moment of exposure |

## Open questions

1. ~~**Which scanner runs when the pushed tree carries a different `tests/supply-chain-scan.sh` from
   the one keel ships: the installed keel's, the pushed tree's, or both with the stricter result?**~~
   **Answered 2026-09-27 by Bernard, asked as a choice: the installed keel's only.** A branch can
   never weaken its own check. The cost, accepted with it: in keel's own repository, a scanner rule
   added on a branch does not guard that branch's pushes until the installed keel carries it.

## Recommendation

Build something smaller: point the pre-push scan at the content of the commits being pushed, which
the hook already reads off stdin for the loosening check, and stop falling back to the pushed
tree's own scanner: the installed keel's scanner is the only one that runs. The hook is the only
check at the moment a secret becomes public, so it should check what is being published. Next is
`write-plan`.

## Not decided here

How the pushed content is materialised for the scanner, how a deleted ref or a first push is
treated, and whether the same change applies to the commit guard's view of the profile.
