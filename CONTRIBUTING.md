# Contributing to keel

A skill change affects every repository with the plugin installed. That is the reason for most of
what follows.

## Before anything

```
tests/run-tests.sh
```

Free, no dependencies, about four and a half minutes. Run it in the background and read the last
line. It runs the skill validator, the CLI suite, the leak scanner, the documented-claims check, and
the same lint CI runs. If it is red before you start, fix that first or you will not know what you
broke.

## Adding or changing a skill

**Use the `create-skill` skill.** It is not ceremony; it encodes the order that makes the difference.

1. **Check nothing already covers it.** Overlapping skills are worse than a missing one: the router
   picks arbitrarily and neither gets improved. "No new skill, improve the existing one" is a common
   and correct outcome.
2. **Baseline first.** Run the scenario against a subagent **without** the skill, and record how it
   fails, quoting the reasoning it used. Those quotes become the skill's content. A rationalisation
   table built from real excuses closes real loopholes; one you imagined closes imaginary ones.
3. **Match the form to the failure.** A prohibition fixes a discipline failure and measurably
   backfires on a wrong-shaped output, which needs a positive recipe instead.
4. **Write the minimum** that addresses what you observed.
5. **Re-run.** It will usually comply while finding a new way around the edge. Add that, repeat.
6. **Add an eval** under `tests/evals/scenarios/` if the skill enforces discipline. That is the only
   thing that tests whether it changes behaviour under pressure.

Skipping the baseline is the same mistake as writing a test after the code: you get something that
passes and proves nothing.

## The rules the validator enforces

You do not need to remember these; `tests/validate-skills.sh` will tell you. Listed so you know what
you are covered for.

- `description` starts with "Use when" and states **triggering conditions only**, never the workflow.
  A description that summarises the process becomes a shortcut the model takes instead of reading the
  body.
- Body within 700 words, which is the target rather than the ceiling: ADR-0001 allows up to 900, and
  anything over 700 requires a passing eval arm at that length recorded in `tests/evals/results.md`.
  **An arm discharges the length it was run at, not the body it was run against**, so a body that
  grows past the length of its last passing arm owes a new one. A gate arm counts, per ADR-0001's
  clarification of 2026-09-04. Six bodies carry a passing arm at their current length:
  `coding-standards` 795 (2026-09-03), `write-docs` 756 (2026-09-02), `context-budget` 723
  (2026-09-02) and `write-prd` 793 (2026-08-30) on dedicated length arms, and `tdd` 793 and
  `execute-plan` 884 on the 0.17.0 release gate of 2026-09-01, all in `tests/evals/results.md`.
  Assume 700 is the limit unless you are willing to run one. Aim at 400 for one linear path, 600
  when it fans out to subagents or carries modes.
- No `@` links. They force-load at parse time and burn context before it is needed.
- No literal `docs/keel`. Skills use `<docs_root>` and read `profile.docs_root`; templates use
  `{{DOCS_ROOT}}`.
- Relative links resolve, in reference files as well as in skill bodies.
- No em or en dashes.
- Every router destination in `skills/keel` exists, appears in `templates/prompting-cheatsheet.md`,
  and is named in `hooks/session-start`. The last two were added after both had already drifted: a
  skill absent from the cheatsheet is one no user learns to ask for, and one absent from the
  injection is one the model will not think of unless it is named.
- The SessionStart injection stays under 400 tokens. It is in the prefix of every request.
- No client name, partner name, specific repository name, or developer path. Examples use
  `payments-api`, "a partner bank", `PROD-042-requirements.md`.
- A model named on a brief is one of `sonnet`, `opus`, `haiku`, `fable` or `inherit`, written as
  `` model `<alias>` ``. A brief pointing at an alias that does not exist fails silently at dispatch
  time, which is the worst way for it to fail.
- The `description` frontmatter of every skill, summed, stays under 1,320 tokens. That sum is in the
  prefix of every request in every keel project, and 1,320 is 30 skills at the measured mean, which
  is the count decision 6 says to revisit before rather than after.
- `skills/repo-snapshot`'s section 10 requires a `security-audit --full` item, a `coding-standards`
  item, and a line saying what the snapshot did not check. A snapshot that omits all three reads as a
  clean bill of health, which is the one thing it must never accidentally be.
- `templates/profile.schema.json` cannot change shape without `SCHEMA_VERSION` moving, because
  `doctor` compares the version and not the fields, so a silent schema change is one it stays quiet
  about.
- **Shipped content names no organisation.** Nothing under `skills/`, `templates/` or
  `output-styles/` carries the house's own name; say "the house defaults" or "a service following
  the observability standard" instead. `tests/no-internal-leaks.sh` enforces it, so publishing stays
  a deletion rather than an audit.
- **Client and partner identifiers are not in this repository.** `tests/no-internal-leaks.sh` loads
  them from `KEEL_DENY_FILE`, defaulting to `~/.config/keel/internal-deny-list.txt`, and prints on
  every run whether it found one. Without it the generic patterns still run: an absent list degrades
  the scan, it does not silence it. Ask a maintainer for the file. The list left the tree because it
  was the one place that enumerated who we work with, and it has to contain the names in order to
  search for them.
- **Documentation obeys the writing rules too.** Anything under `docs/` or at the repository root is
  checked for em and en dashes and for relative links that resolve, so a plan or an ADR is held to
  what a skill is held to. Links inside fenced code blocks are skipped, because a plan quotes the
  markdown it is telling you to write elsewhere, and the docs-root rule is not applied to prose: a
  skill writes `<docs_root>`, but a document explaining the default layout has to name it.

## What goes in the body, and what moves

**Body:** the decisions, the gates, the ordering, and any brief you dispatch to a subagent. A brief
in a reference file is one the model may not have loaded at the moment it builds the dispatch.

**References:** checklists, templates, worked examples, long tables. Unbounded in length.

## Every rule states its reason

A rule with no reason gets rationalised away under pressure, which is exactly when it matters. The
best reasons name a real failure:

> Numbers come from commands, not from committed reports, because a committed report said 1.94%
> statement coverage where the truth was 23.29%.

That survives an argument. "Be accurate" does not.

**This is not automated, deliberately.** A check for "does this rule state a reason" is a proxy for a
judgement, and the proxy was wrong three times on one file during development. A reviewer checks it.

## When a check disagrees with you

**Assume the check is wrong until proven otherwise.** Ten times during development a mechanical rule
rejected correct output: a prohibition phrased without "must", a story legitimately titled "upload and
download", a `grep` that was not a verify command, prose naming the default docs root.

Fix the check, then pin the case in the relevant test file as a must-not-reject. The costs are
asymmetric: too loose misses a defect, too strict teaches people to ignore checks, and the second is
unrecoverable.

## Commits and review

- Conventional commits: `type(scope): summary`.
- **No attribution footers.** No `Co-Authored-By`, no robot emoji, no generated-with line.
- No em or en dashes, in the message as well as the code.
- Say *why*, not just what. If a test or a real repository changed your mind, that belongs in the
  message; it is the most valuable thing in the history.
- **Documentation lands in the same commit.** `README.md`, `CHANGELOG.md`, and the plan. A status line
  claiming 3 of 19 when 5 exist makes every other claim suspect.

**Review:** either Bernard Tebandeke or Edrine Kamya, and never the change's own author. Both are not
required; requiring both would stall the tool whenever one is busy, which is how internal tooling
dies.

## Releases

Monthly, tagged, gated by the behavioural evals in `tests/evals/`. Record the results in
`tests/evals/results.md`: which passed, which failed, and the exact rationalisation any failure used.
**A new rationalisation is the most valuable output of a release**, because it goes straight into the
skill's table and closes a loophole nobody had imagined.

## Testing against a real repository

The most useful thing you can do. Every skill here was changed by being run, usually more than once,
and no skill has ever survived its first real repository unaltered.

Use a copy when the skill writes files. During development a probe of mine ran `git init` in a
project as a side effect of a read-only check, which it had no business doing.

## Known gaps

Kept in `CHANGELOG.md` under "Known gaps" and honest about it. If you find another, add it there
rather than to a list of intentions.
