# keel

A house standard operating procedure for AI-assisted software delivery, packaged as a
Claude Code plugin plus a thin per-project bootstrap.

**Status:** installable, 25 skills built, `keel` CLI and session hook working. **Not 1.0.0:**
that needs two pilots and a verified install from a second machine.

## Install

```bash
/plugin marketplace add gbi-solutions-ltd/keel
/plugin install keel@gbi
```

That is the whole install **on Claude Code**. The skills, the session hook and the `keel` CLI all
arrive with the plugin: a plugin's `bin/` directory is added to the PATH that Claude Code's Bash
tool uses, so after restarting the session `keel version` in a Claude Code shell prints the VERSION
file.

**Codex CLI is supported too, and it is not the same install or the same guarantee.** keel is Tier
A on Claude Code and Tier B on Codex: the skills, `AGENTS.md` and the CLI are the same, and the set
of gates that actually fire is smaller. `docs/harness-support.md` is generated from the capability
manifest and is the only place that answers which, so it is the page to read before relying on a
gate. Codex also requires a step Claude Code does not: it runs no hook until you have trusted the
plugin's hooks, and it says nothing when it skips one.

The marketplace is cloned over HTTPS, so nothing needs configuring and `gh` is not required.

A local path is also accepted, `/plugin marketplace add /absolute/path/to/keel`, which is
useful with no network. It is **not** a live view of your working tree: see Upgrading.

Then, in each project:

```bash
keel init                        # existing project: detect the stack, write the profile and block
keel new <name> --stack node     # new project: scaffold, git init, CI, a passing sample test
keel doctor                      # check either, non-zero on any problem
keel doctor --fast               # same checks minus executing the verify commands
keel doctor --json --fast         # machine-readable, for a fleet script to consume
```

`init` is idempotent and never overwrites a value you have corrected by hand; detection is a
starting point, not an authority. Use `--force` to overwrite deliberately.

`doctor` runs the whole suite plus its own checks and takes several minutes, silent for most of
them: it is slow, not hung, because its time goes on running each verify command rather than on
reading the profile.

### Recommended plugins

`keel init` writes the right set into `.claude/settings.json` for you: `security-guidance`,
`code-review`, and `skill-creator` on every project, `context7` and a language server per detected
stack, and `frontend-design` plus `playwright` where the project has a UI. Installing is then one
confirmation per plugin in `/plugin`. Full verdicts, and why `feature-dev` is the one plugin kept
off by default, are in [`docs/04-plugin-strategy.md`](docs/04-plugin-strategy.md).

### Optional: `keel` in your own terminal

The plugin puts `keel` on the Bash tool's PATH, not your login shell's. Do this only if you want
to run `keel doctor` outside Claude Code:

```bash
ln -sfn ~/.claude/plugins/cache/gbi/keel/<version>/bin/keel ~/.local/bin/keel
```

That cache path is keyed by version and breaks on every upgrade; point it at a clone instead for a
link that survives. Detail, including what an `incomplete install` message means, is in
[`docs/03-install-and-distribution.md`](docs/03-install-and-distribution.md#the-two-paths-and-which-one-the-plugin-reaches).

### Replies are short by default, and can be plain too

Conversation replies are terse and technical by default; artifacts stay exactly as detailed as
their skill requires. Both are dials in `.keel/profile.json`, independent of each other:

```json
"conventions": { "response_style": "verbose", "explain_level": "plain" }
```

`keel init` writes `terse` and `technical` explicitly, so a project with no keys at all is also
treated as terse and technical. Full behaviour of each value is in
[`docs/profile-keys.md`](docs/profile-keys.md). The plugin also ships a **keel terse** output
style, selectable in `/config`; it is machine-wide rather than per-project, so it is the option
for a non-keel repository.

## Upgrading

Two layers always, and a third only if you made the optional symlink. Forgetting the per-project
layer is the common failure: the skills change, the per-project files do not, and `doctor` starts
reporting things the project never got.

| Layer | Lives in | Picks up a change by |
| --- | --- | --- |
| The plugin: skills, hook, and the `keel` CLI | A **copy** at `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` | `/plugin marketplace update gbi` then `/plugin install keel@gbi`, then restart the session |
| Per-project files | Each repo's `.claude/` and `.keel/` | `keel init` in that repo |
| An optional terminal symlink, if you made one | Wherever you pointed it | Re-point it at the new version directory, or point it at a clone and `git pull` |

```bash
/plugin marketplace update gbi        # fetches the new version
/plugin install keel@gbi              # installs it, then restart the session
cd /path/to/your/project && keel init # updates that project's files
keel doctor
```

**An installed plugin is a copy, not a link**, keyed by the version in `.claude-plugin/plugin.json`:
editing your clone or pushing to `main` changes nothing in an installed session until the version
bumps.

**`keel init` is safe to re-run** and is the only way per-project files pick up a change. It
merges: your corrected verify commands, your profile edits, and your accumulated allow rules all
survive. It adds what is missing and leaves the rest alone.

`.keel/profile.json` records `keel_version` and `schema_version`, so `doctor` can tell you whether
a project needs re-initialising. Every key the file may contain, what it does, and whether keel
writes it or you do, is listed in [docs/profile-keys.md](docs/profile-keys.md).

### Permissions

`keel init` sets `bypassPermissions` so the pipeline is not a prompt per tool call, and writes
`deny` and `ask` rules into the committed `.claude/settings.json` that still apply under bypass;
`keel doctor` fails if either goes missing. Bounded, not safe: the residual is decision 12 of
[doc 07](docs/07-open-decisions.md). The VS Code extension needs two extra user settings for the
mode to take effect at all, `keel doctor` warns when it does not see them, and the full story,
including what does and does not carry to Codex, is in
[`docs/03-install-and-distribution.md`](docs/03-install-and-distribution.md#permissions-bypass-the-prompts-keep-the-guardrails).

## What problem this solves

Today every engineer prompts Claude Code differently, so quality varies per person and
per repo. keel makes the process the default: the same discovery, planning, TDD,
security, review, and shipping steps run on every project, whether it is greenfield or
a ten-year-old service, and whether the engineer remembers to ask for them or not.

## Skills

25 skills, each developed by running it against a real repository, not by writing it and hoping.
[`docs/02-skill-catalog.md`](docs/02-skill-catalog.md) has the full spec per skill: trigger, reads,
writes. `CHANGELOG.md` has what each build run found, including the defects a skill caught in the
repository it was tested against (a savepoint collision that leaves merchant wallets debited, a
worker leak, a broken lint command in this repo's own profile) and the modes still unexercised.

| Stage | Skills |
| --- | --- |
| Discover | `repo-snapshot`, `apex-export`, `apex-port-plan`, `write-prd` |
| Define | `write-user-stories`, `design-database`, `design-architecture` |
| Plan | `write-plan`, `execute-plan` |
| Build | `tdd`, `coding-standards`, `debug` |
| Verify | `review-code`, `security-audit`, `refactor`, `optimize-performance` |
| Ship | `setup-deployment`, `ship` |
| Document | `write-docs` |
| Meta | `create-skill`, `context-budget`, `incident-response`, `shape-idea`, `port-assess` |
| Route | `keel` |

`repo-snapshot` feeding `write-prd` is the first working link in the artifact chain: the
snapshot is read from disk rather than re-derived, so the PRD costs a fraction of what a cold
analysis would.

## Tests

```bash
tests/run-tests.sh           # static: free, plain bash, no dependencies, runs on every commit
tests/evals/stage.sh <name>  # behavioural: costs API tokens, runs before a release
tests/supply-chain-scan.sh   # refuse to ship anything that runs on an installing machine
```

The static suite validates skill shape (frontmatter, word budgets, links), keeps the plugin
generic (`tests/no-internal-leaks.sh`), and scans for what would execute on or leak from an
installing machine (`tests/supply-chain-scan.sh`, 19 pattern rules and 5 structural). Full rule
list is in [`CONTRIBUTING.md`](CONTRIBUTING.md#the-rules-the-validator-enforces).

14 scenarios exist, testing whether a discipline skill changes behaviour under pressure, which
shape checks cannot; results and the arguments they produced are in
[`tests/evals/results.md`](tests/evals/results.md).

A project using keel gets its own opt-in guard:

```bash
keel guard install    # pre-push, pre-commit, and prepare-commit-msg hooks, repo-local
keel scan             # run the supply chain scan by hand
```

Pre-push refuses anything `keel scan` flags, a push straight to the default branch, and a push
whose profile is weaker than what is already on the remote. Pre-commit is inert until
`gates.commit_guard` turns it on. Detail is in
[`docs/03-install-and-distribution.md`](docs/03-install-and-distribution.md#commands).

## How to read this repo

Read in order. Each doc is self-contained but they build on each other.

| Doc | What it answers |
| ----- | ----------------- |
| [`docs/01-architecture.md`](docs/01-architecture.md) | How the pieces fit together and why it is shaped this way. **Start here.** |
| [`docs/02-skill-catalog.md`](docs/02-skill-catalog.md) | The 25 skills, their triggers, inputs, and outputs |
| [`docs/03-install-and-distribution.md`](docs/03-install-and-distribution.md) | Install options compared, the recommendation, and the `keel` CLI spec |
| [`docs/04-plugin-strategy.md`](docs/04-plugin-strategy.md) | Verdict on each of the nine third-party plugins and how skills call them |
| [`docs/05-token-and-memory-design.md`](docs/05-token-and-memory-design.md) | Prompt caching, context budget, project memory |
| [`docs/06-repo-layout.md`](docs/06-repo-layout.md) | Exact file tree of the keel repo |
| [`docs/07-open-decisions.md`](docs/07-open-decisions.md) | Every call taken and why, decisions: 12 of 12 resolved, two with a named part still open |
| [`docs/standards.md`](docs/standards.md) | This repo's own conventions, the judgement calls only |
| [`docs/runbooks/cutting-a-release.md`](docs/runbooks/cutting-a-release.md) | How a release is cut: the eval gate, the three-place version bump, both tags, and the public export. Executed for 0.17.0 |
| [`docs/runbooks/going-public.md`](docs/runbooks/going-public.md) | What publishing this repository required, executed 2026-08-17, each step annotated with what actually happened |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | How to add or change a skill, and why the order matters |
| [`SOURCES.md`](SOURCES.md) | Attribution, per skill, for the four MIT projects this is built from |

Templates that ship into every installed project:

| Template | Purpose |
| ---------- | --------- |
| [`templates/project-claude-md-block.md`](templates/project-claude-md-block.md) | The block `keel init` merges into a project's `CLAUDE.md` |
| [`templates/prompting-cheatsheet.md`](templates/prompting-cheatsheet.md) | How to phrase requests so the right skill fires |
| [`templates/keel-profile.example.json`](templates/keel-profile.example.json) | Per-project profile: stack, verify commands, gates |

## Where it comes from

| Source | What we take |
| -------- | -------------- |
| `andrej-karpathy-skills` | The four behavioural principles, and the discipline of keeping the always-loaded layer tiny |
| `superpowers` | Skill mechanics: TDD iron law, four-phase debugging, plan structure, TDD-for-skills, the session start hook pattern |
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
build is smaller than both and opinionated about how this house ships.
