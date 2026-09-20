# Stories: tiered multi-harness support

| | |
|---|---|
| Derived from | [`../architecture/tiered-multi-harness-support.md`](../architecture/tiered-multi-harness-support.md), accepted, and ADR-0003, ADR-0004, ADR-0005, all `accepted` 2026-09-05 |
| Date | 2026-09-05 |
| Stories | 19 (build: 15, verify: 1, fix: 2, decide: 1) |
| Coverage | 7 of 7 requirements covered. See the table at the end |

> Story IDs are permanent. Plans trace to them. Retire rather than renumber.
> **There is no PRD, deliberately.** `docs/ideas/keel-on-codex.md` declines `write-prd` in its
> amendment, and the design carries requirement IDs R-01 to R-07 with its own coverage table in
> section 11 for exactly this purpose. This document treats the design as the requirements source.
> The deviation was put to the requester on 2026-09-05 and chosen over running `write-prd`.
>
> **Accepted 2026-09-05.** The three ADRs were accepted by Bernard Tebandeke on that date and the
> design with them, so these stories are no longer provisional. Their `Verification` sections stay
> open: acceptance is agreement, not proof, and the plan is what produces the evidence.

## Epic E-01: One source of truth for what a harness can do

**Goal:** the answer to "does gate G work on harness H" exists in exactly one place, and everything
else is derived from it.
**Requirements:** R-04, R-05
**Stories:** S-01, S-02
**Ships when:** `resolve.sh` answers for both harnesses with no python3 on PATH, and no second copy
of the fact exists anywhere in the tree.

### S-01 State every harness capability and gate requirement in one checked-in file

| | |
|---|---|
| Kind | build |
| Satisfies | R-04 |
| Size | S |
| Depends on | none |
| Status of requirement | confirmed |

**As a** keel maintainer
**I want** each harness's primitives and each gate's requirements written down once
**So that** no two parts of keel can disagree about what a harness delivers

**Acceptance criteria**

```gherkin
Scenario: the manifest lists both harnesses
  Given lib/harness/capabilities
  When it is read
  Then claude provides pretooluse_ask
  And codex does not provide pretooluse_ask

Scenario: every gate names what it requires
  Given the manifest
  When each of session-start, done-guard, context-watch and sensitive-guard is read
  Then each names at least one required primitive

Scenario: every row carries provenance
  Given the manifest
  When any harness row is read
  Then it carries a source, a version and a date
```

**Notes:** flat pipe-delimited text, not JSON, because `hooks/sensitive-guard` reads it and must
work with no python3. Design section 4.

### S-02 Resolve the active gate set for a harness, in pure bash

| | |
|---|---|
| Kind | build |
| Satisfies | R-04, R-05 |
| Size | M |
| Depends on | S-01 |
| Status of requirement | confirmed |

**As a** hook running on a developer's machine
**I want** one function that answers whether a gate is active here
**So that** no caller has to reimplement the rule and get it subtly different

**Acceptance criteria**

```gherkin
Scenario: a gate whose primitives are all present
  Given harness claude
  When the active gate set is resolved
  Then it contains sensitive-guard

Scenario: a gate with a missing primitive
  Given harness codex
  When the active gate set is resolved
  Then it does not contain sensitive-guard
  And it contains session-start, done-guard and context-watch

Scenario: no python3 on PATH
  Given python3 is not available
  When the active gate set is resolved for either harness
  Then the answer is unchanged

Scenario: an unknown harness
  Given harness name "cursor"
  When the active gate set is resolved
  Then the result is empty and the exit status is non-zero

Scenario: a primitive with no evidence
  Given a manifest row with no source, version or date
  When the active gate set is resolved
  Then that primitive is treated as not provided
```

**Notes:** absent evidence fails, never passes. ADR-0003 consequences.

## Epic E-02: keel installs on Codex, and installs only what works there

**Goal:** a Codex user gets the skills, `AGENTS.md`, the CLI and the three gates that function, and
nothing that does not.
**Requirements:** R-01, R-02, R-03
**Stories:** S-03, S-04, S-05, S-06, S-07
**Ships when:** `keel init` in a fresh repo with `--harness codex` writes Codex config and no
`sensitive-guard` registration, and Claude Code output is byte-identical to today.

### S-03 Move the Claude-only writers behind a harness contract without changing their output

| | |
|---|---|
| Kind | build |
| Satisfies | R-01 |
| Size | L |
| Depends on | S-02 |
| Status of requirement | confirmed |

**As a** Claude Code user
**I want** the multi-harness work to change nothing about my install
**So that** a feature I do not use cannot break the one I do

**Acceptance criteria**

```gherkin
Scenario: init output is unchanged on Claude Code
  Given a fixture repo and the current keel
  When keel init runs before and after the refactor
  Then .claude/settings.json is byte-identical
  And .claude/settings.local.json is byte-identical
  And CLAUDE.md and AGENTS.md are byte-identical

Scenario: the neutral code names no harness
  Given bin/keel after the refactor
  When it is searched outside lib/harness/
  Then no occurrence of .claude, CLAUDE.md, enabledPlugins or known_marketplaces remains
```

**Notes:** 76 coupling points, all in `init`, `new` and `doctor`; every writer is a leaf called only
from `cmd_init` and `cmd_new`. `bin/keel#init)        shift; cmd_init "$@" ;;` is the dispatch.

### S-04 Record which harnesses a repository serves

| | |
|---|---|
| Kind | build |
| Satisfies | R-01, R-05 |
| Size | M |
| Depends on | S-02 |
| Status of requirement | confirmed |

**As a** team with some developers on Claude Code and some on Codex
**I want** one repository to serve both
**So that** our configuration is not whatever the last person to run init chose

**Acceptance criteria**

```gherkin
Scenario: explicit flag
  Given a fresh repo
  When keel init --harness claude,codex runs
  Then .keel/profile.json harnesses is ["claude","codex"]

Scenario: detection from tracked files
  Given a repo with .codex/config.toml tracked in git
  When keel init runs with no --harness flag
  Then harnesses contains codex

Scenario: an untracked config is not a signal
  Given a repo with .codex/config.toml present but untracked
  When keel init runs with no --harness flag
  Then harnesses does not contain codex

Scenario: AGENTS.md is never a signal
  Given a repo with AGENTS.md and no .codex directory
  When keel init runs with no --harness flag
  Then harnesses is ["claude"]

Scenario: an existing schema 2 profile
  Given a repo whose profile is schema_version 2
  When keel init runs
  Then harnesses is ["claude"]
  And schema_version is 3

Scenario: init asks nothing
  Given any repo
  When keel init runs with no tty
  Then it completes without prompting
```

**Notes:** `keel init` is non-interactive today (`bin/keel:806-807`), and R-01 forbids adding a
prompt. ADR-0004.

### S-05 Write Codex configuration on a repository that serves Codex

| | |
|---|---|
| Kind | build |
| Satisfies | R-02 |
| Size | M |
| Depends on | S-04 |
| Status of requirement | confirmed |

**As a** developer using Codex on a keel repository
**I want** keel to write the Codex configuration it can honestly write
**So that** I get the parts of keel that work on my harness

**Acceptance criteria**

```gherkin
Scenario: path denies port and get stronger
  Given a repo initialised with harness codex
  When the Codex permission profile is written
  Then it denies the five secret path globs
  And it contains no command-pattern rule

Scenario: ask rules are absent, not faked
  Given a repo initialised with harness codex
  When the Codex permission profile is written
  Then no entry claims to prompt a human

Scenario: Claude files are not written for a codex-only repo
  Given a repo initialised with --harness codex
  When init completes
  Then no .claude/settings.json exists
  And AGENTS.md carries the managed block
```

**Notes:** Codex has no command-pattern rule syntax. Of 26 current rules, 5 port as path globs, 8
become redundant, 13 have no counterpart. Design section 8.

### S-06 Ship the Codex plugin manifest pointing at the same skills directory

| | |
|---|---|
| Kind | build |
| Satisfies | R-02 |
| Size | S |
| Depends on | S-08 |
| Status of requirement | confirmed |

**As a** Codex user installing keel
**I want** one marketplace command to install the skills and the working gates
**So that** installing is not a manual copy that goes stale

**Acceptance criteria**

```gherkin
Scenario: the manifest points at the one skills directory
  Given .codex-plugin/plugin.json
  When it is read
  Then skills is "./skills/"
  And hooks is "./hooks/hooks.codex.json"

Scenario: no second copy of any skill exists
  Given the repository tree
  When it is searched for a duplicated SKILL.md
  Then every skill appears exactly once
```

**Notes:** verified against the vendor docs on 2026-09-05: manifest paths are author-chosen and
relative. Zero-copy is what makes drift impossible rather than merely checked. Design 10.2.

### S-07 Report the running harness and its live gate set in keel doctor

| | |
|---|---|
| Kind | build |
| Satisfies | R-05 |
| Size | M |
| Depends on | S-02, S-04 |
| Status of requirement | confirmed |

**As a** developer who wants to know what protects this repository
**I want** doctor to answer for the harness I am actually running
**So that** I learn it from the machine in front of me rather than from a document

**Acceptance criteria**

```gherkin
Scenario: running under Codex
  Given CODEX_VERSION is set in the environment
  When keel doctor runs
  Then it names codex as the running harness
  And it reports sensitive-guard as not available on this harness

Scenario: the harness cannot be determined
  Given neither CODEX_VERSION nor a Codex hook payload
  When keel doctor runs
  Then it says it cannot determine the harness
  And it reports against every harness in profile.harnesses

Scenario: a declared hard block that this harness cannot enforce
  Given a profile with hard_block_paths and harnesses including codex
  When keel doctor runs
  Then it warns that hard_block_paths is not enforced for Codex users of this repository

Scenario: a harness installed but not listed
  Given codex is on PATH and harnesses is ["claude"]
  When keel doctor runs
  Then it says so
```

**Notes:** `CLAUDE_PLUGIN_ROOT` is not a discriminator; Codex sets it
(`codex-rs/hooks/src/engine/discovery.rs:266-269`). Design 10.7.

## Epic E-03: The gates behave correctly on Codex, or refuse

**Goal:** every gate keel registers on Codex works, and the one it does not register cannot mislead.
**Requirements:** R-02, R-03
**Stories:** S-08, S-09, S-10, S-11
**Ships when:** the three Tier B gates fire on a live Codex session and `sensitive-guard` blocks
rather than reports when wired up by hand.

### S-08 Generate the per-harness hook manifests from the capability manifest

| | |
|---|---|
| Kind | build |
| Satisfies | R-03, R-04 |
| Size | M |
| Depends on | S-02 |
| Status of requirement | confirmed |

**As a** keel maintainer
**I want** the hook manifests derived rather than written
**So that** registering an inert gate is not something a person can do by hand

**Acceptance criteria**

```gherkin
Scenario: the Codex manifest omits the gate that cannot work
  Given the generator has run
  When hooks/hooks.codex.json is read
  Then it contains no entry for sensitive-guard
  And it contains entries for session-start, done-guard and context-watch

Scenario: the Claude manifest is unchanged
  Given the generator has run
  When hooks/hooks.json is compared to its previous content
  Then it is byte-identical

Scenario: every control-bearing entry is synchronous
  Given either generated manifest
  When each hook entry is read
  Then async is false
```

**Notes:** `async: false` is what makes exit 2 and the JSON decision path work at all
(`codex-rs/hooks/src/engine/mod.rs:141-156`). It is generated, not typed.

### S-09 Refuse loudly when sensitive-guard runs on a harness that cannot support it

| | |
|---|---|
| Kind | build |
| Satisfies | R-03 |
| Size | S |
| Depends on | S-02 |
| Status of requirement | confirmed |

**As a** developer who has wired keel's hooks up by hand on Codex
**I want** the gate to stop me rather than pretend
**So that** I never believe I have a protection I do not have

**Acceptance criteria**

```gherkin
Scenario: the harness cannot put a command to a human
  Given the running harness does not provide pretooluse_ask
  When hooks/sensitive-guard runs
  Then it writes the reason to stderr
  And it exits 2

Scenario: the harness can
  Given the running harness provides pretooluse_ask
  When hooks/sensitive-guard runs on a repo with no hard_block_paths
  Then it produces no output and exits 0
```

**Notes:** exit 2 rather than 1 is the whole point. On Codex, exit 2 sets `should_block` and
surfaces stderr as the block reason (`codex-rs/hooks/src/events/pre_tool_use.rs`); any other
non-zero code discards stderr and lets the command run.

### S-10 Emit the Stop decision Codex understands from done-guard

| | |
|---|---|
| Kind | build |
| Satisfies | R-02 |
| Size | S |
| Depends on | S-02 |
| Status of requirement | confirmed |

**As a** developer using Codex
**I want** the done gate to actually hold the turn open
**So that** keel's verification gate is not advisory on my harness

**Acceptance criteria**

```gherkin
Scenario: blocking on Codex
  Given the running harness is codex
  When done-guard blocks
  Then the emitted decision is "block"

Scenario: blocking on Claude Code
  Given the running harness is claude
  When done-guard blocks
  Then the emitted decision is "deny"
```

**Notes:** Codex's `Stop` schema enumerates `decision` as `["block"]` only. A one-word difference,
and the gate is inert without it.

### S-11 Detect an unreadable transcript rather than reporting zero tokens

| | |
|---|---|
| Kind | build |
| Satisfies | R-02, R-03 |
| Size | M |
| Depends on | S-02 |
| Status of requirement | confirmed |

**As a** developer relying on the context watchdog
**I want** it to tell me when it has stopped working
**So that** a silent parser failure does not look like a quiet session

**Acceptance criteria**

```gherkin
Scenario: a Codex transcript
  Given a recorded Codex transcript fixture
  When context_watch reads it
  Then it reports a token total greater than zero

Scenario: a Claude Code transcript
  Given a recorded Claude Code transcript fixture
  When context_watch reads it
  Then it reports the same total it reports today

Scenario: an unrecognised format
  Given a transcript in neither format
  When context_watch reads it
  Then it reports unsupported
  And it does not report zero

Scenario: the format is surfaced to the user
  Given an unrecognised transcript
  When keel doctor runs
  Then it reports the context watchdog as inactive
```

**Notes:** parser selected by sniffing the transcript's shape, not by harness identity, so a format
change within one harness is caught too. Codex states the format is not a stable interface, which is
why the fixture canary in S-12 is a condition of this gate counting at all.

## Epic E-04: Every claim about a harness is checked

**Goal:** a document cannot claim a gate the manifest does not grant.
**Requirements:** R-04, R-06
**Stories:** S-12, S-13, S-14
**Ships when:** CI fails on a deliberately introduced over-claim.

### S-12 Fail the build when a generated artifact is stale or a manifest row lacks provenance

| | |
|---|---|
| Kind | build |
| Satisfies | R-04, R-06 |
| Size | M |
| Depends on | S-08 |
| Status of requirement | confirmed |

**As a** reviewer of a keel pull request
**I want** a hand-edited hook manifest to fail
**So that** the derived artifacts stay derived

**Acceptance criteria**

```gherkin
Scenario: a hand-edited manifest
  Given hooks/hooks.codex.json has been edited by hand
  When tests/test-harness-claims.sh runs
  Then it fails and names the file

Scenario: everything regenerated
  Given the generator has just run
  When tests/test-harness-claims.sh runs
  Then it passes

Scenario: a manifest row missing provenance
  Given a capability row with no date
  When tests/test-harness-claims.sh runs
  Then it fails and names the row

Scenario: an async flag flipped
  Given a generated manifest entry with async true
  When tests/test-harness-claims.sh runs
  Then it fails

Scenario: the Codex transcript fixture no longer parses
  Given the recorded Codex transcript fixture
  When the canary test runs
  Then it fails if context_watch cannot read it
```

**Notes:** freshness of a probe is deliberately **not** checked here. No network, and a date-based
expiry fails by calendar rather than by change, which
`tests/generate-profile-keys.sh:11` rejects as a technique. Completeness is checked; freshness moves
to the release runbook and to doctor.

### S-13 Fail the build when a document claims a gate the manifest does not grant

| | |
|---|---|
| Kind | build |
| Satisfies | R-06 |
| Size | L |
| Depends on | S-12 |
| Status of requirement | confirmed |

**As a** person reading keel's README
**I want** its claims about my harness to be true
**So that** I do not configure a repository around a protection that is not there

**Acceptance criteria**

```gherkin
Scenario: a tagged claim the manifest grants
  Given a sentence tagged gate=sensitive-guard harness=claude
  When tests/test-harness-claims.sh runs
  Then it passes

Scenario: a tagged claim the manifest denies
  Given a sentence tagged gate=sensitive-guard harness=codex
  When tests/test-harness-claims.sh runs
  Then it fails and names the file, line and gate

Scenario: an untagged sentence using gate vocabulary
  Given a new sentence in README.md naming a gate with no claim tag
  When tests/test-harness-claims.sh runs
  Then it fails as an unregistered claim

Scenario: historical records are out of scope
  Given a sentence in docs/ideas/ or docs/plans/ naming a gate
  When tests/test-harness-claims.sh runs
  Then it is ignored
```

**Notes:** two-sided on purpose. A registry alone misses new claims; a prose scan alone is the
technique `tests/test-doc-claims.sh:1-16` rejects. A new file rather than an extension of that one,
because it compares against a capability matrix rather than a count. Design section 11.

### S-14 Repair every sentence that stops being true

| | |
|---|---|
| Kind | fix |
| Satisfies | R-06 |
| Size | L |
| Depends on | S-13 |
| Status of requirement | confirmed |

**As a** reader of any keel document
**I want** harness-dependent claims to name their harness
**So that** I can tell what applies to me

**Acceptance criteria**

```gherkin
Scenario: every inventoried sentence is repaired
  Given the 18 locations in the claim inventory
  When each is read
  Then each either names a harness or points at docs/harness-support.md

Scenario: the generated support page exists
  Given docs/harness-support.md
  When it is read
  Then it carries the tier table, the probe dates and one paragraph on what Tier B cannot claim

Scenario: the checks agree
  Given the repaired documents
  When tests/test-harness-claims.sh runs
  Then it passes
```

**Notes:** the enumerated list with current line numbers and remedy classes is
[`../architecture/tiered-multi-harness-claim-inventory.md`](../architecture/tiered-multi-harness-claim-inventory.md).
It names three things the count of eighteen hides, including one false derivation that is arithmetic
rather than a sentence and which no scan will find.

## Epic E-05: The skills read correctly on both harnesses

**Goal:** no skill body instructs a mechanism that does not exist on the harness reading it.
**Requirements:** R-02, R-07
**Stories:** S-15, S-16
**Ships when:** no skill body names a vendor model alias or a harness-specific agent type, and the
fan-out still happens on both harnesses.

### S-15 Move the fan-out model pin out of skill bodies into harness configuration

| | |
|---|---|
| Kind | build |
| Satisfies | R-02, R-07 |
| Size | L |
| Depends on | S-05 |
| Status of requirement | confirmed |

**As a** Codex user following a keel skill
**I want** its delegation instruction to name something that exists on my harness
**So that** I am not told to use an agent type and a model that mean nothing here

**Acceptance criteria**

```gherkin
Scenario: no vendor alias survives in a body
  Given the 25 skill bodies and their references
  When they are searched
  Then no occurrence of model `sonnet`, `opus`, `haiku` or `fable` remains

Scenario: the profile resolves on both harnesses
  Given a delegation profile named in a skill body
  When it is resolved for claude and for codex
  Then each yields a model the harness accepts

Scenario: the validator enforces the new rule
  Given a dispatch paragraph naming no delegation profile
  When tests/validate-skills.sh runs
  Then it fails

Scenario: word ceilings still hold
  Given the rewritten bodies
  When tests/validate-skills.sh runs
  Then no body exceeds 900 words
```

**Notes:** the checker is **not** the blocker; `model inherit` passes it today, verified by running
the real validator against three variants. The blocker is that `inherit` means "the driver's model"
and discards the 43% saving `docs/ideas/model-routing.md:130-141` measured. ADR-0005 records
`inherit` as the documented fallback if this proves expensive. `execute-plan` needs no change.

### S-16 Harness-qualify the two skill instructions that name Claude Code plugins

| | |
|---|---|
| Kind | fix |
| Satisfies | R-07 |
| Size | S |
| Depends on | S-13 |
| Status of requirement | confirmed |

**As a** Codex user reading security-audit or create-skill
**I want** a plugin instruction that does not apply to me to say so
**So that** I do not go looking for something that is not there

**Acceptance criteria**

```gherkin
Scenario: the instruction names its harness
  Given skills/security-audit/SKILL.md and skills/create-skill/SKILL.md
  When the plugin paragraphs are read
  Then each names Claude Code and states the fallback

Scenario: the catalogue agrees
  Given docs/02-skill-catalog.md and docs/04-plugin-strategy.md
  When tests/validate-skills.sh runs
  Then the plugin-delegation check passes
```

**Notes:** `tests/validate-skills.sh:390-463` requires a plugin delegation claimed in the docs to be
named in the delegating skill's body, so body and document move together or the build fails.

## Epic E-06: Evals cover both harnesses

**Goal:** a release gate says something about Codex, and says which scenarios it ran.
**Requirements:** R-02, R-07
**Stories:** S-17, S-18
**Ships when:** a release gate dispatches a defined scenario set on both harnesses.

### S-17 Pin the release-gate scenario set in a file

| | |
|---|---|
| Kind | build |
| Satisfies | R-07 |
| Size | S |
| Depends on | none |
| Status of requirement | confirmed |

**As a** person cutting a release
**I want** the gate scenario set to be defined rather than remembered
**So that** doubling the matrix does not double an ambiguity

**Acceptance criteria**

```gherkin
Scenario: the set is defined
  Given the gate scenario file
  When it is read
  Then it names each scenario in the release gate

Scenario: the count claim matches
  Given tests/evals/README.md
  When tests/test-doc-claims.sh runs
  Then the claimed gate count equals the number of scenarios in the file
```

**Notes:** the set exists in no file today; `tests/evals/results.md`, at "One documentation defect",
records a live six-versus-seven disagreement. Settling it is part of this work, decided 2026-09-05.

### S-18 Dispatch a scenario on the harness under test

| | |
|---|---|
| Kind | verify |
| Satisfies | R-02 |
| Size | M |
| Depends on | S-17 |
| Status of requirement | confirmed |

**As a** person running the release gate
**I want** the staging guidance to name the harness I am testing
**So that** I do not run a Codex arm with Claude Code flags

**Acceptance criteria**

```gherkin
Scenario: guidance for Codex
  Given stage.sh is run for a codex arm
  When its guidance is printed
  Then it names codex exec with --skip-git-repo-check

Scenario: guidance for Claude Code
  Given stage.sh is run for a claude arm
  When its guidance is printed
  Then it is unchanged from today

Scenario: the harness-neutral half stays neutral
  Given tests/evals/run.sh
  When it assembles a prompt
  Then it names no harness
```

**Notes:** `verify` rather than `build`: `run.sh` is already harness-neutral and `stage.sh` prints
guidance rather than dispatching. There is no dispatcher and no scorer to write; scoring is human by
design (`tests/evals/run.sh:3`). The Codex recipe was proven on 2026-09-05, recorded in
`tests/evals/results.md`.

## Deferred

### S-19 Re-derive the skill description budget for Codex

| | |
|---|---|
| Kind | decide |
| Satisfies | R-02 |
| Size | M |
| Depends on | S-15 |
| Status of requirement | confirmed |

**As a** keel maintainer
**I want** to know whether the 900-word ceiling and the description budget hold on Codex
**So that** the corpus is sized for the harness that loads it

**Acceptance criteria**

```gherkin
Scenario: a decision is recorded
  Given eval arms run on Codex at the current body lengths
  When the result is read
  Then either ADR-0001 is confirmed as applying to both harnesses
  Or a superseding ADR states a Codex-specific ceiling
```

**Notes:** needs a measurement, so it is a `decide` story rather than a question to re-ask. Codex
budgets a share of the context window rather than a fixed allowance and silently shortens or drops
descriptions under pressure, so ADR-0001's 44-tokens-per-description and 1,320-token ceiling
cannot be reused, only rederived. Design section 12 question 5. **Until this lands, any document
stating the ceiling as validated on both harnesses is a false claim and S-13 should catch it.**

## Coverage

| Requirement | Status | Stories | Note |
|---|---|---|---|
| R-01 Tier A unchanged, no regression | confirmed | S-03, S-04 | |
| R-02 Tier B is skills, AGENTS.md, the CLI and three gates | confirmed | S-05, S-06, S-10, S-11, S-15, S-18, S-19 | |
| R-03 No gate installs where it does not function | confirmed | S-08, S-09, S-11 | Met for registration and repository writes; met behaviourally, not literally, for the plugin payload. Risk accepted 2026-09-05 |
| R-04 The tier table is mechanically true | confirmed | S-01, S-02, S-08, S-12 | |
| R-05 doctor reports the harness and what is active | confirmed | S-02, S-04, S-07 | |
| R-06 A test fails when a claim exceeds the harness | confirmed | S-12, S-13, S-14 | |
| R-07 The seven design questions | confirmed | S-15, S-16, S-17, S-18 | Q4's premise was wrong; there is no dispatcher to build |

**Forward:** 7 of 7 requirements have at least one story. None uncovered.
**Backward:** every story names a requirement that exists in the design's section 11.

**Not covered here, because it is already done.** The CCA standing risk was added to
`docs/runbooks/cutting-a-release.md` section 4 and the design's section 9 on 2026-09-05, so it needs
no story. It remains trigger (a) on the design's open question 1.

## Critical path

S-01, S-02, S-08, S-12, S-13, S-14. Everything that makes a claim checkable runs through the
manifest and the resolver, and the document repairs cannot start before the check that polices them
exists.

**Concurrent once S-02 lands:** S-03, S-04, S-09, S-10, S-11 touch different files and depend on
nothing outstanding between them. S-17 depends on nothing at all and can run at any point.
