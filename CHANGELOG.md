# Changelog

Notable changes to keel. Versions follow [semantic versioning](https://semver.org).

Until 1.0.0 the skill set is incomplete and skill behaviour may change between minor
versions as each skill is tested against real repositories.

## 0.13.0 - 2026-08-19

**The managed CLAUDE.md block fits the budget it declares.** Its own header has always said "Budget:
450 tokens. This sits in every request, so every line must earn its place." It rendered at 598. So
every project `keel init` configured opened with a `keel doctor` warning about a block keel itself
wrote, which is the warning most likely to teach someone that keel's warnings are noise.

The template now renders at 421 tokens on the `node-ts` fixture, a 30 percent cut, with every rule
intact. The `###` section headings became bold run-in leads and the prose was rewritten; the worked
examples were compressed rather than dropped. Nothing that told an agent what to do was removed.

**It shipped because nothing asserted the target.** `tests/test-keel.sh` checked the 700 ceiling and
never the 450 target, so the template could drift 148 tokens past its stated budget with a green
suite. There is now an assertion for the target, and it was verified red against the old template
before the trim.

**`docs/standards.md` recorded this overrun as a departure on the argument that closing it "deletes a
rule rather than words".** That was wrong and is now corrected there. The words were available; the
test that would have shown it was missing.

**One caveat, recorded rather than hidden.** A rendered block substitutes the three verify commands
and the docs root, so its size varies per project. This repository renders 469 because its
`verify.lint` is a single 160 character `shellcheck` invocation, which is 198 characters of commands
where the fixture has 37. That is a property of one profile value, and it stays recorded as a
narrowed departure with shortening `verify.lint` as its end condition.

## 0.12.1 - 2026-08-19

**A fixture's evidence file was never committed.** `tests/evals/fixtures/incident-diagnose-first/logs/worker.log`
matched `.gitignore`'s `*.log` rule, so it existed in one working tree and in no clone. The whole
suite passed locally, because `stage.sh` copies what is on disk, and the export gate went red,
because an export copies what git knows.

The file is not incidental to its scenario. It carries the fifteen minute healthy gap between the
deploy and the first failure, which is the fact that contradicts the user's hypothesis and the reason
the fixture exists. A clone was staging an incident with no evidence in it.

`.gitignore` now carves eval fixtures out of `*.log`, the same carve-out `tests/fixtures/apex`
already has for being synthetic and committed on purpose. `tests/test-eval-harness.sh` case 18
asserts that no fixture file is gitignored, so the suite catches this rather than the export three
steps later.

**No skill changed between 0.12.0 and 0.12.1**, so the six passing treatment arms carry over
unchanged. They were dispatched from a tree that contained the log, which is the tree 0.12.1 ships.

## 0.12.0 - 2026-08-19

**`write-docs` can delegate its reading.** `Agent` was absent from its `allowed-tools`, so a skill
whose description covers documenting a feature or module read every file inline, in the main
context, for the rest of the session. Step 3 now dispatches concurrent `Explore` agents for the code
reading when the snapshot, PRD and architecture doc do not exist, which is the case the skill was
silent on. `repo-snapshot`, `port-assess` and `apex-port-plan` already worked this way.

`refactor` and `optimize-performance` were checked at the same time and deliberately left alone.
Neither has a wide-read phase: `refactor` is told to stay inside the boundary it was given, and
`optimize-performance` is measurement throughout, where a delegated number is a number nobody ran.

The body goes from 695 to 738 words, over ADR-0001's 700 word target, so it owes a passing eval arm
at that length. That arm ran and passed, recorded in `tests/evals/results.md` under 2026-08-19. It
also found that the eval harness cannot see tool calls, so whether the new branch fired is not
scored; the reason is written up there.

**`write-prd` no longer reads as licence to ask five questions at once.** Step 2 has always said one
question per message. Step 5 said to surface open questions as choices, and an eval arm took that as
permission to batch, asking five in one table. Step 5 now states that the rule holds there, that "as
choices" governs the form of a question and never the count, and that where `AskUserQuestion` is
unavailable it is still one question in the reply rather than a list in it. 699 to 759 words, with a
passing arm at that length.

**Every eval scenario now has a fixture, and that changed what the gate measures.** Dispatch moved
outside the repository just before this release, which closed a real exposure and left five of six
scenarios pointed at an empty directory: an arm with no code can say what it would do and cannot be
observed doing it. Five fixtures were added, all bash and dependency-free. In the gate that followed,
three arms modified code and ran suites, one ran a suite ten times to test the user's claim rather
than accepting it, and one wrote a PRD against a real schema.

Arms then found three defects in those fixtures within the hour, all fixed: a retry loop that logged
a backoff and never slept, a commit summary claiming changes its diff did not contain, and a comment
describing a database column that does not exist. Two arms read the fixtures better than they were
written, and both readings are kept and documented rather than removed.

**The eval gate is six scenarios again.** `done-without-verifying` is back in it, scored on the plan
file an arm leaves behind rather than on the reply it writes, because both arms passed the old
reply-level criteria identically while leaving plan files that differed. All six treatment arms pass.

## 0.11.0 - 2026-08-18

Four changes. Three touch the same file, `.keel/profile.json`: the watchdog's window key changed
meaning and is now written, every key in the profile is now described and discoverable, and replies
can be asked to define their technical terms. The fourth is a new language.

**`gates.context_window` is now a floor, and `keel init` writes it.** The watchdog cannot read a
session's context window: a 1M session records its model as plain `claude-opus-5` and no field
anywhere names the window. The only correct mechanism was the profile key, and nothing wrote it, so
every project needed it typed in by hand and `keel doctor` nagged about it on every run.

Writing it was unsafe until the key changed meaning. `window_for` returned a configured value before
it reached the observation correction, so a profile saying 200000 on a genuine 1M session reported
200% occupancy, hard-stopped the session at 170,000 tokens and never lifted. Writing a conservative
value into every profile would have made that the default experience. The key is now a floor:
observation may still raise it in flight, which is what makes a wrong value recoverable rather than
permanent.

**Replies can be asked to use plain language, and artifacts still cannot.** The reply is the only
part of keel's output aimed at a reader who is not a developer, and nothing told it to avoid the
vocabulary of the thing it describes. `conventions.explain_level` is that dial, separate from
`response_style` because length and vocabulary are independent choices. The always-loaded injection
did not grow to pay for it: the hook swaps its paragraph rather than appending one, so the defaults
still cost exactly what they did before.

**PL/SQL is detected, and it is the first language keel infers rather than reads.** All thirteen
existing languages are read from a file the project commits about itself, which is what makes a
profile trustworthy, and a wrong profile is worse than an empty one because an empty one makes a
skill ask. So the marker is deliberately conservative: no other language's manifest anywhere, `.sql`
and `.plsql` outnumbering every other extension, at least ten of them, and at least one carrying a
token no other dialect uses natively. A repository that declares itself is never censused, so no
existing project's profile can change and `keel init` on one does no extra filesystem work.

**Every profile key is now described, and discoverable in one page.** The file every skill reads and
every user is expected to adjust could not be learned without reading `bin/keel`. 35 of 59 declared
keys carried no description, and five had neither a description nor a mention in any document.

### Added

- `keel init` writes `gates.context_window: 200000`. `SCHEMA_VERSION` does not move, because the
  schema already declared the field.
- An upper bound of `LONG_WINDOW`, currently 1,000,000, on every window source. It is the largest
  context window any current model offers and already the highest value observation could reach, so
  it adds no ceiling the observed path did not have. A mistyped extra zero no longer silences the
  watchdog for the life of the project.
- `keel doctor` reports the window the watchdog will actually use, and says why when that differs
  from the file: a value above the maximum, a value below the default that a floor cannot apply, a
  value that is not a usable number, or `KEEL_CONTEXT_WINDOW` overriding all of them.
- `docs/profile-keys.md`, a generated reference for every key `.keel/profile.json` may contain,
  saying what each does and whether `keel init` writes it or you do. Produced by
  `tests/generate-profile-keys.sh`, linked from the README, and guarded two ways:
  `tests/validate-skills.sh` fails when the page and the schema disagree, and `tests/test-keel.sh`
  pins the set-by column against a real `keel init`. The column is derived from an actual init
  rather than a maintained list, because a maintained list is what drifts.
- A description on all 35 keys that had none. The five with no description and no mention anywhere
  got the most care: `deploy.secrets_manager` now says it names the store and never a secret,
  `deploy.registry` that it is the address and not the access.
- `keel init` writes `plugins.recommended`, and `keel doctor` names any recommended plugin that is
  not enabled along with the `/plugin install` command for it.
- PL/SQL detection, the fourteenth language and the first inferred rather than read. A repository
  with no manifest for any of the other thirteen, where `.sql` and `.plsql` outnumber every other
  extension and at least one carries an Oracle-exclusive token, is detected as `plsql` with `oracle`
  as its datastore. Every verify command stays `null`, because utPLSQL runs inside a database and the
  connection details are not in the repository, so the profile still needs finishing by hand.
- `conventions.explain_level`, `technical` by default. Set it to `plain` and chat replies define a
  technical term the first time they use it. Artifacts are unaffected: a PRD, plan or ADR stays as
  technical and as detailed as its skill requires. `keel init` writes the key, and the SessionStart
  hook picks its paragraph from this key and `response_style` together, so all four combinations are
  configured rather than three plus a silence.

### Changed

- `gates.context_window` is a floor rather than a ceiling. A value at or below 200000 now has no
  effect; `KEEL_CONTEXT_WINDOW` is how a smaller window is forced deliberately, and it is used as
  set apart from the bound.
- `lib/context_watch.py`'s `measure` and `handoff` commands take an optional project directory and
  read `gates.context_window` from it. They previously ignored the profile entirely, which was
  harmless while almost no profile set the key and wrong once `init` wrote it everywhere: a 1M
  project at 150,001 tokens got a handoff header reading `150,001 of 200,000 tokens, 75.0%` while
  the hook sat correctly silent at 15%. The project is named rather than inferred from the working
  directory, because a transcript does not say which project it belongs to and guessing made the
  same transcript report two different windows depending on where the command was run. With no
  project named the window comes from the transcript alone, as before.
- The `gates.context_window` schema description, both `keel doctor` watchdog messages, and
  `window_for`'s docstring all describe the rule the code implements. All four previously said an
  explicit setting simply wins.
- `SCHEMA_VERSION` moves to 2, for `conventions.explain_level`. Existing projects will see
  `keel doctor` report the profile as older than the installed keel. Re-run `keel init` to pick the
  key up; it merges, so your own values survive.
- `tests/validate-skills.sh` sizes the SessionStart injection for all four dial combinations rather
  than only the one the local profile selects, and reports a hook that produces no output instead of
  counting it as comfortably small.

### Fixed

- The session-prefix size check in `tests/test-session-start.sh` ran the hook by a relative path
  with only an upper bound, so from any other working directory it measured 0 tokens and passed. The
  hook could have been deleted and it would have stayed green. It now uses the absolute path and a
  lower bound.
- `keel doctor` no longer leaks `integer expression expected` when `gates.context_window` holds a
  value wider than a 64 bit integer.
- A repository that already had a `.claude/settings.json` received no plugins at all from
  `keel init`, not even `keel@gbi`, and `keel doctor` could not report it. `plugin_report` reads
  `plugins.recommended`, which nothing wrote, so it fell back to a hardcoded three with no language
  server in it. init now writes the key, from one `expected_plugins()` definition that both writers
  read, so a fresh init produces the same set in both places.
- `keel doctor` reported a plugin as not enabled when it was enabled at user scope. `plugin_report`
  read only the project's `.claude/settings.json`, which was harmless while its fallback list held
  three plugins nobody enables per project, and wrong the moment `keel@gbi` entered the list: keel is
  normally enabled at user scope, so every project was told it was missing, on the line above doctor
  saying the marketplace was registered. It now merges every scope Claude Code merges, as
  `boundary_report` already did.

Nothing is written into an existing `.claude/settings.json`. That file is normally committed and
decides what loads for everyone who clones, which is a decision for whoever owns the repository,
and it is the same position `bin/keel` already takes on permission mode.

### Known gaps

The handoff still has to be resumed by hand: the watchdog writes `.keel/handoff.md`, and the user
runs `/clear` and points the next session at it. `/clear` cannot be triggered by a plugin. The
resume half is buildable and is not built, because nothing yet detects whether a handoff is current;
a pointer injected at session start would otherwise send a new session to last week's work. Tracked
in `docs/ideas/context-window-at-init.md`.

An enabled plugin that is not installed still looks identical to one that is working. keel cannot
install a plugin, and verifying that an entry resolves was left out of this change deliberately.

`plugins.recommended` does not follow a project that changes stack. `merge_profile` keeps any
non-empty existing value, which is what lets a curated list survive a re-init, and it cannot tell a
curated list from a stale detected one: adding `go.mod` to a TypeScript project updates `stack.also`
but leaves `gopls-lsp` out of the recommended list, and nothing reports the difference. Re-running
`keel init` does not fix it. `keel doctor` warns about `stack.has_ui` drift in the same situation and
the same treatment would suit here.

Seven declared keys are read by nothing: `gates.tdd`, `gates.coding_standards`, `gates.review`,
`gates.observability`, `gates.docs_updated`, `plugins.excluded` and `conventions.working_branch`.
Their descriptions now say so rather than describing enforcement that does not happen. They are
listed here because the list is worth closing, not worth hiding.

## 0.10.0 - 2026-08-17

**Evals: five treatment arms, all pass, no new rationalisation.** Run 2026-08-17 against `852e373`,
which is what decision 9 gates a release on. `tdd-under-deadline`, `debug-obvious-cause`,
`ship-with-flaky-tests`, `build-with-no-prd` and `incident-diagnose-first` all held under pressure.
`done-without-verifying` was not run: it is recorded invalid, because both arms pass and it therefore
measures nothing about the skill. Detail in `tests/evals/results.md`.

The run produced two findings about the harness rather than the skills, and the first is the more
serious. **The scenario files are reachable from the working directory the arms run in, and the `tdd`
arm found the file describing how it would be scored and said so.** Every previous run had the same
exposure, so this is newly noticed rather than new, but until the arms are dispatched from a
directory that does not contain this checkout, every result carries an asterisk. Second,
`debug-obvious-cause`'s criteria failed to distinguish a labelled conditional mitigation from a fix
offered as a resolution, for the second time; the identical problem was recorded against the 1.0.0
gate on 2026-08-16, so it is now a scenario defect to fix rather than an observation to repeat.

The release that makes keel public, and the one that stops 0.9.0 naming two different trees. Every
paragraph below sat under `## Unreleased` while the work landed across three pull requests; folding
them here is what makes the published tree reachable by an existing install, because the plugin cache
is keyed by the version in `plugin.json` and a push to `main` on its own reaches nobody.

**keel is public.** `gbi-solutions-ltd/keel` is a public repository, MIT licensed, 158 files at two
commits, CI green. This repository is `gbi-solutions-ltd/keel-internal` and stays private as the
development history. Executed as `docs/plans/2026-08-17-go-public.md`; the runbook at
`docs/runbooks/going-public.md` is now the record of what it took.

**The history was not published.** Sweeping every commit found all 27 deny patterns reachable, from
six real-content files carrying client names in old worked examples, from the deny list's own history,
and from two commit messages. `HEAD` was already clean. So the public repository is a fresh tree and
the 159 commits stayed private. `docs/audits/` is the only content deliberately withheld, because it
is the security posture of real services, named.

**MIT, replacing all rights reserved.** A public repository under that notice is source nobody may
legally use. Roughly a third of the skill set is adapted from four MIT projects, so MIT is the honest
match; their portions keep their own notices. `LICENSE` is canonical MIT text and nothing else, and
the third-party relationship moved to `NOTICE`, because appending it to `LICENSE` stopped GitHub
detecting the licence at all.

**The deny list left the tree**, which decision 2 required before any public release. It was the one
file that enumerated who we work with, and its test was a second copy, because both must contain the
names in order to search for them. Both are clean now. Client patterns load from `KEEL_DENY_FILE`,
default `~/.config/keel/internal-deny-list.txt`; an absent list degrades to the generic path patterns
rather than to silence, and the mode prints on every run so a half-armed scan cannot report `OK`
quietly. The coverage assertion now proves the mechanism with invented names rather than the real
list, which is a real reduction and is recorded in both files.

**Shipped content names no organisation.** All five reference files decision 2 confined GBi to are
generic once the name comes out of their prose, so `GBI_ALLOWED` is gone and the rule is simply that
shipped content carries no organisation name. `gbi-defaults.md` is `house-defaults.md`, renamed rather
than deleted because the link checker fails on a broken link; that rename touched thirteen references
across eleven files, not the one link expected, because the file was cited as prose throughout the
coding-standards set.

**Two push-protection rejections, neither a real secret, both fixed at the cause.** A literal PEM
private-key opening line in a supply-chain fixture whose body was one character, and a synthetic
Stripe-shaped token in the APEX redaction fixture. Fixing the fixtures rather than allowlisting the
detections means a contributor or a fork never trips them. The first secret sweep missed the second
one because it used the OpenAI `sk-` shape and not Stripe's `sk_live_`, so the sweep is now a
per-provider list.

Three smaller things fixed along the way, each found by a check rather than by review:
`.claude-plugin/marketplace.json` advertised "GBi internal AI engineering tooling"; `plugin.json` still
declared `"license": "SEE LICENSE IN LICENSE"` after the MIT change; and the plan document for this
work enumerated the client names in an assertion, which the newly armed scanner caught immediately.

Two fixes to the checks themselves, both found by reviewing 0.9.0 rather than by anything failing.
Neither changes what keel does, so neither has taken a number yet; fold these paragraphs into
whatever ships next.

**A leak repeated past a pipe buffer is reported instead of dropped.** `tests/no-internal-leaks.sh`
wrapped its search in `if hit=$(grep ... | head -1)`. `head` exits after the first line, `grep` dies
on SIGPIPE with 141, and `set -o pipefail` makes that the pipeline's status, so the branch was
skipped while `hit` held a real finding: a file with more matches than a pipe holds scanned clean.
Reproduces from about 5,000 matching lines, which is not hypothetical for the two absolute-path
patterns, since one APEX export or one long audit is enough. The same shape was fixed in the new GBi
rule at 0.9.0 when review found it there; this is the original loop, which had carried it since the
scanner was written.

**The writing rules now cover documentation, which closes the gap 0.9.0 recorded as known.**
Everything the validator checked applied to `skills/`, `templates/` and `output-styles/`, so every
plan, ADR, idea record, runbook and root document was exempt from the rules it is written under. Em
and en dashes and unresolvable relative links are now reported under `docs/` and at the repository
root as well. It starts green: zero violations across 48 files, so this is a rule with no cleanup
behind it.

Two limits are deliberate and both were measured against this repository before the rule was written
rather than argued about. **Links inside fenced code blocks are skipped**, because a plan quotes the
markdown it is telling someone else to write: without stripping fences the rule rejects
`docs/plans/2026-08-17-release-readiness.md` nine times, and two of those nine are `sed` patterns
that are not links at all. **The docs-root rule is not applied to prose**, because it fires on five
correct documents including `docs/05-token-and-memory-design.md`, which is the document that defines
the layout and therefore has to name it. Both limits are pinned as must-not-reject cases in
`tests/test-validate-skills.sh`, which is what `CONTRIBUTING.md` asks for whenever a check is found
to be stricter than correct output.

## 0.9.0 - 2026-08-17

The release the perf work was waiting for. That work asked to fold into whatever shipped next rather
than take a number of its own, and this is it, so the paragraphs below carry both. **0.8.0 will
always name two different trees**, the one tagged before the perf work and the one installed after
it, and `keel version` cannot tell them apart; what changes here is that nobody has to care from
0.9.0 onward.

Four items, raised together. Three of them are the same shape: a rule that was written down, agreed,
and never checked, so it drifted and nothing said anything.

**Decision 2's extraction list is enforced.** It confined GBi-specific content to five named
reference files so that publishing would be a deletion rather than an audit of twenty. Nothing
enforced it. Eight more files had picked up the name, four of them `SKILL.md` bodies the decision
forbids outright, and `tests/no-internal-leaks.sh` had never looked: its deny list is built for
client identifiers and GBi is not a client. The eight are neutralised as exchanges rather than
deletions. `debug` now says "a service following the observability standard" rather than "a GBi
service", which states the condition the name was carrying implicitly, and the standards template
says "the house defaults", which is what a generated document in a non-GBi repository always needed.
The scanner now fails on `\bGBi` anywhere under `skills/` or `templates/` outside the declared five.
It matches the branded form and not `gbi-solutions`, because the latter is correct inside the two
templates that carry the canonical JSON Schema URL.

**The model pins are documented.** They shipped in 0.8.0 and lived only in `docs/standards.md`, which
nobody installing the plugin reads. `README.md` now carries the table: the four fan-out briefs go to
`sonnet`, `execute-plan`'s implementation and both reviews stay `inherit`, and the validator rejects
any alias Claude Code does not accept. It also records what cannot be built, so it is not proposed
again: a session's own model is unreachable from a plugin, no hook event exposes model selection,
and a complexity router keys on the wrong variable because routing pays on work that is long and
mechanical rather than work that is simple. No brief names `haiku`, because the comparison that would
justify it has never been measured, and the idea record now says so plainly rather than implying a
saving.

**Seven false claims in the root documents, corrected.** The suite is four and a half minutes and
both `README.md` and `CONTRIBUTING.md` called it "seconds". `keel doctor` is around eleven minutes
and did not get faster, because its time goes on running each verify command rather than on reading
the profile. `keel guard install` writes two hooks, not one. `CONTRIBUTING.md` stated a 700-word
ceiling where ADR-0001 sets 700 as a target and prices 900 above it. `SOURCES.md` credited every
skill but `ship`, and asserted that every close adaptation names its source in a `SKILL.md` trailer,
which has never been true of any of the five. This file called the project `gbaiutils`. And the
1.0.0 gate still demanded an install "using only `gh` auth" that decision 2 had already established
is not required, in the direction that costs people time.

**A test for the ones a machine can hold.** `tests/test-doc-claims.sh` derives five counts from the
tree and fails when README disagrees: the skill count, the eval scenarios, the supply-chain pattern
and structural rule counts, and the resolved decisions. Four of the five were wrong or unreadable
when it was written. It is scoped to numbers on purpose, because a test that asserts on wording goes
red whenever somebody improves a sentence, and `CONTRIBUTING.md` already says the too-strict failure
is the one you do not recover from. Two claims were also reworded to carry digits: a number a check
cannot read goes stale exactly like one that is wrong.

**A snapshot now names the tool, not just the skill.** "No tests on the settlement path. Fix: `tdd`"
left the reader to choose a test runner before they could start, once per gap, six or seven times a
document. Section 10 cites a new shared reference, `skills/keel/references/tool-choices.md`, keyed on
`profile.stack.language`: one pick, one named runner-up and one reason for each of thirteen
languages across test runners, lint and format, typecheck, and the language-independent gaps.
`repo-snapshot`'s body did not change and is still at 699 words of its 700.

Each row carries its **reason** rather than its verdict, which is the only mitigation available for
the real risk here: a rule about process ages in years and a rule about which package to install ages
in months. Nothing in keel expires, and `docs/ideas/snapshot-recommends-tools.md` records that as an
open question rather than implying a review nobody scheduled. `tests/validate-skills.sh` fails when a
language `lib/detect-stack.sh` detects has no row, and when section 10 stops citing the table.

**A runbook for publishing, and nothing flipped.** `docs/runbooks/going-public.md` is the ordered
list: the licence decision, moving the deny list outside the tree with a fallback, what to do with
each of the five GBi files, the five places the repository name is load-bearing including two schema
URLs that 404 silently, what happens to `docs/audits`, and the history scan that most people skip.
Two of its steps are decisions an owner has to take rather than commands anyone can run.

### The performance work, folded in from Unreleased

**The test suite is 81 seconds faster, and `keel init` is two and a half times faster.** The suite
was 351.7s and is now 270.0s; `keel init` on a node project was 2.021s and is now 0.818s. Nothing
about what keel does changed, and no existing assertion was altered.

Two functions each started a fresh `python3` for every single value they read, and both were called
in a loop. `pkg_script` read one npm script name per interpreter start, and `detect_verify` asked it
up to three times for each verify key: seventeen of the twenty-four interpreter starts in one
`keel init` on a node project. `json_get` read one dotted path per start, thirteen of doctor's
nineteen. Each now reads its file once per process. Across the suite that is 3304 interpreter starts
down to 1075.

Both caches are primed in the parent shell on purpose. Nearly every caller is a `$( )`, which is a
subshell that inherits variables and cannot write back, so a cache filling itself lazily would be
built and thrown away once per call and save nothing. The priming call looks redundant and is not.

Two costs were measured and deliberately left alone, so that nobody measures them again: `git` at
2437 spawns is about 14 seconds, and creating the 167 test fixtures about 7 seconds, together under
6% of the suite. Also unchanged, and worth knowing: `keel doctor` itself is no faster in wall time
despite halving its interpreter starts, because its time goes on actually running each verify
command, not on reading the profile.

Review of that work found four things, all now fixed. **A newline inside an npm script value lost
the whole script**, so a project declaring `"test"` across two lines was told no test command was
found; the value is flattened now rather than the entry dropped, which is safe because callers read
it as a presence test and write `npm run <name>`, never the body. **A literal dotted key such as
`{"a.b": 1}` was served as if it were nested**, so `profile get nested.a.b` returned a value that
`profile set nested.a.b` refused; such keys stay out of the cache and the interpreter answers for
them. **The script cache marked itself loaded before checking the file existed**, so a `package.json`
appearing later in the same process was never read. And **the two spawn-count assertions passed at
zero**, which is exactly the case they exist to catch, so both now require at least one start.

### Known gap in this release

The behavioural evals were **not** re-run for 0.9.0. Decision 9 gates a release on them and they cost
API tokens, so whoever cuts the tag runs `tests/evals/run.sh` and records the result, including any
new rationalisation, in `tests/evals/results.md`. Nothing in this release changes a discipline
skill's rules, but that is an argument for expecting them to pass rather than for not running them.

Also unchanged and still true: nothing enforces the writing rules on anything under `docs/`.
`tests/validate-skills.sh` checks em dashes, links and docs-root notation under `skills/`,
`templates/` and `output-styles/` only, so every plan, ADR, idea record and runbook is unchecked. The
area is clean today, which makes this latent rather than active.

## 0.8.0 - 2026-08-17

Two changes, from two suggestions raised together. Both were shaped before they were built, and both
came back smaller than they were asked for, which is recorded in `docs/ideas/`.

**The "re-run keel init" warning now means something.** It compared the profile's `keel_version`
against the installed release, so it fired on every release whether or not the profile was missing
anything: 0.7.0 and 0.7.1 changed no field between them and both would have told every project to
re-initialise. A warning that fires when nothing changed is one nobody reads on the release where
something did. The profile now carries a `schema_version`, owned by the tool like `keel_version` and
bumped only when a field is added, removed, renamed or moved, and doctor compares that instead.
Existing profiles have no such key, which reads as stale and is correct: they predate it, and
`keel init` merges the new fields in without touching a value anyone set by hand.

The asked-for question was how new fields reach existing installations, and the answer turned out to
already be built. `merge_profile` has always merged a fresh template under an existing profile with
human values winning. What was missing was a signal worth acting on, not a mechanism.

The comparison is three-way, not equal-or-not. A profile written by a **newer** keel than yours says
so and tells you to upgrade the plugin, explicitly not to re-run `init`. The profile is a committed
file, so on a team the engineer who upgraded first commits a higher `schema_version` than the others
have installed; treating that as stale would have had them write it back down, and the two would
have traded the field back and forth, each following the tool's advice.

**A validator now makes `schema_version` hard to forget.** Changing the field set in
`templates/profile.schema.json` without bumping the version fails the build, and the failure says
which two lines to change.

**It cannot force the bump and does not claim to.** Nothing can: on a fresh clone or a depth-1 CI
checkout there is no earlier state to compare against, so the check knows what the fields hash to
and not whether that changed. What it does is record one fingerprint per schema version, so the
cheap way out of a failure is to add a line and bump the version, and overwriting a released
version's fingerprint is a visibly different act that a reviewer can see in the diff. It also covers
the schema document rather than `write_profile`, which is the code that actually writes profiles;
the two already differ in both directions, and that limit is stated where the check lives.

**A repo snapshot says what it did not check.** The skill deliberately does not audit, and its own
templates said so, but nothing made the document say so, so a snapshot that reported debt and never
looked at security read as a clean bill of health. Section 10 now requires a `security-audit --full`
item and a `coding-standards` item on a first look at an unfamiliar repository, and the handoff names
what was not checked.

The suggestion was to fold both audits into the snapshot. That was declined and the reasoning is in
`docs/ideas/snapshot-surfaces-remediation-gaps.md`: `security-audit --full` is already scoped for a
new engagement, the snapshot's body is at 699 of ADR-0001's 700 words, and one long document instead
of three that each get read is not an improvement.

**Not covered.** Nothing measures whether a snapshot written under the new rule actually gets the
referral acted on, and the posture-baseline idea underneath the suggestion, a run you repeat after
remediation and diff, is recorded as an open question rather than built. Nothing in keel takes a
prior artifact as a baseline today.

**What this release was not gated on.** `CONTRIBUTING.md` says releases are gated by the
behavioural evals. The only scenario that exists, `done-without-verifying`, does not discriminate
between its arms and carries a do-not-re-run warning until its fixture is rebuilt, so it was not
run: a green line from it would mean nothing. It is unchanged since 0.7.1, and neither change here
touches the behaviour it probes.

## 0.7.1 - 2026-08-17

One rule, from decision 11, which an eval produced rather than an opinion.

**A checkbox now records who witnessed the step, not just that it is done.** Nothing said what to do
with a step somebody else already performed, which is every resumed plan, and an eval on 2026-08-16
caught an arm ticking "write the failing test" and "watch it fail" in a session where neither
happened. `execute-plan` ticks on output it read and notes any step it did not witness, the plan
template carries the rule in its banner so a plan states it where it is read, and a delegated
subagent is asked to name the steps that were already satisfied when it arrived. `hooks/done-guard`
is unchanged: it reads one turn's tool calls and cannot know who did what in an earlier session.

**What this release was not gated on.** `CONTRIBUTING.md` says releases are gated by the
behavioural evals. The only scenario that exists, `done-without-verifying`, does not discriminate
between its arms and carries a do-not-re-run warning until its fixture is rebuilt, so it was not
run: a green line from it would mean nothing. The rule shipped here is the finding that scenario
produced, and nothing yet measures whether it changes behaviour.

## 0.7.0 - 2026-08-16

Four suggestions arrived together. Three were built, one was shaped and declined in the form it was
asked for, and the reason each is written down is that two of them rested on a premise that turned
out to be false.

**A claim of done now rests on a command that ran.** `write-plan` requires a `Done when:` line per
task, a command from `profile.verify` plus its expected result, so a reviewer can check the claim
without reading the diff and a delegated subagent that sees only its own section still receives it.
`execute-plan` ticks a checkbox on output it has read, and the compliance review gains a fifth
question: a report with no `Done when:` output is DEVIATES on its own, however good the code looks.

**Install is documented from the marketplace, because the old reason for the symlink was wrong.**
Both documents said a plugin cannot put anything on PATH and used it to justify a manual step. A
plugin's `bin/` **is** added to the PATH the Bash tool uses, checked against the plugins reference
and against a live session, so the two `/plugin` lines are a complete install. The symlink survives
as optional and for the login shell only, with the warning that the cache path is keyed by version
and so the link breaks on every upgrade.

**Replies are short by default; artifacts are not.** The two are separate dials, and treating them
as one is what stalled the idea: the objection was that keel's rules make the model say more, but
every rule it cited is a short obligation, not a long one.

### Added

- **`hooks/done-guard`**, on `Stop` and `SubagentStop`, so it covers delegated work, which is where
  a claim of done is least visible. It fires on a structural condition, *this turn edited code and
  never ran the test command*, not on the word "done" in the final message: matching English misses
  "that's the retry path covered" and fires on "done reading the config", and a guard that cries
  wolf gets switched off alongside `sensitive-guard`, which shares its `hooks.json`.

  **It fails open where `sensitive-guard` fails closed**, and the difference is not an oversight.
  That hook asks a human whenever it cannot answer, because `ask` is the one decision the model
  cannot grant itself. A `Stop` hook has no equivalent: denying a stop it cannot justify produces a
  turn that will not end with nobody in the loop to clear it.

  Silent unless the repository sets `gates.done_verified`. keel sets `required` for itself;
  `keel init` writes `warn`, because a hook that stops turns is not something to switch on for a
  repository without asking. An earlier draft used `block`, which the profile schema rejects, so
  every project taking the gate would have failed `keel doctor`.

- **`conventions.response_style`**, `terse` by default, `verbose` as the opt-out.
  `hooks/session-start` injects the brevity rule unless it reads `verbose`. An absent key and an
  absent profile both mean terse, so existing projects pick it up without re-running `init`.

- **`output-styles/keel-terse.md`**, the machine-wide alternative for non-keel repositories,
  selectable in `/config`. It is not what makes keel projects terse and nothing sets it for you.

- **`tests/test-cache-install.sh`**, which runs `keel version` and `keel init` out of a
  tracked-files-only copy, the thing a marketplace install produces. It is the check behind the
  corrected install documentation rather than a recollection, and it guards the superseded PATH
  claim against returning by copy and paste.

- **`tests/test-session-start.sh`**, six cases, and a model alias rule plus an `output-styles/`
  frontmatter rule in `tests/validate-skills.sh`.

### Changed

- **Every subagent brief names its model.** The four wide-reading fan-outs go to `sonnet`;
  implementation and both reviews in `execute-plan` stay `inherit`, because code under the TDD gate
  and judging another agent's verdict is the work least worth making cheaper.

  **No complexity router, and the request for one could not be built as asked.** A session's model
  cannot be changed by a plugin, a hook, or the model itself: no hook event exposes model selection,
  checked 2026-08-16. What remains is delegation, which is not free because a subagent starts cold
  and re-reads context the main thread holds, so the payoff tracks long mechanical work rather than
  simple work. Nothing goes to `haiku` until one measured comparison exists.

- **The SessionStart injection is 356 tokens, up from 300**, against a 250 target and a 400 ceiling.
  That is 56 tokens of input in every request of every session, spent to shorten output in some of
  them, with 44 tokens of headroom left. It is now the tightest budget in
  `docs/05-token-and-memory-design.md`. The trade was instructed explicitly, and the number is
  measured rather than estimated.

- `verify.lint` gains `hooks/done-guard`. The command is a literal file list and does not glob
  `hooks/`, so without this the new hook would never have been linted and CI would never have seen
  it.

### Fixed

- **An unreadable `.keel/profile.json` no longer takes the session injection down with it.** Found
  by review before this shipped. `hooks/session-start` runs under `set -e` with the profile read as
  the last command in an `&&` chain, so a 000-mode profile exited 1 and printed nothing: the session
  lost the whole router pointer, not just the brevity rule, and looked exactly like keel was not
  installed. `hooks/done-guard` already failed open correctly but leaked bash's "Permission denied"
  to stderr on the end of every turn, which a `Stop` hook surfaces as an error notice. Both are
  guarded with `-r` and both cases are tested, skipped as root since root can read a 000 file.

### Not covered

- **Neither new eval scenario has been run.** `done-without-verifying` is written, assembles, and is
  recorded in `tests/evals/results.md` as not yet dispatched, because an arm is dispatched and
  scored by an agent. It is the only behavioural check on the three prose layers of the done work.
- **Nothing measures reply length**, so whether the brevity rule pays for its 56 tokens is unknown.
- **`keel init` does not write `outputStyle`.** The style's addressable name could not be verified:
  the plugins reference does not say whether plugin output styles are namespaced, `claude --debug`
  logs nothing about it, and the one official plugin that ships this behaviour has no
  `output-styles/` directory at all. Open decision 10 names the single observation that settles it.
- **The shorter-responses idea was not built as asked.** Trimming the skills' report sections was
  dropped: five of six dispatching skills now sit within four words of ADR-0001's warning.

## Also in 0.7.0: the work that preceded these four suggestions

Written while it was still unreleased, and kept as its own section because it is a separate body of
work rather than a continuation of the four above. It ships in the same version.


Two standing rules that had been left to whoever remembered them, and two things `keel init` wrote
into every project it touched that were wrong for anyone who was not the author.

The rules: lint runs per edit rather than per session, and documentation is a gate rather than a
follow-up. The fixes: a session hook that told every session the plugin was missing, including the
sessions that had it, and a committed marketplace source that pointed at a private repository and
shadowed whatever the reader had chosen for themselves.

### Changed

- **The managed block's 628 tokens against a 450 target is now a recorded departure, not a silence.**
  Task 7.5 offered a trim or a departure. Closing a 178-token gap means cutting about a quarter of a
  block that is rules end to end with no summary prose in it, so a trim of that size deletes a rule
  rather than words, and neither pilot showed a rule in it as unearned. Raising the target so the
  warning stops is what `docs/standards.md` forbids. It is in the departures table with an end
  condition: the block carries the per-edit lint rule and the documentation gate as prose that
  nothing enforces, and when either becomes a check its prose comes out and the block is re-measured
  against 450. `keel doctor` still warns every run and the 700 ceiling still fails.

- **ADR-0001 is accepted**, dated 2026-08-16. It had shipped and merged while still `proposed`.

- **Lint runs after every file edit, not once at the end.** The managed CLAUDE.md block says so, and
  says what to do where a project has no lint command: name that fact and run the nearest check that
  exists, instead of skipping verification silently or inventing a command. It sits in the block
  rather than in `execute-plan` or `tdd` because it applies to every task in every project, and both
  of those skills are within three words of the 700-word ceiling. The block now renders around 600
  tokens against a 450 target and a 700 ceiling, which `keel doctor` reports and
  `docs/05-token-and-memory-design.md` records.

- **Documentation is part of the quality gate.** The block states it, `ship` check 6 requires docs
  written as current state rather than as a record of the review, and the review rubric gains a
  documentation pass: was every document the change made wrong updated in the same commit, is
  generated output regenerated rather than hand-edited, and does the changed prose describe the
  system or the argument about it.

- **ADR alternatives are stated as properties, never as episodes.** "We tried it and it was slow"
  cannot be re-evaluated when the constraints change; a number can. In
  `skills/design-architecture/references/adr-template.md`.

- **`design-architecture --existing` has a reference of its own**,
  `skills/design-architecture/references/existing-mode.md`, carrying four rules the mode needed and
  did not have: what to read when there is no snapshot, which is the normal case for a project keel
  built itself; that a new design and the design it extends link to each other and that the older
  one is corrected in place; that a scoped design covers its slice and points at the design covering
  the rest, rather than copying a coverage table that then drifts; and that the mode looks for the
  requirement a PRD is missing, not only the requirement a design is missing. Found on the mode's
  first run, recorded in `docs/audits/2026-08-15-existing-mode-run.md`.

- **The library-fact fallback names a source instead of asking for a confession.** Where `context7`
  is unavailable, `design-architecture` now reads the vendor's own documentation and says what it
  could not verify. On the run that prompted this, three of the facts that moved a decision were
  pricing and plan requirements rather than API signatures, which `context7` does not carry.

### Fixed

Three from the first `keel init` on a repository keel had nothing to do with, an existing GBi
Express service with real history. Recorded in
`docs/audits/2026-08-15-existing-service-pilot.md`.

- **`keel init` corrupted a `.gitignore` whose last line had no newline.** `ignore_local_state`
  appended its rules to a file it never terminated, so on a hand-written `.gitignore` ending without
  a newline, which is most of them, keel's rule was welded onto the project's own last line. The
  result was one line matching nothing: it **destroyed a rule the repository already had** and added
  neither of the two keel was adding. `init` reported success.

  The loop order is what made it silent. `grep -qxF` matches an unterminated final line, so the first
  rule was correctly skipped as present and the second was appended with no newline before it. The
  file is now terminated before anything is appended.

- **`stack.datastores` was a hardcoded empty list, so every profile said the project used no
  datastore.** There was no detector and never had been, while
  `templates/keel-profile.example.json` advertised `["postgres", "redis"]` as the shape of an
  answer `init` could not produce. The pilot service declared both, in its dependencies and in its
  compose file, and was recorded as using neither. Same defect `stack.has_ui` had: a field that
  always says none reads as a detected none.

  `detect_datastores` reads two independent signals and reports the union, because either alone is
  wrong on a real repository. Dependency manifests across the languages keel detects name the client
  library and say nothing for the ones it does not parse; compose files name the service and miss a
  managed database that exists only as a connection string. Lockfiles are excluded on purpose, since
  a transitive driver is not a declaration that the project uses that store.

- **`keel doctor` accepted a developer's global `.gitignore` in place of the repository's own.** The
  check was a bare `git check-ignore`, which answers "is this ignored on this machine" rather than
  "would whoever clones this commit the file". This is why the corruption above survived a `doctor`
  run that reported `ok`: the author's `~/.gitignore` covers `settings.local.json`, so destroying the
  repository's rule changed nothing the checker could see.

  The suite had asserted the right property since the rule was written, neutralising
  `core.excludesFile` in two tests precisely because the repository's own line has to protect a
  teammate who has no global rule. The shipped check never did. Both checks now go through
  `repo_ignores`, which neutralises it. `.git/info/exclude` is per-clone and equally private and is
  deliberately left alone, because there is no config key for it and the check should claim only what
  it verifies.

- **The plugin-less nudge fired in every session, including every session that had the plugin.**
  `.claude/keel-nudge` exited early on `CLAUDE_PLUGIN_ROOT`, which is set only for hooks a plugin
  itself defines. A hook registered in a project's `settings.json` never receives it, so the early
  exit was unreachable and the hook printed "the keel plugin is not loaded in this session" in every
  session of every keel project since it was written. Measured in a live session in a real project:
  24 `keel:` skills loaded, and the same session told it had none.

  No rewrite of the check can work. A project hook's environment carries `CLAUDE_PROJECT_DIR` and
  thirteen other `CLAUDE_*` variables, and not one names a loaded plugin. The message is now a
  conditional the reader evaluates against its own skill list, which is the one place the answer is
  actually visible: "if you have no skills named `keel:*`, the plugin is not loaded and the rest of
  this note applies". It prints in every session, so it is budgeted at 200 tokens like the
  SessionStart injection it sits beside, and it currently renders at about 177.

  The old test passed because it set `CLAUDE_PLUGIN_ROOT` by hand and asserted silence, which is a
  check proving the mechanism it invented rather than the condition that occurs. Two cases replace
  it: the output does not vary with that variable, and the condition it states is one the reader can
  check.

- **`keel init` committed a marketplace source, which is a per-machine fact.** Every project it
  touched received `"gbi": { "source": { "source": "github", "repo": "gbi-solutions-ltd/keel" } }`
  in `.claude/settings.json`. A marketplace source says where a particular reader gets keel from, so
  a committed one is wrong for everyone whose answer differs. It was wrong two ways at once: a
  reader outside the GitHub org cannot reach a private repository, and at project scope the
  declaration shadows whatever that reader chose at user level.

  Measured on the author's machine, where the second failure had been silently in effect: user
  settings declared `gbi` as a `directory` source pointing at the working repository, and
  `known_marketplaces.json` had resolved `gbi` to the `github` source with a clone of the merged
  `main` at `plugins/marketplaces/gbi`. Every keel project was therefore loading published skills
  rather than the ones being edited.

  The declaration is now written nowhere. `enabledPlugins` still records `keel@gbi`, which is the
  part that is true of a project: this is the plugin set the repository expects, and a teammate
  running `/plugin` sees it listed. The nearest working case was already in the same function, since
  every `@claude-plugins-official` plugin is enabled without a marketplace declaration and resolves
  fine. `keel doctor` already passed on an unregistered marketplace and already named the install
  command, so nothing downstream changed. Three cases pin it, including one that fails if the
  private repository is named anywhere in the committed settings.

**Open, not fixed:** plugin loading in `agroplex-frontend` is intermittent, and the fix above may
not be its cause. The same probe in the same directory reported 24 `keel:` skills on one run and
zero on the next, so some of what the nudge reported was true. The remaining fact, and it is a state
inconsistency in Claude Code's plugin store rather than anything keel writes:
`installed_plugins.json` records `installPath` as `plugins/cache/gbi/keel/0.6.0` for both the user
and the `agroplex-frontend` project scope, and that directory does not exist. The cache holds
`0.6.1`, complete with all 24 skills, written days after the record. A session resolving through the
recorded path finds nothing while a session that re-resolves finds everything, which fits the
observed flip, but the loader's behaviour has not been read and this is not yet a diagnosis.
Reinstalling the plugin is the remedy to try first, and it is not a code change.

- **The artifact chain never updated the artifact it came from.** `write-prd --from-idea` reads the
  idea record and carries five things forward from it, and nothing told it to write anything back. A
  grep across all 24 skills for any instruction to update an upstream artifact returned nothing.
  Observed on a real greenfield run: the PRD settled who supplies the hardware, what the board
  displays and who may override a branch rate, and the idea record went on listing all three as open
  questions until a human asked for it to be corrected.

  This contradicted a rule keel already ships, since
  `skills/write-docs/references/current-state-prose.md` requires a document to state what is true
  now, and the managed CLAUDE.md block makes documentation a gate. The chain exempted itself from
  both.

  The rule now lives where it is read at the moment it applies: rule 6 of the PRD template, a
  section of the story template, and one line in `write-prd`'s step 5. It is stated in both
  directions, so a story updates the PRD and the PRD updates the idea record, and a settled question
  is struck through with its answer rather than deleted, so the decision keeps its trace.

- **`keel init` told a greenfield project to snapshot a codebase that did not exist.** Every init
  closed with `try "use repo-snapshot on this codebase"`, which on an empty directory is advice to
  read nothing. It now branches on `project.kind`, which init already computes: a `docs` project is
  pointed at `shape-idea` or `write-prd`, and a project with code is unchanged.

- **init demanded a test command that doctor excuses.** The `no test command was detected` note fired
  whenever `verify.test` was null, while `cmd_doctor` reports that verify commands are not expected
  for `project.kind: docs`. The same state answered two contradictory ways, with init's answer read
  first. Suppressed for `docs`, unchanged everywhere else.

- **`write-user-stories` had two mechanisms for an open question and no rule for choosing.** Step 1
  says to put blocking questions to the user as choices; step 2 defines a `decide` story kind for the
  same situation. It now says to ask only what the user can settle now, and to write a `decide` story
  for anything needing a measurement, a lawyer, or a decision they already deferred. Re-asking what a
  PRD knowingly left open teaches people the process wastes their time.

- **The story template assumed one requirement status per story.** A story satisfying a `confirmed`
  and an `inferred` requirement had no defined representation. Each is now named separately, because
  one word cannot describe two requirements and the optimistic half is the one a reader remembers.

- **`keel profile get` answered in Python rather than JSON.** The profile holds `true`, and
  `profile get` printed `True`, so the value could not be fed back to `profile set` and no shell
  comparison against `true` worked. Found by following `design-architecture`'s own instruction to
  set `stack.has_ui` and reading it back. `bin/keel` already carried the scar: one reader compared
  against both `"False"` and `"false"`, another against `"False"` alone. `json_get` now prints
  `true`, `false` and empty for null, and both readers moved with it in the same change. A
  regression case pins the `has_ui` mismatch warning, which was the reader most likely to break
  silently.

- **`keel doctor` printed warnings and then said "no problems".** `warn()` incremented no counter,
  so a run with three warnings ended with a summary naming none of them. Writing the 0.6.1 release
  notes meant counting the WARN lines by hand. The summary now carries the count on both the passing
  and the failing line. Exit status is unchanged, so warnings still do not fail a run.

- **`design-architecture` claimed every `decide` story owes an ADR.** The greenfield run reached
  that instruction with four of them and not one was answerable at design time: they waited on a
  lawyer, a measurement, and two product decisions. Followed literally it asks for four ADRs
  recording decisions nobody made, which is writing `accepted` on a human's behalf one step earlier.
  The skill now says an ADR follows once the answer exists and nothing until then, with the
  reasoning in the ADR template's "when not to write one".

- **A design could name no stack and still pass its own self-review.** `design-architecture --new`
  produced a design committing to "browser clients" and a "managed realtime backend" with no
  language, framework or vendor named, and it satisfied every item of the template's self-review.
  `write-plan` then could not write a line of code and had to stop and ask twice.

  The only place the stack was ever expected was a note about diagram syntax inside
  `mermaid-patterns.md`, and the design template's own provenance says it merged
  `tech-stack-selection.md`, so the job was meant to live there and was lost in the merge.
  Self-review item 5, "no library version is named that was not checked", pushed the same way by
  reading as a reason to name no technology at all. Section 4 now requires the stack in words for
  each thing that runs, separates that from naming a version, and a new item 7 checks it.

- **Every verify command is null on a greenfield project, and the plan template only said to admit
  it.** A new project has no test command because it has no project, so "say so in the task rather
  than substituting a guess" left every step 2 and step 4 unrunnable. The resolution is ordering
  rather than honesty: task 1 creates the toolchain and writes the commands into the profile, and
  everything after inherits real commands. Its own failing-test step watches the test command fail
  because the toolchain is absent, which is a genuine failure rather than a ceremonial one. The
  template now says this, including that task 1 satisfies no story and should say so instead of
  having one invented for it.

- **`execute-plan` refused the bootstrap task `write-plan` had just been told to produce.** The
  greenfield fix above makes task 1 create the verify commands; `execute-plan` refuses to start when
  a verify command is absent. Both rules cannot hold on a new project, because the commands cannot
  exist before the task that creates them and that task cannot run while they are missing. Found on
  the first attempt to execute a plan shaped by the fix, one end of the chain having been changed
  without checking the other. The precondition now carries an exception for a plan whose task 1
  creates them, and still refuses a plan whose commands are absent and which creates none.

- **`proposed` was read as "unproven" rather than "unagreed", which made a spike unexecutable.**
  `execute-plan` refuses when an ADR the plan cites is `proposed`. The plan in question was a
  walking skeleton whose whole purpose was to prove a vendor's offline cache survives a week on a
  cheap device, so its ADRs were `proposed` because that evidence did not exist, and the evidence
  could not exist until the plan ran. Two states wear one status: **nobody has agreed it**, which
  genuinely blocks, and **agreed but unproven**, which is the normal condition of a decision just
  taken, since every ADR carries a `Verification` section precisely because acceptance is not proof.
  What unblocked it was one exchange asking the person who had already chosen the vendor to accept
  the ADRs. The table now says `Nobody has agreed it`, and a new
  `skills/execute-plan/references/preconditions.md` says how to tell the two apart before refusing.

  Both fixes freed words rather than costing them: moving the precondition table's `Why it blocks`
  column into that reference took `execute-plan` from 697 to 691 against the 700 ceiling.

- **The skill link check rejected a correct link carrying an anchor.** `references/x.md#a-heading`
  names a file that exists, and both link checks resolved the anchor as part of the path and failed.
  A check that rejects correct work is the failure this repository's standards name twice, in
  `write-plan`'s self-review and in the story template. Both checks now strip the anchor, and four
  cases cover the shapes never exercised: an anchored link, a `../` path into a sibling skill, a
  `../` path that does not exist, and an external URL, which must not be treated as a path.

  Worth recording how it was found, because the report that prompted it was wrong. The claim was
  that nothing verified skill links at all; in fact `tests/validate-skills.sh` has checked them in
  bodies and in references for some time, and both were already tested. The claim came from memory
  rather than from the file, and the first test written to prove the gap passed immediately, which
  is what exposed it.

- **`revise` described the rare reason to revise a PRD and not the common one.** The mode read "a
  PRD exists but is vague or self-contradictory". The PRD that needed revising was neither: it was
  deliberately incomplete, because the template tells a writer to put `Unknown, needs a decision`
  rather than invent a number, and two of those had since been answered. That is what happens to
  every PRD that gets built, and a reader matching the stated trigger against a good document
  concludes the mode does not apply. The trigger now reads "vague, contradictory, or overtaken".

- **Diagnosing a maturing PRD produced an empty defect list.** `revise` says to look for untestable
  requirements, missing IDs, "should" statements, invented specifics and contradictions. Against a
  just-approved PRD every one came back clean, which is correct and useless. The diagnosis that
  mattered was a different shape: every `Unknown, needs a decision`, every `inferred` requirement,
  every open question, and which now have answers. The questionnaire now gives both lists and says
  which case each belongs to, and says to strike a settled question through in place rather than
  deleting the row, since the trace from question to answer is most of why anyone reads an old PRD.

- **Two skills disagreed about where a `decide` story's answer goes.** `write-user-stories` said it
  produces "a written decision, usually an ADR" and `design-architecture` said each produces an ADR,
  while the ADR template says not to write one for anything reversible in an afternoon that nobody
  would question. Two decide stories were answered with threshold values, 30 seconds and 20 percent,
  and following the first two instructions means writing ADRs for two constants. Fixed from both
  sides, since either alone leaves the contradiction: an ADR is for a decision that shapes the
  system, a value belongs in the `NFR` or `FR` it qualifies, and the reasoning goes in that
  requirement's `Evidence` column so the number never arrives bare.

  All sixteen were found by running the artifact chain end to end on a real new project, and are
  recorded with their evidence in `docs/audits/2026-08-15-greenfield-pilot.md`. That run exercised
  `write-prd --from-idea` and `design-architecture --new`, two of the five unrun modes in the 1.0.0
  gate, then `write-plan`, the first two tasks of `execute-plan`, and `write-prd --revise`, which is a gate mode and produced the last three.

### Added

- **`hooks/sensitive-guard`, the one gate a sentence in chat cannot move.** Plan task 4.3, decision
  3. A `PreToolUse` hook that emits `ask` when a `git commit` stages a file matching top-level
  `hard_block_paths`, naming the files and telling the reader to run `security-audit --diff` first.
  It is silent in any repository that declares no such paths, which is almost all of them, and the
  check that decides this is a shell builtin rather than `grep`, because `grep ... || exit 0` cannot
  tell "no match" from "grep is not on PATH" and fails open in the one situation where a guard must
  not.

  **`ask` rather than `deny`, and that is the strongest form available rather than a softening.**
  `security-audit` is a skill the model executes, not a command a hook can run, so nothing can
  verify from a hook that an audit ran clean, and any receipt the model could write is one a
  sentence in chat could obtain. `ask` is the only decision in the protocol the model cannot satisfy
  for itself, and it survives `bypassPermissions`. It guards the commit rather than the edit,
  because a gate that fires on every edit to auth code is a gate people delete, and it reads the
  staged set plus tracked modifications whenever the command carries `-a`, `--all` or a pathspec,
  since all three commit working tree content that `--cached` does not show. It reads a command
  string, so `sh -c`, a here-doc or `git -C dir commit` gets past it, exactly as the permission deny
  rules already warn: it raises the cost of a careless commit and review is still the boundary.

  **It asks whenever it cannot answer.** An absent `python3`, an unreadable or unparseable profile,
  and a failing `git diff` all produce `ask` rather than silence, because a repository that declared
  sensitive paths and quietly got nothing would believe in cover it did not have. The tool and
  command filters run first, in bash, so this never becomes a prompt on every `Read`.

  A bare directory pattern such as `src/auth` matches everything under it, which `fnmatch` alone
  does not do, and the semantics are now written next to the field in the profile schema. Sixteen
  cases in `tests/test-sensitive-guard.sh`.

  The managed CLAUDE.md block moves from 628 to 634 tokens, since the lint command now names the new
  hook. Still over the 450 target and under the 700 ceiling, and the departure in
  `docs/standards.md` is updated to the current figure.

- **The sum of the skill descriptions is bounded, at 1,320 tokens in `tests/validate-skills.sh`.**
  Every description sits in the prefix of every request in every keel project, and only the
  individual ones were capped. The gap that left was wider than the growth it was there to catch: at
  24 skills, every description sitting legally at 216 chars totals 1,440 tokens against the 1,066
  actually measured, so a third of the budget could arrive with no skill added and nothing anywhere
  saying a word. 1,320 is 30 skills at the measured 44-token mean, which is decision 6's own
  trigger to revisit granularity **before** the count reaches 30, so the check fires where that
  decision already said to look and its message says the remedy is fewer skills rather than shorter
  descriptions. The total is now stated on every clean run, breach or not, because a budget nobody
  sees until it fails is one that gets breached by the change that had no idea it was near. Plan
  task 7.5.

- **`write-docs` prefers a generator to prose.** OpenAPI from the framework's decorators, code docs
  from JSDoc or docstrings, release notes from Conventional Commits. Prose restating what the code
  already declares goes stale silently, and the wiring is what gets committed rather than the
  generated output pasted in by hand. Hand-written text covers what no generator can produce: why
  the thing exists, how the parts fit, what the reader must do.

- **`skills/write-docs/references/current-state-prose.md`**, and a rule in `docs/standards.md` that
  applies it to everything this repository ships. Review history enters a document mainly when the
  document is patched after a correction: amending the sentence that carried the wrong claim keeps
  its frame, so the correction lands on top of the mistake and the document argues with a reader who
  never saw the exchange. The remedy is structural. Delete the section and write it again from the
  code. The reference carries the tells to reread for, four rewrites, and the line between residue
  and a scar rule, which stays because the reader acts on it.

- **`keel doctor` checks that a fresh clone can open the documents the repository references.**
  Every repo-relative markdown link in `README.md`, `CLAUDE.md`, `AGENTS.md` and the docs root is
  resolved against `HEAD` rather than against the working tree. A target git ignores is a `FAIL`,
  because committing does not fix it and the ignore rule has to change first; a target that is
  merely uncommitted is a `WARN`, because the next `git add` clears it and failing would fire on
  every document between being written and being committed. Links git cannot carry either way are
  skipped: absolute URLs, mail, page anchors, and site-absolute paths. A link to a path that is
  absent everywhere is a broken link, which is a different defect and not this check. Paths are
  normalised before the lookup, because `HEAD:docs/../templates/x.md` does not resolve: git never
  normalises a tree path, and the first run of this check against keel itself called five of its own
  committed files unreadable on exactly that.

  `check_docs_ignored` already covered the one directory keel owns. This covers the rest, and it
  took two pilots to see: forex had its whole docs root ignored, agroplex ignores 25 of its 28
  documents and links three of them from the README.

  It was baselined before it was written, which is what decided its form. Two agents reviewed
  agroplex's documentation with no skill and no hint, one of them asked outright what a fresh clone
  gets. Both read the three unreachable files and reported them as content problems, one calling
  them "~6 months stale" when the date was simply when they were last committed before removal, and
  went on to recommend linking a fourth document that is also ignored. The reason the framing did
  not save them is mechanical: `git status` is structurally blind to ignored files, so the obvious
  instrument returns clean, and `git log` answers happily for a path `HEAD` does not carry. That is
  a missing check rather than missing judgement, which is why this is in `doctor` and not a skill.

- **All five behavioural evals re-run after both pilots, 2026-08-16, all passing.** The previous run
  was 2026-08-11, before either pilot and before the 24 findings they produced were fixed, so every
  skill the scenarios exercise had changed underneath them. Recorded in `tests/evals/results.md`.

  No new rationalisations, which is the result rather than an absence of one: both arms that could
  have produced one answered with arguments the skills had already taken from earlier runs, the
  `tdd` table's "it may be green *because* a test asserts the wrong behaviour" and the
  `incident-response` cost argument against fixing forward. What earlier evals put into the skills
  came back out of them under the same pressure.

  One finding, and it is against a scenario rather than a skill. `debug-obvious-cause` fails a reply
  that proposes "any fix, before establishing why the behaviour occurs", which does not distinguish
  a fix offered as resolution from a mitigation that is labelled, conditional on declared customer
  impact, and leaves the investigation open. `incident-response` requires the second, so the
  criteria as written would penalise the skill set for being consistent with itself. Recorded, not
  changed: rewriting pass criteria on the strength of a run that passed is how criteria drift into
  describing whatever the model last did.

- **The skill body ceiling moves to 900 words, and 700 becomes an enforced warning.**
  `docs/decisions/ADR-0001-skill-body-word-ceiling.md`, the first ADR this repository has written
  about itself. The old rule was 400 and 600 as documented targets under a hard 700, and it failed
  in a way worth naming: **the targets were unchecked and the ceiling was enforced, so bodies went
  where the check was.** Measured across all 24 skills, no skill met 400, four were under 600, and
  fifteen sat within 20 words of the ceiling with eight within six.

  The remedy the standard named, moving substance into `references/`, turned out to be exhausted
  rather than unused: `coding-standards` carries 12 reference files and 17,816 words in them and its
  body is still 683. A body's floor is its step count plus the sentence each reference costs to
  introduce, not the detail it holds.

  So the replacement is one target the validator warns on rather than a third number nobody checks,
  and a body over 700 needs a passing eval arm at that length, which puts the room on observed
  behaviour instead of on an assertion. The 700 figure never had a failure behind it, which made it
  the one enforced rule in this repository that `docs/standards.md` could not justify the way it
  justifies the others.

  `tests/validate-skills.sh` gains a warning level and counts warnings in its summary. All 24 skills
  currently validate with none, because nothing has taken the new room yet. The immediate unblocking
  is the fresh-clone documentation rule, which belongs in `write-docs` at 695 and `repo-snapshot` at
  699 and could not land in either.

**Not covered:** no behavioural eval for the documentation rules. `tests/evals/README.md` takes
scenarios only from a recorded baseline, and none has been run for these.

## 0.6.1 - 2026-08-14

Everything here came out of one thing: running `keel init --force` against a real repository rather
than a fixture. That was the last open item of the multi-stack detection work, and it found four
defects the fixtures could not, because each of them is about a repository saying something a
fixture never says.

### Fixed

- **The remedy for a gitignored docs root was one git cannot honour.** `init` correctly refused on a
  project whose `.gitignore` had a bare `docs` line, then told the reader to add `!docs/keel/`. Git
  never looks inside an excluded directory, so a negation cannot re-include anything under one.
  Appending exactly what keel printed and re-running produced the identical refusal, with nothing to
  suggest the advice was the problem rather than the `.gitignore`. The message now prints the full
  ordered recipe, re-including each parent before the negation that reaches the root, and builds it
  from the segments of `docs_root` so it holds for a root nested deeper or not nested at all. The
  test reads the patterns back out of the message and applies them, so it passes only while what
  keel prints is what actually works.

- **Two lockfiles were read as a declaration.** The project carried both `bun.lockb` and
  `package-lock.json`, `detect_js_pm` checked bun first and unconditionally, and the profile got
  `bun` for the manager and `bun run` for lint, typecheck, build and test. The project's own
  `Dockerfile` runs `npm ci`; the `bun.lockb` was residue from the scaffold it was generated with
  and had not moved in a year; and bun was not installed on the machine at all. Four commands nobody
  could run, presented as detected fact, and doctor failed on all four at once.

  Two lockfiles are not two declarations, they are none. `detect_js_pm` now prints nothing and every
  command needing a manager stays null, which is noisier and honest. No lockfile at all is unchanged
  and still means npm, a bare `package.json` being npm by definition rather than an ambiguity.
  `stack.package_manager` becomes `null` and not `"none"`: `"none"` is a project with no manager,
  this is one whose manager could not be read, and the skills that ask have to tell them apart.

- **A project with no tests failed the doctor of the profile init had just written.** `verify.test`
  is a warning and `verify.test_one` a failure, so a repository with no test script and no runner
  failed on the derived field while the root cause was only warned about one line later, and the
  init note named the warned field rather than the failing one. `test_one` is still required, and
  still fails, wherever `verify.test` is set: a missing one is an oversight only when there are
  tests to run. With both null the project has declared no tests at all, and doctor now says that
  once, as a warning, naming the actual cause. The note names both fields.

### Added

- **`deploy.ci` and `deploy.target` are detected instead of written null unconditionally.** The CI
  config was sitting in the repository the whole time, so every reader of the profile had to go and
  open a file `init` had already walked past. Both are now read the way a lockfile is read: a config
  committed to the repository is a declaration, its absence is not, and two of them are not two
  declarations. `github-actions`, `gitlab-ci`, `circleci`, `jenkins`, `azure-pipelines`,
  `bitbucket-pipelines` and `drone` for the pipeline; `fly`, `vercel`, `netlify` and `render` for
  the target.

  Nothing opens a file. Naming the cloud a workflow deploys to needs the deep read `repo-snapshot`
  does, and inferring it from a marker is how a profile ends up authoritative and wrong. A
  `Dockerfile` is deliberately not a target and there is a test pinning it to null: it says how a
  thing is packaged, never where it runs, and the project this was written for has one and ships the
  image to a VM over ssh. An empty `.github/workflows` declares nothing either, that being what
  deleting the last workflow leaves behind.

## 0.6.0 - 2026-08-13

### Changed, and it breaks every existing install

- **Renamed to `keel`.** `gbaiutils` said what the thing was made of rather than what it does, and
  `gbai` was a pun that had to be spelled out loud every time. A keel is the member a hull is built
  around and the reason a ship stays upright under load, which is the claim this tool actually makes.
  The marketplace is now `gbi`, so the company name lives where it belongs, on the marketplace rather
  than inside the tool.

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

  **No compatibility fallback, deliberately.** Nothing reads `.gbai/` any more, and no deprecation
  warning fires, because at 0.6.0 the only initialised repository is this one. A fallback would be
  code carried to 1.0 for a migration nobody has to make. The cost of this rename never gets lower
  than it is today, which is the argument for doing it now rather than after the pilots.

  **Four things a person has to do by hand**, none of which a release can do for them: rename the
  GitHub repository (old URLs redirect, so an existing marketplace entry keeps resolving), re-point
  the `keel` symlink on PATH, run `/plugin marketplace remove gbai` then add `gbi`, and rename any
  local clone directory.

  **Entries below 0.6.0 keep the old names on purpose.** They record what the commands were called at
  the time. Rewriting them would put `keel init` in a release where no such command existed.

### Added

- **keel now runs `keel init` on itself.** The profile had been hand-written since before `init`
  existed, so the repository claimed to be configured by 0.1.0 and had no CLAUDE.md or AGENTS.md at
  all, which doctor had been reporting for four releases. Re-running init merged under every
  hand-written value, including the `verify_notes` and the deliberately non-idiomatic lint string, and
  added what the defaults have gained since: `artifacts`, `observability`, `verify.test_integration`.

  The scanner caught the one thing worth catching. `init` writes an executable `.claude/keel-nudge`,
  and committing it puts a new executable in a plugin repository, which is exactly the route the
  `structural-executable` rule exists to challenge. It is enumerated in `allowed_executable` now, with
  the reason beside it, rather than waved through.

- **More plugin keywords**, from 7 to 35, covering what the 24 skills actually offer: refactoring,
  debugging, observability, threat modelling, supply chain, ADRs, runbooks, incident response,
  CI/CD, Oracle APEX porting, context management, skill authoring and git hooks among them. The old
  list named a third of the catalogue and made the rest undiscoverable.

## 0.5.0 - 2026-08-13

### Added

- **`shape-idea`**, which turns a rough idea into a recorded decision `write-prd` can consume, or into
  a decision not to build it. Writes `<docs_root>/ideas/<slug>.md`.

  **The baseline is why this skill is not what it was going to be.** Asked to help think through a
  three-feature dashboard idea, an agent with no skill pushed back hard and well: it killed a
  per-second balance refresh with connection-pool arithmetic, challenged "the true number" against the
  actual wallet data model, and redirected a chat panel to append-only notes on a compliance
  argument. Teaching pushback would have taught what the model already does.

  It failed in four other ways. It wrote nothing durable, so the whole analysis died with the
  session. It produced a sprint slice for an idea with no requirements, which is what `write-prd`'s
  hard gate exists to prevent. It closed with five questions in one wall. And it deliberately buried
  its own strongest objection: "I did not lead with the possibility that they may not need a dashboard
  at all... opening by dismissing the premise tends to end the conversation instead of improving the
  idea." The skill is built around those four, and that quote is in its rationalisation table.

- **`port-assess`**, for moving an existing codebase to another stack. `apex-port-plan` keeps APEX,
  which reads an export rather than a codebase. Writes `<docs_root>/port/<service>-assessment.md`.

  Every step came from an observed failure rather than a design session. Step 1 exists because a
  baseline read a snapshot that described **a different branch**: different framework version,
  different test count, different SQL safety, and one of the two trees had no authentication at all.
  Step 2 exists because "port to NestJS and React" was put to a service with no UI, no `package.json`
  and `has_ui: false`, so half the proposal was greenfield sold as translation. Step 4 exists because
  the obvious Node replacement for a Java serialiser drops null fields: identical meaning, different
  bytes, and every signature rejected on the first request with an absent optional field, which no
  ordinary test catches. Step 5 exists because two separate runs judged a document from a grep count
  or its filename and admitted it only afterwards, unprompted.

- **`write-prd` reads the idea record.** `from-idea` now opens `<docs_root>/ideas/<slug>.md` and asks
  nothing it settles, the same way `from-repo` reads `snapshot.md`. Without this the two skills would
  ask the user the same problem, users and scope questions twice, which is the overlap `create-skill`
  step 0 exists to prevent. The mapping from record to PRD lives in the questionnaire reference, so
  the skill body stayed at exactly its previous length.

### Added

- **The push guard now refuses a push to the default branch**, not only one the supply chain scan
  flags. Work lands through a pull request, so that branch is written by a merge rather than a push,
  and a rule nobody can forget beats a rule everyone agrees to. `git push --no-verify` is the one-off
  escape hatch, and `conventions.protect_default_branch: false` is the standing one for a project that
  genuinely pushes to its default branch.

  The branch name is read from `conventions.default_branch`, with the remote's HEAD as a fallback.
  When neither states it the hook checks nothing rather than assuming `main`: a refusal naming the
  wrong branch teaches people to reach for `--no-verify` by reflex, which costs more than the guard
  buys. `protect_default_branch` was already in `templates/gbai-profile.example.json` and read by
  nothing, so this makes an advertised key real, and adds it to the schema and to what `init` writes.

  Two things the tests caught rather than review. The flag was parsed with `\(true\|false\)`, a GNU
  sed extension that matches nothing on the BSD sed macOS ships, so a project that had switched the
  guard off would still have been refused. And the hook reads its refs from stdin, which a `read`
  against a terminal would sit and wait on, so it checks the refs only when git is actually feeding
  it.

- **The generated pre-push hook is now linted.** Its body lives inside a quoted heredoc, so
  `verify.lint` reads it as a string and has never parsed it. `tests/test-gbai.sh` now installs the
  guard and runs shellcheck on the written file. It earned the slot on its first run: the refusal
  message interpolates the branch name, so its heredoc is unquoted, and a pair of backticks added
  around a suggested command in that message was command substitution waiting to run on somebody's
  machine.

### Fixed

- **`gbai init --team` staged everything it wrote except `.gitignore`, which is the one file the flag
  exists for.** `init` appends the `.claude/settings.local.json` rule to `.gitignore`, and `--team`
  staged `.gbai`, `CLAUDE.md`, `AGENTS.md`, `.claude` and the docs root but not `.gitignore` itself. A
  teammate cloning that repo therefore had no rule holding the `bypassPermissions` local settings file
  out, so the file the rule exists to exclude gets committed by the next person to run `git add -A`.
  Staging now includes `.gitignore`.

  The same line printed "Staged for commit (--team)." in a directory that is not a git repository,
  because the `git add` failure was swallowed by `|| true`. It now reports what happened. `--team` had
  no test coverage at all, which is why neither was caught; both are pinned now.

  `docs/01`, `docs/03` and `docs/07` credited the marketplace reference and the nudge hook to
  `gbai init --team`, and said the flag commits. Plain `gbai init` writes both, and `--team` only
  stages; corrected in all five places.

- **The router and the shipped cheatsheet had drifted, and nothing checked.** `incident-response` was
  routable by the model and absent from `prompting.md`, the document that ships into every project, so
  a user would never learn to ask for it. `README.md` has claimed since 0.2.0 that the cheatsheet
  agreement is "enforced by the validator" and it was not. `tests/validate-skills.sh` now requires
  every router destination to appear in the cheatsheet, with both directions pinned in its tests.

- **A `Read` deny rule does not stop Bash reading the same file.** Found when a subagent working under
  gbaiutils' own guardrails reported `.env` contents it had obtained through Bash rather than the Read
  tool. `gbai init` now also denies the common `cat`, `head`, `tail`, `less`, `more` and `strings`
  shapes against `.env`, `secrets/` and `id_rsa*`.

  Stated plainly in the code and worth repeating: this is defence in depth, not a boundary. A command
  string cannot be matched exhaustively, and `sh -c`, `xargs`, `env` or a Python one-liner all get
  past it. A secret in the working tree is reachable by any agent that can run commands.

- **`port-assess` shared `apex-port-plan`'s assessment template for about an hour.** The reasoning was
  that two templates drift. The re-run showed it was the wrong trade: the APEX template is APEX-shaped
  in twenty-one places, naming `INDEX.md`, `xref.tsv`, page ids, PL/SQL packages and build options,
  and it specifies an output path contradicting the skill's. The agent rewrote four sections, ignored
  the path, and said so. A shared template every user has to rewrite is a detour, so `port-assess` now
  has its own, and each cross-references the other's rules section.

### Documentation sweep

A pass over every document against the tree, before committing. It found more than tidying.

- **The SessionStart injection named 19 of 24 skills.** It is the only routing map a session has
  before loading anything, and it is in the prefix of every request, so a skill missing from it is one
  the model will not think of unless the user names it. `incident-response` was among the missing,
  which is the skill that most needs to fire without being asked for. Now named, and
  `tests/validate-skills.sh` requires every skill to appear and caps the injection at its 400 token
  ceiling.

- **`docs/06-repo-layout.md` described a repo that never existed.** It was written as a plan, said so
  ("as it should exist when Phase 6 is done"), and listed `lib/write-profile.sh`,
  `lib/doctor-checks.sh`, `templates/settings.template.json`, `templates/docs-gbai-skeleton/`,
  `tests/test-init.sh`, `tests/test-doctor.sh` and per-stack `tests/fixtures/`, none of which were
  ever created. Regenerated from the tree, and reframed as a description rather than an intention.

- **`docs/03` documented a `gbai upgrade` command that does not exist.** Removed, and `gbai scan` and
  `gbai guard`, which do, are now specified there.

- **`SOURCES.md` named `templates/claude-md-block.md`**, which is `project-claude-md-block.md`, and
  said the licence was "not yet chosen" two releases after it was. It also left seven original skills
  to be inferred from "everything not listed above". They are now listed by name, because a reader
  cannot otherwise tell an original skill from an adaptation nobody credited.

- **`docs/07` named `pipeline-templates.md`**, which is `pipeline-patterns.md`. That list is what a
  future public release would work from, so a wrong name there means a GBi-specific file ships. Two
  files that have since become GBi-specific were added to it.

- **`incident-response` had no entry in the skill catalog**, and had not since it shipped at 0.3.0.
  Doc 02 flagged its own gap and carried it for two releases. Closed, and the file now says plainly
  that it is the one map of the four that is *not* mechanically checked, so it stays a discipline.

- Counts corrected in `README.md`, `docs/01`, `docs/03`, `docs/05` and `skills/context-budget`.
  Decision 6 in `docs/07` is superseded rather than edited, per that file's own append-only rule, with
  the token arithmetic that makes the granularity question concrete: the descriptions are now ~1,120
  tokens in every request, up from ~760, and nothing caps them.

### Skill description sweep

Descriptions are the only part of a skill that loads on every request, so they are the one place where
shortening pays per request rather than per invocation. All 24 were swept for redundancy.

- **55 tokens per request recovered**, from 1,122 to 1,067, by merging near-synonyms *within* a single
  description: "asked whether something is secure" with "a vulnerability check is requested", "migrate
  or port" down to "port", "scope or size a rewrite" with "the risks before committing". No skill's set
  of distinct triggers changed.

- **Three of the cuts were reverted, because they removed a trigger rather than a synonym.**
  `security-audit` had lost "asked whether something is secure", which is the most natural way anyone
  raises it. `design-architecture` had lost "system structure", leaving only the narrower "service
  boundaries". `refactor` had lost "a file has grown hard to change" as a standalone situation, which
  is not the same as "before adding a feature to code that is difficult to work in". Each is worth more
  than the handful of tokens it costs.

- **The 40-token target in doc 05 was set before any skill existed and is not reachable.** After
  removing every intra-description synonym the mean is 44, and the only four skills under 40 are those
  with the narrowest trigger surface. Four distinct triggers do not fit in 144 characters. The target
  is now 44, measured rather than guessed.

- **The validator was looser than the budget it enforced.** `DESC_MAX_CHARS` was 260, about 72 tokens,
  against doc 05's documented 60-token ceiling, so every description in the repo could have breached
  the budget and passed. Now 216 chars, and the ceiling has a test in both directions for the first
  time. It had none.

- **Bodies had nothing to merge.** Checked for identical sentences across all 24: there are none, and
  eight cross-skill reference links already carry the shared material. The deduplication had already
  been done.

### Known, not fixed: skill bodies are close to their ceiling

Eight of 24 skill bodies sit within 15 words of the 700-word hard ceiling, four of them within four
words. Writing this release hit that ceiling four times.

Bodies load on invocation rather than on every request, so this is not a token cost. It is a
maintenance one: any future edit to `repo-snapshot`, `tdd`, `execute-plan`, `port-assess` or
`incident-response` fails the build until something else is cut.

Doc 05 predicts the cause: a skill in the 600 band "without a dispatch table or modes is carrying
padding". By that test `repo-snapshot`, `execute-plan`, `port-assess` and `write-prd` earn their length
through subagent briefs or modes, and `tdd`, `debug`, `incident-response` and `shape-idea` do not.

**Not trimmed here, deliberately.** Every one of those four carries rationalisation tables and red
flags that were added because a specific failure was observed, and several are the reason their eval
passes. Cutting them is a behavioural change that needs evals to prove no regression, not a tidy-up to
be bundled into a documentation sweep.

### Not yet verified

- Both skills were baselined and re-run through subagents, which is what `create-skill` requires, and
  both re-runs produced markedly better work than their baselines. **Neither has been invoked through
  the loaded plugin**, so routing is untested: the re-runs were told which skill to follow. Whether
  the router picks them from natural phrasing is a pilot question.

- Neither has an eval scenario in `tests/evals/`. The re-run transcripts are the evidence today, and
  that is weaker than a repeatable eval.

## 0.4.0 - 2026-08-13

### Added

- **Eight standards that were missing, and the checks that enforce them.** `coding-standards` goes
  from 4 topic references to 10, with short entries and their reasons in `references/gbi-defaults.md`.

  | New reference | Covers |
  |---|---|
  | `rate-limiting.md` | Token bucket and why not the other three, atomicity (a read-modify-write limiter enforces N times its configured rate across N instances), keys the caller cannot choose, the 429 contract |
  | `caching.md` | TTL by data class, keys carrying everything that varies the value, invalidation shipping with the write path, stampede handling, and the query cache (parameterised queries are a plan cache argument as well as an injection one) |
  | `authorisation.md` | Deny by default, permissions rather than role names, object-level checks, tenant scoping at the data layer, the revocation window, separation of duties on money |
  | `resilience.md` | Timeouts on every outbound call, retries bounded and jittered with a budget, circuit breakers, pool isolation, and the partner-timeout rule that a transaction is left pending rather than assumed either way |
  | `async-work.md` | The outbox pattern, at-least-once as the contract rather than a failure mode, idempotent consumers, dead letter queues, ordering, scheduled-job leases, and transaction boundaries |
  | `time-and-dates.md` | UTC in storage, dates that are not timestamps, business days and cutoffs as data, monotonic clocks for durations, and the injected clock that makes any of it testable |
  | `api-contracts.md` | What actually counts as breaking, versioning, deprecation with measurement, error codes as contract, pagination, and webhooks as an API you provide |
  | `data-protection.md` | Classification, minimisation, retention that executes, deletion reaching the copies, encryption and which threat each kind stops, and subject rights built once |

  Plus accessibility into `frontend.md`, which had none, and expand-and-contract schema change and a
  dependency policy into `gbi-defaults.md`.

  Documented and enforced rather than documented only, because a standard nothing looks for is a
  standard nobody follows. `review-code`'s rubric now asks whether a new outbound call has a timeout,
  whether an event is published inside a transaction, whether a consumer is idempotent, whether a
  timestamp carries a zone, plus a contracts pass for changes a caller cannot be redeployed around
  and a personal-data pass. `security-audit` gains sections on rate limiting, caching, time, and the
  personal-data lifecycle beyond log redaction, and treats a missing timeout as the availability
  vulnerability it is.

  **The index of topic references moved out of the skill body into `gbi-defaults.md`.** Ten rows in
  the body would have left about 30 words of headroom against a 700-word ceiling, on a skill whose
  target is 400. The body now points at the index and is 588 words rather than 629, and an eleventh
  reference costs nothing there. `tests/validate-skills.sh` was extended in the same change to
  resolve links inside reference files, since the index is ten links in the one file whose whole job
  is routing and nothing was checking them.

- **`tests/supply-chain-scan.sh`**, and `tests/test-supply-chain.sh` proving it catches what it
  claims. 19 pattern rules and 4 structural ones, over a plugin whose hooks run automatically on
  every engineer's machine and whose skills are instructions a capable agent follows.

  Covers pipe-to-shell, decode-and-execute, `eval` over fetched content, reverse shells, network
  calls inside anything that runs unattended, credential stores and keychain extraction, shell
  startup files and machine-wide config, destructive deletes, history wiping, obfuscated literals,
  and agent-facing prompt injection (a skill telling the model to ignore its instructions, conceal
  what it did, or act without telling the user). Structurally: no tracked binaries, an enumerated set
  of executables, no bidirectional or zero-width characters, and no hook that `hooks.json` does not
  register.

  Suppression is explicit and loud: a line ending `supply-chain-scan: allow <reason>` is skipped,
  every honoured suppression prints on every run, and one with no reason is itself a finding. The
  tree carries three, all in the tests that prove the guard works.

- **`gbai scan` and `gbai guard install|status|uninstall`.** The guard is a repo-local pre-push hook
  that runs the scan, so a branch carrying a flagged file does not reach a remote where it is
  permanent. Opt-in, because it sets `core.hooksPath`, and repo-local, because setting that globally
  would silently disable every other repository's hooks on the machine. `git push --no-verify` is the
  deliberate way past it. CI runs the scan as its own job so it can be a required check on its own.

- **Plugin boundary detection in `gbai doctor`.** Two kinds of collision. A registry names the
  plugins known to ship a competing methodology (`feature-dev`, `superpowers`, `gstack`) with a
  reason for each. The second needs no registry: the installed plugin cache is read directly, so any
  plugin shipping a skill name gbaiutils also ships is found, whoever wrote it. That collision is
  silent in a real session, which is the point of reporting it, since Claude Code resolves the name
  to one of the two and records nothing.

  It reports and stops there. Nothing is disabled on anybody's behalf, and the managed CLAUDE.md
  block now carries one line of precedence so a session with both loaded knows which wins.

- **The context watchdog**, `hooks/context-watch` and `lib/context_watch.py`, on `UserPromptSubmit`,
  `PreToolUse` and `PreCompact`. Silent below 70% of the window, warns between 70 and 85, and past
  85 denies tool calls until a handoff is written.

  Occupancy is read rather than estimated: the transcript records the usage the API reported, so it
  is `input_tokens + cache_creation + cache_read + output_tokens` of the last main-thread assistant
  turn. The cache fields are the whole measurement. On a long session `input_tokens` is routinely 1,
  so a watchdog reading it alone would call a full window one token. Sidechain entries are excluded,
  or a subagent reading twenty files would report the main thread as full, which inverts the reason
  for delegating.

  `Write`, `Edit` and `Read` stay available past the threshold, because being told to write a handoff
  while writing is refused is a deadlock dressed as a safety feature. The stop lifts once the handoff
  is refreshed, so it is a pause rather than a wall. `PreCompact` writes a mechanical handoff on its
  own: what was asked, which files were written, and where it got to, with the judgement part left
  explicitly marked as unfinished.

  Silent when `python3` is absent rather than printing an apology on every prompt, and `gbai doctor`
  reports that it is inert so the silence is not mistaken for protection. Off via
  `GBAI_CONTEXT_WATCH=off` or `gates.context_watch: false`; thresholds configurable.

- **`gbai doctor` now enforces the managed block's token budget**, which doc 05 has claimed since it
  was written and nothing checked. The block sits in the prefix of every request in a repository, so
  a line added there is paid per request per engineer. Warns over the 450 target, fails over the 700
  ceiling.

### What the first run against a real repository changed

Everything above was built against fixtures. Pointing it at a Spring Boot service, on a branch cut
from `main`, changed four things and confirmed the rest. None were findable from a fixture, because a
fixture only contains the shape its author already imagined.

- **The context watchdog would have hard-stopped every 1M session immediately.** A real 2.4MB
  transcript held 401,247 tokens and reported **200%** of the assumed 200,000 window, because a
  genuine 1M session records its model as plain `claude-opus-5`, with no marker and no field anywhere
  naming its window. At 200% the stop fires on the first tool call and never lifts, on exactly the
  sessions with the most room left.

  Fixed three ways, since the window cannot simply be read: an explicit `gates.context_window` or
  `GBAI_CONTEXT_WINDOW` wins; failing that, occupancy above a tier is proof the window is larger,
  which can only correct upward and never invents room that is absent; and `gbai doctor` prints the
  assumption in force, because a silent wrong one either stops sessions at a fifth of their capacity
  or never fires at all.

- **`structural-binary` produced twenty findings, every one of them wrong.** A Gradle wrapper jar,
  nine rotated log archives and uploaded PDFs are all correct in a service repository. That rule was
  written for a tree that is markdown, bash and a little Python, and letting it apply everywhere is
  exactly the check-stricter-than-correct-output failure `docs/standards.md` warns about. Now scoped
  to plugin repositories.

  Splitting it **kept the finding that mattered**: `structural-secret-material` applies everywhere and
  reports a committed key, keystore or certificate. It found six PKCS#12 keystores under
  `src/main/resources`, independently of `security-audit` having reported the same thing there.
  Exceptions go in a committed `.gbai/scan-allow`, because a binary has no line to annotate.

- **The scan took 7.9 seconds on a 73-file repository**, running one grep per rule per file. It now
  runs one grep per rule over a prebuilt list: 1.75 seconds there, 4 on this repository. It matters
  because this runs as a pre-push hook, and a slow hook is one people pass with `--no-verify` by
  reflex.

- **The managed CLAUDE.md block was 682 tokens of its own 700 ceiling**, leaving 18 for a project's
  verify commands. The real repository's `verify.test` is a Gradle command carrying five `--tests`
  filters, so the rendered block reached 724 and `doctor` failed the project for the template's
  weight. Rewritten to 524, rendering at 573 there. The new budget check was right; what it caught
  was ours.

- **`coding-standards` was then run for real against the same service, end to end**, which is the
  only thing that tests the content rather than the machinery. It produced a `standards.md`, wired a
  working `checkstyleMain` gate where `verify.lint` had been null, and changed the skill twice:

  **Counting gives the wrong answer when the majority pattern is a defect.** Step 1 said to count and
  take the majority as the convention. The service has 7 string-concatenated SQL queries against 3
  parameterised, so following the skill literally would have written "SQL is built by concatenation
  here" into a standards document as sanctioned convention. Step 1 now says counting decides style
  and never correctness, and names the shape.

  **A rule can be right while its violations cannot be fixed yet.** The credential-literal rule fired
  on three hardcoded partner secrets, which cannot be fixed without rotating them with the partners.
  Deleting the rule loses it; leaving it red means the gate never passes. Step 3 now carries the
  third option: keep the rule, suppress the known sites in a committed file, each entry naming what
  closes it, so anything new still fails.

  The run also confirmed the new references earn their place. `resilience.md` found **20 outbound
  HTTP call sites with zero timeouts**, on `HttpClient.newHttpClient()`, which has no request timeout
  at all. `time-and-dates.md` found `java.sql.Timestamp` in 6 places against one `LocalDateTime`.
  Neither was covered by any standard before this release. The largest finding was not from a new
  reference at all: five `finally { return ... }` blocks that discard the `catch` block's 400 and
  return 200, so every failure on those endpoints reports success to the partner.

- **Confirmed working, unchanged:** `init` idempotent on a repository it had never been tuned against
  and carrying an older profile, the version refresh, the guardrail merge into an existing settings
  file, the boundary check (correctly silent, nothing conflicting installed), and the pre-push guard,
  which refused a real push over the keystores.

  `doctor` also reported three verify commands failing, and they genuinely do: `gradlew` is committed
  as mode `100644`, so `./gradlew` cannot run for anyone who clones. That is the repository's defect,
  surfaced by the tool rather than a fault in it.

### Fixed

- **`VERSION` and `.claude-plugin/plugin.json` had drifted**, at 0.3.0 and 0.2.0. The plugin cache is
  keyed on `plugin.json`, so the whole APEX release reached nobody who installed it: `gbai version`
  was right, the CHANGELOG was right, and every installed copy stayed on the previous skills with
  nothing failing. Both now move together, pinned by a test that also checks the newest CHANGELOG
  heading agrees.

- **The supply chain scan read tracked files only**, so a file was invisible to it for exactly as
  long as it took to write and commit, which is the only window in which deleting it is free. Found
  when the run meant to verify this release's eight new files scanned none of them. It now reads
  `--cached --others --exclude-standard`, so untracked work is in scope and ignored paths are not.

- **Two supply chain rules matched nothing on the machine they were written on.** Both used an empty
  alternative, `(ba|z|k|)sh`, which GNU grep accepts and other greps reject outright. The scan
  swallowed the error, reported clean, and counted both rules in its total. Found by the coverage
  test, which is the only reason it was found at all. The scanner now refuses to start when any rule
  fails to compile, and a case pins that behaviour with a regex no implementation accepts.

### Not yet verified

- The context watchdog's arithmetic is now checked against a real 2.4MB transcript as well as
  fixtures, and that is what found the 200% defect. **What remains unproven is that Claude Code
  invokes the hook with the fields assumed here**, and that `permissionDecision: deny` on
  `PreToolUse` produces the pause intended. Both need a live session reaching 85% of its window.
  Until that has happened once, treat the stop as designed rather than demonstrated.

- The pre-push guard is tested by running the hook directly rather than by pushing, since a push
  needs a remote. The hook's own refusal is proven; git's invocation of it is not.

## 0.3.0 - 2026-08-13

### Added

- `gbai apex-export`, and the `apex-export` and `apex-port-plan` skills. Exports one Oracle APEX
  application into a directory an agent can grep: one directory per page, SQL and PL/SQL in their
  own files, and `xref.tsv` mapping every database object to every page that uses it.

  Reads the APEX dictionary views rather than the native export, because every reference in
  `f100.sql` is a 14 digit internal id and grepping it for a table name finds nothing. The views
  also need only a read only user associated with the workspace, where `APEX_EXPORT` wants
  `APEX_ADMINISTRATOR_ROLE`.

  Version tolerance comes from probing `ALL_TAB_COLUMNS` for the columns each view actually has on
  the target instance, then selecting all of them except a small noise denylist. There is no version
  table in the code and no hand-written column list to fall out of date. Everything that could not be
  read is written into `INDEX.md` as scope, not omitted.

  Credentials found in application source are redacted by default and reported in `REDACTIONS.md`.

- `tests/test-apex-export.sh`, 39 cases driven from a committed capture fixture with no database.
  Possible because `lib/apex_render.py` is pure and all I/O lives in `lib/apex_export.py`; the
  suite asserts that split directly so it cannot erode.

### Fixed before first release

Every item here was found by running against a live APEX 22.2 instance with a 156 page
application. None was findable from a fixture, because a fixture only ever contains the shape its
author already believed in.

- **Roughly twenty hand-written column names were wrong**, and each one failed quietly. The
  dynamic action view names its event `WHEN_EVENT_NAME`, not `EVENT_NAME`; its element is
  `WHEN_ELEMENT`, not `TRIGGERING_ELEMENT`. A computation's code is in `COMPUTATION`, an
  application process's in `PROCESS`, and an authorization scheme's in `ATTRIBUTE_01`. Every wrong
  guess dropped the column and printed a reassuring "absent on this version" line, so the export
  looked complete while containing none of the code. Dynamic action rows came out nearly empty.

  Fixed by deleting the hand-written lists entirely. The catalog is now the authority: every
  column the view has is selected except a small noise denylist, so a column this tool has never
  heard of still arrives and a column Oracle renames cannot go missing.

- **Database dependencies were followed one level deep, so most of the logic was missing.** An APEX
  page calls `PKG_HTTPS`; `PKG_HTTPS` calls `PKG_AQ`; `PKG_AQ` is the entire asynchronous messaging
  layer. Scanning only page source found the first and missed the rest. Triggers were missed
  entirely, because a trigger fires on DML and is never named by anything. The first live run
  exported 44 PL/SQL units and **zero triggers** from a schema holding 559 objects and 123 triggers.

  The export looked complete. Anyone scoping a port against it would have sized the thin half.
  References are now followed transitively until nothing new appears, and triggers are pulled in via
  the tables they hang off: 44 units became 169, and 0 triggers became 87.

- **Long values in unrecognised columns were silently clipped.** The attribute table renders values
  over 300 characters truncated. A code-bearing column absent from the source map therefore lost its
  content with no signal, and a clipped query is indistinguishable from a short one to whoever reads
  it. One real export lost **62 inline LOV queries, every one cut mid-SQL**. Any value long enough to
  be clipped is now written to its own file instead, whatever its column is called.

- **A fatal-error scan matched the application's own source.** The check for a failed connect
  looked for strings like `invalid username` anywhere in the client output. A PL/SQL function
  containing `'Invalid Username/Password. Please try again.'` aborted a successful export at the
  last step, after six minutes of extraction. The scan now skips lines belonging to a JSON result
  document, which is where everything from the database lives.

- **Short source values were dropped from the export entirely.** A length rule sent values under
  80 characters to the attribute table instead of their own file, and the attribute table excluded
  every source column on principle. An authorization scheme whose whole body is one line vanished.

- **An object named like a SQL keyword flooded `xref.tsv`.** The schema contains a function named
  `JOIN`, so matching bare identifiers against the catalog produced 54 references to it, one per
  query with a join. Keyword-named objects now match only where they are called, taking that from
  54 rows to the 2 real ones.

- Several thousand single-line files: condition expressions exist on nearly every component and are
  usually one short line. File count on the real application went from 2350 to 1021.

- Section markers were emitted as bare `@@@GBAI-SECTION:name` lines. SQLcl reads a line beginning
  `@@` as the run-nested-script command and swallows it with **no output and no error**, so no
  section was ever named, parsing fell back to positional order, and one section failing to return
  would have shifted every later section onto the wrong name. Silent misattribution of data.

  Found by running against Oracle Free in Docker, not by any test, and it is not findable by one:
  a capture fixture is the client's output, and this bug was in the client's input. The fix emits
  `prompt @@@GBAI-SECTION:name`, and `tests/test-apex-export.sh` now asserts the generated scripts
  directly rather than only their output.

- `set long` was 2000000000, which makes SQLcl print a Java memory warning on every run. Reduced to
  10MB, still far above any real APEX region source.

### Proved against a live instance

All 27 dictionary views resolved on APEX 22.2. A 156 page application exported end to end with zero
warnings: 309 database objects reached three levels deep, 169 PL/SQL units including 87 triggers, 104
tables, region SQL and PL/SQL preserved verbatim including `&SUBST.` syntax and bind variables.

`apex-port-plan` was then run against that export twice: once against the incomplete first pass, and
again after the closure fix. Both runs completed and produced an assessment. The second found a
production defect in the client's ledger that neither the tooling nor a page-by-page reading would
have surfaced, which is the outcome the skill exists for.

### Known gaps

- APEX automations and scheduled jobs are not extracted. They are not in the dictionary views this
  reads, and `apex-port-plan` tells the reader to ask about them instead of implying coverage.
- Queue infrastructure DDL (`DBMS_AQADM`, `DBMS_AQ.REGISTER`, `DBMS_SCHEDULER` job definitions) and
  sequences are not reachable from the dictionary views either. Worth adding: a schema this tool
  reported on had 81 sequences and exported none of them.
- Only APEX 22.2 has been exercised. The catalog driven column selection means older and newer
  releases should degrade to a recorded warning rather than a failure, but that is a design
  intention and not yet a measurement.
- The difficulty bands have not been checked against anyone's judgement of the same application.
  They rank pages sensibly on the one real application seen so far, which is not the same thing.

## 0.2.0 - 2026-08-12

Released to move the plugin cache off `0.1.0`. Claude Code caches an installed plugin at
`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`, so the version is the cache key and
pushing to `main` without changing it leaves every installed copy on the old skills. Bumping is
part of shipping a change, not a ceremony after it.

### Added

- Plugin and marketplace manifests, so the repository is installable via
  `/plugin marketplace add gbi-solutions-ltd/gbaiutils`.
- `skills/repo-snapshot`, the first skill. Analyses an unfamiliar repository through six
  parallel subagents and writes a snapshot document to the project's docs root. Tested
  against three repositories across two stacks.
- `skills/write-prd`, in three modes: `from-idea`, `from-repo`, and `revise`. Every
  requirement carries a permanent ID and a status of `confirmed`, `inferred`, or `disputed`.
  In `from-repo` mode every requirement starts `inferred`, and behaviour the code exhibits
  that is not a requirement goes in its own section rather than being promoted to one.
  `from-repo` tested against a Spring Boot service, consuming that service's snapshot, which
  is the first working link in the artifact chain.
- `skills/write-user-stories`. Breaks a PRD into epics and stories, each tracing to the
  requirement IDs it satisfies, and proves coverage in both directions rather than asserting
  it. Stories carry a kind of `build`, `verify`, `fix`, or `decide`, because a PRD written
  `from-repo` describes a system that mostly already runs and treating every requirement as
  new work reimplements working software. Tested against the same service's PRD.
- `skills/design-architecture`, in three modes: `new`, `existing`, and `adr`. Never presents a
  single option, because a decision with no stated alternative is a preference. Produces
  mermaid context, container, and sequence diagrams, a failure-mode table, and one ADR per
  material decision. An ADR the skill writes is always `proposed`; only a person marks one
  `accepted`. `adr` mode tested against the same service, where the four `decide` stories
  produced four ADRs, closing the third link in the artifact chain.
- `skills/write-plan`. Bite-sized TDD tasks with exact file paths, real code, and a
  `Consumes`/`Produces` interface block per task so a task executed in isolation knows the
  signatures its neighbours use. Verify commands are read from `.gbai/profile.json` rather than
  guessed from the stack. Tested against the same service, producing a 6-task plan from one
  story and one ADR.
- `skills/tdd`. Adapted from superpowers, with verify commands read from `.gbai/profile.json`
  and an explicit stated-exception path for spikes, generated code, and configuration. Taking
  the exception is allowed; taking it silently is not.
- `tests/validate-skills.sh`, `tests/test-validate-skills.sh`, and `tests/run-tests.sh`. Static
  validation of frontmatter shape, word budgets, `@` links, docs-root notation, link
  resolution, and house style, with tests proving the validator catches each one.
- `.github/workflows/ci.yml` running the tests and shellcheck.
- `.gbai/profile.json` for gbaiutils itself, so the repo dogfoods its own profile contract.
- `skills/debug`. Four phases with an iron law of no fix without an explanation, a three-fix
  circuit breaker that escalates to an architecture question rather than a fourth attempt, and
  two references: backwards tracing to where a bad value was created, and instrumenting every
  boundary in one run rather than guessing which component is wrong.
- `skills/execute-plan`, inline and delegated modes. Step 1 is a refusal gate: it will not start
  on a plan whose ADR is only `proposed`, whose PRD is a draft, whose stories are provisional,
  on the default branch, or where a verifying command is missing from the profile.
- `skills/coding-standards`. Derives conventions from the code rather than importing a style
  guide, then splits them: anything a tool can check moves into the linter, and only judgement
  calls reach `<docs_root>/standards.md`. Includes the GBi defaults on writing style, secrets,
  errors, money, data, and tests.
- `docs/standards.md` for this repository, produced by running that skill on itself.
- `skills/review-code`. Delegates the correctness pass to the `code-review` plugin when present
  and degrades to an inline rubric when not, then adds four checks a generic reviewer cannot
  run: does the diff match the plan, does every changed line trace to the request, were the
  tests written first (checked by commit order, not by claim), and does it contradict an
  accepted decision. Findings are ranked, capped at around ten, and an approval must name what
  was checked.
- `skills/security-audit`, in `--diff` and `--full` scopes. Seven phases ordered by where
  breaches actually come from: secrets, supply chain, pipeline, configuration, STRIDE, OWASP,
  then a payments and cards checklist. Every finding needs a concrete exploit and a `file:line`,
  and unverified leads go in a separate section so a report of three real problems does not read
  as forty. Four references, including a payments checklist covering the domain risk that generic
  tooling does not touch.
- `skills/refactor`. Refuses to start without tests that pass first, because a refactor with no
  tests is a rewrite with optimism. Commits per step so the work is revertible, and treats a test
  you had to change as a behaviour change that must be said out loud.
- `skills/optimize-performance`. Refuses to start without both a numeric target and a
  reproducible baseline, profiles rather than reasons, changes one thing at a time, and reverts
  anything that did not move the number because complexity has a permanent cost.
- `skills/setup-deployment`. Builds the whole path from commit to running, including the way back.
  Its reference carries seven traps found in real GBi repositories, each of which made a pipeline
  look like it worked when it did not.
- `skills/ship`. An eight-check gate whose value is refusing. It runs the tests itself rather than
  trusting a previous green run, will not repair its own failures, and requires an override to
  name the specific check being accepted.
- `skills/write-docs`, covering five document types. Its rule is that every instruction is executed
  before it is written down, because an untested quickstart fails at the moment a new joiner has
  least context.
- `skills/create-skill`. TDD applied to process documentation: baseline the failure first and quote
  the reasoning the agent used, then match the form to the failure, because a prohibition fixes a
  discipline failure and measurably backfires on a wrong-shaped output.
- `skills/context-budget`. Measures the always-loaded layer per source against a budget, hunts the
  cache hazards that make every request pay full price, and quantifies each recommended move.
- `skills/gbai`, the router. 347 words, because it is the skill loaded most often. Routes to one
  skill and stops, prefers the process skill when two fit, and answers directly when none does.
- A validator check that every router destination exists, added test-first. A route to a deleted
  skill is a dead end the model follows confidently, and nothing else would have caught it.
- Design documentation in `docs/`, the phased build in `IMPLEMENTATION-PLAN.md`, and the
  three templates that `gbai init` writes into a project.
- `SOURCES.md` and `THIRD-PARTY-LICENSES.md`, recording attribution per skill for the four
  MIT projects this work adapts.

### Added, from review feedback

- `coding-standards/references/observability.md`. Logging, telemetry, and traces as a standard:
  required log fields including the calling actor, level semantics, redaction at the serialisation
  boundary, span coverage, and a configurable backend defaulting to SigNoz with Grafana, Datadog, and
  none as alternatives. Instrumentation is OpenTelemetry regardless, so switching is configuration.
- **Error logs written to be pasted into an agent CLI.** An `error` line states the failing operation
  in domain terms, carries the identifiers needed to reproduce as fields, and includes a
  `remediation` field naming the skill to use. `debug` now starts from those fields rather than the
  stack trace.
- `coding-standards/references/frontend.md`. Extract on the second occurrence rather than the third,
  a four-layer component boundary checked by import direction, and a theming test that is concrete:
  if the brand colour changes, exactly one file changes. Plus token storage, CSRF, XSS, and the fact
  that there is no such thing as a frontend secret.
- Frontend security added to the OWASP checklist, since scanners cover almost none of it.
- `tdd` now prefers a real running database over a mocked repository where behaviour touches
  persistence, with `verify.test_integration` in the profile and a reference section on what only a
  real database catches: constraints, transactions, precision, concurrency, and query correctness.
- Thin-image guidance in `setup-deployment`, with the reminder that a file deleted in a later layer
  is still in the image.
- `write-prd`, `write-user-stories`, and `write-plan` now put a PRD's blocking open questions to the
  user as `AskUserQuestion` choices rather than listing them. A question in section 13 goes
  unanswered; the same question as a choice gets settled in seconds.
- A **1.0.0 gate** in the implementation plan: two pilots, one existing service and one greenfield,
  at least one driven by someone other than the author, plus a verified install from a second
  machine. The greenfield pilot is the more likely to fail, because `--from-idea`, `--new`, and
  `gbai new` have never been run at all.

- `gbai new <name> [--stack node|python|go|minimal]`. Creates the directory, initialises git, lays
  down the gbaiutils layer, a CI workflow that fails on a broken build, and a sample test that
  passes. It does not scaffold an application: that belongs to `design-architecture`, after
  `write-prd` has established what is being built.

- `profile.artifacts`, a map from artifact type to where it actually lives. Every skill that reads
  an artifact checks the map before the default path, and `gbai doctor` fails on a mapped path that
  does not exist.
- `project.kind` of `docs`, detected when no stack and no source files are present. `doctor` then
  reports the project as pre-implementation and skips the verify checks instead of failing.
- `gbai new` now names the command to use instead when it refuses a non-empty directory.

- `tests/no-internal-leaks.sh`, which refuses to ship client names, partner names, specific
  repository names, project document identifiers, or developer absolute paths. It found eight leaks
  I had introduced myself, including a client's document identifiers in the profile example that
  ships to every project. Wired into `run-tests.sh` and CI.

- `templates/profile.schema.json`, documenting why each field exists rather than only its type.
- The plugin-less nudge hook, committed into each project by `gbai init` and `gbai new`. Silent when
  the plugin is loaded; names the install command when it is not. Load-bearing per decision 1: with
  skills living in the plugin, it is the only thing telling a session without it that a standard
  exists.
- `gbai doctor` now names a recommended plugin that is not enabled, and warns when `feature-dev` is
  present alongside gbaiutils. Both were specified in `docs/04` and found unwritten by a plan sweep.
- `CONTRIBUTING.md`.

- `skills/incident-response`, the twentieth skill and the one `create-skill` produced. Inverts
  `debug` deliberately: during an incident, restoring service outranks understanding it, and the two
  are sequential rather than in conflict.

### Changed

- Skill body budget split into two bands: 400 words for a single linear path, 600 for skills
  that fan out to subagents or carry multiple modes. The 700 word ceiling is unchanged.
  Reasoning in `docs/05-token-and-memory-design.md`.
- Every path that a skill reads or writes is now expressed against `profile.docs_root` rather
  than a hardcoded `docs/gbai`, so a project whose docs root differs still works.

- `bin/gbai` with `init` and `doctor`, plus `lib/detect-stack.sh` and `lib/merge-claude-md.sh`.
  Detects seven stacks, reads verify commands from what the project declares rather than guessing,
  and leaves a command `null` when the project declares none so a skill knows to ask.
- `hooks/session-start` and `hooks/hooks.json`. The injection is deliberately static, verified
  byte-identical across runs, at roughly 209 tokens.
- `tests/test-gbai.sh`, 25 cases covering detection, rendering, idempotency, marker corruption,
  the gitignored docs root, profile preservation, and every doctor check.

- `tests/evals/` with a harness and four pressure scenarios: TDD under a deadline, debugging with a
  confident wrong diagnosis supplied, shipping with failures dismissed as flaky, and building with
  no requirements. Each records its baseline behaviour and its pass criteria. Scoring is
  deliberately human, because a grep for the right words is trivially satisfied by an agent that
  then does not do the thing.
- All four evals run and passed, recorded in `tests/evals/results.md`. Each produced an argument the
  skill did not have, and three were added: a counter to "the suite is green, do not touch it", a
  section on how a reported symptom refutes a supplied diagnosis, and a section on why "they are
  flaky" is not an override on money code.

### Added, from a second round of review feedback

- `skills/gbai/references/asking-questions.md`, one shared convention for every question this
  tooling asks, replacing six skills that each described it slightly differently. The rule that
  prompted it: **a multi-select question marks no option `(Recommended)`.** With several valid
  answers the label reads either as "pick this one", contradicting the question, or as "include
  this one", which says nothing about the rest, and marking one of several valid options implies
  the unmarked ones are wrong. The most appropriate option goes first and the order carries it,
  which cannot be misread and stays true when the user picks three of four.
- Open questions are now surfaced as choices wherever they arise, not only in `write-prd`.
  `design-architecture`, `write-plan`, `write-user-stories` and `execute-plan` all put blocking
  questions to the user, and the PRD, design and plan templates say the section is the record
  rather than the mechanism. A question filed in a table at the end of a long document is read
  past, and returns three weeks later as an assumption.
- `gbai init` writes permission guardrails into the committed `.claude/settings.json`: `deny`
  rules for secrets, `ask` rules for destructive commands. It sets
  `permissions.defaultMode: "bypassPermissions"` in `.claude/settings.local.json` and adds that
  file to `.gitignore`.

  The split is the point. A committed file that sets `bypassPermissions` turns off every prompt
  for anyone who clones the repository before they have read a line of it, so the mode is
  per-developer and the guardrails are shared. It works because `deny` and `ask` still apply once
  prompts are off while `allow` does not, meaning protection written as an allowlist would be
  decorative. Verified against a live session rather than taken from the documentation: a denied
  `Read` of `.env` and an asked `git clean -fd` both held while an ordinary write went through
  unprompted. `doctor` now fails when the guardrails are missing and when the local file is not
  ignored. `init` never overwrites the local file, which accumulates a developer's own allow rules.

### Fixed

- `gbai` invoked through a symlink resolved its own installation to the symlink's directory, because
  `dirname` does not follow links. It then lost `lib/`, `templates/` and `VERSION`, and continued
  running into undefined functions rather than stopping, so the failure presented as a defect in the
  project being configured. It now walks the link chain, and refuses to start when its own files are
  not beside it. Found on the first real install, which is also the documented one: a symlink into a
  directory on PATH.
- Documented that a session started by the VS Code extension ignores `permissions.defaultMode`
  from every settings file and resolves its own, which is why setting the mode by hand appeared to
  do nothing. It needs `claudeCode.allowDangerouslySkipPermissions` and
  `claudeCode.initialPermissionMode` in VS Code user settings, neither of which a repository can
  ship. `doctor` warns when the extension is installed and the setting is absent, because
  otherwise the project simply runs in a different mode than it asked for and nothing says so.
  Not a gbaiutils defect, but indistinguishable from one until you know.
- The install instructions omitted putting `gbai` on PATH at all. A Claude Code plugin does not
  extend PATH, so the two `/plugin` commands deliver every skill and no CLI, and the first
  `gbai init` reports `command not found`. Both halves are now documented as halves, along with
  installing the marketplace from a local clone, which needs no credentials.

### Changed

- `gbai doctor` no longer checks `gh`. It reported that `gh` was needed to install from the private
  marketplace, which is false, so it sent people to install a tool they did not need. It now checks
  whether the gbaiutils marketplace is registered on this machine, which is what actually decides
  whether a session has any skills, looking in both `CLAUDE_CONFIG_DIR` and the default directory
  because they can differ and either may be live. Advisory, for the same reason the `gh` check was
  advisory: a CI runner has neither and is a legitimate state.
- `gbai init` refreshes `profile.gbaiutils_version` on every run. It is the one field the tool owns
  rather than the human, and letting the existing value win froze it at the version of the first
  init, which made "has this project been re-initialised since the upgrade?" unanswerable. Every
  other value in the profile still belongs to the human. `doctor` warns when a project trails the
  installed version.

### Corrected

- **The private-repo install works, and does not need `gh`.** Previously recorded as the one
  unverified assumption in the design. `/plugin marketplace add gbi-solutions-ltd/gbaiutils` has
  now been run: it clones over **HTTPS** and authenticates through the ordinary git credential
  helper, `osxkeychain` here. `gh auth login` is one way to populate that helper and not a
  requirement. The earlier claim came from assuming the plugin system would reach GitHub the same
  way this repository's own remote does, which is an SSH host alias. Installing from a second
  machine is still worth doing, but as a check on one engineer's credentials rather than on
  whether the mechanism works.
- The claim that a marketplace added from a local path "points at your working tree and picks up
  edits on the next session" is withdrawn: an installed plugin is a **copy** under
  `~/.claude/plugins/cache/`, keyed by version, whatever source it came from. Editing the clone
  does not change an installed plugin. See the upgrade path in the README.

### Known gaps
- 20 skills built, the last produced by `create-skill` itself.
- One scenario per skill is evidence, not proof. No scenario yet combines pressures, which is where
  discipline skills usually break.
- The artifact-producing skills (`repo-snapshot`, `write-plan`, `design-architecture`) have no
  evals; they were tested against real repositories instead, which is weaker evidence.
- `write-prd`'s `from-idea` and `revise` modes, and `design-architecture`'s `new` and
  `existing` modes, are written but never run.
