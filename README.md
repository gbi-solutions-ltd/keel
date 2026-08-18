# keel

GBi's standard operating procedure for AI-assisted software delivery, packaged as a
Claude Code plugin plus a thin per-project bootstrap.

**Status:** installable, 24 skills built, `keel` CLI and session hook working. **Not 1.0.0:**
that needs two pilots and a verified install from a second machine. See the gate in
[`IMPLEMENTATION-PLAN.md`](IMPLEMENTATION-PLAN.md).

## Install

```
/plugin marketplace add gbi-solutions-ltd/keel
/plugin install keel@gbi
```

That is the whole install. The skills, the session hook and the `keel` CLI all arrive with the
plugin: a plugin's `bin/` directory is added to the PATH that Claude Code's Bash tool uses, so
after restarting the session `keel version` in a Claude Code shell prints the VERSION file.

The marketplace is cloned over HTTPS, so nothing needs configuring and `gh` is not required. The
repository was private until 2026-08-17 and the install worked the same way then, through the
ordinary git credential helper.

A local path is also accepted, `/plugin marketplace add /absolute/path/to/keel`, which is
useful with no network. It is **not** a live view of your working tree: see Upgrading.

Then, in each project:

```
keel init                        # existing project: detect the stack, write the profile and block
keel new <name> --stack node     # new project: scaffold, git init, CI, a passing sample test
keel doctor                      # check either, non-zero on any problem
```

`init` is idempotent and never overwrites a value you have corrected by hand; detection is a
starting point, not an authority. Use `--force` to overwrite deliberately.

`doctor` runs the whole suite plus its own checks and takes around eleven minutes, silent for most
of them. It is slow, not hung. The 2026-08-17 perf work made the suite 81 seconds faster and left
`doctor` where it was, because its time goes on running each verify command rather than on reading
the profile.

### Optional: `keel` in your own terminal

The plugin puts `keel` on the Bash tool's PATH, not your login shell's. Nothing in the pipeline
needs it there, so do this only if you want to run `keel doctor` outside Claude Code:

```
ln -sfn ~/.claude/plugins/cache/gbi/keel/<version>/bin/keel ~/.local/bin/keel
keel version                                                  # must print the VERSION file
```

**That cache path is keyed by version and changes on every upgrade.** If you want a link that
survives upgrades, point it at a clone instead and keep the clone current with `git pull`.
Symlinking either way is supported and tested: `keel` resolves its own installation through the
link. If it prints `incomplete install`, the link points somewhere without the full repo beside it.

### Replies are short by default

Conversation replies are brief; **artifacts are not**. A PRD, plan, ADR or audit stays exactly as
detailed as its skill requires. What gets cut is the chat restating them.

This is on by default in every keel project. To turn it off, set `verbose` in `.keel/profile.json`:

```json
"conventions": { "response_style": "verbose" }
```

`keel init` writes `"terse"` there so the key is visible rather than implied, and a project with no
key at all is treated as terse, so this applies without re-running `init`.

### Replies can be plain as well as short

Length and vocabulary are separate dials. Where somebody who is not a developer reads the replies,
set `plain` in `.keel/profile.json`:

```json
"conventions": { "explain_level": "plain" }
```

A plain reply defines a technical term the first time it uses it, rather than swapping it for a
simpler word: the reply still has to point at an artifact that uses the real term. `technical` is
the default and is what `keel init` writes. This changes replies only. Artifacts stay technical
whatever it says, and it composes with `response_style`, so all four combinations are valid.

The plugin also ships an output style, **keel terse**, selectable in `/config` under **Output
style**. That one is machine-wide rather than per-project, so it is the option for non-keel
repositories. It is not required here and nothing sets it for you.

## Upgrading

Two layers always, and a third only if you made the optional symlink. Forgetting the per-project
layer is the common failure: the skills change, the per-project files do not, and `doctor` starts
reporting things the project never got.

| Layer | Lives in | Picks up a change by |
|---|---|---|
| The plugin: skills, hook, and the `keel` CLI | A **copy** at `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` | `/plugin marketplace update gbi` then `/plugin install keel@gbi`, then restart the session |
| Per-project files | Each repo's `.claude/` and `.keel/` | `keel init` in that repo |
| An optional terminal symlink, if you made one | Wherever you pointed it | Re-point it at the new version directory, or point it at a clone and `git pull` |

```
/plugin marketplace update gbi        # fetches the new version
/plugin install keel@gbi              # installs it, then restart the session
cd /path/to/your/project && keel init # updates that project's files
keel doctor
```

**An installed plugin is a copy, not a link.** That is true of a marketplace added from a local
path as much as from GitHub, so editing your clone changes nothing in an installed session. The
cache is keyed by the version in `.claude-plugin/plugin.json`, which is why every change that
should reach an installed copy comes with a version bump. A push to `main` on its own reaches
nobody.

**`keel init` is safe to re-run** and is the only way per-project files pick up a change. It
merges: your corrected verify commands, your profile edits, and your accumulated allow rules all
survive. It adds what is missing and leaves the rest alone.

Every key `.keel/profile.json` may contain, what it does, and whether keel writes it or you do,
is listed in [docs/profile-keys.md](docs/profile-keys.md).

`.keel/profile.json` records `keel_version`, so comparing it with `keel version` tells you
whether a project has been re-initialised since the last upgrade.

It also records `schema_version`, and that is the one `doctor` warns on. It moves only when the
profile gains or loses a field, so most upgrades need no re-init and do not ask for one. A profile
written before the field existed has no `schema_version`, which reads as stale and is correct.

### If you work in the VS Code extension

`init` sets `bypassPermissions` for you, but **a session the VS Code extension starts ignores
`permissions.defaultMode` from every settings file.** It resolves its own mode. Add these to your
VS Code user settings, once per machine:

```json
"claudeCode.allowDangerouslySkipPermissions": true,
"claudeCode.initialPermissionMode": "bypassPermissions"
```

The CLI, and JetBrains, need neither. `keel doctor` warns when this applies to you.

Bypassing prompts is safe here because the guardrails do not depend on them: `keel init` writes
`deny` rules for secrets and `ask` rules for destructive commands into the committed
`.claude/settings.json`, and both kinds still apply under `bypassPermissions`. `allow` rules do
not, which is why the protection is written the way it is. See
[doc 03](docs/03-install-and-distribution.md).

## What problem this solves

Today every engineer prompts Claude Code differently, so quality varies per person and
per repo. keel makes the process the default: the same discovery, planning, TDD,
security, review, and shipping steps run on every project, whether it is greenfield or
a ten-year-old service, and whether the engineer remembers to ask for them or not.

## Skills

Built and tested against real repositories. Each skill is developed by running it, not by
writing it and hoping.

| Skill | Status | Tested against |
|-------|--------|----------------|
| [`skills/repo-snapshot`](skills/repo-snapshot/SKILL.md) | Built | A NestJS service (451 files), a Spring Boot service (73), and a 4-workspace monorepo (407) |
| [`skills/apex-export`](skills/apex-export/SKILL.md) | Built | A live APEX 22.2 instance: a 156 page application, all 27 dictionary views resolved, 309 database objects reached three levels deep, zero warnings. Plus Oracle Free 23 in Docker for the client layer, and 39 offline cases against a capture fixture. The live runs found seven bugs no fixture could, including twenty wrong column names and a dependency scan that missed 125 of 169 PL/SQL units. See `CHANGELOG.md` |
| [`skills/apex-port-plan`](skills/apex-port-plan/SKILL.md) | Built | The same application, twice: once against an incomplete export and again after the fix. Produced an assessment that found a production defect in the client's ledger, a savepoint name collision that leaves merchant wallets debited when a settlement fails |
| [`skills/write-prd`](skills/write-prd/SKILL.md) | Built, `from-repo` mode tested | The Spring Boot service, consuming its snapshot. `from-idea` and `revise` modes are unexercised |
| [`skills/write-user-stories`](skills/write-user-stories/SKILL.md) | Built | The same service, consuming its PRD. 19 stories, coverage proved both ways |
| [`skills/design-architecture`](skills/design-architecture/SKILL.md) | Built, `adr` mode tested | The same service. Its 4 `decide` stories produced 4 ADRs. `new` and `existing` design modes unexercised |
| [`skills/write-plan`](skills/write-plan/SKILL.md) | Built | The same service. A 6-task plan from one story and one ADR, using the profile's verify commands |
| [`skills/tdd`](skills/tdd/SKILL.md) | Built | Used for real to build this repo's own skill validator, red then green |
| [`skills/debug`](skills/debug/SKILL.md) | Built | An undiagnosed worker leak in a NestJS suite. Two hypotheses refuted, no fix guessed |
| [`skills/execute-plan`](skills/execute-plan/SKILL.md) | Built | Its refusal gate, against a real plan blocked by an unaccepted ADR. Correctly refused |
| [`skills/coding-standards`](skills/coding-standards/SKILL.md) | Built | This repo. Produced `docs/standards.md` and found a broken lint command in its own profile. Carries 10 topic references: observability, time, resilience, async work, authorisation, rate limiting, API contracts, caching, data protection, frontend |
| [`skills/review-code`](skills/review-code/SKILL.md) | Built | This repo's own last commit. All four project-specific passes ran; suite verified rather than assumed |
| [`skills/security-audit`](skills/security-audit/SKILL.md) | Built | Phase order re-found every known issue in the Spring Boot service, including 6 keystores inside the built jar |
| [`skills/refactor`](skills/refactor/SKILL.md) | Built | Its precondition, against a real target with no tests. Correctly stopped and routed to `tdd` |
| [`skills/optimize-performance`](skills/optimize-performance/SKILL.md) | Built | Its precondition, against a service with no target and no baseline. Correctly refused |
| [`skills/setup-deployment`](skills/setup-deployment/SKILL.md) | Built | Built CI and a runbook for a service that had neither. Its own artifact guard had a bug, caught by testing it |
| [`skills/ship`](skills/ship/SKILL.md) | Built | Its gate, against this repo. Correctly refused on check 8, which found a real departure |
| [`skills/write-docs`](skills/write-docs/SKILL.md) | Built | Replaced a NestJS service's default-template README, every command executed first |
| [`skills/create-skill`](skills/create-skill/SKILL.md) | Built | Describes the loop that produced the other 17. Not yet used to produce one |
| [`skills/context-budget`](skills/context-budget/SKILL.md) | Built | A 38KB always-loaded file. Found a real cache hazard on line 3 |
| [`skills/keel`](skills/keel/SKILL.md) | Built | All 24 routes resolve, the shipped cheatsheet lists every one, and the SessionStart injection names every one. All three enforced by the validator, the last two added after they had already drifted |
| [`skills/incident-response`](skills/incident-response/SKILL.md) | Built | Produced by `create-skill`, baseline first. Its eval passes |
| [`skills/shape-idea`](skills/shape-idea/SKILL.md) | Built | Baseline first, then re-run. The baseline pushed back well and still wrote nothing down, produced a sprint plan for an idea with no requirements, and buried its own strongest objection inside that plan. The skill is built around those four failures, not around teaching pushback |
| [`skills/port-assess`](skills/port-assess/SKILL.md) | Built | Baseline first, then re-run, against a Spring Boot service. Each step came from a real failure: a snapshot describing a different branch, a React half with no source to port from, a Node serialiser dropping nulls so the bytes differed and every signature was rejected, and two runs judging a document from a grep count |

Specifications are in [`docs/02-skill-catalog.md`](docs/02-skill-catalog.md); what remains to build
around them is in [`IMPLEMENTATION-PLAN.md`](IMPLEMENTATION-PLAN.md).

`repo-snapshot` feeding `write-prd` is the first working link in the artifact chain: the
snapshot is read from disk rather than re-derived, so the PRD costs a fraction of what a cold
analysis would.

### Which model runs a delegated brief

Several skills fan work out to subagents. Those briefs name the model, so the wide mechanical
reading does not run on whatever the session happens to be pinned to:

| Brief | Model | Why |
|---|---|---|
| `repo-snapshot`, `port-assess`, `apex-port-plan`, `shape-idea` fan-outs | `sonnet` | Wide mechanical reading over many files, with a cited `path:line` for every claim, so the output is checkable |
| `execute-plan` implementation and both reviews | `inherit` | These write code under the TDD gate or judge another agent's verdict. A cheaper model gets less benefit of the doubt, not more |

The dispatching skill announces the model in one line when it delegates.
`tests/validate-skills.sh` rejects any alias Claude Code does not accept, because a brief sent to a
model that does not exist is a brief sent to nothing and the failure is silent. No brief names a
full model id, which would pin harder and rot faster, and none names `haiku` yet: that waits on one
measured comparison rather than an assumption.

**A session's own model is not part of this and cannot be.** No hook event exposes model selection,
so nothing here can move a session from one model to another; that stays `/model`. There is no
complexity router either, and there will not be one: routing pays on work that is long and
mechanical, not on work that is simple, so a router keyed on guessed complexity is wrong in the
direction nobody notices. The reasoning is in
[`docs/ideas/model-routing.md`](docs/ideas/model-routing.md).

## Tests

```
tests/run-tests.sh           # static: free, seconds, runs on every commit
tests/evals/run.sh <name>    # behavioural: costs API tokens, runs before a release
tests/supply-chain-scan.sh   # refuse to ship anything that runs on an installing machine
```

Plain bash, no dependencies, about four and a half minutes: 270.0s measured 2026-08-17, down from
351.7s. Run it in the background and read the last line. `tests/validate-skills.sh` enforces the frontmatter shape,
the word budgets, the docs-root notation, and that every relative link resolves, in reference files
as well as in skill bodies; `tests/test-validate-skills.sh` proves the validator catches what it
claims, including the false positives that a naive check produces.

Every rule in the validator exists because it was violated during development, usually by
whoever had just written the rule.

`tests/no-internal-leaks.sh` keeps the plugin generic: no client or partner names, no specific
repository names, no developer paths. Examples use `payments-api` and "a partner bank" so nobody
mistakes them for real systems.

`tests/supply-chain-scan.sh` is the one that matters most to whoever installs this. The hooks here
run automatically at session start and the skills are instructions a capable agent follows, so a
hostile or careless line executes on every engineer's machine without anybody invoking anything.
19 pattern rules and 5 structural ones cover pipe-to-shell, decode-and-execute, credential reads,
machine-wide persistence, obfuscated literals, invisible bidirectional characters, unexpected
executables, and skills that tell an agent to ignore its instructions or hide what it did.

It is a denylist, so the check that keeps it honest is `tests/test-supply-chain.sh`, which fails
when any rule stops firing. That test earned its place immediately: two rules were written with an
empty regex alternative that this machine's grep rejects, so both matched nothing while the scan
reported clean and counted them in its total. The scanner now refuses to start on a rule it cannot
compile.

Exceptions are explicit. A line ending `supply-chain-scan: allow <reason>` is skipped, every
honoured suppression prints on every run, and one with no reason is a finding in its own right.

```
keel guard install    # pre-push and pre-commit hooks, repo-local, opt-in
keel scan             # run it by hand
```

The hook refuses a push the scan flags, and a push to `conventions.default_branch`, since work
lands through a pull request. It reads that branch from the profile rather than assuming `main`, and
checks nothing when nothing states it. Set `conventions.protect_default_branch` to `false` in a
project that genuinely pushes to its default branch.

It writes a `pre-commit` hook in the same place, which does nothing until `gates.commit_guard` is
set to `required` or `warn` in the profile. When on it runs `verify.format`, `verify.lint` and
`verify.typecheck` against the commit and refuses rather than reformatting, because a hook that
rewrites files and re-stages them puts content into a commit its author never read.

The guard is opt-in because it sets `core.hooksPath`, which is a change to your git configuration.
It is repo-local: setting that globally would silently disable every other repository's hooks on
the machine.

The evals in `tests/evals/` are the only thing that tests whether a discipline skill changes
behaviour under pressure. The static suite checks shape; a skill can pass it and do nothing.

6 scenarios exist. Five pass and discriminate, last re-run 2026-08-16 after both pilots. The sixth,
`done-without-verifying`, passes in both arms, which means it measures nothing about the skill and
is recorded as an invalid scenario rather than a passing one. Results and the arguments they
produced are in [`tests/evals/results.md`](tests/evals/results.md).

## How to read this repo

Read in order. Each doc is self-contained but they build on each other.

| Doc | What it answers |
|-----|-----------------|
| [`IMPLEMENTATION-PLAN.md`](IMPLEMENTATION-PLAN.md) | What gets built, in what order, with what verification. **Start here.** |
| [`docs/01-architecture.md`](docs/01-architecture.md) | How the pieces fit together and why it is shaped this way |
| [`docs/02-skill-catalog.md`](docs/02-skill-catalog.md) | The 24 skills, their triggers, inputs, and outputs |
| [`docs/03-install-and-distribution.md`](docs/03-install-and-distribution.md) | Install options compared, the recommendation, and the `keel` CLI spec |
| [`docs/04-plugin-strategy.md`](docs/04-plugin-strategy.md) | Verdict on each of the nine third-party plugins and how skills call them |
| [`docs/05-token-and-memory-design.md`](docs/05-token-and-memory-design.md) | Prompt caching, context budget, project memory |
| [`docs/06-repo-layout.md`](docs/06-repo-layout.md) | Exact file tree of the keel repo |
| [`docs/07-open-decisions.md`](docs/07-open-decisions.md) | Every call taken and why, decisions: 11 of 11 resolved, two with a named part still open |
| [`docs/standards.md`](docs/standards.md) | This repo's own conventions, the judgement calls only |
| [`docs/runbooks/going-public.md`](docs/runbooks/going-public.md) | What publishing this repository would require. Two of its steps are decisions, and none of it has been executed |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | How to add or change a skill, and why the order matters |
| [`SOURCES.md`](SOURCES.md) | Attribution, per skill, for the four MIT projects this is built from |

Templates that ship into every installed project:

| Template | Purpose |
|----------|---------|
| [`templates/project-claude-md-block.md`](templates/project-claude-md-block.md) | The block `keel init` merges into a project's `CLAUDE.md` |
| [`templates/prompting-cheatsheet.md`](templates/prompting-cheatsheet.md) | How to phrase requests so the right skill fires |
| [`templates/keel-profile.example.json`](templates/keel-profile.example.json) | Per-project profile: stack, verify commands, gates |

## Where it comes from

| Source | What we take |
|--------|--------------|
| `andrej-karpathy-skills` | The four behavioural principles, and the discipline of keeping the always-loaded layer tiny |
| `superpowers` | Skill mechanics: TDD iron law, four-phase debugging, plan structure, TDD-for-skills, session-start hook pattern |
| `cursor-starter` | Prompt content: PRD, user stories, architecture, stack choice, CI/CD, security audit, repo snapshot, review, refactor, performance |
| `gstack` | Distribution model (no vendored files, team mode), skill routing, preamble tiering for token control |

All four are MIT licensed. [`SOURCES.md`](SOURCES.md) records attribution per skill and
distinguishes close adaptations from structural borrowings.

## Licence

MIT, in [`LICENSE`](LICENSE). The adapted portions keep their own notices, reproduced in full in
[`THIRD-PARTY-LICENSES.md`](THIRD-PARTY-LICENSES.md), because crediting a source in `SOURCES.md` does
not on its own discharge the obligation. [`NOTICE`](NOTICE) summarises that relationship; it is
separate from `LICENSE` so that `LICENSE` stays canonical MIT text and licence detection works.

We take the ideas, not the code. gstack is ~1,200 files and carries a browser daemon we
do not need. superpowers is a general methodology with no opinion on our stack. What we
build is smaller than both and opinionated about how GBi ships.
