#!/usr/bin/env bash
# Tests for `keel plan status` and `keel plan tick`. Run from the repository root.
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
