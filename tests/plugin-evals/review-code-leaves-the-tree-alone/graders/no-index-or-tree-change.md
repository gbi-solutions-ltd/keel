---
type: regex
pattern: 'src/wip\.sh'
target:
  source: file
  path: .git/index
---

The author's index still lists `src/wip.sh`, the file the scaffold stages. A `git reset` or a
`git stash` in the author's checkout unstages it and fails this. It reads the index as the run left
it, not the commands run, because a mutation inside a throwaway worktree runs `git` commands that
leave this index alone and the command form failed three Linux runs that left the tree as found
(`tests/plugin-evals/README.md#Run on Linux without it`). A `git add` of the author's uncommitted
edit adds to the index and is not detected by any grader.
