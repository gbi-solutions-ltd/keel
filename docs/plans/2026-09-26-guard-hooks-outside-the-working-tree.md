# Guard hooks outside the working tree Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go, on output you read.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness, or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** close the findings of the 2026-09-26 review of `06b8ef2..b7c70f9` that block or should
block shipping, starting with the guard running a checked-out branch's own hooks.
**Stories:** none. The review findings below are the requirements, each decided by the maintainer
on 2026-09-26; each task names the finding it closes.
**ADRs:** none bear on this. ADR-0003 governs harness hooks, and these are git hooks.
**Architecture:** `keel guard install` writes its three hooks into git's own hooks directory,
`$(git rev-parse --git-common-dir)/hooks`, and sets no `core.hooksPath`. No checkout writes
there, so checking out a branch can no longer run that branch's hooks. One function,
`guard_state`, answers "is the guard installed" for `guard status` and `doctor` alike, and it
recognises an install at the old `.githooks` path and another tool's hooks, which keel never
overwrites or redirects.

**Findings this plan closes** (from the review, ranked there):

| # | Finding | Task |
|---|---|---|
| 1 | `core.hooksPath=.githooks` is a working-tree path, so any checkout, a fork's pull request included, runs that branch's hooks. Reproduced on git 2.50.1; live in this clone until unset on 2026-09-26 | 1, 2, 3 |
| 2 | doctor tells a project with another tool's `core.hooksPath` (husky, lefthook, a global gitleaks) to run `keel guard install`, which would switch that tool off, and counts any `.githooks/pre-push` as keel's guard | 1, 2 |
| 3 | A non-zero `verify.security` exit reads "does not run" though the audit ran; a hand-set null does not last, since init detects it again and the pre-push hook refuses a null; the skills that require doctor to pass do not say it needs the network | 4 |
| 4 | Two tests cannot fail: nothing pins `write_ci`'s read of the profile's branch, or pnpm detection | 5 |
| 5 | docs/03 says the trailer goes on "every commit" and "before this release"; the CI-only ruff job sits unexplained beside "One definition per verify command"; five execution notes in the 2026-09-25 plan are unwrapped | 6 |

**Decisions, 2026-09-26, maintainer:** fix the design before shipping; the hooks go in git's own
hooks directory with no `core.hooksPath`, not in a keel directory under `.git` with an absolute
path, because an absolute path goes stale when the repository folder moves and a `core.hooksPath`
disables every hook already in `.git/hooks`; findings 2 to 5 are fixed here; the review's finding
6, the pre-push scan reading the working tree rather than the pushed commits, is filed as an idea
and is not in this plan.

**Concurrent batches:** none. Every task shares `bin/keel`, `tests/test-keel.sh`,
`docs/03-install-and-distribution.md` or `CHANGELOG.md` with another, so they run in order.

## Global constraints

- Verify commands, from `.keel/profile.json`: test `tests/run-tests.sh`; one test file
  `tests/test-keel.sh` (the `tests/{name}` pattern); typecheck and build are `null`, since there is
  nothing to compile; lint is:

  ```bash
  shellcheck -x bin/keel bin/keel-fleet lib/*.sh lib/harness/*.sh tests/*.sh tests/evals/run.sh \
    tests/evals/stage.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard
  ```

- `tests/test-keel.sh` takes about five minutes and `tests/run-tests.sh` about seven. Both print
  nothing until each file finishes. Slow is not hung.
- Lint after each file edit, not at the end of the task.
- Never start on `main`. Work on `sandbox`, which is where this repository's pull requests come
  from.
- **This clone has no `core.hooksPath` and runs no hooks** until task 3 installs the guard. Do not
  set `core.hooksPath` anywhere, and never `--global`. Tests run in fixture repositories.
- `tests/test-keel.sh` run directly inherits the machine's global git config, which only
  `tests/run-tests.sh` isolates. Before the first run, from a directory outside any repository,
  `git config --show-scope --get core.hooksPath` and `git config --show-scope --get init.templateDir`
  must both print nothing; if either prints a value, stop and report, since every install in the
  new cases would then be refused.
- No em dash and no en dash anywhere: code, comments, strings, docs, commit messages.
- Prose in markdown wraps at 100 columns; tables do not (docs/standards.md, "Prose wraps at 100
  columns; tables do not").
- Every rule a comment states carries its reason (docs/standards.md, "Every rule carries its
  reason").
- A gate is never weakened so this repository can pass it (docs/standards.md, "A gate is never
  weakened so this repository can pass it").
- Documentation lands in the same commit as the change: a line under `## Unreleased` at the top of
  `CHANGELOG.md`, plus any document the change makes wrong, stating what is true now.
- **Citations into `bin/keel` and `tests/test-keel.sh` use a phrase, never a line number**, in
  the form `` bin/keel#<text from the line> ``; `tests/validate-citations.sh` refuses a line number
  into either. A phrase must occur **once** in its file (`grep -cF '<phrase>' <file>`) and contain
  no `|`.
- After an edit that inserts or deletes lines in any tracked file, run `tests/validate-citations.sh`
  and repair what it reports; then grep the repository for `<that file>:<N>` citations with N at or
  after the edit, compare `git show HEAD:<file> | sed -n '<N>p'` with the current line N, and
  repair each whose target moved. **A repaired citation names the line its sentence describes**,
  found by reading the sentence, never whatever sits at the old number. Where no line does what the
  sentence says, cite the nearest definition and report it as unresolved. Leave citations that
  were already wrong at HEAD alone.
- **doctor may start python3 at most 10 times**, asserted by
  `` tests/test-keel.sh#keel doctor starts python3 at most 10 times ``, and it is at 10. New doctor
  code uses git, grep and sed, or the cached `json_get`.
- **A schema edit regenerates the reference:** run
  `tests/generate-profile-keys.sh > docs/profile-keys.md`, then `tests/test-profile-keys.sh` must
  pass.
- The doctor code is in `cmd_doctor_text` (`` bin/keel#cmd_doctor_text() { ``); the guard code is
  `cmd_guard` (`` bin/keel#cmd_guard() { ``).
- Fixtures from `fixture <stack>` in `tests/test-keel.sh` are copies of a committed git repository;
  their `.git/hooks` holds only git's `.sample` files.
- Stage named paths only. Never `git add -A`, `git add .` or `git commit -a`.
- Commit messages are conventional, title and body only: no `Co-Authored-By`, no robot emoji, no
  generated-with line.
- Do not delete a file you did not create, except where a task names it. If `git status` shows
  something unexpected, report it and leave it alone.

---

### Task 1: `keel guard` installs into git's hooks directory and never takes over another tool's

> **Execution note (2026-09-26):** delegated. Step 1: 3 then 0 `.githooks` hits, every target
> once. Step 2 witnessed in the implementer's report: 616 passed, 44 failed, every expected FAIL
> present plus the moved cases that run the hooks by path; only the three named cases passed on
> red. Step 4: 654 passed, 0 failed. Spec review COMPLIES. **Beyond the step text, approved by the
> coordinator after the quality review and a focused re-review, and built instead of the code
> above where they differ:** a legacy `.githooks` that also holds executable hooks without keel's
> mark (`*.sample` ignored) is refused by install and left in place by uninstall, naming the files
> (`guard_legacy_others`); after the move install re-checks `guard_state` and stops, naming the
> scope, when a `core.hooksPath` from another config takes over, and uninstall says so rather
> than claiming an unset; `guard_state` checks `installed` before `foreign-hook`, and status names
> an unmarked `pre-commit` or `prepare-commit-msg` as another tool's; relative paths resolve
> against the working-tree top (`guard_top`), where git resolves them; the refusal messages name
> the setting's scope and no longer advise the circular "call it from keel's hook"; the checkout
> test asserts it is on `fork-pr`; uninstall's last line names the directory; docs/03's doctor
> bullet and install paragraph and the CHANGELOG entry say so. Each added case witnessed red on the
> earlier code or under a mutation, then green. Final `tests/test-keel.sh` 668 passed, 0 failed;
> `tests/run-tests.sh` All test files passed; lint 0; validator OK. The suite's one earlier red was
> the coordinator's: this plan's global constraints quoted a global-scope `git config` read, which
> the supply chain scan's `persist-global` rule flags; reworded to `--show-scope`, in this commit.
> Citations repaired: the two predicted `$GUARD_DIR/pre-push` phrases, the docs/03 `Installs three
> hooks` phrase, and two `CHANGELOG.md` line citations the entry moved, now phrases. Considered,
> not taken: a bare repository's relative `core.hooksPath` from a subdirectory; messages print a
> relative hooks path from a subdirectory; status on a legacy install with other hooks still
> suggests re-running install, which then refuses and names them.

**Story:** findings 1 and 2
**Files:**
- Modify: `bin/keel` (the comment and `GUARD_DIR` above `guard_hook_body`, `cmd_guard`, and the
  push guard test in `cmd_doctor_text`, which uses `GUARD_DIR` and must not break when it goes)
- Modify: `tests/test-keel.sh`
- Modify: `docs/03-install-and-distribution.md`
- Modify: `README.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: `guard_hook_body`, `guard_precommit_body`, `guard_prepare_commit_msg_body`, each of
  whose output carries the line `installed by \`keel guard install\``
- Produces: `GUARD_LEGACY_DIR` (`.githooks`), `GUARD_MARK` (the text
  `` installed by `keel guard install` ``), `guard_dir` (prints the hooks directory) and
  `guard_state` (prints exactly one of `installed`, `legacy`, `foreign-path`, `foreign-hook`,
  `absent`), and `guard_foreign_hook` (prints the first of the three hook names whose file lacks
  keel's mark, status 1 when none). Task 2 consumes `guard_state`, `guard_dir` and `GUARD_LEGACY_DIR`. `GUARD_DIR` is
  removed, so doctor's installed test becomes `[ "$(guard_state)" = installed ]` in this task;
  task 2 gives each other state its own line.

**Depends on:** none

**Done when:** `tests/test-keel.sh` passes.

- [x] **Step 1: Write the failing tests**

First move the existing guard cases to the new location. They name `.githooks/` as a path, which
after this task holds nothing keel wrote. Run this before inserting anything below, so it touches
only lines that exist today:

```bash
sed -i.bak 's#\.githooks/#.git/hooks/#g' tests/test-keel.sh && rm tests/test-keel.sh.bak
grep -c '\.githooks' tests/test-keel.sh
```

Expected: the count printed is `3`, the three `core.hooksPath` assertions replaced next.

Replace:

```bash
[ "$( cd "$g" && git config core.hooksPath )" = ".githooks" ] \
  && ok "guard install points core.hooksPath at the repository's own hooks" \
  || bad "guard" "core.hooksPath was not set"
```

with:

```bash
# git's own hooks directory, and no core.hooksPath at all: a path inside the working tree is
# replaced by every checkout, which is how a checked-out branch got to run its own hooks.
[ -z "$( cd "$g" && git config core.hooksPath )" ] \
  && ok "guard install sets no core.hooksPath" \
  || bad "guard" "core.hooksPath was set to '$( cd "$g" && git config core.hooksPath )'"
```

In the no-footers block, replace:

```bash
[ "$(git -C "$nf" config core.hooksPath)" = ".githooks" ] \
  || bad "no footers" "fixture precondition: guard install did not set core.hooksPath"
```

with:

```bash
[ -z "$(git -C "$nf" config core.hooksPath)" ] \
  || bad "no footers" "fixture precondition: core.hooksPath is set, so .git/hooks does not run"
```

In the guard status block, replace:

```bash
[ "$(git -C "$gs" config core.hooksPath)" = ".githooks" ] \
  || bad "guard status" "fixture precondition: guard install did not set core.hooksPath"
```

with:

```bash
[ -z "$(git -C "$gs" config core.hooksPath)" ] \
  || bad "guard status" "fixture precondition: core.hooksPath is set, so .git/hooks does not run"
```

Replace:

```bash
[ -z "$( cd "$g" && git config core.hooksPath 2>/dev/null )" ] \
  && ok "guard uninstall clears core.hooksPath" || bad "guard" "core.hooksPath survived uninstall"
```

with:

```bash
[ ! -e "$g/.git/hooks/pre-push" ] \
  && ok "guard uninstall removes the pre-push hook" || bad "guard" "pre-push survived uninstall"
```

Replace the two comments that say the guard changes git configuration:

```bash
# The guard is the only part of keel that changes a developer's git configuration, so each test
# here is as much about what it does not touch as what it does.
```

with:

```bash
# The guard is the only part of keel that writes into a developer's git directory, so each test
# here is as much about what it does not touch as what it does.
```

and:

```bash
# Repo-local, and that is the whole safety argument for a tool that reconfigures git. A global
# setting here would disable every other repository's hooks on the machine.
```

with:

```bash
# No git configuration at all, and never global: a global core.hooksPath would disable every other
# repository's hooks on the machine.
```

Run `grep -c '\.githooks' tests/test-keel.sh`. Expected: `0`.

Then insert above the final `printf` line of `tests/test-keel.sh`:

```bash
# ---- a checkout cannot run a branch's own hooks --------------------------------------------------
# The guard used core.hooksPath=.githooks, a path inside the working tree, so every checkout
# replaced the hooks with the checked-out branch's own, and a fork's pull request ran its code the
# moment anyone checked it out. The guard now lives in git's hooks directory, which no checkout
# writes. Reproduced on git 2.50.1 before the fix.
xh="$(fixture node-ts)"
( cd "$xh" && "$KEEL" init -y >/dev/null 2>&1 && "$KEEL" guard install >/dev/null 2>&1 )
[ -x "$xh/.git/hooks/pre-push" ] \
  || bad "guard location" "fixture precondition: guard install wrote no .git/hooks/pre-push"
( cd "$xh" && git checkout -q -b fork-pr && mkdir -p .githooks \
  && printf '#!/bin/sh\ntouch "%s/checkout-ran-a-branch-hook"\n' "$xh" > .githooks/post-checkout \
  && chmod +x .githooks/post-checkout && git add .githooks \
  && git commit -q --no-verify -m "a branch that ships its own hook" \
  && git checkout -q - && git checkout -q fork-pr ) >/dev/null 2>&1
[ -e "$xh/.githooks/post-checkout" ] \
  || bad "guard location" "fixture precondition: the branch's hook file is not checked out"
[ ! -e "$xh/checkout-ran-a-branch-hook" ] \
  && ok "checking out a branch does not run that branch's own hooks" \
  || bad "guard location" "a checked-out branch's .githooks/post-checkout ran"
rm -rf "$xh"

# ---- an install at the old .githooks path is recognised and moved --------------------------------
# Every guard installed before 2026-09-26 sits in .githooks with core.hooksPath pointing there.
# status must say so, and install must move it rather than leave both.
lg="$(fixture node-ts)"
( cd "$lg" && "$KEEL" init -y >/dev/null 2>&1 && "$KEEL" guard install >/dev/null 2>&1 \
  && mkdir -p .githooks \
  && mv .git/hooks/pre-push .git/hooks/pre-commit .git/hooks/prepare-commit-msg .githooks/ \
  && git config core.hooksPath .githooks )
out="$( cd "$lg" && "$KEEL" guard status 2>&1 )"; rc=$?
case "$out" in
  *"working-tree path"*) [ "$rc" -ne 0 ] && ok "guard status names an install at .githooks and exits non-zero" \
                           || bad "guard legacy" "status named it but exited 0" ;;
  *) bad "guard legacy" "status did not name the .githooks install: $out" ;;
esac
( cd "$lg" && "$KEEL" guard install >/dev/null 2>&1 )
[ -z "$(git -C "$lg" config core.hooksPath)" ] && [ -x "$lg/.git/hooks/pre-push" ] \
  && ok "guard install moves a .githooks install into .git/hooks and unsets core.hooksPath" \
  || bad "guard legacy" "after install: core.hooksPath='$(git -C "$lg" config core.hooksPath)', pre-push $( [ -x "$lg/.git/hooks/pre-push" ] && echo present || echo missing )"
( cd "$lg" && "$KEEL" guard status >/dev/null 2>&1 ) \
  && ok "guard status is 0 once the .githooks install is moved" \
  || bad "guard legacy" "status non-zero after the move"
rm -rf "$lg"

# ---- another tool's hooks are never taken over ---------------------------------------------------
# A core.hooksPath keel did not set belongs to husky, lefthook or a global scanner; replacing it
# switches that tool's hooks off. A same-named hook file in .git/hooks is another tool's too.
# install refuses both, and leaves them exactly as they were.
fp="$(fixture node-ts)"
( cd "$fp" && "$KEEL" init -y >/dev/null 2>&1 && git config core.hooksPath .husky )
( cd "$fp" && "$KEEL" guard install >/dev/null 2>&1 ) \
  && bad "guard foreign" "install exited 0 with core.hooksPath pointing at .husky" \
  || ok "guard install refuses while core.hooksPath points at another tool's hooks"
[ "$(git -C "$fp" config core.hooksPath)" = ".husky" ] && [ ! -e "$fp/.git/hooks/pre-push" ] \
  && ok "the refused install leaves core.hooksPath and .git/hooks untouched" \
  || bad "guard foreign" "core.hooksPath='$(git -C "$fp" config core.hooksPath)', pre-push $( [ -e "$fp/.git/hooks/pre-push" ] && echo written || echo absent )"
out="$( cd "$fp" && "$KEEL" guard status 2>&1 )"
case "$out" in
  *"which keel did not set"*) ok "guard status names a foreign core.hooksPath" ;;
  *) bad "guard foreign" "status: $out" ;;
esac
rm -rf "$fp"
fh="$(fixture node-ts)"
( cd "$fh" && "$KEEL" init -y >/dev/null 2>&1 \
  && printf '#!/bin/sh\n# another tool\nexit 0\n' > .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit )
( cd "$fh" && "$KEEL" guard install >/dev/null 2>&1 ) \
  && bad "guard foreign" "install exited 0 over another tool's pre-commit" \
  || ok "guard install refuses to overwrite another tool's hook"
grep -q 'another tool' "$fh/.git/hooks/pre-commit" && [ ! -e "$fh/.git/hooks/pre-push" ] \
  && ok "the refused install leaves the other tool's hook in place and writes nothing" \
  || bad "guard foreign" "the other tool's pre-commit was replaced, or pre-push was written"
out="$( cd "$fh" && "$KEEL" guard status 2>&1 )"
case "$out" in
  *"pre-commit is another tool's hook"*) ok "guard status names another tool's pre-commit" ;;
  *) bad "guard foreign" "status with a foreign pre-commit: $out" ;;
esac
rm -rf "$fh"
# .githooks is also a common name for a project's own committed hooks. Without keel's mark it is
# theirs, and install must not unset core.hooksPath as if it were keel's old install.
ph="$(fixture node-ts)"
( cd "$ph" && "$KEEL" init -y >/dev/null 2>&1 && mkdir -p .githooks \
  && printf '#!/bin/sh\n# the project own hook\nexit 0\n' > .githooks/pre-commit \
  && chmod +x .githooks/pre-commit && git config core.hooksPath .githooks )
( cd "$ph" && "$KEEL" guard install >/dev/null 2>&1 ) \
  && bad "guard foreign" "install exited 0 over a project's own .githooks" \
  || ok "guard install refuses a .githooks that holds a project's own hooks"
[ "$(git -C "$ph" config core.hooksPath)" = ".githooks" ] \
  && grep -q 'the project own hook' "$ph/.githooks/pre-commit" \
  && ok "the project's own .githooks stays in core.hooksPath, untouched" \
  || bad "guard foreign" "core.hooksPath='$(git -C "$ph" config core.hooksPath)', or .githooks/pre-commit was replaced"
rm -rf "$ph"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL on at least these, each for the reason shown:
- `guard: core.hooksPath was set to '.githooks'`
- `guard: no executable .git/hooks/pre-push`, and the other moved cases that run
  `.git/hooks/...` directly, since install still writes `.githooks/`
- `guard location: a checked-out branch's .githooks/post-checkout ran`, or its precondition line,
  since install writes no `.git/hooks/pre-push`
- `guard legacy: status did not name the .githooks install`
- `guard foreign: install exited 0 with core.hooksPath pointing at .husky`
- `guard foreign: install exited 0 over another tool's pre-commit`, and the status line after it
- `guard foreign: install exited 0 over a project's own .githooks`, and the untouched check after
  it, since the old install overwrote `.githooks/pre-commit`

These cases pass here and are expected to: they assert an absence or a state the old code also
leaves. `guard uninstall removes the pre-push hook`, `guard status is 0 once the .githooks install
is moved`, and `the refused install leaves the other tool's hook in place and writes nothing`.
Record the exact FAIL lines. Any other case in the new blocks that passes here is a finding: say
which.

- [x] **Step 3: Write the minimal implementation**

In `bin/keel`, replace the comment block and the line from
`# The guard is opt-in, and it is opt-in for a reason worth stating rather than assuming: it sets`
down to and including `GUARD_DIR=".githooks"` with:

```bash
# The guard is opt-in: it writes three hooks into this repository's git directory, and a tool that
# does that the moment you run `init` is a tool people stop running.
#
# It lives in git's own hooks directory, never in the working tree, and sets no core.hooksPath.
# Until 2026-09-26 it used core.hooksPath=.githooks, a working-tree path, so every checkout replaced
# the hooks with the checked-out branch's own and a fork's pull request ran its code on checkout.
# No checkout writes into the git directory. `git rev-parse --git-common-dir` is used and not
# `--git-path hooks`, because --git-path follows core.hooksPath, which would name .githooks again;
# the common dir is shared by every worktree, and is relative to the current directory.
#
# It never takes over another tool's hooks: a core.hooksPath keel did not set, or a same-named hook
# without keel's mark, belongs to husky, lefthook or a scanner, and replacing either switches that
# tool off. Nothing here writes git configuration at all, least of all globally.
GUARD_LEGACY_DIR=".githooks"
GUARD_MARK='installed by `keel guard install`'

guard_dir() { printf '%s/hooks' "$(git rev-parse --git-common-dir)"; }

# The first of keel's three hook names whose file in the hooks directory lacks keel's mark, which
# makes it another tool's: the pre-commit framework and lefthook write there. Status 1 when none.
guard_foreign_hook() {
    local d f; d="$(guard_dir)"
    for f in pre-push pre-commit prepare-commit-msg; do
        if [ -e "$d/$f" ] && ! grep -qF "$GUARD_MARK" "$d/$f"; then printf '%s' "$f"; return 0; fi
    done
    return 1
}

# One answer to "is the guard installed", for `guard status` and doctor alike:
#   legacy        core.hooksPath is .githooks and keel's pre-push is there: keel's own old install
#   foreign-path  core.hooksPath points anywhere else, so git never runs the hooks directory. A
#                 .githooks without keel's mark is a project's own hooks, and lands here
#   foreign-hook  the hooks directory holds another tool's pre-push, pre-commit or prepare-commit-msg
#   installed     keel's executable pre-push is in the hooks directory
#   absent        none of these, a keel pre-push that lost its executable bit included
guard_state() {
    local hp d rp rd; hp="$(git config core.hooksPath 2>/dev/null || true)"; d="$(guard_dir)"
    # A core.hooksPath naming the hooks directory itself redirects nothing, so it is not foreign.
    if [ -n "$hp" ]; then
        rp="$(cd "$hp" 2>/dev/null && pwd -P)"; rd="$(cd "$d" 2>/dev/null && pwd -P)"
        if [ -n "$rp" ] && [ "$rp" = "$rd" ]; then hp=""; fi
    fi
    if [ "$hp" = "$GUARD_LEGACY_DIR" ] && grep -qF "$GUARD_MARK" "$GUARD_LEGACY_DIR/pre-push" 2>/dev/null; then
        printf 'legacy'
    elif [ -n "$hp" ]; then
        printf 'foreign-path'
    elif guard_foreign_hook >/dev/null; then
        printf 'foreign-hook'
    elif [ -x "$d/pre-push" ] && grep -qF "$GUARD_MARK" "$d/pre-push"; then
        printf 'installed'
    else
        printf 'absent'
    fi
}
```

In `cmd_guard`, replace the `install)` branch, from `install)` down to and including its `;;`,
with:

```bash
        install)
            local st d f; st="$(guard_state)"; d="$(guard_dir)"
            # Decided by guard_state, not by the setting's value: a .githooks without keel's mark
            # is a project's own hooks, and unsetting core.hooksPath would switch them off.
            if [ "$st" = foreign-path ]; then
                die "core.hooksPath points at '$(git config core.hooksPath)', which keel did not set, so git runs no hooks from $d. Replacing it would switch those hooks off; unset it yourself if keel's guard should take their place."
            fi
            if f="$(guard_foreign_hook)"; then
                die "$d/$f is another tool's hook, and installing would overwrite it. Remove it, or call it from keel's hook after install, then re-run."
            fi
            mkdir -p "$d"
            guard_hook_body > "$d/pre-push"
            guard_precommit_body > "$d/pre-commit"
            guard_prepare_commit_msg_body > "$d/prepare-commit-msg"
            chmod +x "$d/pre-push" "$d/pre-commit" "$d/prepare-commit-msg"
            if [ "$st" = legacy ]; then
                git config --unset core.hooksPath || die "could not unset core.hooksPath, which still points at $GUARD_LEGACY_DIR. Unset it with: git config --unset core.hooksPath"
                say "moved the guard out of $GUARD_LEGACY_DIR/, a working-tree path that every checkout replaces, and unset core.hooksPath. Delete $GUARD_LEGACY_DIR/, with 'git rm -r $GUARD_LEGACY_DIR' where it is committed"
            fi
            say "installed pre-push, pre-commit and prepare-commit-msg in $d, where no checkout can replace them"
            say "the commit hook stays inert until gates.commit_guard is 'required' or 'warn'"
            say "the hooks are not committed: each clone runs 'keel guard install' for itself"
            ;;
```

Replace the `uninstall)` branch, from `uninstall)` down to and including its `;;`, with:

```bash
        uninstall)
            local d f; d="$(guard_dir)"
            # Only files carrying keel's mark: a same-named hook without it is another tool's.
            for f in pre-push pre-commit prepare-commit-msg; do
                if grep -qF "$GUARD_MARK" "$d/$f" 2>/dev/null; then rm -f "$d/$f"; fi
            done
            # An install at .githooks is unhooked, not deleted: those files are often committed,
            # and keel does not delete tracked files.
            if [ "$(guard_state)" = legacy ]; then
                git config --unset core.hooksPath 2>/dev/null || true
                say "unset core.hooksPath, which pointed at keel's old install in $GUARD_LEGACY_DIR/. Delete $GUARD_LEGACY_DIR/ yourself, with 'git rm -r $GUARD_LEGACY_DIR' where it is committed"
            fi
            say "removed keel's push, commit and message hooks from $d. Hooks other tools wrote are untouched"
            ;;
```

In the `status)` branch, replace its first lines:

```bash
            local hp; hp="$(git config core.hooksPath 2>/dev/null || true)"
            if [ "$hp" = "$GUARD_DIR" ] && [ -x "$GUARD_DIR/pre-push" ]; then
                say "push guard: active"
```

with:

```bash
            local hp d st; hp="$(git config core.hooksPath 2>/dev/null || true)"; d="$(guard_dir)"
            st="$(guard_state)"
            if [ "$st" = installed ]; then
                say "push guard: active"
```

then, inside that branch, replace every remaining `$GUARD_DIR/` with `$d/`: the `pre-commit`
test, the `prepare-commit-msg` test, and the `grep -q no_attribution_footers` line.

Then replace the status branch's tail, which after the edits above reads exactly:

```bash
            elif [ -n "$hp" ]; then
                say "push guard: inactive. core.hooksPath points at '$hp', which keel did not set"
                return 1
            else
                say "push guard: not installed. Run 'keel guard install'"
                return 1
            fi
```

(the 12-space indentation makes it unique: `guard_state`'s own `elif [ -n "$hp" ]` is indented
four), with:

```bash
            elif [ "$st" = legacy ]; then
                say "push guard: installed in $GUARD_LEGACY_DIR/, a working-tree path, so checking out a branch runs that branch's own hooks. Re-run 'keel guard install' to move it into $d"
                return 1
            elif [ "$st" = foreign-path ]; then
                say "push guard: inactive. core.hooksPath points at '$hp', which keel did not set"
                return 1
            elif [ "$st" = foreign-hook ]; then
                say "push guard: not installed. $d/$(guard_foreign_hook) is another tool's hook"
                return 1
            else
                say "push guard: not installed. Run 'keel guard install'"
                return 1
            fi
```

In `cmd_doctor_text`, doctor's push guard test also reads `GUARD_DIR`, which is gone, and under
`set -u` an unset variable aborts doctor. Replace:

```bash
        local ghp; ghp="$(git config core.hooksPath 2>/dev/null || true)"
        if [ "$ghp" = "$GUARD_DIR" ] && [ -x "$GUARD_DIR/pre-push" ]; then
```

with:

```bash
        if [ "$(guard_state)" = installed ]; then
```

Run `grep -c 'GUARD_DIR' bin/keel`. Expected: `0`.
Run the lint command. Expected: exit 0.

In `docs/03-install-and-distribution.md`, replace:

```markdown
Installs three hooks, by writing `.githooks/pre-push`, `.githooks/pre-commit`, and
`.githooks/prepare-commit-msg`, and setting
`core.hooksPath` **for this repository only**. Opt-in, because it changes your git configuration, and
repo-local because setting `core.hooksPath` globally would silently disable every other repository's
hooks on the machine. `git push --no-verify` is the deliberate way past it.
```

with:

```markdown
Installs three hooks, `pre-push`, `pre-commit` and `prepare-commit-msg`, into git's own hooks
directory (`.git/hooks`, shared by every worktree), and sets no `core.hooksPath`. No checkout
writes there, so checking out a branch, a fork's pull request included, never runs that branch's
own hooks; until 2026-09-26 the guard lived in `.githooks` behind `core.hooksPath`, a working-tree
path every checkout replaced. `keel guard install` moves such an install and unsets the setting.
It refuses while `core.hooksPath` points anywhere else, or while a same-named hook without keel's
mark is present, because replacing either switches another tool's hooks off. The hooks are not
committed: each clone runs `keel guard install` for itself. Opt-in, because it writes into your git
directory. `git push --no-verify` is the deliberate way past it.
```

In the same file, replace:

```markdown
`git commit --no-verify` does not skip it, only bypassing `core.hooksPath` skips the trailer.
```

with:

```markdown
`git commit --no-verify` does not skip it; only running git with hooks disabled, such as
`git -c core.hooksPath=/dev/null commit`, skips the trailer.
```

In `README.md`, replace:

```
keel guard install    # pre-push, pre-commit, and prepare-commit-msg hooks, repo-local
```

with:

```
keel guard install    # pre-push, pre-commit, and prepare-commit-msg hooks, in .git/hooks
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS, including every case in the three new blocks, `guard install sets no
core.hooksPath` and `guard uninstall removes the pre-push hook`. `doctor output unchanged against
HEAD` stays green, because its fixture has no guard and prints the `absent` line either way. Any
other red is a finding.

- [x] **Step 5: Run the suite at the unit boundary, then hand over**

Add under `## Unreleased` in `CHANGELOG.md`:

```markdown
- `keel guard install` writes its hooks into git's own hooks directory and sets no
  `core.hooksPath`. It used `core.hooksPath=.githooks`, a working-tree path, so checking out any
  branch, a fork's pull request included, ran that branch's own hooks. install moves an install at
  `.githooks` and unsets the setting, and refuses while another tool's `core.hooksPath` or
  same-named hook is present. The hooks are no longer committed; each clone installs its own.
```

Run: `tests/validate-citations.sh`, and repair any citation it reports, then check the line shifts
in `bin/keel`, `tests/test-keel.sh` and `docs/03-install-and-distribution.md` as the global
constraints describe. Expect it to report at least
`docs/plans/2026-08-17-release-readiness.md` and
`docs/plans/2026-09-19-make-keel-enforceable-outside-the-agent.md`, which cite
`` bin/keel#guard_hook_body > "$GUARD_DIR/pre-push" ``, a line this task replaces: repoint each to
`` bin/keel#guard_hook_body > "$d/pre-push" ``, which occurs once.
Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named. `tests/supply-chain-scan.sh` still
allows `.githooks/*` as an executable path; task 3 removes that allowance with this repository's
own `.githooks/`. Run `grep -rn githooks tests/ lib/ hooks/ skills/ templates/` and report any hit
outside `tests/test-keel.sh` and that allowance: it names the old location.

```bash
git add bin/keel tests/test-keel.sh docs/03-install-and-distribution.md README.md CHANGELOG.md
git status --porcelain
```

Add any file whose citation you repaired. Stage exactly those paths and stop. **Do not commit.**
The coordinator commits with
`git commit -m "fix(guard): install into git's hooks directory, where no checkout reaches"`.

---

### Task 2: `doctor` reports the guard by the same state `guard status` uses

> **Execution note (2026-09-26):** delegated. Step 2 witnessed in the implementer's report: 668
> passed, 4 failed, the four `doctor guard state` cases on the generic warning. Step 4: 672 passed,
> 0 failed, the python3 budget at 10 and `doctor output unchanged against HEAD` green. Review (spec
> and quality): COMPLIES, and every new case red under its mutation. **Beyond the step text,
> approved by the coordinator after that review:** the comment above the `case` said only the
> absent state is sent to guard install, which the legacy line contradicted, and now says the
> absent and legacy states are; a legacy `.githooks` that also holds other executable hooks is
> named in both doctor's line and `guard status`'s, since install refuses it; the foreign-path
> line in both names the setting's scope (`guard_hooks_path_source`); the CHANGELOG and docs/03
> say "same-named hook", not `pre-push`. Four cases added for these, red then green: 676 passed,
> 0 failed; `tests/run-tests.sh` All test files passed; lint 0; validator OK. One citation the
> added lines moved onto a blank line, the pre-push line citation in
> `docs/ideas/windows-python3-detection-is-wrong.md`, now cites the phrase `&& have_py=1`, the
> pre-push line its sentence describes.

**Story:** findings 1 and 2
**Files:**
- Modify: `bin/keel` (function `cmd_doctor_text`)
- Modify: `tests/test-keel.sh`
- Modify: `docs/03-install-and-distribution.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: `guard_state`, `guard_dir`, `guard_foreign_hook` and `GUARD_LEGACY_DIR` from task 1
- Produces: nothing new

**Depends on:** task 1

**Done when:** `tests/test-keel.sh` passes.

- [x] **Step 1: Write the failing tests**

Insert above the final `printf` line of `tests/test-keel.sh`:

```bash
# ---- doctor names the guard's real state, and never sends anyone to replace another tool --------
# doctor tested core.hooksPath=.githooks plus an executable .githooks/pre-push, so any project's own
# .githooks/pre-push read as keel's guard, and every other state got "Run: keel guard install",
# which for a husky or lefthook project meant switching those hooks off.
dg="$(fixture node-ts)"
( cd "$dg" && "$KEEL" init -y >/dev/null 2>&1 )
seed_standards "$dg"
( cd "$dg" && git config core.hooksPath .husky )
out="$( cd "$dg" && "$KEEL" doctor --fast 2>&1 )"
line="$(printf '%s\n' "$out" | grep 'push guard')"
case "$line" in
  *"which keel did not set"*)
    case "$line" in
      *"Run: keel guard install"*) bad "doctor guard state" "a foreign core.hooksPath was told to run guard install: $line" ;;
      *) ok "doctor names a foreign core.hooksPath and does not send it to guard install" ;;
    esac ;;
  *) bad "doctor guard state" "foreign core.hooksPath line: $line" ;;
esac
( cd "$dg" && git config --unset core.hooksPath \
  && printf '#!/bin/sh\n# another tool\nexit 0\n' > .git/hooks/pre-push && chmod +x .git/hooks/pre-push )
out="$( cd "$dg" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"ok    push guard installed"*) bad "doctor guard state" "another tool's pre-push counted as keel's guard" ;;
  *"another tool's hook"*) ok "doctor does not count another tool's pre-push as the guard" ;;
  *) bad "doctor guard state" "foreign pre-push line: $(printf '%s\n' "$out" | grep 'push guard')" ;;
esac
( cd "$dg" && rm -f .git/hooks/pre-push \
  && printf '#!/bin/sh\n# another tool\nexit 0\n' > .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit )
out="$( cd "$dg" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"pre-commit is another tool's hook"*) ok "doctor names another tool's pre-commit rather than calling the guard absent" ;;
  *) bad "doctor guard state" "foreign pre-commit line: $(printf '%s\n' "$out" | grep 'push guard')" ;;
esac
( cd "$dg" && rm -f .git/hooks/pre-commit && "$KEEL" guard install >/dev/null 2>&1 \
  && mkdir -p .githooks \
  && mv .git/hooks/pre-push .git/hooks/pre-commit .git/hooks/prepare-commit-msg .githooks/ \
  && git config core.hooksPath .githooks )
out="$( cd "$dg" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"WARN  the push guard is installed in .githooks/, a working-tree path"*)
    ok "doctor warns that an install at .githooks runs a checked-out branch's hooks" ;;
  *) bad "doctor guard state" "legacy line: $(printf '%s\n' "$out" | grep 'push guard')" ;;
esac
rm -rf "$dg"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL on `doctor guard state` four times. After task 1 doctor knows only installed or
not, so each of the three states prints the generic warning ending `Run: keel guard install`: the
foreign `core.hooksPath` case fails on `foreign core.hooksPath line`, the foreign pre-push case on
`foreign pre-push line`, the foreign pre-commit case on `foreign pre-commit line`, and the
`.githooks` case on `legacy line`.

- [x] **Step 3: Write the minimal implementation**

In `bin/keel`, function `cmd_doctor_text`, replace:

```bash
        if [ "$(guard_state)" = installed ]; then
            good "push guard installed: a push to the default branch is refused outside a session too"
        else
            warn "conventions.protect_default_branch is not false and the push guard is not installed, so nothing outside a session enforces it. Run: keel guard install"
        fi
```

with:

```bash
        # The same state `keel guard status` reports, so the two never disagree. Only the absent
        # state is sent to guard install: install refuses the foreign ones, because running it
        # there would switch another tool's hooks off, and the legacy one it moves.
        case "$(guard_state)" in
          installed)
            good "push guard installed: a push to the default branch is refused outside a session too" ;;
          legacy)
            warn "the push guard is installed in $GUARD_LEGACY_DIR/, a working-tree path, so checking out a branch runs that branch's own hooks. Run: keel guard install, which moves it into $(guard_dir)" ;;
          foreign-path)
            warn "conventions.protect_default_branch is not false and the push guard is not installed: core.hooksPath points at '$(git config core.hooksPath)', which keel did not set, and keel guard install refuses to replace it" ;;
          foreign-hook)
            warn "conventions.protect_default_branch is not false and the push guard is not installed: $(guard_dir)/$(guard_foreign_hook) is another tool's hook, which keel guard install will not overwrite" ;;
          *)
            warn "conventions.protect_default_branch is not false and the push guard is not installed, so nothing outside a session enforces it. Run: keel guard install" ;;
        esac
```

In the comment above that block, replace:

```bash
    # FAIL: installing it changes the developer's git configuration, which stays their choice. It
```

with:

```bash
    # FAIL: installing it writes into the developer's git directory, which stays their choice. It
```

Run the lint command. Expected: exit 0.

In `docs/03-install-and-distribution.md`, replace:

```markdown
`keel doctor` warns while `conventions.protect_default_branch` is not false and the guard is not
installed, because nothing else outside a session enforces that key.
```

with:

```markdown
`keel doctor` warns while `conventions.protect_default_branch` is not false and the guard is not
installed, because nothing else outside a session enforces that key. It reports the state
`keel guard status` does: an install at `.githooks` is a warning to move it, and another tool's
`core.hooksPath` or `pre-push` is named without sending you to `keel guard install`.
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS, including the four new `doctor guard state` cases, the existing `doctor warns when
the push guard is not installed` and `doctor reports an installed push guard as ok`, and
`keel doctor starts python3 at most 10 times (10)`. `doctor output unchanged against HEAD` stays
green: its fixture prints the unchanged `absent` line.

- [x] **Step 5: Run the suite at the unit boundary, then hand over**

Add under `## Unreleased` in `CHANGELOG.md`:

```markdown
- `keel doctor` reports the push guard in the same states `keel guard status` does. An install at
  `.githooks` warns that a checkout runs the branch's own hooks; another tool's `core.hooksPath` or
  `pre-push` is named, not counted as the guard and not sent to `keel guard install`.
```

Run: `tests/validate-citations.sh`, repair what it reports, and check the line shifts in
`bin/keel` and `docs/03-install-and-distribution.md`.
Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named.

```bash
git add bin/keel tests/test-keel.sh docs/03-install-and-distribution.md CHANGELOG.md
git status --porcelain
```

Add any file whose citation you repaired. Stage exactly those paths and stop. **Do not commit.**
The coordinator commits with
`git commit -m "fix(doctor): report the guard's real state, and never replace another tool's hooks"`.

---

### Task 3: this repository runs its guard from `.git/hooks`

> **Execution note (2026-09-26):** delegated. Step 1 witnessed in the implementer's report: the
> absent-state WARN. Before the install, `.git/hooks` held only samples and `core.hooksPath` was
> unset. Step 3: `installed pre-push, pre-commit and prepare-commit-msg in .git/hooks, where no
> checkout can replace them`, no move line, `core.hooksPath` unset. Step 4: `ok    push guard
> installed: a push to the default branch is refused outside a session too` and `keel doctor: no
> problems, 5 warnings`, which is the Done when. `tests/run-tests.sh` All test files passed;
> validator OK; scan clean; `grep -c githooks docs/06-repo-layout.md` is 0. No citation moved onto
> a wrong target. One line break added to the snapshot correction to keep it within 100 columns.
> Review: the coordinator checked the diff against the step text (file removals, one comment, a
> tree entry, two text swaps); no review subagent was dispatched.

**Story:** finding 1
**Files:**
- Delete: `.githooks/pre-push`, `.githooks/pre-commit`, `.githooks/prepare-commit-msg` (tracked
  since 9fb2b3b)
- Modify: `tests/supply-chain-scan.sh` (function `allowed_executable`)
- Modify: `docs/06-repo-layout.md`
- Modify: `docs/snapshot.md` (one `Correction:` line)
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: task 1's `keel guard install`
- Produces: nothing new

**Depends on:** task 2

**Done when:** `bin/keel doctor --fast` prints `ok    push guard installed` and a summary starting
`keel doctor: no problems`, and `git config core.hooksPath` prints nothing.

- [x] **Step 1: Watch the check fail**

Run: `bin/keel doctor --fast`
Expected: `WARN  conventions.protect_default_branch is not false and the push guard is not
installed, so nothing outside a session enforces it. Run: keel guard install`, because this clone's
`core.hooksPath` was unset on 2026-09-26 and `.git/hooks` holds only samples.

- [x] **Step 2: Remove the committed hooks and their allowance**

```bash
git rm -q .githooks/pre-push .githooks/pre-commit .githooks/prepare-commit-msg
ls .githooks 2>/dev/null || echo "gone"
```

Expected: `gone`.

In `tests/supply-chain-scan.sh`, function `allowed_executable`, replace:

```bash
        .githooks/*)         return 0 ;;   # written by `keel guard install`, and scanned like everything else
```

with:

```bash
        .githooks/*)         return 0 ;;   # keel guard install wrote here until 2026-09-26; a plugin repo that committed it on that advice is not flagged for it
```

The allowance stays: removing it would fail every plugin repository that committed `.githooks/`
on keel's earlier advice, and the files are still scanned like everything else.

In `docs/06-repo-layout.md`, delete these five lines from the tree:

```
├── .githooks/                          # this repository's own guard, from `keel guard install`
│   ├── pre-commit                      # inert while gates.commit_guard is off
│   ├── pre-push                        # refuses a push to main, and runs the supply chain scan
│   └── prepare-commit-msg              # adds nothing here: no_attribution_footers is true
│
```

In `docs/snapshot.md`, replace:

```markdown
task 4 and follow-up C). `keel init` still does not install it. This clone's `core.hooksPath` is
`.githooks`, whose hooks are committed (9fb2b3b, task 7).
```

with:

```markdown
task 4 and follow-up C). `keel init` still does not install it. This clone runs the guard from
`.git/hooks` with no `core.hooksPath`, per docs/plans/2026-09-26-guard-hooks-outside-the-working-tree.md.
```

In `CHANGELOG.md`, replace the entry task 7 of the previous plan added:

```markdown
- keel runs its own push guard, committed under `.githooks/`, and its `.claude/settings.json`
  carries the curl, wget and nc ask rules. Its profile records 0.21.0.
  `keel doctor` on this repository failed on the rules and warned on the guard.
```

with:

```markdown
- keel runs its own push guard, installed in `.git/hooks`, and its `.claude/settings.json`
  carries the curl, wget and nc ask rules. Its profile records 0.21.0.
  `keel doctor` on this repository failed on the rules and warned on the guard.
```

- [x] **Step 3: Install the guard here**

Run: `bin/keel guard install`
Expected: `installed pre-push, pre-commit and prepare-commit-msg in .git/hooks, where no checkout
can replace them`, and no line about moving from `.githooks`, since `core.hooksPath` is unset.
Run: `git config core.hooksPath || echo "unset"`
Expected: `unset`.

- [x] **Step 4: Watch the check pass**

Run: `bin/keel doctor --fast`
Expected: `ok    push guard installed: a push to the default branch is refused outside a session
too` and a summary starting `keel doctor: no problems`.

- [x] **Step 5: Run the suite at the unit boundary, then hand over**

Run: `tests/validate-citations.sh`, repair what it reports, and check the line shifts in
`docs/06-repo-layout.md` and `docs/snapshot.md`.
Run: `tests/run-tests.sh`
Expected: PASS. `tests/test-doc-claims.sh`'s tree check fails only on a top-level entry the tree
omits, never on one the tree shows that is gone, so it cannot catch a leftover `.githooks/` line:
confirm the removal with `grep -c githooks docs/06-repo-layout.md`, which must print `0`.

```bash
git add tests/supply-chain-scan.sh docs/06-repo-layout.md docs/snapshot.md CHANGELOG.md
git status --porcelain
```

The three `git rm` deletions are already staged. Add any file whose citation you repaired. Stage
exactly those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "chore: this repository's guard lives in .git/hooks, not in the tree"`; that commit
runs through the installed hooks and must carry no `Keel-Version` trailer.

---

### Task 4: a failing `verify.security` says what it means, and a project can keep its own

> **Execution note (2026-09-26):** delegated. Step 2 witnessed in the implementer's report: 676
> passed, 2 failed, both `verify.security result` cases on `FAIL  verify.security does not run
> (0s): exit 3`. Step 4: 678 passed, 0 failed, with the twelve existing `verify.security` cases.
> Schema `2 +-`, `tests/test-profile-keys.sh` 12 passed, lint 0, validator OK, scan clean,
> `tests/run-tests.sh` All test files passed. The preconditions.md sentences were reflowed into
> the paragraph they extend, words unchanged. Review: the coordinator read the diff against the
> step text; no review subagent was dispatched. The two skill reference edits are a skill change,
> which docs/standards.md's review rule has a maintainer review at the pull request.

**Story:** finding 3
**Files:**
- Modify: `bin/keel` (function `cmd_doctor_text`)
- Modify: `tests/test-keel.sh`
- Modify: `templates/profile.schema.json` (the `verify.security` description)
- Modify: `docs/profile-keys.md` (regenerated)
- Modify: `docs/03-install-and-distribution.md`
- Modify: `skills/execute-plan/references/preconditions.md`
- Modify: `skills/write-plan/references/plan-template.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: doctor's verify loop, `for k in test lint typecheck build security; do`
- Produces: the FAIL line `verify.security exited <rc> (<n>s): <command>. ...` in place of
  `verify.security does not run` for a non-zero, non-timeout exit

**Depends on:** task 3

**Done when:** `tests/test-keel.sh` passes.

- [x] **Step 1: Write the failing test**

Insert above the final `printf` line of `tests/test-keel.sh`:

```bash
# ---- a failing verify.security is reported as an audit result, not a broken command -------------
# An audit exits non-zero on a finding at or above its threshold, and when it cannot reach its
# registry. "does not run" sent the reader to debug a command that ran.
fs="$(fixture node-ts)"
( cd "$fs" && "$KEEL" init -y >/dev/null 2>&1 \
  && "$KEEL" profile set verify.security 'exit 3' >/dev/null 2>&1 )
seed_standards "$fs"
[ "$(verify_of "$fs" security)" = "exit 3" ] \
  || bad "verify.security result" "fixture precondition: verify.security is '$(verify_of "$fs" security)'"
out="$( cd "$fs" && "$KEEL" doctor 2>&1 )"
case "$out" in
  *"FAIL  verify.security exited 3"*"run it to see which"*)
    ok "doctor reports a failing verify.security as an exit code and how to read it" ;;
  *) bad "verify.security result" "line: $(printf '%s\n' "$out" | grep 'verify.security')" ;;
esac
case "$out" in
  *"verify.security does not run"*) bad "verify.security result" "still says 'does not run'" ;;
  *) ok "a failing verify.security no longer reads as a command that does not run" ;;
esac
rm -rf "$fs"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL on `verify.security result` twice: the line is
`FAIL  verify.security does not run (0s): exit 3`, and `still says 'does not run'`.

- [x] **Step 3: Write the minimal implementation**

In `bin/keel`, function `cmd_doctor_text`, replace:

```bash
            else fail "verify.$k does not run (${el}s): $c"; fi
```

with:

```bash
            elif [ "$k" = security ]; then
                # An audit exits non-zero on a finding at or above its threshold and when it cannot
                # reach its registry, so "does not run" would send the reader to debug a command that
                # ran. Its output is discarded like every verify command's, so the line says how to
                # tell the two apart.
                fail "verify.security exited $rc (${el}s): $c. An audit exits non-zero on a finding at or above its threshold and when it cannot reach its registry; run it to see which"
            else fail "verify.$k does not run (${el}s): $c"; fi
```

Run the lint command. Expected: exit 0.

Update the schema description. Edit it through `json.dump`, which round-trips this file:

```bash
python3 - <<'PY'
import json
p = "templates/profile.schema.json"
s = json.load(open(p))
e = s["properties"]["verify"]["properties"]["security"]
old = e["description"]
add = " To keep a different audit, or a no-op, set it to that command: keel init keeps any value that is not null, and detects one again where it is null."
assert add not in old
e["description"] = old + add
f = open(p, "w"); json.dump(s, f, indent=2, ensure_ascii=False); f.write("\n"); f.close()
PY
git diff --stat templates/profile.schema.json
tests/generate-profile-keys.sh > docs/profile-keys.md
tests/test-profile-keys.sh
```

Expected: `templates/profile.schema.json | 2 +-`, and `tests/test-profile-keys.sh` passes.

In `docs/03-install-and-distribution.md`, replace:

```markdown
  them and reaches the network, so full doctor fails with `verify.security does not run` offline or
  when the audit finds a high advisory
```

with:

```markdown
  them and reaches the network, so full doctor fails with `verify.security exited <code>` offline
  or when the audit finds a high advisory. A project that wants another threshold, or no audit in
  doctor, sets `verify.security` to that command; `keel init` keeps any value that is not null,
  and detects the audit again where it is null
```

In `skills/execute-plan/references/preconditions.md`, directly after the line
`exit 0, which is all it keeps.`, which ends the sentence beginning `Doctor is right for that one`,
add, wrapped at 100 columns:

```markdown
Full doctor also runs `verify.security` where `keel init` detected one, which needs the network
and fails on a high advisory. Name that line when stopping on it: it is the dependency tree's
state, not task 1's toolchain.
```

In `skills/write-plan/references/plan-template.md`, replace:

```markdown
`keel profile set verify.test ...` for each and a `keel doctor` that must pass. State the commands
```

with:

```markdown
`keel profile set verify.test ...` for each and a `keel doctor` that must pass. Full doctor also
runs `verify.security` where one was detected, which needs the network, so a task that must leave
doctor passing names that dependency. State the commands
```

and rewrap the rest of that paragraph at 100 columns without changing a word.

These two are reference files, not skill bodies, so no word ceiling or eval arm applies
(docs/standards.md, the word ceiling rule); `tests/validate-skills.sh` inside the suite checks
their links.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS, including both `verify.security result` cases and every existing `verify.security`
case from the previous plan's task 6.

- [x] **Step 5: Run the suite at the unit boundary, then hand over**

Add under `## Unreleased` in `CHANGELOG.md`:

```markdown
- A failing `verify.security` in full `keel doctor` reads `verify.security exited <code>` and
  says an audit exits non-zero on a finding or an unreachable registry, not `does not run`. A
  project keeps its own audit, or a no-op, by setting `verify.security` to it; init keeps any
  value that is not null.
```

Run: `tests/validate-citations.sh`, repair what it reports, and check the line shifts in every
file this task changed.
Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named.

```bash
git add bin/keel tests/test-keel.sh templates/profile.schema.json docs/profile-keys.md \
        docs/03-install-and-distribution.md skills/execute-plan/references/preconditions.md \
        skills/write-plan/references/plan-template.md CHANGELOG.md
git status --porcelain
```

Add any file whose citation you repaired. Stage exactly those paths and stop. **Do not commit.**
The coordinator commits with
`git commit -m "fix(doctor): a failing verify.security reads as an audit result"`.

---

### Task 5: pin `write_ci`'s branch read and pnpm detection with tests that can fail

> **Execution note (2026-09-26):** delegated. Step 2 witnessed in the implementer's report, on the
> file's preamble plus the two new blocks: with the profile read blanked, `FAIL  write_ci branch:
> workflow trigger: 5:    branches: [main]`; with the `pnpm)` arm deleted, `FAIL  verify.security:
> pnpm: got ''`; each restored and `git diff --stat` empty. Step 4: 680 passed, 0 failed, both new
> cases passing. `tests/run-tests.sh` All test files passed. No citation moved. Review: the
> coordinator checked that only `tests/test-keel.sh` changed; no review subagent was dispatched
> for two verbatim test blocks.

**Story:** finding 4
**Files:**
- Modify: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `write_ci` (reads `conventions.default_branch`), `detect_verify`'s `pnpm)` arm
- Produces: nothing new

**Depends on:** task 4

**Done when:** `tests/test-keel.sh` passes, and each new case goes red under its mutation in
step 2.

- [x] **Step 1: Write the tests**

Insert above the final `printf` line of `tests/test-keel.sh`:

```bash
# ---- write_ci follows the profile's branch, not git's ---------------------------------------------
# Both default-branch cases above use a master repository where git and the profile agree, so
# deleting write_ci's read of the profile left them green. Here they disagree.
tb="$(fixture node-ts)"
( cd "$tb" && "$KEEL" init -y >/dev/null 2>&1 \
  && "$KEEL" profile set conventions.default_branch trunk >/dev/null 2>&1 \
  && rm -rf .github && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(prof_of "$tb" conventions.default_branch)" = trunk ] \
  || bad "write_ci branch" "fixture precondition: the profile does not record trunk"
grep -q 'branches: \[trunk\]' "$tb/.github/workflows/ci.yml" \
  && ok "generated CI triggers on the profile's branch where git names another" \
  || bad "write_ci branch" "workflow trigger: $(grep -n 'branches' "$tb/.github/workflows/ci.yml")"
rm -rf "$tb"

# ---- pnpm detection has a case of its own -------------------------------------------------------
# The CI case for pnpm reads write_ci's own mapping, so deleting detect_verify's pnpm arm left
# every case green.
sp="$(fixture node-ts)"; : > "$sp/pnpm-lock.yaml"
( cd "$sp" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(verify_of "$sp" security)" = "pnpm audit --audit-level high" ] \
  && ok "init detects verify.security from a pnpm-lock.yaml" \
  || bad "verify.security" "pnpm: got '$(verify_of "$sp" security)'"
rm -rf "$sp"
```

- [x] **Step 2: Watch each fail under its mutation**

These pin code that already works, so each is proved by breaking that code, then restoring it.

```bash
cp bin/keel /tmp/keel.orig 2>/dev/null || cp bin/keel "${TMPDIR:-/tmp}/keel.orig"
```

Use the scratch directory the coordinator names in place of `${TMPDIR:-/tmp}` where one is given.
1. In `bin/keel`, function `write_ci`, change the line
   `local branch; branch="$(json_get .keel/profile.json conventions.default_branch || true)"` to
   `local branch; branch=""`. Run `tests/test-keel.sh`. Expected: FAIL on `write_ci branch:
   workflow trigger` with `branches: [main]` or `branches: [master]`, the fixture's git branch.
   Restore `bin/keel` from the copy and confirm `git diff --stat bin/keel` prints nothing.
2. In `lib/detect-stack.sh`, delete the line
   `              pnpm) printf 'pnpm audit --audit-level high' ;;`. Run `tests/test-keel.sh`.
   Expected: FAIL on `verify.security: pnpm: got ''`. Restore it with
   `git checkout -- lib/detect-stack.sh` and confirm `git diff --stat lib/detect-stack.sh` prints
   nothing.

If a case stays green under its mutation, stop and report it.

- [x] **Step 3: There is no implementation**

The code these pin is already correct; this task adds proof, not behaviour.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS, including both new cases.

- [x] **Step 5: Run the suite at the unit boundary, then hand over**

No CHANGELOG line: nothing a user sees changes.
Run: `tests/run-tests.sh`
Expected: PASS.

```bash
git add tests/test-keel.sh
git status --porcelain
```

`git status --porcelain` must list only `tests/test-keel.sh`: the mutations were restored. Stage
exactly that path and stop. **Do not commit.** The coordinator commits with
`git commit -m "test: pin write_ci's profile branch read and pnpm detection"`.

---

### Task 6: the documents the review found wrong

> **Execution note (2026-09-26):** delegated. Every target occurred once. Step 4: word-diff count
> 0 and the `awk` check empty, so only line breaks moved. **Deviation:** the docs/06 tree comment as
> given made the line 114 characters, so it reads `the pipeline. Shell lint from the profile; ruff
> only here`, meaning unchanged. Three `docs/standards.md` line citations in
> `docs/audits/2026-09-25-standards.md` moved by the new paragraph were renumbered onto the rows
> they name. `tests/run-tests.sh` All test files passed; validator OK; scan clean. No CHANGELOG
> line: nothing a user sees changes. Left: docs/03's trailer paragraph now states the
> `no_attribution_footers` exception in two sentences. Review: the coordinator read the report
> against the step text; no review subagent was dispatched for this documentation task.

**Story:** finding 5
**Files:**
- Modify: `docs/03-install-and-distribution.md`
- Modify: `docs/standards.md`
- Modify: `docs/06-repo-layout.md`
- Modify: `docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md`

**Interfaces:** none. Documentation only.

**Depends on:** task 5

**Done when:** `tests/run-tests.sh` passes, which runs the citation and document validators over
`docs/`, and `awk 'length>100 && /^>/' docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md`
prints only lines that are a single unbreakable token.

- [x] **Step 1: There is no failing test for this**

This task corrects prose. No validator reads these sentences or the wrap of a blockquote.

- [x] **Step 2: The trailer paragraph in docs/03**

In `docs/03-install-and-distribution.md`, replace:

```markdown
The prepare-commit-msg hook appends a `Keel-Version: <version>` trailer to every commit message,
```

with:

```markdown
The prepare-commit-msg hook appends a `Keel-Version: <version>` trailer to each commit message,
unless the profile sets `conventions.no_attribution_footers` to `true`,
```

and replace:

```markdown
A hook installed before this release needs `keel guard install` re-run to pick it up.
```

with:

```markdown
A hook written by an older keel adds the trailer whatever that key says; `keel guard status` names
that case, and `keel guard install` replaces the hook.
```

- [x] **Step 3: ruff beside "One definition per verify command"**

In `docs/standards.md`, under `## One definition per verify command`, after the paragraph that
begins `**Example:** \`.github/workflows/ci.yml\` reads \`verify.lint\` with \`jq\``, add:

```markdown
**Exception:** ruff over `lib/` runs in CI only, as the `Python lint` job, by the maintainer's
decision of 2026-09-25, so a contributor needs nothing new installed. It is not a verify command,
so there is no second copy to drift; the cost is that a ruff finding first appears in CI, and the
job pins ruff's version and rule set so that it only ever reports the tree.
```

In `docs/06-repo-layout.md`, replace:

```
│   └── workflows/ci.yml                # the pipeline. Its lint comes from .keel/profile.json
```

with:

```
│   └── workflows/ci.yml                # the pipeline. Its shell lint comes from the profile; ruff runs here only
```

- [x] **Step 4: Rewrap the five long execution notes**

The notes for tasks 0, 1 (two paragraphs), 2 and 3 of the 2026-09-25 plan are single blockquote
lines. Rewrap every blockquote line over 100 columns at 100, never breaking inside a backtick
span, because a citation split across lines no longer resolves:

```bash
python3 - <<'PY'
import re
p = "docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md"
lines = open(p).read().split("\n")
token = re.compile(r"(?:`[^`]*`|[^\s`])+")
out = []
for line in lines:
    if line.startswith("> ") and len(line) > 100:
        cur = ">"
        for w in token.findall(line[2:]):
            if len(cur) + 1 + len(w) > 100 and cur != ">":
                out.append(cur); cur = ">"
            cur += " " + w
        out.append(cur)
    else:
        out.append(line)
open(p, "w").write("\n".join(out))
PY
git diff --word-diff=porcelain docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md \
  | grep '^[-+][^-+]' | grep -v '^+>$' | wc -l
awk 'length>100 && /^>/' docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md
```

Expected: the count is `0`, meaning no word changed, only line breaks and the `>` each new line
starts with; and the `awk` prints nothing, or only lines holding one token too long to break.

- [x] **Step 5: Run the suite at the unit boundary, then hand over**

Run: `tests/validate-citations.sh`, repair what it reports, and grep for
`docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md:` and
`docs/03-install-and-distribution.md:` line citations whose target the rewrap or the added lines
moved.
Run: `tests/run-tests.sh`
Expected: PASS.

```bash
git add docs/03-install-and-distribution.md docs/standards.md docs/06-repo-layout.md \
        docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md
git status --porcelain
```

Add any file whose citation you repaired. Stage exactly those paths and stop. **Do not commit.**
The coordinator commits with
`git commit -m "docs: the trailer, the ruff exception and the plan's long notes"`.

---

## Not in this plan

| Item | Why it is not a task | Next |
|---|---|---|
| The pre-push scan reads the working tree, not the pushed commits, and falls back to the branch's own scanner | Review finding 6, filed as an idea by the maintainer's decision | `shape-idea` |
| `--force` for install over another tool's hook, or chaining to it | Refusing is the safe default; chaining is a design of its own | an idea, if a project asks |
| Repositories that committed `.githooks/` on keel's earlier advice | install and uninstall print how to remove it; keel never deletes tracked files, and the supply chain scan keeps allowing the path | the release note |
| A subdirectory project's hooks read the repository top level's `.keel/profile.json`, since git runs hooks from there | Already so before this plan, when the old hooks did not run at all | an idea, if a monorepo asks |
| After a checkout, a commit or push still runs that branch's code: the commit guard evals the branch profile's `verify.*` commands once `gates.commit_guard` is set, and the push scan can fall back to the branch's own scanner | A commit gate runs the project's commands by design; the scanner fallback is the review's finding 6 | `shape-idea`, with finding 6 |
| `docs/ideas/profile-loosening-goes-unnoticed.md` and `docs/ideas/no-durable-provenance-record.md` say the hooks are installed into `.githooks/` | An idea document records its proposal as written; its status row says it was built | none |
| The review's consider items: enum FAIL on non-gate keys, an older keel against a newer profile, CI `permissions` and hash-pinned ruff, the unquoted branch in generated YAML, `null` on gate keys, the `profile set` comment | Each is a separate judgement the maintainer has not made | `shape-idea`, with the deferred decisions |

## Open questions

None block a task. The decisions of 2026-09-26 are in the header.
