# README structure

Adapted from `cursor-starter/documentation/readme-generator.md`. Ordered by what a reader needs
first, which is not what the author finds most interesting.

## The order

1. **Name and one sentence.** What it is. Someone should decide in ten seconds whether to keep
   reading.
2. **What it does, in a paragraph.** The problem it solves and who uses it. For a service, say
   whether its callers are people or machines.
3. **Status, if it is not simply "working".** Mid-migration, deprecated, or unsafe to deploy from
   the default branch. This belongs above the setup instructions, not in a footnote.
4. **Stack.** Languages, framework, datastores, with versions.
5. **Running it locally.** The verified path. See below.
6. **Commands.** Test, lint, build, run, each copied from the profile.
7. **Architecture, briefly**, with a link to the real document rather than a summary that drifts.
8. **Conventions that will surprise someone.** Non-standard naming, a deliberate oddity, a shape
   that must not be tidied.
9. **Where the rest of the docs are.**

## Running it locally

The section most often wrong, and the one a new joiner hits first.

- Every prerequisite with a version, including the ones you have had installed for two years.
- Commands in order, copy-pasteable, no placeholders like `<your-value>` without saying where to
  get it.
- What "it worked" looks like: a port, a log line, a URL returning something.
- **Every command executed on a clean checkout before it is written down.**

If a step needs a credential nobody outside the team can get, say so plainly rather than letting
someone discover it at step four.

## What not to include

- A feature list that duplicates the PRD.
- Prose restating what the code says.
- A badge that is not checked. A broken build badge is worse than none.
- An architecture summary that will drift from the architecture doc. Link instead.
- Anything that changes weekly. It will be stale and it will make everything near it suspect.

## The template README

A GitLab or GitHub default template left in place is a finding, not a placeholder. Found on a
production payment service where the entire operational documentation lived in a `CLAUDE.md`
instead, so no human reader ever found it. If the README is a template, it is documenting nothing
and should be treated as absent.
