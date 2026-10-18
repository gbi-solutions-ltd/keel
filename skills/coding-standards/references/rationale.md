# Why `coding-standards`'s steps are as they are

The reasons behind `coding-standards`'s steps. The steps themselves are in [SKILL.md](../SKILL.md).

## Step 2: Split mechanical from judgement

Anything in the first pile that ends up in prose will be ignored within a month, because nobody
re-reads a style guide. Anything in the second pile put into a linter produces false positives
that teach people to disable the linter.

## Step 3: Wire the mechanical pile

Fix what new rules flag in the same commit, because a linter landing with 400 warnings is a linter
everyone learns to ignore.

Prefer a check-only command for gates, because a `lint` script that mutates cannot serve as a CI
gate.

Never widen or drop a rule whose violations cannot be fixed now, because the suppression is what
keeps anything new failing.

## Step 4: Write the judgement pile

Every entry carries a reason and an example, because a rule with no reason gets argued about and a
rule with no example gets misread.

## Step 5: Verify and report

The lint command must pass on the current codebase, or you have shipped a broken gate.
