# Close the enforcement gaps from the snapshot, Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go, on output you read.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness, or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** close the verified gaps in section 10 of `docs/snapshot.md`, so that a gate means what it
says, generated CI runs where it should, and keel passes its own checks.

**Stories:** none. This is repository-infrastructure remediation, and the numbered
recommendations in section 10 of `docs/snapshot.md` stand in for stories: tasks 1 and 2 trace to
recommendation 1, task 3 to 2, task 4 to 4, task 7 to 3, task 8 to 5, task 9 to 6. Tasks 5, 6
and 10 come from the maintainer's decisions of 2026-09-25, recorded under "Decisions taken" below.
Task 0 is infrastructure and traces to none. The rest of recommendation 7 is a `decide` item and
is not planned here, see "Not in this plan". `write-user-stories` was not run, on the same basis
as `docs/plans/2026-09-19-make-keel-enforceable-outside-the-agent.md`.

**ADRs:** ADR-0003 (a primitive with no evidence row is treated as absent; no task here adds a hook,
so none needs a row).

**Architecture:** every change stays inside the existing layers. Tasks 1, 2 and 4 read the schema
and git config keel already has; task 3 reads a profile key `write_ci` ignored; task 5 declares one
new profile key, `conventions.no_attribution_footers`, and so moves `SCHEMA_VERSION` from 4 to 5,
the only task that does; task 6 adds a detector branch; tasks 7 to 10 are files outside `bin/`.

**Concurrent batches:** none. Tasks 1 to 6 all edit `bin/keel` and `tests/test-keel.sh`; every
task from 1 edits `CHANGELOG.md`; tasks 7, 9 and 10 touch the profile and CI, which a batch may
not. Run in order.

**Decisions taken, 2026-09-25, by the maintainer:**

| Question | Answer | Where it lands |
|---|---|---|
| Should the macOS job be a required check? | Advisory first; required after a week of green runs | Task 9, and a row in "Not in this plan" |
| How is `lib/*.py` linted? | ruff in CI only; the local lint string stays shellcheck | Task 10 |
| Does keel run its own push guard? | Yes: install it and commit `.githooks/` | Task 7 |
| The guard's `Keel-Version` trailer conflicts with the no-footers rule | The message hook honours `conventions.no_attribution_footers`, declared in the schema | Task 5 |
| Should keel detect `verify.security`? | Yes, from the package manager; full `doctor` runs it, `--fast` does not | Task 6 |

**How this plan was checked.** Tasks 1 to 4 were dry-run on 2026-09-25 in a scratch clone: each
new test failed as its step 2 predicts and passed once its step 3 code was applied, with
shellcheck clean. The full suite on that clone then found three reds the first draft had not
predicted. Each is now handled in the task that causes it: the pre-push case in task 1, the
python3 start budget in task 2, and the doctor baseline comparison in task 4. An independent
review then read the plan against the code; its findings are folded in. Tasks 5 to 10 were added
after the decisions above and dry-run the same way, on top of tasks 0 to 4.

## Global constraints

- Verify commands, from `.keel/profile.json`: test `tests/run-tests.sh`; one test file
  `tests/test-keel.sh` (the `tests/{name}` pattern); typecheck and build are `null`, since there is
  nothing to compile; lint is:

  ```bash
  shellcheck -x bin/keel bin/keel-fleet lib/*.sh lib/harness/*.sh tests/*.sh tests/evals/run.sh \
    tests/evals/stage.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard
  ```

- `tests/test-keel.sh` takes about five minutes and `tests/run-tests.sh` about seven. Both print
  nothing until each file finishes. Slow is not hung.
- Lint after each file edit, not at the end of the task.
- Never start on `main`. Work on `sandbox`, which is where this repository's pull requests come
  from.
- No em dash and no en dash anywhere: code, comments, strings, docs, commit messages.
- Prose in markdown wraps at 100 columns; tables do not (docs/standards.md, "Prose wraps at 100
  columns; tables do not").
- Every rule a comment states carries its reason (docs/standards.md, "Every rule carries its
  reason").
- A gate is never weakened so this repository can pass it (docs/standards.md, "A gate is never
  weakened so this repository can pass it").
- Documentation lands in the same commit as the change: a line under `## Unreleased` at the top of
  `CHANGELOG.md` (create the heading directly above `## 0.21.0 - 2026-09-22` in the first task
  that needs it), plus any document the change makes wrong. Each task names the documents it
  found.
- **Citations into `bin/keel` and `tests/test-keel.sh` use a phrase, never a line number**, in
  the form `` bin/keel#<text from the line> ``; `tests/validate-citations.sh` refuses a line number
  into either. Older documents still cite `bin/keel`, `tests/validate-skills.sh` and
  `tests/test-doc-claims.sh` by line, and every insertion shifts them. After any edit to one of
  those three files, run that validator and repair every citation it reports, in the same task.
  It catches only a citation that now lands on a blank line or out of range, so the set it
  reports depends on where each insertion lands: the final dry run, with tasks 1 to 7, 9 and 10
  applied, reported 19, in `docs/plans/2026-09-07-declared-profile-keys-take-effect.md` (four),
  `docs/prd/context-window-at-init.md` and `docs/prd/plain-language-chat.md` and
  `docs/ideas/declared-profile-keys-take-effect.md` (two each), and one each in
  `docs/plans/2026-09-19-make-keel-enforceable-outside-the-agent.md`,
  `docs/plans/2026-09-01-standards-assessment.md`,
  `docs/plans/2026-09-02-the-four-mode-router-and-audit.md`,
  `docs/architecture/tiered-multi-harness-support.md`,
  `docs/ideas/leon-van-zyl-skill-collection.md`, `docs/ideas/windows-python3-detection-is-wrong.md`,
  `docs/ideas/write-ci-does-not-match-ship.md` and two files under `docs/audits/`. Stage the files
  you changed with the task that shifted them.
- **The validator does not see a shift that lands on a non-blank line, and any cited document can
  shift.** Task 1's two added lines in `docs/03-install-and-distribution.md` moved four line
  citations of it onto the paragraph above, silently, and only a quality review found them. So
  after inserting or deleting lines in any tracked file, grep the repository for
  `<that file>:<N>` citations with N at or after the edit, compare
  `git show HEAD:<file> | sed -n '<N>p'` with the current line N, and repair each whose target
  moved, under the rule below.
- **A repaired citation names the code its sentence is about, never whatever sits at the old line
  number.** Many of these line citations were already stale before this plan: task 1's first
  attempt copied the text at each old number and fixed wrong targets in place permanently, such as
  a claim about `merge_ts_strict` citing `set -euo pipefail`, and a quality review rejected it.
  For each one: read the sentence around the citation, find in the current file the line that
  sentence describes, and cite a phrase from that line which occurs **once** in the file (check
  with `grep -cF '<phrase>' <file>`; a phrase such as `else` matches dozens of lines). Where the
  sentence names a function, the function's definition line is the right target. Where no line in
  the current file does what the sentence says, leave the claim's wording alone, cite the nearest
  definition that does exist, and name that citation in your report as unresolved. Leave line
  citations the validator did not report untouched, even stale ones: this plan repairs what it
  shifted, and a wider repair is its own piece of work.
- **doctor may start python3 at most 10 times**, asserted by the case
  `` tests/test-keel.sh#keel doctor starts python3 at most 10 times ``, and it is at 10 today. A new
  doctor check shares an existing interpreter start or uses the cached `json_get`.
- **A schema edit regenerates the reference:** run
  `tests/generate-profile-keys.sh > docs/profile-keys.md`, then `tests/test-profile-keys.sh` must
  pass.
- **The doctor code is in `cmd_doctor_text`**, not `cmd_doctor`, which is the `--json` wrapper
  around it (`` bin/keel#cmd_doctor_text() { ``).
- Stage named paths only. Never `git add -A`, `git add .` or `git commit -a`.
- Commit messages are conventional, with no `Co-Authored-By`, no robot emoji and no generated-with
  line.
- Do not delete a file you did not create. If `git status` shows something unexpected, report it
  and leave it alone.

---

### Task 0: the plan's inputs into the tree, and the suite green

> **Execution note (2026-09-25):** done inline by the coordinator, since it commits documents and
> changes no code. Step 2's suite run was witnessed: tests/run-tests.sh printed All test files
> passed, exit 0, with all three files present. **Correction, found by task 1's implementer:** that
> run was green only because the files were untracked. `tests/test-harness-claims.sh` scans tracked
> top-level docs, and once committed, `docs/snapshot.md` failed it with eleven untagged hook
> sentences. The coordinator tagged them with `keel:claim` markers for the claude harness in a
> separate commit, after which that file passed 32 of 32.

**Story:** none. Infrastructure: task 8 cites two of them by path, and all three were
untracked when this plan was written. One of them was deleted once already by an agent that
mistook it for a stray file.
**Files:**
- Add: `docs/snapshot.md`
- Add: `docs/audits/2026-09-25-standards.md`
- Add: `docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md`

**Interfaces:** none.

**Depends on:** none

**Done when:** `tests/run-tests.sh` passes with the three files in the tree.

- [x] **Step 1: There is no failing test for this**

This task commits documents. The suite already validates their citations, links and dashes.

- [x] **Step 2: Run the suite with the three files present**

Run: `tests/run-tests.sh`
Expected: PASS. It ends `All test files passed`. `tests/validate-citations.sh` reads untracked
documents too, so this checks all three files.

- [x] **Step 3: Hand over**

```bash
git add docs/snapshot.md docs/audits/2026-09-25-standards.md \
        docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "docs: snapshot, standards assessment, and the plan that closes their gaps"`.

---

### Task 1: `profile set` refuses a value outside the schema's enum

> **Execution note (2026-09-25):** the first attempt passed spec review (COMPLIES) and failed
> quality review on one blocking finding: its 20 citation repairs copied the text at each old line
> number, which fixed already-stale targets in phrase form. Discarded unstaged and uncommitted, and
> re-dispatched fresh against the tightened citation rule in the global constraints, with the test
> assertion and comment tightened too. The review's suggestion to prove null with a gate key instead
> of `project.kind` was not taken: every enum key in the schema excludes null, so no key avoids that
> conflict.

> **Second attempt (2026-09-25):** the implementer's session was killed during step 5's full suite
> run, before it reported or staged. Its transcript witnessed steps 2 and 4: three FAIL lines on
> `profile set enum` as predicted (611 passed, 3 failed), then 614 passed, 0 failed, with lint and
> `tests/validate-citations.sh` clean after 15 citation repairs. The coordinator ran
> `tests/run-tests.sh` on the unchanged tree: All test files passed, exit 0. Spec review COMPLIES;
> quality review found nothing blocking. Two repaired citations are **unresolved**, citing the
> nearest line that exists because no current line says what their sentence claims:
> `docs/ideas/concise-responses.md` (`bin/keel#harness_section context-block`; the 450 and 700 token
> thresholds live in `lib/harness/claude.sh`) and `docs/ideas/keel-on-codex.md`
> (`docs/03-install-and-distribution.md#and nothing else, which is the tier below.`; the "skills
> stay Claude-only" sentence it once cited is gone). The quality review also found that the two
> lines this task adds to `docs/03-install-and-distribution.md` shift four citations of its line 475
> onto the wrong line, which the validator cannot see; a follow-up dispatch repaired them in the
> same commit, citing `docs/03-install-and-distribution.md#The skills are no longer Claude-only.`
> The sentences around those four still quote "The skills themselves stay Claude-only for now",
> which `docs/03-install-and-distribution.md` no longer says; their wording was left alone, so they
> stand as unresolved too. Its other findings, left for the report: `null` passes on gate keys and
> reads as `off`; `type` is not checked; `gates.additionalProperties` keys from pre-schema-4
> profiles go unchecked; `docs/snapshot.md` still says gate values are never validated.

**Story:** snapshot recommendation 1
**Files:**
- Modify: `bin/keel` (function `profile_set`)
- Modify: `tests/test-keel.sh`
- Modify: `docs/03-install-and-distribution.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: `$HERE/templates/profile.schema.json`, already shipped with the plugin
- Changes: the pre-push case in `tests/test-keel.sh` that writes `gates.commit_guard disabled`
  through `profile set`. Its comment says `profile set` has "no validation of its own", which this
  task makes false, so the case writes the value directly instead.
- Produces: `profile_set` exits 1 with a message naming the accepted values when a key has an
  `enum` under the schema's `properties` and the value is not in it. `null` is still accepted,
  because `profile set <key> null` is the documented way to clear a value
  (`` tests/test-keel.sh#profile set null clears a value ``). Gate keys the schema does not name,
  which fall under `gates.additionalProperties`, are not checked: `profile set` refuses a path
  that does not already exist, so such a key can only arrive by hand edit, and task 2 does not
  check it either. That is a stated limit, not an oversight.

**Depends on:** task 0

**Done when:** `tests/test-keel.sh` passes.

- [x] **Step 1: Write the failing test**

Insert this block in `tests/test-keel.sh` immediately above the file's final
`printf '\n%s passed, %s failed\n' "$pass" "$fail"` line:

```bash
# ---- profile set checks a value against the schema's enum ---------------------------------------
# A gate holding a typo reads as a weaker gate: hooks/done-guard treats anything that is not `off`
# or `required` as `warn`. So a value the schema does not list is refused where it is typed.
pe="$(fixture node-ts)"
( cd "$pe" && "$KEEL" init -y >/dev/null 2>&1 )
out="$( cd "$pe" && "$KEEL" profile set gates.done_verified requird 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && ok "profile set refuses a gate value outside the schema enum" \
  || bad "profile set enum" "exit $rc for gates.done_verified requird"
case "$out" in
  *required*warn*off*) ok "the enum refusal names the accepted values" ;;
  *) bad "profile set enum" "refusal did not list required, warn, off: '$out'" ;;
esac
got="$(prof_of "$pe" gates.done_verified)"
[ "$got" = "warn" ] && ok "the refused enum value was not written" \
  || bad "profile set enum" "gates.done_verified is '$got', not the init default warn"
( cd "$pe" && "$KEEL" profile set gates.done_verified required >/dev/null 2>&1 ) \
  && ok "profile set still accepts a value the enum lists" \
  || bad "profile set enum" "refused gates.done_verified required"
( cd "$pe" && "$KEEL" profile set project.kind null >/dev/null 2>&1 ) \
  && ok "profile set still accepts null on an enum key, which clears it" \
  || bad "profile set enum" "refused null for project.kind"
rm -rf "$pe"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: three FAIL lines on `profile set enum`, the first reading
`exit 0 for gates.done_verified requird`. The two `still accepts` lines pass.

- [x] **Step 3: Write the minimal implementation**

In `bin/keel`, change the first two lines of function `profile_set` from:

```bash
profile_set() {
    python3 - "$1" "$2" <<'PY'
```

to:

```bash
profile_set() {
    python3 - "$1" "$2" "$HERE/templates/profile.schema.json" <<'PY'
```

The interpreter line alone is not unique: two other functions in `bin/keel` open the same way.

Then, in the same heredoc, insert this directly above the line `node[keys[-1]] = val`:

```python
# The schema's enums are the only record of which values a key accepts, and until this check a
# typo in a gate was written, accepted by doctor, and read as a weaker gate by every hook. A
# missing or unreadable schema skips the check rather than refusing every write: an install with
# no templates/ fails louder elsewhere. null is let through because `profile set <key> null` is the
# documented way to clear a value. Keys under gates.additionalProperties are not walked: a path
# the profile does not already hold is refused above, so such a key only arrives by hand edit.
try:
    s = json.load(open(sys.argv[3]))
except Exception:
    s = None
for k in keys:
    s = (s.get("properties") or {}).get(k) if isinstance(s, dict) else None
if isinstance(s, dict) and "enum" in s and val is not None and val not in s["enum"]:
    sys.stderr.write("keel: '%s' is not a value %s accepts. Use one of: %s.\n"
                     % (raw, path, ", ".join(str(e) for e in s["enum"])))
    sys.exit(1)
```

Then, in `tests/test-keel.sh`, change the setup of the pre-push case whose assertion reads
`pre-push refuses gates.commit_guard set to an unrecognized value`. Replace:

```bash
# an unrecognized value, not "required", "warn" or "off", such as a typo, must be treated as a
# loosening too. The pre-commit hook's own case statement (`bin/keel#case "$gate" in`) already
# treats anything but required/warn as fully off, so this is a real value a profile can hold, not
# a contrived one, and `keel profile set` writes it as a plain JSON string with no validation of
# its own.
( cd "$rt" && "$KEEL" profile set gates.commit_guard disabled >/dev/null 2>&1 )
```

with:

```bash
# an unrecognized value, not "required", "warn" or "off", such as a typo, must be treated as a
# loosening too. The pre-commit hook's own case statement (`bin/keel#case "$gate" in`) already
# treats anything but required/warn as fully off, so this is a real value a profile can hold, not
# a contrived one. `keel profile set` refuses it now, but a hand edit or an older keel still writes
# one, so the value is written directly.
python3 - "$rt/.keel/profile.json" <<'PY'
import json, sys
p = json.load(open(sys.argv[1]))
p["gates"]["commit_guard"] = "disabled"
json.dump(p, open(sys.argv[1], "w"), indent=2)
PY
```

Without this change that case goes red once the refusal lands: `profile set` refuses `disabled`,
the commit that follows carries no loosening, and the hook has nothing to refuse.

In `docs/03-install-and-distribution.md`, in the `keel profile` paragraph that ends
`` `keel_version` and `schema_version` are refused too: `init` owns both. ``, append, wrapped at
100 columns:

```markdown
A value outside the enum the profile schema declares for that key is refused as well, and the
refusal names the values it accepts. `null` still clears one.
```

Run the lint command from the global constraints. Expected: exit 0.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS, the five new lines and the pre-push case above included.

- [x] **Step 5: Run the suite at the unit boundary, then hand over**

Add under `## Unreleased` in `CHANGELOG.md` (creating the heading as the global constraints say):

```markdown
- `keel profile set` refuses a value the profile schema's enum does not list, and names the
  values it accepts. A gate set to a typo was written and then read as a weaker gate.
```

Run: `tests/validate-citations.sh`, and repair any citation it reports.
Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.

```bash
git add bin/keel tests/test-keel.sh docs/03-install-and-distribution.md CHANGELOG.md
git status --porcelain
```

Add to that list any file whose citation you repaired. Stage exactly those paths and stop. **Do
not commit.** The coordinator commits after both review passes, with
`git commit -m "fix(profile): refuse a value outside the schema enum"`.

---

### Task 2: `doctor` fails a profile value outside the schema's enum

> **Execution note (2026-09-25):** delegated. Steps 2 and 4 witnessed in the implementer's report:
> `FAIL  doctor enum: no FAIL for gates.security_audit:` with 615 passed, 1 failed, then 616 passed,
> 0 failed including the python3 budget case at 10; lint exit 0; `tests/run-tests.sh` All test files
> passed. **One edit beyond the step text, accepted in spec review as required by the documentation
> constraint:** `docs/03-install-and-distribution.md` said "The last three above are advisory",
> which the new bullet would have made include a FAIL check, so it now names the `schema_version`
> check and the last two. Spec review COMPLIES; quality review found nothing blocking. The repair of
> `docs/audits/2026-09-01-security.md` is **unresolved**: its sentence describes a `keel verify`
> command that no longer exists, and it now cites the pre-commit guard's `eval "$cmd"`, the nearest
> line doing that work. The quality review also found six citations in
> `docs/audits/2026-09-25-standards.md`, correct when written at `fe7dcb1`, that tasks 1 and 2 had
> shifted onto the wrong line; a follow-up dispatch converted them to phrase form in this commit.
> That audit's path-less shorthand citations (`:1421`, `:1615`, and four of the eight in its
> `:288,...` list) are stale too, but the validator does not read that form and they were left.
> Should-fix findings not taken, since both are this task's step text: every finding's message says
> "for a gate that means a weaker one" even for keys outside `gates.`, and the comment and doc say
> every hook reads a typo as weaker, though no hook reads `gates.security_audit`; and a missing or
> unreadable schema exits the check silently, leaving only `ok profile parses`. Considered: a stderr
> warning such as `ResourceWarning` is read as a parse error and drops the enum findings; `%r`
> prints Python spelling (`True`, `['warn']`) where task 1 prints the raw value; no test asserts
> doctor's exit status on an enum FAIL.
>
> **Follow-up B (2026-09-25), approved by the maintainer, committed separately:** both should-fix
> findings above are taken. The weaker-gate clause is appended only to keys under `gates.`; the
> comment and the docs/03 bullet say whatever reads a gate treats an unrecognised value as weaker,
> not every hook; an unreadable schema prints one `noschema|` line, which doctor shows as a WARN.
> Still one python3 start. Witnessed in the implementer's report: `FAIL  doctor enum: a non-gate
> key's FAIL claims a weaker gate` and `FAIL  doctor noschema: no WARN for an unreadable schema`
> with 622 passed, 2 failed, then 624 passed, 0 failed with the budget case at 10;
> `tests/run-tests.sh` All test files passed. Four citations the validator reported repaired to
> phrases, each confirmed by the review against its sentence. Review: spec COMPLIES, nothing
> blocking. Considered: the `profile set` comment (`bin/keel#typo in a gate was written`) still says
> every hook, outside this fix's scope; a schema that parses but is not an object aborts doctor as
> before; no case covers an invalid-JSON schema, checked by hand to warn.

**Story:** snapshot recommendation 1
**Files:**
- Modify: `bin/keel` (function `cmd_doctor_text`)
- Modify: `tests/test-keel.sh`
- Modify: `docs/03-install-and-distribution.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: `$HERE/templates/profile.schema.json`; doctor's local `fail` helper; the existing
  profile-parse call, which this task extends rather than adding a second python3 start
- Produces: one `FAIL` line per out-of-enum value, of the form
  `gates.security_audit is 'reqired', which is not one of required, warn, off. ...`

**Depends on:** task 1, which shares its files.

**Done when:** `tests/test-keel.sh` passes.

- [x] **Step 1: Write the failing test**

Insert above the same final `printf` line of `tests/test-keel.sh`:

```bash
# ---- doctor fails a value outside the schema's enum ---------------------------------------------
# profile set now refuses one, but a hand edit or an older keel can still write it, and doctor is
# where a project is told its profile means something other than it reads.
de="$(fixture node-ts)"
( cd "$de" && "$KEEL" init -y >/dev/null 2>&1 )
seed_standards "$de"
out="$( cd "$de" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"which is not one of"*) bad "doctor enum" "a fresh init profile was reported out of enum: $out" ;;
  *) ok "doctor reports no enum problem on a profile init wrote" ;;
esac
python3 - "$de/.keel/profile.json" <<'PY'
import json, sys
p = json.load(open(sys.argv[1]))
p["gates"]["security_audit"] = "reqired"
json.dump(p, open(sys.argv[1], "w"), indent=2)
PY
out="$( cd "$de" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"FAIL  gates.security_audit is 'reqired', which is not one of required, warn, off"*)
    ok "doctor fails a gate value outside the schema enum" ;;
  *) bad "doctor enum" "no FAIL for gates.security_audit: $(printf '%s\n' "$out" | grep -n security_audit)" ;;
esac
rm -rf "$de"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL on `doctor enum` with `no FAIL for gates.security_audit`. The fresh-profile line
passes.

- [x] **Step 3: Write the minimal implementation**

In `bin/keel`, function `cmd_doctor_text`, the profile-parse check starts python3 once, and doctor
is at its budget of 10 starts. A second call for the enum check makes it 11 and turns the budget
case red, which the dry run found. So the enum check goes inside the call that already exists.
Replace:

```bash
        local profile_err
        profile_err="$(python3 -c "import json;json.load(open('.keel/profile.json'))" 2>&1 >/dev/null)"
        if [ -z "$profile_err" ]; then
            good "profile parses"
        else
```

with:

```bash
        local profile_out profile_err enum_line
        # One interpreter start parses the profile and checks its enum values against the schema,
        # because doctor's python3 starts are budgeted ("keel doctor starts python3 at most 10
        # times" in tests/test-keel.sh). Enum findings come back on stdout prefixed enum|, and
        # anything else is the parse error. An out-of-enum value is a FAIL and not a WARN: a gate
        # holding a typo is read as a weaker gate by every hook (hooks/done-guard treats it as
        # warn), so the file reads as configured while enforcing less.
        profile_out="$(python3 - "$HERE/templates/profile.schema.json" 2>&1 <<'PY'
import json, sys
prof = json.load(open(".keel/profile.json"))
try:
    schema = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
def walk(s, p, path):
    for k, sub in (s.get("properties") or {}).items():
        if not isinstance(p, dict) or k not in p or not isinstance(sub, dict):
            continue
        v, here = p[k], path + [k]
        if "enum" in sub and v is not None and v not in sub["enum"]:
            print("enum|%s is %r, which is not one of %s. keel does not recognise it, and for a "
                  "gate that means a weaker one. Fix it with: keel profile set %s <value>"
                  % (".".join(here), v, ", ".join(str(e) for e in sub["enum"]), ".".join(here)))
        if isinstance(v, dict):
            walk(sub, v, here)
walk(schema, prof, [])
PY
)"
        profile_err="$(printf '%s\n' "$profile_out" | grep -v '^enum|' || true)"
        if [ -z "$profile_err" ]; then
            good "profile parses"
            while IFS= read -r enum_line; do
                case "$enum_line" in enum\|*) fail "${enum_line#enum|}" ;; esac
            done <<< "$profile_out"
        else
```

The `else` branch that follows is unchanged. A JSON error still reaches it with `JSONDecodeError`
in `profile_err`, because the parse runs first and its traceback is on the same captured output.

In `docs/03-install-and-distribution.md`, in the list under `The verification command. Checks
that:`, add this bullet directly after the one about `schema_version`:

```markdown
- every profile value the schema constrains to an enum holds one of its values. A gate holding a
  typo fails, because every hook reads it as a weaker gate
```

Run the lint command. Expected: exit 0.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS, including `keel doctor starts python3 at most 10 times`.

- [x] **Step 5: Run the suite at the unit boundary, then hand over**

Add under `## Unreleased` in `CHANGELOG.md`:

```markdown
- `keel doctor` fails any profile value outside the schema's enum, naming the key and the values
  it accepts. Nothing checked them before.
```

Run: `tests/validate-citations.sh`, and repair any citation it reports.
Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.

```bash
git add bin/keel tests/test-keel.sh docs/03-install-and-distribution.md CHANGELOG.md
git status --porcelain
```

Add any file whose citation you repaired. Stage exactly those paths and stop. **Do not commit.**
The coordinator commits with
`git commit -m "fix(doctor): fail a profile value outside the schema enum"`.

---

### Task 3: generated CI runs on the default branch the profile records

> **Execution note (2026-09-25):** delegated. The first dispatch hit an API rate limit after step 1;
> its one uncommitted edit was discarded and the task re-dispatched from a clean tree. Steps 2 and 4
> witnessed in the second implementer's report:
> `FAIL  write_ci branch: workflow trigger: 5:    branches: [main]` with 616 passed, 1 failed, then
> 617 passed, 0 failed; `tests/test-profile-keys.sh` 12 passed; lint exit 0; `tests/run-tests.sh`
> All test files passed. Nine citations repaired. **Unresolved:**
> `docs/ideas/windows-python3-detection-is-wrong.md` now cites `bin/keel#if ! python3 -c 'pass'`
> beside wording that still says `if ! command -v python3`, which no line does any more. Spec review
> COMPLIES; quality review found nothing blocking. **Should fix, not taken because it changes this
> task's step text, raised with the maintainer:** with no python3, `json_get` returns empty and the
> workflow falls back to `main` while `write_profile` (which uses printf) still records `master`, so
> the CHANGELOG line is false there; `"${branch:-$(default_branch)}"` would fix it. Considered: a
> branch name containing `,`, `]`, `{` or a leading `!` breaks or changes the YAML flow sequence;
> `docs/snapshot.md` still says `write_ci` hardcodes main;
> `docs/plans/2026-09-21-coding-standards-enforcement.md` still lists the now-repaired line 490
> citation as left untouched; `x-keel-read-by` for `conventions.default_branch` names only the push
> guard.
>
> **Follow-up A (2026-09-25), approved by the maintainer, committed separately:** the should-fix
> above is taken. `write_ci` falls back to `$(default_branch)`, and a new case runs init on a
> `master` repository behind the suite's Store-alias python3 shim. Witnessed in the implementer's
> report: `FAIL  write_ci branch: workflow trigger without python3: 5:    branches: [main]` with
> 619 passed, 1 failed, then 620 passed, 0 failed; `tests/run-tests.sh` All test files passed.
> Nine citations shifted by the two added lines repaired to phrases; the review found one pointing
> one line past its subject (`CHANGELOG.md`, `project.kind`'s read), repointed by the coordinator
> to `bin/keel#echo service`. Review: spec COMPLIES. Considered: the fallback matches the profile
> because `merge_profile` without python3 replaces the whole profile, so a python-free read like
> the push guard's sed would not depend on that.

**Story:** snapshot recommendation 2
**Files:**
- Modify: `bin/keel` (function `write_ci`)
- Modify: `tests/test-keel.sh`
- Modify: `templates/profile.schema.json` (description of `conventions.default_branch`)
- Modify: `docs/profile-keys.md` (regenerated)
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: `conventions.default_branch`, which `write_profile` already writes from
  `default_branch()`
- Produces: `branches: [<default_branch>]` in the generated workflow, `main` when the key is empty

**Depends on:** task 2, which shares `bin/keel` and `tests/test-keel.sh`.

**Done when:** `tests/test-keel.sh` passes.

- [x] **Step 1: Write the failing test**

Insert above the final `printf` line of `tests/test-keel.sh`:

```bash
# ---- generated CI triggers on the recorded default branch ---------------------------------------
# write_ci hardcoded `branches: [main]`, so a master repository got a workflow that never ran on a
# push to its own default branch, while the profile beside it said master.
mb="$(mktemp -d)"
( cd "$mb" && git init -q -b master . && git config user.email t@t.t && git config user.name t \
  && printf '{"name":"f","scripts":{"test":"jest"}}\n' > package.json \
  && git add package.json && git commit -qm init && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(prof_of "$mb" conventions.default_branch)" = master ] \
  || bad "write_ci branch" "fixture precondition: profile did not record master"
grep -q 'branches: \[master\]' "$mb/.github/workflows/ci.yml" \
  && ok "generated CI runs on the default branch the profile records" \
  || bad "write_ci branch" "workflow trigger: $(grep -n 'branches' "$mb/.github/workflows/ci.yml")"
rm -rf "$mb"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL on `write_ci branch` with `workflow trigger: 5:    branches: [main]`.

- [x] **Step 3: Write the minimal implementation**

In `bin/keel`, function `write_ci`, directly below the line
`local test_cmd; test_cmd="$(json_get .keel/profile.json verify.test || true)"`, add:

```bash
    # The trigger branch is the profile's, not an assumption. Hardcoding main meant a master
    # repository's CI never ran on a push to its default branch.
    local branch; branch="$(json_get .keel/profile.json conventions.default_branch || true)"
```

and replace:

```bash
      printf 'name: CI\n\non:\n  push:\n    branches: [main]\n  pull_request:\n\njobs:\n'
```

with:

```bash
      printf 'name: CI\n\non:\n  push:\n    branches: [%s]\n  pull_request:\n\njobs:\n' "${branch:-main}"
```

In `templates/profile.schema.json`, change the description of `conventions.default_branch` from:

```
The repository's default branch, which is frequently not the checked-out one. Skills refuse to implement here and repo-snapshot compares HEAD against it.
```

to:

```
The repository's default branch, which is frequently not the checked-out one. Skills refuse to implement here, repo-snapshot compares HEAD against it, and the CI workflow keel init generates runs on pushes to it.
```

Run: `tests/generate-profile-keys.sh > docs/profile-keys.md`
Run the lint command. Expected: exit 0.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS.
Run: `tests/test-profile-keys.sh`
Expected: PASS.

- [x] **Step 5: Run the suite at the unit boundary, then hand over**

Add under `## Unreleased` in `CHANGELOG.md`:

```markdown
- The CI workflow `keel init` generates runs on pushes to `conventions.default_branch`, not to a
  hardcoded `main`. It applies where init writes a workflow, which it does only when no CI is
  declared yet; a `master` repository initialised earlier keeps `branches: [main]` in its
  `.github/workflows/ci.yml` until someone edits it.
```

Run: `tests/validate-citations.sh`, and repair any citation it reports.
Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.

```bash
git add bin/keel tests/test-keel.sh templates/profile.schema.json docs/profile-keys.md CHANGELOG.md
git status --porcelain
```

Add any file whose citation you repaired. Stage exactly those paths and stop. **Do not commit.**
The coordinator commits with
`git commit -m "fix(init): generated CI runs on the recorded default branch"`.

---

### Task 4: `doctor` says when the push guard is not installed

> **Execution note (2026-09-25):** delegated. The implementer was dispatched by an earlier session
> of this run, which was then stopped while paused on a question; this session took over with the
> work staged. Step 2 witnessed in the implementer's report: `FAIL  doctor guard: no guard warning
> without an install` and `FAIL  doctor guard: no ok line after guard install`, 617 passed, 2
> failed. Step 4: both new cases pass, 618 passed, 1 failed, the one red the step names (`doctor
> output unchanged against HEAD`, diff exactly the new WARN line); step 4's "four new guard lines"
> is two cases in step 1's block. `tests/test-profile-keys.sh` 12 passed; lint exit 0;
> `tests/validate-citations.sh` OK, 1639 citations; `tests/run-tests.sh` exit 1 on that same red
> only, confirmed independently by the quality review in a throwaway worktree. No citation
> repaired: the 29 `bin/keel:N` citations at or after the insertion were already stale at HEAD.
> Spec review COMPLIES. Quality review, nothing blocking; should fix: doctor tests the key `= true`
> through `json_get` while the pre-push hook protects on anything but `false` through sed, so an
> absent key, a non-boolean value or a missing python3 leaves doctor silent while the hook still
> refuses; and the new test does not pin the key condition (deleting it keeps both cases green).
> Consider: a subproject inside a larger repository gets a false ok (inherited from `cmd_guard
> status`); in docs/03 the new sentence sits before "That is tested." and reads as tested;
> `docs/snapshot.md` still says doctor does not report the guard. Carried to the follow-up below
> and the final report.
>
> **Follow-up C (2026-09-25), approved by the maintainer, committed separately:** both should-fix
> findings are taken, and the docs/03 sentence order with them. Doctor reads the key with the
> hook's own sed and tests `!= false`, so an absent key, a non-boolean value or a missing python3
> warns wherever the hook refuses; the WARN now says "is not false". Tests added for `false` (no
> line), the key absent (warns) and the string `"false"` (warns, the case that pins the sed read
> over `json_get`). Witnessed in the implementer's report: `FAIL  doctor guard: no guard warning
> with the key absent` against the committed code; the `false` case red against a copy without
> the key condition and the string case red against a `json_get` read; then 626 passed, 1 failed,
> the one red `doctor output unchanged against HEAD` with exactly the reworded WARN as its diff.
> "That is tested." now sits before the push-guard sentence in docs/03. Review: spec COMPLIES,
> the string case added on its should-fix. Considered: a hand-edited `" : false"` reads as not
> false in both hook and doctor; doctor does not check the hook can resolve a default branch.
> **Task 7's step 1 quotes the old wording**; the warning it expects now reads
> `conventions.protect_default_branch is not false and the push guard is not installed`.

**Story:** snapshot recommendation 4
**Files:**
- Modify: `bin/keel` (function `cmd_doctor_text`)
- Modify: `tests/test-keel.sh`
- Modify: `templates/profile.schema.json` (description of `conventions.protect_default_branch`)
- Modify: `docs/profile-keys.md` (regenerated)
- Modify: `docs/03-install-and-distribution.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: `GUARD_DIR` (`.githooks`, a global in `bin/keel`), and the same install test
  `cmd_guard status` uses: `core.hooksPath` equals `GUARD_DIR` and `GUARD_DIR/pre-push` is
  executable; `json_get`, which answers from the cache and starts no interpreter
- Produces: a `WARN` when `conventions.protect_default_branch` is `true` in a git repository and
  the guard is not installed; an `ok` line when it is. A WARN, not a FAIL: installing it changes
  the developer's git configuration and stays their choice (docs/03-install-and-distribution.md,
  "Opt-in, because it changes your git configuration").

**Depends on:** task 3, which shares `bin/keel`, `tests/test-keel.sh` and the schema.

**Done when:** `tests/test-keel.sh` passes after the coordinator's commit, see step 5.

- [x] **Step 1: Write the failing test**

Insert above the final `printf` line of `tests/test-keel.sh`:

```bash
# ---- doctor reports whether the push guard is installed ------------------------------------------
# protect_default_branch is true by default and only the push guard enforces it outside a session,
# and init does not install the guard. Nothing said so until this line.
pg="$(fixture node-ts)"
( cd "$pg" && "$KEEL" init -y >/dev/null 2>&1 )
seed_standards "$pg"
out="$( cd "$pg" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"WARN  conventions.protect_default_branch is true and the push guard is not installed"*)
    ok "doctor warns when the push guard is not installed" ;;
  *) bad "doctor guard" "no guard warning without an install: $(printf '%s\n' "$out" | grep -in guard)" ;;
esac
( cd "$pg" && "$KEEL" guard install >/dev/null 2>&1 )
out="$( cd "$pg" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"ok    push guard installed"*) ok "doctor reports an installed push guard as ok" ;;
  *) bad "doctor guard" "no ok line after guard install: $(printf '%s\n' "$out" | grep -in guard)" ;;
esac
rm -rf "$pg"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL on `doctor guard` twice, `no guard warning without an install` and `no ok line
after guard install`.

- [x] **Step 3: Write the minimal implementation**

In `bin/keel`, function `cmd_doctor_text`, directly below the `if [ "$cs" = required ]; then ...
fi` block that checks `gates.coding_standards`, add:

```bash
    # The push guard is the only thing that enforces protect_default_branch outside a session, and
    # init does not install it, so without this line nothing tells anyone it is off. A WARN, not a
    # FAIL: installing it changes the developer's git configuration, which stays their choice.
    if [ "$(json_get .keel/profile.json conventions.protect_default_branch 2>/dev/null || true)" = true ] \
       && git rev-parse --git-dir >/dev/null 2>&1; then
        local ghp; ghp="$(git config core.hooksPath 2>/dev/null || true)"
        if [ "$ghp" = "$GUARD_DIR" ] && [ -x "$GUARD_DIR/pre-push" ]; then
            good "push guard installed: a push to the default branch is refused outside a session too"
        else
            warn "conventions.protect_default_branch is true and the push guard is not installed, so nothing outside a session enforces it. Run: keel guard install"
        fi
    fi
```

In `templates/profile.schema.json`, append this sentence to the description of
`conventions.protect_default_branch`:

```
keel doctor warns when this is true and the guard is not installed.
```

Run: `tests/generate-profile-keys.sh > docs/profile-keys.md`

In `docs/03-install-and-distribution.md`, make three edits, each wrapped at 100 columns:

1. At the end of the paragraph that begins `Installs three hooks, by writing`, add:

   ```markdown
   `keel doctor` warns while `conventions.protect_default_branch` is true and the guard is not
   installed, because nothing else outside a session enforces that key.
   ```

2. In the list under `The verification command. Checks that:`, add after the enum bullet task 2
   added:

   ```markdown
   - the push guard is installed, where `conventions.protect_default_branch` is true. A warning,
     since installing it changes the developer's git configuration
   ```

3. In the paragraph that begins `**The property that matters: doctor's only complaint on a fresh
   project`, replace the bold sentence
   `**The property that matters: doctor's only complaint on a fresh project is the one thing `new`
   told it about, and nothing else.**` with:

   ```markdown
   **The property that matters: doctor's only failure on a fresh project is the one thing `new`
   told it about, and nothing else.** It also warns that the push guard is not installed, which
   `keel guard install` clears.
   ```

   The test behind that paragraph counts FAIL lines only, so it stays green while the paragraph
   goes stale. It is the case
   `` tests/test-keel.sh#and that is the only FAIL a fresh project has ``.

Run the lint command. Expected: exit 0.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: the four new guard lines pass, and one existing case is red on purpose:
`doctor output unchanged against HEAD`. It compares doctor's output with the committed `bin/keel`,
so while this change is uncommitted its diff is exactly the new line
`WARN  conventions.protect_default_branch is true and the push guard is not installed ...`. Its
comment in `tests/test-keel.sh` records that it is red for the whole of a task that changes
doctor's output and green once that task is committed. Any other red is a finding.
Run: `tests/test-profile-keys.sh`
Expected: PASS.

- [x] **Step 5: Run the suite at the unit boundary, then hand over**

Add under `## Unreleased` in `CHANGELOG.md`:

```markdown
- `keel doctor` warns when `conventions.protect_default_branch` is true and `keel guard install`
  has not been run, and says ok once it has. The guard was opt-in and nothing reported it off.
```

Run: `tests/validate-citations.sh`, and repair any citation it reports.
Run: `tests/run-tests.sh`
Expected: the one red named in step 4 and no other. Report it with its diff. The coordinator
commits, then re-runs `tests/test-keel.sh` and confirms `doctor output unchanged against HEAD` is
green; that run is this task's `Done when`.

```bash
git add bin/keel tests/test-keel.sh templates/profile.schema.json docs/profile-keys.md \
        docs/03-install-and-distribution.md CHANGELOG.md
git status --porcelain
```

Add any file whose citation you repaired. Stage exactly those paths and stop. **Do not commit.**
The coordinator commits with
`git commit -m "feat(doctor): warn when the push guard is not installed"`.

---

### Task 5: the message hook honours `conventions.no_attribution_footers`

> **Execution note (2026-09-26):** delegated. Step 2 witnessed in the implementer's report: `FAIL
> no footers: the trailer was added although no_attribution_footers is true` with 627 passed, 1
> failed (and `doctor output unchanged against HEAD` green, confirming follow-up C). Step 4: 628
> passed, 0 failed, with the four named cases; `tests/validate-skills.sh` OK with no fingerprint
> finding (the plan's `ebcd5f8fba88` held); `tests/test-doc-claims.sh` 64 passed;
> `.keel/profile.json | 2 +-`; lint exit 0; `tests/run-tests.sh` All test files passed. Twelve
> citations shifted by the `tests/validate-skills.sh` and `tests/test-doc-claims.sh` insertions
> repaired to phrases, two renumbered. **Unresolved:**
> `docs/plans/2026-09-19-make-keel-enforceable-outside-the-agent.md` cites
> `tests/validate-skills.sh#Em and en`, the comment stating the docs em-dash rule, because the
> check line itself occurs twice. Spec review COMPLIES. Quality review, nothing blocking; three
> should-fix items taken before the commit, beyond the step text: the test now also asserts
> `core.hooksPath` is `.githooks` and the commit happened (witnessed red against 433ee9b's hook,
> green against this one), since without them it passed with no hook run; one renumbered
> citation that kept its old line's target was pointed at the ship row it describes; and the
> CHANGELOG entry and docs/03 say a hook installed earlier needs `keel guard install` re-run. The
> fourth, `keel guard status` still saying commits get a trailer when the key is true, is
> follow-up D below, approved by the maintainer. Considered: the bump makes every doctor ask for a
> `keel init` that writes no new field; `keel profile set` writes the string `"yes"` to this
> boolean key, since task 1 checks enums, not types; a same-named key before `conventions` would
> also match the sed, as with `protect_default_branch`.
>
> **Follow-up D (2026-09-26), approved by the maintainer, committed separately:** `keel guard
> status` reads the key with the hook's sed and says `adds no trailer` when it is true, or, when
> the installed hook predates the key (no `no_attribution_footers` in its body), that commits
> still get the trailer and `keel guard install` must be re-run. Witnessed in the implementer's
> report: both new cases red at 629 passed, 2 failed, then 631 passed, 0 failed;
> `tests/run-tests.sh` All test files passed. Two `CHANGELOG.md` line citations the one-line
> shift moved, both already wrong at HEAD, pointed at the lines their sentences quote, confirmed
> by the review. Review: spec COMPLIES, nothing blocking. Considered: a precondition comment in
> the new block overstates what a missing hook does; the unchanged line is also false where the
> hook exits early for a missing profile or `keel_version`.

**Story:** maintainer decision of 2026-09-25. `keel guard install` writes a prepare-commit-msg
hook that appends `Keel-Version: <version>` to every commit, and nothing lets a repository whose
commits carry a title and body only switch it off. keel's own profile already sets
`conventions.no_attribution_footers: true`, and no code reads it.
**Files:**
- Modify: `bin/keel` (function `guard_prepare_commit_msg_body`, and the `SCHEMA_VERSION` constant)
- Modify: `templates/profile.schema.json` (a new key, `conventions.no_attribution_footers`)
- Modify: `docs/profile-keys.md` (regenerated)
- Modify: `tests/test-keel.sh`
- Modify: `tests/validate-skills.sh` (function `schema_fingerprint_for`)
- Modify: `tests/test-doc-claims.sh` (the `SCHEMA_VERSION` pin)
- Modify: `.keel/profile.json` (its `schema_version`)
- Modify: `docs/03-install-and-distribution.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: `.keel/profile.json`, read with `sed` as the hook already reads `keel_version`, because
  a git hook cannot count on python3
- Produces: the hook exits before adding the trailer when `conventions.no_attribution_footers` is
  `true`. The key is optional and human-set: `keel init` does not write it, and `keel profile set`
  still refuses it on a profile that lacks it, as it refuses any absent path.
- Changes: `SCHEMA_VERSION` 4 to 5, because `bin/keel` says to bump it "only when a field is added,
  removed, renamed or moved", and this adds one. Every project's `doctor` then warns once that its
  profile is at 4 until `keel init` is re-run, which is the cost that rule accepts.

**Depends on:** task 4, which shares `bin/keel`, `tests/test-keel.sh` and the schema.

**Done when:** `tests/test-keel.sh` passes.

- [x] **Step 1: Write the failing test**

Insert above the final `printf` line of `tests/test-keel.sh`:

```bash
# ---- the message hook honours conventions.no_attribution_footers ---------------------------------
# A trailer is a footer, and a repository that declares it wants none gets none.
nf="$(fixture bare)"
( cd "$nf" && "$KEEL" init -y >/dev/null 2>&1 && "$KEEL" guard install >/dev/null 2>&1 )
# Without the hook the case below passes over nothing, so its absence is a failure of its own.
[ -x "$nf/.githooks/prepare-commit-msg" ] \
  || bad "no footers" "fixture precondition: guard install wrote no prepare-commit-msg hook"
python3 - "$nf/.keel/profile.json" <<'PY'
import json, sys
p = json.load(open(sys.argv[1]))
p["conventions"]["no_attribution_footers"] = True
json.dump(p, open(sys.argv[1], "w"), indent=2)
PY
( cd "$nf" && git add -A && git commit -q -m "no footer wanted" )
msg="$( cd "$nf" && git log -1 --format=%B )"
case "$msg" in
  *Keel-Version*) bad "no footers" "the trailer was added although no_attribution_footers is true: $msg" ;;
  *) ok "the message hook adds no trailer when conventions.no_attribution_footers is true" ;;
esac
rm -rf "$nf"
```

The existing case `commit message carries the Keel-Version trailer` stays as it is: it proves the
trailer is still added when the key is absent.

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL on `no footers`, `the trailer was added although no_attribution_footers is true`.

- [x] **Step 3: Write the minimal implementation**

In `bin/keel`, function `guard_prepare_commit_msg_body`, directly below the hook line
`[ -f .keel/profile.json ] || exit 0`, add:

```bash
# conventions.no_attribution_footers true means this repository's commit messages are a title and a
# body and nothing else, and a trailer is a footer. Read with sed, like keel_version below, because
# a git hook cannot count on python3.
footers="$(sed -n 's/.*"no_attribution_footers": *\([a-z]*\).*/\1/p' .keel/profile.json 2>/dev/null | head -1)"
[ "$footers" = true ] && exit 0
```

Change `SCHEMA_VERSION=4` to `SCHEMA_VERSION=5`.

Declare the key. `templates/profile.schema.json` round-trips through `json.dump` byte for byte, so
edit it with:

```bash
python3 - <<'PY'
import json
p = "templates/profile.schema.json"
s = json.load(open(p))
s["properties"]["conventions"]["properties"]["no_attribution_footers"] = {
    "type": "boolean",
    "default": False,
    "description": "true means this repository's commit messages carry a title and a body only. The prepare-commit-msg hook `keel guard install` writes then adds no Keel-Version trailer. Set by hand; keel init does not write it.",
    "x-keel-read-by": "code:bin/keel#footers=\"$(sed -n",
}
f = open(p, "w"); json.dump(s, f, indent=2, ensure_ascii=False); f.write("\n"); f.close()
PY
tests/generate-profile-keys.sh > docs/profile-keys.md
```

In `tests/validate-skills.sh`, function `schema_fingerprint_for`, add a line below
`4) printf 'd5159ecbff0b' ;;`:

```bash
        5) printf 'ebcd5f8fba88' ;;
```

That value is the fingerprint of the field set after this task, measured in the dry run. If
`tests/validate-skills.sh` reports a different one, the field set differs from the plan's, which is
a finding to report rather than a value to paste.

In `tests/test-doc-claims.sh`, replace:

```bash
if [ "$sv" = "4" ]; then
    ok "SCHEMA_VERSION is where the retired-keys plan left it ($sv)"
else
    bad "SCHEMA_VERSION is where the retired-keys plan left it" \
        "bin/keel is at $sv, expected 4. docs/plans/2026-09-07-declared-profile-keys-take-effect.md was the last plan to move it, by retiring the six keys nothing could honour. A further bump is either a change riding along or one that needs its own story, its own schema row and its own fingerprint line in tests/validate-skills.sh"
fi
```

with:

```bash
# 5 since 2026-09-25, when docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md
# task 5 declared conventions.no_attribution_footers, the key the message hook now honours.
if [ "$sv" = "5" ]; then
    ok "SCHEMA_VERSION is where the no-footers task left it ($sv)"
else
    bad "SCHEMA_VERSION is where the no-footers task left it" \
        "bin/keel is at $sv, expected 5. docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md was the last plan to move it, by declaring conventions.no_attribution_footers. A further bump is either a change riding along or one that needs its own story, its own schema row and its own fingerprint line in tests/validate-skills.sh"
fi
```

In `tests/test-keel.sh`, replace:

```bash
[ "$sv" = "4" ] && ok "init writes schema version 4" \
  || bad "init writes schema version 4" "got $sv"
```

with:

```bash
[ "$sv" = "5" ] && ok "init writes schema version 5" \
  || bad "init writes schema version 5" "got $sv"
```

and, in the case `a schema 2 profile upgrades to claude only`, replace:

```bash
[ "$got" = '4 ["claude"]' ] && ok "a schema 2 profile upgrades to claude only" \
```

with:

```bash
[ "$got" = '5 ["claude"]' ] && ok "a schema 2 profile upgrades to claude only" \
```

The dry run found that one: an upgrade lands on the current schema version, now 5.

keel's own profile must move with it: the case `dogfood profile` in `tests/test-doc-claims.sh`
fails when this repository's `schema_version` differs from `bin/keel`'s, which the dry run hit.
`keel profile set` refuses `schema_version`, and the file round-trips through `json.dump`
unchanged, so:

```bash
python3 -c 'import json; p = json.load(open(".keel/profile.json")); p["schema_version"] = 5; f = open(".keel/profile.json", "w"); json.dump(p, f, indent=2); f.write("\n")'
git diff --stat .keel/profile.json
```

Expected: `.keel/profile.json | 2 +-`.

In `docs/03-install-and-distribution.md`, at the end of the paragraph that begins
`The prepare-commit-msg hook appends a`, add, wrapped at 100 columns:

```markdown
A repository whose commit messages carry a title and body only sets
`conventions.no_attribution_footers` to `true` in its profile, and the hook then adds nothing.
```

Run the lint command. Expected: exit 0.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS. The new `no footers` line passes, and so do `init writes schema version 5`,
`a schema 2 profile upgrades to claude only` and `commit message carries the Keel-Version
trailer`. `doctor output unchanged against HEAD` stays green: it normalises the schema version
number, and nothing else doctor prints changes in this task.
Run: `tests/validate-skills.sh`
Expected: PASS, with no fingerprint finding.
Run: `tests/test-doc-claims.sh`
Expected: PASS, including `SCHEMA_VERSION is where the no-footers task left it (5)` and the
`dogfood profile` cases.

- [x] **Step 5: Run the suite at the unit boundary, then hand over**

Add under `## Unreleased` in `CHANGELOG.md`:

```markdown
- The prepare-commit-msg hook from `keel guard install` adds no `Keel-Version` trailer where the
  profile sets `conventions.no_attribution_footers` to `true`, a key the schema now declares.
  Profile schema version 5: `keel doctor` asks each project to re-run `keel init` once.
```

Run: `tests/validate-citations.sh`, and repair any citation it reports.
Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.

```bash
git add bin/keel templates/profile.schema.json docs/profile-keys.md tests/test-keel.sh \
        tests/validate-skills.sh tests/test-doc-claims.sh .keel/profile.json \
        docs/03-install-and-distribution.md CHANGELOG.md
git status --porcelain
```

Add any file whose citation you repaired. Stage exactly those paths and stop. **Do not commit.**
The coordinator commits with
`git commit -m "feat(guard): the message hook honours conventions.no_attribution_footers"`.

---

### Task 6: detect `verify.security` from the lockfile, and run it in full `doctor`

> **Execution note (2026-09-26):** delegated. Step 2 witnessed in the implementer's report: 634
> passed, 5 failed, the four `verify.security` FAILs the step names plus `full doctor runs
> verify.security: no sentinel`, with the two named cases and two sentinel siblings passing.
> Step 4: 639 passed, 0 failed; `tests/test-profile-keys.sh` 12 passed. **Step 4's predicted red
> did not happen:** `doctor output unchanged against HEAD` stayed green because its fixture is an
> empty directory, `project.kind` `docs`, which skips the whole verify block; the spec review
> confirmed it. So no test pins full-mode doctor output on a real project. Spec review COMPLIES.
> Quality review, **one blocking item fixed before the commit, beyond the step text:** any
> `yarn.lock` produced `yarn npm audit`, which exists only on yarn 2+, so on yarn 1 full doctor
> failed and a hand-set null came back on the next init; detection now requires `__metadata:` in
> `yarn.lock`, with cases for both lockfile kinds, and the doctor message, schema description,
> docs/03 and CHANGELOG say yarn 2+. Should-fix items also taken: `write_ci` drops its audit step
> only when `verify.security` is that same audit (`[ "$sec" != "$audit" ]`, with a case), so a
> different scanner no longer removes the dependency audit; docs/03 and the CHANGELOG say full
> doctor fails offline or on a high advisory; test comments the change made wrong reworded; the
> fleet-view idea's citations point at doctor's own reads. A focused re-review of the fixes found
> nothing blocking. Final `tests/test-keel.sh` 642 passed, 0 failed; `tests/run-tests.sh` All test
> files passed (before the last wording fix, which moved no line). Citations the edits shifted
> repaired, about twenty, several already stale at HEAD and moved further; the `project.kind`
> reader row in the 2026-09-07 plan repointed by the coordinator to `bin/keel#echo service`, the
> read. **Unresolved:** the 2026-09-07 plan's sentence about the declared-only loop now cites the
> e2e line that replaced it. Not taken, for the final report: `write_ci`'s own yarn mapping still
> writes `yarn npm audit` for a yarn 1 project (pre-existing); `docs/snapshot.md` says
> `verify.security` is never detected, left for a correction sweep with the earlier tasks' claims.

**Story:** maintainer decision of 2026-09-25. `write_ci` already maps a JavaScript package manager
to an audit command, but never records it as `verify.security`, so `doctor` and `ship` never see
one, while `init` writes `gates.security_audit: required`.
**Files:**
- Modify: `lib/detect-stack.sh` (function `detect_verify`)
- Modify: `bin/keel` (functions `write_ci` and `cmd_doctor_text`)
- Modify: `tests/test-keel.sh`, including the existing sentinel case that asserts full doctor never
  runs `verify.security`, which this task makes false on purpose
- Modify: `templates/profile.schema.json` (the `verify.security` and `verify.e2e` entries)
- Modify: `docs/profile-keys.md` (regenerated)
- Modify: `docs/03-install-and-distribution.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: `detect_js_pm`, which names a manager only when exactly one lockfile is present and
  otherwise prints `npm` with no lockfile, or nothing when several conflict
- Produces: `verify.security` of `npm audit --audit-level=high` with a `package-lock.json`,
  `pnpm audit --audit-level high` with a `pnpm-lock.yaml`, `yarn npm audit --severity high` with a
  `yarn.lock`, and `null` otherwise. The same three strings `write_ci` already writes. pip stays
  `null`: its audit command installs a package, and `doctor` executes verify commands.
- Changes: full `doctor` executes `verify.security` in the loop that runs test, lint, typecheck and
  build, so it reaches the network. `--fast` never executes a verify command and still does not. A
  null `verify.security` stays an `ok` line, never a warning, because most stacks have no detector.
  `write_ci` writes no separate `Audit dependencies` step when `verify.security` is set, since the
  verify loop already writes a `security` step running the same command.

**Depends on:** task 5, which shares `bin/keel`, `tests/test-keel.sh` and the schema.

**Done when:** `tests/test-keel.sh` passes after the coordinator's commit, see step 5.

- [x] **Step 1: Write the failing test**

Insert above the final `printf` line of `tests/test-keel.sh`:

```bash
# ---- verify.security is detected from a JavaScript lockfile --------------------------------------
# write_ci mapped the package manager to an audit and never told the profile, so doctor and ship
# saw no security command on any project. Only with the lockfile the audit reads: npm audit exits
# non-zero without one.
sl="$(fixture node-ts)"; printf '{"lockfileVersion": 3}\n' > "$sl/package-lock.json"
( cd "$sl" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(verify_of "$sl" security)" = "npm audit --audit-level=high" ] \
  && ok "init detects verify.security from a package-lock.json" \
  || bad "verify.security" "got '$(verify_of "$sl" security)'"
grep -q 'name: security' "$sl/.github/workflows/ci.yml" \
  && ok "generated CI runs verify.security as its own step" \
  || bad "verify.security" "no security step in the generated workflow"
[ "$(grep -c 'npm audit --audit-level=high' "$sl/.github/workflows/ci.yml")" -eq 1 ] \
  && ok "generated CI runs the audit once, as the security step" \
  || bad "verify.security" "audit steps: $(grep -n 'audit' "$sl/.github/workflows/ci.yml" | tr '\n' ' ')"
seed_standards "$sl"
out="$( cd "$sl" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"ok    verify.security set (not run, --fast)"*) ok "doctor --fast names verify.security without running it" ;;
  *) bad "verify.security" "no --fast line: $(printf '%s\n' "$out" | grep -n 'verify.security')" ;;
esac
rm -rf "$sl"
sn="$(fixture node-ts)"
( cd "$sn" && "$KEEL" init -y >/dev/null 2>&1 )
[ -z "$(verify_of "$sn" security)" ] && ok "no lockfile means no verify.security" \
  || bad "verify.security" "detected '$(verify_of "$sn" security)' with no lockfile"
seed_standards "$sn"
out="$( cd "$sn" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"ok    verify.security is null: keel detects one only from an npm, pnpm or yarn lockfile"*)
    ok "a null verify.security is an ok line, not a warning" ;;
  *) bad "verify.security" "null line: $(printf '%s\n' "$out" | grep -n 'verify.security')" ;;
esac
rm -rf "$sn"
```

Then replace the existing sentinel case, which asserts the behaviour this task reverses. Replace:

```bash
# The same assertion without --fast, and this is the one with teeth. A review proved by mutation
# that the case above passes an implementation which runs the command but short-circuits on --fast:
# nothing asserted under --fast can see such a path, so the sentinel there catches only a loop that
# always runs. Plain doctor costs about a second on this fixture, measured 2026-09-08: npm test,
# lint, typecheck and build each fail immediately with no node_modules installed. Both keys carry a
# sentinel, because one loop serves both and a mutation running only the security branch would
# otherwise go unseen.
( cd "$we" && "$KEEL" profile set verify.security 'touch security-ran-sentinel' >/dev/null 2>&1 )
full="$( cd "$we" && "$KEEL" doctor 2>&1 )"
if [ -e "$we/e2e-ran-sentinel" ] || [ -e "$we/security-ran-sentinel" ]; then
  bad "doctor runs neither verify.e2e nor verify.security without --fast" "$full"
else
  ok "doctor runs neither verify.e2e nor verify.security without --fast"
fi
```

with:

```bash
# The same assertion without --fast, and this is the one with teeth. A review proved by mutation
# that the case above passes an implementation which runs the command but short-circuits on --fast:
# nothing asserted under --fast can see such a path. Plain doctor costs about a second on this
# fixture, measured 2026-09-08: npm test, lint, typecheck and build each fail immediately with no
# node_modules installed. e2e must never run. security runs in full doctor and only there, by
# decision on 2026-09-25, so it carries a sentinel under --fast and another without.
( cd "$we" && "$KEEL" profile set verify.security 'touch security-ran-sentinel' >/dev/null 2>&1 )
( cd "$we" && "$KEEL" doctor --fast >/dev/null 2>&1 )
[ -e "$we/security-ran-sentinel" ] \
  && bad "doctor --fast does not execute verify.security" "the sentinel file exists, so the command ran" \
  || ok "doctor --fast does not execute verify.security"
full="$( cd "$we" && "$KEEL" doctor 2>&1 )"
[ -e "$we/e2e-ran-sentinel" ] \
  && bad "doctor never runs verify.e2e, even without --fast" "$full" \
  || ok "doctor never runs verify.e2e, even without --fast"
[ -e "$we/security-ran-sentinel" ] \
  && ok "full doctor runs verify.security" \
  || bad "full doctor runs verify.security" "no sentinel, so the command never ran: $full"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL on `verify.security` four times: `got ''`, `no security step in the generated
workflow`, the `--fast` line and the null line. Two lines pass already and must stay passing:
`generated CI runs the audit once, as the security step`, which is the guard against writing the
audit twice once the security step exists, and `no lockfile means no verify.security`. In the
replaced sentinel case, `full doctor runs verify.security` fails with `no sentinel, so the command
never ran`, and its two siblings pass.

- [x] **Step 3: Write the minimal implementation**

In `lib/detect-stack.sh`, function `detect_verify`, in the `typescript|javascript` branch, directly
below the line `e2e) [ -n "$(pkg_script 'test:e2e')" ] && pkg_run 'test:e2e' ;;`, add:

```bash
          # A dependency audit, with the mapping write_ci uses, and only where the lockfile the
          # audit reads exists: npm audit exits non-zero with no package-lock.json, and detect_js_pm
          # prints npm when there is no lockfile at all. It names pnpm or yarn only from their own
          # lockfile, and nothing when two conflict.
          security)
            case "$(detect_js_pm)" in
              npm)  [ -f package-lock.json ] && printf 'npm audit --audit-level=high' ;;
              pnpm) printf 'pnpm audit --audit-level high' ;;
              yarn) printf 'yarn npm audit --severity high' ;;
            esac ;;
```

In `bin/keel`, function `write_ci`, directly below the `local branch; ...` line task 3 added, add:

```bash
    local sec; sec="$(json_get .keel/profile.json verify.security || true)"
```

and replace:

```bash
      [ -n "$audit" ] && printf '\n      - name: Audit dependencies\n        run: %s\n' "$audit"
```

with:

```bash
      # verify.security, where set, is already a step from the loop above, and a second audit of
      # the same lockfile would run twice and fail twice.
      [ -n "$audit" ] && [ -z "$sec" ] && printf '\n      - name: Audit dependencies\n        run: %s\n' "$audit"
```

In `bin/keel`, function `cmd_doctor_text`, replace:

```bash
        for k in test lint typecheck build; do
            local c; c="$(json_get .keel/profile.json "verify.$k" || true)"
            [ -z "$c" ] && { warn "verify.$k is null"; continue; }
```

with:

```bash
        # security runs here, in full doctor, by decision on 2026-09-25: it reaches the network,
        # and --fast, which never executes a verify command, is the offline form.
        for k in test lint typecheck build security; do
            local c; c="$(json_get .keel/profile.json "verify.$k" || true)"
            if [ -z "$c" ]; then
                # A null security is ok and not a warning. keel detects one only from an npm, pnpm
                # or yarn lockfile, so a warning would fire on every other project and no keel
                # command could clear it.
                if [ "$k" = security ]; then
                    good "verify.security is null: keel detects one only from an npm, pnpm or yarn lockfile, so set it if this project has another"
                else
                    warn "verify.$k is null"
                fi
                continue
            fi
```

Then, in the same function, replace the whole block that runs from the comment line
`# Declared and never run, which is the honest treatment for these two.` down to and including
the `done` that closes `for k in e2e security; do`, with straight-line code for e2e alone. A loop
over one item fails shellcheck (SC2043), which the dry run hit:

```bash
        # Declared and never run, which is the honest treatment for e2e: it needs a running system
        # by its own description, so running it here would make doctor cost what a deployment
        # costs. security was declared here too until 2026-09-25, when init began detecting it and
        # it moved to the loop above.
        #
        # null is `ok` and not a warning. e2e's detector fires only on a node `test:e2e` script, so
        # init writes null into effectively every profile. A warning here would fire on every
        # project keel has ever made, would be clearable by no keel command, and is the required
        # value on Dart per that stack's own FR-14. "does not detect", present tense, is a claim
        # about this project rather than about what keel can do.
        local dc; dc="$(json_get .keel/profile.json verify.e2e || true)"
        if [ -z "$dc" ]; then good "verify.e2e is null: keel does not detect one, so set it if this project has one"
        else good "verify.e2e is set (declared, not run): $dc"
        fi
```

Both e2e lines print exactly what they printed before.

Update the schema entry:

```bash
python3 - <<'PY'
import json
p = "templates/profile.schema.json"
s = json.load(open(p))
e = s["properties"]["verify"]["properties"]["security"]
e["description"] = "The command that runs a security scanner, such as a dependency audit. keel init detects one from a single npm, pnpm or yarn lockfile, and null is the ordinary value elsewhere. Run by full `keel doctor`, which then reaches the network; `keel doctor --fast` only checks that it is set. security-audit does its own reading either way."
e["x-keel-read-by"] = "code:bin/keel#for k in test lint typecheck build security; do"
# e2e's reader moved with the code above, from the shared loop to its own line.
s["properties"]["verify"]["properties"]["e2e"]["x-keel-read-by"] = "code:bin/keel#local dc; dc=\"$(json_get .keel/profile.json verify.e2e"
f = open(p, "w"); json.dump(s, f, indent=2, ensure_ascii=False); f.write("\n"); f.close()
PY
tests/generate-profile-keys.sh > docs/profile-keys.md
```

In `docs/03-install-and-distribution.md`, in the list under `The verification command. Checks
that:`, replace the first bullet's opening words
`- every command in `profile.verify` actually runs and exits 0` with
`- every command in `profile.verify` actually runs and exits 0, `verify.security` included, which
  reaches the network,` and leave the rest of that bullet as it is.

Run the lint command. Expected: exit 0.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: the six new lines and the three sentinel lines pass. `doctor output unchanged against
HEAD` is red on purpose while
uncommitted: the null-security line moved from the declared loop to the run loop and changed its
wording, so its diff shows the old `verify.security is null: keel does not detect one` line going
and the new one arriving. Any other red is a finding.
Run: `tests/test-profile-keys.sh`
Expected: PASS.

- [x] **Step 5: Run the suite at the unit boundary, then hand over**

Add under `## Unreleased` in `CHANGELOG.md`:

```markdown
- `keel init` detects `verify.security` from a single npm, pnpm or yarn lockfile, the same audit
  the generated CI already ran, and full `keel doctor` runs it, reaching the network.
  `keel doctor --fast` does not. Generated CI runs the audit once, as the `security` step.
```

Run: `tests/validate-citations.sh`, and repair any citation it reports.
Run: `tests/run-tests.sh`
Expected: PASS, apart from the one red named in step 4. The coordinator commits, then re-runs
`tests/test-keel.sh` and confirms it is green; that run is this task's `Done when`.

```bash
git add lib/detect-stack.sh bin/keel tests/test-keel.sh templates/profile.schema.json \
        docs/profile-keys.md docs/03-install-and-distribution.md CHANGELOG.md
git status --porcelain
```

Add any file whose citation you repaired. Stage exactly those paths and stop. **Do not commit.**
The coordinator commits with
`git commit -m "feat(detect): verify.security from the lockfile, run by full doctor"`.

---

### Task 7: keel passes its own doctor, with its push guard installed

> **Execution note (2026-09-26):** delegated. Step 1 witnessed in the implementer's report: `FAIL
> 3 permission guardrail(s) missing from .claude/settings.json` and the task 4 warning, now worded
> `conventions.protect_default_branch is not false and the push guard is not installed` (follow-up
> C), plus five warnings the task does not cover: codex installed but not in `harnesses`,
> `artifacts.snapshot` null beside an existing snapshot, `verify.typecheck` and `verify.build`
> null, the VS Code extension note. Step 2: `.claude/settings.json | 5 ++++-`, `.keel/profile.json
> | 2 +-`. Step 3: the install line as expected; `core.hooksPath` is `.githooks`, repository only.
> Step 4: the four named ok lines and `keel doctor: no problems, 5 warnings`, confirmed by the
> review, which is the Done when. `tests/run-tests.sh` All test files passed; validator OK.
> Citations repaired: two `CHANGELOG.md` line numbers, and `.claude/settings.json:39-46` to
> `42-49` in `tests/test-doc-claims.sh` and the seed-mode plan, the hooks block the three new
> rules moved. Review (spec and quality): COMPLIES, nothing blocking. It simulated pushes against a
> bare remote: `sandbox` pushes pass, `main` is refused, the scanner fallback runs, and commits
> get no trailer. Considered: the docs/06 comment omits the weaker-profile refusal; the hook
> prefers a `keel` on PATH over this repository's own scanner; `tests/export-public.sh` does not
> exclude `.githooks/`, so the hooks ship in the public export; `.githooks/*` is not linted.

**Story:** snapshot recommendation 3, and the maintainer's decision to run the push guard here
**Files:**
- Modify: `.claude/settings.json`
- Modify: `.keel/profile.json`
- Add: `.githooks/pre-push`, `.githooks/pre-commit`, `.githooks/prepare-commit-msg`
- Modify: `docs/06-repo-layout.md`, whose tree `tests/test-doc-claims.sh` requires to show every
  top-level entry, which the dry run hit once `.githooks/` existed
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: `keel_ask_rules` in `lib/harness/claude.sh`, the source of the three missing rules;
  `keel guard install`; task 5's hook change, which keeps the trailer off this repository's
  commits because its profile sets `conventions.no_attribution_footers: true`
- Produces: nothing new

**Depends on:** task 6, so the doctor run below includes every new line.

**Done when:** there is no `profile.verify` command for this. The check is
`bin/keel doctor --fast` printing a summary line that starts `keel doctor: no problems`, with no
push-guard warning.

- [x] **Step 1: Watch the check fail**

This task has no new test: the failing checks already exist in `doctor`.

Run: `bin/keel doctor --fast`
Expected: `FAIL  3 permission guardrail(s) missing from .claude/settings.json.` and the task 4
warning `conventions.protect_default_branch is true and the push guard is not installed`.

- [x] **Step 2: Add the three rules, and correct the version**

`keel init` is not used here: `.keel/profile.json` carries a note saying it is maintained by hand,
because init merges and would keep keys this file retired.

In `.claude/settings.json`, the `ask` array ends with `"Bash(npm publish*)"`. Replace:

```json
      "Bash(npm publish*)"
    ]
```

with:

```json
      "Bash(npm publish*)",
      "Bash(curl *)",
      "Bash(wget *)",
      "Bash(nc *)"
    ]
```

This is a text edit rather than a JSON rewrite because `json.dump` does not reproduce this file's
formatting byte for byte. Checked on 2026-09-25 in a clone: `tests/supply-chain-scan.sh` stays
clean with the three rules in place.

Then correct `keel_version`, which `keel profile set` refuses to touch. Task 5 already moved
`schema_version` to 5. This file round-trips through `json.dump` unchanged:

```bash
python3 -c 'import json; p = json.load(open(".keel/profile.json")); p["keel_version"] = open("VERSION").read().strip(); f = open(".keel/profile.json", "w"); json.dump(p, f, indent=2); f.write("\n")'
git diff --stat .claude/settings.json .keel/profile.json
```

Expected: `.claude/settings.json | 5 ++++-` and `.keel/profile.json | 2 +-`.

- [x] **Step 3: Install the push guard**

Run: `bin/keel guard install`
Expected: `installed .githooks/pre-push, .githooks/pre-commit, and .githooks/prepare-commit-msg,
and set core.hooksPath for this repository only`.

From here, a push to `main` from this clone is refused, which matches this repository's
pull-request workflow; `git push --no-verify` is the deliberate way past it. The pre-push scan
uses `tests/supply-chain-scan.sh` when `keel` is not on the terminal's PATH. The pre-commit hook
stays inert because `gates.commit_guard` is `off`.

In `docs/06-repo-layout.md`, in the tree, insert directly after the `.codex-plugin/` entry and its
following `│` line:

```
├── .githooks/                          # this repository's own guard, from `keel guard install`
│   ├── pre-commit                      # inert while gates.commit_guard is off
│   ├── pre-push                        # refuses a push to main, and runs the supply chain scan
│   └── prepare-commit-msg              # adds nothing here: no_attribution_footers is true
│
```

- [x] **Step 4: Watch the check pass**

Run: `bin/keel doctor --fast`
Expected: `ok    permission guardrails present in .claude/settings.json`,
`ok    configured by keel 0.21.0`, `ok    profile is at schema version 5`,
`ok    push guard installed`, and a summary starting `keel doctor: no problems`.

- [x] **Step 5: Run the suite at the unit boundary, then hand over**

Add under `## Unreleased` in `CHANGELOG.md`:

```markdown
- keel runs its own push guard, committed under `.githooks/`, and its `.claude/settings.json`
  carries the curl, wget and nc ask rules. Its profile records 0.21.0.
  `keel doctor` on this repository failed on the rules and warned on the guard.
```

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.

```bash
git add .claude/settings.json .keel/profile.json .githooks/pre-push .githooks/pre-commit \
        .githooks/prepare-commit-msg docs/06-repo-layout.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "chore: keel passes its own doctor and runs its own push guard"`. That commit is
the first to pass through the installed hooks: its message must come out with no `Keel-Version`
trailer, which `git log -1 --format=%B` shows. A trailer there means task 5 did not take effect,
and is a finding.

---

### Task 8: correct the stale idea statuses

> **Execution note (2026-09-26):** delegated. Every replace target occurred once; the implementer
> first confirmed each stated fact (the plans exist and name the ideas; `9c68003` fixes both
> Windows bugs with stub-python3 tests; the Windows CI row is under "Not in this plan"). No
> citation moved: nothing cites the Windows idea by line, and the other six kept their line
> counts. Step 4's block is five lines. `tests/run-tests.sh` All test files passed; validator OK.
> Review (spec and quality): COMPLIES, and on truth found "Next | Nothing" false for three ideas
> whose plan deliberately left a part open. **Deviation from the step text, by the maintainer's
> decision:** those three Next rows name what is left instead: the `CODEOWNERS` companion
> (profile-loosening), loosening in `doctor --json` (fleet-view), and whether keel's own `ci.yml`
> adopts the generated shape (write-ci); edited by the coordinator after the suite run, table text
> only, validator OK. Considered: the provenance idea's status could note the trailer is now
> conditional and off in keel's own repository; the Windows idea's body still says "still using";
> "Status corrected 2026-09-25" credits the snapshot, which found the drift.

**Story:** snapshot recommendation 5
**Files:**
- Modify: `docs/ideas/fleet-view-for-doctor.md`
- Modify: `docs/ideas/incidents-do-not-feed-back-into-standards.md`
- Modify: `docs/ideas/no-durable-provenance-record.md`
- Modify: `docs/ideas/profile-loosening-goes-unnoticed.md`
- Modify: `docs/ideas/write-ci-does-not-match-ship.md`
- Modify: `docs/ideas/coding-standards-audit-and-seed-modes.md`
- Modify: `docs/ideas/windows-python3-detection-is-wrong.md`

**Interfaces:** none. Documentation only.

**Depends on:** task 0, which commits the two documents the new rows cite. It shares no file with
task 7 and follows it only because this plan declares no batch. Two of these files may already
carry a citation repair from tasks 1 to 6; edit the status rows only.

**Done when:** `tests/run-tests.sh` passes, which runs the citation and document validators over
`docs/`.

- [x] **Step 1: There is no failing test for this**

This task corrects status text. No validator reads an idea's status, and adding one is not in
scope.

- [x] **Step 2: Replace the two status rows in each of the five outside-the-agent ideas**

In each of `fleet-view-for-doctor.md`, `incidents-do-not-feed-back-into-standards.md`,
`no-durable-provenance-record.md`, `profile-loosening-goes-unnoticed.md` and
`write-ci-does-not-match-ship.md`, replace:

```markdown
| Status | shaped |
```

with:

```markdown
| Status | built via docs/plans/2026-09-19-make-keel-enforceable-outside-the-agent.md. Status corrected 2026-09-25 by docs/snapshot.md |
```

and replace:

```markdown
| Next | `write-plan`, as one increment of the outside-the-agent plan |
```

with:

```markdown
| Next | Nothing |
```

- [x] **Step 3: Correct the coding-standards modes idea**

In `docs/ideas/coding-standards-audit-and-seed-modes.md`, replace the whole `| Status |` row with:

```markdown
| Status | built via docs/plans/2026-09-02-the-four-mode-router-and-audit.md and docs/plans/2026-09-03-seed-mode-and-its-arm.md. Status corrected 2026-09-25 by docs/snapshot.md |
```

and the whole `| Next |` row with:

```markdown
| Next | Nothing |
```

- [x] **Step 4: Give the Windows idea a status**

In `docs/ideas/windows-python3-detection-is-wrong.md`, insert directly below the
`# Windows: python3 detection is wrong in two ways` heading and its following blank line:

```markdown
| | |
|---|---|
| Status | built in `9c68003`, both bugs, each with a test using a stub python3. No CI job runs on Windows |
| Next | Nothing here. A Windows CI job is listed under "Not in this plan" in docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md |

```

- [x] **Step 5: Run the suite at the unit boundary, then hand over**

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.

```bash
git add docs/ideas/fleet-view-for-doctor.md docs/ideas/incidents-do-not-feed-back-into-standards.md \
        docs/ideas/no-durable-provenance-record.md docs/ideas/profile-loosening-goes-unnoticed.md \
        docs/ideas/write-ci-does-not-match-ship.md docs/ideas/coding-standards-audit-and-seed-modes.md \
        docs/ideas/windows-python3-detection-is-wrong.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "docs(ideas): record the ideas that were built as built"`.

---

### Task 9: run the test suite on macOS in CI, advisory

> **Execution note (2026-09-26):** delegated. Step 1's YAML check printed `ok` before and after.
> The implementer confirmed both claims in the job's comment: `run-tests.sh`'s lint step prints
> SKIP and exits 0 without shellcheck, and doctor runs a verify command with no time limit when
> neither `timeout` nor `gtimeout` exists. Two `CHANGELOG.md` line citations the entry moved were
> renumbered onto the lines they quote. `tests/run-tests.sh` All test files passed; validator OK.
> **Review: the coordinator checked the staged text against the step's two blocks (each occurs
> once, verbatim) and the two renumbered targets; no review subagent was dispatched for this
> verbatim insert.** Considered: in bash, `command -v timeout gtimeout` returns non-zero when either
> name is missing, so the step may print a found path and then "neither timeout nor gtimeout"; the
> path line is the answer. **Done when is open:** it needs the `Tests on macOS` job's result on
> the pull request, which exists only after a push, and nothing has been pushed.
>
> **Done when, witnessed 2026-09-26:** on pull request #72, run 36265854757, `Tests on macOS`
> passed in 4m41s, and its timeout step printed `neither timeout nor gtimeout`, so on that runner
> doctor runs verify commands with no time limit. It stays advisory, by decision.

**Story:** snapshot recommendation 6, and the maintainer's decision that the job starts advisory
**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify: `CHANGELOG.md`

**Interfaces:** none.

**Depends on:** task 8.

**Done when:** there is no command. This is a human check that the `Tests on macOS` job ran on the
pull request that carries this plan's commits, and what it reported. It is **not** made a required
status check here: by decision it stays advisory until it has a week of green runs, and making it
required then is the row "Make the macOS job required" in "Not in this plan".

- [x] **Step 1: There is no local test for this**

A workflow file is exercised only by GitHub Actions. Before pushing, check that it still parses:

Run: `ruby -ryaml -e 'YAML.load_file(".github/workflows/ci.yml"); puts "ok"'`
Expected: `ok`. Ruby ships with macOS. On a machine without it, say so and rely on the job run.

- [x] **Step 2: Add the job**

In `.github/workflows/ci.yml`, insert this job between the `validate` job and the comment block
that introduces `supply-chain`:

```yaml
  # A separate job rather than a matrix on `validate`, so that job's required-check name does not
  # change. Advisory until it has a week of green runs, by decision on 2026-09-25: branch
  # protection does not list it yet. macOS is the maintainer's platform and had never run in CI.
  # Stock macOS ships neither `timeout` nor `gtimeout`, so doctor runs verify commands unbounded
  # there; the first step records which one this runner has, because a runner image with coreutils
  # would not take that path. Tests only: shellcheck is not preinstalled on macOS runners, so the
  # lint step in run-tests.sh reports SKIP here, and lint results do not depend on the platform.
  test-macos:
    name: Tests on macOS
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Record which timeout binary exists
        run: command -v timeout gtimeout || echo "neither timeout nor gtimeout"

      - name: Run tests
        run: tests/run-tests.sh
```

Run the step 1 check again. Expected: `ok`.

- [x] **Step 3: Run the suite at the unit boundary, then hand over**

Add under `## Unreleased` in `CHANGELOG.md`:

```markdown
- CI runs the test suite on macOS as well as Linux, as its own job, advisory until it has a week
  of green runs.
```

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.

```bash
git add .github/workflows/ci.yml CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "ci: run the test suite on macOS, advisory"`. After the push, read the
`Tests on macOS` job, report its result and what the timeout step printed. A red job there is a
finding for `debug`, not a reason to drop the job.

---

### Task 10: lint the Python in `lib/` with ruff, in CI

> **Execution note (2026-09-26):** delegated. Step 1 witnessed in the implementer's report: ruff
> 0.16.9 from a throwaway venv, `ruff check --isolated --no-cache --select E4,E7,E9,F lib/`
> printed `All checks passed!` at e242a88. YAML check `ok`; the `Enforced by` target occurred
> once; two `CHANGELOG.md` line citations the entry moved renumbered onto the lines they quote.
> `tests/run-tests.sh` All test files passed; validator OK. **Review: the coordinator checked
> the staged text against the step's blocks (the job once, verbatim, between `test-macos` and
> `supply-chain`; the old row gone and the new one present; the CHANGELOG entry) and the two
> renumbered targets; no review subagent was dispatched for this verbatim insert.** **Done when
> is half open:** the local ruff run passed; the `Python lint` job needs a push.
>
> **Done when, witnessed 2026-09-26:** on pull request #72, run 36265854757, `Python lint` passed
> in 9s, by then installing ruff from a hash-checked requirements file (see the security audit's
> L-02, fixed before shipping).

**Story:** maintainer decision of 2026-09-25: ruff in CI only, the local lint string unchanged
**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify: `docs/standards.md` (the `Enforced by` row of its header)
- Modify: `CHANGELOG.md`

**Interfaces:** none.

**Depends on:** task 9, which shares `.github/workflows/ci.yml`.

**Done when:** the ruff command below passes locally, and the `Python lint` job is green on the pull
request. It is a CI job, not a `profile.verify` command, by decision.

- [x] **Step 1: Watch the command run against the tree as it is**

ruff is not a local dependency, so run it from a throwaway environment:

```bash
python3 -m venv "${TMPDIR:-/tmp}/keel-ruff"
"${TMPDIR:-/tmp}/keel-ruff/bin/pip" install -q ruff==0.16.9
"${TMPDIR:-/tmp}/keel-ruff/bin/ruff" check --isolated --no-cache --select E4,E7,E9,F lib/
```

Expected: `All checks passed!`. Measured on 2026-09-25 at `6d67084`. There is no red step here:
the rule set is chosen to be clean today, so the job keeps anything new out rather than landing
with findings.

The rule set is named rather than defaulted. ruff 0.16.9's default set reported 119 findings on
the same tree, 110 of them UP031 (percent formatting), a style preference and not a defect;
`E4`, `E7`, `E9` and `F` are the correctness rules. `--isolated` keeps a developer's own ruff
configuration out of the result.

- [x] **Step 2: Add the job**

In `.github/workflows/ci.yml`, insert this job directly after the `test-macos` job task 9 added:

```yaml
  # ruff over the Python in lib/, in CI only, by decision on 2026-09-25: the local lint string stays
  # shellcheck, so a contributor needs nothing new. Pinned, so a ruff release cannot turn CI red on
  # its own, and the rule set named, because ruff's defaults add a style rule with 110 findings
  # here. --isolated keeps any ruff configuration outside the repository out of the result.
  python-lint:
    name: Python lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: ruff
        run: pipx run ruff==0.16.9 check --isolated --no-cache --select E4,E7,E9,F lib/
```

Run: `ruby -ryaml -e 'YAML.load_file(".github/workflows/ci.yml"); puts "ok"'`
Expected: `ok`.

In `docs/standards.md`, in the header table, replace the `Enforced by` row:

```markdown
| Enforced by | `tests/run-tests.sh`, which runs `tests/validate-skills.sh`, `tests/no-internal-leaks.sh`, `tests/supply-chain-scan.sh`, and `shellcheck` from the profile |
```

with:

```markdown
| Enforced by | `tests/run-tests.sh`, which runs `tests/validate-skills.sh`, `tests/no-internal-leaks.sh`, `tests/supply-chain-scan.sh`, and `shellcheck` from the profile; and ruff over `lib/` in CI only |
```

- [x] **Step 3: Run the suite at the unit boundary, then hand over**

Add under `## Unreleased` in `CHANGELOG.md`:

```markdown
- CI lints the Python in `lib/` with ruff 0.16.9, correctness rules only (E4, E7, E9, F), as its
  own job. The local lint command is unchanged.
```

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
`tests/supply-chain-scan.sh` runs inside it and reads the workflow file too.

```bash
git add .github/workflows/ci.yml docs/standards.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "ci: lint lib/ with ruff, correctness rules only"`. After the push, report the
`Python lint` job's result.

---

## Not in this plan

Each of these is a decision before it is work. A plan task for any of them would pick the answer
silently.

| Item | Why it is not a task | Next |
|---|---|---|
| Run `verify.lint` after each edit in a session, through a PostToolUse hook | The injected block says "lint after each file edit" and nothing enforces it. A hook costs a lint run per edit, open decision 4 already weighed that cost for commits, and ADR-0003 needs an evidence row for the primitive | `design-architecture`, an ADR |
| Run keel's own checks in target-project CI: `keel scan`, the profile loosening check, the standards gate | Generated CI cannot call `keel` because nothing installs it there. Vendoring, fetching a release, or re-expressing the checks are three different designs | `design-architecture`, an ADR |
| Make the macOS job required | Decided 2026-09-25: advisory until it has a week of green runs | the maintainer adds `Tests on macOS` to branch protection for `main` once that holds |
| The standards assessment's remedies | Folding in or departing from five house references, the APEX schema identifier, and departures D-2 and D-4 are judgement about the standards document, which `coding-standards` owns | `coding-standards`, from `docs/audits/2026-09-25-standards.md` |
| A Windows CI job | The Windows fixes have tests with stub interpreters and no real Windows run; a Git Bash job is possible and its cost is unknown | `setup-deployment` |
| Existing `master` repositories whose generated CI says `main` | Task 3 fixes new workflows only; init never rewrites an existing one, by design | a note in the release, or a `doctor` check if it turns out to be common |
| `verify.security` for pip, and for stacks with no lockfile audit | pip-audit installs a package, and `doctor` executes verify commands | a separate decision, if a Python project asks |

## Open questions

None block a task. The decisions of 2026-09-25 are recorded in the header. What remains of
recommendation 7 in `docs/snapshot.md` is the first two rows of the table above.
