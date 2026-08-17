# Suite Runtime Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go, on output you read.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness, or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** bring `tests/run-tests.sh` under five minutes on a developer machine by removing
interpreter starts that do no work, without changing a single observable behaviour of `keel`.

**Stories:** none. This is infrastructure, agreed directly with Bernard on 2026-08-17 and recorded
in the session handoff rather than in `docs/stories/`. Saying so beats inventing a story for it to
trace to.

**ADRs:** none apply. ADR-0001 bounds skill body words and is untouched here.

**Architecture:** two functions each spawn a fresh `python3` per single value they read, and both
are called in a loop. `pkg_script` in `lib/detect-stack.sh` reads one npm script name per
interpreter start and `detect_verify` calls it up to three times for each of ten verify keys.
`json_get` in `bin/keel` reads one dotted path per interpreter start and `cmd_doctor` reads
thirteen. Each grows a process-lifetime cache filled by one interpreter start, and every later read
becomes a shell lookup. No call site changes and no output changes.

**The one thing that makes this non-obvious.** Both functions return a value, so nearly every call
site is a command substitution: `v="$(detect_verify "$k" "$lang")"` in `write_profile`, and
`kind="$(json_get .keel/profile.json project.kind || echo service)"` in `cmd_doctor`. A `$( )` runs
in a subshell, which **inherits** the parent's variables but cannot write back to them. A cache
that fills itself lazily on first use would therefore be built and discarded once per call and save
nothing at all.

So each cache is **primed once in the parent shell**, before the loop that reads it, and the
subshells inherit it already full. That priming call is the entire point of the change. It looks
redundant next to a lazy loader and it is not; both tasks put a comment on it saying so, because
the natural instinct on reading it is to delete it.

## Global constraints

Copied in full. Every task inherits these.

- Verify commands, from `.keel/profile.json`:
  - test: `tests/run-tests.sh`
  - one test: `tests/{name}`
  - lint: `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`
  - typecheck, build, format: `null`. There is no typecheck or build command in this project.
- Never start on `main`. All keel work goes on `sandbox` and reaches `main` by pull request.
- **Behaviour must not change.** This is an optimisation. Every existing assertion in
  `tests/test-keel.sh` must still pass unaltered, and a task that needs an existing assertion
  changed has found a behaviour change and must stop and report rather than edit the assertion.
- **The full suite takes about six minutes.** Run it in the background and read the last line for
  the verdict, `All test files passed` or `N test file(s) failed`. A wrapper's exit code printed
  beside it is not the verdict.
- **Do not edit tracked files while the suite is running.** `tests/no-internal-leaks.sh` scans
  every tracked file via `git ls-files`, so an edit mid-run makes the result meaningless.
- `timeout` does not exist on this macOS.
- Target bash is **3.2**. No associative arrays, no `${var,,}`, no `EPOCHREALTIME`.
- Both caches live for one process. `bin/keel` runs once per command, so there is no cross-command
  staleness to reason about, only within-command.

## The measurements this plan is built on

Taken on 2026-08-17 on Bernard's machine, python3 3.13.1 at `/usr/local/bin/python3`.

| Measurement | Command | Value |
|---|---|---|
| **Suite, clean, the baseline** | `time tests/run-tests.sh`, idle machine | **351.7s (5:51.71)**, `All test files passed` |
| Same run, CPU split | as reported by `time` | 196s user, **150s system**, 98% CPU |
| Suite, per file, instrumented | `prof-run.sh` with a counting shim | 370s total, the shim's own cost included |
| `tests/test-keel.sh` alone | same | **288s**, 78% of the suite |
| `python3` start, doing nothing | 200 × `python3 -c pass` | **41.2 ms** |
| `python3` start, parsing the profile | 200 × `python3 -c "import json;json.load(...)"` | **44.7 ms** |
| `git` start | 200 × `git rev-parse --show-toplevel` | **5.6 ms** |
| One fixture | 50 × `mktemp -d` + `git init` + 2 × `git config` | **42 ms** |
| One `keel init`, node fixture | `time keel init` | **2.021s**, 24 python3, 7 git |
| One `keel doctor`, node fixture | `time keel doctor` | **1.575s**, 19 python3, 6 git |
| Whole suite | counting shim | **3304 python3**, 2437 git |

`bash -x` on one `keel init` and one `keel doctor`, counted by call site:

| Command | `pkg_script` | `json_get` | Other python3 | Total |
|---|---|---|---|---|
| `keel init`, node fixture | **17** | 6 | 1 | 24 |
| `keel doctor`, node fixture | 0 | **13** | 6 | 19 |

### What this overturns

The session handoff attributed the runtime to `json_get` and to `keel doctor` reading eighteen
fields. **That is right for doctor and wrong for init.** Only 6 of init's 24 interpreter starts are
`json_get`; 17 are `pkg_script`, which the handoff does not mention. Batching `json_get` alone
would have taken about 45 seconds off the suite and missed the five-minute target. The larger
single win is in a different file.

The handoff also records the suite as eleven minutes. Measured here it is **5 minutes 52 seconds**.
The eleven-minute figure is `keel doctor` in this repository, which is a different thing:
`cmd_doctor` at `bin/keel:1134` evals every verify command, and this project's `verify.test` is
`tests/run-tests.sh`, so doctor runs the whole suite inside itself and then keeps going.

That matters for the size of the job. The target is under five minutes, so the cut needed is about
**52 seconds**, not six minutes. The two changes below are projected to remove more than twice
that, which is the margin that makes a third change unnecessary.

The 150 seconds of **system** time against 196 of user time is the corroborating evidence. Nearly
half the CPU this suite burns is the kernel creating and tearing down processes, not any code
computing anything.

Two costs were measured and found **not** worth touching, recorded so nobody re-measures them:
`git` at 2437 spawns is about 14 seconds, and the 167 fixture creations about 7 seconds. Together
under 6% of the suite. The 75-fixture figure in the handoff undercounts, and it still does not
matter.

### What the plan is expected to save

| Change | Spawns | Removed | At 44.7 ms |
|---|---|---|---|
| Task 1, `pkg_script`, per node init | 17 → 1 | 16 | 0.72 s |
| Task 2, `json_get`, per init | 6 → 2 | 4 | 0.18 s |
| Task 2, `json_get`, per doctor | 13 → 2 | 11 | 0.49 s |

Neither cache reaches one spawn. `docs_root` is called at `bin/keel:701` and `bin/keel:1056`
before the profile is primed and inside a `$( )`, so it always pays its own interpreter start; the
priming call pays a second. Two is the floor without restructuring `docs_root`, which is not worth
it for one spawn.

That leaves `keel init` at about 4 interpreter starts, down from 24, and `keel doctor` at about 8,
down from 19.

`tests/test-keel.sh` runs `keel init` 106 times and `keel doctor` 41 times. If every init were a
node fixture that is 116 seconds off a 352 second suite, landing near 3 minutes 56.

**Not every init is a node fixture.** `pkg_script` returns before spawning anything when there is
no `package.json`, so task 1's saving applies only to the node and polyglot fixtures and the true
figure is lower. Task 2's saving applies to every fixture. The honest floor, counting only task 2,
is 106 × 0.18 + 41 × 0.49 = **39 seconds**, which on its own does *not* reach the target; the
combination is expected to, and task 3 measures it rather than asserting it.

If task 3 finds the suite still over five minutes, it stops and reports rather than starting a
fourth change.

---

### Task 1: One interpreter start for every package.json script, not one per lookup

**Story:** none, infrastructure.

**Files:**
- Modify: `lib/detect-stack.sh`
- Modify: `bin/keel`, one line in `write_profile` to prime the cache in the parent shell
- Test: `tests/test-keel.sh`

**Interfaces:**
- Consumes: nothing new.
- Produces: `pkg_scripts_load`, which fills `PKG_SCRIPTS` with one `name<TAB>command` line per
  entry in `package.json`'s `scripts` object, and the guard `PKG_SCRIPTS_LOADED`. `pkg_script`
  keeps its exact signature, `pkg_script <name>`, printing the command or nothing.

**Done when:** `tests/test-keel.sh` passes with the new assertion, and `tests/run-tests.sh` reports
`All test files passed`.

- [x] **Step 1: Write the failing test**

Add this to `tests/test-keel.sh`, immediately after the existing node-ts verify detection cases.
It counts interpreter starts by putting a counting shim first on `PATH`, which is how the
measurements above were taken.

```bash
# One interpreter start per npm script lookup, and detect_verify looks up to three times for each
# of ten verify keys. On a node project that was seventeen of init's twenty-four python3 starts,
# reading one small file seventeen times. The bound is asserted rather than the saving, because a
# saving in seconds is a property of the machine and a spawn count is a property of the code.
d="$(fixture node-ts)"
shimdir="$(mktemp -d)"
real_python="$(command -v python3)"
cat > "$shimdir/python3" <<SHIM
#!/bin/sh
printf 'x\n' >> "$shimdir/count"
exec "$real_python" "\$@"
SHIM
chmod +x "$shimdir/python3"
: > "$shimdir/count"
( cd "$d" && PATH="$shimdir:$PATH" "$KEEL" init >/dev/null 2>&1 )
spawns="$(grep -c x "$shimdir/count" 2>/dev/null || true)"
[ "${spawns:-99}" -le 10 ] \
  && ok "keel init starts python3 at most 10 times ($spawns)" \
  || bad "interpreter starts" "keel init started python3 $spawns times on a node fixture. pkg_script and json_get are meant to read their file once each, not once per value"
rm -rf "$d" "$shimdir"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL, `keel init started python3 24 times on a node fixture`.
Observed 2026-08-17: FAIL, `keel init started python3 23 times on a node fixture`, 267 passed 1
failed. Twenty-three rather than twenty-four; the same measurement one spawn off, and the bound
does not turn on it.

- [x] **Step 3: Write the minimal implementation**

Written as specified, with one deviation: `IFS="$(printf '\t')"` is assigned to a local `tab` above
the loop rather than on the `while` itself. On the `while` it forks a subshell per line per lookup,
which is the cost this task exists to remove.

In `lib/detect-stack.sh`, replace the whole `pkg_script` function with:

```bash
# Every script in package.json, read once. Filled on the first lookup and never again in this
# process, so a project with no package.json and a stack that never asks still costs nothing.
#
# One interpreter start per lookup was seventeen of init's twenty-four on a node project, because
# detect_verify is called once per verify key and asks for up to three script names each time.
PKG_SCRIPTS=""
PKG_SCRIPTS_LOADED=""

pkg_scripts_load() {
    [ -n "$PKG_SCRIPTS_LOADED" ] && return 0
    PKG_SCRIPTS_LOADED=1
    [ -f package.json ] || return 0
    have_python || return 0
    # A name or command containing a newline would break the line-per-script format, so it is left
    # out. Nothing reads such a script today and a wrong answer is worse than no answer.
    PKG_SCRIPTS="$(python3 - <<'PY' 2>/dev/null
import json
try:
    for k, v in json.load(open("package.json")).get("scripts", {}).items():
        k, v = str(k), str(v)
        if "\n" not in k and "\n" not in v:
            print(f"{k}\t{v}")
except Exception:
    pass
PY
)"
    return 0
}

# Print a package.json script by name, or nothing.
pkg_script() {
    [ -f package.json ] || return 0
    pkg_scripts_load
    [ -n "$PKG_SCRIPTS" ] || return 0
    local k v tab; tab="$(printf '\t')"
    # The redirect is on the loop, not a pipe, so this runs in the current shell and spawns nothing.
    while IFS="$tab" read -r k v; do
        if [ "$k" = "$1" ]; then printf '%s' "$v"; return 0; fi
    done <<< "$PKG_SCRIPTS"
    return 0
}
```

Then prime it in the parent shell. In `bin/keel`, in `write_profile`, add this immediately above
the `printf '  "verify": {\n'` line, before the loop over the verify keys:

```bash
      # Fill the script cache here, in this shell. The loop below reads each verify key through
      # `v="$(detect_verify ...)"`, and a $( ) is a subshell: it inherits this variable already
      # full, but anything it loads itself dies with it. Without this line every key would load
      # package.json again and the cache would save nothing. It is not redundant.
      pkg_scripts_load
```

- [x] **Step 4: Run it and watch it pass**

Observed 2026-08-17: PASS, `keel init starts python3 at most 10 times (8)`, 268 passed 0 failed.
shellcheck clean, exit 0.

Run: `tests/test-keel.sh`
Expected: PASS, `keel init starts python3 at most 10 times (8)`. If the count is still 24, the
priming call is missing or is in a subshell. Every existing node-ts assertion
about `verify.test`, `verify.lint`, `verify.typecheck`, `verify.format` and `verify.e2e` must still
pass unchanged. If any of them now fails, the cache is returning a different answer from the
per-lookup read and the implementation is wrong: do not edit the assertion.

Run: `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`
Expected: clean, exit 0.

- [x] **Step 5: Commit** Committed as `9658a02`.

```bash
git add lib/detect-stack.sh bin/keel tests/test-keel.sh
git commit -m "perf(detect-stack): read package.json scripts once, not once per lookup"
```

---

### Task 2: One interpreter start for the profile, not one per field

**Story:** none, infrastructure.

**Files:**
- Modify: `bin/keel`
- Test: `tests/test-keel.sh`

**Interfaces:**
- Consumes: nothing new.
- Produces: `json_load`, which flattens a JSON file to one `dotted.path=value` line per scalar and
  stores it in `JSON_CACHE` for the file named in `JSON_CACHE_FILE`; and `json_cache_clear`, which
  empties both. `json_get` keeps its exact signature, `json_get <file> <dotted.path>`, its exact
  output, and its exit code contract: **0 and the value when the key is present, 1 when it is
  absent.** Callers depend on that difference; `bin/keel:1100` reads
  `json_get .keel/profile.json project.kind || echo service` and an absent key must reach the
  default while a null key must not.

**Done when:** `tests/test-keel.sh` passes with the new assertion, and `tests/run-tests.sh` reports
`All test files passed`.

- [x] **Step 1: Write the failing test**

Add to `tests/test-keel.sh`, after the task 1 case. Doctor is where the field reads concentrate.

```bash
# Thirteen of doctor's nineteen interpreter starts were json_get reading one dotted path each from
# the same small file.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init >/dev/null 2>&1 )
shimdir="$(mktemp -d)"
real_python="$(command -v python3)"
cat > "$shimdir/python3" <<SHIM
#!/bin/sh
printf 'x\n' >> "$shimdir/count"
exec "$real_python" "\$@"
SHIM
chmod +x "$shimdir/python3"
: > "$shimdir/count"
( cd "$d" && PATH="$shimdir:$PATH" "$KEEL" doctor >/dev/null 2>&1 )
spawns="$(grep -c x "$shimdir/count" 2>/dev/null || true)"
[ "${spawns:-99}" -le 10 ] \
  && ok "keel doctor starts python3 at most 10 times ($spawns)" \
  || bad "interpreter starts" "keel doctor started python3 $spawns times. json_get is meant to read the profile once, not once per field"
rm -rf "$d" "$shimdir"

# The absent/null distinction json_get's callers depend on. A cache that cannot tell them apart
# sends `project.kind` to its 'service' default on a profile that says 'docs'.
#
# test_integration, not build: the node-ts fixture declares a build script, so verify.build is set
# and would not test the null path at all.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init >/dev/null 2>&1 )
( cd "$d" && "$KEEL" profile get verify.test_integration >/dev/null 2>&1 ) \
  && ok "a null field reads as present and empty" \
  || bad "json_get contract" "verify.test_integration is null in the profile, and 'profile get' treated it as absent"
( cd "$d" && "$KEEL" profile get verify.nosuchfield >/dev/null 2>&1 ) \
  && bad "json_get contract" "verify.nosuchfield does not exist, and 'profile get' treated it as present" \
  || ok "an absent field is refused"
rm -rf "$d"
```

- [x] **Step 2: Run it and watch it fail**

Observed 2026-08-17: FAIL, `keel doctor started python3 19 times`, exactly as written, and both
contract cases passed already. 270 passed, 1 failed.

Run: `tests/test-keel.sh`
Expected: FAIL, `keel doctor started python3 19 times`. The two contract cases are expected to
**pass** already: they describe the behaviour that exists today and must survive task 2. Both were
run against a node-ts fixture on 2026-08-17 before this plan was written, and behaved as described:
`profile get verify.test_integration` printed an empty line and exited 0, `profile get
verify.nosuchfield` printed `keel: no such field` and exited 1. If either fails at this step, stop:
the cache design below is built on that difference.

- [x] **Step 3: Write the minimal implementation**

Written as specified, with two additions the plan did not name and one trap it could not have
known:

1. **`set_verify` is a third profile writer** and now clears the cache too. `cmd_new` calls it
   after `write_profile` and before `render_block`, so leaving it out would have made the stated
   invariant, invalidate wherever the profile is written, false in one place. Nothing is stale
   today only because `cmd_new` never primes the cache.
2. **The clear must not swallow the exit status.** `profile_set` refuses an unknown path with
   exit 1 and `cmd_profile` reports it. `json_cache_clear` as the last statement would have
   returned 0 and turned every refusal into a success. Both writers carry the status over the
   clear by hand.
3. **bash 3.2 breaks on an apostrophe in a heredoc inside a `$( )`.** The comment this step says to
   keep reads `not Python's`, and that apostrophe opened a quote that swallowed the rest of
   `bin/keel`; the parse error surfaced 700 lines later at an unrelated `(`. Confirmed minimally:
   the same heredoc outside a `$( )` parses, and without the apostrophe inside one it parses.
   `shellcheck` reports nothing either way. The comment is reworded to `not the Python spelling`
   and both cache loaders carry a note saying why.

In `bin/keel`, replace the whole `json_get` function with the following. Keep the comment about
JSON spelling; it records a real defect and the flattener has the same problem.

```bash
# The whole file, flattened to one dotted.path=value line per scalar, read once per process.
#
# One interpreter start per field meant doctor paid thirteen of them to read one small file. The
# cache is keyed on the path because more than one file is never read in a single command today,
# and a second one would otherwise silently serve the first one's values.
JSON_CACHE=""
JSON_CACHE_FILE=""

json_cache_clear() { JSON_CACHE=""; JSON_CACHE_FILE=""; }

json_load() {  # json_load <file>
    [ "$JSON_CACHE_FILE" = "$1" ] && return 0
    have_python || return 1
    JSON_CACHE="$(python3 - "$1" <<'PY' 2>/dev/null
import json, sys

def render(v):
    # JSON spelling, not the Python spelling. The profile holds `true`, and printing `True` meant
    # the value could not be fed back to `profile set` and no shell comparison against `true` worked.
    if v is None:  return ""
    if v is True:  return "true"
    if v is False: return "false"
    return str(v)

def walk(d, prefix):
    for k, v in d.items():
        p = prefix + str(k)
        if isinstance(v, dict):
            walk(v, p + ".")
        else:
            s = render(v)
            # A value spanning lines cannot be held in a line-per-field cache. It is left out, and
            # json_get falls back to reading that one field with an interpreter, which is correct
            # and merely slow. Emitting it would corrupt every field after it.
            if "\n" not in p and "\n" not in s:
                print(p + "=" + s)

try:
    walk(json.load(open(sys.argv[1])), "")
except Exception:
    sys.exit(1)
PY
)" || { json_cache_clear; return 1; }
    JSON_CACHE_FILE="$1"
    return 0
}

json_get() {  # json_get <file> <dotted.path>
    have_python || return 1
    if json_load "$1"; then
        local line
        while IFS= read -r line; do
            case "$line" in
              "$2="*) printf '%s\n' "${line#*=}"; return 0 ;;
            esac
        done <<< "$JSON_CACHE"
    fi
    # Not in the cache: either the key is absent, or its value spans lines and the flattener left
    # it out. One interpreter start tells the two apart, and both are rare.
    python3 - "$1" "$2" <<'PY' 2>/dev/null
import json,sys
d=json.load(open(sys.argv[1]))
for k in sys.argv[2].split("."):
    if not isinstance(d,dict) or k not in d: sys.exit(1)
    d=d[k]
if   d is None:  print("")
elif d is True:  print("true")
elif d is False: print("false")
else:            print(d)
PY
}
```

Then two more things, both required for the cache to do anything at all.

**Invalidate it wherever the profile is written**, so a read after a write in the same process
cannot serve the old value. Add `json_cache_clear` as the last statement of `write_profile`, and as
the last statement of `profile_set`.

**Prime it in the parent shell**, for the same subshell reason as task 1. Every reader is a
`$( )`. Add this to `cmd_init`, immediately after the `write_profile "$root"` line:

```bash
    # write_profile has just replaced the file and cleared the cache. Fill it here, in this shell,
    # so the reads below and the ones inside render_block inherit it full. Each of those is a $( ),
    # which cannot fill it for anybody else. Not redundant.
    json_load .keel/profile.json || true
```

and this to `cmd_doctor`, immediately after the `good "profile parses"` branch closes:

```bash
    json_load .keel/profile.json || true
```

- [x] **Step 4: Run it and watch it pass**

Observed 2026-08-17: 271 passed, 0 failed. `keel init starts python3 at most 10 times (3)` and
`keel doctor starts python3 at most 10 times (9)`. shellcheck clean, exit 0.

Doctor at 9 sits one under the bound rather than the 8 projected. Six of the nine are not
`json_get` at all, one is the priming load, one is `docs_root` paying its own start before the
profile is primed, and the last is the fallback for `gates.context_watch`, which `write_profile`
does not write and so is never in the cache. Anyone adding a read of an absent key here will trip
the assertion, and that is the assertion doing its job.

Run: `tests/test-keel.sh`
Expected: PASS on all three new cases, `keel doctor starts python3 at most 10 times (8)`, and every
existing assertion still passing. In particular the `re-running init is byte-identical` case and
the `renders the real verify command` case are the ones that catch a cache serving a stale profile.

Run: `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`
Expected: clean, exit 0.

- [x] **Step 5: Commit** Committed as `c00b182`, with `lib/detect-stack.sh` added for the bash 3.2
note.

```bash
git add bin/keel tests/test-keel.sh
git commit -m "perf(keel): read the profile once per command, not once per field"
```

---

### Task 3: Measure again, and record what did not help

**Story:** none, infrastructure.

**Files:**
- Modify: `docs/plans/2026-08-17-suite-runtime.md` (this file, the results table below)
- Modify: `CHANGELOG.md`
- Modify: `tests/run-tests.sh` (its header comment, which says "seconds")

**Interfaces:**
- Consumes: the two changes from tasks 1 and 2.
- Produces: nothing code depends on.

**Done when:** `tests/run-tests.sh` reports `All test files passed` and the wall time recorded in
the table below is **under 300 seconds**, from `time tests/run-tests.sh` on an otherwise idle
machine.

- [x] **Step 1: There is no test for this**

This task is a measurement and a documentation change. The bound that protects the optimisation
from a later refactor is the spawn-count assertion written in tasks 1 and 2, which is a test and
already exists. A wall-clock assertion is deliberately **not** added: it would be a test that fails
on a loaded machine and passes on a fast one, and a suite that goes red for reasons unrelated to
the code is worse than no timing check at all.

- [x] **Step 2: Measure**

Run, on an idle machine, in the background, and read the last line for the verdict:

```bash
time tests/run-tests.sh
```

Measured 2026-08-17, same machine and same idle conditions as the before column. Every run reported
`All test files passed`.

| | Before | After |
|---|---|---|
| `tests/run-tests.sh` wall time | **351.7s (5:51.71)** | **270.0s (4:29.99)** |
| `tests/run-tests.sh` system time | **150s** | **135.5s** |
| `keel init`, node fixture | 2.021s, 24 python3 | **0.818s, 3 python3** |
| `keel doctor`, node fixture | 1.575s, 19 python3 | **1.551s, 9 python3** |
| Suite python3 spawns | 3304 | **1075** |

Three things in that table are worth more than the headline.

**`keel doctor` is no faster.** Its interpreter starts halved and its wall time moved by 24
milliseconds, because doctor spends its time running each verify command, not reading the profile.
The saving in the suite comes from `keel init`, which `tests/test-keel.sh` runs 106 times.

**The system time barely moved**, 150s to 135.5s, while user time fell 196s to 139s. Process
creation was the corroborating evidence for the diagnosis and it is still most of what this suite
does; what went away was the interpreter work on top of it. That is the honest reading of where the
remaining four and a half minutes sit.

**The before column's 24 was 23 when re-measured** with the counting shim immediately before the
change. One spawn, and it changes nothing: the assertion is a bound, not an equality.

- [x] **Step 3: If it is over 300 seconds, stop**

270.0s, under the 300s target, so nothing was stopped and no third optimisation was started.

Report the number and where the remaining time sits. Do not start a third optimisation inside this
plan. The next candidates, in the order the measurements favour them, are: the 106 `keel init`
runs themselves, which do real filesystem work and may not all be needed; and running the
thirteen test files concurrently, which is a change to `tests/run-tests.sh` rather than to `keel`
and carries its own risk of interleaved output.

- [x] **Step 4: Correct the documents this makes wrong**

`tests/run-tests.sh` line 2 says `Free, no dependencies, seconds.` It has not been seconds for some
time. Replace `seconds` with the measured figure.

Add a CHANGELOG entry under `## Unreleased`, stating the before and after wall time, the two
changes, and the two costs that were measured and left alone (`git` spawns at about 14 seconds and
fixture creation at about 7 seconds, together under 6% of the suite). Recording what did not help
is what stops the next person re-measuring it.

- [x] **Step 5: Commit**

```bash
git add docs/plans/2026-08-17-suite-runtime.md CHANGELOG.md tests/run-tests.sh
git commit -m "docs(perf): record the suite runtime before and after"
```

---

## Open questions

None block execution.

One is worth Bernard's opinion after task 3, not before: **the five-minute target is a
local-machine target.** CI runs the identical `tests/run-tests.sh` on `ubuntu-latest` in 3m3s
today, so CI already clears it and gains only a little from this work. If the point of the change
is developer feedback time rather than CI time, that is worth saying out loud, because it makes
concurrency in `tests/run-tests.sh` a better next step than any further interpreter-start work.

---

## Task 4: The review findings, agreed and not yet fixed

Reviewed 2026-08-17 over `33d3022..HEAD`, after tasks 1 to 3 were committed. Bernard said fix all
four. **All four are fixed**, each with its failing test watched first. Each was reproduced by
building `33d3022` and HEAD side by side and diffing the output, so the evidence below is observed,
not argued.

The three behaviour findings were run as one RED pass, `tests/test-keel.sh` on 2026-08-17: **272
passed, 3 failed**, each failing with the message its own case names. Finding 4 cannot fail on a
healthy run by construction, so its RED was shown directly: `grep -c x` on an empty file prints `0`
and `[ 0 -le 10 ]` succeeds, while the added lower bound refuses it.

GREEN, same day: `tests/run-tests.sh`, **`All test files passed`**, `tests/test-keel.sh` 275 passed
0 failed, `shellcheck` clean, wall time **267.97s (4:27.97)**, still inside the 300s target. Spawn
counts unmoved at 3 for `init` and 9 for `doctor`.

**REQUIRED SUB-SKILL:** `keel:tdd`. Finding 1 is a behaviour change and needs its failing test
first.

**Files:** `lib/detect-stack.sh`, `bin/keel`, `tests/test-keel.sh`.

**Done when:** all four are fixed, `tests/run-tests.sh` reports `All test files passed`, and
`shellcheck -x` on the profile's lint string is clean.

- [x] **Finding 1, blocking: a newline in an npm script value makes the whole script disappear**

Fixed as stated: `pkg_scripts_load` skips a *name* containing a newline and flattens a newline in a
*value* to a space. RED observed, `test was '' on a package.json whose test script contains a
newline`; GREEN observed, `verify.test` is `npm test` and `verify.lint` is still `npm run lint` on
the same fixture. A second assertion covers the script beside it, because the original defect could
equally have been the format losing everything after the multi-line entry rather than just that one.

`pkg_scripts_load` in `lib/detect-stack.sh` skips any script whose name **or value** contains a
newline, and `pkg_script` has no per-key fallback the way `json_get` does. So the key is lost, not
just the value.

Observed, on a fixture whose `package.json` holds `{"scripts":{"test":"echo a\nfoo","lint":"eslint ."}}`:

| | `verify.test` | `verify.lint` |
|---|---|---|
| `33d3022` | `npm test` | `npm run lint` |
| HEAD | **null** | `npm run lint` |

This breaks the plan's own global constraint that behaviour must not change, and `keel init` then
tells the project no test command was detected. The comment in the code, "a wrong answer is worse
than no answer", is inverted here: dropping the key **is** the wrong answer.

Every caller uses the value only as a presence test, `[ -n "$s" ] && pkg_run test`, and the command
written to the profile is `npm run <name>` rather than the script body. So the fix is to keep the
key and flatten the newline out of the value, not to skip the entry. A name containing a newline can
still be skipped: every lookup passes a fixed name like `test`.

Test first: a node fixture with a newline inside a script value, asserting `verify.test` is still
`npm test`.

- [x] **Finding 2, should fix: `profile get` and `profile set` disagree about a literal dotted key**

Fixed as stated, with one thing the finding did not spell out: the skip is on the **key segment**,
not the joined path, which legitimately contains dots, and it happens **before** the recursion, so
everything under such a key stays out of the cache too. `{"a.b": {"c": 1}}` is the same ambiguity one
level down. RED observed, `a literal 'a.b' key was served as the nested path nested.a.b`; GREEN
observed, `keel: no such field 'nested.a.b'` and exit 1, with ordinary nested reads unaffected.

`walk` in `bin/keel` joins segments with `.`, so `{"a":{"b":1}}` and `{"a.b":1}` are the same line
in the cache and `json_get` cannot tell them apart.

Observed, with `"nested": {"a.b": 1}` added to a profile:

| | result |
|---|---|
| `33d3022`, `profile get nested.a.b` | `keel: no such field`, exit 1 |
| HEAD, `profile get nested.a.b` | **`1`, exit 0** |
| HEAD, `profile set nested.a.b 2` | `no such field`, exit 1 |

`get` now claims a path exists that `set` refuses, and refusing a path that does not exist is the
whole point of that refusal. keel never writes such a key itself, which is why this is not blocking.

Fix: have `walk` skip any key containing a `.`, exactly as it already skips newlines. The key never
enters the cache, `json_get` falls through to the interpreter, and the interpreter refuses it
correctly. One line, and it restores the old behaviour rather than approximating it.

- [x] **Finding 3, should fix: `PKG_SCRIPTS_LOADED=1` is set before the `[ -f package.json ]` check**

Fixed as stated. The test sources `lib/detect-stack.sh` directly, which is the first case in this
suite to do so, because `bin/keel` cannot reach the ordering today: `pkg_script` returns at its own
`[ -f package.json ]` guard before it ever calls the loader, so the only way in is the priming call
in `write_profile`, and `cmd_new` scaffolds the file before it primes. RED observed through that
route, `pkg_script returned ''`; GREEN observed, `jest`.

A `package.json` created after the first lookup in the same process is never read: the load is
marked done against an empty cache. Unreachable today only because `cmd_new` scaffolds the file
before anything detects, so one reordered line in `cmd_new` turns it into silently empty verify
detection.

Fix: set the flag after the `-f` and `have_python` guards, so it means "loaded" rather than
"attempted". The cost when there is no `package.json` is one `stat` per call and no interpreter
starts, which is what that path already cost before this plan.

- [x] **Finding 4, should fix: the spawn-count assertions pass vacuously at zero**

Fixed as stated, `[ "${spawns:-99}" -ge 1 ] && [ "${spawns:-99}" -le 10 ]` on both cases. Shown
directly rather than through the suite, since a healthy run cannot exercise it: on an empty count
file `grep -c` prints `0`, the old condition passed and the new one refuses.

`grep -c` prints `0` and exits 1 on an empty count file, `|| true` swallows the status, and
`[ 0 -le 10 ]` succeeds. A `$KEEL` that dies before it reaches an interpreter reports PASS, which is
the regression these two assertions exist to catch.

Fix: add a lower bound, `[ "$spawns" -ge 1 ]`, to both cases. Safe because the suite already
requires python3: without it the js-tooling assertions above these cases fail first.

### Checked during the review and correct, so nobody re-checks

- `local rc=$?` does preserve the status. The masking pitfall is `local x=$(cmd)`, not `$?`. Exit
  codes for every `profile set` refusal are byte-identical to `33d3022`.
- `case "$line" in "$2="*)` is literal, not a glob. Glob characters from a **quoted** expansion in a
  `case` pattern match literally on bash 3.2, so `keel profile get 'verify.*'` still refuses.
- The python3-absent path degrades exactly as before: `init` exits 0 and writes a profile,
  `profile get` exits 1.
- A multi-line **profile** value falls back to the interpreter and does not corrupt the fields
  around it. This is finding 1's counterpart in `json_get`, and it is the half that works.
- `keel new --stack minimal` renders `tests/test.sh` into CLAUDE.md, so the `set_verify` then
  `render_block` ordering is right.
