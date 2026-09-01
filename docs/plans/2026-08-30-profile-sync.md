# keel profile sync Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go, on output you read.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness, or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** one command fills the artifact keys whose default location is unambiguous and present,
and `keel doctor` tells anyone who has not run it that they need to.
**Stories:** S-01 to S-09, all nine, from `docs/stories/profile-sync.md`
**ADRs:** none. ADR-0001 constrains skill body length and no task here touches a skill body, which
is CON-03 and the reason this variant was chosen over five skill lines.
**Architecture:** one new function `profile_sync` beside `profile_set` in `bin/keel`, one helper
`dir_has_file`, one `sync)` arm in `cmd_profile`'s existing `case`, and one loop in `cmd_doctor`
next to the artifact loop already there. No new file, no new dependency, no schema change.

## Progress

Updated as each task lands. A tick here means its `Done when:` command was run and its output read.

| Task | | Landed |
|---|---|---|
| 1 | `keel profile sync` fills the keys whose default is present | [x] |
| 2 | A set key is never touched, and the command says what it did | [x] |
| 3 | Only the exact default counts | [x] |
| 4 | An empty directory does not count as present | [x] |
| 5 | `sync` refuses where `get` and `set` already do | [x] |
| 6 | doctor reports a fillable null key | [x] |
| 7 | Discovery: `--help` and the documents | [x] |

## Global constraints

Copied in full rather than linked. A task executed by a fresh agent that reads only its own section
must still obey these.

- **Verify commands, from `.keel/profile.json`:** test `tests/run-tests.sh`, one test
  `tests/test-keel.sh`, lint
  `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh tests/evals/stage.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`.
  There is no typecheck command in this project.
- **`shellcheck` is not installed on this machine.** `tests/run-tests.sh` prints `SKIP` for it
  rather than passing it, and CI runs it. Say so on handover rather than reporting lint passed.
- **Never start on `main`.** Work goes on `sandbox`.
- **No em dashes anywhere**, including in the code comments these tasks add.
- **CON-01: no new writer.** `profile_set` at `bin/keel:973-1017` is the writer. It refuses a
  dotted path not already in the file (`:990-998`), and all six `artifacts.*` keys are seeded by
  `write_profile` at `bin/keel:445-448`, so all six are settable today. It is silent on success and
  clears the JSON cache before returning, carrying its exit status over the clear by hand.
- **CON-02: doctor must not edit the profile.** Task 6 warns and names the command. It writes
  nothing.
- **CON-03: no skill body gains a word.** No task here opens `skills/`.
- **CON-04: no hook.** No task adds one.
- **CON-05: the `artifacts.*` schema stays `["string","null"]`.** No task opens
  `templates/profile.schema.json`.
- **doctor's interpreter budget is 10 python3 starts**, asserted at `tests/test-keel.sh:1189`.
  Measured on a fresh `node-ts` fixture on 2026-08-30: **doctor currently starts 7**. Task 6 is
  designed to add none, and why it adds none is proved in that task rather than assumed.
- **`prof_of` prints `None` for a JSON null**, because it is `print(v)` on the Python value, not
  the empty string. Assert `[ "$got" = "None" ]`, the shape already used at `tests/test-keel.sh:928`
  and `:1821`. `[ -z "$got" ]` silently passes when `prof_of` fails for an unrelated reason, which
  is the bug this note exists to stop.
- **`docs_root` is `docs/keel` by default**, `bin/keel:55`, not `docs`. This repository's own
  profile says `docs`, which is why the stories read `docs/plans`. **A fresh fixture will be
  `docs/keel`.** Every task below reads the root from `docs_root()` and every test derives it
  rather than hardcoding either spelling.

## No concurrent batch

Tasks 2 to 7 all modify `bin/keel` and `tests/test-keel.sh`. Two tasks naming the same file cannot
be a concurrent batch, so this plan is strictly serial. Task 1 first, then any order, but one at a
time.

---

### Task 1: `keel profile sync` fills the keys whose default is present

**Story:** S-01
**Files:**
- Modify: `bin/keel`
- Test: `tests/test-keel.sh`

**Interfaces:**
- Produces: `profile_sync()`, no arguments, prints one line per key filled, returns 0. Called only
  from `cmd_profile`.
- Produces: `dir_has_file <dir>`, returns 0 when the directory holds at least one non-hidden entry.
  Task 4 is the task that makes it matter; it is defined here because `profile_sync` calls it from
  its first line of real work.
- Consumes: `docs_root()` at `bin/keel:278`, `json_get`, `profile_set`, `say` at `bin/keel:74`.

**Depends on:** none

**Done when:** `tests/test-keel.sh` prints `PASS  keel profile sync fills the keys whose default is
present` and the file reports `0 failed`, then `tests/run-tests.sh` prints `All test files passed`.

**Why `json_get` and not a fresh interpreter.** `json_load` flattens the whole profile once into
`JSON_CACHE`, and a **null** value renders as an empty string rather than being omitted, so
`artifacts.snapshot=` is in the cache and `json_get` answers from it without starting python3.
Verified 2026-08-30: `keel profile get artifacts.snapshot` on this repository, whose key is null,
started python3 exactly once, which is `json_load` itself.

- [x] **Step 1: Write the failing test**

Append to the profile section of `tests/test-keel.sh`, after the existing `keel profile set` cases:

```bash
# S-01. The artifacts map named where a project's documents live and nothing ever filled it: six
# keys, six nulls, on the repository that dogfoods the tool. sync fills the three whose default is
# one unambiguous location. FR-01, FR-03, FR-05, FR-09, FR-15.
#
# The root is read from the profile rather than written as `docs`: a fresh init writes
# `docs/keel`, bin/keel:55, and this repository's own profile says `docs`, so a hardcoded spelling
# passes here and fails for the next person who runs it somewhere else.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
root="$(prof_of "$d" docs_root)"
mkdir -p "$d/$root/decisions" "$d/$root/plans"
printf 'x\n' > "$d/$root/snapshot.md"
printf 'x\n' > "$d/$root/decisions/ADR-0001-x.md"
printf 'x\n' > "$d/$root/plans/2026-01-01-x.md"
( cd "$d" && "$KEEL" profile sync >/dev/null 2>&1 )
got="$(prof_of "$d" artifacts.snapshot artifacts.decisions artifacts.plans | tr '\n' ' ')"
want="$root/snapshot.md $root/decisions $root/plans "
[ "$got" = "$want" ] && ok "keel profile sync fills the keys whose default is present" \
  || bad "profile sync" "got '$got', want '$want'"
rm -rf "$d"

# FR-05. A default location that is not there leaves the key null. Writing an absent path would
# convert a silent gap into a hard doctor failure, bin/keel:1335.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
root="$(prof_of "$d" docs_root)"
mkdir -p "$d/$root/plans"
printf 'x\n' > "$d/$root/plans/2026-01-01-x.md"
( cd "$d" && "$KEEL" profile sync >/dev/null 2>&1 )
got="$(prof_of "$d" artifacts.snapshot artifacts.plans | tr '\n' ' ')"
[ "$got" = "None $root/plans " ] && ok "sync leaves a key null when its default is absent" \
  || bad "profile sync" "got '$got', want 'None $root/plans '"
rm -rf "$d"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL twice. The first is
`FAIL  profile sync: got 'None None None ', want 'docs/keel/snapshot.md docs/keel/decisions
docs/keel/plans '`, because `keel profile sync` exits non-zero on the unknown subcommand and writes
nothing, so all three keys are still null.

- [x] **Step 3: Write the minimal implementation**

In `bin/keel`, immediately after `profile_set`'s closing brace, `bin/keel:1017`. **Match on the
comment two lines above it, not on the brace:** `profile_set` ends with the same four lines as the
verify setter below it, `local rc=$?` / `json_cache_clear` / `return $rc` / `}`, so a text match on
that tail lands in the wrong function. The unique anchor is the comment that begins "The refusals
above are exit 1, and cmd_profile's caller reads that." Found by prototyping this task, 2026-08-30.

```bash
# A directory with nothing in it means the project has no documents of that kind, so the key stays
# null. Hidden entries do not count: a lone `.gitkeep` is how an empty directory is kept in git, and
# treating it as a document would record a set that does not exist.
#
# Neither does keel's own scaffolding. `init` writes <docs_root>/decisions/ADR-0000-template.md, so
# that directory is never empty on a freshly initialised project, and counting the template would
# set the key and make doctor warn on every new project before anyone had written anything. It is
# named rather than listed because it is the only file init puts inside a directory any key looks
# at, checked 2026-08-30. FR-06.
dir_has_file() {   # dir_has_file <dir>
    local d="$1" e
    [ -d "$d" ] || return 1
    for e in "$d"/*; do
        [ -e "$e" ] || continue
        case "${e##*/}" in ADR-0000-template.md) continue ;; esac
        return 0
    done
    return 1
}

# Fill the artifact keys whose default location is one unambiguous place and is really there.
#
# Three keys, not six. `prd`, `stories` and `architecture` default to `<docs_root>/<key>/<slug>.md`,
# one file per slug, and a repository with five PRDs has no single path to record. Task 3 says so in
# the output; here they are simply absent from the list. FR-03, FR-04.
#
# `json_get` rather than a fresh interpreter: json_load flattens the profile once and renders a null
# as an empty string, so a null key is a cache hit and costs no interpreter start.
profile_sync() {
    local root; root="$(docs_root)"
    local key path filled=0
    for key in snapshot decisions plans; do
        [ -n "$(json_get .keel/profile.json "artifacts.$key" 2>/dev/null || true)" ] && continue
        case "$key" in
          snapshot) path="$root/snapshot.md"; [ -f "$path" ] || continue ;;
          *)        path="$root/$key"; dir_has_file "$path" || continue ;;
        esac
        profile_set "artifacts.$key" "$path" || return 1
        say "  artifacts.$key -> $path"
        filled=$((filled+1))
    done
    return 0
}
```

Then add the `sync` arm to `cmd_profile`'s `case`, between the `set)` arm and the `*)` arm at
`bin/keel:1027`:

```bash
      sync) profile_sync ;;
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on both new cases, `0 failed`.
Then run `tests/run-tests.sh`. Expected: `All test files passed`. Nothing else may break.

- [x] **Step 5: Hand over**

```bash
git add bin/keel tests/test-keel.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** Paste the `git status --porcelain` output
into your report; if it lists anything this task did not touch, say so and leave it unstaged.

---

### Task 2: A set key is never touched, and the command says what it did

**Story:** S-02, S-05
**Files:**
- Modify: `bin/keel`
- Test: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `profile_sync()` from task 1. This task adds the `filled` report and the skip guard's
  test; the `filled` counter already exists and is currently unused.

**Depends on:** task 1

**Done when:** `tests/test-keel.sh` prints `PASS  sync leaves a key that is already set` and
`PASS  a second sync run changes nothing` and reports `0 failed`, then `tests/run-tests.sh` prints
`All test files passed`.

- [x] **Step 1: Write the failing test**

Append after task 1's cases:

```bash
# S-02, FR-02. The map is documented as the user's override for a document that lives elsewhere.
# A command that means to help must not discard a deliberate value, so a key that already holds one
# is skipped even when the default is sitting there too.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
root="$(prof_of "$d" docs_root)"
mkdir -p "$d/wiki"; printf 'x\n' > "$d/wiki/overview.md"
printf 'x\n' > "$d/$root/snapshot.md"
( cd "$d" && "$KEEL" profile set artifacts.snapshot wiki/overview.md >/dev/null 2>&1 )
( cd "$d" && "$KEEL" profile sync >/dev/null 2>&1 )
got="$(prof_of "$d" artifacts.snapshot)"
[ "$got" = "wiki/overview.md" ] && ok "sync leaves a key that is already set" \
  || bad "profile sync" "sync overwrote a deliberate override with '$got'"
rm -rf "$d"

# S-02, FR-07. Idempotent, asserted byte for byte. A second run that rewrites the same values
# through a JSON dump can still reorder or reformat, and on a tracked file that is a spurious diff
# somebody has to read. "No key changed" is the weaker claim and it is not the one that matters.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
root="$(prof_of "$d" docs_root)"
mkdir -p "$d/$root/plans"; printf 'x\n' > "$d/$root/plans/2026-01-01-x.md"
( cd "$d" && "$KEEL" profile sync >/dev/null 2>&1 )
before="$(cat "$d/.keel/profile.json")"
out="$( cd "$d" && "$KEEL" profile sync 2>&1 )"
after="$(cat "$d/.keel/profile.json")"
[ "$before" = "$after" ] && ok "a second sync run changes nothing" \
  || bad "profile sync" "a second run rewrote .keel/profile.json"
case "$out" in
  *"no artifact key changed"*) ok "sync says so when it changed nothing" ;;
  *) bad "profile sync" "a no-op run said nothing useful: '$out'" ;;
esac
rm -rf "$d"

# S-05, FR-16. Filling nothing is the correct outcome on a repository already in order, and a
# non-zero exit there would fail a pre-push hook for a state that is fine.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
( cd "$d" && "$KEEL" profile sync >/dev/null 2>&1 ) \
  && ok "sync exits 0 when it fills nothing" \
  || bad "profile sync" "sync exited non-zero on a repository with nothing to fill"
rm -rf "$d"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: `FAIL  profile sync: a no-op run said nothing useful: ''`. The override and idempotence
cases pass already, because task 1's `continue` guard covers both; **that is expected and is not a
reason to skip them.** They pin behaviour that a later edit to the guard would silently remove, and
step 3 changes only the reporting.

- [x] **Step 3: Write the minimal implementation**

In `profile_sync`, replace `return 0` with:

```bash
    [ "$filled" -eq 0 ] && say "  no artifact key changed"
    return 0
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on all four new cases, `0 failed`.
Then `tests/run-tests.sh`. Expected: `All test files passed`.

- [x] **Step 5: Hand over**

```bash
git add bin/keel tests/test-keel.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.**

---

### Task 3: Only the exact default counts

**Story:** S-03, S-07
**Files:**
- Modify: `bin/keel`
- Test: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `profile_sync()` from task 1.
- Produces: the skip line naming `prd`, `stories` and `architecture`.

**Depends on:** task 1

**Done when:** `tests/test-keel.sh` prints `PASS  sync says why it skips prd, stories and
architecture` and `PASS  a monorepo leaves snapshot null` and reports `0 failed`, then
`tests/run-tests.sh` prints `All test files passed`.

- [x] **Step 1: Write the failing test**

```bash
# S-03, FR-04. prd, stories and architecture default to one file per slug, so a repository with
# five PRDs has no single path to record. Skipping them silently reads as a bug, so the command
# says which it skipped and why.
#
# The one-PRD case is the one that fails quietly. A repository with exactly one PRD looks fillable,
# and filling it would be right today and wrong the moment a second PRD is written: the rule is
# about the shape of the default, not about how many documents happen to be there.
for n in 5 1; do
    d="$(fixture node-ts)"
    ( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
    root="$(prof_of "$d" docs_root)"
    mkdir -p "$d/$root/prd"
    i=0; while [ "$i" -lt "$n" ]; do printf 'x\n' > "$d/$root/prd/p$i.md"; i=$((i+1)); done
    out="$( cd "$d" && "$KEEL" profile sync 2>&1 )"
    got="$(prof_of "$d" artifacts.prd)"
    [ "$got" = "None" ] && ok "sync leaves prd null with $n PRD(s) present" \
      || bad "profile sync" "sync filled artifacts.prd with '$got' from $n file(s)"
    case "$out" in
      *prd*stories*architecture*) ok "sync says why it skips prd, stories and architecture" ;;
      *) bad "profile sync" "sync skipped three keys and said nothing: '$out'" ;;
    esac
    rm -rf "$d"
done

# S-07, FR-13. repo-snapshot emits snapshot-<unit>.md per unit in a monorepo and the key is a single
# string, so it cannot hold them and stays null. The second case is what stops a naive glob:
# `snapshot*.md` would match the per-unit files and pick one.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
root="$(prof_of "$d" docs_root)"
printf 'x\n' > "$d/$root/snapshot-api.md"; printf 'x\n' > "$d/$root/snapshot-web.md"
( cd "$d" && "$KEEL" profile sync >/dev/null 2>&1 )
got="$(prof_of "$d" artifacts.snapshot)"
[ "$got" = "None" ] && ok "a monorepo leaves snapshot null" \
  || bad "profile sync" "per-unit snapshots filled artifacts.snapshot with '$got'"
printf 'x\n' > "$d/$root/snapshot.md"
( cd "$d" && "$KEEL" profile sync >/dev/null 2>&1 )
got="$(prof_of "$d" artifacts.snapshot)"
[ "$got" = "$root/snapshot.md" ] && ok "a root snapshot beside per-unit ones is still recorded" \
  || bad "profile sync" "got '$got', want '$root/snapshot.md'"
rm -rf "$d"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: `FAIL  profile sync: sync skipped three keys and said nothing: ''`, twice. The monorepo
cases pass already, because task 1 tests `[ -f "$root/snapshot.md" ]` and matches nothing else.
**Keep them.** They are what stops a later "improvement" to a glob, which is the specific edit this
requirement exists to prevent.

- [x] **Step 3: Write the minimal implementation**

In `profile_sync`, immediately before the final `return 0`:

```bash
    # Said every run, filled or not. These three default to <docs_root>/<key>/<slug>.md, one file
    # per slug, so there is no single path a string key could hold. Silence here reads as an
    # oversight and gets reported as a bug against a decision. FR-04.
    say "  prd, stories and architecture are skipped: each defaults to one file per slug under $root, so there is no single path to record"
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on all six new cases, `0 failed`.
Then `tests/run-tests.sh`. Expected: `All test files passed`.

Task 2's no-op case also still passes: its assertion is on `no artifact key changed`, which is a
separate line from the skip line added here.

- [x] **Step 5: Hand over**

```bash
git add bin/keel tests/test-keel.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.**

---

### Task 4: An empty directory does not count as present

**Story:** S-04
**Files:**
- Test: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `dir_has_file` from task 1.

**Depends on:** task 1

**Done when:** `tests/test-keel.sh` prints `PASS  an empty docs directory leaves its key null` and
reports `0 failed`, then `tests/run-tests.sh` prints `All test files passed`.

**This task is test-only, and that is deliberate.** `dir_has_file` was written in task 1 because
`profile_sync` calls it there. FR-06 is `confirmed, was author-added`: nobody asked for it, Bernard
kept it on 2026-08-30, and this task is the cheapest thing to delete if the rule is ever reversed.
Keeping the rule's assertions in their own task is what makes that true.

- [x] **Step 1: Write the failing test**

```bash
# S-04, FR-06. An empty docs/decisions means the project has no decision records. Setting the key
# would be literally true, useless to every reader, and would silence task 6's warning for a
# directory with nothing in it.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
root="$(prof_of "$d" docs_root)"
mkdir -p "$d/$root/decisions"
( cd "$d" && "$KEEL" profile sync >/dev/null 2>&1 )
got="$(prof_of "$d" artifacts.decisions)"
[ "$got" = "None" ] && ok "an empty docs directory leaves its key null" \
  || bad "profile sync" "an empty decisions directory was recorded as '$got'"

# keel init scaffolds decisions/ADR-0000-template.md, so this directory is never empty on a fresh
# project. Counting the template would set the key and warn on every newly initialised repository
# before anyone had written a decision. Found by prototyping, 2026-08-30, and FR-06 amended for it.
printf 'x\n' > "$d/$root/decisions/ADR-0000-template.md"
( cd "$d" && "$KEEL" profile sync >/dev/null 2>&1 )
got="$(prof_of "$d" artifacts.decisions)"
[ "$got" = "None" ] && ok "a directory holding only keel's own template leaves its key null" \
  || bad "profile sync" "the scaffolded ADR template was counted as a document: '$got'"

# A directory kept in git by a lone .gitkeep is still empty of documents.
printf '' > "$d/$root/decisions/.gitkeep"
( cd "$d" && "$KEEL" profile sync >/dev/null 2>&1 )
got="$(prof_of "$d" artifacts.decisions)"
[ "$got" = "None" ] && ok "a directory holding only .gitkeep leaves its key null" \
  || bad "profile sync" "a .gitkeep-only directory was recorded as '$got'"

printf 'x\n' > "$d/$root/decisions/ADR-0001-x.md"
( cd "$d" && "$KEEL" profile sync >/dev/null 2>&1 )
got="$(prof_of "$d" artifacts.decisions)"
[ "$got" = "$root/decisions" ] && ok "one document is enough to record the directory" \
  || bad "profile sync" "got '$got', want '$root/decisions'"
rm -rf "$d"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: **all four pass on the first run**, because task 1 implemented `dir_has_file` to make
`profile_sync` work at all.

**This is the TDD exception, and it is taken out loud rather than silently.** These are `verify`
assertions for behaviour written one task earlier, not `build`. To confirm they can fail rather than
assuming it, break the rule and watch: temporarily change `dir_has_file`'s body to `[ -d "$1" ]`,
run `tests/test-keel.sh`, confirm the first three cases FAIL, then restore it. Record in the handover
that you did this and what you saw. An assertion never seen red is an assertion that proves nothing,
and here the only way to see it red is to make it so.

- [x] **Step 3: Write the minimal implementation**

None. `dir_has_file` from task 1 already satisfies FR-06. Do not add code; if step 2's break-and-
restore did not produce the two expected failures, stop and report, because the helper is not doing
what this task claims it does.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on all four, `0 failed`, with `dir_has_file` restored.
Then `tests/run-tests.sh`. Expected: `All test files passed`.

- [x] **Step 5: Hand over**

```bash
git add tests/test-keel.sh
git status --porcelain
```

Stage exactly that path and stop. **Do not commit.** `bin/keel` must be unchanged by this task; if
`git status --porcelain` lists it, the restore in step 2 was incomplete.

---

### Task 5: `sync` refuses where `get` and `set` already do

**Story:** S-06
**Files:**
- Modify: `bin/keel`
- Test: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `cmd_profile`'s existing guards at `bin/keel:1019-1020`.

**Depends on:** task 1

**Done when:** `tests/test-keel.sh` prints `PASS  profile sync refuses without a profile` and
`PASS  an unknown profile subcommand names sync` and reports `0 failed`, then `tests/run-tests.sh`
prints `All test files passed`.

- [x] **Step 1: Write the failing test**

```bash
# S-06, FR-14. cmd_profile already refuses both cases for get and set, and sync inherits them by
# entering through the same function. This is the assertion proving it, so that a later refactor
# that gives sync its own entry point is caught rather than shipped.
d="$(mktemp -d)"
out="$( cd "$d" && "$KEEL" profile sync 2>&1 )"
case "$out" in
  *"Run 'keel init'"*) ok "profile sync refuses without a profile" ;;
  *) bad "profile sync" "no profile gave '$out', want the shared 'Run keel init' refusal" ;;
esac
rm -rf "$d"

# FR-01. A subcommand whose own sibling error message denies it exists is not beside get and set.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
out="$( cd "$d" && "$KEEL" profile frobnicate 2>&1 )"
case "$out" in
  *get*set*sync*) ok "an unknown profile subcommand names sync" ;;
  *) bad "profile sync" "the unknown-subcommand message does not name sync: '$out'" ;;
esac
rm -rf "$d"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: `FAIL  profile sync: the unknown-subcommand message does not name sync: keel: unknown
profile subcommand 'frobnicate'. Try get or set.` The first case passes already, for the reason its
own comment gives.

- [x] **Step 3: Write the minimal implementation**

At `bin/keel:1027`, change the message:

```bash
      *)   die "unknown profile subcommand '${1:-}'. Try get, set or sync." ;;
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on both, `0 failed`.
Then `tests/run-tests.sh`. Expected: `All test files passed`.

- [x] **Step 5: Hand over**

```bash
git add bin/keel tests/test-keel.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.**

---

### Task 6: doctor reports a fillable null key

**Story:** S-08
**Files:**
- Modify: `bin/keel`
- Test: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `dir_has_file` from task 1, `docs_root()`, and `cmd_doctor`'s local `root` already set
  at `bin/keel:1276`.
- Produces: nothing other tasks consume.

**Depends on:** task 1

**Done when:** `tests/test-keel.sh` prints `PASS  doctor names profile sync for a fillable null key`
and `PASS  keel doctor starts python3 at most 10 times` and reports `0 failed`, then
`tests/run-tests.sh` prints `All test files passed`.

**The interpreter budget is the risk in this task.** `tests/test-keel.sh:1189` caps doctor at 10
python3 starts and it currently uses 7, measured 2026-08-30. The loop below adds none, because
`json_get` answers a null key from `json_load`'s flat cache. Step 4 re-reads that existing
assertion's output rather than trusting the reasoning.

- [x] **Step 1: Write the failing test**

```bash
# S-08, FR-10, FR-11, NFR-03. A null key whose default is present means the profile does not know
# about a document sitting in docs_root. A warning and never a failure, because nothing is broken
# and the remedy is one command. Shape follows the stack.has_ui warning at bin/keel:1390.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
root="$(prof_of "$d" docs_root)"
mkdir -p "$d/$root/plans" "$d/$root/prd"
printf 'x\n' > "$d/$root/plans/2026-01-01-x.md"
printf 'x\n' > "$d/$root/prd/p0.md"
out="$( cd "$d" && "$KEEL" doctor 2>&1 )"
case "$out" in
  *"artifacts.plans"*"keel profile sync"*) ok "doctor names profile sync for a fillable null key" ;;
  *) bad "doctor" "no sync warning for a null artifacts.plans beside $root/plans" ;;
esac
# FR-11. prd has no remedy under FR-04, so naming one would send people to a command that
# deliberately does nothing for them. This is the assertion that keeps the warning honest.
case "$out" in
  *artifacts.prd*) bad "doctor" "doctor warned about artifacts.prd, which sync will not fill" ;;
  *) ok "doctor says nothing about a key sync cannot fill" ;;
esac
# FR-10. A warning, never a failure. Nothing here is broken.
case "$out" in
  *"FAIL"*"artifacts.plans"*) bad "doctor" "the sync nudge was raised as a failure, not a warning" ;;
  *) ok "the sync nudge is a warning, not a failure" ;;
esac
# NFR-03. --fast is where most people will meet it, so it has to be reached there too.
out="$( cd "$d" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"keel profile sync"*) ok "doctor --fast reports it too" ;;
  *) bad "doctor" "--fast did not print the sync warning" ;;
esac
rm -rf "$d"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: `FAIL  doctor: no sync warning for a null artifacts.plans beside docs/keel/plans` and
`FAIL  doctor: --fast did not print the sync warning`. The two negative cases pass already; keep
them, since they are what a later broadening of the loop would break.

- [x] **Step 3: Write the minimal implementation**

In `cmd_doctor`, immediately after the existing artifacts loop's closing `fi` (after
`bin/keel:1343`):

```bash
    # The other half of the map: a key that is null while its default is sitting there. The profile
    # does not know about a document the repository has, and a skill reading the map gets the
    # fallback. A warning and never a failure, because nothing is broken.
    #
    # The same three keys `profile sync` fills, and no more. prd, stories and architecture default
    # to one file per slug, so sync will not fill them by decision, and naming a remedy that does
    # nothing for them is worse than saying nothing. FR-10, FR-11.
    #
    # json_get answers from json_load's flat cache, where a null renders as an empty string, so this
    # loop adds no interpreter start to the budget asserted in tests/test-keel.sh:1189.
    if have_python; then
        local akey apath
        for akey in snapshot decisions plans; do
            [ -n "$(json_get .keel/profile.json "artifacts.$akey" 2>/dev/null || true)" ] && continue
            case "$akey" in
              snapshot) apath="$root/snapshot.md"; [ -f "$apath" ] || continue ;;
              *)        apath="$root/$akey"; dir_has_file "$apath" || continue ;;
            esac
            warn "artifacts.$akey is null but '$apath' exists, so the profile does not know about it. Record it with: keel profile sync"
        done
    fi
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on all four new cases, `0 failed`.

**Then read the interpreter budget case's own output in that same run**, which prints the count:
`PASS  keel doctor starts python3 at most 10 times (7)`. If the number rose above 7, the loop is
starting an interpreter and the reasoning above is wrong; stop and report rather than raising the
cap.

Then `tests/run-tests.sh`. Expected: `All test files passed`.

- [x] **Step 5: Hand over**

```bash
git add bin/keel tests/test-keel.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** Report the interpreter count you read.

---

### Task 7: Discovery, `--help` and the documents

**Story:** S-09
**Files:**
- Modify: `bin/keel`
- Modify: `docs/03-install-and-distribution.md`
- Modify: `CHANGELOG.md`
- Test: `tests/test-keel.sh`

**Interfaces:**
- Consumes: nothing. This task adds no behaviour beyond one help line.

**Depends on:** task 1

**Done when:** `tests/test-keel.sh` prints `PASS  keel --help names profile sync` and reports
`0 failed`, then `tests/run-tests.sh` prints `All test files passed`.

- [x] **Step 1: Write the failing test**

```bash
# S-09, FR-12. Without this the command is discoverable only from doctor's warning, which a user
# reaches only if their tree already has the gap it solves.
out="$( "$KEEL" --help 2>&1 )"
case "$out" in
  *"profile get|set|sync"*) ok "keel --help names profile sync" ;;
  *) bad "help" "the profile line in --help does not name sync" ;;
esac
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: `FAIL  help: the profile line in --help does not name sync`.

- [x] **Step 3: Write the minimal implementation**

At `bin/keel:1881`:

```bash
        say "  profile get|set|sync <dotted.path> [value]   read or correct one profile field, or record where this project's documents are"
```

Then in `docs/03-install-and-distribution.md`, extend the block at lines 366-367:

```
keel profile get <dotted.path>
keel profile set <dotted.path> <value>
keel profile sync
```

and add this paragraph after the one that ends "`keel_version` and `schema_version` are refused
too: `init` owns both.":

> `sync` is the same map filled from the other direction. It records where this project's documents
> already are, for the three artifact keys whose default is one unambiguous location: `snapshot`,
> `decisions` and `plans`. A key that already holds a value is never touched, since that value is
> the override the map exists for, and a directory with nothing in it is not a document set. `prd`,
> `stories` and `architecture` are deliberately never filled: each defaults to one file per slug, so
> a repository with five PRDs has no single path a string key could hold. `keel doctor` warns when a
> fillable key is null and its documents are there, which is how anyone finds out the command
> exists.

Then add a `CHANGELOG.md` entry under `## Unreleased`.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS, `0 failed`.
Then `tests/run-tests.sh`. Expected: `All test files passed`. `tests/test-doc-claims.sh` asserts
countable claims in `README.md`; this task changes no count there, and a green run is the check.

- [x] **Step 5: Hand over**

```bash
git add bin/keel docs/03-install-and-distribution.md CHANGELOG.md tests/test-keel.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.**

---

## Story coverage

| Story | Task | Kind |
|---|---|---|
| S-01 | 1 | build |
| S-02 | 2 | build |
| S-03 | 3 | build |
| S-04 | 4 | build, delivered as verify. See the task's own note |
| S-05 | 2 | build |
| S-06 | 5 | verify |
| S-07 | 3 | build |
| S-08 | 6 | build |
| S-09 | 7 | build |

All nine stories map to a task. No task exists that no story asked for.

## What prototyping this plan changed

Task 1 and task 6 were prototyped against a scratch copy of `bin/keel` on 2026-08-30, then the
prototype was deleted. Three things came out of it that reading alone had not:

- **`keel init` scaffolds `<docs_root>/decisions/ADR-0000-template.md`.** FR-06 as approved counted
  any file, so a freshly initialised project would have had `artifacts.decisions` set to a directory
  holding a template and a standing doctor warning from the first run. FR-06 was amended the same
  day, asked as a choice, and `dir_has_file` skips the template by name. Verified after the fix: a
  fresh init reports `no artifact key changed` and doctor is silent, and writing one real ADR fills
  the key.
- **`profile_set`'s closing four lines are textually identical to the verify setter's below it**, so
  the insertion anchor in task 1 had to become the comment above them.
- **The interpreter budget holds.** Doctor with task 6's loop started python3 7 times, the same as
  without it, against a cap of 10.

The prototype also confirmed the whole of task 1 end to end: three keys filled, three left null, a
second run byte-identical, and the skip line printed.

## What this plan does not settle

**The story document's open question 2, whether `sync` needs its own fixture.** Answered here by
not adding one: every task reuses the existing `node-ts` fixture and creates the documents it needs
inside it, because what is under test is the profile and the directory tree, not the stack. A new
fixture would be a third copy of `keel init` for no extra coverage.

**S-01's trailing-slash choice is now pinned in code as well as in the story.** A directory key is
written as `<root>/decisions`, no trailing slash. Doctor's `[ -e "$path" ]` accepts either.

**`snapshot` will not be filled on this repository**, because `docs/snapshot.md` does not exist
here. Running `keel profile sync` on keel itself after this lands fills `decisions` and `plans` and
reports the other four. That is the PRD's success metric and it is worth running once as the
acceptance check, but it is not a task, because the command's correctness does not depend on this
repository's contents.
