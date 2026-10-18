# Why `write-prd`'s steps are as they are

The reasons behind `write-prd`'s steps. The steps themselves are in [`SKILL.md`](../SKILL.md).

## Step 1: Pick the mode and gather inputs

Check `profile.artifacts.prd` before choosing `from-idea`, because a second PRD beside a mature one
makes the repo worse.

Run `keel:repo-snapshot` first in `from-repo` when there is no snapshot, because
reverse-engineering requirements from an unread codebase produces confident fiction.

Write one PRD per coherent product surface, because a document spanning several surfaces is
approved by nobody.

## Step 2: Ask, one question per message

In `from-repo`, ask only what code cannot answer, because the snapshot has the rest.

Step 3 runs in the middle of this step because the questions worth asking are the ambiguities
classification turns up.

## Step 3: Separate observed from required

This step is `from-repo` only, and it is the point of the mode.

Never promote an accident to a requirement: a PRD asserting the system must do what it currently
does by mistake is worse than no PRD, because the next engineer will defend it.

## Step 4: Write it

`FR-NN`, `NFR-NN` and `CON-NN` IDs and their statuses are structural, not decoration:
`write-user-stories` traces to them and `write-plan` proves coverage against them.

## Step 5: Self-review, then gate

Name the `inferred`, `disputed` and `author-added` requirements plainly, because those are what the
user is really being asked to rule on.

Surface open questions as choices, because a question buried in section 13 goes unanswered, while
the same question as a choice gets settled in seconds.

## Common mistakes

Mark invented requirements `author-added` and count them, because the no-invention rules cover
numbers, not features.
