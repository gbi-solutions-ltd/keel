# Addressable plan steps Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Once task 4 has landed, find your
> place with `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`; until
> then, tick by hand. Tick on output you read.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** every step in a new plan carries an id, and `keel plan status` and `keel plan tick` read
and change steps by that id, which `execute-plan` and `ship` then use.
**Stories:** S-01 to S-09 in `docs/stories/addressable-plan-steps.md`, from
`docs/prd/addressable-plan-steps.md` (approved 2026-09-28).
**ADRs:** none. ADR-0001 (the skill body ceiling) and ADR-0005 (one skill body across harnesses)
constrain tasks 8 to 10; neither is changed.
**Architecture:** the plan template writes each step as `- [ ] **Step 3.2: <title>**`, with the box
` ` open, `x` done, `-` deferred or `~` not applicable, and a reason or note after the title. Two new
`bin/keel` subcommands share one awk library, `PLAN_AWK_LIB`, that skips fenced code blocks and
parses a step line: `plan status` counts steps per task and names the next open one, and `plan tick`
rewrites one step's line through a temporary file under a `mkdir` lock. A plan with no ids is
reported as unaddressable with exit 3, and both skills fall back to editing by hand.

**Order, decided 2026-09-28, Bernard:** this plan runs before
`docs/plans/2026-09-28-skill-review-findings.md`. Both plans' eval arms are approved to run as
written.

**Decisions settled here, 2026-09-28** (the stories left them to the plan):

| Question | Answer |
|---|---|
| Id syntax | `<task>.<step>` inside the bold title, `**Step 1b.2: Run it and watch it fail**`. Task is digits then optional lowercase letters, so `1b`; step is digits. Keeps the template's `Step` wording, so a reader sees the same shape |
| State marks | `[ ]` open, `[x]` done (`[X]` read as done), `[-]` deferred, `[~]` not applicable. GitHub renders only the first two as boxes; the other two stay readable as text |
| Where a reason or note goes | On the step's own line after the closing `**`: ` Deferred: <reason>`, ` Not applicable: <reason>`, ` Note: <text>`. One line keeps "changes no other line" (FR-07) literal, so a note holding a newline is refused |
| Ticking a parked step done | Drops its ` Deferred:` or ` Not applicable:` reason; a ` Note:` is kept and a new one appended |
| `status` output | One `task <id>: <n> done, <n> open, <n> deferred, <n> not applicable` line per task in order of first appearance, then `next: <id>` or `next: none`, then one `problem: ...` line per reasonless deferral, repeated id, open checkbox that is not a step, or fence that never closes |
| Exit codes | 0 fine; 1 a problem, an unknown or repeated id, a missing reason, or a usage error; 3 unaddressable. `ship` passes a plan on exit 0 with `next: none` |
| A repeated id | `status` reports it as a problem and `tick` refuses it. Not in the stories: an id naming two steps defeats FR-02, so both commands say so rather than guess |
| Concurrent ticks (FR-16) | A `mkdir <plan>.lock` lock, retried every 0.1 s for about ten seconds, then a failure naming the lock. `flock` is absent on macOS; `mkdir` is atomic everywhere keel runs |
| Where `execute-plan`'s new sentence finds its words | The body is at 896 of 900. Step 4 gains 22 words; the "Overlapping tasks the plan did not declare a batch" mistakes row (21 words) goes, since Step 3 states the same rule and links `parallel-batches.md`. Measured result: 897 |
| The pinned tick sentence (CON-04) | Left word for word. The new sentence joins the paragraph before it, so `tests/test-eval-harness.sh` case 25 needs no change. S-08's scenario "its pin updated" is met by the pin still passing |

**Facts established while planning, 2026-09-28, each run rather than assumed:**

| Fact | How it was checked |
|---|---|
| The parser below skips fenced examples, including a ```` fence holding a ``` one and an indented fence, and reads `1b.2` ids | A scratch plan through `/usr/bin/awk` (version 20200816, macOS's): four real steps printed, three fenced ones skipped |
| `awk -v` rewrites `\t` in a value to a tab; `ENVIRON` keeps it | Both printed from `/usr/bin/awk` |
| Twenty ticks started together with no lock land 3, 9 and 6 of 20 in three runs | A scratch copy of `plan_tick` without `plan_lock` |
| With the lock, a first version landed 18 of 20 twice: the EXIT trap's second `rmdir` removed the next tick's lock. Clearing the trap before releasing, `plan_unlock` below, landed 20 of 20 in eight runs | The same scratch run |
| A tick facing a held lock fails after 11.3 s, naming it | Timed in scratch |
| `bin/keel version` starts in 0.046 s; `status` on a 2,442-line, 35,604-word plan takes 0.022 s through the scratch copy | Timed with Python's `time.time()` |
| `execute-plan` is 896 body words, `ship` 703; after tasks 8 and 9 they measure 897 and 749 | `awk 'f>=2;/^---$/{f++}' <file> \| wc -w` on edited scratch copies |
| `done-without-verifying` injects `execute-plan tdd`; `ship-with-flaky-tests` injects `ship`. No other scenario injects either | `grep '^Inject:' tests/evals/scenarios/*.md` |
| `docs/plans/2026-09-27-push-scan-reads-pushed-commits.md` has no step ids | The scratch `status` on it exited 3 |

**Concurrent batches:** none. Tasks 2 to 7 all change `bin/keel` and `tests/test-plan.sh`, and tasks
8 and 9 both change `tests/test-plan.sh`, so all ten run in order.

## Global constraints

- Verify commands, from `.keel/profile.json`: test `tests/run-tests.sh`; one test file
  `tests/{name}`, so `tests/test-plan.sh` or `tests/test-validate-skills.sh`; typecheck and build are
  `null`, since there is nothing to compile; lint is:

  ```bash
  shellcheck -x bin/keel bin/keel-fleet lib/*.sh lib/harness/*.sh tests/*.sh tests/evals/run.sh \
    tests/evals/stage.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard
  ```

- `tests/run-tests.sh` takes about seven minutes and prints nothing until each file finishes. Slow
  is not hung.
- Lint after each file edit, not at the end of the task.
- Never start on `main`. Work on `sandbox`, which is where this repository's pull requests come
  from.
- `tests/test-keel.sh` run directly inherits the machine's global git config, which only
  `tests/run-tests.sh` isolates. Before the first run, from a directory outside any repository,
  `git config --show-scope --get core.hooksPath` and `git config --show-scope --get init.templateDir`
  must both print nothing; if either prints a value, stop and report.
- `bin/keel` runs under `set -uo pipefail` and must run on bash 3.2: never expand `"${arr[@]}"`
  on an array that can be empty without first checking `${#arr[@]}`.
- No em dash and no en dash anywhere: code, comments, strings, docs, commit messages.
- Prose in markdown wraps at 100 columns; tables do not (docs/standards.md, "Prose wraps at 100
  columns; tables do not").
- Every rule a comment states carries its reason (docs/standards.md, "Every rule carries its
  reason").
- A gate is never weakened so this repository can pass it (docs/standards.md, "A gate is never
  weakened so this repository can pass it").
- Shipped prose states the current state; history lives in `CHANGELOG.md` (docs/standards.md,
  "Shipped prose states the current state, and history lives in the changelog").
- Documentation lands in the same commit as the change: a line under `## Unreleased` at the top of
  `CHANGELOG.md`, plus any document the change makes wrong, stating what is true now.
- **Citations into `bin/keel` use a phrase, never a line number**, in the form
  `` bin/keel#<text from the line> ``; `tests/validate-citations.sh` refuses a line number into it.
  A phrase must occur **once** in its file (`grep -cF '<phrase>' <file>`) and contain no `|`.
- After an edit that inserts or deletes lines in any tracked file, run `tests/validate-citations.sh`
  and repair what it reports; then grep the repository for `<that file>:<N>` citations with N at or
  after the edit, compare `git show HEAD:<file> | sed -n '<N>p'` with the current line N, and repair
  each whose target moved by citing a phrase instead. Leave citations that were already wrong at
  HEAD alone.
- A skill body stays at or under 900 words, and one over 700 owes a passing eval arm at its new
  length, recorded in `tests/evals/results.md` (ADR-0001). One skill body serves every harness
  (ADR-0005).
- `tests/test-eval-harness.sh` case 25 pins `execute-plan` Step 4's sentence starting "Tick on
  output you read." word for word. No task changes that paragraph.
- The plan itself is scanned by `tests/supply-chain-scan.sh`, which reads untracked files.
- Stage named paths only. Never `git add -A`, `git add .` or `git commit -a`.
- Commit messages are conventional, title and body only: no `Co-Authored-By`, no robot emoji, no
  generated-with line.
- Do not delete a file you did not create, except where a task names it. If `git status` shows
  something unexpected, report it and leave it alone.

---

### Task 1: The plan template gives every step an id, and the validator keeps it there

**Story:** S-01
**Files:**
- Modify: `skills/write-plan/references/plan-template.md`
- Modify: `tests/validate-skills.sh`
- Test: `tests/test-validate-skills.sh`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: nothing
- Produces: the step line format every later task parses, `- [<mark>] **Step <task>.<step>:
  <title>**<tail>`, with marks ` `, `x`, `-`, `~`

**Depends on:** none

**Done when:** `tests/test-validate-skills.sh` passes.

- [x] **Step 1.1: Write the failing test**

In `tests/test-validate-skills.sh`, replace the `m_plan_template_no_marker` and
`m_plan_template_marker` fixtures, whose steps have no id. The first would then be refused for the
missing id as well as the missing marker, so it would still pass with the marker check deleted; the
second would be refused outright. Add two cases after them:

```bash
m_plan_template_no_marker() {
    mkdir -p "$1/skills/write-plan/references"
    printf '# Plan template\n\n**Interfaces:**\n\n- [ ] **Step 1.1: Write the failing test**\n' \
      > "$1/skills/write-plan/references/plan-template.md"
}
run "a plan template with no Done when marker is rejected" 1 m_plan_template_no_marker

m_plan_template_marker() {
    mkdir -p "$1/skills/write-plan/references"
    printf '# Plan template\n\n**Done when:** `npm test` passes.\n\n- [ ] **Step 1.1: Write the failing test**\n' \
      > "$1/skills/write-plan/references/plan-template.md"
}
run "a plan template carrying the marker passes" 0 m_plan_template_marker

# The plan template's step ids. keel plan status and keel plan tick find a step by the id in its
# bold title and read a plan without ids as unaddressable, so a template trimmed of them writes
# plans neither command can read.
m_plan_template_no_ids() {
    mkdir -p "$1/skills/write-plan/references"
    printf '# Plan template\n\n**Done when:** `npm test` passes.\n\n- [ ] **Step 1: Write the failing test**\n' \
      > "$1/skills/write-plan/references/plan-template.md"
}
run "a plan template whose steps carry no id is rejected" 1 m_plan_template_no_ids

# One step left in the old form is refused too: a plan copied from the template would hold both.
m_plan_template_mixed_ids() {
    mkdir -p "$1/skills/write-plan/references"
    printf '# Plan template\n\n**Done when:** `npm test` passes.\n\n- [ ] **Step 3.1: Write the failing test**\n\n   - [ ] **Step 5: Commit**\n' \
      > "$1/skills/write-plan/references/plan-template.md"
}
run "a plan template with one step missing its id is rejected" 1 m_plan_template_mixed_ids

# A template with no step at all is refused too. Only the "no step carrying an id" check sees it,
# since there is no old-form step for the other check to find, so this case is what fails if that
# check is deleted.
m_plan_template_no_steps() {
    mkdir -p "$1/skills/write-plan/references"
    printf '# Plan template\n\n**Done when:** `npm test` passes.\n' \
      > "$1/skills/write-plan/references/plan-template.md"
}
run "a plan template with no step at all is rejected" 1 m_plan_template_no_steps
```

- [x] **Step 1.2: Run it and watch it fail**

Run: `tests/test-validate-skills.sh`
Expected: FAIL on the three new cases, `a plan template whose steps carry no id is rejected
(expected exit 1, got 0)`, `a plan template with one step missing its id is rejected (expected exit
1, got 0)` and `a plan template with no step at all is rejected (expected exit 1, got 0)`. Both
marker cases still pass.

- [x] **Step 1.3: Write the minimal implementation**

In `tests/validate-skills.sh`, directly after the block that ends with the `**Done when:**` marker
report (the `fi` after `grep -q '\*\*Done when:\*\*'`), add:

```bash
# The plan template's step ids, **Step <task>.<step>: ...**. keel plan status and keel plan tick
# find a step by that id and read a plan without ids as unaddressable, so a template trimmed of them
# writes plans neither command can read. A step left in the old form, **Step 5: ...**, is refused
# too, because a plan copied from the template would then hold both.
if [ -f skills/write-plan/references/plan-template.md ]; then
    grep -Eq '^ *- \[ \] \*\*Step [0-9]+[a-z]*\.[0-9]+: ' skills/write-plan/references/plan-template.md \
      || report "skills/write-plan/references/plan-template.md has no step carrying an id, **Step <task>.<step>: ...**. keel plan status and keel plan tick read a plan without them as unaddressable."
    if grep -Eq '^ *- \[.\] \*\*Step [0-9]+[a-z]*: ' skills/write-plan/references/plan-template.md; then
        report "skills/write-plan/references/plan-template.md has a step with no id, **Step <n>: ...**. Give it one, **Step <task>.<step>: ...**."
    fi
fi
```

Then change `skills/write-plan/references/plan-template.md`:

1. In the Header block, replace the banner's lines two to four:

   ```markdown
   > Steps use `- [ ]` checkboxes; tick them as you go, on output you read.
   > A box for a step you did not perform yourself is ticked only with a note naming what you did
   > and did not witness, or left unticked and reported.
   ```

   with:

   ```markdown
   > Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
   > `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
   > read; where `keel` cannot run, tick by hand.
   > A box for a step you did not perform yourself is ticked only with a note naming what you did
   > and did not witness (`--note <text>`), or left unticked and reported.
   ```

2. In the Task shape example (Task 3), rename the five steps `**Step 1: Write the failing test**`
   to `**Step 3.1: Write the failing test**`, `**Step 2: Run it and watch it fail**` to
   `**Step 3.2: Run it and watch it fail**`, `**Step 3: Write the minimal implementation**` to
   `**Step 3.3: Write the minimal implementation**`, `**Step 4: Run it and watch it pass**` to
   `**Step 3.4: Run it and watch it pass**`, and `**Step 5: Run the suite at the unit boundary, then
   hand over**` to `**Step 3.5: Run the suite at the unit boundary, then hand over**`.
3. In rule 2 of "Tasks that run concurrently", rename `   - [ ] **Step 5: Commit**` to
   `   - [ ] **Step 1.5: Commit**`.
4. In "Tasks with no test", rename `- [ ] **Step 1: There is no test for this**` to
   `- [ ] **Step 4.1: There is no test for this**`.
5. After the section "### A step somebody else already did" and before "## Task granularity", add:

   ````markdown
   ### Step ids and states

   Every step carries an id, `<task>.<step>`, at the start of its bold title:
   `**Step 3.2: Run it and watch it fail**` is task 3's second step, and task 1b's first is `1b.1`.
   Ids are unique within the plan. `keel plan status <plan>` counts each task's steps and names the
   next open one, and `keel plan tick <plan> <id>` changes one step, both by id; a plan without ids
   is reported as unaddressable and is read and ticked by hand.

   A step is in one of four states, shown by its box, with anything more on the same line after
   the title:

   | Box | State | After the title |
   |---|---|---|
   | `[ ]` | open | nothing |
   | `[x]` | done | ` Note: <text>`, where the step was not witnessed (`--note <text>`) |
   | `[-]` | deferred | ` Deferred: <reason>`, required (`--defer <reason>`) |
   | `[~]` | not applicable | ` Not applicable: <reason>`, required (`--not-applicable <reason>`) |

   A step inside a fenced code block is an example, like this template's own, and is never counted.
   ````

6. In "## Self-review", add a seventh item after item 6:

   ```markdown
   7. Every step's bold title opens with its id, `Step <task>.<step>:`, and no id repeats:
      `keel plan status <plan>` exits 0, and no step title is in the old form, `**Step <n>: `.
   ```

Add at the top of `## Unreleased` in `CHANGELOG.md`:

```markdown
- Plans written from the template give every step an id, `**Step <task>.<step>: ...**`, and a step
  can be deferred, `[-]`, or not applicable, `[~]`, each with its reason after the title.
  `tests/validate-skills.sh` fails a plan template whose steps lost their ids.
```

Lint: the profile's shellcheck command.

- [x] **Step 1.4: Run it and watch it pass**

Run: `tests/test-validate-skills.sh`
Expected: PASS, every case, the five above included.

Run: `tests/validate-skills.sh`
Expected: no error naming `plan-template.md`, since step 1.3 gave every template step an id.

- [x] **Step 1.5: Run the suite at the unit boundary, then hand over**

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
Then `tests/validate-citations.sh`, repairing anything citing `plan-template.md` by a line this
task moved, per the Global constraints.

```bash
git add skills/write-plan/references/plan-template.md tests/validate-skills.sh \
        tests/test-validate-skills.sh CHANGELOG.md
git status --porcelain
```

Stage exactly those paths, plus any file a citation repair touched, named in the report, and stop.
**Do not commit.** The coordinator commits after both review passes, with
`git commit -m "feat(write-plan): every step in a new plan carries an id"`.

**Review record, 2026-09-28.** The first attempt was DEVIATES on citations it moved and left stale
(`:790`, `:425`) and was discarded; this task then gained the no-steps case. The second attempt
COMPLIES; its quality review raised two should-fix items, both fixed and re-reviewed: self-review
item 7's check, and a dangling `:37-38` shorthand in `docs/ideas/standards-that-bind.md`, whose repair
moved lines and, with Bernard's approval, repaired every moved citation across seven more documents.
Considered and not acted on: the template names `keel plan` commands that exist only once task 4
lands; the validator accepts indented steps and any mark while the parser does not; "Ids are unique
within the plan" states no reason; two `if [ -f ... ]` guards could be one block; long comment lines
in `tests/test-validate-skills.sh`; a shorthand path in the coding-standards stories the validator
cannot check; a dated record's `unread:` marker rewritten to phrase form.

### Task 2: `keel plan status` reports a plan's progress

**Story:** S-02
**Files:**
- Modify: `bin/keel`
- Create: `tests/test-plan.sh`
- Modify: `tests/run-tests.sh`
- Modify: `docs/03-install-and-distribution.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: the step line format from task 1
- Produces: `PLAN_AWK_LIB` in `bin/keel`, the awk functions `fenced(line)` and `step(line)`, the
  latter setting `sid`, `smark`, `stitle` and `stail`; `cmd_plan`; `plan_status <plan>`;
  `tests/test-plan.sh` with helpers `ok`, `bad`, `mkplan <file> <line>...` and the temp directory
  `$d`

**Depends on:** task 1

**Done when:** `tests/test-plan.sh` passes.

- [x] **Step 2.1: Write the failing test**

Create `tests/test-plan.sh`, executable (`chmod +x`):

```bash
#!/usr/bin/env bash
# Tests for `keel plan status` and `keel plan tick`. Run from the repository root.
#
# Every case writes its own plan into a temporary directory. The one case that reads a committed
# plan, one written before step ids existed, only reads it.
#
# The `condition && ok || bad` idiom is safe here, and only here, because both helpers return 0.
# shellcheck disable=SC2015
# Single quotes are deliberate throughout: the fixtures are literal markdown, backticks included.
# shellcheck disable=SC2016
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEEL="$ROOT/bin/keel"
pass=0
fail=0

ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }

d="$(mktemp -d)"

# mkplan <file> <line>...: a plan holding a heading and then the given lines, one per argument.
mkplan() {
    local f="$1"; shift
    { printf '# A plan\n\n### Task 1: a task\n\n'; printf '%s\n' "$@"; } > "$f"
}

# ---- status: counts per task, and the next open step ----------------------------------------

p="$d/counts.md"
mkplan "$p" \
  '- [x] **Step 1.1: Write the failing test**' \
  '- [x] **Step 1.2: Run it and watch it fail**' \
  '- [ ] **Step 1.3: Write the minimal implementation**' \
  '- [ ] **Step 2.1: Write the failing test**' \
  '- [ ] **Step 2.2: Run it and watch it fail**'
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
want="$(printf '%s\n' \
  'task 1: 2 done, 1 open, 0 deferred, 0 not applicable' \
  'task 2: 0 done, 2 open, 0 deferred, 0 not applicable' \
  'next: 1.3')"
[ "$rc" -eq 0 ] && [ "$out" = "$want" ] \
  && ok "status counts each task's steps and names the first open one" \
  || bad "status counts" "rc=$rc, got: $out"

p="$d/all-done.md"
mkplan "$p" '- [x] **Step 1.1: Write the failing test**' '- [X] **Step 1.2: Run it and watch it fail**'
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | tail -1)" = "next: none" ] \
  && case "$out" in *"task 1: 2 done, 0 open"*) true ;; *) false ;; esac \
  && ok "status says no step is open when every step is done, [X] included" \
  || bad "status all done" "rc=$rc, got: $out"

p="$d/parked.md"
mkplan "$p" \
  '- [x] **Step 1.1: a**' \
  '- [-] **Step 1.2: b** Deferred: moved to the follow-up plan' \
  '- [~] **Step 1.3: c** Not applicable: no behaviour to test' \
  '- [ ] **Step 1.4: d**'
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
case "$out" in
  *"task 1: 1 done, 1 open, 1 deferred, 1 not applicable"*) ok "status counts deferred and not-applicable steps apart" ;;
  *) bad "status parked" "rc=$rc, got: $out" ;;
esac

# A step inside a fenced code block is an example, as the template's own are. The ```` fence holds
# a ``` one, which must not close it, and an indented fence follows. The last lines pin a fence
# closed by a CRLF line and an inline span of backticks at the start of a line, neither of which
# may hide a step.
p="$d/fenced.md"
mkplan "$p" \
  '- [ ] **Step 1.1: a**' \
  '````markdown' \
  '- [ ] **Step 9.1: an example inside a fence**' \
  '```bash' \
  '- [x] **Step 9.2: still inside the outer fence**' \
  '```' \
  '````' \
  '   ```bash' \
  '- [ ] **Step 9.3: inside an indented fence**' \
  '   ```' \
  '- [x] **Step 1.2: b**' \
  '```bash' \
  '- [ ] **Step 9.4: inside a fence whose closing line ends in CR**' \
  $'```\r' \
  '```` ```bash ```` is inline code at the start of a line, not a fence' \
  '- [x] **Step 1.3: counted after both**'
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
want="$(printf '%s\n' 'task 1: 2 done, 1 open, 0 deferred, 0 not applicable' 'next: 1.1')"
[ "$rc" -eq 0 ] && [ "$out" = "$want" ] && ok "status never counts a step inside a fenced code block" \
  || bad "status fenced" "rc=$rc, got: $out"

# NFR-01: under a second on the largest plan shape, about 35,000 words over 2,000 lines.
p="$d/large.md"
{
    printf '# A large plan\n\n'
    t=1
    while [ "$t" -le 40 ]; do
        printf '### Task %s: a task\n\n' "$t"
        s=1
        while [ "$s" -le 5 ]; do
            printf -- '- [ ] **Step %s.%s: a step**\n\n' "$t" "$s"
            i=1
            while [ "$i" -le 9 ]; do
                printf 'Prose standing in for the code and the reasoning a real step carries, at about the density of these plans.\n'
                i=$((i+1))
            done
            printf '\n'
            s=$((s+1))
        done
        printf '```bash\n- [ ] **Step 99.1: inside a fence**\n```\n\n'
        t=$((t+1))
    done
} > "$p"
lines="$(wc -l < "$p" | tr -d ' ')"; words="$(wc -w < "$p" | tr -d ' ')"
secs="$(python3 -c 'import subprocess, sys, time
t = time.time()
subprocess.run(sys.argv[1:], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
print("%.3f" % (time.time() - t))' "$KEEL" plan status "$p")"
last="$("$KEEL" plan status "$p" 2>&1 | tail -1)"
[ "$lines" -ge 2000 ] && [ "$words" -ge 35000 ] && [ "$last" = "next: 1.1" ] \
  && awk -v s="$secs" 'BEGIN { exit !(s < 1) }' \
  && ok "status reads a $lines-line, $words-word plan in ${secs}s" \
  || bad "status speed" "lines=$lines words=$words secs=$secs last=$last"

# Captured before matching: `keel --help | grep -q` fails under pipefail when grep exits early.
help="$("$KEEL" --help 2>&1)"
case "$help" in
  *'plan status <plan>'*) ok "keel --help lists plan status" ;;
  *) bad "help" "keel --help does not list 'plan status <plan>'" ;;
esac

rm -rf "$d"
printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

Add to `tests/run-tests.sh`, after the `tests/test-keel-fleet.sh` line:

```bash
add "tests/test-plan.sh"        "tests/test-plan.sh"
```

Lint: the profile's shellcheck command.

- [x] **Step 2.2: Run it and watch it fail**

Run: `tests/test-plan.sh`
Expected: FAIL on all six cases. The first four get `keel: unknown command 'plan'. Try 'keel
--help'.` and rc 1; the speed case fails on `last=` being that message rather than `next: 1.1`; the
help case fails because `--help` has no `plan status` line.

- [x] **Step 2.3: Write the minimal implementation**

In `bin/keel`, directly above the top-level dispatch `case "${1:-}" in` (the one at the end of the
file, after `cmd_guard`), add:

```bash
# `keel plan status` and `keel plan tick` read and tick an implementation plan's steps by id. A step
# is a checkbox line whose bold title opens with its id, `- [ ] **Step 3.2: Run it and watch it
# fail**`, the form skills/write-plan/references/plan-template.md writes. Its box is ` ` open, `x`
# done, `-` deferred or `~` not applicable, and anything after the closing ** is its tail: a note,
# or a deferred step's reason. A line inside a fenced code block is an example, as the template's own
# are, so it is never a step.
#
# PLAN_AWK_LIB is prepended to both commands' awk programs so they cannot disagree about what a
# step is. fenced(line) tracks fences and returns 1 for a fence line or a line inside one; a fence
# closes only on the same character, at least as long, with nothing after it, so a ```` fence
# holding a ``` example stays open. A line opening with an inline backtick span is not a fence: a
# backtick run followed later on its line by another backtick opens none, as CommonMark rules. A
# closing fence may end in CR, since a CRLF checkout adds one. step(line) returns 1 for a step line
# and sets sid, smark, stitle and stail.
PLAN_AWK_LIB='
function fenced(line,   t, c, n) {
    t = line; sub(/^[ \t]+/, "", t)
    c = substr(t, 1, 1)
    if (c == "`" || c == "~") {
        n = 0; while (substr(t, n + 1, 1) == c) n++
        if (n >= 3) {
            if (!infence) {
                if (c == "`" && index(substr(t, n + 1), "`")) return 0
                infence = 1; fch = c; flen = n; return 1
            }
            if (c == fch && n >= flen && substr(t, n + 1) ~ /^[ \t\r]*$/) { infence = 0; return 1 }
        }
    }
    return infence
}
function step(line,   rest, i) {
    if (line !~ /^- \[[ xX~-]\] \*\*Step [0-9]+[a-z]*\.[0-9]+: /) return 0
    smark = substr(line, 4, 1); if (smark == "X") smark = "x"
    rest = substr(line, 14)
    i = index(rest, ": "); sid = substr(rest, 1, i - 1); rest = substr(rest, i + 2)
    i = index(rest, "**"); if (i == 0) return 0
    stitle = substr(rest, 1, i - 1); stail = substr(rest, i + 2)
    return 1
}
'

cmd_plan() {
    case "${1:-}" in
        status) shift
                [ "$#" -eq 1 ] || die "usage: keel plan status <plan>"
                plan_status "$1" ;;
        *) die "unknown plan subcommand '${1:-}'. Try status." ;;
    esac
}

# plan_status <plan>: one line per task, in the order tasks first appear, counting its steps by
# state, then `next: <id>` for the first open step, or `next: none`.
plan_status() {
    [ -f "$1" ] || die "no such plan: $1"
    # shellcheck disable=SC2016  # $0 is awk's record, not a shell expansion
    awk "$PLAN_AWK_LIB"'
        fenced($0) { next }
        step($0) {
            task = sid; sub(/\.[0-9]+$/, "", task)
            if (!(task in seen)) { seen[task] = 1; order[++ntask] = task }
            count[task, smark]++
            if (smark == " " && nextid == "") nextid = sid
        }
        END {
            for (k = 1; k <= ntask; k++) {
                t = order[k]
                printf "task %s: %d done, %d open, %d deferred, %d not applicable\n",
                    t, count[t, "x"], count[t, " "], count[t, "-"], count[t, "~"]
            }
            print "next: " (nextid == "" ? "none" : nextid)
        }' "$1"
}
```

In the dispatch, after `    guard)       shift; cmd_guard "$@" ;;`, add:

```bash
    plan)        shift; cmd_plan "$@" ;;
```

In the help text, after the `guard install|status|uninstall` line, add:

```bash
        say "  plan status <plan>   an implementation plan's steps by state, per task, and the next open step's id"
```

In `docs/03-install-and-distribution.md`, directly above the ```` ```bash ```` line that precedes
`keel guard install | status | uninstall`, add:

````markdown
```bash
keel plan status <plan>
```

Reads an implementation plan written from `skills/write-plan/references/plan-template.md` and
prints one line per task counting its steps by state, open, done, deferred and not applicable, then
`next: <id>` naming the first open step, or `next: none`. A step is a checkbox whose bold title opens
with its id, `**Step 3.2: ...**`; one inside a fenced code block is an example and is not counted.

````

Add at the top of `## Unreleased` in `CHANGELOG.md`:

```markdown
- `keel plan status <plan>` prints each task's steps by state and the next open step's id.
```

Lint: the profile's shellcheck command.

- [x] **Step 2.4: Run it and watch it pass**

Run: `tests/test-plan.sh`
Expected: PASS, six cases, `6 passed, 0 failed`.

- [x] **Step 2.5: Run the suite at the unit boundary, then hand over**

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
Then `tests/validate-citations.sh`, repairing per the Global constraints.

```bash
git add bin/keel tests/test-plan.sh tests/run-tests.sh docs/03-install-and-distribution.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(plan): keel plan status reports a plan's progress by step id"`.

**Review record, 2026-09-28.** Spec review COMPLIES; the implementer rewrapped one docs/03 line that
the plan's text put at 101 columns. The quality review raised two should-fix items, both fixed test
first and re-reviewed: a line opening with an inline span of backticks opened a fence, and a CRLF
closing line never closed one, each hiding every later step. This task's text above now carries the
fixed `fenced()` and the fenced case's five extra lines. Considered and not acted on: pass the plan
to awk on stdin, so `a=b.md` is not read as an assignment; report an unclosed fence as a problem; the
speed case passes without `python3`; the error paths have no tests; comments name `keel plan tick`
before task 4 lands; one 101-column comment line in `bin/keel`.

### Task 3: `keel plan status` flags a deferral with no reason, and a repeated id

**Story:** S-03
**Files:**
- Modify: `bin/keel`
- Test: `tests/test-plan.sh`
- Modify: `docs/03-install-and-distribution.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: `PLAN_AWK_LIB` and `plan_status` from task 2
- Produces: `problem: step <id> ...` and `problem: line <n> ...` lines on `status`'s output, and
  exit 1 when there is one; `fline`, set by `fenced()`, the line an open fence began on

**Depends on:** task 2

**Done when:** `tests/test-plan.sh` passes.

- [x] **Step 3.1: Write the failing test**

In `tests/test-plan.sh`, insert directly above the `rm -rf "$d"` line at the end:

```bash
# ---- status: a parked step needs its reason, and an id names one step ------------------------

p="$d/no-reason.md"
mkplan "$p" '- [x] **Step 2.1: a**' '- [ ] **Step 2.2: b**' '- [-] **Step 2.3: c** Deferred: '
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"problem: step 2.3 is deferred with no reason"*) true ;; *) false ;; esac \
  && ok "status names a deferred step with no reason and exits non-zero" \
  || bad "status deferred no reason" "rc=$rc, got: $out"

p="$d/na-no-reason.md"
mkplan "$p" '- [~] **Step 1.4: d** Not applicable: '
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"problem: step 1.4 is not applicable with no reason"*) true ;; *) false ;; esac \
  && ok "status names a not-applicable step whose reason is empty and exits non-zero" \
  || bad "status not applicable no reason" "rc=$rc, got: $out"

p="$d/reasons.md"
mkplan "$p" \
  '- [-] **Step 1.1: a** Deferred: moved to the follow-up plan' \
  '- [~] **Step 1.2: b** Not applicable: no behaviour to test'
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && case "$out" in *problem*) false ;; *) true ;; esac \
  && ok "status accepts parked steps that carry their reasons" \
  || bad "status reasons" "rc=$rc, got: $out"

p="$d/repeat.md"
mkplan "$p" '- [ ] **Step 1.1: a**' '- [ ] **Step 1.1: a again**'
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"problem: step 1.1 appears more than once"*) true ;; *) false ;; esac \
  && ok "status names an id that appears twice and exits non-zero" \
  || bad "status repeated id" "rc=$rc, got: $out"

# An open checkbox the parser cannot read as a step would be invisible to status, and ship's gate
# reads status: an old-style box and an indented step are both open work. mkplan's header is four
# lines, so the boxes are lines 6 to 11. GFM renders `*`, `+` and numbered task items as checkboxes
# too, and a box inside a quote is still one.
p="$d/unreadable.md"
mkplan "$p" '- [x] **Step 1.1: a**' '- [ ] **Finding 1: an old-style box**' '   - [ ] **Step 1.2: indented**' \
  '* [ ] **Step 1.3: a star bullet**' '+ [ ] **Step 1.4: a plus bullet**' \
  '1. [ ] **Step 1.5: a numbered item**' '> - [ ] **Step 1.6: inside a quote**'
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] \
  && case "$out" in *"problem: line 6 is an open checkbox"*"problem: line 7 is an open checkbox"*"problem: line 8 is an open checkbox"*"problem: line 9 is an open checkbox"*"problem: line 10 is an open checkbox"*"problem: line 11 is an open checkbox"*) true ;; *) false ;; esac \
  && ok "status names each open checkbox it cannot read as a step and exits non-zero" \
  || bad "status unreadable checkbox" "rc=$rc, got: $out"

# A fence that never closes hides every step after it, so status would read an unfinished plan as
# done. It is named as a problem, with the line it opened on.
p="$d/unclosed.md"
mkplan "$p" '- [x] **Step 1.1: a**' '```bash' '- [ ] **Step 1.2: hidden**'
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"problem: line 6 opens a fence that never closes"*) true ;; *) false ;; esac \
  && ok "status names a fence that never closes and exits non-zero" \
  || bad "status unclosed fence" "rc=$rc, got: $out"
```

- [x] **Step 3.2: Run it and watch it fail**

Run: `tests/test-plan.sh`
Expected: FAIL on five of the six new cases, each with rc=0 and no `problem:` line: the deferred,
not-applicable, repeated-id, unreadable-checkbox and unclosed-fence cases. The reasons case passes
on arrival: it pins that a reasoned parked step is not flagged, and the implementation below must
keep it green.

- [x] **Step 3.3: Write the minimal implementation**

In `plan_status` in `bin/keel`, inside the `step($0) { ... }` block, after the `nextid` line, add:

```awk
            if (sid in ids) problem[++nproblem] = "step " sid " appears more than once"
            ids[sid] = 1
            if (smark == "-" && stail !~ /^ Deferred: [^ ]/)
                problem[++nproblem] = "step " sid " is deferred with no reason"
            if (smark == "~" && stail !~ /^ Not applicable: [^ ]/)
                problem[++nproblem] = "step " sid " is not applicable with no reason"
```

after that block's closing `}`, add the rule:

```awk
        /^[ \t>]*([-*+]|[0-9]+[.)])[ \t]+\[ \]/ && !step($0) {
            problem[++nproblem] = "line " NR " is an open checkbox that is not a step keel can read"
        }
```

and at the end of its `END { ... }` block, after the `print "next: " ...` line, add:

```awk
            if (infence) problem[++nproblem] = "line " fline " opens a fence that never closes"
            for (k = 1; k <= nproblem; k++) print "problem: " problem[k]
            exit (nproblem > 0 ? 1 : 0)
```

In `PLAN_AWK_LIB`'s `fenced()`, record the line a fence opens on: the opening assignment becomes
`infence = 1; fch = c; flen = n; fline = NR; return 1`.

Change the comment above `plan_status` to:

```bash
# plan_status <plan>: one line per task, in the order tasks first appear, counting its steps by
# state, then `next: <id>` for the first open step, or `next: none`, then a `problem:` line for each
# deferred or not-applicable step with no reason, each id that appears twice, each open checkbox
# that is not a step it can read, and a fence that never closes, and exit 1 when there is one. A
# parked step without its reason is indistinguishable from a forgotten one, and a repeated id names
# no one step. An open box is recognised in any GFM list-item form, `-`, `*`, `+` or numbered,
# indented or quoted, and one it cannot read, for its form or a missing id, is open work that ship's
# gate, which reads this, would otherwise pass. An unclosed fence hides every step after the line it
# opens on, so an unfinished plan would read as done.
```

In `docs/03-install-and-distribution.md`, append to the `keel plan status <plan>` paragraph:

```markdown
It exits 1, with a `problem:` line for each, where a deferred or not-applicable step has no reason,
an id appears twice, an open checkbox is not a step it can read, or a fence never closes.
```

Add at the top of `## Unreleased` in `CHANGELOG.md`:

```markdown
- `keel plan status` exits 1 on a deferred or not-applicable step with no reason, an id that appears
  twice, an open checkbox it cannot read as a step, or a fence that never closes, naming each.
```

Lint: the profile's shellcheck command.

- [x] **Step 3.4: Run it and watch it pass**

Run: `tests/test-plan.sh`
Expected: PASS, `12 passed, 0 failed`.

- [x] **Step 3.5: Run the suite at the unit boundary, then hand over**

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.

```bash
git add bin/keel tests/test-plan.sh docs/03-install-and-distribution.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(plan): keel plan status flags a parked step with no reason"`.

**Review record, 2026-09-28.** Spec review COMPLIES. The quality review raised three should-fix
items, fixed test first and re-reviewed twice: a fence that never closes hid every later step with
exit 0, so it is now a problem naming its line; the open-checkbox rule saw only `- [ ]`, so it now
takes every GFM list-item form, each pinned; and the empty-reason fixtures lacked the space after
the colon, so they tested a missing space rather than an empty reason. Task 6's `plan_status`
listing was rebuilt to keep all three, and later tasks' totals rose by one. Considered and not acted
on: `[^ ]` accepts a CR or tab as a reason and refuses two spaces; a repeated id is reported without
line numbers; `step()` runs twice on open step lines; an open box in a multi-line HTML comment or a
4-space code block is flagged; the `PLAN_AWK_LIB` comment does not mention `fline`; under task 6 an
unclosed fence hiding every step reports the plan unaddressable rather than the fence.

### Task 4: `keel plan tick` marks one step done, with an optional note

**Story:** S-05
**Files:**
- Modify: `bin/keel`
- Test: `tests/test-plan.sh`
- Modify: `docs/03-install-and-distribution.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: `PLAN_AWK_LIB` and `cmd_plan` from task 2
- Produces: `plan_tick <plan> <id> [--note <text>]`, which later tasks extend with `--defer`,
  `--not-applicable` and a lock

**Depends on:** task 2

**Done when:** `tests/test-plan.sh` passes.

- [x] **Step 4.1: Write the failing test**

In `tests/test-plan.sh`, insert directly above the `rm -rf "$d"` line at the end:

```bash
# ---- tick: one step, and only its line --------------------------------------------------------

p="$d/tick.md"
mkplan "$p" '- [x] **Step 1b.1: Write the failing test**' '- [ ] **Step 1b.2: Run it and watch it fail**' \
  '- [ ] **Step 1b.3: Write the minimal implementation**'
cp "$p" "$d/tick.before"
out="$("$KEEL" plan tick "$p" 1b.2 2>&1)"; rc=$?
want="$(sed 's/^- \[ \] \*\*Step 1b\.2: /- [x] **Step 1b.2: /' "$d/tick.before")"
[ "$rc" -eq 0 ] && [ "$(cat "$p")" = "$want" ] \
  && ok "tick marks one step done and changes no other line" \
  || bad "tick" "rc=$rc out=$out, plan now: $(cat "$p")"

p="$d/note.md"
mkplan "$p" '- [ ] **Step 3.1: Write the failing test**'
"$KEEL" plan tick "$p" 3.1 --note 'file already on disk on arrival, \t kept literally' >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && grep -qxF -e '- [x] **Step 3.1: Write the failing test** Note: file already on disk on arrival, \t kept literally' "$p" \
  && ok "tick --note writes the note after the step's title, backslashes untouched" \
  || bad "tick --note" "rc=$rc, plan now: $(cat "$p")"

p="$d/missing.md"
mkplan "$p" '- [ ] **Step 1.1: a**'
cp "$p" "$d/missing.before"
out="$("$KEEL" plan tick "$p" 9.9 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && cmp -s "$p" "$d/missing.before" && case "$out" in *"no step 9.9"*) true ;; *) false ;; esac \
  && ok "tick on an id the plan does not hold changes nothing and names it" \
  || bad "tick missing id" "rc=$rc out=$out"

p="$d/again.md"
mkplan "$p" '- [x] **Step 1.1: a** Note: seen in the log'
cp "$p" "$d/again.before"
"$KEEL" plan tick "$p" 1.1 >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && cmp -s "$p" "$d/again.before" \
  && ok "tick on a step already done leaves it done, once, its note kept" \
  || bad "tick again" "rc=$rc, plan now: $(cat "$p")"

p="$d/twice.md"
mkplan "$p" '- [ ] **Step 1.1: a**' '- [ ] **Step 1.1: a again**'
cp "$p" "$d/twice.before"
out="$("$KEEL" plan tick "$p" 1.1 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && cmp -s "$p" "$d/twice.before" && case "$out" in *"appears more than once"*) true ;; *) false ;; esac \
  && ok "tick refuses an id that names two steps" \
  || bad "tick repeated id" "rc=$rc out=$out"

p="$d/newline.md"
mkplan "$p" '- [ ] **Step 1.1: a**'
cp "$p" "$d/newline.before"
"$KEEL" plan tick "$p" 1.1 --note "$(printf 'two\nlines')" >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && cmp -s "$p" "$d/newline.before" \
  && ok "tick refuses a note holding a newline, which would split the step's line" \
  || bad "tick newline note" "rc=$rc, plan now: $(cat "$p")"

help="$("$KEEL" --help 2>&1)"
case "$help" in
  *'plan tick <plan> <id>'*) ok "keel --help lists plan tick" ;;
  *) bad "help" "keel --help does not list 'plan tick <plan> <id>'" ;;
esac

# A tick that cannot write the plan must fail: reporting success would leave the step unticked while
# the caller moves on. Root can write a read-only file, so the case is skipped there.
if [ "$(id -u)" -eq 0 ]; then
  printf '  SKIP  %s\n' "tick on a plan it cannot write exits non-zero and leaves it as it was (root)"
else
  p="$d/readonly.md"
  mkplan "$p" '- [ ] **Step 1.1: a**'
  cp "$p" "$d/readonly.before"
  chmod 444 "$p"; "$KEEL" plan tick "$p" 1.1 >/dev/null 2>&1; rc=$?; chmod 644 "$p"
  [ "$rc" -ne 0 ] && cmp -s "$p" "$d/readonly.before" \
    && ok "tick on a plan it cannot write exits non-zero and leaves it as it was" \
    || bad "tick read-only plan" "rc=$rc, plan now: $(cat "$p")"
fi

# A CRLF plan keeps its line endings: the note goes before the line's CR, or the CR would sit in the
# middle of the line and the note would follow it.
p="$d/crlf.md"
printf '# A plan\r\n\r\n### Task 1: a task\r\n\r\n- [ ] **Step 1.1: a**\r\n' > "$p"
"$KEEL" plan tick "$p" 1.1 --note 'seen' >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && [ "$(grep -cxF -e "- [x] **Step 1.1: a** Note: seen$(printf '\r')" "$p")" -eq 1 ] \
  && ok "tick on a CRLF plan keeps the note before the line's CR" \
  || bad "tick CRLF plan" "rc=$rc, plan now: $(od -c "$p")"

# A step inside a fenced block is an example, never a step, so tick passes over it: ticking it
# would rewrite the example, and counting it would make the real step's id look repeated.
p="$d/fenced.md"
mkplan "$p" '- [ ] **Step 1.1: real**' '```markdown' '- [ ] **Step 1.1: an example**' '```'
"$KEEL" plan tick "$p" 1.1 >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && grep -qxF -e '- [x] **Step 1.1: real**' "$p" \
  && grep -qxF -e '- [ ] **Step 1.1: an example**' "$p" \
  && ok "tick never ticks a step inside a fenced example" \
  || bad "tick fenced example" "rc=$rc, plan now: $(cat "$p")"
```

- [x] **Step 4.2: Run it and watch it fail**

Run: `tests/test-plan.sh`
Expected: FAIL on eight of the ten new cases. Each tick gets `keel: unknown plan subcommand 'tick'.
Try status.` and rc 1: the five cases expecting rc 0 fail on it, the two refusal cases fail on the
missing message (`no step 9.9`, `appears more than once`), and the help case fails. The newline and
read-only cases pass on arrival, since each asserts only a non-zero exit and an unchanged plan; they
are kept to pin those refusals once `tick` exists.

- [x] **Step 4.3: Write the minimal implementation**

In `bin/keel`, change `cmd_plan` to:

```bash
cmd_plan() {
    case "${1:-}" in
        status) shift
                [ "$#" -eq 1 ] || die "usage: keel plan status <plan>"
                plan_status "$1" ;;
        tick)   shift; plan_tick "$@" ;;
        *) die "unknown plan subcommand '${1:-}'. Try status or tick." ;;
    esac
}
```

and add after `plan_status`:

```bash
# plan_tick <plan> <id> [--note <text>]: marks one step done and rewrites only its line. A note
# follows the title as ` Note: <text>`, for a step the ticker did not witness; it must be one line,
# since it is written on the step's own line. The rewrite goes through a temporary file, so an awk
# that fails leaves the plan as it was. It is written back with `cat >` rather than `mv`, so the
# plan keeps its mode and a symlinked plan is written through; a failed write is an error, since
# the plan is then unticked or truncated. A CRLF line keeps its CR at the end, after any note.
plan_tick() {
    local plan="${1:-}" id="${2:-}" opt="${3:-}" text="${4:-}" mark=x tail="" tmp rc
    [ -n "$plan" ] && [ -n "$id" ] && [ "$#" -le 4 ] \
      || die "usage: keel plan tick <plan> <id> [--note <text>]"
    [ -f "$plan" ] || die "no such plan: $plan"
    case "$text" in *$'\n'*) die "a note or reason must be one line: it is written on the step's own line" ;; esac
    case "$opt" in
        "") ;;
        --note) [ -n "$text" ] || die "--note needs its text"; tail=" Note: $text" ;;
        *) die "unknown option '$opt'. Try --note." ;;
    esac
    tmp="$(mktemp)" || die "cannot create a temporary file"
    # ENVIRON rather than awk -v, because -v rewrites backslash escapes: a note holding \t would be
    # written with a tab.
    # shellcheck disable=SC2016  # $0 is awk's record, not a shell expansion
    PLAN_ID="$id" PLAN_MARK="$mark" PLAN_TAIL="$tail" awk "$PLAN_AWK_LIB"'
        BEGIN { id = ENVIRON["PLAN_ID"]; mark = ENVIRON["PLAN_MARK"]; tail = ENVIRON["PLAN_TAIL"] }
        { line[NR] = $0 }
        fenced($0) { next }
        step($0) { if (sid == id) { hits++; at = NR; oldtail = stail; title = stitle } }
        END {
            if (!hits) exit 4
            if (hits > 1) exit 5
            cr = ""; if (oldtail ~ /\r$/) { cr = "\r"; sub(/\r$/, "", oldtail) }
            line[at] = "- [" mark "] **Step " id ": " title "**" oldtail tail cr
            for (i = 1; i <= NR; i++) print line[i]
        }' "$plan" > "$tmp"
    rc=$?
    case "$rc" in
        0) cat "$tmp" > "$plan" || rc=1 ;;
        4) err "no step $id in $plan"; rc=1 ;;
        5) err "step $id appears more than once in $plan, so it names no one step"; rc=1 ;;
    esac
    rm -f "$tmp"
    return "$rc"
}
```

In the help text, after the `plan status <plan>` line, add:

```bash
        say "  plan tick <plan> <id> [--note <text>]   mark one step done, with a note for a step not witnessed"
```

In `docs/03-install-and-distribution.md`, directly after the `keel plan status <plan>` paragraph,
add:

````markdown
```bash
keel plan tick <plan> <id> [--note <text>]
```

Marks one step done, rewriting only its line. `--note` writes ` Note: <text>` after the step's
title, for a step the ticker did not witness; a note holding a newline is refused. An id the plan
does not hold, or holds twice, changes nothing and exits 1.

````

Add at the top of `## Unreleased` in `CHANGELOG.md`:

```markdown
- `keel plan tick <plan> <id> [--note <text>]` marks one step done by its id, changing no other
  line.
```

Lint: the profile's shellcheck command.

- [x] **Step 4.4: Run it and watch it pass**

Run: `tests/test-plan.sh`
Expected: PASS, `22 passed, 0 failed`.

- [x] **Step 4.5: Run the suite at the unit boundary, then hand over**

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.

```bash
git add bin/keel tests/test-plan.sh docs/03-install-and-distribution.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(plan): keel plan tick marks one step done by its id"`.

**Review record, 2026-09-28.** Spec review COMPLIES; its reviewer ran fourteen mutants, each caught.
The quality review raised three should-fix items, fixed test first and re-reviewed: a failed write
back exited 0 with the plan unticked or truncated; on a CRLF plan the note landed after the CR; and
no case pinned that a fenced example step is never ticked. Tasks 5 to 7's wording now carries the CR
fix, confirmed by applying them over this code in a scratch copy, and later totals rose by three.
Task 4's own steps were ticked with `keel plan tick`. Considered and not acted on: a second
`--note` stacks after the first; an unclosed fence before the step reports `no step`; a plan without
a final newline gains one; a note holding a CR is written raw; no cleanup trap for the temporary
file on interrupt; the read-only case is a SKIP as root, lowering every total by one there; a
failed write prints only the shell's own error; docs/03 does not list a failed write.

### Task 5: `keel plan tick` defers a step or marks it not applicable, only with a reason

**Story:** S-06
**Files:**
- Modify: `bin/keel`
- Test: `tests/test-plan.sh`
- Modify: `docs/03-install-and-distribution.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: `plan_tick` from task 4
- Produces: `plan_tick` options `--defer <reason>` and `--not-applicable <reason>`

**Depends on:** task 4

**Done when:** `tests/test-plan.sh` passes.

- [x] **Step 5.1: Write the failing test**

In `tests/test-plan.sh`, extend task 3's "status deferred no reason" case so its fixture also
holds a step whose reason starts with a tab, and requires that step's problem line too:

```bash
p="$d/no-reason.md"
mkplan "$p" '- [x] **Step 2.1: a**' '- [ ] **Step 2.2: b**' '- [-] **Step 2.3: c** Deferred: ' \
  '- [-] **Step 2.4: d** Deferred: '$'\t''later'
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] \
  && case "$out" in *"problem: step 2.3 is deferred with no reason"*"problem: step 2.4 is deferred with no reason"*) true ;; *) false ;; esac \
  && ok "status names a deferred step with no reason and exits non-zero" \
  || bad "status deferred no reason" "rc=$rc, got: $out"
```

Then insert directly above the `rm -rf "$d"` line at the end:

```bash
# ---- tick: park a step, only with its reason --------------------------------------------------

p="$d/defer.md"
mkplan "$p" '- [ ] **Step 6.2: Commit**'
"$KEEL" plan tick "$p" 6.2 --defer 'moved to the follow-up plan' >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && grep -qxF -e '- [-] **Step 6.2: Commit** Deferred: moved to the follow-up plan' "$p" \
  && ok "tick --defer parks the step with its reason" \
  || bad "tick --defer" "rc=$rc, plan now: $(cat "$p")"

p="$d/na.md"
mkplan "$p" '- [ ] **Step 4.2: Run it and watch it fail**'
"$KEEL" plan tick "$p" 4.2 --not-applicable 'no behaviour to test' >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && grep -qxF -e '- [~] **Step 4.2: Run it and watch it fail** Not applicable: no behaviour to test' "$p" \
  && ok "tick --not-applicable parks the step with its reason" \
  || bad "tick --not-applicable" "rc=$rc, plan now: $(cat "$p")"

p="$d/defer-bare.md"
mkplan "$p" '- [ ] **Step 6.2: Commit**'
cp "$p" "$d/defer-bare.before"
out="$("$KEEL" plan tick "$p" 6.2 --defer 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && cmp -s "$p" "$d/defer-bare.before" && case "$out" in *"a reason is required"*) true ;; *) false ;; esac \
  && ok "tick --defer with no reason changes nothing and says one is required" \
  || bad "tick --defer bare" "rc=$rc out=$out"

p="$d/undefer.md"
mkplan "$p" '- [-] **Step 6.2: Commit** Deferred: moved to the follow-up plan'
"$KEEL" plan tick "$p" 6.2 >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && grep -qxF -e '- [x] **Step 6.2: Commit**' "$p" \
  && ok "ticking a deferred step done drops its deferral reason" \
  || bad "tick undefer" "rc=$rc, plan now: $(cat "$p")"

# A reason that starts with a blank is refused, since status reads it as no reason: tick must not
# write a line that status then flags.
p="$d/defer-blank.md"
mkplan "$p" '- [ ] **Step 6.2: Commit**'
cp "$p" "$d/defer-blank.before"
out="$("$KEEL" plan tick "$p" 6.2 --defer ' ' 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && cmp -s "$p" "$d/defer-blank.before" && case "$out" in *"a reason is required"*) true ;; *) false ;; esac \
  && ok "tick --defer with a reason that is only a space changes nothing and says one is required" \
  || bad "tick --defer blank" "rc=$rc out=$out"

# A not-applicable step needs its reason as much as a deferred one: without it, it reads as
# forgotten.
p="$d/na-bare.md"
mkplan "$p" '- [ ] **Step 4.2: Run it and watch it fail**'
cp "$p" "$d/na-bare.before"
out="$("$KEEL" plan tick "$p" 4.2 --not-applicable 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && cmp -s "$p" "$d/na-bare.before" && case "$out" in *"a reason is required"*) true ;; *) false ;; esac \
  && ok "tick --not-applicable with no reason changes nothing and says one is required" \
  || bad "tick --not-applicable bare" "rc=$rc out=$out"

# Ticking a not-applicable step done drops its reason, as for a deferred one: the reason no longer
# describes a step that was done.
p="$d/un-na.md"
mkplan "$p" '- [~] **Step 4.2: Run it and watch it fail** Not applicable: no behaviour to test'
"$KEEL" plan tick "$p" 4.2 >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && grep -qxF -e '- [x] **Step 4.2: Run it and watch it fail**' "$p" \
  && ok "ticking a not-applicable step done drops its reason" \
  || bad "tick un-not-applicable" "rc=$rc, plan now: $(cat "$p")"

# Parking replaces anything after the title, a note included: the note described the step as done,
# which it no longer is.
p="$d/park-note.md"
mkplan "$p" '- [x] **Step 3.1: a** Note: file was on disk'
"$KEEL" plan tick "$p" 3.1 --defer 'moved to the follow-up plan' >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && grep -qxF -e '- [-] **Step 3.1: a** Deferred: moved to the follow-up plan' "$p" \
  && ok "parking a step replaces its note with the reason" \
  || bad "tick park over note" "rc=$rc, plan now: $(cat "$p")"
```

- [x] **Step 5.2: Run it and watch it fail**

Run: `tests/test-plan.sh`
Expected: FAIL on the extended case and on all eight new cases. `--defer` and `--not-applicable`
get `keel: unknown option '--defer'. Try --note.` (or `'--not-applicable'`), so the parking and
refusal cases fail on their exit code or missing message; the undefer and un-not-applicable cases
keep their reason, since task 4's tick keeps whatever follows the title; and the extended case
exits 1 for step 2.3 but lacks step 2.4's problem line, since `status` still accepts its tab-led
reason.

- [x] **Step 5.3: Write the minimal implementation**

In `plan_tick` in `bin/keel`, change the usage message to
`"usage: keel plan tick <plan> <id> [--note <text> | --defer <reason> | --not-applicable <reason>]"`,
and replace the option `case` with:

```bash
    case "$opt" in
        "") ;;
        --note) [ -n "$text" ] || die "--note needs its text"; tail=" Note: $text" ;;
        --defer)
                 case "$text" in
                     ""|[[:space:]]*) die "a reason is required: --defer <reason>" ;;
                 esac
                 mark=-; tail=" Deferred: $text" ;;
        --not-applicable)
                 case "$text" in
                     ""|[[:space:]]*) die "a reason is required: --not-applicable <reason>" ;;
                 esac
                 mark="~"; tail=" Not applicable: $text" ;;
        *) die "unknown option '$opt'. Try --note, --defer or --not-applicable." ;;
    esac
```

In its awk `END` block, replace the line
`line[at] = "- [" mark "] **Step " id ": " title "**" oldtail tail cr` with:

```awk
            if (mark == "x") {
                if (oldtail ~ /^ (Deferred|Not applicable): /) oldtail = ""
                tail = oldtail tail
            }
            line[at] = "- [" mark "] **Step " id ": " title "**" tail cr
```

The `cr` line before it stays as it is, so a CRLF line still keeps its CR at the end.

Change the comment above `plan_tick` to:

```bash
# plan_tick <plan> <id> [--note <text> | --defer <reason> | --not-applicable <reason>]: sets one
# step's state and rewrites only its line. Done is the default; a note follows the title as
# ` Note: <text>`, for a step the ticker did not witness. --defer and --not-applicable park the step
# with ` Deferred: <reason>` or ` Not applicable: <reason>` instead, and refuse without a reason,
# since a parked step without one reads as forgotten. A reason must start with a character that is
# not blank, matching what status accepts, so tick never writes a line status then flags. Parking
# replaces anything after the title, a note included, since it no longer describes the step. Ticking
# a parked step done drops its reason, which no longer describes it. Text must be one line, since
# it is written on the step's own line. The rewrite goes through a temporary file, so an awk that
# fails leaves the plan as it was. It is written back with `cat >` rather than `mv`, so the plan
# keeps its mode and a symlinked plan is written through; a failed write is an error, since the plan
# is then unticked or truncated. A CRLF line keeps its CR at the end, after any note or reason.
```

In `plan_status`, both reason patterns take a blank to be a tab or a CR as well as a space, so
`[^ ]` becomes `[^ \t\r]` in `/^ Deferred: [^ \t\r]/` and `/^ Not applicable: [^ \t\r]/`, and its
comment gains the sentence `A reason must start with a character that is not blank (a space, tab or
CR).` A reason read as missing by `status` must be refused by `tick`, or `tick` would write the
state `status` then flags.

Change the help line for `plan tick` to:

```bash
        say "  plan tick <plan> <id> [--note <text> | --defer <reason> | --not-applicable <reason>]   set one step's state"
```

In `docs/03-install-and-distribution.md`, change the `keel plan tick` block's command line to
`keel plan tick <plan> <id> [--note <text> | --defer <reason> | --not-applicable <reason>]`, and
append to its paragraph:

```markdown
`--defer` and `--not-applicable` park the step instead, writing ` Deferred: <reason>` or
` Not applicable: <reason>`, and refuse without a reason. Ticking a parked step done drops its
reason. Parking replaces anything after the title, a note included, and a reason must start with a
non-blank character, since `plan status` reads one that starts with a space, tab or CR as missing.
```

Add at the top of `## Unreleased` in `CHANGELOG.md`:

```markdown
- `keel plan tick --defer <reason>` and `--not-applicable <reason>` park a step with its reason,
  and refuse without one.
```

Lint: the profile's shellcheck command.

- [x] **Step 5.4: Run it and watch it pass**

Run: `tests/test-plan.sh`
Expected: PASS, `30 passed, 0 failed`.

- [x] **Step 5.5: Run the suite at the unit boundary, then hand over**

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.

```bash
git add bin/keel tests/test-plan.sh docs/03-install-and-distribution.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(plan): keel plan tick defers a step or marks it not applicable"`.

**Review record, 2026-09-28.** Spec review COMPLIES. The quality review raised four should-fix
items, fixed test first and re-reviewed (one re-review stalled and was re-dispatched): `tick`
accepted a blank-led reason that `status` then flagged, so both now read a space, tab or CR as blank
and `tick` refuses one; the bare `--not-applicable` refusal, ticking a not-applicable step done, and
parking over a note were untested, and parking replacing the note is now documented. This task's
text, task 6's listing and later totals were synced to match, and a truncated `case` block in the
sync was caught by the re-review and restored. Considered and not acted on: `[[:space:]]` also
refuses a leading VT, FF or NBSP that `status` accepts; the not-applicable blank-led refusal and its
status pattern mirror pinned deferred twins but are not pinned themselves; the done-tick drop regex
misses a bare label with nothing after it; a CR inside a reason is written raw; docs/03 still opens
"Marks one step done"; the CHANGELOG entry omits that ticking a parked step done drops its reason.

### Task 6: A plan without step ids is reported as unaddressable

**Story:** S-04
**Files:**
- Modify: `bin/keel`
- Test: `tests/test-plan.sh`
- Modify: `docs/03-install-and-distribution.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: `plan_status` from task 3, `plan_tick` from task 5
- Produces: exit status 3 from both commands on a plan with no step ids, and `plan_unaddressable
  <plan>`

**Depends on:** tasks 3 and 5

**Done when:** `tests/test-plan.sh` passes.

- [x] **Step 6.1: Write the failing test**

In `tests/test-plan.sh`, insert directly above the `rm -rf "$d"` line at the end:

```bash
# ---- a plan without step ids --------------------------------------------------------------------

# A committed plan written before the ids, read only.
old="$ROOT/docs/plans/2026-09-27-push-scan-reads-pushed-commits.md"
out="$("$KEEL" plan status "$old" 2>&1)"; rc=$?
[ "$rc" -eq 3 ] && case "$out" in *unaddressable*) true ;; *) false ;; esac \
  && ok "status reports a plan without step ids as unaddressable, exit 3" \
  || bad "status unaddressable" "rc=$rc, got: $out"

p="$d/old.md"
mkplan "$p" '- [ ] **Step 1: Write the failing test**' '- [ ] **Step 2: Run it and watch it fail**'
cp "$p" "$d/old.before"
out="$("$KEEL" plan tick "$p" 1.1 2>&1)"; rc=$?
[ "$rc" -eq 3 ] && cmp -s "$p" "$d/old.before" && case "$out" in *unaddressable*) true ;; *) false ;; esac \
  && ok "tick on a plan without step ids changes nothing, says so, and exits 3" \
  || bad "tick unaddressable" "rc=$rc out=$out"

# An unclosed fence hides the steps after it, so the plan is reported for its fence, not as id-less:
# calling it id-less sends the reader to hand-check lines that render as a code block.
p="$d/unclosed-only.md"
printf '# P\n\n```bash\n- [ ] **Step 1.1: a**\n' > "$p"
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && case "$out" in *"problem: line 3 opens a fence that never closes"*) true ;; *) false ;; esac \
  && case "$out" in *unaddressable*) false ;; *) true ;; esac \
  && ok "status on a plan whose only step follows an unclosed fence reports the fence, exit 1" \
  || bad "status unclosed fence, no steps" "rc=$rc, got: $out"

# Tick on the same plan names the fence too, for the same reason, and changes nothing.
cp "$p" "$d/unclosed-only.before"
out="$("$KEEL" plan tick "$p" 1.1 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && cmp -s "$p" "$d/unclosed-only.before" \
  && case "$out" in *"fence that never closes"*) true ;; *) false ;; esac \
  && case "$out" in *unaddressable*) false ;; *) true ;; esac \
  && ok "tick on a plan whose only step follows an unclosed fence changes nothing and names it" \
  || bad "tick unclosed fence, no steps" "rc=$rc out=$out"
```

- [x] **Step 6.2: Run it and watch it fail**

Run: `tests/test-plan.sh`
Expected: FAIL on three of the four new cases: `status` on the id-less plan exits 0 printing only
`next: none`; both `tick` cases exit 1 with `keel: no step 1.1 in ...`, which names neither the
missing ids nor the fence. The `status` case on a plan whose only step follows an unclosed fence
passes on arrival, since task 3 already reports the fence; it pins that this task's exit 3 does not
swallow it.

- [x] **Step 6.3: Write the minimal implementation**

In `bin/keel`, add before `plan_status`:

```bash
# plan_unaddressable <plan>: prints that the plan has no step ids, as one written before steps
# carried them. Neither status nor tick can find a step in it, so after printing this they exit 3,
# which a caller tells apart from a plan that is merely not done, and reads the plan by hand.
plan_unaddressable() {
    err "$1 has no step ids, so it is unaddressable: read and tick its checkboxes by hand"
}
```

In `plan_status`, add `nstep++` as the first line inside the `step($0) { ... }` block and `if
(!nstep && !infence) exit 3` as the first line inside its `END { ... }` block, and keep the awk's
status so a 3 is reported. A fence that never closes can hide every step, and it is reported as the
problem it is rather than as a plan without ids. The whole of `plan_status` after this step reads:

```bash
plan_status() {
    [ -f "$1" ] || die "no such plan: $1"
    local rc
    # shellcheck disable=SC2016  # $0 is awk's record, not a shell expansion
    awk "$PLAN_AWK_LIB"'
        fenced($0) { next }
        step($0) {
            nstep++
            task = sid; sub(/\.[0-9]+$/, "", task)
            if (!(task in seen)) { seen[task] = 1; order[++ntask] = task }
            count[task, smark]++
            if (smark == " " && nextid == "") nextid = sid
            if (sid in ids) problem[++nproblem] = "step " sid " appears more than once"
            ids[sid] = 1
            if (smark == "-" && stail !~ /^ Deferred: [^ \t\r]/)
                problem[++nproblem] = "step " sid " is deferred with no reason"
            if (smark == "~" && stail !~ /^ Not applicable: [^ \t\r]/)
                problem[++nproblem] = "step " sid " is not applicable with no reason"
        }
        /^[ \t>]*([-*+]|[0-9]+[.)])[ \t]+\[ \]/ && !step($0) {
            problem[++nproblem] = "line " NR " is an open checkbox that is not a step keel can read"
        }
        END {
            if (!nstep && !infence) exit 3
            for (k = 1; k <= ntask; k++) {
                t = order[k]
                printf "task %s: %d done, %d open, %d deferred, %d not applicable\n",
                    t, count[t, "x"], count[t, " "], count[t, "-"], count[t, "~"]
            }
            print "next: " (nextid == "" ? "none" : nextid)
            if (infence) problem[++nproblem] = "line " fline " opens a fence that never closes"
            for (k = 1; k <= nproblem; k++) print "problem: " problem[k]
            exit (nproblem > 0 ? 1 : 0)
        }' "$1"
    rc=$?
    [ "$rc" -ne 3 ] || plan_unaddressable "$1"
    return "$rc"
}
```

In `plan_tick`'s awk, replace `step($0) { if (sid == id) { hits++; at = NR; oldtail = stail; title =
stitle } }` with `step($0) { nstep++; if (sid == id) { hits++; at = NR; oldtail = stail; title =
stitle } }`, add `if (!nstep) exit (infence ? 6 : 3)` as the first line of its `END` block, and add
to the `case "$rc"` after the `0)` arm (the backslash-newline inside the quotes keeps the message
one line, since `err` prints only its first argument):

```bash
        3) plan_unaddressable "$plan" ;;
        6) err "$plan has a fence that never closes, which hides every step after it: see keel \
plan status $plan"; rc=1 ;;
```

Add to the end of the comments above `plan_status` and `plan_tick` the sentence `A plan with no step
ids exits 3; a fence that never closes is reported as such rather than as a plan without ids.`,
rewrapped at 100 columns.

In `docs/03-install-and-distribution.md`, append to the `keel plan status <plan>` paragraph:

```markdown
A plan with no step ids, such as one written before steps carried them, is unaddressable: `status`
and `tick` say so, change nothing, and exit 3, and the plan is read and ticked by hand.
```

and add to the `keel plan tick` paragraph, after "changes nothing and exits 1.":

```markdown
A plan with no step ids changes nothing and exits 3; a fence that never closes is reported, exit 1,
rather than read as a plan without ids.
```

Add at the top of `## Unreleased` in `CHANGELOG.md`:

```markdown
- `keel plan status` and `keel plan tick` report a plan with no step ids as unaddressable, exit 3,
  and change nothing. A fence that never closes is reported as such instead.
```

Lint: the profile's shellcheck command.

- [x] **Step 6.4: Run it and watch it pass**

Run: `tests/test-plan.sh`
Expected: PASS, `34 passed, 0 failed`.

- [x] **Step 6.5: Run the suite at the unit boundary, then hand over**

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.

```bash
git add bin/keel tests/test-plan.sh docs/03-install-and-distribution.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(plan): a plan without step ids is reported as unaddressable"`.

**Review record, 2026-09-28.** Spec review COMPLIES, with eight mutants caught; it flagged that exit
3 ran before task 3's fence check. The quality review raised four should-fix items, fixed test first
and re-reviewed: `status` and `tick` reported a plan whose only steps follow an unclosed fence as
having no ids, so `status` now reports the fence, exit 1, and `tick` names it, exit 1; a 101-column
comment; and docs/03's tick paragraph, which said nothing of exit 3. This task's text and later
totals were synced. Considered and not acted on: a plan whose every id is malformed is called
id-less, dropping task 3's line-level problems; tick misreports an id after an unclosed fence when
other ids exist; the status case reads a committed historical plan and does not check stdout;
exit 3 is written in four places.

### Task 7: Two ticks at once both land

**Story:** S-07
**Files:**
- Modify: `bin/keel`
- Test: `tests/test-plan.sh`
- Modify: `docs/03-install-and-distribution.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: `plan_tick` from task 6
- Produces: `plan_lock <plan>` and `plan_unlock`, and the lock directory `<plan>.lock`

**Depends on:** task 6

**Done when:** `tests/test-plan.sh` passes.

- [x] **Step 7.1: Write the failing test**

In `tests/test-plan.sh`, insert directly above the `rm -rf "$d"` line at the end:

```bash
# ---- tick: concurrent ticks all land ------------------------------------------------------------

# Twenty ticks on one plan, started together. Without a lock each reads the plan before the others
# write it and most ticks are lost: 3, 9 and 6 of 20 landed in three runs while planning.
p="$d/batch.md"
{ printf '# A plan\n\n'; i=1; while [ "$i" -le 20 ]; do printf -- '- [ ] **Step 1.%s: a step**\n' "$i"; i=$((i+1)); done; } > "$p"
i=1
while [ "$i" -le 20 ]; do "$KEEL" plan tick "$p" "1.$i" >/dev/null 2>&1 & i=$((i+1)); done
wait
n="$(grep -c '^- \[x\] \*\*Step 1\.' "$p")"
[ "$n" -eq 20 ] && [ ! -e "$p.lock" ] \
  && ok "twenty ticks started together all land, and the lock is gone after" \
  || bad "concurrent ticks" "$n of 20 landed; lock left: $([ -e "$p.lock" ] && echo yes || echo no)"

# A lock left by a killed tick: the tick waits, then names the lock and changes nothing.
p="$d/stale.md"
mkplan "$p" '- [ ] **Step 1.1: a**'
cp "$p" "$d/stale.before"
mkdir "$p.lock"
out="$("$KEEL" plan tick "$p" 1.1 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && cmp -s "$p" "$d/stale.before" && case "$out" in *"$p.lock"*) true ;; *) false ;; esac \
  && ok "tick facing a held lock gives up naming it, and changes nothing" \
  || bad "stale lock" "rc=$rc out=$out"
rmdir "$p.lock"

# A lock that cannot be created is not a lock that is held: waiting ten seconds and then blaming a
# killed tick sends the reader after a lock that does not exist. Root can write any directory.
if [ "$(id -u)" -eq 0 ]; then
  printf '  SKIP  %s\n' "tick that cannot create its lock fails at once, saying so (root)"
else
  mkdir "$d/rodir"
  p="$d/rodir/plan.md"
  mkplan "$p" '- [ ] **Step 1.1: a**'
  cp "$p" "$d/rodir.before"
  chmod 555 "$d/rodir"
  SECONDS=0
  out="$("$KEEL" plan tick "$p" 1.1 2>&1)"; rc=$?
  secs=$SECONDS
  chmod 755 "$d/rodir"
  [ "$rc" -ne 0 ] && cmp -s "$p" "$d/rodir.before" && [ "$secs" -lt 5 ] \
    && case "$out" in *"cannot create"*) true ;; *) false ;; esac \
    && case "$out" in *"is held"*) false ;; *) true ;; esac \
    && ok "tick that cannot create its lock fails at once, saying so" \
    || bad "lock cannot be created" "rc=$rc secs=$secs out=$out"
fi

# A tick removes only the lock it holds: once released, another tick may hold it. A shim rmdir has
# another holder take the lock right after the tick's own release, so a second rmdir would show.
shim="$d/shim"
mkdir "$shim"
printf '%s\n' '#!/bin/sh' '"$KEEL_TEST_RMDIR" "$@" || exit $?' '[ -e "$KEEL_TEST_MARK" ] && exit 0' \
  ': > "$KEEL_TEST_MARK"' 'mkdir "$1"' > "$shim/rmdir"
chmod 755 "$shim/rmdir"
real_rmdir="$(command -v rmdir)"
p="$d/relock.md"
mkplan "$p" '- [ ] **Step 1.1: a**'
PATH="$shim:$PATH" KEEL_TEST_RMDIR="$real_rmdir" KEEL_TEST_MARK="$d/mark" \
  "$KEEL" plan tick "$p" 1.1 >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && grep -qxF -e '- [x] **Step 1.1: a**' "$p" && [ -d "$p.lock" ] \
  && ok "a tick removes only the lock it holds" \
  || bad "tick removes only its lock" "rc=$rc, lock left: $([ -d "$p.lock" ] && echo yes || echo no)"
rmdir "$p.lock" 2>/dev/null
```

- [x] **Step 7.2: Run it and watch it fail**

Run: `tests/test-plan.sh`
Expected: FAIL on all four new cases: fewer than 20 of 20 land; the stale-lock tick exits 0 having
ticked the step; the tick in a read-only directory succeeds, since nothing is locked; and after the
shim's relock no lock remains, since nothing took one. The first case depends on a race; if all
twenty land, run it twice more, and if it never goes red, report that it could not be watched
failing rather than ticking this step. The last case is the deterministic pin on `plan_unlock`
clearing its traps first.

- [x] **Step 7.3: Write the minimal implementation**

In `bin/keel`, add before `plan_tick`:

```bash
# plan_lock <plan>: holds <plan>.lock until plan_unlock, so two ticks on one plan cannot each
# read it before the other writes and drop one's change, which a concurrent batch's ticks otherwise
# do. mkdir is the lock because it is atomic on every filesystem keel runs on and needs no flock,
# which macOS lacks. It waits about ten seconds, then fails naming the lock, because a tick killed
# with SIGKILL leaves it behind and nothing else would say so. A mkdir that fails with no lock
# present is retried once, since a lock released between the failed mkdir and the check is not an
# error; if that fails with still no lock, as in a directory it cannot write, it fails at once.
plan_lock() {
    local n=0
    until mkdir "$1.lock" 2>/dev/null; do
        if [ ! -e "$1.lock" ]; then
            mkdir "$1.lock" 2>/dev/null && break
            [ -e "$1.lock" ] || die "cannot create $1.lock, so the plan cannot be locked: check its \
directory is writable"
        fi
        n=$((n + 1))
        [ "$n" -lt 100 ] || die "$1.lock is held by another keel plan tick. If none is running, one was killed: remove $1.lock"
        sleep 0.1
    done
    PLAN_LOCK="$1.lock"
    trap 'rmdir "$PLAN_LOCK" 2>/dev/null' EXIT
    trap 'exit 130' INT TERM
}

# plan_unlock: clears the traps before releasing, because an EXIT trap left set would rmdir the lock
# a second time at exit, by which point another tick may hold it. Planning saw exactly that: 18 of
# 20 concurrent ticks landed until the traps were cleared first.
plan_unlock() {
    trap - EXIT INT TERM
    rmdir "$PLAN_LOCK"
}
```

In `plan_tick`, add `plan_lock "$plan"` on its own line directly before `tmp="$(mktemp)" || die
"cannot create a temporary file"`, and replace the `rm -f "$tmp"` line near its end with:

```bash
    rm -f "$tmp"
    plan_unlock
```

In `docs/03-install-and-distribution.md`, append to the `keel plan tick` paragraph:

```markdown
Ticks on one plan take turns through a lock, the directory `<plan>.lock`, so a concurrent batch's
ticks all land. A tick waits about ten seconds for it, then fails naming it, since a killed tick can
leave it behind.
```

Add at the top of `## Unreleased` in `CHANGELOG.md`:

```markdown
- `keel plan tick` takes a lock, `<plan>.lock`, so ticks started together on one plan all land.
```

Lint: the profile's shellcheck command.

- [x] **Step 7.4: Run it and watch it pass**

Run: `tests/test-plan.sh`
Expected: PASS, `38 passed, 0 failed`. The stale-lock case takes about eleven seconds.

- [x] **Step 7.5: Run the suite at the unit boundary, then hand over**

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.

```bash
git add bin/keel tests/test-plan.sh docs/03-install-and-distribution.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(plan): keel plan tick locks the plan so concurrent ticks land"`.

**Review record, 2026-09-28.** Spec review COMPLIES; removing the lock turned both cases red every
run, while removing `plan_unlock`'s trap clearing was caught only about 6 runs in 10. The quality
review raised two should-fix items, fixed test first and re-reviewed: a lock that could not be
created, as in a read-only directory, was reported after ten seconds as one that is held, so it now
fails at once, with a retry so a lock released mid-check is not misreported (a race the first fixer
found in the specified fix); and a shim `rmdir` now pins the trap clearing deterministically. One
fixer stopped on repeated shell-check outages and was re-dispatched. Considered and not acted on: a
symlink and its target take different locks; `trap 'exit 130' INT TERM` is redundant; the stale-lock
case does not check the held lock survives; the stale-lock case adds about ten seconds to the file;
signal windows around the lock; the temporary file on a signal; `status` reads without the lock and
a tick truncates in place; docs/03 does not mention the immediate failure.

### Task 8: `execute-plan` ticks and finds its place with the commands

**Story:** S-08
**Files:**
- Modify: `skills/execute-plan/SKILL.md`
- Modify: `skills/execute-plan/references/subagent-prompts.md`
- Modify: `skills/execute-plan/references/parallel-batches.md`
- Test: `tests/test-plan.sh`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: `keel plan status` and `keel plan tick` as tasks 2 to 7 left them
- Produces: nothing new in code

**Depends on:** task 7

**Done when:** `tests/test-plan.sh` passes.

- [x] **Step 8.1: Write the failing test**

In `tests/test-plan.sh`, insert directly above the `rm -rf "$d"` line at the end:

```bash
# ---- the skills name the commands, and the fallback -----------------------------------------------

f="$ROOT/skills/execute-plan/SKILL.md"
grep -qF 'Resume with `keel plan status`; tick with `keel plan tick`, or by' "$f" \
  && grep -qF 'hand where `keel` cannot run or reports the plan unaddressable.' "$f" \
  && ok "execute-plan resumes and ticks with the commands, by hand where keel cannot run" \
  || bad "execute-plan" "Step 4 does not name keel plan status, keel plan tick and the fallback"

f="$ROOT/skills/execute-plan/references/subagent-prompts.md"
grep -qF 'task'"'"'s steps with `keel plan tick <plan> <id>`' "$f" \
  && grep -qF '`keel plan tick <plan> <id> --note <text>`' "$f" \
  && grep -qF 'unaddressable' "$f" \
  && grep -qF 'keel plan status <plan>' "$f" \
  && grep -qF 'one call per step' "$f" \
  && grep -qF 'not installed or not on PATH' "$f" \
  && ok "subagent-prompts ticks with keel plan tick, notes with --note, and names the fallback" \
  || bad "subagent-prompts" "the tick instructions do not name keel plan tick, --note and the fallback"

f="$ROOT/skills/execute-plan/references/parallel-batches.md"
grep -qF 'Tick the whole batch'"'"'s steps with `keel plan tick`' "$f" \
  && grep -qF 'By hand, tick serially' "$f" \
  && ok "parallel-batches lets locked ticks overlap and keeps hand ticks serial" \
  || bad "parallel-batches" "the batch tick rule does not name keel plan tick"
```

- [x] **Step 8.2: Run it and watch it fail**

Run: `tests/test-plan.sh`
Expected: FAIL on all three new cases, each naming its file.

- [x] **Step 8.3: Write the minimal implementation**

In `skills/execute-plan/SKILL.md`, Step 4, replace:

```markdown
For each task: mark it in progress, follow its steps exactly, run its `Done when:` command, then
hand over as the task specifies.
```

with:

```markdown
For each task: mark it in progress, follow its steps exactly, run its `Done when:` command, then
hand over as the task specifies. Resume with `keel plan status`; tick with `keel plan tick`, or by
hand where `keel` cannot run or reports the plan unaddressable.
```

and delete this row from the Common mistakes table, whose rule Step 3 states with its link:

```markdown
| Overlapping tasks the plan did not declare a batch | Disjoint files are not enough. Read the batch rules |
```

In `skills/execute-plan/references/subagent-prompts.md`, replace:

```markdown
After both passes, with pass one at COMPLIES and pass two carrying nothing `blocking`: tick the
checkboxes in the plan file, **then commit**, with the paths and the message the task's hand-over
step names, then dispatch the next.
```

with:

```markdown
After both passes, with pass one at COMPLIES and pass two carrying nothing `blocking`: tick the
task's steps with `keel plan tick <plan> <id>`, **then commit**, with the paths and the message the
task's hand-over step names, then dispatch the next. Where `keel` cannot run, or reports the plan
unaddressable because it has no step ids, tick the checkboxes by editing the plan file.
```

and replace:

```markdown
You are ticking boxes for work you did not do, so tick on the subagent's reported output and add a
note for every step it named as already satisfied. Nobody witnessed those, and the plan is the only
place that can say so.
```

with:

```markdown
You are ticking boxes for work you did not do, so tick on the subagent's reported output and add a
note, `keel plan tick <plan> <id> --note <text>`, for every step it named as already satisfied.
Nobody witnessed those, and the plan is the only place that can say so.
```

In the same file's "## Running the loop" section, after the paragraph ending "you now have two
problems entangled.", add this paragraph, so a delegated coordinator resumes with the command too
(Step 4 of the skill body is written for whoever holds the keyboard):

```markdown
**Find where the run stands with `keel plan status <plan>`**: its `next:` line names the first
open step, and so the next task to dispatch; after a compaction it replaces rereading the plan.
Where `keel` is not installed or not on PATH, or it reports the plan unaddressable, read the
checkboxes instead.
```

and directly after the replaced "After both passes" paragraph, add this one, which states the
rule's reason and what the fallback's "cannot run" means:

```markdown
`<id>` is a step id such as `3.2`, one call per step, never a task number. The command is used
rather than an edit because it rewrites only that step's line, in the form `keel plan status` and
`ship`'s gate read back, and holds a lock so a batch's ticks cannot overwrite each other. In the
fallback, "cannot run" means `keel` is not installed or not on PATH. Any other failure (exit 1)
names what is wrong with the id or the plan, such as an id the plan does not hold, a fence that
never closes, or a lock still held, and is fixed rather than bypassed by editing the plan by hand,
which would reopen the race the lock closes.
```

In `skills/execute-plan/references/parallel-batches.md`, replace:

```markdown
3. Tick the checkboxes for the whole batch, serially. Two near-simultaneous edits to the plan file
   will otherwise drop one task's ticks through a stale read.
```

with:

```markdown
3. Tick the whole batch's steps with `keel plan tick`, which locks the plan, so ticks may overlap.
   By hand, tick serially: two near-simultaneous edits to the plan file drop one task's ticks
   through a stale read.
```

Add at the top of `## Unreleased` in `CHANGELOG.md`:

```markdown
- `execute-plan` resumes with `keel plan status` and ticks with `keel plan tick`, by hand where
  `keel` cannot run or the plan has no step ids.
```

Run `tests/validate-skills.sh` and confirm the `execute-plan` line reports 897 words, within the
900 ceiling. Then `tests/validate-citations.sh`, repairing per the Global constraints.

- [x] **Step 8.4: Run it and watch it pass**

Run: `tests/test-plan.sh`
Expected: PASS, `41 passed, 0 failed`.

- [x] **Step 8.5: Run the suite at the unit boundary, then hand over**

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
`tests/test-eval-harness.sh` case 25 passes unchanged, since the pinned paragraph was not touched.

```bash
git add skills/execute-plan/SKILL.md skills/execute-plan/references/subagent-prompts.md \
        skills/execute-plan/references/parallel-batches.md tests/test-plan.sh CHANGELOG.md
git status --porcelain
```

Stage exactly those paths, plus any file a citation repair touched, named in the report, and stop.
**Do not commit.** The coordinator commits after both review passes, with
`git commit -m "feat(execute-plan): resume and tick with keel plan status and keel plan tick"`.

**Review record, 2026-09-28.** Spec review COMPLIES, with all five citation repairs confirmed. The
quality review raised three should-fix items, fixed test first in `subagent-prompts.md` (the body
stays at 897 words) and re-reviewed: a delegated coordinator was never told to resume with
`keel plan status`; the new rules stated no reason; and "cannot run" and `<id>` were undefined, so
any failure could read as licence to hand-edit. Two more moved citations were repaired. Considered
and not acted on: "disjoint files are not enough" now lives only in `parallel-batches.md`; the inline
coordinator is not told `--note` by name; "mark it in progress" has no matching step state; the
wording tests depend on line wrapping; `docs/prd/coding-standards-enforcement.md`'s `:145-165` was
already off at HEAD and now falls further from the DEVIATES paragraph.

### Task 9: `ship` reads plan readiness from `keel plan status`

**Story:** S-09
**Files:**
- Modify: `skills/ship/SKILL.md`
- Test: `tests/test-plan.sh`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: `keel plan status`'s output and exit status, from tasks 2, 3 and 6
- Produces: nothing new in code

**Depends on:** task 8

**Done when:** `tests/test-plan.sh` passes.

- [x] **Step 9.1: Write the failing test** Note: written by the second implementer, whose session died before it reported; the coordinator read it in the diff

In `tests/test-plan.sh`, insert directly above the `rm -rf "$d"` line at the end:

```bash
f="$ROOT/skills/ship/SKILL.md"
grep -qF '7. **`keel plan status <plan>` prints `next: none` and exits 0**, and the report names each' "$f" \
  && grep -qF 'deferred or not-applicable step with its reason. Exit 1 fails the gate.' "$f" \
  && grep -qF 'Where `keel` is not installed or not on PATH, or reports the plan unaddressable, read the' "$f" \
  && grep -qF 'plan by hand instead: every checkbox is ticked, or the remainder is explicitly deferred and' "$f" \
  && ok "ship gates on keel plan status, names deferrals, and falls back by hand" \
  || bad "ship" "gate item 7 does not read keel plan status with its by-hand fallback"
```

- [x] **Step 9.2: Run it and watch it fail** Note: the first run was not witnessed; the coordinator saw its first phrase absent from HEAD's ship skill, and the fixer ran the final case against the old item 7: 41 passed, 1 failed

Run: `tests/test-plan.sh`
Expected: FAIL on the new case, `ship: gate item 7 does not read keel plan status with its by-hand
fallback`.

- [x] **Step 9.3: Write the minimal implementation** Note: edited by the second implementer before its session died; verified by the coordinator, then spec and quality review

In `skills/ship/SKILL.md`, replace:

```markdown
7. **The plan's checkboxes are ticked**, or the remainder is explicitly deferred and said out loud.
```

with:

```markdown
7. **`keel plan status <plan>` prints `next: none` and exits 0**, and the report names each
   deferred or not-applicable step with its reason. Exit 1 fails the gate.
   Where `keel` is not installed or not on PATH, or reports the plan unaddressable, read the
   plan by hand instead: every checkbox is ticked, or the remainder is explicitly deferred and
   said out loud.
```

Add at the top of `## Unreleased` in `CHANGELOG.md`:

```markdown
- `ship` passes a plan when `keel plan status` prints `next: none` and exits 0; a plan with no step
  ids is still checked by its boxes, as before.
```

Item 7 takes five lines, so item 8 lands on line 36 and each of the test's four phrases is one
whole line. Run `tests/validate-skills.sh` and confirm the `ship` line reports 749 words.

The new item is four lines longer, so every line below it moves by four. Repair each citation into
`skills/ship/SKILL.md` that was correct before and now moves, in both the `skills/ship/SKILL.md:<N>`
form and the `ship/SKILL.md:<N>` shorthand the validator does not see. A single line becomes a
phrase citation; a range naming the whole gate keeps line numbers, since a phrase cannot name a
range, and ends at item 8, the branch, now line 36:

| File | Before | After |
|---|---|---|
| `docs/plans/2026-08-31-release-operations-and-claims-audit.md`, the gate sentence listing tests to branch | `skills/ship/SKILL.md:20-31` | `skills/ship/SKILL.md:20-36`, since the sentence names all eight items (the range was already one short before this task) |
| the same file, the bullet quoting the red-check rule | `skills/ship/SKILL.md:39-40` | `skills/ship/SKILL.md#Say which check failed` |
| `docs/plans/2026-09-07-declared-profile-keys-take-effect.md` | `advisory:skills/ship/SKILL.md:66` | `advisory:skills/ship/SKILL.md#profile.conventions.commit_style` |
| `docs/ideas/declared-profile-keys-take-effect.md` | `skills/ship/SKILL.md:66` | `skills/ship/SKILL.md#profile.conventions.commit_style` |
| `docs/ideas/leon-van-zyl-skill-collection.md`, line 139 | `ship/SKILL.md:81` | `ship/SKILL.md#if there is no pipeline to run this` |
| the same file, line 193 | `ship/SKILL.md:36-37` | `ship/SKILL.md#Do not fix it as part of shipping` |
| the same file, the gate ranges | `ship/SKILL.md:16-32`, `:20-32` | `ship/SKILL.md:16-36`, `:20-36` |
| `docs/ideas/write-ci-does-not-match-ship.md` | `skills/ship/SKILL.md:20-32` | `skills/ship/SKILL.md:20-36` |
| `docs/ideas/standards-that-bind.md` | `skills/ship/SKILL.md:16-32`, `:20-32` | `skills/ship/SKILL.md:16-36`, `:20-36` |

Each phrase must occur once in `skills/ship/SKILL.md` (`grep -cF`). A repair that reflows its
paragraph and moves later lines of its own file repairs any citation into that file in turn. Then
run `tests/validate-citations.sh`, and grep for `ship/SKILL.md:` as well as `skills/ship/SKILL.md:`
before handing over.

- [x] **Step 9.4: Run it and watch it pass**

Run: `tests/test-plan.sh`
Expected: PASS, `42 passed, 0 failed`.

- [x] **Step 9.5: Run the suite at the unit boundary, then hand over**

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.

```bash
git add skills/ship/SKILL.md tests/test-plan.sh CHANGELOG.md
git status --porcelain
```

Stage exactly those paths, plus each file a citation repair touched, named in the report, and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(ship): the plan gate reads keel plan status"`.

**Review record, 2026-09-29.** The second implementer's session died on an authentication failure
after its edits and before it verified or reported; its diff matched this task line for line, so the
coordinator ran the verification and staged it rather than discarding it. Spec review COMPLIES, with
every row of the citation table confirmed. The quality review raised three should-fix items, fixed
test first and re-reviewed: a plan deferred in full passed with nothing said; the by-hand read
missed a stray open box that `keel plan status` fails; and the two fallbacks were split unlike
`execute-plan`'s, with "cannot run" undefined. Item 7 is now the five lines above and `ship` is 749
words. Considered and not acted on: "the report" could be read as keel's output; the by-hand path
asks for no reason; an older `keel` without `plan` fails the gate rather than falling back;
`execute-plan` and `ship` word the trigger differently; `write-ci-does-not-match-ship.md` row 7 and
`standards-that-bind.md:516`'s word counts sit beside repaired citations and were stale before; the
`ship` CHANGELOG entry does not name the deferral report.

### Task 10: The eval arms that inject `execute-plan` and `ship` pass at the new bodies

**Story:** S-08 and S-09, their last scenarios; ADR-0001 for both new lengths
**Files:**
- Modify: `tests/evals/results.md`

**Interfaces:**
- Consumes: the bodies tasks 8 and 9 left, at 897 and 749 words
- Produces: one results entry per arm

**Depends on:** tasks 8 and 9

**Done when:** there is no command. Each arm is graded against its scenario's criteria by reading its
result, and both are recorded as **Pass** in `tests/evals/results.md`.

- [x] **Step 10.1: There is no test for this**

An eval arm is a model run graded by reading its tool calls and reply against the scenario's
written criteria; no script can grade it.

**Only a Pass discharges ADR-0001.** A Partial, which `done-without-verifying.md` defines and has
seen before, stops this task exactly as a fail does: report it with the arm's own words, and do not
re-run the arm hoping for a pass.

**What the arm finds on its PATH.** It runs whichever `keel` the PATH resolves, and where that is
this clone's `bin/keel`, as through a `~/.local/bin/keel` symlink, it has tasks 2 to 7's commands.
The `done-without-verifying` fixture plan has no step ids, so `keel plan status` and `keel plan
tick` exit 3 there and the arm is expected to fall back to editing the boxes by hand, which is the
path the new Step 4 sentence names. Record which `keel` it found (`command -v keel` from the staged
`project/`) in the results entry. It costs API tokens, about $0.30 to $2 an arm going by the
last recorded runs.

- [x] **Step 10.2: Run the `execute-plan` arm**

```bash
dir=$(tests/evals/stage.sh done-without-verifying)
( cd "$dir/project" && claude -p "$(cat ../prompt.md)" \
    --setting-sources "" --disable-slash-commands \
    --permission-mode bypassPermissions --output-format json > "$dir/result.json" )
```

Grade `$dir/project/PLAN.md`, not the reply, against `tests/evals/scenarios/done-without-verifying.md`,
whose Scoring section says so, in its form `pass (open xN, named xM)`; read `$dir/result.json` only
for the rationalisation the arm used.
A fail stops this task: report it with the arm's own words and use `keel:debug`, rather than
editing the body until it passes.

- [x] **Step 10.3: Run the `ship` arm** Note: run by the coordinator at Bernard's request after the classifier denied the subagent's dispatch

```bash
dir=$(tests/evals/stage.sh ship-with-flaky-tests)
( cd "$dir/project" && claude -p "$(cat ../prompt.md)" \
    --setting-sources "" --disable-slash-commands \
    --permission-mode bypassPermissions --output-format json > "$dir/result.json" )
```

Grade it against `tests/evals/scenarios/ship-with-flaky-tests.md`. A fail stops this task as above.

- [x] **Step 10.4: Record both** Note: graded and written by the coordinator at Bernard's request

Append to `tests/evals/results.md`, in the shape of its 2026-09-21 "ship gate reads
gates.coding_standards" entry:

```markdown
## 2026-MM-DD, execute-plan and ship re-run at the keel plan bodies

`docs/plans/2026-09-28-addressable-plan-steps.md` tasks 8 and 9 changed `skills/execute-plan/SKILL.md`
from 896 to 897 words and `skills/ship/SKILL.md` from 703 to 749. ADR-0001 requires a passing arm
at each new length; the existing scenarios are re-run.

**Method.** One treatment arm each, staged by `tests/evals/stage.sh` and dispatched from the staged
`project/` directory with `--setting-sources "" --disable-slash-commands --permission-mode
bypassPermissions --output-format json`. <turns, time and cost of each, from result.json>

| Scenario | Skill | Verdict | Note |
|---|---|---|---|
| `done-without-verifying` | `execute-plan` | <verdict> | <what the arm did, against the criteria> |
| `ship-with-flaky-tests` | `ship` | <verdict> | <what the arm did, against the criteria> |
```

Fill each `<...>` from the arm's own result, and the date with the day it ran.

- [x] **Step 10.5: Hand over**

```bash
git add tests/evals/results.md
git status --porcelain
```

Stage exactly that path and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "test(evals): execute-plan and ship pass at the keel plan bodies"`.

**Review record, 2026-09-29.** The implementer ran the `execute-plan` arm; the auto-mode
classifier denied its dispatch of the `ship` arm, and then the coordinator's message resuming it. At
Bernard's request the coordinator ran the `ship` arm once, and graded and recorded both itself.
Both arms Pass, and spec review re-graded both from their output and COMPLIES, with one overclaim
corrected ("failed identically" became "exited 1"). The quality review raised two should-fix items,
both fixed and re-reviewed: the `ship` note implied item 7 was exercised, and nothing said neither
arm reached the new `keel plan` text. The re-review's one should-fix, the cause of item 7 going
unreached, took its own wording without a further round. Considered and not acted on: name the arm
transcripts' session ids; the Skill column omits `tdd`, which the arm also injected; the claude.ai
connector notice reaches arms despite `--setting-sources ""`; the `execute-plan` note's colon
implies a reason the arm never learned; "check 1" beside "item 7".

## Code review, 2026-09-29

`review-code` over the whole branch found one blocking item and five should-fix; Bernard chose to
fix all six before shipping, each test first through an implementer and both reviews:

- Blocking: a tick on a full disk could empty the plan. A short temporary copy (busybox awk exits 0
  on a failed write) was copied over it, and a failed copy back deleted the only complete copy. A
  tick now checks the copy is complete before writing back, and keeps it, naming it, if the write
  back fails.
- A fence opened on a list-item line was not seen, so its closing line opened a phantom fence that
  hid the steps after it. It is now seen, and closes when its item ends at a less-indented list
  item. Two rounds of quality review narrowed that close so an unclosed bullet fence, and a list
  fence closed at column 0 or after a tab, hide no step.
- The ```` fence case gained a step between the inner and outer close, so breaking the length rule
  now fails a test.
- A title holding `**` is no longer cut when parked; with no `**` that ends the title or opens a
  note or reason, the first `**` still ends it, so a malformed parked tail is still flagged.
- Task 9's steps 9.1 to 9.3 carry notes saying what was and was not witnessed.
- S-01's scenario says no existing plan is migrated, since six took citation repairs.

Considered and not acted on: a read-only plan reports "may now be truncated" and leaves a temporary
copy; trailing blanks after a title's closing `**` still fall back to the first `**`; a nested
`- 1. ```` marker is not stripped; the completeness check cannot see bytes lost inside a line; a
free-form bold tail now joins the title; `tick p 1.1 '' text` drops the text; `status` does not list
parked steps; the lock retry, the argument count and `--note` needing text are untested; two
citation repairs fixed citations already wrong before this branch; this feature's idea and stories
describe the old serial-tick rule; `next:` can point back at a step deliberately left open.

## Coverage

| Story | Tasks |
|---|---|
| S-01 | 1 |
| S-02 | 2 |
| S-03 | 3 |
| S-04 | 6 |
| S-05 | 4 |
| S-06 | 5 |
| S-07 | 7 |
| S-08 | 8, 10 |
| S-09 | 9, 10 |
