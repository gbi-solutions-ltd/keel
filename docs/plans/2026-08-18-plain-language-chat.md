# Plain language in chat replies Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go, on output you read.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness, or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** a project can set `conventions.explain_level` to `plain` and have every chat reply define
its technical terms, without the always-loaded injection growing by a byte.

**Stories:** S-01 to S-08, from `docs/stories/plain-language-chat.md`
**PRD:** `docs/prd/plain-language-chat.md`, approved 2026-08-18
**ADRs:** none. This adds one profile key and one branch to an existing hook. ADR-0001 governs
skill body length and no skill is touched.
**Architecture:** one new enum key in the profile schema, one extra `case` branch in
`hooks/session-start`, and two new paragraph constants. No new file except none: every change lands
in a file that already exists. There is no architecture document because there is no new component
and no new boundary.

## Global constraints

Copied in full rather than linked, because a task executed by a fresh agent that reads only its own
section must still obey them.

- Verify commands, from `.keel/profile.json`:
  - test: `tests/run-tests.sh`
  - one test: `tests/{name}`, for example `tests/test-session-start.sh`
  - lint: `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`
  - format, typecheck, build, e2e, security: `null`. There is nothing to compile and no formatter.
- The full suite takes about four and a half minutes. Run the single test in steps 2 and 4, and the
  full suite before the commit step.
- Never start on `main`. `conventions.default_branch` is `main` and
  `protect_default_branch` is `true`. All keel work goes on the `sandbox` branch.
- **No em dashes, en dashes, or any dash longer than a hyphen**, in code, comments, documents or
  commit messages. `tests/no-internal-leaks.sh` and the house style both care.
- **No `python3` in `hooks/session-start`.** It runs before every session and must not depend on an
  interpreter being present or pay its startup. `hooks/session-start:16-20` states this. Tests may
  use `python3` freely; the hook may not.
- **The injected output must stay byte-identical for a given profile.** No date, no branch, no
  counter, no file that changes. `hooks/session-start:4-8` states why: one volatile byte costs the
  prompt cache on every request of every session.
- `NFR-01`: no combination may exceed **1,285 characters**, which the validator's `chars * 10 / 36`
  estimate reports as 356 tokens. The 400 ceiling at `tests/validate-skills.sh:283-284` remains the
  outer limit; 356 is the tighter rule this work adds.
- Commit style is `conventional`. No `Co-Authored-By` trailer, no robot emoji, no attribution
  footer.

## The four forms, fixed and measured

Every task refers to these. They were measured through the real hook on 2026-08-18 and the numbers
are asserted exactly, not as bounds.

| `response_style` | `explain_level` | Injects | Total |
|---|---|---|---|
| `terse` | `technical` | the brevity paragraph shipping today, unchanged | 1,284 chars, 356 tokens |
| `terse` | `plain` | `PLAIN_TERSE` below | 1,283 chars, 356 tokens |
| `verbose` | `technical` | nothing, exactly as today | 1,082 chars, 300 tokens |
| `verbose` | `plain` | `PLAIN_VERBOSE` below | 1,273 chars, 353 tokens |

`PLAIN_TERSE`, from `FR-15`:

```
Replies stay brief and plain; artifacts full and technical. Define a technical term on first use.
Never omit which checks ran or were skipped, assumptions, deviations, or a Done when command's output.
```

`PLAIN_VERBOSE`, from `FR-17`:

```
Replies stay plain; artifacts full and technical. Define a technical term on first use.
Never omit which checks ran or were skipped, assumptions, deviations, or a Done when command's output.
```

Neither carries the pointer sentence, "Say what changed, where it is, and what needs a decision".
It does not fit in either form. Giving it up rather than the exemption list is `FR-15`, and it is a
decision, not an oversight. Do not add it back.

---

## Task 1: Declare the key and move the schema version

**Story:** S-01
**Files:**
- Modify: `templates/profile.schema.json`
- Modify: `bin/keel`
- Modify: `tests/validate-skills.sh`
- Modify: `templates/keel-profile.example.json`
- Modify: `.keel/profile.json` (this repository's own, because keel dogfoods itself)
- Modify: `docs/profile-keys.md` (regenerated; task 2's deliverable, folded in during execution)

**Interfaces:**
- Produces: `conventions.explain_level`, enum `["technical", "plain"]`, default `"technical"`,
  consumed by tasks 2, 3 and 4.
- Produces: `SCHEMA_VERSION=2` in `bin/keel`, and the fingerprint `24e947eee3ce` recorded for it.

**Done when:** `tests/validate-skills.sh` reports no schema fingerprint finding and
`tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

In `tests/test-keel.sh`, immediately after the `init writes conventions.response_style=terse`
assertion at `:1533-1539`, add:

```bash
# explain_level is written explicitly for the same reason response_style is: technical is what a
# project gets without asking, so the key that changes it has to be visible in the file the reader
# already opens.
python3 -c "
import json,sys
c=json.load(open('$d/.keel/profile.json')).get('conventions',{})
sys.exit(0 if c.get('explain_level')=='technical' else 1)" \
  && ok "init writes conventions.explain_level=technical" \
  || bad "explain_level" "init did not write technical"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL, `explain_level: init did not write technical`. The validator also fails, with
`templates/profile.schema.json changed its field set` once step 3 edits the schema; that is the
second half of this task and is expected until step 3 finishes.

**Deviation, found during execution on 2026-08-18 and settled by the requester.**
`tests/test-keel.sh:1562-1567` asserted `schema_version == 1` on a freshly initialised profile,
under the name `writing context_window did not move schema_version`. The name describes a real
non-behaviour; the implementation pinned a version literal, so it was unsatisfiable by any
legitimate bump and it blocked `FR-11`. Proved both halves before changing anything: with
`SCHEMA_VERSION=1` the validator fails with `changed its field set (fingerprint 24e947eee3ce,
expected 2128b5ddbcc7)`, so the bump is mandatory, not a preference. The assertion was rewritten to
pin the fact it names, that `gates.context_window` is schema-declared and therefore never needed a
bump, and was checked falsifiable by deleting the key and watching it fail. This edits a test the
context-window work shipped, which is why it was put to the requester as a choice rather than
absorbed.

- [x] **Step 3: Write the minimal implementation**

In `tests/test-keel.sh`, replace the assertion at `:1562-1567` as described in the deviation above.

In `templates/profile.schema.json`, inside `properties.conventions.properties`, immediately after
the `response_style` block:

```json
        "explain_level": {
          "enum": [
            "technical",
            "plain"
          ],
          "default": "technical",
          "description": "technical assumes the vocabulary of the thing being described; plain has chat replies define a technical term the first time they use it. It changes replies only: artifacts stay technical whatever this says, and the SessionStart hook picks its injected paragraph from this key and response_style together. Absent is treated as technical."
        }
```

In `bin/keel`, at `:36`:

```bash
SCHEMA_VERSION=2
```

In `bin/keel` at `:387`, extend the conventions line, and extend the comment above it at `:384-386`
to name both keys:

```bash
      # response_style and explain_level are written explicitly rather than left absent and
      # defaulted. Terse and technical are what a project gets without asking, so the keys that
      # change them have to be visible in the file the reader already opens, not things they must
      # first learn exist. "verbose" and "plain" are the opt-ins.
      printf '  "conventions": { "commit_style": "conventional", "default_branch": "%s", "protect_default_branch": true, "response_style": "terse", "explain_level": "technical" },\n' "$(default_branch)"
```

In `tests/validate-skills.sh`, in `schema_fingerprint_for` at `:69-71`, add a line and leave the
version 1 line exactly as it is:

```bash
    case "$1" in
        1) printf '2128b5ddbcc7' ;;
        2) printf '24e947eee3ce' ;;
    esac
```

In `templates/keel-profile.example.json`, in the `conventions` block at `:44-50`, after
`"response_style": "terse",`:

```json
    "explain_level": "technical",
```

In `.keel/profile.json`, this repository's own profile, set `"schema_version": 2` and add
`"explain_level": "technical"` to `conventions`. keel dogfoods itself, and the `_note` in that file
says it is written by hand. Skipping it ships a keel whose own `keel doctor` reports the repository
it lives in as carrying a stale profile, which is the one repository nobody would think to check.
No test asserts this, which is exactly why it is easy to miss.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS, `init writes conventions.explain_level=technical`.

Run: `tests/validate-skills.sh`
Expected: no `schema fingerprint` finding. If it reports a fingerprint other than `24e947eee3ce`,
the schema edit added or moved a key path beyond the intended one. Do not paste the reported value
over the `2) ` line without finding out what else changed.

Then run the full suite: `tests/run-tests.sh`. Nothing else may break.

- [x] **Step 5: Commit**

```bash
git add templates/profile.schema.json bin/keel tests/validate-skills.sh \
        templates/keel-profile.example.json tests/test-keel.sh .keel/profile.json \
        docs/profile-keys.md
git commit -m "feat(profile): conventions.explain_level, technical by default"
```

---

## Task 2: The reference page picks the key up

**Story:** S-03
**Files:**
- Modify: `docs/profile-keys.md` (regenerated, not hand-edited)

**Interfaces:**
- Consumes: `conventions.explain_level` from task 1.
- Produces: nothing new. The page is generated output.

**Done when:** `tests/test-profile-keys.sh` passes with no key missing a row, and
`tests/run-tests.sh` is green.

- [x] **Step 1: There is no new test for this**

`tests/validate-skills.sh` already asserts that the committed `docs/profile-keys.md` agrees with the
schema, and task 1 changed the schema. That assertion is the failing test and it is already written.

**Corrected during execution on 2026-08-18.** This step originally named
`tests/test-profile-keys.sh:31-46`. That suite generates a page into a temporary directory and
checks the generator against it, so it passes whether or not the committed page is stale: it tests
the generator, not the artifact. The check that fails on a stale committed page is the validator's
drift rule. Verified by running both against the schema change before regenerating.

- [x] **Step 2: Run it and watch it fail** (witnessed)

Run: `tests/validate-skills.sh`
Expected: FAIL, `docs/profile-keys.md disagrees with templates/profile.schema.json: no row for
conventions.explain_level`.

Run: `tests/test-profile-keys.sh`
Expected: PASS, all 9 assertions, for the reason in step 1. Record that rather than claiming a
failure you did not see.

- [x] **Step 3: Write the minimal implementation**

Regenerate the page. The generator reads the schema, so there is no code to change:

```bash
bash tests/generate-profile-keys.sh > docs/profile-keys.md
```

Confirm the new row landed and reads from the schema description:

```bash
/usr/bin/grep -n 'conventions.explain_level' docs/profile-keys.md
```

Expected: one row, `| `conventions.explain_level` | one of: `technical`, `plain` | `keel init` | ...`.
If the third column says **you** rather than `keel init`, task 1's `bin/keel` edit did not land and
the generator is right about it.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/validate-skills.sh`
Expected: `OK 24 skills validated`, with no drift finding.

Run: `tests/test-profile-keys.sh`
Expected: PASS on all 9 assertions, including `two runs produce identical bytes`.

Then run the full suite: `tests/run-tests.sh`.

- [x] **Step 5: Commit, together with task 1**

**Corrected during execution on 2026-08-18.** This was a separate commit. It is not, because
`tests/validate-skills.sh` fails on the tree between task 1 and this one: the schema and the page it
generates are enforced to move together, so a commit carrying only the schema leaves the repository
red by its own validator. Files that change together belong together, and task 1's `Done when:`
could not otherwise hold.

The commit is task 1's, with `docs/profile-keys.md` added to it.

---

## Task 3: The hook selects from both dials

**Story:** S-04, S-05
**Files:**
- Modify: `hooks/session-start`
- Modify: `tests/test-session-start.sh`

**Interfaces:**
- Consumes: `conventions.explain_level` from task 1.
- Produces: the four injected forms in the table above, consumed by tasks 4 and 5.

**Done when:** `tests/test-session-start.sh` passes with all four combination cases green, and
`tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

In `tests/test-session-start.sh`, replace the `fixture` helper at `:25-33` so it can write both
keys, and replace the `check` helper at `:46-64` so it matches a named form rather than the
substring `Replies stay brief`. That substring now matches two different paragraphs, so the old
helper would pass while asserting nothing:

```bash
# A profile carrying the two keys. Either may be empty, meaning the key is absent.
fixture() {   # fixture <root> <response_style-or-empty> <explain_level-or-empty>
    local root="$1" style="$2" level="$3" body=""
    mkdir -p "$root/.keel"
    [ -n "$style" ] && body="\"response_style\": \"$style\""
    if [ -n "$level" ]; then
        [ -n "$body" ] && body="$body, "
        body="$body\"explain_level\": \"$level\""
    fi
    printf '{\n  "conventions": {%s}\n}\n' "$body" > "$root/.keel/profile.json"
}

# `want` names which of the four forms is expected: brief, plain-terse, plain-verbose, or none.
# Matching a named form rather than a substring is load bearing. "Replies stay brief" is a prefix of
# both the brevity paragraph and the terse-plus-plain one, so a substring check passes whichever of
# the two the hook picked, which is precisely the bug this file exists to catch.
check() {   # check <name> <root> <want: brief|plain-terse|plain-verbose|none>
    local name="$1" root="$2" want="$3" out got
    if ! out="$(context_of "$root")"; then
        bad "$name" "hook did not emit valid JSON"
        return 0
    fi
    case "$out" in
        *"pick a skill"*) ;;
        *) bad "$name" "the routing text is missing"; return 0 ;;
    esac
    case "$out" in
        *"Replies stay brief and plain"*)               got=plain-terse ;;
        *"Replies stay plain"*)                         got=plain-verbose ;;
        *"Replies stay brief; artifacts stay full"*)    got=brief ;;
        *)                                              got=none ;;
    esac
    if [ "$got" = "$want" ]; then ok "$name"
    else bad "$name" "expected the $want form, got $got"; fi
}
```

Then replace cases 1 to 6 at `:66-101` with the four combinations plus the existing edge cases,
keeping every comment that explains why a case is there:

```bash
# 1. Both keys absent. Existing projects get the documented defaults without re-running init.
fixture "$tmp/a" "" ""
check "no keys at all is terse and technical" "$tmp/a" brief

# 2. The written defaults.
fixture "$tmp/b" "terse" "technical"
check "terse and technical injects the brevity rule" "$tmp/b" brief

# 3. The length opt-out, unchanged by this work.
fixture "$tmp/c" "verbose" "technical"
check "verbose and technical injects nothing" "$tmp/c" none

# 4. The vocabulary opt-in, on the default length. This is the combination the feature is for.
fixture "$tmp/g" "terse" "plain"
check "terse and plain injects the plain rule with the brevity rule" "$tmp/g" plain-terse

# 5. Both dials moved. It must have a paragraph rather than falling through to silence, which is
# what a hook keyed on one variable at a time would do.
fixture "$tmp/h" "verbose" "plain"
check "verbose and plain injects the plain rule alone" "$tmp/h" plain-verbose

# 6. explain_level alone, with response_style absent and therefore terse.
fixture "$tmp/i" "" "plain"
check "explain_level alone is read, and response_style defaults to terse" "$tmp/i" plain-terse

# 7. An unrecognised value falls back to the documented default rather than to silence.
fixture "$tmp/j" "terse" "simple"
check "an unrecognised explain_level is treated as technical" "$tmp/j" brief

# 8. No profile at all. A session outside a keel project must still start.
mkdir -p "$tmp/d"
check "no profile still emits valid JSON and the router pointer" "$tmp/d" brief

# 9. The hook runs from a subdirectory as readily as the root, the way sensitive-guard does. A
# session started in src/ is ordinary and must not silently lose the rule.
fixture "$tmp/e" "verbose" "plain"
mkdir -p "$tmp/e/src/deep"
check "the profile is found from a subdirectory" "$tmp/e/src/deep" plain-verbose

# 10. An unreadable profile must degrade to the defaults, not take the whole injection down with
# it. Found by review before the first ship: `set -e` plus the read being the last command in an &&
# chain meant the hook exited 1 and printed nothing, so the session lost the router pointer entirely
# and the failure looked like the plugin was not installed.
#
# Skipped as root, which can read a 000 file, so the case would pass while testing nothing.
if [ "$(id -u)" -eq 0 ]; then
    printf '  SKIP  unreadable profile degrades to the defaults (running as root)\n'
else
    fixture "$tmp/f" "verbose" "plain"
    chmod 000 "$tmp/f/.keel/profile.json"
    check "an unreadable profile degrades to terse and technical" "$tmp/f" brief
    chmod 644 "$tmp/f/.keel/profile.json"
fi
```

Add the exact-size assertions after case 10, before the existing prefix bound at `:104-125`:

```bash
# The four forms are asserted at their exact measured sizes, not as an upper bound. NFR-01 caps
# every combination at 1285 characters and the wordings were chosen against that, so a wording edit
# has to be a deliberate act with a re-measurement rather than a drift that stays green until it
# does not.
size_of() {   # size_of <root>
    ( cd "$1" && "$HOOK" ) 2>/dev/null | wc -c | tr -d ' '
}
for spec in "b:1284:terse and technical" "g:1279:terse and plain" \
            "c:1082:verbose and technical" "h:1269:verbose and plain"; do
    d="${spec%%:*}"; rest="${spec#*:}"; want="${rest%%:*}"; label="${rest#*:}"
    got="$(size_of "$tmp/$d")"
    if [ "$got" = "$want" ]; then
        ok "$label injects exactly $want characters"
    else
        bad "size" "$label injects $got characters, expected $want. NFR-01 caps every form at 1285"
    fi
done
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-session-start.sh`
Expected: FAIL. Cases 4, 5 and 6 report `expected the plain-terse form, got brief` or
`expected the plain-verbose form, got none`, and the size loop reports the two plain forms at the
wrong character counts. Cases 1, 2, 3, 8, 9 and 10 pass, because they assert behaviour that already
exists.

- [x] **Step 3: Write the minimal implementation**

In `hooks/session-start`, extend the bound stated in the header comment at `:9-14`, since the hook
now reads two keys:

```bash
# THE ONE EXCEPTION, AND ITS BOUND. It reads `conventions.response_style` and
# `conventions.explain_level` from the project profile. That is a file that changes, which the rule
# above forbids, so the bound matters: the output has exactly four forms, and it moves between them
# only when a person deliberately edits a key. That costs one cache miss on the session after the
# edit, the same as editing CLAUDE.md, rather than one per request. A key read for its value would
# be volatile; a key read for which of four paragraphs to print is not.
```

Add the two paragraphs beside `BREVITY` at `:44-48`, leaving `BREVITY` byte-identical:

```bash
read -r -d '' PLAIN_TERSE <<'TXT' || true

Replies stay brief and plain; artifacts full and technical. Define a technical term on first use.
Never omit which checks ran or were skipped, assumptions, deviations, or a Done when command's output.
TXT

read -r -d '' PLAIN_VERBOSE <<'TXT' || true

Replies stay plain; artifacts full and technical. Define a technical term on first use.
Never omit which checks ran or were skipped, assumptions, deviations, or a Done when command's output.
TXT
```

Replace the single `case` at `:60-73` with the two-dial selection. Keep the `-r` test and the
comment explaining it, both of which are load bearing:

```bash
# Terse and technical unless the project asked otherwise. Absent profile, absent key, unreadable
# file and an unrecognised value all mean the defaults, because that is what the schema documents
# and a hook is not the place to report a bad profile.
#
# The `-r` test is load bearing and was added after review caught it. This script runs under
# `set -e`, and the assignment is the last command in the chain, so a read that fails takes the
# whole hook down: exit 1, nothing on stdout, and the session loses the router pointer entirely
# rather than just the paragraph. A 000-mode profile is rare; a session that silently looks like
# keel is not installed is expensive.
#
# Four combinations, four outcomes, and the silent one is deliberate: verbose plus technical is the
# project that asked for neither rule.
style_text=""
[ -n "$profile" ] && [ -r "$profile" ] && style_text="$(<"$profile")"

verbose=no
case "$style_text" in
    *'"response_style": "verbose"'*|*'"response_style":"verbose"'*) verbose=yes ;;
esac

plain=no
case "$style_text" in
    *'"explain_level": "plain"'*|*'"explain_level":"plain"'*) plain=yes ;;
esac

if [ "$plain" = yes ]; then
    if [ "$verbose" = yes ]; then CONTEXT="$CONTEXT$PLAIN_VERBOSE"
    else CONTEXT="$CONTEXT$PLAIN_TERSE"; fi
elif [ "$verbose" = no ]; then
    CONTEXT="$CONTEXT$BREVITY"
fi
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-session-start.sh`
Expected: PASS on every case, including the four exact sizes. If a size is off by a few characters,
the paragraph was retyped rather than copied. Copy it from the table at the top of this plan; the
counts were measured from those exact bytes.

Run: `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`
Expected: no findings. Default severity, so info and style findings fail too.

Then run the full suite: `tests/run-tests.sh`.

- [x] **Step 5: Commit**

```bash
git add hooks/session-start tests/test-session-start.sh
git commit -m "feat(hook): pick the injected paragraph from both response_style and explain_level"
```

---

## Task 4: The budget check covers every combination

**Story:** S-06
**Files:**
- Modify: `tests/validate-skills.sh`
- Modify: `tests/test-validate-skills.sh`

**Interfaces:**
- Consumes: the four forms from task 3.
- Produces: nothing consumed by a later task.

**Done when:** `tests/validate-skills.sh` reports no size finding against this repository, and
`tests/test-validate-skills.sh` passes including the new case.

- [x] **Step 1: Write the failing test**

In `tests/test-validate-skills.sh`, beside the existing schema fingerprint cases, add a case
proving the size check notices a combination other than the repository's own. Follow the fixture
idiom the file already uses for its other cases:

This file drives every case through `run_out <name> <expected-rc> <fixture-fn> <needle>
<want-present>`, defined at `:116-123`. Follow that idiom rather than writing a bare case, so the
new check is reported the same way as its neighbours:

```bash
# The size check ran the hook once, from the repository root, so it measured whichever form this
# repository's own profile selects and nothing else. A paragraph that fits terse and technical while
# breaking verbose and plain would have shipped green. This fixture is what says otherwise: its hook
# is small for every combination except verbose plus plain.
m_hook_one_combo_oversized() {
    mkdir -p "$1/hooks"
    cat > "$1/hooks/session-start" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
text="short"
case "$(cat .keel/profile.json 2>/dev/null || true)" in
    *'"response_style": "verbose"'*)
        case "$(cat .keel/profile.json 2>/dev/null || true)" in
            *'"explain_level": "plain"'*) text="$(head -c 1500 /dev/zero | tr '\0' 'x')" ;;
        esac ;;
esac
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$text"
HOOK
    chmod +x "$1/hooks/session-start"
}
run_out "a combination over the ceiling is reported, not just the local one" 1 \
    m_hook_one_combo_oversized "response_style=verbose explain_level=plain" yes
```

`fixture_valid` builds the rest of the tree, so the fixture function only writes the hook. The
needle is the exact phrase the validator's message must carry, which is what makes the finding
name the offending combination rather than just saying the hook is too big.

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-validate-skills.sh`
Expected: FAIL on `a combination over the ceiling is reported, not just the local one`. The
validator measures only the form the fixture's own profile selects, so the oversized `verbose` plus
`plain` form is never produced and never seen, the validator exits 0, and the expected rc of 1 is
not met.

- [x] **Step 3: Write the minimal implementation**

In `tests/validate-skills.sh`, replace the single measurement at `:281-285` with a loop over the
four combinations. It writes each profile into a temporary directory rather than editing the
repository's own, because a check that mutates the repository it is checking is a check nobody
trusts:

```bash
    # Doc 05 budgets this at 250 tokens, 400 hard, and NFR-01 of docs/prd/plain-language-chat.md
    # tightens it to 356 for every combination. Estimated at chars/3.6, the same way doctor sizes
    # the CLAUDE.md block, because a count-tokens call needs an API key and a check that only runs
    # where a key happens to exist is absent exactly where nobody is watching.
    #
    # All four combinations, not just the one this repository's profile selects. Measuring only the
    # local configuration is how a paragraph that fits terse and technical reaches a release while
    # breaking verbose and plain.
    hook_abs="$PWD/hooks/session-start"
    probe="$(mktemp -d)"
    mkdir -p "$probe/.keel"
    # Split with parameter expansion rather than `set --`. This is top level, not a function, so
    # `set --` would clobber the script's own positional parameters, and it needs an unquoted
    # expansion that shellcheck is right to flag.
    for combo in "terse technical" "terse plain" "verbose technical" "verbose plain"; do
        rs="${combo%% *}"; el="${combo##* }"
        printf '{"conventions": {"response_style": "%s", "explain_level": "%s"}}\n' "$rs" "$el" \
            > "$probe/.keel/profile.json"
        hook_chars=$( cd "$probe" && bash "$hook_abs" 2>/dev/null | wc -c | tr -d ' ' )
        hook_tokens=$(( hook_chars * 10 / 36 ))
        if [ "$hook_tokens" -gt 400 ]; then
            report "hooks/session-start injects about $hook_tokens tokens for response_style=$rs explain_level=$el, over the 400 ceiling. It is in every request of every session."
        elif [ "$hook_tokens" -gt 356 ]; then
            report "hooks/session-start injects about $hook_tokens tokens for response_style=$rs explain_level=$el, over the 356 rule in docs/prd/plain-language-chat.md NFR-01. The 44 tokens below the 400 ceiling are spoken for."
        fi
    done
    rm -rf "$probe"
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-validate-skills.sh`
Expected: PASS on `a combination over the ceiling is reported, not just the local one`, and every
existing case still green.

Run: `tests/validate-skills.sh`
Expected: no size finding. The four real forms measure 356, 355, 300 and 352 tokens.

Run: `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`
Expected: no findings.

Then run the full suite: `tests/run-tests.sh`.

- [x] **Step 5: Commit**

```bash
git add tests/validate-skills.sh tests/test-validate-skills.sh
git commit -m "test(budget): size the session prefix for all four dial combinations"
```

---

## Task 5: The token design document records four forms

**Story:** S-07
**Files:**
- Modify: `docs/05-token-and-memory-design.md`

**Interfaces:**
- Consumes: the measured sizes from task 3.
- Produces: nothing consumed by a later task.

**Done when:** `tests/test-doc-claims.sh` passes and `tests/run-tests.sh` is green.

- [x] **Step 1: There is no new test for this**

This task is a documentation correction. `tests/test-doc-claims.sh` already runs against this file
and is the check that it does not contradict the code. Inventing an assertion that the prose
contains four numbers would pin the wording rather than the claim, and would fail on the next
sentence anybody rewrites.

- [x] **Step 2: Run it and watch it fail** (witnessed as a PASS, not a failure: see the step text)

Run: `tests/test-doc-claims.sh`
Expected: PASS. It passes before this task and after it, because the figures it checks are not the
ones this task edits. Record that in the tick note rather than claiming a failure you did not see.

- [x] **Step 3: Write the minimal implementation**

In `docs/05-token-and-memory-design.md`, replace the sentence at `:272-274` that describes two
forms:

```markdown
**The rule is on by default and it is not free.** `hooks/session-start` selects one paragraph from
`conventions.response_style` and `conventions.explain_level` together, so there are four forms and
not two:

| `response_style` | `explain_level` | Injected | Tokens |
|---|---|---|---|
| `terse` | `technical` | the brevity paragraph | 356 |
| `terse` | `plain` | brevity and define-on-first-use | 355 |
| `verbose` | `technical` | nothing | 300 |
| `verbose` | `plain` | define-on-first-use | 352 |

The defaults cost 356 against a 250 target and a 400 ceiling. That is 56 tokens of input in every
request of every session, spent to shorten output in some of them, and the direction of that trade
has never been measured. It was taken as an explicit instruction on 2026-08-16, not as an inference,
and it is recorded here rather than buried because the 44 tokens of remaining headroom are now the
tightest budget in this document. `docs/prd/plain-language-chat.md` `NFR-01` holds every combination
at or under 356 for exactly that reason, and `tests/validate-skills.sh` measures all four.
```

Leave the figures at `:72`, `:78` and `:318` alone. They describe the default configuration, which
is still 356.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-doc-claims.sh`
Expected: PASS.

Confirm the four figures match reality rather than the plan:

```bash
# HOOK is resolved before the cd. Expanding $PWD inside the subshell would resolve it after, which
# points at the temporary directory and measures nothing.
HOOK="$PWD/hooks/session-start"
for s in terse verbose; do for l in technical plain; do
  d=$(mktemp -d); mkdir -p "$d/.keel"
  printf '{"conventions":{"response_style":"%s","explain_level":"%s"}}\n' "$s" "$l" > "$d/.keel/profile.json"
  c=$( cd "$d" && bash "$HOOK" 2>/dev/null | wc -c | tr -d ' ' )
  printf '%s %s: %s chars, %s tokens\n' "$s" "$l" "$c" "$(( c * 10 / 36 ))"
  rm -rf "$d"
done; done
```

Expected: `terse technical: 1284 chars, 356 tokens`, `terse plain: 1279 chars, 355 tokens`,
`verbose technical: 1082 chars, 300 tokens`, `verbose plain: 1269 chars, 352 tokens`. If any figure
differs, the document is wrong and the table above must be corrected to what the hook actually
produces, not the reverse.

Then run the full suite: `tests/run-tests.sh`.

- [x] **Step 5: Commit**

```bash
git add docs/05-token-and-memory-design.md
git commit -m "docs(tokens): record all four session prefix forms"
```

---

## Task 6: Prove nothing else moved

**Story:** S-08
**Files:**
- Modify: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `SCHEMA_VERSION=2` from task 1.
- Produces: nothing.

**Done when:** `tests/test-keel.sh` passes including the new doctor assertion, and
`tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

In `tests/test-keel.sh`, beside the other doctor assertions, add:

Place it in the doctor section that starts at `:979`, and follow that section's idiom: build a
fixture, run `keel init` in it, then run `"$KEEL" doctor`. `KEEL` is defined at `:15`.

```bash
# FR-16: doctor says nothing about explain_level. The schema drift message is the whole mechanism
# for getting the key into an existing project, and a nudge for an optional preference key would
# print on every run of every project that is content with the default, which is most of them.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
out="$( cd "$d" && "$KEEL" doctor 2>&1 )"
case "$out" in
    *explain_level*) bad "doctor" "doctor named explain_level; FR-16 says the drift message is the whole mechanism" ;;
    *) ok "doctor says nothing about explain_level" ;;
esac
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: PASS, because nothing has been written that would name the key. This assertion pins an
absence, so it passes on the day it is written and earns its keep the day somebody adds a nudge.
Record that in the tick note rather than claiming a failure you did not see.

To confirm it can fail, add a `warn "conventions.explain_level is unset"` line **inside
`cmd_doctor`**, at `bin/keel:1175` just above the `[ -f .keel/profile.json ]` guard, run doctor
against an initialised fixture, watch the case report `doctor named explain_level`, then restore
`bin/keel` and confirm `git diff --stat bin/keel` is empty. Do not commit that line.

**Corrected during execution on 2026-08-18.** The first attempt inserted a bare `printf` next to the
`cmd_doctor()` definition rather than inside its body, and doctor's output was unchanged, so the
check proved nothing about the assertion. A falsifiability check that does not falsify is worse than
none: it reads as proof. The instruction now names the line and the enclosing function, and requires
watching the restore as well as the failure.

- [x] **Step 3: Write the minimal implementation**

There is none. This task asserts that no implementation exists.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS, `doctor says nothing about explain_level`.

Then confirm the diff touched nothing it must not, which is the other half of `FR-14`:

**Corrected during execution on 2026-08-18.** These originally compared against `main...HEAD`.
`main` is behind `sandbox` by the whole of the previous release's work, so that range conflates this
change with everything else awaiting a pull request and the check reads as a large unexplained diff.
Compare against the commit this work branched from instead:

```bash
base=f9cdb03    # the merge of PR #29, which is where this work starts
git diff --stat "$base"..HEAD -- skills/ output-styles/
```

Expected: empty output. Any file listed under `skills/` or `output-styles/` is scope nobody agreed
to, and `S-08`'s notes say it comes back as a `fix` story rather than being quietly kept.

```bash
git diff --stat "$base"..HEAD -- templates/
```

Expected: exactly two files, `templates/profile.schema.json` and
`templates/keel-profile.example.json`.

Then run the full suite: `tests/run-tests.sh`.

- [x] **Step 5: Commit**

```bash
git add tests/test-keel.sh
git commit -m "test(doctor): pin that explain_level gets no doctor output"
```

---

## Task 7: Update the changelog and the README

**Story:** none. This is release hygiene, not a story, and it is named as such rather than being
traced to a story it does not serve.
**Files:**
- Modify: `CHANGELOG.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: everything above.
- Produces: nothing.

**Done when:** `tests/run-tests.sh` is green, which includes `tests/test-doc-claims.sh` and
`tests/no-internal-leaks.sh` against both files.

- [x] **Step 1: There is no test for this**

This task is release documentation. `tests/test-doc-claims.sh` and `tests/no-internal-leaks.sh`
already run against both files and are the only automatable checks that apply.

- [x] **Step 2: Run them and watch them pass** (witnessed: 5 passed, 0 failed, before the edit)

Run: `tests/test-doc-claims.sh`
Expected: PASS, before the edit.

- [x] **Step 3: Write the minimal implementation**

In `CHANGELOG.md`, under the unreleased heading:

```markdown
### Added

- `conventions.explain_level`, `technical` by default. Set it to `plain` and chat replies define a
  technical term the first time they use it. Artifacts are unaffected: a PRD, plan or ADR stays as
  technical as its skill requires. `keel init` writes the key, and the SessionStart hook picks its
  paragraph from this key and `response_style` together, so all four combinations are configured.

### Changed

- `SCHEMA_VERSION` moves to 2. Existing projects will see `keel doctor` report the profile as older
  than the installed keel. Re-run `keel init` to pick the key up; it merges, so your own values
  survive.
```

In `README.md`, in the "Replies are short by default" section, after the paragraph at `:69-70`
that ends "so this applies without re-running `init`", add a subsection:

```markdown
### Replies can be plain as well as short

Length and vocabulary are separate dials. Where somebody who is not a developer reads the replies,
set `plain` in `.keel/profile.json`:

```json
"conventions": { "explain_level": "plain" }
```

A plain reply defines a technical term the first time it uses it, rather than swapping it for a
simpler word: the reply still has to point at an artifact that uses the real term. `technical` is
the default and is what `keel init` writes. This changes replies only. Artifacts stay technical
whatever it says, and it composes with `response_style`, so all four combinations are valid.
```

Note the nested fence: the JSON block inside the added section needs the surrounding markdown to
keep its own fencing intact. Check the rendered file after the edit.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/run-tests.sh`
Expected: green, including `tests/test-doc-claims.sh` and `tests/no-internal-leaks.sh`.

- [x] **Step 5: Commit**

```bash
git add CHANGELOG.md README.md
git commit -m "docs(release): record explain_level and the schema version bump"
```

---

## Story coverage

| Story | Kind | Tasks |
|---|---|---|
| S-01 Declare the key and move the schema version | build | 1 |
| S-02 `keel init` writes the key | build | 1 |
| S-03 The generated reference gains a row | build | 2 |
| S-04 Four combinations, one determined output each | build | 3 |
| S-05 The two plain paragraphs, inside the budget | build | 3 |
| S-06 The size check covers every combination | build | 4 |
| S-07 Doc 05 records the four measured sizes | build | 5 |
| S-08 Nothing outside the hook, the schema and the docs changes | verify | 6 |

Every story maps to at least one task. Task 7 maps to no story and says so.

S-02 is folded into task 1 rather than given its own: the `bin/keel` edit and the schema edit are
one reviewable change, and splitting them would leave task 1 declaring a key that `keel init` does
not write, which fails `tests/test-keel.sh` until the next task lands.

S-04 and S-05 share task 3 for the same reason. Splitting the branch from the text it selects would
leave a task whose `Done when:` cannot pass, because the branches would select paragraphs that do
not exist yet.

## What this plan could not settle

Nothing blocks execution. Two items are recorded rather than hidden:

- **`Q7` in the PRD is answered but overrulable.** This work pays for a `SCHEMA_VERSION` bump, which
  makes declaring `artifacts._note` free, and `docs/prd/usable-profile.md` left it undeclared partly
  on that cost. The other half of its reasoning still holds, at `tests/test-profile-keys.sh:49-50`:
  it is a note to the reader rather than a key anyone sets. It stays out of scope. If that is
  overruled, it belongs in task 1 and nowhere else, because a later bump costs version 3.
- **`A1` and `A2` in the PRD stay unchecked forever, by decision.** Nobody is measuring whether keel
  influences reply vocabulary, and no instance of a non-technical reader has been named. This plan
  builds the mechanism the PRD specifies and cannot tell you whether it works.


## Post-review corrections, 2026-08-18

`review-code` ran after task 7, with the `code-review` plugin as the correctness pass. Both passes
independently found the same blocking defect. Five findings were fixed in a follow-up commit rather
than by amending the task commits, so the review and its outcome stay legible in the history.

| # | Where | What was wrong |
|---|---|---|
| 1 | `hooks/session-start` | Both plain paragraphs replaced "artifacts stay full" with "artifacts stay technical". Those answer different questions, and the first is the only thing in the injected context exempting artifacts from the brevity rule. A `terse` plus `plain` session carried "Replies stay brief and plain" with nothing saying a PRD is exempt. The PRD costed out losing the pointer sentence and never mentioned this, so it was a slip. Restoring it cost 4 characters, well inside `NFR-01` |
| 2 | `tests/validate-skills.sh` | `mktemp -d` was unguarded. On failure `probe` is empty and `cd ""` returns 0, so the loop would measure this repository's own profile four times and report green, defeating the check `NFR-02` added. Separately there was no floor, so a hook that fails to run measured 0 tokens and passed |
| 3 | `tests/test-keel.sh` | The `FR-16` assertion ran doctor only on a freshly initialised profile, already at the current schema version, so the drift branch never executed. A nudge added inside the drift message would have passed it, which is the one place the comment says it guards |
| 4 | `docs/07-open-decisions.md` | Described the mechanism as one key |
| 5 | `CHANGELOG.md` | Added a second `### Added` and `### Changed` to a release section that already had both, so the older prose read as though it sat under the new headings |

Findings 2 and 3 are both the same species: a check that cannot fail for the reason it claims. Two
of the three tests written for this feature had that defect, and one of them was a falsifiability
check written specifically to prevent it.
