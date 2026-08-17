# Terse Chat Output Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** ship an opt-in output style that compresses conversation without touching artifact detail
or the statements keel's gates depend on, and put the shipped file under the same content rules as
every other shipped file.

**Stories:** none written. Scope is `docs/ideas/concise-responses.md`, agreed 2026-08-16 once the
requester separated artifact detail from chat length.
**ADRs:** ADR-0001 governs skill bodies. No skill body changes here, so it does not bind, and that
is the point: the style file carries the rule at zero always-loaded cost.
**Architecture:** one new plugin component directory, `output-styles/`, holding one file. Claude
Code loads that directory by default, so `plugin.json` needs no `outputStyles` field. The validator's
existing content-rules loop is extended to cover it. Nothing else changes behaviour.

## Global constraints

Copied from `.keel/profile.json` and the repository conventions. Every task inherits these.

- Verify commands: test `tests/run-tests.sh`, one test `tests/{name}`, lint
  `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`
- There is no format, typecheck, build or e2e command in this project.
- **The full suite takes upwards of ten minutes**, nearly all of it `tests/test-keel.sh`. Run it in
  the background and do not pipe it through `tail`, which buffers the whole run.
- Never start on `main`. This lands on `sandbox`, PR'd to `main`.
- Conventional commits, title and body only. No attribution footers, no robot emoji.
- No em dashes or en dashes anywhere. Task 2 is what makes the validator enforce that in the new
  directory rather than leaving it to review.
- `gates.done_verified` is `required` in this repository, so `hooks/done-guard` refuses to end a
  turn that edited code without running `tests/run-tests.sh`. That is intentional and it applies to
  the agent executing this plan.

## Decisions taken while planning

1. **SUPERSEDED 2026-08-16 by `docs/plans/2026-08-16-terse-by-default.md`.** This decision chose
   opt-in; the requester reversed it to on-by-default with `conventions.response_style` as the
   opt-out. `force-for-plugin` is still rejected, for the reason given below: it cannot be declined
   per project. The original text follows.

   **Opt-in, not `force-for-plugin`.** A plugin output style can set `force-for-plugin: true` and
   apply itself whenever the plugin is enabled, overriding whatever the user chose in `/config`.
   Rejected: it takes a setting the user made, it cannot be declined per project, and it is
   invisible in every settings file. Open question 2 in the idea record asked this and answered
   opt-in.
2. **`keel init` does not write `outputStyle` yet, and the reason is in this repository already.**
   `bin/keel:470` records the failure mode for exactly this: a name written into `settings.json`
   that fails to resolve "lands in settings.json, fails to resolve, and the user distrusts the whole
   file". Whether a plugin's style is addressed as `keel-terse` or namespaced the way skills are
   (`keel:tdd`) has not been observed, only guessed at. Task 3 records the observation that would
   settle it. Writing a guess is the one thing this repository has already learned not to do.
3. **`keep-coding-instructions: true`.** Without it, Claude Code's built-in software engineering
   instructions are dropped, which would silently change how work is scoped and verified. The goal
   is shorter replies, not a different engineer.
4. **The style names its exemptions rather than implying them.** Every statement keel's gates
   depend on is short, so a blunt "be brief" does not obviously threaten them, and that is precisely
   why it would erode them: nothing would notice. They are listed by name in the file.
5. **No skill bodies are trimmed in this plan.** The idea record's recommendation included trimming
   the report sections of the longest skills. Dropped: five of six dispatching skills now sit within
   four words of the ADR-0001 warning after the model pins, so any trim there is a separate,
   measured piece of work, and the style is what the idea is actually about.

---

### Task 1: The style file

**Files:**
- Create: `output-styles/keel-terse.md`

**Interfaces:**
- Produces: a style whose frontmatter carries `name`, `description` and
  `keep-coding-instructions: true`, consumed by task 2's validator rule and named in task 3's docs

**Done when:** `python3` parses the frontmatter and reports all three fields present with
`keep-coding-instructions` true, and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

There is no test file for output styles yet; task 2 creates the rule that checks them. Write this
task's check as a one-line command run by hand at step 2, and let task 2 turn it into an enforced
rule. Stated rather than skipped: this task's gate is a command, task 2's is the validator.

```bash
python3 -c "
import sys
t=open('output-styles/keel-terse.md').read()
assert t.startswith('---'), 'no frontmatter'
fm=t.split('---')[1]
for k in ('name:','description:','keep-coding-instructions: true'):
    assert k in fm, k
print('frontmatter OK')"
```

- [x] **Step 2: Run it and watch it fail**

Run the command above.
Expected: FAIL, `FileNotFoundError`, because `output-styles/` does not exist.

- [x] **Step 3: Write the style**

Create `output-styles/keel-terse.md`. The frontmatter:

```markdown
---
name: keel terse
description: Short conversation replies. Artifacts stay as detailed as the skill requires.
keep-coding-instructions: true
---
```

The body states the split first, then what compresses, then what does not. Write it so the
exemptions are unambiguous, because a model applying a brevity instruction will otherwise trade away
the shortest obligations first.

The two dials, stated as the opening rule:

- **Artifacts are unaffected.** A PRD, plan, ADR, snapshot, runbook, report or audit is as long as
  its skill requires. Brevity never justifies a thinner document, a dropped section, or a table
  reduced to prose.
- **The reply is a pointer, not a copy.** Say what changed, where it is, and what needs a decision.

What to cut, listed concretely enough to act on:

- Preamble and postamble. No announcing what you are about to do before doing it, no closing offer
  of further help.
- Re-narrating tool results the user can see, and restating file contents just written.
- Explaining reasoning already recorded in the artifact. Cite the path instead.
- Recapping a multi-step run step by step when the outcome and the exceptions are the whole message.
- Hedging, and caveats already stated once.

What stays, by name, because these are what make the process auditable:

- The one-line skill announcement.
- Every verification that was run, and **which were skipped**, with output when something failed.
- Assumptions, and any second reading of an ambiguous request.
- Deviations from a plan, refusals, and what blocked them.
- The output of a task's `Done when:` command.
- One recommendation, and the named next step.

Close with the resolution rule, which is the file's real content:

> When brevity and one of the statements above conflict, the statement wins. Compress the narration
> around it instead. A reply that is short because it left out a skipped check is not terse, it is
> wrong.

- [x] **Step 4: Run it and watch it pass**

Run the step 1 command.
Expected: `frontmatter OK`.

Then run `tests/run-tests.sh` in the background. Expected: green. It does not yet check this file,
which is task 2.

- [x] **Step 5: Commit**

```bash
git add output-styles/keel-terse.md
git commit -m "feat(output-styles): keel terse, opt-in short replies

Artifacts keep their detail; the conversation stops restating them. Ships
the exemptions by name, because a brevity instruction otherwise trades away
the shortest obligations first and those are the auditable ones."
```

---

### Task 2: Put the new directory under the content rules

**Files:**
- Modify: `tests/validate-skills.sh`
- Modify: `tests/test-validate-skills.sh`

**Interfaces:**
- Consumes: `output-styles/keel-terse.md` from task 1
- Produces: the em dash, docs-path and broken-link rules applied to `output-styles/`, plus a
  frontmatter rule for style files

**Done when:** `tests/test-validate-skills.sh` passes including two new cases, and
`tests/validate-skills.sh` passes against this repository.

- [x] **Step 1: Write the failing test**

Add to `tests/test-validate-skills.sh`, following the existing `run <name> <expected-exit> <mutate>`
shape:

```bash
# The shipped style is shipped text, so it obeys the same content rules as skills and templates.
# It was not covered when output-styles/ was added, which is how a directory acquires its own
# quietly different standard.
m_style_em_dash() {
    mkdir -p "$1/output-styles"
    printf -- '---\nname: t\ndescription: d\nkeep-coding-instructions: true\n---\n\nA %s dash.\n' \
      "$(printf '\xe2\x80\x94')" > "$1/output-styles/t.md"
}
run "an em dash in an output style is rejected" 1 m_style_em_dash

m_style_no_keep_coding() {
    mkdir -p "$1/output-styles"
    printf -- '---\nname: t\ndescription: d\n---\n\nBody.\n' > "$1/output-styles/t.md"
}
run "an output style without keep-coding-instructions is rejected" 1 m_style_no_keep_coding
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-validate-skills.sh`
Expected: FAIL on both new cases, `expected exit 1, got 0`.

- [x] **Step 3: Extend the content loop and add the frontmatter rule**

In `tests/validate-skills.sh`, change the content-rules loop's source from

```bash
done < <(find skills templates -name '*.md' 2>/dev/null)
```

to

```bash
done < <(find skills templates output-styles -name '*.md' 2>/dev/null)
```

`find` errors on a missing directory, so keep the existing `2>/dev/null` and confirm at step 4 that
a tree without `output-styles/` still passes: every fixture in `tests/test-validate-skills.sh` is
such a tree, so this is already covered by the 38 cases that must stay green.

Then add the frontmatter rule, in the file's established voice:

```bash
# A style that drops keep-coding-instructions replaces Claude Code's software engineering
# instructions rather than adding to them, which changes how work is scoped and verified. The goal
# here is shorter replies, not a different engineer, and the difference is invisible until someone
# wonders why the tests stopped being run.
for style in output-styles/*.md; do
    [ -e "$style" ] || continue
    fm="$(frontmatter_of "$style")"
    case "$fm" in *"keep-coding-instructions: true"*) ;;
        *) report "$style: no 'keep-coding-instructions: true'. A style without it drops the built-in software engineering instructions." ;;
    esac
    case "$fm" in *"name:"*) ;; *) report "$style: no name" ;; esac
    case "$fm" in *"description:"*) ;; *) report "$style: no description" ;; esac
done
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-validate-skills.sh`
Expected: PASS, 40 cases.

Run: `tests/validate-skills.sh`
Expected: PASS, 24 skills validated.

Then `tests/run-tests.sh` in the background, and the profile's lint command. Both green.

- [x] **Step 5: Commit**

```bash
git add tests/validate-skills.sh tests/test-validate-skills.sh
git commit -m "test(validate-skills): output-styles obeys the shipped-text rules

A new component directory arrived outside every content rule, which is how a
directory acquires its own quietly different standard. It now gets the em
dash, docs-path and broken-link checks, plus a frontmatter rule: a style
without keep-coding-instructions replaces the built-in engineering
instructions instead of adding to them, and nothing would have noticed."
```

---

### Task 3: Document it, and record what would let `keel init` set it

**Files:**
- Modify: `README.md`
- Modify: `docs/05-token-and-memory-design.md`
- Modify: `docs/07-open-decisions.md`

**Interfaces:**
- Consumes: the style from task 1
- Produces: nothing other tasks read

**Done when:** `tests/run-tests.sh` is green, including `tests/no-internal-leaks.sh` and
`tests/test-cache-install.sh`, and `grep -c 'keel terse' README.md` is at least 1.

- [x] **Step 1: There is no test for this**

Documentation prose has no command behind it. The `Done when:` line above checks that the README
mentions the style and that the shipped-file scanners still pass; it does not check that the
sentences are true. That is a review job, and saying so is the honest version.

- [x] **Step 2: README**

Add a short subsection under Install, after the optional-symlink block, saying: the plugin ships an
opt-in output style; select it in `/config` under **Output style**; it shortens replies and does not
change how long documents are; it takes effect after `/clear` or a new session. State plainly that
it is not on by default and that keel does not set it for you.

- [x] **Step 3: `docs/05-token-and-memory-design.md`**

That document budgets input. Add a short section recording that reply length is **output** cost,
that it was previously ungoverned, and that the style is the lever, with the honest limits: it does
not reach subagents, whose reports come back through their own system prompt, and keel's share of
reply length has never been measured. Reference open question 1 in the idea record rather than
restating it.

- [x] **Step 4: `docs/07-open-decisions.md`**

Record the decision task 2 could not take, phrased as the observation that settles it:

> **Should `keel init` set `outputStyle` for a project?** Not until the style's addressable name is
> observed rather than guessed. A plugin skill is addressed `keel:tdd`; whether a plugin output
> style is `keel-terse` or `keel:terse` has not been checked. `bin/keel:470` already records what a
> wrong name costs: it lands in `settings.json`, fails to resolve, and the reader distrusts the
> whole file. **What settles it:** open `/config` after a session restart with this version
> installed and read the name listed under Output style. If init later writes it, the escape hatch
> is `.claude/settings.local.json`, which is gitignored and overrides the committed value.

- [x] **Step 5: Run the suite and watch it pass**

Run `tests/run-tests.sh` in the background, and the profile's lint command.
Expected: both green. `tests/no-internal-leaks.sh` and `tests/supply-chain-scan.sh` read these files
and must stay clean.

- [x] **Step 6: Commit**

```bash
git add README.md docs/05-token-and-memory-design.md docs/07-open-decisions.md
git commit -m "docs: the terse output style, and what it deliberately does not do

Selecting it is a user action in /config, not something keel init does. The
name a settings file would need has not been observed, and bin/keel:470
already records what writing an unresolvable one costs. Recorded in
07-open-decisions with the observation that settles it."
```

---

## Open questions

Neither blocks execution.

1. **What share of reply length is keel's?** Open question 1 in the idea record, unanswered. If the
   answer is small, this plan's value is mostly in the artifact-versus-chat rule rather than in
   token savings, and that rule is worth having either way.
2. **Does the style change eval outcomes?** The five Tier 3 scenarios assert that gates are
   announced out loud. A style that suppressed an announcement should fail them, which is the
   correct outcome and the reason the exemptions are named in the file. Not run here, for the same
   reason `done-without-verifying` is not: an arm is dispatched by an agent.

## What this plan does not cover

Trimming skill report sections, which the idea record's recommendation included. Five of the six
dispatching skills now sit within four words of ADR-0001's 700-word warning, so a trim there is
separate, measured work rather than something to fold in here.
