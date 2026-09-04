# PRD: detect PL/SQL projects

| | |
|---|---|
| Status | approved |
| Mode | from-idea |
| Author | Bernard, with Claude |
| Date | 2026-08-18 |
| Derived from | `docs/ideas/plsql-stack-detection.md`, at `9b52a3a`, and this conversation |
| Approved by | Bernard, 2026-08-18 |

> Requirement IDs are permanent. `write-user-stories` and `write-plan` trace to them.
> Retire an ID rather than renumbering.

## 1. Executive summary

`keel init` on an Oracle PL/SQL repository produces a profile with no language, no datastore and no
test command, so every skill that reads the profile has nothing to work from and falls back to
asking. This PRD covers detecting PL/SQL as a fourteenth language and setting `oracle` as a
datastore, on a marker deliberately built so it cannot fire on any project that declares itself to
be something else.

It is for anyone running keel on an Oracle codebase, and it matters now because two such
repositories exist in current work. What it does **not** do is produce a test command: utPLSQL runs
inside a database and the connection details are not in the repository, so every verify command
stays `null` and the profile still needs a human to finish it. That is a smaller benefit than the
source idea implies, and saying so here is the point.

## 2. Problem statement

Sourcing `lib/detect-stack.sh` read-only in the Oracle repository on 2026-08-18, a git-tracked
codebase of 191 `.sql` files with a working utPLSQL v3 suite, produced:

```
detect_languages: []
detect_stack:     unknown unknown none none
detect_also:      []
verify.test:      []
verify.test_one:  []
verify.lint:      []
datastores:       []
```

Every field empty on a repository that is unambiguously Oracle. The cost is not dramatic: a skill
asks the user instead of reading the profile. But it repeats on every Oracle repository, and it
leaves `keel doctor` unable to say anything useful about a stack it does not recognise.

**Why this is harder than it looks, and why the marker is most of the document.** All thirteen
existing languages are detected from a file the project itself declares: `package.json`, `go.mod`,
`Cargo.toml`, `pom.xml`, `Package.swift` (`lib/detect-stack.sh:172-212`). That is not incidental,
it is what makes detection trustworthy. PL/SQL declares nothing, so this would be the first language
keel infers rather than reads. **A wrong profile is worse than an empty one**, because an empty
profile makes a skill ask and a wrong one makes it proceed.

## 3. Goals and non-goals

**Goals**

- An Oracle PL/SQL repository gets `stack.language` and `stack.datastores` filled in by `keel init`.
- The marker cannot fire on any repository that declares another language, by construction rather
  than by tuning.
- A skill that needs a verify command still asks, because none is invented.

**Non-goals**

- Producing any verify command for PL/SQL. See `CON-02`.
- Detecting general SQL. Every false positive found on 2026-08-18 was a general-SQL directory inside
  another language's project, so general SQL is the failure mode rather than a target.
- Recommending a language server. None exists. See `CON-03`.
- Fixing how stack plugins reach a repository that already has `.claude/settings.json`. That is a
  real defect and it is not this one: `docs/ideas/stack-plugins-on-existing-repos.md`.
- A PL/SQL section in `coding-standards`.

## 4. Users and personas

| Who | Wants | Knows |
|---|---|---|
| An engineer running `keel init` on an Oracle codebase | The profile to describe the project without hand-editing | Their database. Not keel's profile schema |
| Every keel skill that reads `stack.language` | A value other than `unknown`, or an honest `unknown` | Only what the profile says |
| An engineer on a TypeScript service carrying `.sql` migrations | To be entirely unaffected | Nothing about this change, and that is the requirement |

The third row is the one this document is really about.

## 5. Functional requirements

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-01 | `detect_languages` must report `plsql` when all four hold: no manifest exists for any of the thirteen currently detected languages; `.sql` and `.plsql` files together outnumber every other single extension in the tree, counting neither extensionless files nor Oracle's own `.pks`, `.pkb`, `.prc` and `.fnc` as a competing extension; there are at least ten `.sql` or `.plsql` files; and at least one of them contains an Oracle-exclusive token per `FR-12`. | confirmed | Requester, 2026-08-18, choosing "plurality plus a floor" and then adding the content signal. The package-extension exclusion was added during implementation and is not a change of intent: 30 `.pks` plus 30 `.pkb` plus 12 `.sql` is the idiomatic Oracle layout, and it censused as "12 30" and went undetected. They are excluded from the denominator only, never counted as evidence, per `A2` |
| FR-02 | `plsql` must not be reported when a manifest for any of the thirteen is present, whatever the `.sql` count. | confirmed | The Drizzle service: 20 `.sql` against 379 `.ts`, with `package.json`. This is the case the marker exists to survive |
| FR-03 | `plsql` must not be reported when `.sql` plus `.plsql` number fewer than ten. | confirmed | Requester, 2026-08-18. Stops a nearly empty repository with one stray `.sql` being labelled Oracle |
| FR-04 | The extension census must run only after the manifest check has failed to find any of the thirteen. | confirmed | Correctness and cost together: a repository that declares itself needs no census, and skipping it is what keeps `keel init` from walking a large tree |
| FR-05 | `lang_profile plsql` must emit language `plsql`, runtime `oracle`, and package manager `none`. | confirmed | The shape `lang_profile` returns for every language, `lib/detect-stack.sh:216-272` |
| FR-06 | `lang_profile plsql` must emit framework `apex` when a `manifest.json` containing `"apex_version"` sits at the root of the tree, and `none` otherwise. | confirmed | Requester, 2026-08-18. The file is keel's own output, written at `lib/apex_render.py:646` and pinned by `tests/test-apex-export.sh:56`, so it is self-declaring and cannot false-positive |
| FR-07 | `stack.datastores` must include `oracle` exactly when `FR-01` fires. | confirmed | The source idea's recommendation, and `CON-04`: the existing datastore detector cannot do this |
| FR-08 | Every `verify` command must remain `null` for a PL/SQL project. | confirmed | `CON-02`. utPLSQL needs a connection string, a schema and credentials, none of which are in the repository |
| FR-09 | `skills/keel/references/tool-choices.md` must carry three rows for `plsql`: utPLSQL in the test runner table, and `none` with a reason in each of the lint and typecheck tables. | confirmed | Requester, 2026-08-18. `CON-01` requires only one row, so this is a choice: the tables are read one concern at a time, and the typecheck table already carries `none` rows with reasons for `ruby` and `lua`, so a `none` verdict is established practice rather than a gap |
| FR-10 | The accumulator assignment must be spelled `out="$out plsql"`, matching the thirteen existing branches. | confirmed | `tests/validate-skills.sh:367-368` extracts languages by matching that exact spelling. A different spelling silently disables the rule rather than breaking it, which `:369-375` records as a failure mode this repository keeps rediscovering |
| FR-11 | A repository detected as `plsql` must report `plsql` as its only language, with `detect_also` empty. | confirmed | Follows from `FR-01`: the marker requires that no other language's manifest exists |
| FR-12 | The Oracle-exclusive token set must be `VARCHAR2`, `DBMS_`, and `PACKAGE BODY`, matched case-insensitively. `%TYPE` and `%ROWTYPE` must not be used. | confirmed | Requester chose a content signal on 2026-08-18. The token set is narrower than the one proposed alongside that choice: PostgreSQL's PL/pgSQL supports both `%TYPE` and `%ROWTYPE`, so including them would readmit the false positive this requirement exists to remove. The three kept have no PostgreSQL equivalent |
| FR-13 | The content scan must stop at the first matching file. | confirmed | Bounds the cost of the common case. The no-match path reads each candidate once, which is proportionate on a tree already established to be manifest-less and SQL-dominant |

## 6. Non-functional requirements

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| NFR-01 | The census walk must prune `node_modules` and `.git`, as `find_marker` does. | confirmed | `lib/detect-stack.sh:61-71`, whose comment records that `-prune` rather than `-not -path` is the whole cost on a repository with a large `node_modules` |
| NFR-02 | `keel init` on a repository that declares any of the thirteen must do no more filesystem work than it does today. | confirmed | Follows from `FR-04`. Testable: the census is not reached on any existing fixture |
| NFR-03 | Detection must add no new interpreter dependency and no new external command beyond what `lib/detect-stack.sh` already uses. | confirmed | The file is sourced by `bin/keel` on every `init` and `doctor` |
| NFR-04 | The census must be a single filesystem pass rather than one per extension. | confirmed | Requester, 2026-08-18, choosing structural bounds over a wall-clock assertion. A timed test fails on a loaded CI runner for reasons unrelated to the code, and `NFR-01`, `NFR-02` and this together bound the same cost with properties a fixture can assert |

## 7. Constraints

| ID | Constraint | Imposed by | Evidence |
|---|---|---|---|
| CON-01 | Every language in `detect_languages` must have a row in `skills/keel/references/tool-choices.md` or the build fails. One row anywhere in the file satisfies it. | `tests/validate-skills.sh:364-379` | Read on 2026-08-18. **The source idea cites `:341-345` and says three rows in three tables are required; both are wrong**, and the correction is recorded here so nobody plans against the wrong rule |
| CON-02 | Detection never guesses a verify command. An absent command becomes `null` so a skill knows to ask. | `lib/detect-stack.sh:290-292` | The doctrine that makes the profile trustworthy |
| CON-03 | No PL/SQL or SQL language server exists in the `claude-plugins-official` catalogue. | The catalogue | Searched 2026-08-18 across every SQL, Oracle and PL/SQL name it carries: twelve language servers, none for SQL. `lang_lsp` returns empty for an unmapped language and `detect_plugins` skips it silently (`lib/detect-stack.sh:581-608`), so this needs no code |
| CON-04 | `detect_datastores` returns early when no dependency manifest exists, so `oracle` cannot be added to its pair list and reach a PL/SQL repository. | The existing function | `lib/detect-stack.sh:555-580`. **The source idea states that an `oracle` pair already exists there and that fixing it is cheaper than the language half. There is no `oracle` anywhere in the file**; the eight pairs are postgres, mysql, redis, mongodb, sqlite, elasticsearch, cassandra and dynamodb |
| CON-05 | PL/SQL is the first language keel infers rather than reads from a declaration. | The ecosystem | No manifest format exists for it |

## 8. Observed but not required

Not applicable, because this is `from-idea` mode. Nothing is being reverse-engineered.

## 9. Success metrics

Detection correctness, asserted by fixtures, and nothing about adoption.

| Measure | Target | Source |
|---|---|---|
| Fires on an Oracle-shaped fixture: no manifest, at least ten `.sql`, `.sql` dominant | `plsql`, `oracle`, framework `none` | New fixture in `tests/test-keel.sh` |
| Silent on a TypeScript fixture carrying `.sql` migrations | language `typescript`, no `oracle` | New fixture, modelled on the Drizzle service |
| Silent on every one of the thirteen existing manifests | unchanged from today | The existing fixtures, which must not move |
| Silent on a repository with fewer than ten `.sql` and no manifest | `unknown` | New fixture |
| Verify commands on a detected PL/SQL project | all `null` | New fixture |

**Adoption is explicitly not measured.** Whether any client repository runs `keel init` on the
strength of this is outside what the change controls, and the requester chose on 2026-08-18 to
measure the detector rather than invent an adoption target. This answers open question 3 of the
source idea, which asked whether the Oracle repository wants a profile at all: the honest answer is
that nobody knows, and the work is justified by the detector being correct rather than by a
prediction about a repository that is not ours to commit.

## 10. Milestones

`Unknown, needs a decision`. No deadline was given. There is no sequencing constraint: nothing else
in flight touches `lib/detect-stack.sh`.

## 11. Out of scope

| Excluded | Why |
|---|---|
| Any `verify` command for PL/SQL | `CON-02` and `FR-08`. The connection details are not in the repository |
| General SQL detection | Every false positive found was general SQL inside another language's project |
| A language server recommendation | `CON-03`. None exists, and the code already handles an unmapped language by doing nothing |
| Stack plugins on a repository with an existing `.claude/settings.json` | A real defect, tracked separately at `docs/ideas/stack-plugins-on-existing-repos.md` |
| A PL/SQL section in `coding-standards` | Left undecided by the source idea, and nothing depends on it |
| Filename-convention markers (`.pks`, `.pkb`, `.prc`, `.fnc`) | Ruled out by measurement: none exist anywhere on the machine, and the Oracle repository has one `.spc.sql` and one `.bdy.sql` in 191 files |

## 12. Assumptions

| ID | Assumption | False if | Checked |
|---|---|---|---|
| A1 | A PL/SQL repository has no manifest for any of the thirteen. | An Oracle project carries, say, a `package.json` for tooling | **Partly.** True of the Oracle repository, which has only `.claude/settings.json`. One instance |
| A2 | Filename convention is not a usable marker. | `.pks` / `.pkb` files are common in practice | **Yes, and it rules out the obvious marker.** A machine-wide search on 2026-08-18 found none |
| A3 | ~~`.sql` plus `.plsql` dominance is a sound proxy~~ **Superseded 2026-08-18 by the content signal.** Dominance plus an Oracle-exclusive token is the proxy. | A PostgreSQL migrations repository contains `VARCHAR2`, `DBMS_` or `PACKAGE BODY` | **Yes, by construction.** None of the three has a PostgreSQL equivalent |
| A4 | Ten files is the right floor. | A real Oracle repository has fewer | **No.** The number was chosen, not measured. Both known instances have 191 and 1,129 |
| A5 | utPLSQL is the framework worth naming in `tool-choices.md`. | An Oracle project that tests uses something else | **Partly.** 16 mentions in the Oracle repository's tests, and it is the only real option |
| A6 | Two repositories justify a fourteenth language. | The cost lands once and the benefit does not repeat | **No.** The house's Oracle exposure is not written down anywhere |
| A7 | An Oracle repository contains at least one of `VARCHAR2`, `DBMS_` or `PACKAGE BODY`. | An Oracle codebase of pure table DDL uses none of them | **No, and it is the cost of `FR-12`.** Such a repository would now be missed where the filename marker alone would have caught it. Neither known instance was checked for these tokens, because neither is reachable from here |

## 13. Open questions

| # | Question | Needs | Blocks |
|---|---|---|---|
| Q1 | ~~Is a mislabelled SQL migrations repository acceptable, or does the marker need an Oracle signal?~~ **Answered 2026-08-18: it needs one.** Now `FR-12`, with the token set narrowed to Oracle-exclusive terms. | Closed | FR-01 |
| Q2 | ~~Is there an absolute wall-time budget?~~ **Answered 2026-08-18: no, and no timed test.** Structural bounds instead, `NFR-01`, `NFR-02` and `NFR-04`. | Closed | NFR-04 |
| Q3 | ~~One `tool-choices.md` row or three?~~ **Answered 2026-08-18: three.** Now `FR-09`. | Closed | FR-09 |
| Q4 | ~~Which PL/SQL language server?~~ Answered 2026-08-18: none exists. Now `CON-03`. | Closed | Section 11 |
| Q5 | ~~Does the Oracle repository want a profile at all?~~ Answered 2026-08-18: unknown, and the work is justified by detector correctness instead. Now section 9. | Closed | Section 9 |
| Q6 | ~~Is general SQL in scope?~~ Answered 2026-08-18: no. Now section 11. | Closed | Section 11 |
| Q7 | `A7` is the new unchecked risk: an Oracle repository of pure table DDL, using none of the three tokens, is now missed. Is that acceptable, or does the token set need widening once a real repository can be checked? | Bernard, when an Oracle repository is reachable | FR-12 |
