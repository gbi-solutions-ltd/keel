# Install and Distribution

## The options, compared

| Option | How it works | Upgrade story | Repo footprint | Verdict |
|--------|--------------|---------------|----------------|---------|
| **A. Vendored copy** | A script copies skills into each repo's `.claude/skills/` | Re-run the script in every repo, then a PR each | Large, ~20 files that show up in every diff | Rejected. Version drift within a month |
| **B. Git submodule** | `.claude/keel` as a submodule | `git submodule update`, per repo | Small, but submodules are a support burden and break shallow clones and most CI defaults | Rejected |
| **C. npm or pip package** | `npx keel init` | Version bump per repo | Small | Rejected. Forces a Node or Python dependency onto every repo, including the Go and PHP ones |
| **D. Plugin only** | Claude Code plugin, installed per machine | Automatic | Zero | Close, but the repo then carries none of its own facts, and a teammate without the plugin gets nothing |
| **E. Plugin plus thin bootstrap** | Plugin per machine, plus `.keel/` and a `CLAUDE.md` block committed per repo | Automatic for skills, per-repo only for repo facts, which is correct | ~3 files | **Recommended** |

## The recommendation, concretely

**keel is a git repo that is both a Claude Code plugin and its own marketplace.**

```
Machine level (once per engineer)
  /plugin marketplace add gbi-solutions-ltd/keel
  /plugin install keel@gbi
  -> installs 24 skills, the SessionStart hooks, and bin/keel on the Bash tool's PATH
  ln -sfn <cache-or-clone>/bin/keel ~/.local/bin/keel
  -> optional: puts keel on your login shell's PATH. The plugin already put it
     on the Bash tool's

Project level (once per repo)
  keel init
  -> writes .keel/profile.json
  -> merges a block into CLAUDE.md
  -> writes .claude/settings.json with recommended plugins and hooks
  -> scaffolds docs/keel/
  -> optionally stages all of it for commit (keel init --team)
```

Skills are never copied into a repo. Upgrading the plugin upgrades every project.

### The two PATHs, and which one the plugin reaches

A plugin's `bin/` directory is added to the PATH that Claude Code's Bash tool uses, so the two
`/plugin` lines are a complete install for work done inside Claude Code: skills, references, the
SessionStart hook and the CLI. That PATH is not the login shell's, which is the only thing the
symlink below still buys.

This was not always the documented position. It asserted the opposite, that a plugin could put
nothing on PATH and the symlink was therefore mandatory, written after installing on the author's
own machine and finding `keel init` reporting `command not found`. That symptom was real; the
explanation was wrong, or has since stopped being true. `tests/test-cache-install.sh` now runs the
CLI out of a tracked-files-only copy, which is what a marketplace install produces, so the claim
in this section has a check behind it rather than a recollection.

So the symlink is a documented optional step, for the login shell only:

```
ln -sfn ~/.claude/plugins/cache/gbi/keel/<version>/bin/keel ~/.local/bin/keel
```

That cache path is keyed by version, so the link breaks on every upgrade. Pointing it at a clone
instead gives a path that survives, at the cost of keeping the clone current.

Optional or not, it exposed the second half of the same bug. `bin/keel` resolved its own root with
`dirname "${BASH_SOURCE[0]}"`, and `dirname` does not follow symlinks, so through a link `HERE`
became the PATH directory. The failure was silent in the way that matters: `lib/` failed to source,
`VERSION` fell back to `0.0.0` because the read was `|| echo 0.0.0`, and templates were absent. The
script kept going into undefined functions, so the error surfaced as an apparent defect in the
project being configured. It now resolves the link chain by hand, `readlink -f` being absent on
older macOS, and refuses to run at all when `lib/` or `VERSION` is missing beside it. Three tests
pin it, including the loud failure.

### Installing from a local clone

`/plugin marketplace add` accepts an absolute local path as well as a GitHub repo:

```
/plugin marketplace add /absolute/path/to/keel
```

This needs no credentials, so it works with no network and on a machine whose git credentials are
not set up.

**It is not a live view of your working tree.** An installed plugin is copied into
`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` whatever source it came from, and the
cache is keyed by the version in `plugin.json`. Editing your clone changes nothing in an installed
session, and neither does pushing to `main`. Every change that should reach an installed copy
carries a version bump. See Upgrading in the README.

### Permissions: bypass the prompts, keep the guardrails

The prompts are the tax on this whole tooling. A skill that dispatches six subagents and runs a
verify command is worth little if a person has to approve each step, so the default is
`bypassPermissions`. That is only defensible if something still stops the small number of actions
nobody wants an agent taking unattended.

Two rule kinds survive `bypassPermissions`, and one does not:

| Kind | Under bypass | Used for |
|---|---|---|
| `deny` | Still blocks | What is never legitimate. Reading `.env`, keys, `secrets/**` |
| `ask` | Still prompts | Destructive but sometimes right. Force push, `reset --hard`, `terraform destroy`, `kubectl delete`. Since 0.16.1 also egress: `curl`, `wget`, `nc` |
| `allow` | **No effect** | Nothing. Everything is already approved |

That last row is the one to internalise: protection written as an allowlist evaporates the moment
the mode changes. It has to be `deny` and `ask` or it is decorative.

Verified against a live session rather than read from the documentation. With bypass on, a denied
`Read` of `.env` and an asked `git clean -fd` both held while an ordinary file write went through
unprompted. A side finding worth knowing: a compound command inherits the strictest rule among its
subcommands, so `git clean -fd && touch x` prompts for the whole thing.

**The mode and the guardrails live in different files, deliberately.**

| File | Contains | Committed |
|---|---|---|
| `.claude/settings.json` | `deny` and `ask` rules, plugins, the nudge hook | Yes |
| `.claude/settings.local.json` | `permissions.defaultMode` | **No**, and `keel init` adds it to `.gitignore` |

A committed file that sets `bypassPermissions` turns off every prompt for anyone who clones the
repository, before they have read a line of it. That is a decision each engineer makes about their
own machine, not one a repository makes on their behalf. Splitting it costs nothing, because Claude
Code merges both files and the guardrails apply either way. `keel doctor` fails if the guardrails
go missing, and fails if the local file is not ignored.

`init` never overwrites the local file. It accumulates a developer's own allow rules over months,
and losing those is worse than not setting the mode.

### The setting that silently does nothing in an IDE

Reported as "I added the mode by hand and starting Claude in the folder ignores it", and it is not
a keel bug:

> In a session the VS Code extension started, a settings-file `defaultMode` doesn't set the
> starting mode.

The extension resolves its own starting mode and ignores `permissions.defaultMode` from every
settings file. Two VS Code user settings are needed instead, and neither can be shipped in a
repository:

```json
"claudeCode.allowDangerouslySkipPermissions": true,
"claudeCode.initialPermissionMode": "bypassPermissions"
```

The first is a gate: without it the mode is not offered at all. In the CLI, and in JetBrains, which
runs Claude Code in a terminal, the settings file works as written.

`keel doctor` warns when the extension is installed and that setting is absent, because the failure
is invisible: the mode simply is not what the project asked for, and nothing says so.

### Why this is right for GBi specifically

You have many repos across several stacks. The failure mode to avoid is the one where
`tdd` in `payments-api` is six months behind `tdd` in `merchant-portal` and nobody knows
which is current. The plugin model makes that impossible. The per-repo bootstrap exists
only for facts that genuinely differ per repo: how to run its tests, what it deploys to,
which gates apply.

### The gap this leaves, and how it is closed

A teammate who clones the repo without the plugin gets an ordinary Claude Code session,
and the SOP silently does not apply. `keel init` handles this by writing a `SessionStart`
hook that injects the text below. `--team` stages that hook, which is what gets it into
the teammate's clone:

> If you have no skills named `keel:*`, the keel plugin is not loaded in this session and
> the rest of this note applies. If you do have them, ignore it.
>
> This project expects the plugin. Without it its gates on tests, security, and review do
> not apply, and `.keel/profile.json` is what is left: read it before running any test,
> lint, or build command rather than assuming the stack's usual one.
>
> Install it:
> `/plugin marketplace add gbi-solutions-ltd/keel` then `/plugin install keel@gbi`
>
> Continuing without it is fine for a small change.

**The hook states the condition rather than testing it**, because it cannot test it.
`CLAUDE_PLUGIN_ROOT` is set only for hooks a plugin itself defines, and a hook registered
in a project's `settings.json` receives `CLAUDE_PROJECT_DIR` and thirteen other `CLAUDE_*`
variables, none of which names a loaded plugin. The reader knows its own skill list, so
the message asks it to look there. Keying off the variable instead, which is what the hook
did originally, made it silent under a test that set the variable by hand and wrong in
every real session.

It therefore prints in every session rather than only plugin-less ones, so it is budgeted
at 200 tokens like the `SessionStart` injection it sits beside, and a test fails if it
grows past that. Whether it should hard-block instead of nudge is
[open decision 3](07-open-decisions.md).

## The `keel` CLI

Ships in the plugin at `bin/keel`. **Plain bash, POSIX-compatible, zero runtime
dependencies.** This matters: gstack requires Bun, which is a real install barrier and an
odd thing to demand of a PHP repo. Everything the CLI does is file manipulation and process
detection, which bash handles.

The CLI does not parse the profile back. Claude reads `.keel/profile.json` with the Read
tool. The CLI only writes it.

### Commands

```
keel init [--team] [--force]
```
Detects the stack, generates `.keel/profile.json`, merges the CLAUDE.md block, writes
`.claude/settings.json`, scaffolds `docs/keel/`. `--team` also stages what it wrote, including
`.gitignore`; making the commit is left to you.
Idempotent: safe to re-run, and re-running picks up new keel defaults.

Detection matrix:

| Signal | Inferred |
|--------|----------|
| `package.json` with `typescript` dep | TypeScript, plus `typescript-lsp` |
| `package.json` scripts | `verify.test`, `verify.lint`, `verify.build` read directly from `scripts` |
| `go.mod` | Go, `go test ./...`, plus `gopls-lsp` |
| `composer.json` | PHP, plus `php-lsp` |
| `pyproject.toml`, `requirements.txt` or `setup.py` | Python, plus `pyright-lsp` |
| `pom.xml` or `build.gradle` | Java, plus `jdtls-lsp` |
| `build.gradle.kts`, or `kotlin` in a Gradle build | Kotlin, plus `kotlin-lsp` |
| `Cargo.toml` | Rust, plus `rust-analyzer-lsp` |
| `*.csproj`, `*.sln` or `global.json` | C#, `dotnet test`, plus `csharp-lsp` |
| `Gemfile` | Ruby, plus `ruby-lsp` |
| `Package.swift` | Swift, `swift test`, plus `swift-lsp` |
| `CMakeLists.txt` or `meson.build` | C or C++, plus `clangd-lsp` |
| `.luarc.json`, `init.lua` or a `*.rockspec` | Lua, plus `lua-lsp` |
| No manifest for any of the above, and `.sql` plus `.plsql` dominating the tree with an Oracle-exclusive token present | PL/SQL, `oracle` as the datastore, and no language server, because none exists for it |
| More than one of the above | The first is `stack.language` and drives the verify commands; the rest are `stack.also`, and each gets its language server |
| `Dockerfile`, `.github/workflows/` | deployment already set up, `setup-deployment` runs in audit mode |
| any of `next.config`, `vite.config`, `angular.json`, a `public/` dir | has a UI, so recommend `frontend-design` and `playwright` |

Anything it cannot detect, it asks about interactively, and each question has a sensible
default so `keel init -y` works in CI.

```
keel doctor
```
The verification command. Checks that:
- every command in `profile.verify` actually runs and exits 0 (each is timed, printed as it
  starts, and capped at 900s where a `timeout` binary exists; `--fast` skips executing them
  and only validates the fields, for when the suite itself is the slow part)
- the CLAUDE.md block markers are intact and not duplicated
- recommended plugins for this stack are installed, and names the missing ones
- `docs/keel/` structure exists
- **`git check-ignore` does not match the docs root** (see below)
- the permission guardrails are present, and `.claude/settings.local.json` is git-ignored
- the profile's `schema_version` matches the one this keel expects, so a project whose profile is
  missing fields the new skills read says so. It reports the `keel_version` that configured the
  project alongside it, but does not warn on that: most releases change no field, and a warning
  that fires on every upgrade is one nobody reads on the upgrade that mattered
- the `gbi` marketplace, which carries keel, is registered on this machine, which decides whether a session
  has any skills at all
- no skill in the installed plugin exceeds its word budget or contains an `@` link

Exits non-zero on failure so CI can run it. The last three above are advisory: a CI runner
legitimately has no marketplace, and an un-upgraded project still works.

### The artifact map, for a repo that already has documents

Found by running `init` on a real project that carried 30,000 words of requirements, 21,000 of
architecture, and a decisions log, all under its own `PROD-NNN` style naming convention, before a
line of code existed.

`profile.docs_root` solves *where* artifacts go. It does not solve a repo whose artifacts already
exist under names keel would never guess. Without a map, `write-user-stories` reads
`<docs_root>/prd/`, finds nothing, and routes to `write-prd` to author a second PRD beside a mature
one. The tool would make the codebase worse.

```json
"artifacts": {
  "prd": "docs/PROD-042-requirements.md",
  "architecture": "docs/PROD-051-architecture.md",
  "decisions": "docs/PROD-018-decisions-log.md"
}
```

Every skill that reads an artifact checks the map before the default path. `keel doctor` fails on a
mapped path that does not exist, because a broken map is worse than no map: it reads as configured.

### Pre-implementation repos

The same project exposed a second problem: a documents-only repo can never satisfy
`verify.test_one`, so `doctor` failed on a project doing nothing wrong. A check that always fails on
a legitimate state teaches people to ignore the checker.

`project.kind` is now `docs` when no stack is detected and no source files are tracked. `doctor`
reports the project as pre-implementation, skips the verify checks, and warns to switch the kind to
`service` once there is code.

### The gitignored-docs trap

Found while piloting `repo-snapshot` on a real repo: `docs/` was listed in `.gitignore`, so the
snapshot was written successfully, reported successfully, and was invisible to git and to every
teammate. Nothing errored.

This breaks the whole artifact chain, not one skill. Every skill downstream of `repo-snapshot`
reads from `docs/keel/` and assumes it is committed. A silently ignored docs root turns the
pipeline into a set of files on one laptop.

So `keel init` must, before writing anything:

1. Run `git check-ignore -v <docs_root>` and `git check-ignore -v <docs_root>/snapshot.md`.
2. If either matches, do not silently proceed. Offer two fixes: add a negation
   (`!docs/keel/`) to `.gitignore`, or set `profile.docs_root` to a path that is tracked.
3. Record the chosen root in `profile.docs_root`, and never hardcode `docs/keel` in a skill.

`keel doctor` re-checks this on every run, because a later `.gitignore` edit can reintroduce it.

### Writing into a `.gitignore` somebody else wrote

The other half of the same file, found on the existing-service pilot. `init` appends two rules to
`.gitignore`, and a hand-written one usually has no newline on its final line. Appending to it welds
keel's rule onto the project's own, producing a single line that matches neither: it **removes a rule
the repository had chosen** and adds nothing.

So the rule for every file keel writes into a working tree it did not create: terminate before you
append, and treat the existing content as the project's, not as a buffer.

The check that should have caught it had the matching flaw. `git check-ignore` answers "is this
ignored on this machine", and a developer's global `~/.gitignore` can carry the very rule keel just
destroyed. `doctor` asks whether whoever clones the repository will commit the file, so it
neutralises `core.excludesFile` and reads the repository's own rules alone. The suite had asserted
that property for longer than the shipped check enforced it, which is the more useful lesson: a test
that isolates a condition the product does not is a test passing for its own reasons.

```
keel scan
```
Runs the supply chain scan over this tree: tracked files plus anything untracked that git is not
ignoring. Non-zero on any finding. 19 pattern rules and 5 structural, covering what would execute on,
or leak to, whoever clones or installs the repository. Details and the suppression mechanism are in
`tests/supply-chain-scan.sh` and the README.

```
keel guard install | status | uninstall
```
Installs two hooks, by writing `.githooks/pre-push` and `.githooks/pre-commit` and setting
`core.hooksPath` **for this repository only**. Opt-in, because it changes your git configuration, and
repo-local because setting `core.hooksPath` globally would silently disable every other repository's
hooks on the machine. `git push --no-verify` is the deliberate way past it.

The pre-push hook refuses two things. A push carrying anything `keel scan` flags. And a push to
`conventions.default_branch`, because work lands through a pull request, so that branch is written by
a merge rather than by a push. The branch name is read from the profile and never assumed: with
neither a profile nor a remote HEAD to read, the hook checks nothing rather than guessing `main`, on
the reasoning that a refusal naming the wrong branch teaches people to reach for `--no-verify` by
reflex. A project that genuinely pushes to its default branch sets
`conventions.protect_default_branch` to `false`.

The pre-commit hook is inert until `gates.commit_guard` says otherwise. `off`, which is what `init`
writes, and it exits before checking anything: a team adopts the guard for the push protections
above, and a commit gate arriving uninvited with them is how the whole thing gets uninstalled.
`required` runs `verify.format`, `verify.lint` and `verify.typecheck` and refuses the commit on a
failure; `warn` runs them and lets the commit through. Null and templated commands are skipped, the
same way `keel doctor` skips them, because neither can be run as written.

It refuses and never formats. Both `house-defaults.md` and `coding-standards` require a gate to be a
check-only command, and a hook that rewrote your files and re-staged them would put content into a
commit its author never read. So a refusal names `verify.format_fix` as the remedy and leaves the
tree alone. `git commit --no-verify` is the deliberate way past it.

The full test suite is not here, and neither is `verify.test_one`: the hook has no way to derive a
test path from a changed file, and an expensive commit produces fewer, larger commits. See open
decision 4.

```
keel profile get <dotted.path>
keel profile set <dotted.path> <value>
```
Reads and writes one field of `.keel/profile.json`. `init` writes the profile once and then defends
every human value in it, which is right for a re-init and wrong for a fact that has changed since, so
this is how a project records that it grew a user interface without hand-editing JSON. `true`, `false`
and `null` are written as JSON literals rather than the strings that spell them, and a bare integer as
a number. A path that does not already exist is refused, since a typo would otherwise write a key
nothing reads while the caller walks away believing the fact was recorded. `keel_version` and
`schema_version` are refused too: `init` owns both.

```
keel new <name> [--stack node|python|go|minimal]
```
Greenfield scaffolding. Creates the directory, initialises git, lays down the keel layer, a CI
workflow that fails on a broken build, and a sample test that passes.

**It does not scaffold an application, deliberately.** An opinionated framework skeleton would rot
within two releases and would be a recommendation nobody asked for. `design-architecture` chooses the
stack, after `write-prd` establishes what is being built. The sample source file exists so the
project has somewhere for its first real test to go, and it says so in a comment.

**The property that matters: a freshly created project passes its own `keel doctor`.** That is
tested. It means the sample test must run with nothing installed, so node uses `node --test`, python
uses `unittest`, and the minimal stack uses a shell script. Where detection would infer a command
whose tool is absent, `new` states the command instead, because it knows what it generated.

`docs/keel/NEXT-STEPS.md` points at `write-prd` rather than at code, since the whole point of a
greenfield start is that the expensive decisions are still cheap.

## Idempotent CLAUDE.md merging

The single most fragile part of any tool like this. The mechanism:

```markdown
<!-- keel:start v1 -->
... managed content, regenerated on every init and upgrade ...
<!-- keel:end -->
```

Rules:
- Content between the markers is owned by keel and replaced wholesale on upgrade.
- Content outside the markers is owned by the project and never touched.
- Missing markers mean a fresh append, never a rewrite.
- Duplicate markers are an error that `keel doctor` reports rather than silently fixing.
- The version in the open marker lets a future upgrade migrate old blocks knowingly.

The managed block is in [`templates/project-claude-md-block.md`](../templates/project-claude-md-block.md)
and is deliberately short, around 450 tokens, because it sits in every request. See
[doc 05](05-token-and-memory-design.md).

## Cross-agent portability

`keel init` also writes `AGENTS.md` containing the same managed block. Cursor, Codex,
Copilot CLI, and Gemini CLI all read it. This costs one extra file write and means the
principles and verify commands apply even when someone is not in Claude Code. The skills
themselves stay Claude-only for now; porting them is a later decision, not a Phase 1 one.

## Rollout

1. Build it, then pilot on exactly two repos: one existing service and one greenfield.
2. Run for two weeks. Collect what broke and what got skipped.
3. Fix, then roll to volunteers.
4. Only then make `keel doctor` a CI requirement, and only for repos that have opted in.

Making it mandatory before it is good is the fastest way to have everyone route around it.
