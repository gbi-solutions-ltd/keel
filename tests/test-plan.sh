#!/usr/bin/env bash
# Tests for `keel plan status`, `keel plan tick`, `keel plan report`, `keel plan risk` and
# `keel plan batches`. Run from the repository root.
#
# Every case writes its own plan into a temporary directory. The one case that reads a committed
# plan, one written before step ids existed, only reads it.
#
# The `condition && ok || bad` idiom is safe here, and only here, because both helpers return 0.
# shellcheck disable=SC2015
# Single quotes are deliberate throughout: the fixtures are literal markdown, backticks included.
# shellcheck disable=SC2016
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEEL="$ROOT/bin/keel"
pass=0
fail=0

ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }

d="$(mktemp -d)"

# mkplan <file> <line>...: a plan holding a heading and then the given lines, one per argument.
mkplan() {
    local f="$1"; shift
    { printf '# A plan\n\n### Task 1: a task\n\n'; printf '%s\n' "$@"; } > "$f"
}

# ---- status: counts per task, and the next open step ----------------------------------------

p="$d/counts.md"
mkplan "$p" \
  '- [x] **Step 1.1: Write the failing test**' \
  '- [x] **Step 1.2: Run it and watch it fail**' \
  '- [ ] **Step 1.3: Write the minimal implementation**' \
  '- [ ] **Step 2.1: Write the failing test**' \
  '- [ ] **Step 2.2: Run it and watch it fail**'
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
want="$(printf '%s\n' \
  'task 1: 2 done, 1 open, 0 deferred, 0 not applicable' \
  'task 2: 0 done, 2 open, 0 deferred, 0 not applicable' \
  'next: 1.3')"
[ "$rc" -eq 0 ] && [ "$out" = "$want" ] \
  && ok "status counts each task's steps and names the first open one" \
  || bad "status counts" "rc=$rc, got: $out"

p="$d/all-done.md"
mkplan "$p" '- [x] **Step 1.1: Write the failing test**' '- [X] **Step 1.2: Run it and watch it fail**'
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | tail -1)" = "next: none" ] \
  && case "$out" in *"task 1: 2 done, 0 open"*) true ;; *) false ;; esac \
  && ok "status says no step is open when every step is done, [X] included" \
  || bad "status all done" "rc=$rc, got: $out"

p="$d/parked.md"
mkplan "$p" \
  '- [x] **Step 1.1: a**' \
  '- [-] **Step 1.2: b** Deferred: moved to the follow-up plan' \
  '- [~] **Step 1.3: c** Not applicable: no behaviour to test' \
  '- [ ] **Step 1.4: d**'
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
case "$out" in
  *"task 1: 1 done, 1 open, 1 deferred, 1 not applicable"*) ok "status counts deferred and not-applicable steps apart" ;;
  *) bad "status parked" "rc=$rc, got: $out" ;;
esac

# A step inside a fenced code block is an example, as the template's own are. The ```` fence holds
# a ``` one, which must not close it, and an indented fence follows. The last lines pin a fence
# closed by a CRLF line and an inline span of backticks at the start of a line, neither of which
# may hide a step.
p="$d/fenced.md"
mkplan "$p" \
  '- [ ] **Step 1.1: a**' \
  '````markdown' \
  '- [ ] **Step 9.1: an example inside a fence**' \
  '```bash' \
  '- [x] **Step 9.2: still inside the outer fence**' \
  '```' \
  '- [ ] **Step 9.9: after the inner example, still inside**' \
  '````' \
  '   ```bash' \
  '- [ ] **Step 9.3: inside an indented fence**' \
  '   ```' \
  '- [x] **Step 1.2: b**' \
  '```bash' \
  '- [ ] **Step 9.4: inside a fence whose closing line ends in CR**' \
  $'```\r' \
  '```` ```bash ```` is inline code at the start of a line, not a fence' \
  '- [x] **Step 1.3: counted after both**'
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
want="$(printf '%s\n' 'task 1: 2 done, 1 open, 0 deferred, 0 not applicable' 'next: 1.1')"
[ "$rc" -eq 0 ] && [ "$out" = "$want" ] && ok "status never counts a step inside a fenced code block" \
  || bad "status fenced" "rc=$rc, got: $out"

# A fence may open on a list item's line, as CommonMark allows. Missed, its indented closing line
# would open a phantom fence that hides every step up to the next bare ```, the open one included.
p="$d/list-fence.md"
mkplan "$p" \
  '- [x] **Step 1.1: a**' \
  '1. ```bash' \
  '   tests/run-tests.sh' \
  '   ```' \
  '- [ ] **Step 1.2: b**' \
  '```bash' \
  'tests/test-plan.sh' \
  '```' \
  '- [x] **Step 1.3: c**'
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
want="$(printf '%s\n' 'task 1: 2 done, 1 open, 0 deferred, 0 not applicable' 'next: 1.2')"
[ "$rc" -eq 0 ] && [ "$out" = "$want" ] && ok "status sees a fence opened on a list item's line" \
  || bad "status list-item fence" "rc=$rc, got: $out"
out="$("$KEEL" plan tick "$p" 1.2 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && grep -qxF -e '- [x] **Step 1.2: b**' "$p" \
  && ok "tick finds a step after a fence opened on a list item's line" \
  || bad "tick list-item fence" "rc=$rc out=$out"

# A fence opened in a list item closes when the item ends, as CommonMark has it, so one never
# closed does not swallow the steps after its item.
p="$d/list-fence-open.md"
mkplan "$p" \
  '- [x] **Step 1.1: a**' \
  '- ``` opens a fence, as CommonMark has it' \
  '- [ ] **Step 1.2: b**' \
  '```bash' \
  'x' \
  '```' \
  '- [x] **Step 1.3: c**'
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
want="$(printf '%s\n' 'task 1: 2 done, 1 open, 0 deferred, 0 not applicable' 'next: 1.2')"
[ "$rc" -eq 0 ] && [ "$out" = "$want" ] && ok "a fence opened in a list item closes when the item ends" \
  || bad "status list-item fence left open" "rc=$rc, got: $out"

# Only a list item ends the item early: a closing fence indented less than the item's content, at
# column 0 or after a tab, still closes the fence, rather than opening a new one that hides steps.
p="$d/list-fence-col0.md"
mkplan "$p" '- [x] **Step 1.1: a**' '- ```bash' '  x' '```' '- [ ] **Step 1.2: b**' \
  '```bash' 'y' '```' '- [x] **Step 1.3: c**'
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "$want" ] \
  && ok "a list item's fence closed at column 0 hides no step" \
  || bad "status list-item fence closed at column 0" "rc=$rc, got: $out"

p="$d/list-fence-tab.md"
mkplan "$p" '- [x] **Step 1.1: a**' '1. ```bash' $'\tx' $'\t```' '- [ ] **Step 1.2: b**' \
  '```bash' 'y' '```' '- [x] **Step 1.3: c**'
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "$want" ] \
  && ok "a list item's fence closed after a tab hides no step" \
  || bad "status list-item fence closed after a tab" "rc=$rc, got: $out"

# Indentation is compared in columns, a tab reaching the next multiple of four, as CommonMark
# counts it. A box indented by a tab inside a fence opened at `- ` is four columns in, past the
# item's content at two, so it is content, not an open box; counted as one character, it ended the
# fence and read as one. After `-<TAB>` the item's content starts at column four, so a box indented
# two spaces ends the item and its fence and is an open box status must show; counted in
# characters, the content started at two and the box was hidden in the fence, which the next step
# then ended.
p="$d/list-fence-tabbox.md"
mkplan "$p" '- [x] **Step 1.1: a**' '- ```markdown' $'\t- [ ] an example box' '  ```' \
  '- [ ] **Step 1.2: b**'
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
want="$(printf '%s\n' 'task 1: 1 done, 1 open, 0 deferred, 0 not applicable' 'next: 1.2')"
[ "$rc" -eq 0 ] && [ "$out" = "$want" ] \
  && ok "a box indented by a tab inside a list item's fence is content, counted in columns" \
  || bad "status list-item fence tab content" "rc=$rc, got: $out"
p="$d/list-fence-tabmark.md"
mkplan "$p" '- [x] **Step 1.1: a**' $'-\t```markdown' '  - [ ] an open box' \
  '- [ ] **Step 1.2: b**'
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
want="$(printf '%s\n' 'task 1: 1 done, 1 open, 0 deferred, 0 not applicable' 'next: 1.2' \
  'problem: line 7 is an open checkbox that is not a step keel can read')"
[ "$rc" -eq 1 ] && [ "$out" = "$want" ] \
  && ok "a fence opened after a marker and a tab ends with its item, counted in columns" \
  || bad "status list-item fence after a marker tab" "rc=$rc, got: $out"

# itemfence_plan <file> <b|c>: three tasks, task 2 depending on task 1 and sharing src/b.js with
# task 3. Task 1 holds a fence opened on its own indented line inside a list item: in b, an example
# whose inner fences sit at the outer fence's indent, so its last ``` opens a new fence; in c, a
# fence with no closer.
itemfence_plan() {
    { printf '%s\n' '# P' '' '### Task 1: one' '' '**Files:**' '- Create: `src/a.js`' '' \
        '**Depends on:** none' '' '**Done when:** x' '' '- [ ] **Step 1.1: Write it**' ''
      if [ "$2" = b ]; then
          printf '%s\n' '2. **Write the final step as a commit.** Like this:' '' '   ```markdown' \
            '   - [ ] **Step 1.5: Commit**' '' '   You are in your own worktree.' '' '   ```bash' \
            '   git add src/format.js test/format.test.js' \
            '   git commit -m "feat(format): normalise whitespace"' '   ```' '   ```' '' \
            '- [ ] **Step 1.2: more**' ''
      else
          printf '%s\n' '  ```bash' '  make' ''
      fi
      printf '%s\n' '### Task 2: two' '' '**Files:**' '- Modify: `src/b.js`' '' \
        '**Depends on:** task 1' '' '**Done when:** x' '' '- [ ] **Step 2.1: do**' '' \
        '```bash' 'make' '```' '' '### Task 3: three' '' '**Files:**' '- Modify: `src/b.js`' '' \
        '**Depends on:** none' '' '**Done when:** x' '' '- [ ] **Step 3.1: do**'; } > "$1"
}

# A fence opened on its own indented line inside a list item belongs to the item, as CommonMark has
# it: it closes on a closer at most three columns past the item's content, and one left open ends
# where the item does, at a non-blank line indented less than the item's content. Read otherwise,
# the example's last ``` (b) or the missing closer (c) opened a fence that hid task 2 and its open
# step from status, and so from ship's gate.
for v in b c; do
    p="$d/itemfence-$v.md"
    itemfence_plan "$p" "$v"
    out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
    n1=1; [ "$v" = b ] && n1=2
    want="$(printf '%s\n' "task 1: 0 done, $n1 open, 0 deferred, 0 not applicable" \
      'task 2: 0 done, 1 open, 0 deferred, 0 not applicable' \
      'task 3: 0 done, 1 open, 0 deferred, 0 not applicable' 'next: 1.1')"
    [ "$rc" -eq 0 ] && [ "$out" = "$want" ] \
      && ok "status lists every task after a fence opened inside a list item ($v)" \
      || bad "status item fence $v" "rc=$rc, got: $out"
done

# fence4_plan <file>: three tasks, the first holding the template's nested-fence example, a fenced
# step whose own fence is indented six columns inside a fence indented two.
fence4_plan() {
    printf '%s\n' '# P' '' '### Task 1: a' '' '**Depends on:** none' '**Files:**' \
      '- Modify: `a.sh`' '' '**Done when:** x' '' \
      '- [ ] **Step 1.1: Write the step form.** A step with a command looks like:' '' \
      '  ```markdown' '  - [ ] **Step 9.1: Run it**' '' '      ```bash' '      bin/x' '      ```' \
      '  ```' '' '### Task 2: b' '' '**Depends on:** task 1' '**Files:**' '- Modify: `c.sh`' '' \
      '**Done when:** x' '' '- [ ] **Step 2.1: Run**' '' '  ```bash' '  make' '  ```' '' \
      '### Task 3: c' '' '**Depends on:** none' '**Files:**' '- Modify: `c.sh`' '' \
      '**Done when:** x' '' '- [ ] **Step 3.1: do**' > "$1"
}
# icb_plan <file>: four tasks, the first holding an indented code block whose first line is ```.
# Indented four columns, that line is code, not a fence, so the bare ``` after task 3 opens one
# and the next closes it.
icb_plan() {
    printf '%s\n' '# P' '' '### Task 1: t' '' '**Depends on:** none' '**Files:**' \
      '- Modify: `a.sh`' '' \
      '**Done when:** x' '' '- [ ] **Step 1.1: do**' '' 'Example:' '' '    ```' '    x' '' \
      '### Task 2: t' '' '**Depends on:** task 1' '**Files:**' '- Modify: `c.sh`' '' \
      '**Done when:** x' '' '- [ ] **Step 2.1: do**' '' \
      '### Task 3: t' '' '**Depends on:** none' '**Files:**' '- Modify: `c.sh`' '' \
      '**Done when:** x' '' '- [ ] **Step 3.1: do**' '' '```' 'y' '```' \
      '### Task 4: t' '' '**Depends on:** none' '**Files:**' '- Modify: `e.sh`' '' \
      '**Done when:** x' '' '- [ ] **Step 4.1: do**' > "$1"
}

# closer4_plan <file>: three tasks, the first holding a fence outside any list item whose content
# is a line of three backticks indented four spaces, then the real closer; task 2 holds a later
# fence, and task 3 follows it, depending on nothing and sharing c.sh with task 2.
closer4_plan() {
    printf '%s\n' '# P' '' '### Task 1: t' '' '**Depends on:** none' '**Files:**' \
      '- Modify: `a.sh`' '' '**Done when:** x' '' 'Example:' '' '```' 'x' '    ```' '```' '' \
      '- [ ] **Step 1.1: do**' '' \
      '### Task 2: t' '' '**Depends on:** task 1' '**Files:**' '- Modify: `c.sh`' '' \
      '**Done when:** x' '' '- [ ] **Step 2.1: do**' '' '```' 'make' '```' '' \
      '### Task 3: t' '' '**Depends on:** none' '**Files:**' '- Modify: `c.sh`' '' \
      '**Done when:** x' '' '- [ ] **Step 3.1: do**' > "$1"
}

# A fence opens only when indented at most three columns, and closes only on the same character,
# at least as long, indented at most three columns past the item it opened in, as CommonMark has
# it. A fence line indented further inside an open fence is content: read as a closer, the outer
# closer then opened a phantom fence that hid task 2 and its open step from status, and so from
# ship's gate, which reads status.
p="$d/fence4.md"
fence4_plan "$p"
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
want="$(printf '%s\n' 'task 1: 0 done, 1 open, 0 deferred, 0 not applicable' \
  'task 2: 0 done, 1 open, 0 deferred, 0 not applicable' \
  'task 3: 0 done, 1 open, 0 deferred, 0 not applicable' 'next: 1.1')"
[ "$rc" -eq 0 ] && [ "$out" = "$want" ] \
  && ok "status lists a task after a fence nested four columns deep, with its open step" \
  || bad "status nested fence" "rc=$rc, got: $out"
out="$("$KEEL" plan tick "$p" 2.1 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && grep -qxF -e '- [x] **Step 2.1: Run**' "$p" \
  && ok "tick finds a step after a fence nested four columns deep" \
  || bad "tick nested fence" "rc=$rc out=$out"
p="$d/icb.md"
icb_plan "$p"
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
want="$(printf '%s\n' 'task 1: 0 done, 1 open, 0 deferred, 0 not applicable' \
  'task 2: 0 done, 1 open, 0 deferred, 0 not applicable' \
  'task 3: 0 done, 1 open, 0 deferred, 0 not applicable' \
  'task 4: 0 done, 1 open, 0 deferred, 0 not applicable' 'next: 1.1')"
[ "$rc" -eq 0 ] && [ "$out" = "$want" ] \
  && ok "status reads a fence line indented four columns as code, not a fence" \
  || bad "status indented code block" "rc=$rc, got: $out"
# Outside a list item a fence closes only on a closer indented at most three columns, so a ``` four
# spaces in is content. Read as the closer, the real closer would open a fence, the later fence's
# closer another that never closes, and task 3 and its open step would be hidden.
p="$d/closer4.md"
closer4_plan "$p"
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
want="$(printf '%s\n' 'task 1: 0 done, 1 open, 0 deferred, 0 not applicable' \
  'task 2: 0 done, 1 open, 0 deferred, 0 not applicable' \
  'task 3: 0 done, 1 open, 0 deferred, 0 not applicable' 'next: 1.1')"
[ "$rc" -eq 0 ] && [ "$out" = "$want" ] \
  && ok "status reads a closer indented four columns outside a list item as content" \
  || bad "status closer indented four" "rc=$rc, got: $out"

# NFR-01: under a second on the largest plan shape, about 35,000 words over 2,000 lines.
p="$d/large.md"
{
    printf '# A large plan\n\n'
    t=1
    while [ "$t" -le 40 ]; do
        printf '### Task %s: a task\n\n' "$t"
        s=1
        while [ "$s" -le 5 ]; do
            printf -- '- [ ] **Step %s.%s: a step**\n\n' "$t" "$s"
            i=1
            while [ "$i" -le 9 ]; do
                printf 'Prose standing in for the code and the reasoning a real step carries, at about the density of these plans.\n'
                i=$((i+1))
            done
            printf '\n'
            s=$((s+1))
        done
        printf '```bash\n- [ ] **Step 99.1: inside a fence**\n```\n\n'
        t=$((t+1))
    done
} > "$p"
lines="$(wc -l < "$p" | tr -d ' ')"; words="$(wc -w < "$p" | tr -d ' ')"
secs="$(python3 -c 'import subprocess, sys, time
t = time.time()
subprocess.run(sys.argv[1:], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
print("%.3f" % (time.time() - t))' "$KEEL" plan status "$p")"
last="$("$KEEL" plan status "$p" 2>&1 | tail -1)"
[ "$lines" -ge 2000 ] && [ "$words" -ge 35000 ] && [ "$last" = "next: 1.1" ] \
  && awk -v s="$secs" 'BEGIN { exit !(s < 1) }' \
  && ok "status reads a $lines-line, $words-word plan in ${secs}s" \
  || bad "status speed" "lines=$lines words=$words secs=$secs last=$last"

# Captured before matching: `keel --help | grep -q` fails under pipefail when grep exits early.
help="$("$KEEL" --help 2>&1)"
case "$help" in
  *'plan status <plan>'*) ok "keel --help lists plan status" ;;
  *) bad "help" "keel --help does not list 'plan status <plan>'" ;;
esac

# ---- status: a parked step needs its reason, and an id names one step ------------------------

p="$d/no-reason.md"
mkplan "$p" '- [x] **Step 2.1: a**' '- [ ] **Step 2.2: b**' '- [-] **Step 2.3: c** Deferred: ' \
  '- [-] **Step 2.4: d** Deferred: '$'\t''later'
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] \
  && case "$out" in *"problem: step 2.3 is deferred with no reason"*"problem: step 2.4 is deferred with no reason"*) true ;; *) false ;; esac \
  && ok "status names a deferred step with no reason and exits non-zero" \
  || bad "status deferred no reason" "rc=$rc, got: $out"

p="$d/na-no-reason.md"
mkplan "$p" '- [~] **Step 1.4: d** Not applicable: '
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"problem: step 1.4 is not applicable with no reason"*) true ;; *) false ;; esac \
  && ok "status names a not-applicable step whose reason is empty and exits non-zero" \
  || bad "status not applicable no reason" "rc=$rc, got: $out"

p="$d/reasons.md"
mkplan "$p" \
  '- [-] **Step 1.1: a** Deferred: moved to the follow-up plan' \
  '- [~] **Step 1.2: b** Not applicable: no behaviour to test'
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && case "$out" in *problem*) false ;; *) true ;; esac \
  && ok "status accepts parked steps that carry their reasons" \
  || bad "status reasons" "rc=$rc, got: $out"

p="$d/repeat.md"
mkplan "$p" '- [ ] **Step 1.1: a**' '- [ ] **Step 1.1: a again**'
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"problem: step 1.1 appears more than once"*) true ;; *) false ;; esac \
  && ok "status names an id that appears twice and exits non-zero" \
  || bad "status repeated id" "rc=$rc, got: $out"

# An open checkbox the parser cannot read as a step would be invisible to status, and ship's gate
# reads status: an old-style box and an indented step are both open work. mkplan's header is four
# lines, so the boxes are lines 6 to 11. GFM renders `*`, `+` and numbered task items as checkboxes
# too, and a box inside a quote is still one.
p="$d/unreadable.md"
mkplan "$p" '- [x] **Step 1.1: a**' '- [ ] **Finding 1: an old-style box**' '   - [ ] **Step 1.2: indented**' \
  '* [ ] **Step 1.3: a star bullet**' '+ [ ] **Step 1.4: a plus bullet**' \
  '1. [ ] **Step 1.5: a numbered item**' '> - [ ] **Step 1.6: inside a quote**'
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] \
  && case "$out" in *"problem: line 6 is an open checkbox"*"problem: line 7 is an open checkbox"*"problem: line 8 is an open checkbox"*"problem: line 9 is an open checkbox"*"problem: line 10 is an open checkbox"*"problem: line 11 is an open checkbox"*) true ;; *) false ;; esac \
  && ok "status names each open checkbox it cannot read as a step and exits non-zero" \
  || bad "status unreadable checkbox" "rc=$rc, got: $out"

# A fence that never closes hides every step after it, so status would read an unfinished plan as
# done. It is named as a problem, with the line it opened on.
p="$d/unclosed.md"
mkplan "$p" '- [x] **Step 1.1: a**' '```bash' '- [ ] **Step 1.2: hidden**'
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"problem: line 6 opens a fence that never closes"*) true ;; *) false ;; esac \
  && ok "status names a fence that never closes and exits non-zero" \
  || bad "status unclosed fence" "rc=$rc, got: $out"

# ---- tick: one step, and only its line --------------------------------------------------------

p="$d/tick.md"
mkplan "$p" '- [x] **Step 1b.1: Write the failing test**' '- [ ] **Step 1b.2: Run it and watch it fail**' \
  '- [ ] **Step 1b.3: Write the minimal implementation**'
cp "$p" "$d/tick.before"
out="$("$KEEL" plan tick "$p" 1b.2 2>&1)"; rc=$?
want="$(sed 's/^- \[ \] \*\*Step 1b\.2: /- [x] **Step 1b.2: /' "$d/tick.before")"
[ "$rc" -eq 0 ] && [ "$(cat "$p")" = "$want" ] \
  && ok "tick marks one step done and changes no other line" \
  || bad "tick" "rc=$rc out=$out, plan now: $(cat "$p")"

p="$d/note.md"
mkplan "$p" '- [ ] **Step 3.1: Write the failing test**'
"$KEEL" plan tick "$p" 3.1 --note 'file already on disk on arrival, \t kept literally' >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && grep -qxF -e '- [x] **Step 3.1: Write the failing test** Note: file already on disk on arrival, \t kept literally' "$p" \
  && ok "tick --note writes the note after the step's title, backslashes untouched" \
  || bad "tick --note" "rc=$rc, plan now: $(cat "$p")"

p="$d/missing.md"
mkplan "$p" '- [ ] **Step 1.1: a**'
cp "$p" "$d/missing.before"
out="$("$KEEL" plan tick "$p" 9.9 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && cmp -s "$p" "$d/missing.before" && case "$out" in *"no step 9.9"*) true ;; *) false ;; esac \
  && ok "tick on an id the plan does not hold changes nothing and names it" \
  || bad "tick missing id" "rc=$rc out=$out"

p="$d/again.md"
mkplan "$p" '- [x] **Step 1.1: a** Note: seen in the log'
cp "$p" "$d/again.before"
"$KEEL" plan tick "$p" 1.1 >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && cmp -s "$p" "$d/again.before" \
  && ok "tick on a step already done leaves it done, once, its note kept" \
  || bad "tick again" "rc=$rc, plan now: $(cat "$p")"

p="$d/twice.md"
mkplan "$p" '- [ ] **Step 1.1: a**' '- [ ] **Step 1.1: a again**'
cp "$p" "$d/twice.before"
out="$("$KEEL" plan tick "$p" 1.1 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && cmp -s "$p" "$d/twice.before" && case "$out" in *"appears more than once"*) true ;; *) false ;; esac \
  && ok "tick refuses an id that names two steps" \
  || bad "tick repeated id" "rc=$rc out=$out"

p="$d/newline.md"
mkplan "$p" '- [ ] **Step 1.1: a**'
cp "$p" "$d/newline.before"
"$KEEL" plan tick "$p" 1.1 --note "$(printf 'two\nlines')" >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && cmp -s "$p" "$d/newline.before" \
  && ok "tick refuses a note holding a newline, which would split the step's line" \
  || bad "tick newline note" "rc=$rc, plan now: $(cat "$p")"

help="$("$KEEL" --help 2>&1)"
case "$help" in
  *'plan tick <plan> <id>'*) ok "keel --help lists plan tick" ;;
  *) bad "help" "keel --help does not list 'plan tick <plan> <id>'" ;;
esac

# A tick that cannot write the plan must fail: reporting success would leave the step unticked while
# the caller moves on. Root can write a read-only file, so the case is skipped there.
if [ "$(id -u)" -eq 0 ]; then
  printf '  SKIP  %s\n' "tick on a plan it cannot write exits non-zero and leaves it as it was (root)"
else
  p="$d/readonly.md"
  mkplan "$p" '- [ ] **Step 1.1: a**'
  cp "$p" "$d/readonly.before"
  chmod 444 "$p"; "$KEEL" plan tick "$p" 1.1 >/dev/null 2>&1; rc=$?; chmod 644 "$p"
  [ "$rc" -ne 0 ] && cmp -s "$p" "$d/readonly.before" \
    && ok "tick on a plan it cannot write exits non-zero and leaves it as it was" \
    || bad "tick read-only plan" "rc=$rc, plan now: $(cat "$p")"
fi

# A CRLF plan keeps its line endings: the note goes before the line's CR, or the CR would sit in the
# middle of the line and the note would follow it.
p="$d/crlf.md"
printf '# A plan\r\n\r\n### Task 1: a task\r\n\r\n- [ ] **Step 1.1: a**\r\n' > "$p"
"$KEEL" plan tick "$p" 1.1 --note 'seen' >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && [ "$(grep -cxF -e "- [x] **Step 1.1: a** Note: seen$(printf '\r')" "$p")" -eq 1 ] \
  && ok "tick on a CRLF plan keeps the note before the line's CR" \
  || bad "tick CRLF plan" "rc=$rc, plan now: $(od -c "$p")"

# A step inside a fenced block is an example, never a step, so tick passes over it: ticking it
# would rewrite the example, and counting it would make the real step's id look repeated.
p="$d/fenced.md"
mkplan "$p" '- [ ] **Step 1.1: real**' '```markdown' '- [ ] **Step 1.1: an example**' '```'
"$KEEL" plan tick "$p" 1.1 >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && grep -qxF -e '- [x] **Step 1.1: real**' "$p" \
  && grep -qxF -e '- [ ] **Step 1.1: an example**' "$p" \
  && ok "tick never ticks a step inside a fenced example" \
  || bad "tick fenced example" "rc=$rc, plan now: $(cat "$p")"

# ---- tick: park a step, only with its reason --------------------------------------------------

p="$d/defer.md"
mkplan "$p" '- [ ] **Step 6.2: Commit**'
"$KEEL" plan tick "$p" 6.2 --defer 'moved to the follow-up plan' >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && grep -qxF -e '- [-] **Step 6.2: Commit** Deferred: moved to the follow-up plan' "$p" \
  && ok "tick --defer parks the step with its reason" \
  || bad "tick --defer" "rc=$rc, plan now: $(cat "$p")"

p="$d/na.md"
mkplan "$p" '- [ ] **Step 4.2: Run it and watch it fail**'
"$KEEL" plan tick "$p" 4.2 --not-applicable 'no behaviour to test' >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && grep -qxF -e '- [~] **Step 4.2: Run it and watch it fail** Not applicable: no behaviour to test' "$p" \
  && ok "tick --not-applicable parks the step with its reason" \
  || bad "tick --not-applicable" "rc=$rc, plan now: $(cat "$p")"

p="$d/defer-bare.md"
mkplan "$p" '- [ ] **Step 6.2: Commit**'
cp "$p" "$d/defer-bare.before"
out="$("$KEEL" plan tick "$p" 6.2 --defer 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && cmp -s "$p" "$d/defer-bare.before" && case "$out" in *"a reason is required"*) true ;; *) false ;; esac \
  && ok "tick --defer with no reason changes nothing and says one is required" \
  || bad "tick --defer bare" "rc=$rc out=$out"

p="$d/undefer.md"
mkplan "$p" '- [-] **Step 6.2: Commit** Deferred: moved to the follow-up plan'
"$KEEL" plan tick "$p" 6.2 >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && grep -qxF -e '- [x] **Step 6.2: Commit**' "$p" \
  && ok "ticking a deferred step done drops its deferral reason" \
  || bad "tick undefer" "rc=$rc, plan now: $(cat "$p")"

# A reason that starts with a blank is refused, since status reads it as no reason: tick must not
# write a line that status then flags.
p="$d/defer-blank.md"
mkplan "$p" '- [ ] **Step 6.2: Commit**'
cp "$p" "$d/defer-blank.before"
out="$("$KEEL" plan tick "$p" 6.2 --defer ' ' 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && cmp -s "$p" "$d/defer-blank.before" && case "$out" in *"a reason is required"*) true ;; *) false ;; esac \
  && ok "tick --defer with a reason that is only a space changes nothing and says one is required" \
  || bad "tick --defer blank" "rc=$rc out=$out"

# A not-applicable step needs its reason as much as a deferred one: without it, it reads as
# forgotten.
p="$d/na-bare.md"
mkplan "$p" '- [ ] **Step 4.2: Run it and watch it fail**'
cp "$p" "$d/na-bare.before"
out="$("$KEEL" plan tick "$p" 4.2 --not-applicable 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && cmp -s "$p" "$d/na-bare.before" && case "$out" in *"a reason is required"*) true ;; *) false ;; esac \
  && ok "tick --not-applicable with no reason changes nothing and says one is required" \
  || bad "tick --not-applicable bare" "rc=$rc out=$out"

# Ticking a not-applicable step done drops its reason, as for a deferred one: the reason no longer
# describes a step that was done.
p="$d/un-na.md"
mkplan "$p" '- [~] **Step 4.2: Run it and watch it fail** Not applicable: no behaviour to test'
"$KEEL" plan tick "$p" 4.2 >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && grep -qxF -e '- [x] **Step 4.2: Run it and watch it fail**' "$p" \
  && ok "ticking a not-applicable step done drops its reason" \
  || bad "tick un-not-applicable" "rc=$rc, plan now: $(cat "$p")"

# Parking replaces anything after the title, a note included: the note described the step as done,
# which it no longer is.
p="$d/park-note.md"
mkplan "$p" '- [x] **Step 3.1: a** Note: file was on disk'
"$KEEL" plan tick "$p" 3.1 --defer 'moved to the follow-up plan' >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && grep -qxF -e '- [-] **Step 3.1: a** Deferred: moved to the follow-up plan' "$p" \
  && ok "parking a step replaces its note with the reason" \
  || bad "tick park over note" "rc=$rc, plan now: $(cat "$p")"

# A title may hold `**`, as a glob does: the title ends at the `**` that ends the line or opens a
# note or reason, or parking would rewrite the rest of the title as if it were a tail.
p="$d/glob-title.md"
mkplan "$p" '- [ ] **Step 1.1: Run `**/*.md` glob**'
"$KEEL" plan tick "$p" 1.1 --defer later >/dev/null 2>&1; rc=$?
out="$("$KEEL" plan status "$p" 2>&1)"; src=$?
[ "$rc" -eq 0 ] && [ "$src" -eq 0 ] \
  && grep -qxF -e '- [-] **Step 1.1: Run `**/*.md` glob** Deferred: later' "$p" \
  && ok "parking a step whose title holds ** keeps the whole title" \
  || bad "tick park glob title" "rc=$rc status rc=$src out=$out, plan now: $(cat "$p")"

p="$d/glob-note.md"
mkplan "$p" '- [ ] **Step 1.1: Run `**/*.md` glob**'
"$KEEL" plan tick "$p" 1.1 --note seen >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && grep -qxF -e '- [x] **Step 1.1: Run `**/*.md` glob** Note: seen' "$p" \
  && ok "a done tick with a note on a title that holds ** keeps the whole title" \
  || bad "tick note glob title" "rc=$rc, plan now: $(cat "$p")"

# A tail that opens no note or reason still ends the title at the first **, so a parked step whose
# reason lacks its prefix stays a step and is flagged, rather than vanishing from the gate.
p="$d/bad-tail.md"
mkplan "$p" '- [x] **Step 1.1: a**' '- [-] **Step 1.2: b** moved to later' \
  '- [x] **Step 1.3: c** (seen)'
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
[ "$rc" -eq 1 ] \
  && case "$out" in *"problem: step 1.2 is deferred with no reason"*) true ;; *) false ;; esac \
  && ok "status flags a parked step whose tail is not a reason" \
  || bad "status bad tail" "rc=$rc, got: $out"

# ---- a plan without step ids --------------------------------------------------------------------

# A committed plan written before the ids, read only.
old="$ROOT/docs/plans/2026-09-27-push-scan-reads-pushed-commits.md"
out="$("$KEEL" plan status "$old" 2>&1)"; rc=$?
[ "$rc" -eq 3 ] && case "$out" in *unaddressable*) true ;; *) false ;; esac \
  && ok "status reports a plan without step ids as unaddressable, exit 3" \
  || bad "status unaddressable" "rc=$rc, got: $out"

p="$d/old.md"
mkplan "$p" '- [ ] **Step 1: Write the failing test**' '- [ ] **Step 2: Run it and watch it fail**'
cp "$p" "$d/old.before"
out="$("$KEEL" plan tick "$p" 1.1 2>&1)"; rc=$?
[ "$rc" -eq 3 ] && cmp -s "$p" "$d/old.before" && case "$out" in *unaddressable*) true ;; *) false ;; esac \
  && ok "tick on a plan without step ids changes nothing, says so, and exits 3" \
  || bad "tick unaddressable" "rc=$rc out=$out"

# An unclosed fence hides the steps after it, so the plan is reported for its fence, not as id-less:
# calling it id-less sends the reader to hand-check lines that render as a code block.
p="$d/unclosed-only.md"
printf '# P\n\n```bash\n- [ ] **Step 1.1: a**\n' > "$p"
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && case "$out" in *"problem: line 3 opens a fence that never closes"*) true ;; *) false ;; esac \
  && case "$out" in *unaddressable*) false ;; *) true ;; esac \
  && ok "status on a plan whose only step follows an unclosed fence reports the fence, exit 1" \
  || bad "status unclosed fence, no steps" "rc=$rc, got: $out"

# Tick on the same plan names the fence too, for the same reason, and changes nothing.
cp "$p" "$d/unclosed-only.before"
out="$("$KEEL" plan tick "$p" 1.1 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && cmp -s "$p" "$d/unclosed-only.before" \
  && case "$out" in *"fence that never closes"*) true ;; *) false ;; esac \
  && case "$out" in *unaddressable*) false ;; *) true ;; esac \
  && ok "tick on a plan whose only step follows an unclosed fence changes nothing and names it" \
  || bad "tick unclosed fence, no steps" "rc=$rc out=$out"

# ---- tick: concurrent ticks all land ------------------------------------------------------------

# Twenty ticks on one plan, started together. Without a lock each reads the plan before the others
# write it and most ticks are lost: 3, 9 and 6 of 20 landed in three runs while planning.
p="$d/batch.md"
{ printf '# A plan\n\n'; i=1; while [ "$i" -le 20 ]; do printf -- '- [ ] **Step 1.%s: a step**\n' "$i"; i=$((i+1)); done; } > "$p"
i=1
while [ "$i" -le 20 ]; do "$KEEL" plan tick "$p" "1.$i" >/dev/null 2>&1 & i=$((i+1)); done
wait
n="$(grep -c '^- \[x\] \*\*Step 1\.' "$p")"
[ "$n" -eq 20 ] && [ ! -e "$p.lock" ] \
  && ok "twenty ticks started together all land, and the lock is gone after" \
  || bad "concurrent ticks" "$n of 20 landed; lock left: $([ -e "$p.lock" ] && echo yes || echo no)"

# A lock left by a killed tick: the tick waits, then names the lock and changes nothing.
p="$d/stale.md"
mkplan "$p" '- [ ] **Step 1.1: a**'
cp "$p" "$d/stale.before"
mkdir "$p.lock"
out="$("$KEEL" plan tick "$p" 1.1 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && cmp -s "$p" "$d/stale.before" && case "$out" in *"$p.lock"*) true ;; *) false ;; esac \
  && ok "tick facing a held lock gives up naming it, and changes nothing" \
  || bad "stale lock" "rc=$rc out=$out"
rmdir "$p.lock"

# A lock that cannot be created is not a lock that is held: waiting ten seconds and then blaming a
# killed tick sends the reader after a lock that does not exist. Root can write any directory.
if [ "$(id -u)" -eq 0 ]; then
  printf '  SKIP  %s\n' "tick that cannot create its lock fails at once, saying so (root)"
else
  mkdir "$d/rodir"
  p="$d/rodir/plan.md"
  mkplan "$p" '- [ ] **Step 1.1: a**'
  cp "$p" "$d/rodir.before"
  chmod 555 "$d/rodir"
  SECONDS=0
  out="$("$KEEL" plan tick "$p" 1.1 2>&1)"; rc=$?
  secs=$SECONDS
  chmod 755 "$d/rodir"
  [ "$rc" -ne 0 ] && cmp -s "$p" "$d/rodir.before" && [ "$secs" -lt 5 ] \
    && case "$out" in *"cannot create"*) true ;; *) false ;; esac \
    && case "$out" in *"is held"*) false ;; *) true ;; esac \
    && ok "tick that cannot create its lock fails at once, saying so" \
    || bad "lock cannot be created" "rc=$rc secs=$secs out=$out"
fi

# A tick removes only the lock it holds: once released, another tick may hold it. A shim rmdir has
# another holder take the lock right after the tick's own release, so a second rmdir would show.
shim="$d/shim"
mkdir "$shim"
printf '%s\n' '#!/bin/sh' '"$KEEL_TEST_RMDIR" "$@" || exit $?' '[ -e "$KEEL_TEST_MARK" ] && exit 0' \
  ': > "$KEEL_TEST_MARK"' 'mkdir "$1"' > "$shim/rmdir"
chmod 755 "$shim/rmdir"
real_rmdir="$(command -v rmdir)"
p="$d/relock.md"
mkplan "$p" '- [ ] **Step 1.1: a**'
PATH="$shim:$PATH" KEEL_TEST_RMDIR="$real_rmdir" KEEL_TEST_MARK="$d/mark" \
  "$KEEL" plan tick "$p" 1.1 >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && grep -qxF -e '- [x] **Step 1.1: a**' "$p" && [ -d "$p.lock" ] \
  && ok "a tick removes only the lock it holds" \
  || bad "tick removes only its lock" "rc=$rc, lock left: $([ -d "$p.lock" ] && echo yes || echo no)"
rmdir "$p.lock" 2>/dev/null

# ---- tick: a failed write never costs the plan --------------------------------------------------

# Busybox awk exits 0 on a write that failed for a full disk, leaving the temporary copy empty or
# short. A shim awk does that for the tick's program only, which alone reads PLAN_ID, so copying
# that back would empty the plan.
shim="$d/shim-awk"
mkdir "$shim"
printf '%s\n' '#!/bin/sh' 'for a in "$@"; do case "$a" in *PLAN_ID*) exit 0 ;; esac; done' \
  'exec "$KEEL_TEST_AWK" "$@"' > "$shim/awk"
chmod 755 "$shim/awk"
real_awk="$(command -v awk)"
p="$d/short.md"
mkplan "$p" '- [ ] **Step 1.1: a**'
cp "$p" "$d/short.before"
out="$(PATH="$shim:$PATH" KEEL_TEST_AWK="$real_awk" "$KEEL" plan tick "$p" 1.1 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && cmp -s "$p" "$d/short.before" \
  && case "$out" in *"came out incomplete"*) true ;; *) false ;; esac \
  && ok "tick whose ticked copy comes out incomplete leaves the plan as it was" \
  || bad "tick incomplete copy" "rc=$rc out=$out, plan now: $(cat "$p")"

# A copy back that fails has already truncated the plan, so the ticked copy is the only complete one
# and is kept. A shim cat exits 1 without writing. It fails every call, because the copy back is the
# only cat a tick runs. macOS mktemp ignores TMPDIR, so the kept copy is found from the message and
# removed after, wherever it is.
shim="$d/shim-cat"
mkdir "$shim" "$d/tmpdir"
printf '%s\n' '#!/bin/sh' 'exit 1' > "$shim/cat"
chmod 755 "$shim/cat"
p="$d/nocopy.md"
mkplan "$p" '- [ ] **Step 1.1: a**'
out="$(PATH="$shim:$PATH" TMPDIR="$d/tmpdir" "$KEEL" plan tick "$p" 1.1 2>&1)"; rc=$?
kept="${out##*kept at }"
[ "$rc" -eq 1 ] && case "$out" in *"ticked copy is kept at /"*) true ;; *) false ;; esac \
  && [ -f "$kept" ] && grep -qxF -e '- [x] **Step 1.1: a**' "$kept" && [ ! -e "$p.lock" ] \
  && ok "tick whose copy back fails keeps the ticked copy, names it, and releases the lock" \
  || bad "tick failed copy back" \
       "rc=$rc out=$out, lock left: $([ -e "$p.lock" ] && echo yes || echo no)"
case "$kept" in /*) rm -f "$kept" ;; esac

# ---- report: lead time and rework from git ------------------------------------------------------

# rrepo <dir>: an empty repository, as tests/test-keel.sh builds them.
rrepo() {
    mkdir -p "$1"
    ( cd "$1" && git init -q -b main . && git config user.email t@t.t && git config user.name t ) \
      || bad "fixture repository" "could not create $1"
}

# rcommit <repo> <author date> <title> [<body>]: commits the tree as it stands. The committer date
# is fixed and unlike every author date, so a report that read the committer time, which a rebase
# rewrites, would print the wrong time. An empty commit is allowed, for a rework that edits no plan.
# A commit that fails is a FAIL of its own, so a fixture that did not build cannot pass by luck.
rcommit() {
    local r="$1" when="$2"
    ( cd "$r" && git add . \
      && GIT_AUTHOR_DATE="$when" GIT_COMMITTER_DATE="2026-11-01T00:00:00+0000" \
         git commit -q --allow-empty -m "$3" ${4:+-m "$4"} ) \
      || { bad "fixture commit" "git add or commit failed in $r for: $3"; return 1; }
}

# rgit <repo> <author date> <git args>...: any other history-building git command, with the same
# dates and the same loudness, for branches and merges.
rgit() {
    local r="$1" when="$2"; shift 2
    ( cd "$r" && GIT_AUTHOR_DATE="$when" GIT_COMMITTER_DATE="2026-11-01T00:00:00+0000" git "$@" >/dev/null ) \
      || bad "fixture git" "git $* failed in $r"
}

# jget <json> <python expression over d>: one value out of a report's JSON.
jget() { printf '%s' "$1" | python3 -c 'import json, sys; d = json.load(sys.stdin); print('"$2"')' 2>&1; }

r="$d/rrepo"; rrepo "$r"; mkdir -p "$r/docs/plans"; p="$r/docs/plans/p.md"
printf '%s\n' '# A plan' '' '**Implementer routing:** keel-implementer' '' '### Task 1: a' '' \
  '- [ ] **Step 1.1: a**' '- [ ] **Step 1.2: b**' '' '### Task 2: c' '' '- [ ] **Step 2.1: c**' > "$p"
rcommit "$r" "2026-10-16T09:00:00+0000" "docs(plans): add p"
"$KEEL" plan tick "$p" 1.1 --note 'rounds: 1; routing: keel-implementer (by hand)' >/dev/null
rcommit "$r" "2026-10-16T10:00:00+0000" "tick 1.1"
"$KEEL" plan tick "$p" 1.2 --note 'rounds: 2; routing: keel-implementer' >/dev/null
rcommit "$r" "2026-10-16T10:30:00+0000" "tick 1.2"

# An uncommitted tick: the report reads the committed copy only.
"$KEEL" plan tick "$p" 2.1 >/dev/null
out="$("$KEEL" plan report "$p" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -qxF 'planned: 2026-10-16T09:00:00Z' \
  && ok "report prints planned as the author time of the commit that added the plan" \
  || bad "report planned" "rc=$rc, got: $out"
printf '%s\n' "$out" | grep -qF 'task 1: done 2026-10-16T10:30:00Z' \
  && ok "report prints a task's time as the author time of its last closing commit" \
  || bad "report task time" "got: $out"
printf '%s\n' "$out" | grep -qxF 'task 1: done 2026-10-16T10:30:00Z, rounds 2, routing keel-implementer' \
  && ok "report takes the last rounds and the last routing from the task's done steps" \
  || bad "report rounds and routing" "got: $out"
printf '%s\n' "$out" | grep -qxF 'task 2: open' \
  && ok "report prints a task with an open step as open, an uncommitted tick unread" \
  || bad "report open task" "got: $out"
printf '%s\n' "$out" | grep -qxF 'delivered: not yet' && printf '%s\n' "$out" | grep -qxF 'lead time: not yet' \
  && ok "report prints delivered and lead time as not yet while a step is open" \
  || bad "report not delivered" "got: $out"
printf '%s\n' "$out" | grep -qxF 'planned routing: keel-implementer' \
  && ok "report prints the plan's Implementer routing header" \
  || bad "report planned routing" "got: $out"
printf '%s\n' "$out" | grep -qxF 'rework: 0' \
  && ok "report prints rework: 0 when no commit reworks the plan" \
  || bad "report rework none" "got: $out"

js="$("$KEEL" plan report "$p" --json 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$js" | python3 -m json.tool >/dev/null 2>&1 \
  && [ "$(jget "$js" 'd["delivered"], d["lead_time_hours"], d["tasks"][1]["done"], d["tasks"][1]["rounds"], d["tasks"][1]["routing"]')" = "None None None None None" ] \
  && ok "report --json is valid JSON and holds null where the text says not yet or unknown" \
  || bad "report json nulls" "rc=$rc, got: $js"

# The same plan from a subdirectory by a relative path.
sub="$( cd "$r/docs" && "$KEEL" plan report plans/p.md 2>&1 )"
[ "$sub" = "$out" ] \
  && ok "report run from a subdirectory with a relative path reports the same" \
  || bad "report subdirectory" "got: $sub"

# Committed, the tick shows, and the lead time is delivered minus planned: 09:00 to 13:20.
rcommit "$r" "2026-10-16T13:20:00+0000" "tick 2.1"
out="$("$KEEL" plan report "$p" 2>&1)"; rc=$?
printf '%s\n' "$out" | grep -qxF 'task 2: done 2026-10-16T13:20:00Z, rounds unknown, routing unknown' \
  && ok "report prints rounds unknown and routing unknown for a task whose notes hold neither" \
  || bad "report unknown" "rc=$rc, got: $out"
printf '%s\n' "$out" | grep -qxF 'delivered: 2026-10-16T13:20:00Z' \
  && ok "report prints delivered as the latest task time once every step is closed" \
  || bad "report delivered" "got: $out"
printf '%s\n' "$out" | grep -qxF 'lead time: 4.3h' \
  && ok "report prints lead time in hours to one decimal" \
  || bad "report lead time" "got: $out"
js="$("$KEEL" plan report "$p" --json 2>&1)"
[ "$(jget "$js" 'd["delivered"], d["lead_time_hours"], d["tasks"][0]["rounds"], d["tasks"][0]["routing"], d["tasks"][1]["routing"]')" = "2026-10-16T13:20:00Z 4.3 2 keel-implementer None" ] \
  && ok "report --json carries the same facts as the text" \
  || bad "report json facts" "got: $js"

# Rework: a commit reachable from HEAD with the line `Reworks <plan path>`, root-relative.
rcommit "$r" "2026-10-17T09:00:00+0000" "fix: first" "Reworks docs/plans/p.md"; h1="$(git -C "$r" rev-parse --short HEAD)"
rcommit "$r" "2026-10-17T10:00:00+0000" "fix: other plan" "Reworks docs/plans/other.md"
rcommit "$r" "2026-10-17T11:00:00+0000" "fix: second" "A line before it.

Reworks docs/plans/p.md
A line after it."; h2="$(git -C "$r" rev-parse --short HEAD)"
rcommit "$r" "2026-10-17T12:00:00+0000" "fix: prefix only" "Reworks docs/plans/p.md.bak"
out="$("$KEEL" plan report "$p" 2>&1)"
printf '%s\n' "$out" | grep -qxF "rework: 2 ($h2 $h1)" \
  && ok "report counts the commits that rework this plan, with their hashes, and no other plan's" \
  || bad "report rework" "want rework: 2 ($h2 $h1), got: $out"
# Commits after the last tick that leave the plan alone, two or more in a row, move no time.
printf '%s\n' "$out" | grep -qxF 'task 2: done 2026-10-16T13:20:00Z, rounds unknown, routing unknown' \
  && printf '%s\n' "$out" | grep -qxF 'delivered: 2026-10-16T13:20:00Z' \
  && printf '%s\n' "$out" | grep -qxF 'lead time: 4.3h' \
  && ok "report keeps its times when later commits leave the plan alone" \
  || bad "report later commits" "got: $out"
js="$("$KEEL" plan report "$p" --json 2>&1)"
[ "$(jget "$js" 'd["rework"]["count"], " ".join(d["rework"]["commits"])')" = "2 $h2 $h1" ] \
  && ok "report --json carries the rework count and hashes" \
  || bad "report json rework" "got: $js"

# A plan without the header is planned at inherit.
r2="$d/rrepo2"; rrepo "$r2"; p2="$r2/plan.md"
mkplan "$p2" '- [x] **Step 1.1: a**' '- [x] **Step 1.2: b**'
rcommit "$r2" "2026-10-16T09:00:00+0000" "add"
out="$("$KEEL" plan report "$p2" 2>&1)"; rc=$?
printf '%s\n' "$out" | grep -qxF 'planned routing: inherit (not stated)' \
  && ok "report prints inherit (not stated) when the plan names no routing" \
  || bad "report no routing" "rc=$rc, got: $out"
# A step closed in the commit that adds the plan is closed at that commit.
printf '%s\n' "$out" | grep -qxF 'task 1: done 2026-10-16T09:00:00Z, rounds unknown, routing unknown' \
  && printf '%s\n' "$out" | grep -qxF 'lead time: 0.0h' \
  && ok "report counts a step closed in the adding commit as closed at that commit" \
  || bad "report closed on add" "got: $out"

# Deferred and not-applicable steps leave open as a done one does.
r3="$d/rrepo3"; rrepo "$r3"; p3="$r3/plan.md"
mkplan "$p3" '- [ ] **Step 1.1: a**' '- [ ] **Step 1.2: b**'
rcommit "$r3" "2026-10-16T09:00:00+0000" "add"
"$KEEL" plan tick "$p3" 1.1 --defer 'moved on' >/dev/null
rcommit "$r3" "2026-10-16T10:00:00+0000" "defer 1.1"
"$KEEL" plan tick "$p3" 1.2 --not-applicable 'nothing to test' >/dev/null
rcommit "$r3" "2026-10-16T11:00:00+0000" "park 1.2"
out="$("$KEEL" plan report "$p3" 2>&1)"
printf '%s\n' "$out" | grep -qxF 'delivered: 2026-10-16T11:00:00Z' \
  && ok "report counts a deferred or not-applicable step as closed" \
  || bad "report parked steps" "got: $out"

# A step closed, reopened and closed again counts from the last close.
r4="$d/rrepo4"; rrepo "$r4"; p4="$r4/plan.md"
mkplan "$p4" '- [ ] **Step 1.1: a**'
rcommit "$r4" "2026-10-16T09:00:00+0000" "add"
"$KEEL" plan tick "$p4" 1.1 >/dev/null
rcommit "$r4" "2026-10-16T10:00:00+0000" "close"
sed 's/^- \[x\]/- [ ]/' "$p4" > "$p4.new" && mv "$p4.new" "$p4"
rcommit "$r4" "2026-10-16T11:00:00+0000" "reopen"
"$KEEL" plan tick "$p4" 1.1 >/dev/null
rcommit "$r4" "2026-10-16T12:00:00+0000" "close again"
out="$("$KEEL" plan report "$p4" 2>&1)"
printf '%s\n' "$out" | grep -qF 'task 1: done 2026-10-16T12:00:00Z' \
  && ok "report dates a task from the last time its step left open, not the first" \
  || bad "report reopened step" "got: $out"

# Renames are not followed: the plan is planned when it appeared under its present name.
( cd "$r4" && git mv plan.md renamed.md )
rcommit "$r4" "2026-10-16T15:00:00+0000" "rename"
out="$("$KEEL" plan report "$r4/renamed.md" 2>&1)"
printf '%s\n' "$out" | grep -qxF 'planned: 2026-10-16T15:00:00Z' \
  && ok "report does not follow a rename: planned is when the present name appeared" \
  || bad "report rename" "got: $out"

# Errors: a missing file, a plan without step ids, and a plan with no history.
out="$("$KEEL" plan report "$d/absent.md" 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && case "$out" in *"$d/absent.md"*) true ;; *) false ;; esac \
  && ok "report on a missing file exits 1 naming it" \
  || bad "report missing" "rc=$rc, got: $out"

r5="$d/rrepo5"; rrepo "$r5"; p5="$r5/old.md"
mkplan "$p5" '- [ ] **Step 1: Write the failing test**'
rcommit "$r5" "2026-10-16T09:00:00+0000" "add"
out="$("$KEEL" plan report "$p5" 2>&1)"; rc=$?
[ "$rc" -eq 3 ] && case "$out" in *unaddressable*) true ;; *) false ;; esac \
  && ok "report on a plan without step ids exits 3" \
  || bad "report unaddressable" "rc=$rc, got: $out"

mkplan "$r5/new.md" '- [ ] **Step 1.1: a**'
out="$("$KEEL" plan report "$r5/new.md" 2>&1)"; rc=$?
[ "$rc" -eq 4 ] && case "$out" in *"no history yet"*) true ;; *) false ;; esac \
  && ok "report on a plan that is not committed exits 4, saying it has no history yet" \
  || bad "report uncommitted" "rc=$rc, got: $out"
( cd "$r5" && git add new.md )
out="$("$KEEL" plan report "$r5/new.md" 2>&1)"; rc=$?
[ "$rc" -eq 4 ] && case "$out" in *"no history yet"*) true ;; *) false ;; esac \
  && ok "report on a plan that is staged but not committed exits 4" \
  || bad "report staged only" "rc=$rc, got: $out"

# Parallel worktrees merged back: a task closes where its step closed, not where the merge landed.
r6="$d/rrepo6"; rrepo "$r6"; p6="$r6/plan.md"
printf '%s\n' '# A plan' '' '### Task 1: a' '' '- [ ] **Step 1.1: a**' '' '### Task 2: b' '' '- [ ] **Step 2.1: b**' > "$p6"
rcommit "$r6" "2026-10-16T09:00:00+0000" "add"
rgit "$r6" "2026-10-16T09:00:00+0000" checkout -q -b a
"$KEEL" plan tick "$p6" 1.1 >/dev/null
rcommit "$r6" "2026-10-16T10:00:00+0000" "tick 1.1 on a"
rgit "$r6" "2026-10-16T10:00:00+0000" checkout -q main
rgit "$r6" "2026-10-16T10:00:00+0000" checkout -q -b b
"$KEEL" plan tick "$p6" 2.1 >/dev/null
rcommit "$r6" "2026-10-16T11:00:00+0000" "tick 2.1 on b"
rgit "$r6" "2026-10-16T11:00:00+0000" checkout -q main
rgit "$r6" "2026-10-16T15:00:00+0000" merge -q --no-ff -m "merge a and b" a b
out="$("$KEEL" plan report "$p6" 2>&1)"
printf '%s\n' "$out" | grep -qxF 'planned: 2026-10-16T09:00:00Z' \
  && printf '%s\n' "$out" | grep -qF 'task 1: done 2026-10-16T10:00:00Z' \
  && printf '%s\n' "$out" | grep -qF 'task 2: done 2026-10-16T11:00:00Z' \
  && printf '%s\n' "$out" | grep -qxF 'delivered: 2026-10-16T11:00:00Z' \
  && printf '%s\n' "$out" | grep -qxF 'lead time: 2.0h' \
  && ok "report dates a task from the commit that closed its step, not the merge that brought it in" \
  || bad "report parallel merge" "got: $out"

# The same, merged one branch at a time, the first merge fast-forwarding nothing.
r7="$d/rrepo7"; rrepo "$r7"; p7="$r7/plan.md"
cp "$p6" "$p7"; sed 's/^- \[x\]/- [ ]/' "$p7" > "$p7.new" && mv "$p7.new" "$p7"
rcommit "$r7" "2026-10-16T09:00:00+0000" "add"
rgit "$r7" "2026-10-16T09:00:00+0000" checkout -q -b a
"$KEEL" plan tick "$p7" 1.1 >/dev/null
rcommit "$r7" "2026-10-16T10:00:00+0000" "tick 1.1 on a"
rgit "$r7" "2026-10-16T10:00:00+0000" checkout -q main
rgit "$r7" "2026-10-16T10:00:00+0000" checkout -q -b b
"$KEEL" plan tick "$p7" 2.1 >/dev/null
rcommit "$r7" "2026-10-16T11:00:00+0000" "tick 2.1 on b"
rgit "$r7" "2026-10-16T11:00:00+0000" checkout -q main
rgit "$r7" "2026-10-16T14:00:00+0000" merge -q --no-ff -m "merge a" a
rgit "$r7" "2026-10-16T15:00:00+0000" merge -q --no-ff -m "merge b" b
out="$("$KEEL" plan report "$p7" 2>&1)"
printf '%s\n' "$out" | grep -qF 'task 1: done 2026-10-16T10:00:00Z' \
  && printf '%s\n' "$out" | grep -qF 'task 2: done 2026-10-16T11:00:00Z' \
  && ok "report dates each task from its own branch when the branches are merged one after the other" \
  || bad "report sequential merges" "got: $out"

# The plan's path is a literal path, never a pattern: d/p[1].md is not d/p1.md.
r8="$d/rrepo8"; rrepo "$r8"; mkdir -p "$r8/d"
mkplan "$r8/d/p1.md" '- [ ] **Step 1.1: a**'
rcommit "$r8" "2026-10-16T09:00:00+0000" "add p1"
mkplan "$r8/d/p[1].md" '- [ ] **Step 1.1: a**'
rcommit "$r8" "2026-10-16T10:00:00+0000" "add p[1]"
out="$("$KEEL" plan report "$r8/d/p[1].md" 2>&1)"
printf '%s\n' "$out" | grep -qxF 'planned: 2026-10-16T10:00:00Z' \
  && ok "report reads the plan path literally: d/p[1].md is not d/p1.md" \
  || bad "report literal path" "got: $out"
out="$("$KEEL" plan report "$r8/d/p1.md" 2>&1)"
printf '%s\n' "$out" | grep -qxF 'planned: 2026-10-16T09:00:00Z' \
  && ok "report still reads d/p1.md as itself beside d/p[1].md" \
  || bad "report literal path, the plain name" "got: $out"

# A path with a non-ASCII name is exact, in the history walk and in the rework line.
r9="$d/rrepo9"; rrepo "$r9"; mkdir -p "$r9/d"
mkplan "$r9/d/plän.md" '- [ ] **Step 1.1: a**'
rcommit "$r9" "2026-10-16T09:00:00+0000" "add"
"$KEEL" plan tick "$r9/d/plän.md" 1.1 >/dev/null
rcommit "$r9" "2026-10-16T10:00:00+0000" "tick"
rcommit "$r9" "2026-10-17T09:00:00+0000" "fix" "Reworks d/plän.md"
out="$("$KEEL" plan report "$r9/d/plän.md" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -qxF 'planned: 2026-10-16T09:00:00Z' \
  && printf '%s\n' "$out" | grep -qF 'task 1: done 2026-10-16T10:00:00Z' \
  && printf '%s\n' "$out" | grep -qE '^rework: 1 \(' \
  && ok "report handles a plan whose path is not ASCII" \
  || bad "report non-ASCII path" "rc=$rc, got: $out"

# A shallow clone has lost the commits the times come from, so the report refuses.
sh="$d/shallow"
git clone -q --depth 1 "file://$r" "$sh" 2>/dev/null || bad "fixture clone" "git clone --depth 1 failed"
out="$("$KEEL" plan report "$sh/docs/plans/p.md" 2>&1)"; rc=$?
[ "$rc" -eq 5 ] && case "$out" in *shallow*) true ;; *) false ;; esac \
  && ok "report on a shallow clone exits 5, saying so" \
  || bad "report shallow" "rc=$rc, got: $out"

# Note fields begin the note or follow "; ": a longer word or a sentence does not make one.
r10="$d/rrepo10"; rrepo "$r10"; p10="$r10/plan.md"
{ printf '# A plan\n\n'
  printf '### Task %s: t\n\n- [ ] **Step %s.1: s**\n\n' 1 1 2 2 3 3 4 4 5 5 6 6; } > "$p10"
rcommit "$r10" "2026-10-16T09:00:00+0000" "add"
"$KEEL" plan tick "$p10" 1.1 --note 'routing: keel-implementer (sonnet, by hand); rounds: 2' >/dev/null
"$KEEL" plan tick "$p10" 2.1 --note 'subrounds: 3' >/dev/null
"$KEEL" plan tick "$p10" 3.1 --note 'Implementer routing: x' >/dev/null
"$KEEL" plan tick "$p10" 4.1 --note 'see rounds: 9 and routing: y above' >/dev/null
"$KEEL" plan tick "$p10" 5.1 --defer 'rounds: 9; routing: z' >/dev/null
"$KEEL" plan tick "$p10" 6.1 --note 'rounds: 4; Implementer routing: x; routing: a; routing: keel-implementer' >/dev/null
rcommit "$r10" "2026-10-16T10:00:00+0000" "tick all"
out="$("$KEEL" plan report "$p10" 2>&1)"
printf '%s\n' "$out" | grep -qxF 'task 1: done 2026-10-16T10:00:00Z, rounds 2, routing keel-implementer (sonnet, by hand)' \
  && ok "report reads routing written before rounds, its text running to the next semicolon" \
  || bad "report routing before rounds" "got: $out"
printf '%s\n' "$out" | grep -qxF 'task 2: done 2026-10-16T10:00:00Z, rounds unknown, routing unknown' \
  && ok "report does not read subrounds: as rounds:" \
  || bad "report subrounds" "got: $out"
printf '%s\n' "$out" | grep -qxF 'task 3: done 2026-10-16T10:00:00Z, rounds unknown, routing unknown' \
  && ok "report does not read Implementer routing: as routing:" \
  || bad "report Implementer routing" "got: $out"
printf '%s\n' "$out" | grep -qxF 'task 4: done 2026-10-16T10:00:00Z, rounds unknown, routing unknown' \
  && ok "report does not read a field out of the middle of a sentence" \
  || bad "report fields in prose" "got: $out"
printf '%s\n' "$out" | grep -qxF 'task 5: done 2026-10-16T10:00:00Z, rounds unknown, routing unknown' \
  && ok "report does not read a deferred step's reason for rounds or routing" \
  || bad "report deferred reason" "got: $out"
printf '%s\n' "$out" | grep -qxF 'task 6: done 2026-10-16T10:00:00Z, rounds 4, routing keel-implementer' \
  && ok "report takes the last of a field written twice in one note" \
  || bad "report last field" "got: $out"

# The note is the text after the last " Note: ", as plan tick writes it, so a step with text after
# its title still has its fields read, and that step text is never read as fields.
r10b="$d/rrepo10b"; rrepo "$r10b"; p10b="$r10b/plan.md"
{ printf '# A plan\n\n'
  printf '### Task 1: t\n\n- [ ] **Step 1.1: Check.** `bash t.sh`, then commit\n\n'
  printf '### Task 2: t\n\n- [ ] **Step 2.1: Check.** do it; routing: bogus\n\n'; } > "$p10b"
rcommit "$r10b" "2026-10-16T09:00:00+0000" "add"
"$KEEL" plan tick "$p10b" 1.1 --note 'rounds: 2; routing: keel-implementer' >/dev/null
"$KEEL" plan tick "$p10b" 2.1 >/dev/null
rcommit "$r10b" "2026-10-16T10:00:00+0000" "tick all"
out="$("$KEEL" plan report "$p10b" 2>&1)"
printf '%s\n' "$out" | grep -qxF 'task 1: done 2026-10-16T10:00:00Z, rounds 2, routing keel-implementer' \
  && ok "report reads a tick note that follows step text after the title" \
  || bad "report note after step text" "got: $out"
printf '%s\n' "$out" | grep -qxF 'task 2: done 2026-10-16T10:00:00Z, rounds unknown, routing unknown' \
  && ok "report does not read fields out of step text when the step has no note" \
  || bad "report fields in step text" "got: $out"

# An author offset is shown in UTC: 12:00 at +0300 is 09:00Z, and 15:20 at +0300 is 12:20Z.
r11="$d/rrepo11"; rrepo "$r11"; p11="$r11/plan.md"
mkplan "$p11" '- [ ] **Step 1.1: a**'
rcommit "$r11" "2026-10-16T12:00:00+0300" "add"
"$KEEL" plan tick "$p11" 1.1 >/dev/null
rcommit "$r11" "2026-10-16T15:20:00+0300" "tick"
out="$("$KEEL" plan report "$p11" 2>&1)"
printf '%s\n' "$out" | grep -qxF 'planned: 2026-10-16T09:00:00Z' \
  && printf '%s\n' "$out" | grep -qF 'task 1: done 2026-10-16T12:20:00Z' \
  && printf '%s\n' "$out" | grep -qxF 'lead time: 3.3h' \
  && ok "report shows an author time at a non-zero offset in UTC" \
  || bad "report offset" "got: $out"

help="$("$KEEL" --help 2>&1)"
case "$help" in
  *'plan report <plan>'*) ok "keel --help lists plan report" ;;
  *) bad "help" "keel --help does not list 'plan report <plan>'" ;;
esac

# ---- risk: which review loop a change gets ------------------------------------------------------

nl=$'\n'

# rkrepo <dir> [<pattern>...]: a repository with one commit whose profile declares the patterns as
# hard_block_paths, or declares no list at all when there are none. json.dumps writes the list, so a
# pattern with a space in it is exact. Every step that fails is a FAIL of its own, so a fixture that
# did not build cannot make a case pass by luck.
rkrepo() {
    local r="$1"; shift
    rrepo "$r"
    mkdir -p "$r/.keel" "$r/docs" "$r/src/ui" || bad "fixture directories" "mkdir failed in $r"
    if [ "$#" -gt 0 ]; then
        python3 -c 'import json, sys; print(json.dumps({"hard_block_paths": sys.argv[1:]}))' "$@" \
          > "$r/.keel/profile.json"
    else
        printf '{"project": {"name": "t"}}\n' > "$r/.keel/profile.json"
    fi || bad "fixture profile" "could not write the profile in $r"
    printf 'x\n' > "$r/README" || bad "fixture file" "could not write README in $r"
    rcommit "$r" "2026-10-16T09:00:00+0000" "init"
}

# rkwrite <repo> <path>...: writes each file, parent directories included.
rkwrite() {
    local r="$1" f; shift
    for f in "$@"; do
        mkdir -p "$r/$(dirname "$f")" && printf 'x\n' > "$r/$f" \
          || bad "fixture file" "could not write $f in $r"
    done
}

# rkstage <repo> <path>...: writes each file and stages it.
rkstage() {
    local r="$1"
    rkwrite "$@"; shift
    ( cd "$r" && git add -- "$@" ) || bad "fixture stage" "git add failed in $r"
}

# rkprofile <repo> <json>|-: commits the profile as given, or with none for -. It commits whatever
# else is staged, so a case calls it before it stages the change under test. --staged reads the
# profile as HEAD has it, so a case that needs a given list at HEAD has to commit it.
rkprofile() {
    local r="$1" j="$2"
    if [ "$j" = "-" ]; then rm -f "$r/.keel/profile.json"; else printf '%s\n' "$j" > "$r/.keel/profile.json"; fi \
      || { bad "fixture profile" "could not write the profile in $r"; return 1; }
    rcommit "$r" "2026-10-16T09:30:00+0000" "profile"
}

# rk <dir> <args>...: runs `keel plan risk` from <dir>, stdout and stderr together so a case sees
# every line, and leaves them in rk_out and rk_rc, because a pipe or a substitution would lose the
# exit code.
rk() {
    local dir="$1"; shift
    rk_out="$(cd "$dir" && "$KEEL" plan risk "$@" 2>&1)"; rk_rc=$?
}

# rk_split <dir> <args>...: like rk, but stdout alone in rk_out and stderr alone in rk_err, for the
# cases that read the one line risk writes on stderr.
rk_split() {
    local dir="$1"; shift
    rk_out="$(cd "$dir" && "$KEEL" plan risk "$@" 2>"$d/rk.err")"; rk_rc=$?
    rk_err="$(cat "$d/rk.err")"
}

# rk_timed <dir> <args>...: like rk, under a ten second limit, for a case that would hang. The
# limit is timeout, or gtimeout, or perl's alarm where neither exists, as on a stock macOS. With
# RK_SPLIT set, stdout and stderr are kept apart, as rk_split does.
rk_timed() {
    local dir="$1"; shift
    if command -v timeout >/dev/null 2>&1; then rk_lim=(timeout 10)
    elif command -v gtimeout >/dev/null 2>&1; then rk_lim=(gtimeout 10)
    else rk_lim=(perl -e 'alarm 10; exec @ARGV or die "exec: $!"'); fi
    if [ -n "${RK_SPLIT:-}" ]; then
        rk_out="$(cd "$dir" && "${rk_lim[@]}" "$KEEL" plan risk "$@" 2>"$d/rk.err")"; rk_rc=$?
        rk_err="$(cat "$d/rk.err")"
    else
        rk_out="$(cd "$dir" && "${rk_lim[@]}" "$KEEL" plan risk "$@" 2>&1)"; rk_rc=$?
    fi
}

# rk_noloop: true when the last run printed no `loop:` line, which is what a caller reads to decide.
rk_noloop() { ! printf '%s\n' "$rk_out" | grep -q '^loop:'; }

# 1 to 3: the rule on explicit paths, from the root and from a subdirectory. Paths are named from
# the repository root wherever keel runs, as git names them.
rk0="$d/rk0"; rkrepo "$rk0" 'src/payments' '*/auth/*'
for where in "$rk0" "$rk0/src/ui"; do
    lbl="${where#"$d"/}"
    rk "$where" src/payments/fee.sh
    [ "$rk_rc" -eq 0 ] && [ "$rk_out" = "src/payments/fee.sh${nl}loop: full" ] \
      && ok "risk: a path under a declared directory prints it, then loop: full (run in $lbl)" \
      || bad "risk directory pattern ($lbl)" "rc=$rk_rc, got: $rk_out"
    rk "$where" lib/auth/token.go
    [ "$rk_rc" -eq 0 ] && [ "$rk_out" = "lib/auth/token.go${nl}loop: full" ] \
      && ok "risk: a path matching a declared glob prints it, then loop: full (run in $lbl)" \
      || bad "risk glob pattern ($lbl)" "rc=$rk_rc, got: $rk_out"
    rk "$where" docs/readme.md src/ui/form.ts
    [ "$rk_rc" -eq 0 ] && [ "$rk_out" = "loop: light" ] \
      && ok "risk: paths matching nothing print loop: light alone (run in $lbl)" \
      || bad "risk light ($lbl)" "rc=$rk_rc, got: $rk_out"
    rk "$where" docs/readme.md src/payments/fee.sh src/ui/form.ts
    [ "$rk_rc" -eq 0 ] && [ "$rk_out" = "src/payments/fee.sh${nl}loop: full" ] \
      && ok "risk: mixed paths print only the matching one, then loop: full (run in $lbl)" \
      || bad "risk mixed ($lbl)" "rc=$rk_rc, got: $rk_out"
done
rk "$rk0" -- src/payments/fee.sh
[ "$rk_rc" -eq 0 ] && [ "$rk_out" = "src/payments/fee.sh${nl}loop: full" ] \
  && ok "risk: -- ends the options, so paths follow it" \
  || bad "risk double dash" "rc=$rk_rc, got: $rk_out"
rk "$rk0" ./src/payments//fee.sh
[ "$rk_rc" -eq 0 ] && [ "$rk_out" = "src/payments/fee.sh${nl}loop: full" ] \
  && ok "risk: a path spelled ./a//b is matched as a/b, so a spelling cannot read as light" \
  || bad "risk path spelling" "rc=$rk_rc, got: $rk_out"

# 4: staged. A rename out of a declared path names the old path, from the root and a subdirectory.
rk1="$d/rk1"; rkrepo "$rk1" 'src/payments'
rkstage "$rk1" src/payments/fee.sh
rcommit "$rk1" "2026-10-16T10:00:00+0000" "add fee"
( cd "$rk1" && git mv src/payments/fee.sh docs/fee.sh ) || bad "fixture rename" "git mv failed in $rk1"
for where in "$rk1" "$rk1/src/ui"; do
    lbl="${where#"$d"/}"
    rk "$where"
    [ "$rk_rc" -eq 0 ] && [ "$rk_out" = "src/payments/fee.sh${nl}loop: full" ] \
      && ok "risk: a staged rename out of a declared path names the old path, by default (run in $lbl)" \
      || bad "risk staged rename ($lbl)" "rc=$rk_rc, got: $rk_out"
    rk "$where" --staged
    [ "$rk_rc" -eq 0 ] && [ "$rk_out" = "src/payments/fee.sh${nl}loop: full" ] \
      && ok "risk: --staged is the default (run in $lbl)" \
      || bad "risk --staged ($lbl)" "rc=$rk_rc, got: $rk_out"
done
rk2="$d/rk2"; rkrepo "$rk2" 'src/payments'
rkstage "$rk2" src/payments/fee.sh
rcommit "$rk2" "2026-10-16T10:00:00+0000" "add fee"
printf 'changed\n' > "$rk2/src/payments/fee.sh" || bad "fixture edit" "could not edit fee.sh in $rk2"
rk "$rk2"
[ "$rk_rc" -eq 4 ] && rk_noloop && case "$rk_out" in *staged*) true ;; *) false ;; esac \
  && ok "risk: nothing staged exits 4 with no loop: line, an unstaged edit not counted" \
  || bad "risk nothing staged" "rc=$rk_rc, got: $rk_out"
rkstage "$rk2" docs/a.md
rk "$rk2"
[ "$rk_rc" -eq 0 ] && [ "$rk_out" = "loop: light" ] \
  && ok "risk: reads the index, so an unstaged edit to a declared path does not make a staged change full" \
  || bad "risk index not working tree" "rc=$rk_rc, got: $rk_out"

# 5: a range reads the commits between, renames included. An empty range exits 4.
rk3="$d/rk3"; rkrepo "$rk3" 'src/payments'
rkstage "$rk3" src/payments/fee.sh
rcommit "$rk3" "2026-10-16T10:00:00+0000" "add fee"
rkstage "$rk3" docs/a.md
rcommit "$rk3" "2026-10-16T11:00:00+0000" "add doc"
( cd "$rk3" && git mv src/payments/fee.sh docs/fee.sh ) || bad "fixture rename" "git mv failed in $rk3"
rcommit "$rk3" "2026-10-16T12:00:00+0000" "move fee"
for where in "$rk3" "$rk3/src/ui"; do
    lbl="${where#"$d"/}"
    rk "$where" --range HEAD~2..HEAD~1
    [ "$rk_rc" -eq 0 ] && [ "$rk_out" = "loop: light" ] \
      && ok "risk: --range over a change that touches nothing declared prints loop: light (run in $lbl)" \
      || bad "risk range light ($lbl)" "rc=$rk_rc, got: $rk_out"
    rk "$where" --range HEAD~3..HEAD~2
    [ "$rk_rc" -eq 0 ] && [ "$rk_out" = "src/payments/fee.sh${nl}loop: full" ] \
      && ok "risk: --range over a change that adds a declared path prints it, then loop: full (run in $lbl)" \
      || bad "risk range full ($lbl)" "rc=$rk_rc, got: $rk_out"
    rk "$where" --range HEAD~1..HEAD
    [ "$rk_rc" -eq 0 ] && [ "$rk_out" = "src/payments/fee.sh${nl}loop: full" ] \
      && ok "risk: --range over a rename out of a declared path names the old path (run in $lbl)" \
      || bad "risk range rename ($lbl)" "rc=$rk_rc, got: $rk_out"
    rk "$where" --range HEAD..HEAD
    [ "$rk_rc" -eq 4 ] && rk_noloop \
      && ok "risk: an empty --range exits 4 with no loop: line (run in $lbl)" \
      || bad "risk empty range ($lbl)" "rc=$rk_rc, got: $rk_out"
done
rk "$rk3" --range nosuchrev..HEAD
[ "$rk_rc" -eq 6 ] && rk_noloop \
  && ok "risk: a range git cannot read exits 6 with no loop: line" \
  || bad "risk bad range" "rc=$rk_rc, got: $rk_out"

# 6: no list is the light loop, said so, and still needs something to be staged.
rk4="$d/rk4"; rkrepo "$rk4"
rk "$rk4"
[ "$rk_rc" -eq 4 ] && rk_noloop \
  && ok "risk: with no list declared and nothing staged, still exits 4" \
  || bad "risk no list, nothing staged" "rc=$rk_rc, got: $rk_out"
rkstage "$rk4" src/payments/fee.sh
rk "$rk4"
[ "$rk_rc" -eq 0 ] && [ "$rk_out" = "no hard_block_paths declared${nl}loop: light" ] \
  && ok "risk: a profile with no hard_block_paths key says so, then loop: light" \
  || bad "risk no key" "rc=$rk_rc, got: $rk_out"
rk4b="$d/rk4b"; rkrepo "$rk4b"; rkprofile "$rk4b" '{"hard_block_paths": []}'
rkstage "$rk4b" src/payments/fee.sh
rk "$rk4b"
[ "$rk_rc" -eq 0 ] && [ "$rk_out" = "no hard_block_paths declared${nl}loop: light" ] \
  && ok "risk: an empty hard_block_paths list says so, then loop: light" \
  || bad "risk empty list" "rc=$rk_rc, got: $rk_out"
rk4c="$d/rk4c"; rkrepo "$rk4c"; rkprofile "$rk4c" -
rkstage "$rk4c" src/payments/fee.sh
rk "$rk4c/src/ui"
[ "$rk_rc" -eq 0 ] && [ "$rk_out" = "no hard_block_paths declared${nl}loop: light" ] \
  && ok "risk: no profile anywhere, at the root or below it, is the same as no list" \
  || bad "risk no profile" "rc=$rk_rc, got: $rk_out"

# 6b: the union. The hook reads the nearest .keel/profile.json walking up from the directory it
# runs in, and that can be any directory, so `plan risk` matches the changed paths against every
# list the hook could use: the root's as the base has it and as the working tree has it, every
# nested one tracked at the base, tracked, modified or untracked in the working tree (ignored ones
# too), and the one the hook's upward search finds above the repository. Patterns are taken as
# written and matched against root-relative paths, as the hook matches them.
# rk_full <label> <path>...: the last run exited 0 and printed exactly those paths, then loop: full.
rk_full() {
    local lbl="$1" want="" p; shift
    for p in "$@"; do want="${want:+$want$nl}$p"; done
    [ "$rk_rc" -eq 0 ] && [ "$rk_out" = "$want${nl}loop: full" ] \
      && ok "risk: $lbl" \
      || bad "risk $lbl" "rc=$rk_rc, want: [$want] then loop: full, got: $rk_out"
}
# rk_light <label> [declared]: the last run exited 0 and printed loop: light alone, or with the
# line saying nothing is declared when the second argument is "none".
rk_light() {
    local want="loop: light"
    [ "${2:-}" = "none" ] && want="no hard_block_paths declared${nl}loop: light"
    [ "$rk_rc" -eq 0 ] && [ "$rk_out" = "$want" ] \
      && ok "risk: $1" \
      || bad "risk $1" "rc=$rk_rc, got: $rk_out"
}
# rk_unread <label> <needle>: the last run exited 3, printed no loop: line and named <needle>.
rk_unread() {
    [ "$rk_rc" -eq 3 ] && rk_noloop && case "$rk_out" in *"$2"*) true ;; *) false ;; esac \
      && ok "risk: $1" \
      || bad "risk $1" "rc=$rk_rc, want exit 3 naming '$2', got: $rk_out"
}
# rknest <dir> <root json>|- <nested json>: a repository whose root profile is the first (none, for
# -) and that has svc/.keel/profile.json holding the second, both committed, nothing staged.
rknest() {
    local r="$1"
    rkrepo "$r"; rkprofile "$r" "$2"
    mkdir -p "$r/svc/.keel" || bad "fixture directories" "mkdir failed in $r"
    printf '%s\n' "$3" > "$r/svc/.keel/profile.json" || bad "fixture profile" "write failed in $r"
    rcommit "$r" "2026-10-16T09:40:00+0000" "nested profile"
}

# A list only in a nested profile, with the change under it: full, from the root and from svc.
rkn1="$d/rkn1"; rknest "$rkn1" - '{"hard_block_paths": ["svc/src/payments"]}'
rkstage "$rkn1" svc/src/payments/fee.sh
for where in "$rkn1" "$rkn1/svc"; do
    lbl="${where#"$d"/}"
    rk "$where"
    rk_full "a list only in a nested profile, a staged change under it, is full (run in $lbl)" svc/src/payments/fee.sh
    rk "$where" --staged
    rk_full "the same with --staged named (run in $lbl)" svc/src/payments/fee.sh
    rk "$where" svc/src/payments/fee.sh
    rk_full "the same for an explicit path, read from the working tree (run in $lbl)" svc/src/payments/fee.sh
done
rcommit "$rkn1" "2026-10-16T10:00:00+0000" "fee"
rkstage "$rkn1" docs/a.md
for where in "$rkn1" "$rkn1/svc"; do
    rk "$where" --range HEAD~1..HEAD
    rk_full "a nested list at <a>, under --range, is full (run in ${where#"$d"/})" svc/src/payments/fee.sh
done
# Patterns are matched as written against root-relative paths, as the hook does: a nested profile
# naming src/payments covers the root's src/payments, and not svc/src/payments.
rkn1b="$d/rkn1b"; rknest "$rkn1b" - '{"hard_block_paths": ["src/payments"]}'
rkstage "$rkn1b" svc/src/payments/fee.sh
rk "$rkn1b/svc"
rk_light "a nested pattern is not made relative to its directory, so svc/src/payments is not src/payments"
rkstage "$rkn1b" src/payments/fee.sh
rk "$rkn1b/svc"
rk_full "a nested pattern matches the root-relative path it names" src/payments/fee.sh

# An untracked nested profile is one the hook reads from inside its directory, so its list counts
# from anywhere.
rkn2="$d/rkn2"; rkrepo "$rkn2"; rkprofile "$rkn2" -
mkdir -p "$rkn2/svc/.keel" || bad "fixture directories" "mkdir failed in $rkn2"
printf '{"hard_block_paths": ["svc/src/payments"]}\n' > "$rkn2/svc/.keel/profile.json" \
  || bad "fixture profile" "write failed in $rkn2"
rkstage "$rkn2" svc/src/payments/fee.sh
for where in "$rkn2" "$rkn2/svc"; do
    rk "$where"
    rk_full "an untracked nested profile that matches is full (run in ${where#"$d"/})" svc/src/payments/fee.sh
done
# A nested profile in the change itself is a change to a profile, never light.
rkn3="$d/rkn3"; rkrepo "$rkn3"; rkprofile "$rkn3" -
rkstage "$rkn3" svc/.keel/profile.json svc/src/payments/fee.sh
rk "$rkn3"
[ "$rk_rc" -eq 0 ] && [ "$(printf '%s\n' "$rk_out" | sed -n 1p)" = "svc/.keel/profile.json" ] \
  && [ "$(printf '%s\n' "$rk_out" | tail -1)" = "loop: full" ] \
  && ok "risk: a change that adds a profile below the root is full, naming it" \
  || bad "risk staged nested profile" "rc=$rk_rc, got: $rk_out"
rkn3b="$d/rkn3b"; rknest "$rkn3b" - '{"hard_block_paths": ["svc/src/payments"]}'
( cd "$rkn3b" && git rm -q -f svc/.keel/profile.json ) || bad "fixture delete" "git rm failed in $rkn3b"
rk "$rkn3b"
[ "$rk_rc" -eq 0 ] && [ "$(printf '%s\n' "$rk_out" | sed -n 1p)" = "svc/.keel/profile.json" ] \
  && [ "$(printf '%s\n' "$rk_out" | tail -1)" = "loop: full" ] \
  && ok "risk: a change that deletes a profile below the root is full, naming it" \
  || bad "risk staged nested profile delete" "rc=$rk_rc, got: $rk_out"
rkn3c="$d/rkn3c"; rkrepo "$rkn3c" 'docs/secret'
rkstage "$rkn3c" svc/.Keel/Profile.JSON
rk "$rkn3c"
[ "$rk_rc" -eq 0 ] && [ "$(printf '%s\n' "$rk_out" | sed -n 1p)" = "svc/.Keel/Profile.JSON" ] \
  && [ "$(printf '%s\n' "$rk_out" | tail -1)" = "loop: full" ] \
  && ok "risk: a change to a profile spelled in another case is full, naming it" \
  || bad "risk staged case-variant profile" "rc=$rk_rc, got: $rk_out"

# A root list and a nested one, and only the nested one matches: full, from the root and from svc.
rkp1="$d/rkp1"; rknest "$rkp1" '{"hard_block_paths": ["docs/secret"]}' '{"hard_block_paths": ["svc/src/payments"]}'
rkstage "$rkp1" svc/src/payments/fee.sh docs/a.md
for where in "$rkp1" "$rkp1/svc"; do
    lbl="${where#"$d"/}"
    rk "$where"
    rk_full "a root list and a nested one, only the nested one matching, is full (run in $lbl)" svc/src/payments/fee.sh
    rk "$where" svc/src/payments/fee.sh docs/a.md
    rk_full "the same for explicit paths, read from the working tree (run in $lbl)" svc/src/payments/fee.sh
done
rcommit "$rkp1" "2026-10-16T10:00:00+0000" "fee"
for where in "$rkp1" "$rkp1/svc"; do
    rk "$where" --range HEAD~1..HEAD
    rk_full "the same under --range, the nested profile being at <a> (run in ${where#"$d"/})" svc/src/payments/fee.sh
done
# Both lists matching prints every path either one covers, once.
rkstage "$rkp1" docs/secret/k.txt svc/src/payments/b.sh docs/a.md
rk "$rkp1/svc"
rk_full "paths matching either list are all printed, sorted" docs/secret/k.txt svc/src/payments/b.sh
# Lists that match nothing are light, with no line saying nothing is declared, since one is.
rkp2="$d/rkp2"; rknest "$rkp2" '{"hard_block_paths": ["docs/secret"]}' '{"hard_block_paths": ["svc/src/payments"]}'
rkstage "$rkp2" docs/a.md src/ui/form.ts
for where in "$rkp2" "$rkp2/svc"; do
    rk "$where"
    rk_light "a root list and a nested one that match nothing are light (run in ${where#"$d"/})"
done
rkp3="$d/rkp3"; rknest "$rkp3" - '{"hard_block_paths": ["svc/src/payments"]}'
rkstage "$rkp3" docs/a.md
rk "$rkp3"
rk_light "a nested list that matches nothing is light (run in rkp3)"
rkp4="$d/rkp4"; rknest "$rkp4" '{"project": {"name": "t"}}' '{"hard_block_paths": []}'
rkstage "$rkp4" svc/src/payments/fee.sh
rk "$rkp4/svc"
rk_light "profiles that declare no list say so, then loop: light" none
# An untracked nested profile whose list matches nothing changes nothing.
rkp5="$d/rkp5"; rkrepo "$rkp5" 'docs/secret'
mkdir -p "$rkp5/svc/.keel" || bad "fixture directories" "mkdir failed in $rkp5"
printf '{"hard_block_paths": ["svc/src/payments"]}\n' > "$rkp5/svc/.keel/profile.json" \
  || bad "fixture profile" "write failed in $rkp5"
rkstage "$rkp5" docs/a.md
for where in "$rkp5" "$rkp5/svc"; do
    rk "$where"
    rk_light "an untracked nested profile that matches nothing is light (run in ${where#"$d"/})"
done

# The root profile is read as the base has it and as the working tree has it: an unstaged edit to
# it that adds a pattern counts, though the commit would not carry it. HEAD says src/auth, the
# working tree says src/payments, and src/payments/fee.sh is staged.
rku1="$d/rku1"; rkrepo "$rku1" 'src/auth'
printf '{"hard_block_paths": ["src/payments"]}\n' > "$rku1/.keel/profile.json" \
  || bad "fixture profile" "write failed in $rku1"
rkstage "$rku1" src/payments/fee.sh
for where in "$rku1" "$rku1/src/ui"; do
    rk "$where"
    rk_full "an unstaged edit that adds the staged path's pattern to the root list is full (run in ${where#"$d"/})" src/payments/fee.sh
done
rku1b="$d/rku1b"; rkrepo "$rku1b" 'src/auth'
rkstage "$rku1b" src/payments/fee.sh
rcommit "$rku1b" "2026-10-16T10:00:00+0000" "fee"
printf '{"hard_block_paths": ["src/payments"]}\n' > "$rku1b/.keel/profile.json" \
  || bad "fixture profile" "write failed in $rku1b"
rk "$rku1b" --range HEAD~1..HEAD
rk_full "the same under --range: <a> says src/auth, the working tree src/payments" src/payments/fee.sh
# No profile at HEAD, or no commit yet, and one in the working tree: its list counts.
rku2="$d/rku2"; rrepo "$rku2"; mkdir -p "$rku2/.keel"
printf '{"hard_block_paths":["src/payments"]}\n' > "$rku2/.keel/profile.json" \
  || bad "fixture profile" "write failed in $rku2"
rkstage "$rku2" src/payments/fee.sh
rk "$rku2"
rk_full "a root profile in the working tree and not at HEAD, with no commit yet, is read" src/payments/fee.sh
rku3="$d/rku3"; rkrepo "$rku3"; rkprofile "$rku3" -
printf '{"hard_block_paths":["src/payments"]}\n' > "$rku3/.keel/profile.json" \
  || bad "fixture profile" "write failed in $rku3"
rkstage "$rku3" src/payments/fee.sh
for where in "$rku3" "$rku3/src/ui"; do
    rk "$where"
    rk_full "an untracked root profile, which the hook reads, is read (run in ${where#"$d"/})" src/payments/fee.sh
done
# A nested profile deleted from the working tree but tracked at the base still counts.
rku4="$d/rku4"; rknest "$rku4" - '{"hard_block_paths": ["svc/src/payments"]}'
rm -f "$rku4/svc/.keel/profile.json" || bad "fixture delete" "rm failed in $rku4"
rkstage "$rku4" svc/src/payments/fee.sh
rk "$rku4"
rk_full "a nested profile tracked at HEAD and gone from the working tree still counts" svc/src/payments/fee.sh

# An untracked profile that .gitignore hides is still one the hook reads.
# rkig <dir>: a repository whose .gitignore hides svc/.keel/, with an ignored nested profile
# declaring svc/src/payments beside a root list of docs/secret.
rkig() {
    local r="$1"
    rkrepo "$r" 'docs/secret'
    printf 'svc/.keel/\n' > "$r/.gitignore" || bad "fixture ignore" "write failed in $r"
    rcommit "$r" "2026-10-16T09:40:00+0000" "ignore svc/.keel"
    mkdir -p "$r/svc/.keel" || bad "fixture directories" "mkdir failed in $r"
    printf '{"hard_block_paths": ["svc/src/payments"]}\n' > "$r/svc/.keel/profile.json" \
      || bad "fixture profile" "write failed in $r"
    ( cd "$r" && git check-ignore -q svc/.keel/profile.json ) \
      || bad "fixture ignored profile" "svc/.keel/profile.json is not ignored in $r"
}
rki1="$d/rki1"; rkig "$rki1"
rkstage "$rki1" svc/src/payments/fee.sh
for where in "$rki1" "$rki1/svc"; do
    rk "$where"
    rk_full "an untracked, gitignored nested profile that matches is full (run in ${where#"$d"/})" svc/src/payments/fee.sh
done
rki2="$d/rki2"; rkig "$rki2"
rkstage "$rki2" docs/a.md
rk "$rki2"
rk_light "an untracked, gitignored nested profile that matches nothing is light"

# A symlink named .keel, or a symlinked profile, anywhere: a profile that cannot be read.
rksl1="$d/rksl1"; rkrepo "$rksl1" 'docs/secret'
mkdir -p "$rksl1/svc" && ln -s nowhere "$rksl1/svc/.keel" || bad "fixture symlink" "could not link in $rksl1"
rkstage "$rksl1" docs/a.md
for where in "$rksl1" "$rksl1/svc"; do
    rk "$where"
    rk_unread "a symlinked svc/.keel, dangling, exits 3 naming it (run in ${where#"$d"/})" "svc/.keel"
done
rksl2="$d/rksl2"; rkrepo "$rksl2" 'docs/secret'
mkdir -p "$rksl2/real" "$rksl2/svc" && printf '{"hard_block_paths": []}\n' > "$rksl2/real/profile.json" \
  && ln -s ../real "$rksl2/svc/.keel" || bad "fixture symlink" "could not link in $rksl2"
rkstage "$rksl2" docs/a.md
rk "$rksl2"
rk_unread "a symlinked svc/.keel to a readable profile is not followed, so exit 3" "svc/.keel"
rcommit "$rksl2" "2026-10-16T09:50:00+0000" "linked .keel"
rm -f "$rksl2/svc/.keel" || bad "fixture delete" "rm failed in $rksl2"
rkstage "$rksl2" docs/b.md
rk "$rksl2"
rk_unread "a symlinked svc/.keel tracked at HEAD and gone from the working tree still exits 3" "svc/.keel"
rksl3="$d/rksl3"; rkrepo "$rksl3" 'docs/secret'
mkdir -p "$rksl3/svc/.keel" && printf '{}\n' > "$rksl3/other.json" \
  && ln -s ../../other.json "$rksl3/svc/.keel/profile.json" || bad "fixture symlink" "could not link in $rksl3"
rkstage "$rksl3" docs/a.md
rk "$rksl3"
rk_unread "a symlinked svc/.keel/profile.json exits 3 naming it" "svc/.keel/profile.json"

# Discovery is case-insensitive, as a macOS file system is: svc/.Keel/profile.json is a profile.
rkc1="$d/rkc1"; rkrepo "$rkc1" 'docs/secret'
mkdir -p "$rkc1/svc/.Keel" || bad "fixture directories" "mkdir failed in $rkc1"
printf '{"hard_block_paths": ["svc/src/payments"]}\n' > "$rkc1/svc/.Keel/profile.json" \
  || bad "fixture profile" "write failed in $rkc1"
rcommit "$rkc1" "2026-10-16T09:40:00+0000" "case-variant profile"
rkstage "$rkc1" svc/src/payments/fee.sh
for where in "$rkc1" "$rkc1/svc"; do
    rk "$where"
    rk_full "a tracked svc/.Keel/profile.json is a profile (run in ${where#"$d"/})" svc/src/payments/fee.sh
done
rkc2="$d/rkc2"; rkrepo "$rkc2" 'docs/secret'
mkdir -p "$rkc2/svc/.KEEL" || bad "fixture directories" "mkdir failed in $rkc2"
printf '{"hard_block_paths": ["svc/src/payments"]}\n' > "$rkc2/svc/.KEEL/Profile.JSON" \
  || bad "fixture profile" "write failed in $rkc2"
rkstage "$rkc2" svc/src/payments/fee.sh
rk "$rkc2"
rk_full "an untracked svc/.KEEL/Profile.JSON is a profile too" svc/src/payments/fee.sh
rkc3="$d/rkc3"; rkrepo "$rkc3" 'docs/secret'
mkdir -p "$rkc3/svc/.Keel" || bad "fixture directories" "mkdir failed in $rkc3"
printf '{not json' > "$rkc3/svc/.Keel/profile.json" || bad "fixture profile" "write failed in $rkc3"
rkstage "$rkc3" docs/a.md
rk "$rkc3"
rk_unread "an invalid svc/.Keel/profile.json exits 3 naming it" "svc/.Keel/profile.json"

# A nested profile that cannot be read: exit 3 naming it, unless something else already matched.
rkv1="$d/rkv1"; rknest "$rkv1" '{"hard_block_paths": ["docs/secret"]}' '{not json'
rkstage "$rkv1" docs/a.md
for where in "$rkv1" "$rkv1/svc"; do
    rk "$where"
    rk_unread "an invalid nested profile exits 3 naming it, no loop: line (run in ${where#"$d"/})" "svc/.keel/profile.json"
done
rkstage "$rkv1" docs/secret/k.txt
rk_split "$rkv1"
rk_full "a path a readable list matches is full, whatever else cannot be read" docs/secret/k.txt
rkv2="$d/rkv2"; rkrepo "$rkv2" 'docs/secret'
mkdir -p "$rkv2/svc/.keel" || bad "fixture directories" "mkdir failed in $rkv2"
printf '{not json' > "$rkv2/svc/.keel/profile.json" || bad "fixture profile" "write failed in $rkv2"
rkstage "$rkv2" docs/a.md
rk "$rkv2"
rk_unread "an invalid untracked nested profile exits 3 naming it" "svc/.keel/profile.json"
rkv3="$d/rkv3"; rknest "$rkv3" - '{"hard_block_paths": "svc"}'
rkstage "$rkv3" docs/a.md
rk "$rkv3"
rk_unread "a nested profile whose list is the wrong shape exits 3 naming it" "svc/.keel/profile.json"

# 6c: above the repository. The hook run from the root, where no profile is, reads the nearest one
# above the repository, and run from svc it reads svc's own. keel cannot know which directory the
# hook will run in, so the nearest profile above the repository is in the union whatever directory
# keel runs in, including one whose own profile would stop a walk that began there.
rko="$d/outer"; rkrepo "$rko/repo"; rkprofile "$rko/repo" -
mkdir -p "$rko/.keel" "$rko/repo/svc/.keel" || bad "fixture directories" "mkdir failed in $rko"
printf '{"hard_block_paths": ["secret"]}\n' > "$rko/.keel/profile.json" \
  && printf '{"hard_block_paths": ["nothing"]}\n' > "$rko/repo/svc/.keel/profile.json" \
  || bad "fixture profile" "write failed in $rko"
rcommit "$rko/repo" "2026-10-16T09:40:00+0000" "nested profile"
rkstage "$rko/repo" secret/k
for where in "$rko/repo" "$rko/repo/svc"; do
    rk "$where"
    rk_full "a profile above the repository, with none at the root, counts (run in ${where#"$d"/})" secret/k
done
# A profile above the repository that cannot be read is named, and decides nothing if a path
# matched.
rkoa="$d/outer2"; rkrepo "$rkoa/repo" 'docs/secret'
mkdir -p "$rkoa/.keel" || bad "fixture directories" "mkdir failed in $rkoa"
printf '{not json' > "$rkoa/.keel/profile.json" || bad "fixture profile" "write failed in $rkoa"
rkstage "$rkoa/repo" docs/a.md
rk "$rkoa/repo"
rk_unread "an invalid profile above the repository exits 3 naming it" "outer2/.keel/profile.json"

# The hook walks the logical $PWD, symlinks unresolved, so a profile above the repository by the
# path the shell took is one it reads, though the resolved path never passes it. view/sub is a link
# to real/repo, and view has the profile. From view/sub/svc, whose own profile stops a walk begun
# there, the parents of the repository are still those of view/sub.
rkl="$d/lg"; rkrepo "$rkl/real/repo"; rkprofile "$rkl/real/repo" -
mkdir -p "$rkl/view/.keel" "$rkl/real/repo/svc/.keel" || bad "fixture directories" "mkdir failed in $rkl"
printf '{"hard_block_paths": ["secret"]}\n' > "$rkl/view/.keel/profile.json" \
  && printf '{"hard_block_paths": ["nothing"]}\n' > "$rkl/real/repo/svc/.keel/profile.json" \
  && ln -s ../real/repo "$rkl/view/sub" || bad "fixture profile" "write or link failed in $rkl"
rcommit "$rkl/real/repo" "2026-10-16T09:40:00+0000" "nested profile"
rkstage "$rkl/real/repo" secret/k
for where in "$rkl/view/sub" "$rkl/view/sub/svc"; do
    rk "$where"
    rk_full "a profile above the repository by its logical path counts (run in ${where#"$d"/})" secret/k
done

# A nested repository or submodule named .keel. An untracked embedded repository is listed by git
# as svc/.keel/, with the slash, and a tracked one is a gitlink, mode 160000, which no file listing
# shows as a profile. The hook reads svc/.keel/profile.json from inside an embedded repository.
# rkemb <dir> <profile text>|-: a repository with root list docs/secret and an untracked embedded
# repository svc/.keel holding the profile text, or none for -. It is made after the commit, since
# rcommit's `git add .` would stage it as a gitlink.
rkemb() {
    local r="$1"
    rkrepo "$r" 'docs/secret'
    mkdir -p "$r/svc" && git init -q "$r/svc/.keel" || bad "fixture embedded repository" "git init failed in $r"
    if [ "$2" != "-" ]; then
        printf '%s\n' "$2" > "$r/svc/.keel/profile.json" || bad "fixture profile" "write failed in $r"
    fi
}
rkm1="$d/rkm1"; rkemb "$rkm1" '{"hard_block_paths": ["svc/secret"]}'
rkstage "$rkm1" svc/secret/k
( cd "$rkm1" && git ls-files --others | grep -qx 'svc/\.keel/' ) \
  || bad "fixture embedded repository" "git does not list svc/.keel/ as untracked in $rkm1"
for where in "$rkm1" "$rkm1/svc"; do
    rk "$where"
    rk_full "a profile in an untracked embedded repository named .keel counts (run in ${where#"$d"/})" svc/secret/k
done
rkm2="$d/rkm2"; rkemb "$rkm2" '{not json'
rkstage "$rkm2" docs/a.md
for where in "$rkm2" "$rkm2/svc"; do
    rk "$where"
    rk_unread "an invalid profile in an untracked embedded .keel exits 3 naming it (run in ${where#"$d"/})" "svc/.keel/profile.json"
done
rkm3="$d/rkm3"; rkemb "$rkm3" -
rkstage "$rkm3" docs/a.md
rk "$rkm3"
rk_light "an untracked embedded .keel with no profile in it is no profile"
# A tracked gitlink named .keel, in any case, is a profile that cannot be read.
# rkgl <dir> <name>: a repository with root list docs/secret and a gitlink at svc/<name>,
# committed.
rkgl() {
    local r="$1"
    rkrepo "$r" 'docs/secret'
    ( cd "$r" && git update-index --add --cacheinfo "160000,$(git rev-parse HEAD),svc/$2" ) \
      || bad "fixture gitlink" "update-index failed in $r"
    rgit "$r" "2026-10-16T09:40:00+0000" commit -q -m "gitlink"
}
rkg1="$d/rkg1"; rkgl "$rkg1" .keel
rkstage "$rkg1" docs/a.md
rk "$rkg1"
rk_unread "a gitlink svc/.keel tracked at HEAD exits 3 naming it" "svc/.keel"
rkg2="$d/rkg2"; rkgl "$rkg2" .KEEL
rkstage "$rkg2" docs/a.md
rk "$rkg2"
rk_unread "a gitlink svc/.KEEL tracked at HEAD, in another case, exits 3 naming it" "svc/.KEEL"
rkg3="$d/rkg3"; rkgl "$rkg3" .keel
rkstage "$rkg3" docs/secret/k.txt
rk_split "$rkg3"
rk_full "a path a readable list matches is full, whatever gitlink cannot be read" docs/secret/k.txt
# The same gitlink in the index only, and in a range whose base has none: still never light.
rkg4="$d/rkg4"; rkrepo "$rkg4" 'docs/secret'
( cd "$rkg4" && git update-index --add --cacheinfo "160000,$(git rev-parse HEAD),svc/.keel" ) \
  || bad "fixture gitlink" "update-index failed in $rkg4"
rkstage "$rkg4" docs/a.md
rk_split "$rkg4"
rk_full "a change that adds a gitlink named .keel is full, naming it" svc/.keel
# Any changed path whose last component is .keel, in any case, is full: a file, a link, a gitlink.
rkg5="$d/rkg5"; rkrepo "$rkg5" 'docs/secret'
rkstage "$rkg5" svc/.Keel docs/a.md
for where in "$rkg5" "$rkg5/svc"; do
    rk_split "$where"
    rk_full "a change to a path named .Keel is full, naming it (run in ${where#"$d"/})" svc/.Keel
done

# A profile that is not a regular file, a FIFO above all, cannot be read, and opening it would wait
# for a writer for ever. It exits 3 naming it, unless something matched, and does not hang.
rkf1="$d/rkf1"; rkrepo "$rkf1" 'docs/secret'
mkdir -p "$rkf1/svc/.keel" && mkfifo "$rkf1/svc/.keel/profile.json" \
  || bad "fixture fifo" "mkfifo failed in $rkf1"
rkstage "$rkf1" docs/a.md
rk_timed "$rkf1/svc"
rk_unread "a FIFO as svc/.keel/profile.json exits 3 naming it, and does not hang" "svc/.keel/profile.json"
rkstage "$rkf1" docs/secret/k.txt
RK_SPLIT=1 rk_timed "$rkf1/svc"
rk_full "a path a readable list matches is full, with a FIFO profile beside it" docs/secret/k.txt
rkf2="$d/rkf2"; rkrepo "$rkf2" 'docs/secret'
mkdir -p "$rkf2/svc/.keel/profile.json" || bad "fixture directory" "mkdir failed in $rkf2"
rkstage "$rkf2" docs/a.md
rk_timed "$rkf2/svc"
rk_unread "a directory as svc/.keel/profile.json exits 3 naming it" "svc/.keel/profile.json"

# A full verdict with a profile that could not be read says so on stderr, one line naming it, and
# stays full. No unreadable profile, no such line.
rke1="$d/rke1"; rknest "$rke1" '{"hard_block_paths": ["docs/secret"]}' '{not json'
rkstage "$rke1" docs/secret/k.txt
rk_split "$rke1/svc"
[ "$rk_rc" -eq 0 ] && [ "$rk_out" = "docs/secret/k.txt${nl}loop: full" ] \
  && [ "$(printf '%s\n' "$rk_err" | wc -l | tr -d ' ')" -eq 1 ] \
  && case "$rk_err" in "keel: "*"svc/.keel/profile.json"*) true ;; *) false ;; esac \
  && ok "risk: a full verdict with an unreadable profile names it in one line on stderr" \
  || bad "risk full names unreadable" "rc=$rk_rc, out: [$rk_out], err: [$rk_err]"
rke2="$d/rke2"; rknest "$rke2" '{"hard_block_paths": ["docs/secret"]}' '{"hard_block_paths": []}'
rkstage "$rke2" docs/secret/k.txt
rk_split "$rke2/svc"
[ "$rk_rc" -eq 0 ] && [ "$rk_out" = "docs/secret/k.txt${nl}loop: full" ] && [ -z "$rk_err" ] \
  && ok "risk: a full verdict with every profile readable writes nothing on stderr" \
  || bad "risk full quiet" "rc=$rk_rc, out: [$rk_out], err: [$rk_err]"

# 7: a profile that cannot be read, a list of the wrong shape, no python3, and no work tree.
rk5="$d/rk5"; rkrepo "$rk5" 'src/payments'
rkprofile "$rk5" '{not json'
rkstage "$rk5" docs/a.md
for where in "$rk5" "$rk5/src/ui"; do
    lbl="${where#"$d"/}"
    rk "$where"
    [ "$rk_rc" -eq 3 ] && rk_noloop && case "$rk_out" in *".keel/profile.json"*) true ;; *) false ;; esac \
      && ok "risk: a profile that is not valid JSON exits 3 naming it, no loop: line (run in $lbl)" \
      || bad "risk invalid profile ($lbl)" "rc=$rk_rc, got: $rk_out"
done
# Only a missing key or [] is no list. Any other value, falsy ones included, is a list that cannot
# be read, and the loop is not decided.
rkn=0
for shape in '{"hard_block_paths": "src/payments"}' '{"hard_block_paths": {}}' \
             '{"hard_block_paths": ""}' '{"hard_block_paths": false}' '{"hard_block_paths": 0}' \
             '{"hard_block_paths": null}' '{"hard_block_paths": true}' '{"hard_block_paths": [1]}' \
             '{"hard_block_paths": ["src", null]}' '[]' '"x"' '0'; do
    rkn=$((rkn + 1)); rks="$d/rks$rkn"; rkrepo "$rks"; rkprofile "$rks" "$shape"
    rkstage "$rks" docs/a.md
    rk "$rks"
    [ "$rk_rc" -eq 3 ] && rk_noloop && case "$rk_out" in *".keel/profile.json"*) true ;; *) false ;; esac \
      && ok "risk: a profile of $shape exits 3 naming it, rather than reading it as none" \
      || bad "risk list shape $shape" "rc=$rk_rc, got: $rk_out"
done

nopy="$d/nopy"; mkdir -p "$nopy"
for b in bash git env dirname basename cat sed awk grep tr sort uname mktemp rm head tail; do
    t="$(command -v "$b" 2>/dev/null)" && [ -n "$t" ] && ln -s "$t" "$nopy/$b"
done
if PATH="$nopy" python3 -c 'pass' >/dev/null 2>&1; then
    bad "fixture no python3" "python3 still runs with PATH=$nopy"
fi
printf '{"hard_block_paths": ["src/payments"]}\n' > "$rk5/.keel/profile.json" || bad "fixture profile" "write failed in $rk5"
rk_out="$(cd "$rk5" && PATH="$nopy" "$(command -v bash)" "$KEEL" plan risk docs/a.md 2>&1)"; rk_rc=$?
[ "$rk_rc" -eq 3 ] && rk_noloop && case "$rk_out" in *python3*) true ;; *) false ;; esac \
  && ok "risk: python3 absent exits 3 naming python3, no loop: line" \
  || bad "risk no python3" "rc=$rk_rc, got: $rk_out"

mkdir -p "$d/nogit"
rk_out="$(cd "$d/nogit" && GIT_CEILING_DIRECTORIES="$d" "$KEEL" plan risk docs/a.md 2>&1)"; rk_rc=$?
[ "$rk_rc" -eq 6 ] && rk_noloop \
  && ok "risk: outside a git work tree exits 6 with no loop: line" \
  || bad "risk no work tree" "rc=$rk_rc, got: $rk_out"
case "$rk_out" in
  *"keel: keel"*|*"keel: plan risk"*) bad "risk prefix" "the message repeats its prefix: $rk_out" ;;
  *) ok "risk: the message carries one keel: prefix" ;;
esac

# 8: the verdict is the hook's. The rule is cut out of hooks/sensitive-guard here, at test time, so
# a change to the hook's matching changes this test's expectation with it and `plan risk` has to
# follow. The extraction must find the rule; an empty one would make every verdict agree.
rule="$(awk '/^def matches\(/ { p = 1 } p && /^$/ { exit } p' "$ROOT/hooks/sensitive-guard")"
case "$rule" in
  "def matches("*"fnmatch("*) ;;
  *) bad "parity fixture" "could not extract def matches from hooks/sensitive-guard, got: $rule" ;;
esac
hook_hits() {   # hook_hits <pattern> <path>...: the paths the hook's rule says <pattern> matches
    HOOK_RULE="$rule" python3 -c '
import os, sys
from fnmatch import fnmatch
exec(os.environ["HOOK_RULE"])
print("\n".join(sorted({f for f in sys.argv[2:] if matches(f, sys.argv[1])})))' "$@"
}
rk6="$d/rk6"; rkrepo "$rk6"
parity_paths=('src/payments/fee.sh' 'src/payments' 'src/payments-old/x.sh' 'src/billing/inv.go'
  'src/billing' 'lib/auth/token.go' 'src/auth/deep/two words/k.go' 'src/pay ments/a b.sh'
  'docs/readme.md' 'docs/sub/readme.md' 'src/ui/form.ts' 'payments/src/payments/x')
for pat in 'src/payments' 'src/billing/' '*/auth/*' 'src/pay ments' 'docs/*.md' 'src/auth/**'; do
    python3 -c 'import json, sys; print(json.dumps({"hard_block_paths": sys.argv[1:]}))' "$pat" \
      > "$rk6/.keel/profile.json" || bad "fixture profile" "write failed in $rk6"
    want="$(hook_hits "$pat" "${parity_paths[@]}")"
    rk "$rk6" "${parity_paths[@]}"
    got="$(printf '%s\n' "$rk_out" | sed '$d')"
    if [ -n "$want" ]; then wloop="loop: full"; else wloop="loop: light"; fi
    [ "$rk_rc" -eq 0 ] && [ "$got" = "$want" ] && [ "$(printf '%s\n' "$rk_out" | tail -1)" = "$wloop" ] \
      && [ -n "$want" ] \
      && ok "risk: agrees with the hook's rule on '$pat'" \
      || bad "risk parity '$pat'" "rc=$rk_rc, hook matches: [$want], risk printed: [$rk_out]"
done

# 9: a usage error exits 1 and prints no loop: line, so nothing can read it as a verdict.
for args in '--stagd' '--range' '--range nodots' '--range ..HEAD' '--range HEAD..' '--range HEAD...HEAD' \
            '--staged docs/a.md' '--staged --range HEAD..HEAD' '--range HEAD..HEAD docs/a.md' '--range -x..HEAD' \
            '--range HEAD..HEAD..HEAD' '--range HEAD..HEAD...HEAD' \
            '/etc/passwd' '/abs/src/payments/fee.sh' '../x' '..' '.' './../x' 'src/../../x' \
            'docs/a.md ../x' 'a/..'; do
    # shellcheck disable=SC2086  # the words are split on purpose
    rk "$rk0" $args
    [ "$rk_rc" -eq 1 ] && rk_noloop && case "$rk_out" in *Usage*|*usage*) true ;; *) false ;; esac \
      && ok "risk: usage error '$args' exits 1, says how to use it, prints no loop: line" \
      || bad "risk usage '$args'" "rc=$rk_rc, got: $rk_out"
done

# 11: the change cannot lower its own review. A change to the profile is a full loop whatever the
# profile then says, and the list the base had is in the union: HEAD for --staged, <a> for --range,
# so a staged, an unstaged or a deleted profile cannot empty the list that judges the change.
# rk_self <label>: the last run exited 0, named the profile first, gave a reason on a second line,
# and ended on loop: full.
rk_self() {
    [ "$rk_rc" -eq 0 ] \
      && [ "$(printf '%s\n' "$rk_out" | sed -n 1p)" = ".keel/profile.json" ] \
      && printf '%s\n' "$rk_out" | sed -n 2p | grep -q '^keel: .*profile' \
      && [ "$(printf '%s\n' "$rk_out" | tail -1)" = "loop: full" ] \
      && ok "risk: $1" || bad "risk $1" "rc=$rk_rc, got: $rk_out"
}
rk7="$d/rk7"; rkrepo "$rk7" 'src/payments'
rkstage "$rk7" src/payments/fee.sh
printf '{"hard_block_paths":[]}\n' > "$rk7/.keel/profile.json" || bad "fixture profile" "write failed in $rk7"
( cd "$rk7" && git add -- .keel/profile.json ) || bad "fixture stage" "git add failed in $rk7"
for where in "$rk7" "$rk7/src/ui"; do
    rk "$where"
    rk_self "a staged payments change with a staged empty list is full, naming the profile (run in ${where#"$d"/})"
done
rk7b="$d/rk7b"; rkrepo "$rk7b" 'src/payments'
rkstage "$rk7b" src/payments/fee.sh
printf '{"hard_block_paths":[]}\n' > "$rk7b/.keel/profile.json" || bad "fixture profile" "write failed in $rk7b"
rk "$rk7b"
[ "$rk_rc" -eq 0 ] && [ "$rk_out" = "src/payments/fee.sh${nl}loop: full" ] \
  && ok "risk: an unstaged edit that empties the list does not lower a staged change (reads HEAD's list)" \
  || bad "risk unstaged profile edit" "rc=$rk_rc, got: $rk_out"
rk7c="$d/rk7c"; rkrepo "$rk7c" 'src/payments'
rkstage "$rk7c" src/payments/fee.sh
( cd "$rk7c" && git rm -q -f .keel/profile.json ) || bad "fixture delete" "git rm failed in $rk7c"
rk "$rk7c"
rk_self "a staged deletion of the profile with a payments change is full, naming the profile"
rk7d="$d/rk7d"; rkrepo "$rk7d" 'src/payments'
printf '{"hard_block_paths":[]}\n' > "$rk7d/.keel/profile.json" || bad "fixture profile" "write failed in $rk7d"
( cd "$rk7d" && git add -- .keel/profile.json ) || bad "fixture stage" "git add failed in $rk7d"
rk "$rk7d"
rk_self "a staged change to the profile alone is full, naming the profile"
rk "$rk0" .keel/profile.json
rk_self "the profile named as an explicit path is full, naming the profile"
rk "$rk0" src/ui/form.ts ./.keel//profile.json
rk_self "the profile named as ./.keel//profile.json is full, naming the profile"

rk7e="$d/rk7e"; rkrepo "$rk7e" 'src/payments'
rkstage "$rk7e" src/payments/fee.sh docs/a.md
printf '{"hard_block_paths":[]}\n' > "$rk7e/.keel/profile.json" || bad "fixture profile" "write failed in $rk7e"
rcommit "$rk7e" "2026-10-16T10:00:00+0000" "fee, and the list emptied"
rk "$rk7e" --range HEAD~1..HEAD
rk_self "a range that changes the profile is full, naming the profile"
rk7f="$d/rk7f"; rkrepo "$rk7f" 'src/payments'
rkstage "$rk7f" src/payments/fee.sh
rcommit "$rk7f" "2026-10-16T10:00:00+0000" "fee"
printf '{"hard_block_paths":[]}\n' > "$rk7f/.keel/profile.json" || bad "fixture profile" "write failed in $rk7f"
rk "$rk7f" --range HEAD~1..HEAD
[ "$rk_rc" -eq 0 ] && [ "$rk_out" = "src/payments/fee.sh${nl}loop: full" ] \
  && ok "risk: --range reads the list as the base had it, not the working tree's" \
  || bad "risk range reads base" "rc=$rk_rc, got: $rk_out"

# No HEAD and no profile is no list. A root profile in the working tree that HEAD lacks is read
# (case 6b), and a repository with neither has nothing declared.
rk7g2="$d/rk7g2"; rrepo "$rk7g2"; rkstage "$rk7g2" src/payments/fee.sh
rk "$rk7g2"
[ "$rk_rc" -eq 0 ] && [ "$rk_out" = "no hard_block_paths declared${nl}loop: light" ] \
  && ok "risk: a repository with no commit and no profile has no list, so no list" \
  || bad "risk no HEAD" "rc=$rk_rc, got: $rk_out"

# A profile that exists in any form and cannot be read is not an absent one.
rk8="$d/rk8"; rkrepo "$rk8" 'src/payments'
rm -f "$rk8/.keel/profile.json" && ln -s nowhere.json "$rk8/.keel/profile.json" \
  || bad "fixture symlink" "could not link the profile in $rk8"
rk "$rk8" docs/a.md
[ "$rk_rc" -eq 3 ] && rk_noloop && case "$rk_out" in *".keel/profile.json"*) true ;; *) false ;; esac \
  && ok "risk: a dangling profile symlink exits 3 naming it, paths mode" \
  || bad "risk dangling profile" "rc=$rk_rc, got: $rk_out"
rk8b="$d/rk8b"; rkrepo "$rk8b" 'src/payments'
rm -rf "$rk8b/.keel" && ln -s nowhere "$rk8b/.keel" || bad "fixture symlink" "could not link .keel in $rk8b"
rk "$rk8b" docs/a.md
[ "$rk_rc" -eq 3 ] && rk_noloop \
  && ok "risk: a dangling .keel symlink exits 3, paths mode" \
  || bad "risk dangling .keel" "rc=$rk_rc, got: $rk_out"
rk8c="$d/rk8c"; rkrepo "$rk8c" 'src/payments'; rkprofile "$rk8c" -
ln -s nowhere.json "$rk8c/.keel/profile.json" || bad "fixture symlink" "could not link in $rk8c"
rcommit "$rk8c" "2026-10-16T09:40:00+0000" "dangling profile"
rkstage "$rk8c" docs/a.md
rk "$rk8c"
[ "$rk_rc" -eq 3 ] && rk_noloop && case "$rk_out" in *".keel/profile.json"*) true ;; *) false ;; esac \
  && ok "risk: a profile symlink at HEAD exits 3 naming it, --staged" \
  || bad "risk symlink at HEAD" "rc=$rk_rc, got: $rk_out"
rk8d="$d/rk8d"; rkrepo "$rk8d" 'src/payments'; rkprofile "$rk8d" -
printf '{"hard_block_paths":[]}\n' > "$rk8d/other.json" && ln -s ../other.json "$rk8d/.keel/profile.json" \
  || bad "fixture symlink" "could not link in $rk8d"
rcommit "$rk8d" "2026-10-16T09:40:00+0000" "linked profile"
rkstage "$rk8d" docs/a.md
rk "$rk8d"
[ "$rk_rc" -eq 3 ] && rk_noloop \
  && ok "risk: a profile symlink at HEAD is not followed, so it exits 3, --staged" \
  || bad "risk linked profile at HEAD" "rc=$rk_rc, got: $rk_out"

# Paths are root-relative; the usage errors for those that are not are in case 9. A name that only
# begins with two dots is an ordinary name.
rk "$rk0" ..hidden/x
[ "$rk_rc" -eq 0 ] && [ "$rk_out" = "loop: light" ] \
  && ok "risk: a name that merely begins with two dots is an ordinary path" \
  || bad "risk ..name" "rc=$rk_rc, got: $rk_out"

# A name with a newline in it cannot plant a loop: line. Control characters are printed escaped.
rk9="$d/rk9"; rkrepo "$rk9" 'evil*' 'loop*'
evil="evil${nl}loop: light"
rk "$rk9" "$evil" 'loop: light'
[ "$rk_rc" -eq 0 ] && [ "$(printf '%s\n' "$rk_out" | tail -1)" = "loop: full" ] \
  && ! printf '%s\n' "$rk_out" | grep -qxF 'loop: light' \
  && printf '%s\n' "$rk_out" | grep -qxF 'evil\nloop: light' \
  && ok "risk: a path with a newline prints escaped, and no path line reads as a loop: line" \
  || bad "risk newline path" "rc=$rk_rc, got: $rk_out"
rkstage "$rk9" "$evil" 'loop: full' "tab${nl}x"
rk "$rk9"
[ "$rk_rc" -eq 0 ] && [ "$(printf '%s\n' "$rk_out" | tail -1)" = "loop: full" ] \
  && [ "$(printf '%s\n' "$rk_out" | grep -c '^loop:')" -eq 1 ] \
  && printf '%s\n' "$rk_out" | grep -qxF 'evil\nloop: light' \
  && ok "risk: --staged prints such names escaped too, one loop: line, the last" \
  || bad "risk newline staged" "rc=$rk_rc, got: $rk_out"

# git failing with nothing on stderr leaves no dangling colon.
fakegit="$d/fakegit"; mkdir -p "$fakegit"
printf '#!/bin/bash\nfor a in "$@"; do [ "$a" = diff ] && exit 1; done\nexec %s "$@"\n' "$(command -v git)" \
  > "$fakegit/git" && chmod +x "$fakegit/git" || bad "fixture fake git" "could not write it"
rk_out="$(cd "$rk3" && PATH="$fakegit:$PATH" "$KEEL" plan risk --staged 2>&1)"; rk_rc=$?
[ "$rk_rc" -eq 6 ] && rk_noloop && case "$rk_out" in *" "|*:) false ;; *) true ;; esac \
  && ok "risk: git failing silently exits 6 with no trailing colon" \
  || bad "risk silent git failure" "rc=$rk_rc, got: [$rk_out]"

# keel's own repository has a profile at the root and twelve tracked fixture profiles below it, and
# the union must still decide: docs/README.md is light, and the hook's own file is full. Paths are
# named, so nothing here reads the index or the history.
if [ "$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null)" = "$(cd "$ROOT" && pwd -P)" ] \
   && grep -q '"hooks"' "$ROOT/.keel/profile.json" 2>/dev/null; then
    rk "$ROOT" docs/README.md
    rk_light "keel's own repository, with its nested fixture profiles, is light for docs/README.md"
    rk "$ROOT" hooks/sensitive-guard
    rk_full "keel's own repository is full for hooks/sensitive-guard" hooks/sensitive-guard
else
    printf '  SKIP  risk: keel'"'"'s own repository (not a git checkout declaring hooks)\n'
fi

# 10: the report carries the loop beside rounds and routing, anchored the same way.
rl="$d/rloop"; rrepo "$rl"; pl="$rl/plan.md"
{ printf '# A plan\n\n'
  printf '### Task %s: t\n\n- [ ] **Step %s.1: s**\n\n' 1 1 2 2 3 3 4 4 5 5 6 6 7 7; } > "$pl"
rcommit "$rl" "2026-10-16T09:00:00+0000" "add"
"$KEEL" plan tick "$pl" 1.1 --note 'rounds: 1; routing: keel-implementer; loop: light' >/dev/null
"$KEEL" plan tick "$pl" 2.1 --note 'rounds: 2; routing: inherit; loop: full' >/dev/null
"$KEEL" plan tick "$pl" 3.1 --note 'rounds: 1; routing: x' >/dev/null
"$KEEL" plan tick "$pl" 4.1 --note 'see loop: full above; subloop: full' >/dev/null
"$KEEL" plan tick "$pl" 5.1 --note 'loop: light; loop: full' >/dev/null
"$KEEL" plan tick "$pl" 6.1 --note 'loop: heavy' >/dev/null
rcommit "$rl" "2026-10-16T10:00:00+0000" "tick six"
out="$("$KEEL" plan report "$pl" 2>&1)"; rc=$?
t="done 2026-10-16T10:00:00Z"
[ "$rc" -eq 0 ] \
  && printf '%s\n' "$out" | grep -qxF "task 1: $t, rounds 1, routing keel-implementer, loop light" \
  && printf '%s\n' "$out" | grep -qxF "task 2: $t, rounds 2, routing inherit, loop full" \
  && ok "report prints , loop light or , loop full after routing when the done step's note has it" \
  || bad "report loop" "rc=$rc, got: $out"
printf '%s\n' "$out" | grep -qxF "task 3: $t, rounds 1, routing x" \
  && ok "report prints no loop for a task whose notes hold none" \
  || bad "report no loop" "got: $out"
printf '%s\n' "$out" | grep -qxF "task 4: $t, rounds unknown, routing unknown" \
  && ok "report does not read loop: from prose or from subloop:" \
  || bad "report loop anchoring" "got: $out"
printf '%s\n' "$out" | grep -qxF "task 5: $t, rounds unknown, routing unknown, loop full" \
  && ok "report takes the last loop: in the note" \
  || bad "report last loop" "got: $out"
printf '%s\n' "$out" | grep -qxF "task 6: $t, rounds unknown, routing unknown" \
  && ok "report ignores a loop that is neither light nor full" \
  || bad "report loop value" "got: $out"
printf '%s\n' "$out" | grep -qxF "task 7: open" \
  && ok "report prints an open task as open, with no loop" \
  || bad "report open task loop" "got: $out"
js="$("$KEEL" plan report "$pl" --json 2>&1)"
[ "$(jget "$js" '[t["loop"] for t in d["tasks"]]')" = "['light', 'full', None, None, 'full', None, None]" ] \
  && ok "report --json carries loop, or null" \
  || bad "report json loop" "got: $js"

# ---- batches: which tasks of a plan may run at the same time -------------------------------------

# task <id> <depends> <file>...: one task section for `plan batches`. A depends of - writes no
# Depends on line, and no file writes no Files block, so each rule can be left out on its own.
task() {
    local id="$1" dep="$2" f; shift 2
    printf '### Task %s: a task\n\n' "$id"
    [ "$dep" = "-" ] || printf '**Depends on:** %s\n' "$dep"
    if [ "$#" -gt 0 ]; then
        printf '**Files:**\n'
        for f in "$@"; do printf -- '- Modify: `%s`\n' "$f"; done
    fi
    printf '\n'
}

# bt <plan>...: `keel plan batches` on the plan, its output and exit code in bt_out and bt_rc.
bt() { bt_out="$("$KEEL" plan batches "$@" 2>&1)"; bt_rc=$?; }
CHECK="check: in each batch, every Done when names only its task's own test, and each last step commits"
# The two reasons a line outside the strict form gets (behaviours 1 and 2).
SDEP="has a Depends on line not in the strict form, so its order is unknown"
SFILES="has a Files block not in the strict form, so its paths are unknown"

# 1, 2: tasks are read in plan order, and the example of the task prints as written.
p="$d/bt-example.md"
{ printf '# A plan\n\n## Tasks\n\n'
  task 1 none a.md; task 2 none b.md; task 3 'tasks 1 and 2' c.md; task 4 'tasks 1 and 3' d.md; } > "$p"
bt "$p"
want="$(printf '%s\n' 'batch: 1 2' 'alone: 3' 'alone: 4' \
  'why: task 3 depends on task 1 and task 2' 'why: task 4 depends on task 3' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: two free tasks batch, and a dependent runs after them, each dependency named once" \
  || bad "batches example" "rc=$bt_rc, got: $bt_out"

# The Depends on forms of the task, seen through which dependencies the reason names. Tasks 1 to 3
# are free and disjoint, so they share a batch and task 4 is held back by exactly what it names.
# The Depends on forms of the task, seen through which dependencies the reason names. Tasks 1 to 3
# are free and disjoint, so they share a batch and task 4 is held back by exactly what it names.
# Only the strict forms are read: the same ids written another way run the task alone (below).
for case_ in \
  'tasks 1 and 2|task 1 and task 2' \
  'tasks 3 and 1|task 1 and task 3' \
  'tasks 1 to 3|task 1, task 2 and task 3' \
  'tasks 1, 2 and 3|task 1, task 2 and task 3' \
  'tasks 1, 2, and 3|task 1, task 2 and task 3' \
  'tasks 1, 2 and 3.|task 1, task 2 and task 3' \
  'Tasks 1 and 3|task 1 and task 3' \
  'TASK 2|task 2' \
  'task 3.|task 3' \
  '  task 1  |task 1'; do
    dep="${case_%%|*}"; reason="${case_#*|}"
    p="$d/bt-dep.md"
    { task 1 none a.md; task 2 none b.md; task 3 none c.md; task 4 "$dep" d.md; } > "$p"
    bt "$p"
    printf '%s\n' "$bt_out" | grep -qxF "why: task 4 depends on $reason" \
      && ok "batches: Depends on '$dep' names $reason" \
      || bad "batches depends form $dep" "rc=$bt_rc, got: $bt_out"
done
p="$d/bt-dep-many.md"
{ task 1 none a.md; task 2 none b.md; task 3 none c.md; task 4 none d.md; task 5 none e.md
  task 6 'tasks 1, 2, 3 and 4' f.md; } > "$p"
bt "$p"
want="$(printf '%s\n' 'batch: 1 2 3 4 5' 'alone: 6' \
  'why: task 6 depends on task 1, task 2, task 3 and task 4' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: any number of ids before 'and' are read, and an unnamed task is not a dependency" \
  || bad "batches many ids" "rc=$bt_rc, got: $bt_out"
p="$d/bt-dep0.md"
{ task 0 none a.md; task 4 none b.md; task 5 none c.md; task 6 'tasks 0 to 5' d.md; } > "$p"
bt "$p"
printf '%s\n' "$bt_out" | grep -qxF "why: task 6 depends on task 0, task 4 and task 5" \
  && ok "batches: 'tasks 0 to 5' is every task between them in plan order, ids need not be consecutive" \
  || bad "batches tasks 0 to 5" "rc=$bt_rc, got: $bt_out"
p="$d/bt-dep-missing.md"
{ task 1 none a.md; task 2 'tasks 1 to 9' b.md; } > "$p"
bt "$p"
want="$(printf '%s\n' 'alone: 1' 'alone: 2' \
  'why: task 2 depends on task 9, which this plan does not have above it' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a range ending at a task the plan does not have runs alone, naming it" \
  || bad "batches range to a missing task" "rc=$bt_rc, got: $bt_out"
# A range written with a hyphen runs its task alone: read as its first task only, task 3 here
# would batch with task 2, which it depends on.
p="$d/bt-hyphen.md"
{ task 1 none a.md; task 2 'task 1' b.md; task 3 'tasks 1-2' c.md; } > "$p"
bt "$p"
want="$(printf '%s\n' 'alone: 1' 'alone: 2' 'alone: 3' 'why: task 2 depends on task 1' \
  'why: task 3 has a Depends on line not in the strict form, so its order is unknown' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a task depending on 'tasks 1-2' runs alone, so never batches with task 2" \
  || bad "batches hyphen range" "rc=$bt_rc, got: $bt_out"
# Every other separator between two ids is not in the strict form either, so the task runs alone
# and never batches with task 2. An en or em dash is built with a printf escape so this file holds
# no literal dash. It runs under a UTF-8 locale, where macOS awk's byte-wise substr splits a dash
# and a regex match on the lone byte is fatal, which a C locale hides. The locale is the first of
# C.UTF-8 and en_US.UTF-8 that the machine has, because macOS may lack C.UTF-8, and a locale that
# does not exist falls back to C without a word. A locale exists when its charmap reads UTF-8.
# With neither, each case whose separator holds a non-ASCII byte is skipped by name, because under
# C it would pass for the wrong reason; the ASCII separators still run, under C, since they do
# not depend on the locale.
dash_loc=""
for dash_try in C.UTF-8 en_US.UTF-8; do
    if [ "$(LC_ALL=$dash_try locale charmap 2>/dev/null)" = "UTF-8" ]; then
        dash_loc="$dash_try"; break
    fi
done
unset dash_try
for dep in "$(printf 'tasks 1\342\200\2232')" "$(printf 'tasks 1\342\200\2242')" 'tasks 1..2' \
  'tasks 1~2' 'tasks 1; 2' 'tasks 1 or 2' 'tasks 1 and/or 2' 'tasks 1 through 2' 'tasks 1 thru 2' \
  'tasks 1 & 2' 'tasks 1/2' 'tasks 1, 2' 'tasks 1 - 2'; do
    if [ -z "$dash_loc" ] && [ -n "$(printf '%s' "$dep" | LC_ALL=C tr -d '\000-\177')" ]; then
        printf '  SKIP  batches separator %s: needs UTF-8, and neither %s nor %s exists here\n' \
          "'$dep'" C.UTF-8 en_US.UTF-8
        continue
    fi
    p="$d/bt-sep.md"
    { task 1 none a.md; task 2 'task 1' b.md; task 3 "$dep" c.md; } > "$p"
    LC_ALL=${dash_loc:-C} bt "$p"
    want="$(printf '%s\n' 'alone: 1' 'alone: 2' 'alone: 3' 'why: task 2 depends on task 1' \
      "why: task 3 $SDEP" "$CHECK")"
    [ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
      && ok "batches: a task depending on '$dep' runs alone (LC_ALL=${dash_loc:-C})" \
      || bad "batches separator $dep (LC_ALL=${dash_loc:-C})" "rc=$bt_rc, got: $bt_out"
done
# none is no dependency only as the whole line, with surrounding spaces and one trailing period.
p="$d/bt-none.md"
{ task 1 'none.' a.md; task 2 '  none  ' b.md; task 3 'task 1' c.md; } > "$p"
bt "$p"
[ "$(printf '%s\n' "$bt_out" | head -2 | tr '\n' '|')" = "batch: 1 2|alone: 3|" ] \
  && ok "batches: a Depends on of exactly none, with spaces or a trailing period, is none" \
  || bad "batches none" "rc=$bt_rc, got: $bt_out"
p="$d/bt-case.md"
{ task 1 none a.md; task 2A none b.md; task 3 'Tasks 1 and 2a' c.md; } > "$p"
bt "$p"
printf '%s\n' "$bt_out" | grep -qxF "why: task 3 depends on task 1 and task 2A" \
  && ok "batches: ids are digits then letters, compared without regard to case, shown as headed" \
  || bad "batches id case" "rc=$bt_rc, got: $bt_out"
p="$d/bt-letter.md"
{ task 1 none a.md; task 1b 'task 1' b.md; task 1c 'task 1' c.md; } > "$p"
bt "$p"
[ "$(printf '%s\n' "$bt_out" | head -2 | tr '\n' '|')" = "alone: 1|batch: 1b 1c|" ] \
  && ok "batches: a letter id such as 1b is a task, and tasks depending on one task batch together" \
  || bad "batches letter id" "rc=$bt_rc, got: $bt_out"
p="$d/bt-letter-list.md"
{ task 1 none a.md; task 1b none b.md; task 2A none c.md; task 3 'tasks 1b and 2A' d.md; } > "$p"
bt "$p"
want="$(printf '%s\n' 'batch: 1 1b 2A' 'alone: 3' 'why: task 3 depends on task 1b and task 2A' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: ids with letters read in the strict list form" \
  || bad "batches letter ids in a list" "rc=$bt_rc, got: $bt_out"

# An id on more than one heading, compared without case, names no one task, so every task with it
# runs alone, and so does a task depending on it, whose dependency cannot be resolved. Read as the
# first heading with that id, task 5 here would batch with the second, which it depends on.
SDUP="shares its id with another task, so its dependents cannot be placed"
p="$d/bt-dupcase.md"
{ task 1 none a.md; task 2A none b.md; task 3 'task 1' c.md; task 2a none d.md
  task 5 'task 2a' e.md; } > "$p"
bt "$p"
want="$(printf '%s\n' 'alone: 1' 'alone: 2A' 'alone: 3' 'alone: 2a' 'alone: 5' \
  "why: task 2A $SDUP" "why: task 2a $SDUP" \
   \
  'why: task 5 depends on task 2a, which more than one task has as its id, so its order is unknown' \
  "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: ids that differ only in case are one id, so each task with it runs alone" \
  || bad "batches duplicate id case" "rc=$bt_rc, got: $bt_out"
p="$d/bt-dup.md"
{ task 1 none a.md; task 2 none b.md; task 3 'task 1' c.md; task 2 none d.md
  task 5 'task 2' e.md; } > "$p"
bt "$p"
want="$(printf '%s\n' 'alone: 1' 'alone: 2' 'alone: 3' 'alone: 2' 'alone: 5' \
  "why: task 2 $SDUP" "why: task 2 $SDUP" \
  'why: task 5 depends on task 2, which more than one task has as its id, so its order is unknown' \
  "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a heading id written twice runs both alone, and a task depending on it" \
  || bad "batches duplicate id" "rc=$bt_rc, got: $bt_out"

# A heading the command does not read hides a task, which could then batch with a task that edits
# its files or runs before it, so every task in the plan runs alone, with one why naming the line.
# Task 3 here edits the hidden task's file. Lowercase, a deeper heading and a double space were safe
# before, by another rule, and are caught by this one too.
for h in '### Task 2 - b' '## Task 2: b' '### Task 2. b' '### Task 2 : b' '### Task two: b' \
  '### Task: 2 b' '### task 2: b' '#### Task 2: b' '###  Task 2: b' '### TASK 2: b' \
  '  ### Task 2: b' '   ### Task 2: b' '> ### Task 2: b' '>### Task 2: b' ' > ## Task 2: b'; do
    p="$d/bt-heading.md"
    { task 1 none a.md
      printf '%s\n\n**Depends on:** none\n**Files:**\n- Modify: `b.md`\n\n' "$h"
      printf -- '**Done when:** x\n\n- [ ] **Step 2.1: do**\n\n'
      task 3 none b.md; } > "$p"
    bt "$p"
    want="$(printf '%s\n' 'alone: 1' 'alone: 3' \
      "why: the heading '$h' is not one this command reads, so every task runs alone, since a task it cannot see could run out of order" \
      "$CHECK")"
    [ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
      && ok "batches: an unread heading '$h' runs every task alone" \
      || bad "batches unread heading $h" "rc=$bt_rc, got: $bt_out"
done
HIDWHY="is not one this command reads, so every task runs alone, since a task it cannot see could"
HIDWHY="$HIDWHY run out of order"
# A tab after the #s still makes a heading, as CommonMark has it, so `###<TAB>Task 2: two` is a
# task this reader does not read. In r2 task 3 edits the hidden task 2's file and batched with task
# 4; in q3 the hidden heading is followed by no Files block, and tasks 1 and 3 batched.
p="$d/bt-tab-r2.md"
printf '%s\n' '# P' '' '### Task 1: one' '' '**Files:**' '- Modify: `src/a.js`' '' \
  '**Depends on:** none' '' '**Done when:** x' '' '- [ ] **Step 1.1: do**' '' $'###\tTask 2: two' \
  '' '**Files:**' '- Modify: `src/b.js`' '' '**Depends on:** task 1' '' '**Done when:** x' '' \
  '- [ ] do it' '' '### Task 3: three' '' '**Files:**' '- Modify: `src/b.js`' '' \
  '**Depends on:** none' '' '**Done when:** x' '' '- [ ] **Step 3.1: do**' '' '### Task 4: four' \
  '' '**Files:**' '- Modify: `src/c.js`' '' '**Depends on:** none' '' '**Done when:** x' '' \
  '- [ ] **Step 4.1: do**' > "$p"
bt "$p"
want="$(printf '%s\n' 'alone: 1' 'alone: 3' 'alone: 4' "why: the heading '"$'###\tTask 2: two'"' $HIDWHY" \
  "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a task heading with a tab after its #s runs every task alone (r2)" \
  || bad "batches tab heading r2" "rc=$bt_rc, got: $bt_out"
p="$d/bt-tab-q3.md"
printf '%s\n' '# P' '' '### Task 1: one' '' '**Files:**' '- Modify: `src/a.js`' '' \
  '**Depends on:** none' '' $'###\tTask 2: two' '' '**Steps:** none' '' '**Done when:** x' '' \
  '- [ ] **Step 1.1: do**' '' '### Task 3: three' '' '**Files:**' '- Modify: `src/b.js`' '' \
  '**Depends on:** none' '' '**Done when:** x' '' '- [ ] **Step 3.1: do**' > "$p"
bt "$p"
want="$(printf '%s\n' 'alone: 1' 'alone: 3' "why: the heading '"$'###\tTask 2: two'"' $HIDWHY" \
  "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a task heading with a tab after its #s runs every task alone (q3)" \
  || bad "batches tab heading q3" "rc=$bt_rc, got: $bt_out"
# Case, up to three leading spaces and a quote do not hide a heading from the check either: in
# these two plans task 3 edits the hidden task 2's file, and before the check saw them it batched
# beside it.
p="$d/bt-upper.md"
printf '%s\n' '# P' '' '### Task 1: t' '' '**Depends on:** none' '**Files:**' '- Modify: `a.sh`' \
  '' '**Done when:** x' '' '- [ ] **Step 1.1: do**' '' '### TASK 2: t' '' '**Depends on:** task 1' \
  '**Files:**' '- Modify: `c.sh`' '' '### Task 3: t' '' '**Depends on:** none' '**Files:**' \
  '- Modify: `c.sh`' '' '**Done when:** x' '' '- [ ] **Step 3.1: do**' '' '### Task 4: t' '' \
  '**Depends on:** none' '**Files:**' '- Modify: `d.sh`' '' '**Done when:** x' '' \
  '- [ ] **Step 4.1: do**' > "$p"
bt "$p"
want="$(printf '%s\n' 'alone: 1' 'alone: 3' 'alone: 4' \
  "why: the heading '### TASK 2: t' $HIDWHY" \
  "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: an upper-case task heading runs every task alone" \
  || bad "batches upper-case heading" "rc=$bt_rc, got: $bt_out"
p="$d/bt-bq.md"
printf '%s\n' '# P' '' '### Task 1: t' '' '**Depends on:** none' '**Files:**' '- Modify: `a.sh`' \
  '' '**Done when:** x' '' '- [ ] **Step 1.1: do**' '' '> ### Task 2: t' '>' \
  '> **Depends on:** task 1' \
  '> **Files:**' '> - Modify: `c.sh`' '>' '> - [ ] **Step 2.1: do**' '' '### Task 3: t' '' \
  '**Depends on:** none' '**Files:**' '- Modify: `c.sh`' '' '**Done when:** x' '' \
  '- [ ] **Step 3.1: do**' > "$p"
bt "$p"
want="$(printf '%s\n' 'alone: 1' 'alone: 3' \
  "why: the heading '> ### Task 2: t' $HIDWHY" \
  "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a task heading inside a quote runs every task alone" \
  || bad "batches quoted heading" "rc=$bt_rc, got: $bt_out"
# A step whose task has no heading the command reads is a task it cannot see, for the same reason.
p="$d/bt-orphan-step.md"
{ task 1 none a.md
  printf '**Task 2: b**\n\n**Done when:** x\n\n- [ ] **Step 2.1: do**\n\n'
  task 3 none b.md; } > "$p"
bt "$p"
want="$(printf '%s\n' 'alone: 1' 'alone: 3' \
  "why: step 2.1 names task 2, which has no heading this command reads, so every task runs alone, since a task it cannot see could run out of order" \
  "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a step whose task has no heading runs every task alone" \
  || bad "batches orphan step" "rc=$bt_rc, got: $bt_out"
bt "$p" --json
case "$bt_out" in *'"why": [{"task": "", "reason": "step 2.1 names task 2, '*) true ;; *) false ;; esac \
  && ok "batches --json: a reason for the whole plan has an empty task" \
  || bad "batches orphan step json" "rc=$bt_rc, got: $bt_out"
# A step and a heading the command reads, ids differing only in case, are one task.
p="$d/bt-step-case.md"
{ printf '### Task 1A: a task\n\n**Depends on:** none\n**Files:**\n- Modify: `a.md`\n\n'
  printf -- '**Done when:** x\n\n- [ ] **Step 1a.1: do**\n\n'; task 2 none b.md; } > "$p"
bt "$p"
want="$(printf '%s\n' 'batch: 1A 2' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a step id matches its heading without regard to case" \
  || bad "batches step id case" "rc=$bt_rc, got: $bt_out"

# A range is every task whose number lies between its ends as well as every task between them in
# plan order, because plans are not always in number order. Here task 2 sits below task 3, and
# read in plan order alone task 4 would batch with task 2, which it depends on.
p="$d/bt-range-order.md"
{ task 1 none a.md; task 3 none b.md; task 2 'task 3' c.md; task 4 'tasks 1 to 3' d.md; } > "$p"
bt "$p"
want="$(printf '%s\n' 'batch: 1 3' 'alone: 2' 'alone: 4' 'why: task 2 depends on task 3' \
  'why: task 4 depends on task 2' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a range takes every task numbered between its ends, wherever it is in the plan" \
  || bad "batches range number order" "rc=$bt_rc, got: $bt_out"
# A task numbered inside the range but below the task cannot be a dependency it waits for, so the
# range's meaning is not known and the task runs alone.
p="$d/bt-range-below.md"
{ task 1 none a.md; task 3 none b.md; task 4 'tasks 1 to 3' d.md; task 2 none c.md; } > "$p"
bt "$p"
want="$(printf '%s\n' 'batch: 1 3' 'alone: 4' 'alone: 2' \
  'why: task 4 has a range that reaches a task below it, so its order is unknown' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a range that reaches a task below its own runs alone" \
  || bad "batches range below" "rc=$bt_rc, got: $bt_out"

# Section edges: a fenced heading and label are examples, and the next heading ends a section, so
# the Depends on line under it is not task 2's second one.
p="$d/bt-edges.md"
{ printf '# A plan\n\n```\n### Task 9: an example\n```\n\n'
  task 1 none a.md; task 2 none b.md
  printf '## What this plan does not build\n\n**Depends on:** task 1\n\n'; } > "$p"
bt "$p"
want="$(printf '%s\n' 'batch: 1 2' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a fenced heading is no task, and a later ## section is not read into the last task" \
  || bad "batches section edges" "rc=$bt_rc, got: $bt_out"
# A fence that never closes hides every line after it, so a task after it cannot be seen and could
# run beside one it depends on or shares a file with: every task runs alone, under one why naming
# the line that opens the fence, and --json carries it with an empty task. Before this read tasks 1
# and 2 batched and task 3, which shares a.sh with task 1, was not scheduled at all. The fence opens
# at column 0, then indented after a paragraph, where no list item bounds it.
for fence in '```bash' '  ```bash'; do
    p="$d/bt-unclosed.md"
    { task 1 none a.sh; task 2 none b.sh
      printf '**Done when:** x\n\nExample:\n\n%s\nmake\n\n' "$fence"; task 3 none a.sh; } > "$p"
    ln="$(grep -n -xF -e "$fence" "$p" | head -1 | cut -d: -f1)"
    why="the fence opened at line $ln, '$fence', never closes, so every task runs alone, since a"
    why="$why task it hides could run out of order"
    bt "$p"
    want="$(printf '%s\n' 'alone: 1' 'alone: 2' "why: $why" "$CHECK")"
    [ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
      && ok "batches: a fence that never closes runs every task alone ($fence)" \
      || bad "batches unclosed fence $fence" "rc=$bt_rc, got: $bt_out"
    bt "$p" --json
    case "$bt_out" in
      *'"why": [{"task": "", "reason": "'"$why"'"}]'*)
        ok "batches --json: a fence that never closes is one reason with an empty task ($fence)" ;;
      *) bad "batches --json unclosed fence $fence" "rc=$bt_rc, got: $bt_out" ;;
    esac
done
# A Files-like line after the first task heading but outside every task's section, as under a ##
# heading between two tasks or after the last, names paths the reader cannot give to one task, so
# every task runs alone, under one why naming the line. Before this read tasks 1 and 2 batched,
# though the first form gives task 1 the file task 2 modifies.
for orphan in '**Files:**|- Modify: `b.sh`' '- Modify: `b.sh`' '> **Test files:** `b.sh`'; do
    for where in between after; do
        p="$d/bt-orphan-files.md"
        { printf '# P\n\n## Phase 1\n\n'; task 1 none a.sh
          [ "$where" = after ] && task 2 none b.sh
          printf '## Phase 1 notes\n\n'; printf '%s\n' "$orphan" | tr '|' '\n'; printf '\n'
          [ "$where" = between ] && { printf '## Phase 2\n\n'; task 2 none b.sh; }; } > "$p"
        bt "$p"
        first="${orphan%%|*}"
        why="why: the line '$first' names files outside any task, so every task runs alone,"
        why="$why since this command cannot tell which task it belongs to"
        want="$(printf '%s\n' 'alone: 1' 'alone: 2' "$why" "$CHECK")"
        [ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
          && ok "batches: a Files line outside any task ($where) runs every task alone ($orphan)" \
          || bad "batches orphan files $where $orphan" "rc=$bt_rc, got: $bt_out"
    done
done
p="$d/bt-fenced-label.md"
{ printf '### Task 1: a task\n\n```\n**Depends on:** none\n**Files:**\n- `a.md`\n```\n\n'
  task 2 none b.md; } > "$p"
bt "$p"
printf '%s\n' "$bt_out" | grep -qxF "why: task 1 has no Depends on line, so its order is unknown" \
  && ok "batches: a Depends on line inside a fenced block is an example, never read" \
  || bad "batches fenced label" "rc=$bt_rc, got: $bt_out"
# The fence reader is shared with status: a nested fence line indented four columns is content,
# so task 2 is seen and task 3 never batches before it; a ``` in an indented code block opens none.
p="$d/bt-fence4.md"
fence4_plan "$p"
bt "$p"
want="$(printf '%s\n' 'alone: 1' 'alone: 2' 'alone: 3' 'why: task 2 depends on task 1' \
  'why: task 3 shares c.sh with task 2' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a fence nested four columns deep hides no task, so task 3 runs after task 2" \
  || bad "batches nested fence" "rc=$bt_rc, got: $bt_out"
p="$d/bt-icb.md"
icb_plan "$p"
bt "$p"
want="$(printf '%s\n' 'alone: 1' 'alone: 2' 'batch: 3 4' 'why: task 2 depends on task 1' \
  'why: task 3 shares c.sh with task 2' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a fence line in an indented code block opens no fence, so no task is hidden" \
  || bad "batches indented code block" "rc=$bt_rc, got: $bt_out"
p="$d/bt-closer4.md"
closer4_plan "$p"
bt "$p"
want="$(printf '%s\n' 'alone: 1' 'alone: 2' 'alone: 3' 'why: task 2 depends on task 1' \
  'why: task 3 shares c.sh with task 2' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a closer indented four columns outside a list item hides no task" \
  || bad "batches closer indented four" "rc=$bt_rc, got: $bt_out"
# A fence opened inside a list item ends with the item (see itemfence_plan), so task 2 is seen: it
# runs after task 1, and task 3, which shares src/b.js with it, never batches with task 1 before it.
for v in b c; do
    p="$d/bt-itemfence-$v.md"
    itemfence_plan "$p" "$v"
    bt "$p"
    want="$(printf '%s\n' 'alone: 1' 'alone: 2' 'alone: 3' 'why: task 2 depends on task 1' \
      'why: task 3 shares src/b.js with task 2' "$CHECK")"
    [ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
      && ok "batches: a fence opened inside a list item hides no task ($v)" \
      || bad "batches item fence $v" "rc=$bt_rc, got: $bt_out"
done

# The Files block (behaviour 2): from the label to the next blank line, **Label:** line or section
# end. Task 1 names its path in a list item, task 2 has prose after the blank line, task 3's block
# is ended by the label under it, and task 4's by a blank line before that label, so the prose and
# the Interfaces lists are not read as paths.
p="$d/bt-files.md"
{ printf '### Task 1: a task\n\n**Depends on:** none\n**Files:**\n- Modify: `a.md`\n\n'
  printf '### Task 2: a task\n\n**Depends on:** none\n**Files:**\n- Modify: `b.md`\n\nProse naming `a.md`.\n\n'
  printf '### Task 3: a task\n\n**Depends on:** none\n**Files:**\n- Modify: `c.md`\n**Interfaces:**\n- Uses `a.md`\n\n'
  printf '### Task 4: a task\n\n**Depends on:** none\n**Files:**\n- Modify: `d.md`\n\n**Interfaces:**\n- Uses `a.md`\n\n'; } > "$p"
bt "$p"
want="$(printf '%s\n' 'batch: 1 2 3 4' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: the Files block ends at a blank line or a ** label, and what follows is not read" \
  || bad "batches files block extent" "rc=$bt_rc, got: $bt_out"
p="$d/bt-files-same.md"
{ task 1 none a.md; task 2 none a.md; } > "$p"
bt "$p"
printf '%s\n' "$bt_out" | grep -qxF "why: task 2 shares a.md with task 1" \
  && ok "batches: a path in a Files list item counts" \
  || bad "batches files list item" "rc=$bt_rc, got: $bt_out"

# ftask <id> <depends> <line>...: a task whose Files block is the given lines as written, one per
# argument, so a form task() would never write can be tried. fstrict and floose put it beside the
# clean task 1: a strict block batches with it, and one that is not runs alone with the Files why.
ftask() {
    local id="$1" dep="$2" l; shift 2
    printf '### Task %s: a task\n\n**Depends on:** %s\n**Files:**\n' "$id" "$dep"
    for l in "$@"; do printf '%s\n' "$l"; done
    printf '\n'
}
fstrict() {
    local label="$1" p="$d/bt-fs.md"; shift
    { task 1 none a.md; ftask 2 none "$@"; } > "$p"
    bt "$p"
    want="$(printf '%s\n' 'batch: 1 2' "$CHECK")"
    [ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
      && ok "batches: a Files block with $label is strict" \
      || bad "batches strict files $label" "rc=$bt_rc, got: $bt_out"
}
floose() {
    local label="$1" p="$d/bt-fl.md"; shift
    { task 1 none a.md; ftask 2 none "$@"; } > "$p"
    bt "$p"
    want="$(printf '%s\n' 'alone: 1' 'alone: 2' "why: task 2 $SFILES" "$CHECK")"
    [ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
      && ok "batches: a Files block with $label runs alone" \
      || bad "batches loose files $label" "rc=$bt_rc, got: $bt_out"
}
fstrict 'one path' '- Modify: `b.md`'
fstrict 'each of the five words' '- Create: `b.md`' '- Modify: `c.md`' '- Delete: `d.md`' \
  '- Test: `e.md`' '- Rename: `f.md`'
fstrict 'a parenthesised note before the colon' \
  '- Create (if the body cannot hold the detail): `b.md`'
fstrict 'paths separated by commas and a final and' '- Modify: `b.md`, `c.md` and `d.md`'
fstrict 'a comma before the final and' '- Modify: `b.md`, `c.md`, and `d.md`'
fstrict 'two paths joined by and' '- Modify: `b.md` and `c.md`'
fstrict 'a continuation line' '- Modify: `b.md`, `c.md`,' '  `d.md`'
fstrict 'a continuation line after and' '- Modify: `b.md`, `c.md` and' '  `d.md`'
fstrict 'a continuation line after a comma and and' '- Modify: `b.md`, `c.md`, and' '  `d.md`'
fstrict 'a continuation of several lines' '- Modify: `b.md`,' '  `c.md`,' '  `d.md`'
fstrict 'every allowed path character' '- Modify: `Lib/@scope+x/a_b-c.d.md`'
fstrict 'a hidden directory' '- Modify: `.hidden/x.md`'
fstrict 'trailing spaces on a line' '- Modify: `b.md`   '
fstrict 'a name that only starts with dots' '- Modify: `a/..b/.c/d.md`'
# A rename names both paths joined by `and`, so it batches with an unrelated task and shares with a
# task naming either path. Written with `to`, it is outside the form, so the task runs alone.
for rp in src/old.js src/new.js; do
    p="$d/bt-rename.md"
    { ftask 1 none '- Rename: `src/old.js` and `src/new.js`'; task 2 none b.md
      task 3 none "$rp"; } > "$p"
    bt "$p"
    want="$(printf '%s\n' 'batch: 1 2' 'alone: 3' "why: task 3 shares $rp with task 1" "$CHECK")"
    [ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
      && ok "batches: a rename joined by and batches, and shares $rp" \
      || bad "batches rename $rp" "rc=$bt_rc, got: $bt_out"
done
# The label alone, with trailing spaces, is the strict label line.
p="$d/bt-fs-label.md"
{ task 1 none a.md
  printf '### Task 2: a task\n\n**Depends on:** none\n**Files:**   \n- Modify: `b.md`\n\n'; } > "$p"
bt "$p"
[ "$(printf '%s\n' "$bt_out" | head -1)" = "batch: 1 2" ] \
  && ok "batches: a Files label with only spaces after it is the strict label line" \
  || bad "batches files label spaces" "rc=$bt_rc, got: $bt_out"

# Prose, notes, links and any word or separator outside the strict form.
floose 'prose' 'Edits b.md and c.md.'
floose 'prose before the list' 'These files change:' '- Modify: `b.md`'
floose 'a note after the path' '- Modify: `b.md` (new file)'
floose 'a note after the path with a line range' '- Modify: `b.md` (lines 3-9)'
floose 'a markdown link' '- Modify: [b.md](b.md)'
floose 'a path outside backticks' '- Modify: b.md'
floose 'a path with a link and backticks' '- Modify: [`b.md`](b.md)'
floose 'a word that is not one of the five' '- Update: `b.md`'
floose 'a lower case word' '- modify: `b.md`'
floose 'no word' '- `b.md`'
floose 'a star bullet' '* Modify: `b.md`'
floose 'an indented list item' '  - Modify: `b.md`'
floose 'no space after the colon' '- Modify:`b.md`'
floose 'two spaces after the colon' '- Modify:  `b.md`'
floose 'a space before the colon' '- Modify : `b.md`'
floose 'an empty note' '- Create (): `b.md`'
floose 'a nested note' '- Create (a (b)): `b.md`'
floose 'a note holding a path' '- Create (see `c.md`): `b.md`'
floose 'a note after the colon' '- Create: (see c.md) `b.md`'
floose 'a semicolon between paths' '- Modify: `b.md`; `c.md`'
floose 'and twice' '- Modify: `b.md` and `c.md` and `d.md`'
floose 'and before a comma' '- Modify: `b.md` and `c.md`, `d.md`'
floose 'no space after the comma' '- Modify: `b.md`,`c.md`'
floose 'a trailing comma and no continuation' '- Modify: `b.md`,'
floose 'a trailing and and no continuation' '- Modify: `b.md` and'
floose 'a dangling comma, and an unindented continuation' '- Modify: `b.md`,' '`c.md`'
floose 'a continuation after a complete line' '- Modify: `b.md`' '  `c.md`'
floose 'a continuation after and with two paths' '- Modify: `b.md` and' '  `c.md`, `d.md`'
floose 'a continuation that holds prose' '- Modify: `b.md`,' '  and `c.md`'
floose 'a continuation straight after the label' '  `b.md`'
floose 'a bold line' '**new** `b.md`'
floose 'a quoted list item' '> - Modify: `b.md`'
floose 'a space in a path' '- Modify: `b c.md`'
floose 'a colon in a path' '- Modify: `b.md:3`'
floose 'a # in a path' '- Modify: `b.md#phrase`'
floose 'a backslash in a path' '- Modify: `b\c.md`'
floose 'a brace in a path' '- Modify: `b{1}.md`'
floose 'a * in a path' '- Modify: `b*.md`'
floose 'a ? in a path' '- Modify: `b?.md`'
floose 'a [ in a path' '- Modify: `b[1].md`'
floose 'a comma in a path' '- Modify: `b,c.md`'
floose 'a parenthesis in a path' '- Modify: `b(1).md`'
floose 'a dollar in a path' '- Modify: `b$.md`'
floose 'a tilde in a path' '- Modify: `~/b.md`'
floose 'a non-ASCII letter in a path' "$(printf -- '- Modify: `caf\303\251.md`')"
floose 'a leading slash' '- Modify: `/b.md`'
floose 'a // in a path' '- Modify: `a//b.md`'
floose 'a /./ in a path' '- Modify: `a/./b.md`'
floose 'a /../ in a path' '- Modify: `a/../b.md`'
floose 'a leading ./' '- Modify: `./b.md`'
floose 'a leading ../' '- Modify: `../b.md`'
floose 'a trailing /.' '- Modify: `a/.`'
floose 'a path that is a dot' '- Modify: `.`'
floose 'a path that is two dots' '- Modify: `..`'
floose 'a trailing slash' '- Modify: `skills/x/`'
floose 'an empty path' '- Modify: ``'
floose 'an unclosed backtick' '- Modify: `b.md'
floose 'a fenced block inside it' '- Modify: `b.md`' '```' '- Modify: `c.md`' '```'
floose 'only prose and no list' 'Nothing is changed here.'
floose 'a rename written with to' '- Rename: `src/old.js` to `src/new.js`'
# A path on a continuation line counts toward sharing.
p="$d/bt-fs-share.md"
{ task 1 none d.md; ftask 2 none '- Modify: `b.md`, `c.md`,' '  `d.md`'; } > "$p"
bt "$p"
want="$(printf '%s\n' 'alone: 1' 'alone: 2' 'why: task 2 shares d.md with task 1' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a path on a continuation line is a path of the task" \
  || bad "batches continuation shares" "rc=$bt_rc, got: $bt_out"

# The label line carries nothing else, and a block that is ambiguous runs alone.
p="$d/bt-fl-label.md"
{ task 1 none a.md
  printf '### Task 2: a task\n\n**Depends on:** none\n**Files:** `b.md`\n\n'; } > "$p"
bt "$p"
want="$(printf '%s\n' 'alone: 1' 'alone: 2' "why: task 2 $SFILES" "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a path on the Files label's own line is not the strict form, so the task runs alone" \
  || bad "batches files label line" "rc=$bt_rc, got: $bt_out"
# A line outside the block that may name paths is quoted with its line number, so the writer can
# find it.
for item in '- Modify: `c.md`' '* Modify: `c.md`' '1. Modify: `c.md`' '  - Modify: `c.md`'; do
    p="$d/bt-fl-after-blank.md"
    { task 1 none a.md
      printf '### Task 2: a task\n\n**Depends on:** none\n**Files:**\n- Modify: `b.md`\n\n%s\n\n' "$item"; } > "$p"
    bt "$p"
    wantq="$(printf '%s\n' 'alone: 1' 'alone: 2' "why: task 2 $SFILES (line 13: '$item')" "$CHECK")"
    [ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$wantq" ] \
      && ok "batches: a list item after a blank line, before the next label, runs alone ($item)" \
      || bad "batches list after blank $item" "rc=$bt_rc, got: $bt_out"
done
p="$d/bt-fl-after-blank2.md"
{ task 1 none a.md
  printf '### Task 2: a task\n\n**Depends on:** none\n**Files:**\n- Modify: `b.md`\n\nA word.\n\n- Modify: `c.md`\n\n'; } > "$p"
bt "$p"
wantq="$(printf '%s\n' 'alone: 1' 'alone: 2' \
  "why: task 2 $SFILES (line 15: '- Modify: \`c.md\`')" "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$wantq" ] \
  && ok "batches: a list item after a blank line and prose still runs alone, until a label" \
  || bad "batches list after prose" "rc=$bt_rc, got: $bt_out"
p="$d/bt-fl-twofiles.md"
{ task 1 none a.md
  printf '### Task 2: a task\n\n**Depends on:** none\n**Files:**\n- Modify: `b.md`\n**Files:**\n- Modify: `c.md`\n\n'; } > "$p"
bt "$p"
wantq="$(printf '%s\n' 'alone: 1' 'alone: 2' "why: task 2 $SFILES (line 12: '**Files:**')" \
  "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$wantq" ] \
  && ok "batches: a second Files label runs the task alone, since its paths would be unread" \
  || bad "batches two files labels" "rc=$bt_rc, got: $bt_out"
# A second Files-like label, in any case, or a Files-like list item outside the Files block, holds
# paths the block does not, so the task runs alone, and the reason quotes the first such line with
# its number. In each plan task 1 also creates tests/shared.sh, which task 2 modifies, so read any
# other way it would batch beside task 2. Each case is the line number, a tab, and the lines after
# the Files block, joined by |, of which the first non-blank one at that number is quoted.
for case_ in $'8\t**Files (tests):**|- Create: `tests/shared.sh`' \
  $'9\t|**Test files:**|- Create: `tests/shared.sh`' \
  $'9\t|**test FILES:**|- Create: `tests/shared.sh`' \
  $'10\t|**Interfaces:**|- Create: `tests/shared.sh`' \
  $'10\t|**Interfaces:**|* modify (later): `tests/shared.sh`' \
  $'11\t|**Done when:** x||- Test: `tests/shared.sh` passes' \
  $'10\t|**Behaviours:**|1. Test: an empty list fails.' \
  $'10\t|**Behaviours:**|- Modify `tests/shared.sh`: also' \
  $'10\t|**Behaviours:**|- Test\t: `tests/shared.sh`' \
  $'10\t|**Interfaces:**|> **Files:** `tests/shared.sh`' $'9\t|> **Files:** `tests/shared.sh`' \
  $'10\t|**Interfaces:**|- **Files:** `tests/shared.sh`' \
  $'10\t|**Interfaces:**|> 1. **Test files:** x' \
  $'9\t|**File:**|- Create: `tests/shared.sh`'; do
    n="${case_%%$'\t'*}"; extra="${case_#*$'\t'}"
    p="$d/bt-files-extra.md"
    { printf '# P\n\n### Task 1: t\n\n**Depends on:** none\n**Files:**\n- Modify: `a.sh`\n'
      printf '%s\n' "$extra" | tr '|' '\n'
      printf '\n'; task 2 none tests/shared.sh; } > "$p"
    q="$(sed -n "${n}p" "$p")"
    wantq="$(printf '%s\n' 'alone: 1' 'alone: 2' "why: task 1 $SFILES (line $n: '$q')" "$CHECK")"
    bt "$p"
    [ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$wantq" ] \
      && ok "batches: a Files-like line outside the Files block runs the task alone ($extra)" \
      || bad "batches files-like line $extra" "rc=$bt_rc, got: $bt_out"
done
# A list item counts only when its word is exactly Create, Modify, Delete, Test or Rename, and so
# not followed by more letters, with a colon later on the line, so a longer word is prose and the
# task still batches.
for extra in '- Tests: `tests/shared.sh` passes' '- Testing: `tests/shared.sh`' \
  '- Created by: `tests/shared.sh`'; do
    p="$d/bt-files-word.md"
    { printf '# P\n\n### Task 1: t\n\n**Depends on:** none\n**Files:**\n- Modify: `a.sh`\n\n'
      printf '**Done when:** x\n\n%s\n\n' "$extra"; task 2 none tests/shared.sh; } > "$p"
    bt "$p"
    wantw="$(printf '%s\n' 'batch: 1 2' "$CHECK")"
    [ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$wantw" ] \
      && ok "batches: a list item opening with a longer word is not Files-like ($extra)" \
      || bad "batches files-like word $extra" "rc=$bt_rc, got: $bt_out"
done
# A label counts as Files-like only when `file` or `files` is a whole word in its name, so a word
# that merely holds it (`Profile`, `Filename`, `Profiler`) names no path and the task still batches.
for extra in '**Profile key record:** a record keyed by `tests/shared.sh`' \
  '- **Profile key record:** keeps the record' '> **Filename:** x' '**Profiler:**'; do
    p="$d/bt-files-label.md"
    { printf '# P\n\n### Task 1: t\n\n**Depends on:** none\n**Files:**\n- Modify: `a.sh`\n\n'
      printf '**Done when:** x\n\n%s\n\n' "$extra"; task 2 none tests/shared.sh; } > "$p"
    bt "$p"
    wantw="$(printf '%s\n' 'batch: 1 2' "$CHECK")"
    [ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$wantw" ] \
      && ok "batches: a label holding file inside another word is not Files-like ($extra)" \
      || bad "batches files-label word $extra" "rc=$bt_rc, got: $bt_out"
done
# An indented line after the blank that ends the Files block, before the next label, continues the
# block's last item as a Markdown paragraph, so it may hold a path.
p="$d/bt-files-cont.md"
printf '%s\n' '# P' '' '### Task 1: t' '' '**Depends on:** none' '**Files:**' '- Modify: `a.sh`' \
  '' '  and `shared.sh`, for its import' '' '**Done when:** x' '' '- [ ] **Step 1.1: do**' '' \
  '### Task 2: t' '' '**Depends on:** none' '**Files:**' '- Modify: `shared.sh`' '' \
  '**Done when:** x' '' '- [ ] **Step 2.1: do**' > "$p"
bt "$p"
wantq="$(printf '%s\n' 'alone: 1' 'alone: 2' \
  "why: task 1 $SFILES (line 9: '  and \`shared.sh\`, for its import')" "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$wantq" ] \
  && ok "batches: an indented line after the Files block, before the next label, runs alone" \
  || bad "batches files continuation paragraph" "rc=$bt_rc, got: $bt_out"
p="$d/bt-fl-pending.md"
{ task 1 none a.md
  printf '### Task 2: a task\n\n**Depends on:** none\n**Files:**\n- Modify: `b.md`,\n**Interfaces:**\n- Uses `c.md`\n\n'; } > "$p"
bt "$p"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a list ending on a comma with no continuation before a label runs alone" \
  || bad "batches pending separator" "rc=$bt_rc, got: $bt_out"
p="$d/bt-fl-fenced.md"
{ task 1 none a.md
  printf '### Task 2: a task\n\n**Depends on:** none\n**Files:**\n- Modify: `b.md`\n\n```\n- Modify: `c.md`\n```\n\n'; } > "$p"
bt "$p"
wantq="$(printf '%s\n' 'alone: 1' 'alone: 2' "why: task 2 $SFILES (line 13: '\`\`\`')" "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$wantq" ] \
  && ok "batches: a fenced block between the Files block and the next label runs the task alone" \
  || bad "batches fence after files" "rc=$bt_rc, got: $bt_out"
# A second Depends on line would be unread, so the task runs alone.
p="$d/bt-twodeps.md"
{ task 1 none a.md
  printf '### Task 2: a task\n\n**Depends on:** none\n**Depends on:** task 1\n**Files:**\n- Modify: `b.md`\n\n'; } > "$p"
bt "$p"
want="$(printf '%s\n' 'alone: 1' 'alone: 2' "why: task 2 $SDEP" "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a second Depends on line runs the task alone, since it would be unread" \
  || bad "batches two depends lines" "rc=$bt_rc, got: $bt_out"

# The label alone with no list under it names no paths, so it counts as no Files block.
p="$d/bt-files-none.md"
{ task 1 none a.md
  printf '### Task 2: a task\n\n**Depends on:** none\n**Files:**\n\nProse only.\n\n'; } > "$p"
bt "$p"
printf '%s\n' "$bt_out" | grep -qxF "why: task 2 has no Files block, so its paths are unknown" \
  && ok "batches: a Files label with no list under it counts as no Files block" \
  || bad "batches files label alone" "rc=$bt_rc, got: $bt_out"

# One file written another way is not read as that file: every such form is outside the strict
# form, so its task runs alone and no cutting of the path can read it wrong. Task 2 names the clean
# form and is not held back by a task whose paths are unknown.
for case_ in 'a.sh:1-5|a.sh' './a.sh|a.sh' 'a.sh#phrase|a.sh' 'a.sh::test_a|a.sh' \
  'a.sh:foo()|a.sh' 'a.sh:L4|a.sh' 'a.sh (lines 3-9)|a.sh' 'lib//x.sh|lib/x.sh' \
  'lib/./x.sh|lib/x.sh' '/lib/x.sh|lib/x.sh' '../lib/x.sh|lib/x.sh'; do
    p1="${case_%%|*}"; p2="${case_#*|}"
    p="$d/bt-norm.md"
    { task 1 none "$p1"; task 2 none "$p2"; } > "$p"
    bt "$p"
    want="$(printf '%s\n' 'alone: 1' 'alone: 2' "why: task 1 $SFILES" "$CHECK")"
    [ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
      && ok "batches: \`$p1\` is not read as \`$p2\`: its task runs alone" \
      || bad "batches path form $p1 $p2" "rc=$bt_rc, got: $bt_out"
done

# 3: a shared path splits a batch and says which. Plan order is kept: task 3 never joins task 1.
p="$d/bt-shared.md"
{ task 1 none CHANGELOG.md; task 2 none CHANGELOG.md; } > "$p"
bt "$p"
want="$(printf '%s\n' 'alone: 1' 'alone: 2' 'why: task 2 shares CHANGELOG.md with task 1' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: tasks naming one path run alone, and the reason names the path and the task" \
  || bad "batches shared path" "rc=$bt_rc, got: $bt_out"
p="$d/bt-order.md"
{ task 1 none a.md; task 2 none a.md; task 3 none c.md; } > "$p"
bt "$p"
[ "$(printf '%s\n' "$bt_out" | head -2 | tr '\n' '|')" = "alone: 1|batch: 2 3|" ] \
  && ok "batches: a task never moves above one before it, so 3 joins 2 and not 1" \
  || bad "batches plan order" "rc=$bt_rc, got: $bt_out"
# Behaviour 3: on a case-insensitive file system App.tsx and app.tsx are one file, so two paths that
# differ only in case are shared, and the reason shows the later task's spelling.
p="$d/bt-pathcase.md"
{ task 1 none src/App.tsx; task 2 none src/app.tsx; task 3 none DOCS/a.md; task 4 none docs/A.md; } > "$p"
bt "$p"
want="$(printf '%s\n' 'alone: 1' 'batch: 2 3' 'alone: 4' 'why: task 2 shares src/app.tsx with task 1' \
  'why: task 4 shares docs/A.md with task 3' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: paths that differ only in case are one path" \
  || bad "batches path case" "rc=$bt_rc, got: $bt_out"

# A directory written without its trailing slash is a legal strict path, so it is shared with every
# path under it, in either order and without regard to case; a name that only starts with it is not.
p="$d/bt-prefix.md"
{ task 1 none skills/x; task 2 none skills/x/a.md; task 3 none skills/xy.md; } > "$p"
bt "$p"
want="$(printf '%s\n' 'alone: 1' 'batch: 2 3' 'why: task 2 shares skills/x with task 1' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a directory path is shared with the paths under it, and not with a longer name" \
  || bad "batches directory prefix" "rc=$bt_rc, got: $bt_out"
p="$d/bt-prefix2.md"
{ task 1 none skills/x/a.md; task 2 none Skills/X; } > "$p"
bt "$p"
want="$(printf '%s\n' 'alone: 1' 'alone: 2' 'why: task 2 shares Skills/X with task 1' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a directory path later in the plan is shared with a file under it, in any case" \
  || bad "batches directory prefix later" "rc=$bt_rc, got: $bt_out"

# 4: unbatchable tasks run alone, each with its reason. Task 1 is free, task 2 is the subject.
unb() {  # unb <label> <task 2 text> <reason after "why: ">
    local p="$d/bt-unb.md"
    { task 1 none a.md; printf '%s\n' "$2"; } > "$p"
    bt "$p"
    want="$(printf '%s\n' 'alone: 1' 'alone: 2' "why: $3" "$CHECK")"
    [ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
      && ok "batches: $1" || bad "batches unbatchable $1" "rc=$bt_rc, got: $bt_out"
}
unb "no Depends on line runs alone" "$(task 2 - b.md)" \
    "task 2 has no Depends on line, so its order is unknown"
unb "a dependency the plan does not have runs alone" "$(task 2 'task 9' b.md)" \
    "task 2 depends on task 9, which this plan does not have above it"
p="$d/bt-below.md"
{ task 1 none a.md; task 2 'task 3' b.md; task 3 none c.md; } > "$p"
bt "$p"
want="$(printf '%s\n' 'alone: 1' 'alone: 2' 'alone: 3' \
  'why: task 2 depends on task 3, which this plan does not have above it' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a dependency on a task below runs alone" \
  || bad "batches dependency below" "rc=$bt_rc, got: $bt_out"
unb "no Files block runs alone" "$(task 2 none)" \
    "task 2 has no Files block, so its paths are unknown"
unb "a directory runs alone" "$(task 2 none skills/x/)" "task 2 $SFILES"
for pat in 'skills/*.md' 'skills/a?.md' 'skills/[ab].md'; do
    unb "the pattern $pat runs alone" "$(task 2 none "$pat")" "task 2 $SFILES"
done
for cfg in package-lock.json pnpm-lock.yaml yarn.lock package.json Cargo.lock Cargo.toml go.mod go.sum \
    poetry.lock uv.lock pyproject.toml requirements.txt requirements-dev.txt Gemfile Gemfile.lock \
    composer.json composer.lock pubspec.yaml pubspec.lock .eslintrc .eslintrc.json eslint.config.js \
    .prettierrc .prettierrc.yml prettier.config.js biome.json ruff.toml .ruff.toml .editorconfig \
    .golangci.yml rustfmt.toml .rubocop.yml tsconfig.json tsconfig.app.json .github/workflows/ci.yml \
    .circleci/config.yml .gitlab-ci.yml Jenkinsfile azure-pipelines.yml bitbucket-pipelines.yml \
    .keel/profile.json web/package.json svc/api/go.mod; do
    unb "$cfg is shared config and runs alone" "$(task 2 none "$cfg")" \
        "task 2 edits shared config $cfg"
done
unb "Package.json is shared config whatever its case" "$(task 2 none Package.json)" \
    "task 2 edits shared config Package.json"
unb ".GitHub/Workflows/ci.yml is shared config whatever its case" \
    "$(task 2 none .GitHub/Workflows/ci.yml)" "task 2 edits shared config .GitHub/Workflows/ci.yml"
p="$d/bt-notcfg.md"
{ task 1 none docs/package.json.md; task 2 none docs/tsconfig.md; task 3 none lib/requirements.sh; } > "$p"
bt "$p"
[ "$(printf '%s\n' "$bt_out" | head -1)" = "batch: 1 2 3" ] \
  && ok "batches: a name that only resembles shared config is not shared config" \
  || bad "batches not config" "rc=$bt_rc, got: $bt_out"

# The reason a task gets is one: no Depends on line wins over its files (task 2), and an unknown
# dependency wins over its files too (task 3).
p="$d/bt-onewhy.md"
{ task 1 none a.md; task 2 - package.json; task 3 'task 9' package.json; } > "$p"
bt "$p"
[ "$(printf '%s\n' "$bt_out" | grep -c '^why:')" -eq 2 ] \
  && printf '%s\n' "$bt_out" | grep -qxF "why: task 2 has no Depends on line, so its order is unknown" \
  && printf '%s\n' "$bt_out" | grep -qxF "why: task 3 depends on task 9, which this plan does not have above it" \
  && ok "batches: a task with several faults gets one why line" \
  || bad "batches one why" "rc=$bt_rc, got: $bt_out"

# Behaviour 1: a Depends on line outside the strict form runs its task alone with one why, whatever
# it says. Each of these was once read as some ids, or as none, and the reading was wrong somewhere.
# Task 1 is free and task 2 is the subject.
for dep in 'story 4' '' 'task #1' 'TBD' 'the schema task' 'Task one' 'T1' \
  'tasks 1 (schema) and 2 (API)' 'tasks 1-2' 'task 1 and task two' "none (needs task 2's table)" \
  'task 1, with row 3 of its results' 'none, but see task 1' 'None' 'NONE' 'none..' 'none .' \
  'none and task 1' 'Task 1 (the schema)' 'task 1 and 2' 'tasks 1' 'tasks 1, 2' 'tasks 1, and 2' \
  'tasks 1 to' 'tasks 1 to 1' 'tasks 2 to 1' 'tasks 1 and 2 and 3' 'tasks 1,2 and 3' \
  'tasks 1 , 2 and 3' 'task  1' 'tasks 1  and 2' 'tasks 1 AND 2' 'tasks 1 To 2' 'task' 'tasks' \
  'task 1,' 'task 1:' 'task 1;' 'Tasks: 1 and 2' 'task 1 task 2' 'task 1.5' 'task 1b2' 'task -1' \
  'task 01x!' $'task\t1' $'task 1\t' $'tasks 1 and\t2' 'see task 1' 'task 1..' 'task 1 .'; do
    unb "Depends on '$dep' is not in the strict form and runs alone" "$(task 2 "$dep" b.md)" \
        "task 2 $SDEP"
done
p="$d/bt-unread-json.md"
{ task 1 none a.md; task 2 'story 4' b.md; } > "$p"
bt "$p" --json
printf '%s' "$bt_out" | grep -qF '"why": [{"task": "2", "reason": "task 2 has a Depends on line not in the strict form, so its order is unknown"}]' \
  && printf '%s' "$bt_out" | grep -qF '"steps": [{"alone": "1"}, {"alone": "2"}]' \
  && ok "batches --json carries the strict-form Depends on reason" \
  || bad "batches json strict form" "rc=$bt_rc, got: $bt_out"

# A task after a lone unbatchable task is checked against it: its dependency on it, or a path it
# shares with it, is its why. Task 2 is shared config, so it runs alone and has its own reason.
p="$d/bt-after-alone.md"
{ task 1 none a.md; task 2 none package.json; task 3 'task 2' c.md; } > "$p"
bt "$p"
want="$(printf '%s\n' 'alone: 1' 'alone: 2' 'alone: 3' \
  'why: task 2 edits shared config package.json' 'why: task 3 depends on task 2' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a task depending on a lone unbatchable task before it gets its why" \
  || bad "batches after alone dependency" "rc=$bt_rc, got: $bt_out"
p="$d/bt-after-alone-path.md"
{ task 1 none a.md; task 2 - b.md; task 3 none b.md; task 4 none d.md; } > "$p"
bt "$p"
want="$(printf '%s\n' 'alone: 1' 'alone: 2' 'batch: 3 4' \
  'why: task 2 has no Depends on line, so its order is unknown' 'why: task 3 shares b.md with task 2' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a task sharing a path with a lone unbatchable task before it gets its why" \
  || bad "batches after alone path" "rc=$bt_rc, got: $bt_out"
# With nothing to hold it back from the lone task, the next task gets no why of its own.
p="$d/bt-after-alone-free.md"
{ task 1 none a.md; task 2 - b.md; task 3 none c.md; task 4 none d.md; } > "$p"
bt "$p"
want="$(printf '%s\n' 'alone: 1' 'alone: 2' 'batch: 3 4' \
  'why: task 2 has no Depends on line, so its order is unknown' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a free task after a lone unbatchable one has no reason of its own, and gets no why" \
  || bad "batches after alone free" "rc=$bt_rc, got: $bt_out"

# 5: the check line is always printed, and one task prints alone.
p="$d/bt-one.md"
{ task 1 none a.md; } > "$p"
bt "$p"
want="$(printf '%s\n' 'alone: 1' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a plan with one task prints alone and the check line" \
  || bad "batches one task" "rc=$bt_rc, got: $bt_out"

# 6: --json carries the steps, reasons and check, and needs no python3.
p="$d/bt-example.md"
bt "$p" --json
want='{"steps": [{"batch": ["1", "2"]}, {"alone": "3"}, {"alone": "4"}], "why": [{"task": "3", "reason": "task 3 depends on task 1 and task 2"}, {"task": "4", "reason": "task 4 depends on task 3"}], "check": "in each batch, every Done when names only its task'"'"'s own test, and each last step commits"}'
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches --json prints steps, why and check as one object" \
  || bad "batches json" "rc=$bt_rc, got: $bt_out"
bt --json "$p"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: --json may come before the plan" \
  || bad "batches json first" "rc=$bt_rc, got: $bt_out"
bt_out="$(PATH="$nopy" "$(command -v bash)" "$KEEL" plan batches "$p" --json 2>&1)"; bt_rc=$?
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches --json runs with no python3 on the path" \
  || bad "batches json no python3" "rc=$bt_rc, got: $bt_out"
printf '%s' "$bt_out" | python3 -m json.tool >/dev/null 2>&1 \
  && ok "batches --json is valid JSON" || bad "batches json valid" "got: $bt_out"
p="$d/bt-json-esc.md"
{ task 1 none 'a"b\c.md'; task 2 none a.md; } > "$p"
bt "$p" --json
printf '%s' "$bt_out" | python3 -c 'import json, sys; d = json.load(sys.stdin); sys.exit(0 if d["why"][0]["reason"] == "task 1 has a Files block not in the strict form, so its paths are unknown" else 1)' 2>/dev/null \
  && ok "batches --json stays valid JSON when a path held a quote and a backslash, and the task runs alone" \
  || bad "batches json escape" "rc=$bt_rc, got: $bt_out"
p="$d/bt-json-nowhy.md"
{ task 1 none a.md; task 2 none b.md; } > "$p"
bt "$p" --json
[ "$bt_out" = '{"steps": [{"batch": ["1", "2"]}], "why": [], "check": "in each batch, every Done when names only its task'"'"'s own test, and each last step commits"}' ] \
  && ok "batches --json with nothing to explain prints an empty why list" \
  || bad "batches json no why" "rc=$bt_rc, got: $bt_out"

# A plan with CRLF line endings reads the same.
p="$d/bt-crlf.md"
{ task 1 none a.md; task 2 none a.md; } | awk '{ printf "%s\r\n", $0 }' > "$p"
bt "$p"
want="$(printf '%s\n' 'alone: 1' 'alone: 2' 'why: task 2 shares a.md with task 1' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a CRLF plan reads as an LF one" \
  || bad "batches crlf" "rc=$bt_rc, got: $bt_out"
# A CRLF plan reads the strict forms too: a continuation line and a Depends on line with a period.
p="$d/bt-crlf-strict.md"
{ task 1 'none.' a.md
  printf '### Task 2: a task\n\n**Depends on:** none.\n**Files:**\n- Modify: `b.md`,\n  `a.md`\n\n'; } \
  | awk '{ printf "%s\r\n", $0 }' > "$p"
bt "$p"
want="$(printf '%s\n' 'alone: 1' 'alone: 2' 'why: task 2 shares a.md with task 1' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a CRLF plan reads a continuation line and a trailing period" \
  || bad "batches crlf strict" "rc=$bt_rc, got: $bt_out"
# A CRLF blank line still ends a Files block. Read as a line holding a CR, it would not, and the
# prose after it would be read as task 1's paths and stop a batch that is safe.
p="$d/bt-crlf-blank.md"
{ printf '### Task 1: a task\n\n**Depends on:** none\n**Files:**\n- Modify: `a.md`\n\n'
  printf 'Prose naming `b.md`.\n\n'; task 2 none b.md; } | awk '{ printf "%s\r\n", $0 }' > "$p"
bt "$p"
want="$(printf '%s\n' 'batch: 1 2' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: a CRLF blank line ends a Files block" \
  || bad "batches crlf blank" "rc=$bt_rc, got: $bt_out"

# 7: errors.
u='usage: keel plan batches <plan> [--json]'
for args in "" "--json" "--bogus $d/bt-one.md" "$d/bt-one.md $d/bt-example.md" "$d/bt-one.md --json --bogus"; do
    # shellcheck disable=SC2086  # the words of args are the arguments
    bt $args
    [ "$bt_rc" -eq 1 ] && case "$bt_out" in *"$u"*) true ;; *) false ;; esac \
      && ok "batches: arguments '${args#"$d"/}' exit 1 with the usage line" \
      || bad "batches usage $args" "rc=$bt_rc, got: $bt_out"
done
bt "$d/no-such-plan.md"
[ "$bt_rc" -eq 1 ] && case "$bt_out" in *"no such plan: $d/no-such-plan.md"*) true ;; *) false ;; esac \
  && ok "batches: a missing plan exits 1 naming it" \
  || bad "batches missing" "rc=$bt_rc, got: $bt_out"
p="$d/bt-notasks.md"
printf '# A plan\n\n## Tasks\n\n- [ ] **Step 1.1: a**\n\n```\n### Task 1: only an example\n```\n' > "$p"
bt "$p"
[ "$bt_rc" -eq 3 ] && case "$bt_out" in *"no ### Task heading"*) true ;; *) false ;; esac \
  && ok "batches: a plan with no ### Task heading exits 3 saying so" \
  || bad "batches no tasks" "rc=$bt_rc, got: $bt_out"
bt "$p" --json
[ "$bt_rc" -eq 3 ] && case "$bt_out" in *"no ### Task heading"*) true ;; *) false ;; esac \
  && ok "batches --json: a plan with no ### Task heading exits 3 and prints no object" \
  || bad "batches no tasks json" "rc=$bt_rc, got: $bt_out"

# Every committed plan reads without a shell error: 0 with an object of lines, or 3 for a plan with
# no task headings. Only the plans are read, as the one case on a committed plan above does.
bad_plans=""
for p in "$ROOT"/docs/plans/*.md; do
    bt "$p"
    case "$bt_rc" in
        0) case "$bt_out" in "$CHECK"|*$'\n'"$CHECK") ;; *) bad_plans="$bad_plans ${p##*/}" ;; esac ;;
        3) case "$bt_out" in "keel: "*"no ### Task heading"*) ;; *) bad_plans="$bad_plans ${p##*/}" ;; esac ;;
        *) bad_plans="$bad_plans ${p##*/}" ;;
    esac
done
[ -z "$bad_plans" ] \
  && ok "batches: every plan in docs/plans exits 0 ending in the check line, or 3 saying so" \
  || bad "batches committed plans" "not read cleanly:$bad_plans"

# 8: documented.
bt_out="$("$KEEL" plan nosuch 2>&1)"
case "$bt_out" in *'status, tick, report, risk or batches'*) true ;; *) false ;; esac \
  && ok "batches: the unknown-subcommand message names batches" \
  || bad "batches subcommand message" "got: $bt_out"
help="$("$KEEL" --help 2>&1)"
[ "$(printf '%s\n' "$help" | grep -n 'plan batches <plan> \[--json\]' | cut -d: -f1)" \
  = "$(( $(printf '%s\n' "$help" | grep -n '^  plan risk ' | cut -d: -f1) + 1 ))" ] \
  && ok "batches: keel --help lists plan batches right after plan risk" \
  || bad "batches help" "$help"
grep -qF 'batches' <(sed -n 1,3p "$ROOT/tests/test-plan.sh") \
  && ok "batches: this file's header names batches" \
  || bad "batches test header" "the first lines do not name batches"
grep -qF 'keel plan batches <plan> [--json]' "$ROOT/docs/03-install-and-distribution.md" \
  && ok "batches: docs/03-install-and-distribution.md has its section" \
  || bad "batches docs" "docs/03-install-and-distribution.md does not name the command"

# Plans copy the template's example lines, so the template's example task, and the example it gives
# of each strict line, are themselves in the strict form: neither gets a strict-form why.
tpl="$ROOT/skills/write-plan/references/plan-template.md"
p="$d/bt-template.md"
{ task 1 none a.md; task 2 none b.md
  awk '/^### Task 3: Reject an empty credential at startup/ { on = 1 } /^- \[ \] \*\*Step 3\.1/ { on = 0 } on' "$tpl"
} > "$p"
bt "$p"
want="$(printf '%s\n' 'batch: 1 2' 'alone: 3' 'why: task 3 depends on task 2' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: the template's example task is in the strict form" \
  || bad "batches template example task" "rc=$bt_rc, got: $bt_out"
p="$d/bt-template-lines.md"
{ task 1 none a.md; task 2 none b.md
  printf '### Task 3: a task\n\n'
  awk '/^\*\*Depends on:\*\* tasks 1 and 2$/ { on = 1 } on && /^```/ { on = 0 } on' "$tpl"
  printf '\n'
} > "$p"
bt "$p"
want="$(printf '%s\n' 'batch: 1 2' 'alone: 3' 'why: task 3 depends on task 1 and task 2' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] && grep -qF -- '- Test: `test/format.test.js`' "$p" \
  && ok "batches: the template's example Depends on and Files lines are in the strict form" \
  || bad "batches template example lines" "rc=$bt_rc, got: $bt_out"
# The template's rule-2 example, a step that commits, holds a fenced command inside a fenced step.
# Copied into a plan as written, read from the template so this case follows it, it must hide no
# task: tasks 2 and 3 after it are seen by status and by batches, where task 3 shares b.md with 2.
p="$d/bt-template-commit.md"
{ printf '%s\n' '# P' '' '### Task 1: a task' '' '**Depends on:** none' '**Files:**' \
    '- Modify: `a.md`' '' '**Done when:** x' '' '- [ ] **Step 1.1: a**' ''
  awk '/^2\. \*\*Write the final step as a commit/ { on = 1 }
       /^   The named-paths rule above still applies/ { on = 0 } on' "$tpl"
  printf '%s\n' '- [ ] **Step 1.2: b**' '' '### Task 2: a task' '' '**Depends on:** none' \
    '**Files:**' '- Modify: `b.md`' '' '**Done when:** x' '' '- [ ] **Step 2.1: c**' '' \
    '### Task 3: a task' '' '**Depends on:** none' '**Files:**' '- Modify: `b.md`' '' \
    '**Done when:** x' '' '- [ ] **Step 3.1: d**'; } > "$p"
out="$("$KEEL" plan status "$p" 2>&1)"; rc=$?
want="$(printf '%s\n' 'task 1: 0 done, 2 open, 0 deferred, 0 not applicable' \
  'task 2: 0 done, 1 open, 0 deferred, 0 not applicable' \
  'task 3: 0 done, 1 open, 0 deferred, 0 not applicable' 'next: 1.1')"
[ "$rc" -eq 0 ] && [ "$out" = "$want" ] \
  && grep -qF 'git commit -m "feat(format): normalise whitespace"' "$p" \
  && ok "status: the template's commit example hides no task after it" \
  || bad "status template commit example" "rc=$rc, got: $out"
bt "$p"
want="$(printf '%s\n' 'batch: 1 2' 'alone: 3' 'why: task 3 shares b.md with task 2' "$CHECK")"
[ "$bt_rc" -eq 0 ] && [ "$bt_out" = "$want" ] \
  && ok "batches: the template's commit example hides no task after it" \
  || bad "batches template commit example" "rc=$bt_rc, got: $bt_out"

# ---- the skills name the commands, and the fallback -----------------------------------------------

f="$ROOT/skills/execute-plan/SKILL.md"
grep -qF 'Resume with `keel plan status`; tick with `keel plan tick`, or by' "$f" \
  && grep -qF 'hand where `keel` cannot run or reports the plan unaddressable.' "$f" \
  && ok "execute-plan resumes and ticks with the commands, by hand where keel cannot run" \
  || bad "execute-plan" "Step 4 does not name keel plan status, keel plan tick and the fallback"

f="$ROOT/skills/execute-plan/references/subagent-prompts.md"
grep -qF 'task'"'"'s steps with `keel plan tick <plan> <id>`' "$f" \
  && grep -qF '`keel plan tick <plan> <id> --note <text>`' "$f" \
  && grep -qF 'unaddressable' "$f" \
  && grep -qF 'keel plan status <plan>' "$f" \
  && grep -qF 'one call per step' "$f" \
  && grep -qF 'not installed or not on PATH' "$f" \
  && ok "subagent-prompts ticks with keel plan tick, notes with --note, and names the fallback" \
  || bad "subagent-prompts" "the tick instructions do not name keel plan tick, --note and the fallback"

f="$ROOT/skills/execute-plan/references/parallel-batches.md"
grep -qF 'Tick the whole batch'"'"'s steps with `keel plan tick`' "$f" \
  && grep -qF 'By hand, tick serially' "$f" \
  && ok "parallel-batches lets locked ticks overlap and keeps hand ticks serial" \
  || bad "parallel-batches" "the batch tick rule does not name keel plan tick"

f="$ROOT/skills/ship/SKILL.md"
grep -qF '7. **`keel plan status <plan>` prints `next: none` and exits 0**, and the report names each' "$f" \
  && grep -qF 'deferred or not-applicable step with its reason. Exit 1 fails the gate.' "$f" \
  && grep -qF 'Where `keel` is not installed or not on PATH, or reports the plan unaddressable, read the' "$f" \
  && grep -qF 'plan by hand instead: every checkbox is ticked, or the remainder is explicitly deferred and' "$f" \
  && ok "ship gates on keel plan status, names deferrals, and falls back by hand" \
  || bad "ship" "gate item 7 does not read keel plan status with its by-hand fallback"

rm -rf "$d"
printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
