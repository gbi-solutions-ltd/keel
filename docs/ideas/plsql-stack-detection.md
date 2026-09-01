# Idea: detect PL/SQL and SQL projects

| | |
|---|---|
| Raised by | Bernard, 2026-08-18 |
| Status | **built 2026-08-18.** PL/SQL detection is in `lib/detect-stack.sh` with `oracle` as its datastore, specified in `docs/prd/plsql-stack-detection.md` and covered by nine fixtures in the suite. Status corrected 2026-08-30 |
| Recommendation | Build something smaller: detect the language and the datastore, leave every verify command null. No language server exists, so the LSP half needs no code |
| Next | `write-prd` done: `docs/prd/plsql-stack-detection.md`, 2026-08-18. All four open questions are answered |

## A note on naming

The repositories behind the evidence below are client work and are not named, because keel is a
generic plugin and `tests/no-internal-leaks.sh` refuses project-specific identifiers: a reader
assumes a name in here means something to keel, and it also discloses who we work with. They are
referred to by what makes them evidence. **The Oracle repository** is a git-tracked Oracle
codebase of 191 `.sql` files, a working utPLSQL v3 suite, and no manifest of any kind. **The
Drizzle service** is a TypeScript service of 379 `.ts` files carrying 20 `.sql` migrations, which
is the false positive any detector has to survive.

## The problem

Anyone running `keel init` on an Oracle PL/SQL repository gets a profile that says the project has
no language, no datastore and no test command, so every skill that reads the profile has nothing to
work from and asks the user instead. There are two such repositories in GBi work right now.

**Evidence.** Run on 2026-08-18 against the Oracle repository, a git-tracked
Oracle codebase of 191 `.sql` files with a working utPLSQL v3 suite at `tests/run_all_tests.sql` and
a documented SQLcl or SQL\*Plus runner. Sourcing `lib/detect-stack.sh` read-only in that directory
produced:

```
detect_languages: []
detect_stack:     unknown unknown none none
detect_also:      []
verify.test:      []
verify.test_one:  []
verify.lint:      []
datastores:       []
```

Every field empty, including `datastores`, on a repository that is unambiguously Oracle. The second
instance is an `apex-export` output tree (663 `.sql`, 466 `.plsql`), though that tree
is keel's own `apex-export` output rather than a hand-written project, which makes it a weaker case.

## What was asked for

> Ability to detect PLSQL or general SQL projects and configure profile schema accordingly. Where
> possible, an appropriate LSP plugin could be suggested for installation

## The case against

**Strongest argument for not building this at all: PL/SQL has no manifest, so this is the first
language keel would infer rather than read, and the inference is unsafe.** All thirteen languages in
`detect_languages` (`lib/detect-stack.sh:172-212`) are detected from a file the project itself
declares: `package.json`, `go.mod`, `Cargo.toml`, `pom.xml`, `Package.swift`. That is not an
accident of implementation, it is what makes detection trustworthy, and the same doctrine is stated
explicitly for verify commands at `lib/detect-stack.sh:290-292`: "Never guesses: an absent command
becomes null in the profile so a skill knows to ask." A PL/SQL repository declares nothing. The only
available signal is the presence of `.sql` files, which is a property of a great many projects that
are not PL/SQL projects: a TypeScript service in the same estate holds 20 `.sql`
Drizzle migrations against 379 `.ts` files, and the sweep of 2026-08-18 also found stray `.sql` in
two further non-Oracle services. Mislabelling a TypeScript service as a PL/SQL
project is worse than the empty profile this idea is trying to fix, because an empty profile makes
a skill ask and a wrong profile makes it proceed.

That argument is answerable, and the answer is the shape of the recommendation rather than a reason
to stop: a ratio test that yields to any manifest cannot fire on the Drizzle repository, because
that repository has a `package.json`. But it has to be built as "no manifest anywhere, and `.sql`
dominates", not as "counts `.sql` files", and the difference is the whole risk.

**Second argument: even perfect detection cannot produce a test command.** utPLSQL runs inside a
database. `tests/run_all_tests.sql` is meaningless without a connection string, a schema and
credentials, none of which are in the repository and none of which keel may guess. So `verify.test`
stays `null` whatever this builds, and the profile the user ends up with still has to be finished by
hand. What detection actually buys is `stack.language`, `stack.datastores` and a language server
recommendation, which is real but is less than the idea implies.

**Third argument: it is not a one-line change.** `tests/validate-skills.sh:364-379` fails the build
when a language in `detect_languages` has no row in `skills/keel/references/tool-choices.md`. Adding
`plsql` therefore requires at least one row, with a reason rather than a verdict, for an ecosystem
where the honest answer to lint and typecheck is "none". (Corrected 2026-08-18: the original said
`:341-345` and asserted three rows were required. The rule is a whole-file grep and one row passes.)

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Nothing | The empty profile is real and reproducible, and there are two repositories waiting on it |
| Do it manually | One edit to `.keel/profile.json` after `init` | Genuinely viable, and it is what happens today. The profile is a file and a human may write any of it. It does not travel, so the next Oracle repository pays again, and it leaves `keel doctor` unable to say anything useful about a stack it does not recognise |
| Buy it | Nothing available | No tool classifies a repository as a PL/SQL project and emits keel's profile shape |
| Build something smaller | One conservative marker plus a datastore hint, no verify commands | Recommended. See the variants table |

**Variants of building it**

| Variant | Note |
|---|---|
| No manifest anywhere, and `.sql` plus `.plsql` are the dominant extension | Recommended. Cannot fire on any of the false positives found on 2026-08-18, because every one of them has a manifest. Yields to the existing thirteen by construction |
| A raw count of `.sql` files over a threshold | Rejected. Fires on the Drizzle service at 20 files, and on any repository with a large migrations directory |
| Detect `oracle` in `stack.datastores` only, and leave `language` alone | Smaller still, and it fixes the more obviously wrong field. Leaves `language: unknown`, so `coding-standards` and `tdd` still have nothing |
| Detect PL/SQL specifically, versus SQL generally | The idea says both. They are different: PL/SQL implies Oracle and a package structure, general SQL implies migrations and usually belongs to another language's project. Recommend PL/SQL only, since general SQL is the false-positive case |
| Recognise `apex-export` output as a project kind | Narrow and certain, because that layout is keel's own and has a `manifest.json`. Does nothing for the hand-written repository, which is the real instance |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| A PL/SQL repository has no manifest of any kind | The marker can be "absence of manifest plus SQL dominance" | True of the Oracle repository, which has only `.claude/settings.json`. One instance | Partly |
| Filename convention is not a reliable marker | `.pks` / `.pkb` / `.spc.sql` / `.bdy.sql` are too rare to key on | the Oracle repository has exactly one `.spc.sql` and one `.bdy.sql` out of 191 files. A machine-wide search for `.pks`, `.pkb`, `.prc`, `.fnc` found none at all | **Yes, and it rules out the obvious marker** |
| utPLSQL is the test framework worth naming | An Oracle project that tests at all uses it | 16 mentions across the Oracle repository's `tests/`. One instance, and it is the only real option | Partly |
| `verify.test` must stay null | No test command can run without a connection | Follows from the doctrine at `lib/detect-stack.sh:290-292`. Nobody has tried to write one | **No, worth one attempt before accepting it** |
| Two repositories justify a fourteenth language | The cost lands once and the benefit repeats | Unknown. GBi's Oracle exposure is not written down anywhere | **No** |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| Every detected language is read from a declared manifest | `lib/detect-stack.sh:172-212` | PL/SQL would be the first inferred language, and the doctrine that makes detection trustworthy is the thing being departed from |
| Detection never guesses a verify command | `lib/detect-stack.sh:290-292` | `verify.test` stays null, so the profile still needs a human |
| `datastores` is detected by grepping dependency manifests | `lib/detect-stack.sh:555-580` | ~~The `oracle` entry exists and can never fire~~ **Wrong, corrected 2026-08-18 while writing the PRD: there is no `oracle` pair, and no `oracle` anywhere in the file.** The eight pairs are postgres, mysql, redis, mongodb, sqlite, elasticsearch, cassandra, dynamodb. The function also returns early when no manifest exists, so `oracle` cannot be added to that list and reach a PL/SQL repository at all. It is new work keyed on the new marker, not a cheap fix. Now `CON-04` |
| A detected language with no tool-choices row fails the build | `tests/validate-skills.sh:364-379` | **Line range corrected 2026-08-18: `:341-345` is a repo-snapshot rule.** The check greps the whole file for one row matching the language, so ~~three table rows~~ **one row satisfies the build**. Three may still be the better thing to write, which is now `Q3` in the PRD |
| A live false positive exists | the Drizzle service: 20 `.sql`, 379 `.ts`, with `package.json` and `tsconfig.json` | Any marker must yield to a manifest. A count-based rule is not safe |
| Filename conventions are absent in practice | 1 `.spc.sql` and 1 `.bdy.sql` in 191 files; no `.pks`, `.pkb`, `.prc` or `.fnc` anywhere on the machine | The marker most guides would suggest does not exist in the real repository |
| keel already ships two Oracle skills | `skills/apex-export`, `skills/apex-port-plan` | Oracle is not new ground. Neither skill needs `stack.language`, which is why the gap survived this long |
| The LSP half already works, on a fresh repository only | `lib/detect-stack.sh:581-596` maps all thirteen languages to a language server, `detect_plugins` at `:601-608` collects them, and `bin/keel:565` writes them into `.claude/settings.json`. Verified 2026-08-18 on a fixture: a fresh TypeScript repo gets `typescript-lsp` enabled | `docs/03-install-and-distribution.md:212-222` is accurate. Adding PL/SQL means one `lang_lsp` branch, if a server exists |
| The LSP is silently skipped on any repository that already has `.claude/settings.json` | `bin/keel:558-561` returns after merging permissions only, and `merge_permissions_into_settings` (`:583-606`) touches `permissions` and nothing else. Verified on a fixture: the mature repo got no `enabledPlugins` key at all, not even `keel@gbi` | The real defect, and it is not PL/SQL's. Tracked in `docs/ideas/stack-plugins-on-existing-repos.md` |
| `plugin_report` cannot detect that, because init never writes `plugins.recommended` | `bin/keel:142-163` falls back to a hardcoded three with no LSP in it; `tests/validate-skills.sh:358-360` records the omission as deliberate | The mechanism exists and works. Only the writer is missing, which is one line |

## Open questions

1. **Is the LSP contradiction fixed by implementing `docs/03` or by correcting it?**
   **Answered 2026-08-18, and the premise was wrong.** There is no contradiction: `docs/03` is
   accurate and `lang_lsp` covers all thirteen languages. The real defect is narrower and is not
   about PL/SQL, so it moved to its own record, `docs/ideas/stack-plugins-on-existing-repos.md`.
   For this idea it collapses to a small question, open question 2 below.
2. **Which PL/SQL language server, if any?** **Answered 2026-08-18: none exists.** The
   `claude-plugins-official` catalogue on this machine was searched for every SQL, Oracle and PL/SQL
   name it carries. There are twelve language servers and not one of them is for SQL. The closest is
   `oracledb`, a database client sourced from a third-party git URL rather than the official
   marketplace, which is a different kind of thing and a larger decision than a language server.
   `lang_lsp` already returns empty for an unmapped language and `detect_plugins` skips it silently
   (`lib/detect-stack.sh:603-606`), so this needs no code at all. The `tool-choices.md` row should
   say "none, and here is why".
3. ~~**Does the Oracle repository want a keel profile at all?**~~ **Answered 2026-08-18: nobody
   knows, and the work is justified on detector correctness instead.** The requester chose to measure
   whether the marker fires and stays silent where it must, asserted by fixtures, rather than invent
   an adoption target for a repository that is not ours to commit. Now section 9 of
   `docs/prd/plsql-stack-detection.md`.
4. ~~**Is general SQL in scope?**~~ **Answered 2026-08-18: no**, as recommended. Now section 11 of
   the PRD.

## Recommendation

**Build something smaller.** Detect PL/SQL only, on the conservative marker "no manifest for any of
the thirteen, and `.sql` plus `.plsql` dominate the tree", set `stack.datastores` to `oracle` on the
same signal, and leave every verify command null so a skill still asks.

Why: the empty profile is reproducible and there are two repositories waiting, but the marker is an
inference rather than a declaration, so the only safe version is one that cannot fire on any project
that declares itself to be something else. The false positive at the Drizzle service is the test
this must pass.

Next: `write-prd` is done, at `docs/prd/plsql-stack-detection.md`. The marker was settled there as
"no manifest, `.sql` plus `.plsql` are the plurality, there are at least ten of them, **and at least
one contains an Oracle-exclusive token**", the last clause added on 2026-08-18 so a manifest-less
PostgreSQL migrations repository cannot be mislabelled. That restores the doctrine this record
worried about departing from: the project declares itself again, in file contents rather than a
manifest. The tokens are `VARCHAR2`, `DBMS_` and `PACKAGE BODY`; `%TYPE` and `%ROWTYPE` were
considered and rejected, because PL/pgSQL supports both. And
`stack.framework` reads `apex` when keel's own `manifest.json` carrying `"apex_version"` is present.
The LSP half needs no code at all: open question 2 established that no PL/SQL language server
exists.

## Not decided here

Decided on 2026-08-18 while writing the PRD, and struck through here so the trace survives:

- ~~The exact dominance ratio~~ Plurality plus a floor of ten, `FR-01` to `FR-03`.
- ~~Whether `stack.framework` should read `apex`~~ Yes, `FR-06`, keyed on keel's own manifest.
- ~~Whether `coding-standards` grows a PL/SQL section~~ No, out of scope.

Still open: how the tree is walked in detail, which is a plan-level question bounded by `NFR-01`
and `NFR-02`; the wording and number of `tool-choices.md` rows, now `Q3`; and everything about how
stack plugins reach a repository that already has a settings file, which is
`docs/ideas/stack-plugins-on-existing-repos.md`.
