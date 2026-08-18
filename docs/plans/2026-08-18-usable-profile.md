# Usable profile Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go, on output you read.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness, or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** every profile key is described and discoverable in one generated page that cannot drift,
and `keel init` records the plugins a project expects so `keel doctor` can report what is missing.

**Stories:** S-01 to S-13
**PRD:** `docs/prd/usable-profile.md`, approved 2026-08-18
**ADRs:** none. ADR-0001 governs skill body length and no skill is touched.
**Architecture:** one new script, one new generated page, and edits to four existing files. No new
component and no boundary, which is why there is no architecture document.

## Global constraints

Copied in full rather than linked, because a task executed by a fresh agent that reads only its own
section must still obey them.

- Verify commands, from `.keel/profile.json`:
  - test: `tests/run-tests.sh`
  - one test: `tests/{name}`, for example `tests/test-keel.sh`
  - lint: `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`
  - format, typecheck, build, e2e, security: `null`. There is no such command. Do not invent one.
- Never start on `main`. This work belongs on `sandbox`.
- Conventional commit messages. **No `Co-Authored-By` trailer, no robot emoji, no generated-by
  footer.** Title and body only.
- No em dash, en dash, or any dash longer than a hyphen, anywhere: code, comments, commit messages,
  documentation.
- **No project-specific identifiers.** `tests/no-internal-leaks.sh` refuses a client name, a
  partner name, a repository name or an absolute home path. It caught five on the previous change.
  Examples use `payments-api`, "a partner bank", `PROD-042-requirements.md`.
- `SCHEMA_VERSION` does not move. The validator fingerprints key **paths** and not descriptions
  (`tests/validate-skills.sh:364-372`), so writing descriptions is free. Declaring `artifacts._note`
  would add a path and force a bump, which is why FR-12 omits it instead.
- `tests/validate-skills.sh` is the fast check that runs on every commit. **It must not gain a
  `keel init` run.** Anything needing a real profile goes in `tests/test-keel.sh`, which already
  runs `init` 117 times.
- `hooks/session-start` is not touched by any task.
- `keel doctor` must still start `python3` at most ten times (`tests/test-keel.sh:405`, measured 8).

## Measurements this plan was written against

Taken 2026-08-18 at `5e2de35`, so a reader can tell when they have gone stale.

| Fact | Value |
|---|---|
| Leaf keys declared by the schema | 59 |
| Written by `keel init` | 48 |
| Human-only | 11 |
| Carrying no description | 35 |
| Keys constrained by `enum` with no `type` | 11 |
| Key set written by init, across empty, node and go fixtures | identical, 49 including `artifacts._note` |
| One `keel init -y` | about 1 second |
| `tests/test-keel.sh` | about 210 seconds |
| Full `tests/run-tests.sh` | about 300 seconds |

---

### Task 1: A script that generates the reference from the schema

**Story:** S-02, S-07
**Files:**
- Create: `tests/generate-profile-keys.sh`

**Interfaces:**
- Consumes: `templates/profile.schema.json`, and `bin/keel init` for the written-by-init column
- Produces: the page on stdout. Task 3 redirects it to `docs/profile-keys.md`. The row format is
  `| ` + backticked key + ` | ` + type + ` | ` + set-by + ` | ` + description + ` |`, which task 5
  parses

**Done when:** `tests/generate-profile-keys.sh` runs twice and produces identical bytes, and
`tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

Create `tests/test-profile-keys.sh`:

```bash
#!/usr/bin/env bash
# Tests for tests/generate-profile-keys.sh, which produces docs/profile-keys.md.
#
# The generator is the only thing standing between the schema and a reference page that would
# otherwise be written by hand and go stale. What is asserted here is that it covers every declared
# key, omits what the schema does not declare, and produces the same bytes twice.
#
# Run from the repository root.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GEN="$ROOT/tests/generate-profile-keys.sh"
pass=0
fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }

command -v python3 >/dev/null 2>&1 || { printf 'SKIP  python3 absent\n'; exit 0; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

bash "$GEN" > "$work/a.md" 2>"$work/err.txt"
rc=$?
[ "$rc" -eq 0 ] && ok "the generator exits 0" || bad "generator" "rc=$rc: $(head -3 "$work/err.txt")"

# Every declared leaf key gets a row. A generator that silently skips a key produces a reference
# that is wrong in the one way nobody checks: by omission.
missing="$(SCHEMA="$ROOT/templates/profile.schema.json" PAGE="$work/a.md" python3 -c "
import json, os, re
d = json.load(open(os.environ['SCHEMA']))
def declared(node, p=''):
    out = []
    for k, v in (node.get('properties') or {}).items():
        path = f'{p}.{k}' if p else k
        if isinstance(v, dict) and v.get('properties'): out += declared(v, path)
        else: out.append(path)
    return out
page = open(os.environ['PAGE']).read()
rows = set(re.findall(r'^\| \`([^\`]+)\` \|', page, re.M))
print(' '.join(sorted(set(declared(d)) - rows)))
")"
[ -z "$missing" ] && ok "every declared key has a row" \
  || bad "coverage" "no row for: $missing"

# artifacts._note is written by keel init and not declared by the schema. It is a note to the
# reader rather than a key anyone sets, and declaring it would cost a SCHEMA_VERSION bump.
grep -q 'artifacts._note' "$work/a.md" \
  && bad "omission" "artifacts._note appears; the schema does not declare it and FR-12 omits it" \
  || ok "a key the schema does not declare is omitted"

# Determinism is what makes the drift rule in validate-skills usable. A generator that varies
# produces a rule that fails at random, and a rule that fails at random gets disabled.
bash "$GEN" > "$work/b.md" 2>/dev/null
cmp -s "$work/a.md" "$work/b.md" && ok "two runs produce identical bytes" \
  || bad "determinism" "the generator is not reproducible"

# The check has to run where nobody is watching, so it cannot depend on a key existing.
env -u ANTHROPIC_API_KEY bash "$GEN" > "$work/c.md" 2>/dev/null
cmp -s "$work/a.md" "$work/c.md" && ok "the generator needs no API key" \
  || bad "offline" "output differed with ANTHROPIC_API_KEY unset"

grep -qE 'curl|wget|urllib|requests|socket' "$GEN" \
  && bad "offline" "the generator reaches the network" \
  || ok "the generator makes no network call"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

Then add it to `tests/run-tests.sh`, after the `run tests/test-context-watch.sh` line:

```bash
run tests/test-profile-keys.sh
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-profile-keys.sh`
Expected: FAIL on every assertion, because `tests/generate-profile-keys.sh` does not exist yet. The
first failure reads `generator: rc=127`.

- [x] **Step 3: Write the minimal implementation**

Create `tests/generate-profile-keys.sh`:

```bash
#!/usr/bin/env bash
# Generate docs/profile-keys.md from templates/profile.schema.json.
#
# The reference is generated rather than written because this repository has been bitten by profile
# drift twice, and a hand-written copy of 59 keys is a second thing to keep in step with the first.
# Generated, a stale page is a failing build rather than a wrong sentence.
#
# The "Set by" column comes from running `keel init` in a throwaway fixture rather than from a list
# maintained here. That list would drift the same way: it said twelve human-only keys until the
# context window work moved one of them, and nothing would have noticed.
#
# Deterministic by construction: no date, no path, no counter, nothing from the environment.
#
# Usage: tests/generate-profile-keys.sh > docs/profile-keys.md   (from the repository root)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# One init, about a second. The key set it writes is the same for every stack, checked against
# empty, node and go fixtures on 2026-08-18, so an empty fixture is enough and is the least
# arbitrary choice.
( cd "$work" && git init -q -b main . && "$ROOT/bin/keel" init -y >/dev/null 2>&1 )

SCHEMA="$ROOT/templates/profile.schema.json" PROFILE="$work/.keel/profile.json" python3 - <<'PY'
import json, os

schema = json.load(open(os.environ["SCHEMA"]))


def type_of(v):
    """What a reader needs to know they may put here.

    Eleven keys constrain by `enum` and carry no `type`. For those the allowed values are the
    useful answer: "one of: required, warn, off" tells a reader what to write, where "string"
    does not.
    """
    if v.get("enum"):
        return "one of: " + ", ".join("`%s`" % e for e in v["enum"])
    t = v.get("type", "")
    return (t if isinstance(t, str) else "/".join(t)) or "unconstrained"


def declared(node, p=""):
    out = []
    for k, v in (node.get("properties") or {}).items():
        path = "%s.%s" % (p, k) if p else k
        if isinstance(v, dict) and v.get("properties"):
            out += declared(v, path)
        else:
            out.append((path, type_of(v), (v.get("description") or "").strip()))
    return out


def leaves(o, p=""):
    s = set()
    if isinstance(o, dict):
        for k, v in o.items():
            s |= leaves(v, "%s.%s" % (p, k) if p else k)
    else:
        s.add(p)
    return s


written = leaves(json.load(open(os.environ["PROFILE"])))

print("# Profile keys")
print()
print("Every key `.keel/profile.json` may contain, what it does, and whether keel writes it.")
print()
print("Generated by `tests/generate-profile-keys.sh` from `templates/profile.schema.json`.")
print("Do not edit by hand: `tests/validate-skills.sh` fails when this file and the schema")
print("disagree, and names the command that regenerates it.")
print()
print("**Set by** is derived by running `keel init` against a throwaway fixture, so it cannot")
print("drift from what init actually writes. A key marked **you** is one keel never writes: it")
print("does nothing until a human adds it.")
print()
print("| Key | Type | Set by | Description |")
print("|---|---|---|---|")
for path, typ, desc in declared(schema):
    setby = "`keel init`" if path in written else "**you**"
    text = (desc or "_No description yet._").replace("|", "\\|")
    print("| `%s` | %s | %s | %s |" % (path, typ, setby, text))
PY
```

Then `chmod +x tests/generate-profile-keys.sh`.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-profile-keys.sh`
Expected: PASS, six assertions.
Then the linter, which covers `tests/*.sh`:
`shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`
Expected: clean.
Then `tests/run-tests.sh`. Expected: green.

- [x] **Step 5: Commit**

```bash
git add tests/generate-profile-keys.sh tests/test-profile-keys.sh tests/run-tests.sh
git commit -m "feat(docs): generate the profile key reference from the schema

A hand-written copy of 59 keys is a second thing to keep in step with the
first, and this repository has been bitten by profile drift twice. The
set-by column comes from a real keel init rather than a maintained list,
which is the part that would have gone stale silently."
```

---

## Deviations found while executing task 1

Recorded here rather than left as differences between the plan and what happened.

| What the plan said | What was true |
|---|---|
| Step 2 would "FAIL on every assertion" | Four of six passed **vacuously** against a missing generator: two empty outputs compare identical, and `grep` on a file that does not exist finds no network call. The real signals were `rc=127` and 59 missing rows. They were each proven to bite afterwards by mutating the generator three ways |
| The test code as written would lint | `shellcheck` refuses the `A && ok ... || bad ...` idiom under SC2015. The other suites carry a file-level `# shellcheck disable=SC2015` with a comment saying it is safe because both helpers `return 0`. Followed that rather than rewriting six assertions |
| Nothing about the supply chain scanner | `tests/supply-chain-scan.sh` flagged the assertion's own grep pattern, because a line that searches for `curl`, `wget`, `urllib`, `requests` and `socket` contains all five. Suppressed with a reason, **not** obfuscated: splitting the pattern into fragments to quieten the scanner is the instinct that scanner exists to catch |

The suppression took two attempts. The marker has to sit on the same line as the hit
(`tests/supply-chain-scan.sh:205-218`), and the first attempt put it on a continued line where the
scanner never saw it. The pattern is now a variable on its own line, which also let that one
assertion become a plain `if/else` and avoid SC2015 without the directive.

**A tighter expectation for the remaining tasks.** Where a task creates a file that does not exist
yet, "watch it fail" means watch the assertions that *can* fail do so, and prove the rest bite after
the subject exists. Stating "FAIL on every assertion" was wrong here and would be wrong again in
tasks 3 and 6.

---

### Task 2: Every declared key carries a description

**Story:** S-01
**Files:**
- Modify: `templates/profile.schema.json`

**Interfaces:**
- Consumes: nothing
- Produces: 35 new `description` fields. No key is added, renamed or removed, so the fingerprint
  is untouched and `SCHEMA_VERSION` does not move

**Done when:** `tests/generate-profile-keys.sh | grep -c 'No description yet'` prints `0`, and
`tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

The assertion belongs with the other schema rules. In `tests/validate-skills.sh`, inside the
existing `if [ -f templates/profile.schema.json ] && command -v python3 ...` block, before the
fingerprint check, add:

```bash
    # A key with no description is a key a reader cannot act on, and the generated reference has a
    # blank cell where its answer should be. 35 of 59 were empty on 2026-08-18.
    bare="$(python3 - <<'PY'
import json
d = json.load(open("templates/profile.schema.json"))
def walk(node, p=""):
    out = []
    for k, v in (node.get("properties") or {}).items():
        path = "%s.%s" % (p, k) if p else k
        if isinstance(v, dict) and v.get("properties"):
            out += walk(v, path)
        elif not (v.get("description") or "").strip():
            out.append(path)
    return out
print(" ".join(walk(d)))
PY
)"
    [ -z "$bare" ] \
      || report "templates/profile.schema.json has keys with no description: $bare. Every key a user may set has to say what it does; the generated reference shows a blank cell otherwise."
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/validate-skills.sh`
Expected: FAIL, naming 35 keys beginning `project.name gates.tdd ...`.

- [x] **Step 3: Write the minimal implementation**

Add a `description` to each of the 35 keys in `templates/profile.schema.json`. The list, from the
run of 2026-08-18:

`project.name`, `project.description`, `stack.language`, `stack.runtime`, `stack.framework`,
`stack.package_manager`, `stack.datastores`, `verify.test`, `verify.typecheck`, `verify.build`,
`verify.e2e`, `verify.security`, `artifacts.snapshot`, `artifacts.prd`, `artifacts.stories`,
`artifacts.architecture`, `artifacts.decisions`, `artifacts.plans`, `gates.tdd`,
`gates.coding_standards`, `gates.review`, `gates.security_audit`, `gates.observability`,
`gates.docs_updated`, `conventions.commit_style`, `conventions.working_branch`,
`observability.otlp_endpoint_var`, `observability.log_shipping`, `deploy.target`, `deploy.ci`,
`deploy.registry`, `deploy.envs`, `deploy.secrets_manager`, `plugins.recommended`,
`plugins.excluded`.

Each description says what the key controls and what changes if it is set differently. Follow the
voice of the 24 that already exist: they explain the reasoning, not just the field. Two worked
examples, to fix the register:

```json
"gates.tdd": {
  "description": "Whether a skill must write a failing test before implementation code. required is the default and is what tdd enforces; warn lets a task proceed after saying it skipped the cycle; off removes the obligation entirely, which is the right setting only for a repository that is not tested at all."
}
```

```json
"plugins.recommended": {
  "description": "Plugins this project expects, as marketplace-qualified names such as typescript-lsp@claude-plugins-official. keel init writes the list from the stack it detected, and keel doctor names any that are not enabled along with the command that installs them. Edit it to add or drop one: a value here is preserved when init is re-run."
}
```

The five that have neither a description nor a mention in any document need the most care, because
nothing else explains them: `conventions.working_branch`, `deploy.registry`,
`deploy.secrets_manager`, `plugins.excluded`, `plugins.recommended`.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/validate-skills.sh`
Expected: PASS, no bare-key report.
Then confirm the reference has no blanks:
`tests/generate-profile-keys.sh | grep -c 'No description yet'`
Expected: `0`.
Then `tests/run-tests.sh`. Expected: green.

- [x] **Step 5: Commit**

```bash
git add templates/profile.schema.json tests/validate-skills.sh
git commit -m "docs(schema): describe every profile key

35 of 59 keys had no description, and five had neither a description nor
a mention in any document, so the only way to learn what they did was to
read bin/keel. No key is added or renamed, so the fingerprint is
unchanged and SCHEMA_VERSION does not move."
```

---

### Task 3: The reference is committed and linked

**Story:** S-03, S-06
**Files:**
- Create: `docs/profile-keys.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: `tests/generate-profile-keys.sh` from task 1
- Produces: `docs/profile-keys.md`, which task 4 checks the column of and task 5 checks the schema
  half of

**Done when:** `tests/run-tests.sh` is green and `README.md` links `docs/profile-keys.md`.

- [x] **Step 1: Write the failing test**

Append to `tests/test-profile-keys.sh`, before the summary lines:

```bash
# The page is committed, not generated on demand, so a reader browsing the repository finds it.
[ -f "$ROOT/docs/profile-keys.md" ] && ok "docs/profile-keys.md is committed" \
  || bad "page" "the reference page is not committed"

# And it says what it is, so nobody edits it by hand and loses the edit on the next regeneration.
grep -q 'generate-profile-keys.sh' "$ROOT/docs/profile-keys.md" 2>/dev/null \
  && ok "the page names the script that produces it" \
  || bad "page" "the page does not say it is generated"

# The gap this whole change exists to close is discovery. A page nothing links to repeats it.
grep -q 'docs/profile-keys.md' "$ROOT/README.md" \
  && ok "the README links the reference" \
  || bad "discovery" "README.md does not link docs/profile-keys.md"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-profile-keys.sh`
Expected: FAIL on all three, beginning `page: the reference page is not committed`.

- [x] **Step 3: Write the minimal implementation**

Generate the page:

```bash
tests/generate-profile-keys.sh > docs/profile-keys.md
```

Then add a line to `README.md`, in the section that describes the profile:

```markdown
Every key `.keel/profile.json` may contain, and whether keel writes it, is listed in
[docs/profile-keys.md](docs/profile-keys.md).
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-profile-keys.sh`
Expected: PASS, nine assertions.
Then `tests/run-tests.sh`. Expected: green.

- [x] **Step 5: Commit**

```bash
git add docs/profile-keys.md README.md
git commit -m "docs: commit the profile key reference and link it

The only complete list of what a profile may contain was a JSON Schema
nothing pointed at. Six of the eleven keys keel never writes appeared in
no document a user reads."
```

---

### Task 4: The set-by column cannot drift from what init writes

**Story:** S-04
**Files:**
- Modify: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `docs/profile-keys.md` from task 3, and the `fixture` helper at `tests/test-keel.sh:23`
- Produces: nothing

**Done when:** `tests/test-keel.sh` passes and `tests/run-tests.sh` is green.

This check lives here rather than in `tests/validate-skills.sh` because it needs a real profile, and
the fast validator must not grow a `keel init` run.

- [x] **Step 1: Write the failing test**

Insert into `tests/test-keel.sh`, **before** its closing
`printf '\n%s passed, %s failed\n'` and `[ "$fail" -eq 0 ]`, never after them (see the note below):

```bash
# The reference says which keys keel writes and which a human adds. That column is derived from a
# real init when the page is generated, and this is what stops it drifting afterwards. A
# hand-maintained list said twelve human-only keys until the context window work moved one, and
# nothing would have noticed.
c="$(fixture node-ts)"
( cd "$c" && "$KEEL" init -y >/dev/null 2>&1 )
drift="$(PAGE="$ROOT/docs/profile-keys.md" PROFILE="$c/.keel/profile.json" python3 -c "
import json, os, re
page = open(os.environ['PAGE']).read()
claimed = {}
for k, setby in re.findall(r'^\| \`([^\`]+)\` \| [^|]* \| ([^|]*) \|', page, re.M):
    claimed[k] = 'init' in setby
def leaves(o, p=''):
    s = set()
    if isinstance(o, dict):
        for k, v in o.items(): s |= leaves(v, f'{p}.{k}' if p else k)
    else: s.add(p)
    return s
actual = leaves(json.load(open(os.environ['PROFILE'])))
bad = [k for k, says_init in claimed.items() if says_init != (k in actual)]
print(' '.join(sorted(bad)))
")"
[ -z "$drift" ] && ok "the reference's set-by column matches what keel init writes" \
  || bad "profile-keys" "the column disagrees with a real init for: $drift. Regenerate with tests/generate-profile-keys.sh"
rm -rf "$c"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: PASS. **This is a `verify` story and passing here is the expected outcome**: task 3
generated the column from a real init, so it already agrees. Confirm the assertion is not vacuous by
editing one row of `docs/profile-keys.md`, changing a `` `keel init` `` cell to `**you**`, running
the test, watching it fail naming that key, then restoring the file with
`git checkout docs/profile-keys.md`. Record that you did.

- [x] **Step 3: There is no implementation step**

Nothing to write. Task 3 produced the column; this pins it.

- [x] **Step 4: Run the full suite**

Run: `tests/run-tests.sh`
Expected: green.

- [x] **Step 5: Commit**

```bash
git add tests/test-keel.sh
git commit -m "test(docs): pin the reference's set-by column against a real init

The column is the half of the page the schema cannot check, so without
this it is the half that drifts. It needs a real profile, so it lives in
the slow suite rather than the per-commit validator."
```

---

## Deviation found while executing task 4

**"Append to `tests/test-keel.sh`" was wrong, and dangerously so.** That file ends with

```bash
printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

Appending puts new assertions after both. The printed count is then stale, and worse, the script's
exit status becomes that of the last command, which in task 4's case was `rm -rf "$c"`. The file
would have exited 0 whatever failed, silently disabling all 290 of its assertions while still
printing green. Caught by noticing the appended block sat below the summary, and confirmed fixed by
the count moving from 290 to 291.

Every task in this plan that adds to `tests/test-keel.sh` now says **insert before the summary**.
That is tasks 4, 6, 7 and 8. The wording was corrected in place rather than left for each task to
rediscover.

---

### Task 5: A schema edit that skips the page fails the build

**Story:** S-05
**Files:**
- Modify: `tests/validate-skills.sh`

**Interfaces:**
- Consumes: `docs/profile-keys.md`, `templates/profile.schema.json`
- Produces: nothing. Adds one rule beside the existing schema rules

**Done when:** `tests/validate-skills.sh` passes, and fails when the schema is edited without
regenerating the page. `tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

Add to `tests/test-validate-skills.sh`, following the shape of the existing fixture cases in that
file: a case that builds a fixture root with a schema declaring a key the page does not carry, runs
the validator against it, and expects a non-zero exit naming the key.

Use the file's own harness rather than a bespoke invocation: `run "<name>" <expected_rc> <fixture_fn>`
builds a valid tree with `fixture_valid`, applies the mutation, and checks the exit code. A fixture
builder is needed because `fixture_valid` creates neither the schema nor the page, and the rule is
guarded on both existing, so without one the cases would pass by skipping the rule entirely. That is
the same trap `tool_table_fixture` at `tests/test-validate-skills.sh:357` was written to avoid.

```bash
# The rule is guarded on both files existing, so the fixture has to build them or the case passes
# by checking nothing. Same reason tool_table_fixture exists a few rules above.
profile_keys_fixture() {
    local root="$1" page_rows="$2"
    mkdir -p "$root/docs" "$root/templates"
    printf '{"properties":{"a":{"type":"string","description":"A."},"b":{"type":"string","description":"B."}}}\n' \
      > "$root/templates/profile.schema.json"
    { printf '# Profile keys\n\ngenerate-profile-keys.sh\n\n'
      printf '| Key | Type | Set by | Description |\n|---|---|---|---|\n'
      printf '%s' "$page_rows"
    } > "$root/docs/profile-keys.md"
}

m_keys_ok()      { profile_keys_fixture "$1" '| `a` | string | `keel init` | A. |
| `b` | string | **you** | B. |
'; }
run "a reference matching the schema passes" 0 m_keys_ok

m_keys_missing() { profile_keys_fixture "$1" '| `a` | string | `keel init` | A. |
'; }
run "a key absent from the reference is rejected" 1 m_keys_missing

m_keys_stale()   { profile_keys_fixture "$1" '| `a` | string | `keel init` | Something else entirely. |
| `b` | string | **you** | B. |
'; }
run "a stale description in the reference is rejected" 1 m_keys_stale

m_keys_extra()   { profile_keys_fixture "$1" '| `a` | string | `keel init` | A. |
| `b` | string | **you** | B. |
| `c` | string | **you** | Not in the schema. |
'; }
run "a reference row the schema does not declare is rejected" 1 m_keys_extra
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-validate-skills.sh`
Expected: FAIL on the three cases that expect exit 1, because the rule does not exist yet so the
validator exits 0 for all four. The first case, which expects 0, passes for the wrong reason and is
there to catch a rule that rejects everything.

- [x] **Step 3: Write the minimal implementation**

In `tests/validate-skills.sh`, beside the other schema rules and guarded on both files existing the
way the neighbouring rules are:

```bash
# The reference page is generated, so the only way it goes wrong is by not being regenerated. This
# compares the page against the schema and nothing else: the set-by column needs a real profile and
# is checked in tests/test-keel.sh, because this validator runs on every commit and must stay fast.
if [ -f docs/profile-keys.md ] && [ -f templates/profile.schema.json ] && command -v python3 >/dev/null 2>&1; then
    stale="$(python3 - <<'PY'
import json, re
schema = json.load(open("templates/profile.schema.json"))
def declared(node, p=""):
    out = {}
    for k, v in (node.get("properties") or {}).items():
        path = "%s.%s" % (p, k) if p else k
        if isinstance(v, dict) and v.get("properties"):
            out.update(declared(v, path))
        else:
            out[path] = (v.get("description") or "").strip()
    return out
want = declared(schema)
page = open("docs/profile-keys.md").read()
got = {}
for m in re.finditer(r"^\| `([^`]+)` \| [^|]* \| [^|]* \| (.*) \|$", page, re.M):
    got[m.group(1)] = m.group(2).replace("\\|", "|")
problems = []
problems += ["no row for %s" % k for k in sorted(set(want) - set(got))]
problems += ["a row for %s, which the schema does not declare" % k for k in sorted(set(got) - set(want))]
problems += ["a stale description for %s" % k
             for k in sorted(set(want) & set(got))
             if got[k] != (want[k] or "_No description yet._")]
print("; ".join(problems))
PY
)"
    [ -z "$stale" ] \
      || report "docs/profile-keys.md disagrees with templates/profile.schema.json: $stale. Regenerate it with 'tests/generate-profile-keys.sh > docs/profile-keys.md'."
fi
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-validate-skills.sh`
Expected: PASS.
Then `tests/validate-skills.sh` against this repository. Expected: `OK`.
Then confirm the rule bites for real: add a key to `templates/profile.schema.json`, run
`tests/validate-skills.sh`, watch it report `no row for <key>`, then remove it. Record that you did.
Then `tests/run-tests.sh`. Expected: green.

- [x] **Step 5: Commit**

```bash
git add tests/validate-skills.sh tests/test-validate-skills.sh
git commit -m "test(docs): fail the build when the key reference is stale

A generated page that nothing checks is a hand-written page with extra
steps. This compares it against the schema only; the set-by column needs
a real profile and is pinned in the slow suite."
```

---

### Task 6: Init records the plugins this project expects

**Story:** S-08
**Files:**
- Modify: `bin/keel`
- Modify: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `detect_plugins` (`lib/detect-stack.sh:601-608`), which already returns one language
  server per detected language plus `frontend-design` and `playwright` when there is a UI
- Produces: `plugins.recommended` in every profile `keel init` creates, as an array of
  marketplace-qualified names

**Done when:** `tests/test-keel.sh` passes and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

Insert into `tests/test-keel.sh`, **before** its closing
`printf '\n%s passed, %s failed\n'` and `[ "$fail" -eq 0 ]`, never after them (see the note below):

```bash
# doctor has always been able to report a missing recommended plugin; it had nothing to check
# against. plugin_report reads plugins.recommended and falls back to a fixed three when it is
# absent, and init never wrote it, so no language server was ever named.
pr="$(fixture node-ts)"
( cd "$pr" && "$KEEL" init -y >/dev/null 2>&1 )
python3 -c "
import json,sys
r=json.load(open('$pr/.keel/profile.json')).get('plugins',{}).get('recommended') or []
sys.exit(0 if 'typescript-lsp@claude-plugins-official' in r else 1)" \
  && ok "init records the language server for the detected stack" \
  || bad "plugins" "plugins.recommended does not name typescript-lsp"
rm -rf "$pr"

pg="$(fixture go)"
( cd "$pg" && "$KEEL" init -y >/dev/null 2>&1 )
python3 -c "
import json,sys
r=json.load(open('$pg/.keel/profile.json')).get('plugins',{}).get('recommended') or []
sys.exit(0 if 'gopls-lsp@claude-plugins-official' in r else 1)" \
  && ok "a go project records gopls-lsp" \
  || bad "plugins" "plugins.recommended does not name gopls-lsp"
rm -rf "$pg"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL on both, `plugins: plugins.recommended does not name typescript-lsp`.

- [x] **Step 3: Write the minimal implementation**

In `bin/keel`, in `write_profile`, after the `artifacts` block and before the closing brace, add the
`plugins` object. `detect_plugins` prints one bare plugin name per line; the marketplace suffix is
added here, the same way `write_settings` does it at `bin/keel:565`:

```bash
      # Written so doctor has the right list to check. plugin_report has always read this key and
      # fallen back to a fixed three when it was absent, which is why a language server was never
      # named on a repository that already had a .claude/settings.json: nothing enabled it and
      # nothing reported it missing.
      printf '  "plugins": { "recommended": [%s] },\n' \
        "$(detect_plugins | awk 'NF { if (n++) printf ", "; printf "\"%s@claude-plugins-official\"", $0 }')"
```

Place it immediately before the `artifacts` block so the generated file keeps its current ordering,
and add the trailing comma to whichever line now precedes it.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on both.
Then the linter and `tests/run-tests.sh`. Expected: both clean.

- [x] **Step 5: Commit**

```bash
git add bin/keel tests/test-keel.sh
git commit -m "feat(init): record the plugins a project expects

detect_plugins already computed this list and write_settings already
used it. Only the profile writer was missing, so plugin_report fell back
to a fixed three and no language server was ever named."
```

---

## Deviations found while executing tasks 5 and 6

**Task 5's cases could not use exit codes.** Declaring a schema in a fixture also activates the
fingerprint rule, which reads `SCHEMA_VERSION` from a `bin/keel` a small fixture has no reason to
carry, so the validator exits 1 whatever the reference says. Three of the four cases passed while
asserting nothing, and only the one expecting exit 0 exposed it. `check` discards output, so a
`check_reports` helper was added that asserts on the message instead.

**Task 5's rule broke the parse of the whole validator, once.** The regex matches backticked keys,
so it contained backticks, and bash 3.2 does not treat a quoted heredoc as literal inside a `$( )`.
`lib/detect-stack.sh:28` already records this trap above its own heredoc, and `shellcheck` does not
see it. The rule now uses `\x60` and carries the same warning.

**Task 6 as written made `keel doctor` report less than before.** The plan said to write
`plugins.recommended` from `detect_plugins`, which is what `FR-07` says. But `write_settings` enables
seven plugins: `keel@gbi`, five official ones, and the stack's language servers. Recording only the
language servers gave `plugin_report` a **narrower** list than its old hardcoded fallback, so doctor
silently stopped naming `security-guidance`, `code-review` and `skill-creator`. `S-09` also requires
`keel@gbi` to be named, which that list omitted.

Both of the assertions written for task 6 passed against the broken implementation. What caught it
was `tests/test-keel.sh:1349`, a years-old assertion about `security-guidance` that has nothing to do
with this feature. **The fix is better than the plan:** one `expected_plugins()` function that both
writers read, rather than the two lists the plan implied, which disagreed within a single turn.

**The page is regenerated in task 6, not task 10.** The plan left `docs/profile-keys.md` stale from
task 6 until task 10, which would have meant four consecutive tasks whose `Done when` says "green"
running against a known-red suite. A suite that is expected to be red cannot report a new failure,
and three of those four tasks are `verify` stories whose whole value is noticing one. Task 10 keeps
the `CHANGELOG`, which is its more important half.

---

### Task 7: Doctor reports the gap, and names the fix

**Story:** S-09, S-10
**Files:**
- Modify: `bin/keel`
- Modify: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `plugin_report` (`bin/keel:142-163`), which prints `missing:<plugin>` per recommended
  plugin that is not enabled
- Produces: nothing new. One warn message gains the install command

**Done when:** `tests/test-keel.sh` passes and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

Insert into `tests/test-keel.sh`, **before** its closing
`printf '\n%s passed, %s failed\n'` and `[ "$fail" -eq 0 ]`, never after them (see the note below):

```bash
# The case this whole half exists for. A repository that already has .claude/settings.json takes
# the merge path, which touches permissions and nothing else, so no plugin is enabled: not the
# language server, not keel@gbi. Until init wrote plugins.recommended, doctor could not see it.
pm="$(fixture node-ts)"
mkdir -p "$pm/.claude"
printf '{\n  "permissions": { "allow": ["Bash(ls:*)"] }\n}\n' > "$pm/.claude/settings.json"
( cd "$pm" && "$KEEL" init -y >/dev/null 2>&1 )
out="$( cd "$pm" && "$KEEL" doctor 2>&1 )"
case "$out" in *typescript-lsp*) ok "doctor names the missing language server on a mature repo" ;;
  *) bad "plugins" "doctor did not name typescript-lsp as missing" ;; esac
case "$out" in *"/plugin install"*) ok "doctor names the command that installs it" ;;
  *) bad "plugins" "doctor reported a missing plugin without saying how to install it" ;; esac
rm -rf "$pm"

# A fresh repository has them enabled already, so it must stay quiet. A warning that fires on a
# healthy project is one people learn to scroll past.
pf="$(fixture node-ts)"
( cd "$pf" && "$KEEL" init -y >/dev/null 2>&1 )
out="$( cd "$pf" && "$KEEL" doctor 2>&1 )"
case "$out" in *"recommended plugin not enabled"*) bad "plugins" "doctor warned on a fresh repo where init enabled everything" ;;
  *) ok "a fresh repository is not warned about plugins" ;; esac
rm -rf "$pf"

# And a profile written before this change keeps the generic list, so it loses nothing.
po="$(fixture node-ts)"
( cd "$po" && "$KEEL" init -y >/dev/null 2>&1 )
python3 - "$po" <<'PY4'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d.pop("plugins", None)
p.write_text(json.dumps(d,indent=2)+"\n")
PY4
out="$( cd "$po" && "$KEEL" doctor 2>&1 )"
case "$out" in *security-guidance*) ok "a profile with no plugins.recommended still gets the generic list" ;;
  *) bad "plugins" "the fallback stopped working for a pre-existing profile" ;; esac
rm -rf "$po"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: the first assertion passes once task 6 has landed, because the list is now written. FAIL
on `plugins: doctor reported a missing plugin without saying how to install it`. The third and
fourth pass already.

- [x] **Step 3: Write the minimal implementation**

In `bin/keel`, change the `missing:` branch at line 1242:

```bash
              missing:*)  warn "recommended plugin not enabled: ${line#missing:}. Install it with '/plugin install ${line#missing:}'. The skill that uses it degrades to an inline fallback." ;;
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on all four.
Then the linter and `tests/run-tests.sh`. Expected: both clean. The suite includes the assertion
that `keel doctor` starts `python3` at most ten times; it measured 8 on 2026-08-18 and task 6 added
no interpreter start, so it must still pass. If it does not, stop and report.

- [x] **Step 5: Commit**

```bash
git add bin/keel tests/test-keel.sh
git commit -m "feat(doctor): name the missing plugins and how to install them

A repository that already had .claude/settings.json got no plugins at
all, not even keel@gbi, and doctor could not report it because the list
it checked was a hardcoded three with no language server in it. The
warning now names the command, the way the marketplace nudge does."
```

---

### Task 8: A curated list survives, and settings files are left alone

**Story:** S-11
**Files:**
- Modify: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `merge_profile` (`bin/keel:290`), `merge_permissions_into_settings` (`bin/keel:583-606`)
- Produces: nothing

**Done when:** `tests/test-keel.sh` passes and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the test for behaviour believed correct**

Insert into `tests/test-keel.sh`, **before** its closing
`printf '\n%s passed, %s failed\n'` and `[ "$fail" -eq 0 ]`, never after them (see the note below):

```bash
# Two deliberate non-behaviours, which are the kind most easily lost to a later helpful change.
ps="$(fixture node-ts)"
mkdir -p "$ps/.claude"
printf '{\n  "permissions": { "allow": ["Bash(ls:*)"] }\n}\n' > "$ps/.claude/settings.json"
( cd "$ps" && "$KEEL" init -y >/dev/null 2>&1 )
python3 -c "
import json,sys
s=json.load(open('$ps/.claude/settings.json'))
sys.exit(0 if 'enabledPlugins' not in s else 1)" \
  && ok "init adds no plugin entries to an existing settings file" \
  || bad "settings" "init wrote enabledPlugins into a file the project already had"

# The same path must still add the guardrails, which is the one thing it is for.
python3 -c "
import json,sys
p=json.load(open('$ps/.claude/settings.json')).get('permissions',{})
sys.exit(0 if p.get('deny') else 1)" \
  && ok "init still merges the permission guardrails into an existing settings file" \
  || bad "settings" "the permission merge stopped happening"

# A curated plugins.recommended is a human value and merge_profile must keep it.
python3 - "$ps" <<'PY5'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["plugins"]["recommended"]=["context7@claude-plugins-official"]
p.write_text(json.dumps(d,indent=2)+"\n")
PY5
( cd "$ps" && "$KEEL" init -y >/dev/null 2>&1 )
python3 -c "
import json,sys
r=json.load(open('$ps/.keel/profile.json'))['plugins']['recommended']
sys.exit(0 if r==['context7@claude-plugins-official'] else 1)" \
  && ok "a hand-edited plugins.recommended survives re-initialisation" \
  || bad "plugins" "re-init overwrote a curated plugin list"
rm -rf "$ps"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: PASS on all three. **A `verify` story.** Confirm the third assertion bites by temporarily
changing the expected list to `['nothing@nowhere']`, running the test, watching it fail, and
changing it back. Record that you did.

If the first assertion fails, stop: `write_settings` has started writing into an existing file and
that is `FR-11` broken, not a test to adjust.

- [x] **Step 3: There is no implementation step**

Nothing to write. `bin/keel:558-561` already returns after merging permissions, and
`merge_profile` at `bin/keel:290` already prefers a non-empty human value.

- [x] **Step 4: Run the full suite**

Run: `tests/run-tests.sh`
Expected: green.

- [x] **Step 5: Commit**

```bash
git add tests/test-keel.sh
git commit -m "test(init): pin two deliberate non-behaviours

Not writing plugins into a settings file the project already had is a
decision, not an oversight: that file is committed and decides what
loads for everyone who clones. Also pins that a curated plugin list
survives re-init, and that the permission merge still happens."
```

---

### Task 9: Nothing else moved

**Story:** S-12, S-13
**Files:**
- None. This task runs existing assertions and checks a diff

**Interfaces:**
- Consumes: the spawn-budget assertion at `tests/test-keel.sh:389-406` and the prefix guard in
  `tests/test-session-start.sh`
- Produces: nothing

**Done when:** `tests/run-tests.sh` is green.

- [x] **Step 1: There is no new test for the prefix**

`tests/test-session-start.sh` already pins the injected prefix between 300 and 356 estimated tokens,
with both bounds, after the first version of that guard was found to pass vacuously. No task in this
plan touches `hooks/session-start`, so `NFR-03` holds if that assertion still passes. Adding a
second assertion of the same thing would be duplication, not coverage.

For `NFR-02` there is nothing to add either. `tests/test-keel.sh:389-406` already counts doctor's
interpreter starts and asserts at most ten, and it already prints the number it measured. Tasks 6
and 7 put a profile read and more output on doctor's path, so what this task does is **run that
existing assertion and read the number**, not write a second one.

Writing a second shim was the first draft of this task and it was wrong twice over. It duplicated
`tests/test-keel.sh:405`, and its shim ended `exec /usr/bin/env python3 "$@"` while `$shimdir` was
first on `PATH`, so it would have found itself and recursed. The existing shim resolves
`real_python="$(command -v python3)"` **before** touching `PATH` and execs that absolute path, which
is the detail that makes it work. Left recorded here because it is the kind of mistake that looks
correct in review.

- [x] **Step 2: Run the existing assertion and read the number**

Run: `tests/test-keel.sh`
Expected: PASS, and its output names the count, as in
`keel doctor starts python3 at most 10 times (8)`. Record the number. If it is above 10, stop: the
fix is to remove an interpreter start, not to raise the budget. The context window work hit this
ceiling and solved it by reading a constant with `sed` rather than an interpreter, which is the
precedent.

- [x] **Step 3: There is no implementation step**

Nothing to write, unless step 2 reported more than ten.

- [x] **Step 4: Run the full suite**

Run: `tests/run-tests.sh`
Expected: green. Then confirm `NFR-03` directly:
`git diff --stat HEAD~8 -- hooks/`
Expected: no output. If `hooks/` changed at any point in this plan, `NFR-03` is violated and must be
reported rather than absorbed.

- [x] **Step 5: Commit**

There is nothing to commit for this task unless step 2 or step 4 found a problem. Say so in the
report rather than inventing a commit: a task whose whole job is to confirm that two existing
guards still hold has no deliverable when they do.

---

### Task 10: Regenerate, and land the documentation

**Story:** none. This is the documentation obligation, not a story.
**Files:**
- Modify: `docs/profile-keys.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: everything above
- Produces: nothing

**Done when:** `tests/run-tests.sh` is green.

Task 6 adds `plugins.recommended` to what `keel init` writes, which moves that key's set-by column
from **you** to `keel init`. The page committed in task 3 is stale from that moment, and task 5's
rule does not catch it because the change is in the column, not the schema. Task 4's does, in the
slow suite. This task closes it deliberately rather than leaving it to be discovered.

`docs/standards.md:129-130` and `CONTRIBUTING.md:125` require `CHANGELOG.md` in the same commit as
the change. It was missed on the previous plan and caught at the ship gate.

- [x] **Step 1: Confirm the page is stale**

Run: `tests/test-keel.sh`
Expected: FAIL, `profile-keys: the column disagrees with a real init for: plugins.recommended`.
That is task 4's assertion doing its job.

- [x] **Step 2: Regenerate**

```bash
tests/generate-profile-keys.sh > docs/profile-keys.md
```

- [x] **Step 3: Write the changelog entry**

Add to `CHANGELOG.md`, under the existing `## Unreleased` heading:

```markdown
### Added

- `docs/profile-keys.md`, a generated reference for every key `.keel/profile.json` may contain,
  saying what each does and whether `keel init` writes it. Produced by
  `tests/generate-profile-keys.sh`; `tests/validate-skills.sh` fails when it and the schema
  disagree, and `tests/test-keel.sh` pins the set-by column against a real `keel init`.
- Every key in `templates/profile.schema.json` now carries a description. 35 of 59 had none, and
  five had neither a description nor a mention in any document, so the only way to learn what they
  did was to read `bin/keel`.
- `keel init` writes `plugins.recommended` from the stack it detected, and `keel doctor` names any
  recommended plugin that is not enabled along with the `/plugin install` command for it.

### Fixed

- A repository that already had a `.claude/settings.json` received no plugins at all from
  `keel init`, not even `keel@gbi`, and `keel doctor` could not report it: `plugin_report` reads
  `plugins.recommended`, which nothing wrote, so it fell back to a hardcoded three with no language
  server in it. init now writes the key. Nothing is written into the settings file itself, which
  stays a decision for whoever owns that repository.

### Known gap

An enabled plugin that is not installed still looks identical to one that is working. `keel` cannot
install a plugin, and verifying that an entry resolves was left out of this change deliberately.
```

- [x] **Step 4: Run the full suite**

Run: `tests/run-tests.sh`
Expected: green, including task 4's column assertion.
Then: `tests/no-internal-leaks.sh`. Expected: `OK`. Run it explicitly because this task writes
prose, and prose is what the previous change leaked from.

- [x] **Step 5: Commit**

```bash
git add docs/profile-keys.md CHANGELOG.md
git commit -m "docs: regenerate the key reference and record the change

plugins.recommended moved from a key you add to one keel writes, so the
page's set-by column was stale the moment init started writing it."
```

---

## Story coverage

| Story | Kind | Task | Note |
|---|---|---|---|
| S-01 | build | 2 | The bulk of the work: 35 descriptions |
| S-02 | build | 1 | |
| S-03 | build | 3 | |
| S-04 | build | 4 | In the slow suite, because it needs a real profile |
| S-05 | build | 5 | In the fast validator, schema half only |
| S-06 | build | 3 | Folded: the page and its link ship together or the page is undiscoverable |
| S-07 | verify | 1 | Folded: it asserts properties of the generator task 1 writes |
| S-08 | build | 6 | |
| S-09 | verify | 7 | |
| S-10 | fix | 7 | Folded: the same doctor output, and shipping one without the other is half a message |
| S-11 | verify | 8 | |
| S-12 | verify | 9 | |
| S-13 | verify | 9 | Folded: satisfied by an existing assertion plus a diff check |

Thirteen stories, ten tasks. Every story maps to at least one task. Task 10 maps to no story and is
the documentation obligation, which `CONTRIBUTING.md:125` requires and the previous plan omitted.

## What this plan could not settle

Nothing blocks execution. Two PRD questions are open and neither gates a task:

- **Q3**, whether fresh repositories should stop having plugins written into `.claude/settings.json`
  so both paths behave the same way. The change here is correct either way.
- **Q5**, whether `keel doctor` should warn about a keel-side problem like an undescribed key.
  Handled at build time by task 2's rule instead, which is where a keel defect belongs.

One thing a reader should know before starting: **task 2 is most of the work and none of it is
code.** Thirty-five descriptions, in the voice of the twenty-four that already exist, five of them
for keys nothing else in the repository explains. Budget accordingly, and expect the build to stay
red from task 2 step 1 until the last description lands.
