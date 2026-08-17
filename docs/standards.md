# Coding standards: keel

| | |
|---|---|
| Derived from | All 9 skills, 3 scripts, and 3 templates, at commit `2e698ff` |
| Date | 2026-08-11 |
| Enforced by | `tests/run-tests.sh`, which runs `tests/validate-skills.sh`, `tests/no-internal-leaks.sh`, `tests/supply-chain-scan.sh`, and `shellcheck` from the profile |
| Departures from GBi defaults | Listed in the last section |

> Anything a linter can check is not in this file, by design. If you find a formatting rule here,
> move it into `tests/validate-skills.sh` and delete it from here.

## Already mechanical

These are checked by `tests/validate-skills.sh`, so they are not conventions you need to
remember. Listed only so you know what you are covered for:

frontmatter has `name` and `description`; the description starts with "Use when" and is under 260
characters; the body is within the 900 word ceiling, and warns over the 700 target; no `@` links;
no hardcoded `docs/keel` path
in a skill or template; no `{{DOCS_ROOT}}` in a skill; relative links resolve; no em or en dashes.

Each of those rules exists because it was broken during development, usually by whoever had just
written it. That is why they are enforced rather than documented.

---

## Skills are markdown, and the body is a budget

**Rule:** a skill body targets 700 words. 900 is a hard ceiling. `tests/validate-skills.sh` fails
at the ceiling and warns over the target, and a body over the target needs a passing eval arm at
that length in `tests/evals/results.md`. See `docs/decisions/ADR-0001-skill-body-word-ceiling.md`.

**Why:** the body loads on every invocation, so length has a real per-use cost, and a long enough
body gets skimmed rather than followed. The previous numbers were 400 and 600 under a hard 700, and
they failed in a specific way worth remembering: the targets were documented and unchecked while
the ceiling was enforced, so bodies went where the check was. By 2026-08-16 no skill met 400, four
were under 600, and fifteen of 24 sat within 20 words of the ceiling. **A ceiling with no enforced
number under it is not a limit, it is where bodies settle.**

**Example:** `skills/coding-standards/SKILL.md` is the case that shows moving detail out has a
floor: 12 reference files carrying 17,816 words, and a body still at 683. Reach for a reference
because a reader needs it at one step, not as a way to buy words.

## Subagent briefs stay in the body; everything else can move

**Rule:** detail belongs in `references/`, except a brief the skill dispatches to a subagent.

**Why:** a brief in a reference file is one the model may not have loaded at the moment it builds
the dispatch. Progressive disclosure is right for reading and wrong for constructing a call.

**Example:** `skills/repo-snapshot/SKILL.md` keeps its agent table inline and moves the eleven
output sections to `references/section-templates.md`.

## A check is never stricter than correct output

**Rule:** when a mechanical check disagrees with output you believe is correct, the check is wrong
until proven otherwise. Fix it, then pin the case in `tests/test-validate-skills.sh`.

**Why:** five times during development a proxy rule rejected valid work. Too loose misses a
defect; too strict teaches people to ignore checks, which is unrecoverable.

**Example:** `tests/test-validate-skills.sh` carries two must-not-reject cases: prose naming the
default docs root, and a template comment doing the same. See `docs/02-skill-catalog.md`.

## Prose wraps at 100 columns; tables do not

**Rule:** wrap prose at 100. Leave table rows and code blocks on one line however long.

**Why:** wrapped tables are unreadable in raw markdown, and this repository is read raw more often
than rendered.

**Example:** the longest line in `skills/` is 227 characters and is a table row. No prose line
exceeds 100.

## Every rule carries its reason, and its reason is usually a scar

**Rule:** a rule in a skill states why, preferably naming the failure that produced it.

**Why:** an unexplained rule gets relitigated or rationalised away under pressure, which is
exactly when it matters. A rule attached to a real failure survives.

**Example:** the coverage figure rule in `repo-snapshot` records that a committed report said
1.94% where the truth was 23.29%. The number is what makes the rule stick.

## Tests are bash, and the validator has its own tests

**Rule:** no test framework, no runtime dependency. A script that validates the repo gets tests
proving it catches what it claims.

**Why:** the CLI must run on any machine with no install step, so its tests must too. And a
validator that silently passes everything is worse than none.

**Example:** `tests/validate-skills.sh` is checked by `tests/test-validate-skills.sh`, 34 cases,
including both directions.

## Evidence about the tooling comes from the tooling, not from the shell around it

**Rule:** when a result is evidence about what keel does, take it from the command itself. Use
`/usr/bin/grep` or `bash -c` rather than bare `grep`, use absolute paths in a background shell, read
the log rather than the exit line, and let a slow command finish before calling it hung.

**Why:** each of the three below produced a confident wrong answer, and a wrong answer about your
own tooling is worse than no answer, because it gets acted on. None of them is a bug in keel and
none can be linted, which is why they live here.

**Example, the shell's `grep` is not the one keel runs.** It resolves to a wrapper function from the
author's zsh snapshot. It reported `detect_datastores` returning nothing on a repository where it
correctly returns postgres and redis, which read as a real defect. It has since also failed on glob
handling for `--include` where `/usr/bin/grep` would not.

**Example, a background shell does not start in the repository.** `tests/run-tests.sh` launched from
one begins in the parent directory. Two runs reported `SUITE EXIT: 0` having never executed, because
`echo "SUITE EXIT: $?"` reported the status of the `echo` and masked the 127.

**Example, `keel doctor` here takes about 11 minutes and is silent for most of it.** It runs every
`verify` command, and `verify.test` is the whole suite, which itself invokes `keel doctor` against
generated fixtures. It prints nothing between `verify.test_one is set` and the suite finishing, and
`ps` is misleading in both directions because the `( eval "$c" )` subshell inherits doctor's own
command line. It was killed twice on 2026-08-16 in the belief it had hung, then completed on its own
with exit 0.

The suite on its own measured 473 seconds on 2026-08-16 and is variable: an earlier run the same
afternoon was still in the supply chain cases when a ten minute limit killed it. Give both a
generous allowance and run them in the background rather than against a default timeout, because a
run cut short at the timeout looks exactly like a failure and is not one.

## Documentation lands with the change, not after

**Rule:** a skill is not done until `README.md`, `CHANGELOG.md`, and the plan are updated in the
same commit.

**Why:** a status line claiming 3 of 19 when 5 exist makes every other claim in the file
suspect.

**Example:** every `feat(skill):` commit in this repository touches those three files.

## Shipped prose states the current state, and history lives in the changelog

**Rule:** a skill, reference, template, or document under `docs/` describes what is true now. No
past-tense narration of the work, no sentence explaining why something is *not* the case, no
rejected option described by what happened to it. When feedback shows a section is wrong, delete it
and write it again from the code rather than amending the sentence that carried the wrong claim.
`CHANGELOG.md` holds the history, and a superseding ADR holds a reversed decision.

**Why:** a skill is read by an agent mid-task with a decision to make, and it is loaded on every
invocation forever. A sentence that only makes sense to someone who saw the review has to be decoded
before it can be used. A rule stating the failure that produced it is a different thing and stays:
that scar is what the reader acts on.

**Example:** `skills/write-docs/references/current-state-prose.md` carries the tells and the
rewrites; section 8 of `skills/review-code/references/rubric.md` checks for them in a diff.

---

## Examples use generic names, never a real one

**Rule:** an example in a skill, reference, or template uses an obviously generic name.
`payments-api`, "a partner bank", `PROD-042-requirements.md`. Never a client, a partner, a real
repository, or a developer's absolute path.

**Why:** this plugin installs into every project. A reader who meets a real client name in a skill
assumes it means something to keel, and spends time working out what. It also discloses who we
work with, in a repository that may not stay private.

**Example:** `tests/no-internal-leaks.sh` enforces it and found eight of my own leaks on its first
run, including a client's document identifiers sitting in the profile example that ships to every
project.

## The leak scanner only catches what it has been told about

**Rule:** work that touches a client system adds that client's identifiers to the `DENY` list in
`tests/no-internal-leaks.sh`, with a sample in `SAMPLES` in `tests/test-no-leaks.sh`, **in the same
commit as the work**. Names, schemas, hosts, repository names, and the business vocabulary that
identifies them without naming them.

**Why:** the scanner is a denylist. It is silent about every identifier nobody has entered, so it is
at its weakest exactly when it is most needed: the first commit after meeting a new client, when
their names are fresh in the working tree and in the agent's context. Building `apex-export` put a
workspace schema, a hosting provider and two co-tenant schemas into this repository's orbit, and the
scanner passed the whole time because it had never heard of any of them.

**How it is enforced.** Two halves, and only one is mechanical:

- **Rot is mechanical.** `tests/test-no-leaks.sh` asks the scanner for its patterns via
  `--list-patterns`, runs it over a file containing a sample of every one, and fails if any pattern
  never fires. A hand written regex that stops matching after a rename cannot go unnoticed, and a
  new `DENY` entry with no sample fails immediately. `tests/run-tests.sh` runs this, and CI runs
  `tests/run-tests.sh`.
- **Absence is not.** No test can know about a client nobody has written down. That step is
  judgement, it belongs to whoever did the work, and it is why this rule is written here rather than
  left to the suite.

**Note on the denylist as disclosure.** Adding a name records that we met them. The header of
`tests/no-internal-leaks.sh` already carries the plan for this: before the repository is ever made
public, move `DENY` into a file outside the tree and have the script read it, falling back to the
generic path and document-identifier patterns when it is absent. Adding entries raises the cost of
skipping that step; it does not change the plan.

## A denylist ships with the test that proves every rule still fires

**Rule:** a scanner built from hand-written patterns (`tests/no-internal-leaks.sh`,
`tests/supply-chain-scan.sh`) exposes its rule ids, and its test runs a sample of every one through
it and fails when any never fires.

**Why:** a denylist that matches nothing still reports OK, and still counts the dead rules in its
total. Nothing else notices. This is not hypothetical here: two supply chain rules were written with
an empty regex alternative, `(ba|z|k|)sh`, which GNU grep accepts and this machine's grep rejects
outright. Both matched nothing, the scan said clean, and the summary said 19 rules. The coverage
test is the only reason it was found.

**Example:** `tests/test-supply-chain.sh` compares `--list-rules` against the ids that fired over a
fixture containing a sample of each. `tests/supply-chain-scan.sh` additionally refuses to start when
any rule fails to compile, so the same class of failure is now loud rather than caught on a good day.

## An exception to a scanner is written on the line, with its reason

**Rule:** where a scanner is wrong about a specific line, append `supply-chain-scan: allow <reason>`
to that line. Never widen a pattern, and never add a file to the skip list, to make one line pass.

**Why:** widening a rule to accommodate one exception silently stops catching the real thing
everywhere else, and a skip list hides a whole file from every rule at once. A per-line suppression
is visible in the diff that introduces it, is printed on every run afterwards, and is counted in the
summary, so growth is something a reviewer sees rather than discovers.

**Example:** three suppressions exist, all in `tests/test-keel.sh`, where the tests that prove the
push guard rejects a pipe-to-shell must contain a pipe-to-shell. A suppression with no reason is
itself a finding.

## One definition per verify command

**Rule:** a verify command is defined once, in `.keel/profile.json`, and both the local runner and
CI read it from there. Never restate it in a workflow file.

**Why:** restating guarantees drift, because only one copy gets updated. The lint step here ran
`shellcheck` in CI and `shellcheck -S warning` locally, so CI failed on 52 findings nobody had seen.
The first instinct on that is to distrust the pipeline.

**Example:** `.github/workflows/ci.yml` reads `verify.lint` with `jq`; `tests/run-tests.sh` reads the
same field. Changing the severity now changes both.

## Review

Either Bernard Tebandeke or Edrine Kamya reviews a skill change; both are not required. **No skill
change is merged by its own author unreviewed**, which is the property the two-reviewer rule exists
to guarantee. A skill affects every repository with the plugin installed, so it is not a solo
change even when it is a one-line change.

## Departures from GBi defaults

| Default | This project | Why |
|---|---|---|
| Strict type checking on | Not applicable | No typed language here. Skills are markdown, scripts are bash |
| A bug fix ships with a test that reproduced it | Applies to `tests/`, not to skills | A skill's equivalent is a behavioural eval, which needs the Phase 6 harness. Recorded as a real gap in `CHANGELOG.md` |
| Migrations forward-only | Not applicable | No database |
| Scripts are bash, and `python3` is optional | `keel apex-export` requires `python3` and fails loudly without it | The work is parsing megabytes of JSON out of a database client, intersecting a wanted column list against a live catalog, and writing a file tree. Every bash version of that is a worse version of what the standard library already does. A half working export is worse than none, because the artifact's whole value is that an agent trusts what it reads. `apex_missing_deps` in `lib/apex-export.sh` names what is missing rather than degrading |
| The managed CLAUDE.md block meets its 450-token target | This repository's block is about 634 tokens, over the target and under the 700 ceiling | See below. Recorded 2026-08-16 under plan task 7.5 |

The eval gap is temporary and has an end condition, tracked in `CHANGELOG.md`. The `python3`
departure is permanent and scoped to one command; nothing else in `bin/keel` gained a hard
dependency.

**The block departure, and why it is a departure rather than a new target.** Task 7.5 offered two
moves: trim the block to 450, or record the overrun. Closing a 184-token gap means removing about a
quarter of the block, and the block is rules end to end with no summary prose to cut, so a trim of
that size deletes a rule rather than words. Neither pilot showed a rule in it as unearned. Raising
the target to 628 so the warning stops is the move the rule below forbids, which leaves this.

**Its end condition:** the block is over target because it carries two rules as prose that nothing
enforces, the per-edit lint rule and the documentation gate. When either becomes a check, its prose
comes out and the block is re-measured against 450. Until then `keel doctor` warns on every run, the
700 ceiling still fails, and the figure is re-measured at each release rather than assumed. A block
that grows past 700 is not covered by this departure.

**This repository branches and reviews like any other.** Work goes on a branch, lands through a
pull request, and `ship`'s check 8 applies here with no exception. Every commit on `main` arrives as
a merge.

## The renderer is pure, and that is a testable property

**Rule:** `lib/apex_render.py` never opens a connection or spawns a process. All I/O lives in
`lib/apex_export.py`.

**Why:** it is what lets `tests/test-apex-export.sh` drive the entire rendering path from a
committed capture fixture with no Oracle instance anywhere. Thirty three cases run in CI on a
runner that has never seen a database.

**Example:** the test asserts the property directly, by grepping `apex_render.py` for `subprocess`
and `run_sqlcl`. Without that case the split erodes on the first convenient import and the offline
suite quietly stops proving anything about a live run.

## A gate is never weakened so this repository can pass it

**Rule:** where keel's own gate refuses this repository, the repository changes or the refusal is
recorded as a departure with an end condition. The gate does not move.

**Why:** every gate here is also advice given to every project with the plugin installed. A check
relaxed so its author can ship is worth nothing to the next reader, who has no way to tell which
rules were meant and which were negotiated. This is the one rule that keeps the rest honest, and it
is why the departures table above exists at all rather than being quietly empty.

## A dispatch names its model, and says so

**Rule:** a skill that dispatches a subagent names the model at the dispatch site and announces it
in one line. Wide mechanical reading goes to `sonnet`. Anything writing code under a gate, or
judging another agent's verdict, stays `inherit`. No brief names a full model id, and none names
`haiku` yet. `tests/validate-skills.sh` rejects any alias Claude Code does not accept.

**Why:** a session's model cannot be changed by a plugin, a hook, or the model itself. Checked
2026-08-16 against the Claude Code hooks documentation: no hook event exposes model selection. So
delegation is the only routing available, and it is not free, because a subagent starts cold and
re-reads context the main thread already holds. The payoff therefore depends on the work being
**long and mechanical**, not on it being **simple**, which is why nothing here keys on guessed
complexity: a router that did would be wrong in the direction nobody notices, since a cheap model
doing a poor job produces plausible output rather than an error.

`haiku` waits on one measured comparison, recorded as open question 3 in
`docs/ideas/model-routing.md`. Full model ids are excluded because an id pinned in a skill goes
stale with nothing to notice, while an alias tracks the current model. The announcement costs
nothing and was asked for directly.

**Where the words came from.** `repo-snapshot` and `port-assess` had one and three words of
headroom under ADR-0001's 700-word warning, so the dispatch sentences were tightened to fit the pin
rather than the pin being dropped or the ceiling crossed. The announcement clause survives in full
only in the two skills that had room and in
`skills/execute-plan/references/subagent-prompts.md`; this section is what the other two point at.
