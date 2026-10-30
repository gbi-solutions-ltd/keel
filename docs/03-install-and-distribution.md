# Install and Distribution

## The options, compared

| Option | How it works | Upgrade story | Repo footprint | Verdict |
| -------- | -------------- | --------------- | ---------------- | --------- |
| **A. Vendored copy** | A script copies skills into each repo's `.claude/skills/` | Re-run the script in every repo, then a PR each | Large, ~20 files that show up in every diff | Rejected. Version drift within a month |
| **B. Git submodule** | `.claude/keel` as a submodule | `git submodule update`, per repo | Small, but submodules are a support burden and break shallow clones and most CI defaults | Rejected |
| **C. npm or pip package** | `npx keel init` | Version bump per repo | Small | Rejected. Forces a Node or Python dependency onto every repo, including the Go and PHP ones |
| **D. Plugin only** | Claude Code plugin, installed per machine | Automatic | Zero | Close, but the repo then carries none of its own facts, and a teammate without the plugin gets nothing |
| **E. Plugin plus thin bootstrap** | Plugin per machine, plus `.keel/` and a `CLAUDE.md` block committed per repo | Automatic for skills, per-repo only for repo facts, which is correct | ~3 files | **Recommended** |

## The recommendation, concretely

**keel is a git repo that is both a Claude Code plugin and its own marketplace.**

```text
Machine level (once per engineer)
  /plugin marketplace add gbi-solutions-ltd/keel
  /plugin install keel@gbi
  -> installs 25 skills, the SessionStart hooks, and bin/keel on the Bash tool's PATH
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

```bash
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

```bash
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
| --- | --- | --- |
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
| --- | --- | --- |
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

### Why this is right for this house specifically

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

```bash
keel init [--team] [--force]
```

Detects the stack, generates `.keel/profile.json`, merges the CLAUDE.md block, writes
`.claude/settings.json`, scaffolds `docs/keel/`. `--team` also stages what it wrote, including
`.gitignore`; making the commit is left to you.
Idempotent: safe to re-run, and re-running picks up new keel defaults.

Detection matrix:

| Signal | Inferred |
| -------- | ---------- |
| `pubspec.yaml` | Dart, `flutter test` for a Flutter project or `dart test` for a plain package that declares `package:test`, either one only where `test/` holds a file ending `_test.dart` for it to run, the analyzer and `dart format`, and no language server plugin, because the catalogue has none for it. `flutter` as the framework where the manifest declares the Flutter SDK, which also sets `has_ui` |
| `package.json` with `typescript` dep | TypeScript, plus `typescript-lsp` |
| `package.json` scripts | `verify.test`, `verify.lint`, `verify.build` read directly from `scripts` |
| `go.mod` | Go, `go test ./...`, plus `gopls-lsp` |
| `composer.json` | PHP, plus `php-lsp` |
| `pyproject.toml`, `requirements.txt` or `setup.py` | Python, plus `pyright-lsp` |
| `build.gradle.kts`, or `kotlin` in a Gradle build | Kotlin, plus `kotlin-lsp` |
| `pom.xml` or `build.gradle` | Java, plus `jdtls-lsp` |
| `Cargo.toml` | Rust, plus `rust-analyzer-lsp` |
| `*.csproj`, `*.sln` or `global.json` | C#, `dotnet test`, plus `csharp-lsp` |
| `Gemfile` | Ruby, plus `ruby-lsp` |
| `Package.swift` | Swift, `swift test`, plus `swift-lsp` |
| `CMakeLists.txt` or `meson.build` | C or C++, plus `clangd-lsp` |
| `.luarc.json`, `init.lua` or a `*.rockspec` | Lua, plus `lua-lsp` |
| No manifest for any of the above, and `.sql` plus `.plsql` dominating the tree with an Oracle-exclusive token present | PL/SQL, `oracle` as the datastore, and no language server, because none exists for it |
| More than one of the above | The first is `stack.language` and drives the verify commands; the rest are `stack.also`, and each gets its language server |
| `Dockerfile`, `.github/workflows/` | deployment already set up, `setup-deployment` runs in audit mode |
| any of `next.config`, `vite.config`, `angular.json`, a `public/` dir, an APEX manifest, or `flutter` as the framework | has a UI, so recommend `frontend-design`, and `playwright` where that UI is browser-rendered. A Flutter application gets `frontend-design` only: `playwright` drives browsers and Flutter's own end-to-end tool is the SDK's `integration_test`. Unless the same root also carries a browser UI of its own, a `public/` dir or an `index.html`, in which case it gets both: the exclusion is about there being no browser to drive, not about Flutter being present |

Anything it cannot detect, it asks about interactively, and each question has a sensible
default so `keel init -y` works in CI.

```bash
keel doctor
```

The verification command. Checks that:

- every command in `profile.verify` actually runs and exits 0 (each is timed, printed as it starts,
  and capped at 900s where a `timeout` binary exists; `--fast` skips executing them and only
  validates the fields, for when the suite itself is the slow part). `verify.security` is one of
  them and reaches the network, so full doctor fails with `verify.security exited <code>` offline
  or when the audit finds a high advisory. A project that wants another threshold, or no audit in
  doctor, sets `verify.security` to that command; `keel init` keeps any value that is not null,
  and detects the audit again where it is null
- the CLAUDE.md block markers are intact and not duplicated
- recommended plugins for this stack are installed, and names the missing ones
- `docs/keel/` structure exists
- **`git check-ignore` does not match the docs root** (see below)
- the permission guardrails are present, and `.claude/settings.local.json` is git-ignored
- the profile's `schema_version` matches the one this keel expects, so a project whose profile is
  missing fields the new skills read says so. It reports the `keel_version` that configured the
  project alongside it, but does not warn on that: most releases change no field, and a warning
  that fires on every upgrade is one nobody reads on the upgrade that mattered
- every profile value the schema constrains to an enum holds one of its values. A gate holding a
  typo fails, because whatever reads a gate treats a value it does not recognise as a weaker one.
  A schema doctor cannot read warns, since the check did not run
- the push guard is installed, where `conventions.protect_default_branch` is not false. A warning,
  since installing it writes into the developer's git directory
- the `gbi` marketplace, which carries keel, is registered on this machine, which decides whether a session
  has any skills at all
- no skill in the installed plugin exceeds its word budget or contains an `@` link

Exits non-zero on failure so CI can run it. The `schema_version` check and the last two above
are advisory: a CI runner legitimately has no marketplace, and an un-upgraded project still works.

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

```bash
keel scan
```

Runs the supply chain scan over this tree: tracked files plus anything untracked that git is not
ignoring. Non-zero on any finding. 19 pattern rules and 5 structural, covering what would execute on,
or leak to, whoever clones or installs the repository. Details and the suppression mechanism are in
`tests/supply-chain-scan.sh` and the README.

```bash
keel scan --push <remote> <commit>
```

Scans a commit instead of the working tree: the commit's own tree in full, and every version of a
key, keystore or certificate file that a commit reachable from it, and from no ref of `<remote>`
fetched here, added or changed and the tip does not hold with that same content. git keeps such a
file in history, so a push carries it to the remote though the tip does not show it. Other content
in those intermediate commits is not scanned. The commit itself is scanned whatever the
remote-tracking refs say, since they record what was last fetched, possibly from another URL, and
not what the remote holds; so a new tag or branch on a commit the remote already has is refused
over anything the scan flags in it. The history walk does trust them, so after `git remote set-url`
a key the old remote's refs reach is not checked. It refuses, before scanning, a commit
holding a path git refuses to check out, one with a `.git`, `.`, `..` or empty component, and one
holding paths this filesystem cannot write apart, such as two that differ only in case and in
content. The copy it scans has the commit's own names and modes, and no filter or conversion the
pushed `.gitattributes`, or this user's own git configuration, names is applied to it.

The allow list is the commit's own `.keel/scan-allow`, and an entry covers the version of the path
the commit holds, the one reviewed. A version of that path a pushed commit held and the tip does
not is refused, so a live key put at an allowed path and replaced with the fixture again, or
deleted, before the tip does not pass. An older version that was reviewed too, a fixture since
regenerated, is pinned by a line naming the path and then that version's blob, `git rev-parse
<commit>:<path>`, before any reason: a first push to a remote with no fetched refs walks the whole
history and refuses every unpinned older version. A pin covers that one version only. A commit holding something this filesystem reads as `.keel/scan-allow` that is not that file
itself, a symlink by that name or `.keel/SCAN-ALLOW` on a case-folding disk, is refused outright.

```bash
keel scan --leaks <remote> [<object>:<ref>]...
keel scan --leaks-message <file>
```

The leak guard: what a push, or a message, carries that must not reach a public repository, checked
against the internal deny list. `<object>` is a commit or tag id and `<ref>` the remote ref it is
pushed to; a ref name cannot hold a colon, so the split is unambiguous. Exit 0 with no finding, 1
with any, and 2 on a usage error, an object that is neither a commit nor a tag, a message file that
cannot be read, a history walk that fails, or a deny list holding a pattern that is not a valid
regular expression.

The deny list is one file of patterns, one extended regular expression per line, with `#` comments
and blank lines ignored, read from `$KEEL_DENY_FILE` or else `keel/internal-deny-list.txt` under
`$XDG_CONFIG_HOME`, or `~/.config`. It lives outside every repository, because a list of client
names is itself the disclosure. `tests/no-internal-leaks.sh` reads it through the same loader,
`lib/deny-list.sh`. Two generic patterns always run, a developer's home directory path under each of
the two common prefixes. The first line printed says which mode this was: the list loaded, with its
path and pattern count, or a warning that no list was found and that client names are not checked on
this machine.

A pattern that is not a valid extended regular expression, such as one with a parenthesis left open,
is refused rather than skipped. grep cannot compile it, so it would match nothing, and the scan
would print its mode line and no findings while that name went unchecked. The loader tries each
pattern from the file with `grep -E` over empty input as it reads it, once in the caller's locale
and once in the C locale `keel scan` greps in, since what compiles can differ between them, and
leaves out each one that does not compile in either; the count in the mode line is of the valid
patterns. After the mode line the scan prints `leak guard: deny list line <n>: not a valid pattern,
so it checked nothing` for each, then `leak guard: refusing to scan: fix the deny list at <path>`,
and exits 2 having checked nothing. The pattern itself is never printed: open the file at line
`<n>`. `tests/no-internal-leaks.sh` prints `FAIL  deny list line <n>: not a valid pattern` for each,
after its mode line, and exits 1 before it scans.

What is checked, for every commit in range: each line of its message, subject, body and trailers;
its author and committer names and emails; every path it added, modified or changed in type; and the
content of those files. The content is checked in every commit that added or changed the file, so a
file a later commit in the push deletes is still found. A tag object's own message and tagger are
checked, and each pushed ref name. Binary files are skipped by the supply chain scanner's own test,
`grep -I`, run once over the candidates, so a pattern inside a binary file, or an empty one, is not
found. The organisation rules of `tests/no-internal-leaks.sh` are not deny patterns and are not
applied: the owner's own identity is not a leak.

The range is the walk `keel scan --push` makes: every commit reachable from a pushed commit and from
no remote-tracking ref of `<remote>`. It trusts those refs, which record what was last fetched and
not what the remote holds, so after `git remote set-url` they can describe another repository. Two
rules back that up. A root commit in range is refused, because the public repository has one root,
already pushed, and a second means an unrelated history, a private one included, is being joined to
it. A path the repository ignores, by `.gitignore` or `.git/info/exclude` and not by this user's
global ignore file, is refused when a commit holds it, which is what a force-added audit looks like.
A line of a commit message whose key is `Claude-Session:`, in any case, is refused whatever made the
commit: a cherry-pick, a rebase, a clone without the hook, or `--no-verify`.

Nothing matched is ever printed: not the text, not the pattern, not a commit subject. A finding
names where it was found, a commit, a message line, a path, and which pattern matched, as
`generic pattern 2` or `deny list line 4`, the line of the deny list file, comments and blank lines
counted. A path or ref name that matches a pattern is printed as `a changed path` or `a pushed ref
name`, in every line that would name it. Output that does not name what it found is safe to
paste into an issue.

The root rule means a first push to an empty repository, or a push to a remote named by URL, which
has no remote-tracking refs here, needs `git push --no-verify`. Do that once, after reading the
history by hand.

`keel scan --leaks-message <file>` checks every line of one text file against the same list, up to
but not including a scissors line, `# ------------------------ >8 ------------------------`. A line
that starts with `#` counts, because git commits one under some cleanup modes. It works on any text
file, so it is how a pull request body or release notes are checked before they are posted.

```bash
keel plan status <plan>
```

Reads an implementation plan written from `skills/write-plan/references/plan-template.md` and
prints one line per task counting its steps by state, open, done, deferred and not applicable, then
`next: <id>` naming the first open step, or `next: none`. A step is a checkbox whose bold title
opens with its id, `**Step 3.2: ...**`; one inside a fenced code block is an example and is not
counted. It exits 1, with a `problem:` line for each, where a deferred or not-applicable step has no
reason, an id appears twice, an open checkbox is not a step it can read, or a fence never closes.
A plan with no step ids, such as one written before steps carried them, is unaddressable: `status`
and `tick` say so, change nothing, and exit 3, and the plan is read and ticked by hand.

```bash
keel plan tick <plan> <id> [--note <text> | --defer <reason> | --not-applicable <reason>]
```

Marks one step done, rewriting only its line. `--note` writes ` Note: <text>` after the step's
title, for a step the ticker did not witness; a note holding a newline is refused. An id the plan
does not hold, or holds twice, changes nothing and exits 1.
A plan with no step ids changes nothing and exits 3; a fence that never closes is reported, exit 1,
rather than read as a plan without ids.
`--defer` and `--not-applicable` park the step instead, writing ` Deferred: <reason>` or
` Not applicable: <reason>`, and refuse without a reason. Ticking a parked step done drops its
reason. Parking replaces anything after the title, a note included, and a reason must start with a
non-blank character, since `plan status` reads one that starts with a space, tab or CR as missing.
Ticks on one plan take turns through a lock, the directory `<plan>.lock`, so a concurrent batch's
ticks all land. A tick waits about ten seconds for it, then fails naming it, since a killed tick can
leave it behind.

```bash
keel plan report <plan> [--json]
```

Says how long a plan took and whether it came back as a fix, from git alone: nothing is stored, and
every number comes from the commit history and the committed copies of the plan. The working-tree
copy is never read, so a tick not yet committed changes nothing. It prints:

```text
planned: 2026-10-16T09:00:00Z
planned routing: keel-implementer
task 1: done 2026-10-16T10:30:00Z, rounds 2, routing keel-implementer, loop light
task 2: open
delivered: not yet
lead time: not yet
rework: 2 (3f9a1c2 b81d0e7)
```

`planned` is the author time of the first commit that has the plan. Every time is an author time,
shown in UTC, because a rebase rewrites committer times and this measures when the work was done.
`planned routing` is the plan's `**Implementer routing:**` header, or `inherit (not stated)`. A
task is `done` at the author time of the latest commit at which one of its steps closed, by any
mark, done, deferred or not applicable. A step closes at a commit where it is closed and is open
or absent in every parent that has the plan, so a merge does not move the time of a step a branch
closed before it: tasks run in parallel worktrees and merged back keep the times of their own
commits. A step already closed in the commit that adds the plan counts as closed at that commit,
and one closed, reopened and closed again counts from its last close. A task with an open step is
`open`. `rounds` and `routing` are the last `rounds: <n>` and the last `routing: <text>` in the
notes of the task's done steps (`keel plan tick --note`). The note is the text after the last
` Note: ` on the step's line, as `plan tick` writes it, so step text before it is never read, and a
step with no ` Note: ` has no note. A field begins the note or follows `; `, as in
`rounds: 2; routing: keel-implementer`, so `subrounds: 3` or a sentence that mentions routing is not
one; the routing text runs to the next `;` or the end of the note. Absent, each is
`unknown`. `loop` is read the same way: the last `loop: light` or `loop: full`, which is what
`keel plan risk` decided for the task. A task with none, or with another word, prints no loop.
`delivered` is the latest task time once every step is closed, else `not yet`, and
`lead time` is delivered minus planned in hours to one decimal. `rework` counts the commits
reachable from `HEAD` whose message holds the line `Reworks <plan path>` on its own line, the path
from the repository root, with their short hashes, newest first; a line naming another plan does not
count.

Routing and rounds come from `execute-plan`. It reads the routing from the plan's
`**Implementer routing:**` header, and when it ticks the last done step of a task it writes
`rounds: <n>; routing: <profile>` into that step's note. A plan ticked by hand with no note reports
both as `unknown`.

The `Reworks` line comes from `debug`. When the commit that introduced a bug's cause also changed a
plan, the fix's commit message body carries `Reworks <root-relative plan path>` on a line of its
own (`skills/debug/references/rework-link.md`). It is a body line, not a trailer, so it holds where
`conventions.no_attribution_footers` is true, and a fix whose cause was not introduced with a plan
carries no line. `ship` puts this report in the pull request body when the branch changed a plan.

Run the report on the branch, before a squash merge: after one, the plan's planned time and its
delivered time collapse into the one squash commit. A plan committed already ticked reports a lead
time of `0.0h` for the same reason.

`--json` prints the same facts as one object, with `null` where the text says `not yet` or
`unknown`, and where a task prints no loop. A missing file exits 1, naming it. A plan with no step
ids exits 3, as `status` and `tick` do. A plan with no committed history, one not committed yet,
exits 4. A shallow clone exits 5, since the commits the times come from are not there:
`git fetch --unshallow` first. The plan's path is read literally, never as a pattern, and may hold
any characters. It reports the same from any directory in the repository, by a relative path.
Renames are not followed: the history is that of the plan's present path, so a plan moved or
renamed is planned, for this report, when it appeared under its present name.

```bash
keel plan risk [--staged | --range <a>..<b> | <path>...]
```

Says which review loop a change gets, from the sensitive paths the project declares in its profile,
so the choice is not a judgement. It prints each changed path that a declared pattern matches, then
a last line, `loop: full` or `loop: light`:

```text
src/payments/fee.sh
loop: full
```

**Only `loop: light` with exit 0 means the light loop.** Anything else is the full loop:
`loop: full`, any other exit, a `keel` too old to have the command, or no `keel`. Failing to decide
is never a reason to review less, and none of the failing exits prints a `loop:` line.

`--staged`, the default, reads the index with `git diff --cached --no-renames --name-only -z`;
`--range <a>..<b>` reads the commits between with `git diff --no-renames --name-only -z <a> <b>`;
paths given on the command line are used as they are, named from the repository root as git names
them (a leading `./` or a doubled `/` is tidied). They are root-relative: an absolute path, one
that leaves the root with `..`, or the root itself is a usage error, not a path that matches
nothing. `--no-renames` is deliberate: otherwise a file moved out of a declared directory reports
only its new name and reads as light. The changed paths never come from the working tree, so an
unstaged edit to an ordinary file changes nothing; the profiles are read from it too (below), so an
unstaged edit to a profile does change the verdict. The profile and the paths are both taken from
`git rev-parse --show-toplevel`, so the answer is the same from any directory in the repository,
with one exception: a profile above the repository that only a symlinked path to it passes is read
when keel runs through that path.

<!-- keel:claim gate=sensitive-guard harness=claude -->
**The list is a union.** `hooks/sensitive-guard` reads the nearest `.keel/profile.json` walking up
from the directory it runs in, and that can be any directory, so `plan risk` matches the changed
paths against the patterns of every profile the hook could read from anywhere:

- the root profile as the base has it (`HEAD` for `--staged`, `<a>` for `--range`) and as the
  working tree has it, which is the only way explicit paths, naming no commit, read it;
- every nested `*/.keel/profile.json` tracked at the base, tracked or modified in the working tree,
  or untracked there, ignored files included (`git ls-files --others` without
  `--exclude-standard`);
- the nearest profile above the repository, whatever directory keel runs in. The hook stops at the
  first profile it meets, so run from `svc`, which has its own, it never reads one above the
  repository, but run from the root, which has none, it does. keel therefore also walks up from the
  repository's parent, and adds the nearest profile it finds there. It walks from the current
  directory too, by the logical `$PWD` with symlinks unresolved, as the hook does, and by the
  resolved path, and from the logical parent of the repository when that differs.

The base is in the union so a change cannot lower its own review, and the working tree is in it
because the hook reads that: with `["src/auth"]` at `HEAD`, an unstaged edit making it
`["src/payments"]` and `src/payments/fee.sh` staged, the hook asks, so this says `loop: full`.
Patterns are used as written and matched against the root-relative paths, as the hook matches
them, so a nested profile's `src/payments` is the root's `src/payments`, not one under its own
directory. Any match prints the matching paths and `loop: full`. Discovery is case-insensitive, as
a macOS file system is, so `svc/.Keel/profile.json` is a profile. A change that adds, edits or
deletes any `.keel/profile.json`, at the root or below it, in any case, is `loop: full` whatever
the profiles then say, printing that path as the match with a one-line reason on stderr. So is a
change to any path whose last component is `.keel`, in any case: a symlink, a submodule or a file
of that name.
A matched path is printed with any control character escaped (a newline is `\n`), and one that
would begin `loop:` is led by `./`, so no path line can read as the verdict.

<!-- keel:claim gate=sensitive-guard harness=claude -->
A pattern matches a path as `hooks/sensitive-guard` matches it, against the profile's
`hard_block_paths`: by `fnmatch`, or as a directory, so `src/payments` covers
`src/payments/fee.sh`. The rule is mirrored in `keel` and not shared with the hook, which must run
without it; `tests/test-plan.sh` cuts the hook's rule out of the hook when it runs and requires the
same verdict from both.

<!-- keel:claim gate=sensitive-guard harness=claude -->
A profile that is found and cannot be read, or whose `hard_block_paths` is not a list of strings,
is exit 3, naming it, with no `loop:` line, so the loop is the full loop. Unreadable is invalid
JSON, a symlink (a profile that is one, or a directory named `.keel` that is one, tracked at the
base or present, dangling or not; a link is never followed), a profile that is not a plain file at
the base, a profile that is not a regular file in the working tree (a FIFO, which is not opened,
since opening it waits for a writer), or a `.keel` that is a submodule (mode 160000), at the base
or in the index. An untracked nested repository named `.keel` is read for the `profile.json` in
it. A match in a profile that did read is still `loop: full`, since nothing unread can make a match
less, so exit 3 is for when nothing matched. A full verdict reached while some profile could not be
read says so in one line on stderr, naming them; the verdict stays full.

<!-- keel:claim gate=sensitive-guard harness=claude -->
No list anywhere, which is no profile, none with a `hard_block_paths` key, or only empty lists, is
the light loop, with exit 0, and says so before the verdict:

```text
no hard_block_paths declared
loop: light
```

Lists that match nothing are `loop: light` alone, with no such line. Only a missing key or `[]` is
no list: `{}`, `""`, `false`, `0` and `null` are lists that cannot be read.

Exit 1 is a usage error: an unknown option, a path that is absolute or leaves the root, or a range
that is not `<a>..<b>`. Exit 3 is a profile that is not valid JSON, one that exists in any form
and cannot be read (a dangling symlink, or a symlink at the base, which is not followed), a list
that is not a list of strings, in any profile the union reads (above) when no list matched, or no
`python3`. Exit 4 is nothing staged, or a range that changes no file. Exit 6 is git that cannot be
run, a directory that is not a git work tree, or a range git cannot read.

```bash
keel plan batches <plan> [--json]
```

Prints the batches a plan's tasks allow, so `write-plan` can declare them and `execute-plan` can
check a declared one. One line per scheduling step in plan order, `batch: 1 2` for tasks that may
run at the same time and `alone: 3` for one that may not; then a `why:` line for each task that
could not join the step before it (for a task straight after a lone task that runs alone, that
lone task is the step before it); then one `check:` line:

```text
batch: 1 2
alone: 3
alone: 4
why: task 3 depends on task 1 and task 2
why: task 4 depends on task 3
check: in each batch, every Done when names only its task's own test, and each last step commits
```

It reads each `### Task <id>:` heading outside a fenced block. An id is digits then any letters
(`1`, `1b`, `2A`), compared without regard to case. A task's section ends at the next `### Task`
heading or the next `## ` heading, so a section after the last task is not read into it. Fences are
read as CommonMark reads them, and as `keel plan status` reads them, since the two share one reader:
a fence opens on a line indented at most three columns, and closes only on a line of the same
character, at least as long, indented at most three columns past the list item it opened in, with
nothing but spaces after it. So a fence of four backticks holding an example fenced with three stays
open, as the template writes its nested examples, and so does a fence holding a fence line indented
four or more columns past it; read as a closer, such a line would end the outer fence early, and the
outer closer would open a phantom fence hiding the next task from both commands. A fence opened on
its own line inside a list item belongs to the item, as CommonMark has it: it closes on a closer at
most three columns past the item's content, and ends with the item, at a non-blank line indented
less than that content. So a fence left without its closer, or opened by an example's stray last
closer, cannot hide the plan after its item from either command. Outside a list item an indented
fence keeps CommonMark's reading, its content at any indent, since only an item bounds it.

A task the command cannot see makes every task in the plan run alone, with one `why:` line naming
it. That is a line that opens like a task heading, with `#`s and then `task` as a word in any case,
after up to three spaces and any `>` quote marks, and with spaces or a tab after the `#`s, as
CommonMark takes either, but is not `### Task <id>:` exactly at the start of the line, such as
`### Task 2 - b`, `###<TAB>Task 2: b`, `## Task 2: b`, `### Task 2. b`, `### Task 2 : b`,
`### Task two: b`, `### TASK 2: b`, `  ### Task 2: b` or `> ### Task 2: b`; or a step whose task,
its id before the last dot as `keel plan status` reads it, has no such heading. A hidden task could
edit any file and need any task, so any batch beside it could put two agents on one file or run a
task before its dependency.

A `Files`-like label or list item, as the strict form below defines them, after the first task
heading but in no task's section, as under a `## ` heading between two tasks or after the last, also
makes every task run alone, with one `why:` line naming it: `why: the line '**Files:**' names files
outside any task, so every task runs alone, since this command cannot tell which task it belongs
to`. It could belong to the task above it or the task below, and a batch that missed its paths could
put two agents on one file. A self-review item written as `6. **Files:** ...` counts too, which
costs a plan written that way its batches and never makes one unsafe; the template's self-review
writes no such label.

A fence that never closes hides every line after it, as CommonMark renders it, and so any task
there, which could edit any file and need any task. It makes every task run alone, with one `why:`
line naming the line that opens it, such as `why: the fence opened at line 21, '```bash', never
closes, so every task runs alone, since a task it hides could run out of order`, and
`keel plan status` reports the same fence as a problem.

An id on more than one heading, compared without case (`2A` and `2a`, or `### Task 2:` twice),
names no one task. Each task with it runs alone, with `why: task 2a shares its id with another
task, so its dependents cannot be placed`, and so does a task depending on that id, because which
of the tasks it waits for is not known.

Only a task written in a strict form can join a batch. A task whose `Depends on:` line or `Files`
block is not in the form runs alone with a `why:` line. The lines are free text, and a free-text
reading misreads some ways of writing them into an unsafe batch, a task batched with one it depends
on or two tasks on one file. Running alone costs only overlap and is never unsafe, so where the text
is in any doubt the task runs alone, and `write-plan` writes these lines itself, so it can write the
form.

`**Depends on:**` is read from the label's own line, after the label, with the spaces around it and
one trailing `.` removed. What remains is exactly one of `none`; `task <id>`; `tasks <id> and <id>`;
`tasks <id>, <id> and <id>`, with any number of ids before the `and` and an optional comma before it
once two ids precede it; or `tasks <id> to <id>`, which is every task between the two in plan order
and every task whose number lies between theirs, because plans are not always in number order and a
reader takes `tasks 1 to 3` to include task 2 wherever it sits. If one of those is not above the
task, the task runs alone, with `why: task 4 has a range that reaches a task below it, so its order
is unknown`, since a task cannot wait for one scheduled after it. `task` and `tasks` match in any
case, the rest exactly, with one space between words. An id is digits then any letters (`1`, `1b`,
`2A`), compared without regard to case. So `tasks 1, 2 and 3` is 1, 2 and 3, `tasks 1 to 3` is 1, 2
and 3, and each of `tasks 1 (schema) and 2 (API)`, `tasks 1-2`, `none (needs task 2's table)` and
`task 1, with row 3 of its results` runs alone, with `why: task 3 has a Depends on line not in the
strict form, so its order is unknown`.

`**Files:**` is the block from the label to the next blank line, `**Label:**` line or section end,
and every line in it is one of: the label line with nothing after it; a list item `- <Word>: `,
where Word is `Create`, `Modify`, `Delete`, `Test` or `Rename`, optionally with a parenthesised note
before the colon, as in `- Create (if the body cannot hold the detail): `, followed by one or more
backticked paths separated by `, ` with an optional final `and`; or an indented continuation line of
backticked paths with the same separators, after a line that ended on a separator. A path is one
token of letters, digits and `._-/@+` that does not start or end with `/` and has no empty, `.` or
`..` segment, so `//`, `/./`, `/../` and a leading `./` are out. A rename names both of its paths,
as `` - Rename: `src/old.js` and `src/new.js` ``, and a task shares a path with it when it names
either; written with ` to ` instead of `and`, the line is outside the form and the task runs alone,
since only `and` is in the strict form. Anything else in the block makes the task run alone, with
`why: task 2 has a Files block not in the strict form, so its paths are unknown`: prose, a note
after a path, a Markdown link, a path outside backticks, or a space, `:`, `#`, `\`, `{`, `*`, `?` or
`[` inside a path. Each of those is how a plan writes a note, a line range, a pattern or a place in
the file, and each read as a path makes one file read as two, or a pattern read as a file. So does a
block that is ambiguous about where it ends: a list item, or an indented line that continues the
last item as a paragraph, after a blank line but before the next `**Label:**` line; a fenced block
in or after the block; or a list that ends on a separator with nothing to continue it. So does a
task that names paths outside its block, which a batch would not see: a second `**Files:**` label,
or any other label with `file` or `files` as a whole word, in any case (`**Test files:**`,
`**Files (tests):**`, `**File:**`; not `**Profile key record:**` or `**Filename:**`, which name no
path), quoted or in a list item (`> **Files:**`, `- **Files:**`), or a list item opening with
`Create`, `Modify`, `Delete`, `Test` or `Rename`, in any case, followed by ` (`, or by no letter
and then a `:` later on the line, quoted or not, anywhere else in the task, such as a `Behaviours`
or step item, since Markdown renders each as a label or a list item, and a stray backtick or space
before the colon, as in `` - Modify `b.js`: also ``, still leaves a path on the line. A longer
word, as in `Tests:`, `Testing:` or `Created by:`, is not one of the five, so its item is prose.
For one of these, and for a line after the blank line that ends the block, the reason quotes the first such line with its
number, so the writer can find it: `why: task 2 has a Files block not in the strict form, so its
paths are unknown (line 41: '1. Test: an empty list fails.')`. A block with no path counts as no
Files block.

Paths compare without regard to case, because on a case-insensitive file system `App.tsx` and
`app.tsx` are one file. A path that holds another is shared with it, so `skills/x` and
`skills/x/a.md` do not batch, since a directory written without its trailing `/` is still a legal
path. Merging two paths can only stop a batch, never start a wrong one.

Scheduling keeps plan order. Walking the tasks in order, a task joins the current batch when its
dependencies all landed before the batch began, it shares no path with a task already in the
batch, and it is batchable; otherwise the batch is closed and the task starts the next one, or
runs alone. No task is scheduled before a task above it, so the output is a schedule a plan can
declare as written. A reason names only the dependencies in the step just closed, or the first
shared path and the tasks in the batch that have it. A task that follows a task running alone is
checked against it: a dependency on it, or a path shared with it, is the follower's reason. A
follower with neither starts a new step and gets no `why:` line of its own, because the lone task's
reason was given with that task.

A task runs alone, with its reason, when the command cannot know its order or its paths. That is a
task with no `Depends on:` line, a second one, or one not in the strict form, because reading it
any other way would batch a task whose dependency was merely written another way; one depending on
a task the plan does not have above it; a task with no `Files` block, or one whose block is not in
the strict form, which includes a path that is a directory or a pattern, ending in `/` or holding
`*`, `?` or `[`, because `skills/x/` and `skills/x/a.md` compare as different strings and would let
two overlapping tasks into one batch; and a path that is shared config, matched by basename or by
path as listed, without regard to case: a lockfile or dependency manifest (`package-lock.json`,
`Cargo.toml`, `go.mod`, `requirements*.txt` and the like), a lint, format or type config
(`.eslintrc*`, `tsconfig*.json`, `.editorconfig`), a CI file (anything under `.github/workflows/`
or `.circleci/`, `.gitlab-ci.yml`, `Jenkinsfile`), or `.keel/profile.json`, because two agents each
editing one of these produce two versions of it. A strict path can still be shared config.

Known limits. Plans in the template's form are read exactly, and a structure the reader cannot place
runs every task alone. A line-by-line reader cannot be complete against every piece of Markdown, so
a few edge cases remain, each outside the template's form and accepted for the reason given. Ids
compare as strings, so `### Task 01:` and `task 1` are two tasks and a task depending on task 1 can
batch with task 01: the template and `write-plan` number tasks without leading zeros, and reading
numbers would need a rule for every other spelling of one. A `Depends on:` line inside a blockquote
is not read, so when the task also has a plain one the quoted one is ignored: the template never
quotes a label, and a task with only a quoted one has no `Depends on:` line and runs alone. An HTML
comment is read as plain text, so a heading inside `<!--` and `-->` counts as a task and a label on
the comment's opening line is not read: the template writes no HTML comment, and the reading then
matches what an agent reading the raw plan sees. A fence inside a blockquote, or one indented four
or more columns in a nested list, is not read as a fence, so its lines are read as plain text: the
template's fences sit at most three columns in, and a missed fence whose closer sits as deep as its
opener is missed whole, so it hides nothing. A fence opened on its own line inside a list item ends
where the reader takes the item to end, by its own line-by-line count of the open list items: that
can differ from CommonMark after a lazy line that does not follow a paragraph, and then the fence
ends a few lines early, showing them, or runs on past the item to its closer, hiding the lines
between; the template's steps hold their commands in fences indented with their items, which it
reads as CommonMark does. A closing line indented less than the item's content is read as the
fence's closer, where CommonMark ends the item and opens a new fence there: that new fence would
hide every line after it, so the reader shows those lines rather than hide them, and the template
indents each closer with its opener. A file named in prose outside a task's `Files` block, such as
`` *Files:* `src/b.js` `` in italics, is not read, so a batch may not see it: the template names a
task's files only in its `Files` block, and a reader that took every backticked path in prose as a
file would run nearly every real plan alone, since their steps and notes name files they do not
edit.

The `check:` line is always printed, because two conditions for a batch, that each `Done when:`
names only its own task's test and that each task's last step commits, are text the command cannot
judge. It proposes; the plan declares and the approver approves.

`--json` prints the same steps, reasons and check as one object, without `python3`. The one
reason for a plan with a hidden task belongs to no task, so its `task` is empty:

```json
{"steps": [{"batch": ["1", "2"]}, {"alone": "3"}], "why": [{"task": "3", "reason": "task 3 depends on task 1 and task 2"}], "check": "..."}
```

Exit 0 when it printed. Exit 1 is a usage error (no argument, an unknown option, or two plans) or a
missing plan, naming it. Exit 3 is a plan with no `### Task` heading.

```bash
keel guard install [--leak-guard | --no-leak-guard] | status | uninstall
```

Installs three hooks, `pre-push`, `pre-commit` and `prepare-commit-msg`, into git's own hooks
directory (`.git/hooks`, shared by every worktree), and sets no `core.hooksPath`. No checkout
writes there, so checking out a branch, a fork's pull request included, never runs that branch's
own hooks; until 2026-09-26 the guard lived in `.githooks` behind `core.hooksPath`, a working-tree
path every checkout replaced. `keel guard install` moves such an install and unsets the setting,
unless `.githooks` also holds hooks keel did not write, which unsetting it would stop running.
It refuses while `core.hooksPath` points anywhere else, or while a same-named hook without keel's
mark is present, because replacing either switches another tool's hooks off. The hooks are not
committed: each clone runs `keel guard install` for itself. Opt-in, because it writes into your git
directory. `git push --no-verify` is the deliberate way past it.
`keel doctor` warns while `conventions.protect_default_branch` is not false and the guard is not
installed, because nothing else outside a session enforces that key. It reports the state
`keel guard status` does: an install at `.githooks` is a warning to move it, naming first any hooks
there keel did not write, and another tool's `core.hooksPath`, with the config it is set in, or
same-named hook is named without sending you to `keel guard install`.

The pre-push hook refuses three things. A push carrying anything `keel scan --push` flags: the hook
runs it once for each commit a ref is pushed to, which scans that commit's tree and the key files
anywhere in the history the push carries, never the working tree. The scanner is the installed
keel's, the one `keel` on PATH runs, never the pushed repository's own `tests/supply-chain-scan.sh`,
so a branch cannot weaken the scanner's rules on the push that publishes the change. The allow list
is another matter: it is the pushed commit's own, so an entry a branch adds counts on that push and
is reviewed with the rest of the branch. Where `keel` on PATH is a symlink into a clone of keel,
that clone's working tree is the installed keel, so in keel's own repository a branch checked out
there is scanned by its own copy. For this scan, with no `keel` on PATH the hook says nothing was
scanned and lets the push through (the 2026-09-27 choice), and with a `keel` too old for `--push`
it says so and scans the working tree instead; the leak guard below reverses the first of these for
itself. Run by hand, with no arguments, it scans the working tree;
with nothing to push, it scans nothing. The hook reads git's lines from the right, so a push source
holding a space, such as `:/fix HEAD`, is still read as the commit it names and the ref it updates.
`keel guard status` calls a hook written before `--push` stale, since it scans the working tree.

The other two refusals. A push to `conventions.default_branch`, because work lands through a pull
request, so that branch is written by a merge rather than by a push. The branch name is read from
the profile and never assumed: with neither a profile nor a remote HEAD to read, the hook checks
nothing rather than guessing `main`, on the reasoning that a refusal naming the wrong branch teaches
people to reach for `--no-verify` by reflex. And a push whose
`.keel/profile.json` is weaker, on the branch being pushed, than the one already on the remote (or,
on a branch's first push, than the remote default branch): a gate moved toward `off`, a `verify.*`
command that became null or a non-string, or a path dropped from the profile's list of blocked
paths. `git push --no-verify` is the deliberate way past this one too, the same as the other two. A
project that genuinely pushes to its default branch sets `conventions.protect_default_branch` to
`false`. The hooks are written at install time, so running `keel guard install` again picks up a
newer keel's hooks.

`keel guard install --leak-guard` turns on the leak guard for this repository, which is the only way
to turn it on: it changes what every push and commit does, so it is never on by default, and the
presence of the deny list does not turn it on (the list lives in the owner's home, and on by
presence would refuse his pushes to a client's own repository, which names that client
legitimately). It writes `LEAK_GUARD=1` as the third line of the `pre-push` hook, after the
`VERIFY_KEYS` line, and a fourth hook, `commit-msg`, carrying keel's mark. A plain `keel guard
install` in a repository that never opted in writes `LEAK_GUARD=0` and no `commit-msg`. A reinstall
keeps the choice the installed `pre-push` holds, so one after an upgrade cannot switch the leak
guard off silently; `keel guard install --no-leak-guard` writes `LEAK_GUARD=0` and removes
`commit-msg` when it carries keel's mark. `--leak-guard` refuses, and writes nothing, while a
`commit-msg` without keel's mark exists; a plain install ignores one. `keel guard uninstall` removes
keel's `commit-msg` too, and leaves another tool's.
`keel guard install --leak-guard` belongs in the main working copy and never in a worktree:
worktrees share `.git/hooks`, so an install there replaces the hooks of every worktree at once.

With the leak guard on, the `pre-push` hook feeds `keel scan --leaks <remote> <sha>:<ref>...` every
pushed ref that is not a delete, after the default-branch and profile checks and before the supply
chain scan, and refuses the push on a finding. Each finding names a commit, a field or a file, and
the deny list line whose pattern matched, never the matched text. Run by hand, it runs
`keel scan --leaks origin` with no refs, which prints the mode line. With the deny list absent,
the generic patterns run and a clean push goes through, with a warning saying so.

The `commit-msg` hook rewrites the message through a temporary file, in this order. It removes every
line whose key is `Claude-Session:` in any case and keeps every other line as it is,
`Co-Authored-By:` lines included. It adds `Signed-off-by: <name> <email>`, as
`git var GIT_AUTHOR_IDENT` gives them, once, with
`git interpret-trailers --if-exists addIfDifferent`. Then it runs `keel scan --leaks-message` on
the result and refuses the commit on a finding, keeping the message in `.git/COMMIT_EDITMSG`.
A commit amended with `--no-edit` comes through unchanged.

Both hooks fail closed. A `keel` is usable only when its `--help`, read whole, names `scan --leaks`
(the push) or `scan --leaks-message` (the commit): an older `keel` answers a mode it does not know
by running the supply chain scan and exiting 0, so trusting its exit status would pass every
message.
With no `keel` on PATH, or an unusable one, the push or the commit is refused and says nothing was
checked. This reverses, for the leak guard only, the 2026-09-27 choice the paragraph on the pre-push
hook above states for the supply chain scan, which keeps it: the owner decided on 2026-10-22 that
the leak guard is opted into, and what it guards against cannot be removed once pushed. With
`LEAK_GUARD=0` the hook runs only the checks listed above.

A deny list holding a pattern that is not valid fails closed as well: `keel scan` exits 2 after
naming the deny list line to fix, and the `pre-push` hook refuses with `keel guard: push refused by
the leak guard.`, a push that only deletes a branch included, while the `commit-msg` hook refuses
with its `nothing was checked. Commit refused.` line.

`keel guard status` adds one `leak guard:` line after its others when the installed `pre-push` holds
`LEAK_GUARD=1`: on with the deny list loaded and its pattern count, on with a warning that no deny
list was found, on with `commit-msg` missing or not keel's, or on with the number of deny list
patterns that are not valid, so that every scan refuses. It adds nothing otherwise.

What the leak guard does not cover. `git push --no-verify` and `git commit --no-verify` skip both
hooks. And nothing made on GitHub passes through a hook: merge commits, pull request titles and
bodies, and release notes are written there, so `keel scan --leaks-message <file>` is the way to
check one by hand.

The pre-commit hook is inert until `gates.commit_guard` says otherwise. `off`, which is what `init`
writes, and it exits before checking anything: a team adopts the guard for the push protections
above, and a commit gate arriving uninvited with them is how the whole thing gets uninstalled.
`required` runs `verify.format`, `verify.lint` and `verify.typecheck` and refuses the commit on a
failure; `warn` runs them and lets the commit through. Null and templated commands are skipped, the
same way `keel doctor` skips them, because neither can be run as written.

### keel ci-review

```bash
keel ci-review install [--oauth]
keel ci-review remove
keel ci-review status
```

Review in CI is off until you ask for it, and the workflow file is the switch: present is on, absent
is off. `install` writes one file, `.github/workflows/keel-review.yml`, from
`templates/ci-review.yml`. There is no profile key and `keel doctor` has no check for it, because
there is no setting to read, validate or keep in sync, and a project that never runs the command has
no workflow, no secret and no cost. `status` says whether the file is absent, keel's or not keel's,
and, for keel's file or none where `install` would refuse, why (see below); it writes nothing.
`install` does not commit the file: read it, commit it and push it. `remove` deletes it, and so does
deleting it yourself.

GitHub reads workflows only from the root of the repository, so the command acts there from any
directory of the work tree, and it refuses outside a git work tree and in a bare repository. keel
knows its own file by the first line alone, a mark naming the command. A workflow without that
mark is never overwritten or removed: `install` refuses over it, `remove` leaves it, and `status`
says it exists and is not keel's. A file of yours that quotes the mark further down is still yours.
Running `install` over keel's own file rewrites it, unless one of the refusals below applies, and
that is how `--oauth` switches the secret the workflow reads from the repository secret
`ANTHROPIC_API_KEY` to `CLAUDE_CODE_OAUTH_TOKEN`, a subscription token from `claude setup-token`.
keel never reads, writes or asks for either: it prints the name the workflow reads, and you set
it.

keel's review in CI runs only on GitHub Actions, so it does not run on GitLab, Bitbucket or Azure
DevOps. `install` refuses in two cases, names the file or the host it read, and writes nothing, not
even `.github`:

- another CI system's file, `.gitlab-ci.yml`, `.circleci/config.yml`, `Jenkinsfile`,
  `azure-pipelines.yml`, `bitbucket-pipelines.yml` or `.drone.yml`, with no GitHub workflow of your
  own, meaning no `.yml` or `.yaml` in `.github/workflows` other than keel's own. That repository's
  CI is the other system, and keel does not add a second CI system. This is checked first, so a
  repository with both gets this reason;
- an `origin` whose host contains `gitlab` or `bitbucket`, or is Azure DevOps' cloud
  (`dev.azure.com`, its subdomains, `*.visualstudio.com`). The workflow would never run there. Only
  the host is printed.

Any other host passes, so GitHub Enterprise on any host name and self-hosted Azure DevOps Server are
not refused, and neither is an `origin` keel cannot read. There is no flag to override the refusal.
In a repository on GitHub that carries a stale marker from another CI, delete that marker first.

Where `install` would refuse, `status` says why. With no workflow file it says review in CI is not
available here: for another CI's file, which CI it is, that the repository has no GitHub workflow,
and that keel does not add a second CI system; for the `origin`, that review in CI runs only on
GitHub Actions and which host the `origin` is on. With keel's own file it says the file is a second
CI system, or that it would never run on that host, and that `remove` deletes it. A workflow keel
did not write is still reported as not keel's.

The workflow needs the Claude GitHub App on the repository (https://github.com/apps/claude), the
secret it names, and a project that has run `keel init`; keel sets none of them. It runs
`review-code` through the Claude Code GitHub Action, and the job is asked to read the diff, run
`git diff`, `git log` and `git show`, and post one pull request comment. Its tool list holds `Read`,
`Grep`, `Glob`, `Agent`, those three git commands and one `gh pr comment` command scoped to that
pull request, with no edit tool and no push. **That is what the workflow asks for, not a
guarantee:** `skills/review-code/SKILL.md` declares unrestricted `Bash` in its own frontmatter, and
whether the action honours that is unverified, so nothing here says the job cannot write a file.
The workflow does not use `pull_request_target`, grants `contents: read` and no `contents: write`,
checks out with `persist-credentials: false`, and puts only the pull request number and two commit
hashes in the prompt, never a branch name or the title or body of a pull request.

It skips drafts, pull requests from forks, because GitHub withholds the secret from them, and
Dependabot, which has no Actions secret. It runs when a pull request is opened, made ready for
review or reopened, and not on each push, because a review per push is the cost people turn this
off over. Adding `synchronize` to `types` in the file gives that, and one session for every push.
Each run is a Claude session on your account, bounded by `--max-turns 30` and a 20 minute job
timeout. It cannot run the suite, because the job's tools allow no test command and allowing the
profile's would widen what a pull request's content can make the job execute, so the report says
"suite not run in CI".

Residual risk: the reviewer reads a pull request's content and can read files on the runner, so a
repository secret could in principle be shown in a comment by a crafted change. Opening a pull
request from a branch of the same repository needs write access to it, which limits who can try.
`persist-credentials: false` and the scoped comment command close the obvious path. The tool
allowlist is the only restriction on the reviewer, and no deny rule is set for reading `/proc` or
`.git/config`.

`anthropics/claude-code-action@v1` is a tag, the form the vendor documents, and not a commit. Pin
it to a commit, with the tag in a trailing comment, as `.github/workflows/ci.yml` pins the other
actions. This is GitHub only: there is no GitLab version. The tests pin
what the file says and what the command does; the workflow has not been run against a real
repository.

Two more limits are unverified. `git diff`, `git log` and `git show` accept `--output=<file>`, so
the `Bash(git diff:*)`, `Bash(git log:*)` and `Bash(git show:*)` entries do not stop those commands
writing a file. That has not been tried in CI, and it is one more reason the read-only limit is
stated as the workflow's intent and not as a guarantee. The `plugin_marketplaces` URL names no ref,
so the job is expected to install whatever keel's default branch holds, not the keel version in
your project. That is unverified until a real run, and the job holds the secret at that point.

## `keel-fleet <repo-path>... | --file <path-list-file>`

Fans out `keel doctor --json --fast` across repositories and prints one tab-separated row per
repository: `repo`, `keel_version`, `schema_version`, `verify_test_null`, `problems`,
`warnings`.
Exits non-zero if any repository has a problem or could not be read. It is a second binary the
plugin adds to `PATH` alongside `keel`, not a `keel` subcommand, and it runs the `keel` sitting
next to it, falling back to the one on `PATH`, so the login-shell install's single symlink is
enough.

The prepare-commit-msg hook appends a `Keel-Version: <version>` trailer to each commit message,
unless the profile sets `conventions.no_attribution_footers` to `true`,
read from `.keel/profile.json`'s `keel_version` field, so which standard a change was made under
survives into `git log` rather than only being visible live during the session that made it. It
never duplicates the trailer on `git commit --amend`. Unlike the pre-push and pre-commit hooks,
`git commit --no-verify` does not skip it; only running git with hooks disabled, such as
`git -c core.hooksPath=/dev/null commit`, skips the trailer.
A repository whose commit messages carry a title and body only sets
`conventions.no_attribution_footers` to `true` in its profile, and the hook then adds nothing.
A hook written by an older keel adds the trailer whatever that key says; `keel guard status` names
that case, and `keel guard install` replaces the hook.

It refuses and never formats. Both `house-defaults.md` and `coding-standards` require a gate to be a
check-only command, and a hook that rewrote your files and re-staged them would put content into a
commit its author never read. So a refusal names `verify.format_fix` as the remedy and leaves the
tree alone. `git commit --no-verify` is the deliberate way past it.

The full test suite is not here, and neither is `verify.test_one`: the hook has no way to derive a
test path from a changed file, and an expensive commit produces fewer, larger commits. See open
decision 4.

```bash
keel profile get <dotted.path>
keel profile set <dotted.path> <value>
keel profile sync
```

Reads and writes one field of `.keel/profile.json`. `init` writes the profile once and then defends
every human value in it, which is right for a re-init and wrong for a fact that has changed since, so
this is how a project records that it grew a user interface without hand-editing JSON. `true`, `false`
and `null` are written as JSON literals rather than the strings that spell them, and a bare integer as
a number. A path that does not already exist is refused, since a typo would otherwise write a key
nothing reads while the caller walks away believing the fact was recorded. `keel_version` and
`schema_version` are refused too: `init` owns both. A value outside the enum the profile schema
declares for that key is refused as well, and the refusal names the values it accepts. `null` still
clears one.

`sync` is the same map filled from the other direction. It records where this project's documents
already are, for the three artifact keys whose default is one unambiguous location: `snapshot`,
`decisions` and `plans`. A key that already holds a value is never touched, since that value is the
override the map exists for, and a directory holding nothing but `init`'s own `ADR-0000-template.md`
is not a document set. `prd`, `stories` and `architecture` are deliberately never filled: each
defaults to one file per slug, so a repository with five PRDs has no single path a string key could
hold. `keel doctor` warns when a fillable key is null and its documents are there, which is how
anyone finds out the command exists.

```bash
keel new <name> [--stack node|python|go|minimal]
```

Greenfield scaffolding. Creates the directory, initialises git, lays down the keel layer, a CI
workflow that fails on a broken build, and a sample test that passes.

**It does not scaffold an application, deliberately.** An opinionated framework skeleton would rot
within two releases and would be a recommendation nobody asked for. `design-architecture` chooses the
stack, after `write-prd` establishes what is being built. The sample source file exists so the
project has somewhere for its first real test to go, and it says so in a comment.

**The property that matters: doctor's only failure on a fresh project is the one thing `new`
told it about, and nothing else.** That is tested. It also warns that the push guard is not
installed, which `keel guard install` clears. `gates.coding_standards` defaults to required
and `new` cannot write `docs/standards.md` itself, so doctor names that gap and `NEXT-STEPS.md`
puts writing it first. Past that, the sample test must run with nothing installed, so node uses
`node --test`, python uses `unittest`, and the minimal stack uses a shell script. Where detection
would infer a command whose tool is absent, `new` states the command instead, because it knows
what it generated.

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

## Other harnesses

`keel init` writes the managed block to `CLAUDE.md` alone. An `AGENTS.md` already in the
repository is left byte for byte and unstaged, and `keel doctor` does not read it, because its
readers are other harnesses and keel serves Claude Code only (ADR-0013).
v0.26.0 is the last keel release that wrote `AGENTS.md`, which Cursor, Codex, Copilot CLI and
Gemini CLI read.

v0.26.0 is also the last keel release with Codex support, and a separate keel plugin for Codex is
planned. Until it ships, a Codex user installs the v0.26.0 tag:

```bash
codex plugin marketplace add gbi-solutions-ltd/keel --ref v0.26.0 && codex plugin add keel@gbi
```

## Rollout

1. Build it, then pilot on exactly two repos: one existing service and one greenfield.
2. Run for two weeks. Collect what broke and what got skipped.
3. Fix, then roll to volunteers.
4. Only then make `keel doctor` a CI requirement, and only for repos that have opted in.

Making it mandatory before it is good is the fastest way to have everyone route around it.
