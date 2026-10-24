# Runbook: cutting a keel release

**Covers:** everything between "a release is due" and a published GitHub release, all in
`gbi-solutions-ltd/keel`: the eval gate, the version-bump pull request, the merge, the annotated
tag on the merged commit and the GitHub release.

**Does not cover:** deciding that a release is due, or which number it gets. That is the owner's
call, and it is the first section below because getting it wrong is the one thing here that cannot
be undone. A change that is not a release lands through a pull request like any other. First
publication of a repository is [`going-public.md`](going-public.md).

The commands of sections 0 and 1 and the version-bump steps of section 2 were run end to end for
0.17.0 on 2026-09-01 and their output is what is quoted. The branch step in section 2 and all of
sections 3 and 4 have not yet been run on a release. The symptoms table is wider than one release:
rows marked *recorded* come from the 2026-08-17 and 2026-08-19 runs and were not reproduced on that
one.

There is one repository, `gbi-solutions-ltd/keel`, and it is public. Every branch pushed to it is
public the moment it lands, so nothing goes onto a branch that is not fit to read, and the leak
guard in section 3 runs on every push.

## 0. Before anything: three decisions

1. **Is a release due?** Entries accumulate under `CHANGELOG.md`'s `## Unreleased` and a release is
   a decision about a set of changes, not a side effect of the last PR to merge. Do not bump because
   the changelog looks full.
2. **Which number?** Semver. Note that 1.0.0 is held back pending two team pilots and a verified
   install from a second machine.
3. **Does the gate transfer, or is it owed?** See section 1.

## 1. The eval gate

Seven treatment arms, one dispatch each, scored by reading. They cost real money: the 0.17.0 gate
was **$2.3430** and 2 minutes 16 seconds of wall clock.

**When it transfers.** 0.16.1 shipped on the 0.16.0 gate because no skill body and no eval fixture
changed, and no scenario exercised the one thing that did. That is the whole test: if the diff since
the last tag touches a skill body or a fixture, the gate is owed.

```bash
git diff --stat "v$(cat VERSION)"..HEAD -- skills/ tests/evals/
```

Empty output is the only thing that lets a gate transfer, and say so in the CHANGELOG entry when it
does.

**Dispatch all 7 concurrently.** Staging once per arm is what makes that safe, and serial
dispatch costs the same money for four times the wall clock. The mechanics, and why every flag on
the `claude -p` line is load bearing, are in `tests/evals/README.md`; do not re-derive them.
Arms run with `bypassPermissions` and search the whole machine, so a gate is dispatched where
nothing else is within reach (L-01 of `docs/audits/2026-10-18-security.md`). `tests/evals/gate.sh`
stages every arm and writes `OUT/dispatch.sh`, and dispatches nothing. Stage into an `OUT` outside
the tree, in a disposable workspace (a cloud session or a container) that holds no personal
credentials beyond a scoped key for the gate and no other repositories, delete the checkout there,
then run the dispatch, which refuses while anything keel-shaped is reachable:

```bash
tests/evals/gate.sh /tmp/keel-gate-run                      # one run of each arm
tests/evals/gate.sh --runs 3 --model <id> /tmp/keel-gate-3  # a pass rate needs more than one run
tests/evals/gate.sh --dry-run /tmp/keel-gate-dry            # stage and print; lines have no check
# delete the checkout from this workspace, then:
bash /tmp/keel-gate-run/dispatch.sh                         # refuses if keel is reachable
```

Results are written to `OUT/<scenario>.<run>.jsonl`, with the arm's `.err` and its `.dir` file
beside it and one `exit=` line per arm in `OUT/exits.txt`. The stream's final `result` record
carries the model and the cost, which is where the `results.md` entry takes them from. `OUT` must
be outside the repository and must not already hold `.dir` files; the script refuses both, for the
reasons in its header. The set is `tests/evals/gate-scenarios` and nowhere else: it was pasted into
this runbook until 2026-09-06, which is how a script ran six arms while `results.md` said seven.

**Keep the `.dir` files.** Scoring is reading, it is slow, and a session can run out of context
half way through it. The staged directories survive until the OS clears them, so an unfinished gate
is resumed by reading the artifacts rather than by paying for the arms twice. The 0.17.0 gate was
scored across two sessions exactly this way, four arms then two, at no extra cost. Write the paths
into the `results.md` entry as you go and mark the entry INCOMPLETE until every arm is scored. In a
disposable workspace, copy `OUT` and the staged directories out, or score before discarding the
workspace, because they go with it.

**Score against the scenario file, not from memory.** Each `tests/evals/scenarios/<name>.md` carries
its own criteria and several are scored on an artifact rather than on the reply:
`done-without-verifying` is scored on `project/PLAN.md`, `commit-outside-a-worktree` on git state.
Record the grade where a scenario defines one, not just the verdict: a run that moves down the form
list has changed behaviour even when the verdict has not.

**Then record it twice**, in `tests/evals/results.md` with the date, cost and method, and in the
CHANGELOG entry for the release: which passed, which failed, and **the exact rationalisation any
failure used, verbatim**. A new rationalisation is the most valuable thing the gate produces,
because it goes into the skill's table and closes a loophole nobody had imagined.

A failed arm is not automatically a blocked release, but it is the owner's decision and it is
recorded in the CHANGELOG either way.

## 2. The version bump

Do the bump on a branch `release/X.Y.Z` from `main`, never on `main` itself:

```bash
git fetch origin && git switch -c release/0.17.0 origin/main
```

**Four places, one commit, because `tests/test-keel.sh` pins them to each other:**

1. `VERSION`, which drives the CLI and every project's profile
2. `.claude-plugin/plugin.json`, which keys the installed plugin cache on Claude Code
3. `.codex-plugin/plugin.json`, which keys it on Codex. Added 2026-09-06 with Tier B, and the
   version check globs `.*-plugin/plugin.json` rather than naming them, so a third manifest is
   covered on the day it is added rather than the day it drifts
4. `CHANGELOG.md`'s newest `## ` heading, which is what a human reads

```bash
printf '0.17.0\n' > VERSION
# edit .claude-plugin/plugin.json "version"
# edit .codex-plugin/plugin.json "version"
# change `## Unreleased` to `## 0.17.0 - YYYY-MM-DD`, and add the gate result to that entry
```

**Why all of them and not some.** They drifted once: `VERSION` reached 0.3.0 with a whole feature
behind it while `plugin.json` still said 0.2.0. Nothing failed, `keel version` was right and the
CHANGELOG was right, and every install stayed on the previous skills because the cache had already
seen 0.2.0 and had no reason to fetch again. The symptom is a skill fix that reaches nobody and
cannot be reproduced by its author, whose working tree is correct.

**The suite goes red at this point, in two files, and that is normal:**

```
  FAIL  doctor output unchanged against HEAD: 13c13 < ok    configured by keel 0.22.0 --- > ok    configured by keel 0.23.0
== tests/test-cache-install.sh (1s)
  FAIL  version, from a tracked-files-only copy (got: 0.22.0)
```

Both compare the committed tree against the working one. `tests/test-cache-install.sh` builds its
copy with `git archive HEAD` and compares `keel version` from it against the working `VERSION`.
`tests/test-keel.sh` runs `keel doctor` from a worktree of `HEAD` and diffs its output against the
working tree's, and doctor prints the version. Between the edit and the commit both genuinely
disagree. **Commit, then re-run, and require green.** Those two failures, with the version as the
only difference, are expected; anything else is not. The second was first seen at 0.23.0.

```bash
tests/run-tests.sh          # expect the two failures above
git add VERSION .claude-plugin/plugin.json .codex-plugin/plugin.json CHANGELOG.md
git commit -s -m "release: 0.17.0"
tests/run-tests.sh          # expect: All test files passed
```

The release machine has `shellcheck` (0.11.0 at 0.23.0), and `run-tests.sh` runs it as the last
step, printing `OK    shellcheck clean`. On a machine without it, `run-tests.sh` prints `SKIP` and
only CI runs it. Section 3's wait is not optional either way, because CI is what proves the release
commit itself.

## 3. Land it

The release commit reaches `main` through a pull request from `release/X.Y.Z`, reviewed by someone
other than its author.

1. Write the gate result into the pull request body, with any accepted failure named, and check
   that file before anything is published, since a pull request body is public too:
   ```bash
   keel scan --leaks-message <body-file>
   ```
2. Push the release branch from your own terminal, and read the leak guard's mode line first:
   ```bash
   git push origin release/0.17.0
   ```
   ```
   leak guard: deny list loaded from ~/.config/keel/internal-deny-list.txt (25 patterns)
   ```
   The line must say the deny list is loaded and give the owner's full count. A `WARNING no deny
   list` line means only the 2 generic patterns ran: see Symptoms. The push is public the moment it
   lands, so the guard is the only check between this machine and the world.
3. Open the pull request, which is what starts CI:
   ```bash
   gh pr create --base main --head release/0.17.0 --title "release: 0.17.0" --body-file <body-file>
   ```
4. Wait for CI on the pull request, the `DCO sign-off` job included, **on the release commit
   specifically**. CI builds on pull requests and on pushes to `main` only, so there is nothing to
   wait for before this step:
   ```bash
   gh run view <run-id> --json headSha,conclusion -q '.headSha + " " + .conclusion'
   ```
   A green run against the previous head is not a green release. Read the SHA.
5. Review by the reviewer who is not the author.
6. Merge, and read the result rather than chaining on it:
   ```bash
   gh pr merge <n> --merge
   gh pr view <n> --json state,mergeCommit -q '.state + " " + .mergeCommit.oid'
   ```

## 4. Sweep, tag and release

**First Tier B release only: the CHANGELOG entry must carry the CCA warning in plain words.** Not a
link to the design, and not a sentence about capability manifests. The text to paste is in
`docs/architecture/tiered-multi-harness-support.md` section 9, and it says that on Codex two of the
three gates stop blocking if an upstream change lands, that nothing in keel will go red when it
does, and what to check. A person reading only the CHANGELOG has to learn this; it is the one risk
in Tier B that a keel user cannot detect for themselves.

Nothing in this section is reversible. A tag and a release are public the moment they are pushed,
and making a repository private again does not recall clones or forks.

**1. Fetch, and sweep the merge commit.** The release-time sweep runs over the tracked tree of the
commit that was merged, on a detached checkout of it:

```bash
git fetch origin --tags
git switch --detach <merge-sha>
tests/no-internal-leaks.sh
```

```
mode  internal deny list loaded from <home>/.config/keel/internal-deny-list.txt (25 patterns)
OK    no project-specific identifiers
```

**Read the mode line, not just the OK.** The scanner takes no directory argument: passing one is
silently ignored and it sweeps `git ls-files` of wherever it is run, which is why the sweep runs on
the detached checkout and not on whatever branch happens to be out. `git ls-files` is also why a
new file has to be `git add`ed before the suite means anything: an untracked file is invisible to
this scanner, and to the supply chain scan beside it. That is also why the untracked `docs/audits/`
on the owner's machine is not swept: it is not in `git ls-files`. The real mode line names the home
directory it loaded from, which is why it is elided above: this repository's own sweep rejects a
developer's absolute path in a tracked file. And the deny list lives outside the tree at
`~/.config/keel/internal-deny-list.txt`, so on a machine without it the scan degrades to two
generic patterns and still prints `OK`. Two things must both be true: **the full pattern count**,
and `OK`.

**2. Check the tag message and the release notes.** Both are public text:

```bash
keel scan --leaks-message <message-file>
keel scan --leaks-message <notes-file>
```

**3. Tag the merge commit, annotated.** The tag message is the release summary;
`git tag -l -n30 v0.16.1` shows the house shape. The leak guard checks the tag's message on push.

```bash
git tag -a v0.17.0 <merge-sha> -F <message-file>
git push origin v0.17.0
```

Each push needs a Touch ID approval, because the signing key is in Secretive.

**4. Release.**

```bash
gh release create v0.17.0 --repo gbi-solutions-ltd/keel \
    --title "keel 0.17.0" --notes-file <notes-file> --latest
```

Release notes are written for someone who has never read this repository: no commit SHAs, no PR
numbers, no path that exists only in the private clone. `gh release view v0.16.1 --repo
gbi-solutions-ltd/keel --json body` is the house shape.

**5. Verify what shipped, through the API rather than from your clone.**

```bash
gh api "repos/gbi-solutions-ltd/keel/contents/VERSION?ref=v0.17.0" -q .content | base64 -d   # 0.17.0
gh api "repos/gbi-solutions-ltd/keel/contents/docs/audits?ref=v0.17.0"                       # expect 404
```

`VERSION` at the tag must read the number just released, and `docs/audits` at the tag must be a 404:
the directory is the security posture of real services, named, and it lives only in the private
clone. `.claude/` is published, so there is no 404 check for it. A local clone shows what you
built. The API shows what people can read.

## Symptoms

| Symptom | Likely cause | Action |
|---|---|---|
| `FAIL version, from a tracked-files-only copy (got: <old>)` and `FAIL doctor output unchanged against HEAD`, differing only in the version, and nothing else | The bump is edited but not committed | Expected. Commit, re-run, require green |
| Any other test red at bump time | Not the bump | Stop. Fix it in its own change |
| `gh pr checks` green but the release commit was never built | The check ran against the previous head | Read `headSha` on the run, not the PR |
| The push prints `leak guard: WARNING no deny list` | The deny list is absent on this machine, so only the 2 generic patterns ran | Do not push. Restore `~/.config/keel/internal-deny-list.txt` and push again |
| The push is refused with `keel is not on PATH` | The leak guard cannot find `keel` | Put this working copy's `bin/keel` on PATH and push again |
| The `DCO sign-off` check fails on the pull request | A commit on the branch has no `Signed-off-by` line | `git rebase --signoff main`, then push the branch again |
| A validator reports a broken citation into `docs/audits/` on the owner's machine | The private clone is behind, or missing a file | Pull it |
| The sweep prints `OK` with "generic patterns only" | The deny list is absent on this machine | Do not push. Restore `~/.config/keel/internal-deny-list.txt` and re-sweep |
| Push protection rejects a push | A test fixture shaped like a credential | Fix at the cause, not the unblock link. Sweep per provider: the first sweep missed a Stripe key by searching the OpenAI shape. *Recorded* |
| A skill fix reaches nobody after a release | a `plugin.json` disagrees with `VERSION` | The cache is keyed on `plugin.json`, and there are two of them since Tier B. Bump all four. *Recorded* |
| A `main...release/X.Y.Z` range gives obviously wrong counts | Local `main` is behind `origin/main` | `git fetch` first. It has produced a wrong artifact before |
| The release commit passes CI on the PR and fails the same checks on `main` | A `producer \| grep -q` under `pipefail`, not the tree. grep leaves at the first match and the producer's 141 fails the pipeline | Read the failures for a common shape before re-running. Fix the pipeline, not the thing it accused |

## Do not

- **Do not bump `VERSION` as part of an ordinary ship.** A release is a decision about a set of
  changes. Ship with `## Unreleased` entries and leave the number alone; offer the bump, do not take
  it.
- **Start every change on its own branch from `main`.** A release is committed on `release/X.Y.Z`,
  and the rule breaks by committing on `main` or by sitting there afterwards.
- **Do not re-dispatch an eval arm whose staged directory still exists.** It is the same arm at
  full price, and scoring is reading.
- **Do not quietly turn a documentation change into a release to get it published.** Plugin
  installs are keyed by version, so a commit on `main` with no tag reaches no installed user, which
  is a reason to land the change through a pull request and release when one is due, not a reason to
  cut a release for it.
- **Do not add `keel-internal` as a remote of this working copy, and never push its history: it is
  archived, and every deny pattern is reachable in it.** One wrong `git push` of that history would
  publish all of them.
- **Do not fix a red check as part of releasing.** A gate that repairs its own failures is not a
  gate, and the fix belongs in its own reviewed change.

## Who decides what

| Decision | Whose |
|---|---|
| Whether a release is due, and its number | Bernard |
| Accepting a failed eval arm and releasing anyway | Bernard, named in the CHANGELOG |
| What is withheld (`tests/withheld.sh`) | Bernard. `docs/audits/` is the standing answer |
| Everything else here | Whoever is running the release |

## Still open

**Settled 2026-09-06: the gate is seven, and the set is `tests/evals/gate-scenarios`.**
`commit-outside-a-worktree` is IN, being the only scenario that tests a subagent's behaviour, a path
nothing else exercises. Releases through 0.17.0 ran six, so the next gate runs one arm more than the
last one did. The dispatch script in section 1 reads that file now instead of carrying its own copy,
which is what let the two disagree.

`tests/evals/gate.sh` was committed on 2026-10-17, so section 1 runs it rather than a pasted script.
