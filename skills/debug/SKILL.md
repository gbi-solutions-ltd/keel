---
name: debug
description: Use when encountering any bug, test failure, unexpected behaviour, performance anomaly, build failure, or integration problem, before proposing a fix.
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob, Agent]
---

# Debug

## Overview

Find the root cause, then fix that. A symptom fix is a second bug wearing the first one's clothes.

**Core principle:** you cannot fix what you have not explained. If you cannot say why it happens, you
are guessing.

## The iron law

```
NO FIX WITHOUT AN EXPLANATION FIRST
```

Phase 1 is not slow. Guessing is, because each wrong guess adds code you must reason around.

## Phase 1: Establish the facts

1. **Read the error.** All of it, stack trace included. Errors frequently contain the answer, and
   skipping to the code is how you miss it. A service following the observability standard logs
   `op`, `actor`, and a `remediation` field naming the skill to use: start from those rather than
   the stack.
2. **Confirm you are reading the right code.** In a session touching several repositories, check the
   file you opened belongs to the system that failed. Diagnosing repository A's symptom against
   repository B's code produces a confident, wrong answer.
3. **Reproduce it, then isolate it.** Exact steps, every time. **For a test failure, run that test
   alone first:** passing alone and failing in the suite means shared state, not the test, and that
   single check redirects the whole investigation.
4. **Check what changed.** `git log`, dependency bumps, config and environment.
5. **Instrument the boundaries.** In a multi-component path, log what enters and leaves each, then run
   once. See [references/boundary-instrumentation.md](references/boundary-instrumentation.md). The
   evidence names the failing component instead of you picking one.
6. **Trace backwards to the source.** Keep asking what passed the bad value until you reach where
   it was created. Fix there, not where it surfaced. See
   [references/root-cause-tracing.md](references/root-cause-tracing.md).

## Phase 2: Compare against something that works

Find the nearest working case: the same operation on another entity, or the same pattern elsewhere.

List **every** difference, including ones that "cannot matter". The one you dismiss is frequently the
cause. Following a reference? Read all of it; partial understanding guarantees a partial fix.

## Phase 3: One hypothesis, one test

State it in a sentence: "X happens because Y." Specific enough to be wrong.

Then make the smallest change that would confirm or refute it. One variable. Do not fix three
things and run the suite; you will not know which mattered, and you may have added a bug.

Refuted? Form a new hypothesis from what you learned. Do not stack another fix on top.

**Do not know?** Say so. "I do not understand why X" is a useful sentence. Pretending is not.

## Phase 4: Fix the cause

1. **Write a failing test that reproduces the bug.** Before the fix.
   **REQUIRED SUB-SKILL:** `keel:tdd`.
2. **Fix the root cause.** One change. No "while I am here" improvements, no bundled
   refactoring; both make the fix unreviewable.
3. **Verify.** The new test passes, the suite passes, the reproduction no longer reproduces.

## The three-fix circuit breaker

After **three** failed fixes, stop. Three failures each revealing a new problem elsewhere is not
bad luck, it is the design being wrong. Raise the architecture question instead; a fourth attempt
without that conversation is how a bug becomes a rewrite.

## Red flags: stop and return to Phase 1

"Quick fix now, investigate later." "Let me just try changing X." "It is probably the cache."
Proposing a fix before tracing the data flow. Several fixes at once. A fix added while a previous one
is unverified. Any sentence starting "I do not fully understand this but".

## When there is genuinely no root cause

Sometimes it is environmental, a race, or a third party, but you earn that only after Phase 1.
Document what you ruled out, handle it explicitly, and add the logging that would settle it next time.
Most such findings are incomplete investigations.

## Common mistakes

| Mistake | Instead |
|---|---|
| Fixing where the error surfaced | Trace to where the bad value originated |
| "Fixed" with no test | A bug with no regression test returns |
| Skipping it because the bug looks obvious | Obvious bugs have root causes too |
| A fourth fix attempt | Three failures means question the design |
