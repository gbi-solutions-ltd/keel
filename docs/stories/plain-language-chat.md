# Stories: plain language in chat replies

| | |
|---|---|
| Derived from | `docs/prd/plain-language-chat.md`, PRD status `approved` |
| Date | 2026-08-18 |
| Stories | 8 (build: 7, verify: 1, fix: 0, decide: 0) |
| Coverage | 22 of 22 requirements covered. See the table at the end |

> Story IDs are permanent. Plans trace to them. Retire rather than renumber.
> The PRD is approved, so these stories are not provisional. Every requirement it carries is
> `confirmed`; none is `inferred` or `disputed`, and there are no open questions left to settle.
> That is unusual, and it is why there are no `decide` stories.

**Nothing here is blocked.** An earlier draft said `S-01` waited on a shared `SCHEMA_VERSION` bump
with the profile documentation work. That was checked before planning and is wrong: that work
shipped in PR #29 and moves no schema version. `S-01` carries the bump to 2 alone and can start
immediately.

---

## Epic E-01: The key exists and travels with the project

**Goal:** a project can say `explain_level` in its profile, `keel init` writes it, and a user can
find out what it does without reading the schema.
**Requirements:** FR-01, FR-02, FR-03, FR-11, FR-13
**Stories:** S-01, S-02, S-03
**Ships when:** `keel init` on a fresh repository produces a profile containing
`"explain_level": "technical"`, and `docs/profile-keys.md` has a row for it.

### S-01 Declare `conventions.explain_level` and move the schema version

| | |
|---|---|
| Kind | build |
| Satisfies | FR-01, FR-02, FR-11 |
| Size | M |
| Depends on | nothing |
| Status of requirement | FR-01 confirmed, FR-02 confirmed, FR-11 confirmed |

**As a** developer setting up keel on a project
**I want** the profile schema to declare a key for reply vocabulary
**So that** the setting is a documented part of the profile rather than a convention I have to know

**Acceptance criteria**

```gherkin
Scenario: the key is declared with exactly two values
  Given templates/profile.schema.json
  When conventions.explain_level is read
  Then its enum is exactly ["technical", "plain"]
  And its default is "technical"
  And it carries a non-empty description

Scenario: response_style is untouched
  Given templates/profile.schema.json
  When conventions.response_style is read
  Then its enum is exactly ["terse", "verbose"]

Scenario: a profile using the new value validates
  Given a profile with conventions.explain_level set to "plain"
  When it is validated against the schema
  Then validation passes

Scenario: an unknown value is rejected by the schema
  Given a profile with conventions.explain_level set to "simple"
  When it is validated against the schema
  Then validation fails

Scenario: the schema drift check passes
  Given bin/keel declares SCHEMA_VERSION=2
  And tests/validate-skills.sh schema_fingerprint_for has a line for 2
  And the line for version 1 is unedited
  When tests/validate-skills.sh runs
  Then it reports no schema fingerprint finding
```

**Notes:** the version 1 fingerprint line is a released version's record. Editing it rather than
adding a line for 2 leaves every existing profile claiming a field set it does not have, which is
the failure `tests/validate-skills.sh:53-70` exists to prevent.

### S-02 `keel init` writes the key into a new profile

| | |
|---|---|
| Kind | build |
| Satisfies | FR-03 |
| Size | S |
| Depends on | S-01 |
| Status of requirement | confirmed |

**As a** developer running `keel init` on a new project
**I want** `explain_level` written into the profile with its default
**So that** I can see the setting exists and change it without reading the schema or the docs

**Acceptance criteria**

```gherkin
Scenario: a fresh init writes the key
  Given an empty repository
  When keel init runs
  Then .keel/profile.json contains conventions.explain_level set to "technical"

Scenario: init on an existing version 1 profile merges rather than overwrites
  Given a profile at schema version 1 with conventions.response_style set to "verbose"
  When keel init runs again
  Then conventions.explain_level is present and set to "technical"
  And conventions.response_style is still "verbose"
```

**Notes:** the second scenario is how the key reaches a project that already exists, which is what
`CON-06` and the doctor drift message point a user at.

### S-03 The generated key reference gains a row

| | |
|---|---|
| Kind | build |
| Satisfies | FR-13 |
| Size | S |
| Depends on | S-01 |
| Status of requirement | confirmed |

**As a** user trying to work out what a profile key does
**I want** `explain_level` documented on the reference page alongside every other key
**So that** I do not have to read the JSON schema to find out what values it takes

**Acceptance criteria**

```gherkin
Scenario: the reference page has a row for the key
  Given the schema declares conventions.explain_level
  When tests/generate-profile-keys.sh runs
  Then docs/profile-keys.md contains a row for conventions.explain_level
  And the row states its two values and which one is the default

Scenario: the coverage test passes
  When tests/test-profile-keys.sh runs
  Then it reports no key without a row
```

**Notes:** the page is generated, so the work is confirming the generator picks the key up rather
than writing a row. A hand-written row would be reverted by the next run.

---

## Epic E-02: The hook selects from both dials

**Goal:** the injected paragraph is chosen by length and vocabulary together, and every one of the
four combinations produces a determined output.
**Requirements:** FR-04, FR-05, FR-06, FR-07, FR-08, FR-09, FR-10, FR-12, FR-15, FR-17, NFR-03, NFR-04
**Stories:** S-04, S-05
**Ships when:** all four combinations inject the paragraph the PRD names, and a session with an
unreadable profile still gets the router pointer.

### S-04 Four combinations, one determined output each

| | |
|---|---|
| Kind | build |
| Satisfies | FR-04, FR-05, FR-06, FR-09, FR-10, FR-12, NFR-03, NFR-04 |
| Size | L |
| Depends on | S-01 |
| Status of requirement | all confirmed |

**As a** developer whose project has set both dials
**I want** the session hook to honour both of them together
**So that** choosing plain vocabulary does not silently change how long the replies are, or the
reverse

**Acceptance criteria**

```gherkin
Scenario: terse and technical is unchanged from today
  Given a profile with response_style "terse" and explain_level "technical"
  When hooks/session-start runs
  Then the injected context contains the brevity paragraph shipping today
  And the output is byte-identical to the output before this change

Scenario: terse and plain
  Given a profile with response_style "terse" and explain_level "plain"
  When hooks/session-start runs
  Then the injected context contains the paragraph FR-15 fixes

Scenario: verbose and technical injects no paragraph
  Given a profile with response_style "verbose" and explain_level "technical"
  When hooks/session-start runs
  Then the injected context contains the router pointer
  And it contains no paragraph about reply length or vocabulary

Scenario: verbose and plain injects a paragraph rather than falling through to silence
  Given a profile with response_style "verbose" and explain_level "plain"
  When hooks/session-start runs
  Then the injected context contains the paragraph FR-17 fixes

Scenario: an absent or unrecognised value falls back to technical
  Given a profile with no explain_level key
  When hooks/session-start runs
  Then the output is byte-identical to the same profile with explain_level "technical"

Scenario: an unreadable profile still yields a usable session
  Given a profile file that cannot be read
  When hooks/session-start runs
  Then it exits 0
  And the injected context contains the router pointer
```

**Notes:** the match is textual, so `"explain_level": "plain"` and `"explain_level":"plain"` must
both be recognised, and no `python3` may enter this hook. `hooks/session-start:16-20` states why.
The first scenario is the regression guard: today's default configuration must not move a byte, or
every existing session pays a cache miss for a feature it did not ask for.

### S-05 The two plain paragraphs, inside the character budget

| | |
|---|---|
| Kind | build |
| Satisfies | FR-07, FR-08, FR-15, FR-17 |
| Size | M |
| Depends on | S-04 |
| Status of requirement | all confirmed |

**As a** non-technical person reading keel's replies
**I want** a technical term defined the first time it appears
**So that** I can follow the reply without asking what a word meant

**Acceptance criteria**

```gherkin
Scenario: the plain paragraphs say define, not replace
  Given either plain paragraph
  Then it instructs that a technical term is defined on first use
  And it does not instruct that a term is replaced with a lay equivalent

Scenario: the exempted statements are named item by item
  Given either plain paragraph
  Then it names which verifications ran and which were skipped
  And it names assumptions, deviations, and a Done when command's output

Scenario: terse and plain fits the budget
  Given a profile with response_style "terse" and explain_level "plain"
  When hooks/session-start runs
  Then the output is 1279 characters

Scenario: verbose and plain fits the budget
  Given a profile with response_style "verbose" and explain_level "plain"
  When hooks/session-start runs
  Then the output is 1269 characters
```

**Notes:** both wordings are fixed in the PRD under section 5 and were measured through the real
hook on 2026-08-18. Neither carries the pointer sentence, "Say what changed, where it is, and what
needs a decision": it does not fit, in either form, and giving it up rather than the exemption list
was the decision recorded as `FR-15`. The character counts are asserted exactly rather than as an
upper bound, so that an edit to the wording has to be a deliberate act with a re-measurement, not a
drift.

---

## Epic E-03: The budget stays enforced

**Goal:** the check that guards the always-loaded block measures every combination, not the one the
repository happens to be configured for.
**Requirements:** NFR-01, NFR-02
**Stories:** S-06
**Ships when:** a wording that fits `terse` plus `technical` but breaks `verbose` plus `plain`
fails the build.

### S-06 The size check covers every combination

| | |
|---|---|
| Kind | build |
| Satisfies | NFR-01, NFR-02 |
| Size | M |
| Depends on | S-04 |
| Status of requirement | confirmed |

**As a** maintainer of keel
**I want** the always-loaded budget checked against all four configurations
**So that** a paragraph that only fits the configuration this repository uses cannot reach a release

**Acceptance criteria**

```gherkin
Scenario: every combination is measured
  When tests/validate-skills.sh runs
  Then it measures the hook output for all four combinations of response_style and explain_level

Scenario: a combination over the rule fails the build
  Given a plain paragraph long enough to take any combination past 356 tokens
  When tests/validate-skills.sh runs
  Then it reports a finding naming that combination
  And the finding states the measured token count

Scenario: today's shipping configuration still passes
  Given the four wordings the PRD fixes
  When tests/validate-skills.sh runs
  Then it reports no size finding
```

**Notes:** the check today runs the hook once from the repository root, at
`tests/validate-skills.sh:281`, so it measures whatever keel's own profile selects and nothing else.
The 400-token ceiling at `:283-284` stays as the outer limit; the 356 rule of `NFR-01` is the tighter
one this story adds.

---

## Epic E-04: The record stays true

**Goal:** the documents that state what the always-loaded block costs say what it actually costs,
and nothing outside this change quietly moves.
**Requirements:** FR-14, FR-16, NFR-05
**Stories:** S-07, S-08
**Ships when:** `docs/05-token-and-memory-design.md` names four measured figures and a reviewer can
see that no skill, artifact template or doctor output changed.

### S-07 The token design document records the four measured sizes

| | |
|---|---|
| Kind | build |
| Satisfies | NFR-05 |
| Size | S |
| Depends on | S-05 |
| Status of requirement | confirmed |

**As a** maintainer deciding whether some future thing fits in the always-loaded block
**I want** the document that owns that budget to state what each configuration actually costs
**So that** the next person sizing a change reads a measurement rather than a figure from before
this one

**Acceptance criteria**

```gherkin
Scenario: all four figures are stated
  Given docs/05-token-and-memory-design.md
  Then it states the measured size of each of the four combinations
  And each figure matches what hooks/session-start produces for that combination

Scenario: the superseded figures are gone
  Given docs/05-token-and-memory-design.md
  Then it no longer presents 300 and 356 as the only two sizes the hook produces
```

**Notes:** the section at `:272-278` is the record of the tightest budget in the project, and it
currently describes a hook with two forms. After this work it has four.

### S-08 Nothing outside the hook, the schema and the docs changes behaviour

| | |
|---|---|
| Kind | verify |
| Satisfies | FR-14, FR-16 |
| Size | S |
| Depends on | S-01, S-04 |
| Status of requirement | confirmed |

**As a** user on `technical`, which is everyone who does not opt in
**I want** this change to be invisible to me
**So that** a feature I did not enable cannot alter what my skills write or what my tools print

**Acceptance criteria**

```gherkin
Scenario: doctor gains no output about the new key
  Given a profile at schema version 2 with explain_level set to "technical"
  When keel doctor runs
  Then its output contains no line naming explain_level

Scenario: doctor still reports drift on an older profile
  Given a profile at schema version 1
  When keel doctor runs
  Then it warns that the profile is at an older schema version
  And it names keel init as the fix

Scenario: no skill or artifact template changed
  Given the diff for this work
  Then it touches no file under skills/
  And it touches no file under templates/ other than the profile schema and the example profile
  And it touches no file under output-styles/
```

**Notes:** this is a `verify` story because the work is proving an absence. If the third scenario
fails, whatever changed under `skills/` or `output-styles/` was scope nobody agreed to, and it comes
back here as a `fix`. The second scenario pins existing behaviour rather than new behaviour: it is
the mechanism `CON-06` relies on to get the key into projects that already exist.

---

## Order and critical path

| # | Story | Why here |
|---|---|---|
| 1 | S-01 | Everything reads the schema |
| 2 | S-04 | The hook change is the feature. S-02 and S-03 can run beside it |
| 3 | S-05 | The wording needs the branches to exist to be measured in place |
| 4 | S-06 | The budget check needs four combinations to check |
| 5 | S-07 | The figures are only final once S-05 is |
| - | S-02, S-03 | Parallel with S-04, after S-01 |
| - | S-08 | Last. It asserts what the finished diff did not touch |

**Critical path:** S-01, S-04, S-05, S-06, S-07.

No story is blocked, by an undecided question or by anything outside this backlog.

## Coverage

| Requirement | Status | Stories | Note |
|---|---|---|---|
| FR-01 | confirmed | S-01 | |
| FR-02 | confirmed | S-01 | Asserted as unchanged, not built |
| FR-03 | confirmed | S-02 | |
| FR-04 | confirmed | S-04 | |
| FR-05 | confirmed | S-04 | |
| FR-06 | confirmed | S-04 | |
| FR-07 | confirmed | S-05 | |
| FR-08 | confirmed | S-05 | |
| FR-09 | confirmed | S-04 | |
| FR-10 | confirmed | S-04 | |
| FR-11 | confirmed | S-01 | |
| FR-12 | confirmed | S-04 | The four combination tests are S-04's acceptance criteria |
| FR-13 | confirmed | S-03 | |
| FR-14 | confirmed | S-08 | Verified as an absence in the diff |
| FR-15 | confirmed | S-05 | |
| FR-16 | confirmed | S-08 | Verified as an absence in doctor's output |
| FR-17 | confirmed | S-05 | |
| NFR-01 | confirmed | S-05, S-06 | S-05 meets it, S-06 enforces it |
| NFR-02 | confirmed | S-06 | |
| NFR-03 | confirmed | S-04 | |
| NFR-04 | confirmed | S-04 | |
| NFR-05 | confirmed | S-07 | |
| CON-01 | confirmed | none | Constraint, not work. Enforced by the check S-06 extends |
| CON-02 | confirmed | none | Constraint. It is why S-05 has a character budget rather than a target |
| CON-03 | confirmed | none | Constraint. S-01 asserts it as an unchanged enum |
| CON-04 | confirmed | none | Constraint. S-08 asserts it as an absence in the diff |
| CON-05 | confirmed | none | Constraint imposed by the platform. Nothing here can change it |
| CON-06 | confirmed | none | Constraint. It is why S-01 moves SCHEMA_VERSION and why S-08 pins the drift message |
| CON-07 | confirmed | none | Constraint. S-04's first scenario is what keeps it true |

**Forward:** 22 of 22 requirements have at least one story. All 17 `FR` and all 5 `NFR` entries are
covered. The 7 `CON` entries have no stories, which is correct: a constraint is something the work
must not violate, not work to do. Each names where it is asserted rather than being left blank.

**Backward:** every story's `Satisfies` names a requirement that exists in
`docs/prd/plain-language-chat.md`. No story satisfies nothing.
