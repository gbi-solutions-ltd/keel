# ci-review refuses a repository on another CI Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** `keel ci-review install` in a repository whose CI is not GitHub Actions, or whose
`origin` is on a host that is not GitHub, writes nothing and says why, instead of writing a
workflow that never runs and saying review in CI is on.
**Stories:** none. One refusal in an existing command; the tests pin it.
**ADRs:** none. "A second CI system is the worst outcome" (`docs/03-install-and-distribution.md`,
the reason `keel init` skips its workflow when another CI marker exists) is the rule applied here.
**Architecture:** one new function in `bin/keel`, `ci_review_elsewhere`, reusing
`CI_MARKER_PAIRS` from `lib/detect-stack.sh`, with one helper, `ci_review_origin_host`, that reads
the host from `origin`. `install` refuses on it, `status` reports it, `remove`
is unchanged. No flag to override. Decided by Bernard on 2026-10-14.

## Global constraints

Copied from `.keel/profile.json` and `docs/standards.md`. Every task inherits these.

- Verify commands: test `tests/run-tests.sh`, one test `tests/{name}`, lint as `.keel/profile.json`
  spells it (read it there; do not retype it from here). CI runs that lint and **info findings fail
  it**. If `command -v shellcheck` prints nothing, say the lint was not run and that CI will run it.
  It is not a pass.
- **`tests/run-tests.sh` takes about 2m30s.** Where a tool call cannot run that long, run it in the
  background and read its log. Say which ran.
- **Precondition: the working tree is clean and nothing is staged.** Each commit stages named paths
  only, checked with `git diff --cached --name-only`. Never `git add -A`.
- Never start on `main`.
- No em dashes and no en dashes, in any file or commit message. Prose wraps at 100 columns; table
  rows and code blocks do not.
- Every commit carries its own documentation, `CHANGELOG.md` included.
- Commits and pull requests carry no attribution footers.

## What this plan does not build

- **No GitLab version of the review.** GitLab runs its own pipelines; keel writes nothing there.
- **No override flag.** A repository on GitHub with a stale `.gitlab-ci.yml` deletes that file
  first; the refusal says which file it read.
- **No change to `remove`.** It deletes keel's file wherever it is, which is how a mistaken install
  from an older keel is undone.

## The rule

`ci_review_elsewhere` prints the rule's number and its fact, `<n>|<fact>`, and returns 0 when
review in CI should not be installed here, and prints nothing and returns 1 otherwise. Each caller
adds the consequence that fits it. It runs from the repository root.

1. **Another CI, and no GitHub workflow.** If `.github/workflows` holds no `*.yml` or `*.yaml` other
   than keel's own `keel-review.yml`, and a file named in `CI_MARKER_PAIRS` exists, the fact is
   `this repository's CI is <name> (<file>) and it has no GitHub workflow`, naming the first marker
   found in the order `CI_MARKER_PAIRS` lists them. A repository that already runs GitHub Actions
   beside another system is not refused: adding a workflow there adds no second system.
2. **A non-GitHub `origin`.** Otherwise, if `git remote get-url origin` succeeds and its host
   contains `gitlab` or `bitbucket`, is `dev.azure.com`, or ends in `.dev.azure.com` or
   `.visualstudio.com`, the fact is `this repository's origin is on <host>`. The URL is lower-cased
   first. The host is parsed from `<scheme>://[userinfo@]host[:port]/...` for the schemes `http`,
   `https`, `ssh`, `git`, `git+ssh` and `ssh+git`, and from `[user@]host:path`. For a scheme URL the
   authority ends at the first `/`, `?` or `#`, as git's own URL handling ends it, and the host
   follows the last `@` inside the authority. One trailing dot on the host is dropped. A host
   holding `[` or `]`, a local path, and the remote-helper form `<transport>::<address>` do not
   parse. Any other host, no `origin`, or a URL that does not parse, is not refused: GitHub
   Enterprise runs on hosts of any name, and self-hosted Azure DevOps Server cannot be told from its
   name.
3. **Keel's own file only.** Rule 1 leaves out `keel-review.yml` only when `ci_review_is_keels` is
   true; a workflow of the user's by that name is a GitHub workflow like any other.

**Changed after review, 2026-10-14:** the quality review found `git@ssh.dev.azure.com:...` (Azure
DevOps' own SSH form), `http://` GitLab, `git+ssh://`, upper-case schemes and a raw `/` in a
credential all slipped through rule 2, and that rule 1 left out any file named `keel-review.yml`.
Rules 2 and 3 above are the result; `bitbucket` is matched by name as `gitlab` is. A second
quality review found that a fallback for a raw `/` in a credential, which git itself rejects, made
`https://user@github.com/org/x@gitlab.git` refuse an origin on github.com; the authority now ends
where git ends it. It also found the refusal said "second CI system" when only the origin rule had
fired, so the message now says why the file would not run. A third review found "would never run"
false for rule 1 on a repository GitHub hosts, where the file would run beside the other CI; each
rule's reason now carries its own consequence, and the docs drop a sentence that amounted to an
override recipe. A fourth review found rule 1's reason read wrongly in `status` once keel's file
existed, and never said the missing GitHub workflow was part of it; the function now prints the
fact and each caller its own consequence.

## Messages

- `install` refused writes nothing (no `.github` directory either), exits non-zero, and dies with:
  - rule 1: `<fact>. keel does not add a second CI system, so it wrote nothing.`
  - rule 2: `review in CI runs only on GitHub Actions, and <fact>, where its workflow would never
    run. keel wrote nothing.`

  The refusal comes before the not-keel's-file check and before any write. Rule 1 is checked before
  rule 2, so a repository with both gives rule 1's fact.
- `status` with no keel file:
  - rule 1: `review in CI: not available here. <Fact>, and keel does not add a second CI system.`
  - rule 2: `review in CI: not available here. It runs only on GitHub Actions, and <fact>.`
- `status` with keel's file:
  - rule 1: `review in CI: <file> is keel's, and <fact>, so it is a second CI system. 'keel
    ci-review remove' deletes it.`
  - rule 2: `review in CI: <file> is keel's, but <fact>, where it would never run. 'keel ci-review
    remove' deletes it.`
- `status` and `install` otherwise: unchanged.

---

### Task 1: the refusal, its tests and its docs

**Story:** none.
**Files:**
- Modify: `bin/keel`, `tests/test-ci-review.sh`, `docs/03-install-and-distribution.md`,
  `README.md` (only if its ci-review lines need it), `CHANGELOG.md`

**Interfaces:**
- Produces: `ci_review_elsewhere` in `bin/keel`.
- Consumes: `CI_MARKER_PAIRS` from `lib/detect-stack.sh`, `CI_REVIEW_FILE`, `ci_review_is_keels`,
  `die`, `say`.

**Depends on:** none

**Done when:** `bash tests/test-ci-review.sh` prints no FAIL, `tests/run-tests.sh` is green apart
from a lint that could not run, which is named, and every mutation in step 1.4 fails a named case.

- [x] **Step 1.1: Write the failing tests** Note: tests written by subagents across four passes; witnessed by me: 99 passed, 0 failed

Append numbered cases to `tests/test-ci-review.sh` in its existing style. Each builds its own repo
with the file's `repo` helper. At least:

1. `.gitlab-ci.yml` present, no workflows: `install` exits non-zero, `.github` does not exist, and
   the output names `gitlab-ci` and `.gitlab-ci.yml` and says `second CI system`.
2. Same repo: `status` says `not available here` and names `gitlab-ci`, and writes nothing.
3. `bitbucket-pipelines.yml` present: `install` refused, naming `bitbucket-pipelines`.
4. `.gitlab-ci.yml` plus `.github/workflows/ci.yml`: `install` succeeds and writes the file.
5. `.gitlab-ci.yml` plus only keel's own `keel-review.yml` (written by an earlier `install` before
   the marker was added): `install` refused; `status` says the file is keel's and a second CI
   system; `remove` deletes it.
6. `origin` `https://gitlab.com/acme/pay.git`: refused, naming `gitlab.com`.
7. `origin` `git@gitlab.example.com:acme/pay.git`: refused, naming `gitlab.example.com`.
8. `origin` `ssh://git@bitbucket.org:7999/acme/pay.git`: refused, naming `bitbucket.org`.
9. `origin` `https://dev.azure.com/acme/pay/_git/pay`: refused.
10. `origin` `git@github.com:acme/pay.git`: `install` succeeds.
11. `origin` `https://github.acme.internal/acme/pay.git` (an Enterprise-like host): succeeds.
12. A refused `install` leaves an existing unrelated file in `.github/` byte for byte.

- [x] **Step 1.2: Run them and watch them fail** Note: not witnessed by me; each implementer reported a failing-first run (57/12, 76/9, 70/20, 74/24, 91/8)

`bash tests/test-ci-review.sh`; the new refusal cases fail and the old ones still pass. Read it.

- [x] **Step 1.3: Write the function and wire it in** Note: code by subagents; one comment rewrapped by me; spec and quality reviews over four rounds, final COMPLIES with nothing blocking

Put `ci_review_elsewhere` beside `ci_review_is_keels`, with a comment saying why: a workflow on a
platform that never runs it is a dead file that says review in CI is on. Wire `install` and `status`
as "Messages" says. Shell style as the rest of `bin/keel`: `local`, quoted expansions, no new
dependencies. Run the test file until it prints no FAIL, then the profile's lint if `shellcheck`
exists.

- [x] **Step 1.4: Mutation checks** Note: not witnessed by me; implementers and reviewers applied the listed mutations and more, each failing a named case

Each of these, applied alone, must make at least one named case fail; record which. Restore after
each with `git diff` showing only the intended change.

1. `install` ignores the reason.
2. Rule 1 skips its no-GitHub-workflow condition.
3. Rule 1 counts keel's own `keel-review.yml` as a GitHub workflow.
4. The host parse drops the `[user@]host:path` form.
5. `gitlab` matching is removed from rule 2.

- [x] **Step 1.5: The docs** Note: docs by subagents; I tightened two sentences and rewrapped one paragraph; doc-claims 63/0 and citations OK witnessed by me

In `docs/03-install-and-distribution.md`, `### keel ci-review`: one paragraph after the first,
saying the command runs only where GitHub Actions does, the two rules in plain words, that
`install` refuses and writes nothing, what `status` says, and that a repository on GitHub with a
stale marker from another CI deletes that marker first. Name GitLab plainly: keel's review in CI
does not run there. `CHANGELOG.md`, Unreleased: extend the `keel ci-review` entry with one
sentence. `README.md` only if a line there would now be wrong.

- [x] **Step 1.6: Check and commit** Note: witnessed by me: run-tests.sh all passed (exit 0), profile lint rc 0 with shellcheck 0.11.0 (not CI's version); commit follows this tick

Stage `bin/keel`, `tests/test-ci-review.sh`, `docs/03-install-and-distribution.md`, `CHANGELOG.md`,
this plan with its ticks, and `README.md` if changed. Run `bash tests/test-doc-claims.sh` and
`tests/validate-citations.sh`, and the full `tests/run-tests.sh`; require no failure. Check
`git diff --cached --name-only`. Commit: `feat(cli): keel ci-review refuses a repository on
another CI`.
