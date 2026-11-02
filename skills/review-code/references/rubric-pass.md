# The rubric pass brief

Dispatch this once per review, after step 2 and before step 4. Model `inherit`, and the dispatch's
description starts `inherit: `. This pass judges whether another agent's work is right, which is the
work least worth making cheaper, and a description with no routing label is ambiguous between
inherited and forgotten. `docs/standards.md`, "A dispatch names its model, and says so", has the
rule.

Dispatch it as agent type `keel-reviewer`, keeping the `inherit: ` description. A hook,
`hooks/review-guard`, refuses that agent type the git commands that would change the author's tree,
and the hook sees the agent type, not the description. Where the agent type does not exist, in a
session without the plugin, dispatch a general agent with the same brief; the prompt below states
the git rules, so they hold without the hook.

## Why a dispatch and not a section of the skill

A reviewer that wrote the code, or watched it being written, is anchored on it: it reads what it
meant rather than what is there.
[../../write-plan/references/plan-review.md](../../write-plan/references/plan-review.md) makes the
same argument for plans. No instance of it is on record for code review, so this brief rests on the
argument and not on a measurement. The rubric is also 2,574 words the driver does not need to load,
so the brief hands the subagent a path to it and the driver never reads it.

## What the driver must hand over

A subagent starts cold, so a brief that names none of these makes it guess:

- the diff, as a command with the base resolved, and not "the changes": `git diff <base>...HEAD`
  for committed work, or `git diff <base>` where the change is not committed yet;
- the plan or story path, or the intent you inferred in step 1 where there is none;
- the path to `<docs_root>/standards.md`, and the decisions directory: `artifacts.decisions` in
  `.keel/profile.json`, else `<docs_root>/decisions/`;
- the result of the suite run you made in step 3, quoted, so the reviewer does not run a suite of
  minutes a second time;
- the test command for the revert check: `verify.test_one` from `.keel/profile.json` with its
  placeholders (`{path}` or `{name}`) filled for the added test file or case, else `verify.test`;
- the sensitive files step 3 found, one path per line, or `none`, so the reviewer mutates the
  files the project marked and does not choose them;
- `verify.test_one` with its placeholder left unfilled, since item 6 runs a different covering test
  for each mutant and only the reviewer knows which; else `verify.test`;
- on a re-review, the last round's survivors, as the table rows that reported them;
- the absolute path to `rubric.md`: the path you read this brief from, with `rubric-pass.md`
  replaced by `rubric.md`. A relative path does not resolve from the repository the subagent works
  in.

## The prompt

```
Review a change against this project's own rules. You are not the author and did not watch it being
written: read what is there.

=== CHANGE ===
Diff: <the git diff command, with the base resolved>
Intent: <the plan or story path, or the intent the driver inferred>

=== PROJECT ===
Standards: <path to standards.md>
Decisions: <the decisions directory>
Suite result, run by the driver: <quoted output>
Test command for item 5 below: <verify.test_one, else verify.test>
Sensitive paths: <the files, or none>
Test command for item 6 below, placeholder unfilled: <verify.test_one, else verify.test>
Survivors from the last round, on a re-review: <the table rows, or none>

=== RUBRIC ===
Read <absolute path to rubric.md> in full and answer its checks against the diff. The links in the
rubric are relative to the rubric's own directory, so resolve them from there and not from the
repository you work in. The suite has already run and its result is above: do not run it again,
except through item 5's revert check or item 6's mutants where only `verify.test` exists. Those run
the whole suite, which takes minutes each time. A failing or missing suite is itself a finding.

Also answer these six, which the rubric does not cover. Read the plan, the decisions and the
standards first.

1. Does the diff match the plan? Anything implemented that no task asked for is unplanned scope.
   Anything a task asked for and is absent is an incomplete claim. Where the plan lists behaviours,
   does every behaviour's example have a case named for it? For a task with no test, quote the line
   of the diff, or the check output, that produces it.
2. Does every changed line trace to the request? Adjacent improvements, reformatting and drive-by
   refactoring belong in their own change.
3. Were the tests written first? A test committed after its implementation never ran red, so it is
   unproven until item 5's revert check. Commit order shows this across commits; within one commit,
   only the revert check can.
4. Does it contradict an accepted decision? Look in the decisions directory above, and if it is
   empty look for a decision log before concluding there are none.
5. Has any test in the diff been proved able to fail? A case nobody watched go red is unproven.
   Revert the line it covers, run the test command above, restore it. A suite that cannot fail is
   a finding.
6. Does every changed decision line on a sensitive path have a test that can fail on it? These are
   the paths a mistake costs most on, and a test that cannot fail on a changed guard is no evidence.
   For each changed decision line in a file under `Sensitive paths` that is production code, make
   one mutant in item 5's throwaway worktree (create it as below if item 5 made none), run the
   covering test, record killed or survived, and restore the line before the next mutant. On a
   re-review run the last round's survivors first: each must now die. A decision line the fix adds
   gets its own mutant.
   - Production code is a file some test runs. Tests, docs, `*.json`, `*.yml`, `*.yaml` and `*.toml`
     are not: list each as unchecked, with the reason "no test runs it". On keel's own list, for
     example, `hooks/*` counts; `settings.json`, `.github/workflows` and `templates/ci-review.yml`
     do not.
   - A decision line is a condition, comparison, guard, early return, boolean operator or boundary
     constant. Mutants: shell `[ "$n" -ge 3 ]` to `-gt`, `|| exit 1` removed, a `case` arm removed;
     awk `NR > 1` to `NR > 2`; Python `if a and b` to `or`; TypeScript `===` to `!==`, `??` removed.
   - The covering test is the test file the diff changed for that source, else the one named after
     it (`tests/test-<name>.sh`, `test_<name>.py`, `<name>.test.ts`), run with the item 6 test
     command above with its placeholder filled; else `verify.test`.
   - Make at most 10 mutants, in diff order, and at most 3 where only `verify.test` can run them,
     because each then costs a whole suite run. Name every decision line you left unchecked. Those
     are reported, not findings, so the cap never becomes a block.
   - With `Sensitive paths: none`, say `not applicable: no hard_block_paths path changed`.
   A surviving mutant is Blocking: name the line, the mutation and the case that would kill it,
   because nothing in the suite observes that line's behaviour on a path the project marked
   sensitive. A row `| src/auth/session.ts:42 | >= to > | npm test -- session.test.ts | survived |`
   becomes the finding "no case pins a session expiring exactly at its limit".

Do item 5's revert and item 6's mutants in a throwaway worktree, never in the working tree: the
author's tree is not yours to change, and another reviewer may be reading it. Create it with
`git worktree add --detach <path> HEAD`, where `<path>` is a new directory under the system temp
directory, named for this review alone: `review-<short commit>-<four letters you choose>`, never a
fixed name, because two reviews on one machine would share it and one would change the other's tree.
Look up the short commit first and write the name out in full. If the path exists, choose other
letters; never reuse or remove a worktree you did not create. Write `<path>` as
`"${TMPDIR:-/tmp}/<name>"` or a literal path under the temp directory, because a hook
refuses a target it cannot resolve, such as one held in `"$wt"`, and `TMPDIR` is often unset on
Linux. If the change is not committed, apply it there with `git diff HEAD | git -C <path> apply`,
but skip that when `git diff HEAD` is empty (only new files changed): `apply` rejects empty input,
and a failed step must not stop the copy that follows. Then copy in the untracked files, from the
repository root:
`git ls-files -z --others --exclude-standard | tar --null -T - -cf - | tar -xf - -C <path>`.
`git diff` lists no untracked file, and item 6 must be able to mutate a new file on a sensitive
path. Remove it with `git worktree remove --force <path>` after item 6 and before you report,
whatever the outcome, and say that you did. The revert and the mutants leave it modified, so a plain
remove would refuse. If a test cannot run there, say that the revert check or that mutant was not
done and why; do not do it in the working tree.

Do not edit the change. Say what is wrong and let the author fix it. Run no git command that
changes the author's index, working tree or stash: no `stash`, `checkout`, `restore`, `reset`,
`commit`, or `git add` of a file. Read the change with `diff`, `log`, `show` and `status`. Your own
worktree's files are yours to change, but its stash is the author's, since every worktree of a
repository shares one: run no `stash` there either. On 2026-10-12 one reviewer ran `git stash` on
the tree under review and put the stash back, and another left a worktree behind; the next may not
clean up. Where you run as `keel-reviewer`, a hook enforces these git rules by refusing the
command; they are stated here because they hold where no hook does. If it
refuses one, report the step you could not do rather than look for another way to run it.

Rank each finding, by these meanings and no others:
- Blocking: wrong behaviour, a security defect, data loss, or an unmet requirement. Must fix before
  merge.
- Should fix: will cost real time later, or violates a standard. A finding from a rubric bullet that
  names a coding-standards reference (`observability.md`, `resilience.md` and the like) violates a
  standard, so it is Should fix at least: the ship gate counts it only at that rank.
- Consider: a genuine preference. Say it once.
Each has a `file:line`, what is wrong, why it matters and what to do. If nothing blocks, say so in
the first line and name what you checked. Cap at around ten.

Report item 6 as a table, so the evidence is read and not asserted: one row per mutant, then the
unchecked lines with their reasons.

| file:line | mutation | command | killed or survived |
|---|---|---|---|
```

## Why item 6 mutates, and how far

Verify RED shows that a test the author wrote can fail. It does not show that a test already in the
suite can fail on a line this diff changed, and on a path the project marked sensitive that is the
claim worth checking. Item 6 closes it the way
[../../tdd/references/writing-good-tests.md](../../tdd/references/writing-good-tests.md), "Proving a
case can fail, after the fact", describes: one line reverted, the covering test run, the line
restored. The 10-mutant cap and the report-not-block rule for unchecked lines keep the cost bounded,
so a large diff on a sensitive path costs a stated amount of review and never an unreviewable one.
It runs once, in the final review, where the whole change is in view; the per-task reviews inside
`execute-plan` do not run it.

## Reading the result

The findings go into step 4's ranking as they are. Where the `code-review` plugin also ran, you are
the only one who has seen both sets of findings, so you are the one who spots a conflict. A conflict
is a stated disagreement about a cited line. Where there is one, this pass's finding governs: it has
read the plan, the decisions and the standards, which the plugin's generic reviewers have not. Keep
this pass's finding in the ranking and list the plugin's beside it, marked overridden and with its
location, so the author sees both. A clean result here does not clear a plugin finding, because
silence is not a conflict.
[../../keel/references/reporting-findings.md](../../keel/references/reporting-findings.md) carries
the reason behind the ranking, cap and first-line rules the prompt above states.
