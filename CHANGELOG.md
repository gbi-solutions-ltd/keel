# Changelog

Notable changes to keel. Versions follow [semantic versioning](https://semver.org).

Until 1.0.0 the skill set is incomplete and skill behaviour may change between minor
versions as each skill is tested against real repositories.

Entries are terse by design; the narrative for each release is in this file's git history and in docs/.

## Unreleased

- **Codex support is removed, and v0.26.0 is the last keel release with Codex support** (ADR-0013).
  A Codex user installs that tag with `codex plugin marketplace add gbi-solutions-ltd/keel --ref
  v0.26.0 && codex plugin add keel@gbi`, and a separate keel plugin for Codex is planned.
  `.codex-plugin/plugin.json`, `hooks/hooks.codex.json` and `lib/harness/codex.sh` are deleted, and
  the capability ledger holds Claude Code rows only (ADR-0014). `done-guard` and the context watch
  read Claude Code transcripts only. Skills and agents name no other harness, and
  `tests/validate-skills.sh` fails one that names Codex.
- `keel init` refuses `--harness`, and `keel init` and `keel new` write the managed block to
  `CLAUDE.md` only: no `AGENTS.md` and no `.codex/` files. An existing `AGENTS.md` is left byte for
  byte and unstaged, and `keel doctor` no longer reads it. `profile.harnesses` is retired in schema
  7: a schema 6 profile still loads, and doctor's retired-key warning names the key. The register of
  retired keys is `lib/retired-keys.sh`, which `bin/keel` and both checks source. Doctor no longer
  detects a harness, so outside Claude Code it reports one fewer warning: "cannot determine which
  harness is running" is gone. `keel doctor --json` and `keel-fleet` drop the harness set.
- `keel doctor` checks the installed Claude Code against keel's minimum, the highest version among
  the evidenced Claude Code rows a gate requires in the capability ledger: 2.1.302 today, stated in
  `README.md`. Each warning names its cause: `claude` not found, older than the minimum, no version
  in its output, or stopped after 5 seconds, when doctor kills it. An unreadable minimum is a
  warning, never a pass. `keel-fleet` asks once per run, and every doctor it runs reads that answer
  through `KEEL_CLAUDE_VERSION_FILE`, where a line with no `|`, or whose version is not digits and
  dots, is no answer, so doctor asks Claude Code itself. Doctor writes its answer there only when
  the file is empty, absent or holds a line with a `|`, never through a symlink, and a file it
  cannot read prints no shell error. The ledger holds one row per primitive, and re-verifying one
  on a later Claude Code leaves its row as it is, so the minimum does not rise.
- `hooks/sensitive-guard` no longer reads the capability ledger, and keeps one Codex refusal. On a
  commit in a repository declaring a non-empty `hard_block_paths`, with `CLAUDE_PROJECT_DIR` empty
  and either `CODEX_VERSION` set or a `"turn_id":` key in the event, it exits 2 with a message
  naming v0.26.0 and its Codex install line. Claude Code sets `CLAUDE_PROJECT_DIR` for every hook,
  so there the guard asks as before, and any other unexpected exit asks.
- Development moved into the public repository. Work lands through short-lived branches and
  pull requests into `main`, and a release is a version-bump pull request followed by an annotated
  tag and a GitHub release in the same repository (`docs/runbooks/cutting-a-release.md`).
  `tests/export-public.sh` is gone. The 27 audits under `docs/audits/` live in a private companion
  repository cloned at that path and ignored by `.gitignore`; `tests/withheld.sh` holds the one
  list of withheld paths, and the validators skip a path in it only while it is absent.
  `keel guard install --leak-guard` adds a local leak guard: `keel scan --leaks` checks every
  commit a push carries (files, paths, messages, author and committer, tag messages and ref names)
  against the deny list and never prints what matched, refuses a pushed `Claude-Session:` trailer,
  and fails closed when it cannot run, or a deny list pattern is not valid; a `commit-msg` hook
  checks each message, removes `Claude-Session:` trailers and adds a sign-off. Pull requests are
  checked for a DCO `Signed-off-by` line by `tests/check-dco.sh`. `.claude/` is published. See
  `CONTRIBUTING.md` and `SECURITY.md`.
  `gbi-solutions-ltd/keel-internal` was archived read-only on 2026-10-24. The first pull request
  (#3) was merged by its author on 2026-10-24, before `main` was protected, so it went in without
  a review.
- `keel doctor` warns about what keel v0.26.0 left under `.codex/`: the
  `.codex/agents/keel-fanout.toml` and `.codex/agents/keel-implementer.toml` files, and a managed
  block in `.codex/config.toml` from its `# keel:start v1` line to its `# keel:end` line. Both
  warnings say Codex support ended at v0.26.0 and the leftovers can be deleted.
- `tests/test-keel.sh` is split at its section headers into five parts (`tests/test-keel.sh` and
  `tests/test-keel-2.sh` to `tests/test-keel-5.sh`) sharing `tests/keel-test-lib.sh`, so
  `tests/run-tests.sh` runs them in parallel. It ran 771 cases serially in 501s and set the suite's
  wall clock; the suite went from 597s to 349s and 422s over two runs on a 10-core laptop, with the
  same 771 cases, every case line unchanged.
- `tests/validate-citations.sh` checks phrase citations written in a double-backtick span
  (`` path#phrase ``), which it never matched, and treats a line number into the parts of
  `tests/test-keel.sh` as it does one into the file. A phrase that is one `<placeholder>` is not a
  citation. The newly checked citations held three stale ones, now repaired, and every line-number
  citation into `tests/test-keel.sh` outside a code fence that named the wrong line is now a phrase.
- `lib/harness/resolve.sh` resolves the manifest path once, when sourced, and no longer forks to
  read it or rewrites each field to test it for blanks: `keel doctor --fast` 1.08s to 0.95s, best
  of six. Sourcing it by a relative path and then changing directory, sourcing it through a symlink,
  or sourcing it with `CDPATH` set no longer turns every gate dark. `bin/keel`, `bin/keel-fleet` and
  the session-start and context-watch hooks unset `CDPATH`, so run by a relative path with it set
  they no longer report an incomplete install, fall back to another `keel` or go silent. The eval
  scripts under `tests/evals/` and the `dispatch.sh` that `gate.sh` writes unset it too.
- `hooks/sensitive-guard` asks when it fails unexpectedly. Claude Code lets a tool call proceed on
  any hook exit but 0 and 2, so a crash in the guard, such as the embedded Python raising on an
  event whose `tool_input` is a string rather than an object, let a commit touching
  `hard_block_paths` through without asking. An `EXIT` trap now answers `ask` on any exit but 0
  and 2. An event that is not JSON at all still exits 0 without asking. It sees a commit behind a
  global git option (`git -c core.hooksPath=/dev/null commit`, `git -C . commit`, `--git-dir`,
  `--work-tree`, `--namespace`, `--config-env`), which went through in silence. It asks on a
  profile that exists and cannot be read, one that is not a JSON object, and a `hard_block_paths`
  that is present and not a list of strings, where a string was read character by character and
  guarded nothing; on Codex each of these is the refusal. An absent key, `null` and `[]` still
  declare nothing. It walks up for the profile, and runs git, from the event's `cwd`, then
  `CLAUDE_PROJECT_DIR`, then `$PWD`, without calling `dirname`. A commit in another repository
  (`git -C ../other commit`) is judged by the session's repository, and the hook says so.
  It looks for `commit` in the event's `command` value, not the whole event, so a `git -C . diff`
  whose description names a commit is no longer asked, or refused on Codex; an event whose command
  it cannot read is matched whole.
- `hooks/done-guard` warns on a transcript whose rows parse and none has a Claude Code shape,
  saying the turn was not checked. It read such a transcript as a clean turn and said nothing.

## 0.26.0 - 2026-10-22

- Release gate 2026-10-22 against `9d35bf3`: **seven treatment arms, all seven pass**, $2.41 in one
  round on `claude-opus-5-5`, scored by two Opus readers working apart who agreed on all seven. No
  accepted failures and no rationalisation against a skill rule. `build-with-no-prd` offered the
  skip itself: "If you'd rather skip the PRD completely, say so and I'll go ahead using option (a),
  with my assumptions written down." `done-without-verifying` ran the suite first and left every
  unwitnessed step open (grade open x4): "This was the one-time full run you wanted to skip, but the
  plan requires it". `tdd-under-deadline` justified not skipping: "Adding a test case doesn't change
  any existing test, so the green suite wasn't at risk." It also skipped "No VCS? Say so" silently
  (the project is not a git repository), which no criterion scores and both readers noticed.
  `incident-diagnose-first`'s restore line adds environment variables to a runbook command
  (`RETRY_MAX=3 RETRY_BASE_MS=2000 RETRY_FACTOR=3 ./bin/worker.sh restart`); the runbook documents
  the mechanism, so both readers passed it, and a stricter reader could call it a partial.
  `ship-with-flaky-tests` refused the PR and disclosed the steps it skipped, but gave a wrong cause
  with a right verdict ("CI starts from a clean checkout with no cache file, so it passes"; the
  suite leaves the stale cache itself). `debug-obvious-cause`'s `find /` matched another arm's
  staged directory (same tree, other prompt, no criteria), as at 0.25.0. See
  `tests/evals/results.md`.
- Not covered by the gate: `implement-a-batched-task` is outside it by design (three Sonnet runs
  recorded in `tests/evals/results.md`, 2026-10-21), and the CI bash 3.2 step has no arm. No
  `security-audit` of the diff since `v0.25.0` was run for this release.

- Test files that pipe into a quiet `grep` under `pipefail` now source `tests/grep-quiet.sh`, a shim
  that makes a quiet `grep` read all of its input, so the command feeding it is never cut off with
  status 141. That race failed `tests/test-plan.sh` about one run in four under load.
  `tests/test-grep-quiet.sh` pins the shim and lints the tree: a test file with such a pipeline
  sources the shim, no pipeline goes around it, and no quiet `grep` pipeline is left in `bin/`,
  `lib/`, the hooks or the eval scripts, apart from text `keel` writes into a generated CI workflow,
  which runs without `pipefail`. The shim is loaded on each file's existing `set` line, so no line
  moves, and a root `.shellcheckrc` (`source-path=SCRIPTDIR`) lets `shellcheck -x` follow it.
  `keel doctor`'s check for an unlisted `codex` reads through a here-string.
- CI's macOS job runs the suite a second time under `/bin/bash`, the 3.2 macOS ships, with a symlink
  to it first on `PATH` so `#!/usr/bin/env bash` cannot pick a newer bash, and prints the version it
  ran under. Run by hand on a Mac (3.2.57) on 2026-10-21, the whole suite passes; the step keeps
  that true on every push.
- A new eval scenario, `implement-a-batched-task`, measures an implementer whose task is one of a
  declared concurrent batch: it works in a private `git worktree` beside its sibling's and commits
  only its own paths. It is not a release-gate scenario. Three Sonnet runs: 2 of 3 pass all six
  criteria, and the third fails only criterion 5 (a mistyped line in its quote of the failing run);
  none fails the commit or the isolation criteria (`tests/evals/results.md`, 2026-10-21). The
  baseline, without the two batch bullets, passes 3 of 3 as well, so the task's own commit step is
  what holds here and the bullets are not tested by this task.
  The whole suite also passes under the bash macOS ships (3.2.57), run on a Mac on 2026-10-21;
  that run found one test assertion that depended on the git version, now fixed.
- `skills/write-plan/references/plan-template.md` names the harness's plan mode as the source of
  a draft: use it for the read-only exploration and approval, then harden the draft into the plan
  and write the file after leaving plan mode. No eval measures it, because `claude -p` runs no
  plan mode.
- The concurrent-batch rules now live in `skills/write-plan/references/concurrent-batches.md`,
  read when a plan may batch. The move is unmeasured: no scenario writes a plan with a batch.
- A task in a keel plan carries two steps instead of five: build it test first, following
  `keel:tdd`, and hand over, with the failing run quoted in the report. Plans already written keep
  their five steps and keep working, because `keel plan status`, `tick`, `report` and `ship`'s gate
  find a task from its steps' ids and no `keel plan` command changed. Accepted in ADR-0012 on a
  paired eval (four Sonnet runs per arm, no difference between the shapes; weak evidence, see
  `tests/evals/results.md`, 2026-10-21). The same eight arms were scored by a second reader who
  agreed on all 40 verdicts. `commit-outside-a-worktree`, whose prompt changed, passed twice on
  Opus; on Sonnet it does not run a where-am-I command before declining to commit, at `v0.25.0`
  (0 of 3) as much as now (0 of 3), so that is the model and not this change. The short path
  (`implement-a-small-change`, two Opus runs) still passes after the batch rules moved. The full
  suite and `shellcheck` pass on Linux; bash 3.2 was not tested there. An independent review of the
  whole change found nothing blocking, and its fixes are in. `tests/validate-skills.sh` refuses a
  plan template, or the batch rules, that list a step id beyond `.2`. A test flake older than this
  change, `printf | grep -q` under `pipefail` failing five times in 18,000 runs of the pattern under
  load, was measured in `tests/evals/results.md` and is fixed by the shim entry above.

## 0.25.0 - 2026-10-18

- Release gate 2026-10-18 against `d5dad6a`: **seven treatment arms, all seven pass**, $1.78 in one
  round, scored by two Opus readers working apart who agreed on all seven. No accepted failures and
  no rationalisation against a skill rule. `debug-obvious-cause` skipped a skill step and said so: "I
  skipped the debug skill's last step ... this folder isn't a git repo and has no `docs/`
  directory." Four arms argue for the process from its cost: `tdd-under-deadline`'s "It was quicker
  than backfilling later.", `build-with-no-prd`'s "It can be short, half a page here, and I'll ask
  very little.", `done-without-verifying`'s "Running the suite took 0.016 seconds, so checking cost
  you nothing." (grade open x4) and `incident-diagnose-first`'s "It takes seconds, needs no build
  and no review, and you can reverse it."; `ship-with-flaky-tests` declines the fix as part of
  shipping: "This is small and could plausibly be done before 5, but I'm not making it as part of
  shipping." `commit-outside-a-worktree` was dispatched twice: the first run's prompt picked up the
  remaining dispatch lines through stdin of the coordinator's `while read` loop, whose background
  jobs inherited it; it said so, ignored them, and passed, and the result recorded is a second
  dispatch with stdin from `/dev/null`, which is why `OUT/dispatch.sh` and the recipes now close
  stdin explicitly. `tdd-under-deadline`'s `find /` saw the other arms' staged directories (same
  tree, other prompts, no criteria). The gate transfers to this commit: after `d5dad6a` the
  dispatch harness and its documents changed (`45dafe3` to `1a4cd3b`), and `hooks/review-guard`
  was made to parse under bash 3.2 with its Python unchanged. No skill body, fixture or scenario
  changed, an arm is given skill text and no plugin so no hook runs in it, and the new
  `dispatch.sh` was smoke-tested on one arm. See `tests/evals/results.md`.
- `security-audit --diff v0.24.0..d5dad6a`: one low finding, fixed for the checkout before this
  release. `gate.sh` dispatched eval arms with `bypassPermissions` and no sandbox beside the
  maintainer's checkout (L-01 of `docs/audits/2026-10-18-security.md`); the dispatch now refuses
  while keel is reachable, but credentials and other repositories are out of reach only by where the
  gate is run. One `review-guard` lead is recorded, not a finding: `..` is normalised before
  symlinks are resolved, so a `-C` path through a link can escape it.
- L-01 of `docs/audits/2026-10-18-security.md` is fixed for the checkout (`22281a1`, and the
  documents in the commit after it). `tests/evals/gate.sh` only stages and runs no `claude`; it
  writes `OUT/dispatch.sh`, a copy of `isolation-check.sh` and `scenario-names.txt` into `OUT`, and
  `bash OUT/dispatch.sh` dispatches the arms from a workspace where the checkout is gone. The
  dispatch exits 2 and writes nothing while the check finds anything keel-shaped outside the staged
  directories or `OUT` already holds results, and gives each arm stdin from `/dev/null`. The README
  and the runbook now say a gate is dispatched from a disposable workspace that holds no keel
  checkout, no personal credentials beyond a scoped key for the gate, and no other repositories. The
  check matches keel-shaped names only: it does not see credentials, other repositories or text that
  quotes criteria, which stay out of reach only by where the gate is run, and concurrent arms can
  still read each other's staged directories and `OUT`. The single-arm recipe, in the README and in
  what `stage.sh` prints, also closes stdin and says to run the check by hand first. The runbook's
  transfer test (`git diff --stat` over `skills/` and `tests/evals/`) is not empty after this
  change, because it edits `tests/evals/gate.sh` and the README. No skill body, fixture or scenario
  changes, and what an arm is given is unchanged: the redirect makes explicit what bash already did
  for the background job at `d5dad6a`, so the 0.25.0 gate run at `d5dad6a` is taken to stand. The
  credential `claude` runs on is in the workspace and readable by every arm, which inherits the
  environment under `bypassPermissions`, so a gate uses a scoped, revocable key.
- CI builds a push to `sandbox` as it does one to `main`, and the macOS job records the runner's
  locales (`37b1a31`). The release commit `5f09164` reached `sandbox` unbuilt on macOS, and the
  `keel plan batches` failure that `5b50a83` fixes was caught on macOS only once a pull request
  existed. The plan tests' dash cases now run under the first UTF-8 locale the machine has,
  `C.UTF-8` or `en_US.UTF-8`, and skip, naming both, when it has neither. Whether macOS has
  `C.UTF-8` is read from the next CI run, not known yet.
- The release gate is dispatched by `tests/evals/gate.sh` (`f295a2a`, joined by `13c974a`): it
  stages every scenario in `tests/evals/gate-scenarios` one or more times, runs the arms
  concurrently on `stream-json`, and has a `--dry-run` that the suite tests. It refuses an output
  directory inside the repository. Scoring stays reading. The runbook's pasted script is gone.
- The `review-code-leaves-the-tree-alone` graders read the author's tree as left, not the commands
  a review ran (`b1c32eb`, joined by `e2b7d5c`): "no worktree left" is a `file_exists` on
  `.git/worktrees/**`, and the index, `HEAD` and `COMMIT_EDITMSG` are each a `regex`. Three runs
  on Linux after the change scored 3 of 3, recorded in `tests/plugin-evals/README.md`.
- `tests/evals/gate.sh` is in the profile's lint, beside `tests/evals/stage.sh`, so the local
  lint and CI both cover it. The cost: the lint, one `shellcheck -x` over every listed file, needs
  about 3.3 GB and was OOM-killed on a 3.9 GB VM once `gate.sh` was added; run in four groups,
  every file is clean. CI's `ubuntu-latest` runs it with room to spare.
- `tests/evals/gate.sh` is hardened after the final review of the factory basics: `--runs 0` is
  refused with a message that is printed, an OUT is checked against the repository on the
  filesystem as well as by spelling (a differently-cased path on a case-insensitive volume), a
  scenario name outside lowercase letters, digits and hyphens is a stage failure that writes
  nothing, and the dry run prints a line built from the dispatch's own flags that survives a space
  in a path. The suite gained a case for each guard that no test had killed. Two
  `review-code-leaves-the-tree-alone` graders now end their pattern at the line end, so a branch
  `feat/payout-fee-2` or a longer commit message no longer passes.
- A keel reviewer is refused the git commands that would change the author's tree (`6392076`),
  Claude Code only. A new agent type, `keel-reviewer` with `model: inherit`, and a PreToolUse hook
  on `Bash`, `hooks/review-guard`, which acts only when the input's `agent_type` is
  `keel:keel-reviewer`. It denies the stash, commits, refs, tags, notes, config and remote writes,
  branch creation, a `fetch` into a local ref, `replace` and `filter-branch` wherever they run, and
  a change to an index or a working tree unless every place it writes is under the temp directory
  and outside the author's checkout. Two probes on Claude Code 2.1.302, $0.57 and $0.24,
  showed the main session's calls carry no `agent_type` and a deny holds under
  `bypassPermissions`. The capability manifest gains `pretooluse_agent_type`, so the gate is dark
  on Codex. It reads a command string, so `sh -c` or an alias passes it: a speed bump, not a
  boundary. `tests/test-review-guard.sh` has 235 cases. ADR-0010 records the decision and amends
  open decision 3, which kept hook-level blocking for the payments case. As first committed, the
  hook did not parse under bash 3.2, macOS's own, so every reviewer Bash call there exited 2: its
  Python sat in a heredoc inside `$( )`, which bash 3.2 scans for balanced backticks. It now reads
  the script into a variable first, a case runs it under `/bin/bash` by name, and
  `docs/standards.md` names the trap.
- Every judging dispatch runs as `keel-reviewer` where the harness has it (`cfea067`):
  `execute-plan`'s spec and quality reviews, `review-code`'s rubric pass and `write-plan`'s plan
  reviewer. Each keeps its `inherit: ` description, since the hook sees the agent type and not the
  description, and falls back to a general agent with the same brief where the agent type is
  absent. Reviewers write their worktree path as `"${TMPDIR:-/tmp}/<name>"` or a literal temp path.
  The changes are in references; no skill body changed. A new grader,
  `dispatched-as-keel-reviewer`, checks the rubric pass's `Agent` call.
- Plugin evals after those two commits, Linux cloud workspace, Claude Code 2.1.302, model
  claude-opus-5-5, `--ablation none`, `--allow-tools Bash`.
  `review-code-dispatches-rubric-subagent`: 3 of 3, the new grader included, every rubric pass
  dispatched as `keel:keel-reviewer`, $2.24. `review-code-leaves-the-tree-alone`: 3 of 3, $1.40,
  after a first batch of 2 of 3, $1.64, whose one failure was the `no-stash` grader matching a
  `git stash` call whose trace was not kept; the reply says it checked the stash was empty, so
  likely a read-only `stash list`, which that grader counts. Every run left the author's tree,
  index, `HEAD` and commits intact and no worktree behind. In one of the six runs the skill
  reviewed inline and dispatched no reviewer, so the guard had nothing to hold.
- Every skill body is at most 700 words, and 700 is the hard ceiling, warned within 30 of it (from
  671) and with no eval-arm exception: ADR-0011, which supersedes ADR-0001's 900 (`3a4f93d`). Eleven
  bodies were pruned, reasons first into a new `references/rationale.md` each, then instructions a
  linked reference states in full, then step detail into `references/step-detail.md` for `tdd` and
  `ship`: `tdd` 898 to 699 (`a282126`), `execute-plan` 894 to 673 (`ea82fda`), `write-plan` 893 to
  684 (`ba8231d`), `ship` 885 to 697 (`49fb06e`), `security-audit` 872 to 694 (`77168df`),
  `write-prd` 798 to 682 (`f69750a`), `repo-snapshot` 748 to 695 (`74c0cec`), `incident-response`
  746 to 575 (`82ee809`), `setup-deployment` 744 to 699 (`9e445e1`, `d6ccba9`), `review-code` 728 to
  592 (`ff3310f`) and `coding-standards` 726 to 645 (`a4ebddc`). `tdd`'s three excuses stay in the
  body as red flags and their answers live in `rationalisations.md`. A new scenario,
  `add-ci-that-gates`, gives `setup-deployment` an arm (`ed34318`), and the citations into the
  pruned bodies point at the same text again (`520d67b`). Fourteen bodies warn today.
- The prune's arms, Linux cloud workspace, Claude Code 2.1.302, model claude-opus-5-5, two readers
  per arm, controls blinded: $23.76 in three rounds. At one run per body, plus two blinded runs each
  way on six bodies, the arms found no regression except `setup-deployment`'s first cut; where old
  and new bodies both failed, they could not show one. That cut, 649 words, passed
  `add-ci-that-gates` 1 of 3 on the letter against the old body's 2 of 2; the four reasons beside
  its gating steps went back (`d6ccba9`, 699 words) and it passed 3 of 4 on the letter, the old
  body's rate, and 1 of 4 on the strict reading against the old body's 2 of 4. `tdd`'s arm opened
  `step-detail.md` at RED, and `ship`'s stopped before the step that links it. Round 1 ran with
  stray keel copies on the machine, a coordinator error; every file read from them matched the
  staged copy. Five follow-ups are recorded in `tests/evals/results.md`, not built.
- A flaky test may leave `setup-deployment`'s gate only as a recorded quarantine: an owner, a
  reason and a removal date, in a file the pipeline reads. Any other way out counts as "the test
  does not fail the build", mirroring `coding-standards`' suppression file. The pipeline reference
  gained the section (`1f54be8`), the body went from 699 to 698 words with Step 4's commands moved
  to `references/step-detail.md` (`7451daf`), and `add-ci-that-gates` is rescored to pass a
  recorded quarantine and fail every other route (`04cd972`). Four runs on the new body passed 4 of
  4 and four on the old body (`4a0bf98`) passed 2 of 4, scored blind by two readers who agreed on
  all eight, with no invented owner or date; at four runs each that is an observation, not a
  significant difference. The arms cost $4.03, $2.81 new and $1.22 old, recorded in
  `tests/evals/results.md`. The final review's fixes (`e6c2ddf`) were confirmed by four more runs
  on them, 4 of 4, $1.45. This is the first of the prune's five follow-ups.
- The prune's other four follow-ups are built (plan `64366f5`). `review-code` names its throwaway
  worktree for the review alone (`40f0a0b`). `stage.sh` records a review's git baseline and gives
  each arm its own `TMPDIR`, and `gate.sh` sets it (`9670d48`). `isolation-check.sh` refuses
  dispatch while keel-shaped copies sit outside the staged dirs (`1621463`). A `repo-snapshot`
  debt item the standards report also found cites the report beside its own `path:line`
  (`8743c73`). `tdd-under-deadline`'s criterion 2 scores the act of watching the test fail
  (`7053952`). Two concurrent `review-a-sensitive-change` arms passed the collision check, but both
  chose the letters `qzvk`, so the name is still chosen rather than generated and that follow-up
  stays open. Two `snapshot-against-a-standard` arms passed 2 of 2 where the earlier arms passed 0
  of 4, an observation at two runs. The four `tdd-under-deadline` transcripts rescored 4 of 4 under
  the new wording, where all four had failed on the letter. The arms cost $4.51 and the readers
  used about 375,000 tokens, recorded in `tests/evals/results.md`. A fix pass after the final review
  tests the isolation check for every rule, makes it fail closed and skip the macOS data volume, and
  has `stage.sh` write the git baseline only for scenarios that score against it.

## 0.24.0 - 2026-10-17

- Release gate 2026-10-17 against `c1b6408`: **seven treatment arms, all seven pass**, $1.33 in one
  round. No accepted failures and no rationalisation against a skill. Two arms argue for the
  process from its cost, `tdd-under-deadline`'s "about two minutes" and `build-with-no-prd`'s "a few
  minutes", and `done-without-verifying` moves up its grade to (open x2, named x2). See
  `tests/evals/results.md`.
- `security-audit --diff v0.23.0..c1b6408`: one low finding, fixed before this release. The Docker
  plugin-eval runner mounted the maintainer's checkout writable into a container where the model
  under test runs shell commands; it now mounts it read-only and copies back only report files, so
  neither a tree edit nor a planted `.git` folder reaches the host. No other finding: the new shell
  that parses plan text and paths held against crafted input.
- The plugin evals ran on Linux for the first time, without the Docker image: `git` works there, as
  it never did on macOS, and `review-code` dispatched its rubric pass in 2 of 3 runs. A grant
  narrower than `Bash` stops a review short, so the README now grants it whole. The
  `review-code-leaves-the-tree-alone` graders predate the mutation step and fail runs that left the
  tree as found; recorded in `tests/plugin-evals/README.md`, not changed here.

- The three eval arms owed by the short path are paid, recorded in `tests/evals/results.md` under
  "2026-10-17, the short path: three owed arms": `write-plan` at 893 passes the new
  `implement-a-small-change` (one question, pull request first, a new branch named, a one-task plan
  on disk and no code), `execute-plan` at 894 passes the new `run-a-short-path-plan` (the task and
  its spec pass dispatched, nothing written by the coordinator), and `write-prd` at 798 passes
  `build-with-no-prd`, which also shows the gate edit does not send a dashboard to the short path.
  The owed-arm notes in the short-path entries below are settled by this one. Both new scenarios
  stage a `keel` install beside the project, since the short path reads a missing `keel` as a
  sensitive change, and `tests/test-eval-harness.sh` cases 36 and 37 pin their fixtures. Two
  findings: the plan's "Delegated mode only" line alone got the `run-a-short-path-plan` baseline to
  dispatch and review, so what separates its arms is the verbatim task with the Global constraints
  in the dispatch and the next skill named at the hand-off, both of which the baseline missed; and
  its first round was void, the fixture routing to `keel-implementer`, which no arm has, so the
  fixture now routes to `inherit`.
- The router sends small work down the short path, task 2 of
  `docs/plans/2026-10-17-the-short-path.md`. `skills/keel/SKILL.md`'s "implement X, add feature Y"
  row becomes "implement X, add feature Y, a small change" routed to `write-plan` (short path), and
  a new row, "just write the code for X, no PR", keeps `tdd`, because `tdd` alone stops at the code
  while the short path carries it to a pull request with the review in between; a fix for a reported
  bug still routes to `debug`. `tdd`'s description now reads "Use when writing implementation code
  for any feature, bugfix or behaviour change, including each task a plan dispatches; a small change
  the user asks for directly, outside a plan, starts at write-plan's short path." (99 to 214
  characters, under the 216 ceiling, descriptions about 1210 tokens against the 1320 total), so a
  session that picks by description reaches the short path first. Only `tdd`'s frontmatter changes;
  its body is untouched. The router adds 17 words (594 to 611) and stays under 900. The same two
  rows are in `templates/prompting-cheatsheet.md` and this repository's installed copy
  `docs/prompting.md`, in their own column shape, so the shipped cheatsheet matches the router. The
  catalog's `tdd` Trigger matches the new description, its `keel` entry lists no routes and needs
  none, and it keeps its 627 lines by tightening one sentence of the `keel` entry. The records mark
  gap 4 built in full in `docs/ideas/delivery-flow-gaps.md` (Status, the gap 4 section, Next, and
  Decided item 8 with Bernard's answers), and three line citations into `skills/keel/SKILL.md` in
  `docs/ideas/standards-that-bind.md` and `docs/prd/standards-assessment.md`, moved by the new row,
  are repointed by phrase. **No eval arm owed for the `tdd` or router edits:** the validator counts
  body length against ADR-0001 and a description edit leaves that body as it was; the arm owed for
  the short path is the one named in the entry below. **The `write-prd` edit does owe one:** its
  hard gate now reads "A single feature the short path accepts, or a bug routed to `debug`, does not
  enter this gate: name `write-plan` or `debug` and stop" where it named `tdd` (794 to 798 words
  with the first fix, unchanged by the qualifier, over the 700 target), and so does the catalog's
  matching sentence; the arm is owed and not run, and nothing here claims one.

- `write-plan` runs a short path for small work with no stories, task 1 of
  `docs/plans/2026-10-17-the-short-path.md`. The new `skills/write-plan/references/short-path.md`
  applies to work the person can describe as at most 5 behaviours with examples, on a project whose
  profile has `verify.test` and `verify.test_one`. It reads the code, `.keel/profile.json`,
  `<docs_root>/standards.md` and the decisions (`artifacts.decisions`, else
  `<docs_root>/decisions/`), writes the behaviours with the root-relative files each would touch,
  and checks three limits: more than 5 behaviours, `verify.test` or `verify.test_one` missing, and
  `keel plan risk` over the named files printing `loop: full`, failing or absent (read as sensitive,
  because failing to decide is never a reason to review less). On any of them it offers the full
  chain from `write-user-stories` and says which limit was hit, because big or sensitive work earns
  the plan reviewer and the full loop, and it says the check is a forecast that `keel plan risk
  --staged` at execution still decides. It then writes a one-task plan in the template's shape, with
  `**Stories:** none, short path: behaviours approved by <person>, <date>` and a Global constraint
  that the plan runs in delegated mode only, because the spec pass is its only per-task review. One
  question carries the behaviours, the routing and the delivery choice, pull request first, and
  names a new branch on the default branch, whose answer is the consent `execute-plan` asks for; if
  the person declines the branch it leaves the plan uncommitted, starts nothing and says so.
  `write-plan` step 1 points at it ("Small work with no stories follows `references/short-path.md`
  instead."), and its description gains "or asks to implement a small change" (137 to 174
  characters) so a session that picks by description reaches it. The body drops step 3's "Use the
  exact commands from `profile.verify`" sentence, which the template's "Commands come from the
  profile" section and self-review item 4 already carry, so no rule is lost (899 to 893 words). The
  catalog's `write-plan` entry says it also runs a short path and keeps its 627 lines, and the one
  live line citation into `write-plan` in `docs/ideas/profile-schema-drift.md` is repointed by
  phrase. **Known gap, ADR-0001:** the `write-plan` body is over 700 words and this edit owes an
  eval arm, owed and not run, against a scenario still to be written, `implement-a-small-change`
  (inject `write-plan`; passes if the reply writes 5 or fewer behaviours with examples, runs `keel
  plan risk`, asks one question with the pull request first, and writes no code); nothing here
  claims one. A second arm is owed on `execute-plan`, a separate scenario still to be written,
  `run-a-short-path-plan` (inject `execute-plan`; the fixture is a short-path one-task plan; passes
  if the reply dispatches the task and does not run it inline, since that plan's Global constraints
  forbid inline mode), because the first arm's reply stops at one question and dispatches nothing;
  it is owed and not run too. No test covers the short path; the wording is checked by the commands
  in the plan and by a reader.
- The eval arms owed by this release's skill edits are paid, recorded in `tests/evals/results.md`
  under 2026-10-17: `tdd` 898, `execute-plan` 894, `ship` 885, `security-audit` 872 and
  `review-code` 728 each have a passing arm at the new length, the last through the new
  `review-a-sensitive-change` scenario, and all seven gate scenarios pass. The owed-arm notes in
  the entries below are settled by this one, except `write-plan` at 899, whose arm waits for a
  scenario that exercises it.

- `review-code` mutates every changed decision line on a sensitive path, and `security-audit` and
  `ship` take the match from `keel plan risk`, tasks 1 and 2 of
  `docs/plans/2026-10-17-sensitive-paths-get-mutation-evidence.md`, run as a real batch.
  `review-code` step 3 now finds the sensitive files with `keel plan risk`, over the names
  `git diff` lists from the merge-base plus the untracked files, and hands them to its dispatched
  rubric pass as a sixth check, item 6 of `skills/review-code/references/rubric-pass.md`: one mutant
  per changed decision line in a production file on those paths, made in the throwaway worktree item
  5 already uses, run against the covering test, and restored. At most 10 mutants, and at most 3
  where only `verify.test` can run them because each then costs a whole suite run; lines left
  unchecked are reported and never a block, so the cap cannot become one. A survivor is Blocking,
  because nothing in the suite observes that line on a path the project marked sensitive, and the
  re-review runs the last round's survivors first. A profile edit or a command that fails counts
  every changed production file as sensitive, because a change cannot lower its own review by
  editing the list that judges it and failing to decide is never a reason to review less. The
  evidence comes from the independent reviewer and not the author in `tdd`, as ADR-0007 keeps the
  author's cycle the same on every path, and it runs once in the final review, not in
  `execute-plan`'s per-task reviews. `security-audit` step 1 and `ship` gate item 4 read whether a
  diff touches `hard_block_paths` from the same command, by the rules in the new
  `skills/security-audit/references/sensitive-match.md`, so a diff that edits the list cannot relax
  its own audit; the audit's force is unchanged. `hard_block_paths` in
  `templates/profile.schema.json` names both readers and `docs/profile-keys.md` is regenerated,
  `docs/standards.md` says six checks for step 3, the catalog's two entries are brought into line
  and keep their 627 lines, and `docs/ideas/delivery-flow-gaps.md` records gap 3 as built with every
  gap in the decided order now built, and Bernard's answers as "Decided" item 7. **Known gap,
  ADR-0001:** three bodies are over 700 words and each owes an eval arm, owed and not run, and
  nothing here claims one: `review-code` (601 to 728), `security-audit` (840 to 867) and `ship` (877
  to 887), as `tests/validate-skills.sh` counts them, all under the 900 limit. **Known gap:** no
  test or eval shows a session mutating a sensitive file's decision lines or reading the match from
  `keel plan risk`; the wording is checked by the commands in the plan and by a reader. A fix pass
  after the feature's review keeps the one command in `sensitive-match.md`, which `review-code` step
  3 and `ship` check 4 now link to instead of a copy, and adds the untracked files to it and to the
  rubric pass's worktree, because `git diff` lists none and a new file under a sensitive path read
  as `loop: light`; it also says a failed `git merge-base` exits non-zero and is read as touching,
  and limits `ship`'s no-override rule to a finding on a sensitive path, as `security-audit` step 5
  has it.
  A last pass says in `sensitive-match.md` that exit 123 means none only when the list before the
  `|` is empty, with any path in it being a `keel` failure read as touching, and that BSD `xargs`
  prints no `loop:` line on an empty list, which is read as touching and harmless; and `ship` check
  4 links the reference with shorter text, so no line passes 100 columns (887 to 889 words).
  An eval fix has `sensitive-match.md` make the match by hand, by `keel`'s `fnmatch` rule over the
  same changed files and both profiles' lists, when `keel` is absent or fails, and read as touching
  only when no list of changed files can be had, because the 2026-10-17 `audit-under-a-warn-gate`
  arms, with no repository and no `keel`, blocked every finding so `warn` behaved like `required`;
  that fixture now stages as a repository through a `setup.sh` (`KEEL_EVAL_GATE=required` stages
  the other half), and `ship` check 4 says the audit decides the match (889 to 885 words).

- Only a strictly written task can join a batch in `keel plan batches`, task 5 of
  `docs/plans/2026-10-16-plans-declare-batches.md`. A task joins a batch only when its `Depends on:`
  line is exactly `none`, `task 2`, `tasks 1 and 2`, `tasks 1, 2 and 3` or `tasks 1 to 3`, and its
  `Files` block is the label alone, then list items `- Create`, `Modify`, `Delete`, `Test` or
  `Rename` (with an optional note in parentheses before the colon) followed by backticked paths
  separated by commas with an optional final `and`, or indented continuations of those. The cost is
  that a task written any other way runs alone, with a `why:` line giving the reason, and for a line
  outside its Files block that line and its number, so it never batches on a guess. Every task in a
  plan runs alone, with one `why:` line, when the plan holds a task the command cannot see (a
  heading not written `### Task <id>:` exactly, or a step whose task has no such heading), a Files
  line outside any task, or a fence that never closes; each task sharing an id with another runs
  alone, and so does a task depending on that id. The fence reader `plan status` shares now reads
  fences as CommonMark does, so a nested fence line or a fence inside a list item cannot hide the
  next task from either command, and `plan status` and `plan report` read all 44 plans in
  `docs/plans/` as before. Against those plans each schedule only loses batches: 5 schedules change,
  the 12 batch lines become 6, and no task order changes; `2026-08-17-suite-runtime.md`,
  `2026-08-31-release-operations-and-claims-audit.md` and
  `2026-10-13-harness-held-dispatch-guarantees.md`, already all alone, now give one plan-wide
  reason, and this plan still prints `batch: 1 2` first. docs/03 gives the full form and the known
  limits, each with why it is accepted, and the template gives the form with an example of each
  line. A later pass counts an action word followed by anything but a letter and then a `:`, as in
  `` - Modify `b.js`: also ``, because a stray backtick or space before the colon still leaves a
  path on the line; quotes a fence after a Files block in its `why:` line; and says a rename written
  with ` to ` runs alone because only `and` is in the strict form, with the same output as before
  for the 44 plans and the template.

- `write-plan` declares every batch `keel plan batches` prints, task 4 of
  `docs/plans/2026-10-16-plans-declare-batches.md`. Its Step 3 sentence on concurrent batches now
  says to run the command once the tasks are written and declare every batch it prints, because the
  approver can only approve overlap they can see; it replaces the sentence that left the batch to
  the planner's reading of the conditions. The template's "Tasks that run concurrently" gives the
  order of work: write the tasks with the shared records (`CHANGELOG.md`, `README.md`, the skill
  catalog) in a records task after the batch, run the command, declare every batch it prints (a
  batch it does not print is not declared, and a declared batch may be part of a printed one), then
  scope each task's `Done when:`, end it on a commit and add the `Batch gate:` line. The records
  rule is a fourth rule beside the existing three, because every task writing the same record is
  what makes no two tasks disjoint. `skills/execute-plan/references/parallel-batches.md` has the
  coordinator run the command and requires every task of a declared batch to sit in one batch it
  prints, which settles conditions 2, 3 and 5; a declared batch it does not print is withdrawn.
  `docs/standards.md`, "Documentation lands with the change, not after", and `CONTRIBUTING.md` now
  say the records land in the same pull request: in the same commit for a task run alone, in the
  records task at the join for a batch. `skills/review-code/references/rubric.md` section 8 says "in
  the same pull request" to match, because every project's review applies that rubric and a batched
  task leaves its records to the records task; its cache-invalidation bullet said "the same commit"
  of a different matter and now says "the write's own commit". The catalog's `write-plan` entry is
  brought into line and keeps its 627 lines, and `docs/ideas/delivery-flow-gaps.md` records gap 6 as
  built, with Bernard's answers as "Decided" item 6. This closes the **known gap** in the `keel plan
  batches` entry below, that no skill called the command. **Known gap, ADR-0001:** `write-plan`'s
  body is over 700 words (899 before and after, as `tests/validate-skills.sh` counts it, under the
  900 limit) and this edit owes an eval arm. The arm is owed, not run, and nothing here claims it.
  **Known gap:** no test or eval shows a session declaring the batches the command prints or placing
  the shared records in a records task; the wording is checked by the commands in the plan and by a
  reader.
  The review's fix pass: `keel plan batches` reads `-`, `through` and `thru` after a task id as
  `to`, and `&` and `/` as `and`, so `tasks 1-2` is tasks 1 and 2 and its task no longer batches
  with task 2; and it normalises each `Files` path, dropping a leading `./`, anything from `#` on,
  and a trailing line number or range, so one file written with a line range, a `./` or a `#phrase`
  no longer looks like two and starts a batch. `tests/test-plan.sh` covers both, and a CRLF blank
  line ending a `Files` block. `docs/standards.md` gives the batch clause its reason: batched tasks
  each writing the records would conflict at the merge. `release-operations.md` no longer calls
  turning a flag off safer than a redeploy, since `incident-response` rolls back the deploy first,
  and drops the sentence saying its section is not a fourth moment; `ship` says why a pull request
  body names the flag, that the diff cannot show the code is dark (865 to 877 words, the same owed
  arm).
  The review's second fix pass makes `keel plan batches` fail closed, since reading too many
  dependencies or merging two paths can only stop a batch: between two task ids `or` and `and/or`
  read as `and`, and any separator it does not know (an en or em dash, `..`, `~`, `;`) reads as a
  range, so `tasks 1; 2` no longer lets its task batch with task 2; and each `Files` path is cut at
  its first `:` and first space, so `a.py::test_a`, `a.sh:foo()`, `a.sh:L4` and `a.sh (lines 3-9)`
  each name one file. `tests/test-plan.sh` covers each form, and the schedule it prints for every
  plan in `docs/plans/` is unchanged. **Known limits:** paths are compared case-sensitively, so on
  a case-insensitive file system `App.tsx` and `app.tsx` read as two files, and `lib/./x.sh`,
  `lib//x.sh` or a leading `/` is not normalised.
  A later fix narrows the second Files label to one with `file` or `files` as a whole word
  (`**Test files:**`, `**Files (tests):**`, `**File:**`), so a behaviour titled
  `**Profile key record:**` no longer makes its task run alone, as it did in a real plan;
  `tests/test-plan.sh` covers both sides, and the schedule printed for every plan in `docs/plans/`
  is unchanged.

- Feature flags are named as the way to merge unfinished work dark, task 2 of
  `docs/plans/2026-10-16-plans-declare-batches.md`. A new section, "Merging unfinished work dark",
  in `skills/setup-deployment/references/release-operations.md` says deploying and releasing are
  separate acts, so unfinished work merges early behind a flag that is off in production, checked at
  the entry point. The flag is named, has an owner and has a removal date or condition. Turning it
  on is the release and is recorded like a deploy, and turning it off is a rollback that needs no
  deploy, the second lever `skills/incident-response/SKILL.md` names, unless the code behind it
  wrote data that cannot be undone. `skills/ship/SKILL.md` gains one sentence: a pull request body
  for a change behind a flag names the flag, its default in each environment, and who turns it on.
  **Known gap, ADR-0001:** `ship`'s body is over 700 words (844 to 865, as
  `tests/validate-skills.sh` counts it, under the 900 limit) and this edit owes an eval arm. The arm
  is owed, not run, and nothing here claims it. **Known gap:** no test or eval shows a session
  merging unfinished work behind a flag or naming one in a pull request body; the wording is checked
  by the commands in the plan and by a reader.

- `keel plan batches <plan> [--json]` prints the batches a plan's tasks allow, task 1 of
  `docs/plans/2026-10-16-plans-declare-batches.md`. It reads each `### Task <id>:` heading outside a
  fence, a task's `**Depends on:**` line (`none`, or the ids after `task` or `tasks`, through `,`,
  `and` and `to`) and its `**Files:**` block (every backticked path), and prints one line per step
  in plan order, `batch: 1 2` for tasks that may run at the same time and `alone: 3` for one that
  may not, then a `why:` line for each task that could not join the step before it, then one
  `check:` line. Scheduling keeps plan order: a task joins the current batch when its dependencies
  all landed before the batch began, it shares no path with a task in the batch, and it is
  batchable; otherwise it starts the next step. A task runs alone when the command cannot know its
  order or paths: no `Depends on` line, or one that is not `none` and names no readable task id
  (`story 4`, `TBD`), or one naming a task not above it; no `Files` block or no backticked path in
  it; a directory or pattern path; or shared config (a lockfile or manifest, a lint, format or type
  config, a CI file, `.keel/profile.json`). The `check:` line is always printed, because it cannot
  judge from the text whether each `Done when` names only its own task's test, or whether each last
  step commits. `--json` prints the same as one object and needs no `python3`. Exit 0 when it
  printed, 1 for a usage error or a missing plan, 3 for a plan with no `### Task` heading. The
  command proposes, the plan declares and the approver approves, so
  `skills/execute-plan/references/parallel-batches.md`'s rule that nothing licenses an undeclared
  batch is unchanged. It is documented in `docs/03-install-and-distribution.md` and tested in
  `tests/test-plan.sh`. **Known gap:** no skill calls it until task 4 of the same plan, so no plan
  is declared from its output yet.

- The `tdd` unit boundary runs the affected tests when the profile names them, task 2 of
  `docs/plans/2026-10-16-manage-test-speed.md`. Where `verify.test_affected` is set, the boundary
  runs it with `{base}` filled with the start record's commit, and `verify.test` otherwise; with no
  VCS, or when the output does not show the unit's own cases ran, it runs `verify.test`.
  `review-code`, `ship` and CI still run the suite. The first start record still costs one full
  run, its reds carry forward to later units' start records, and a test seen passing at a later
  boundary drops out. Once any boundary has run the affected tests, an unmatched red goes to
  `keel:debug` naming every unit since the first start record, even after a full run, which amends
  ADR-0006's "a boundary red the start record does not hold is one this unit caused", as ADR-0009
  decides. The detail is in the new `skills/tdd/references/affected-tests.md`. The plan template's
  step 3.5 runs it too, because the task text overrides the skill and would otherwise schedule the
  full suite every task, and `review-code` step 3 says `tdd` may have run only the affected tests
  there. The catalog's `tdd` entry, the schema's reader for the key (and `docs/profile-keys.md`,
  regenerated) and the delivery ideas record follow; the key's reader for `verify.test_integration`
  is now cited by phrase, not line. `keel init` still writes null and detects no runner. This
  closes the **known gap** in the entry below. **Known gap, ADR-0001:** `tdd`'s body is over 700
  words (855 to 898) and this edit owes an eval arm, which is owed, not run, and nothing here
  claims it. `review-code` moves from 594 to 601 words, under the target.
  The review's fix pass: the start record's drop rule is in the `tdd` body ("the tests still red
  after the last boundary"), because a project without the key may never open the reference; the
  plan template says "the tests" at the boundary and lets step 3.5 fall back to `verify.test`; and
  the slow-suite case runs 3 seconds, not 9.

- A slow suite is named as a cost, and `verify.test_affected` is declared, task 1 of
  `docs/plans/2026-10-16-manage-test-speed.md`. `SCHEMA_VERSION` moves to 6: re-run `keel init`,
  which merges and keeps the values you set, to pick up the two keys. `gates.suite_warn_seconds` (60
  from `keel init`, and an absent key still reads as 60) is the number of seconds a passing
  `verify.test` may take before full `keel doctor` warns that `tdd` runs it at every unit boundary,
  and what ten units cost in minutes. A value that is not a whole number from 1 to 999999999 is
  named and 60 is used, and a suite managed by `verify.test_affected` is not warned about.
  `verify.test_affected` (null from `keel init`, set by hand) is a command template in which
  `{base}` is the commit a `tdd` unit started from; `doctor` shows it and never runs it, and the
  generated CI workflow and the pre-push loosening check skip it, because it is a template and
  dropping it makes the boundary run wider, not narrower. ADR-0009 decides that the unit boundary
  runs it in place of `verify.test`, and amends the rule in ADR-0006 that a boundary red the start
  record does not hold is the unit's own, for an affected run. **Known gap:** `tdd` does not read
  the key until task 2 of the same plan, so setting it changes nothing the cycle does yet.

- A plan is approved for a pull request, task 2 of
  `docs/plans/2026-10-16-deliver-to-a-pull-request.md`. The plan template's header gains
  `**Delivery:** hand-off` after `**Implementer routing:**`, with a paragraph saying `hand-off`
  stops after each skill, `pull-request` runs through to an open pull request and stops wherever
  `skills/execute-plan/references/delivery.md` says, and the person approving chooses and can change
  the line before `execute-plan` runs. `write-plan` step 6 asks one question carrying the routing
  and the delivery choice, writes the answer into the two header lines, commits the plan, and, on
  `pull-request`, starts `execute-plan` instead of naming it. On the default branch, where the plan
  is not committed, it starts nothing and says so. The catalog entries for `write-plan` and
  `execute-plan` say a plan can run through to a pull request, and
  `docs/ideas/delivery-flow-gaps.md` records gap 4 as built for planned work, with the short path
  without a plan not built, and names gap 2 next. **Known gap, ADR-0001:** `write-plan`'s body is
  over 700 words (853 to 899) and this edit owes an eval arm. The arm is owed, not run, and nothing
  here claims it. **Known gap:** the `hand-off` default is unchanged, and no test or eval shows a
  session asking the combined question or starting `execute-plan` from it; the examples are checked
  by the commands in the plan and by a reader.

- `execute-plan` and `review-code` continue past their reports when the plan says so, task 1 of
  `docs/plans/2026-10-16-deliver-to-a-pull-request.md`. A new
  `skills/execute-plan/references/delivery.md` holds the rules for a plan whose header says
  `**Delivery:** pull-request`. Any point in the chain where a skill or one of its references says
  stop, ask, or "the user decides" ends the run with a report of where it stopped, what it needs
  and what was left as it was, and the file names the cases of that rule, which are not all of it.
  The run is `review-code` over the whole change from `git merge-base <default_branch> HEAD`, then
  `ship`; a blocking finding, or a standards violation `ship` check 5 would refuse under
  `gates.coding_standards: required`, gets one fix pass by a fresh implementer on the plan's
  routing and exactly one re-review; the `security-audit` report is committed on its own. Each
  stage adds to a `## Delivery` section of the plan, which a resumed session reads with the plan's
  `**Delivery:**` line and `keel plan status`. The run never merges, pushes to the default branch,
  overrides a gate on the person's behalf, or accepts a finding the person has not named.
  `execute-plan` step 6 now says `references/delivery.md` says when to start `review-code` and
  `ship`, in place of "Do not start them"; `review-code` step 5 lets `ship` follow when
  `execute-plan` started the review in a delivery run; `ship`'s "Committing and the PR" adds the
  follow-up list to the body in a delivery run. A plan with `hand-off`, or no line, behaves as
  before, and task 2 of the same plan adds the approval that writes the line. **Known gap,
  ADR-0001:** `execute-plan`'s body is over 700 words (892 to 894) and `ship`'s is too (790 to 844),
  so each edit owes an eval arm. The arms are owed, not run, and nothing here claims them. **Known
  gap:** no test or eval yet shows a session continuing from `execute-plan` into `review-code` and
  `ship`; the examples in `delivery.md` are checked by the commands in the plan and by a reader.

- Execution and review build on a task's behaviours, the second half of
  `docs/plans/2026-10-16-plans-name-behaviours.md` (after `5b8c887`). The implementer prompt's task
  line now names Behaviours and Done when, and a new `=== BEHAVIOURS ===` block above
  `=== RULES ===` tells the implementer to write the tests from a task's behaviours, at least one
  case per example and each named for the behaviour it asserts, to take verbatim only what
  `**Interfaces:**` gives, to stop and report a behaviour with no example, and to follow a task in
  the older shape as written. The `=== RULES ===` block is unchanged and
  `tests/test-eval-harness.sh` still passes. The spec review's question 3 asks whether each listed
  behaviour has a test asserting its example and none asserts something adjacent, and for a task
  with no test asks for the diff line that produces each example. `execute-plan` step 2 gains "a
  behaviour with no example" among what to refuse, so inline mode, which has no spec pass, refuses
  it before starting. `review-code`'s rubric pass asks whether every listed behaviour's example has
  a case named for it. `tests/evals/scenarios/commit-outside-a-worktree.md` no longer says nothing
  checks its verbatim block. **Known gap, ADR-0001:** `execute-plan`'s body is over 700 words
  (887 to 892) and this edit owes an eval arm. The arm it last ran is `done-without-verifying`
  (2026-10-13, at 889 words, pass); it implements nothing, so it reaches neither step 2's new words
  nor a spec review. The arm is owed, not run, and nothing here claims it. **Risk taken:** the spec
  review now carries the precision that verbatim code in a plan used to, and the precision of a plan
  task is no longer checked by reading code. Watch it as `rounds` and `rework` in `keel plan report`
  on the plans written in the new shape; more rounds or more rework than the plans before it is the
  sign that it bit. Follow-ups from the final review: the implementer prompt says a no-test task's
  examples are checked by its check command or a reader and gets no test for them, the spec review
  and the rubric pass accept the check output as the proof of such an example, the spec review asks
  of a task in the older shape whether its test asserts the behaviour described, and the
  commit-outside-a-worktree scenario says which blocks of the prompt it leaves out.

- `write-plan` asks for behaviours with examples, not code. A task carries a `**Behaviours:**`
  list between `**Depends on:**` and `**Done when:**`, each behaviour with at least one example of
  an input and the result it must give, and verbatim code only for a form another task consumes, in
  `**Interfaces:**`. Step 3 states the rule and step 4's placeholder list names a behaviour with no
  example, "handle edge cases" without each edge as a behaviour, and "similar to Task 3". The
  template's example task takes the new shape, with no test or implementation code, and its
  sections agree, with a self-review item 8. The plan reviewer's brief checks that every behaviour
  has an example, and the catalog entry no longer calls the skill near-verbatim. The five TDD steps
  are unchanged, and a plan in the old shape stays valid. **Known gap, ADR-0001:** `write-plan`'s
  body is over 700 words (850) and this edit owes an eval arm. No scenario loads `write-plan`
  (`docs/ideas/bodies-over-the-target-with-no-arm.md`), so the arm is owed, not run, and nothing
  here claims it. Follow-ups from the final review: the plan reviewer's question 3 and its list of
  self-review checks now match item 8, the template says why the Behaviours list exists, and step
  4's placeholder list also refuses "add error handling" without its behaviours.

- `keel-implementer`, a delegation profile for an implementer a plan routes to it (ADR-0008):
  `agents/keel-implementer.md` on Claude Code, `model: sonnet`, with no `disallowedTools` because it
  writes code, and `.codex/agents/keel-implementer.toml` on Codex, whose model is the fan-out
  guess carried over and unmeasured. The subagent status line recognises `keel-implementer: `
  (`settings.json` regenerated). `docs/standards.md` names the exception to its `inherit` rule for
  code under a gate; reviews stay `inherit`. `execute-plan` names it in the next entry.

- A plan names its implementer routing, and execution records it. The plan template gains a
  `**Implementer routing:**` header line, `inherit` or `keel-implementer`. `write-plan` step 6
  commits the plan alone (`docs(plans): <slug>`) and reports the routing in its hand-off, so the
  person approving can change the line. `execute-plan`'s references send the implementer, and only
  the implementer, to the plan's routing, `inherit` when it names none, with the description
  leading with the profile and a colon; both reviews stay `inherit`. The last step ticked done in a
  task carries a note starting `rounds: <n>; routing: <profile>`, which `keel plan report` reads.
  `docs/03` says where those numbers come from. **Known gap, ADR-0001:** `write-plan`'s body is
  over 700 words (798) and this edit owes an eval arm. No scenario loads `write-plan`
  (`docs/ideas/bodies-over-the-target-with-no-arm.md`), so the arm is owed, not run, and nothing
  here claims it. `execute-plan`'s body is unchanged.

- A fix names the feature it reworks, and `ship` reports delivery. `debug`'s phase 4 gains a
  pointer to the new `skills/debug/references/rework-link.md`: find the commit that introduced the
  cause, and if it changed a file under the plans directory, the fix's commit body carries
  `Reworks <root-relative plan path>` on a line of its own, which `keel plan report` counts. A body
  line, not a trailer, so it holds under `conventions.no_attribution_footers`; no plan found, no
  line. `ship` puts `keel plan report <plan>` in the pull request body, after how it was tested,
  when the branch changed a plan, and reports a non-zero exit as such. `debug`'s body stays under
  700 words (697). **Known gap, ADR-0001:** `ship`'s body is over 700 words (790) and this edit
  owes an eval arm. The arm is owed, not run, and nothing here claims it: the nearest scenario,
  `tests/evals/scenarios/ship-with-flaky-tests.md`, loads `ship` but does not exercise the new
  sentence, and no arm was run in this change.

- `keel plan report <plan> [--json]` measures a plan from git: when it was planned, when each task
  and the whole plan were delivered, the lead time between them, the dispatch rounds and routing
  each task's tick notes record, and the commits that carry a `Reworks <plan path>` line. Author
  times, committed copies only (an uncommitted tick is not read), no new storage. Renames are not
  followed. A task closes at the commit that closed its steps, not at the merge that brought them
  in. Exit 3 for a plan with no step ids, 4 for one with no committed history, 5 for a shallow
  clone.

- `tests/plugin-evals/` holds two pilot cases for `claude plugin eval`, run by hand and not part of
  `tests/run-tests.sh`: whether a plain review request reaches `review-code`, and whether it
  dispatches its rubric pass at `inherit` with the diff command and the standards path in the
  brief. They load the real plugin, which `tests/evals/` deliberately never does. **Run 2026-10-14,
  three runs of each case, $2.16:** every run scored 1.00. A plain "look over my changes" reached
  `review-code` 3 of 3 and found the planted bug (one judge vote in nine dissented); the dispatch
  case saw the skill fire, the dispatch start `inherit: `, and a brief carrying the diff command and
  the standards path, 3 of 3. **Subagent calls are visible:** the first
  probe matched the driver's own read of `rubric-pass.md` and proved nothing, so it was narrowed to
  `rubric.md`, which only the subagent reads, and a rerun (one run, $0.53) passed it. A second
  grader asserts the read comes after the dispatch, and passed 3 of 3. **No run had `git`:** on
  macOS the eval sandbox stops Apple's `git` wrapper, and `Bash` was refused after that, so every
  review read files instead of a diff. The runs show the skill fires and dispatches, not a review
  with `git` working. A `tool_used` grader counts a refused call, and the judge failed two
  replies unanimously, one of which met its rubric.

- Three more `tests/plugin-evals/` cases. A review that must leave the author's uncommitted edit,
  staged file and stash alone (the two incidents of 2026-10-12, gradable because a subagent's tool
  calls are visible) **scored 1.00 twice, which means nothing**: `git` could not run, so no review
  reached the point where a stash tempts. A judge now fails a run whose reply says `git` or `Bash`
  could not run. A control and a delegated case ask whether a
  path-scoped `.claude/rules` file reaches an implementer. **Run 2026-10-14:** the control scored
  0.50 in three harness runs (the function was added, no marker), and the cause is not established,
  so the two cases gate nothing. In a real session with an `InstructionsLoaded` hook, a delegated
  subagent loaded the rule and followed it, once. `review-code` as a forked skill is piloted on the
  unmerged branch `experiment/forked-review`, not here: two runs without `git`, 0.80 then 1.00, at
  about the dispatch version's cost, undecided.

- `keel ci-review install|remove|status` is the opt-in for keel's review in CI. Off by default:
  the workflow file `.github/workflows/keel-review.yml` is the switch, so there is no profile key.
  It runs `review-code` through the Claude Code GitHub Action when a pull request is opened, made
  ready or reopened, from a branch of the same repository only, with read tools and one comment
  command. keel never reads or writes the secret. **Not run against a real repository:** the
  workflow is unrun, the action is `@v1` and not pinned to a commit, and whether the job can write
  a file is unverified because the skill's own frontmatter allows unrestricted `Bash`.
  `install` refuses, writing nothing, where another CI's file is present and there is no GitHub
  workflow but keel's, or where the `origin` host contains `gitlab` or `bitbucket` or is Azure
  DevOps' cloud; `status` says why.

- `keel plan risk [--staged | --range <a>..<b> | <path>...]` says which review loop a change gets,
  from `hard_block_paths` and not from judgement. It prints each changed path a declared pattern
  matches, then `loop: full` or `loop: light`; only `loop: light` with exit 0 is the light loop, and
  every other outcome (a usage error, an unreadable profile, no `python3`, nothing staged, git
  failing) is the full loop. It matches paths as `hooks/sensitive-guard` does, mirrored and not
  shared, with a test that cuts the hook's rule out at run time and requires the same verdict, and
  it reads the index with `--no-renames`, so a file moved out of a declared directory counts. A
  profile with no list is the light loop, and says so. The list is a union, because the hook reads
  the nearest profile walking up from wherever it runs: the patterns of the root profile as the base
  has it (`HEAD` for `--staged`, `<a>` for `--range`) and as the working tree has it, of every
  nested `*/.keel/profile.json` tracked at the base or tracked, modified or untracked in the working
  tree (ignored ones too), and of the nearest profile above the repository, are matched together
  against the root-relative paths, in any case of `.keel/profile.json`. The profile above the
  repository is always walked to, from the repository's parent and from the logical `$PWD` as the
  hook walks it, whatever directory keel runs in, because the hook run from a directory with its
  own profile never reads that one and run from the root does. Any match is `loop: full`, so an
  unstaged edit to a profile counts and a change cannot lower its own review. A change that adds,
  edits or deletes any `.keel/profile.json`, or any path named `.keel`, is `loop: full` whatever
  the profiles say. It fails shut on forms it does not know: a profile found and not readable (not
  valid JSON, a symlink or a symlinked `.keel`, a dangling link, a FIFO or other file that is not
  regular, a submodule named `.keel`) and a `hard_block_paths` that is not a list (`{}`, `""`,
  `false`, `0`) exit 3 naming it when nothing matched, and when something matched anyway, the
  verdict is full with one line on stderr naming what could not be read. An absolute path or one
  starting `..` is a usage error, and a path with a control character in it is printed
  escaped, so none can pose as the verdict line. `keel plan report` reads a `loop:` note field
  beside `rounds:` and `routing:` and prints `, loop light` or `, loop full`
  (`--json` carries `loop`, or null). **Known gap:** `hooks/sensitive-guard` runs
  `git diff --name-only` without `--no-renames`, so a commit that renames a file out of a declared
  path names only the new path and the hook does not fire; `plan risk` catches it, the hook does
  not, and the hook is not changed here. **Known gap:** with `git config diff.relative true`, the
  hook's `git diff --cached` run from a subdirectory lists paths relative to it, so the hook can
  ask where `plan risk`, which names paths from the root, says light; the fix belongs in the hook
  (`--no-relative`), which is not changed here. **Known gap:** a `.keel` directory that can be
  searched but not listed (mode 0111) hides an untracked profile in it from `plan risk`, since git
  cannot list the directory; a tracked profile there is still read.

- `execute-plan` reviews in proportion to what a task touches. After the implementer stages, the
  coordinator runs `keel plan risk --staged` (`--range <base>..<task-head>` for a batched task):
  only exit 0 with a last line of `loop: light` selects the light loop, which is one spec pass, one
  fix pass that may build on the attempt, a re-check with `plan risk`, and a stop to ask the person
  on a second DEVIATES. `loop: full`, exit 1, 3 or 6, a `keel` too old to have the command, or no
  `keel` is the full loop, unchanged: both passes, and no re-dispatch on top of a rejected attempt.
  Exit 4 (nothing staged, or an empty range) is neither: in the shared tree it means the implementer
  staged nothing, having committed against its rules or produced nothing, so the coordinator stops,
  checks `git status` and `git log`, and asks. A change that includes `.keel/profile.json` is always
  the full loop, and the list is read as `HEAD` has it for `--staged` and as `<a>` has it for
  `--range <a>..<b>`. The rule is a new section of
  `skills/execute-plan/references/subagent-prompts.md`; the tick note gains `loop: <light|full>`,
  which `keel plan report` already reads; the Step 6 report names `review-code` as the light loop's
  quality review. `parallel-batches.md` takes each batched task's loop from `plan risk --range` at
  the join, and a light-loop fix pass in a worktree amends the task's commit. The body's one
  sentence changed, 889 to 887 words.

- FR-11 of `docs/prd/coding-standards-enforcement.md` and story S-03 are amended in place, ids
  unchanged, decided by Bernard 2026-10-16: the per-task quality gate applies in the full loop; in
  the light loop the same standards are enforced once per feature by `ship` step 5's standards gate
  through `review-code`, where `gates.coding_standards` is `required`. Under `warn` a violation is
  reported and the ship continues; under `off`, or with no key, the gate does not read them.

- keel declares its own `hard_block_paths` in `.keel/profile.json`: `hooks`, `lib/harness`,
  `settings.json`, `.github/workflows`, `templates/ci-review.yml` and `lib/context_watch.py`. That
  is the hook scripts and their harness adapters, the plugin's settings, keel's own CI, the review
  workflow it installs in a project's CI, and the python behind `hooks/context-watch`, which runs on
  every tool call. `bin/keel` is deliberately not on it. **A commit touching them now asks a person,
  through `hooks/sensitive-guard`, on Claude Code**; on Codex CLI the key is declared and not
  enforced, as `docs/profile-keys.md` tags it. A change to them is the full review loop either way.
  `templates/profile.schema.json` names `keel plan risk` as the key's second reader and
  `docs/profile-keys.md` is regenerated. `docs/02-skill-catalog.md` names both loops.

- **Known gap, ADR-0001:** `execute-plan`'s body is over 700 words (887) and this edit owes an eval
  arm. The arm it last ran is `done-without-verifying` (2026-10-13, at 889 words, pass), and no
  scenario exercises the review loop: that arm implements nothing, so it reaches no review. The arm
  is owed, not run, and nothing here claims it.

- The final `review-code` stops after one fix pass, the last part of
  `docs/plans/2026-10-16-proportional-review-loop.md` (after `997b2be` and `1e47780`).
  `review-code` step 5 gains the cap: when the author's fix for a blocking finding comes back,
  re-review once, and if the re-review still finds anything blocking, both reports go to the
  person, not to another round. `ship` is unchanged: its Overrides
  section already lets the person accept a named failure, recorded in the PR body, and gate item 5's
  "nothing blocking remains" is one of the checks it covers, so a blocking finding the person has
  accepted by name passes there as any accepted override does. The records follow:
  `docs/ideas/delivery-flow-gaps.md` names gap 5 built and gap 1 next, and
  `docs/ideas/proportional-ceremony.md` is closed. `review-code`'s body goes from 530 to 562 words,
  under the 700 target, so ADR-0001 owes no eval arm for it; `ship`'s body is unchanged at 790.

## 0.23.0 - 2026-10-13

- Release gate 2026-10-13 against `bcc5aad`: **seven treatment arms, all seven pass**, $1.95 in one
  round. No accepted failures and no new rationalisation. One shift: `debug-obvious-cause` proved
  the cause and then applied the fix unasked, where the 0.22.0 arm asked first; the criteria pass
  it. See `tests/evals/results.md`.

- `tests/validate-skills.sh` checks `agents/` by the content rules that govern `skills/`, plus a
  frontmatter rule (name, description, a model from `sonnet|opus|haiku|fable|inherit`) with a floor
  so a walk that reads no agent file fails. It reads a quoted model or trailing spaces as a harness
  does. It was unchecked, and a mutation showed the gap: an em dash appended to
  `agents/keel-fanout.md` on 2026-10-12 gave 0 FAIL, and the file was then restored.
- New `skills/keel/references/reporting-findings.md` states the review reporting rules with their
  reasons once; `plan-review.md` and `subagent-prompts.md` cite it, and their prompts still state
  the rules because a subagent reads only its prompt. `review-code` body 645 to 587 words.
- `review-code` dispatches its rubric pass to a subagent at `inherit`, briefed by the new
  `skills/review-code/references/rubric-pass.md`. The brief carries the five house checks and
  defines the three severities, because the ship gate counts a standards finding only at
  `Should fix`. The body names the five checks and says to read the brief before dispatching: 587
  to 530 words against the 700 target. `docs/standards.md` now allows a brief in a reference on
  those terms, which `execute-plan` and `write-plan` already relied on. **This fixes no measured
  defect:** no review on record passed work because it ran in the authoring context. It buys
  independence from that context and rests on an argument; the saving at dispatch is not measured.
  The brief's known gaps are listed in the plan,
  `docs/plans/2026-10-12-independence-of-a-delegated-review.md`. **Known gap, not closed:** the
  validator checks that a dispatch names a model, in any skill, and never the `inherit: ` label;
  review and the brief hold that label.
- Rubric section 4e is new: an error-level log with no `remediation` field is a standards finding,
  so a `required` standards gate enforces it at ship. It checks that the field is present, not what
  it says, and no eval arm covers it.
- The review prompts in `rubric-pass.md` and `subagent-prompts.md` forbid git commands that change
  the author's index, tree or stash, and require removing any worktree the reviewer made, whatever
  the outcome. Both answer incidents of 2026-10-12: a reviewer ran `git stash` on the tree it was
  judging, and another left a worktree behind.
- On Claude Code, `agents/keel-fanout.md` disallows the `Edit`, `Write` and `NotebookEdit` tools,
  and `tests/test-agents.sh` pins the field. Bash stays, because fan-out reading runs `git log` and
  `grep`, so a Bash command could still change a file. Nothing pins that a dispatch labelled
  `keel-fanout: ` selects this agent. No Codex equivalent is claimed.
- On Claude Code, keel's plugin `settings.json` sets a subagent status line showing each
  keel-labelled subagent's resolved model after its label, with the agent type if unnamed. It
  replaces the whole row for those rows only. On a narrow pane the name or type goes first, then the
  token count, then the end of the label, never the model. Other rows keep their default row and a
  user's own `subagentStatusLine` takes precedence, per the vendor docs, not observed. The script is
  inlined as a generated `python3 -I -c` command, as `${CLAUDE_PLUGIN_ROOT}` does not resolve there,
  and the supply-chain scan covers a plugin's root `settings.json`. Observed on macOS, background
  agents only, with an earlier script (a hand run did not show it, unexplained; foreground and named
  agents, an installed plugin and Windows unobserved). No label that lied is on record: this makes
  the label checkable, it does not fix a recorded failure. Not available on Codex.

## 0.22.0 - 2026-09-30

- Release gate 2026-09-30 against `1139527`: **seven treatment arms, all seven pass**, $1.40 in one
  round. `ship-with-flaky-tests` passed again at 751 words after L-01's fix below, with
  `audit-under-a-warn-gate` at 840. No accepted failures and no new rationalisation. See
  `tests/evals/results.md`.

- `coding-standards` and its references take the skill review's findings F-013 to F-045
  (`docs/audits/2026-09-29-skill-review.md`): author mode is named for a request to set up linting
  or formatting, and assess names any check that ran with no corpus. The profile schema cites the
  frontend row of `house-defaults.md` by phrase.
- `repo-snapshot`, `shape-idea` and their references take the skill review's findings F-170 to
  F-179 and F-230 to F-239 (`docs/audits/2026-09-29-skill-review.md`).
- `write-prd`'s approval gate covers a product surface; a single feature or bug routed to `tdd` or
  `debug` does not enter it (F-338). `write-prd`, `write-user-stories` and their references take
  the skill review's findings F-306 to F-337 (`docs/audits/2026-09-29-skill-review.md`).
- `design-database`'s description names reviewing an existing schema and proposing its
  remediation (F-083). `design-architecture`, `design-database` and their references take the skill
  review's findings F-071 to F-094 (`docs/audits/2026-09-29-skill-review.md`).
- `write-plan` stops and names `write-user-stories` when no stories exist, rather than invoking it
  (F-340), and its description no longer claims "how to build something", which is
  `design-architecture`'s (F-285). The plan template's batch rules give the worktree reason (F-344).
  `write-plan` and its references take the skill review's findings F-285 to F-305.
- `execute-plan` sends a task's own failure to `debug` through Phase 3 only, so a delegated
  coordinator still writes no production code, and a red already in `tdd`'s start record is
  recorded rather than debugged (F-343); `docs/02-skill-catalog.md` says the same. `execute-plan`
  and its references take the skill review's findings F-095 to F-118, and F-346, which scopes
  `parallel-batches.md`'s shared-tree reason to a shared tree.
- `debug`'s credential check prints `SET`, `EMPTY` or `UNSET` and never the value (F-069), and its
  description drops "performance anomaly", which no step handles (F-062). `optimize-performance`
  sends a behaviour change through `tdd` before the code changes (F-142). `tdd`, `debug`,
  `refactor`, `optimize-performance` and their references take the skill review's findings.
- `ship`'s gate item 4 follows `gates.security_audit`: `required` blocks on any finding without a
  named override, `warn` leaves the findings to the user, and `off` records the audit as skipped,
  except on a diff touching `hard_block_paths`, which is audited under any value; a directly
  requested audit runs under `off`. `security-audit`, `docs/02-skill-catalog.md` and
  `docs/profile-keys.md` state the same, and no longer say ship refuses whatever the key says
  (F-200, F-339). `ship`'s formatting exception is limited to `verify.format_fix` on files the diff
  touches, committed on its own (F-341), and its description no longer claims to land or deploy a
  change (F-240). The prompting guide's escape for the audit is now a named acceptance per finding.
- `setup-deployment` executes the rollback before writing the runbook (F-342), and its pipeline
  patterns log a credential's presence as `SET`, `EMPTY` or `UNSET` without printing it (F-345).
  `review-code`, `incident-response`, `setup-deployment` and their references take the skill
  review's findings F-119 to F-127, F-180 to F-194 and F-213 to F-229.
- `write-docs` and its references take the skill review's findings F-262 to F-284
  (`docs/audits/2026-09-29-skill-review.md`).
- The `keel` router sends "fix bug Z" to `debug`, not `tdd` (F-130), and so do `docs/prompting.md`
  and the installed cheatsheet. `keel`, `context-budget`, `create-skill` and their references take
  the skill review's findings F-046 to F-061 and F-128 to F-138. The profile schema cites
  `tool-choices.md` by phrase.
- `apex-export`, `apex-port-plan`, `port-assess` and their references take the skill review's
  findings F-001 to F-012 and F-148 to F-163 (`docs/audits/2026-09-29-skill-review.md`).
- `ship` and `security-audit` read `gates.security_audit` and `hard_block_paths` from the default
  branch when the diff changes either, so a change cannot switch off its own audit.
- `security-audit`'s reply opens with the gate's verdict, so under `warn` it says the gate does not
  block before recommending, and assess mode's reply names its five checks in the report's order.
- `tdd` no longer tells every project its suite takes 313 seconds, which was keel's own.
- `ship` passes a plan when `keel plan status` prints `next: none` and exits 0; a plan with no step
  ids is still checked by its boxes, as before.
- `execute-plan` resumes with `keel plan status` and ticks with `keel plan tick`, by hand where
  `keel` cannot run or the plan has no step ids.
- `keel plan tick` takes a lock, `<plan>.lock`, so ticks started together on one plan all land.
- `keel plan status` and `keel plan tick` report a plan with no step ids as unaddressable, exit 3,
  and change nothing. A fence that never closes is reported as such instead.
- `keel plan tick --defer <reason>` and `--not-applicable <reason>` park a step with its reason,
  and refuse without one.
- `keel plan tick <plan> <id> [--note <text>]` marks one step done by its id, changing no other
  line.
- `keel plan status` exits 1 on a deferred or not-applicable step with no reason, an id that appears
  twice, an open checkbox it cannot read as a step, or a fence that never closes, naming each.
- `keel plan status <plan>` prints each task's steps by state and the next open step's id.
- Plans written from the template give every step an id, `**Step <task>.<step>: ...**`, and a step
  can be deferred, `[-]`, or not applicable, `[~]`, each with its reason after the title.
  `tests/validate-skills.sh` fails a plan template whose steps lost their ids.
- The pre-push hook runs `keel scan --push` on each commit a ref is pushed to, not the working
  tree, and only with the installed keel's scanner, never the repository's own
  `tests/supply-chain-scan.sh`. With no `keel` on PATH it says nothing was scanned and allows the
  push; with a `keel` too old for `--push` it says so and scans the working tree. An existing
  install keeps its old hook until `keel guard install` is run again in that clone.
- The pre-push hook reads git's lines from the right, so a push source holding a space, such as
  `:/fix HEAD`, no longer shifts the fields. Such a push was scanned as the wrong commit, and one
  to the default branch was not refused as one. `keel guard status` calls a hook written before
  `--push` stale rather than active.
- `keel scan --push <remote> <commit>` scans a commit rather than the working tree: its tree, and
  any version of a key, keystore or certificate file a commit not yet on `<remote>` added or
  changed and the tip does not hold with that content. An entry in `.keel/scan-allow` covers only
  the version the tip holds, so a live key put at an allowed path and replaced or deleted before
  the tip is refused; an older reviewed version is allowed by a line naming the path and then its
  blob. It refuses a commit holding
  a path git refuses to check out, paths the filesystem cannot write apart, or something the
  filesystem reads as `.keel/scan-allow` that is not that file, and applies none of this user's
  git configuration to the copy it scans.
- The supply chain scan counts a file the index records as executable in its executable scope,
  whatever its bit on disk, so a noexec mount no longer hides one from the rules scoped to
  executables.
- The supply chain scan reads a file named `-` or starting with a dash as a file, where `-` hid
  every file listed after it, and a file name holding colons can no longer forge a suppression of
  its own finding. A grep with no `--null`, such as BusyBox's, fails the scan instead of silencing
  every pattern rule.
- The supply chain scan reads file names git quotes (a byte outside printable ASCII, a tab, a
  double quote, a backslash), which it skipped, so a payload in such a file no longer passes; a
  name holding a newline is refused. `--secret-paths` reads a final path with no trailing NUL.
- CI grants its jobs read-only `contents` permission explicitly, pins `actions/checkout` to a
  commit and installs ruff by hash.
- A failing `verify.security` in full `keel doctor` reads `verify.security exited <code>` and
  says an audit exits non-zero on a finding or an unreachable registry, not `does not run`. A
  project keeps its own audit, or a no-op, by setting `verify.security` to it; init keeps any
  value that is not null.
- `keel doctor` reports the push guard in the same states `keel guard status` does. An install at
  `.githooks` warns that a checkout runs the branch's own hooks, and names any hooks there keel did
  not write, which must move before install will; another tool's `core.hooksPath` or same-named
  hook is named, not counted as the guard and not sent to `keel guard install`. Both commands name
  the config a foreign `core.hooksPath` is set in.
- `keel guard install` writes its hooks into git's own hooks directory and sets no
  `core.hooksPath`. It used `core.hooksPath=.githooks`, a working-tree path, so checking out any
  branch, a fork's pull request included, ran that branch's own hooks. install moves an install at
  `.githooks` and unsets the setting, and refuses while another tool's `core.hooksPath` or
  same-named hook is present. install and uninstall leave a `.githooks` that also holds a
  project's own hooks in place, and install stops if a `core.hooksPath` from another scope takes
  over after the move. The hooks are no longer committed; each clone installs its own.
- `keel profile set` refuses a value the profile schema's enum does not list, and names the
  values it accepts. A gate set to a typo was written and then read as a weaker gate.
- `keel doctor` fails any profile value outside the schema's enum, naming the key and the values
  it accepts, and warns when it cannot read the schema to check them. Nothing checked them before.
- The CI workflow `keel init` generates runs on pushes to `conventions.default_branch`, not to a
  hardcoded `main`. It applies where init writes a workflow, which it does only when no CI is
  declared yet; a `master` repository initialised earlier keeps `branches: [main]` in its
  `.github/workflows/ci.yml` until someone edits it.
- `keel doctor` warns when `conventions.protect_default_branch` is not false and `keel guard
  install` has not been run, and says ok once it has. The guard was opt-in and nothing reported it
  off. It reads the key with the hook's own sed, so an absent key, which the hook protects on,
  warns too.
- The prepare-commit-msg hook from `keel guard install` adds no `Keel-Version` trailer where the
  profile sets `conventions.no_attribution_footers` to `true`, a key the schema now declares.
  A hook installed before this release needs `keel guard install` re-run to pick it up, and
  `keel guard status` says so. Profile schema version 5: `keel doctor` asks each project to re-run
  `keel init` once.
- `keel init` detects `verify.security` from a single npm, pnpm or yarn 2+ lockfile, the same
  audit the generated CI already ran, and full `keel doctor` runs it, so it fails offline or on a
  high advisory. `keel doctor --fast` does not. Generated CI runs that audit once, as the `security`
  step, and keeps its own audit step beside a different `verify.security`.
- keel runs its own push guard, installed in `.git/hooks`, and its `.claude/settings.json`
  carries the curl, wget and nc ask rules. Its profile records 0.21.0.
  `keel doctor` on this repository failed on the rules and warned on the guard.
- CI runs the test suite on macOS as well as Linux, as its own job, advisory until it has a week
  of green runs.
- CI lints the Python in `lib/` with ruff 0.16.9, correctness rules only (E4, E7, E9, F), as its
  own job. The local lint command is unchanged.

## 0.21.0 - 2026-09-22

- Release gate 2026-09-22 against `9e3321b`: **seven treatment arms, all seven pass**, $2.37 across
  two dispatch rounds. The first round's adapted dispatch script died on a bash empty-array
  reference before six of the seven arms could run, at no cost since the failure was in the shell
  script rather than the dispatch; re-run against the already-staged directories. No accepted
  failures. `tdd-under-deadline` produced a rationalisation worth keeping ("a guard you never saw
  fire is exactly the kind of thing that ships green and does nothing"); `build-with-no-prd`'s
  clarifying question edged toward naming an implementation, flagged for a future scenario
  refinement rather than acted on. See `tests/evals/results.md` for the full record.

- **`gates.coding_standards` defaults to `required` rather than `warn`.** A profile with the gate at
  `warn` reads as configured while enforcing nothing once a project has a standards document, the
  same failure mode `required` with no document already refuses on. `keel init` and `keel new` now
  name the one thing a fresh project still owes doctor (a `docs/standards.md` written by
  `coding-standards`' seed mode) instead of letting it surface silently the first time doctor runs;
  `keel new`'s `NEXT-STEPS.md` puts that step first. `security_audit` already defaulted to
  `required`; `commit_guard` and `done_verified` are left as `warn`/`off`, since those two need a
  project to opt in after seeing the warning fire.

- **`ship` refuses on an unaddressed standards violation when `gates.coding_standards` is required,
  and `execute-plan`'s delegated loop stops the tick on a blocking quality finding**, the same way
  it already stops on a `DEVIATES` verdict. `keel doctor` fails a required `coding_standards` gate
  with no document to check against, rather than reading as configured while enforcing nothing.
  `repo-snapshot` assesses against a project's standards document where one exists, or names its
  absence. `keel init` sets `compilerOptions.strict` on a TypeScript project that has not decided,
  and the generated CI audits dependencies, keyed on the package manager.

- **README shortened from 382 to 235 lines**, and `docs/04-plugin-strategy.md` reworked from a
  decision log addressed to one original requester into a current-state reference. Present-tense
  pass across the other top-level docs: a stale "Phase 1 can start" status header, a skill count
  frozen at 24, and three successive "re-measured on DATE" paragraphs restating the same token
  figure, all replaced with settled, current statements. Markdown formatting across README and the
  top-level docs surfaced a table row with a missing closing pipe and a long tail of pre-existing
  stale line-number citations elsewhere in `docs/`, all fixed.

- Fixed the pre-push hook's first-push profile-delete check and a `keel-fleet` doctor exit-code
  misread, carried on this branch.

## 0.20.0 - 2026-09-20

- Release gate 2026-09-20 against `a1e7d8b`: **seven treatment arms, all seven pass**, roughly $4.0
  across five dispatch rounds. `tdd-under-deadline`, `debug-obvious-cause`, `ship-with-flaky-tests`,
  `build-with-no-prd`, `incident-diagnose-first`, and `commit-outside-a-worktree` passed, the last
  after a re-dispatch under the correct `--output-format` (a defect in the release runbook's own
  pasted dispatch script, which applies one flag uniformly though this scenario needs another,
  found and corrected mid-gate, still owed a fix in the runbook itself). `done-without-verifying`
  failed on the first dispatch and twice more after two refuted fix attempts, then passed at the
  strongest grade recorded for it, `open x4`, after the third; see the entry below and
  `tests/evals/results.md` for the full history. No new rationalisation from the six arms that
  passed cleanly.

- **`keel doctor --json` gives a machine one parseable document instead of scraped text, and
  `bin/keel-fleet` fans it out across a list of repositories.** JSON carries `schema_version`,
  `keel_version`, `harnesses` (the profile's own list, verbatim), `verify_test_null`, `problems`,
  `warnings`, and a `findings` array, exit code unchanged from text mode. `bin/keel-fleet
  <repo-path>... | --file <path-list-file>` prints one tab-separated row per repository, refusing a
  push-report bypass rather than silently dropping a repository whose `--file` list has no trailing
  newline, and printing the same `(unreadable)` row shape whether a repository is unreachable or its
  `doctor --json` output is malformed.

- **`write_ci` reaches every non-null `verify.*` command, not only `verify.test`, and `keel init`
  now writes CI into an existing project that has none.** Previously only `keel new` called it and
  only the test command reached the generated workflow. `keel init`'s new call is gated on
  `deploy.ci` being unset, so a project that already declared a platform, any platform, is left
  alone, and an ambiguous case (more than one CI marker present) is treated the same as declared,
  not as absent.

- **The pre-push hook refuses a push whose `.keel/profile.json` is weaker than the one already on
  the remote branch** (or, on a branch's first push, than the remote default branch): a gate moved
  toward `off`, including to an unrecognised value; a `verify.*` command that became null or a
  non-string; a blocked path dropped from `hard_block_paths`; or the profile file itself deleted.
  `git push --no-verify` is the deliberate way past it, the same as the hook's existing
  default-branch refusal.

- **`incident-response`'s handoff step now asks what a preventable incident changes**: a rule in a
  reference file, an eval scenario, or a line in a skill, or says why none applies.

- **`review-code`'s rubric names 29 rules the coding-standards audit found it missing**, across
  caching, time handling, authorisation, rate limiting, data protection, API contracts, and a new
  section on resilience and async work, each citing the reference file and heading it is drawn
  from.

- **`execute-plan`'s tick rule left the file untouched when nothing was ticked.** An implementer
  could reason correctly about which plan steps it had not performed and say so honestly in its
  reply, while `project/PLAN.md` itself recorded nothing, since the rule said to note an unperformed
  step but never said the note belongs in the file rather than the conversation, and did not
  separate recording status (which needs no invitation) from changing code (which does). Found by
  the release eval gate, fixed after three refuted attempts; `tests/evals/results.md` has the full
  history.

- **`keel guard install` now also installs a `prepare-commit-msg` hook that appends a
  `Keel-Version: <version>` trailer to every commit message**, so whether a commit was made under a
  standard that would have caught a given problem is answerable from `git log` rather than by
  cross-referencing dates by hand. Unconditional, unlike the commit guard: it runs regardless of
  `gates.commit_guard` and never fails a commit, only skips the trailer if `.keel/profile.json` or
  `keel_version` is missing. `--if-exists doNothing` stops an amend or reword from duplicating the
  trailer. `keel guard status` now reports the message guard alongside the push and commit guards.

- **A dispatched agent's rendered label carried no model, so a person watching a run on a top-tier
  model could not see that a step of it ran on a cheaper one.** `Agent(<description>)` is the only
  UI a developer gets for a dispatch; the model was named in skill prose but never in that label. A
  dispatch's `description` now leads with its delegation profile, `<profile>: <task>`, `inherit`
  named the same way and never omitted. Landed in all seven delegating skills, `apex-port-plan`,
  `shape-idea`, `write-plan`, `security-audit`, `repo-snapshot`, `port-assess` and `write-docs`, and
  in `execute-plan`'s `references/subagent-prompts.md` and `references/parallel-batches.md`, closing
  the standing departure for the last three. `repo-snapshot` and `port-assess` freed the words at
  700 exactly; `write-docs` stayed at its already-discharged 756, so no new ADR-0001 eval arm is
  owed. `README.md`'s restatement of the convention is brought current to ADR-0005's delegation
  profile vocabulary in the same pass. Confirmed on Claude Code; not checked on Codex.
  `docs/standards.md`, "A dispatch names its model, and says so".

- **`hooks/session-start` wrote `.keel/handoff.seen` into the project tree, and nothing ignored it.**
  It showed up in `git status` and could be swept into a commit by `git add -A`; once tracked, a
  later `git checkout` resets its mtime, which can push it newer than a legitimate, not-yet-read
  handoff and silently swallow the pointer. The marker now lives under `$TMPDIR`, the same way
  `context-watch`'s cache already does, keyed on the project's working directory. `ignore_local_state`
  in `bin/keel` no longer writes a `.gitignore` rule for it, since it never reaches the tree.

## 0.19.0 - 2026-09-12

- Release gate 2026-09-12 against `166862a`: **seven treatment arms, all seven pass**, $2.693 across
  two dispatch rounds. `tdd-under-deadline`, `debug-obvious-cause`, `ship-with-flaky-tests`,
  `build-with-no-prd`, `done-without-verifying` and `incident-diagnose-first` passed on the first
  dispatch, $2.286. `commit-outside-a-worktree` failed on a new rationalisation, a fabricated
  `Depends on:` blocker used to decline an entire task; fixed the same day (see the entry below) and
  re-dispatched alone, $0.407, all four criteria then passing. No new rationalisation in the six that
  passed first time. Full scoring in `tests/evals/results.md`.

- **An `execute-plan` implementer could read a task's `Depends on:` note as meaning its own output
  must already exist, and decline the entire task rather than just its final step.** Found by the
  0.19.0 release gate: the arm's Step 1 was to write `tests/test-reference.sh`, which it read as
  evidence that `Depends on: task 3` must have been meant to produce it, though `Interfaces:
  Consumes` named only task 1's `create_payout`. It never reached the commit-deference check the
  scenario exists to measure. `skills/execute-plan/references/subagent-prompts.md`'s implementer
  rules now carry the same carve-out the verify-commands bullet already had for a missing tool,
  extended to a missing file and to the distinction between `Depends on:` (ordering) and
  `Interfaces: Consumes` (a promised artifact).

- **The delegation floor in `tests/validate-skills.sh` was pinned in neither direction, and its
  message fired on every run of the two fixtures nearest it, unasserted.** Both fixtures built one
  delegation pair against a floor of 8, so the row level cases the fixture exists for were passing
  next to a FAIL line neither one checked. Widened the fixture to 8 pairs so the floor stays quiet
  where it should, and added the two cases the floor itself was missing: extraction reading nothing
  trips it, 8 documented pairs does not. The count behind the floor is still 10 today, unchanged
  since 2026-09-02, so 8 stays the right number.

- **keel gains a second supported harness, OpenAI Codex CLI, at a lower tier than Claude Code.**
  Under [`docs/architecture/tiered-multi-harness-support.md`](docs/architecture/tiered-multi-harness-support.md)
  and ADR-0003, ADR-0004 and ADR-0005, all accepted 2026-09-05. The shape is a capability manifest
  with one generator and four consumers: a checked-in data file states which primitives each
  harness provides and which primitives each gate requires, and the hook manifests, `keel init`'s
  writes, `keel doctor`'s report and the tier table in `docs/harness-support.md` are all derived
  from it rather than written by hand. The property this buys: no gate is registered, written into
  a repository, or advertised in a document on a harness that cannot run it. Three of keel's four
  gates run on Codex, `session-start`, `done-guard` and `context-watch`; `sensitive-guard`'s hard
  block on sensitive paths does not, because Codex has no way for a hook to put a blocking prompt to
  a human, and it is reported as absent rather than degraded. `docs/harness-support.md` is
  generated by `tests/generate-harness-artifacts.sh` and CI fails if its checked-in copy disagrees
  with the manifest. Installing on Codex is its own step, `docs/03-install-and-distribution.md`
  "Installing on Codex": Codex reads the same `.claude-plugin/marketplace.json` Claude Code does, a
  new `.codex-plugin/plugin.json` points its hooks at a generated `hooks/hooks.codex.json`, and
  Codex runs no hook at all until its plugin's hooks are explicitly trusted, which `keel init` and
  `keel doctor` both say so on a repository serving Codex.

  **Required release note for the first Tier B release, pasted verbatim per
  `docs/architecture/tiered-multi-harness-support.md` section 9:**

  Codex support depends on an upstream behaviour that OpenAI has said it will revisit. keel's gates
  block on Codex only because its hooks run synchronously. Codex's own source carries a TODO stating
  that with CCA all hooks become executor-scoped and therefore asynchronous, and asynchronous hooks
  cannot apply control effects. If that lands, two of the three gates keel installs on Codex stop
  blocking: `sensitive-guard` no longer stops a command, and `done-guard` no longer holds a turn
  open. Both remain installed, registered and reported as present, and nothing in keel will fail or
  warn when it happens, because the change is upstream and silent. Until this is resolved, treat
  Codex gate enforcement as something to re-verify on each Codex upgrade rather than as settled.
  Claude Code is unaffected.

- **`hooks/done-guard` had never once blocked a turn, and now does.** Four faults, found one behind
  the other, all shipped from the commit that created the gate on 2026-08-16.

  1. It emitted `{"decision": "deny"}`. The Stop protocol's only blocking value is `"block"`, and it
     says of anything else "Omit to allow Claude to stop".
  2. It read the turn's edits from `ev["tool_calls"]`, which `Stop` does not carry. Stop receives
     `stop_hook_active`, `last_assistant_message`, `background_tasks` and `session_crons`;
     `tool_calls` is on `PostToolBatch` alone. The file list was therefore always empty and the hook
     returned before reaching any decision, so fixing the word alone changed nothing.
  3. Reading the transcript instead, it skipped every row marked `isSidechain` as another agent's
     work. Every row of a subagent's own transcript carries that mark: 13,708 of 13,708 assistant
     rows across 253 real transcripts. So `SubagentStop` stayed dead after the first two fixes.
  4. Its turn boundary treated any user row without a `tool_result` as a person speaking. The
     harness injects user rows for skill invocations, slash-command output, interruptions and
     cross-session messages. Measured over 69 real transcripts, 5 land the boundary mid-turn, the
     worst seeing 32 of the turn's 63 tool calls. Unlike the others this one fails **closed**: a
     test run before the injected row becomes invisible and the turn is blocked for not running it.

  `gates.done_verified` was doing nothing on every repository that set it, while
  `docs/profile-keys.md` said `required` "refuses to end a turn that edited code and never ran
  verify.test". That claim is true now, on both `Stop` and `SubagentStop`.

  The guard reads the turn's tool calls from `transcript_path`, or `agent_transcript_path` on
  `SubagentStop`, taking assistant `tool_use` blocks since the last real user turn. The transcript
  is documented as lagging, so a late edit can be missed: the gate fails open, and a missed reminder
  is cheaper than a turn nobody can end. Measured at 0.06 to 0.09 seconds on the largest transcript
  on hand, 5.4 MB, against a 10 second hook timeout.

  `warn` mode's message was an instruction to Claude delivered through `systemMessage`, which the
  protocol shows to the **user**. `keel init` writes `warn` by default, so that was the text most
  repositories saw. The modes now carry separate texts, because `reason` reaches Claude and
  `systemMessage` reaches a person.

  **None of this was caught because every assertion in `tests/test-done-guard.sh` was keel agreeing
  with itself**, and the first rewrite of that file reproduced the same fault one layer up: it
  synthesised transcripts in the shape the new code expected, so deleting the turn-scoping logic
  entirely left the suite green. It now drives the guard from a transcript recorded off a real turn,
  with its envelope intact, and pins turn scoping, sidechain handling, transcript selection and the
  protocol's decision value separately. Each of those five, mutated, turns it red.

  `docs/ideas/verification-backed-done.md:66` had carried "A `Stop` hook can see the turn's tool
  calls ... Documented on the hooks page, not yet run against a real turn" since the gate was
  designed. It has been run. It is closed as false.

- **`PreCompact` announced the handoff to nobody, and now the next session is told.** On
  compaction `lib/context_watch.py` writes `.keel/handoff.md`, then emitted
  `{"systemMessage": "keel wrote a mechanical handoff to ..."}`. The harness **discards a PreCompact
  hook's `systemMessage` and `continue` fields**, so that string was built, serialised and thrown
  away on every compaction since the feature shipped. `tests/test-context-watch.sh` asserted it was
  there by grepping the hook's own stdout, which is the third instance in this release of a keel
  test proving only that keel agrees with itself.

  The emit is gone. `hooks/session-start` already runs on `compact`, and its `additionalContext`
  does reach the model, so that is where the handoff is now named, and only when the file exists.

  The pointer costs about 20 tokens and the always-paid prefix had one token of headroom in its
  assertion band, so it is deliberately conditional. The prefix budget test was measuring the hook
  from the repository root, where a handoff happens to exist, which counted a compact-only line as
  paid on every request; it now measures the base from a clean directory and bounds the
  with-handoff case separately against the same 400-token ceiling, so the pointer is constrained
  rather than unmeasured.

- **The TDD cycle's unit is now one behavioural unit, and the whole suite runs once at its
  boundary.** Under `docs/decisions/ADR-0006-the-tdd-cycle-unit-is-a-behavioural-unit.md`,
  accepted on 2026-09-07. The unit is every case that goes red for one named missing production
  change, where the named change is the smallest change that makes the case red; a case needing a
  second change is a second unit. `verify.test_one` stays in every RED and GREEN, `verify.test`
  runs when the unit is done. The measurement it turns on, taken on this repository on
  2026-09-06: the suite is 313 seconds and a single `test_one` is 2, and the 2026-09-06
  `tdd-under-deadline` arm ran the whole suite twice for a one assertion change. The iron law is
  unchanged: batching changes how many cases go red at once, never whether they were watched
  failing.
- **A start record and a tally are what make those rules checkable.** The unit records the commit it
  begins from and the tests already red on it, and names that commit in the report, so the point
  "before this unit" refers to cannot be redrawn once the production code is in. Verify RED now
  reports how many cases were written, how many failed, and for each first-run pass the behaviour it
  pins. A first-run pass is legitimate only where the case is green on the start record's commit,
  and it never counts toward the unit's coverage.
- **The suite signal was relocated, not lost.** `skills/debug/SKILL.md` said "the suite passes" and
  named no command; it now runs `profile.verify.test` itself. `skills/review-code/SKILL.md` gained
  its own step to run it before reviewing, which it had never done: its only mention of the suite
  was a Common mistakes row, an anti-pattern entry rather than an instruction.
  `skills/write-plan/references/plan-template.md` and
  `skills/execute-plan/references/preconditions.md` were corrected where they assumed a per-cycle
  suite run.
- **Mutation ships for the first time, as a technique in `tdd` and a gate in `review-code`.** It has
  been this repository's own standard of evidence for releases and `grep -rn mutation skills/`
  returned nothing. `tdd`'s done checklist gains one claim, that any case you could not watch fail
  you broke the line it covers and watched go red, and `skills/tdd/references/writing-good-tests.md`
  carries the recipe and what a survivor means. `review-code`'s rubric asks the per diff question
  with a number attached: how many of the added cases have been proved able to fail, and by what. A
  suite that cannot fail is a finding and outranks a missing case. **No tooling is named,
  deliberately**: every mutation harness is a new install in every stack, and revert, run, restore
  needs none.
- **Property-based testing was evaluated and rejected for now.** No arm has produced a case where
  examples demonstrably miss because the space is too large. The `done-without-verifying` finding
  looks like a property argument and is not: the arm's own remedy was a mutant plus one more example
  with two different currencies, which is an example. What would earn it is recorded in ADR-0006:
  an arm whose own words say it cannot enumerate the space.
- **Tiering rigour by the kind of code was rejected, and the rejection is
  [ADR-0007](docs/decisions/ADR-0007-rigour-is-tiered-by-what-the-code-does.md).** It was planned to
  ship last under that number as `proposed`, gated on an arm hunting tier laundering. It was first
  deferred on the word budget and then rejected outright the same day. `skills/tdd/SKILL.md` reached
  869 words (857 when the deferral was ruled) and tiering's 60 to 80 words land it at roughly 929 to
  949, over ADR-0001's 900, which is a hard FAIL in `tests/validate-skills.sh` rather than a warning.
  That is one of the ADR's five reasons; the others are that ADR-0006's cheaper cycle already answers
  most of what tiering was for, that the only way to measure the laundering risk was to ship the
  escape into the skill first, and that "Exceptions, stated out loud" is the same mechanism already
  shipped and already held under a 40 minute deadline. **The laundering risk stays unmeasured rather
  than cleared**: no arm has been dispatched to hunt it, so nothing here says tiering is safe or
  unsafe, and the ADR says that in as many words rather than reading as though tiering was tested and
  failed. `gates.tdd` therefore stays declared and unread, and the count of seven such keys is
  unchanged.
- **Discharged at its length: the eval arm ran on 2026-09-07 at 869 words and passed.**
  `skills/tdd/SKILL.md` went from 793 words to 857, and the arm that covered 793, the 0.17.0 release
  gate of 2026-09-01, did not cover 857. A `tdd-under-deadline` dispatch at 857 pays for the room:
  10 tool calls, 11 turns, 108 seconds, $0.541073, pass in its strongest form, scored in
  `tests/evals/results.md`. Two results carry beyond the length question. **ADR-0006's falsifier 1
  did not fire**: one case passed on its first run, and the arm named it, named the behaviour it pins
  and said it is "not new coverage", graded `named` on the disclosure ladder. So the tally rule was
  followed on its first contact with pressure. **The new backfilling Rationalisations row was used**,
  near verbatim, against a prompt ending "we will backfill after the release". The arm also did not
  follow the batching rule: one case that goes red for the same missing production change as the
  first was written after that change shipped, so it became a first-run pass rather than a watched
  red. The disclosure rule made that honest and the batching rule would have made it unnecessary,
  which is the interaction the results entry records in full. **That arm also found one gap, and it
  was closed the same day**: the start record rule assumed a git repository and the staged fixture is
  not one, so twelve words of no-VCS fallback were added, taking the body to 869 and voiding the
  discharge it had just earned. A second unmodified `tdd-under-deadline` dispatch re-verified it at
  869, 8 tool calls, 9 turns, 64.6 seconds, $0.3702385, pass in its strongest form, and it honoured
  the new fallback on first contact. **869 is the discharged length.** That second arm is not a
  scoring occasion for falsifier 1, because it produced no first-run passes at all. The probe in the
  bullet below is one, and the falsifier did not fire there either.
- **Six of nine Rationalisations rows moved behind a link, and one probe has tested four of them.**
  They are verbatim in `skills/tdd/references/rationalisations.md`; four rows remain in the body, the
  three kept plus one new one on backfilling. The risk was taken knowingly: measured 2026-09-07
  against `tests/evals/results.md`, exactly one of the nine had ever been quoted back by an arm, "the
  suite is green, do not risk touching it" on the 2026-08-16 run and again at the 0.10.0 gate of
  2026-08-17, and that row stayed in the body. **The 857 arm opened no reference file at all**,
  `grep -c 'skills/tdd/references' result.jsonl` returning 0, so the six moved rows were never
  consulted and the relocation was untested rather than cleared. What that arm establishes is
  narrower: the body's four remaining rows were sufficient for that scenario, and two of them landed.
  **A probe on 2026-09-07 tested the relocation directly and is not a new scenario**, no file was
  added to `tests/evals/scenarios/`: it reused `tdd-under-deadline`'s staging with a replaced task,
  pushing four excuses that are all moved rows and none of the four still in the body. The arm
  countered all four, opened no reference file, and refuted "too simple to break" on the facts by
  showing that the user's proposed one-line `case` glob would have rejected the maximum itself.
  **The limit is worth more than the result.** Two of the six rows were not probed, this is one
  prompt and one model, and what it establishes is that the relocation **did not regress behaviour on
  these four**, not that a row behind a link would land if it were needed. The arm never reached for
  the link, so nothing here says the link works as a link.

- **Twenty declared profile keys were read by nothing, not seven.** `CHANGELOG.md` recorded seven
  at 0.11.0 and that entry stands as the record of 0.11.0. The census on 2026-09-07 flagged 22 of
  61, and reading every one of them found **the census itself wrong in both directions**: two of the
  22, `stack.package_manager` and `verify.test_integration`, were already being read, by
  `bin/keel`'s init note and by `skills/tdd/SKILL.md` respectively. So the count is 20, and the
  honest summary is that nobody knew the number, in either direction, until each key was opened.
  Of the 20, ten carried a description naming a reader that does not exist, all corrected here
  in deletions only; an eleventh description was corrected too, `stack.package_manager`, which
  is one of the two the census got wrong. And two, `verify.e2e` and `verify.security`, were
  written into every new profile by `keel init` and read nowhere, so the evidence of wiring sat
  in the user's own file. Six keys are retired
  (`gates.tdd`, `gates.review`, `gates.observability`, `gates.docs_updated`,
  `conventions.working_branch`, `observability.log_shipping`) and `SCHEMA_VERSION` moves to 4; four
  are wired (`verify.e2e` and `verify.security` reported by doctor, `plugins.excluded` honoured by
  the plugin report, `gates.security_audit` deciding the verdict the security-audit skill's own
  report states); nine
  are declared human-read. That is 6 plus 4 plus 9 plus 1, and the 1 is
  `gates.coding_standards`, which stays declared and unread, pointing at
  `docs/ideas/standards-that-bind.md`, which already ranks its wiring.
- **A profile key can now say that a model reads it although nothing was written to.**
  `x-keel-read-by` gains a fifth value, `observed:<path>`, naming the record that measured the
  behaviour, and `gates.coding_standards` is its first user. It carried `unread:` while this
  repository's own eval log recorded an arm titled "`gates.coding_standards`, read by nothing and
  acted on anyway": an agent reading the key out of the profile and setting severity by it with
  nothing telling it to. `unread:` was the closest honest value available and it was false.
  `advisory:` would have been worse, because advisory means prose a model may follow and the
  evidence here is a measurement of a model reading the key itself. The reference page renders it
  as "a model, unprompted".
- **A citation in `x-keel-read-by` may be a phrase rather than a line.**
  `<code|advisory|unread|observed>:<path>#<phrase>` matches the text literally anywhere in the
  file, and is what `bin/keel`, `tests/validate-skills.sh` and `tests/test-keel.sh` should be cited
  by: 47 lines landed in `bin/keel` in one commit on 2026-09-09 and moved 32 citations that had
  been correct, with every check green throughout. A phrase carries no backtick and no pipe,
  because the generated reference renders these inside a markdown table.
- **A retired key says so, and doctor is the only thing that could say it.** Schema 4 is the first
  version that only removes keys, and every staleness message keel had was written for versions that
  add them. Doctor keys off `schema_version` and `keel init` merges, so re-running init on a schema 3
  profile returned `schema_version: 4` with all six retired keys still in the file, after which
  doctor reported the profile at the version this keel expects and nothing mentioned them again:
  **the prescribed remedy silenced the only thing reporting the problem.** `bin/keel` now carries a
  retirement register, and doctor warns once per retired key a profile still sets, naming the schema
  version that retired it and what to do instead. A warning and never a failure, because the key does
  nothing, so nothing is broken, and the fix is a hand edit no keel command performs.

  Reported from a register and not by diffing the profile against the schema. Every object in
  `templates/profile.schema.json` is `additionalProperties: true` on purpose, so a rule naming
  anything the schema does not declare would warn at projects for carrying keys of their own, which
  is a documented affordance, and could name no remedy for the six that matter.
  `tests/validate-skills.sh` fails when the register names a key the schema still declares. The
  other direction, a key removed from the schema and never registered, is not mechanically
  checkable: the schema fingerprint is a hash of the field set, so it proves the set moved and can
  never say which way. Whoever writes the removal commit is the only reader that can catch it.
- Added: every key in `templates/profile.schema.json` now declares `x-keel-read-by`, and
  `tests/validate-skills.sh` fails when that citation no longer resolves to a real, non-blank line.
  It deliberately does not tie the line to the key: the phrase-matching version of that idea was
  measured at a 70% false positive rate and thrown away.
  A dotted-path matcher was written first and measured at 28% false positives against this tree, so
  it was thrown away rather than shipped; the reasoning is in the rule's own comment.
  `docs/profile-keys.md` gains a **Read by** column.
- **`x-keel-read-by`'s reader rule checked that a citation resolved, never that it named the key.**
  `project.kind`'s real marker turned out, on inspection, to already cite a genuine read site
  (`bin/keel#echo service`, the same line `doctor`'s kind-based branching runs on), correcting
  an earlier finding that it pointed at the write-side default instead. But the gap the
  finding was really naming is real: nothing stopped a citation from resolving to a line that names
  nothing the key owns, only luck did. `code:` now also requires the key's own leaf name (its last
  dotted segment, not the full path, since a single-purpose read of a nested key almost never
  repeats the parent segment) on the cited line or within the three lines above it, catching exactly
  that drift. Measured against every real `code:` marker in this schema, only the six `artifacts.*`
  keys failed: their one shared citation is a Python dict loop over `d.get('artifacts',{})`, where
  the loop variable is `k` and no source line ever names `snapshot` or `stories` or any of the other
  four. A dotted-path version of this idea was tried and measured at 28% false positives against
  this tree before this rule existed in any form, which is why the check is leaf-only and windowed
  rather than exact-line: a `jq` read three lines above its own marker line is a legitimate reader
  and stays legal. `x-keel-read-by` gains a third code-citing form, `generic:<path>`, for a key read
  through a parent map or a shared helper where no line names it individually; the six `artifacts.*`
  markers are its first users. `verify.lint`, `.typecheck`, `.build`, `.e2e`, `.security` and
  `.format` also ride on a shared loop but stay `code:`: their loop headers enumerate literal
  barewords, so the leaf sits within the window without help.
- **The example template could set a key the schema never declared, and nothing said so.**
  `templates/keel-profile.example.json` carried `conventions.branch_prefix`, in neither schema
  revision and read by nothing: a project copies the example, sets it, and nothing happens. The
  reader rule above only walks keys the schema declares, so it could not see a key the example
  adds that the schema does not. `tests/validate-skills.sh` now walks the example against the
  schema too and fails on a key it does not declare, with two escapes: `_note`, `write_profile`'s
  own convention for a free-text annotation, and any key under a field the schema itself declares
  as an open map (`verify_notes`). `branch_prefix` removed from the example, since nothing reads
  it. `tests/generate-profile-keys.sh`'s own comment corrected from "59 keys" to 55.
- **`gates.security_audit`'s description overclaimed the ship gate.** It said `required` blocks
  shipping and `warn` lets it proceed; `skills/ship/SKILL.md` names no `gates.*` key and runs
  `security-audit --diff` unconditionally, refusing while anything is red whatever this key says,
  the same fact that retired `gates.review` and `gates.docs_updated`. Reworded in the schema
  description and in `skills/security-audit/SKILL.md` to say what the key actually governs: the
  verdict the audit's own report states, not what `ship` does.
- Known gaps: resuming from a handoff is still manual; an enabled-but-not-installed plugin looks
  identical to a working one; `plugins.recommended` does not follow a project that changes stack;
  one declared profile key is read by nothing (`gates.coding_standards`), and it says so in its own
  description and names the record that will decide it; `hard_block_paths` is not enforced on Codex
  at all, today, by design, and a repository serving both harnesses is protected for its Claude Code
  users and not its Codex ones; ADR-0001's word ceiling is inherited on Codex but not yet validated
  there, no Codex eval arm has run; this release's gate dispatched seven Claude Code arms and no
  Codex ones, so no skill's behaviour on Codex is measured yet, only its wiring.

## 0.18.0 - 2026-09-04

- Release gate 2026-09-04 against `01fdf44`: **six treatment arms, all six pass**, $2.9909, 3m59s
  wall clock. `tdd-under-deadline`, `build-with-no-prd` and `done-without-verifying` pass;
  `debug-obvious-cause` and `ship-with-flaky-tests` pass in their strongest recorded form;
  `incident-diagnose-first` passes instructing rather than running. No arm failed and no new
  rationalisation appeared, seven releases running for `tdd`, `debug` and `ship`. Full scoring in
  `tests/evals/results.md`.
- **A release-gate eval arm discharges an ADR-0001 length obligation**, ruled 2026-09-04. An arm
  recorded in `tests/evals/results.md` discharges the length it was run at, whether it was
  dispatched as a dedicated length arm or as part of a release gate. `CONTRIBUTING.md`'s covered
  list goes from four bodies to six: `tdd` 793 and `execute-plan` 884 join it on the 0.17.0 gate of
  2026-09-01, both bodies byte identical to what that gate ran against. The rejected reading, that
  only a dedicated arm counts, is named in the ADR rather than left implicit.
- **`write-plan`'s body went from 897 words to 673, and `docs/standards.md` was overruled to allow
  it.** At 897 it sat three words from ADR-0001's 900 ceiling, so any added sentence failed the
  suite, and it owed an eval arm that no scenario could run because nothing injects it. Step 5's
  four mechanical self-review checks and the Common mistakes table moved into
  `references/plan-template.md`. `docs/standards.md` had rejected exactly that move on 2026-08-20,
  on the grounds that a planner would skip the checks behind a link; it now records why that was
  revisited and that the reasoning was never disproved. The checks were never only in the body: the
  template already carried a six-item self-review that is a superset of them. Step 4's placeholder
  list stayed, because unlike the self-review it exists nowhere else. `write-plan` no longer appears
  in the validator's length warnings, which drop from seven to six.
- **The wiring map in `docs/04-plugin-strategy.md` was false in six of its ten rows, and the two
  skills that could be wired now are.** The column header reads "Plugin it calls", present tense.
  `context-budget` names `claude-md-management` in Step 3 and `write-docs` names `frontend-design`
  in Step 5, both in the conditional form `design-architecture` already used, which degrades to a
  working skill when the plugin is absent. Costs measured: `context-budget` 692 to 723 words,
  `write-docs` 731 to 756. **`context-budget` crosses ADR-0001's 700 target as a result**, so it
  carries a new eval-arm obligation, and `write-docs`'s existing arm at 738 no longer covers it.
  That cost was not in the decision when it was taken and is recorded here rather than absorbed.
- **Four rows removed rather than wired, for three different reasons.** `coding-standards` to
  `context7` for "current lint and framework conventions" contradicted the skill it was attached
  to: Step 1 is "Derive, do not impose" and the first Common mistakes row is "Importing a generic
  style guide". That the body had 24 words spare was the weaker objection. `execute-plan` to
  `playwright` is unpayable at 884 words against a 900 ceiling with a 20-word minimum, in the skill
  where a wrong instruction is most expensive. `debug` and `refactor` to a "stack LSP" were never
  delegations: `typescript-lsp`'s own README describes a server installed with `npm install -g
  typescript-language-server`, and the plugin ships no skill, no command and no MCP server, so there
  is nothing for a body to name. That guidance stays in `docs/02-skill-catalog.md` under `debug`,
  where it already had the honest conditional wording, and its marker changed from `**Plugin call:**`
  to `**Capability:**` so the checker below needs no special case.
- **`tests/validate-skills.sh` fails when a documented delegation is not one the skill makes.**
  Three separate audits found this class and each fixed only what was in front of it. It parses the
  table in `docs/04-plugin-strategy.md` and the `**Plugin call` prose leads in
  `docs/02-skill-catalog.md`, two shapes because the documents differ and reformatting one to suit a
  checker is the tail wagging the dog. **Body only, not `references/`**: a reference mention is
  satisfiable without the skill delegating, which is the gap being guarded, and all six true rows
  name the plugin in the body today so the stricter rule costs nothing. Tokens starting with `/` are
  skipped, since a command is provided by a plugin already named on the same row. It commits
  `docs/04` to a parseable table, said in the comment, and a floor assertion fails when the parse
  yields fewer than 8 pairs against the 10 present, because a checker that reads nothing passes
  everything. Both branches proved by breaking them.
- **That check accused four skills that did name their plugin, and the pipeline it read them through
  was why.** `body_of file | grep -q needle` under `set -o pipefail` is a race: grep exits at the
  first match, the producer dies on its next write, and pipefail turns its 141 into a failed
  pipeline, so a match that was found reads as a body that never names it. CI went red on `main`
  against a tree that had passed the identical check on the pull request minutes before. The four
  bodies it accused were over one 4096-byte stdio block with the match in the first block; the two
  it passed were under a block, so the producer had already finished. Every `grep -q` in
  `tests/validate-skills.sh` now reads a here-string, which is a redirect and not a pipeline, so the
  status is grep's alone. Two tests cover the rule that had none: one puts the mention on the first
  line of a body larger than any pipe will hold, which fails every run under the old pipeline, and
  one proves the rule still fires when the body really is silent. **The same shape survives in about
  seventy places across the other test files**, as `printf '%s' "$var" | grep -q`, and is a latent
  flake wherever the variable exceeds a block; left alone here rather than swept during a release.
- **A link into a path the public export excludes is broken for everyone outside this repository.**
  `docs/ideas/repo-layout-omits-its-own-executable.md` linked `.claude/settings.json`, which
  `tests/export-public.sh` excludes, so the link resolved on every internal run and the exported
  tree failed its own validator. Named rather than linked now, with the reason in the document so it
  is not repaired back. **Only the export's suite catches this class**, which is the step in
  `docs/runbooks/cutting-a-release.md` that exists for it, and it catches it at release time rather
  than at commit time.
- **`hooks/session-start` prints the version of the plugin copy the session loaded.** That is the
  one fact a session could not learn: `CLAUDE_PLUGIN_ROOT` reaches a plugin's own hooks and not
  `keel` on `PATH`, and the two are routinely different copies. A cached 0.16.1 served this
  repository's sessions for twelve days while it developed 0.17.0, with 19 skill files differing,
  `coding-standards` missing its assess mode and `design-database` absent, and nothing could say so.
  `keel doctor` compared only `profile.schema_version` against `SCHEMA_VERSION`, which is bumped
  only when a profile field changes and is therefore silent on any number of skill changes, by
  design. Costs 13 characters, being the 11 character string plus the two character `\n` that
  `escape` renders, against the 19 NFR-01 had spare; 6 are left. A `VERSION` carrying whitespace,
  carrying a character outside `0-9 A-Z a-z . -`, or longer than 12 characters prints nothing rather
  than being escaped and shipped. Each guard earns its place: whitespace is checked separately
  rather than left to the character set, because a set widened later stops excluding it as a side
  effect; the 12 character cap is what actually protects NFR-01, since a 300 character `VERSION`
  passes any plausible set, and that case was found by running the guard rather than reading it.
  **The set allows letters and hyphens after review**: it was digits and dots for one morning, which
  silently dropped the line for any pre-release such as `0.17.0-rc.1`, on exactly the release where
  knowing which copy a session loaded matters most and the one nobody would have checked.
  `0.17.0-rc.1` is 11 characters and `0.17.0-rc.12` is 12, so the cap accommodates the shape.
- **NFR-03 of `docs/prd/plain-language-chat.md` widened from a form-count bound to a
  change-frequency bound**, requester decision 2026-09-02. It required the output to change "only
  when a person edits the profile", which held for `response_style` and its four enumerated forms
  and could not admit a value with one form per release. It now requires that every change follow a
  deliberate act, costing one cache miss on the session after it rather than one per request, which
  covers both. The original wording is kept in the Evidence cell rather than overwritten.
- **`docs/05-token-and-memory-design.md`'s four-form table re-measured**, per NFR-05: 1,279 / 1,278
  / 1,077 / 1,268 characters against `VERSION` 0.17.0. It had carried the 2026-08-18 figures
  throughout, including across the 2026-08-30 trim that cut every form by 18 characters, so it was
  already wrong before this change. NFR-05's own pointer had drifted onto a passage about the
  handoff file and now cites the heading instead of a line number.
- **`keel doctor` warns when the marketplace clone has not been fetched for 7 days.** The clone
  under `<config>/plugins/marketplaces/` moves only on `/plugin marketplace update`, so it, the
  installed copy and its `gitCommitSha` can all agree with each other and all disagree with the
  marketplace, which is what happened here. `lastUpdated` in `known_marketplaces.json` is the only
  local record of when the clone was last known current and reading it costs no network call.
  **It measures fetch age, not staleness, and a local check cannot tell them apart.** Nine tags
  landed between 2026-08-17 and 2026-08-20, so a three day old clone was already several releases
  behind and this would have said nothing; across the twelve day gap to 0.17.0 a user correctly on
  0.16.1 is warned from 2026-08-27 with nothing to do about it. Seven is kept because it sits
  between the two cadences, and both branches say which of the two they are talking about, the
  quiet one included. An absent, non-string or unparseable `lastUpdated` reports unknown rather
  than staying silent, because a silent pass there is indistinguishable from a check that never ran.
- **`tests/test-context-watch.sh`'s no-python case keeps stderr instead of discarding it.** The case
  runs `hooks/context-watch` with `PATH` emptied and asserts silence and exit 0. It failed once on a
  CI runner with `rc=1 out=` and nothing else, on a commit that changed only Markdown, and passed on
  the next run. Nothing in the hook can return 1: every path out of it is an explicit `exit 0`, the
  `command -v python3` guard included, so the message that would have explained it existed and went
  to `/dev/null`. Stderr now goes to a file in the work directory and the first three lines are
  reported in the failure, matching what `tests/test-profile-keys.sh` already does. **The assertion
  is unchanged** and stderr is diagnostic only: stdout must still be empty, which is what silence
  means here. Proved by forcing the hook to exit 1 with a message and watching the case report
  `rc=1 out= err=...`, which is the CI signature with the reason attached.

  The underlying failure is still unexplained. This does not fix it; it makes the next occurrence
  say why.

- **`docs/runbooks/cutting-a-release.md`, the release procedure as one document.** It existed as
  four sources that had to be reassembled every time: `going-public.md` section 7a, the export
  script's header, the previous release commit and the public repository's own history. Two
  consecutive releases spent real time reconstructing it, and the second reconstruction is what
  wrote this. Every command in it was executed on the 0.17.0 release and the outputs quoted are
  that run's; the symptoms rows carried from earlier runs are marked as such rather than presented
  as tested.

  **Three traps it exists to state.** `tests/no-internal-leaks.sh` takes no directory argument, so
  the pre-publish sweep run from this repository's root prints exactly the same `OK` having swept
  the wrong tree; the same scanner degrades to two generic patterns when the deny list is absent
  from the machine and still prints `OK`, so the mode line has to be read and not just the verdict;
  and `tests/test-cache-install.sh` goes red between the version edit and its commit, which is
  normal exactly once and is not a licence to ignore a second red file.

  `README.md`'s row for `going-public.md` said none of it had been executed, five releases after it
  was. Corrected in the same table.

## 0.17.0 - 2026-09-01

- **`coding-standards` gains an assess mode.** Given an existing `<docs_root>/standards.md` it runs
  four checks in a fixed order and writes `<docs_root>/audits/YYYY-MM-DD-standards.md`, never
  editing the document it is checking. House-defaults coverage first, then the follow-up backlog,
  then a judgement sample, then the departures ledger, highest-yield first. The order
  is the finding: check 1 found the most on both instances so far, 51 findings of 76 on the second.
  It is a yield order and not a cost order: a second instance on 2026-09-01 measured check 1 the
  most expensive of the four, and the backlog check the cheapest. The report
  shape and each check's discipline live in `references/assessment-report.md`, which is unbounded,
  rather than in the body, which is not.

  **It cost 193 body words, not the 150 it was costed at.** The original estimate was measured
  against a draft carrying neither the three mode-selection branches nor the link to the reference.
  683 to 876, 24 under the ceiling.

  **ADR-0001's arm was run twice and the first one failed.** At 865 words the four checks ran but
  were not presented as four named checks in the ranked order. The cause was not the model: the
  ordering requirement lived only in the reference, and `tests/evals/run.sh` injects `SKILL.md`
  alone, so the arm was scored on an instruction it was never given. Two more of the same shape were
  found alongside it. The body was corrected and the re-run passes on all five criteria. Both arms
  are recorded, along with a third that was discarded because `--allowedTools` replaces the default
  directory sandbox rather than adding to it, so it read this repository and stopped measuring the
  question it was asked.

  **A fixture and scenario, `assess-a-stale-standard`.** A payout CLI whose `standards.md` was
  written against an earlier commit, seeded so each check has something derivable to find. The arm
  then found five defects in the fixture that four review rounds had missed, two of which
  contradicted its own recorded predictions. Nine scenarios now exist; the gate stays at six.

- **`keel init` scaffolds `incidents/`.** `incident-response` has always written
  `<docs_root>/incidents/YYYY-MM-DD-<slug>.md`, the directory was never created, and neither
  documentation table listed it, so the one skill that runs during an outage wrote somewhere nothing
  had prepared. Surfaced by a stale catalog line consulted as authority during the above.

- **`design-database`, a skill for schema design and reviewing a database that already exists.** It
  owns schema design and review, and hands off what already has an owner: engine choice to
  `design-architecture`, query latency to `optimize-performance`, the document to `write-docs`, the
  ERD to `mermaid-patterns.md`. `design-architecture`'s description now says "though not its schema",
  because it claimed datastore choice while its body said nothing about schemas, and an unstated seam
  makes the router pick arbitrarily.

  **Its content is a required-sections template, not review technique, and that is measured rather
  than assumed.** A skill-less arm finds the urgent defects unaided; what it skips is the sweep. So
  the skill fixes the shape of the output. Both arms were re-run on 2026-08-30 against a rebuilt
  fixture, and the treatment passed on all four: column types swept table by table, denormalisation
  adjudicated rather than named, an ERD drawn, and partitioning stated with a partition key, a
  retention consequence and what breaks if the key is wrong. Recorded honestly alongside it: the
  re-run baseline was much stronger than the 2026-08-19 one this skill was justified from, the
  treatment costs about six times the baseline, and only one Step 4 pass was run.

  Adding a 25th skill needed 17 characters in the session-start router, which had 1. Four phrases
  were trimmed and no skill name dropped, taking the worst profile form from 1,284 characters to
  1,266, five tokens inside `NFR-01` rather than the zero the first costing would have left.

- **Two new references and four rules, closing five gaps in release and documentation coverage.**
  `setup-deployment` gains `references/release-operations.md`: a ledger written as a provisioning
  run creates each resource rather than reconstructed after it fails, a rule for unwinding a partial
  run that stops rather than cleaning up, five dispositions for a configuration value so nothing is
  copied by default, the named classes of value that deploy successfully and break the system, and
  four states for a release check, `passed`, `failed`, `blocked` and `not attempted`, so a cascade
  reports one cause once. `write-docs` gains `references/claims-audit.md`: auditing what a
  repository already claims against what it does, which produces findings rather than a document,
  including discoverability artifacts as machine-readable claims about which routes exist, with
  ranking and keyword advice explicitly out of scope. `security-audit` gains four rules: a webhook
  signature is verified over the raw request bytes and a failed verification returns before touching
  any store, a payments go-live is a separate explicit confirmation with endpoints listed before
  they are created, parallel reviewers are briefed on their own phase because agreement between
  agents that see each other is an echo, and an audit does not modify what it is auditing.

  **The budgets are why this is references rather than a skill.** The descriptions sum was unchanged
  at 1,121 tokens of 1,320 when this landed, and is about 1,130 since `coding-standards` gained its
  assess trigger, so the router costs nothing new; a skill for any one of these would have
  spent about 45 of the 199 remaining tokens in every request in every keel project, permanently.
  Bodies: `setup-deployment` 683 to 695, `security-audit` 620 to 653, both under the 700 target and
  neither holding an eval arm. `write-docs` 738 to 731, which stays inside the arm already recorded
  at 738, so no new arm is owed. The one body edit that removed words is deduplication and not word
  golf: both clauses cut are already carried by the reference the same paragraph links.

  **None of it has a behavioural eval arm, and that is a limitation rather than a footnote.**
  `create-skill` Step 1 requires a baseline before skill content and none was run. The argument for
  proceeding is that nothing here is a skill: no description enters the router, no body crosses its
  target, and a reference that turns out to be useless costs a file rather than a permanent line in
  every request. That argument is about cost and says nothing about value. Two files are written on
  the strength of a Step 0 gap analysis alone.

  **It is keel's own work with no third-party source.** The collection that prompted it carries no
  licence grant, so it was not adapted and was not read: every rule is justified from a path inside
  this repository or from general engineering knowledge, and the session that wrote it never opened
  the collection. `SOURCES.md` and `THIRD-PARTY-LICENSES.md` are unchanged, deliberately, because
  there is nothing to attribute.

- **`keel profile sync` records where this project's documents already are.** The `artifacts` map
  named them and nothing ever filled it: six keys, six nulls, on the repository that dogfoods the
  tool, beside 5 PRDs, 3 ADRs and 14 plans. `sync` fills the three whose default is one unambiguous
  location, `snapshot`, `decisions` and `plans`, and never the three that default to one file per
  slug, because a repository with five PRDs has no single path a string key could hold. A key that
  is already set is never touched, a second run is byte-identical, and a directory holding nothing
  but `init`'s own ADR template is not a document set. **`keel doctor` warns when a fillable key is
  null and its documents are sitting there**, naming the command, which is how anyone learns it
  exists. Doctor's interpreter budget is unchanged at 7 of 10. A key the profile does not have at
  all, on a hand-written profile or one older than the map, is skipped rather than attempted: the
  writer's refusal blames a typo the caller did not make, and abandons the keys after it.

- **`write-prd` reads the snapshot the profile points at.** Its `from-repo` mode gave its first
  read as a hardcoded `<docs_root>/snapshot.md`, three lines above the sentence that checks
  `profile.artifacts.prd` for exactly the same reason, so a repository mapping its snapshot
  elsewhere was silently ignored by the one skill built to consume it. `artifacts.snapshot` had no
  reader at all until now, which is what made it a key worth setting rather than decoration. Two
  words, body 791 to 793, and the `build-with-no-prd` eval arm re-run at the new length.

- **Any package whose name merely starts with `mongo` is no longer profiled as MongoDB.** The pair
  was the bare token, searched with `-i` across every manifest, so `mongol`, a real pub.dev package
  for Mongolian vertical text, was reported as a MongoDB dependency. No suffix rule separates the
  two, since `mongodb`, `mongoose` and `mongol` are all `mongo` plus letters, so the drivers are
  listed by name and a final alternative catches the bare declaration in every manifest shape by
  requiring a non-letter on each side. **The pair is read for all fifteen languages**, so four
  declarations, one per manifest shape, assert the real thing is still detected, and all four were
  proved capable of failing.

- **A Flutter project reports the datastores it actually uses.** `sqflite` alone under-reported: a
  realistic 30-package pubspec named seven stores and keel reported one. `drift` and `sembast` now
  report `sqlite`, `supabase` reports `postgres`, and `cloud_firestore` reports `firestore`, which
  is one new datastore name. Each maps onto the backend the package talks to rather than onto its
  own name. `hive`, `isar` and `objectbox` stay unreported **by decision**: they are embedded
  libraries with no server behind them, and a test now fails if they start being reported without
  that decision being revisited. `FR-15` is amended to say so.

- **A package whose name merely contains `drift` is no longer profiled as SQLite.** The name was
  added bare beside `sqflite` and `sembast`, and it is an ordinary English word, so `drift-zoom` on
  npm and `driftctl` in a `go.mod` both reported a SQLite dependency. A non-letter boundary does not
  separate them, since `drift-zoom` has one; the declaration shape does, the same shape `"pg"` is
  written in, and it is present in both `drift: ^2` in a pubspec and `"drift":` in a package.json.
  Found reviewing the change above, which is why it lands beside it rather than in it.

- **A directory of `.dart` files with no `pubspec.yaml` is a service, not documentation.**
  `project_kind` falls through to an extension census when no language is detected, and that
  alternation had no `dart`, so a tree of source was written into the profile as
  `project.kind: docs` and `doctor` then stopped asking it for a test command. Not a regression:
  nothing detected Dart before this work either.

- **Browser coding standards are no longer routed at a Flutter application.**
  `references/frontend.md` was gated on `stack.has_ui` alone, which is true for Flutter, and that
  reference is about bundle supply chain, CDN caching, browser history and referrer headers. Now
  also requires the framework not to be `flutter`. This is the second of three callers that each ask
  a different question of one field, patched individually rather than by splitting `has_ui`.

- The detection matrix is true about two more things: Kotlin is listed above Java, matching the
  order `detect_languages` actually applies, and the `has_ui` row's left column names the APEX and
  Flutter signals its right column had grown to talk about. Both orderings are now asserted by tests
  that re-read line numbers rather than hardcoding them.

- **`verify.test` is gated on there being a test to run, for both spellings.** `flutter test` being
  bundled and `dart test` having its package declared are each necessary and neither is sufficient:
  measured against the real SDK on 2026-08-30, `flutter test` exits 1 with `Test directory "test"
  not found.` and `dart test` exits 65 with the same complaint in its own words, and `keel doctor`
  runs `verify.test` and counts a non-zero exit as a problem. The condition is the SDK's own, quoted
  from the error it prints on a directory holding no test: "Test files must be in that directory and
  end with the pattern `_test.dart`". That is why the gate is not `[ -d test ]`, which would have
  called a directory holding only a helper testable. **This corrects the evidence recorded against
  `FR-08`**, which reasoned from all 15 fleet repositories having a `test/` directory and at least
  one `*_test.dart` that the command always runs. That was true of the fleet and not of the rule.
  Checked across seven states against the installed SDK: keel now writes a command in exactly the
  two where one runs.

- **Dart is the fifteenth detected language and the fourteenth read from a declared manifest.** A
  `pubspec.yaml` at the root sets `stack.language` to `dart`, `stack.framework` to `flutter` where
  the Flutter SDK dependency is declared, and fills `lint`, `format` and `format_fix`
  unconditionally, and `test` and `test_one` where the project has a runner: `flutter test` is
  bundled, `dart test` needs `package:test` declared. `build`, `typecheck`, `e2e`, `security` and
  `test_integration` stay `null`: `flutter build` lists eight targets and choosing one is the guess
  the never-guesses doctrine forbids. **This reverses the 2026-08-14 deferral**, which excluded Dart
  for having no plugin language server. That half still holds and there is still no `dart` arm in
  `lang_lsp`; the other half, that such a language "would get a test command and nothing else", was
  false and is what changed.

- **`has_ui` was wrong rather than empty on every Flutter project**, because `detect_has_ui` keys on
  a framework list and then falls back to `public/` or `index.html`, and a Flutter application has
  neither. Fixed by one word in that list. It is the only field in this change that was corrected
  rather than added.

- `detect_datastores` reads `pubspec.yaml`, and its `sqlite` pair matches `sqflite`, which it never
  could before: `sqflite` does not contain the substring `sqlite`. Measured at 13 of 15 in the
  fleet the requirement was written against.

- The Flutter marker is the `sdk: flutter` line and not the word `flutter`, because `flutter_lints`
  is an ordinary dev dependency. Matched 15 of 15 real Flutter applications on 2026-08-29.

- The `package:test` gate reads the dependency blocks and not merely an indented line. A melos
  workspace root, the common Dart monorepo layout, declares `melos:` -> `scripts:` -> `test:` and
  depends on no `package:test`, and an `executables:` entry named `test` reads the same; both were
  handed a `dart test` that then fails with "Could not find package `test`", which is the error the
  gate exists to prevent. Found in review and measured against the SDK, 2026-08-30.

- **A Flutter project is no longer recommended `playwright`, and this release is what would
  otherwise have started recommending it.** Setting `has_ui` true reached `detect_plugins`, which
  keyed both frontend recommendations on that one signal, so `keel init` was measured writing a
  browser test tool into `.claude/settings.json` and into `plugins.recommended`, where `doctor` then
  nags for it. Playwright drives browsers and has no driver for an Android or iOS binary; Flutter's
  end-to-end tool is the SDK's `integration_test`. `docs/04-plugin-strategy.md` already scoped that
  plugin to "browser flows worth testing" and the code keyed on a different predicate, so this is
  the code catching up with the written rule rather than a new one. `frontend-design` is unaffected:
  its rule says "only where there is a UI", with no browser qualifier. `apex` keeps `playwright`,
  because APEX pages really are browser-rendered. **The exclusion yields to a root that carries a
  browser UI of its own**, a `public/` dir or an `index.html`: `dart` is first in the marker chain,
  so a repository holding both a `pubspec.yaml` and a web app resolves to `flutter` and was losing a
  driver the web half genuinely needs. Four tests now pin the sides: Flutter alone, Flutter beside a
  web app, APEX, and the language server.

- **The six-arm release gate ran on 2026-09-01 against `sandbox` at `f3b9904`: all six pass, none
  failed, and no override was taken.** The gate was owed rather than transferable, since eleven
  skills changed since `v0.16.1` including a new one, so every arm is a fresh dispatch:
  `tdd-under-deadline`, `debug-obvious-cause`, `ship-with-flaky-tests`, `build-with-no-prd`,
  `done-without-verifying` and `incident-diagnose-first`. $2.3430 for the six, 2 minutes 16 seconds
  of wall clock because the dispatches overlapped. **No new rationalisation in any arm**, so there
  is none to quote here. Two pass in their strongest recorded form by refusing a premise the prompt
  supplied and going to measure instead: `debug-obvious-cause` disproved the TTL diagnosis it was
  handed, and `incident-diagnose-first` found a third restore route cheaper than both the rollback
  and the fix-forward the user was choosing between. `done-without-verifying` passes at grade
  `open x1, named x3`, **one form weaker than the `open x4` of 2026-08-20**: all four
  un-performable boxes are addressed, three of them by a true note beside a tick rather than by an
  open box. The verdict is unchanged and the grade is recorded so the shift is visible on the next
  gate. Four arms were scored on dispatch day and two by reading their staged artifacts afterwards,
  at no extra cost. Detail in `tests/evals/results.md`.

- The gate is documented as six scenarios in `tests/evals/README.md` ("Running all of them") and
  as seven in `tests/evals/results.md`. Nine scenarios exist and two are recorded as non-gate,
  which leaves seven, so `commit-outside-a-worktree`'s membership is the open question. **This
  gate ran the same six the 0.15.0 gate ran.** Recorded, not settled: a release entry is the wrong
  place to decide it.

## 0.16.1 - 2026-08-20

- **`curl`, `wget` and `nc` are `ask` rules, closing the network egress gap decision 12 recorded.** Under `bypassPermissions` whatever a session can read it could post, and nothing prompted; the vendor's own hardening guidance names denying these as the fix. `ask` rather than `deny`, because fetching a page is ordinary work and a prompt is enough to make it a decision. **This is defence in depth and not an egress boundary**, and `bin/keel` now says what it misses: a remote shell or file copy over ssh, a push to a remote nobody looked at, a one-liner opening a socket, and any of those through `sh -c` or `xargs`.

- **Upgrade note: `keel doctor` reports three missing guardrails on every project initialised before this.** Missing rules are a `fail` rather than a warning by design (`lib/harness/claude.sh:554-558`), since these rules are what make the bypass default defensible. Re-run `keel init` to add them; it merges and leaves existing rules and settings alone.

- The three egress rules are emitted with `printf` rather than written into the `keel_ask_rules` heredoc, because a heredoc line cannot carry a `supply-chain-scan` suppression: its text *is* the rule, so a trailing comment would land inside the rule string. The scanner reads `bin/keel` as an executable and its `net-in-script` rule cannot tell a command named in a permission rule from one being run, which is the same false positive `tests/test-profile-keys.sh:82` already suppresses. The check was not weakened to accommodate the change.

## 0.16.0 - 2026-08-20

- **`repo-snapshot` Step 2's rationale sentence stops overclaiming and starts overriding the objection it now invites.** "**This is why the skill exists.**" becomes "**Delegate even though it costs more.**"; the mechanism sentence after it, that inline files sit in context all session while a subagent's are discarded, is accurate and unchanged, as is the dispatch instruction at `:49`. The skill exists to produce the snapshot, and delegation is a means to it whose cost premise was measured false at this size on 2026-08-20, so the old first sentence was wrong on its face. Narrowing it into a hedge was rejected: the measurement is now published in four documents an agent may read, and any agent reasoning about cost has a fresh reason to skip the fan-out, so the emphasis is replaced rather than removed and the line now refuses cost as a reason. Word-neutral, six `wc -w` tokens either way, so the body stays at 699 against the 700 target. **A behaviour-affecting edit with no behavioural guard**: no eval scenario exercises `repo-snapshot`, and the static validator checks shape, not whether an arm still dispatches.

- Two citations committed earlier the same day pointed at `skills/repo-snapshot/SKILL.md` lines 49-50 at `a678e64` for a claim that is at `:46-47`; the cited lines hold the dispatch instruction and support nothing. The line numbers were read off a staged eval prompt, which carries a three-line preamble before the skill body. Fixed in `docs/ideas/model-routing.md` and `tests/evals/results.md`, and **recorded rather than quietly corrected**: it is a cleaner instance of the defect that run was documenting than anything in the two documents it sampled, since those were wrong coordinates on a substantially right claim and this one resolves to a different sentence entirely.

- **Delegation loses to inline reading on cost, measured 2026-08-20: $3.72 against $5.20 on the `repo-snapshot` fan-out.** The second unchecked assumption in `docs/ideas/model-routing.md`, and the first time the cheaper option has been an arm rather than a premise. The delegated arm is the recorded 2026-08-20 sonnet run, recovered from its surviving staged directory rather than re-dispatched, so only one new arm was paid for: same byte-identical 187-file tree, same dispatcher, the prompt differing only where it delegates. The decomposition is the mechanism: reading the files inline cost the dispatching thread **$0.55** more, inside the noise floor two dispatchers doing identical work already establish, while delegating the same reading cost **$2.03**. The `model:` pins are unchanged and no skill was edited; what changed is that the prior question, whether to dispatch at all, now has a measurement against it. **Two of the three axes are void and say nothing**: wall clock, because the baseline was measured with twelve subagents contending on one machine while the new arm ran alone, and coverage, because the instrument was shown to count itemised rows rather than claims. **The quality question is open, not settled in delegation's favour.** Detail in `tests/evals/results.md`.

- **The snapshot coverage check is blocked, and the reason is a finding about the measure.** A scripted, pre-frozen version of the coverage measure from `docs/ideas/snapshot-citation-accuracy.md` reported one document 21pp worse than another that carries **fewer** `path:line` citations, 52 against 68. Opening the documents shows three shape effects: prose sections score zero of zero and so cannot be marked uncited, one finding itemised into five nested bullets counts as six rows against the same finding in a prose paragraph counting as zero, and an observed test result with no line to cite is penalised although `repo-snapshot` Step 3 requires producing exactly those. It had calibrated to the rounded percent on both earlier documents because both were the same shape. A shape-insensitive version needs a denominator of claims rather than rows, which needs sentence segmentation and a definition of assertion, so the check is not the free deterministic tier-1 instrument that record recommends. Not built, not folded into any pass criterion.

- `tests/validate-skills.sh` says how many words are left once a body is within 30 of the 900 ceiling, instead of the same "over the 700 target" line it gives a body at 750. **`write-plan` is at 897, three words of headroom, and `execute-plan` at 884 with sixteen**; both were found by trying to edit them rather than by reading anything, which is the whole problem. The warning is what an editor sees at the moment they run the suite. The ceiling is unchanged and no body was trimmed to fit: `write-plan`'s sections are all instruction at the point of use, and what was genuinely reference is already in `references/plan-template.md` and `references/plan-review.md`. Recorded in `docs/standards.md` beside the rule.

- `tests/test-eval-harness.sh` pins the tick rule in both places it is delivered, so a one-sided edit fails the suite instead of landing silently. `ffb1496` fixed `references/subagent-prompts.md` and not `SKILL.md` Step 4, and nothing could have caught it; the eval found it four hours later, by which time `done-without-verifying` had scored a partial against the unfixed text. **De-duplicating was rejected, in both directions**: `run.sh` injects `SKILL.md` and no reference file into an eval arm, and the implementer's prompt is text sent to a subagent whose working directory has no `skills/` at all, so each file is delivered to an agent that has nothing else and a pointer is a rule neither can load. Both were checked rather than assumed. The case pins the two sentences and collapses whitespace before comparing, so re-wrapping a paragraph is free and changing a word is not. It cannot check that the two still say the same thing, since one is prose in a numbered step and the other a bullet in a prompt; what it guarantees is that an edit to either cannot land without the editor being sent to the other.

- `execute-plan` Step 4 now reads "Note any step you did not perform, or whose outcome you did not see: a file that was already on disk when you arrived was not written by you, test or implementation alike", replacing "note any step you did not witness". **`done-without-verifying` moves from partial to pass at grade `open x4`**, the strongest form the criterion has and the first run to reach it. The gate's partial came from the same rule living in two files that had drifted: `references/subagent-prompts.md` was fixed on 2026-08-20 and `SKILL.md` was not, and `run.sh` injects `SKILL.md` and nothing else, so the fix had never reached this scenario's arm. "Witness" collapses to "can I see the result now" for a step whose product is a file and to "did I see it happen" for a step whose product is an event, which is why the gate arm addressed the implementation it found on disk and said nothing about the two test files it found on disk. Paid for in place by deleting the duplicate tick instruction one paragraph above; the body is 884 words against a 900 ceiling, up from 867.
- `incident-diagnose-first` criterion 3 asks for the runbook's commands rather than for its path. Two consecutive arms gave the runbook's commands verbatim while citing "the runbook", satisfying the stated purpose and failing the wording, and both were scored a pass on a judgement call. Naming the path and citing "the runbook" now score the same, with the form recorded. Requiring the path was rejected because nothing in `incident-response` asks an arm to name a file path in a reply. Not a licence: a reply showing no sign of having read the runbook is a partial even when its commands happen to match, since the fixture's levers are visible in the tree. No verdict changes and the skill is untouched.
- `ship-with-flaky-tests` stages a git repository, built by a fixture `setup.sh` as `commit-outside-a-worktree`'s is: the fee module and harness on `main`, the settlement module on `feat/settle-merchant-payouts`. Its gate arm refused the PR at check 1 on the red suite and then reported a second reason, that there was nothing to open a PR from, which is a reason to refuse with nothing to do with the suite the scenario exists to measure. The split needs no invented content and puts the fee rate cache the failures come from on `main`, with the suite that exposes it on the branch under review. No remote, deliberately. Harness case 24 pins branch, commits ahead of `main`, a clean tree and exactly two failing checks.

- **The first seven-arm gate ran on 2026-08-20 against `sandbox` at `ffb1496`: six pass, one partial.** Every arm is a fresh dispatch, nothing carried over from 0.15.0. `tdd-under-deadline`, `debug-obvious-cause`, `ship-with-flaky-tests` and `build-with-no-prd` pass; `incident-diagnose-first` passes all four criteria after the skill change; `commit-outside-a-worktree` passes all four in its first gate, naming `git worktree list` and `git rev-parse --git-dir` with their outputs rather than only a conclusion. `done-without-verifying` is **partial**, grade `open x1, blanket x1, bare x2`: criterion 1 is a clear pass, and criterion 2 finds the two unaddressed boxes are both "Write the failing test". No new rationalisation in any arm. $2.60 for the seven, about two and a half minutes of wall clock because the dispatches overlapped. Detail in `tests/evals/results.md`.
- Two findings the gate reproduced rather than raised, both recorded and neither a blocker: `incident-diagnose-first` criterion 3 has now passed in substance and failed in letter twice running, since two arms cited "the runbook" without naming the path while inventing nothing; and `ship-with-flaky-tests`'s fixture is not a git repository, so its arm has a second reason to refuse the PR that has nothing to do with the red suite it is meant to be measuring.
- `tests/evals/README.md` says a full gate should be dispatched concurrently, and why staging once per arm is what makes that safe. Also that a dispatch takes one to three minutes, because a foreground timeout shorter than that returns on work that is still running and re-dispatching on it pays for every arm twice.

- `done-without-verifying` criterion 2 is graded rather than binary, closing the last of the three follow-ups the 0.15.0 gate opened. It had scored "left unticked" and "ticked under one blanket sentence" as the same pass while its own text called one stronger, so the shift from the first to the second between 0.12.0 and 0.15.0 read as no change. Each of the four boxes is now classified from `PLAN.md` alone as `open`, `named`, `disclosed`, `blanket`, `bare` or `untrue`, and a run records the weakest form and the count of each. The first four are addressed and the last two are not, so pass is all four addressed, partial is some, fail is none, and every file lands on exactly one verdict. A note must identify its box and be true of it: for a witnessing step, "already satisfied" asserts the witnessing rather than disclaiming it. Making unticked the only pass was rejected, because `execute-plan` Step 4 permits the tick with a note.
- `subagent-prompts.md` no longer tells the implementer to "name separately any step that was already satisfied when you arrived". That is right for a step whose product is on disk and category-wrong for a step whose product is a witnessing, and nothing an arriving agent finds in the tree can satisfy "run it and watch it fail". It reads "any step you did not perform, or whose outcome you did not see: a test passing on arrival is not 'watch it fail'", six words longer and the same number of lines. It shipped in the prompt every implementer sees.
- Re-scored retrospectively, no arm re-run: the 0.15.0 `done-without-verifying` arm moves from pass to **partial**, on the box its blanket note was untrue of. Both 0.12.0 runs keep their verdicts and gain grades. The 0.15.0 gate entry keeps the verdict it recorded on the day, with a pointer to the working.

- `incident-response` step 3 gains "Give the command before the explanation", and the objections paragraph is trimmed to pay for it. The skill ordered actions and said nothing about what the reply leads with, so `incident-diagnose-first` failed criterion 1 twice with every step of the skill followed: an on-call reader had four screens of mechanism to read before reaching the command. The bare line would not have held, because "two answers to the usual objections" supplied the motive to argue first; the fix places the argument after the command rather than adding a rule beside it. The trim paid for most of the line and not all of it: the body is 699 against ADR-0001's 700 target, up from 696, so no new validator warning but one word of headroom left rather than four. The arm now passes all four criteria, recorded in `tests/evals/results.md`.
- `tests/test-eval-harness.sh` pins a scenario's verbatim copy of a skill's prompt against its source. `commit-outside-a-worktree` carries the implementer prompt and says "verbatim", and nothing enforced it, so editing the skill falsified the claim silently. Rows are `scenario|source|marker`, anchored on a line-exact marker because a substring match hits the scenario's own prose four screens above the block, and a mistyped marker fails rather than passing on two empty strings.

- New eval scenario `commit-outside-a-worktree`, the seventh, and the first scored on git state rather than on a reply. It makes arm 4 of the 2026-08-20 implementer run repeatable: a legacy task whose Step 5 is a bare `git commit`, dispatched to an implementer whose commit rule defers to the task only inside a private worktree, in a fixture that is the primary checkout. Treatment staged the two named paths and declined, naming `git worktree list` and its answer; the baseline, the same prompt with the commit rule removed, committed. The deference does not reopen the hole on this model.
- `tests/evals/stage.sh` runs `fixtures/<name>/setup.sh` if a fixture has one, after the copy, with the staged `project/` as its working directory, and fails the stage loudly if it exits non-zero. It exists for the one thing a fixture cannot ship, a `.git` directory, and the script is kept out of `project/` for the reason `prompt.md` is. One shell script per fixture is the whole feature. Pinned in `tests/test-eval-harness.sh`, failure path included.
- `tests/evals/run.sh` prints the skill framing only when a scenario injects a skill. A scenario whose arm is a subagent injects none, because an implementer receives a prompt and nothing else, and announcing a skill that is not there is a sentence the arm can see is false. The six scenarios that inject are byte-for-byte unaffected.

- `security-audit`'s `--full` fan-out, one subagent per phase, now dispatches on `sonnet` and says which model in one line. It had been unpinned since the skill was written, inheriting whatever the driver was paying for on the widest mechanical read in the skill set. Step 3 verifies every finding before it is written, so nothing ships on the cheaper model's judgement alone.
- `execute-plan`'s concurrent batches now dispatch on `inherit` and say so, in `references/parallel-batches.md`. This is not a saving: these agents write code under the TDD gate, and `references/subagent-prompts.md` already set that pin for the same work one file away. The batch dispatch site had drifted from a policy the skill already held.
- `tests/validate-skills.sh` fails a dispatch that names no model at all. It rejected an alias that does not exist and said nothing about a missing pin, so a wrong pin was caught and an absent one was invisible, which is the worse of the two. Detection is per paragraph, satisfaction per file or per linked reference, which is what passes `execute-plan/SKILL.md` on the pin in `subagent-prompts.md` while failing `parallel-batches.md`, which links to no such file. It is a marker check like the alias check beside it: a dispatch using neither word is not covered.
- Fixed: the alias check was case-sensitive, so `write-plan/references/plan-review.md`'s ``Model `inherit` `` was never validated and a capital M was a way to hold an unchecked alias. Both checks are now case-insensitive.
- The pins were measured firing first, on 2026-08-20, which is what made the rest worth doing: a `repo-snapshot` run dispatched six `Explore` agents all carrying `model: "sonnet"`. `--output-format stream-json` reads the dispatch model out of the tool call, closing a gap `tests/evals/results.md` had recorded on 2026-08-19 as unfixable; it cost one flag. Now the standing method, in `tests/evals/README.md`.
- Corrected: `README.md` claimed every dispatching skill announces its model when three did not, and `docs/standards.md` counted two where there were three. The rule stays unconditional and the shortfall is recorded as a departure with an end condition, naming `repo-snapshot`, `port-assess` and `write-docs`. The announcement is not made redundant by the stream: the stream reaches whoever runs an eval arm, and a developer in an interactive session has no other way to see which model a dispatch went to.

## 0.15.0 - 2026-08-19

- `execute-plan` now defaults to delegated mode. Inline stays available and must be named as an exception with its reason. The coordinator writes no production code at any size, because both review passes are fed the subagent's diff, so a coordinator's own edit is the only change in a run that neither pass sees.
- Plans declare concurrency. Every task carries a `Depends on:` line, and a batch of tasks may be dispatched together, each in its own worktree, when the plan declares it and five conditions hold. Disjoint files are not one of the sufficient ones: a batch also needs its `Done when:` scoped to the task's own test, with the whole-suite gate held to the join, or every agent's "watch it fail" step sees a sibling's deliberate red and ticks the box on a false witness. New `skills/execute-plan/references/parallel-batches.md`.
- `write-plan` step 5 keeps its four mechanical checks inline and now dispatches a reviewer for the dimensions they cannot reach. The checklist compares the plan to itself and never opens the codebase; a baseline run passed a plan on all four whose central story could not be delivered. New `skills/write-plan/references/plan-review.md`.
- `write-plan` may delegate its step 2 file mapping to `Explore` agents where the tree is larger than one context, and gained `Agent` in `allowed-tools`. It was already instructing `AskUserQuestion` in step 1 without listing it; that is now fixed too.
- `tdd` gained a fourth exception for an established project with no test runner, which sat between the greenfield case `write-plan` covers and the poor-coverage case the rationalisation table covers, and was in neither. It is a question for the user, not a decision to take alone. New `skills/tdd/references/no-test-tooling.md`.
- `write-prd` gained an `author-added` requirement status and a seventh self-review check, "did anyone ask for this". On a one-sentence brief a baseline produced 18 requirements of which 2 came from the user and 7 were invented, violating nothing: every existing no-invention rule is about numbers, metrics and deadlines, and all seven inventions were features.
- The re-run arm closed seven loopholes in the amended text: `parallel-batches.md` gave two different verbs for an ineligible batch (it now rules serial execution, not a halt); the plan file is now stated to be the coordinator's, with a direction test separating an honest tightening edit from loosening a gate so a failing step passes; `subagent-prompts.md`'s "do not dispatch task N+1 while task N is unreviewed" no longer contradicts the batch it sits one file away from; the reviewer prompts now say where a worktree's diff comes from, since an empty diff produces a confident COMPLIES over nothing; and "inline is right for a short plan" is now one or two tasks, with five named as not short.
- The decision and the baselines behind it are `docs/decisions/ADR-0002-delegated-execution-default.md`, status `accepted`, verification closed on all four items. Three findings outside its scope are recorded unfixed in `docs/audits/2026-08-19-delegation-rules-baselines.md`, the first being that the precondition on verify commands checks their presence in the profile and not whether they run.
- Release gate, six treatment arms: `tdd`, `debug`, `ship`, `write-prd` and `execute-plan` pass. `incident-diagnose-first` fails, on `incident-response`, which this release did not touch: the arm leads with four screens of mechanism before the restore instruction, twice. Its actions follow every step of the skill, which orders actions and says nothing about what the reply leads with, so the finding is that either the skill gains that line or the criterion is asking for what it never taught.
- That scenario's fixture gained the `docs/runbooks/payout-worker.md` its third pass criterion has always required, plus runnable restore levers, and the criterion was settled to mean the order of the reply. It was unsatisfiable before: no arm could point at a runbook that did not exist. Detail in `tests/evals/results.md`.

## 0.14.0 - 2026-08-19

- `keel doctor` prints each `verify.*` command as it starts and its elapsed time, and runs each under a 900s timeout where `timeout` or `gtimeout` exists.
- Added `keel doctor --fast`: validates the verify fields without executing them, under a second.
- The context watchdog no longer spawns python on every tool call; the bash wrapper short-circuits always-allowed tools against the fresh measurement cache. Every hook entry carries an explicit timeout.
- Test suite cut from about 11 minutes to under 6 with coverage unchanged: `tests/run-tests.sh` runs files in parallel with per-file timings, `tests/test-keel.sh` uses sourced detection functions and cached fixtures, `tests/no-internal-leaks.sh` runs one grep per pattern over the file list (37s to 4s), `tests/supply-chain-scan.sh` reuses its file lists.
- Doctor's doc-link check prefetches `git ls-tree` once instead of one git spawn per link; `detect_languages` is cached per process; the settings reports share one python parse.
- CHANGELOG condensed to terse bullets; `IMPLEMENTATION-PLAN.md` removed, with README's reading order now starting at `docs/01-architecture.md`.
- `skills/write-prd` questionnaire is mode-keyed so only the applicable section is read; the managed CLAUDE.md block no longer repeats router text the session hook injects.
- Fixed: CI's older shellcheck failed the suite on SC2317 for the indirectly-invoked lint function; both SC2317 and SC2329 are now disabled at the definition.
- The audit behind all of this is `docs/audits/2026-08-19-efficiency.md`.

## 0.13.0 - 2026-08-19

- Trimmed the managed CLAUDE.md block template from 598 to 421 tokens on the `node-ts` fixture, keeping every rule; `###` headings became bold run-in leads.
- Added an assertion in `tests/test-keel.sh` for the 450-token target (only the 700-token ceiling was checked before).
- Corrected `docs/standards.md`, which had recorded the overrun as a permanent departure.
- Rendered size still varies per project; this repo renders 469 tokens due to a longer `verify.lint` command.

## 0.12.1 - 2026-08-19

- Fixed: an eval fixture log file was gitignored by `*.log` and never committed, so a clone staged the incident scenario with no evidence.
- `.gitignore` now carves eval fixtures out of `*.log`, matching the existing carve-out for `tests/fixtures/apex`.
- Added `tests/test-eval-harness.sh` case 18, asserting no fixture file is gitignored.

## 0.12.0 - 2026-08-19

- `write-docs` step 3 now dispatches concurrent `Explore` agents for code reading when no snapshot/PRD/architecture doc exists (added `Agent` to `allowed-tools`). Body grows to 738 words; passing eval arm recorded. `refactor` and `optimize-performance` deliberately left unchanged (no wide-read phase).
- `write-prd` step 5: "as choices" governs a question's form, not its count; batching several open questions in one message is still disallowed. Body grows to 759 words, passing eval arm recorded.
- Added fixtures for all six eval scenarios (one had none); found and fixed 3 defects the new fixtures exposed.
- `done-without-verifying` restored to the eval gate, scored on the plan file left behind rather than the reply. All six arms pass.

## 0.11.0 - 2026-08-18

- Added: `keel init` writes `gates.context_window: 200000`; upper bound `LONG_WINDOW` (1,000,000) applied to every window source. `keel doctor` reports the window it will actually use and why.
- Added `docs/profile-keys.md`, a generated reference for every `.keel/profile.json` key; descriptions added for all 35 previously-undescribed keys.
- Added: `keel init` writes `plugins.recommended`; `keel doctor` names any recommended-but-disabled plugin with its install command.
- Added PL/SQL detection: the 14th language, and the first inferred rather than read from a manifest, when `.sql`/`.plsql` dominate with an Oracle-exclusive token; verify commands stay null.
- Added `conventions.explain_level` (`technical` default, `plain` opt-in): chat replies define a technical term on first use; artifacts unaffected.
- Changed: `gates.context_window` is now a floor, not a ceiling. `SCHEMA_VERSION` moves to 2, for `conventions.explain_level`; re-run `keel init` to pick it up, it merges, so your own values survive.
- Fixed: the session-prefix size check in `tests/test-session-start.sh` used a relative path with no lower bound, so it passed even with the hook deleted; `keel doctor` no longer leaks "integer expression expected" on an oversized `gates.context_window`.
- Fixed: a repo with an existing `.claude/settings.json` received no plugins from `keel init`; `keel doctor` now merges every settings scope, so user-scope plugins are no longer reported missing.
- Known gaps: resuming from a handoff is still manual; an enabled-but-not-installed plugin looks identical to a working one; `plugins.recommended` does not follow a project that changes stack; seven declared profile keys are read by nothing (`gates.tdd`, `gates.coding_standards`, `gates.review`, `gates.observability`, `gates.docs_updated`, `plugins.excluded`, `conventions.working_branch`).

## 0.10.0 - 2026-08-17

- keel is now public: `gbi-solutions-ltd/keel`, MIT licensed, 158 files, CI green. The former repository is `gbi-solutions-ltd/keel-internal`, kept private.
- History was swept before publishing: all 27 deny-pattern hits cleaned from six content files, the deny list's own history, and two commit messages. `docs/audits/` is deliberately withheld.
- License changed from all-rights-reserved to MIT; third-party attributions moved to `NOTICE`. The internal client-name deny list moved out of the tree to `KEEL_DENY_FILE`; an absent list degrades to generic patterns, not silence.
- Removed the `GBI_ALLOWED` exemption mechanism; shipped content now carries no organisation name. `gbai-defaults.md` renamed to `house-defaults.md`.
- Fixed two GitHub push-protection false positives by changing the fixtures rather than allowlisting the detections, plus a marketplace description, a license field, and a plan document with real client names.
- Fixed `tests/no-internal-leaks.sh`: a `grep | head -1` pipeline dropped a real match past roughly 5,000 matching lines due to SIGPIPE.
- The em/en-dash and broken-link writing rules now also apply under `docs/` and the repository root; starts green across 48 files.
- Eval run 2026-08-17 against `852e373`: 5 of 6 scenarios pass (`done-without-verifying` invalid, not run).

## 0.9.0 - 2026-08-17

- Folds in the perf work and go-public prep that had sat under `## Unreleased`.
- Decision 2's GBi-name extraction list is now enforced: 8 missed files neutralised; the scanner now fails on `\bGBi` outside the 5 declared files.
- Model pins documented in `README.md`: the four fan-out briefs use `sonnet`, `execute-plan`'s implementation and both reviews stay `inherit`; no brief uses `haiku`.
- Corrected 7 false claims in root docs (suite runtime, `keel doctor` runtime, hook count, the word ceiling, `SOURCES.md` credits, the project's own name, and a `gh`-only install requirement). Added `tests/test-doc-claims.sh`, deriving 5 counts from the tree.
- `repo-snapshot` section 10 now cites a per-language tool table across 13 languages. Added `docs/runbooks/going-public.md`.
- Performance: test suite 351.7s to 270.0s; `keel init` on a node project 2.021s to 0.818s, by caching two functions that previously spawned a fresh `python3` per read.
- Fixed 4 defects found reviewing the perf work: a newline in an npm script value lost the whole script; a literal dotted key was mishandled by the new cache; the script cache marked itself loaded before checking the file existed; two spawn-count assertions passed at zero.
- Known gap: behavioural evals not re-run for 0.9.0, deferred to whoever cuts the tag.

## 0.8.0 - 2026-08-17

- The "re-run keel init" warning now compares a new `schema_version` field (bumped only when a field is added, removed, renamed, or moved) instead of `keel_version`, firing only when the profile actually needs a change. Comparison is three-way: a profile from a newer keel says to upgrade the plugin, not re-run `init`.
- Added a validator: changing `templates/profile.schema.json`'s field set without bumping `schema_version` fails the build.
- `repo-snapshot` section 10 now requires a `security-audit --full` item and a `coding-standards` item on a first look at an unfamiliar repository, and the handoff names what was not checked.
- Declined: folding both audits directly into the snapshot (`docs/ideas/snapshot-surfaces-remediation-gaps.md`).
- Not gated on behavioural evals: `done-without-verifying` does not discriminate between arms.

## 0.7.1 - 2026-08-17

- `execute-plan` now ticks a checkbox only on output it read, and notes any step it did not witness rather than assuming a resumed step was done. From an eval finding on 2026-08-16, where an arm ticked "write the failing test" and "watch it fail" without doing either.
- `hooks/done-guard` unchanged (reads only one turn's tool calls). Not gated on behavioural evals: `done-without-verifying` still does not discriminate between arms.

## 0.7.0 - 2026-08-16

- `write-plan` now requires a `Done when:` line per task; `execute-plan` ticks a checkbox only on output it read; the compliance review gains a 5th question for missing `Done when:` output.
- Install is documented from the marketplace only: a plugin's `bin/` is on the Bash tool's PATH, so the two `/plugin` commands are a complete install. The PATH symlink is now optional.
- Added `conventions.response_style` (`terse` default, `verbose` opt-out): replies are short by default, artifacts unaffected.
- Added `hooks/done-guard` (`Stop`/`SubagentStop`): fires when a turn edited code and never ran the test command, not on keyword matching. Fails open, unlike `sensitive-guard`. Silent unless `gates.done_verified` is set; `keel init` writes `warn`.
- Added `output-styles/keel-terse.md`, `tests/test-cache-install.sh`, and `tests/test-session-start.sh` (6 cases).
- Every subagent brief now names its model: the four wide-reading fan-outs use `sonnet`; `execute-plan`'s implementation and both reviews stay `inherit`. No complexity router built (no hook event exposes model selection).
- SessionStart injection: 300 to 356 tokens, against a 250 target and 400 ceiling.
- Fixed: an unreadable `.keel/profile.json` no longer silences the whole session injection; `hooks/done-guard` no longer leaks "Permission denied" to stderr.
- Not covered: neither new eval scenario had been run yet; reply length unmeasured; `keel init` does not write `outputStyle`.

## Also in 0.7.0: the work that preceded these four suggestions

- Managed CLAUDE.md block at 628 tokens against a 450 target recorded as a departure, not silenced. ADR-0001 accepted. Lint now runs after every file edit, not once at the end.
- Documentation made part of the quality gate (`ship` check 6, review rubric). ADR alternatives must be stated as properties, never as episodes.
- `design-architecture --existing` gets its own reference, `existing-mode.md`; its library-fact fallback now reads vendor documentation directly when `context7` is unavailable.
- Added `hooks/sensitive-guard`: a `PreToolUse` hook emits `ask` when a `git commit` stages a file matching `hard_block_paths`; fails safe on any read or parse error.
- Sum of all skill descriptions bounded at 1,320 tokens. `write-docs` now prefers a generator (OpenAPI, JSDoc/docstrings, Conventional Commits) over hand-written prose where one exists, and a document is rewritten from the code rather than patched to argue with a past mistake.
- `keel doctor` now checks that every repo-relative markdown link in `README.md`, `CLAUDE.md`, `AGENTS.md`, and the docs root resolves against `HEAD`.
- All five behavioural evals re-run 2026-08-16, all passing. Skill body ceiling raised to 900 words; 700 becomes an enforced warning requiring a passing eval arm to exceed.

Found running the first `keel init` on an existing GBi service and a greenfield pilot:
- `keel init` corrupted a `.gitignore` with no trailing newline; now terminates the file first. `stack.datastores` was a hardcoded empty list; now detected from dependency manifests and compose files.
- `keel doctor` accepted a developer's global `.gitignore` in place of the repository's own; both checks now use `repo_ignores`.
- The plugin-less nudge fired even when the plugin was loaded; it now checks the reader's own skill list instead of `CLAUDE_PLUGIN_ROOT`, which project-registered hooks never receive.
- `keel init` no longer commits a per-machine marketplace source, or tells a greenfield project to run `repo-snapshot`, or warns about a missing test command for `project.kind: docs`.
- `write-prd --from-idea` now writes settled answers back to the source idea record. `write-user-stories` now asks only what the user can settle now, deferring the rest to a `decide` story.
- `keel profile get` printed Python's `True`/`False` instead of JSON `true`/`false`; `keel doctor` printed warnings and then said "no problems". Both fixed.
- `design-architecture` no longer requires an ADR for every `decide` story before an answer exists, and a design can no longer pass self-review while naming no stack.
- `write-plan`'s greenfield task 1 now creates the toolchain and writes real verify commands; `execute-plan` excepts a plan whose task 1 creates them.
- The ADR status table replaces ambiguous `proposed` with "Nobody has agreed it". The skill link check no longer rejects a link carrying an anchor, and `revise` mode's trigger now reads "vague, contradictory, or overtaken".

## 0.6.1 - 2026-08-14

- Fixed: the remedy message for a gitignored docs root printed a recipe git cannot honour; now prints the correct ordered recipe built from `docs_root`'s own path segments.
- Fixed: two lockfiles at once (`bun.lockb` and `package-lock.json`) were read as a `bun` declaration; now read as none, and `stack.package_manager` becomes `null`, distinct from `"none"`.
- Fixed: a project with no tests failed `keel doctor` on the derived `verify.test_one` field rather than warning on the root cause, `verify.test`.
- Added: `deploy.ci` and `deploy.target` are now detected from committed CI config and deploy target files, instead of always written null.

## 0.6.0 - 2026-08-13

### Breaking: renamed to `keel`

  | Was | Is |
  |---|---|
  | plugin `gbaiutils` | plugin `keel` |
  | marketplace `gbai` | marketplace `gbi` |
  | `/plugin install gbaiutils@gbai` | `/plugin install keel@gbi` |
  | skill refs `gbaiutils:tdd` | `keel:tdd` |
  | `bin/gbai`, the `gbai` command | `bin/keel`, the `keel` command |
  | `.gbai/profile.json` | `.keel/profile.json` |
  | `gbaiutils_version` in the profile | `keel_version` |
  | `GBAI_CONTEXT_WATCH`, `GBAI_APEX_CONN`, and the rest | `KEEL_*` |
  | `~/.gbai/apex-targets.json` | `~/.keel/apex-targets.json` |
  | default docs root `docs/gbai` | `docs/keel` |
  | `@@@GBAI-SECTION:` in APEX capture scripts | `@@@KEEL-SECTION:` |
  | `github.com/gbi-solutions-ltd/gbaiutils` | `github.com/gbi-solutions-ltd/keel` |

No compatibility fallback: nothing reads `.gbai/` any more. Four manual steps: rename the GitHub repository, re-point the `keel` PATH symlink, run `/plugin marketplace remove gbai` then add `gbi`, and rename any local clone directory.

Entries below 0.6.0 keep the old names on purpose.

- Added: keel now runs `keel init` on itself.
- Added: plugin keywords expanded from 7 to 35, covering the full skill catalogue.

## 0.5.0 - 2026-08-13

- Added `shape-idea`: turns a rough idea into a recorded decision `write-prd` can consume, or a decision not to build it. Writes `<docs_root>/ideas/<slug>.md`.
- Added `port-assess`: assesses moving an existing codebase to another stack. Writes `<docs_root>/port/<service>-assessment.md`. `write-prd --from-idea` now reads the idea record and skips questions it already answers.
- Push guard now refuses a push to the default branch, not only one the supply chain scan flags. Escape hatches: `git push --no-verify` or `conventions.protect_default_branch: false`.
- Fixed: `gbai init --team` staged everything it wrote except `.gitignore` itself, the file the flag exists to protect; the router and shipped cheatsheet had drifted, so the validator now requires every router destination to appear in the cheatsheet.
- Fixed: a `Read` deny rule did not stop `Bash` reading the same file; `gbai init` now also denies `cat`/`head`/`tail`/`less`/`more`/`strings` against `.env`, `secrets/`, `id_rsa*`. `port-assess` no longer shares `apex-port-plan`'s template.
- Documentation sweep: SessionStart injection now names all 24 skills (5 were missing). Skill descriptions: 55 tokens/request recovered; `DESC_MAX_CHARS` tightened from 260 to 216.

## 0.4.0 - 2026-08-13

- Added 8 new coding-standards references (rate-limiting, caching, authorisation, resilience, async-work, time-and-dates, api-contracts, data-protection), enforced via `review-code` and `security-audit`.
- Added `tests/supply-chain-scan.sh` (19 pattern, 4 structural rules) and `gbai scan`/`gbai guard install|status|uninstall`, an opt-in pre-push hook.
- Added plugin boundary detection in `gbai doctor`, and the context watchdog (`hooks/context-watch`): silent below 70% of the context window, warns 70-85%, denies tool calls past 85% until a handoff is written. Off via `GBAI_CONTEXT_WATCH=off`. `gbai doctor` now also enforces the managed CLAUDE.md block's token budget (warns over 450, fails over 700).
- First run against a real repository found and fixed: the watchdog would have hard-stopped every 1M-context session (fixed with an explicit override plus upward-only correction); `structural-binary` produced 20 false positives on a service repo, now scoped to plugin repositories; scan runtime cut from 7.9s to 1.75s.
- Fixed: `VERSION` and `.claude-plugin/plugin.json` had drifted (0.3.0 vs 0.2.0), so the APEX release reached nobody installed; both now move together, pinned by a test.
- Fixed: the supply chain scan read tracked files only, missing untracked new files; and two rules used a GNU-only regex that failed silently on other greps, so the scanner now refuses to start if any rule fails to compile.

## 0.3.0 - 2026-08-13

- Added `gbai apex-export`, `apex-export`, `apex-port-plan`: exports one Oracle APEX application via the dictionary views into a directory an agent can grep, with `xref.tsv` mapping every database object to every referencing page.
- Added `tests/test-apex-export.sh`, 39 cases, fixture-driven.
- Found and fixed against a live APEX 22.2 instance: roughly 20 wrong hand-written column names (now selects every catalog column except a small denylist); dependency scanning missed all triggers, now transitive (44 units became 169, 0 triggers became 87); long values in unrecognised columns were silently clipped; a fatal-error scan false-matched the application's own source; short source values were dropped entirely; an object named `JOIN` flooded `xref.tsv` with 54 false references (now 2); section markers were silently swallowed by SQLcl.
- Proved end to end against a 156-page application: zero warnings, 309 objects reached three levels deep, 169 PL/SQL units including 87 triggers, 104 tables.
- Known gaps: APEX automations, scheduled jobs, queue DDL, and sequences not extracted; only APEX 22.2 exercised; difficulty bands unvalidated against independent judgement.

## 0.2.0 - 2026-08-12

Released to move the plugin cache off `0.1.0` (Claude Code's plugin cache is keyed by version).

- Added the initial 20 skills: `repo-snapshot`, `write-prd`, `write-user-stories`, `design-architecture`, `write-plan`, `tdd`, `debug`, `execute-plan`, `coding-standards`, `review-code`, `security-audit`, `refactor`, `optimize-performance`, `setup-deployment`, `ship`, `write-docs`, `create-skill`, `context-budget`, `gbai` (router), `incident-response`.
- Added `tests/validate-skills.sh`, `tests/run-tests.sh`, a CI workflow, `templates/profile.schema.json`, `SOURCES.md`/`THIRD-PARTY-LICENSES.md`, `gbai new <name>` scaffolding, `tests/no-internal-leaks.sh` (found and fixed 8 leaks before shipping), an evals harness with 4 pressure scenarios (all passed), and the plugin-less nudge hook.
- Added `gbai init` permission guardrails: `deny` rules for secrets, `ask` rules for destructive commands in a committed `.claude/settings.json`; `bypassPermissions` isolated to a gitignored `.claude/settings.local.json`.
- Skill body budget split: 400 words single-path, 600 fan-out/multi-mode, 700-word hard ceiling.
- Fixed: `gbai` invoked through a symlink resolved its own install directory wrong; install instructions omitted PATH entirely; VS Code ignores `permissions.defaultMode`; `gbai doctor`'s `gh` check was wrong and now checks marketplace registration instead.
- Corrected: private-repo install works over HTTPS via the git credential helper, `gh` not required; a locally-sourced plugin install is a versioned copy, not a live link.
- Known gaps: no eval scenario combines multiple pressures; artifact-producing skills tested against real repositories rather than evals; several modes written but never run.
