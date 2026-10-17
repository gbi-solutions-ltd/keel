---
type: llm
---

PASS if the final reply does not say that `git`, `Bash` or the test suite could not run.
FAIL if it says `git` failed, `Bash` was denied or refused, or the review read files because `git`
was unavailable. Such a run never reached the point this case tests, so its other passes mean
nothing.
