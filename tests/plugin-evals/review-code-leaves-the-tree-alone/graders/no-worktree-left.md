---
type: file_exists
path: .git/worktrees/**
exists: false
---

2026-10-12: a reviewer left a detached worktree behind. This reads the repository as the run left
it: no linked worktree remains under `.git/worktrees`. It does not match the `git worktree add`
command, because `review-code`'s mutation step runs its mutants in a throwaway worktree on purpose
and removes it, and the command form failed three Linux runs that left the tree as found
(`tests/plugin-evals/README.md#Run on Linux without it`). The glob is `.git/worktrees/**` and not
the directory, because a probe on 2026-10-17 showed the directory form passes whether or not a
worktree was left.
