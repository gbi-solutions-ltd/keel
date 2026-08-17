# Boundary instrumentation

For a bug in a path that crosses components, the fastest route to the cause is evidence at every
boundary, gathered in one run.

## Why this beats reasoning

In a path like `client -> API -> service -> queue -> worker -> database` there are six places the
data can be wrong. Reasoning picks one, usually the one you understand best, and a wrong pick
costs a full cycle. Instrumenting all six costs one run and eliminates five of them.

The rule: **instrument every boundary, run once, then read.** Instrumenting one boundary at a time
is the same guessing with extra steps.

## What to log at each boundary

1. What entered, in full.
2. What left, in full.
3. The relevant configuration as this component sees it.
4. A correlation id, so one request can be followed across all of them.

Then find the first boundary where what left does not match what should have left. The bug is in
that component and nowhere upstream of it.

## Example: a deploy signing with the wrong identity

```bash
# Layer 1: the pipeline
echo "IDENTITY: ${IDENTITY:+SET}${IDENTITY:-UNSET}"

# Layer 2: the build script
env | grep -c IDENTITY || echo "IDENTITY absent from build environment"

# Layer 3: the signing environment
security find-identity -v | head

# Layer 4: the call itself
codesign --sign "$IDENTITY" --verbose=4 "$APP"
```

One run tells you the secret existed in the pipeline and was absent in the build script, so the
bug is the propagation between them. Without this you would have spent the afternoon on the
keychain.

## Check the command before you believe its result

Three times while building this toolkit a command-level failure was read as a finding about the
code:

| What happened | What it looked like | What it was |
|---|---|---|
| `grep --include=*.ts` unquoted, so the shell expanded it | "zero call sites, dead code" | The grep never ran |
| A whole command block died on a parse error before its `cp` | "the fix did not work" | The restore never ran, so the test used a stale file |
| `timeout` invoked on macOS, where it does not exist | "the test command fails" | `timeout` was not found; the tests were fine |

Each cost a wrong conclusion, and one of them nearly produced a wrong fix.

Before believing a negative result, confirm the command ran. `command -v` the tool, echo the exit
code separately from the output, or run the command alone without the `||` fallback that turns a
crash into a tidy message.

A result you did not get is not the same as a result of nothing.

## Logging the absence of a value

`${VAR:+SET}${VAR:-UNSET}` prints `SET` or `UNSET` and never prints the value. Use it for
credentials.

The common mistake is `echo "VAR=$VAR"`, which prints an empty line for an unset variable and for
an empty one, so it cannot distinguish them. Those are different bugs, and the empty case is the
one that starts the process and then fails later.

## Remove the scaffold, keep one or two lines

Once the cause is found, delete the debugging output. But ask whether one of those boundaries
should stay instrumented permanently: if it was invisible during this incident, it will be
invisible during the next one.

Promote at most one or two, at `INFO` or `DEBUG`, with the correlation id. Committing the whole
scaffold is how logs become unreadable.

## In a test suite

The same technique applies to a failing test you did not write:

- Print the actual value at every assertion boundary, not only the failing one.
- **Run the single test alone.** Passing alone and failing in the suite means the bug is shared
  state, not the test. That one check saves the most time of anything here.
- Log setup and teardown entry and exit. A teardown that fails silently leaves state for the next
  test, producing a failure in a test that has nothing to do with the cause.
- For a worker or handle that outlives the test, log what was created and what was closed. A
  suite that hangs or force-exits is telling you something was created and never closed, and the
  pairing is what identifies it.
