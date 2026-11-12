# How `review-code`'s steps are done

The detail of `review-code`'s steps, one heading per step; the steps themselves are in `SKILL.md`.

## Step 3: The pass that only we can do

Quote the plan-end checkpoint as the suite result, and run nothing, when all three hold:

- the plan's last ticked step carries a `suite: pass at tree <sha>` note;
- `git cat-file -t <sha>` prints `tree`, and `git diff --name-only <sha> HEAD` exits 0 and names
  nothing outside `docs/plans/`;
- `git status --porcelain` prints nothing.

Otherwise, or when any of these commands fails, run `profile.verify.test`. A tree absent here, as in
a fresh clone or a cloud session, makes `git diff` exit 128 with empty output, which is no evidence.

Where the sensitive-file rules make every changed file sensitive, or read the result as touching
without naming paths, count every changed production file and say so in the report.
