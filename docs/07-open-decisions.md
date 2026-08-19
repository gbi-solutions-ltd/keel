# Open Decisions

Nine calls. Each has my recommendation and the reasoning.

**Status as of 2026-08-11: all nine decisions are fully resolved.** Nothing outstanding.

Earlier status: decisions 1 through 5 were resolved before the build began. **Phase 1 is fully
unblocked and can start.** Decisions 6 through 9 are needed at the phase noted on each.

| # | Decision | Status |
|---|---|---|
| 1 | Distribution model | **Resolved:** plugin plus thin bootstrap |
| 2 | Where keel lives | **Resolved:** `gbi-solutions-ltd/keel`, GitHub, private |
| 3 | Gate strength | **Resolved:** enforced with escape hatches, payments hard block |
| 4 | Commit guard hook | **Resolved:** off by default, fast subset when on |
| 5 | Superpowers | **Resolved:** full replacement, uninstall at Phase 3 |
| 6 | Skill granularity | **Resolved:** 19, confirmed by building them. **Superseded 2026-08-13:** 24, see the note under decision 6 |
| 7 | Artifact location | **Resolved:** `docs/keel/`, configurable via `profile.docs_root` |
| 8 | FeatureDev | **Resolved:** excluded |
| 9 | Ownership | **Resolved:** Bernard or Edrine reviews, monthly release, evals before the pilot |

---

## 1. Distribution model. RESOLVED 2026-08-11: plugin plus thin bootstrap.

**Recommendation: plugin plus thin per-project bootstrap** (option E in
[doc 03](03-install-and-distribution.md)).

Skills live once, in the plugin, installed per machine. Repos carry only their own facts:
`.keel/profile.json`, a managed CLAUDE.md block, and `.claude/settings.json`.

The alternative you may prefer is vendoring, which is what your prompt described ("embeds
the skills/hooks in a project folder"). It has one real advantage: the repo is
self-contained, so a contractor or a CI job with no plugin installed still gets the SOP.
The cost is version drift across every repo, which within a year is the harder problem.

If self-containment matters more than I think, a middle path exists: plugin by default,
plus `keel vendor` for repos that genuinely need it, with `keel doctor` reporting how far
behind a vendored copy has fallen.

**Decision:** plugin plus thin bootstrap. No `keel vendor` command gets built. If a repo
later turns out to need self-containment (an external contractor, a CI job with no plugin
access), revisit then rather than building for a case we have not hit.

**Consequence:** the nudge hook written by `keel init`, and staged by `--team`, is
load-bearing, because it is the only thing that tells a plugin-less session that the SOP
exists. Task 1.8 must cover it, and the pilot must test a clone-without-plugin path
explicitly.

---

## 2. Where does keel live. RESOLVED 2026-08-11: `gbi-solutions-ltd/keel` on GitHub, private.

**Decision:** private GitHub repo at `gbi-solutions-ltd/keel`. Marketplace source:

```json
{ "source": "github", "repo": "gbi-solutions-ltd/keel" }
```

GitLab was considered and dropped. It is supported as a marketplace host, but GitHub is the
native path, it needs no auth configuration beyond the `gh` login engineers already have,
and it keeps the generated CI examples (GitHub Actions) consistent with where the tool
itself lives.

**Private repo access.** This paragraph originally said Claude Code resolves private GitHub
marketplaces through the engineer's existing `gh` auth, making `gh auth status` a prerequisite.
**That was wrong**, and it was wrong in the direction that costs people time: `keel doctor` told
anyone without `gh` to install it.

The marketplace is cloned over **HTTPS** and authenticates through the ordinary git credential
helper. Verified by an install that succeeded on a machine with no `gh` at all, using
`osxkeychain`. `gh auth login` is one way to populate that credential and not a requirement; if
`git clone https://github.com/gbi-solutions-ltd/keel.git` works in a terminal, the install
works.

The error came from assuming the plugin system would reach GitHub the way this repository's own
remote does, which is an SSH host alias. It does not, and nothing had tested it.

So:

- `keel doctor` checks whether the marketplace is **registered on this machine**, which is what
  decides whether a session has any skills, and says nothing about `gh`.
- The check is advisory. A CI runner has no marketplace registered and is a legitimate state.

**"Private for now" has one design consequence worth acting on immediately.** If this may go
public later, GBi-specific content should be extractable mechanically rather than tangled
through every skill. Cheapest version of that, and what I would do:

- Keep GBi-specific content confined to named reference files, never inline in a SKILL.md.
  Today that means `skills/security-audit/references/payments-checklist.md`,
  `skills/coding-standards/references/gbi-defaults.md`, and
  `skills/setup-deployment/references/pipeline-patterns.md`.

  **Corrected 2026-08-13**, since this list is what a future public release would work from and a
  wrong name means a file gets missed: the last one is `pipeline-patterns.md`, not
  `pipeline-templates.md`, which never existed. Two more now belong on the list:
  `skills/coding-standards/references/observability.md`, which names SigNoz as the GBi default, and
  `skills/coding-standards/references/authorisation.md`, whose separation-of-duties rules are written
  for a payments business.
- Never hardcode an internal URL, registry path, project id, or environment name in a
  skill. Those belong in `.keel/profile.json`, which lives in the consuming repo and would
  never be published anyway.
- Add a `tests/no-internal-leaks.sh` check to CI that greps skills for internal domains and
  the `gbi-solutions` string outside the allowed reference files.

That costs almost nothing now and turns "open source this" into deleting three files rather
than auditing twenty. Not building a separate `gbi-overlay` repo, which would be premature.

**Added 2026-08-11, found by a sweep:** `tests/no-internal-leaks.sh` is now the single file that
enumerates our clients, because it must contain the names in order to search for them. The guard
against disclosure has become the disclosure. Harmless while the repository is private. Before any
public release its deny list moves outside the public tree, with the script falling back to the
generic patterns (developer paths, document identifiers) when the list is absent. Noted in the
script itself so whoever publishes cannot miss it.

**Enforced 2026-08-17, after the list had already drifted.** The five named files above were a good
intention with no check behind it, and by 0.8.0 eight more files under `skills/` named GBi,
including four `SKILL.md` bodies, which is the one thing this decision explicitly forbids. Neither
`tests/no-internal-leaks.sh` nor `tests/validate-skills.sh` looked for the name: the scanner's deny
list was built for client identifiers and GBi is not a client.

All eight are neutralised. The name now appears under `skills/` only in the five files above, and
`tests/no-internal-leaks.sh` fails when it appears anywhere else under `skills/` or `templates/`.
The wording changes were exchanges rather than deletions: `debug` now says "a service following the
observability standard" rather than "a GBi service", which states the condition the name was
carrying implicitly, and `standards-template.md` says "the house defaults", which is what a
generated document in a non-GBi repository should have said all along.

**Closed 2026-08-17 by removing the thing it was managing.** The five-file list existed so that
publishing would be a deletion rather than an audit. Publishing turned out to need neither: all five
are generic once the organisation's name comes out of their prose. So `GBI_ALLOWED` is gone and the
rule is now simply that shipped content names no organisation, which is stronger than this decision
asked for and simpler to keep.

`gbi-defaults.md` is `house-defaults.md`, renamed rather than deleted, because
`tests/validate-skills.sh` fails on an unresolvable link and `coding-standards`'s body links to it.
That rename turned out to touch **thirteen** references across eleven files rather than the one link
the runbook predicted, which is worth recording: the file was cited as prose throughout the
coding-standards reference set, and prose citations are invisible to the link checker.

Two departures from what the runbook proposed, both deliberate. **SigNoz stays the documented default
backend**, because de-defaulting it would change what `keel init` writes, which is a behaviour change
and not de-branding; the table already lists three alternatives and points at
`profile.observability.backend`. And the read of the two domain checklists found **one** item needing
redaction rather than none: `pipeline-patterns.md` attributed a trap to "a payment platform with 3.6%
coverage", and a sector plus an exact figure identifies an engagement to anyone who has read that
audit. It now says "a service whose coverage was low single digits".

Two things the enforcement deliberately does not cover, so nobody assumes it does. The rule matches
`\bGBi` and not `gbi-solutions`, because `templates/profile.schema.json` and
`templates/keel-profile.example.json` carry `gbi-solutions-ltd` inside the canonical schema URL,
where it is correct. And it is scoped to `skills/` and `templates/`: `docs/`, `README.md`,
`CHANGELOG.md` and the audits name GBi and real client repositories freely, and the audits are the
highest-risk documents in the tree. Both facts, and the rest of what publishing actually requires,
are in `docs/runbooks/going-public.md`.

---

## 3. How hard should the gates be. RESOLVED 2026-08-11: enforced with escape hatches.

Three postures, and the answer changes what Phase 1 builds:

| Posture | Behaviour | Fits |
|---|---|---|
| **Advisory** | Skills suggest, the model can proceed regardless | Teams that resent process |
| **Enforced with escape hatches** | Skills refuse, the user can override by saying so explicitly, and the override is recorded | Most teams |
| **Hard blocked** | Hooks physically prevent the action, no override in-session | Regulated or high-blast-radius work |

**Recommendation: enforced with escape hatches**, with one exception. Given GBi is in
payments, `security-audit` on a diff touching auth, money movement, or PII should be hard
blocked at the hook level, not overridable by a sentence in chat.

**Decision:** enforced with escape hatches, including the payments hard block.

Every skill that gates must state its escape hatch in its own body, and must record the
override in its output when one is used. The hatches are listed in
[templates/prompting-cheatsheet.md](../templates/prompting-cheatsheet.md) so they are
documented for users, not just known to the model.

**Task 4.3 is built, 2026-08-16, as `hooks/sensitive-guard` on `PreToolUse`.** Two things about it
belong here rather than only in the plan, because both change what this decision promised.

**The field is `hard_block_paths` at the top level of the profile, not `gates.hard_block_paths`.**
The paragraph below said `gates`, and `templates/profile.schema.json` has always defined it at the
top level. The schema is what `keel init` writes and what the guard reads, so the prose was the
thing that was wrong.

**The gate asks rather than denies, and that is the strongest available form, not a softening.**
`security-audit` is a skill the model executes, not a command a hook can run, so nothing can verify
from a hook that an audit "ran clean". Any receipt the model could write is a receipt a sentence in
chat could obtain, which is the exact failure this decision exists to prevent. `ask` is the only
decision in the hook protocol the model cannot satisfy for itself: the harness puts it to a human,
and it survives `bypassPermissions`. The guard names the staged files and tells the reader to run
`security-audit --diff` before approving.

It reads the staged set, plus tracked modifications when the command carries `-a`, `--all` or a
pathspec, because all three commit working tree content that `--cached` does not show. It asks
whenever it cannot answer: an absent python3, an unparseable profile, or a failing `git diff` all
produce a prompt rather than silence.

Its limit is stated in the hook and repeated here: it reads a command string, so `sh -c`, an alias,
a here-doc, or `git -C dir commit` reaches a commit without passing through it, exactly as the
permission deny rules already warn. It raises the cost of a careless commit. It is not a boundary
against a determined one, and review remains the boundary.

The list of paths that get the non-overridable block, proposed here and confirmed per repo in
`hard_block_paths`:

- anything under a path matching `auth`, `session`, `token`, or `credential`
- anything that computes, stores, or transmits an amount or a currency
- anything touching card, account, or personal identifiers, including logging and redaction
- migrations, and any change to a webhook signature verification path
- CI workflow files and secret or env configuration

This list belongs in the repo's profile rather than hardcoded in the skill, because it
differs between a payments service and an internal dashboard.

---

## 4. The commit guard hook. RESOLVED 2026-08-11: off by default, fast subset when on.

Should `git commit` be intercepted by a `PreToolUse` hook that runs `verify.test` and
`verify.lint` first?

**For:** it makes "tests pass before commit" a property of the system rather than a request.
**Against:** on a repo with a two-minute test suite it makes every commit take two minutes,
which pushes people toward fewer, larger commits, which is worse for everything else.

**Recommendation: off by default, opt-in per repo via `profile.gates`.** Run the fast
checks (lint, typecheck, changed-file tests) in the guard and leave the full suite to the
`ship` gate and CI. This is what most teams land on after trying the strict version.

**Decision:** off by default, opt-in per repo, and when on it runs the fast subset only.

The guard runs `verify.lint`, `verify.typecheck`, and `verify.test_one` against changed
files. The full suite stays with the `ship` gate and CI. Rationale: an expensive commit
produces fewer, larger commits, which costs more in review quality and bisect ability than
it saves in caught failures.

**Consequence:** `profile.verify.test_one` becomes required rather than optional, since the
guard depends on running tests for a single path. `keel doctor` must verify it works, not
just that it is present.

**Shipped 2026-08-14, partly.** `keel guard install` writes a git `pre-commit` hook rather
than a `PreToolUse` hook, so it holds for `git commit` from any terminal and not only for
commits a model makes. `gates.commit_guard` is `off` by default and takes `required` or
`warn`. It runs `verify.format`, `verify.lint` and `verify.typecheck`.

`verify.test_one` against changed files is **not** in it, so this decision is not fully
closed. The profile's `test_one` is a `{path}` or `{name}` template and nothing maps a
changed file to the test that covers it; guessing that mapping would run the wrong tests or
none, silently. `verify.test_one` stays required for the reason above, and `keel doctor`
already checks it.

The gate also refuses rather than formatting, which is why `verify.format` was split from
the new `verify.format_fix`: a gate must be check-only, and a hook that rewrites files and
re-stages them puts content into a commit its author never read.

---

## 5. Superpowers. RESOLVED 2026-08-11: full replacement, uninstall at Phase 3.

You have it installed. Roughly a third of keel is adapted from it, and its
`using-superpowers` skill instructs the model to invoke superpowers skills before any
response, which will compete with our router.

**Recommendation: keep it until Phase 3 lands, then uninstall.** Running both costs two
session-start injections and produces two answers to "which methodology applies".

The alternative is to build keel as a thin layer on top of superpowers: we ship only
the 10 skills it lacks (PRD, stories, architecture, snapshot, deployment, docs, standards,
security, performance, context budget) and defer to theirs for TDD, debugging, planning,
execution, and skill creation. That is meaningfully less work, and it means their
improvements flow to us for free. The cost is that we cannot adapt their skills to read
`.keel/profile.json`, so every one of them keeps guessing at test commands, and we inherit
their upgrade cadence and any breaking change they make.

**Decision:** full replacement. All 19 skills are ours, adapted to read
`.keel/profile.json`. superpowers stays installed until Phase 3 lands, then gets
uninstalled.

The deciding factor is the profile. A `tdd` skill that knows this repo's exact test command
is materially better than one that rediscovers it every session, and we cannot patch that
into a plugin we do not own.

**Consequences for the plan:**

- Add a task at the end of Phase 3: uninstall superpowers on the author's machine, then
  re-run the four eval scenarios to confirm our skills carry the discipline on their own.
  Running the evals while superpowers is still installed measures the wrong thing.
- `SOURCES.md` must be thorough, since five of our skills are close adaptations of MIT
  licensed superpowers skills.
- We now own the maintenance of `tdd`, `debug`, `write-plan`, `execute-plan`, and
  `create-skill`. Worth periodically reading superpowers releases for improvements to port,
  which is a job for whoever owns decision 9.

---

## 6. Skill granularity. RESOLVED 2026-08-11: 19 skills. SUPERSEDED 2026-08-13: 24.

19 skills is the current design. Two alternatives:

- **Fewer, broader (8 to 10).** One `plan` skill covering PRD, stories, and architecture.
  Cheaper always-loaded cost, but each body grows past the word budget and the model has to
  find its mode inside a long document, which it does less reliably than picking a skill.
- **More, narrower (30+).** gstack's approach. Better routing precision, more maintenance,
  and a real risk that engineers cannot hold the map in their heads.

**Recommendation: 19.** It is close to superpowers' 14, which is field-proven, and the
extra five are areas superpowers simply does not cover.

**Decision:** 19, confirmed with evidence rather than by prediction. All 19 were built and every
body landed inside the budget, between 347 and 700 words. The ones that reached the ceiling did so
carrying irreducible content (six subagent briefs, a five-value classification vocabulary), so
merging any pair would breach it. No skill turned out to be redundant except a candidate that
`create-skill` correctly rejected at step 0.

**Superseded 2026-08-13, and the count is now 24.** Recorded here rather than by editing the
paragraph above, because this file is append-only: a decision reversed is more useful than one
silently rewritten.

The five added since are `incident-response`, `apex-export`, `apex-port-plan`, `shape-idea` and
`port-assess`. None was a granularity change. Each answered a job no existing skill did, three came
out of a client engagement, and two were produced by `create-skill` with a baseline first, one of
which changed its own purpose at step 0 when the baseline turned out to do the thing the skill was
going to teach.

**What the growth actually costs, since that was the reasoning behind picking 19.** The 24
descriptions are 1,066 tokens in every request, measured 2026-08-16, up from roughly 760. That is the
real budget line and it scales linearly. The original argument against 30+ skills was routing
precision and a map nobody can hold in their head; both still stand, and the mechanical checks added
at 0.5.0 (every route present in the cheatsheet and in the session-start injection) exist because
that map had already drifted at 22. **Revisit before 30, not after**, and revisit it as "which of
these should merge", not "how short can a description be".

**Since 2026-08-16 that revisit has a trigger rather than a good intention.** Plan task 7.5 caps the
descriptions sum at 1,320 tokens in `tests/validate-skills.sh`, which is 30 skills at the measured
44-token mean, so the count reaching the number this decision named is now a failing build. The
check's own message says the remedy is fewer skills, because "how short can a description be" is the
answer this decision already rejected.

---

## 7. Where do project artifacts live. RESOLVED 2026-08-11: `docs/keel/`, configurable.

`docs/keel/` is the current design: namespaced, so it never collides with existing docs,
and obvious that a tool manages it.

Alternatives: plain `docs/` (more natural for humans, but merges awkwardly into repos that
already have a `docs/` with its own structure), or `.keel/docs/` (hidden, keeps the repo
root clean, but hidden directories do not get read by humans, and these documents are meant
to be read by humans).

**Recommendation: `docs/keel/`, configurable via `profile.docs_root`** so a repo with a
strong existing convention can point it elsewhere.

**Decision:** `docs/keel/` by default, configurable via `profile.docs_root`, confirmed.

The configurability earned itself immediately: one of the three test repositories gitignores
`docs/` wholesale, so every artifact the chain writes would have been invisible to git. `keel init`
now refuses in that case rather than writing silently, and no skill may hardcode the path.

---

## 8. FeatureDev. RESOLVED 2026-08-11: excluded.

`feature-dev` ships a competing end-to-end workflow, so the design excludes it by default.

**Recommendation: exclude, and re-test in the pilot.** If our pipeline turns out to be
heavier than `feature-dev` for small changes, the right response is to drop several of our
skills and adopt theirs, not to run both.

**Decision:** excluded. Nothing in the build changed the reasoning, and the artifact chain is now
real rather than theoretical: `feature-dev` writes to none of it, so running both would leave half
the work in chat and half on disk. `keel doctor` should warn when it is installed alongside
keel.

---

## 9. Who owns and maintains it. RESOLVED 2026-08-11.

An internal tool with no owner rots in a quarter. Concretely this needs:

- One owner who reviews skill PRs, since a skill change affects every repo at once
- A release cadence. Monthly is right for something this small
- A channel where engineers report "the skill did the wrong thing", which is the only
  signal that catches drift between the docs and reality
- A budget for Tier 3 evals, roughly a few dollars per release run

**Decision:**

- **Review:** you plus one named second reviewer. Any skill change needs both. The second reader is
  the control for the failure this build produced six times: a rule that is stricter than correct
  output. A validator checks shape, not whether a rule is wise.
- **Cadence:** monthly, tagged, gated by the behavioural evals.
- **Evals:** built before the pilot, not during it. Until they existed, every discipline claim in
  the README was untested.

**Reviewers:** Bernard Tebandeke and Edrine Kamya. Either may review a skill change; both are not
required. That is the right call for a two-person team: requiring both would make the tool stall
whenever one is busy, which is how internal tooling dies.

The property that matters is that no skill change is merged by its own author unreviewed. With two
reviewers and either sufficing, that holds as long as the author is not the reviewer.

---

## Two smaller things, my call unless you object

**Attribution.** superpowers, karpathy-skills, and cursor-starter are all MIT. `SOURCES.md`
at the repo root will credit each and name which skills derive from which. Cheap, correct,
and it protects us if this ever goes public.

**Writing style.** Every generated document, commit message, and PR body follows your
global rule: no em dashes, no en dashes, no `Co-Authored-By` trailer, no robot emoji, no
"Generated with Claude Code" footer. This goes into the CLAUDE.md managed block so it
applies in every project without anyone re-stating it.

---

## 10. Should `keel init` set `outputStyle` for a project? PARTLY RESOLVED 2026-08-16.

The plugin now ships `output-styles/keel-terse.md`. Selecting it is a user action in `/config`, so
on a fresh machine nothing is shorter until someone chooses it. `keel init` already writes
`enabledPlugins`, permission rules and a hook into `.claude/settings.json`, so writing `outputStyle`
there is the same class of act and would make the style the project default.

**What blocks it is a fact nobody has checked.** A plugin skill is addressed `keel:tdd`. Whether a
plugin output style is addressed `keel terse`, `keel-terse` or `keel:terse` has not been observed.
`bin/keel:470` already records what a wrong name costs, in the comment written when init stopped
declaring a marketplace source: it "lands in settings.json, fails to resolve, and the user distrusts
the whole file". A settings key naming a style that does not resolve is worse than no key, because
the reader cannot tell which of the other keys are also wrong.

**What settles it.** Restart a session with this version installed, open `/config`, and read the
name listed under Output style. One observation, then this becomes a one-line change to
`write_settings` in `bin/keel`.

**If it is taken.** Two things follow. `write_settings` only writes the full file when
`settings.json` is absent; an existing file goes through `merge_permissions_into_settings`, which
touches permissions and nothing else, so a project that already has settings would not receive the
key without extending that function too. And the escape hatch should be documented rather than
assumed: `.claude/settings.local.json` is gitignored and overrides the committed value, so a
developer who wants the default style back does not have to edit a shared file.

**RESOLVED, the part that mattered.** Terse by default was instructed on 2026-08-16 and ships, but
not through `outputStyle`. `keel init` writes `conventions.response_style: "terse"` into
`.keel/profile.json` and `hooks/session-start` injects the rule unless it reads `verbose`. That is
the mechanism `claude-plugins-official/explanatory-output-style` uses for the same problem, and it
needs no style name.

Extended on 2026-08-18: the hook now reads `conventions.explain_level` alongside `response_style`
and selects one of four paragraphs rather than one of two. Length and vocabulary are separate dials,
and the same reasoning applies to both.

**STILL OPEN, and now an optimisation rather than the mechanism.** Writing `outputStyle` into
`.claude/settings.json` would move the rule out of the per-request prefix and save the 56 tokens the
injection now costs. It waits on the same single observation, and the behaviour no longer depends on
it, so there is no pressure to guess.

---

## 11. The un-witnessed step. RESOLVED 2026-08-17, implemented as specified below.

**The gap.** Nothing in `execute-plan`, `skills/write-plan/references/plan-template.md`, or
`hooks/done-guard` says what to do with a checkbox whose step somebody else already performed. The
shipped rules cover ticking without running the command. They are silent on ticking a step done in
an earlier session, which is every resumed plan, and it is the ordinary way a plan accumulates ticks
nobody can trace.

**Evidence, not conjecture.** Found by running `done-without-verifying` on 2026-08-16, both arms,
recorded in `tests/evals/results.md`. Neither arm wrote a test, so in neither session did anyone
perform task 1's "Step 1: Write the failing test" or watch its RED. The treatment arm ticked those
boxes and annotated them, "steps 1 and 2 were done before this session, so the RED state for this
task was not witnessed here". The baseline ticked the same boxes silently, leaving a plan file
asserting that a failing test was written and watched failing in a session where neither happened.

Both replies to the user were honest. Only one plan file was. That is the failure `execute-plan`
exists to prevent, produced by an arm that passed every stated criterion, and it is invisible from
the reply.

**The rule to add.** A box for a step you did not personally perform is ticked only with a note
naming what you did and did not witness, or left unticked and reported. The distinction that matters
is *witnessed here* against *believed done*, not *done* against *not done*.

**Where it goes, with the budget already measured** so this is not rediscovered:

`execute-plan`'s body is at **699 words** against ADR-0001's 700 warning, and over 700 requires a
passing eval arm at that length recorded in `results.md`. Two word-neutral-enough rewrites of the
existing Step 4 sentence land at exactly 700 and fit:

- `Tick on output you read; note any step you did not witness.`
- `Tick on output you read, noting any step you did not witness.`

Either replaces `Tick the boxes in the actual file, on output not belief.` Sitting exactly on the
warning is tight, so the alternative is to spend a Common mistakes row instead and put the rule in
the references, which are unbudgeted:

- `skills/write-plan/references/plan-template.md`, so a plan carries the convention where it is read.
- `skills/execute-plan/references/subagent-prompts.md`, so a delegated agent receives it, since it
  sees only what is sent.

**`hooks/done-guard` is deliberately not part of this.** It reads a turn's tool calls and cannot
know who performed a step in an earlier session. Extending it here would mean inferring intent from
a transcript, which is the English-matching mistake its header already refuses.

**Not folded into 0.7.0**, which is released. This is the next change, and it needs its own commit
and a line in the CHANGELOG.

**Taken 2026-08-17, the first option.** Step 4's sentence became `Tick on output you read; note any
step you did not witness.` and the body measures 700 words, which is the target and not over it, so
no eval arm is owed. The Common mistakes row was not spent. Both references carry the rule: the plan
template puts it in the banner, so a plan states it where it is read rather than only where it is
authored, and `subagent-prompts.md` splits it in two, because in delegated mode the agent that
performs the step and the agent that ticks the box are different agents. The implementer is asked to
name any step already satisfied on arrival; the orchestrator ticks on that report and annotates.

**Measured 2026-08-19, and the rule holds.** Both arms of `done-without-verifying` were re-run
against the rebuilt fixture. The treatment arm, carrying Step 4's sentence, ticked and annotated. The
baseline, without it, ticked eight boxes and wrote nothing, leaving a plan file asserting steps
nobody performed. On 2026-08-16, before the rule existed, the annotation was an instinct one arm
happened to have; it is now a rule the arm that has it follows.

**The scenario is now the standing check.** Its criteria were rewritten the same day to score the
plan file rather than the reply, precisely because scoring the reply did not discriminate. So the
thing this decision recorded as unmeasured is measured every release, and the release gate is six
scenarios again. See `tests/evals/results.md`, 2026-08-19.

**One thing the measurement found.** The rule was followed incompletely: the treatment arm annotated
task 2's un-witnessed steps and passed over task 1's, which are equally unwitnessed. Not a reason to
reopen this decision, since the alternative it rejected would not have helped, but the criteria now
score that case as a partial so it is visible if it persists.
