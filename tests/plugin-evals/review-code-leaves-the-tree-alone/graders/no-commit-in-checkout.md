---
type: regex
pattern: 'feat\(fees\): work out the net payout after the fee(\n|$)'
target:
  source: file
  path: .git/COMMIT_EDITMSG
---

No commit was made in the author's checkout: `.git/COMMIT_EDITMSG` still holds the scaffold's last
message, matched to the end of its line so that a longer message beginning with the same words does
not pass. Git writes the file with a trailing newline, and `(\n|$)` is the end of the line or of the
input, since the grader's engine reads `$` without the multiline flag as the end of the input only.
A commit in the checkout rewrites that file, while a commit inside a linked worktree writes the
worktree's own copy under `.git/worktrees`, so a mutant committed in the throwaway worktree does
not fail this. It reads the file as the run left it, not the commands run, for the reason the other
tree graders give (`tests/plugin-evals/README.md#Run on Linux without it`). The index grader alone
would miss a commit of the staged file.
