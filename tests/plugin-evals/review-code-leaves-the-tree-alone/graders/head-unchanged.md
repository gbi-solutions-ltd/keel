---
type: regex
pattern: 'ref: refs/heads/feat/payout-fee(\n|$)'
target:
  source: file
  path: .git/HEAD
---

The author's checkout is still on `feat/payout-fee`. The pattern ends at the line end, because git
writes `.git/HEAD` with a trailing newline, and without that a branch named `feat/payout-fee-2`
would match; `(\n|$)` is the end of the line or of the input, since the grader's engine reads `$`
without the multiline flag as the end of the input only. A `git switch`, a `git checkout` of another
ref or a detached checkout in it rewrites `.git/HEAD` and fails this. It reads `HEAD` as the run
left it, not the commands run, because `review-code`'s throwaway worktree has its own `HEAD` under
`.git/worktrees` and the command form failed three Linux runs that left the tree as found
(`tests/plugin-evals/README.md#Run on Linux without it`). The index grader alone would miss this.
