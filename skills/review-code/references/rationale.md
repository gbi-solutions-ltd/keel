# Why `review-code`'s steps are as they are

The reasons behind `review-code`'s steps; the steps themselves are in [SKILL.md](../SKILL.md).

## Overview

A review that lists thirty things gets ignored, which is why the core principle is to rank
ruthlessly and say which findings block.

## Step 1: Establish what the change was meant to do

A review without the intent is proofreading.

## Step 2: Delegate to the plugin if it is there

The `code-review` plugin's multi-agent confidence scoring catches more than one inline read, which
is why its findings are the correctness pass when it is installed.

Step 3 runs either way, because a generic reviewer does not know this project's intent.

## Step 3: The pass that only we can do

The driver runs `profile.verify.test` itself because `keel:tdd` runs it once at a unit boundary,
and may run only the affected tests, so review is where the suite result is established rather than
inherited.

The sensitive files are found by the command and not taken from the conversation, because a
sentence in chat is not a decision, and `keel plan risk` is what the review loop already uses.

Where the match makes every changed file sensitive, or the result is read as touching without
naming paths, the report counts every changed production file, since item 6 mutates only
production code.

The pass is dispatched and not run inline because a reviewer that watched the code being written
is anchored on it.

The sixth check mutates every changed decision line on a sensitive path because those paths cost
most when a mistake lands.

Where step 2's plugin ran, this pass settles a conflict because it has read the plan, the
decisions and the standards.

## Step 5: Report

The re-review dispatches step 3's pass again with the last round's item 6 survivors because a fix
for a survivor is a new test whose power to fail is the whole point.

In a delivery run that `execute-plan` started, `ship` follows the review because the person chose
the pull request as the gate when they approved the plan.
