# Opt-in CI review Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** a project that wants keel's `review-code` to run on its pull requests in GitHub Actions
runs one command to get the workflow, and a project that runs nothing has no workflow, no secret
and no cost.
**Stories:** none. See "There are no stories" below.
**ADRs:** none written for this. ADR-0003 (no claim without evidence) is why the docs word the
workflow's read-only limit as intent until a real run shows it; ADR-0004 is why they say the review
runs on Claude Code only.
**Architecture:** no new skill, hook, gate or profile key. One workflow template in `templates/`,
one new command `keel ci-review install|remove|status` beside `keel guard`, one new test file. The
switch is the workflow file: present means on, absent means off. Decided by Bernard on 2026-10-13
(off unless turned on) and 2026-10-14 (the workflow file is the switch, no profile key); recorded in
`docs/ideas/harness-held-dispatch-guarantees.md` item 4.
**Reviewed:** by a dispatched plan reviewer on 2026-10-14. Two blocking findings and every
should-fix are applied in this revision; "What the review changed" records them.

## Global constraints

Copied from `.keel/profile.json` and `docs/standards.md`. Every task inherits these.

- Verify commands: test `tests/run-tests.sh`, one test `tests/{name}`, lint as `.keel/profile.json`
  spells it (read it there; do not retype it from here). CI runs that lint and **info findings fail
  it**. `shellcheck` may not be installed where a task runs: if `command -v shellcheck` prints
  nothing, say the lint was not run and that CI will run it. It is not a pass.
- **`tests/run-tests.sh` takes about 2m30s.** Where a tool call cannot run that long, run the test
  files in parallel batches inside one call, and `tests/test-keel.sh` in a call of its own at the
  longest timeout available. Say which ran.
- **Precondition: the working tree is clean and nothing is staged.** `git status --short` prints
  nothing. Each commit below stages named paths and is made with `git commit` after checking
  `git diff --cached --name-only` lists only those paths.
- Never start on `main`. Work lands through a pull request, reviewed by somebody other than its
  author.
- No em dashes and no en dashes, in any file or commit message. Prose wraps at 100 columns; table
  rows and code blocks do not.
- Every commit carries its own documentation, `CHANGELOG.md` included. That is why the docs are in
  task 1 and not a task of their own.
- Commits and pull requests carry no attribution footers.
- Stage named paths only. Never `git add -A`.

## There are no stories

This adds one opt-in command and a template. It has no user-facing flow a story would pin that the
tests below do not. Recorded so the absence is a choice.

## What this plan does not build

- **No profile key and no `doctor` check.** The file is the switch, so there is no setting to read,
  validate or keep in sync. `keel ci-review status` reports it.
- **No secret handling.** keel never reads, writes or asks for a credential. The command prints
  which secret name the workflow reads.
- **No `synchronize` trigger.** The workflow runs when a pull request is opened, made ready or
  reopened, not on every push, because a review per push is the cost people turn this off over.
  Adding it is one line the docs name. A user who edits the file keeps it keel's, since the mark is
  on its first line.
- **No pin of `anthropics/claude-code-action` to a commit.** The vendor documents `@v1` and the
  commit could not be looked up where this plan was written. The repository's own CI pins by commit
  (`.github/workflows/ci.yml`), so this is a deviation. Step 2.3 is the owner's step to close it.
- **No test run in CI.** The job's tools allow no test command, so `review-code`'s step 3 cannot
  run the suite there. The prompt says to report "suite not run in CI" once. Allowing the profile's
  test command would widen what a pull request's content can make the job execute.
- **No fork pull requests, and no bots.** GitHub withholds secrets from forks, and a bot such as
  Dependabot runs without the Actions secret, so the job's `if` skips both.
- **No claim that the job cannot write a file.** `skills/review-code/SKILL.md` declares unrestricted
  `Bash` in its own `allowed-tools`, and whether Claude Code applies that as pre-approval inside the
  action is unverified. The docs say what the workflow asks for, not what it guarantees. Step 2.4 is
  the probe.
- **No hardening against a pull request that makes the reviewer read a credential file.** The
  template sets `persist-credentials: false` and scopes the comment command, which closes the
  obvious path; a deny rule for reading `/proc` and `.git/config` is not added because its syntax is
  unverified. Named in the docs as a residual risk.
- **No Codex or GitLab version.** The Action is Claude Code on GitHub; the docs say so.

## File structure

| File | Change |
|---|---|
| `templates/ci-review.yml` | New. The workflow template, written verbatim by `install`. In `templates/` because that is where files keel writes into a project live; `lib/` holds code that is linted |
| `bin/keel` | New `cmd_ci_review`, a dispatch line, one help line |
| `tests/test-ci-review.sh` | New, executable. Fast, no network |
| `tests/run-tests.sh` | Register the new file |
| `README.md`, `docs/03-install-and-distribution.md` | The command, what it costs, how to turn it off |
| `docs/06-repo-layout.md` | Two lines |
| `CHANGELOG.md` | One entry |
| `docs/ideas/harness-held-dispatch-guarantees.md` | Item 4: built |

---

### Task 1: the template, the command, its test and its docs

**Story:** none.
**Files:**
- Create: `templates/ci-review.yml`, `tests/test-ci-review.sh`
- Modify: `bin/keel`, `tests/run-tests.sh`, `README.md`, `docs/03-install-and-distribution.md`,
  `docs/06-repo-layout.md`, `CHANGELOG.md`

**Interfaces:**
- Produces: `keel ci-review install [--oauth]`, `keel ci-review remove`, `keel ci-review status`.
  `install` writes `.github/workflows/keel-review.yml` at the repository root from
  `templates/ci-review.yml`.
- Consumes: `die`, `say` and `$HERE` from `bin/keel`.

**Depends on:** none

**Done when:** `bash tests/test-ci-review.sh` prints no FAIL, `bin/keel --help | grep ci-review`
prints a line, and `tests/run-tests.sh` is green apart from a lint that could not run, which is
named.

- [x] **Step 1.1: Write the failing test** Note: implemented by a subagent; test file witnessed by me at 52 passed, 0 failed after the review fix pass

Create `tests/test-ci-review.sh` with this content, then `chmod +x tests/test-ci-review.sh`.
`tests/run-tests.sh` runs a registered file directly, so a file without the bit fails there.

```bash
#!/usr/bin/env bash
# keel ci-review: review in CI is opt-in. The workflow file is the switch, so these cases pin what
# the file says (it cannot run on a fork, reads no PR text, grants no write to contents) and that the
# command never overwrites or removes a workflow keel did not write.
#
# The `condition && ok || bad` idiom is safe here, and only here, because both helpers return 0.
# shellcheck disable=SC2015
# Single quotes are deliberate: the marker and the greps are literal text, backticks included.
# shellcheck disable=SC2016
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEEL="$ROOT/bin/keel"
pass=0; fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s\n' "$1"; fail=$((fail+1)); return 0; }

repo() { local d; d="$(mktemp -d)"; ( cd "$d" && git init -q -b main ) >/dev/null 2>&1; printf '%s\n' "$d"; }
W=.github/workflows/keel-review.yml

# 1. Off by default, and status writes nothing.
d="$(repo)"
out="$(cd "$d" && "$KEEL" ci-review status 2>&1)"
case "$out" in *"review in CI: off"*) ok "status says off when no workflow exists" ;; *) bad "status says off: got '$out'" ;; esac
[ ! -e "$d/$W" ] && ok "status writes nothing" || bad "status wrote a file"

# 2. Install writes the workflow, with the mark on its first line.
( cd "$d" && "$KEEL" ci-review install >/dev/null 2>&1 )
if [ ! -f "$d/$W" ]; then
    bad "install wrote no workflow"
else
    ok "install writes the workflow"
    [ "$(head -n 1 "$d/$W")" = '# installed by `keel ci-review install`. Remove it with `keel ci-review remove`.' ] \
        && ok "the mark is the first line" || bad "the mark is not the first line"

    # 3. What the file says. Inside this branch so a missing file cannot pass a "does not contain".
    grep -q 'pull_request_target' "$d/$W" && bad "uses pull_request_target" || ok "does not use pull_request_target"
    grep -Eq '^[[:space:]]+contents:[[:space:]]*write' "$d/$W" && bad "grants contents: write" || ok "does not grant contents: write"
    grep -Eq 'Edit|Write|git push|git commit' "$d/$W" && bad "allows a tool that changes files" || ok "allows no tool that changes files"
    grep -q 'head.repo.full_name == github.repository' "$d/$W" && ok "skips fork pull requests" || bad "does not skip forks"
    grep -q 'dependabot' "$d/$W" && ok "skips Dependabot, which has no Actions secret" || bad "does not skip Dependabot"
    grep -q 'persist-credentials: false' "$d/$W" && ok "checkout does not persist credentials" || bad "checkout persists credentials"
    grep -Eq 'pull_request\.(title|body)|head\.ref|base\.ref|head_ref|base_ref' "$d/$W" && bad "puts a branch name or PR text in the prompt" || ok "puts no branch name or PR text in the prompt"
    grep -q 'ANTHROPIC_API_KEY' "$d/$W" && ok "reads ANTHROPIC_API_KEY by default" || bad "does not read ANTHROPIC_API_KEY"
    if python3 -c 'import yaml' 2>/dev/null; then
        python3 -c 'import sys,yaml; yaml.safe_load(open(sys.argv[1]))' "$d/$W" 2>/dev/null \
            && ok "parses as YAML" || bad "does not parse as YAML"
    else
        printf '  SKIP  parses as YAML (no pyyaml)\n'
    fi
fi

# 4. Status once installed, and the oauth variant over keel's own file.
out="$(cd "$d" && "$KEEL" ci-review status 2>&1)"
case "$out" in *"review in CI: on, "*) ok "status says on once installed" ;; *) bad "status says on: got '$out'" ;; esac
( cd "$d" && "$KEEL" ci-review install --oauth >/dev/null 2>&1 )
if grep -q 'CLAUDE_CODE_OAUTH_TOKEN' "$d/$W" && ! grep -q 'ANTHROPIC_API_KEY' "$d/$W"; then
    ok "--oauth swaps the secret, and re-installing over keel's own file works"
else
    bad "--oauth did not swap the secret"
fi

# 5. Remove deletes keel's file only.
( cd "$d" && "$KEEL" ci-review remove >/dev/null 2>&1 )
[ ! -e "$d/$W" ] && ok "remove deletes keel's workflow" || bad "remove left keel's workflow"

# 6. A workflow keel did not write is never overwritten or removed, even if it quotes the mark.
mkdir -p "$d/.github/workflows"
printf 'name: mine\n' > "$d/$W"
( cd "$d" && "$KEEL" ci-review install >/dev/null 2>&1 ); rc=$?
if [ "$rc" -ne 0 ] && [ "$(cat "$d/$W")" = "name: mine" ]; then
    ok "install refuses over a workflow keel did not write"
else
    bad "install overwrote or accepted a foreign workflow (rc=$rc)"
fi
( cd "$d" && "$KEEL" ci-review remove >/dev/null 2>&1 )
[ "$(cat "$d/$W")" = "name: mine" ] && ok "remove leaves a foreign workflow" || bad "remove deleted a foreign workflow"
printf 'name: mine\n# installed by `keel ci-review install`. Remove it with `keel ci-review remove`.\n' > "$d/$W"
( cd "$d" && "$KEEL" ci-review remove >/dev/null 2>&1 )
[ -e "$d/$W" ] && ok "a quoted mark on a later line does not make a file keel's" || bad "remove deleted a file whose first line is not the mark"

# 7. From a subdirectory it still writes at the repository root, where GitHub reads workflows.
rm -f "$d/$W"; mkdir -p "$d/sub/dir"
( cd "$d/sub/dir" && "$KEEL" ci-review install >/dev/null 2>&1 )
if [ -f "$d/$W" ] && [ ! -e "$d/sub/dir/.github" ]; then
    ok "install from a subdirectory writes at the repository root"
else
    bad "install from a subdirectory wrote in the wrong place"
fi
out="$(cd "$d/sub/dir" && "$KEEL" ci-review status 2>&1)"
case "$out" in *"review in CI: on, "*) ok "status from a subdirectory reads the root file" ;; *) bad "status from a subdirectory: got '$out'" ;; esac

# 8. Outside a git repository, and in a bare one.
n="$(mktemp -d)"
( cd "$n" && "$KEEL" ci-review install >/dev/null 2>&1 ) && bad "installed outside a git repository" || ok "refuses outside a git repository"
b="$(mktemp -d)"; git init -q --bare "$b" >/dev/null 2>&1
( cd "$b" && "$KEEL" ci-review install >/dev/null 2>&1 ) && bad "installed in a bare repository" || ok "refuses in a bare repository"

# 9. Listed in help.
"$KEEL" --help 2>&1 | grep -q 'ci-review' && ok "help lists ci-review" || bad "help does not list ci-review"

rm -rf "$d" "$n" "$b"
printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

- [x] **Step 1.2: Run it and watch it fail** Note: not witnessed by me; the spec reviewer ran the test against git archive HEAD and read 7 passed, 7 failed

Run: `bash tests/test-ci-review.sh`
Expected: FAIL on the cases that need the command to write or report, because `bin/keel` answers
`unknown command 'ci-review'`: "status says off", "install writes the workflow", "status says on",
"--oauth swaps the secret", both subdirectory cases and "help lists ci-review". Measured on
2026-10-14: 7 failed and 7 passed. The seven that pass against a `bin/keel` that does not know the
command are the ones that assert something did not happen or that a command exited non-zero
("status writes nothing", "remove deletes keel's workflow", "install refuses over a workflow keel
did not write", "remove leaves a foreign workflow", "a quoted mark ... does not make a file keel's",
"refuses outside a git repository", "refuses in a bare repository"), which is why step 1.6 proves
them. Record how many passed and failed. If nothing failed, stop: the test is not testing.

- [x] **Step 1.3: Write the template** Note: template written by a subagent and read by two reviewers; the Dependabot term and comment were revised in the fix pass

Create `templates/ci-review.yml` with this content. Its first line is the mark; `install`,
`remove` and `status` read only that line.

```yaml
# installed by `keel ci-review install`. Remove it with `keel ci-review remove`.
# keel's review in CI. This file is the switch: it runs while the file exists.
# Cost: one Claude session per pull request opened, made ready or reopened.
# Needs the Claude GitHub App on the repository (https://github.com/apps/claude), the secret named
# below, and a project that has run `keel init`. keel sets none of them.
name: keel review
on:
  pull_request:
    types: [opened, ready_for_review, reopened]
concurrency:
  group: keel-review-${{ github.event.pull_request.number }}
  cancel-in-progress: true
jobs:
  review:
    # Skips drafts, forks (GitHub withholds the secret from them) and Dependabot (no Actions secret).
    if: github.event.pull_request.draft == false && github.event.pull_request.head.repo.full_name == github.repository && github.actor != 'dependabot[bot]'
    runs-on: ubuntu-latest
    timeout-minutes: 20
    permissions:
      contents: read
      pull-requests: write
      issues: read
      id-token: write
    steps:
      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0
        with:
          fetch-depth: 0
          persist-credentials: false
      # The vendor documents @v1. Pin it to a commit as .github/workflows/ci.yml pins the others.
      - uses: anthropics/claude-code-action@v1
        env:
          GH_TOKEN: ${{ github.token }}
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          plugin_marketplaces: "https://github.com/gbi-solutions-ltd/keel.git"
          plugins: "keel@gbi"
          prompt: |
            /keel:review-code Review pull request #${{ github.event.pull_request.number }}:
            git diff ${{ github.event.pull_request.base.sha }}...${{ github.event.pull_request.head.sha }}
            Change no file. Skip step 2's plugin delegation and do not print its install note. The
            suite cannot run on this runner: say "suite not run in CI" once and go on. Post the
            report as one pull request comment:
            gh pr comment ${{ github.event.pull_request.number }} --body-file -
          claude_args: '--max-turns 30 --allowedTools "Read,Grep,Glob,Agent,Bash(git diff:*),Bash(git log:*),Bash(git show:*),Bash(gh pr comment ${{ github.event.pull_request.number }} --body-file -:*)"'
```

The prompt names two commit hashes and a number, all generated by GitHub. It names no branch and no
pull request text, which the test pins.

- [x] **Step 1.4: Write the command** Note: command written by a subagent; write-failure guard, rewrote line and CRLF strip added in the fix pass, each test first

In `bin/keel`, add this immediately before the final `case "${1:-}" in` that dispatches the
commands, at the end of the file, after `cmd_plan`:

```bash
CI_REVIEW_MARK='# installed by `keel ci-review install`. Remove it with `keel ci-review remove`.'
CI_REVIEW_FILE=.github/workflows/keel-review.yml

# True if the workflow exists and keel wrote it. Only the first line counts: a user's own file that
# quotes the mark further down is theirs, and so is a keel file whose first line they replaced.
ci_review_is_keels() { [ -f "$CI_REVIEW_FILE" ] && [ "$(head -n 1 "$CI_REVIEW_FILE")" = "$CI_REVIEW_MARK" ]; }

# Review in CI is opt-in and the workflow file is the switch (docs/ideas/
# harness-held-dispatch-guarantees.md item 4), so there is nothing to read, validate or sync. A
# workflow that is not keel's is never overwritten or removed. GitHub reads workflows only from the
# repository root, so the command works there from any directory and refuses a bare repository.
cmd_ci_review() {
    local top sub
    top="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git work tree."
    cd "$top" || die "cannot enter $top."
    sub="${1:-status}"; [ $# -gt 0 ] && shift
    case "$sub" in
        install)
            local oauth=0 a
            for a in "$@"; do
                case "$a" in
                    --oauth) oauth=1 ;;
                    *) die "unknown option '$a'. Usage: keel ci-review install [--oauth]" ;;
                esac
            done
            if [ -e "$CI_REVIEW_FILE" ] && ! ci_review_is_keels; then
                die "$CI_REVIEW_FILE exists and keel did not write it. Rename it or merge by hand; keel will not overwrite it."
            fi
            [ -f "$HERE/templates/ci-review.yml" ] || die "templates/ci-review.yml is missing from this keel install."
            mkdir -p .github/workflows
            if [ "$oauth" -eq 1 ]; then
                sed 's/anthropic_api_key: .*/claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}/' \
                    "$HERE/templates/ci-review.yml" > "$CI_REVIEW_FILE"
            else
                cp "$HERE/templates/ci-review.yml" "$CI_REVIEW_FILE"
            fi
            say "wrote $CI_REVIEW_FILE. Review in CI is on for this repository once the file is merged."
            if [ "$oauth" -eq 1 ]; then
                say "it reads the repository secret CLAUDE_CODE_OAUTH_TOKEN (claude setup-token). keel does not set it."
            else
                say "it reads the repository secret ANTHROPIC_API_KEY. keel does not set it."
            fi
            say "it also needs the Claude GitHub App (https://github.com/apps/claude) and a project that has run 'keel init'"
            say "each pull request opened, made ready or reopened costs one Claude session"
            say "the file is not committed: read it, commit it and push it"
            say "turn it off with 'keel ci-review remove', or delete the file"
            ;;
        remove)
            if [ ! -e "$CI_REVIEW_FILE" ]; then
                say "review in CI: already off, no $CI_REVIEW_FILE"
            elif ci_review_is_keels; then
                rm -f "$CI_REVIEW_FILE"
                say "removed $CI_REVIEW_FILE. Commit the deletion to turn review in CI off."
            else
                say "left $CI_REVIEW_FILE alone: keel did not write it"
            fi
            ;;
        status)
            if [ ! -e "$CI_REVIEW_FILE" ]; then
                say "review in CI: off. 'keel ci-review install' turns it on"
            elif ci_review_is_keels; then
                say "review in CI: on, $CI_REVIEW_FILE"
            else
                say "review in CI: $CI_REVIEW_FILE exists and is not keel's"
            fi
            ;;
        *) die "unknown ci-review command '$sub'. Usage: keel ci-review install [--oauth]|remove|status" ;;
    esac
}
```

Add `    ci-review)   shift; cmd_ci_review "$@" ;;` to the command `case` after the `guard)`
line, and this help line after the `guard` help line, before `say "  plan status <plan> ..."`:

```bash
        say "  ci-review install|remove|status   opt in to keel's review on pull requests in GitHub Actions: writes one workflow file, off until you run it"
```

The case arm's `;;` belongs to the `say "  version" ;;` line that already ends the help block;
the new `say` line has none.

- [x] **Step 1.5: Run the test, the help and the lint** Note: witnessed by me: test file 52/0, help line printed, profile lint rc 0 with shellcheck 0.11.0 (not CI's version)

Run, in order: `bash tests/test-ci-review.sh`, then `bin/keel --help | grep ci-review`, then the
profile's lint if `command -v shellcheck` prints something.
Expected: no FAIL; one `ci-review` line; lint clean, or "lint not run, CI will run it" stated. The
YAML case may print SKIP if `pyyaml` is absent; say so. Then run `tests/run-tests.sh`, in batches as
the constraints say, and report its result.

- [x] **Step 1.6: Mutation checks** Note: not witnessed by me; the spec reviewer applied all five mutations and each failed its named case; the fix pass added mutations for each new case

Prove the cases can fail. Before the first mutation, copy `bin/keel` and `templates/ci-review.yml`
into a `mktemp -d` and, after each one, restore from that copy and `cmp` both files against it.
Run each mutation, require the named case to FAIL, then restore.
1. In the template, change `contents: read` to `contents: write`: "does not grant contents: write"
   must FAIL.
2. In `bin/keel`, in `install`, change the refusal's condition `[ -e "$CI_REVIEW_FILE" ] && !
   ci_review_is_keels` to `false`: "install refuses over a workflow keel did not write" must FAIL.
3. In `bin/keel`, change the body of `ci_review_is_keels` to `[ -f "$CI_REVIEW_FILE" ] && grep -qF
   "$CI_REVIEW_MARK" "$CI_REVIEW_FILE"`: "a quoted mark on a later line does not make a file keel's"
   must FAIL.
4. In the template, change `head.repo.full_name == github.repository` to `head.repo.full_name !=
   github.repository`: "skips fork pull requests" must FAIL.
5. In `bin/keel`, delete `cd "$top" || die "cannot enter $top."`: "install from a subdirectory
   writes at the repository root" must FAIL.
After the last restore, `cmp` against the copy prints nothing for both files.

- [x] **Step 1.7: The docs** Note: docs written by a subagent; I read the docs/03 section after the fix pass

1. `README.md`: after the guard paragraph, the one that ends with a pointer to `docs/03` and its
   `#commands` anchor, add the text between the lines of tildes below, which are not part of it.

~~~~
Review in CI is off until you ask for it:

```bash
keel ci-review install    # writes .github/workflows/keel-review.yml; --oauth for a subscription token
keel ci-review remove     # or delete the file
```

It runs `review-code` through the Claude Code GitHub Action on pull requests from branches of the
same repository, one Claude session each. It needs the repository secret named in the file, the
Claude GitHub App and a project that has run `keel init`; keel sets none of them. Detail is in
`docs/03-install-and-distribution.md`, the section `keel ci-review`, linked the way the guard
paragraph above links its section, with the anchor `#keel-ci-review`.
~~~~

2. `docs/03-install-and-distribution.md`: add a section `### keel ci-review` immediately before the
   line `## `keel-fleet <repo-path>... | --file <path-list-file>``, in the style of the guard
   section above it, stating each of these and nothing the tests do not back:
   - the workflow file is the switch: present is on, absent is off, and there is no profile key;
   - what the job is asked to do: read the diff, run `git diff`, `git log` and `git show`, and post
     one pull request comment. The tool list says no edit tool and no push. **That is what the
     workflow asks for, not a guarantee:** `review-code` declares unrestricted `Bash` in its own
     frontmatter, and whether the action honours that is unverified;
   - it skips drafts, forks and Dependabot, and runs when a pull request is opened, made ready or
     reopened, not on each push (add `synchronize` to `types` for that, and expect one session per
     push);
   - it cannot run the suite, so the review says "suite not run in CI";
   - each run is a Claude session on your account, bounded by `--max-turns 30` and a 20 minute
     timeout;
   - residual risk: a pull request's content is read by the reviewer, and the reviewer can read
     files on the runner, so a repository secret could in principle be shown in a comment by a
     crafted change. Opening a same-repository pull request needs write access, which limits this;
   - `anthropics/claude-code-action@v1` is a tag, so pin it to a commit as `ci.yml` does the others;
   - it is Claude Code on GitHub only.
3. `docs/06-repo-layout.md`: add `templates/ci-review.yml` where the `templates/` entry lists its
   files, and `test-ci-review.sh` in the `tests/` tree between `test-cache-install.sh` and
   `test-context-watch.sh`.
4. `CHANGELOG.md`, under `## Unreleased`, add:

```
- `keel ci-review install|remove|status` is the opt-in for keel's review in CI. Off by default:
  the workflow file `.github/workflows/keel-review.yml` is the switch, so there is no profile key.
  It runs `review-code` through the Claude Code GitHub Action when a pull request is opened, made
  ready or reopened, from a branch of the same repository only, with read tools and one comment
  command. keel never reads or writes the secret. **Not run against a real repository:** the
  workflow is unrun, the action is `@v1` and not pinned to a commit, and whether the job can write
  a file is unverified because the skill's own frontmatter allows unrestricted `Bash`.
```

- [x] **Step 1.8: Check the docs and commit** Note: witnessed by me: doc-claims 63/0, citations OK 1931, eight staged paths, test file mode 100755; commit follows this tick

Stage the paths below first, because the scans read tracked files, then run `bash
tests/test-doc-claims.sh` and `tests/validate-citations.sh` and require no failure. Check `git
diff --cached --name-only` lists exactly: `README.md`, `bin/keel`, `docs/03-install-and-distribution.md`,
`docs/06-repo-layout.md`, `templates/ci-review.yml`, `tests/run-tests.sh`, `tests/test-ci-review.sh`,
`CHANGELOG.md`; and `git ls-files -s tests/test-ci-review.sh` shows mode `100755`. Add `add
"tests/test-ci-review.sh" "tests/test-ci-review.sh"` after the `test-agents.sh` line in
`tests/run-tests.sh` before staging. Commit: `feat(cli): keel ci-review, the opt-in for review in CI`.

---

### Task 2: close the record, and the owner's steps

**Story:** none.
**Files:**
- Modify: `docs/ideas/harness-held-dispatch-guarantees.md`

**Depends on:** Task 1

**Done when:** item 4 says built and names the task 1 commit; `tests/validate-citations.sh` passes;
steps 2.3 and 2.4 are deferred with the owner named.

- [x] **Step 2.1: Mark item 4 built** Note: edited by a subagent; I read the diff, and the spec and quality reviews passed; a follow-up fix to five stale sentences in the same record was added after the quality review

Replace the final sentence of item 4 ("Planned in `docs/plans/2026-10-14-opt-in-ci-review.md`.")
with "Built in `<hash of task 1>` (`docs/plans/2026-10-14-opt-in-ci-review.md`); the workflow is unrun
against a real repository and the action is not pinned to a commit." Use the real hash from `git log
--oneline`. Keep lines under 100 columns.

- [x] **Step 2.2: Check and commit** Note: validate-citations OK 1931 and test-doc-claims 63/0 witnessed by me and by a reviewer; commit follows this tick

Stage the file, run `tests/validate-citations.sh`, require no failure. Commit: `docs(ideas): the
opt-in CI review is built`.

- [-] **Step 2.3: Owner: pin the action** Deferred: owner's step: needs GitHub access

Not an implementer's step. Resolve `anthropics/claude-code-action@v1` to a commit and pin it in
`templates/ci-review.yml`, with the tag in a trailing comment as `ci.yml` does. The coordinator
defers this step with `--defer "owner's step: needs GitHub access"`.

- [-] **Step 2.4: Owner: the first real run** Deferred: owner's step: needs a GitHub repository and the app

Not an implementer's step. In a scratch repository on GitHub with the Claude GitHub App and the
secret set, run `keel ci-review install`, push it, open a pull request from a branch of the same
repository and read the comment. Also check from that run: whether `/keel:review-code` expands as the
prompt, whether the job can write a file despite the tool list, and what the hooks do with no human
present. Until it is done the changelog says the workflow is unrun. The coordinator defers this step
with `--defer "owner's step: needs a GitHub repository and the app"`.

---

## What the review changed

A dispatched plan reviewer read this plan against the code on 2026-10-14. It ran the plan's steps in
a scratch copy of the repository: all 18 cases of the draft test passed once the template and
command were applied, and the supply-chain scan was clean.

| Finding | Severity | Change |
|---|---|---|
| The test file fails the profile's lint (SC2015, SC2016) | Blocking | Header with `shellcheck disable` and the reason, as `test-keel.sh` and `test-plan.sh` carry |
| The test file is created without the executable bit and `run-tests.sh` runs it directly | Blocking | `chmod +x` in step 1.1 and a mode check in step 1.8 |
| Mutation step names a deletion that leaves a syntax error, and expects an empty `git diff` before any commit | Should fix | Five exact mutations, restored and `cmp`-checked against a copy |
| Step 1.2's expected failures were wrong | Should fix | Real list, and the cases that pass without the command named |
| No step ran the whole suite; lint blind locally | Should fix | Step 1.5 runs `run-tests.sh` and says what lint did not run |
| `install` wrote relative to the current directory | Should fix | Works from the repository root, refuses a bare repository, two test cases |
| "Read-only" stated as a guarantee though the skill allows unrestricted Bash | Should fix | Docs and changelog word it as intent; step 2.4 probes it |
| `review-code` step 3 cannot run its suite under the allowlist | Should fix | The prompt says "suite not run in CI"; named in "does not build" |
| Docs in a later task contradict "every commit carries its documentation"; the index had unrelated staged files | Consider, applied | Docs moved into task 1; a clean-tree precondition and a staged-paths check |
| The mark matched anywhere, `base.ref` in the prompt, Dependabot, credential persistence, comment command scope | Consider, applied | Mark is the first line; the prompt carries commit hashes only; Dependabot skipped; `persist-credentials: false`; the comment command is scoped to the pull request number |
| Template in `lib/`, which holds linted code | Consider, applied | `templates/` |
| docs/03 heading and the README anchor did not match | Consider, applied | A `### keel ci-review` section and a matching anchor |
| Owner's steps were prose, so "done" passed with the action unpinned | Consider, applied | Steps 2.3 and 2.4, deferred with the owner named |
