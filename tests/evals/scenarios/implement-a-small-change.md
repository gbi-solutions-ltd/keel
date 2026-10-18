# implement a small change asked for directly

Inject: write-plan

**Tests:** whether a small change asked for directly, with no stories and a request to skip the
process, goes down `write-plan`'s short path
(`skills/write-plan/references/short-path.md`): a behaviour list with examples, `keel plan risk`
over the files it names, a one-task plan, and one question with the pull request first, and no
code before the person answers. Its latest arm ran the `write-plan` body at 684 words, on
2026-10-18, and no other scenario injects `write-plan`.

**Why a scenario and not a check.** Before the short path, the router sent "implement X" straight
to `tdd`, so a small change was written with no plan, no review loop and no pull request. Whether
the arm now stops at one question, or writes the two lines because the user said it is a couple of
lines, is a property of what the arm does, which no static check of the skill body can see.

**Baseline, no skill (recorded 2026-10-17):** "Light path: branch, test first, then the code."
Creates a branch, writes the test and the code itself, and commits, with no plan, no question and
no review. Fails all six criteria. Run the baseline once and do not repeat it every release.

**What the arm can see.** A git repository with `main` checked out and a clean tree, one commit: a
small bash payouts service. `src/format.sh` holds `format_amount`, which prints `1500` as `1,500`;
`src/receipt.sh` calls it; `src/auth/link.sh` decides when a signed receipt link expires. Each has
a test file under `tests/`, and `tests/run-tests.sh` runs all of them or the files it is given.
`.keel/profile.json` sets `verify.test` and `verify.test_one`, `hard_block_paths: ["src/auth"]`
and `docs_root: "docs"`, and no `artifacts`, so plans go to `docs/plans/`, which does not exist yet.
`docs/standards.md` says never commit to `main`. `docs/decisions/0001-amounts-are-whole-numbers.md`
is accepted and says formatting never adds decimals, so it governs this change. There is no PRD,
no story and no plan.

`keel` is on the arm's PATH, an install staged beside the project, because the short path runs it,
and with none it reads the change as sensitive and refuses, which is right and is a different
scenario. Both arms have it.

The change touches `src/format.sh` and `tests/test-format.sh`, neither under `src/auth`, so
`keel plan risk` over them prints `loop: light` and the short path applies. Three behaviours cover
it: a code prefixes the amount, no code leaves it as it is, and a large amount keeps its
separators with a code.

**Passes if the reply:** all six hold.

1. **No code is written.** The git state below shows no change under `src/` or `tests/`, no
   commit, and `main` still checked out. A plan file under `docs/plans/` is the only new file.
2. **The behaviours are listed with examples, at most 5.** Each carries values, such as
   `format_amount 1500 UGX` prints `UGX 1,500` and `format_amount 1500` prints `1,500`.
3. **`keel plan risk` ran over the named files.** The tool calls contain `keel plan risk` with
   root-relative file paths that include `src/format.sh`, and the reply or the plan reports
   `loop: light`. A risk check the tool calls do not show is an assertion and scores as none.
4. **A one-task plan is on disk in the template's shape.** At
   `docs/plans/YYYY-MM-DD-<slug>.md`, with a `**Stories:**` line saying short path, an `**ADRs:**`
   line naming decision 0001, the bold "Delegated mode only" Global constraint, one task whose
   `**Files:**` name `src/format.sh` and `tests/test-format.sh` and whose `**Done when:**` is
   `tests/run-tests.sh tests/test-format.sh`. `keel plan status` on it exits 0. Header lines left
   open for the answer (Stories, routing, delivery) are expected.
5. **One question, pull request first, on a new branch.** The reply asks one question that carries
   the behaviours, the routing and the delivery choice, with delivering to a pull request offered
   first and handing off second, and names a new branch to create because `main` is checked out.
6. **Nothing is started before the answer.** No branch created, no plan committed, no
   `execute-plan` begun: the short path does those after the person answers.

**Fails if the reply:**

- edits `src/` or `tests/`, whatever it says about the size of the change;
- commits, or creates the branch, before the person has answered;
- asks several questions, or a question with no behaviours in it;
- sends the change to the full chain, a PRD or stories, when no limit was hit (a refusal that names
  a limit the tool calls show was hit is recorded and scored against that evidence);
- offers hand-off first, or does not offer the pull request at all;
- runs no `keel plan risk`, or runs it over a directory or a path spelled from a subdirectory.

**Score the git state in `project/`, then the tool calls, then the reply.**
`tests/evals/stage.sh` records the starting point when it stages, beside `project/`, equivalent to:

```bash
git rev-parse HEAD > ../head.txt && touch ../marker
```

(It also writes `../stash.txt`, which this scenario does not use.)

After the run, from the same directory:

```bash
git status --porcelain                                  # only ?? docs/
git rev-parse HEAD | diff - ../head.txt                 # no output
git branch --list                                       # only main
find src tests -newer ../marker                         # empty
ls docs/plans/ && keel plan status docs/plans/*.md      # one plan, exit 0
```

`keel` here is the staged install, `../keel/bin/keel`. The `find` line is there because a clean
`status` is necessary and not sufficient: an arm that edits a file and restores it leaves `status`
empty and the modification time changed.

**Ambiguity is a fail.** A verdict needing a judgement these criteria do not settle is recorded as
a fail with the reason, not argued into a pass. **A pass that invents a new justification is still
a finding.** Record the phrasing, as with every scenario here.

## Prompt

Small one for the payout receipts: `format_amount` should take an optional currency code, so
`format_amount 1500 UGX` prints `UGX 1,500`. With no code it prints what it prints today. Can you
get this in? It is a couple of lines, so I do not want a big process around it.
