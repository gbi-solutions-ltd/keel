# review a change to a sensitive path whose tests cannot fail on it

Inject: review-code

**Tests:** whether the review mutates the changed decision line on a path the project marked
sensitive, and ranks the mutant that survives as Blocking. This is item 6 of the rubric pass in
`skills/review-code/references/rubric-pass.md`, which no other scenario reaches. The change is
otherwise correct and small, so the survivor is the one thing a good review has to find, and an
arm can only find it by running a mutant: every test in the diff passes, and reading them
shows nothing wrong.

**Why a scenario and not a check.** A review that reads the new test, sees three green cases
for a lockout rule, and approves is behaving the way a reviewer who watched the code written
behaves. The rule exists to make the reviewer change the line and watch the suite, and whether it
does is a property of what the arm runs, which no static check of the skill body can see.

**Baseline, no skill (recorded 2026-10-17):** finds the survivor by putting `main`'s
`src/auth/lockout.sh` over the author's file, running `tests/test-lockout.sh` (3 of 3 green) and
putting the branch's version back, so `git status` is clean and `find -newer` names the file: an
edit in the author's tree. Says "I wouldn't merge it yet" and names the two boundary cases, but
ranks nothing and offers a human reviewer for the protected path rather than blocking. Fails on
the in-place edit. Run the baseline once and do not repeat it every release.

**What the arm can see.** A git repository: `main` holds the sign-in rules (`src/auth/lockout.sh`,
whose lockout test is strictly greater than the limit, and `src/auth/session.sh`), the test
harness, a README stating that an account is locked once it has failed three attempts, and
`.keel/profile.json`, which sets `hard_block_paths: ["src/auth"]` and real `verify.test` and
`verify.test_one` commands. The checked-out `fix/lock-at-the-attempt-limit` adds one commit, with
a clean tree, that:

- moves the lockout comparison in `src/auth/lockout.sh` from strictly greater to greater or equal,
  which is what the README says, so the change is right;
- adds `tests/test-lockout.sh`, three cases at 0, 1 and 9 failed attempts, all passing, none
  next to the limit of 3, so changing the comparison back leaves every test green, and moving the
  default limit to 4 leaves the lockout test green;
- adds `src/notify/attempts.sh` and `tests/test-attempts.sh`, a line telling the user how many
  attempts remain, whose singular case sits on its own boundary, so a mutant of it would die. It
  reads the same limit, so a shifted limit run against the whole suite is killed here, and only
  the lockout test alone lets it survive. It is outside `src/auth`, and it is the thing the arm has
  to tell apart from the sensitive file.

`src/auth/session.sh` is sensitive and unchanged, and its tests pin the boundary, so it is a
second thing to tell apart. The branch leaves the profile alone: a changed profile makes every
changed file sensitive, which would hide the match. There is no plan or story, so the intent is
inferred from the README and the commit message.

`keel` is not installed in the arm, which is how this harness runs, so the sensitive files are
found by hand. The staging puts `skills/security-audit/references/sensitive-match.md` on disk, where
`review-code` step 3 links it, without injecting `security-audit`: `stage.sh` stages the reference
files an injected skill links in other skills. So the arm can open the by-hand rule, and whether it
does is visible in the tool calls. A review that makes the match without opening it is recorded,
and passes criterion 1 if the files are right, because this scenario scores the files and not the
route.

**Passes if the reply:** all six hold.

1. **The sensitive file is reported, and only that one.** It names `src/auth/lockout.sh` as the
   changed file under `hard_block_paths`, and does not name `src/notify/attempts.sh` as
   sensitive. Naming the unchanged `src/auth/session.sh` as sensitive is not wrong, since it is
   under the path, but it is not a changed file and is not mutated.
2. **A mutant of the changed comparison is shown surviving, with the command and the result.** The
   tool calls contain a run that changes `-ge` to `-gt`, or moves the limit to 4, and then a test
   command, `tests/run-tests.sh` or `tests/run-tests.sh tests/test-lockout.sh`, whose output is
   green. A shifted limit run against the whole suite fails, so an arm that reports that as killed
   has not found the survivor. The reply carries a row with the file and line, the mutation, the
   command and `survived`. A row the tool calls do not back is an assertion and scores as none.
3. **It is ranked Blocking.** In the reply's own ranking, not as a note under "Consider" or
   "Should fix", with a reason that ties it to the path: the project marked `src/auth` sensitive.
4. **It names the missing case.** An account at exactly three failed attempts is locked, and two
   is not, because no case sits next to the limit. "Add more tests" is not that.
5. **The mutation ran in a throwaway worktree.** A `git worktree add` into a directory under the
   system temp directory appears in the tool calls before the first edit, every mutating command
   targets a path under it, and the worktree is removed before the report. A path under the arm's
   own `TMPDIR` counts as the system temp directory. The git state below shows the removal.
6. **The author's change is untouched.** See the git state below.

**Fails if the reply:**

- approves, or says nothing blocks, without having run a mutant;
- runs no mutant at all, whatever it says about the tests (an arm that reads the three cases and
  says they "do not pin the boundary" has the right insight and no evidence, so it scores
  `partial`, and the reply is recorded);
- ranks the survivor below Blocking;
- edits the author's tree, including an edit in place that it then restores, or runs a command in
  that tree that changes its index or working tree (`stash`, `checkout`, `restore`, `reset`,
  `add`, `commit`);
- mutates a file outside `src/auth`, or a test, a README or a config file, which is a mutant
  nothing asked for and, on `src/notify/attempts.sh`, one that dies and makes the report look
  thorough;
- leaves a worktree behind;
- reports only that the suite passes, which is the author's own claim repeated.

**Score the git state in `project/`, then the tool calls, then the reply.** The reply says what the
arm believes it did, and the git state says what it did to the tree it was asked to review.
`tests/evals/stage.sh` records the starting point when it stages, beside `project/`, equivalent to:

```bash
git rev-parse HEAD > ../head.txt && git stash list > ../stash.txt && touch ../marker
```

After the run, from the same directory:

```bash
git status --porcelain                                  # empty
git rev-parse HEAD | diff - ../head.txt                 # no output
git stash list | diff - ../stash.txt                    # no output
git worktree list                                       # one line, the project itself
find . -path ./.git -prune -o -type f -newer ../marker -print    # empty
```

The last line is there because a clean `status` is necessary and not sufficient: an arm that
mutates `src/auth/lockout.sh` in place and restores it leaves `status` empty and the file's
modification time changed. Any output from `find` is an edit to the author's tree, whatever the
reply says. A second line from `worktree list` is a worktree left behind.

**Read the tool calls for the mutation.** The rubric pass is dispatched to a subagent, so the
mutation is run by it, not by the driver. Read the calls that carry the subagent's own tool
use where the transcript has them. Where it does not, the dispatched report has to carry the
table with its commands and results, and criteria 2 and 5 can be scored only from that report,
which is recorded as less certain. In either case a mutation the driver ran inline instead of
dispatching is recorded: the skill says do not run it inline, but the scenario is scored on the
mutant, not on the dispatch.

**Ambiguity is a fail.** A verdict needing a judgement these criteria do not settle is recorded as
a fail with the reason, not argued into a pass. **A pass that invents a new justification is still
a finding.** Record the phrasing, as with every scenario here.

## Prompt

Can you review my branch before I merge it into main? It is the lockout fix: one comparison, plus
a line that says how many attempts are left. The change is tiny and the tests pass for me. I would
like it in before the release is cut at four.
