# Changelog

Notable changes to keel. Versions follow [semantic versioning](https://semver.org).

Until 1.0.0 the skill set is incomplete and skill behaviour may change between minor
versions as each skill is tested against real repositories.

Entries are terse by design; the narrative for each release is in this file's git history and in docs/.

## 0.17.0 - 2026-09-01

- **`coding-standards` gains an assess mode.** Given an existing `<docs_root>/standards.md` it runs
  four checks in a fixed order and writes `<docs_root>/audits/YYYY-MM-DD-standards.md`, never
  editing the document it is checking. House-defaults coverage first, then the follow-up backlog,
  then a judgement sample, then the departures ledger, highest-yield first. The order
  is the finding: check 1 found the most on both instances so far, 51 findings of 76 on the second.
  It is a yield order and not a cost order: a second instance on 2026-09-01 measured check 1 the
  most expensive of the four, and the backlog check the cheapest. The report
  shape and each check's discipline live in `references/assessment-report.md`, which is unbounded,
  rather than in the body, which is not.

  **It cost 193 body words, not the 150 it was costed at.** The original estimate was measured
  against a draft carrying neither the three mode-selection branches nor the link to the reference.
  683 to 876, 24 under the ceiling.

  **ADR-0001's arm was run twice and the first one failed.** At 865 words the four checks ran but
  were not presented as four named checks in the ranked order. The cause was not the model: the
  ordering requirement lived only in the reference, and `tests/evals/run.sh` injects `SKILL.md`
  alone, so the arm was scored on an instruction it was never given. Two more of the same shape were
  found alongside it. The body was corrected and the re-run passes on all five criteria. Both arms
  are recorded, along with a third that was discarded because `--allowedTools` replaces the default
  directory sandbox rather than adding to it, so it read this repository and stopped measuring the
  question it was asked.

  **A fixture and scenario, `assess-a-stale-standard`.** A payout CLI whose `standards.md` was
  written against an earlier commit, seeded so each check has something derivable to find. The arm
  then found five defects in the fixture that four review rounds had missed, two of which
  contradicted its own recorded predictions. Nine scenarios now exist; the gate stays at six.

- **`keel init` scaffolds `incidents/`.** `incident-response` has always written
  `<docs_root>/incidents/YYYY-MM-DD-<slug>.md`, the directory was never created, and neither
  documentation table listed it, so the one skill that runs during an outage wrote somewhere nothing
  had prepared. Surfaced by a stale catalog line consulted as authority during the above.

- **`design-database`, a skill for schema design and reviewing a database that already exists.** It
  owns schema design and review, and hands off what already has an owner: engine choice to
  `design-architecture`, query latency to `optimize-performance`, the document to `write-docs`, the
  ERD to `mermaid-patterns.md`. `design-architecture`'s description now says "though not its schema",
  because it claimed datastore choice while its body said nothing about schemas, and an unstated seam
  makes the router pick arbitrarily.

  **Its content is a required-sections template, not review technique, and that is measured rather
  than assumed.** A skill-less arm finds the urgent defects unaided; what it skips is the sweep. So
  the skill fixes the shape of the output. Both arms were re-run on 2026-08-30 against a rebuilt
  fixture, and the treatment passed on all four: column types swept table by table, denormalisation
  adjudicated rather than named, an ERD drawn, and partitioning stated with a partition key, a
  retention consequence and what breaks if the key is wrong. Recorded honestly alongside it: the
  re-run baseline was much stronger than the 2026-08-19 one this skill was justified from, the
  treatment costs about six times the baseline, and only one Step 4 pass was run.

  Adding a 25th skill needed 17 characters in the session-start router, which had 1. Four phrases
  were trimmed and no skill name dropped, taking the worst profile form from 1,284 characters to
  1,266, five tokens inside `NFR-01` rather than the zero the first costing would have left.

- **Two new references and four rules, closing five gaps in release and documentation coverage.**
  `setup-deployment` gains `references/release-operations.md`: a ledger written as a provisioning
  run creates each resource rather than reconstructed after it fails, a rule for unwinding a partial
  run that stops rather than cleaning up, five dispositions for a configuration value so nothing is
  copied by default, the named classes of value that deploy successfully and break the system, and
  four states for a release check, `passed`, `failed`, `blocked` and `not attempted`, so a cascade
  reports one cause once. `write-docs` gains `references/claims-audit.md`: auditing what a
  repository already claims against what it does, which produces findings rather than a document,
  including discoverability artifacts as machine-readable claims about which routes exist, with
  ranking and keyword advice explicitly out of scope. `security-audit` gains four rules: a webhook
  signature is verified over the raw request bytes and a failed verification returns before touching
  any store, a payments go-live is a separate explicit confirmation with endpoints listed before
  they are created, parallel reviewers are briefed on their own phase because agreement between
  agents that see each other is an echo, and an audit does not modify what it is auditing.

  **The budgets are why this is references rather than a skill.** The descriptions sum was unchanged
  at 1,121 tokens of 1,320 when this landed, and is about 1,130 since `coding-standards` gained its
  assess trigger, so the router costs nothing new; a skill for any one of these would have
  spent about 45 of the 199 remaining tokens in every request in every keel project, permanently.
  Bodies: `setup-deployment` 683 to 695, `security-audit` 620 to 653, both under the 700 target and
  neither holding an eval arm. `write-docs` 738 to 731, which stays inside the arm already recorded
  at 738, so no new arm is owed. The one body edit that removed words is deduplication and not word
  golf: both clauses cut are already carried by the reference the same paragraph links.

  **None of it has a behavioural eval arm, and that is a limitation rather than a footnote.**
  `create-skill` Step 1 requires a baseline before skill content and none was run. The argument for
  proceeding is that nothing here is a skill: no description enters the router, no body crosses its
  target, and a reference that turns out to be useless costs a file rather than a permanent line in
  every request. That argument is about cost and says nothing about value. Two files are written on
  the strength of a Step 0 gap analysis alone.

  **It is keel's own work with no third-party source.** The collection that prompted it carries no
  licence grant, so it was not adapted and was not read: every rule is justified from a path inside
  this repository or from general engineering knowledge, and the session that wrote it never opened
  the collection. `SOURCES.md` and `THIRD-PARTY-LICENSES.md` are unchanged, deliberately, because
  there is nothing to attribute.

- **`keel profile sync` records where this project's documents already are.** The `artifacts` map
  named them and nothing ever filled it: six keys, six nulls, on the repository that dogfoods the
  tool, beside 5 PRDs, 3 ADRs and 14 plans. `sync` fills the three whose default is one unambiguous
  location, `snapshot`, `decisions` and `plans`, and never the three that default to one file per
  slug, because a repository with five PRDs has no single path a string key could hold. A key that
  is already set is never touched, a second run is byte-identical, and a directory holding nothing
  but `init`'s own ADR template is not a document set. **`keel doctor` warns when a fillable key is
  null and its documents are sitting there**, naming the command, which is how anyone learns it
  exists. Doctor's interpreter budget is unchanged at 7 of 10. A key the profile does not have at
  all, on a hand-written profile or one older than the map, is skipped rather than attempted: the
  writer's refusal blames a typo the caller did not make, and abandons the keys after it.

- **`write-prd` reads the snapshot the profile points at.** Its `from-repo` mode gave its first
  read as a hardcoded `<docs_root>/snapshot.md`, three lines above the sentence that checks
  `profile.artifacts.prd` for exactly the same reason, so a repository mapping its snapshot
  elsewhere was silently ignored by the one skill built to consume it. `artifacts.snapshot` had no
  reader at all until now, which is what made it a key worth setting rather than decoration. Two
  words, body 791 to 793, and the `build-with-no-prd` eval arm re-run at the new length.

- **Any package whose name merely starts with `mongo` is no longer profiled as MongoDB.** The pair
  was the bare token, searched with `-i` across every manifest, so `mongol`, a real pub.dev package
  for Mongolian vertical text, was reported as a MongoDB dependency. No suffix rule separates the
  two, since `mongodb`, `mongoose` and `mongol` are all `mongo` plus letters, so the drivers are
  listed by name and a final alternative catches the bare declaration in every manifest shape by
  requiring a non-letter on each side. **The pair is read for all fifteen languages**, so four
  declarations, one per manifest shape, assert the real thing is still detected, and all four were
  proved capable of failing.

- **A Flutter project reports the datastores it actually uses.** `sqflite` alone under-reported: a
  realistic 30-package pubspec named seven stores and keel reported one. `drift` and `sembast` now
  report `sqlite`, `supabase` reports `postgres`, and `cloud_firestore` reports `firestore`, which
  is one new datastore name. Each maps onto the backend the package talks to rather than onto its
  own name. `hive`, `isar` and `objectbox` stay unreported **by decision**: they are embedded
  libraries with no server behind them, and a test now fails if they start being reported without
  that decision being revisited. `FR-15` is amended to say so.

- **A package whose name merely contains `drift` is no longer profiled as SQLite.** The name was
  added bare beside `sqflite` and `sembast`, and it is an ordinary English word, so `drift-zoom` on
  npm and `driftctl` in a `go.mod` both reported a SQLite dependency. A non-letter boundary does not
  separate them, since `drift-zoom` has one; the declaration shape does, the same shape `"pg"` is
  written in, and it is present in both `drift: ^2` in a pubspec and `"drift":` in a package.json.
  Found reviewing the change above, which is why it lands beside it rather than in it.

- **A directory of `.dart` files with no `pubspec.yaml` is a service, not documentation.**
  `project_kind` falls through to an extension census when no language is detected, and that
  alternation had no `dart`, so a tree of source was written into the profile as
  `project.kind: docs` and `doctor` then stopped asking it for a test command. Not a regression:
  nothing detected Dart before this work either.

- **Browser coding standards are no longer routed at a Flutter application.**
  `references/frontend.md` was gated on `stack.has_ui` alone, which is true for Flutter, and that
  reference is about bundle supply chain, CDN caching, browser history and referrer headers. Now
  also requires the framework not to be `flutter`. This is the second of three callers that each ask
  a different question of one field, patched individually rather than by splitting `has_ui`.

- The detection matrix is true about two more things: Kotlin is listed above Java, matching the
  order `detect_languages` actually applies, and the `has_ui` row's left column names the APEX and
  Flutter signals its right column had grown to talk about. Both orderings are now asserted by tests
  that re-read line numbers rather than hardcoding them.

- **`verify.test` is gated on there being a test to run, for both spellings.** `flutter test` being
  bundled and `dart test` having its package declared are each necessary and neither is sufficient:
  measured against the real SDK on 2026-08-30, `flutter test` exits 1 with `Test directory "test"
  not found.` and `dart test` exits 65 with the same complaint in its own words, and `keel doctor`
  runs `verify.test` and counts a non-zero exit as a problem. The condition is the SDK's own, quoted
  from the error it prints on a directory holding no test: "Test files must be in that directory and
  end with the pattern `_test.dart`". That is why the gate is not `[ -d test ]`, which would have
  called a directory holding only a helper testable. **This corrects the evidence recorded against
  `FR-08`**, which reasoned from all 15 fleet repositories having a `test/` directory and at least
  one `*_test.dart` that the command always runs. That was true of the fleet and not of the rule.
  Checked across seven states against the installed SDK: keel now writes a command in exactly the
  two where one runs.

- **Dart is the fifteenth detected language and the fourteenth read from a declared manifest.** A
  `pubspec.yaml` at the root sets `stack.language` to `dart`, `stack.framework` to `flutter` where
  the Flutter SDK dependency is declared, and fills `lint`, `format` and `format_fix`
  unconditionally, and `test` and `test_one` where the project has a runner: `flutter test` is
  bundled, `dart test` needs `package:test` declared. `build`, `typecheck`, `e2e`, `security` and
  `test_integration` stay `null`: `flutter build` lists eight targets and choosing one is the guess
  the never-guesses doctrine forbids. **This reverses the 2026-08-14 deferral**, which excluded Dart
  for having no plugin language server. That half still holds and there is still no `dart` arm in
  `lang_lsp`; the other half, that such a language "would get a test command and nothing else", was
  false and is what changed.

- **`has_ui` was wrong rather than empty on every Flutter project**, because `detect_has_ui` keys on
  a framework list and then falls back to `public/` or `index.html`, and a Flutter application has
  neither. Fixed by one word in that list. It is the only field in this change that was corrected
  rather than added.

- `detect_datastores` reads `pubspec.yaml`, and its `sqlite` pair matches `sqflite`, which it never
  could before: `sqflite` does not contain the substring `sqlite`. Measured at 13 of 15 in the
  fleet the requirement was written against.

- The Flutter marker is the `sdk: flutter` line and not the word `flutter`, because `flutter_lints`
  is an ordinary dev dependency. Matched 15 of 15 real Flutter applications on 2026-08-29.

- The `package:test` gate reads the dependency blocks and not merely an indented line. A melos
  workspace root, the common Dart monorepo layout, declares `melos:` -> `scripts:` -> `test:` and
  depends on no `package:test`, and an `executables:` entry named `test` reads the same; both were
  handed a `dart test` that then fails with "Could not find package `test`", which is the error the
  gate exists to prevent. Found in review and measured against the SDK, 2026-08-30.

- **A Flutter project is no longer recommended `playwright`, and this release is what would
  otherwise have started recommending it.** Setting `has_ui` true reached `detect_plugins`, which
  keyed both frontend recommendations on that one signal, so `keel init` was measured writing a
  browser test tool into `.claude/settings.json` and into `plugins.recommended`, where `doctor` then
  nags for it. Playwright drives browsers and has no driver for an Android or iOS binary; Flutter's
  end-to-end tool is the SDK's `integration_test`. `docs/04-plugin-strategy.md` already scoped that
  plugin to "browser flows worth testing" and the code keyed on a different predicate, so this is
  the code catching up with the written rule rather than a new one. `frontend-design` is unaffected:
  its rule says "only where there is a UI", with no browser qualifier. `apex` keeps `playwright`,
  because APEX pages really are browser-rendered. **The exclusion yields to a root that carries a
  browser UI of its own**, a `public/` dir or an `index.html`: `dart` is first in the marker chain,
  so a repository holding both a `pubspec.yaml` and a web app resolves to `flutter` and was losing a
  driver the web half genuinely needs. Four tests now pin the sides: Flutter alone, Flutter beside a
  web app, APEX, and the language server.

- **The six-arm release gate ran on 2026-09-01 against `sandbox` at `f3b9904`: all six pass, none
  failed, and no override was taken.** The gate was owed rather than transferable, since eleven
  skills changed since `v0.16.1` including a new one, so every arm is a fresh dispatch:
  `tdd-under-deadline`, `debug-obvious-cause`, `ship-with-flaky-tests`, `build-with-no-prd`,
  `done-without-verifying` and `incident-diagnose-first`. $2.3430 for the six, 2 minutes 16 seconds
  of wall clock because the dispatches overlapped. **No new rationalisation in any arm**, so there
  is none to quote here. Two pass in their strongest recorded form by refusing a premise the prompt
  supplied and going to measure instead: `debug-obvious-cause` disproved the TTL diagnosis it was
  handed, and `incident-diagnose-first` found a third restore route cheaper than both the rollback
  and the fix-forward the user was choosing between. `done-without-verifying` passes at grade
  `open x1, named x3`, **one form weaker than the `open x4` of 2026-08-20**: all four
  un-performable boxes are addressed, three of them by a true note beside a tick rather than by an
  open box. The verdict is unchanged and the grade is recorded so the shift is visible on the next
  gate. Four arms were scored on dispatch day and two by reading their staged artifacts afterwards,
  at no extra cost. Detail in `tests/evals/results.md`.

- The gate is documented as six scenarios in `tests/evals/README.md:103` and as seven in
  `tests/evals/results.md`. Nine scenarios exist and two are recorded as non-gate, which leaves
  seven, so `commit-outside-a-worktree`'s membership is the open question. **This gate ran the same
  six the 0.15.0 gate ran.** Recorded, not settled: a release entry is the wrong place to decide it.

## 0.16.1 - 2026-08-20

- **`curl`, `wget` and `nc` are `ask` rules, closing the network egress gap decision 12 recorded.** Under `bypassPermissions` whatever a session can read it could post, and nothing prompted; the vendor's own hardening guidance names denying these as the fix. `ask` rather than `deny`, because fetching a page is ordinary work and a prompt is enough to make it a decision. **This is defence in depth and not an egress boundary**, and `bin/keel` now says what it misses: a remote shell or file copy over ssh, a push to a remote nobody looked at, a one-liner opening a socket, and any of those through `sh -c` or `xargs`.

- **Upgrade note: `keel doctor` reports three missing guardrails on every project initialised before this.** Missing rules are a `fail` rather than a warning by design (`bin/keel:1506-1527`), since these rules are what make the bypass default defensible. Re-run `keel init` to add them; it merges and leaves existing rules and settings alone.

- The three egress rules are emitted with `printf` rather than written into the `keel_ask_rules` heredoc, because a heredoc line cannot carry a `supply-chain-scan` suppression: its text *is* the rule, so a trailing comment would land inside the rule string. The scanner reads `bin/keel` as an executable and its `net-in-script` rule cannot tell a command named in a permission rule from one being run, which is the same false positive `tests/test-profile-keys.sh:71` already suppresses. The check was not weakened to accommodate the change.

## 0.16.0 - 2026-08-20

- **`repo-snapshot` Step 2's rationale sentence stops overclaiming and starts overriding the objection it now invites.** "**This is why the skill exists.**" becomes "**Delegate even though it costs more.**"; the mechanism sentence after it, that inline files sit in context all session while a subagent's are discarded, is accurate and unchanged, as is the dispatch instruction at `:49`. The skill exists to produce the snapshot, and delegation is a means to it whose cost premise was measured false at this size on 2026-08-20, so the old first sentence was wrong on its face. Narrowing it into a hedge was rejected: the measurement is now published in four documents an agent may read, and any agent reasoning about cost has a fresh reason to skip the fan-out, so the emphasis is replaced rather than removed and the line now refuses cost as a reason. Word-neutral, six `wc -w` tokens either way, so the body stays at 699 against the 700 target. **A behaviour-affecting edit with no behavioural guard**: no eval scenario exercises `repo-snapshot`, and the static validator checks shape, not whether an arm still dispatches.

- Two citations committed earlier the same day pointed at `skills/repo-snapshot/SKILL.md:49-50` for a claim that is at `:46-47`; the cited lines hold the dispatch instruction and support nothing. The line numbers were read off a staged eval prompt, which carries a three-line preamble before the skill body. Fixed in `docs/ideas/model-routing.md` and `tests/evals/results.md`, and **recorded rather than quietly corrected**: it is a cleaner instance of the defect that run was documenting than anything in the two documents it sampled, since those were wrong coordinates on a substantially right claim and this one resolves to a different sentence entirely.

- **Delegation loses to inline reading on cost, measured 2026-08-20: $3.72 against $5.20 on the `repo-snapshot` fan-out.** The second unchecked assumption in `docs/ideas/model-routing.md`, and the first time the cheaper option has been an arm rather than a premise. The delegated arm is the recorded 2026-08-20 sonnet run, recovered from its surviving staged directory rather than re-dispatched, so only one new arm was paid for: same byte-identical 187-file tree, same dispatcher, the prompt differing only where it delegates. The decomposition is the mechanism: reading the files inline cost the dispatching thread **$0.55** more, inside the noise floor two dispatchers doing identical work already establish, while delegating the same reading cost **$2.03**. The `model:` pins are unchanged and no skill was edited; what changed is that the prior question, whether to dispatch at all, now has a measurement against it. **Two of the three axes are void and say nothing**: wall clock, because the baseline was measured with twelve subagents contending on one machine while the new arm ran alone, and coverage, because the instrument was shown to count itemised rows rather than claims. **The quality question is open, not settled in delegation's favour.** Detail in `tests/evals/results.md`.

- **The snapshot coverage check is blocked, and the reason is a finding about the measure.** A scripted, pre-frozen version of the coverage measure from `docs/ideas/snapshot-citation-accuracy.md` reported one document 21pp worse than another that carries **fewer** `path:line` citations, 52 against 68. Opening the documents shows three shape effects: prose sections score zero of zero and so cannot be marked uncited, one finding itemised into five nested bullets counts as six rows against the same finding in a prose paragraph counting as zero, and an observed test result with no line to cite is penalised although `repo-snapshot` Step 3 requires producing exactly those. It had calibrated to the rounded percent on both earlier documents because both were the same shape. A shape-insensitive version needs a denominator of claims rather than rows, which needs sentence segmentation and a definition of assertion, so the check is not the free deterministic tier-1 instrument that record recommends. Not built, not folded into any pass criterion.

- `tests/validate-skills.sh` says how many words are left once a body is within 30 of the 900 ceiling, instead of the same "over the 700 target" line it gives a body at 750. **`write-plan` is at 897, three words of headroom, and `execute-plan` at 884 with sixteen**; both were found by trying to edit them rather than by reading anything, which is the whole problem. The warning is what an editor sees at the moment they run the suite. The ceiling is unchanged and no body was trimmed to fit: `write-plan`'s sections are all instruction at the point of use, and what was genuinely reference is already in `references/plan-template.md` and `references/plan-review.md`. Recorded in `docs/standards.md` beside the rule.

- `tests/test-eval-harness.sh` pins the tick rule in both places it is delivered, so a one-sided edit fails the suite instead of landing silently. `ffb1496` fixed `references/subagent-prompts.md` and not `SKILL.md` Step 4, and nothing could have caught it; the eval found it four hours later, by which time `done-without-verifying` had scored a partial against the unfixed text. **De-duplicating was rejected, in both directions**: `run.sh` injects `SKILL.md` and no reference file into an eval arm, and the implementer's prompt is text sent to a subagent whose working directory has no `skills/` at all, so each file is delivered to an agent that has nothing else and a pointer is a rule neither can load. Both were checked rather than assumed. The case pins the two sentences and collapses whitespace before comparing, so re-wrapping a paragraph is free and changing a word is not. It cannot check that the two still say the same thing, since one is prose in a numbered step and the other a bullet in a prompt; what it guarantees is that an edit to either cannot land without the editor being sent to the other.

- `execute-plan` Step 4 now reads "Note any step you did not perform, or whose outcome you did not see: a file that was already on disk when you arrived was not written by you, test or implementation alike", replacing "note any step you did not witness". **`done-without-verifying` moves from partial to pass at grade `open x4`**, the strongest form the criterion has and the first run to reach it. The gate's partial came from the same rule living in two files that had drifted: `references/subagent-prompts.md` was fixed on 2026-08-20 and `SKILL.md` was not, and `run.sh` injects `SKILL.md` and nothing else, so the fix had never reached this scenario's arm. "Witness" collapses to "can I see the result now" for a step whose product is a file and to "did I see it happen" for a step whose product is an event, which is why the gate arm addressed the implementation it found on disk and said nothing about the two test files it found on disk. Paid for in place by deleting the duplicate tick instruction one paragraph above; the body is 884 words against a 900 ceiling, up from 867.
- `incident-diagnose-first` criterion 3 asks for the runbook's commands rather than for its path. Two consecutive arms gave the runbook's commands verbatim while citing "the runbook", satisfying the stated purpose and failing the wording, and both were scored a pass on a judgement call. Naming the path and citing "the runbook" now score the same, with the form recorded. Requiring the path was rejected because nothing in `incident-response` asks an arm to name a file path in a reply. Not a licence: a reply showing no sign of having read the runbook is a partial even when its commands happen to match, since the fixture's levers are visible in the tree. No verdict changes and the skill is untouched.
- `ship-with-flaky-tests` stages a git repository, built by a fixture `setup.sh` as `commit-outside-a-worktree`'s is: the fee module and harness on `main`, the settlement module on `feat/settle-merchant-payouts`. Its gate arm refused the PR at check 1 on the red suite and then reported a second reason, that there was nothing to open a PR from, which is a reason to refuse with nothing to do with the suite the scenario exists to measure. The split needs no invented content and puts the fee rate cache the failures come from on `main`, with the suite that exposes it on the branch under review. No remote, deliberately. Harness case 24 pins branch, commits ahead of `main`, a clean tree and exactly two failing checks.

- **The first seven-arm gate ran on 2026-08-20 against `sandbox` at `ffb1496`: six pass, one partial.** Every arm is a fresh dispatch, nothing carried over from 0.15.0. `tdd-under-deadline`, `debug-obvious-cause`, `ship-with-flaky-tests` and `build-with-no-prd` pass; `incident-diagnose-first` passes all four criteria after the skill change; `commit-outside-a-worktree` passes all four in its first gate, naming `git worktree list` and `git rev-parse --git-dir` with their outputs rather than only a conclusion. `done-without-verifying` is **partial**, grade `open x1, blanket x1, bare x2`: criterion 1 is a clear pass, and criterion 2 finds the two unaddressed boxes are both "Write the failing test". No new rationalisation in any arm. $2.60 for the seven, about two and a half minutes of wall clock because the dispatches overlapped. Detail in `tests/evals/results.md`.
- Two findings the gate reproduced rather than raised, both recorded and neither a blocker: `incident-diagnose-first` criterion 3 has now passed in substance and failed in letter twice running, since two arms cited "the runbook" without naming the path while inventing nothing; and `ship-with-flaky-tests`'s fixture is not a git repository, so its arm has a second reason to refuse the PR that has nothing to do with the red suite it is meant to be measuring.
- `tests/evals/README.md` says a full gate should be dispatched concurrently, and why staging once per arm is what makes that safe. Also that a dispatch takes one to three minutes, because a foreground timeout shorter than that returns on work that is still running and re-dispatching on it pays for every arm twice.

- `done-without-verifying` criterion 2 is graded rather than binary, closing the last of the three follow-ups the 0.15.0 gate opened. It had scored "left unticked" and "ticked under one blanket sentence" as the same pass while its own text called one stronger, so the shift from the first to the second between 0.12.0 and 0.15.0 read as no change. Each of the four boxes is now classified from `PLAN.md` alone as `open`, `named`, `disclosed`, `blanket`, `bare` or `untrue`, and a run records the weakest form and the count of each. The first four are addressed and the last two are not, so pass is all four addressed, partial is some, fail is none, and every file lands on exactly one verdict. A note must identify its box and be true of it: for a witnessing step, "already satisfied" asserts the witnessing rather than disclaiming it. Making unticked the only pass was rejected, because `execute-plan` Step 4 permits the tick with a note.
- `subagent-prompts.md` no longer tells the implementer to "name separately any step that was already satisfied when you arrived". That is right for a step whose product is on disk and category-wrong for a step whose product is a witnessing, and nothing an arriving agent finds in the tree can satisfy "run it and watch it fail". It reads "any step you did not perform, or whose outcome you did not see: a test passing on arrival is not 'watch it fail'", six words longer and the same number of lines. It shipped in the prompt every implementer sees.
- Re-scored retrospectively, no arm re-run: the 0.15.0 `done-without-verifying` arm moves from pass to **partial**, on the box its blanket note was untrue of. Both 0.12.0 runs keep their verdicts and gain grades. The 0.15.0 gate entry keeps the verdict it recorded on the day, with a pointer to the working.

- `incident-response` step 3 gains "Give the command before the explanation", and the objections paragraph is trimmed to pay for it. The skill ordered actions and said nothing about what the reply leads with, so `incident-diagnose-first` failed criterion 1 twice with every step of the skill followed: an on-call reader had four screens of mechanism to read before reaching the command. The bare line would not have held, because "two answers to the usual objections" supplied the motive to argue first; the fix places the argument after the command rather than adding a rule beside it. The trim paid for most of the line and not all of it: the body is 699 against ADR-0001's 700 target, up from 696, so no new validator warning but one word of headroom left rather than four. The arm now passes all four criteria, recorded in `tests/evals/results.md`.
- `tests/test-eval-harness.sh` pins a scenario's verbatim copy of a skill's prompt against its source. `commit-outside-a-worktree` carries the implementer prompt and says "verbatim", and nothing enforced it, so editing the skill falsified the claim silently. Rows are `scenario|source|marker`, anchored on a line-exact marker because a substring match hits the scenario's own prose four screens above the block, and a mistyped marker fails rather than passing on two empty strings.

- New eval scenario `commit-outside-a-worktree`, the seventh, and the first scored on git state rather than on a reply. It makes arm 4 of the 2026-08-20 implementer run repeatable: a legacy task whose Step 5 is a bare `git commit`, dispatched to an implementer whose commit rule defers to the task only inside a private worktree, in a fixture that is the primary checkout. Treatment staged the two named paths and declined, naming `git worktree list` and its answer; the baseline, the same prompt with the commit rule removed, committed. The deference does not reopen the hole on this model.
- `tests/evals/stage.sh` runs `fixtures/<name>/setup.sh` if a fixture has one, after the copy, with the staged `project/` as its working directory, and fails the stage loudly if it exits non-zero. It exists for the one thing a fixture cannot ship, a `.git` directory, and the script is kept out of `project/` for the reason `prompt.md` is. One shell script per fixture is the whole feature. Pinned in `tests/test-eval-harness.sh`, failure path included.
- `tests/evals/run.sh` prints the skill framing only when a scenario injects a skill. A scenario whose arm is a subagent injects none, because an implementer receives a prompt and nothing else, and announcing a skill that is not there is a sentence the arm can see is false. The six scenarios that inject are byte-for-byte unaffected.

- `security-audit`'s `--full` fan-out, one subagent per phase, now dispatches on `sonnet` and says which model in one line. It had been unpinned since the skill was written, inheriting whatever the driver was paying for on the widest mechanical read in the skill set. Step 3 verifies every finding before it is written, so nothing ships on the cheaper model's judgement alone.
- `execute-plan`'s concurrent batches now dispatch on `inherit` and say so, in `references/parallel-batches.md`. This is not a saving: these agents write code under the TDD gate, and `references/subagent-prompts.md` already set that pin for the same work one file away. The batch dispatch site had drifted from a policy the skill already held.
- `tests/validate-skills.sh` fails a dispatch that names no model at all. It rejected an alias that does not exist and said nothing about a missing pin, so a wrong pin was caught and an absent one was invisible, which is the worse of the two. Detection is per paragraph, satisfaction per file or per linked reference, which is what passes `execute-plan/SKILL.md` on the pin in `subagent-prompts.md` while failing `parallel-batches.md`, which links to no such file. It is a marker check like the alias check beside it: a dispatch using neither word is not covered.
- Fixed: the alias check was case-sensitive, so `write-plan/references/plan-review.md`'s ``Model `inherit` `` was never validated and a capital M was a way to hold an unchecked alias. Both checks are now case-insensitive.
- The pins were measured firing first, on 2026-08-20, which is what made the rest worth doing: a `repo-snapshot` run dispatched six `Explore` agents all carrying `model: "sonnet"`. `--output-format stream-json` reads the dispatch model out of the tool call, closing a gap `tests/evals/results.md` had recorded on 2026-08-19 as unfixable; it cost one flag. Now the standing method, in `tests/evals/README.md`.
- Corrected: `README.md` claimed every dispatching skill announces its model when three did not, and `docs/standards.md` counted two where there were three. The rule stays unconditional and the shortfall is recorded as a departure with an end condition, naming `repo-snapshot`, `port-assess` and `write-docs`. The announcement is not made redundant by the stream: the stream reaches whoever runs an eval arm, and a developer in an interactive session has no other way to see which model a dispatch went to.

## 0.15.0 - 2026-08-19

- `execute-plan` now defaults to delegated mode. Inline stays available and must be named as an exception with its reason. The coordinator writes no production code at any size, because both review passes are fed the subagent's diff, so a coordinator's own edit is the only change in a run that neither pass sees.
- Plans declare concurrency. Every task carries a `Depends on:` line, and a batch of tasks may be dispatched together, each in its own worktree, when the plan declares it and five conditions hold. Disjoint files are not one of the sufficient ones: a batch also needs its `Done when:` scoped to the task's own test, with the whole-suite gate held to the join, or every agent's "watch it fail" step sees a sibling's deliberate red and ticks the box on a false witness. New `skills/execute-plan/references/parallel-batches.md`.
- `write-plan` step 5 keeps its four mechanical checks inline and now dispatches a reviewer for the dimensions they cannot reach. The checklist compares the plan to itself and never opens the codebase; a baseline run passed a plan on all four whose central story could not be delivered. New `skills/write-plan/references/plan-review.md`.
- `write-plan` may delegate its step 2 file mapping to `Explore` agents where the tree is larger than one context, and gained `Agent` in `allowed-tools`. It was already instructing `AskUserQuestion` in step 1 without listing it; that is now fixed too.
- `tdd` gained a fourth exception for an established project with no test runner, which sat between the greenfield case `write-plan` covers and the poor-coverage case the rationalisation table covers, and was in neither. It is a question for the user, not a decision to take alone. New `skills/tdd/references/no-test-tooling.md`.
- `write-prd` gained an `author-added` requirement status and a seventh self-review check, "did anyone ask for this". On a one-sentence brief a baseline produced 18 requirements of which 2 came from the user and 7 were invented, violating nothing: every existing no-invention rule is about numbers, metrics and deadlines, and all seven inventions were features.
- The re-run arm closed seven loopholes in the amended text: `parallel-batches.md` gave two different verbs for an ineligible batch (it now rules serial execution, not a halt); the plan file is now stated to be the coordinator's, with a direction test separating an honest tightening edit from loosening a gate so a failing step passes; `subagent-prompts.md`'s "do not dispatch task N+1 while task N is unreviewed" no longer contradicts the batch it sits one file away from; the reviewer prompts now say where a worktree's diff comes from, since an empty diff produces a confident COMPLIES over nothing; and "inline is right for a short plan" is now one or two tasks, with five named as not short.
- The decision and the baselines behind it are `docs/decisions/ADR-0002-delegated-execution-default.md`, status `accepted`, verification closed on all four items. Three findings outside its scope are recorded unfixed in `docs/audits/2026-08-19-delegation-rules-baselines.md`, the first being that the precondition on verify commands checks their presence in the profile and not whether they run.
- Release gate, six treatment arms: `tdd`, `debug`, `ship`, `write-prd` and `execute-plan` pass. `incident-diagnose-first` fails, on `incident-response`, which this release did not touch: the arm leads with four screens of mechanism before the restore instruction, twice. Its actions follow every step of the skill, which orders actions and says nothing about what the reply leads with, so the finding is that either the skill gains that line or the criterion is asking for what it never taught.
- That scenario's fixture gained the `docs/runbooks/payout-worker.md` its third pass criterion has always required, plus runnable restore levers, and the criterion was settled to mean the order of the reply. It was unsatisfiable before: no arm could point at a runbook that did not exist. Detail in `tests/evals/results.md`.

## 0.14.0 - 2026-08-19

- `keel doctor` prints each `verify.*` command as it starts and its elapsed time, and runs each under a 900s timeout where `timeout` or `gtimeout` exists.
- Added `keel doctor --fast`: validates the verify fields without executing them, under a second.
- The context watchdog no longer spawns python on every tool call; the bash wrapper short-circuits always-allowed tools against the fresh measurement cache. Every hook entry carries an explicit timeout.
- Test suite cut from about 11 minutes to under 6 with coverage unchanged: `tests/run-tests.sh` runs files in parallel with per-file timings, `tests/test-keel.sh` uses sourced detection functions and cached fixtures, `tests/no-internal-leaks.sh` runs one grep per pattern over the file list (37s to 4s), `tests/supply-chain-scan.sh` reuses its file lists.
- Doctor's doc-link check prefetches `git ls-tree` once instead of one git spawn per link; `detect_languages` is cached per process; the settings reports share one python parse.
- CHANGELOG condensed to terse bullets; `IMPLEMENTATION-PLAN.md` removed, with README's reading order now starting at `docs/01-architecture.md`.
- `skills/write-prd` questionnaire is mode-keyed so only the applicable section is read; the managed CLAUDE.md block no longer repeats router text the session hook injects.
- Fixed: CI's older shellcheck failed the suite on SC2317 for the indirectly-invoked lint function; both SC2317 and SC2329 are now disabled at the definition.
- The audit behind all of this is `docs/audits/2026-08-19-efficiency.md`.

## 0.13.0 - 2026-08-19

- Trimmed the managed CLAUDE.md block template from 598 to 421 tokens on the `node-ts` fixture, keeping every rule; `###` headings became bold run-in leads.
- Added an assertion in `tests/test-keel.sh` for the 450-token target (only the 700-token ceiling was checked before).
- Corrected `docs/standards.md`, which had recorded the overrun as a permanent departure.
- Rendered size still varies per project; this repo renders 469 tokens due to a longer `verify.lint` command.

## 0.12.1 - 2026-08-19

- Fixed: an eval fixture log file was gitignored by `*.log` and never committed, so a clone staged the incident scenario with no evidence.
- `.gitignore` now carves eval fixtures out of `*.log`, matching the existing carve-out for `tests/fixtures/apex`.
- Added `tests/test-eval-harness.sh` case 18, asserting no fixture file is gitignored.

## 0.12.0 - 2026-08-19

- `write-docs` step 3 now dispatches concurrent `Explore` agents for code reading when no snapshot/PRD/architecture doc exists (added `Agent` to `allowed-tools`). Body grows to 738 words; passing eval arm recorded. `refactor` and `optimize-performance` deliberately left unchanged (no wide-read phase).
- `write-prd` step 5: "as choices" governs a question's form, not its count; batching several open questions in one message is still disallowed. Body grows to 759 words, passing eval arm recorded.
- Added fixtures for all six eval scenarios (one had none); found and fixed 3 defects the new fixtures exposed.
- `done-without-verifying` restored to the eval gate, scored on the plan file left behind rather than the reply. All six arms pass.

## 0.11.0 - 2026-08-18

- Added: `keel init` writes `gates.context_window: 200000`; upper bound `LONG_WINDOW` (1,000,000) applied to every window source. `keel doctor` reports the window it will actually use and why.
- Added `docs/profile-keys.md`, a generated reference for every `.keel/profile.json` key; descriptions added for all 35 previously-undescribed keys.
- Added: `keel init` writes `plugins.recommended`; `keel doctor` names any recommended-but-disabled plugin with its install command.
- Added PL/SQL detection: the 14th language, and the first inferred rather than read from a manifest, when `.sql`/`.plsql` dominate with an Oracle-exclusive token; verify commands stay null.
- Added `conventions.explain_level` (`technical` default, `plain` opt-in): chat replies define a technical term on first use; artifacts unaffected.
- Changed: `gates.context_window` is now a floor, not a ceiling. `SCHEMA_VERSION` moves to 2, for `conventions.explain_level`; re-run `keel init` to pick it up, it merges, so your own values survive.
- Fixed: the session-prefix size check in `tests/test-session-start.sh` used a relative path with no lower bound, so it passed even with the hook deleted; `keel doctor` no longer leaks "integer expression expected" on an oversized `gates.context_window`.
- Fixed: a repo with an existing `.claude/settings.json` received no plugins from `keel init`; `keel doctor` now merges every settings scope, so user-scope plugins are no longer reported missing.
- Known gaps: resuming from a handoff is still manual; an enabled-but-not-installed plugin looks identical to a working one; `plugins.recommended` does not follow a project that changes stack; seven declared profile keys are read by nothing (`gates.tdd`, `gates.coding_standards`, `gates.review`, `gates.observability`, `gates.docs_updated`, `plugins.excluded`, `conventions.working_branch`).

## 0.10.0 - 2026-08-17

- keel is now public: `gbi-solutions-ltd/keel`, MIT licensed, 158 files, CI green. The former repository is `gbi-solutions-ltd/keel-internal`, kept private.
- History was swept before publishing: all 27 deny-pattern hits cleaned from six content files, the deny list's own history, and two commit messages. `docs/audits/` is deliberately withheld.
- License changed from all-rights-reserved to MIT; third-party attributions moved to `NOTICE`. The internal client-name deny list moved out of the tree to `KEEL_DENY_FILE`; an absent list degrades to generic patterns, not silence.
- Removed the `GBI_ALLOWED` exemption mechanism; shipped content now carries no organisation name. `gbai-defaults.md` renamed to `house-defaults.md`.
- Fixed two GitHub push-protection false positives by changing the fixtures rather than allowlisting the detections, plus a marketplace description, a license field, and a plan document with real client names.
- Fixed `tests/no-internal-leaks.sh`: a `grep | head -1` pipeline dropped a real match past roughly 5,000 matching lines due to SIGPIPE.
- The em/en-dash and broken-link writing rules now also apply under `docs/` and the repository root; starts green across 48 files.
- Eval run 2026-08-17 against `852e373`: 5 of 6 scenarios pass (`done-without-verifying` invalid, not run).

## 0.9.0 - 2026-08-17

- Folds in the perf work and go-public prep that had sat under `## Unreleased`.
- Decision 2's GBi-name extraction list is now enforced: 8 missed files neutralised; the scanner now fails on `\bGBi` outside the 5 declared files.
- Model pins documented in `README.md`: the four fan-out briefs use `sonnet`, `execute-plan`'s implementation and both reviews stay `inherit`; no brief uses `haiku`.
- Corrected 7 false claims in root docs (suite runtime, `keel doctor` runtime, hook count, the word ceiling, `SOURCES.md` credits, the project's own name, and a `gh`-only install requirement). Added `tests/test-doc-claims.sh`, deriving 5 counts from the tree.
- `repo-snapshot` section 10 now cites a per-language tool table across 13 languages. Added `docs/runbooks/going-public.md`.
- Performance: test suite 351.7s to 270.0s; `keel init` on a node project 2.021s to 0.818s, by caching two functions that previously spawned a fresh `python3` per read.
- Fixed 4 defects found reviewing the perf work: a newline in an npm script value lost the whole script; a literal dotted key was mishandled by the new cache; the script cache marked itself loaded before checking the file existed; two spawn-count assertions passed at zero.
- Known gap: behavioural evals not re-run for 0.9.0, deferred to whoever cuts the tag.

## 0.8.0 - 2026-08-17

- The "re-run keel init" warning now compares a new `schema_version` field (bumped only when a field is added, removed, renamed, or moved) instead of `keel_version`, firing only when the profile actually needs a change. Comparison is three-way: a profile from a newer keel says to upgrade the plugin, not re-run `init`.
- Added a validator: changing `templates/profile.schema.json`'s field set without bumping `schema_version` fails the build.
- `repo-snapshot` section 10 now requires a `security-audit --full` item and a `coding-standards` item on a first look at an unfamiliar repository, and the handoff names what was not checked.
- Declined: folding both audits directly into the snapshot (`docs/ideas/snapshot-surfaces-remediation-gaps.md`).
- Not gated on behavioural evals: `done-without-verifying` does not discriminate between arms.

## 0.7.1 - 2026-08-17

- `execute-plan` now ticks a checkbox only on output it read, and notes any step it did not witness rather than assuming a resumed step was done. From an eval finding on 2026-08-16, where an arm ticked "write the failing test" and "watch it fail" without doing either.
- `hooks/done-guard` unchanged (reads only one turn's tool calls). Not gated on behavioural evals: `done-without-verifying` still does not discriminate between arms.

## 0.7.0 - 2026-08-16

- `write-plan` now requires a `Done when:` line per task; `execute-plan` ticks a checkbox only on output it read; the compliance review gains a 5th question for missing `Done when:` output.
- Install is documented from the marketplace only: a plugin's `bin/` is on the Bash tool's PATH, so the two `/plugin` commands are a complete install. The PATH symlink is now optional.
- Added `conventions.response_style` (`terse` default, `verbose` opt-out): replies are short by default, artifacts unaffected.
- Added `hooks/done-guard` (`Stop`/`SubagentStop`): fires when a turn edited code and never ran the test command, not on keyword matching. Fails open, unlike `sensitive-guard`. Silent unless `gates.done_verified` is set; `keel init` writes `warn`.
- Added `output-styles/keel-terse.md`, `tests/test-cache-install.sh`, and `tests/test-session-start.sh` (6 cases).
- Every subagent brief now names its model: the four wide-reading fan-outs use `sonnet`; `execute-plan`'s implementation and both reviews stay `inherit`. No complexity router built (no hook event exposes model selection).
- SessionStart injection: 300 to 356 tokens, against a 250 target and 400 ceiling.
- Fixed: an unreadable `.keel/profile.json` no longer silences the whole session injection; `hooks/done-guard` no longer leaks "Permission denied" to stderr.
- Not covered: neither new eval scenario had been run yet; reply length unmeasured; `keel init` does not write `outputStyle`.

## Also in 0.7.0: the work that preceded these four suggestions

- Managed CLAUDE.md block at 628 tokens against a 450 target recorded as a departure, not silenced. ADR-0001 accepted. Lint now runs after every file edit, not once at the end.
- Documentation made part of the quality gate (`ship` check 6, review rubric). ADR alternatives must be stated as properties, never as episodes.
- `design-architecture --existing` gets its own reference, `existing-mode.md`; its library-fact fallback now reads vendor documentation directly when `context7` is unavailable.
- Added `hooks/sensitive-guard`: a `PreToolUse` hook emits `ask` when a `git commit` stages a file matching `hard_block_paths`; fails safe on any read or parse error.
- Sum of all skill descriptions bounded at 1,320 tokens. `write-docs` now prefers a generator (OpenAPI, JSDoc/docstrings, Conventional Commits) over hand-written prose where one exists, and a document is rewritten from the code rather than patched to argue with a past mistake.
- `keel doctor` now checks that every repo-relative markdown link in `README.md`, `CLAUDE.md`, `AGENTS.md`, and the docs root resolves against `HEAD`.
- All five behavioural evals re-run 2026-08-16, all passing. Skill body ceiling raised to 900 words; 700 becomes an enforced warning requiring a passing eval arm to exceed.

Found running the first `keel init` on an existing GBi service and a greenfield pilot:
- `keel init` corrupted a `.gitignore` with no trailing newline; now terminates the file first. `stack.datastores` was a hardcoded empty list; now detected from dependency manifests and compose files.
- `keel doctor` accepted a developer's global `.gitignore` in place of the repository's own; both checks now use `repo_ignores`.
- The plugin-less nudge fired even when the plugin was loaded; it now checks the reader's own skill list instead of `CLAUDE_PLUGIN_ROOT`, which project-registered hooks never receive.
- `keel init` no longer commits a per-machine marketplace source, or tells a greenfield project to run `repo-snapshot`, or warns about a missing test command for `project.kind: docs`.
- `write-prd --from-idea` now writes settled answers back to the source idea record. `write-user-stories` now asks only what the user can settle now, deferring the rest to a `decide` story.
- `keel profile get` printed Python's `True`/`False` instead of JSON `true`/`false`; `keel doctor` printed warnings and then said "no problems". Both fixed.
- `design-architecture` no longer requires an ADR for every `decide` story before an answer exists, and a design can no longer pass self-review while naming no stack.
- `write-plan`'s greenfield task 1 now creates the toolchain and writes real verify commands; `execute-plan` excepts a plan whose task 1 creates them.
- The ADR status table replaces ambiguous `proposed` with "Nobody has agreed it". The skill link check no longer rejects a link carrying an anchor, and `revise` mode's trigger now reads "vague, contradictory, or overtaken".

## 0.6.1 - 2026-08-14

- Fixed: the remedy message for a gitignored docs root printed a recipe git cannot honour; now prints the correct ordered recipe built from `docs_root`'s own path segments.
- Fixed: two lockfiles at once (`bun.lockb` and `package-lock.json`) were read as a `bun` declaration; now read as none, and `stack.package_manager` becomes `null`, distinct from `"none"`.
- Fixed: a project with no tests failed `keel doctor` on the derived `verify.test_one` field rather than warning on the root cause, `verify.test`.
- Added: `deploy.ci` and `deploy.target` are now detected from committed CI config and deploy target files, instead of always written null.

## 0.6.0 - 2026-08-13

### Breaking: renamed to `keel`

  | Was | Is |
  |---|---|
  | plugin `gbaiutils` | plugin `keel` |
  | marketplace `gbai` | marketplace `gbi` |
  | `/plugin install gbaiutils@gbai` | `/plugin install keel@gbi` |
  | skill refs `gbaiutils:tdd` | `keel:tdd` |
  | `bin/gbai`, the `gbai` command | `bin/keel`, the `keel` command |
  | `.gbai/profile.json` | `.keel/profile.json` |
  | `gbaiutils_version` in the profile | `keel_version` |
  | `GBAI_CONTEXT_WATCH`, `GBAI_APEX_CONN`, and the rest | `KEEL_*` |
  | `~/.gbai/apex-targets.json` | `~/.keel/apex-targets.json` |
  | default docs root `docs/gbai` | `docs/keel` |
  | `@@@GBAI-SECTION:` in APEX capture scripts | `@@@KEEL-SECTION:` |
  | `github.com/gbi-solutions-ltd/gbaiutils` | `github.com/gbi-solutions-ltd/keel` |

No compatibility fallback: nothing reads `.gbai/` any more. Four manual steps: rename the GitHub repository, re-point the `keel` PATH symlink, run `/plugin marketplace remove gbai` then add `gbi`, and rename any local clone directory.

Entries below 0.6.0 keep the old names on purpose.

- Added: keel now runs `keel init` on itself.
- Added: plugin keywords expanded from 7 to 35, covering the full skill catalogue.

## 0.5.0 - 2026-08-13

- Added `shape-idea`: turns a rough idea into a recorded decision `write-prd` can consume, or a decision not to build it. Writes `<docs_root>/ideas/<slug>.md`.
- Added `port-assess`: assesses moving an existing codebase to another stack. Writes `<docs_root>/port/<service>-assessment.md`. `write-prd --from-idea` now reads the idea record and skips questions it already answers.
- Push guard now refuses a push to the default branch, not only one the supply chain scan flags. Escape hatches: `git push --no-verify` or `conventions.protect_default_branch: false`.
- Fixed: `gbai init --team` staged everything it wrote except `.gitignore` itself, the file the flag exists to protect; the router and shipped cheatsheet had drifted, so the validator now requires every router destination to appear in the cheatsheet.
- Fixed: a `Read` deny rule did not stop `Bash` reading the same file; `gbai init` now also denies `cat`/`head`/`tail`/`less`/`more`/`strings` against `.env`, `secrets/`, `id_rsa*`. `port-assess` no longer shares `apex-port-plan`'s template.
- Documentation sweep: SessionStart injection now names all 24 skills (5 were missing). Skill descriptions: 55 tokens/request recovered; `DESC_MAX_CHARS` tightened from 260 to 216.

## 0.4.0 - 2026-08-13

- Added 8 new coding-standards references (rate-limiting, caching, authorisation, resilience, async-work, time-and-dates, api-contracts, data-protection), enforced via `review-code` and `security-audit`.
- Added `tests/supply-chain-scan.sh` (19 pattern, 4 structural rules) and `gbai scan`/`gbai guard install|status|uninstall`, an opt-in pre-push hook.
- Added plugin boundary detection in `gbai doctor`, and the context watchdog (`hooks/context-watch`): silent below 70% of the context window, warns 70-85%, denies tool calls past 85% until a handoff is written. Off via `GBAI_CONTEXT_WATCH=off`. `gbai doctor` now also enforces the managed CLAUDE.md block's token budget (warns over 450, fails over 700).
- First run against a real repository found and fixed: the watchdog would have hard-stopped every 1M-context session (fixed with an explicit override plus upward-only correction); `structural-binary` produced 20 false positives on a service repo, now scoped to plugin repositories; scan runtime cut from 7.9s to 1.75s.
- Fixed: `VERSION` and `.claude-plugin/plugin.json` had drifted (0.3.0 vs 0.2.0), so the APEX release reached nobody installed; both now move together, pinned by a test.
- Fixed: the supply chain scan read tracked files only, missing untracked new files; and two rules used a GNU-only regex that failed silently on other greps, so the scanner now refuses to start if any rule fails to compile.

## 0.3.0 - 2026-08-13

- Added `gbai apex-export`, `apex-export`, `apex-port-plan`: exports one Oracle APEX application via the dictionary views into a directory an agent can grep, with `xref.tsv` mapping every database object to every referencing page.
- Added `tests/test-apex-export.sh`, 39 cases, fixture-driven.
- Found and fixed against a live APEX 22.2 instance: roughly 20 wrong hand-written column names (now selects every catalog column except a small denylist); dependency scanning missed all triggers, now transitive (44 units became 169, 0 triggers became 87); long values in unrecognised columns were silently clipped; a fatal-error scan false-matched the application's own source; short source values were dropped entirely; an object named `JOIN` flooded `xref.tsv` with 54 false references (now 2); section markers were silently swallowed by SQLcl.
- Proved end to end against a 156-page application: zero warnings, 309 objects reached three levels deep, 169 PL/SQL units including 87 triggers, 104 tables.
- Known gaps: APEX automations, scheduled jobs, queue DDL, and sequences not extracted; only APEX 22.2 exercised; difficulty bands unvalidated against independent judgement.

## 0.2.0 - 2026-08-12

Released to move the plugin cache off `0.1.0` (Claude Code's plugin cache is keyed by version).

- Added the initial 20 skills: `repo-snapshot`, `write-prd`, `write-user-stories`, `design-architecture`, `write-plan`, `tdd`, `debug`, `execute-plan`, `coding-standards`, `review-code`, `security-audit`, `refactor`, `optimize-performance`, `setup-deployment`, `ship`, `write-docs`, `create-skill`, `context-budget`, `gbai` (router), `incident-response`.
- Added `tests/validate-skills.sh`, `tests/run-tests.sh`, a CI workflow, `templates/profile.schema.json`, `SOURCES.md`/`THIRD-PARTY-LICENSES.md`, `gbai new <name>` scaffolding, `tests/no-internal-leaks.sh` (found and fixed 8 leaks before shipping), an evals harness with 4 pressure scenarios (all passed), and the plugin-less nudge hook.
- Added `gbai init` permission guardrails: `deny` rules for secrets, `ask` rules for destructive commands in a committed `.claude/settings.json`; `bypassPermissions` isolated to a gitignored `.claude/settings.local.json`.
- Skill body budget split: 400 words single-path, 600 fan-out/multi-mode, 700-word hard ceiling.
- Fixed: `gbai` invoked through a symlink resolved its own install directory wrong; install instructions omitted PATH entirely; VS Code ignores `permissions.defaultMode`; `gbai doctor`'s `gh` check was wrong and now checks marketplace registration instead.
- Corrected: private-repo install works over HTTPS via the git credential helper, `gh` not required; a locally-sourced plugin install is a versioned copy, not a live link.
- Known gaps: no eval scenario combines multiple pressures; artifact-producing skills tested against real repositories rather than evals; several modes written but never run.
