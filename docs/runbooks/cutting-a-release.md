# Runbook: cutting a keel release

**Covers:** everything between "a release is due" and a published GitHub release on the public
repository, including the eval gate, the three-place version bump, the merge, both tags, and the
public export.

**Does not cover:** deciding that a release is due, or which number it gets. That is the owner's
call, and it is the first section below because getting it wrong is the one thing here that cannot
be undone. Publishing a non-release change to the public tree is
[`going-public.md`](going-public.md) section 7a, not this document. First publication of a
repository is that document too.

**Executed end to end for 0.17.0 on 2026-09-01**, internal `e35df65`, public `8b3e4f2`. Every
command below was run on that release and its output is what is quoted. The symptoms table is wider
than one release: rows marked *recorded* come from the 2026-08-17 and 2026-08-19 runs and were not
reproduced on this one.

Two repositories are involved and confusing them is the expensive mistake:

| Name | Path | What it is |
|---|---|---|
| internal | `gbi-solutions-ltd/keel-internal` | This repository, private, full history, `origin` here |
| public | `gbi-solutions-ltd/keel` | A fresh tree with no shared history, **one commit per release** |

The history is not publishable: every deny pattern is reachable in it, and six files and two
commit messages carry client identifiers. That is why the public tree is an export rather than a mirror,
and why nothing here ever pushes this repository's history anywhere.

## 0. Before anything: three decisions

1. **Is a release due?** Entries accumulate under `CHANGELOG.md`'s `## Unreleased` and a release is
   a decision about a set of changes, not a side effect of the last PR to merge. Do not bump because
   the changelog looks full.
2. **Which number?** Semver. Note that 1.0.0 is held back pending two team pilots and a verified
   install from a second machine.
3. **Does the gate transfer, or is it owed?** See section 1.

## 1. The eval gate

Six treatment arms, one dispatch each, scored by reading. They cost real money: the 0.17.0 gate was
**$2.3430** and 2 minutes 16 seconds of wall clock.

**When it transfers.** 0.16.1 shipped on the 0.16.0 gate because no skill body and no eval fixture
changed, and no scenario exercised the one thing that did. That is the whole test: if the diff since
the last tag touches a skill body or a fixture, the gate is owed.

```bash
git diff --stat "v$(cat VERSION)"..HEAD -- skills/ tests/evals/
```

Empty output is the only thing that lets a gate transfer, and say so in the CHANGELOG entry when it
does.

**Dispatch all six concurrently.** Staging once per arm is what makes that safe, and serial
dispatch costs the same money for four times the wall clock. The mechanics, and why every flag on
the `claude -p` line is load bearing, are in `tests/evals/README.md`; do not re-derive them. This is
the script the 0.17.0 gate ran, kept here because it lives in no repository yet:

```bash
#!/usr/bin/env bash
# Dispatch the six release-gate treatment arms in parallel, one staged directory each.
set -uo pipefail
REPO=/path/to/keel
OUT=./gate-run
mkdir -p "$OUT"

ARMS="tdd-under-deadline debug-obvious-cause ship-with-flaky-tests build-with-no-prd done-without-verifying incident-diagnose-first"

for a in $ARMS; do
    dir="$(cd "$REPO" && tests/evals/stage.sh "$a" 2>"$OUT/$a.stage-err")"
    if [ -z "$dir" ]; then printf 'STAGE FAILED: %s\n' "$a"; cat "$OUT/$a.stage-err"; continue; fi
    printf '%s\n' "$dir" > "$OUT/$a.dir"
    (
        cd "$dir/project" || exit 1
        claude -p "$(cat ../prompt.md)" \
            --setting-sources "" --disable-slash-commands \
            --permission-mode bypassPermissions --output-format json \
            > "$dir/result.json" 2>"$dir/result.err"
        printf '%s exit=%s\n' "$a" "$?" >> "$OUT/exits.txt"
    ) &
    printf 'dispatched %-26s %s\n' "$a" "$dir"
done

wait
```

**Keep the `.dir` files.** Scoring is reading, it is slow, and a session can run out of context
half way through it. The staged directories survive until the OS clears them, so an unfinished gate
is resumed by reading the artifacts rather than by paying for the arms twice. The 0.17.0 gate was
scored across two sessions exactly this way, four arms then two, at no extra cost. Write the paths
into the `results.md` entry as you go and mark the entry INCOMPLETE until every arm is scored.

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

**Three places, one commit, because `tests/test-keel.sh` pins them to each other:**

1. `VERSION`, which drives the CLI and every project's profile
2. `.claude-plugin/plugin.json`, which keys the installed plugin cache
3. `CHANGELOG.md`'s newest `## ` heading, which is what a human reads

```bash
printf '0.17.0\n' > VERSION
# edit .claude-plugin/plugin.json "version"
# change `## Unreleased` to `## 0.17.0 - YYYY-MM-DD`, and add the gate result to that entry
```

**Why all three and not two.** They drifted once: `VERSION` reached 0.3.0 with a whole feature
behind it while `plugin.json` still said 0.2.0. Nothing failed, `keel version` was right and the
CHANGELOG was right, and every install stayed on the previous skills because the cache had already
seen 0.2.0 and had no reason to fetch again. The symptom is a skill fix that reaches nobody and
cannot be reproduced by its author, whose working tree is correct.

**The suite goes red at this point, once, and that is normal:**

```
== tests/test-cache-install.sh (1s)
  FAIL  version, from a tracked-files-only copy (got: 0.16.1)
```

`tests/test-cache-install.sh` builds its copy with `git archive HEAD` and compares `keel version`
from it against the working `VERSION`, so between the edit and the commit those two genuinely
disagree. **Commit, then re-run, and require green.** One failing file with that exact message is
expected; anything else is not.

```bash
tests/run-tests.sh          # expect the one failure above
git add VERSION .claude-plugin/plugin.json CHANGELOG.md
git commit                  # "release: 0.17.0"
tests/run-tests.sh          # expect: All test files passed
```

`shellcheck` is not installed on the release machine and `run-tests.sh` prints `SKIP` for it. CI
runs it. That is the one check that is only ever green in CI, so section 3's wait is not optional.

## 3. Land it internally

All work is on `sandbox` and reaches `main` through a PR. Never commit a release on `main`.

1. Push and wait for CI **on the release commit specifically**:
   ```bash
   git push origin sandbox
   gh run view <run-id> --json headSha,conclusion -q '.headSha + " " + .conclusion'
   ```
   A green run against the previous head is not a green release. Read the SHA.
2. Put the gate result in the PR body, with any accepted failure named.
3. Merge, and read the result rather than chaining on it:
   ```bash
   gh pr merge <n> --merge
   gh pr view <n> --json state,mergeCommit -q '.state + " " + .mergeCommit.oid'
   ```
4. **Tag the merge commit, annotated, without checking out `main`.** The tag message is the release
   summary; `git tag -l -n30 v0.16.1` shows the house shape.
   ```bash
   git fetch origin --tags
   git tag -a v0.17.0 <merge-sha> -F <message-file>
   git push origin v0.17.0
   ```
   Both pushes need a Touch ID approval, because the signing key is in Secretive.
5. Bring `sandbox` level with `main` so the next session starts clean:
   ```bash
   git merge --ff-only origin/main && git push origin sandbox
   ```

## 4. Publish

Nothing in this section is reversible. Making a repository private again does not recall clones or
forks, and a fork network keeps objects reachable after the parent is locked down.

**1. Export.** Tracked files only, via `git ls-files`, so nothing untracked or ignored can be
carried out by accident. Confirm the working tree matches what was merged first:

```bash
git rev-parse <merge-sha>^{tree}    # must equal
git rev-parse HEAD^{tree}           # this
tests/export-public.sh /tmp/keel-export
```

```
exported 280 files to /tmp/keel-export, skipped 14
excluded: docs/audits, .claude, .keel/handoff.md
```

**Note both numbers.** The exclusions are the exposure, not a tidy-up: `docs/audits/` holds the
security posture of real services, named. If this release added an audit, the thing to verify is
that the exclusion fired, not to edit anything.

**2. Commit inside the export, then run its suite.** In that order.

```bash
cd /tmp/keel-export && git init -q && git add -A \
    && git -c user.name=export -c user.email=export@local commit -qm export \
    && tests/run-tests.sh          # All test files passed
```

Committing first because `tests/test-cache-install.sh` archives `HEAD` and a staged index with no
commit has none, which fails for a reason that has nothing to do with the export. Committing
afterwards is worse: a suite run leaves `lib/__pycache__/*.pyc` behind and `rsync` does not read
`.gitignore`.

This step is what caught the manifest defect in the first publication. A subset that fails its own
validator is not a release.

**3. Sweep the export, from inside it.**

```bash
cd /tmp/keel-export && ./tests/no-internal-leaks.sh
```

```
mode  internal deny list loaded from <home>/.config/keel/internal-deny-list.txt (25 patterns)
OK    no project-specific identifiers
```

**Read the mode line, not just the OK.** The scanner takes no directory argument: passing one is
silently ignored and it sweeps `git ls-files` of wherever it is run, so running it from this
repository's root prints the same `OK` having swept the wrong tree. `git ls-files` is also why a
new file has to be `git add`ed before the suite means anything: an untracked file is invisible to
this scanner, and to the supply chain scan beside it. The real mode line names the home directory
it loaded from, which is why it is elided above: this repository's own sweep rejects a developer's
absolute path in a tracked file. And the deny list lives outside
the tree at `~/.config/keel/internal-deny-list.txt`, so on a machine without it the scan degrades to
two generic patterns and still prints `OK`. Two things must both be true: **25 patterns**, and
`OK`.

**4. Sync into a clone of the public repository and check the count.**

```bash
git clone git@github-personal:gbi-solutions-ltd/keel.git /tmp/keel-public
rsync -a --delete --exclude '.git/' /tmp/keel-export/ /tmp/keel-public/
cd /tmp/keel-public && git add -A && git ls-files | wc -l    # must equal the export's number
git status --short | awk '{print $1}' | sort | uniq -c
```

The count must equal what `export-public.sh` printed: 280 for 0.17.0. A disagreement of three is how
the `.pyc` files above were caught.

**5. Commit, push, tag, release.** One commit per release, titled `keel <version>`.

```bash
git commit -F <message-file>
git push origin main
git tag -a v0.17.0 -m "keel 0.17.0" && git push origin v0.17.0
gh release create v0.17.0 --repo gbi-solutions-ltd/keel \
    --title "keel 0.17.0" --notes-file <notes> --latest
```

Release notes are written for someone who has never read this repository: no internal commit SHAs,
no PR numbers, no paths that only exist here. `gh release view v0.16.1 --repo gbi-solutions-ltd/keel
--json body` is the house shape.

**6. Verify what shipped, through the API rather than from your clone.**

```bash
gh api "repos/gbi-solutions-ltd/keel/contents/VERSION?ref=v0.17.0" -q .content | base64 -d
gh api "repos/gbi-solutions-ltd/keel/contents/docs/audits?ref=main"     # expect 404
gh api "repos/gbi-solutions-ltd/keel/contents/.claude?ref=main"         # expect 404
```

A local clone shows what you built. The API shows what people can read.

## Symptoms

| Symptom | Likely cause | Action |
|---|---|---|
| `FAIL version, from a tracked-files-only copy (got: <old>)`, alone | The bump is edited but not committed | Expected. Commit, re-run, require green |
| Any other test red at bump time | Not the bump | Stop. Fix it in its own change |
| `gh pr checks` green but the release commit was never built | The check ran against the previous head | Read `headSha` on the run, not the PR |
| The export's file count and the clone's disagree | A suite run left `.pyc` files that `rsync` copied | Re-export from a clean tree, commit inside it before running the suite. *Recorded* |
| The sweep prints `OK` with "generic patterns only" | The deny list is absent on this machine | Do not push. Restore `~/.config/keel/internal-deny-list.txt` and re-sweep |
| Push protection rejects the public push | A test fixture shaped like a credential | Fix at the cause, not the unblock link. Sweep per provider: the first sweep missed a Stripe key by searching the OpenAI shape. *Recorded* |
| A skill fix reaches nobody after a release | `plugin.json` disagrees with `VERSION` | The cache is keyed on `plugin.json`. Bump all three. *Recorded* |
| A `main...sandbox` range gives obviously wrong counts | Local `main` is behind `origin/main` | `git fetch` first. It has produced a wrong artifact before |
| The release commit passes CI on the PR and fails the same checks on `main` | A `producer \| grep -q` under `pipefail`, not the tree. grep leaves at the first match and the producer's 141 fails the pipeline | Read the failures for a common shape before re-running. Fix the pipeline, not the thing it accused |

## Do not

- **Do not bump `VERSION` as part of an ordinary ship.** A release is a decision about a set of
  changes. Ship with `## Unreleased` entries and leave the number alone; offer the bump, do not take
  it.
- **Do not stay on `main` after merging.** Work happens on `sandbox`, and the rule breaks by
  sitting on `main` afterwards.
- **Do not re-dispatch an eval arm whose staged directory still exists.** It is the same arm at
  full price, and scoring is reading.
- **Do not quietly turn a documentation change into a release to get it published.** Plugin
  installs are keyed by version, so an untagged commit on public `main` reaches no installed user,
  which is a reason to publish an update rather than a reason to cut a release. Section 7a of
  [`going-public.md`](going-public.md) is the route for that.
- **Do not push the public tree from this repository, or add it as a remote here.** The export is
  built in a scratch directory and pushed from a clone of the public repository, so there is no
  configuration in which one wrong `git push` publishes this repository's history.
- **Do not fix a red check as part of releasing.** A gate that repairs its own failures is not a
  gate, and the fix belongs in its own reviewed change.

## Who decides what

| Decision | Whose |
|---|---|
| Whether a release is due, and its number | Bernard |
| Accepting a failed eval arm and releasing anyway | Bernard, named in the CHANGELOG |
| Whether an export exclusion is right | Bernard. `docs/audits/` is the standing answer |
| Everything else here | Whoever is running the release |

## Still open

The gate is documented as six scenarios in `tests/evals/README.md` and as seven in
`tests/evals/results.md`. Nine exist and two are recorded as non-gate, which leaves seven, so
`commit-outside-a-worktree`'s membership is the live question. Releases through 0.17.0 ran the same
six named in section 1.

The dispatch script in section 1 belongs in `tests/evals/gate.sh`, where it would be tested and
maintained rather than pasted. It has produced two gates from a scratch directory.
