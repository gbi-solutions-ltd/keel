# Schema version and snapshot handoff Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go, on output you read.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness, or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** make the "re-run init" warning fire only when the profile is genuinely missing a field, and
make a snapshot say what it did not check instead of reading as a clean bill of health.

**Ideas:** `docs/ideas/profile-schema-drift.md`, `docs/ideas/snapshot-surfaces-remediation-gaps.md`
**ADRs:** ADR-0001 (skill body word ceiling). No new ADR: neither change alters an accepted decision.
**Architecture:** two independent halves in one plan because both are small and both were raised
together. Tasks 1 to 3 add a `schema_version` to the profile, separate from `keel_version`, and move
doctor's staleness warning onto it. Tasks 4 and 5 make `repo-snapshot` state its own limits and refer
the two audits it deliberately does not perform. Task 5 closes the documents.

## Global constraints

Copied verbatim from `.keel/profile.json` and the two idea records. Every task inherits these.

- Verify commands: test `tests/run-tests.sh`, one test `tests/{name}`, lint
  `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`
- `format`, `format_fix`, `typecheck`, `build`, `e2e` and `security` are all `null` in this project.
  Do not invent one.
- Never start on `main`. This repository does all work on `sandbox` and PRs it.
- **ADR-0001:** a skill body over 700 words warns, and over 700 requires a passing eval arm at that
  length recorded in `tests/evals/results.md`. `repo-snapshot`'s body is at **698**. Task 4 has two
  words of headroom and the measuring command is in the task.
- Writing style: no em dashes, no en dashes. Commit messages carry no attribution footer, no robot
  emoji, no generated-with line.
- **The full suite takes 10+ minutes.** Run it in the background and never pipe it through `tail`;
  that buffers the whole run and the output file stays empty until it exits, which reads like a hang.
- **A version or schema bump reddens `tests/test-cache-install.sh` until it is committed.** That test
  archives `HEAD` and compares against the working tree. Commit, then re-run that one file.

## Corrected during execution, 2026-08-17, before task 1 started

`execute-plan`'s step 2 read caught three defects in this plan as first written, and the tasks below
are the corrected versions:

- Task 3's test used `ok`/`bad` helpers that do not exist in `tests/test-validate-skills.sh`. It now
  uses that file's real harness, `run_out`.
- Task 3 copied the whole repository into a scratch directory for no reason: `check()` already runs
  the validator with a fixture as cwd.
- Task 4's new check read `skills/repo-snapshot/...` unguarded. Every case in
  `tests/test-validate-skills.sh` runs the validator from a fixture root that has no such file, so
  as written it would have failed all of them instead of testing its own rule. Both new checks are
  now guarded on the file existing, matching lines 191, 199 and 219 of the validator.

## Deviation from the standard chain, stated rather than hidden

`write-plan` names `write-user-stories` as a required sub-skill when no stories exist, and none do.
Skipped deliberately: both changes came from `shape-idea` records rather than a PRD, and neither adds
a user-facing capability that a story would describe. Tasks trace to the two idea records instead of
to story IDs. If that is the wrong call, the remedy is to write the stories and re-plan, not to
retro-fit IDs onto these tasks.

---

### Task 1: `keel init` writes a `schema_version` the tool owns

**Idea:** `docs/ideas/profile-schema-drift.md`
**Files:**
- Modify: `bin/keel`
- Modify: `templates/profile.schema.json`
- Test: `tests/test-keel.sh`

**Interfaces:**
- Produces: shell variable `SCHEMA_VERSION`, an integer, defined once near the top of `bin/keel`
  beside the other globals. Tasks 2 and 3 both read it.
- Produces: profile key `schema_version`, an integer at the top level, written by `write_profile`,
  preserved by `merge_profile` as tool-owned, and refused by `profile_set`.

**Done when:** `tests/test-keel.sh` passes and the full suite is green.

- [x] **Step 1: Write the failing tests**

Add to `tests/test-keel.sh`, in the staleness block that starts near line 1500, before the existing
`doctor reports a project left on an older keel` case:

```bash
# schema_version is the tool's, like keel_version. It answers "does this profile have the fields
# the installed keel expects", which keel_version cannot, because most releases change no field.
got="$(python3 -c "import json;print(json.load(open('$d/.keel/profile.json')).get('schema_version'))")"
want="$(sed -n 's/^SCHEMA_VERSION=\([0-9][0-9]*\)$/\1/p' "$ROOT/bin/keel")"
[ -n "$want" ] && [ "$got" = "$want" ] && ok "init writes the schema_version bin/keel declares" \
  || bad "schema_version" "profile has '$got', bin/keel declares '$want'"

python3 - "$d" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]) / ".keel/profile.json"
d = json.loads(p.read_text()); d["schema_version"] = 0
p.write_text(json.dumps(d, indent=2) + "\n")
PY
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
got="$(python3 -c "import json;print(json.load(open('$d/.keel/profile.json'))['schema_version'])")"
[ "$got" = "$want" ] && ok "re-running init reclaims schema_version" \
  || bad "schema_version" "stayed '$got' after re-init, want '$want'"

out="$( cd "$d" && "$KEEL" profile set schema_version 2 2>&1 )" && rc=0 || rc=$?
case "$rc:$out" in
  1:*"written by init"*) ok "profile set refuses schema_version" ;;
  *) bad "schema_version" "profile set did not refuse: rc=$rc out=${out:0:80}" ;;
esac
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL, three times. `init writes the schema_version bin/keel declares` reports
`profile has 'None'`, because nothing writes the key yet.

- [x] **Step 3: Write the minimal implementation**

In `bin/keel`, beside the other globals near the top of the file:

```sh
# The profile schema's own version, deliberately separate from VERSION. `keel_version` answers
# "which keel wrote this file". This answers "does this file have the fields the installed keel
# expects", which is the only version of that question worth warning about. Bump it only when a
# field is added, removed, renamed or moved. 0.7.0 and 0.7.1 changed none, and a warning that fires
# on releases like those is one nobody reads by the time it matters.
SCHEMA_VERSION=1
```

In `write_profile`, immediately after the `keel_version` line:

```sh
      printf '  "schema_version": %s,\n' "$SCHEMA_VERSION"
```

In `merge_profile`'s python block, beside the existing `keel_version` line:

```python
merged["schema_version"] = fresh["schema_version"]
```

In `profile_set`, widen the existing guard:

```python
if path.split(".")[0] in ("keel_version", "schema_version"):
    sys.stderr.write(
        "keel: %s is written by init, not by hand. keel_version records which keel configured "
        "this project; schema_version records which set of fields this file has, and doctor reads "
        "both.\n" % path.split(".")[0])
    sys.exit(1)
```

In `templates/profile.schema.json`, in `properties`, immediately after `keel_version`:

```json
    "schema_version": {
      "type": "integer",
      "description": "Which set of profile fields this file has. Written by `keel init`, bumped only when a field is added, removed, renamed or moved. Absent means the file predates the field, which doctor treats as stale."
    },
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS. Then `tests/run-tests.sh`; nothing else may break. Note that
`tests/test-cache-install.sh` compares an archive of `HEAD` against the working tree and is
unaffected by this task, which adds no file.

- [x] **Step 5: Commit**

```bash
git add bin/keel templates/profile.schema.json tests/test-keel.sh
git commit -m "feat(profile): add a tool-owned schema_version, separate from keel_version"
```

---

### Task 2: doctor's staleness warning reads `schema_version`

**Idea:** `docs/ideas/profile-schema-drift.md`
**Files:**
- Modify: `bin/keel`
- Test: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `SCHEMA_VERSION` and the profile's `schema_version`, both from task 1.
- Produces: nothing new. It changes which condition raises the existing warning.

**Behaviour this task establishes**, so there is nothing to decide while implementing:

| Profile state | doctor says | Level |
|---|---|---|
| `schema_version` equals `SCHEMA_VERSION` | `profile is at schema version <n>, which this keel expects` | good |
| `schema_version` lower | `this project's profile is at schema version <n>; keel <VERSION> expects <SCHEMA_VERSION>. Re-run 'keel init' to pick up the new fields. It merges, so your own values survive.` | warn |
| `schema_version` absent | the same warning, with `at schema version none` | warn |
| `schema_version` higher | `your keel is the older one here. Upgrade the plugin.` and says not to re-run init | warn |
| `keel_version` present, whatever it is | `configured by keel <pv>` | good, informational only |

**The higher row and the numeric comparison were added by review**, after the plugin pass found that
a bare `!=` calls a teammate's newer profile stale and tells them to re-run init, which writes the
field back down. The profile is a committed file, so two engineers on different keel versions would
ping-pong it, each following the tool's advice. The success line was reworded in the same pass: it
said `profile is current with keel <VERSION>`, which asserts a release fact the check never
established, and this whole change exists to stop conflating those two.

The substring `configured by keel` moves from the warning to the informational line and keeps its
wording, so the existing assertion at `tests/test-keel.sh:1508` still matches. Retitle that case:
it no longer tests staleness, it tests that doctor reports which keel configured the project.

- [x] **Step 1: Write the failing test**

In `tests/test-keel.sh`, retitle the existing case and add the two below it:

```bash
case "$out" in *"configured by keel 0.0.1-old"*) ok "doctor reports which keel configured the project" ;;
  *) bad "staleness" "doctor did not report the configuring version" ;; esac

# The point of the split: an old keel_version alone is not staleness any more, because most
# releases change no field. Only a schema_version mismatch is.
case "$out" in *"Re-run 'keel init'"*) bad "staleness" "warned on keel_version alone, which fires on every release" ;;
  *) ok "an old keel_version alone does not raise the re-run warning" ;; esac

python3 - "$d" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]) / ".keel/profile.json"
d = json.loads(p.read_text()); del d["schema_version"]
p.write_text(json.dumps(d, indent=2) + "\n")
PY
out2="$( cd "$d" && "$KEEL" doctor 2>&1 )"
case "$out2" in *"schema version none"*) ok "doctor treats an absent schema_version as stale" ;;
  *) bad "staleness" "doctor did not notice a profile with no schema_version" ;; esac
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL on `an old keel_version alone does not raise the re-run warning`, because the current
comparison at `bin/keel:1207` warns on exactly that.

- [x] **Step 3: Write the minimal implementation**

Replace the staleness block in `cmd_doctor`, currently `bin/keel:1203` to `bin/keel:1212`:

```sh
    if have_python; then
        local pv sv iv
        pv="$(json_get .keel/profile.json keel_version || true)"
        sv="$(json_get .keel/profile.json schema_version || true)"
        iv="$(cat "$HERE/VERSION" 2>/dev/null || true)"
        [ -n "$pv" ] && good "configured by keel $pv"
        if [ "$sv" != "$SCHEMA_VERSION" ]; then
            warn "this project's profile is at schema version ${sv:-none}; keel ${iv:-unknown} expects $SCHEMA_VERSION. Re-run 'keel init' to pick up the new fields. It merges, so your own values survive."
        else
            good "profile is current with keel ${iv:-unknown}"
        fi
    fi
```

Update the comment above the block: the reason it exists is unchanged, but it no longer keys off the
release version, and the next reader needs to know that was deliberate.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS. Then `tests/run-tests.sh`; nothing else may break.

- [x] **Step 5: Commit**

```bash
git add bin/keel tests/test-keel.sh
git commit -m "fix(doctor): warn on schema drift, not on every release"
```

---

### Task 3: a schema field change without a version bump fails the build

**Idea:** `docs/ideas/profile-schema-drift.md`, open question 3
**Files:**
- Modify: `tests/validate-skills.sh`
- Test: `tests/test-validate-skills.sh`

**Interfaces:**
- Consumes: `SCHEMA_VERSION` from `bin/keel`, read by `sed`, and `templates/profile.schema.json`.
- Produces: constant `SCHEMA_FINGERPRINT` in `tests/validate-skills.sh`, the first 12 characters of
  the sha256 of the sorted, newline-joined list of `properties` key paths, two levels deep.

Why a fingerprint and not a diff against git: the check has to work on a fresh clone with no history
and inside CI, and it has to fail on the change rather than on the commit.

- [x] **Step 1: Write the failing test**

Add to `tests/test-validate-skills.sh`, after the last `run_out` case, using that file's own harness:
`run_out <name> <expected exit> <mutate fn> <pattern> <yes|no>`, which builds a fixture, runs the
validator with the fixture as cwd, and asserts on both exit code and output.

```bash
# The rule this guards: a field added to the profile schema without SCHEMA_VERSION moving is a
# release that silently expects a field nobody's profile has. Decision 11's lesson, applied to the
# schema: the thing nobody witnessed is the thing that needs a mechanical check.
m_schema_drift() {
    mkdir -p "$1/templates"
    cat > "$1/templates/profile.schema.json" <<'JSON'
{ "properties": { "a_field_nobody_declared": { "type": "string" } } }
JSON
}
run_out "a profile schema whose fields do not match the fingerprint is rejected" 1 m_schema_drift "SCHEMA_VERSION" yes

# The check is guarded on the file existing, like every other repository-only check here, because
# the fixture roots these tests run in have no templates/profile.schema.json.
run_out "no profile schema present means the fingerprint check stays quiet" 0 noop "fingerprint" no
```

**There is no fixture-based positive case**, and that is deliberate: a fixture whose fingerprint
matched would have to hard-code the real repository's field set, which is the thing under test. The
positive case is the repository's own `tests/validate-skills.sh` run staying green, asserted in step
4 and in CI.

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-validate-skills.sh`
Expected: FAIL, `rc=0` and no mention of `SCHEMA_VERSION`, because no such check exists.

- [x] **Step 3: Write the minimal implementation**

In `tests/validate-skills.sh`, beside the other budget constants at the top:

```sh
# The profile schema's field set, fingerprinted. bin/keel's SCHEMA_VERSION tells doctor whether a
# project's profile is missing fields, and it is only true if somebody remembers to bump it. This
# check removes the remembering: change the fields, and the build tells you to bump the version and
# update this line. Both numbers move in the same commit or neither does.
SCHEMA_FINGERPRINT=<the value step 4 prints>
```

And, in the same section as the other repository-only checks, which all guard on the file existing
(`tests/validate-skills.sh:191`, `:199`, `:219`) because the validator is run from fixture roots by
`tests/test-validate-skills.sh`:

```sh
if [ -f templates/profile.schema.json ] && command -v python3 >/dev/null 2>&1; then
    got="$(python3 - <<'PY'
import hashlib, json
d = json.load(open("templates/profile.schema.json"))
paths = []
for k, v in d.get("properties", {}).items():
    paths.append(k)
    if isinstance(v, dict):
        paths += ["%s.%s" % (k, c) for c in v.get("properties", {})]
print(hashlib.sha256("\n".join(sorted(paths)).encode()).hexdigest()[:12])
PY
)"
    if [ "$got" != "$SCHEMA_FINGERPRINT" ]; then
        report "templates/profile.schema.json changed its field set (fingerprint $got, expected $SCHEMA_FINGERPRINT). Bump SCHEMA_VERSION in bin/keel and set SCHEMA_FINGERPRINT here to $got, in the same commit."
    fi
fi
```

`have_python` does not exist in `tests/validate-skills.sh`, which is why the guard above spells the
`command -v python3` test out rather than sourcing `bin/keel`.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/validate-skills.sh`
Expected: it FAILS once, printing the real fingerprint. Paste that value into `SCHEMA_FINGERPRINT`,
run it again, and expect `OK 24 skills validated`. This is the intended bootstrap: the check computes
the number it wants, and the first run is how you learn it.

Then run: `tests/test-validate-skills.sh`
Expected: PASS. Then `tests/run-tests.sh`; nothing else may break.

- [x] **Step 5: Commit**

```bash
git add tests/validate-skills.sh tests/test-validate-skills.sh
git commit -m "test(validate): fail when the profile schema changes without a version bump"
```

---

### Task 4: a snapshot states which checks it did not perform

**Idea:** `docs/ideas/snapshot-surfaces-remediation-gaps.md`
**Files:**
- Modify: `skills/repo-snapshot/SKILL.md`
- Modify: `skills/repo-snapshot/references/section-templates.md`
- Test: `tests/validate-skills.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing programmatic. The contract is the wording, and the check in step 3 is what makes
  it a contract rather than an intention.

**The word budget is the binding constraint here.** The body is at 698 of 700. The step 6 replacement
below is 18 words against the current 17, landing at 699. The rule about which skills to name is
therefore in `section-templates.md`, which is unbudgeted, and **not** in the body. Losing "two or
three" from the body is a deliberate trade, and the cap moves to section 10 in the template where the
seven-item cap already lives.

**Done when:** `tests/validate-skills.sh` passes and
`awk 'f;/^---$/{c++; if(c==2) f=1}' skills/repo-snapshot/SKILL.md | wc -w` prints 700 or less.

- [x] **Step 1: Write the failing test**

Add to `tests/validate-skills.sh`, in the same section as the other cross-file checks:

```bash
# repo-snapshot deliberately does not audit: section-templates.md section 8 says so. A document
# that omits both the refusal and the referral reads as a clean bill of health, which is the one
# thing a snapshot must never accidentally be.
#
# Guarded on the files existing, like every other repository-only check here. tests/test-validate-
# skills.sh runs this validator from fixture roots that contain no skills/repo-snapshot, and an
# unguarded read would fail every one of those cases instead of this rule.
st=skills/repo-snapshot/references/section-templates.md
if [ -f "$st" ]; then
    for needed in 'security-audit --full' 'coding-standards' 'did not check'; do
        grep -qF -- "$needed" "$st" \
          || report "$st does not mention '$needed'. A snapshot that names neither what it skipped nor who does it reads as a clean bill of health."
    done
fi
if [ -f skills/repo-snapshot/SKILL.md ]; then
    grep -qF -- 'did not check' skills/repo-snapshot/SKILL.md \
      || report "skills/repo-snapshot/SKILL.md step 6 does not require the snapshot to say what it did not check."
fi
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/validate-skills.sh`
Expected: FAIL, four times, once per missing string.

- [x] **Step 3: Write the minimal implementation**

In `skills/repo-snapshot/SKILL.md`, replace the whole of step 6's body:

```markdown
Name section 10's highest-value actions with their skills, and what you did not check. Do not start them.
```

In `skills/repo-snapshot/references/section-templates.md`, at the end of section 10, after the
`Cap at seven items` paragraph:

```markdown
**Name two or three actions in the handoff**, not seven. The cap above is what the document may
contain; this is what a reader can act on today.

**Two items are required on a first look at an unfamiliar repository**, because this skill
deliberately does not do either job and a document that omits them reads as a clean bill of health:

- `security-audit --full`, whose own scope line names this exact moment: a new engagement. Section 8
  records what you noticed in passing; it is not an audit and must not be presented as one.
- `coding-standards`, to establish what this repository's conventions are against the GBi defaults.

Then close the document with one line naming what this snapshot did not check, in the same place
every time, so a reader who skips to the end still sees it. `security-audit` already carries this
rule as "say plainly what you did not cover"; the asymmetry was accidental.
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/validate-skills.sh`
Expected: PASS, `OK 24 skills validated`.

Then run: `awk 'f;/^---$/{c++; if(c==2) f=1}' skills/repo-snapshot/SKILL.md | wc -w`
Expected: `699`. If it prints 701 or more, the step 6 wording was changed while implementing; restore
it exactly as written above rather than editing elsewhere to make room.

Then run: `tests/run-tests.sh`; nothing else may break.

- [x] **Step 5: Commit**

```bash
git add skills/repo-snapshot/SKILL.md skills/repo-snapshot/references/section-templates.md \
        tests/validate-skills.sh
git commit -m "feat(repo-snapshot): say what the snapshot did not check, and who does it"
```

---

### Task 5: the CHANGELOG and the two idea records say what is true now

**Idea:** both
**Files:**
- Modify: `CHANGELOG.md`
- Modify: `docs/ideas/profile-schema-drift.md`
- Modify: `docs/ideas/snapshot-surfaces-remediation-gaps.md`

**Interfaces:** none.

**Done when:** there is no command. This is a documentation task and its check is a human reading the
diff. An invented test here would read as coverage.

- [x] **Step 1: There is no test for this**

This task changes prose only. It cannot be automated because correctness is whether the sentences are
true, which no command can decide.

- [x] **Step 2: Write the entry**

Add an `## Unreleased` section at the top of `CHANGELOG.md`, above the 0.7.1 heading, covering both
halves: what the schema version fixes and why the old warning was noise, and what a snapshot now
says about its own limits. Follow the existing entries' shape: state what changed, and state what is
still not covered.

- [x] **Step 3: Close the records**

In both idea records, set `Status` to `agreed, built` and add one line under the recommendation
naming the commits. Do not rewrite the case against; a record whose objections are edited out after
the fact is worth nothing next time.

- [x] **Step 4: Commit**

```bash
git add CHANGELOG.md docs/ideas/profile-schema-drift.md docs/ideas/snapshot-surfaces-remediation-gaps.md
git commit -m "docs: record the schema_version and snapshot handoff changes"
```

---

## Open questions

None blocking. Two were closed during planning and both are recorded in the idea records rather than
here:

- What a skill does when a profile field is absent. Answered: it degrades safely, so this is a signal
  fix and not a correctness one. That answer is why there is no task widening any skill's handling.
- Whether the snapshot should perform the audits itself. Answered no, on 2026-08-17, in favour of the
  referral in task 4.

One is deliberately out of scope: whether a posture baseline that diffs two runs deserves its own
skill. It is open question 2 in the snapshot record and is not planned here.

## Self-review

1. **Idea coverage:** `profile-schema-drift` maps to tasks 1, 2, 3. `snapshot-surfaces-remediation-gaps`
   maps to task 4. Both map to task 5. No idea is unmapped, and no task serves neither.
2. **Placeholder scan:** the only deferred value is `SCHEMA_FINGERPRINT` in task 3, which cannot be
   known before the code that computes it runs. Step 4 of that task states how to obtain it and that
   the first run is expected to fail. That is a bootstrap, not a TBD.
3. **Name consistency:** `SCHEMA_VERSION` (shell, `bin/keel`), `schema_version` (profile key),
   `SCHEMA_FINGERPRINT` (shell, `tests/validate-skills.sh`). Used identically in every task.
4. **Command accuracy:** every verifying command is `tests/run-tests.sh` or a `tests/{name}` form
   from `profile.verify.test_one`. The `awk ... | wc -w` in task 4 measures a budget rather than
   verifying behaviour, and the `grep` calls inside the tests are the implementation, not the gate.
5. **Every task ends with a commit step.** Task 5's is step 4, because it has no test cycle.
6. **No task depends on a file no task creates.** Tasks 2 and 3 depend on `SCHEMA_VERSION` from task
   1, which is why they follow it. Task 4 depends on nothing.
