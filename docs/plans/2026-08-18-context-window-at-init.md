# Context window at init Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go, on output you read.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness, or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** `keel init` writes the context window, and a configured window becomes a floor that
observation can raise and that nothing can push above one million.

**Stories:** S-01, S-02, S-03, S-04, S-05, S-06, S-07, S-08, S-09, S-10, S-11
**PRD:** `docs/prd/context-window-at-init.md`, approved 2026-08-18
**ADRs:** none. ADR-0001 governs skill body length and is untouched by this work.
**Architecture:** no new component. One function changes shape (`window_for`), one `printf` gains a
key, one doctor branch becomes two, and four places that document the rule are rewritten to agree
with it. There is no architecture document because there is no boundary to draw.

## Global constraints

Copied in full rather than linked, because a task executed by a fresh agent that reads only its own
section must still obey them.

- Verify commands, from `.keel/profile.json`:
  - test: `tests/run-tests.sh`
  - one test: `tests/{name}`, for example `tests/test-context-watch.sh`
  - lint: `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`
  - format, typecheck, build, e2e, security: `null`. There is no such command. Do not invent one.
- Never start on `main`. This work belongs on `sandbox`, which is the branch already checked out.
- Conventional commit messages. **No `Co-Authored-By` trailer, no robot emoji, no generated-by
  footer.** Title and body only.
- No em dash, en dash, or any dash longer than a hyphen, anywhere: code, comments, commit messages,
  documentation.
- **Task 5 must not land before tasks 1 and 2.** Writing `gates.context_window: 200000` into every
  profile while a configured value is still a ceiling would hard-stop a 1M session at 170,000 tokens
  permanently. This is a correctness ordering, not a preference.
- `SCHEMA_VERSION` does not move. `gates.context_window` is already declared at
  `templates/profile.schema.json:284`, so no field is added (`CON-01`).
- `hooks/session-start` is not touched by any task. It is at about 356 estimated tokens against a
  400 ceiling, and the remaining headroom is spoken for.
- The watchdog is advisory. It must stay silent when it cannot run, and must never exit non-zero
  (`CON-05`, `hooks/context-watch:14-16`).

## Deviation, agreed 2026-08-18 during execution

**Suite pacing.** As written, every task ends with a full `tests/run-tests.sh`. Measured during
execution, that run takes **278 seconds**, and ten of them is roughly 46 minutes spent mostly
re-running suites the task did not touch. Bernard asked for faster pacing after tasks 1 and 2 had
each been proven against a full green run.

What replaces it, for tasks 3 onward:

| Task | What runs at step 4 |
|---|---|
| 3, 4, 9, 10 | Its own targeted suite only. These tasks modify test files and nothing else |
| 5, 6 | `tests/test-keel.sh`, plus `tests/validate-skills.sh` and `verify.lint` where `bin/keel` changed |
| 7, 8 | `tests/test-keel.sh`, `tests/validate-skills.sh` and `verify.lint`. Both change `bin/keel`, and task 7 also changes `templates/profile.schema.json`, which `validate-skills.sh` fingerprints |
| 10 | One full `tests/run-tests.sh`, which must be green before anything ships |

`tests/run-tests.sh` runs `verify.lint` itself, so the shellcheck line is only called out separately
where the full suite is not being run.

**What this costs.** A regression in a suite nothing in the task touches surfaces at task 10 rather
than immediately. Every commit is small and independently revertible, and `git bisect` over ten
commits is cheap, so the exposure is bounded. Recorded here rather than left as an undocumented
difference between the plan and what happened.

---

### Task 1: A configured window becomes a floor rather than a ceiling

**Story:** S-01
**Files:**
- Modify: `lib/context_watch.py`
- Test: `tests/test-context-watch.sh`

**Interfaces:**
- Consumes: `LONG_WINDOW` and `DEFAULT_WINDOW` (`lib/context_watch.py:27-28`), unchanged
- Produces: `_positive_int(value)`, a module-level helper returning a positive `int` or `None`.
  Tasks 2 and 3 use it. `window_for(model, observed=0, configured=None)` keeps its signature.

**Done when:** `tests/test-context-watch.sh` passes and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

Append to `tests/test-context-watch.sh`, immediately after the block that resets the profile with
`printf '{"docs_root":"docs/keel"}\n' > "$work/.keel/profile.json"` and before the sidechain
section:

```bash
# ---- the floor -------------------------------------------------------------
#
# A configured window is a floor, not a ceiling. window_for used to return a configured value
# before it ever reached the observation correction, so a profile saying 200000 on a genuine 1M
# session reported 200% occupancy, hard-stopped it at 170,000 tokens and never lifted. That is the
# same failure the unconfigured path was rewritten to avoid, reintroduced through the profile.
#
# These call window_for directly rather than through `measure`, because main() calls it without a
# configured value: the profile only reaches it through the hook, and the hook asserts thresholds
# rather than the number.
wf() {   # wf <model> <observed> <configured|none>  -> the window window_for returns
    env -u KEEL_CONTEXT_WINDOW python3 -c "
import sys
sys.path.insert(0, '$ROOT/lib')
import context_watch
cfg = sys.argv[3]
print(context_watch.window_for(sys.argv[1],
                               observed=int(sys.argv[2]),
                               configured=int(cfg) if cfg.isdigit() else None))
" "$1" "$2" "$3"
}

got="$(wf claude-opus-5 400000 200000)"
[ "$got" = "1000000" ] && ok "a configured window below observed occupancy is raised" \
  || bad "floor" "got $got, want 1000000: a configured 200000 would stop a 1M session at 170k forever"

got="$(wf claude-opus-5 100001 1000000)"
[ "$got" = "1000000" ] && ok "a configured window above observed occupancy is left alone" \
  || bad "floor" "got $got, want 1000000"

got="$(wf claude-opus-5 100001 none)"
[ "$got" = "200000" ] && ok "with no configured window the conservative default still applies" \
  || bad "floor" "got $got, want 200000"

got="$(wf claude-opus-5 100001 200000)"
[ "$got" = "200000" ] && ok "a session inside its configured window is not promoted" \
  || bad "floor" "got $got, want 200000: the floor must not promote every session"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-context-watch.sh`
Expected: FAIL, `floor: got 200000, want 1000000: a configured 200000 would stop a 1M session at
170k forever`. The other three pass already, which is the point: they are the behaviour that must
survive the change.

- [x] **Step 3: Write the minimal implementation**

In `lib/context_watch.py`, add above `window_for`:

```python
def _positive_int(value):
    """The value as a positive int, or None when it is not one.

    Both sources are read here and neither is normalised before it arrives: a profile carries an
    int, an environment variable carries a string. `bool` is excluded deliberately, because it is
    an `int` in Python and `True` would otherwise be read as a one token window.
    """
    if isinstance(value, bool):
        return None
    if isinstance(value, int) and value > 0:
        return value
    if isinstance(value, str) and value.isdigit() and int(value) > 0:
        return int(value)
    return None
```

Replace the body of `window_for` after its docstring:

```python
    env = _positive_int(os.environ.get("KEEL_CONTEXT_WINDOW", "").strip())
    if env is not None:
        return env

    window = LONG_WINDOW if "1m" in (model or "").lower() else DEFAULT_WINDOW
    if observed > window:
        window = LONG_WINDOW

    floor = _positive_int(configured)
    if floor is not None and floor > window:
        window = floor
    return window
```

Replace the numbered list inside the docstring, leaving the paragraph above it as it is:

```
    So, in order:

    1. `KEEL_CONTEXT_WINDOW` wins outright, exactly as set. It is the deliberate override: the test
       suite uses it to force a small window, and a session that knows better can do the same.
       Nothing raises it.
    2. Observation beats assumption. Occupancy above a tier is proof the window is larger, since the
       API would have refused the request otherwise. This can only correct upward, so it never
       invents room that is not there.
    3. `gates.context_window` is a floor, not a ceiling. It raises the starting point, and step 2
       may raise it further still. It was a ceiling until 2026-08-18, which is why `keel init` did
       not dare write one: a conservative value would have hard-stopped every larger session at 85%
       of it, permanently, with editing the file the only escape.
    4. Otherwise the model string, then the conservative default.
```

Delete the closing paragraph beginning `The residual error is a 1M session below 200,000 tokens`
and replace it with:

```
    The residual error is now the other way round: a configured window larger than the true one
    cannot be corrected downward, because occupancy proves a lower bound and never an upper one.
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-context-watch.sh`
Expected: PASS, all four new assertions and every pre-existing one.
Then run the full suite: `tests/run-tests.sh`. Nothing else may break.

- [x] **Step 5: Commit**

```bash
git add lib/context_watch.py tests/test-context-watch.sh
git commit -m "fix(watchdog): treat a configured context window as a floor

window_for returned a configured value before reaching the observation
correction, so a profile understating the window hard-stopped a larger
session at 85% of the wrong number and never lifted. Observation may now
raise it, which is what makes keel init writing a conservative value safe."
```

---

### Task 2: No window above one million is ever returned

**Story:** S-02
**Files:**
- Modify: `lib/context_watch.py`
- Test: `tests/test-context-watch.sh`

**Interfaces:**
- Consumes: `_positive_int` and `LONG_WINDOW`, from task 1 and `lib/context_watch.py:28`
- Produces: nothing new. Two lines of `window_for` change

**Done when:** `tests/test-context-watch.sh` passes and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

Append to `tests/test-context-watch.sh`, after the floor block from task 1:

```bash
# ---- the upper bound -------------------------------------------------------
#
# 1,000,000 is the largest context window any current Claude model offers, checked 2026-08-18. It
# is also already the highest value observation can promote to, so bounding the configured value
# there adds no ceiling the observed path did not have. Without it a mistyped extra zero silences
# the watchdog for the life of the project, which is the same harm as the floor bug pointing the
# other way.
got="$(wf claude-opus-5 100001 200000000)"
[ "$got" = "1000000" ] && ok "a profile window above the maximum is bounded" \
  || bad "bound" "got $got, want 1000000: a mistyped window must not silence the watchdog"

got="$(KEEL_CONTEXT_WINDOW=200000000 python3 -c "
import sys
sys.path.insert(0, '$ROOT/lib')
import context_watch
print(context_watch.window_for('claude-opus-5', observed=100001))
")"
[ "$got" = "1000000" ] && ok "an environment window above the maximum is bounded" \
  || bad "bound" "got $got, want 1000000"

got="$(wf claude-opus-5 100001 1000000)"
[ "$got" = "1000000" ] && ok "a window at the maximum is untouched" \
  || bad "bound" "got $got, want 1000000"

grep -q 'min(window, LONG_WINDOW)' "$ROOT/lib/context_watch.py" \
  && ok "the bound is the LONG_WINDOW constant, not a second literal" \
  || bad "bound" "the bound is not expressed as LONG_WINDOW; a larger model would need two edits"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-context-watch.sh`
Expected: FAIL on the first two, `bound: got 200000000, want 1000000`, and FAIL on the fourth,
`the bound is not expressed as LONG_WINDOW`. The third passes already.

- [x] **Step 3: Write the minimal implementation**

In `lib/context_watch.py`, change two lines of `window_for`. The environment branch becomes:

```python
    env = _positive_int(os.environ.get("KEEL_CONTEXT_WINDOW", "").strip())
    if env is not None:
        return min(env, LONG_WINDOW)
```

and the final `return window` becomes:

```python
    return min(window, LONG_WINDOW)
```

Add a fifth entry to the docstring's numbered list, after item 4:

```
    5. Nothing above LONG_WINDOW is returned, from any source. It is the largest context window any
       current model offers, checked 2026-08-18, and already the highest value step 2 can reach, so
       the bound adds no ceiling the observed path did not have. A mistyped extra zero is caught
       rather than silencing the watchdog for the life of the project. When a larger model ships,
       this constant moves and both paths follow.
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-context-watch.sh`
Expected: PASS, including the four assertions from task 1.
Then run the full suite: `tests/run-tests.sh`.

- [x] **Step 5: Commit**

```bash
git add lib/context_watch.py tests/test-context-watch.sh
git commit -m "feat(watchdog): bound the context window at LONG_WINDOW

A configured window above the largest window that exists silenced the
watchdog permanently, which is the floor bug pointing the other way. Both
sources are now bounded by the same constant the observed path already
tops out at, so a larger model is still a one line change."
```

---

### Task 3: The environment override stays absolute

**Story:** S-03
**Files:**
- Test: `tests/test-context-watch.sh`

**Interfaces:**
- Consumes: `wf`, defined in task 1's test block
- Produces: nothing. This is a `verify` story: the behaviour is believed correct and untested

**Done when:** `tests/test-context-watch.sh` passes and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the test for behaviour believed correct**

Append to `tests/test-context-watch.sh`, after the bound block:

```bash
# ---- the environment override ----------------------------------------------
#
# The profile key is a floor; the environment variable is not. It is the deliberate escape hatch,
# and the suite above depends on it: a test that forces a window smaller than its fixture's
# occupancy has no other way to do it. Untested until now, which made it one refactor away from
# quietly becoming a floor as well.
got="$(KEEL_CONTEXT_WINDOW=50000 python3 -c "
import sys
sys.path.insert(0, '$ROOT/lib')
import context_watch
print(context_watch.window_for('claude-opus-5', observed=100001))
")"
[ "$got" = "50000" ] && ok "the environment window is not raised by observation" \
  || bad "env" "got $got, want 50000: forcing a small window must stay possible"

got="$(KEEL_CONTEXT_WINDOW=500000 python3 -c "
import sys
sys.path.insert(0, '$ROOT/lib')
import context_watch
print(context_watch.window_for('claude-opus-5', observed=1, configured=1000000))
")"
[ "$got" = "500000" ] && ok "the environment window outranks the profile" \
  || bad "env" "got $got, want 500000"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-context-watch.sh`
Expected: PASS on both, immediately. **This is a `verify` story and passing at step 2 is the
expected outcome**, not a broken test: the assertions describe behaviour tasks 1 and 2 were written
to preserve. Confirm they are really asserting something by temporarily changing `50000` to
`50001` in the first assertion, watching it fail, and changing it back. Record that you did.

If either fails, stop. The story becomes `fix`, and the environment branch of `window_for` needs
correcting before anything else proceeds.

- [x] **Step 3: There is no implementation step**

Nothing to write. The behaviour exists; this task adds the test that stops it being lost.

- [x] **Step 4: Run the full suite**

Run: `tests/run-tests.sh`
Expected: green.

- [x] **Step 5: Commit**

```bash
git add tests/test-context-watch.sh
git commit -m "test(watchdog): pin the environment window as an absolute override

The profile key became a floor in the previous commit. Nothing asserted
that KEEL_CONTEXT_WINDOW did not, and the suite itself relies on being
able to force a window below observed occupancy."
```

---

### Task 4: The change costs nothing and breaks nothing

**Story:** S-04
**Files:**
- Test: `tests/test-context-watch.sh`

**Interfaces:**
- Consumes: `window_for`, `_positive_int`
- Produces: nothing

**Done when:** `tests/test-context-watch.sh` passes and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the test for behaviour believed correct**

Append to `tests/test-context-watch.sh`, after the environment block:

```bash
# ---- the cost --------------------------------------------------------------
#
# window_for runs on every prompt and, at the stop threshold, on every tool call. It receives
# everything it needs as arguments, and it must stay that way: a filesystem read here is paid
# dozens of times a minute for a number that moves slowly.
python3 -c "
import inspect, sys
sys.path.insert(0, '$ROOT/lib')
import context_watch
src = inspect.getsource(context_watch.window_for) + inspect.getsource(context_watch._positive_int)
banned = ['open(', 'os.path', 'os.stat', 'os.listdir', 'subprocess', 'socket', 'urllib', 'json.load']
hits = [b for b in banned if b in src]
sys.exit(1 if hits else 0)
" && ok "window_for reads nothing from the filesystem or the network" \
  || bad "cost" "window_for gained an I/O call; it runs on every prompt and every tool call"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-context-watch.sh`
Expected: PASS immediately. **A `verify` story again.** Confirm the assertion bites by temporarily
adding `open('/dev/null').close()` as the first line of `_positive_int`, running the test, watching
it fail with `window_for gained an I/O call`, then removing it. Record that you did.

- [x] **Step 3: There is no implementation step**

Nothing to write. NFR-04, that every pre-existing assertion still passes unmodified, is verified by
step 4 rather than by a new assertion: the file has not been edited except by appending.

- [x] **Step 4: Run the full suite**

Run: `tests/run-tests.sh`
Expected: green. Then confirm NFR-04 explicitly:
`git diff --stat HEAD~3 -- tests/test-context-watch.sh`
Expected: additions only, zero deletions. If any line of the original file changed, NFR-04 is
violated and the reason must be reported rather than absorbed.

- [x] **Step 5: Commit**

```bash
git add tests/test-context-watch.sh
git commit -m "test(watchdog): pin window_for as pure arithmetic

It runs on every prompt and every tool call at the stop threshold, so an
I/O call added here is paid constantly for a number that barely moves."
```

---

### Task 5: Init writes the context window

**Story:** S-05
**Files:**
- Modify: `bin/keel`
- Test: `tests/test-keel.sh`

**Interfaces:**
- Consumes: nothing from earlier tasks at runtime. It **depends on tasks 1 and 2 having landed**,
  because the value it writes is only safe once a configured window is a floor
- Produces: `gates.context_window` in every profile `keel init` creates

**Done when:** `tests/test-keel.sh` passes and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

In `tests/test-keel.sh`, immediately after the `init writes conventions.response_style=terse`
assertion, append:

```bash
# The watchdog cannot read the window from a session, so the only correct mechanism is this key and
# nothing wrote it. 200000 is conservative and sometimes wrong, which is acceptable only because a
# configured window is a floor: a larger session raises it in flight rather than being stopped at
# 85% of the wrong number.
python3 -c "
import json,sys
g=json.load(open('$d/.keel/profile.json')).get('gates',{})
sys.exit(0 if g.get('context_window')==200000 else 1)" \
  && ok "init writes gates.context_window=200000" \
  || bad "context_window" "init did not write gates.context_window"

python3 -c "
import json,sys
d=json.load(open('$d/.keel/profile.json'))
sys.exit(0 if d.get('schema_version')==1 else 1)" \
  && ok "writing context_window did not move schema_version" \
  || bad "context_window" "schema_version moved for a field the schema already declares"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL, `context_window: init did not write gates.context_window`. The second assertion
passes already and is there to catch an unnecessary schema bump.

- [x] **Step 3: Write the minimal implementation**

In `bin/keel`, replace the `gates` line in `write_profile` (currently at line 364). Add the comment
above it, beside the existing `done_verified` comment:

```bash
      # context_window is written even though it is sometimes wrong. The window cannot be read from
      # a session, so an unset key means the watchdog assumes 200000 and only discovers otherwise
      # once a session exceeds it. Writing the conservative value is safe because a configured
      # window is a floor: observation raises it in flight. It was a ceiling until 2026-08-18, and
      # writing this key before that change would have hard-stopped every 1M session at 170,000
      # tokens permanently.
      printf '  "gates": { "tdd": "required", "coding_standards": "warn", "review": "required", "security_audit": "required", "observability": "required", "docs_updated": "warn", "commit_guard": "off", "done_verified": "warn", "context_window": 200000 },\n'
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on both.
Then run the full suite: `tests/run-tests.sh`, and the linter:
`shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`
Expected: both clean.

- [x] **Step 5: Commit**

```bash
git add bin/keel tests/test-keel.sh
git commit -m "feat(init): write gates.context_window

Every project needed this typed in by hand, and doctor nagged about it on
every run. Safe to write only now that a configured window is a floor
rather than a ceiling."
```

---

### Task 6: A hand-set window survives re-initialisation

**Story:** S-06
**Files:**
- Test: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `merge_profile` (`bin/keel:277-305`), `fixture` (`tests/test-keel.sh:23`)
- Produces: nothing. `verify` story

**Done when:** `tests/test-keel.sh` passes and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the test for behaviour believed correct**

Append to `tests/test-keel.sh`, after task 5's assertions:

```bash
# Re-running init is how a project picks up new keel defaults, and it must not quietly downgrade a
# 1M project to a 200000 window on the way. merge_profile gives a non-empty human value precedence;
# nothing asserted it for this key.
e="$(fixture node-ts)"
( cd "$e" && "$KEEL" init -y >/dev/null 2>&1 )
python3 - "$e" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["gates"]["context_window"]=1000000
p.write_text(json.dumps(d,indent=2)+"\n")
PY
( cd "$e" && "$KEEL" init -y >/dev/null 2>&1 )
python3 -c "
import json,sys
sys.exit(0 if json.load(open('$e/.keel/profile.json'))['gates']['context_window']==1000000 else 1)" \
  && ok "re-running init preserves a hand-set context_window" \
  || bad "context_window" "re-init overwrote a human value, downgrading a 1m project"

( cd "$e" && "$KEEL" init --force -y >/dev/null 2>&1 )
python3 -c "
import json,sys
sys.exit(0 if json.load(open('$e/.keel/profile.json'))['gates']['context_window']==200000 else 1)" \
  && ok "init --force replaces context_window, as it replaces the rest of the profile" \
  || bad "context_window" "--force left the old value"

# And the downgrade --force just performed is recoverable in flight, which is the only reason it is
# acceptable behaviour rather than a defect.
got="$(env -u KEEL_CONTEXT_WINDOW python3 -c "
import sys
sys.path.insert(0, '$ROOT/lib')
import context_watch
print(context_watch.window_for('claude-opus-5', observed=400000, configured=200000))
")"
[ "$got" = "1000000" ] && ok "a force-downgraded window is raised again by observation" \
  || bad "context_window" "got $got: --force would strand a 1m project at 200000"
rm -rf "$e"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: PASS on all three. **A `verify` story.** Confirm the first assertion bites by temporarily
changing `1000000` to `999999` in the comparison, watching it fail, and changing it back. Record
that you did.

**How this was actually done, 2026-08-18:** `tests/test-keel.sh` takes 204 seconds, so rather than
re-running the whole suite twice, the assertion's exact `python3` comparison was run directly
against a profile holding `999999` and then one holding `1000000`. The first exits 1, which is what
makes `bad()` fire, and the second exits 0. Same proof, seconds instead of seven minutes. The
assertion itself was not modified.

If the first assertion fails, stop: `merge_profile` does not protect this key and the story becomes
`fix`.

- [x] **Step 3: There is no implementation step**

Nothing to write. `merge_profile` at `bin/keel:290` already prefers a non-empty existing value.

- [x] **Step 4: Run the full suite**

Run: `tests/run-tests.sh`
Expected: green.

- [x] **Step 5: Commit**

```bash
git add tests/test-keel.sh
git commit -m "test(init): pin that re-init preserves a hand-set context window

Re-running init is routine, and this key is the one a 1m project sets by
hand. Also pins that the --force downgrade is recoverable in flight,
which is what makes --force acceptable rather than a defect."
```

---

### Task 7: Everything that documents the rule describes the rule

**Story:** S-07, S-09
**Files:**
- Modify: `bin/keel`
- Modify: `templates/profile.schema.json`
- Test: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `$cw`, the profile value doctor already reads at `bin/keel:1267`
- Produces: nothing. Two messages and one schema description change

**Done when:** `tests/test-keel.sh` passes and `tests/run-tests.sh` is green.

Tasks 1 and 2 rewrote `window_for`'s docstring alongside the behaviour, because a function that
contradicts its own docstring should not survive a single commit. This task is the other three
sites named in FR-10.

- [x] **Step 1: Write the failing test**

Append to `tests/test-keel.sh`, after task 6's block:

```bash
# Four places describe how the window is decided and all four said an explicit setting simply wins.
# That stopped being true when the profile key became a floor. A description that is wrong is worse
# than none: it is read once and believed.
f="$(fixture node-ts)"
( cd "$f" && "$KEEL" init -y >/dev/null 2>&1 )
out="$( cd "$f" && "$KEEL" doctor 2>&1 )"
case "$out" in
  *"context watchdog available (window 200000"*) ok "doctor names the configured window" ;;
  *) bad "doctor window" "did not name the configured window: $out" ;;
esac
case "$out" in
  *raised*) ok "doctor says the configured window can be raised by observation" ;;
  *) bad "doctor window" "doctor still presents the configured window as final" ;;
esac

python3 - "$f" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
del d["gates"]["context_window"]
p.write_text(json.dumps(d,indent=2)+"\n")
PY
out="$( cd "$f" && "$KEEL" doctor 2>&1 )"
case "$out" in
  *"window assumed 200000"*) ok "doctor still explains an unset window for older profiles" ;;
  *) bad "doctor window" "the unset branch stopped being reachable or accurate: $out" ;;
esac
rm -rf "$f"

grep -q 'floor' templates/profile.schema.json \
  && ok "the gates.context_window description describes the floor" \
  || bad "schema doc" "the schema still describes a configured window as simply winning"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL on `doctor still presents the configured window as final` and on
`the schema still describes a configured window as simply winning`. The first and third pass.

- [x] **Step 3: Write the minimal implementation**

In `bin/keel`, replace the two `good` lines inside the `else` branch at lines 1268 to 1272:

```bash
            local cw; cw="$(json_get .keel/profile.json gates.context_window 2>/dev/null || true)"
            if [ -n "$cw" ] && [ "$cw" != "None" ]; then
                good "context watchdog available (window $cw from gates.context_window, raised automatically if a session is observed exceeding it). KEEL_CONTEXT_WINDOW overrides it exactly."
            else
                good "context watchdog available (window assumed 200000, raised once a session is observed exceeding it). Projects initialised since 0.10.0 carry gates.context_window; set it here to start from a larger value."
            fi
```

In `templates/profile.schema.json`, replace the `description` of `gates.context_window`:

```json
          "description": "Context window in tokens for sessions in this project, written by keel init as 200000. It is a floor and not a ceiling: the watchdog raises it once a session is observed exceeding it, since the API would have refused the request otherwise, so a value that understates the window costs nothing beyond an early first estimate. It is never raised above 1000000, the largest window any current model offers, so a mistyped extra zero cannot silence the watchdog. KEEL_CONTEXT_WINDOW overrides this exactly and is not raised, which is how a smaller window is forced deliberately."
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on all four.
Then run the full suite: `tests/run-tests.sh`, and the linter:
`shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`
Expected: both clean.

Then confirm FR-10 by reading all four sites and checking they agree:
`grep -n 'floor' lib/context_watch.py templates/profile.schema.json; grep -n 'raised' bin/keel`
Expected: the docstring, the schema description and both doctor messages all describe the floor.

- [x] **Step 5: Commit**

```bash
git add bin/keel templates/profile.schema.json tests/test-keel.sh
git commit -m "docs(watchdog): describe the window rule where people read it

The schema description and both doctor messages still said an explicit
setting wins outright, which stopped being true when the profile key
became a floor. A wrong description is read once and believed."
```

---

### Task 8: Doctor names both values when it bounds a window

**Story:** S-08
**Files:**
- Modify: `bin/keel`
- Test: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `$cw` from task 7's branch, and `LONG_WINDOW` read from `lib/context_watch.py`
- Produces: nothing new

**Done when:** `tests/test-keel.sh` passes and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

Append to `tests/test-keel.sh`, after task 7's block:

```bash
# The bound must not be silent. It exists because a mistyped window disables the watchdog without
# saying so, and a bound that clamps without saying so has moved that failure rather than fixed it.
g="$(fixture node-ts)"
( cd "$g" && "$KEEL" init -y >/dev/null 2>&1 )
python3 - "$g" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["gates"]["context_window"]=200000000
p.write_text(json.dumps(d,indent=2)+"\n")
PY
out="$( cd "$g" && "$KEEL" doctor 2>&1 )"
case "$out" in *200000000*) ok "doctor names the configured value it bounded" ;;
  *) bad "bound report" "doctor did not name the configured 200000000: $out" ;; esac
case "$out" in *1000000*) ok "doctor names the value actually in use" ;;
  *) bad "bound report" "doctor did not name the bounded 1000000: $out" ;; esac

python3 - "$g" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["gates"]["context_window"]=1000000
p.write_text(json.dumps(d,indent=2)+"\n")
PY
out="$( cd "$g" && "$KEEL" doctor 2>&1 )"
case "$out" in *"above the largest"*) bad "bound report" "doctor warned about a legitimate 1000000" ;;
  *) ok "doctor says nothing about bounding a window at the maximum" ;; esac
rm -rf "$g"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL, `bound report: doctor did not name the bounded 1000000`. The first assertion passes
by accident, because the configured value is printed already, and the third passes.

- [x] **Step 3: Write the minimal implementation**

In `bin/keel`, replace the `if [ -n "$cw" ] && [ "$cw" != "None" ]; then` branch written in task 7
with a three-way branch. The maximum is read from the source of the constant rather than repeated,
and with `sed` rather than an interpreter, because both `keel init` and `keel doctor` are asserted
to start `python3` at most ten times:

```bash
            local cw; cw="$(json_get .keel/profile.json gates.context_window 2>/dev/null || true)"
            # The bound is LONG_WINDOW, read from the one place it is defined. A second literal here
            # would drift the day a larger model ships, and that is exactly the day it matters.
            local cwmax; cwmax="$(sed -n 's/^LONG_WINDOW = //p' "$HERE/lib/context_watch.py" | tr -d '_' | head -n1)"
            local cwnum=0
            case "$cw" in ''|*[!0-9]*) ;; *) cwnum=1 ;; esac
            if [ "$cwnum" = 1 ] && [ -n "$cwmax" ] && [ "$cw" -gt "$cwmax" ]; then
                warn "gates.context_window is $cw, above the largest context window that exists. The watchdog is using $cwmax. Correct the value, or a session will never be warned."
            elif [ -n "$cw" ] && [ "$cw" != "None" ]; then
                good "context watchdog available (window $cw from gates.context_window, raised automatically if a session is observed exceeding it). KEEL_CONTEXT_WINDOW overrides it exactly."
            else
                good "context watchdog available (window assumed 200000, raised once a session is observed exceeding it). Projects initialised since 0.10.0 carry gates.context_window; set it here to start from a larger value."
            fi
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on all three, and task 7's four still pass.
Then run the full suite: `tests/run-tests.sh`, and the linter:
`shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`
Expected: both clean. The suite includes the assertion that `keel doctor` starts `python3` at most
ten times; `sed` is not `python3`, so it must still pass. If it does not, stop and report.

- [x] **Step 5: Commit**

```bash
git add bin/keel tests/test-keel.sh
git commit -m "feat(doctor): report a context window that was bounded

A silent clamp relocates the failure the bound was added to prevent. The
maximum is read from LONG_WINDOW with sed rather than repeated, because
doctor is held to at most ten interpreter starts."
```

---

### Task 9: An understated window does not make an ordinary session noisy

**Story:** S-10
**Files:**
- Test: `tests/test-context-watch.sh`

**Interfaces:**
- Consumes: `transcript`, `fire`, `$work` from `tests/test-context-watch.sh:31-49`
- Produces: nothing. This is the end-to-end proof of the whole plan

**Done when:** `tests/test-context-watch.sh` passes and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the test for behaviour believed correct**

Append to `tests/test-context-watch.sh`, after the cost block:

```bash
# ---- end to end ------------------------------------------------------------
#
# The whole plan in one assertion. A profile written by keel init says 200000. The session has used
# 400000 tokens, which is 200% of the written window and 40% of the real one. Before the floor, the
# hook stopped this session on its first tool call and never lifted. It must now be silent.
transcript "$work/e2e.jsonl" 400000 'claude-opus-5'
printf '{"docs_root":"docs/keel","gates":{"context_window":200000}}\n' > "$work/.keel/profile.json"
out="$(fire UserPromptSubmit "$work/e2e.jsonl" "$work")"
[ -z "$out" ] && ok "a 400k session in a project written with 200000 is silent" \
  || bad "e2e" "expected silence at 40 percent of a raised window, got: $out"

# And the warning still fires for a session that really is filling a 200000 window.
transcript "$work/warn.jsonl" 150000 'claude-opus-5'
out="$(fire UserPromptSubmit "$work/warn.jsonl" "$work")"
case "$out" in *"75%"*) ok "the warn still fires at 75 percent of a genuine 200000 window" ;;
  *) bad "e2e" "the floor silenced a warning that should have fired: $out" ;; esac
printf '{"docs_root":"docs/keel"}\n' > "$work/.keel/profile.json"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-context-watch.sh`
Expected: PASS on both. **A `verify` story: passing here is the point.** These assert the outcome
tasks 1, 2 and 5 exist to produce.

To prove the first assertion is not vacuous, temporarily revert `window_for`'s floor block to
`return` the configured value first, run the test, watch it fail with
`expected silence at 40 percent of a raised window, got: PAUSE. Context is at 200%`, then restore.
Record that you did. This is the single most valuable check in the plan: it is the original defect,
reproduced end to end.

- [x] **Step 3: There is no implementation step**

Nothing to write. Tasks 1, 2 and 5 produced this behaviour; this task proves it from the outside.

- [x] **Step 4: Run the full suite**

Run: `tests/run-tests.sh`
Expected: green.

- [x] **Step 5: Commit**

```bash
git add tests/test-context-watch.sh
git commit -m "test(watchdog): prove a written window does not stop a larger session

400k tokens against a profile saying 200000: 200% of the written window
and 40% of the real one. This is the defect the floor was written for,
asserted through the hook rather than the arithmetic."
```

---

### Task 10: The session prefix and the no-python path are untouched

**Story:** S-11
**Files:**
- Test: `tests/test-session-start.sh`. Note it defines `HOOK` and `tmp`, not `ROOT`, and uses
  `if/else` around `ok`/`bad` rather than the `&& ok || bad` idiom of the other suites
- Test: `tests/test-context-watch.sh`

**Interfaces:**
- Consumes: `hooks/session-start`, `hooks/context-watch`
- Produces: nothing

**Done when:** `tests/test-session-start.sh` and `tests/test-context-watch.sh` pass, and
`tests/run-tests.sh` is green.

- [x] **Step 1: Write the test for behaviour believed correct**

Append to `tests/test-session-start.sh`:

```bash
# Every request of every session carries this prefix, so a byte added here is paid forever. It
# measured about 356 estimated tokens on 2026-08-18 against a 400 ceiling, and the remaining
# headroom is already spoken for by two other ideas. Nothing in the context window work touches
# this file; this is what says so a year from now.
# Measured the same way tests/validate-skills.sh:282 does, at chars over 3.6, so the two can never
# disagree about the number. Run from the repository root, as run-tests.sh does.
chars=$(bash hooks/session-start 2>/dev/null | wc -c | tr -d ' ')
est=$(( chars * 10 / 36 ))
if [ "$est" -le 356 ]; then
    ok "the injected session prefix is still about $est tokens, at or under 356"
else
    bad "prefix" "the prefix grew to about $est tokens; the 400 ceiling has 44 tokens of headroom and it is spoken for"
fi
```

Append to `tests/test-context-watch.sh`, after the end-to-end block:

```bash
# The watchdog does nothing at all without python3, rather than printing an apology on every
# prompt. doctor is what reports the silence; the hook must not.
# PATH is emptied rather than pointed at /nonexistent, and bash is resolved to an absolute path
# first. hooks/context-watch is `#!/usr/bin/env bash`, so a PATH with no bash in it fails to exec
# the hook at all: rc 127 and an env error, which looks like a pass to a careless assertion and
# never reaches the python3 check this is testing.
mkdir -p "$work/empty"
bash_bin="$(command -v bash)"
out="$(printf '{"hook_event_name":"UserPromptSubmit","transcript_path":"%s","cwd":"%s","session_id":"s-np","tool_name":"Bash"}' "$work/e2e.jsonl" "$work" | PATH="$work/empty" "$bash_bin" "$HOOK" 2>/dev/null)"; rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "the watchdog is silent and exits 0 when python3 is absent" \
  || bad "no python" "rc=$rc out=$out"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-session-start.sh` then `tests/test-context-watch.sh`
Expected: PASS on both. **A `verify` story.** Confirm the prefix assertion bites by temporarily
changing `-le 356` to `-le 10`, watching it fail, and changing it back. Record that you did.

- [x] **Step 3: There is no implementation step**

Nothing to write. No task in this plan modifies `hooks/session-start` or `hooks/context-watch`.

- [x] **Step 4: Run the full suite**

Run: `tests/run-tests.sh`
Expected: green. Then confirm NFR-02 directly:
`git diff --stat HEAD~9 -- hooks/`
Expected: no output. If `hooks/` changed at any point in this plan, NFR-02 is violated and must be
reported rather than absorbed.

- [x] **Step 5: Commit**

```bash
git add tests/test-session-start.sh tests/test-context-watch.sh
git commit -m "test(hooks): pin the session prefix size and the no-python silence

The prefix is in every request of every session and has 44 tokens of
headroom that two other ideas are already competing for. The watchdog
staying silent without python3 was documented and untested."
```

---

## Story coverage

| Story | Kind | Task | Note |
|---|---|---|---|
| S-01 | fix | 1 | |
| S-02 | build | 2 | |
| S-03 | verify | 3 | |
| S-04 | verify | 4 | NFR-04 verified by task 4 step 4's `git diff --stat`, not by an assertion |
| S-05 | build | 5 | Must not land before tasks 1 and 2 |
| S-06 | verify | 6 | |
| S-07 | fix | 7 | The docstring quarter of FR-10 lands in tasks 1 and 2, so no commit leaves the function contradicting itself |
| S-08 | build | 8 | |
| S-09 | verify | 7 | Folded: it asserts the same two doctor messages task 7 rewrites |
| S-10 | verify | 9 | The end to end proof of the plan |
| S-11 | verify | 10 | |

Eleven stories, ten tasks. Every story maps to at least one task.

## What this plan could not settle

Nothing. Every open question in the PRD was answered before approval, and no step required a
decision the reader has to make.

Two things are deliberately not here, and are recorded rather than forgotten:

- **The handoff pointer at session start.** PRD out of scope, blocked on PRD Q3, how a stale
  handoff is detected. It is the remaining half of `docs/ideas/context-window-at-init.md`.
- **Documenting `gates.context_window` for users.** Task 7 fixes the schema description, which is
  where the key is defined, but the key still appears in no document a user reads. That is
  `docs/ideas/profile-key-documentation.md`, which found 35 of 59 keys with no description at all.

---

## After the review, 2026-08-18

`review-code` ran against the ten commits, with the `code-review` plugin as the correctness pass.
Three findings blocked and three more were fixed alongside them, in four further commits. They are
recorded here because the plan is the record of what happened, and none of them were anticipated by
it.

| Finding | Fix | Commit |
|---|---|---|
| `keel doctor` reported `gates.context_window` verbatim, so a value at or below the default was discarded by the floor while being announced as in force | Doctor reports the window actually in use, and says why it differs from the file | `a5bf6bc` |
| Doctor claimed `KEEL_CONTEXT_WINDOW` overrides while never reading it, and bounded only the profile value | Doctor reads the environment variable and warns when that is above the maximum | `a5bf6bc` |
| A value wider than a 64 bit integer leaked `integer expression expected` into doctor's output and then fell through to the healthy branch | Width capped before comparison, and a non-numeric value warns rather than being reported | `a5bf6bc` |
| Task 10's session-prefix guard ran the hook by a relative path with only an upper bound, so from any other directory it measured 0 tokens and passed. The hook could have been deleted and it stayed green | Absolute `$HOOK`, plus a lower bound so a silent failure is a failure | `8bdb5ee` |
| `measure` and `handoff` ignored the profile, so a 1M project's handoff header read 75% where the hook sat silent at 15% | Both take an optional project directory | `5ce4eab` |
| No `CHANGELOG.md` entry, required in the same commit by `docs/standards.md:129` and `CONTRIBUTING.md:125` | An `Unreleased` section covering Added, Changed, Fixed and a known gap | `9313b44` |

**One of those fixes was itself wrong and had to be debugged.** The first attempt at the `measure`
fix read the profile from `os.getcwd()`, which made the same transcript report two different windows
depending on where the command was run, and broke three pre-existing assertions. `keel:debug` traced
it: these commands are handed a transcript and nothing else, and a transcript does not say which
project it belongs to. The hook only avoids the problem because Claude Code hands it the session's
own `cwd`. The project is now named rather than guessed.

**Two findings were deliberately not fixed**, and neither is silent:

- Test and implementation share a commit in five of the ten original commits, so the history cannot
  prove the test came first. Every failure was witnessed in session and is recorded above, but the
  plan's own step 5 asked for a single commit and that was the wrong instruction. Future plans should
  commit the failing test first.
- `docs/05-token-and-memory-design.md` documents the watchdog in detail and says nothing about how
  the window is decided, which is now a four part rule. The schema description carries it instead.

**A finding that cannot be closed by more work.** `CONTRIBUTING.md:128` requires review by someone
other than the change's own author. This change was written and reviewed by the same session, so the
review above is a first pass and not the required one.
