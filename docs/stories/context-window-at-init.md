# Stories: context window set at init, and correctable by observation

| | |
|---|---|
| Derived from | `docs/prd/context-window-at-init.md`, PRD status `approved` |
| Date | 2026-08-18 |
| Stories | 11 (build: 3, verify: 6, fix: 2) |
| Coverage | 17 of 17 requirements covered. See the table at the end |

> Story IDs are permanent. Plans trace to them. Retire rather than renumber.
> The PRD is approved, so these stories are not provisional. Eight of the seventeen requirements
> they satisfy are `inferred`, and each story names which.

**There are no `decide` stories.** The PRD's Q1 and Q2 were answered before approval and became
requirements; Q5 was flagged in the approval request and approved as written; Q3 and Q4 belong to
other documents. Nothing here waits on a decision.

**The ordering constraint that matters more than any other.** S-05 must not ship before S-01 and
S-02. Writing `gates.context_window` into every profile while a configured value is still a ceiling
would hard-stop a 1M session at 170,000 tokens permanently, which is the failure the PRD exists to
prevent. This is a correctness dependency, not a convenience one.

---

## Epic E-01: The window is computed correctly

**Goal:** the number the watchdog measures against is right, whatever the profile says.
**Requirements:** FR-01, FR-02, FR-03, FR-11, FR-12, NFR-01, NFR-04
**Stories:** S-01, S-02, S-03, S-04
**Ships when:** a configured window below observed occupancy is raised, one above 1,000,000 is
lowered, and every existing assertion in `tests/test-context-watch.sh` still passes unmodified.

### S-01 A configured window is a floor, not a ceiling

| | |
|---|---|
| Kind | fix |
| Satisfies | FR-01 |
| Size | M |
| Depends on | none |
| Status of requirement | FR-01 confirmed |

**As a** developer running a 1M session in a project whose profile understates the window
**I want** the watchdog to raise its estimate once my session proves the window is larger
**So that** it does not pause me at 170,000 tokens with 830,000 still available

**Acceptance criteria**

```gherkin
Scenario: a configured window smaller than observed occupancy is raised
  Given a project profile setting gates.context_window to 200000
  And a transcript whose occupancy is 400000 tokens
  When the window is measured
  Then the reported window is 1000000
  And the reported occupancy is at most 100 percent

Scenario: a configured window larger than observed occupancy is left alone
  Given a project profile setting gates.context_window to 1000000
  And a transcript whose occupancy is 100001 tokens
  When the window is measured
  Then the reported window is 1000000

Scenario: no configured window, behaviour is unchanged
  Given a project profile setting no context window
  And a transcript whose occupancy is 100001 tokens
  When the window is measured
  Then the reported window is 200000

Scenario: a small session is still not promoted
  Given a project profile setting gates.context_window to 200000
  And a transcript whose occupancy is 100001 tokens
  When the window is measured
  Then the reported window is 200000
```

**Notes:** `window_for` returns the configured value at `lib/context_watch.py:142-146`, before
reaching the observation correction at `:149-150`, which is why this is `fix` and not `build`. The
last scenario is the guard the existing suite already has for the unconfigured path
(`tests/test-context-watch.sh:80-83`), restated for the configured one, because a floor implemented
as "always promote" would silently stop protecting ordinary sessions.

### S-02 No window above one million is ever reported

| | |
|---|---|
| Kind | build |
| Satisfies | FR-11, FR-12 |
| Size | S |
| Depends on | S-01 |
| Status of requirement | FR-11 confirmed, FR-12 inferred |

**As a** developer who mistyped the window in a profile
**I want** an impossible value to be treated as the largest window that exists
**So that** a stray zero cannot silence the watchdog for the life of the project

**Acceptance criteria**

```gherkin
Scenario: a profile value above the maximum is bounded
  Given a project profile setting gates.context_window to 200000000
  And a transcript whose occupancy is 100001 tokens
  When the window is measured
  Then the reported window is 1000000

Scenario: the environment variable is bounded the same way
  Given KEEL_CONTEXT_WINDOW is set to 200000000
  And a transcript whose occupancy is 100001 tokens
  When the window is measured
  Then the reported window is 1000000

Scenario: a value at the maximum is untouched
  Given a project profile setting gates.context_window to 1000000
  When the window is measured
  Then the reported window is 1000000

Scenario: the bound is the same constant the observed path uses
  Given the source of lib/context_watch.py
  When the bound is read
  Then it is the LONG_WINDOW constant and not a second literal
```

**Notes:** 1,000,000 is the largest context window any current Claude model offers, verified
2026-08-18 (`CON-06`). It is already the highest value observation can promote to
(`lib/context_watch.py:28`, reached at `:148-150`), so this adds no ceiling the observed path did
not have. The last scenario is what keeps a future larger model a one-line change. The second
scenario is the one to challenge at review: it applies the bound to the environment variable, per
assumption `A8`.

### S-03 The environment variable stays absolute and still outranks the profile

| | |
|---|---|
| Kind | verify |
| Satisfies | FR-02, FR-03 |
| Size | S |
| Depends on | S-01, S-02 |
| Status of requirement | FR-02 confirmed, FR-03 confirmed |

**As a** developer testing the watchdog, or overriding it for one session
**I want** `KEEL_CONTEXT_WINDOW` to mean exactly what I set
**So that** I can force an early stop deliberately, which the floor rule would otherwise prevent

**Acceptance criteria**

```gherkin
Scenario: the environment variable is not raised by observation
  Given KEEL_CONTEXT_WINDOW is set to 50000
  And a transcript whose occupancy is 100001 tokens
  When the window is measured
  Then the reported window is 50000

Scenario: the environment variable outranks the profile
  Given a project profile setting gates.context_window to 1000000
  And KEEL_CONTEXT_WINDOW is set to 500000
  When the window is measured
  Then the reported window is 500000

Scenario: the existing override case is unchanged
  Given KEEL_CONTEXT_WINDOW is set to 500000
  And a transcript whose occupancy is 100001 tokens
  When the window is measured
  Then the reported window is 500000
  And the reported occupancy is 20 percent
```

**Notes:** the third scenario is `tests/test-context-watch.sh:86-88` unchanged, and it must keep
passing without modification. The first scenario is the one that distinguishes this design from the
alternative where both sources are floors: it is currently untested, and it is the behaviour the
test suite itself depends on.

### S-04 The change costs nothing and breaks nothing

| | |
|---|---|
| Kind | verify |
| Satisfies | NFR-01, NFR-04 |
| Size | S |
| Depends on | S-01, S-02 |
| Status of requirement | NFR-01 inferred, NFR-04 inferred |

**As a** developer whose every prompt and tool call runs this hook
**I want** the floor and the bound to be arithmetic on values already in hand
**So that** a watchdog that runs constantly does not start touching the filesystem to do it

**Acceptance criteria**

```gherkin
Scenario: no new reads
  Given the implementation of window_for
  When its body is read
  Then it performs no filesystem, network or subprocess access

Scenario: the existing suite is untouched
  Given tests/test-context-watch.sh as it stands before this work
  When the suite is run against the new implementation
  Then every assertion passes with no edit to the file
```

**Notes:** `window_for` already receives `configured` and `observed` as arguments
(`lib/context_watch.py:120`). NFR-04 was verified by inspection on 2026-08-18 before the PRD was
written: every configured value in the existing suite exceeds its fixture's occupancy. This story
turns that inspection into a run.

---

## Epic E-02: Init settles the window

**Goal:** a new project has a working window setting without anyone editing JSON.
**Requirements:** FR-04, FR-05, FR-06
**Stories:** S-05, S-06
**Ships when:** `keel init` on a fresh fixture produces a profile containing
`gates.context_window`, and a re-run over a hand-set value leaves it alone.

### S-05 Init writes the context window

| | |
|---|---|
| Kind | build |
| Satisfies | FR-04 |
| Size | S |
| Depends on | S-01, S-02 |
| Status of requirement | FR-04 confirmed |

**As a** developer initialising a project with keel
**I want** the context window written for me
**So that** I do not have to discover an undocumented key before the watchdog is correct

**Acceptance criteria**

```gherkin
Scenario: a new profile carries the key
  Given a directory with no .keel/profile.json
  When keel init -y is run
  Then the profile's gates object contains context_window with the value 200000

Scenario: the generated profile is still valid
  Given a directory with no .keel/profile.json
  When keel init -y is run
  Then the profile parses as JSON
  And keel does not report having generated an invalid profile

Scenario: the schema version does not move
  Given the profile written by keel init -y
  When its schema_version is compared with the previous release
  Then it is unchanged
```

**Notes:** the gates object is written at `bin/keel:364` and does not currently include this key.
`gates.context_window` is already declared at `templates/profile.schema.json:284`, so no field is
added and `SCHEMA_VERSION` stays put (`CON-01`). **This story is unsafe to ship before S-01 and
S-02**: without the floor, writing 200000 everywhere converts a self-correcting assumption into a
permanent wrong answer.

### S-06 A hand-set window survives re-initialisation

| | |
|---|---|
| Kind | verify |
| Satisfies | FR-05, FR-06 |
| Size | S |
| Depends on | S-05 |
| Status of requirement | FR-05 inferred, FR-06 inferred |

**As a** developer who set the window by hand for a 1M project
**I want** `keel init` to leave my value alone
**So that** re-running it to pick up new keel defaults does not quietly downgrade my session

**Acceptance criteria**

```gherkin
Scenario: re-init preserves a human value
  Given a profile setting gates.context_window to 1000000
  When keel init -y is run again
  Then gates.context_window is still 1000000

Scenario: force replaces it
  Given a profile setting gates.context_window to 1000000
  When keel init --force -y is run
  Then gates.context_window is 200000

Scenario: the replaced value is recoverable in-session
  Given a profile whose gates.context_window was replaced with 200000 by --force
  And a transcript whose occupancy is 400000 tokens
  When the window is measured
  Then the reported window is 1000000
```

**Notes:** `merge_profile` at `bin/keel:290` already gives a non-empty human value precedence, so
the first scenario asserts existing behaviour rather than adding it. The third scenario is why
`--force` is acceptable at all: S-01 makes the downgrade self-correcting. Without S-01 this story's
second scenario would describe a defect rather than a requirement.

---

## Epic E-03: The tool explains the window it is using

**Goal:** nothing keel says or ships still describes a configured window as simply winning.
**Requirements:** FR-08, FR-09, FR-10, FR-13
**Stories:** S-07, S-08, S-09
**Ships when:** all four documented sites describe the floor and the bound, and doctor names both
values when it clamps.

### S-07 Every place that documents the precedence describes what the code does

| | |
|---|---|
| Kind | fix |
| Satisfies | FR-09, FR-10 |
| Size | M |
| Depends on | S-01, S-02 |
| Status of requirement | FR-09 confirmed, FR-10 confirmed |

**As a** developer reading the schema, the doctor output, or the source
**I want** all of them to describe the same rule
**So that** I do not set the key on the strength of a description that stopped being true

**Acceptance criteria**

```gherkin
Scenario: doctor states the value is a floor
  Given a profile setting gates.context_window to 200000
  When keel doctor is run
  Then its context watchdog line names 200000 and its source
  And it states that observation can raise the value

Scenario: doctor's unset message stays accurate for older profiles
  Given a profile setting no context window
  When keel doctor is run
  Then its context watchdog line states the window is assumed and corrected upward

Scenario: no documented site still claims a configured value simply wins
  Given the gates.context_window description in templates/profile.schema.json
  And both context watchdog messages in bin/keel
  And the priority list in window_for's docstring
  When each is read
  Then each describes the floor, the environment override, and the one million bound
```

**Notes:** the four sites are `templates/profile.schema.json:287`, `bin/keel:1269`, `bin/keel:1271`
and `lib/context_watch.py:130-140`. All four currently state that an explicit setting wins outright,
which is why this is `fix`. The second scenario is not redundant: `bin/keel:1271` remains reachable
for every profile written before S-05.

### S-08 Doctor names both values when it bounds a window

| | |
|---|---|
| Kind | build |
| Satisfies | FR-13 |
| Size | S |
| Depends on | S-02, S-07 |
| Status of requirement | FR-13 inferred |

**As a** developer who mistyped the window
**I want** to be told my value was reduced, and to what
**So that** the bound does not silently replace the silent failure it was added to prevent

**Acceptance criteria**

```gherkin
Scenario: a bounded value is reported
  Given a profile setting gates.context_window to 200000000
  When keel doctor is run
  Then its output names 200000000 as configured
  And names 1000000 as the value in use

Scenario: an unbounded value is reported without noise
  Given a profile setting gates.context_window to 1000000
  When keel doctor is run
  Then its output names 1000000
  And says nothing about a value having been reduced
```

**Notes:** the second scenario exists because a message that fires on every healthy project is one
people learn to ignore, which is the reasoning recorded at `bin/keel:307-310` for a different check.

### S-09 Doctor still reports the window and its source

| | |
|---|---|
| Kind | verify |
| Satisfies | FR-08 |
| Size | S |
| Depends on | S-07 |
| Status of requirement | FR-08 inferred |

**As a** developer diagnosing why a session stopped
**I want** doctor to keep telling me which window it is measuring against
**So that** the one command that can explain the watchdog does not lose the ability while being
reworded

**Acceptance criteria**

```gherkin
Scenario: the window is named when configured
  Given a profile setting gates.context_window to 500000
  When keel doctor is run
  Then its output names 500000

Scenario: the window is named when assumed
  Given a profile setting no context window
  When keel doctor is run
  Then its output names 200000
```

**Notes:** a regression guard around S-07, which rewrites both messages. Existing behaviour at
`bin/keel:1267-1271`.

---

## Epic E-04: The watchdog is unchanged everywhere else

**Goal:** this work changes what the window is, and nothing else about the watchdog.
**Requirements:** FR-07, NFR-02, NFR-03
**Stories:** S-10, S-11
**Ships when:** an ordinary session in a project with an understated window is silent, and the
session-start hook injects the same bytes it did before.

### S-10 An understated window does not make an ordinary session noisy

| | |
|---|---|
| Kind | verify |
| Satisfies | FR-07 |
| Size | S |
| Depends on | S-01, S-05 |
| Status of requirement | FR-07 confirmed |

**As a** developer in a normal session on a newly initialised 1M project
**I want** the watchdog to stay silent
**So that** the cost argument for it holds: an ordinary session pays nothing

**Acceptance criteria**

```gherkin
Scenario: silence below the warn threshold after the window is raised
  Given a profile written by keel init, setting gates.context_window to 200000
  And a transcript whose occupancy is 400000 tokens
  When the UserPromptSubmit hook fires
  Then it prints nothing

Scenario: the warn still fires when genuinely near the limit
  Given a profile setting gates.context_window to 200000
  And a transcript whose occupancy is 150000 tokens
  When the UserPromptSubmit hook fires
  Then it warns that context is at 75 percent
```

**Notes:** the first scenario is the end-to-end proof of the whole PRD: 400,000 tokens is 200% of
the written window and 40% of the true one, and the hook must be silent. The second confirms the
floor has not disabled the warning for a session that really is filling a 200,000 window.

### S-11 The session prefix and the no-python path are untouched

| | |
|---|---|
| Kind | verify |
| Satisfies | NFR-02, NFR-03 |
| Size | S |
| Depends on | none |
| Status of requirement | NFR-02 confirmed, NFR-03 inferred |

**As a** developer paying for every token in every request
**I want** this work to add nothing to the always-loaded prefix
**So that** the 44 tokens of headroom left in the session-start hook stay available for the ideas
that need them

**Acceptance criteria**

```gherkin
Scenario: the injected prefix is unchanged
  Given the bytes hooks/session-start printed before this work
  When it is run after this work
  Then it prints the same bytes

Scenario: the watchdog stays inert without python3
  Given python3 is not on PATH
  When the UserPromptSubmit hook fires
  Then it prints nothing
  And it exits 0
```

**Notes:** nothing in this PRD touches `hooks/session-start`; this asserts that, because the
follow-up work for the handoff pointer will need the headroom and
`docs/ideas/plain-language-chat.md` is competing for the same 44 tokens. The hook measured 356
estimated tokens against a 400 ceiling on 2026-08-18.

---

## Coverage

| Requirement | Status | Stories | Note |
|---|---|---|---|
| FR-01 | confirmed | S-01 | |
| FR-02 | confirmed | S-03 | Bound applied by S-02 |
| FR-03 | confirmed | S-03 | |
| FR-04 | confirmed | S-05 | |
| FR-05 | inferred | S-06 | |
| FR-06 | inferred | S-06 | |
| FR-07 | confirmed | S-10 | |
| FR-08 | inferred | S-09 | |
| FR-09 | confirmed | S-07 | |
| FR-10 | confirmed | S-07 | |
| FR-11 | confirmed | S-02 | |
| FR-12 | inferred | S-02 | |
| FR-13 | inferred | S-08 | |
| NFR-01 | inferred | S-04 | |
| NFR-02 | confirmed | S-11 | |
| NFR-03 | inferred | S-11 | |
| NFR-04 | inferred | S-04 | |
| CON-01 | confirmed | S-05 | Constraint, asserted by S-05's third scenario rather than owned by a story |
| CON-02 | confirmed | none | Constraint. Correctly uncovered: it records residual exposure this work accepts |
| CON-03 | confirmed | none | Constraint. Correctly uncovered |
| CON-04 | confirmed | none | Constraint. Correctly uncovered: `/clear` is out of scope |
| CON-05 | confirmed | S-11 | Constraint, asserted by S-11's second scenario |
| CON-06 | confirmed | S-02 | Constraint, encoded by S-02's fourth scenario |

**Forward:** 17 of 17 `FR` and `NFR` requirements have at least one story. No gaps. Three of the six
constraints are correctly uncovered, being statements of accepted exposure rather than work; the
other three are asserted inside a story and named above.

**Backward:** every story's `Satisfies` names a requirement that exists in the PRD. No story
satisfies nothing.

## Order

Dependency order, critical path marked.

| # | Story | Kind | Critical path |
|---|---|---|---|
| 1 | S-01 A configured window is a floor | fix | **yes** |
| 2 | S-02 No window above one million | build | **yes** |
| 3 | S-03 The environment variable stays absolute | verify | |
| 4 | S-04 The change costs nothing and breaks nothing | verify | |
| 5 | S-07 Every documented place describes what the code does | fix | |
| 6 | S-05 Init writes the context window | build | **yes** |
| 7 | S-06 A hand-set window survives re-initialisation | verify | |
| 8 | S-08 Doctor names both values when it bounds | build | |
| 9 | S-09 Doctor still reports the window and its source | verify | |
| 10 | S-10 An understated window does not make a session noisy | verify | **yes** |
| 11 | S-11 The session prefix and the no-python path are untouched | verify | |

S-11 has no dependencies and can be done at any point. S-01, S-02, S-05 and S-10 are the path: they
are the floor, the bound, the write, and the end-to-end proof that the three together do what the
PRD claims.
