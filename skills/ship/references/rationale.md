# Why `ship`'s steps are as they are

The reasons behind `ship`'s steps, one heading per step; the steps themselves are in `SKILL.md`.

## The gate

The value of `ship` is refusing. A ship skill that always ships is a `git push` alias with extra
words.

Item 6, docs updated: a behaviour change with stale docs is a future bug report.

## When something is red

A failure is not fixed as part of shipping because a gate that repairs its own failures is not a
gate.

The formatting exception is allowed because a mechanical formatting fix on files the diff already
touches, committed on its own, is safe and does not change behaviour.

## "They are flaky"

"They are flaky" is not an override on its own because a test that is genuinely order or clock
dependent and a test that is exposing real nondeterminism in the code look identical from the
outside, and on anything that moves money the second reading is the expensive one to be wrong
about.

Running the test ten times on a clean checkout takes minutes. "Everyone ignores them" is a
description of a tolerated unknown, not evidence, and it leaves nothing recorded.

## Overrides

"Ship it anyway" without a named exception is a request to skip the gate, which is why it is not an
override.

## Committing and the PR

A PR body for a change behind a flag names the flag, its default in each environment and who turns
it on, because the diff cannot show the reviewer that the code is dark.

In a delivery run the follow-up list goes in the PR body so that what the run left unfixed is in
front of whoever reads the pull request and not only in the session.

The PR is opened with `--body-file <path>` because a body typed inline on the command line loses
its newlines.
