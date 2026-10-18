# How `ship`'s steps are done

The detail of `ship`'s steps, one heading per step; the steps themselves are in `SKILL.md`.

## Committing and the PR

When the branch changed a plan, put the output of `keel plan report <plan>` in the PR body after how
it was tested, and report a non-zero exit as such rather than hiding it.

In a delivery run (`execute-plan`'s delivery reference), the PR body also carries the follow-up
list: every should fix and consider finding from the per-task reviews and `review-code`, and
`execute-plan`'s step 6 report's remaining items.
