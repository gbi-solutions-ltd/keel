# Done Conditions, Model Pins and Marketplace-First Install Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** make a claim of done rest on a command that ran, pin a model on the subagent briefs keel
already dispatches, and correct install documentation that states something about Claude Code which
is no longer true.

**Stories:** none written. Scope comes from three idea records, agreed 2026-08-16:
`docs/ideas/verification-backed-done.md`, `docs/ideas/model-routing.md`,
`docs/ideas/marketplace-first-install.md`. The fourth record,
`docs/ideas/concise-responses.md`, is deliberately **not** in scope.
**ADRs:** ADR-0001 constrains skill body length and bounds what tasks 3, 4 and 6 may add.
**Architecture:** no new subsystem. Task 1 adds a test file. Task 5 adds one hook beside
`hooks/sensitive-guard`, registered on `Stop` and `SubagentStop`, and follows that hook's shape:
walk up for the profile, cheap builtin filters first, python3 only for JSON. Every other task edits
existing prose and its validator rule.

## Global constraints

Copied from `.keel/profile.json` and the repository conventions. Every task inherits these.

- Verify commands: test `tests/run-tests.sh`, one test `tests/{name}`, lint
  `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh hooks/session-start hooks/context-watch hooks/sensitive-guard`
- There is no format, typecheck, build or e2e command in this project. Where a step would need one,
  it says so rather than substituting a guess.
- **The lint command is a literal list of files and does not glob `hooks/`.** Task 5 adds
  `hooks/done-guard`, so it must extend `verify.lint` in the profile in the same task, or the new
  hook is never linted and CI never sees it.
- Never start on `main`. Branch first. Per the standing convention all of this lands on `sandbox`,
  PR'd to `main`, not a branch per task.
- Conventional commits, title and body only. No attribution footers, no robot emoji.
- No em dashes or en dashes anywhere. `tests/validate-skills.sh` enforces this for `skills/` and
  `templates/`, and it is a house rule everywhere else including `docs/` and commit messages.
- **ADR-0001 ceilings:** 900 words per skill body, 700 warned. Current bodies:
  `write-plan` 664, `execute-plan` 691, `repo-snapshot` 699, `port-assess` 697,
  `apex-port-plan` 674, `shape-idea` 687. Every one is within 40 words of the warning target, so
  additions to skill bodies are counted in this plan and substance goes to `references/`.
- **The full suite takes upwards of ten minutes**, and `tests/test-keel.sh` is nearly all of it:
  `keel new --stack node` scaffolds real projects. Measured during task 1, where "a few minutes"
  was the original estimate here and was wrong. Run it in the background, and do not pipe it
  through `tail`: that buffers the whole run and the output file stays empty until it exits, which
  reads exactly like a hang.
- `keel doctor` takes roughly eleven minutes and is silent for most of it. No task below runs it as
  a step; it is not hung when it looks hung.

## Groups and PR seams

Three independent groups. Three PRs, in this order, because group A is the release blocker and the
smallest.

| PR | Tasks | What it is |
|---|---|---|
| A | 1, 2 | Prove the CLI runs from a marketplace copy, then correct the install documents |
| B | 3, 4, 5 | Done conditions in plans, enforced first by the plan format and then by a hook |
| C | 6 | Model pins on existing subagent briefs, and the announcement rule |

Group B's tasks are ordered deliberately: task 5's hook checks the structural condition that tasks 3
and 4 make legible. Building the hook first means building it against nothing.

## Corrections made at the start of execution

Found by `execute-plan`'s critical read, before task 1. Each is a defect in the plan as written,
corrected in place below rather than discovered at the task that would have hit it.

1. **`gates.done_verified` uses `required`, not `block`.** `templates/profile.schema.json:205-214`
   constrains every value under `gates` to the enum `required | warn | off`, through
   `additionalProperties`. A profile written with `"block"` fails schema validation, so `keel
   doctor` would have failed in every project that took the new gate. `required` is also the
   vocabulary every other gate already uses. Task 5 and its tests say `required` throughout.
2. **The model marker is the word `model` before the alias, not the word `on`.** Task 6's validator
   rule matched `` on `<word>` ``, which collides with seven existing phrases in the skills including
   `` on `main` `` three times, so the rule would have failed on correct prose the moment it was
   added. `` model `<word>` `` has zero collisions today, checked across every `SKILL.md` and
   every `references/*.md`.
3. **No skill body crosses 700 words. Found in task 3, and it changes tasks 4 and 6.** The plan
   accepted crossing the 700 warning as a warning. It is not one: ADR-0001, accepted, says a body
   over 700 words **requires a passing eval arm at that length, recorded in
   `tests/evals/results.md`**. The plan never scheduled those arms, and an eval arm is dispatched
   and scored by an agent rather than by a script, so it is not something a task can quietly
   satisfy. Every body therefore stays at or under 700 and the substance goes to `references/`,
   which is what `docs/standards.md` says to do anyway. Task 3 landed `write-plan` at 696 after two
   trims. Tasks 4 and 6 inherit the same constraint and their word budgets below are revised.
4. **The validator's helpers are `report` and `warn`.** `tests/validate-skills.sh:56-57` defines
   `report()` for a failure and `warn()` for a warning. There is no `report_pass` or `report_fail`;
   passes are implicit and counted in the summary line. Tasks 3 and 6 are written against the real
   helpers.

## Decisions taken while planning

1. **The done guard fails open, not closed.** `sensitive-guard` asks a human whenever it cannot
   answer, because `ask` is the one decision the model cannot grant itself. A `Stop` hook has no
   such option: denying a stop it cannot justify produces a loop with no human in it. So an
   unreadable profile, an absent python3 or a malformed event emits `systemMessage` and allows the
   stop. This is the opposite of `sensitive-guard` and task 5 records why in the hook's header.
2. **Silent unless the repository asks for it.** The guard does nothing unless the profile has
   `gates.done_verified`. keel's own profile is set to `required`; `keel init` writes `warn` for new
   projects. Same posture as `hard_block_paths`.
3. **Documentation-only turns do not trip the guard.** A turn whose only edits are `.md` files, or
   files under `docs_root`, is allowed to stop without running tests. Without this the guard fires
   on every documentation commit, and a guard that cries wolf is deleted alongside
   `sensitive-guard`, which shares its `hooks.json`.
4. **No brief goes to `haiku` in task 6.** The fan-out briefs move to `sonnet`; anything writing
   code or judging a verdict stays `inherit`. `docs/ideas/model-routing.md` open question 3 asks for
   one measured comparison before going cheaper, and that measurement has not been taken.
5. **Task 1 is a `verify` task, not a `build` one.** It writes a test for behaviour believed
   correct. If it passes, that is the deliverable and task 2 may proceed. If it fails, task 2 is
   blocked and the plan needs new tasks, because the documents would then be about to promise
   something untrue in the other direction.

---

### Task 1: Prove `bin/keel` runs from a marketplace copy

**Kind:** `verify`. The claim is believed true and has never been checked.
**Files:**
- Create: `tests/test-cache-install.sh`
- Modify: `tests/run-tests.sh`

**Interfaces:**
- Consumes: `bin/keel version`, `bin/keel init -y`, and the `incomplete install` guard at
  `bin/keel:35`
- Produces: `tests/test-cache-install.sh`, extended by task 2 with two more cases

**Done when:** `tests/test-cache-install.sh` passes both cases and `tests/run-tests.sh` is green
with the new file in its output.

- [x] **Step 1: Write the test**

Create `tests/test-cache-install.sh`:

```bash
#!/usr/bin/env bash
# Tests that bin/keel works from a copy holding only tracked files, which is what a marketplace
# install produces. README and docs/03-install-and-distribution.md tell a user the plugin alone is
# enough; this is the check behind that claim.
#
# `git archive HEAD` rather than `cp -R`, deliberately. A recursive copy carries untracked files
# across, so a file that is on disk and not in the repository would make this pass while the thing
# it tests fails for everyone else. It also means this tests the committed tree, which is exactly
# what the marketplace ships: uncommitted work in progress is invisible here, and that is correct.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
pass=0
fail=0

ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  FAIL  %s (%s)\n' "$1" "$2"; fail=$((fail+1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if ! git -C "$ROOT" archive HEAD | tar -x -C "$tmp"; then
    printf 'could not archive HEAD; is this a git checkout?\n' >&2
    exit 1
fi

# The whole point: HERE resolves, lib/ and VERSION are found, and the guard at bin/keel:35 stays
# quiet. A copy missing any sourced file prints "incomplete install" and exits 1.
out="$("$tmp/bin/keel" version 2>&1)"
if [ "$out" = "$(cat "$ROOT/VERSION")" ]; then
    ok "version, from a tracked-files-only copy"
else
    bad "version, from a tracked-files-only copy" "got: ${out:0:120}"
fi

# version alone only proves the sources loaded. init proves templates/ and lib/detect-stack.sh
# resolve from the copy too, which is where a pruned install would actually bite.
proj="$tmp/proj"
mkdir -p "$proj"
git -C "$proj" init -q
git -C "$proj" config user.email t@example.com
git -C "$proj" config user.name Test
out="$( cd "$proj" && "$tmp/bin/keel" init -y 2>&1 )"
if [ -f "$proj/.keel/profile.json" ]; then
    ok "init writes a profile, from that copy"
else
    bad "init writes a profile, from that copy" "${out:0:160}"
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

Then `chmod +x tests/test-cache-install.sh`.

- [x] **Step 2: Run it and watch what it does**

Run: `tests/test-cache-install.sh`

This is a `verify` task, so the expected result is **PASS**, not fail. Both outcomes are
informative and only one of them continues this plan:

| Outcome | What it means | What to do |
|---|---|---|
| Both cases pass | The claim in the documents is false in the direction task 2 assumes | Continue to step 3 |
| Either case fails | A marketplace copy cannot run the CLI | **Stop.** Task 2 is blocked. Report which case failed and what `bin/keel` printed. Do not edit the documents |

- [x] **Step 3: Register it in the suite**

In `tests/run-tests.sh`, after the `run tests/test-sensitive-guard.sh` line:

```bash
run tests/test-cache-install.sh
```

- [x] **Step 4: Run the suite and watch it pass**

Run: `tests/run-tests.sh` in the background.
Expected: PASS, with `tests/test-cache-install.sh` in the output and nothing else broken.

Then lint. The lint command is a literal file list containing `tests/*.sh`, which already covers the
new file:
`shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh hooks/session-start hooks/context-watch hooks/sensitive-guard`

- [x] **Step 5: Commit**

```bash
git add tests/test-cache-install.sh tests/run-tests.sh
git commit -m "test(install): check bin/keel runs from a tracked-files-only copy

The install documents say a plugin cannot put keel on PATH and therefore a
symlink into a clone is required. Before correcting that claim, check the
thing it will be replaced by: that the CLI resolves its own installation
from the copy a marketplace install produces."
```

---

### Task 2: Rewrite Install and Upgrading around the marketplace

**Files:**
- Modify: `README.md`
- Modify: `docs/03-install-and-distribution.md`
- Modify: `tests/test-cache-install.sh`

**Interfaces:**
- Consumes: `tests/test-cache-install.sh` from task 1
- Produces: nothing other tasks read

**Done when:** `tests/test-cache-install.sh` passes all four cases, and `tests/no-internal-leaks.sh`
and `tests/supply-chain-scan.sh` are still green. The prose itself has no command behind it and is
reviewed, not tested.

**This task is mostly prose, and prose is reviewed rather than tested.** The one testable part is a
regression guard on the false claim, written first below. Do not invent a test for the rest.

- [x] **Step 1: Write the failing test**

Append to `tests/test-cache-install.sh`, before the final `printf`:

```bash
# The claim these documents used to carry, guarded so it cannot come back by copy and paste. A
# plugin's bin/ IS added to the PATH the Bash tool uses; checked 2026-08-16 against the plugins
# reference and against a live session. The narrower true statement, that this PATH is not the
# login shell's, belongs in the documents and is not matched here.
for doc in README.md docs/03-install-and-distribution.md; do
    if grep -qi 'plugins do not extend\|does not put .keel. on your PATH\|which the plugin install does not do' "$ROOT/$doc"; then
        bad "no false PATH claim in $doc" "found the superseded claim"
    else
        ok "no false PATH claim in $doc"
    fi
done
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-cache-install.sh`
Expected: FAIL, two cases, `found the superseded claim` for both files.

- [x] **Step 3: Rewrite the README Install section**

Replace `README.md` lines 10 to 50 (the `## Install` section through the `keel doctor` block) with:

````markdown
## Install

```
/plugin marketplace add gbi-solutions-ltd/keel
/plugin install keel@gbi
```

That is the whole install. The skills, the session hook and the `keel` CLI all arrive with the
plugin: a plugin's `bin/` directory is added to the PATH that Claude Code's Bash tool uses, so
after restarting the session `keel version` in a Claude Code shell prints the VERSION file.

The repository is private and this works anyway: the marketplace is cloned over HTTPS and
authenticates through your ordinary git credential helper. If cloning
`https://github.com/gbi-solutions-ltd/keel.git` in a terminal works, so does this. `gh` is one way
to populate that credential and is not required.

A local path is also accepted, `/plugin marketplace add /absolute/path/to/keel`, which is useful
with no network. It is **not** a live view of your working tree: see Upgrading.

Then, in each project:

```
keel init                        # existing project: detect the stack, write the profile and block
keel new <name> --stack node     # new project: scaffold, git init, CI, a passing sample test
keel doctor                      # check either, non-zero on any problem
```

`init` is idempotent and never overwrites a value you have corrected by hand; detection is a
starting point, not an authority. Use `--force` to overwrite deliberately.

`doctor` runs the whole suite and takes several minutes, most of them silent. It is slow, not hung.

### Optional: `keel` in your own terminal

The plugin puts `keel` on the Bash tool's PATH, not your login shell's. Nothing in the pipeline
needs it there, so do this only if you want to run `keel doctor` outside Claude Code:

```
ln -sfn ~/.claude/plugins/cache/gbi/keel/<version>/bin/keel ~/.local/bin/keel
keel version                                                  # must print the VERSION file
```

**That cache path is keyed by version and changes on every upgrade.** If you want a link that
survives upgrades, point it at a clone instead and keep the clone current with `git pull`.
Symlinking either way is supported and tested: `keel` resolves its own installation through the
link. If it prints `incomplete install`, the link points somewhere without the full repo beside it.
````

- [x] **Step 4: Rewrite the README Upgrading table**

Replace the three-row table at `README.md` lines 57 to 61 and the shell block below it with:

````markdown
| Layer | Lives in | Picks up a change by |
|---|---|---|
| The plugin: skills, hook, and the `keel` CLI | A **copy** at `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` | `/plugin marketplace update gbi` then `/plugin install keel@gbi`, then restart the session |
| Per-project files | Each repo's `.claude/` and `.keel/` | `keel init` in that repo |
| An optional terminal symlink, if you made one | Wherever you pointed it | Re-point it at the new version directory, or point it at a clone and `git pull` |

```
/plugin marketplace update gbi        # fetches the new version
/plugin install keel@gbi              # installs it, then restart the session
cd /path/to/your/project && keel init # updates that project's files
keel doctor
```
````

Leave the two paragraphs below the table that explain the copy-not-link behaviour and the
re-runnability of `keel init`. They are still true and still the common failure.

- [x] **Step 5: Correct `docs/03-install-and-distribution.md`**

Three edits, in place:

1. Line 23, in the install diagram, replace `-> puts the keel CLI on PATH, which the plugin install
   does not do` with `-> optional: puts keel on your login shell's PATH. The plugin already puts it
   on the Bash tool's`.
2. Line 40, replace the sentence asserting that plugins do not extend PATH with:

   > A plugin's `bin/` directory is added to the PATH that Claude Code's Bash tool uses, so the two
   > `/plugin` lines are a complete install for work done inside Claude Code. That PATH is not the
   > login shell's, which is the only thing the symlink below still buys.

3. Lines 44 to 47, change `So the symlink is a documented install step, not an afterthought` to
   `So the symlink is a documented optional step`, and keep the paragraph at lines 51 to 52 about
   `dirname` not following symlinks unchanged. That failure is still real and is why `bin/keel`
   resolves the link by hand.

- [x] **Step 6: Run the test and watch it pass**

Run: `tests/test-cache-install.sh`
Expected: PASS, all four cases.

Then run the full suite in the background, and lint with the profile's command. Two other checks
read these files and must stay green: `tests/no-internal-leaks.sh` and
`tests/supply-chain-scan.sh`.

- [x] **Step 7: Commit**

```bash
git add README.md docs/03-install-and-distribution.md tests/test-cache-install.sh
git commit -m "docs(install): marketplace first, symlink optional

A plugin's bin/ is added to the Bash tool's PATH, so the two /plugin lines
are a complete install and the symlink is no longer required. Both documents
said the opposite and used it as the reason for a manual step. The symlink
stays, documented as optional and for the login shell only, with the warning
that the cache path is keyed by version.

Guarded by a case in tests/test-cache-install.sh so the superseded claim
cannot return by copy and paste."
```

---

### Task 3: A plan task states the command that proves it done

**Files:**
- Modify: `skills/write-plan/references/plan-template.md`
- Modify: `skills/write-plan/SKILL.md`
- Modify: `tests/validate-skills.sh`
- Modify: `tests/test-validate-skills.sh`

**Interfaces:**
- Produces: the literal marker `**Done when:**`, consumed by task 4's tick rule and named in task
  5's hook message
- `write-plan` body is 664 words. This task adds 21. Ceiling 900, warning 700.

**Done when:** `tests/test-validate-skills.sh` passes including the new case, and
`tests/validate-skills.sh` reports 24 skills validated with `write-plan` under 700 words.

- [x] **Step 1: Write the failing test**

Read `tests/test-validate-skills.sh` first and follow its existing case shape. Add a case that
builds a fixture template without the marker and asserts the validator rejects it, and one with the
marker that passes. The rule being tested: `plan-template.md` must contain `**Done when:**`.

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-validate-skills.sh`
Expected: FAIL. The rule does not exist yet, so the validator accepts the fixture that should be
rejected.

- [x] **Step 3: Add the rule to the validator**

In `tests/validate-skills.sh`, beside the other content rules, with a comment in the file's
established voice explaining why it exists:

```bash
# A plan task without a done condition is where "done" becomes an adjective. The template is the
# only place the requirement can be stated once, so this guards it against a well meaning trim.
# It checks the template, not the plans: it cannot tell whether a written condition is a real
# command, and a rule that pretends to is worse than one that states its limit.
grep -q '\*\*Done when:\*\*' skills/write-plan/references/plan-template.md \
    || report "skills/write-plan/references/plan-template.md has no **Done when:** marker"
```

- [x] **Step 4: Add the marker to the template**

In `skills/write-plan/references/plan-template.md`, in the task shape block, immediately after the
`**Interfaces:**` list and before the first `- [x] **Step 1`:

```markdown
**Done when:** `./gradlew test --tests '*SecurityPropertiesTest'` passes and the full suite is green.
```

Then add this section after the `### Why the Interfaces block exists` section:

````markdown
### Why the Done when line exists

`Done` is otherwise an adjective the implementer applies to their own work. The line names the
command a reviewer would run and the result they would see, which turns it into something a third
party can check without reading the diff.

Rules:

- It is a **command from `profile.verify` plus its expected result**, not a description. "The
  validation works" is not a done condition. "`npm test -- payouts` passes" is.
- Where a task genuinely has no command, the line says so in the same place, the way the
  no-test tasks below do: `**Done when:** there is no command. This is a human check against the
  staging environment.` An honest gap reads as a gap. An invented command reads as coverage.
- It appears once per task, above the steps, so a fresh agent dispatched only that section still
  receives it.
````

- [x] **Step 5: Add one line to the skill body**

In `skills/write-plan/SKILL.md`, in Step 3, after the paragraph beginning "A task is the smallest
unit":

```markdown
**Every task carries a `Done when:` line**: a command from `profile.verify` and the result that
counts as passing. A task whose done condition cannot be written as a command says so in that line
rather than omitting it.
```

Then add a row to the Common mistakes table:

```markdown
| A done condition that describes rather than commands | "The validation works" is not checkable. Name the command and its expected result |
```

- [x] **Step 6: Run it and watch it pass**

Run: `tests/test-validate-skills.sh`
Expected: PASS.

Run: `tests/validate-skills.sh`
Expected: PASS, 24 skills validated. Confirm `write-plan` is not reported over the 700 word warning.

Then run the full suite in the background and lint with the profile's command.

- [x] **Step 7: Commit**

```bash
git add skills/write-plan/ tests/validate-skills.sh tests/test-validate-skills.sh
git commit -m "feat(write-plan): every task states the command that proves it done

Done was an adjective the implementer applied to their own work. A Done when
line names a command from profile.verify and its expected result, so a
reviewer can check the claim without reading the diff, and a delegated
subagent that sees only its own section still receives it.

The validator guards the marker in the template. It deliberately does not
check plans: it cannot tell a real command from a sentence, and a rule that
pretends to would be worse than one that states its limit."
```

---

### Task 4: A checkbox is ticked by a command's output, not by belief

**Files:**
- Modify: `skills/execute-plan/SKILL.md`
- Modify: `skills/execute-plan/references/subagent-prompts.md`

**Interfaces:**
- Consumes: the `**Done when:**` marker produced by task 3
- `execute-plan` body was 691 words and landed at **699**, not the 717 predicted here. Correction 3
  above closed the option of crossing 700, so the body carries one load-bearing clause and the
  detail went into `references/subagent-prompts.md`. The tension `docs/standards.md` names is real
  and is resolved rather than ignored: the clause that governs the tick is in the body, where a
  model that loaded nothing else still sees it, and only the dispatch wording is in the reference,
  which is itself read before the first dispatch.

**Done when:** `tests/validate-skills.sh` passes with `execute-plan` under the 900 ceiling, and
`grep -c 'Done when' skills/execute-plan/SKILL.md skills/execute-plan/references/subagent-prompts.md`
reports at least one in each.

- [x] **Step 1: There is no automated test for this**

This task changes instructions to a model. The validator can check that the words are present, which
task 3 already does for the marker they refer to, and cannot check that they are followed. The
behavioural check is an eval scenario, added in task 5 step 6, scored by an agent rather than by a
script. Say this in the commit rather than fabricating a unit test that asserts a `grep` finds a
sentence.

- [x] **Step 2: Change the tick rule in the skill body**

In `skills/execute-plan/SKILL.md`, Step 4, replace:

```markdown
For each task: mark it in progress, follow its steps exactly, run its verifications, tick the
checkboxes in the plan file, then commit as the task specifies.
```

with:

```markdown
For each task: mark it in progress, follow its steps exactly, run its verifications, tick the
checkboxes in the plan file, then commit as the task specifies.

**A box is ticked by output, not by belief.** Run the task's `Done when:` command and read what it
printed before ticking anything. Where a task's done condition says there is no command, say in the
report which human check is outstanding. A tick with no command behind it is the failure this whole
skill exists to prevent.
```

Then add a row to the Common mistakes table:

```markdown
| Ticking a box because the work looks finished | Run the task's `Done when:` command and read its output first |
```

- [x] **Step 3: Carry the rule into the delegated brief**

Read `skills/execute-plan/references/subagent-prompts.md`. The dispatch brief goes to an agent with
no conversation and no plan file loaded, so a rule stated only in the skill body does not reach it.
Add to the task dispatch brief, in that file's existing voice:

```markdown
Before you report, run this task's `Done when:` command and paste its output into your report. If
you did not run it, say so in the first line of your report. A report claiming completion with no
command output in it will be rejected and re-dispatched, which costs more than saying you skipped it.
```

And add to the review brief, in the list of things the reviewer checks:

```markdown
- The report contains the output of the task's `Done when:` command. A report without it is a
  DEVIATES verdict regardless of how the code looks.
```

- [x] **Step 4: Run the checks and watch them pass**

Run: `tests/validate-skills.sh`
Expected: PASS. `execute-plan` is expected to be reported at roughly 717 words, over the 700 target
and under the 900 ceiling. A warning here is the expected outcome, not a failure.

Then run the full suite in the background and lint with the profile's command.

- [x] **Step 5: Commit**

```bash
git add skills/execute-plan/
git commit -m "feat(execute-plan): a box is ticked by output, not by belief

The plan is the progress record and the same agent that did the work ticks
it, so nothing distinguished an honest tick from an optimistic one. Ticking
now requires having run the task's Done when command and read what it
printed, and the rule is repeated in the dispatch and review briefs because
a delegated agent sees only what is sent to it.

No unit test: the validator can check the words are present and cannot check
they are followed. The behavioural check is an eval scenario."
```

---

### Task 5: A guard that will not let a turn end on unverified code

**Files:**
- Create: `hooks/done-guard`
- Create: `tests/test-done-guard.sh`
- Create: `tests/evals/scenarios/done-without-verifying.md`
- Modify: `hooks/hooks.json`
- Modify: `tests/run-tests.sh`
- Modify: `.keel/profile.json`
- Modify: `bin/keel`

**Interfaces:**
- Consumes: `gates.done_verified` and `verify.test` from `.keel/profile.json`, and the `Stop` and
  `SubagentStop` event shape
- Produces: `hooks/done-guard`, added to `verify.lint`

**Done when:** `tests/test-done-guard.sh` passes all eight cases, `tests/run-tests.sh` is green, and
`shellcheck` with the extended `verify.lint` reports `hooks/done-guard` clean.

**The event contract this is written against**, checked 2026-08-16 against the Claude Code hooks
documentation. Do not infer any other field.

| Field | Type | Use here |
|---|---|---|
| `hook_event_name` | string | `"Stop"` or `"SubagentStop"` |
| `stop_hook_active` | boolean | True when a stop hook is already driving the turn. The loop guard |
| `tool_calls` | array of `{tool_name, tool_use_id, tool_input}` | The whole basis of the decision |
| `cwd` | string | Where to start the walk up for the profile |
| `agent_type` | string, subagent only | Named in the message so a blocked subagent knows it is the subject |

Output, on stdout, exit 0: `{"decision": "deny", "reason": "..."}` prevents the stop and shows the
reason to the model. `{"systemMessage": "..."}` warns without blocking. No output allows the stop.

- [x] **Step 1: Write the failing test**

Create `tests/test-done-guard.sh`, following the shape of `tests/test-sensitive-guard.sh`: a
throwaway directory per case, an event built by `python3 -c` so the JSON is valid, and assertions on
the emitted JSON rather than only on the exit code.

```bash
#!/usr/bin/env bash
# Tests for hooks/done-guard, registered on Stop and SubagentStop.
#
# The guard asserts on emitted JSON rather than exit code, for the same reason sensitive-guard's
# tests do: a hook that exits 0 emitting nothing is indistinguishable from one that is not
# installed. The difference from sensitive-guard is case 8. That guard asks a human whenever it
# cannot answer. This one has no human to ask, because a denied Stop just runs again, so it warns
# and allows. A guard that hangs a session is a guard that gets deleted.

set -uo pipefail

GUARD="$(cd "$(dirname "$0")/.." && pwd)/hooks/done-guard"
pass=0
fail=0

fixture() {   # fixture <root> <gate-json-or-empty> <verify-test-json>
    local root="$1" gate="$2" test_cmd="$3"
    mkdir -p "$root/.keel" "$root/lib" "$root/docs"
    printf '{\n  "verify": {"test": %s},\n  "gates": {%s},\n  "docs_root": "docs"\n}\n' \
        "$test_cmd" "$gate" > "$root/.keel/profile.json"
}

# A Stop event. edits is a space separated list of paths; bash is a space separated list of
# commands. Built through python3 so a command containing quotes cannot produce invalid JSON,
# which is the bug that made a sensitive-guard case pass while testing nothing.
event() {   # event <cwd> <stop_hook_active> <edits> <bash-commands>
    CWD="$1" ACTIVE="$2" EDITS="$3" CMDS="$4" python3 -c '
import json, os
calls = []
for p in os.environ["EDITS"].split():
    calls.append({"tool_name": "Edit", "tool_use_id": "x", "tool_input": {"file_path": p}})
for c in os.environ["CMDS"].split("|"):
    if c:
        calls.append({"tool_name": "Bash", "tool_use_id": "y", "tool_input": {"command": c}})
print(json.dumps({"hook_event_name": "Stop", "cwd": os.environ["CWD"],
                  "stop_hook_active": os.environ["ACTIVE"] == "1",
                  "last_assistant_message": "All set.", "tool_calls": calls}))'
}

check() {   # check <name> <want: deny|warn|none> <root> <active> <edits> <cmds>
    local name="$1" want="$2" root="$3" active="$4" edits="$5" cmds="$6" out
    out="$(event "$root" "$active" "$edits" "$cmds" | ( cd "$root" && "$GUARD" ) 2>/dev/null)"
    case "$want" in
        deny) printf '%s' "$out" | grep -q '"decision": *"deny"' \
                 && { printf '  PASS  %s\n' "$name"; pass=$((pass+1)); } \
                 || { printf '  FAIL  %s (expected deny, got: %s)\n' "$name" "${out:0:90}"; fail=$((fail+1)); } ;;
        warn) printf '%s' "$out" | grep -q '"systemMessage"' && ! printf '%s' "$out" | grep -q '"decision": *"deny"' \
                 && { printf '  PASS  %s\n' "$name"; pass=$((pass+1)); } \
                 || { printf '  FAIL  %s (expected a warning, got: %s)\n' "$name" "${out:0:90}"; fail=$((fail+1)); } ;;
        none) [ -z "$out" ] \
                 && { printf '  PASS  %s\n' "$name"; pass=$((pass+1)); } \
                 || { printf '  FAIL  %s (expected nothing, got: %s)\n' "$name" "${out:0:90}"; fail=$((fail+1)); } ;;
    esac
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# 1. No gate declared: silent, like sensitive-guard with no hard_block_paths.
fixture "$tmp/a" '' '"tests/run-tests.sh"'
check "no gate declared, code edited, no test run" none "$tmp/a" 0 "lib/x.sh" ""

# 2. The case the guard exists for.
fixture "$tmp/b" '"done_verified": "required"' '"tests/run-tests.sh"'
check "required: code edited, test never run" deny "$tmp/b" 0 "lib/x.sh" ""

# 3. The test ran, so there is nothing to say.
fixture "$tmp/c" '"done_verified": "required"' '"tests/run-tests.sh"'
check "required: code edited, test run" none "$tmp/c" 0 "lib/x.sh" "tests/run-tests.sh"

# 4. Documentation only. Decision 3: without this the guard fires on every docs commit.
fixture "$tmp/d" '"done_verified": "required"' '"tests/run-tests.sh"'
check "required: only markdown edited" none "$tmp/d" 0 "README.md docs/x.md" ""

# 5. The loop guard. Without it a denied stop denies again, forever.
fixture "$tmp/e" '"done_verified": "required"' '"tests/run-tests.sh"'
check "required: stop_hook_active is already true" none "$tmp/e" 1 "lib/x.sh" ""

# 6. Nothing to check against.
fixture "$tmp/f" '"done_verified": "required"' 'null'
check "required: profile has no test command" none "$tmp/f" 0 "lib/x.sh" ""

# 7. warn says it without stopping the turn.
fixture "$tmp/g" '"done_verified": "warn"' '"tests/run-tests.sh"'
check "warn: code edited, test never run" warn "$tmp/g" 0 "lib/x.sh" ""

# 8. Fails open, and says so. The documented difference from sensitive-guard.
mkdir -p "$tmp/h/.keel"
printf '{ "gates": {"done_verified": "required"}, ' > "$tmp/h/.keel/profile.json"   # truncated on purpose
check "unparseable profile warns and allows the stop" warn "$tmp/h" 0 "lib/x.sh" ""

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

Then `chmod +x tests/test-done-guard.sh`.

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-done-guard.sh`
Expected: FAIL on every case, because `hooks/done-guard` does not exist. Confirm the failures read
as "expected deny, got:" and similar rather than as a shell error about a missing file: if the file
is missing the harness reports differently, and that is not the failure being watched for. Create
an empty executable `hooks/done-guard` that exits 0 first if needed, so the eight failures are the
guard's behaviour rather than its absence.

- [x] **Step 3: Write the guard**

Create `hooks/done-guard`, with a header in the voice `hooks/sensitive-guard` established, stating
the fail-open decision and why it differs from that hook:

```bash
#!/usr/bin/env bash
# The done guard. Registered on Stop and SubagentStop. Idea record
# docs/ideas/verification-backed-done.md, stage 2.
#
# WHAT IT CHECKS, AND WHAT IT DELIBERATELY DOES NOT. It fires on a structural condition: this turn
# edited code and never ran the project's test command. It does not read the assistant's final
# message for the word "done". That was the first design and it is a string matcher over English:
# it misses "that's the retry path covered" and fires on "done reading the config". A guard that
# cries wolf gets switched off, and this one shares hooks.json with sensitive-guard, which must
# never be switched off.
#
# IT FAILS OPEN. This is the opposite of sensitive-guard and the difference is not an oversight.
# That hook asks a human whenever it cannot answer, because `ask` is the one decision the model
# cannot grant itself. A Stop hook has no equivalent: denying a stop it cannot justify produces a
# turn that will not end, with no human in the loop to clear it. So an unreadable profile, an
# absent python3 or a malformed event emits systemMessage and allows the stop.
#
# SILENT UNLESS THE REPOSITORY ASKS FOR IT, matching hard_block_paths. No gates.done_verified means
# one builtin string match and no output.
#
# DOCUMENTATION TURNS PASS. A turn whose only edits are .md files or files under docs_root does not
# need the test suite, and firing on every documentation commit is how this becomes the hook people
# delete.
#
# ITS LIMIT, STATED RATHER THAN DISCOVERED. It matches the profile's test command as a substring of
# a Bash command, so a wrapper script, a changed directory or an alias runs the suite without being
# seen, and a command that merely mentions the string counts as having run it. This raises the cost
# of claiming done without checking; it is not a proof that the suite passed. It cannot see the
# exit code, and does not pretend to: `ship` is the gate that reads results.

set -uo pipefail
```

The body follows `sensitive-guard`'s order exactly: walk up from `$PWD` for `.keel/profile.json`
and exit 0 if absent; read the profile with `$(<...)` and exit 0 unless it contains
`"done_verified"`; read the event from stdin; exit 0 unless it contains `"stop_hook_active": false`
or the field is absent; then hand the event and the profile path to `python3` through the
environment, exactly as `sensitive-guard` does with `KEEL_EVENT` and `KEEL_PROFILE`. If `python3` is
absent, emit `systemMessage` and exit 0 rather than blocking.

The python section:

```python
import json, os, sys

def warn(reason):
    print(json.dumps({"systemMessage": "keel done-guard: " + reason}))
    sys.exit(0)

def deny(reason):
    print(json.dumps({"decision": "deny", "reason": "keel: " + reason}))
    sys.exit(0)

try:
    ev = json.loads(os.environ.get("KEEL_EVENT") or "{}")
except ValueError:
    warn("the stop event could not be parsed, so this turn was not checked.")

if ev.get("stop_hook_active"):
    sys.exit(0)                      # already looping; never deny twice

try:
    prof = json.load(open(os.environ["KEEL_PROFILE"]))
except (ValueError, OSError, KeyError):
    warn("this repository declares gates.done_verified but its profile could not be read, so this "
         "turn was not checked.")

mode = (prof.get("gates") or {}).get("done_verified") or "off"
if mode == "off":
    sys.exit(0)

test_cmd = (prof.get("verify") or {}).get("test")
if not test_cmd:
    sys.exit(0)                      # nothing to check against

docs_root = (prof.get("docs_root") or "docs").rstrip("/")

def is_code(p):
    return not (p.endswith(".md") or p == docs_root or p.startswith(docs_root + "/"))

edited, ran = [], False
for c in ev.get("tool_calls") or []:
    name = c.get("tool_name")
    ti = c.get("tool_input") or {}
    if name in ("Edit", "Write", "NotebookEdit"):
        p = ti.get("file_path") or ti.get("notebook_path") or ""
        if p and is_code(p):
            edited.append(p)
    elif name == "Bash" and test_cmd in (ti.get("command") or ""):
        ran = True

if not edited or ran:
    sys.exit(0)

who = "This subagent" if ev.get("hook_event_name") == "SubagentStop" else "This turn"
shown = ", ".join(sorted(set(edited))[:5])
msg = ("%s edited %d file(s) including %s and never ran `%s`. Run it and report what it printed "
       "before ending the turn. If the work is genuinely incomplete, say what remains instead of "
       "ending on it." % (who, len(set(edited)), shown, test_cmd))
deny(msg) if mode == "required" else warn(msg)
```

- [x] **Step 4: Run the test and watch it pass**

Run: `tests/test-done-guard.sh`
Expected: PASS, 8 cases.

- [x] **Step 5: Register, lint and declare it**

1. `hooks/hooks.json`: add `Stop` and `SubagentStop` arrays, each with one command entry pointing at
   `"${CLAUDE_PLUGIN_ROOT}/hooks/done-guard"`, `"shell": "bash"`, `"async": false`, matching the
   existing entries' shape. No matcher: these events have no tool to match on.
2. `.keel/profile.json`: add `"done_verified": "required"` to `gates`, and append `hooks/done-guard`
   to `verify.lint`. **Without the lint change the new hook is never linted**, because that command
   is a literal file list and does not glob `hooks/`.
3. `tests/run-tests.sh`: add `run tests/test-done-guard.sh` after the sensitive-guard line.
4. `bin/keel`: find where `init` writes the gates block and add `done_verified` with the value
   `warn` for new projects. Grep for `hard_block_paths` and `commit_guard` to find the right place.
   New projects get the warning, not the refusal, because a hook that stops turns is not something to
   switch on for a repository without asking.
5. `templates/keel-profile.example.json` and `templates/profile.schema.json`: add `done_verified`
   with its three allowed values (`required`, `warn`, `off`, the enum the schema already defines). `keel doctor` validates profiles against the schema, so a value
   the schema does not know is a doctor failure in every project that gets it.

- [x] **Step 6: Add the eval scenario**

Create `tests/evals/scenarios/done-without-verifying.md`, following the shape of the five existing
scenarios. `Inject: execute-plan tdd`. The pressure prompt gives a short plan with `Done when:`
lines, has the user say the tests are slow and to just mark the tasks off, and scores on whether the
run ticks a box without the command's output. This is the behavioural check for tasks 3, 4 and 5,
and it is dispatched and scored by an agent rather than by a script, which `tests/evals/README.md`
already explains and this scenario inherits.

Record the run in `tests/evals/results.md` the way the existing five are recorded.

- [x] **Step 7: Run everything and watch it pass**

Run: `tests/run-tests.sh` in the background.
Expected: PASS, with `tests/test-done-guard.sh` in the output.

Run the profile's lint command, now including `hooks/done-guard`. Expected: clean.

There is no typecheck or build command in this project.

- [x] **Step 8: Commit**

```bash
git add hooks/done-guard hooks/hooks.json tests/test-done-guard.sh tests/run-tests.sh \
        tests/evals/scenarios/done-without-verifying.md tests/evals/results.md \
        .keel/profile.json templates/keel-profile.example.json templates/profile.schema.json bin/keel
git commit -m "feat(hooks): refuse to end a turn that edited code and never ran the tests

Registered on Stop and SubagentStop, so it covers delegated work, which is
where a claim of done is least visible. It fires on a structural condition
rather than on the word done in the final message: matching English misses
real claims and fires on innocent ones, and a guard that cries wolf gets
switched off alongside sensitive-guard.

It fails open where sensitive-guard fails closed. Denying a stop the guard
cannot justify produces a turn that will not end and has no human in it to
clear. An unreadable profile warns and allows.

Silent unless the repository sets gates.done_verified. keel sets required for
itself; keel init writes warn for new projects."
```

---

### Task 6: Name the model on the briefs keel already dispatches

**Files:**
- Modify: `skills/repo-snapshot/SKILL.md`
- Modify: `skills/port-assess/SKILL.md`
- Modify: `skills/apex-port-plan/SKILL.md`
- Modify: `skills/shape-idea/SKILL.md`
- Modify: `skills/execute-plan/references/subagent-prompts.md`
- Modify: `docs/standards.md`
- Modify: `tests/validate-skills.sh`
- Modify: `tests/test-validate-skills.sh`

**Interfaces:**
- Produces: the set of model aliases any skill may name, enforced by the validator
- Word cost per skill body: 9 to 12 words. `repo-snapshot` 699 to 708, `port-assess` 697 to 706,
  `apex-port-plan` 674 to 683, `shape-idea` 687 to 696. All under the 900 ceiling; the first two
  cross the 700 warning.

**Done when:** `tests/validate-skills.sh` passes with 24 skills validated, and
`tests/test-validate-skills.sh` passes including the new model-alias case.

**What this task is not.** It does not route by task complexity and it does not send anything to a
third-party CLI. `docs/ideas/model-routing.md` records why: a session's model cannot be changed by a
plugin at all, and delegation pays on long mechanical work rather than on simple work, so a
complexity router keys on the wrong variable and fails quietly.

- [x] **Step 1: Write the failing test**

Add a case to `tests/test-validate-skills.sh`: a fixture skill naming a model that does not exist
(`model: sonnet-4-turbo`) must be rejected, and one naming `sonnet` must pass. The rule catches an
invented or stale alias, which is the failure that would silently send a brief to nothing.

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-validate-skills.sh`
Expected: FAIL. The validator has no such rule, so the fixture that should be rejected is accepted.

- [x] **Step 3: Add the rule**

In `tests/validate-skills.sh`:

```bash
# A brief dispatched to a model alias that does not exist is a brief dispatched to nothing, and the
# failure is silent. The five aliases below are the ones Claude Code accepts; a full model id is
# also valid and is deliberately not permitted here, because an id pinned in a skill goes stale
# without anything noticing while an alias tracks the current model.
bad_models=$(grep -rhoE 'model `[a-z0-9.-]+`' skills/*/SKILL.md skills/*/references/*.md \
    | sed 's/^model `//; s/`$//' | sort -u \
    | grep -vxE 'sonnet|opus|haiku|fable|inherit' || true)
[ -z "$bad_models" ] \
    || report "unknown model alias in a skill: $(printf '%s' "$bad_models" | tr '\n' ' ')"
```

Read the surrounding rules first and match their reporting helpers exactly.

- [x] **Step 4: Pin the models**

Four edits, each one line, each naming the model and requiring the announcement.

`skills/repo-snapshot/SKILL.md`, replacing the line above the brief table:

```markdown
Dispatch these `Explore` agents **in one message** so they run concurrently, each with model
`sonnet`, and say in one line which model you dispatched.
```

`skills/port-assess/SKILL.md` and `skills/apex-port-plan/SKILL.md`, in the sentence above each brief
table, add: `Dispatch on \`sonnet\` and say so in one line.`

`skills/shape-idea/SKILL.md`, Step 2, change `Delegate wide reading to subagents.` to
`Delegate wide reading to subagents on \`sonnet\`, and say so in one line.`

`skills/execute-plan/references/subagent-prompts.md`, in the dispatch guidance:

```markdown
**Dispatch implementation and review with model `inherit`.** These write code under the TDD gate and judge
whether a verdict is right, which is the work least worth making cheaper. The fan-out reading
briefs in other skills go to `sonnet`; this one does not.
```

- [x] **Step 5: Record the standard**

Add a section to `docs/standards.md` in that file's `Rule / Why` shape:

```markdown
## A dispatch names its model, and says so

**Rule:** a skill that dispatches a subagent names the model on the brief and announces it in one
line. Wide mechanical reading goes to `sonnet`. Anything writing code under a gate, or judging
another agent's verdict, stays `inherit`. No brief names a full model id, and none names `haiku`
yet.

**Why:** a session's model cannot be changed by a plugin, checked 2026-08-16, so delegation is the
only routing available and it is not free: a subagent starts cold and re-reads context the main
thread already holds. That makes the payoff depend on the work being long and mechanical rather
than on it being simple, which is why nothing here keys on complexity. `haiku` waits on one
measured comparison, recorded as open question 3 in `docs/ideas/model-routing.md`. The
announcement is free and was asked for directly.
```

- [x] **Step 6: Run the checks and watch them pass**

Run: `tests/test-validate-skills.sh`
Expected: PASS, including the new case.

Run: `tests/validate-skills.sh`
Expected: PASS, 24 skills validated, descriptions about 1066 tokens, unchanged because no
description was touched. `repo-snapshot` and `port-assess` are expected over the 700 warning and
under the 900 ceiling.

Then run the full suite in the background and lint with the profile's command.

- [x] **Step 7: Commit**

```bash
git add skills/repo-snapshot/ skills/port-assess/ skills/apex-port-plan/ skills/shape-idea/ \
        skills/execute-plan/references/subagent-prompts.md docs/standards.md \
        tests/validate-skills.sh tests/test-validate-skills.sh
git commit -m "feat(skills): name the model on every subagent brief, and announce it

Five skills dispatched subagents and none named a model, so every brief
inherited the session model. The fan-out reading briefs go to sonnet; the
implementation and review briefs stay on inherit, because code under the TDD
gate is the work least worth making cheaper.

No complexity router and no third-party routing. A session's model cannot be
changed by a plugin at all, and delegation pays on long mechanical work
rather than on simple work, so routing by guessed difficulty keys on the
wrong variable. Recorded in docs/ideas/model-routing.md.

The validator rejects a model alias Claude Code does not accept, which is
otherwise a brief dispatched to nothing with no error."
```

---

## Open questions

None block execution. Two are deliberately deferred and recorded rather than answered here:

1. **Should `keel doctor` compare the running CLI's version against the loaded plugin's?** The drift
   is real and observable today (`~/.claude/plugins/cache/gbi/keel/` held `0.6.0` against a working
   tree at `0.6.1`). It is out of scope for task 2, which only has to stop the documents being
   wrong. Raised in `docs/ideas/marketplace-first-install.md`.
2. **Does the done guard need a per-task escape hatch?** Every other keel gate has one the model can
   take by saying so. This one currently has only the repository-level `gates.done_verified`. Leave
   it until the eval scenario in task 5 shows whether the refusal is too blunt in practice.

## What this plan does not cover

`docs/ideas/concise-responses.md`. It was shaped and not agreed, and its recommendation depends on a
measurement nobody has taken: what share of reply length keel is actually responsible for. It is not
in any task above, and adding a brevity rule to the always-loaded block while that block is a
recorded 628-token departure against a 450 budget would be the wrong move regardless.
