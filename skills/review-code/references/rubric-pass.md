# The rubric pass brief

Dispatch this once per review, after step 2 and before step 4. Model `inherit`, and the dispatch's
description starts `inherit: `. This pass judges whether another agent's work is right, which is the
work least worth making cheaper, and a description with no routing label is ambiguous between
inherited and forgotten. `docs/standards.md`, "A dispatch names its model, and says so", has the
rule.

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

=== RUBRIC ===
Read <absolute path to rubric.md> in full and answer its checks against the diff. The links in the
rubric are relative to the rubric's own directory, so resolve them from there and not from the
repository you work in. The suite has already run and its result is above: do not run it again,
except through item 5's revert check where only `verify.test` exists. That runs the whole suite,
which takes minutes each time. A failing or missing suite is itself a finding.

Also answer these five, which the rubric does not cover. Read the plan, the decisions and the
standards first.

1. Does the diff match the plan? Anything implemented that no task asked for is unplanned scope.
   Anything a task asked for and is absent is an incomplete claim.
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

Do item 5's revert in a throwaway worktree, never in the working tree: the author's tree is not
yours to change, and another reviewer may be reading it. Create it with
`git worktree add --detach <path> HEAD`, where `<path>` is a new directory under the system temp
directory. If the change is not committed, apply it there with
`git diff HEAD | git -C <path> apply`. Remove it with `git worktree remove --force <path>` before
you report, whatever the outcome, and say that you did. The revert leaves it modified, so a plain
remove would refuse. If the test cannot run there, say that the revert check was not done and why;
do not do it in the working tree.

Do not edit the change. Say what is wrong and let the author fix it. Run no git command that
changes the author's index, working tree or stash: no `stash`, `checkout`, `restore`, `reset`,
`commit`, or `git add` of a file. Read the change with `diff`, `log`, `show` and `status`. Your own
worktree's files are yours to change, but its stash is the author's, since every worktree of a
repository shares one: run no `stash` there either. On 2026-10-12 one reviewer ran `git stash` on
the tree under review and put the stash back, and another left a worktree behind; the next may not
clean up.

Rank each finding, by these meanings and no others:
- Blocking: wrong behaviour, a security defect, data loss, or an unmet requirement. Must fix before
  merge.
- Should fix: will cost real time later, or violates a standard. A finding from a rubric bullet that
  names a coding-standards reference (`observability.md`, `resilience.md` and the like) violates a
  standard, so it is Should fix at least: the ship gate counts it only at that rank.
- Consider: a genuine preference. Say it once.
Each has a `file:line`, what is wrong, why it matters and what to do. If nothing blocks, say so in
the first line and name what you checked. Cap at around ten.
```

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
