# Skill review changes Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task. Tasks 1 to 12 change skill text, and their
> test is the applied check below; task 13 is eval arms and task 14 is records, and each says so.

**Goal:** every ruled finding in `docs/audits/2026-09-29-skill-review.md` is applied or declined
with a reason, and every eval scenario that injects a changed skill passes against the changed text.
**Stories:** the rest of S-03, and S-04, S-05, S-06 and S-07, in
`docs/stories/skill-and-reference-review.md`, from `docs/prd/skill-and-reference-review.md`.
**ADRs:** ADR-0001 (a body over 700 words owes a passing arm at its new length) and ADR-0005 (one
body per skill across harnesses). Neither decision changes. Task 1 updates ADR-0001's measured
figures for `coding-standards`, its sentence "17 references, 22,750 reference words, and a body of
795", to the counts after task 1's rows, because `tests/test-doc-claims.sh` pins them to the tree.
**Architecture:** no code. Tasks 1 to 12 apply the findings file's rows, grouped by skill, each
row's `Proposed change` being the exact text; the plan adds only the order, the compositions where
rows share lines, and the documents outside `skills/` that the rows make wrong. Each of those tasks
then runs the citation repair below, which pins its rows' citations and moves or pins every citation
its edits displaced. Task 13 re-runs every scenario whose `Inject` names a changed skill, plus a
length arm for each changed body no scenario injects. Task 14 turns each `task-N` in the Resolution
column into its commit.

**Decided 2026-09-29, Bernard:**

- `plan-template.md`'s two batch reasons that assume a shared tree are restated for worktrees, as a
  new finding F-344 added in task 5.
- `write-plan` and `setup-deployment`, which no scenario injects, get dedicated length arms if they
  end over 700 words, the way `context-budget`'s was run on 2026-09-02. That is not a scenario, so
  FR-10 holds. The same holds for any other body no scenario injects that ends over 700 and over its
  last passing arm, which is task 13's rule.
- `skills/tdd/references/writing-good-tests.md` lines 45, 93 and 108 at `bda1acc`, which cite
  keel's own arms as worked examples, are left alone: no finding records them.
- A row's citations are pinned once it is applied. Each task rewrites its own rows' `path:N`
  citations in the findings file to "`path` line N at `bda1acc`", a form
  `tests/validate-citations.sh` does not read, and gives a dated document citing a line its rows
  delete or move the same form, or the line its content moved to. Each task names and stages those
  documents. No allow-list or skip is added to `tests/validate-citations.sh`.

**Concurrent batches:** none. Every task sets rows in the findings file and adds to `CHANGELOG.md`.

## The applied check

Each of tasks 1 to 12 is tested by this script, over that task's F-numbers. For each row it
requires a Resolution in the form below, `made` for a clarity change and `fixed` for the other
kinds, `declined: <reason>` for a refused row. Then, unless the row's note says `composed`:

- A row whose proposal starts with `delete` must have lost the text its Finding quotes first, up to
  any `...`, with backticks and emphasis ignored on both sides; a quoted table row is matched with
  its leading pipe, so the same words in a step do not count.
- Every other piece of the proposed text must be present in the file, whitespace ignored. In a
  proposal written as "`old` becomes `new`", only the text after `becomes`, `becomes:`,
  `becoming:`, `reading`, `as:` or `with` counts.

The file is the one `Where` names, read in either form: `path:N` before the task's citation repair
and "`path` line N at `bda1acc`" after it. A proposal whose first span names another file with a
line, as F-004's `references/assessment-template.md:18-19` does, is checked against that file,
relative to `Where`'s directory.

Extract both scripts to fixed paths with this one command, from the repository root. Each Bash
call is a fresh shell, so a variable or a function set in one is gone in the next: step N.1 of every
task runs this command, and every later command names the two paths literally.

```bash
awk '/^```python$/ {n++; f = 1; next} /^```$/ {f = 0} f && n == 1' docs/plans/2026-09-29-skill-review-changes.md > /tmp/skill-review-check.py && awk '/^```python$/ {n++; f = 1; next} /^```$/ {f = 0} f && n == 2' docs/plans/2026-09-29-skill-review-changes.md > /tmp/skill-review-repair.py
```

A step that counts a phrase does it with one self-contained pipeline,
`tr '\n' ' ' < <file> | tr -s ' ' | grep -oF '<text>' | wc -l`, which prints how often the text
occurs in the file with its line breaks flattened.

```python
import os, re, sys

# Usage: python3 /tmp/skill-review-check.py 13-45 [340 ...]   (F-numbers, single or ranged, inclusive)
FINDINGS = "docs/audits/2026-09-29-skill-review.md"
want = set()
for a in sys.argv[1:]:
    lo, _, hi = a.partition("-")
    want.update(range(int(lo), int(hi or lo) + 1))

SPAN = re.compile(r"`` (.+?) ``|`([^`]+)`")
MARK = re.compile(r"(becomes:?|becoming:|reading|as:|with)\s*$")


def new_text(prop):
    """The spans of a proposed change that must be in the file once it is applied."""
    toks, last = [], 0
    for m in SPAN.finditer(prop):
        toks.append((prop[last:m.start()], m.group(1) if m.group(1) is not None else m.group(2)))
        last = m.end()
    outside = "".join(p for p, _ in toks) + prop[last:]
    marked = re.search(r"becom|reading|appended|as:", outside)
    out = []
    for pre, txt in toks:
        if re.fullmatch(r"(\S+\.md)?:\d+(-\d+)?", txt):
            continue
        if marked and not MARK.search(pre):
            continue
        out += [p for p in txt.replace("\\|", "|").split("<br>") if p.strip()]
    return out


def flat(s):
    return " ".join(s.split())


def plain(s):
    return flat(re.sub(r"[`*]", "", s))


seen, fails = set(), []
for line in open(FINDINGS):
    m = re.match(r"\| F-(\d+) \|", line)
    if not m or int(m.group(1)) not in want:
        continue
    n = int(m.group(1))
    seen.add(n)
    c = [x.strip() for x in re.split(r"(?<!\\)\|", line.strip())[1:-1]]
    fid, where, kind, finding, prop, ruling, res = c[0], c[1], c[2], c[3], c[4], c[6], c[7]
    if ruling.startswith("refused"):
        if not res.startswith("declined: "):
            fails.append(f"{fid}: refused, so its Resolution must be 'declined: <reason>', is '{res}'")
        continue
    if res.startswith("declined: ") and len(res) > len("declined: "):
        continue
    r = re.fullmatch(r"(fixed|made) (task-\d+|[0-9a-f]{7,40})(; .+)?", res)
    if not r:
        fails.append(f"{fid}: Resolution '{res}' is not 'fixed|made <task-N|commit>[; note]'")
        continue
    verb = "made" if kind == "clarity change" else "fixed"
    if r.group(1) != verb:
        fails.append(f"{fid}: a {kind} is '{verb}', not '{r.group(1)}'")
    if "composed" in res:
        continue
    # Where reads `path:N` before a task pins it and "`path` line N at `bda1acc`" after.
    path = re.match(r"`?([^`\s:]+)", where).group(1)
    loc = re.match(r"`([^`\s]+\.md):\d", prop)
    if loc:
        path = os.path.normpath(os.path.join(os.path.dirname(path), loc.group(1)))
    text = flat(open(path).read())
    q = SPAN.search(finding)
    if prop.startswith("delete") and q:
        # The Finding's first quote, up to any "...", markup dropped on both sides, since a Finding
        # quotes prose without it. A quoted table row keeps its leading pipe, so the same words in a
        # step do not count.
        gone = plain(re.split(r"\.\.\.", (q.group(1) or q.group(2)).replace("\\|", "|"))[0])
        if re.search(r"\brow $", finding[:q.start()]):
            gone = "| " + gone
        if gone in plain(open(path).read()):
            fails.append(f"{fid}: deleted, but still in {path}: {gone[:90]}")
    if prop == "delete":
        continue
    for piece in new_text(prop):
        if flat(piece) not in text:
            fails.append(f"{fid}: not in {path}: {flat(piece)[:90]}")

for n in sorted(want - seen):
    fails.append(f"F-{n:03d}: no such row")
for f in fails:
    print("FAIL", f)
print(f"{len(seen)} rows checked, {len(fails)} failing")
sys.exit(1 if fails else 0)
```

Proved before this plan was written, at `d8379dc`: over `1-343` it printed
`343 rows checked, 342 failing`, 318 rows on `Resolution 'open'` and the 24 refused rows on needing
`declined: <reason>`; over `253`, the row fixed at `268a950`, it printed
`1 rows checked, 0 failing`. With every Resolution set as tasks 1 to 12 set them and no row applied,
it still failed all 82 rows whose proposal starts with `delete`, each on `deleted, but still in`,
and passed 42: the 24 refused, the six composed (F-060, F-142, F-242, F-312, F-314, F-332), F-253,
and eleven whose proposed text is already in the file before they are applied: F-012, F-029, F-040,
F-135, F-158, F-215, F-223, F-224, F-228, F-251 and F-252. For those eleven the check proves only
the Resolution, so each task holding one proves the old text gone with a phrase count in its step
N.4. Over `1-345` in a scratch copy where tasks 1 to 12 were simulated, it failed one row, F-118,
where the simulation's own passage matching had cut the row's text short.

## The citation repair

`tests/validate-citations.sh` checks that a cited line exists and is not blank. It cannot say where
a line a row deleted went, and a line a row moved can land on other text and still pass. Each of
tasks 1 to 12 runs this script once every edit of the task is in the working tree, before the
validators, as `python3 /tmp/skill-review-repair.py <the task's F-numbers>`. It does two things.

1. **The findings file.** In the task's own rows, every citation from the repository root in
   `Where`, `Finding` and `Removes` becomes "`path` line N at `bda1acc`", or "`path` lines N-M at
   `bda1acc`" for a range. `Proposed change` is never touched: it is the text the skill carries.
   Elsewhere in the findings file, a citation into a file this task changed takes the same form.
   Shorthand such as `SKILL.md:39` or `:24`, which the validator does not read, is left as written.
2. **Everything else.** A citation into a file this task changed, whose first cited line the task
   deleted or moved, is repaired. A line rewritten in place keeps its number and its citations. In a
   record (under `docs/plans`, `docs/prd`, `docs/stories`, `docs/ideas`, `docs/audits`,
   `docs/architecture` or `docs/decisions`, `docs/07-open-decisions.md`, `docs/harness-support.md`,
   `tests/evals/`, or `CHANGELOG.md`, the list `tests/validate-citations.sh` gives for records) the
   number moves with its line, or the citation takes the pinned form where the line was deleted, or
   rewritten as it moved. In a live document or a code comment it prints `LIVE`, to be repaired by
   hand with the moved line's number or a `path#phrase` citation. A citation inside a longer code
   span prints `HAND`, with the form to write.

It prints one line per change. A citing line already edited is skipped, so once every `LIVE` and
`HAND` line is repaired a second run prints nothing, which is part of each task's `Done when:`. Each
task lists what the script printed when the task was simulated in a scratch copy. A line number
there can differ by one where your rewrap differs from the simulation's, and the script's output is
what counts. A record it changes that the task does not list is staged all the same and named in the
report. The lists assume the task before is committed before this one is dispatched: the script
compares with HEAD, so a predecessor left uncommitted would have its displaced citations listed
again. `CHANGELOG.md` changes in every task, and its one line citation that moves, in
`docs/ideas/keel-on-codex.md`, becomes a phrase citation in task 1, so no later list names it.

```python
import difflib, glob, os, re, subprocess, sys

# Usage: python3 /tmp/skill-review-repair.py 13-45 [340 ...]   (this task's F-numbers), once every edit of the
# task is in the working tree. Prints each change it makes, and each citation left to repair by hand.
FINDINGS = "docs/audits/2026-09-29-skill-review.md"
PLAN = "docs/plans/2026-09-29-skill-review-changes.md"
want = set()
for a in sys.argv[1:]:
    lo, _, hi = a.partition("-")
    want.update(range(int(lo), int(hi or lo) + 1))
CITE = re.compile(r"([A-Za-z0-9._/-]+[.](md|sh|json|yml|yaml|txt|toml)|[A-Za-z0-9._-]+/[A-Za-z0-9._/-]+)"
                  r":([0-9]+)(-([0-9]+))?")
SPAN = re.compile(r"`` .+? ``|`[^`]+`")
RECORD = re.compile(r"^(docs/(plans|prd|stories|architecture|decisions|audits|ideas)/"
                    r"|docs/07-open-decisions\.md$|docs/harness-support\.md$|tests/evals/|CHANGELOG\.md$)")


def git(*a):
    return subprocess.run(["git", *a], capture_output=True, text=True).stdout


changed = [f for f in git("diff", "--name-only", "HEAD").split()
           if f not in (FINDINGS, PLAN) and os.path.isfile(f)]


def pinned(p, a, b):
    return f"`{p}` line {a} at `bda1acc`" if a == b else f"`{p}` lines {a}-{b} at `bda1acc`"


def pin(text, only, where):
    """Every `path:N` from the repository root in text, restricted to paths in only unless it is None,
    becomes the pinned form, which tests/validate-citations.sh does not read."""
    def bare(s):
        def f(m):
            if not os.path.isfile(m.group(1)) or (only is not None and m.group(1) not in only):
                return m.group(0)
            return pinned(m.group(1), int(m.group(3)), int(m.group(5) or m.group(3)))
        return CITE.sub(f, s)
    out, last = [], 0
    for m in SPAN.finditer(text):
        out.append(bare(text[last:m.start()]))
        inner = m.group(0).strip("`").strip()
        c = CITE.fullmatch(inner)
        if c and os.path.isfile(c.group(1)) and (only is None or c.group(1) in only):
            out.append(pinned(c.group(1), int(c.group(3)), int(c.group(5) or c.group(3))))
        else:
            for c in CITE.finditer(inner):
                if os.path.isfile(c.group(1)) and (only is None or c.group(1) in only):
                    print(f"HAND {where} `{c.group(0)}` is inside a longer code span")
            out.append(m.group(0))
        last = m.end()
    out.append(bare(text[last:]))
    return "".join(out)


# 1. The findings file: this task's rows in full, and elsewhere any citation into a file it changed.
lines = open(FINDINGS).read().split("\n")
for i, line in enumerate(lines):
    m = re.match(r"\| F-(\d+) \|", line)
    if m:
        c = re.split(r"(?<!\\)\|", line)
        for k in (2, 4, 6):  # Where, Finding, Removes; never the Proposed change
            c[k] = pin(c[k], None if int(m.group(1)) in want else changed, f"{FINDINGS}:{i + 1}")
        new = "|".join(c)
    else:
        new = pin(line, changed, f"{FINDINGS}:{i + 1}")
    if new != line:
        print(f"PIN  {FINDINGS}:{i + 1}")
        lines[i] = new
open(FINDINGS, "w").write("\n".join(lines))

# 2. Every other citation into a file this task changed whose first cited line the task deleted or
# moved; a line rewritten in place keeps its number. In a record the citation moves with its line,
# or takes the pinned form where the line was deleted or rewritten as it moved. Anywhere else it is
# printed, to repair by hand. A citing line already edited is skipped, so a second run is silent.
old = {f: git("show", "HEAD:" + f).split("\n") for f in changed}
now = {f: open(f).read().split("\n") for f in changed}
ops = {}


def where_now(t, a):
    """The line old line a of t is at now: a itself where it was rewritten in place, its new number
    where it moved unchanged, None where it was deleted, or rewritten and moved."""
    if t not in ops:
        ops[t] = difflib.SequenceMatcher(None, old[t], now[t], autojunk=False).get_opcodes()
    for tag, i1, i2, j1, j2 in ops[t]:
        if i1 <= a - 1 < i2:
            if tag == "equal":
                return j1 + (a - 1 - i1) + 1
            if tag == "replace" and i1 == j1 and a - 1 - i1 < j2 - j1:
                return a
            return None
    return None


code = [f for g in ("bin/*", "hooks/*", "lib/*.sh", "lib/harness/*", "lib/*.py", "tests/*.sh",
                    "tests/evals/*.sh") for f in glob.glob(g)
        if f not in ("tests/validate-citations.sh", "tests/test-validate-citations.sh")]
docs = glob.glob("docs/**/*.md", recursive=True) + glob.glob("skills/**/*.md", recursive=True) \
    + glob.glob("*.md")
for f in sorted(set(docs + code) - {FINDINGS, PLAN}):
    if not os.path.isfile(f):
        continue
    text, head = open(f, errors="replace").read().split("\n"), git("show", "HEAD:" + f).split("\n")
    fence, dirty, seen = False, False, set(head)
    for i, l in enumerate(text):
        if f in code:
            if not re.match(r"^[ \t]*#", l):
                continue
        elif re.match(r"^ *```", l):
            fence = not fence
            continue
        elif fence:
            continue
        if l not in seen:
            continue
        for m in reversed(list(CITE.finditer(l))):
            p = m.group(1)
            t = p if os.path.isfile(p) else os.path.normpath(os.path.join(os.path.dirname(f), p))
            if t not in changed:
                continue
            a, b = int(m.group(3)), int(m.group(5) or m.group(3))
            if a > len(old[t]) or not old[t][a - 1].strip():
                continue
            j = where_now(t, a)
            if j == a:
                continue
            if j is not None and b - a + j <= len(now[t]):
                rep = f"{p}:{j}" + (f"-{b - a + j}" if b > a else "")
            else:
                rep = pinned(p, a, b)
            s, e = m.start(), m.end()
            if not RECORD.match(f):
                print(f"LIVE {f}:{i + 1} `{m.group(0)}`: now {rep}; repair by hand")
                continue
            if rep.startswith("`") and l[:s].count("`") % 2:
                if l[s - 1:s] != "`" or l[e:e + 1] != "`":
                    print(f"HAND {f}:{i + 1} `{m.group(0)}` is inside a longer code span: write {rep}")
                    continue
                s, e = s - 1, e + 1
            l = l[:s] + rep + l[e:]
            print(f"{'MOVE' if not rep.startswith('`') else 'PIN '} {f}:{i + 1} {m.group(0)} -> {rep}")
            dirty = True
        text[i] = l
    if dirty:
        open(f, "w").write("\n".join(text))
```

## Global constraints

- Verify commands, from `.keel/profile.json`: test `tests/run-tests.sh`; one test file
  `tests/{name}`; typecheck and build are `null`, since there is nothing to compile; lint is:

  ```bash
  shellcheck -x bin/keel bin/keel-fleet lib/*.sh lib/harness/*.sh tests/*.sh tests/evals/run.sh \
    tests/evals/stage.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard
  ```

  `tests/run-tests.sh` runs this same command itself, read from the profile, and skips it only
  where shellcheck is not installed, so each task's suite run is also its lint run. Task 1 changes
  two shell files, `tests/test-doc-claims.sh` and a comment in `tests/validate-skills.sh`, and also
  runs the lint on its own in step 1.4. No other task changes a shell file.
- `tests/run-tests.sh` takes about seven minutes and prints nothing until each file finishes. Slow
  is not hung.
- Never start on `main`. Work on `sandbox`, which is where this repository's pull requests come
  from.
- No em dash and no en dash anywhere: skills, docs, findings, commit messages.
- Prose in markdown wraps at 100 columns; tables do not (docs/standards.md, "Prose wraps at 100
  columns; tables do not"). One exception: the citation repair changes only a citation in a record
  and does not rewrap its paragraph, even where the pinned form takes a line past 100 columns,
  because other documents cite records by line number.
- Shipped prose states the current state; history lives in `CHANGELOG.md` (docs/standards.md,
  "Shipped prose states the current state, and history lives in the changelog").
- Documentation lands in the same commit as the change: a line under `## Unreleased` at the top of
  `CHANGELOG.md`, plus any document the change makes wrong.
- A skill body stays at or under 900 words, and one over 700 owes a passing eval arm at its new
  length, recorded in `tests/evals/results.md` (ADR-0001). One skill body serves every harness
  (ADR-0005).
- From the PRD: no rule a skill states is removed unless its finding records the removal and
  Bernard approves it (FR-07); no sentence stating a rule's reason is removed as a clarity change
  (FR-08); no description trigger is removed without the same approval (FR-12); no new eval scenario
  is written (FR-10). A description stays within 216 characters and all of them within 1,320 tokens
  (CON-04).
- Every task points at three sections: "The applied check", "The citation repair", and "How a row
  is applied" below. Whoever implements a task reads all three, and these constraints, before
  starting; a task's own text does not repeat them.
- This plan cites a line of a file some task changes as "`path` line N at `bda1acc`", so no task
  moves a citation in it, and the citation repair skips this file.
- **How a row is applied.** These hold for every row in every task:
  1. A row whose Ruling is `not needed` or `approved 2026-09-29` is applied. A row whose Ruling is
     `refused 2026-09-29` changes nothing, and its Resolution becomes
     `declined: refused 2026-09-29`.
  2. `Where` gives line numbers as at `bda1acc`, as `path:N` until the task's citation repair and
     as "`path` line N at `bda1acc`" after it. Since then only `skills/tdd/SKILL.md` line 87 has
     changed, in place, so every line number still holds. Within one file apply edits from the
     highest line to the lowest, so each line number still points at its text. Order by the line an
     edit lands on, which is not always `Where`'s: "Inserted after `:N`" lands at N, and a row with
     two edits, a deletion with a line it rewrites or a sentence moved elsewhere, is two edits, each
     in its own place in the order. Each task names its rows of that kind. Before each edit, find
     the text the Finding column quotes at those lines; if it is not there, stop and report.
  3. The forms of `Proposed change`: text in a code span replaces the passage at `Where` that it
     rewrites, and a proposal that starts or ends mid-sentence replaces exactly the words from its
     first to its last, matched against the old text; `delete` removes the lines at `Where`, a
     table row or a paragraph with one blank line beside it; "`old` becomes `new`" replaces each
     `old` with its `new`, and "`:N` becomes `new`" replaces line N, or lines N-M for a range;
     "Inserted after `:N`" or "before `:N`" adds the text as its own line or paragraph there;
     "Moved, unchanged, ..." moves the lines it lists. "delete, with `:N` becoming: `text`" deletes
     `Where` and, on line N, replaces the passage `text` rewrites, from the words it starts with to
     the end of that sentence, and not the whole line: F-146's line 54 starts by ending the sentence
     on line 53, and those words stay. Where `text` is a table row, as F-174's is, it is the whole
     line. "delete, with `text` appended to `:N`" deletes `Where` and adds `text` after the last
     sentence that ends on line N, as F-175 does. In a proposal `<br>` is a line break and `\|` is
     `|`.
  4. Rewrap each paragraph you change to 100 columns, and no other paragraph. Tables are not
     wrapped. Two phrases stay whole on one line when you rewrap, because
     `tests/validate-skills.sh` reads them line by line: `delegation profile` with the name that
     follows it (`` delegation profile `keel-fanout` ``), and `` model `inherit` ``. Split across
     lines, the file reads as dispatching subagents without naming a model, which the validator
     fails. A task that must keep other line breaks says so.
  5. Change nothing else in a file: not the rows' neighbours, not wording you would improve.
  6. After applying a row, set its Resolution: `fixed task-N` for a repository fact, a
     contradiction or a stale or broken reference, `made task-N` for a clarity change, where N is
     the task's number. A row this plan composes with another gets `; <note>` after it, and the
     note says `composed` where the row's own text is no longer in the file verbatim. Task 14
     replaces each `task-N` with its commit.
  7. A row that cannot be applied as written is not declined on your own judgement: stop and report
     it. `declined: <reason>` is written only where this plan says so or after the user rules.
  8. Once every row and every other edit of the task is in place, run the citation repair, repair
     what it prints as `LIVE` or `HAND`, and only then run the validators.
- **A body's word count** is the `WARN` line `tests/validate-skills.sh` prints for a body over 700,
  or otherwise `awk '/^---$/ { f++; next } f >= 2' skills/<skill>/SKILL.md | wc -w`. Each task
  reports the count of every body it changed.
- Stage named paths only. Never `git add -A`, `git add .` or `git commit -a`.
- Commit messages are conventional, title and body only: no `Co-Authored-By`, no robot emoji, no
  generated-with line.
- Do not delete a file you did not create, except where a task names it. If `git status` shows
  something unexpected, report it and leave it alone.

---

### Task 1: `coding-standards` and its references

**Story:** S-03, S-04, S-05, S-06
**Files:**
- Modify: `skills/coding-standards/SKILL.md`, and in `skills/coding-standards/references/`:
  `assess.md`, `assessment-report.md`, `async-work.md`, `audit.md`, `caching.md`,
  `data-protection.md`, `frontend.md`, `house-defaults.md`, `resilience.md`, `seed.md`,
  `time-and-dates.md`
- Modify: `templates/profile.schema.json`, `docs/profile-keys.md` (generated)
- Modify, for the counts `tests/test-doc-claims.sh` pins: `tests/test-doc-claims.sh`,
  `tests/validate-skills.sh`, `docs/05-token-and-memory-design.md`, `docs/standards.md`,
  `docs/decisions/ADR-0001-skill-body-word-ceiling.md`,
  `docs/ideas/leon-van-zyl-skill-collection.md`, `docs/ideas/database-design-and-review.md`,
  `tests/evals/scenarios/assess-a-stale-standard.md`
- Modify, for a citation every task's changelog line would move: `docs/ideas/keel-on-codex.md`
- Modify, by the citation repair: `docs/ideas/profile-schema-drift.md`,
  `docs/ideas/standards-assessment-remedies.md`, `docs/ideas/standards-that-bind.md`,
  `docs/plans/2026-08-29-dart-flutter-stack-detection.md`,
  `docs/plans/2026-09-01-standards-assessment.md`,
  `docs/plans/2026-09-02-the-four-mode-router-and-audit.md`,
  `docs/plans/2026-09-07-declared-profile-keys-take-effect.md`, `docs/prd/standards-assessment.md`
- Modify: `docs/audits/2026-09-29-skill-review.md`, `CHANGELOG.md`
- Test: the applied check, over `13-45`; `tests/test-doc-claims.sh`

**Interfaces:**
- Consumes: the applied check and the citation repair, under their headings above.
- Produces: Resolutions `fixed task-1` and `made task-1`, which task 14 turns into this task's
  commit.

**Depends on:** none

**Done when:** `python3 /tmp/skill-review-check.py 13-45` prints `33 rows checked, 0 failing`;
`tests/test-doc-claims.sh`, `tests/validate-skills.sh`, `tests/validate-citations.sh` and the lint
pass; and `python3 /tmp/skill-review-repair.py 13-45` prints nothing.

- [x] **Step 1.1: Extract the test** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 1.2 to 1.4; 1.5's suite run witnessed by the implementer and the fixer only

The test is the applied check, already written under "The applied check". Run the extraction
command there, from the repository root.

- [x] **Step 1.2: Run it and watch it fail** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 1.2 to 1.4; 1.5's suite run witnessed by the implementer and the fixer only

Run: `python3 /tmp/skill-review-check.py 13-45`
Expected: FAIL, `33 rows checked, 33 failing`, each line `Resolution 'open' is not ...`. Two of
these rows, F-029 and F-040, propose text already in the file; step 1.4 proves their old text gone.

- [x] **Step 1.3: Apply F-013 to F-045, and the documents they make wrong** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 1.2 to 1.4; 1.5's suite run witnessed by the implementer and the fixer only

Apply every row from F-013 to F-045 under "How a row is applied". None is refused. F-013 is the
description finding.

F-014 and F-015 both rewrite `skills/coding-standards/SKILL.md` lines 21-22 at `bda1acc` and do not
conflict: apply F-015 to the `**Author**` sentence and F-014 to the `**assess**` clause before it,
so the two lines read, before rewrapping:

```markdown
is **assess**, [references/assess.md](references/assess.md), naming any check that ran with no corpus.
**Author** is steps 1 to 5: what audit offers at its end, and the mode for a request to set up linting or formatting or to write the standard.
```

F-023's `Where` says `assess.md` lines 17-18, but the text it rewrites is lines 18-19, from
`applicable or not` to `No code read.`; replace those.

**Three rows break a test or a citation, so this step changes them too.**

- F-024 deletes `all 12 house defaults` from `assess.md`, which `tests/test-doc-claims.sh` pins as
  check 1b's denominator. In `tests/test-doc-claims.sh`, this comment:

  ```bash
  # a fenced example to house-defaults.md this file fails loudly and names the wrong cause: the two
  # claim_in cases below would report the documents as stale when nothing about the definition of a
  # house rule had moved.
  ```

  becomes:

  ```bash
  # a fenced example to house-defaults.md this file fails loudly and names the wrong cause: the
  # claim_in case below would report the document as stale when nothing about the definition of a
  # house rule had moved.
  ```

  and these eleven lines:

  ```bash
  # claim_in takes the FIRST match of its phrase in the file. Both phrases below are unique today:
  # "denominator is" does not otherwise occur in assessment-report.md, and assess.md spells its only
  # other count as the word "ten". A sentence added above either one carrying a digit in the same
  # shape would silently make these read the wrong number and still pass.
  claim_in skills/coding-standards/references/assessment-report.md \
           "check 1b denominator in assessment-report.md" "$hd_rules" \
           'denominator is [0-9]+'

  claim_in skills/coding-standards/references/assess.md \
           "check 1b denominator in assess.md" "$hd_rules" \
           'all [0-9]+ house defaults'
  ```

  become these seven:

  ```bash
  # claim_in takes the FIRST match of its phrase in the file. The phrase below is unique today:
  # "denominator is" does not otherwise occur in assessment-report.md. A sentence added above it
  # carrying a digit in the same shape would silently make this read the wrong number and still pass.
  # assess.md states no count of its own: its check 1b is counted as assessment-report.md defines.
  claim_in skills/coding-standards/references/assessment-report.md \
           "check 1b denominator in assessment-report.md" "$hd_rules" \
           'denominator is [0-9]+'
  ```

  The same file cites its own lines further down, and the four lines removed move them: in its
  comment ending `already guards the same shape for schema_s12 and says so; this is that guard.`,
  the cited range `186-193` becomes `182-189`.
- F-042 writes `This record has three states`, capitalised, and `tests/test-doc-claims.sh` greps
  `seed.md` for `this record has three states` case-sensitively. In
  `tests/test-doc-claims.sh`, `grep -q 'this record has three states'` becomes
  `grep -qi 'this record has three states'`. No other line of that case changes.
- F-035's rewrap moves `house-defaults.md`'s frontend row from line 31 to line 30, which
  `templates/profile.schema.json` cites by line for two keys, and `docs/profile-keys.md` with it.
  Cite the row by phrase instead, so it stops drifting. In the schema, under `stack.framework`:

  ```text
            "x-keel-read-by": "advisory:skills/coding-standards/references/house-defaults.md:31"
  ```

  becomes:

  ```text
            "x-keel-read-by": "advisory:skills/coding-standards/references/house-defaults.md#profile.stack.framework"
  ```

  and under `stack.has_ui`, the second entry of its list:

  ```text
              "advisory:skills/coding-standards/references/house-defaults.md:31"
  ```

  becomes:

  ```text
              "advisory:skills/coding-standards/references/house-defaults.md#profile.stack.has_ui"
  ```

  Both phrases are on the frontend row, and no row changes them. Then run
  `tests/generate-profile-keys.sh > docs/profile-keys.md`.

**The counts `tests/test-doc-claims.sh` pins.** It compares the `coding-standards` reference count,
reference words and body words with seven documents (the `CLAIMS` list near its end). The rows
leave the 17 references and change the other two. Once every row is in, run:

```bash
cat skills/coding-standards/references/*.md | wc -w
awk 'f;/^---$/{c++; if(c==2) f=1}' skills/coding-standards/SKILL.md | wc -w
```

Call the first number `<words>`, written with a thousands comma, and the second `<body>`. A
simulation of this task printed 22698 and 726; write what your run prints. Then:

- `docs/05-token-and-memory-design.md`:
  `**17 reference files and 22,750 words** in them and its body is still 795,` becomes
  `**17 reference files and <words> words** in them and its body is still <body>,`.
- `tests/validate-skills.sh`, a comment: `It is 17, 22,750 and 795 today` becomes
  `It is 17, <words> and <body> today`.
- `docs/standards.md`: `carries 17 and 22,750 against 795 today` becomes
  `carries 17 and <words> against <body> today`.
- `docs/decisions/ADR-0001-skill-body-word-ceiling.md`: `17 references, 22,750 reference words, and
  a body of 795.` becomes `17 references, <words> reference words, and a body of <body>.`
- `docs/ideas/leon-van-zyl-skill-collection.md`: `sits at 795 words with 17 references carrying
  22,750 words` becomes `sits at <body> words with 17 references carrying <words> words`.
- `docs/ideas/database-design-and-review.md`: `precedent at 17 references, 22,750 words, and a body
  of 795.` becomes `precedent at 17 references, <words> words, and a body of <body>.`
- `tests/evals/scenarios/assess-a-stale-standard.md`: `795 word body is still followed` becomes
  `<body> word body is still followed`. This keeps an existing scenario's stated length in step
  with the body it injects; it writes no scenario, so FR-10 holds.

Each number replaces one of the same width, so no line is rewrapped.

**A changelog citation every task would move.** `docs/ideas/keel-on-codex.md` cites the
2026-09-04 release gate's cost, $2.9909 and 3m59s, by `CHANGELOG.md` line 12. Line 12 is already the
`tdd` timing entry under `## Unreleased`, not the gate, and every task here adds a line above it.
The entry it means is under `## 0.18.0 - 2026-09-04`, beginning "Release gate 2026-09-04 against".
Cite it by that phrase, which no insertion moves, before adding the changelog line and before the
citation repair. In `docs/ideas/keel-on-codex.md`, in the bullet on the measured cost:

```text
(2026-09-04 gate, `CHANGELOG.md:12`)
```

becomes:

```text
(2026-09-04 gate, `CHANGELOG.md#Release gate 2026-09-04 against`)
```

`tests/validate-citations.sh` checks a phrase citation's text is in the file, so a later edit that
drops it fails there.

Then add under `## Unreleased`, at the top of `CHANGELOG.md`:

```markdown
- `coding-standards` and its references take the skill review's findings F-013 to F-045
  (`docs/audits/2026-09-29-skill-review.md`): author mode is named for a request to set up linting
  or formatting, and assess names any check that ran with no corpus. The profile schema cites the
  frontend row of `house-defaults.md` by phrase.
```

Then run the citation repair: `python3 /tmp/skill-review-repair.py 13-45`. Expected: a `PIN` line
naming the findings file for each of this task's 33 rows, and two more for other rows citing a file
this task changed (35 in the simulation), then these:

```text
MOVE docs/ideas/profile-schema-drift.md:81 skills/coding-standards/SKILL.md:53 -> skills/coding-standards/SKILL.md:54
MOVE docs/ideas/standards-assessment-remedies.md:81 skills/coding-standards/references/house-defaults.md:164 -> skills/coding-standards/references/house-defaults.md:163
MOVE docs/ideas/standards-assessment-remedies.md:83 skills/coding-standards/references/house-defaults.md:162-178 -> skills/coding-standards/references/house-defaults.md:161-177
MOVE docs/ideas/standards-that-bind.md:138 skills/coding-standards/SKILL.md:69-71 -> skills/coding-standards/SKILL.md:70-72
MOVE docs/ideas/standards-that-bind.md:346 skills/coding-standards/SKILL.md:69-71 -> skills/coding-standards/SKILL.md:70-72
MOVE docs/plans/2026-08-29-dart-flutter-stack-detection.md:2282 skills/coding-standards/references/house-defaults.md:27 -> skills/coding-standards/references/house-defaults.md:26
MOVE docs/plans/2026-09-01-standards-assessment.md:1163 skills/coding-standards/references/house-defaults.md:18-27 -> skills/coding-standards/references/house-defaults.md:17-26
MOVE docs/plans/2026-09-02-the-four-mode-router-and-audit.md:923 tests/test-doc-claims.sh:218 -> tests/test-doc-claims.sh:214
MOVE docs/plans/2026-09-02-the-four-mode-router-and-audit.md:932 tests/test-doc-claims.sh:283 -> tests/test-doc-claims.sh:279
MOVE docs/plans/2026-09-02-the-four-mode-router-and-audit.md:1446 skills/coding-standards/SKILL.md:38-40 -> skills/coding-standards/SKILL.md:39-41
MOVE docs/plans/2026-09-07-declared-profile-keys-take-effect.md:787 skills/coding-standards/references/house-defaults.md:31 -> skills/coding-standards/references/house-defaults.md:30
MOVE docs/plans/2026-09-07-declared-profile-keys-take-effect.md:788 skills/coding-standards/references/house-defaults.md:31 -> skills/coding-standards/references/house-defaults.md:30
MOVE docs/prd/standards-assessment.md:115 skills/coding-standards/references/house-defaults.md:18-27 -> skills/coding-standards/references/house-defaults.md:17-26
MOVE docs/prd/standards-assessment.md:118 skills/coding-standards/SKILL.md:69-71 -> skills/coding-standards/SKILL.md:70-72
MOVE docs/prd/standards-assessment.md:118 skills/coding-standards/SKILL.md:69-71 -> skills/coding-standards/SKILL.md:70-72
```

- [x] **Step 1.4: Run it and watch it pass** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 1.2 to 1.4; 1.5's suite run witnessed by the implementer and the fixer only

Run: `python3 /tmp/skill-review-check.py 13-45 && tests/test-doc-claims.sh && tests/validate-skills.sh && tests/validate-citations.sh`
Expected: `33 rows checked, 0 failing`, then all three pass. Then run these, from the repository
root:

```bash
python3 /tmp/skill-review-repair.py 13-45
tr '\n' ' ' < skills/coding-standards/references/audit.md | tr -s ' ' | grep -oF 'Nothing else is written, and no file that was read is edited.' | wc -l
tr '\n' ' ' < skills/coding-standards/references/house-defaults.md | tr -s ' ' | grep -oF '## Money, since' | wc -l
```

Expected: the repair prints nothing, and each count prints `0` (F-029 and F-040, whose proposed
text was in the file before they were applied). Run the lint from Global constraints, which
passes. Report the `coding-standards` body's word count, `<body>` above.

- [x] **Step 1.5: Run the suite at the unit boundary, then hand over** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 1.2 to 1.4; 1.5's suite run witnessed by the implementer and the fixer only

Run: `tests/run-tests.sh`
Expected: PASS. The lint ran in step 1.4, for the two shell files this task changed, and runs
again inside the suite.

```bash
git add skills/coding-standards/SKILL.md skills/coding-standards/references/assess.md \
  skills/coding-standards/references/assessment-report.md skills/coding-standards/references/async-work.md \
  skills/coding-standards/references/audit.md skills/coding-standards/references/caching.md \
  skills/coding-standards/references/data-protection.md skills/coding-standards/references/frontend.md \
  skills/coding-standards/references/house-defaults.md skills/coding-standards/references/resilience.md \
  skills/coding-standards/references/seed.md skills/coding-standards/references/time-and-dates.md \
  templates/profile.schema.json docs/profile-keys.md tests/test-doc-claims.sh tests/validate-skills.sh \
  docs/05-token-and-memory-design.md docs/standards.md docs/decisions/ADR-0001-skill-body-word-ceiling.md \
  docs/ideas/leon-van-zyl-skill-collection.md docs/ideas/database-design-and-review.md \
  tests/evals/scenarios/assess-a-stale-standard.md docs/ideas/keel-on-codex.md \
  docs/ideas/profile-schema-drift.md docs/ideas/standards-assessment-remedies.md \
  docs/ideas/standards-that-bind.md docs/plans/2026-08-29-dart-flutter-stack-detection.md \
  docs/plans/2026-09-01-standards-assessment.md docs/plans/2026-09-02-the-four-mode-router-and-audit.md \
  docs/plans/2026-09-07-declared-profile-keys-take-effect.md docs/prd/standards-assessment.md \
  docs/audits/2026-09-29-skill-review.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths, and any other record the citation repair changed, and stop. **Do not
commit.** The coordinator commits after both review passes, with
`git commit -m "fix(skills): apply the skill review's findings to coding-standards"`. Paste the
`git status --porcelain` output into your report; if it lists anything this task did not touch, say
so and leave it unstaged.

**Review record, task 1, 2026-09-29.** Spec review COMPLIES; quality review nothing blocking, four
should-fix. Amended at execution, each re-reviewed (spec COMPLIES, quality nothing blocking):

- F-033, ruled by Bernard: the old line's second sentence, "`profile.stack.has_ui` says whether it
  does.", is removed too, since it no longer held on its own. Resolution carries the note.
- F-043, ruled by Bernard: "audit or author: both derive from that code, and author, which audit
  offers at its end, replaces this document", since audit never writes `standards.md`. Resolution
  `made task-1; composed: ...`. With F-033, the reference words are 22,700, not the simulated
  22,698.
- Documents F-017's deleted row made wrong: `docs/04-plugin-strategy.md` drops its claim about the
  Common mistakes row, and `tests/evals/scenarios/author-a-standard.md`'s fail line names Step 1.
- `docs/prd/standards-assessment.md:115`'s shorthand `:27` moves to `:26` with its range.
- Not acted on, recorded as leads: records quoting Step 4's old "noting any" wording (records keep
  their quotations, by this plan's design); assess has no disposition for a house default wired into
  tooling, which Step 4 now asks for, so check 1b can score it `Omitted`; several record citations
  into `coding-standards` were already off at HEAD and moved by the same offset (the PRD row above
  is four lines off); considers on Step 4's back-reference to Step 3, a lint-only request running
  every author step, the description's grammar, `resilience.md:100`'s payments framing, and the
  scenario's quoted phrase.

### Task 2: `repo-snapshot` and `shape-idea`

**Story:** S-03, S-04, S-05
**Files:**
- Modify: `skills/repo-snapshot/SKILL.md`, `skills/repo-snapshot/references/section-templates.md`,
  `skills/shape-idea/SKILL.md`, `skills/shape-idea/references/idea-template.md`
- Modify, by the citation repair: `docs/audits/2026-09-25-standards.md`,
  `docs/ideas/snapshot-citation-accuracy.md`, `docs/ideas/snapshot-records-its-own-path.md`,
  `docs/ideas/snapshot-surfaces-remediation-gaps.md`, `docs/ideas/standards-that-bind.md`,
  `docs/plans/2026-08-31-release-operations-and-claims-audit.md`,
  `docs/plans/2026-09-05-tiered-multi-harness-support.md`,
  `docs/plans/2026-09-07-declared-profile-keys-take-effect.md`, `docs/prd/profile-sync.md`,
  `docs/prd/standards-assessment.md`
- Modify: `docs/audits/2026-09-29-skill-review.md`, `CHANGELOG.md`
- Test: the applied check, over `170-179 230-239`

**Interfaces:**
- Consumes: the applied check and the citation repair.
- Produces: Resolutions with `task-2`.

**Depends on:** task 1

**Done when:** `python3 /tmp/skill-review-check.py 170-179 230-239` prints
`20 rows checked, 0 failing`, `tests/validate-skills.sh` and `tests/validate-citations.sh` both
pass, and `python3 /tmp/skill-review-repair.py 170-179 230-239` prints nothing.

- [x] **Step 2.1: Extract the test** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 2.2 to 2.4; 2.5's suite run witnessed by the implementer and the fixer only

Run the extraction command under "The applied check", from the repository root.

- [x] **Step 2.2: Run it and watch it fail** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 2.2 to 2.4; 2.5's suite run witnessed by the implementer and the fixer only

Run: `python3 /tmp/skill-review-check.py 170-179 230-239`
Expected: FAIL, `20 rows checked, 20 failing`, each on `Resolution 'open'`.

- [x] **Step 2.3: Apply F-170 to F-179 and F-230 to F-239** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 2.2 to 2.4; 2.5's suite run witnessed by the implementer and the fixer only

Apply every row in those two ranges under "How a row is applied". None is refused. Three rows edit
away from their `Where`, and rule 2 orders their edits separately: in
`skills/repo-snapshot/SKILL.md` F-175 deletes line 110 and appends to line 29, and F-174 deletes
line 109 and rewrites the table row on line 80, so that file's order runs 110, 109, then the other
rows down to 80, then down to 29. F-237 moves `idea-template.md` lines 47 to 54 out of the fence
into a new section after line 86, which is the fence's closing line: the section goes outside the
fence. It is two edits, and `idea-template.md`'s order is F-239 (98), the new section after 86,
F-238 (73-74), then the removal at 47 to 54, moving the lines exactly as listed. Removing them
first, or editing 73-74 first, moves line 86 off the fence, and a simulation that did so put the
section inside it. Then add under `## Unreleased`:

```markdown
- `repo-snapshot`, `shape-idea` and their references take the skill review's findings F-170 to
  F-179 and F-230 to F-239 (`docs/audits/2026-09-29-skill-review.md`).
```

Then run the citation repair: `python3 /tmp/skill-review-repair.py 170-179 230-239`. Expected: a
`PIN` line naming the findings file for each of the 20 rows, then these:

```text
MOVE docs/audits/2026-09-25-standards.md:127 skills/repo-snapshot/references/section-templates.md:28 -> skills/repo-snapshot/references/section-templates.md:26
PIN  docs/ideas/snapshot-citation-accuracy.md:92 skills/repo-snapshot/SKILL.md:70-71 -> `skills/repo-snapshot/SKILL.md` lines 70-71 at `bda1acc`
PIN  docs/ideas/snapshot-citation-accuracy.md:93 skills/repo-snapshot/references/section-templates.md:23-25 -> `skills/repo-snapshot/references/section-templates.md` lines 23-25 at `bda1acc`
MOVE docs/ideas/snapshot-citation-accuracy.md:97 skills/repo-snapshot/references/section-templates.md:12-13 -> skills/repo-snapshot/references/section-templates.md:11-12
MOVE docs/ideas/snapshot-citation-accuracy.md:229 skills/repo-snapshot/references/section-templates.md:12-13 -> skills/repo-snapshot/references/section-templates.md:11-12
MOVE docs/ideas/snapshot-records-its-own-path.md:74 skills/repo-snapshot/SKILL.md:87-88 -> skills/repo-snapshot/SKILL.md:90-91
MOVE docs/ideas/snapshot-surfaces-remediation-gaps.md:74 skills/repo-snapshot/references/section-templates.md:164 -> skills/repo-snapshot/references/section-templates.md:162
MOVE docs/ideas/snapshot-surfaces-remediation-gaps.md:78 skills/repo-snapshot/SKILL.md:55 -> skills/repo-snapshot/SKILL.md:56
MOVE docs/ideas/standards-that-bind.md:348 skills/repo-snapshot/references/section-templates.md:147 -> skills/repo-snapshot/references/section-templates.md:145
MOVE docs/plans/2026-08-31-release-operations-and-claims-audit.md:430 skills/repo-snapshot/references/section-templates.md:169 -> skills/repo-snapshot/references/section-templates.md:167
PIN  docs/plans/2026-09-05-tiered-multi-harness-support.md:3429 skills/shape-idea/SKILL.md:39 -> `skills/shape-idea/SKILL.md` line 39 at `bda1acc`
MOVE docs/plans/2026-09-07-declared-profile-keys-take-effect.md:65 skills/repo-snapshot/references/section-templates.md:257-258 -> skills/repo-snapshot/references/section-templates.md:255-256
MOVE docs/prd/profile-sync.md:95 skills/repo-snapshot/SKILL.md:88 -> skills/repo-snapshot/SKILL.md:91
MOVE docs/prd/standards-assessment.md:258 skills/repo-snapshot/references/section-templates.md:147 -> skills/repo-snapshot/references/section-templates.md:145
MOVE docs/prd/standards-assessment.md:304 skills/repo-snapshot/references/section-templates.md:147 -> skills/repo-snapshot/references/section-templates.md:145
```

- [x] **Step 2.4: Run it and watch it pass** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 2.2 to 2.4; 2.5's suite run witnessed by the implementer and the fixer only

Run: `python3 /tmp/skill-review-check.py 170-179 230-239 && tests/validate-skills.sh && tests/validate-citations.sh`
Expected: `20 rows checked, 0 failing`, then both validators pass. Then, from the repository root:

```bash
python3 /tmp/skill-review-repair.py 170-179 230-239
tr '\n' ' ' < skills/shape-idea/references/idea-template.md | tr -s ' ' | grep -oF 'Doing nothing is always listed' | wc -l
awk '/^ *```/ {f = !f; next} !f' skills/shape-idea/references/idea-template.md | tr '\n' ' ' | tr -s ' ' | grep -oF 'Doing nothing is always listed' | wc -l
grep -c '^## Filling in the case against$' skills/shape-idea/references/idea-template.md
```

Expected: the repair prints nothing, then `1`, `1` and `1`: F-237's text is in the file once, that
once is outside every fence, and its new heading exists. Before the task the second count is `0`,
the text being inside the template's fence. Report both bodies' word counts; `repo-snapshot` is
expected to grow, to about 755, and task 13 re-runs its scenario at that length.

- [x] **Step 2.5: Run the suite at the unit boundary, then hand over** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 2.2 to 2.4; 2.5's suite run witnessed by the implementer and the fixer only

Run: `tests/run-tests.sh`
Expected: PASS. The lint runs inside the suite.

```bash
git add skills/repo-snapshot/SKILL.md skills/repo-snapshot/references/section-templates.md \
  skills/shape-idea/SKILL.md skills/shape-idea/references/idea-template.md \
  docs/audits/2026-09-25-standards.md docs/ideas/snapshot-citation-accuracy.md \
  docs/ideas/snapshot-records-its-own-path.md docs/ideas/snapshot-surfaces-remediation-gaps.md \
  docs/ideas/standards-that-bind.md docs/plans/2026-08-31-release-operations-and-claims-audit.md \
  docs/plans/2026-09-05-tiered-multi-harness-support.md \
  docs/plans/2026-09-07-declared-profile-keys-take-effect.md docs/prd/profile-sync.md \
  docs/prd/standards-assessment.md docs/audits/2026-09-29-skill-review.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths, and any other record the citation repair changed, and stop. **Do not
commit.** The coordinator commits after both review passes, with
`git commit -m "fix(skills): apply the skill review's findings to repo-snapshot and shape-idea"`.
Paste the `git status --porcelain` output into your report.

**Review record, task 2, 2026-09-29.** Spec review COMPLIES; `repo-snapshot` ends at 748 words, not
the simulated 755, which the reviewer reconciled row by row, and two record citations moved one line
less than the simulation's, from a shorter rewrap. Quality review nothing blocking, two should-fix,
both ruled by Bernard and re-reviewed (spec COMPLIES, quality nothing blocking):

- F-237's moved text names its table, since outside the fence "below" and "this one" pointed at
  nothing: "Doing nothing is always listed in the Alternatives table, and its four rows come first.
  **Variants of the idea go in a separate table after it, not in it.**" Step 2.4's phrase still
  counts `1`. Resolution `made task-2; composed: ...`. The moved Status paragraph is rewrapped to
  100, words unchanged, checked by word diff rather than a third review.
- `section-templates.md`'s section 10 line, which F-171 made untrue, reads "Every item here was
  verified in step 3, or is a remedy cited to the assess report."
- Not acted on, recorded as leads: `docs/02-skill-catalog.md` still names the cursor-starter path, a
  ten-section snapshot, `write-prd --from-idea` and snapshot and init reinforcing each other, all
  wrong before this task; Step 3's unverified-claim rule now stated twice (F-172 and the step's
  close); the `asking-questions.md` link F-238 puts inside the fenced template; "its four rows" can
  misread; records already off at HEAD moved by the same offset; awkward ruled text in
  `shape-idea/SKILL.md` lines 20 and 83.

### Task 3: `write-prd` and `write-user-stories`

**Story:** S-03, S-04, S-05
**Files:**
- Modify: `skills/write-prd/SKILL.md`, `skills/write-prd/references/prd-template.md`,
  `skills/write-prd/references/questionnaire.md`, `skills/write-user-stories/SKILL.md`,
  `skills/write-user-stories/references/story-template.md`
- Modify, by the citation repair: `docs/audits/2026-08-19-efficiency.md`,
  `docs/ideas/snapshot-records-its-own-path.md`
- Modify: `docs/audits/2026-09-29-skill-review.md`, `CHANGELOG.md`
- Test: the applied check, over `306-338`

**Interfaces:**
- Consumes: the applied check and the citation repair.
- Produces: Resolutions with `task-3`.

**Depends on:** task 2

**Done when:** `python3 /tmp/skill-review-check.py 306-338` prints `33 rows checked, 0 failing`,
`tests/validate-skills.sh` and `tests/validate-citations.sh` both pass, and
`python3 /tmp/skill-review-repair.py 306-338` prints nothing.

- [x] **Step 3.1: Extract the test** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 3.2 to 3.4; 3.5's suite run witnessed by the implementer and the fixers only

Run the extraction command under "The applied check", from the repository root.

- [x] **Step 3.2: Run it and watch it fail** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 3.2 to 3.4; 3.5's suite run witnessed by the implementer and the fixers only

Run: `python3 /tmp/skill-review-check.py 306-338`
Expected: FAIL, `33 rows checked, 33 failing`.

- [x] **Step 3.3: Apply F-306 to F-338** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 3.2 to 3.4; 3.5's suite run witnessed by the implementer and the fixers only

Apply every row from F-306 to F-338 under "How a row is applied". F-307, F-308 and F-311 are
refused. F-338, from the between-skills section, rewrites `skills/write-prd/SKILL.md` lines 16-18 at
`bda1acc`.

**Three rows share `skills/write-prd/SKILL.md` lines 86-87 at `bda1acc`.** F-312, F-313 and F-314
each rewrite part of them, and they compose. Replace lines 86 and 87 with this, rewrapped at 100
columns:

```markdown
Where this PRD came from an idea record, strike through the questions it settles there first. Ask the blocking open questions (below), then present the PRD for approval and **stop**. Say plainly which requirements are `inferred`, `disputed` and `author-added`, because those are what the user is really being asked to rule on.
```

Set F-312 to `fixed task-3; composed with F-313 and F-314` and F-314 to
`made task-3; composed with F-312 and F-313`. F-313's own text is the passage's last sentence,
verbatim, so it is set to plain `made task-3` and the check reads it.

**`story-template.md` edits lines before moving them.** Highest line first, as rule 2 says: F-335
(line 121), then F-334 (line 90), then F-333 (lines 84-86). Then, per F-332, move the whole
`## Keeping the PRD current` section, from that heading to the last line before
`### Acceptance criteria rules` (lines 81 to 90 at `bda1acc`, and one more once F-334's rewrap has
grown it), to directly before `## Epics`, with one blank line after it. Set F-332 to
`made task-3; composed with F-333 and F-334, which edit the moved lines`.

Then add under `## Unreleased`:

```markdown
- `write-prd`'s approval gate covers a product surface; a single feature or bug routed to `tdd` or
  `debug` does not enter it (F-338). `write-prd`, `write-user-stories` and their references take
  the skill review's findings F-306 to F-337 (`docs/audits/2026-09-29-skill-review.md`).
```

Then run the citation repair: `python3 /tmp/skill-review-repair.py 306-338`. Expected: a `PIN` line
naming the findings file for each of the 33 rows, and one more (34 in the simulation), then these:

```text
MOVE docs/audits/2026-08-19-efficiency.md:114 skills/write-prd/SKILL.md:42 -> skills/write-prd/SKILL.md:41
MOVE docs/ideas/snapshot-records-its-own-path.md:73 skills/write-prd/SKILL.md:28 -> skills/write-prd/SKILL.md:27
MOVE docs/ideas/snapshot-records-its-own-path.md:84 skills/write-prd/SKILL.md:28 -> skills/write-prd/SKILL.md:27
MOVE docs/ideas/snapshot-records-its-own-path.md:115 skills/write-prd/SKILL.md:28 -> skills/write-prd/SKILL.md:27
```

- [x] **Step 3.4: Run it and watch it pass** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 3.2 to 3.4; 3.5's suite run witnessed by the implementer and the fixers only

Run: `python3 /tmp/skill-review-check.py 306-338 && tests/validate-skills.sh && tests/validate-citations.sh`
Expected: `33 rows checked, 0 failing`, then both validators pass. Then, from the repository root:

```bash
python3 /tmp/skill-review-repair.py 306-338
tr '\n' ' ' < skills/write-prd/SKILL.md | tr -s ' ' | grep -oF 'strike through the questions it settles' | wc -l
```

Expected: the repair prints nothing, and the count prints `1`, the composed text, which the check
skips for F-312 and F-314. Report both bodies' word counts.

- [x] **Step 3.5: Run the suite at the unit boundary, then hand over** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 3.2 to 3.4; 3.5's suite run witnessed by the implementer and the fixers only

Run: `tests/run-tests.sh`
Expected: PASS. The lint runs inside the suite.

```bash
git add skills/write-prd/SKILL.md skills/write-prd/references/prd-template.md \
  skills/write-prd/references/questionnaire.md skills/write-user-stories/SKILL.md \
  skills/write-user-stories/references/story-template.md \
  docs/audits/2026-08-19-efficiency.md docs/ideas/snapshot-records-its-own-path.md \
  docs/audits/2026-09-29-skill-review.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths, and any other record the citation repair changed, and stop. **Do not
commit.** The coordinator commits after both review passes, with
`git commit -m "fix(skills): apply the skill review's findings to write-prd and write-user-stories"`.
Paste the `git status --porcelain` output into your report.

**Review record, task 3, 2026-09-29.** Spec review DEVIATES on one point only: F-310 and F-326 made
`docs/02-skill-catalog.md`'s two Writes lines wrong, and this task's Files list did not name the
catalog. Amended to include it; the verified rows were kept and the catalog fixed on top, since the
deviation was an omission the task's own text caused, not wrong work. The citation repair moved
`write-prd` citations by one line up where the simulation had one line down, from a longer F-338
gate, and changed two records the task did not list, both staged; the shorthand `:31` beside a moved
citation in `docs/ideas/snapshot-records-its-own-path.md` moved to `:32` with it. Quality review
nothing blocking, two should-fix, ruled by Bernard and re-reviewed (spec COMPLIES, quality nothing
blocking):

- F-338's gate names where an exempt request goes: "A single feature or bug routed to `tdd` or
  `debug` does not enter this gate: name that skill and stop." The catalog's hard-gate sentence says
  the same. A first wording dropped "routed to", which turned away a request to specify one feature;
  the quality re-review caught it and "routed to" was restored.
- F-326: a mapped stories document is added to in place, in the skill and the catalog.
- Not acted on, recorded as leads: `docs/02-skill-catalog.md` lines already stale in this section
  (Reads without `profile.artifacts.prd`, "if refactoring", the cursor-starter paths F-318 removed);
  adding to a mapped stories document says nothing of continuing story IDs or its coverage table;
  "skipping it is not" reads after the exemption; `story-template.md:178`'s "(step 3)"; a pinned
  citation taking `docs/audits/2026-09-02-standards.md` line 126 to 116 columns, which the repair
  exception allows; partial citations on line 87 of the idea record.

`write-prd` ends at 794 words and `write-user-stories` at 657.

### Task 4: `design-architecture` and `design-database`

**Story:** S-03, S-04, S-05, S-06
**Files:**
- Modify: `skills/design-architecture/SKILL.md`, and in `skills/design-architecture/references/`:
  `adr-template.md`, `design-template.md`, `existing-mode.md`
- Modify: `skills/design-database/SKILL.md`, `skills/design-database/references/oracle.md`,
  `skills/design-database/references/review-template.md`
- Modify, by the citation repair: `docs/plans/2026-09-05-tiered-multi-harness-support.md`
- Modify: `docs/audits/2026-09-29-skill-review.md`, `CHANGELOG.md`
- Test: the applied check, over `71-94`

**Interfaces:**
- Consumes: the applied check and the citation repair.
- Produces: Resolutions with `task-4`.

**Depends on:** task 3

**Done when:** `python3 /tmp/skill-review-check.py 71-94` prints `24 rows checked, 0 failing`,
`tests/validate-skills.sh` and `tests/validate-citations.sh` both pass, and
`python3 /tmp/skill-review-repair.py 71-94` prints nothing.

- [x] **Step 4.1: Extract the test** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 4.2 to 4.4; 4.5's suite run witnessed by the implementer and the fixer only

Run the extraction command under "The applied check", from the repository root.

- [x] **Step 4.2: Run it and watch it fail** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 4.2 to 4.4; 4.5's suite run witnessed by the implementer and the fixer only

Run: `python3 /tmp/skill-review-check.py 71-94`
Expected: FAIL, `24 rows checked, 24 failing`.

- [x] **Step 4.3: Apply F-071 to F-094** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 4.2 to 4.4; 4.5's suite run witnessed by the implementer and the fixer only

Apply every row from F-071 to F-094 under "How a row is applied". F-072 is refused. F-083 is
`design-database`'s description. Two rows land away from their `Where`: F-071's `Where` is
`design-architecture/SKILL.md` line 23, and it inserts after line 27, so order it at 27; F-086
inserts before `design-database/SKILL.md` line 36. Then add under `## Unreleased`:

```markdown
- `design-database`'s description names reviewing an existing schema and proposing its
  remediation (F-083). `design-architecture`, `design-database` and their references take the skill
  review's findings F-071 to F-094 (`docs/audits/2026-09-29-skill-review.md`).
```

Then run the citation repair: `python3 /tmp/skill-review-repair.py 71-94`. Expected: a `PIN` line
naming the findings file for each of the 24 rows, then this:

```text
MOVE docs/plans/2026-09-05-tiered-multi-harness-support.md:3629 skills/design-architecture/SKILL.md:43 -> skills/design-architecture/SKILL.md:45
```

- [x] **Step 4.4: Run it and watch it pass** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 4.2 to 4.4; 4.5's suite run witnessed by the implementer and the fixer only

Run: `python3 /tmp/skill-review-check.py 71-94 && tests/validate-skills.sh && tests/validate-citations.sh`
Expected: `24 rows checked, 0 failing`, then both validators pass, with no description over 216
characters, and `python3 /tmp/skill-review-repair.py 71-94` prints nothing. Report both bodies' word
counts.

- [x] **Step 4.5: Run the suite at the unit boundary, then hand over** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 4.2 to 4.4; 4.5's suite run witnessed by the implementer and the fixer only

Run: `tests/run-tests.sh`
Expected: PASS. The lint runs inside the suite.

```bash
git add skills/design-architecture/SKILL.md skills/design-architecture/references/adr-template.md \
  skills/design-architecture/references/design-template.md \
  skills/design-architecture/references/existing-mode.md skills/design-database/SKILL.md \
  skills/design-database/references/oracle.md skills/design-database/references/review-template.md \
  docs/plans/2026-09-05-tiered-multi-harness-support.md \
  docs/audits/2026-09-29-skill-review.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths, and any other record the citation repair changed, and stop. **Do not
commit.** The coordinator commits after both review passes, with
`git commit -m "fix(skills): apply the skill review's findings to design-architecture and design-database"`.
Paste the `git status --porcelain` output into your report.

**Review record, task 4, 2026-09-29.** Spec and quality reviews ran in parallel. Spec review
DEVIATES on one point only, as in task 3: F-084 removed the hand-off to `write-docs`, and
`docs/02-skill-catalog.md` still claimed it on two lines. Amended to include the catalog; the
verified rows were kept. Quality review nothing blocking, four should-fix: the catalog, and three
that applying rows as written caused, each ruled by Bernard. All re-reviewed (spec COMPLIES,
quality nothing blocking):

- F-071: "In `adr` mode, do Step 5 and stop.", since Step 6 traces a design an ADR does not write.
  Resolution `made task-4; composed: ...`.
- `review-template.md` section 8, whose opening F-094 deleted, now reads "For each finding, in the
  order the skill's Step 4 sets, the smallest correct change."
- The heading over F-092's sentence becomes "What `None found` claims"; the rule it used to name
  lives in the skill's Step 3.
- Not acted on, recorded as leads: F-086's "instead" comes before the paragraph it is an
  alternative to; `existing-mode.md` line 3 still says "`--existing` run", wrong before this task;
  the skill names no path for its review document; F-093's link line is 117 columns; "omitting the
  section" has no noun before it.

`design-architecture` ends at 653 words and `design-database` at 478.

### Task 5: `write-plan`, and the batch reasons as F-344

**Story:** S-03, S-04, S-05, S-06
**Files:**
- Modify: `skills/write-plan/SKILL.md`, `skills/write-plan/references/plan-review.md`,
  `skills/write-plan/references/plan-template.md`
- Modify, by the citation repair: `docs/ideas/profile-schema-drift.md`,
  `docs/plans/2026-09-05-tiered-multi-harness-support.md`,
  `docs/plans/2026-09-28-skill-review-findings.md`
- Modify: `docs/audits/2026-09-29-skill-review.md`, `CHANGELOG.md`
- Test: the applied check, over `285-305 340 344`

**Interfaces:**
- Consumes: the applied check and the citation repair.
- Produces: finding F-344 in the findings file; Resolutions with `task-5`.

**Depends on:** task 4

**Done when:** `python3 /tmp/skill-review-check.py 285-305 340 344` prints
`23 rows checked, 0 failing`, `tests/validate-skills.sh` and `tests/validate-citations.sh` both
pass, and `python3 /tmp/skill-review-repair.py 285-305 340 344` prints nothing.

- [x] **Step 5.1: Write the failing test: record F-344** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 5.1 to 5.4; 5.5's suite run witnessed by the implementer and the fixer only

Run the extraction command under "The applied check", from the repository root. The check
exists; this task's new row does not. Add this row as the last row of the table under
`### skills/write-plan/references/plan-template.md` in `docs/audits/2026-09-29-skill-review.md`,
as one line:

```markdown
| F-344 | skills/write-plan/references/plan-template.md:186-189 | contradiction | Two reasons assume batched tasks share one tree, against `:125-126`, where each runs `in its own worktree ... because the worktree is private`: `:186-189` `A whole-suite Done when: inside a batch cannot pass, because task 2's step 1 writes a failing test on purpose while task 1 is running`, and `:220-222` `with a sibling's failing test in the suite, every agent's step 2 sees red`. Reached when a batch runs as the template says, in worktrees. | `:186-189` becomes `` A whole-suite `Done when:` inside a batch proves nothing about the batch: each worktree holds only its own task's change, so the suite that means anything is the one at the join, where every sibling's change first meets the others. `` and `:220-222` becomes `` The failure these prevent is quieter than a lost race, and it is what a batch run in one shared tree produces: with a sibling's failing test in the suite, every agent's step 2 sees red for the wrong reason and ticks the box, so *"the TDD gate silently stops proving anything"*. A worktree per task is what keeps each suite to its own task. `` | the shared-tree reason for scoping a batched task's Done when, at skills/write-plan/references/plan-template.md:186-189, replaced by the worktree reason | approved 2026-09-29 | open |
```

In the summary paragraph at the top of that file make these replacements, then rewrap the
paragraph. The paragraph is wrapped, so match each old text with whitespace ignored: two of them
cross a line break.

- `343 findings:` becomes `344 findings:`, and `43 contradiction` becomes `44 contradiction`.
- `143 findings would remove` becomes `144 findings would remove`, and `119 approved` becomes
  `120 approved`.
- `Twelve leads were dropped in verification.` becomes `Eleven leads were dropped in verification.`
  The twelve counted the half-finding the next item records, and it is no longer dropped.
- This sentence is deleted:

  ```text
  One half of a finding on `write-plan`'s batch reasons needs a decision rather than a text fix.
  ```

- After the sentence `Four between-skill leads duplicated a finding already recorded at the same
  lines.`, this one is added:

  ```text
  The half of a finding on `write-plan`'s batch reasons that needed a decision was decided on 2026-09-29 and is F-344.
  ```

- [x] **Step 5.2: Run it and watch it fail** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 5.1 to 5.4; 5.5's suite run witnessed by the implementer and the fixer only

Run: `python3 /tmp/skill-review-check.py 285-305 340 344`
Expected: FAIL, `23 rows checked, 23 failing`, F-344 among them.

- [x] **Step 5.3: Apply F-285 to F-305, F-340 and F-344** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 5.1 to 5.4; 5.5's suite run witnessed by the implementer and the fixer only

Apply every row under "How a row is applied". None is refused. F-285 is the description, and F-340,
from the between-skills section, rewrites `skills/write-plan/SKILL.md` line 24 at `bda1acc`. In
`plan-template.md`, F-344's two replacements are the passages from `A whole-suite` on line 186 to
`cannot all pass."*` on line 189, and all of lines 220 to 222; apply the one at 220 first.

F-302 deletes a row whose `Removes` says the rule is kept at `plan-template.md` lines 316-317,
lines F-301 replaces. Set F-302 to `made task-5; the rule is kept in the skill's Step 4, No
placeholders, since F-301 replaces plan-template.md lines 316-317`.

Then add under `## Unreleased`:

```markdown
- `write-plan` stops and names `write-user-stories` when no stories exist, rather than invoking it
  (F-340), and its description no longer claims "how to build something", which is
  `design-architecture`'s (F-285). The plan template's batch rules give the worktree reason (F-344).
  `write-plan` and its references take the skill review's findings F-285 to F-305.
```

Then run the citation repair: `python3 /tmp/skill-review-repair.py 285-305 340 344`. Expected: a
`PIN` line naming the findings file for each of the 23 rows, and one more (24 in the simulation),
then these:

```text
MOVE docs/ideas/profile-schema-drift.md:82 skills/write-plan/SKILL.md:26 -> skills/write-plan/SKILL.md:27
PIN  docs/plans/2026-09-05-tiered-multi-harness-support.md:3427 skills/write-plan/SKILL.md:44 -> `skills/write-plan/SKILL.md` line 44 at `bda1acc`
PIN  docs/plans/2026-09-05-tiered-multi-harness-support.md:3437 skills/write-plan/SKILL.md:93 -> `skills/write-plan/SKILL.md` line 93 at `bda1acc`
MOVE docs/plans/2026-09-28-skill-review-findings.md:361 skills/write-plan/SKILL.md:77-81 -> skills/write-plan/SKILL.md:81-85
```

- [x] **Step 5.4: Run it and watch it pass** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 5.1 to 5.4; 5.5's suite run witnessed by the implementer and the fixer only

Run: `python3 /tmp/skill-review-check.py 285-305 340 344 && tests/validate-skills.sh && tests/validate-citations.sh`
Expected: `23 rows checked, 0 failing`, then both validators pass, and
`python3 /tmp/skill-review-repair.py 285-305 340 344` prints nothing. Report the `write-plan` body's
word count. It is expected at about 760, over 700, which task 13's length arm covers.

- [x] **Step 5.5: Run the suite at the unit boundary, then hand over** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 5.1 to 5.4; 5.5's suite run witnessed by the implementer and the fixer only

Run: `tests/run-tests.sh`
Expected: PASS. `tests/validate-skills.sh` checks the plan template's step ids, so a wrong edit
inside a fence shows here. The lint runs inside the suite.

```bash
git add skills/write-plan/SKILL.md skills/write-plan/references/plan-review.md \
  skills/write-plan/references/plan-template.md docs/ideas/profile-schema-drift.md \
  docs/plans/2026-09-05-tiered-multi-harness-support.md docs/plans/2026-09-28-skill-review-findings.md \
  docs/audits/2026-09-29-skill-review.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths, and any other record the citation repair changed, and stop. **Do not
commit.** The coordinator commits after both review passes, with
`git commit -m "fix(skills): apply the skill review's findings to write-plan"`.
Paste the `git status --porcelain` output into your report.

**Review record, task 5, 2026-09-29.** Spec and quality reviews ran in parallel. Spec review
DEVIATES on one point only, as in tasks 3 and 4: F-287 and F-289 made the catalog's `write-plan`
Writes line and its five-step shape wrong. Amended to include the catalog; the verified rows and the
F-344 record were kept. The catalog's longer paragraph moved three record citations into it, which
the repair followed. Quality review nothing blocking, six should-fix, ruled by Bernard and
re-reviewed (spec COMPLIES, quality nothing blocking):

- Three `plan-template.md` sentences the rows made untrue: the batch exception names its own
  worktrees ("whose tasks commit inside their own worktrees ... merges each worktree back"), since
  F-296 dropped what "that worktree" pointed back to, and F-296 is `composed`; the shared-tree harm
  is scoped "in one shared tree", against F-299; the `Done when:` rule says a whole-suite gate in a
  batch "also proves nothing", matching F-344.
- The findings summary's "The other fifteen" becomes sixteen, F-344 being a removal decided singly.
- `execute-plan`'s `parallel-batches.md` still argues the shared-tree reason F-344 replaced.
  Recorded as a new finding, F-346, which task 6 adds and applies.
- Not acted on, recorded as leads: "the same baseline run predicted the failure" now points at a
  quote F-344 removed; "that deliverable" after F-300; F-344's text credits both the rules and the
  worktree; Step 4 gives every task a suite run while a batched task's suite runs at the join;
  `plan-template.md` line 3 names only the default plans path; the catalog Writes line is 112
  columns, like its neighbours.

`write-plan` ends at 761 words, over 700, which task 13's length arm covers.

### Task 6: `execute-plan`

**Story:** S-03, S-04, S-05, S-06
**Files:**
- Modify: `skills/execute-plan/SKILL.md`, and in `skills/execute-plan/references/`:
  `parallel-batches.md`, `preconditions.md`, `subagent-prompts.md`
- Modify: `tests/evals/scenarios/commit-outside-a-worktree.md`, `docs/02-skill-catalog.md`
- Modify, by the citation repair: `docs/audits/2026-09-25-standards.md`,
  `docs/ideas/addressable-plan-steps.md`, `docs/prd/addressable-plan-steps.md`,
  `docs/stories/addressable-plan-steps.md`
- Modify: `docs/audits/2026-09-29-skill-review.md`, `CHANGELOG.md`
- Test: the applied check, over `95-118 343 346`; `tests/test-eval-harness.sh`; `tests/test-plan.sh`

**Interfaces:**
- Consumes: the applied check and the citation repair.
- Produces: finding F-346 in the findings file; Resolutions with `task-6`.

**Depends on:** task 5

**Done when:** `python3 /tmp/skill-review-check.py 95-118 343 346` prints
`26 rows checked, 0 failing`; `tests/test-eval-harness.sh`, `tests/test-plan.sh`,
`tests/validate-skills.sh` and `tests/validate-citations.sh` pass; and
`python3 /tmp/skill-review-repair.py 95-118 343 346` prints nothing.

- [x] **Step 6.1: Write the failing test: record F-346** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 6.1 to 6.4; 6.5's suite run witnessed by the implementer and the fixer only

Run the extraction command under "The applied check", from the repository root. The task 5 review
found `parallel-batches.md` arguing the shared-tree reason F-344 replaced, and Bernard ruled it a
finding on 2026-09-29. Add this row as the last row of the table under
`### skills/execute-plan/references/parallel-batches.md` in `docs/audits/2026-09-29-skill-review.md`,
as one line:

```markdown
| F-346 | skills/execute-plan/references/parallel-batches.md:27-29 | contradiction | `Task 2's step 1 writes a failing test on purpose. That is TDD working. It also turns task 1's whole-suite gate red through no fault of task 1` holds only in one shared tree, against `:40-41`, where each agent works `in its own checkout so no two write the same tree`, and against `plan-template.md`'s batch rule, where a whole-suite gate in a batch proves nothing because each worktree holds only its own task's change. Reached when a batch runs as this file says, in separate checkouts. | `Task 2's step 1 writes` becomes `In one shared tree, task 2's step 1 writes`, and a paragraph is inserted after `:29` reading `In a worktree the whole-suite gate proves nothing instead: each holds only its own task's change, so the suite that means anything is the one at the join.` | nothing | approved 2026-09-29 | open |
```

In the summary paragraph at the top of that file, matching with whitespace ignored,
`344 findings:` becomes `345 findings:` and `44 contradiction` becomes `45 contradiction`, and this
sentence is added at the paragraph's end:

```markdown
F-346, `execute-plan`'s batch reason for the shared tree F-344 replaced, was found by the task 5
review on 2026-09-29 and approved.
```

Then rewrap the paragraph.

- [x] **Step 6.2: Run it and watch it fail** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 6.1 to 6.4; 6.5's suite run witnessed by the implementer and the fixer only

Run: `python3 /tmp/skill-review-check.py 95-118 343 346`
Expected: FAIL, `26 rows checked, 26 failing`, F-346 among them.

- [x] **Step 6.3: Apply F-095 to F-118 and F-343, and the copies they make wrong** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 6.1 to 6.4; 6.5's suite run witnessed by the implementer and the fixer only

Apply every row under "How a row is applied". None is refused. F-095 is the description; F-343, from
the between-skills section, rewrites `skills/execute-plan/SKILL.md` lines 88-89 at `bda1acc`.
In `parallel-batches.md`, F-346 is its two edits at lines 27 to 29, the rewrite and the paragraph
inserted after line 29, so it comes last in that file's order. Its inserted paragraph adds two
lines, so the repair's `parallel-batches.md` targets below land two lines further down than the
simulation, which ran before F-346 existed.
**Apply the row deletions F-102 to F-105 before F-343**: the body is 897 words, and the findings
file's summary counts it at 889 only with them gone.

**F-100 keeps two line breaks.** `tests/test-plan.sh` greps `skills/execute-plan/SKILL.md` line by
line for the two lines after the one F-100 rewrites. Apply F-100 to line 71 alone and do not rewrap
the paragraph, so it reads:

```markdown
For each task: follow its steps exactly, run its `Done when:` command, then
hand over as the task specifies. Resume with `keel plan status`; tick with `keel plan tick`, or by
hand where `keel` cannot run or reports the plan unaddressable.
```

**F-111 changes a block a scenario carries verbatim.** `tests/test-eval-harness.sh` requires
`tests/evals/scenarios/commit-outside-a-worktree.md` to carry `subagent-prompts.md`'s
`=== RULES ===` block verbatim, and F-111 rewrites that block's last paragraph. Keeping the
scenario's copy in step is what the harness asks; it writes no new scenario, so FR-10 holds. After
the `subagent-prompts.md` rows, replace the scenario's copy with the skill's block, from the
repository root:

```bash
sc=tests/evals/scenarios/commit-outside-a-worktree.md
src=skills/execute-plan/references/subagent-prompts.md
{ awk '$0 == "=== RULES ===" {exit} {print}' "$sc"
  awk '$0 == "=== RULES ===" {f = 1} f && $0 == "```" {exit} f {print}' "$src"; } > "$sc.new" && mv "$sc.new" "$sc"
git diff --stat "$sc"
```

Expected: `1 file changed, 3 insertions(+), 3 deletions(-)`, the paragraph F-111 rewrote.

**`docs/02-skill-catalog.md` states the rule F-343 replaces.** Its `execute-plan` entry,
`**REQUIRED SUB-SKILL:** `tdd` for every task, `debug` on any failure.`, becomes
`**REQUIRED SUB-SKILL:** `tdd` for every task, `debug` through Phase 3 for a failure the task caused.`,
one line of 100 characters.

Then add under `## Unreleased`:

```markdown
- `execute-plan` sends a task's own failure to `debug` through Phase 3 only, so a delegated
  coordinator still writes no production code, and a red already in `tdd`'s start record is
  recorded rather than debugged (F-343); `docs/02-skill-catalog.md` says the same. `execute-plan`
  and its references take the skill review's findings F-095 to F-118, and F-346, which scopes
  `parallel-batches.md`'s shared-tree reason to a shared tree.
```

Then run the citation repair: `python3 /tmp/skill-review-repair.py 95-118 343 346`. Expected: a `PIN`
line naming the findings file for each of the 26 rows, and one more (26 for 25 rows in the simulation), then
these:

```text
MOVE docs/audits/2026-09-25-standards.md:124 skills/execute-plan/SKILL.md:56-61 -> skills/execute-plan/SKILL.md:57-62
MOVE docs/ideas/addressable-plan-steps.md:24 skills/execute-plan/references/parallel-batches.md:96 -> skills/execute-plan/references/parallel-batches.md:98
MOVE docs/prd/addressable-plan-steps.md:36 skills/execute-plan/references/parallel-batches.md:96 -> skills/execute-plan/references/parallel-batches.md:98
MOVE docs/stories/addressable-plan-steps.md:305 skills/execute-plan/references/parallel-batches.md:96 -> skills/execute-plan/references/parallel-batches.md:98
```

- [x] **Step 6.4: Run it and watch it pass** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 6.1 to 6.4; 6.5's suite run witnessed by the implementer and the fixer only

Run: `python3 /tmp/skill-review-check.py 95-118 343 346 && tests/test-eval-harness.sh && tests/test-plan.sh && tests/validate-skills.sh && tests/validate-citations.sh`
Expected: `26 rows checked, 0 failing`, then all four pass; `validate-skills.sh` fails a body over
900, so a pass is the ceiling check. `python3 /tmp/skill-review-repair.py 95-118 343 346` prints
nothing. Report the body's word count, expected about 889.

- [x] **Step 6.5: Run the suite at the unit boundary, then hand over** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 6.1 to 6.4; 6.5's suite run witnessed by the implementer and the fixer only

Run: `tests/run-tests.sh`
Expected: PASS. The lint runs inside the suite.

```bash
git add skills/execute-plan/SKILL.md skills/execute-plan/references/parallel-batches.md \
  skills/execute-plan/references/preconditions.md skills/execute-plan/references/subagent-prompts.md \
  tests/evals/scenarios/commit-outside-a-worktree.md docs/02-skill-catalog.md \
  docs/audits/2026-09-25-standards.md docs/ideas/addressable-plan-steps.md \
  docs/prd/addressable-plan-steps.md docs/stories/addressable-plan-steps.md \
  docs/audits/2026-09-29-skill-review.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths, and any other record the citation repair changed, and stop. **Do not
commit.** The coordinator commits after both review passes, with
`git commit -m "fix(skills): apply the skill review's findings to execute-plan"`.
Paste the `git status --porcelain` output into your report.

**Review record, task 6, 2026-09-29.** Spec and quality reviews ran in parallel. Spec review
DEVIATES on one point only, as in tasks 3 to 5: F-097 and F-109 took `main` out of the skill, and
the catalog's `execute-plan` entry still said "Never starts on `main`." Fixed on top; the verified
rows and the F-346 record were kept. F-346's inserted paragraph added three lines, not two, so the
repair's `parallel-batches.md` targets landed at 101, and it pinned two records citing the rewritten
line 40. Quality review nothing blocking, four should-fix, ruled by Bernard and re-reviewed (spec
COMPLIES, quality nothing blocking):

- The join's red suite: "Use `keel:debug` through Phase 3, then send its Phase 4 to a fresh
  implementer", matching F-343's limit.
- F-346's paragraph reads "In separate worktrees", and the quiet-failure paragraph after it is
  scoped "In that shared tree". Resolution `fixed task-6; composed: ...`.
- `CONTRIBUTING.md` no longer counts `execute-plan` among bodies with an arm at their current
  length: at 889 it owes one, last passed at 884. `docs/standards.md` says it "was at 884". Both
  were wrong before this task. The same `CONTRIBUTING.md` sentence still lists `coding-standards` at
  795 and `write-prd` at 793, which tasks 1 and 3 moved to 726 and 794; task 13 corrects them with
  its arms.
- Not acted on, recorded as leads: `subagent-prompts.md`'s "Paste the standards too" and "the
  mistake the skill names", both still readable; the duplicate `parallel-batches.md` link after
  F-099; "through Phase 3" read literally in inline mode, where nobody owns Phase 4; debug's Phase 3
  change at the join is a coordinator edit to revert before the merge commit; three record lines
  the repair took past 100 columns; the PRD's shorthand `:345-354`.

`execute-plan` ends at 889 words, 11 under the ceiling.

### Task 7: `tdd`, `debug`, `refactor` and `optimize-performance`

**Story:** S-03, S-04, S-05, S-06
**Files:**
- Modify: `skills/tdd/SKILL.md`, `skills/tdd/references/rationalisations.md`,
  `skills/tdd/references/writing-good-tests.md`
- Modify: `skills/debug/SKILL.md`, `skills/debug/references/boundary-instrumentation.md`
- Modify: `skills/refactor/SKILL.md`, `skills/optimize-performance/SKILL.md`
- Modify: `docs/02-skill-catalog.md`, `docs/prd/skill-and-reference-review.md`,
  `docs/ideas/skill-and-reference-review.md`
- Modify, by the citation repair: `docs/ideas/tdd-cycle-cost-and-case-coverage.md`,
  `docs/plans/2026-09-06-tdd-cycle-unit-and-mutation.md`
- Modify: `docs/audits/2026-09-29-skill-review.md`, `CHANGELOG.md`
- Test: the applied check, over `253-261 62-70 164-169 139-147`

**Interfaces:**
- Consumes: the applied check and the citation repair.
- Produces: Resolutions with `task-7`.

**Depends on:** task 6

**Done when:** `python3 /tmp/skill-review-check.py 253-261 62-70 164-169 139-147` prints
`33 rows checked, 0 failing`, `tests/validate-skills.sh` and `tests/validate-citations.sh` both
pass, and `python3 /tmp/skill-review-repair.py 253-261 62-70 164-169 139-147` prints nothing.

- [x] **Step 7.1: Extract the test** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 7.2 to 7.4; 7.5's suite run witnessed by the implementer and the fixer only

Run the extraction command under "The applied check", from the repository root.

- [x] **Step 7.2: Run it and watch it fail** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 7.2 to 7.4; 7.5's suite run witnessed by the implementer and the fixer only

Run: `python3 /tmp/skill-review-check.py 253-261 62-70 164-169 139-147`
Expected: FAIL, `33 rows checked, 32 failing`. F-253 already passes: it was fixed at `268a950`.

- [x] **Step 7.3: Apply the rows, and the documents they make wrong** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 7.2 to 7.4; 7.5's suite run witnessed by the implementer and the fixer only

Apply every row in the four ranges under "How a row is applied", except F-253, which is done. F-140
and F-164 are refused. F-062 and F-139 are description findings, F-139's fix being a line in
`optimize-performance`'s Step 1. F-069 replaces the credential idiom that prints the value;
`docs/audits/2026-09-29-security-skill-review.md` names it as open until this plan.

Two rows edit away from their `Where` in `skills/optimize-performance/SKILL.md`, and rule 2 orders
their edits by where they land: F-146 deletes line 77 and rewrites the passage on line 54 that its
text rewrites, from `Reverting` to the end of that sentence, keeping `nothing.` before it; F-139,
whose `Where` is the description on line 3, inserts after line 22. That file's order runs 77, the
rows between, 61-62 (F-142 below), 54, then 22.

**F-142 keeps the sub-skill marker.** Its proposal drops `**REQUIRED SUB-SKILL:**`, which
`docs/01-architecture.md` requires for a cross-reference. Replace
`skills/optimize-performance/SKILL.md` lines 61-62 at `bda1acc` with this instead, and set F-142 to
`fixed task-7; composed to keep the REQUIRED SUB-SKILL marker that docs/01-architecture.md requires`:

```markdown
If the optimisation changes behaviour at all, stop: **REQUIRED SUB-SKILL:** `keel:tdd` first, test
before code. A faster wrong answer is worse than a slow right one.
```

**The documents these rows make wrong:**

- `docs/02-skill-catalog.md`, the `debug` entry, for F-062: `unexpected behaviour, performance
  anomaly, build` becomes `unexpected behaviour, build`, then rewrap that paragraph. It stays two
  lines.
- `docs/prd/skill-and-reference-review.md`, in its problem statement, this passage:

  ```text
  `skills/tdd/SKILL.md:87` tells every project its suite takes
  313 seconds, which is keel's own `tests/run-tests.sh` as measured for ADR-0006.
  ```

  becomes this, rewrapped with its paragraph:

  ```text
  `skills/tdd/SKILL.md:87` told every project its suite takes 313 seconds, which was keel's own `tests/run-tests.sh` as measured for ADR-0006, until commit `268a950`.
  ```

- `docs/ideas/skill-and-reference-review.md`, in its first bullet, this passage:

  ```text
  says "The suite is 313 seconds and one test is 2." That is keel's own
  ```

  becomes this, rewrapped with its bullet:

  ```text
  said "The suite is 313 seconds and one test is 2." until commit `268a950`. That was keel's own
  ```

Then add under `## Unreleased`:

```markdown
- `debug`'s credential check prints `SET`, `EMPTY` or `UNSET` and never the value (F-069), and its
  description drops "performance anomaly", which no step handles (F-062). `optimize-performance`
  sends a behaviour change through `tdd` before the code changes (F-142). `tdd`, `debug`,
  `refactor`, `optimize-performance` and their references take the skill review's findings.
```

Then run the citation repair: `python3 /tmp/skill-review-repair.py 253-261 62-70 164-169 139-147`.
Expected: a `PIN` line naming the findings file for each of the 33 rows, then these:

```text
MOVE docs/ideas/tdd-cycle-cost-and-case-coverage.md:190 skills/debug/SKILL.md:68 -> skills/debug/SKILL.md:69
MOVE docs/plans/2026-09-06-tdd-cycle-unit-and-mutation.md:199 skills/debug/SKILL.md:68 -> skills/debug/SKILL.md:69
```

- [x] **Step 7.4: Run it and watch it pass** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 7.2 to 7.4; 7.5's suite run witnessed by the implementer and the fixer only

Run: `python3 /tmp/skill-review-check.py 253-261 62-70 164-169 139-147 && tests/validate-skills.sh && tests/validate-citations.sh`
Expected: `33 rows checked, 0 failing`, then both validators pass. Then, from the repository root:

```bash
python3 /tmp/skill-review-repair.py 253-261 62-70 164-169 139-147
tr '\n' ' ' < skills/optimize-performance/SKILL.md | tr -s ' ' | grep -oF 'REQUIRED SUB-SKILL:** `keel:tdd` first' | wc -l
```

Expected: the repair prints nothing, and the count prints `1`. Run F-069's replacement idiom in a
shell three times, with the variable set to `secret123`, set empty, and unset, and confirm it prints
`SET`, `EMPTY` and `UNSET` and no part of the value; quote the output. Report the four bodies' word
counts.

- [x] **Step 7.5: Run the suite at the unit boundary, then hand over** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 7.2 to 7.4; 7.5's suite run witnessed by the implementer and the fixer only

Run: `tests/run-tests.sh`
Expected: PASS. The lint runs inside the suite.

```bash
git add skills/tdd/SKILL.md skills/tdd/references/rationalisations.md \
  skills/tdd/references/writing-good-tests.md skills/debug/SKILL.md \
  skills/debug/references/boundary-instrumentation.md skills/refactor/SKILL.md \
  skills/optimize-performance/SKILL.md docs/02-skill-catalog.md \
  docs/prd/skill-and-reference-review.md docs/ideas/skill-and-reference-review.md \
  docs/ideas/tdd-cycle-cost-and-case-coverage.md docs/plans/2026-09-06-tdd-cycle-unit-and-mutation.md \
  docs/audits/2026-09-29-skill-review.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths, and any other record the citation repair changed, and stop. **Do not
commit.** The coordinator commits after both review passes, with
`git commit -m "fix(skills): apply the skill review's findings to tdd, debug, refactor and optimize-performance"`.
Paste the `git status --porcelain` output into your report.

**Review record, task 7, 2026-09-29.** Spec and quality reviews ran in parallel. Spec review
COMPLIES; the repair's output matched the simulation exactly. Quality review nothing blocking,
three should-fix, ruled by Bernard and re-reviewed (spec COMPLIES, quality nothing blocking):

- F-069's idiom, and F-067's Layer 1 copy of it, printed the credential in a shell trace: under
  `set -x`, which Jenkins' `sh` steps run by default, `[ -n "$VAR" ]` traces the value. Both now
  test `"${VAR:+x}"`, which traces only `x`; checked under `bash -xu`, `sh -xe` and `dash`, with
  the value set, empty and unset. Both Resolutions are `composed`. F-345's row in task 9 is amended
  to the same form, and step 9.4 runs it under `bash -xu`.
- `writing-good-tests.md`'s "why the rule picks the smaller one", whose rule F-258 deleted there,
  reads "why the skill's RED step names the smallest change".
- F-139's regression line called the last good commit the baseline, which Step 1 defines as the
  current measurement: it reads "its number is the target". Resolution `composed`.
- Not acted on, recorded as leads: F-142's text still sits in Step 5, after Step 4 changed the code,
  and the changelog's "before the code changes" overstates it; Layer 2's `env | grep -c` exits
  under `set -e` in the absent case; debug Phase 3's "Do not fix three things" and "Do not stack
  another fix" describe fixes in a phase that has none, and nothing says to undo a refuted
  experiment; F-255 removed the row the `tdd-under-deadline` arm quoted for "backfill", which task
  13 re-runs.

Bodies: `tdd` 855, `debug` 687, `refactor` 419, `optimize-performance` 497.

### Task 8: `security-audit` and `ship`, and the audit gate key

**Story:** S-03, S-04, S-05, S-06
**Files:**
- Modify: `skills/security-audit/SKILL.md`, and in `skills/security-audit/references/`:
  `owasp-checklist.md`, `payments-checklist.md`, `report-template.md`, `stride.md`
- Modify: `skills/ship/SKILL.md`, `skills/ship/references/standards-gate.md`
- Modify: `templates/profile.schema.json`, `docs/profile-keys.md` (generated),
  `docs/02-skill-catalog.md`
- Modify, by the citation repair: `docs/ideas/plain-language-chat.md`,
  `docs/ideas/profile-validation-gaps.md`, `docs/ideas/stack-plugins-on-existing-repos.md`,
  `docs/plans/2026-08-31-release-operations-and-claims-audit.md`,
  `docs/plans/2026-09-05-tiered-multi-harness-support.md`,
  `docs/plans/2026-09-28-addressable-plan-steps.md`, `docs/prd/coding-standards-enforcement.md`,
  `docs/prd/plain-language-chat.md`, `docs/prd/standards-assessment.md`,
  `docs/stories/coding-standards-enforcement.md`
- Modify: `docs/audits/2026-09-29-skill-review.md`, `CHANGELOG.md`
- Test: the applied check, over `195-212 240-252 339 341`; `tests/validate-skills.sh`, which
  compares the schema with `docs/profile-keys.md` and checks each `x-keel-read-by` phrase;
  `tests/test-harness-claims.sh`

**Interfaces:**
- Consumes: the applied check and the citation repair; `tests/generate-profile-keys.sh`, which
  writes `docs/profile-keys.md` from the schema.
- Produces: Resolutions with `task-8`; `gates.security_audit` read by both skills.

**Depends on:** task 7

**Done when:** `python3 /tmp/skill-review-check.py 195-212 240-252 339 341` prints
`33 rows checked, 0 failing`; `tests/validate-skills.sh`, `tests/test-harness-claims.sh`,
`tests/test-profile-keys.sh` and `tests/validate-citations.sh` pass; and
`python3 /tmp/skill-review-repair.py 195-212 240-252 339 341` prints nothing.

- [x] **Step 8.1: Extract the test, and make the key's test red** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 8.3 to 8.4; 8.1 and 8.2's reds and 8.5's suite run witnessed by the implementer and the fixers only

Run the extraction command under "The applied check". Then, in `templates/profile.schema.json`,
under `gates.security_audit`, replace the `description` and `x-keel-read-by` values with these,
leaving `docs/profile-keys.md` alone for now. The description says "a match on a hard-block path"
rather than naming the key, because `tests/test-harness-claims.sh` reads the key's name in
`docs/profile-keys.md` as an unregistered harness claim:

```json
          "description": "Whether security-audit runs before a change ships, and what its findings do. required says any finding blocks shipping unless the user names an override for it; warn reports the findings and leaves accepting them to the user; off skips the audit, and the report says so. A match on a hard-block path is never overridable in conversation, whatever this says. Read by `skills/security-audit/SKILL.md` and by ship's gate item 4, advisorily: it is prose the model follows, not a hook that asserts it, and it applies on both harnesses because skill bodies do.",
          "x-keel-read-by": [
            "advisory:skills/security-audit/SKILL.md#gates.security_audit",
            "advisory:skills/ship/SKILL.md#gates.security_audit"
          ]
```

- [x] **Step 8.2: Run them and watch them fail** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 8.3 to 8.4; 8.1 and 8.2's reds and 8.5's suite run witnessed by the implementer and the fixers only

Run: `python3 /tmp/skill-review-check.py 195-212 240-252 339 341; tests/validate-skills.sh`
Expected: FAIL, `33 rows checked, 33 failing`, and `tests/validate-skills.sh` failing with two
problems: `docs/profile-keys.md disagrees with templates/profile.schema.json: a stale description
for gates.security_audit`, and `gates.security_audit names
advisory:skills/ship/SKILL.md#gates.security_audit and that text is not in skills/ship/SKILL.md`.
Quote both FAIL lines. `tests/test-profile-keys.sh` stays green throughout: it tests the generator,
not the page.

- [x] **Step 8.3: Apply the rows, and regenerate the key's page** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 8.3 to 8.4; 8.1 and 8.2's reds and 8.5's suite run witnessed by the implementer and the fixers only

Apply every row in the ranges under "How a row is applied". F-199, F-241 and F-243 are refused.
F-240 is `ship`'s description. F-200 (security-audit) and F-339 (ship's gate item 4) were approved
as a pair; apply both. F-196, whose `Where` is `security-audit/SKILL.md` line 30, inserts in Step 2
after line 45, so order it at 45.

**F-341 carries F-242.** Both rewrite `skills/ship/SKILL.md` line 43 at `bda1acc`, and F-341's text
contains F-242's change. Apply F-341, and set F-242 to
`made task-8; composed with F-341, whose text contains it`.

Then:

- Run `tests/generate-profile-keys.sh > docs/profile-keys.md`.
- `docs/02-skill-catalog.md`, the `ship` entry's trigger, for F-240: `**Trigger:** "ship it", "open
  a PR", "let's land this", work believed complete.` becomes `**Trigger:** "ship it", "open a PR",
  "push it for review", work believed complete.`
- `docs/02-skill-catalog.md`, the `ship` entry's third checklist item, for F-339:
  `` 3. `security-audit --diff` clean, or findings explicitly accepted by the user `` becomes
  `` 3. `security-audit --diff` per `gates.security_audit`: `required` blocks, `warn` asks, `off` skips ``,
  one line of 98 characters.

Then add under `## Unreleased`:

```markdown
- `ship`'s gate item 4 follows `gates.security_audit`: `required` blocks on any finding without a
  named override, `warn` leaves the findings to the user, and `off` records the audit as skipped.
  `security-audit`, `docs/02-skill-catalog.md` and `docs/profile-keys.md` state the same, and no
  longer say ship refuses whatever the key says (F-200, F-339). `ship`'s formatting exception is
  limited to `verify.format_fix` on files the diff touches, committed on its own (F-341), and its
  description no longer claims to land or deploy a change (F-240).
```

Then run the citation repair: `python3 /tmp/skill-review-repair.py 195-212 240-252 339 341`. The
schema grew by three lines, so records citing it by line move too. Expected: a `PIN` line naming the
findings file for each of the 33 rows, then these:

```text
MOVE docs/ideas/plain-language-chat.md:113 templates/profile.schema.json:329-336 -> templates/profile.schema.json:332-339
MOVE docs/ideas/profile-validation-gaps.md:84 templates/profile.schema.json:396 -> templates/profile.schema.json:399
MOVE docs/ideas/stack-plugins-on-existing-repos.md:114 templates/profile.schema.json:397 -> templates/profile.schema.json:400
MOVE docs/plans/2026-08-31-release-operations-and-claims-audit.md:418 skills/security-audit/references/owasp-checklist.md:119-127 -> skills/security-audit/references/owasp-checklist.md:118-126
MOVE docs/plans/2026-08-31-release-operations-and-claims-audit.md:566 skills/security-audit/references/owasp-checklist.md:79-101 -> skills/security-audit/references/owasp-checklist.md:78-100
MOVE docs/plans/2026-08-31-release-operations-and-claims-audit.md:751 skills/security-audit/SKILL.md:29-44 -> skills/security-audit/SKILL.md:30-45
MOVE docs/plans/2026-09-05-tiered-multi-harness-support.md:3428 skills/security-audit/SKILL.md:46 -> skills/security-audit/SKILL.md:49
MOVE docs/plans/2026-09-28-addressable-plan-steps.md:1939 skills/ship/SKILL.md:36-37 -> skills/ship/SKILL.md:37-38
MOVE docs/plans/2026-09-28-addressable-plan-steps.md:1940 skills/ship/SKILL.md:62 -> skills/ship/SKILL.md:64
MOVE docs/plans/2026-09-28-addressable-plan-steps.md:1941 skills/ship/SKILL.md:62 -> skills/ship/SKILL.md:64
MOVE docs/prd/coding-standards-enforcement.md:43 skills/ship/SKILL.md:26 -> skills/ship/SKILL.md:27
MOVE docs/prd/coding-standards-enforcement.md:112 skills/ship/SKILL.md:26 -> skills/ship/SKILL.md:27
MOVE docs/prd/plain-language-chat.md:84 templates/profile.schema.json:355-362 -> templates/profile.schema.json:358-365
MOVE docs/prd/standards-assessment.md:173 skills/security-audit/references/report-template.md:85 -> skills/security-audit/references/report-template.md:84
MOVE docs/stories/coding-standards-enforcement.md:14 skills/ship/SKILL.md:26 -> skills/ship/SKILL.md:27
```

- [x] **Step 8.4: Run them and watch them pass** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 8.3 to 8.4; 8.1 and 8.2's reds and 8.5's suite run witnessed by the implementer and the fixers only

Run: `python3 /tmp/skill-review-check.py 195-212 240-252 339 341 && tests/validate-skills.sh && tests/test-harness-claims.sh && tests/test-profile-keys.sh && tests/validate-citations.sh`
Expected: `33 rows checked, 0 failing`, then all four pass. Then, from the repository root:

```bash
python3 /tmp/skill-review-repair.py 195-212 240-252 339 341
grep -c 'refuses on anything red' docs/profile-keys.md templates/profile.schema.json skills/security-audit/SKILL.md
tr '\n' ' ' < skills/ship/references/standards-gate.md | tr -s ' ' | grep -oF 'The three values mean what they mean for every other gate' | wc -l
tr '\n' ' ' < skills/ship/references/standards-gate.md | tr -s ' ' | grep -oF 'names nothing and is not an acceptance' | wc -l
```

Expected: the repair prints nothing, the `grep -c` prints `0` for each file, and each count prints
`0` (F-251 and F-252). Report both bodies' word counts; `security-audit` is expected at about 760,
which task 13's `audit-under-a-warn-gate` arm covers.

- [x] **Step 8.5: Run the suite at the unit boundary, then hand over** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 8.3 to 8.4; 8.1 and 8.2's reds and 8.5's suite run witnessed by the implementer and the fixers only

Run: `tests/run-tests.sh`
Expected: PASS. The lint runs inside the suite.

```bash
git add skills/security-audit/SKILL.md skills/security-audit/references/owasp-checklist.md \
  skills/security-audit/references/payments-checklist.md \
  skills/security-audit/references/report-template.md skills/security-audit/references/stride.md \
  skills/ship/SKILL.md skills/ship/references/standards-gate.md templates/profile.schema.json \
  docs/profile-keys.md docs/02-skill-catalog.md \
  docs/ideas/plain-language-chat.md docs/ideas/profile-validation-gaps.md \
  docs/ideas/stack-plugins-on-existing-repos.md docs/plans/2026-08-31-release-operations-and-claims-audit.md \
  docs/plans/2026-09-05-tiered-multi-harness-support.md docs/plans/2026-09-28-addressable-plan-steps.md \
  docs/prd/coding-standards-enforcement.md docs/prd/plain-language-chat.md \
  docs/prd/standards-assessment.md docs/stories/coding-standards-enforcement.md \
  docs/audits/2026-09-29-skill-review.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths, and any other record the citation repair changed, and stop. **Do not
commit.** The coordinator commits after both review passes, with
`git commit -m "fix(skills): apply the skill review's findings to security-audit and ship"`.
Paste the `git status --porcelain` output into your report.

**Review record, task 8, 2026-09-29.** Spec and quality reviews ran in parallel. Spec review
COMPLIES; the repair moved `security-audit/SKILL.md` line 46 to 51, not 49, F-196's paragraph being
three lines. Quality review returned one **blocking** finding: F-200 and F-339 as written let `off`
skip the audit before a ship at Step 1, so a diff touching `hard_block_paths` shipped unaudited,
where ship had always audited it. Ruled by Bernard with five should-fix, and re-reviewed three
times (spec COMPLIES, quality nothing blocking):

- A diff touching a `hard_block_paths` path is audited under any gate value, and a finding there
  blocks and is never overridable in conversation; a directly requested audit runs under `off`.
  security-audit Steps 1 and 5, ship item 4, the schema, the catalog and the changelog say so.
  F-195, F-200 and F-339 are `composed`.
- F-204 is reverted, `declined: reverted, ...`: phase 4 is not in the `--diff` scope a ship runs, so
  the owasp "Credentials with defaults" bullet it deleted is the only pre-ship check for them.
- F-210's severity line made every finding on the default branch Critical: "A Critical finding on
  the default branch stays Critical". `composed`.
- F-341's format exception runs `verify.format_fix` "only on files the diff already touches (passed
  as paths; if the command cannot take them, do not run it)"; the schema's "Never run by a gate"
  names the exception, with a ship reader entry. `composed`.
- The prompting guide's "Docs-only change, skip the audit" becomes a named acceptance per finding,
  which a hard-block path cannot take, in `docs/prompting.md` and the cheatsheet.
- **The citation repair skips a citing line it already edited**, so a fix that shifts lines after
  the first repair leaves those citations stale, and `tests/validate-citations.sh` cannot see it.
  The second spec review found 12 in 8 records; each was reset to HEAD and repaired again, and every
  moved citation was checked by content. Tasks 1 to 7 were checked for the same effect and are
  clear. From task 9 on, a fix after the repair resets any moved citation into a shifted file first.
- Not acted on, recorded as leads: the scope table's "`--diff` Before every ship" and the catalog's
  "what the `ship` gate calls"; standards-gate's overlapping bullets; ship's "on a
  `hard_block_paths` match" can read as the diff rather than the finding, the stricter reading;
  "let's land this" still routes to `ship`, which F-240's description no longer claims, and dropping
  it from the routers would remove a trigger; `docs/02-skill-catalog.md` item 3 wraps to two lines.

Bodies: `security-audit` 800, `ship` 739, both over 700, which task 13's arms cover.

### Task 9: `review-code`, `incident-response` and `setup-deployment`, and F-345

**Story:** S-03, S-04, S-05, S-06
**Files:**
- Modify: `skills/review-code/SKILL.md`, `skills/review-code/references/rubric.md`
- Modify: `skills/incident-response/SKILL.md`,
  `skills/incident-response/references/incident-record.md`
- Modify: `skills/setup-deployment/SKILL.md`,
  `skills/setup-deployment/references/pipeline-patterns.md`
- Modify, by the citation repair: `docs/audits/2026-09-02-standards.md`,
  `docs/ideas/profile-schema-drift.md`, `docs/ideas/standards-that-bind.md`,
  `docs/plans/2026-08-31-release-operations-and-claims-audit.md`,
  `docs/plans/2026-09-06-tdd-cycle-unit-and-mutation.md`,
  `docs/plans/2026-09-07-declared-profile-keys-take-effect.md`,
  `docs/plans/2026-09-19-make-keel-enforceable-outside-the-agent.md`,
  `docs/prd/coding-standards-enforcement.md`, `docs/prd/standards-assessment.md`
- Modify: `docs/audits/2026-09-29-skill-review.md`, `CHANGELOG.md`
- Test: the applied check, over `119-127 180-194 213-229 342 345`

**Interfaces:**
- Consumes: the applied check and the citation repair.
- Produces: finding F-345 in the findings file; Resolutions with `task-9`.

**Depends on:** task 8

**Done when:** `python3 /tmp/skill-review-check.py 119-127 180-194 213-229 342 345` prints
`43 rows checked, 0 failing`, `tests/validate-skills.sh` and `tests/validate-citations.sh` both
pass, and `python3 /tmp/skill-review-repair.py 119-127 180-194 213-229 342 345` prints nothing.

- [x] **Step 9.1: Write the failing test: record F-345** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 9.3 to 9.4; 9.1 and 9.2's reds witnessed by the implementer only; 9.5's suite re-run by the coordinator after the last fix

Run the extraction command under "The applied check", from the repository root. The plan review
found `setup-deployment`'s pipeline patterns recommending the idiom F-069 corrects
in `debug`, with no row. It is recorded here the way F-344 was in task 5. Like F-069 it corrects a
false statement and removes no rule, so it needs no ruling. Add this row as the last row of the
table under `### skills/setup-deployment/references/pipeline-patterns.md` in
`docs/audits/2026-09-29-skill-review.md`, as one line:

```markdown
| F-345 | skills/setup-deployment/references/pipeline-patterns.md:123-124 | contradiction | `To log presence without the value, use ${VAR:+SET}${VAR:-UNSET}, which also distinguishes unset from empty.` is false, as F-069 records for the same idiom in `debug`: run here, a set variable prints `SETsecret123`, leaking the credential, and an empty one prints `UNSET`, the same as an unset one. | `` To log presence without the value, use `[ -n "${VAR+x}" ] && { [ -n "${VAR:+x}" ] && echo SET \|\| echo EMPTY; } \|\| echo UNSET`, which also distinguishes unset from empty and never puts the value in a shell trace. `` | nothing | not needed | open |
```

In the summary paragraph at the top of that file, matching with whitespace ignored,
`345 findings:` becomes `346 findings:` and `45 contradiction` becomes `46 contradiction`, and this
sentence is added at the paragraph's end:

```markdown
F-345, the idiom F-069 corrects, repeated in `setup-deployment`'s pipeline patterns, was found by
the plan review on 2026-09-29 and needs no ruling.
```

Then rewrap the paragraph.

- [x] **Step 9.2: Run it and watch it fail** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 9.3 to 9.4; 9.1 and 9.2's reds witnessed by the implementer only; 9.5's suite re-run by the coordinator after the last fix

Run: `python3 /tmp/skill-review-check.py 119-127 180-194 213-229 342 345`
Expected: FAIL, `43 rows checked, 43 failing`, F-345 among them. Four of these rows, F-215,
F-223, F-224 and F-228, propose text already in the file; step 9.4 proves their old text gone.

- [x] **Step 9.3: Apply the rows** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 9.3 to 9.4; 9.1 and 9.2's reds witnessed by the implementer only; 9.5's suite re-run by the coordinator after the last fix

Apply every row in the ranges under "How a row is applied". F-121 to F-126 and F-216 to F-221, the
Common mistakes rows of `incident-response` and `setup-deployment`, are refused. F-180 and F-213 are
descriptions. F-342, from the between-skills section, rewrites `setup-deployment`'s Step 7 so the
rollback is executed before the runbook is written. F-345 replaces the sentence in
`pipeline-patterns.md` that starts `To log presence without the value` and ends `unset from empty.`

Two rows edit away from their `Where`, and rule 2 orders their edits by where they land: F-180,
whose `Where` is `review-code`'s description on line 3, inserts after line 19; F-215 deletes the
sentence at `setup-deployment/SKILL.md` lines 81-82 and adds it at the end of Step 1, after
`Check them explicitly.` on line 26, so that file's order runs through 81 before 26.

Then add under `## Unreleased`:

```markdown
- `setup-deployment` executes the rollback before writing the runbook (F-342), and its pipeline
  patterns log a credential's presence as `SET`, `EMPTY` or `UNSET` without printing it (F-345).
  `review-code`, `incident-response`, `setup-deployment` and their references take the skill
  review's findings F-119 to F-127, F-180 to F-194 and F-213 to F-229.
```

Then run the citation repair: `python3 /tmp/skill-review-repair.py 119-127 180-194 213-229 342 345`.
Expected: a `PIN` line naming the findings file for each of the 43 rows, then these:

```text
MOVE docs/audits/2026-09-02-standards.md:128 skills/review-code/references/rubric.md:122 -> skills/review-code/references/rubric.md:123
PIN  docs/ideas/profile-schema-drift.md:81 skills/setup-deployment/SKILL.md:30 -> `skills/setup-deployment/SKILL.md` line 30 at `bda1acc`
MOVE docs/ideas/standards-that-bind.md:17 skills/review-code/SKILL.md:21 -> skills/review-code/SKILL.md:24
MOVE docs/ideas/standards-that-bind.md:18 skills/review-code/references/rubric.md:61-63 -> skills/review-code/references/rubric.md:64-66
MOVE docs/ideas/standards-that-bind.md:347 skills/review-code/SKILL.md:21 -> skills/review-code/SKILL.md:24
PIN  docs/plans/2026-08-31-release-operations-and-claims-audit.md:202 skills/setup-deployment/SKILL.md:81-86 -> `skills/setup-deployment/SKILL.md` lines 81-86 at `bda1acc`
PIN  docs/plans/2026-08-31-release-operations-and-claims-audit.md:203 skills/setup-deployment/references/pipeline-patterns.md:126-131 -> `skills/setup-deployment/references/pipeline-patterns.md` lines 126-131 at `bda1acc`
MOVE docs/plans/2026-08-31-release-operations-and-claims-audit.md:209 skills/setup-deployment/SKILL.md:73-76 -> skills/setup-deployment/SKILL.md:76-79
MOVE docs/plans/2026-08-31-release-operations-and-claims-audit.md:218 skills/setup-deployment/SKILL.md:39 -> skills/setup-deployment/SKILL.md:42
PIN  docs/plans/2026-08-31-release-operations-and-claims-audit.md:228 skills/review-code/SKILL.md:83 -> `skills/review-code/SKILL.md` line 83 at `bda1acc`
PIN  docs/plans/2026-08-31-release-operations-and-claims-audit.md:402 skills/setup-deployment/SKILL.md:30-31 -> `skills/setup-deployment/SKILL.md` lines 30-31 at `bda1acc`
MOVE docs/plans/2026-08-31-release-operations-and-claims-audit.md:408 skills/setup-deployment/references/pipeline-patterns.md:120-124 -> skills/setup-deployment/references/pipeline-patterns.md:111-115
MOVE docs/plans/2026-08-31-release-operations-and-claims-audit.md:561 skills/review-code/SKILL.md:68-69 -> skills/review-code/SKILL.md:72-73
MOVE docs/plans/2026-08-31-release-operations-and-claims-audit.md:614 skills/review-code/SKILL.md:63-64 -> skills/review-code/SKILL.md:67-68
MOVE docs/plans/2026-08-31-release-operations-and-claims-audit.md:755 skills/review-code/SKILL.md:26-27 -> skills/review-code/SKILL.md:29-30
MOVE docs/plans/2026-09-06-tdd-cycle-unit-and-mutation.md:201 skills/review-code/SKILL.md:81 -> skills/review-code/SKILL.md:85
PIN  docs/plans/2026-09-07-declared-profile-keys-take-effect.md:255 skills/setup-deployment/SKILL.md:30 -> `skills/setup-deployment/SKILL.md` line 30 at `bda1acc`
MOVE docs/plans/2026-09-19-make-keel-enforceable-outside-the-agent.md:1520 skills/review-code/references/rubric.md:18 -> skills/review-code/references/rubric.md:21
MOVE docs/plans/2026-09-19-make-keel-enforceable-outside-the-agent.md:1544 skills/review-code/references/rubric.md:44 -> skills/review-code/references/rubric.md:47
PIN  docs/plans/2026-09-19-make-keel-enforceable-outside-the-agent.md:1613 skills/review-code/references/rubric.md:97 -> `skills/review-code/references/rubric.md` line 97 at `bda1acc`
MOVE docs/prd/coding-standards-enforcement.md:45 skills/review-code/SKILL.md:61-63 -> skills/review-code/SKILL.md:65-67
MOVE docs/prd/coding-standards-enforcement.md:112 skills/review-code/SKILL.md:61-63 -> skills/review-code/SKILL.md:65-67
MOVE docs/prd/coding-standards-enforcement.md:168 skills/review-code/SKILL.md:61-63 -> skills/review-code/SKILL.md:65-67
MOVE docs/prd/standards-assessment.md:47 skills/review-code/SKILL.md:21 -> skills/review-code/SKILL.md:24
MOVE docs/prd/standards-assessment.md:48 skills/review-code/references/rubric.md:61-63 -> skills/review-code/references/rubric.md:64-66
MOVE docs/prd/standards-assessment.md:156 skills/review-code/references/rubric.md:104-106 -> skills/review-code/references/rubric.md:106-108
```

- [x] **Step 9.4: Run it and watch it pass** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 9.3 to 9.4; 9.1 and 9.2's reds witnessed by the implementer only; 9.5's suite re-run by the coordinator after the last fix

Run: `python3 /tmp/skill-review-check.py 119-127 180-194 213-229 342 345 && tests/validate-skills.sh && tests/validate-citations.sh`
Expected: `43 rows checked, 0 failing`, then both validators pass. Then prove the four rows whose
text was already there, from the repository root:

```bash
python3 /tmp/skill-review-repair.py 119-127 180-194 213-229 342 345
tr '\n' ' ' < skills/setup-deployment/SKILL.md | tr -s ' ' | grep -oF 'before provisioning anything' | wc -l
awk '/^## Step 1/,/^## Step 2/' skills/setup-deployment/SKILL.md | tr '\n' ' ' | tr -s ' ' | grep -oF 'before provisioning anything' | wc -l
tr '\n' ' ' < skills/setup-deployment/references/pipeline-patterns.md | tr -s ' ' | grep -oF 'Every stage fails the build.' | wc -l
tr '\n' ' ' < skills/setup-deployment/references/pipeline-patterns.md | tr -s ' ' | grep -oF 'Read the conditions, not the step names.' | wc -l
tr '\n' ' ' < skills/setup-deployment/references/pipeline-patterns.md | tr -s ' ' | grep -oF 'so growth is visible rather than gradual' | wc -l
```

Expected: the repair prints nothing; then `1` and `1`, F-215's sentence being in the file once and
that once in Step 1, where before the task the second count is `0`, the sentence being in Step 6;
then `0`, `0` and `0` (F-223, F-224, F-228). Run F-345's idiom as step 7.4 ran F-069's, once more
under `bash -xu`, and quote the output, which shows no part of the value, trace lines included.
Report the three bodies' word counts; `setup-deployment` is expected at about 703, which task 13's
length arm covers.

- [x] **Step 9.5: Run the suite at the unit boundary, then hand over** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 9.3 to 9.4; 9.1 and 9.2's reds witnessed by the implementer only; 9.5's suite re-run by the coordinator after the last fix

Run: `tests/run-tests.sh`
Expected: PASS. The lint runs inside the suite.

```bash
git add skills/review-code/SKILL.md skills/review-code/references/rubric.md \
  skills/incident-response/SKILL.md skills/incident-response/references/incident-record.md \
  skills/setup-deployment/SKILL.md skills/setup-deployment/references/pipeline-patterns.md \
  docs/audits/2026-09-02-standards.md docs/ideas/profile-schema-drift.md \
  docs/ideas/standards-that-bind.md docs/plans/2026-08-31-release-operations-and-claims-audit.md \
  docs/plans/2026-09-06-tdd-cycle-unit-and-mutation.md \
  docs/plans/2026-09-07-declared-profile-keys-take-effect.md \
  docs/plans/2026-09-19-make-keel-enforceable-outside-the-agent.md \
  docs/prd/coding-standards-enforcement.md docs/prd/standards-assessment.md \
  docs/audits/2026-09-29-skill-review.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths, and any other record the citation repair changed, and stop. **Do not
commit.** The coordinator commits after both review passes, with
`git commit -m "fix(skills): apply the skill review's findings to review-code, incident-response and setup-deployment"`.
Paste the `git status --porcelain` output into your report.

**Review record, task 9, 2026-09-30.** Spec and quality reviews ran in parallel. Spec review
COMPLIES, confirming two judgement calls: F-226 keeps the yaml after "for example:" (rules 3 and
5), so the MOVE for `docs/plans/2026-08-31-release-operations-and-claims-audit.md` line 408 lands
on `pipeline-patterns.md` lines 119-123, not the simulated 111-115; and the hand-pinned citation at
line 203 of that file is the repair's own rule. Quality review found nothing blocking and two
should-fix, ruled by Bernard on 2026-09-30, then three more on the fix, also ruled; re-reviewed
twice (spec COMPLIES once its note was completed, quality nothing blocking, no should-fix):

- F-342's Step 7 had no path on a new pipeline, with nothing yet to roll back to. It now writes the
  runbook anyway, marks the rollback not yet executed and names running it as the next step in
  Step 8; "record that you ran it" becomes "Note in the runbook when you ran the rollback"; the
  heading reads "Test the rollback when there is one, then write the runbook"; and the Common
  mistakes row's Instead cell reads "Execute the rollback once, or mark it pending". `composed`.
- F-119 named only pausing a corridor as needing a partial diagnosis, while
  `references/incident-record.md` line 79 names failing over too. It now reads "only failing over
  or pausing a corridor needs even a partial diagnosis: which corridor." `composed`.
- **F-345's row was redone.** The implementer's first insertion, `sed -i` with a `mkdir` of a
  scratchpad, was denied by the auto-mode classifier as "Modify Shared Resources", and it made the
  same insertion with Edit. Bernard asked for it redone: the row was deleted, inserted again from
  step 9.1 with Edit, and pinned by the repair; it is byte-identical before and after.
- The F-342 fix added two lines to `setup-deployment/SKILL.md` after the first repair, so lines
  209 and 218 of the release operations plan were reset to HEAD and repaired again, and both moved
  citations were checked by content. The later fixes kept the line count.
- The index was emptied while the first re-review ran, cause not found; the working tree was intact
  and the 17 paths were staged again.
- Not acted on, recorded as leads: image size has no home in Step 7's runbook list since F-228;
  the catalog's line 449 trigger is incomplete and line 377 still true; pipeline-patterns' "Those
  are different bugs" is ambiguous after F-345's added clause; the changelog could name F-181 and
  F-120, and its F-342 entry omits the new pipeline case; the mistakes row says "pending" where
  Step 7 says "not yet executed"; "the next step in Step 8" can read as running it there; the
  fallback is a named exception to `write-docs` line 13, which task 13's fixture tests; and the
  partial-path citations in `docs/ideas/leon-van-zyl-skill-collection.md`, a dated record, were
  imprecise before task 9 and are more so now.

Bodies: `review-code` 645, `incident-response` 746, `setup-deployment` 744, the last two over 700,
which task 13's arms cover.

### Task 10: `write-docs`

**Story:** S-03, S-04, S-05, S-06
**Files:**
- Modify: `skills/write-docs/SKILL.md`, and in `skills/write-docs/references/`: `claims-audit.md`,
  `current-state-prose.md`, `readme-structure.md`
- Modify: `docs/audits/2026-09-29-skill-review.md`, `CHANGELOG.md`
- Test: the applied check, over `262-284`

**Interfaces:**
- Consumes: the applied check and the citation repair.
- Produces: Resolutions with `task-10`.

**Depends on:** task 9

**Done when:** `python3 /tmp/skill-review-check.py 262-284` prints `23 rows checked, 0 failing`,
`tests/validate-skills.sh` and `tests/validate-citations.sh` both pass, and
`python3 /tmp/skill-review-repair.py 262-284` prints nothing.

- [x] **Step 10.1: Extract the test** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 10.3 to 10.4; 10.1 and 10.2's red witnessed by the implementer only; 10.5's suite re-run by the coordinator before the commit

Run the extraction command under "The applied check", from the repository root.

- [x] **Step 10.2: Run it and watch it fail** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 10.3 to 10.4; 10.1 and 10.2's red witnessed by the implementer only; 10.5's suite re-run by the coordinator before the commit

Run: `python3 /tmp/skill-review-check.py 262-284`
Expected: FAIL, `23 rows checked, 23 failing`.

- [x] **Step 10.3: Apply F-262 to F-284** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 10.3 to 10.4; 10.1 and 10.2's red witnessed by the implementer only; 10.5's suite re-run by the coordinator before the commit

Apply every row under "How a row is applied". None is refused. F-262 is the description. Then add
under `## Unreleased`:

```markdown
- `write-docs` and its references take the skill review's findings F-262 to F-284
  (`docs/audits/2026-09-29-skill-review.md`).
```

Then run the citation repair: `python3 /tmp/skill-review-repair.py 262-284`. Expected: a `PIN` line
naming the findings file for each of the 23 rows, and nothing else; the simulation moved no citation
outside it.

- [x] **Step 10.4: Run it and watch it pass** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 10.3 to 10.4; 10.1 and 10.2's red witnessed by the implementer only; 10.5's suite re-run by the coordinator before the commit

Run: `python3 /tmp/skill-review-check.py 262-284 && tests/validate-skills.sh && tests/validate-citations.sh`
Expected: `23 rows checked, 0 failing`, then both validators pass, and
`python3 /tmp/skill-review-repair.py 262-284` prints nothing. Report the body's word count; its last
length arm ran at 756, and task 13 runs another if it ends over that.

- [x] **Step 10.5: Run the suite at the unit boundary, then hand over** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 10.3 to 10.4; 10.1 and 10.2's red witnessed by the implementer only; 10.5's suite re-run by the coordinator before the commit

Run: `tests/run-tests.sh`
Expected: PASS. The lint runs inside the suite.

```bash
git add skills/write-docs/SKILL.md skills/write-docs/references/claims-audit.md \
  skills/write-docs/references/current-state-prose.md skills/write-docs/references/readme-structure.md \
  docs/audits/2026-09-29-skill-review.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths, and any record the citation repair changed, and stop. **Do not
commit.** The coordinator commits after both review passes, with
`git commit -m "fix(skills): apply the skill review's findings to write-docs"`.
Paste the `git status --porcelain` output into your report.

**Review record, task 10, 2026-09-30.** Spec and quality reviews ran in parallel. Spec review
COMPLIES: every row landed verbatim with no other word changed, nine `made` and fourteen `fixed`,
and the repair pinned only the findings file. Quality review found nothing blocking and no
should-fix. No row was refused and nothing needed a ruling.

- Not acted on, recorded as leads: `CONTRIBUTING.md` line 50 still lists `write-docs` at 756,
  which task 13 corrects with the other bodies; the catalog's `write-docs` Trigger line (line 495)
  and the routers' row (`docs/prompting.md` and `templates/prompting-cheatsheet.md` line 42, and
  `skills/keel/SKILL.md` line 35) lack F-262's "check what the docs claim is still true", which
  is incomplete, not false; the catalog's line 504 still cites the `cursor-starter` path F-284
  says exists nowhere; the Step 1 table has no row for the claims audit F-263 routes to;
  `docs/standards.md` line 331's "already-discharged 756 words" sits in a dated entry; and
  `port-assess` line 37 keeps the "leading its description" wording F-264 fixed here, which task 12
  owns.

Body: `write-docs` 699, down from 756, so it no longer owes a length arm.

### Task 11: `keel`, `context-budget` and `create-skill`

**Story:** S-03, S-04, S-05, S-06
**Files:**
- Modify: `skills/keel/SKILL.md`, `skills/keel/references/asking-questions.md`,
  `skills/keel/references/tool-choices.md`
- Modify: `skills/context-budget/SKILL.md`, `skills/create-skill/SKILL.md`,
  `skills/create-skill/references/skill-anatomy.md`
- Modify: `docs/prompting.md`, `templates/prompting-cheatsheet.md`
- Modify: `templates/profile.schema.json`, `docs/profile-keys.md` (generated)
- Modify, by the citation repair: `docs/ideas/declared-profile-keys-take-effect.md`,
  `docs/ideas/tdd-cycle-cost-and-case-coverage.md`,
  `docs/plans/2026-09-07-declared-profile-keys-take-effect.md`
- Modify: `docs/audits/2026-09-29-skill-review.md`, `CHANGELOG.md`
- Test: the applied check, over `46-61 128-138`

**Interfaces:**
- Consumes: the applied check and the citation repair.
- Produces: Resolutions with `task-11`.

**Depends on:** task 10

**Done when:** `python3 /tmp/skill-review-check.py 46-61 128-138` prints
`27 rows checked, 0 failing`, `tests/validate-skills.sh` and `tests/validate-citations.sh` both
pass, and `python3 /tmp/skill-review-repair.py 46-61 128-138` prints nothing.

- [x] **Step 11.1: Extract the test** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 11.3 to 11.4; 11.1 and 11.2's red witnessed by the implementer only; 11.5's suite re-run by the coordinator before the commit

Run the extraction command under "The applied check", from the repository root.

- [x] **Step 11.2: Run it and watch it fail** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 11.3 to 11.4; 11.1 and 11.2's red witnessed by the implementer only; 11.5's suite re-run by the coordinator before the commit

Run: `python3 /tmp/skill-review-check.py 46-61 128-138`
Expected: FAIL, `27 rows checked, 27 failing`. One of these rows, F-135, proposes text already in
the file; step 11.4 proves its old text gone.

- [x] **Step 11.3: Apply the rows, the router's copies, and the schema's citations** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 11.3 to 11.4; 11.1 and 11.2's red witnessed by the implementer only; 11.5's suite re-run by the coordinator before the commit

Apply every row in the two ranges under "How a row is applied". F-133 is refused. F-046, F-054 and
F-128 are descriptions. F-128, whose `Where` is `keel`'s description on line 3, inserts after line
52, so order it at 52. F-130 rewrites `keel/SKILL.md` lines 25 and 27, each in its place.

**F-059 carries F-060.** Both rewrite `skills/create-skill/references/skill-anatomy.md` line 16 at
`bda1acc`, and F-059's text already says 216 characters. Apply F-059, and set F-060 to
`fixed task-11; composed with F-059, whose text carries the 216 limit`.

**F-130 moves "fix bug Z" from `tdd` to `debug`** in the router table. The same two rows are copied
in `docs/prompting.md` and `templates/prompting-cheatsheet.md`, at line 32 and line 35 of each.
In both files, line 32 becomes:

```markdown
| "implement X", "add feature Y" | `tdd` | failing test first, then code |
```

and line 35 becomes:

```markdown
| "this is broken", "why does X fail", "this test is flaky", "fix bug Z", "wtf" | `debug` | root cause, then a failing test, then the fix |
```

**F-136's rewrap moves the lines the schema cites.** `templates/profile.schema.json` cites
`tool-choices.md` lines 20 and 21 for `stack.language` and `stack.also`, and F-136 lengthens item 3
above them by a line. Cite them by phrase instead. In the schema:

```text
          "x-keel-read-by": "advisory:skills/keel/references/tool-choices.md:20"
          "x-keel-read-by": "advisory:skills/keel/references/tool-choices.md:21"
```

become, in the same two places:

```text
          "x-keel-read-by": "advisory:skills/keel/references/tool-choices.md#which every keel project already has"
          "x-keel-read-by": "advisory:skills/keel/references/tool-choices.md#Where a repository is multi-stack"
```

No row changes either phrase. Then run `tests/generate-profile-keys.sh > docs/profile-keys.md`.

Then add under `## Unreleased`:

```markdown
- The `keel` router sends "fix bug Z" to `debug`, not `tdd` (F-130), and so do `docs/prompting.md`
  and the installed cheatsheet. `keel`, `context-budget`, `create-skill` and their references take
  the skill review's findings F-046 to F-061 and F-128 to F-138. The profile schema cites
  `tool-choices.md` by phrase.
```

Then run the citation repair: `python3 /tmp/skill-review-repair.py 46-61 128-138`. Expected: a `PIN`
line naming the findings file for each of the 27 rows, then these:

```text
MOVE docs/ideas/declared-profile-keys-take-effect.md:93 skills/keel/references/tool-choices.md:21 -> skills/keel/references/tool-choices.md:22
MOVE docs/ideas/tdd-cycle-cost-and-case-coverage.md:169 skills/keel/references/tool-choices.md:37 -> skills/keel/references/tool-choices.md:38
MOVE docs/plans/2026-09-07-declared-profile-keys-take-effect.md:785 skills/keel/references/tool-choices.md:20 -> skills/keel/references/tool-choices.md:21
MOVE docs/plans/2026-09-07-declared-profile-keys-take-effect.md:789 skills/keel/references/tool-choices.md:21 -> skills/keel/references/tool-choices.md:22
```

- [x] **Step 11.4: Run it and watch it pass** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 11.3 to 11.4; 11.1 and 11.2's red witnessed by the implementer only; 11.5's suite re-run by the coordinator before the commit

Run: `python3 /tmp/skill-review-check.py 46-61 128-138 && tests/validate-skills.sh && tests/validate-citations.sh`
Expected: `27 rows checked, 0 failing`, then both validators pass. Then, from the repository root:

```bash
python3 /tmp/skill-review-repair.py 46-61 128-138
grep -c '"fix bug Z", "wtf" | `debug`' docs/prompting.md templates/prompting-cheatsheet.md
tr '\n' ' ' < skills/keel/references/asking-questions.md | tr -s ' ' | grep -oF 'Ask about what blocks work.' | wc -l
```

Expected: the repair prints nothing, the `grep -c` prints `1` for each file, and the count prints
`0` (F-135). Report the three bodies' word counts; `context-budget`'s last length arm ran at 723,
and task 13 runs another if it ends over that.

- [x] **Step 11.5: Run the suite at the unit boundary, then hand over** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 11.3 to 11.4; 11.1 and 11.2's red witnessed by the implementer only; 11.5's suite re-run by the coordinator before the commit

Run: `tests/run-tests.sh`
Expected: PASS. `tests/test-keel.sh` installs the cheatsheet, so a broken copy shows here. The lint
runs inside the suite.

```bash
git add skills/keel/SKILL.md skills/keel/references/asking-questions.md \
  skills/keel/references/tool-choices.md skills/context-budget/SKILL.md skills/create-skill/SKILL.md \
  skills/create-skill/references/skill-anatomy.md docs/prompting.md templates/prompting-cheatsheet.md \
  templates/profile.schema.json docs/profile-keys.md \
  docs/ideas/declared-profile-keys-take-effect.md docs/ideas/tdd-cycle-cost-and-case-coverage.md \
  docs/plans/2026-09-07-declared-profile-keys-take-effect.md \
  docs/audits/2026-09-29-skill-review.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths, and any other record the citation repair changed, and stop. **Do not
commit.** The coordinator commits after both review passes, with
`git commit -m "fix(skills): apply the skill review's findings to keel, context-budget and create-skill"`.
Paste the `git status --porcelain` output into your report.

**Review record, task 11, 2026-09-30.** Spec and quality reviews ran in parallel. Spec review
COMPLIES, with one live document the rows made wrong: `docs/02-skill-catalog.md` line 86 said
`keel` "routes to one skill and stops", the wording F-129 replaced. Quality review found nothing
blocking and one should-fix. Ruled by Bernard on 2026-09-30 and re-reviewed (spec COMPLIES,
quality nothing blocking, no should-fix; the first quality re-review stalled and was run again):

- F-055 landed after an existing colon as "probably wrong: Fix the check". A full stop replaces the
  colon, and "so it cannot regress" is cut, which brings `create-skill` from 704 words to 700, so
  it needs no length arm, which task 13 has no fixture for. `composed`.
- **Amended:** the catalog's line 86 reads "routes to one skill and follows it", fixed on top.
- Not acted on, recorded as leads: the catalog's Trigger lines for `create-skill` (line 536),
  `context-budget` (line 560) and `keel` (line 82) lack F-054's, F-046's and F-128's new triggers,
  which is incomplete, not false; the catalog says `create-skill` writes "a new skill directory in
  the keel repo", against F-055, F-056 and F-058, and that `keel` is "Kept under 200 words" (594),
  wrong before this task; `docs/standards.md` line 18 says descriptions are "under 260", against
  the 216 limit, also wrong before this task; F-128's paragraph is not in `hooks/session-start`'s
  compressed router, as that hook compresses; and the schema's two phrase citations quote sentence
  fragments where its other advisory citations quote key names.

Bodies: `keel` 594, `context-budget` 682, down from 723, and `create-skill` 700, none owing a
length arm.

### Task 12: `apex-export`, `apex-port-plan` and `port-assess`

**Story:** S-03, S-04, S-05, S-06
**Files:**
- Modify: `skills/apex-export/SKILL.md`,
  `skills/apex-export/references/connection-and-privileges.md`
- Modify: `skills/apex-port-plan/SKILL.md`,
  `skills/apex-port-plan/references/apex-to-web-mapping.md`,
  `skills/apex-port-plan/references/assessment-template.md`
- Modify: `skills/port-assess/SKILL.md`, `skills/port-assess/references/assessment-template.md`
- Modify, by the citation repair: `docs/audits/2026-09-25-standards.md`,
  `docs/plans/2026-09-05-tiered-multi-harness-support.md`
- Modify: `docs/audits/2026-09-29-skill-review.md`, `CHANGELOG.md`
- Test: the applied check, over `1-12 148-163`

**Interfaces:**
- Consumes: the applied check and the citation repair.
- Produces: Resolutions with `task-12`.

**Depends on:** task 11

**Done when:** `python3 /tmp/skill-review-check.py 1-12 148-163` prints
`28 rows checked, 0 failing`, `tests/validate-skills.sh` and `tests/validate-citations.sh` both
pass, and `python3 /tmp/skill-review-repair.py 1-12 148-163` prints nothing.

- [x] **Step 12.1: Extract the test** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 12.3 to 12.4; 12.1 and 12.2's red witnessed by the implementer only; 12.5's suite re-run by the coordinator before the commit

Run the extraction command under "The applied check", from the repository root.

- [x] **Step 12.2: Run it and watch it fail** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 12.3 to 12.4; 12.1 and 12.2's red witnessed by the implementer only; 12.5's suite re-run by the coordinator before the commit

Run: `python3 /tmp/skill-review-check.py 1-12 148-163`
Expected: FAIL, `28 rows checked, 28 failing`. Two of these rows, F-012 and F-158, propose text
already in the file; step 12.4 proves their old text gone.

- [x] **Step 12.3: Apply the rows** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 12.3 to 12.4; 12.1 and 12.2's red witnessed by the implementer only; 12.5's suite re-run by the coordinator before the commit

Apply every row in the two ranges under "How a row is applied". F-149 and F-150 are refused. F-004
is a description finding whose `Where` is `apex-port-plan/SKILL.md` line 3, and it edits
`references/assessment-template.md` lines 18-19 instead; the check reads that file for it. Then add
under `## Unreleased`:

```markdown
- `apex-export`, `apex-port-plan`, `port-assess` and their references take the skill review's
  findings F-001 to F-012 and F-148 to F-163 (`docs/audits/2026-09-29-skill-review.md`).
```

Then run the citation repair: `python3 /tmp/skill-review-repair.py 1-12 148-163`. Expected: a `PIN`
line naming the findings file for each of the 28 rows, then these:

```text
PIN  docs/audits/2026-09-25-standards.md:102 skills/apex-port-plan/SKILL.md:30 -> `skills/apex-port-plan/SKILL.md` line 30 at `bda1acc`
PIN  docs/plans/2026-09-05-tiered-multi-harness-support.md:3426 skills/apex-port-plan/SKILL.md:30 -> `skills/apex-port-plan/SKILL.md` line 30 at `bda1acc`
```

- [x] **Step 12.4: Run it and watch it pass** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 12.3 to 12.4; 12.1 and 12.2's red witnessed by the implementer only; 12.5's suite re-run by the coordinator before the commit

Run: `python3 /tmp/skill-review-check.py 1-12 148-163 && tests/validate-skills.sh && tests/validate-citations.sh`
Expected: `28 rows checked, 0 failing`, then both validators pass. Then, from the repository root:

```bash
python3 /tmp/skill-review-repair.py 1-12 148-163
tr '\n' ' ' < skills/apex-port-plan/references/assessment-template.md | tr -s ' ' | grep -oF 'An unrevised band was still a judgement' | wc -l
tr '\n' ' ' < skills/port-assess/references/assessment-template.md | tr -s ' ' | grep -oF 'and says so in the row' | wc -l
```

Expected: the repair prints nothing, and each count prints `0` (F-012 and F-158). Report the three
bodies' word counts.

- [x] **Step 12.5: Run the suite at the unit boundary, then hand over** Note: delegated; ticked on the implementer's reported output, re-run by the spec reviewer for 12.3 to 12.4; 12.1 and 12.2's red witnessed by the implementer only; 12.5's suite re-run by the coordinator before the commit

Run: `tests/run-tests.sh`
Expected: PASS. `tests/test-apex-export.sh` exercises the export's reference text where it is
pinned. The lint runs inside the suite.

```bash
git add skills/apex-export/SKILL.md skills/apex-export/references/connection-and-privileges.md \
  skills/apex-port-plan/SKILL.md skills/apex-port-plan/references/apex-to-web-mapping.md \
  skills/apex-port-plan/references/assessment-template.md skills/port-assess/SKILL.md \
  skills/port-assess/references/assessment-template.md \
  docs/audits/2026-09-25-standards.md docs/plans/2026-09-05-tiered-multi-harness-support.md \
  docs/audits/2026-09-29-skill-review.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths, and any other record the citation repair changed, and stop. **Do not
commit.** The coordinator commits after both review passes, with
`git commit -m "fix(skills): apply the skill review's findings to apex-export, apex-port-plan and port-assess"`.
Paste the `git status --porcelain` output into your report.

**Review record, task 12, 2026-09-30.** Spec and quality reviews ran in parallel. Spec review
COMPLIES. It confirmed that F-005 keeps "Confirm the target stack before dispatching.", since the
Finding quotes only the sentence after it, and that F-006's break after "concurrently," is forced
by keeping `` delegation profile `keel-fanout` `` whole. Quality review found nothing blocking and
two should-fix, then one more on the fix. Ruled by Bernard on 2026-09-30 and re-reviewed twice
(spec COMPLIES, quality nothing blocking, no should-fix):

- The repair did not print step 12.3's two expected PINs, because F-006's rewrap kept the
  paragraph at four lines and the script leaves a line rewritten in place. The dispatch label
  those records cite now starts on line 31, so both were pinned by hand to
  `` `skills/apex-port-plan/SKILL.md` line 30 at `bda1acc` ``, the plan's expected text.
- F-156's text said each template names the rules it shares with the other, while only
  `port-assess`'s did. `apex-port-plan`'s template gains the mirror sentence naming `port-assess`.
- F-005's first sentence restated the second and is removed too, taking `apex-port-plan` from 692
  words to 686.
- **Amended:** `apex-port-plan`'s template stated its cite rule as "Cite paths, not summaries",
  against `port-assess` and its own core principle, now that both templates call it shared. It
  reads "Cite `path:line` or mark `Unknown`, never a summary."
- F-005 and F-156 keep their own text verbatim, so their notes take F-033's form, not `composed`,
  and the check still verifies both.
- Not acted on, recorded as leads: the catalog says `apex-port-plan` "dispatches six `Explore`
  agents" and `port-assess` uses "One `Explore` agent per concern", where both use `keel-fanout`,
  which was stale before this task; the catalog's "A band that nobody challenged is still a
  judgement" loses its template wording after F-012 and is still met by Step 3, so it is
  incomplete, not false; the template's cite example is a path without a line; and the no-hours
  rule is worded differently in the two templates, `port-assess` adding "no aggregate size".

Bodies: `apex-export` 536, `apex-port-plan` 686, `port-assess` 662, none owing a length arm.

### Task 13: Every covered skill re-run, and the length arms

**Story:** S-07, and S-04's length criterion
**Files:**
- Modify: `tests/evals/results.md`
- Modify, only on a failing arm: the skill file whose change failed it, and its findings rows

**Interfaces:**
- Consumes: the bodies tasks 1 to 12 left, and their word counts from each task's report.
- Produces: one results entry, which task 14 cites.

**Depends on:** task 12

**Done when:** there is no command from `profile.verify` for an arm; every arm step 13.1 names is
graded pass and recorded, and `tests/run-tests.sh` passes with the entry in.

**The coordinator runs this task inline, and says so in one line**: the auto-mode classifier has
denied a subagent's dispatch of these arms, so each arm is staged here and Bernard either runs it or
tells the coordinator to. Ask before each batch of arms, never assume.

- [x] **Step 13.1: There is no failing test for this; name the arms** Note: coordinator inline, 2026-09-30; over 700 and injected by a scenario: coding-standards 726, repo-snapshot 748, write-prd 794, execute-plan 889, tdd 855, security-audit 800, ship 739, incident-response 746; length arms owed: write-plan 761, setup-deployment 744; under 700: write-docs 699, context-budget 682; no other skill over 700 without a fixture

An arm grades behaviour against a scenario's `Passes if` line; nothing here can be written to fail
first. Record the word count of every changed body now, with
`tests/validate-skills.sh 2>&1 | grep WARN` for those over 700.

**The length rule.** A changed body over 700 words that no scenario injects owes a length arm when
it is longer than its last passing arm at a recorded length, or has none. The scenarios in step 13.2
inject `coding-standards`, `repo-snapshot`, `security-audit`, `debug`, `write-prd`,
`incident-response`, `design-database`, `execute-plan`, `tdd` and `ship`. Of the rest:

| Skill | Last passing arm | Arm, if over 700 and over that |
|---|---|---|
| `write-plan` | none at a recorded length over 700 | step 13.3 |
| `setup-deployment` | none | step 13.4 |
| `write-docs` | 756 words, 2026-09-02 | step 13.5 |
| `context-budget` | 723 words, 2026-09-02 | step 13.6 |

A simulation of tasks 1 to 12 left `write-plan` at about 760 and `setup-deployment` at about 703,
and `write-docs` and `context-budget` at or under 700. Any other skill no scenario injects that this
step measures over 700 has no fixture in this plan: stop and report it.

- [x] **Step 13.2: Re-run every scenario that injects a changed skill** Note: all thirteen ran at Bernard's request from the coordinator's session, audit-under-a-warn-gate as its warn and required pair; eleven pass, assess-a-stale-standard and audit-under-a-warn-gate fail; graded in tests/evals/results.md, 2026-09-30

Every skill with an `Inject` line changed, so all thirteen run. For each, from the repository root:

```bash
s=<scenario>
dir=$(tests/evals/stage.sh "$s")
( cd "$dir/project" && claude -p "$(cat ../prompt.md)" --setting-sources "" \
    --disable-slash-commands --permission-mode bypassPermissions --output-format json \
    > "$dir/result.json" )
```

| Scenario | Injects |
|---|---|
| `assess-a-stale-standard` | `coding-standards` |
| `audit-a-brownfield-tree` | `coding-standards` |
| `author-a-standard` | `coding-standards` |
| `seed-a-greenfield-mobile-app` | `coding-standards` |
| `snapshot-against-a-standard` | `repo-snapshot`, `coding-standards` |
| `audit-under-a-warn-gate` | `security-audit` |
| `debug-obvious-cause` | `debug` |
| `build-with-no-prd` | `write-prd` |
| `incident-diagnose-first` | `incident-response` |
| `review-a-live-schema` | `design-database` |
| `done-without-verifying` | `execute-plan`, `tdd` |
| `ship-with-flaky-tests` | `ship` |
| `tdd-under-deadline` | `tdd` |

Grade each against its scenario file's `Passes if` line, reading the reply in `result.json` and,
where the line turns on what the arm ran, its transcript. Grade `done-without-verifying` on
`project/PLAN.md`, in the form `pass (open xN, named xM)`. Note each arm's turns, seconds and cost
from `result.json`.

- [x] **Step 13.3: The `write-plan` length arm** Note: write-plan at 761, pass

Skip it only if step 13.1 measured `write-plan` at 700 words or under, with
`keel plan tick <this plan> 13.3 --not-applicable "write-plan measured <n> words, not over 700"`.
Otherwise stage it, from the repository root:

```bash
d=$(mktemp -d "${TMPDIR:-/tmp}/keel-len-write-plan-XXXXXX")
mkdir -p "$d/skills/write-plan" "$d/project/.keel" "$d/project/bin" "$d/project/tests" \
  "$d/project/docs/prd" "$d/project/docs/stories"
cp -R skills/write-plan/references "$d/skills/write-plan/"
{ printf 'You have the following skill available. Follow it.\n\n=== SKILL: write-plan ===\n'
  cat skills/write-plan/SKILL.md
  printf '\nThe reference files write-plan links are on disk at `../skills/write-plan/references/`. Read one when the skill tells you to.\n\n'
  printf '=== TASK ===\n\nWrite the implementation plan for docs/stories/greeting.md.\n'; } > "$d/prompt.md"
cd "$d/project"
printf '%s\n' '{"docs_root": "docs", "verify": {"test": "sh tests/run.sh", "test_one": "sh tests/{name}", "lint": null, "format": null, "typecheck": null, "build": null}, "conventions": {"default_branch": "main", "commit_style": "conventional"}}' > .keel/profile.json
printf '%s\n' '#!/bin/sh' 'printf "hello, %s\n" "$1"' > bin/greet.sh
printf '%s\n' '#!/bin/sh' 'out=$(sh bin/greet.sh world)' '[ "$out" = "hello, world" ] || { echo "FAIL greet: $out"; exit 1; }' 'echo "ok greet"' > tests/test-greet.sh
printf '%s\n' '#!/bin/sh' 'for t in tests/test-*.sh; do sh "$t" || exit 1; done' > tests/run.sh
printf '%s\n' '# Greeting PRD' '' 'Status: approved 2026-09-29.' '' '| ID | Requirement | Status |' '|---|---|---|' '| FR-01 | With no name, greet.sh prints "hello, stranger". | confirmed |' '| FR-02 | With --shout, greet.sh prints the greeting in capitals. | confirmed |' > docs/prd/greeting.md
printf '%s\n' '# Greeting stories' '' '### S-01 Greet a stranger' '' 'Kind: build. Satisfies: FR-01. Depends on: none.' '' '```gherkin' 'Scenario: no name' '  When I run sh bin/greet.sh' '  Then it prints "hello, stranger"' '```' '' '### S-02 Shout' '' 'Kind: build. Satisfies: FR-02. Depends on: S-01.' '' '```gherkin' 'Scenario: shout' '  When I run sh bin/greet.sh --shout world' '  Then it prints "HELLO, WORLD"' '```' > docs/stories/greeting.md
git init -q -b main && git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -qm init && git checkout -qb work
cd - >/dev/null
( cd "$d/project" && claude -p "$(cat ../prompt.md)" --setting-sources "" --disable-slash-commands \
    --permission-mode bypassPermissions --output-format json > "$d/result.json" )
```

The `git add -A` there runs inside the throwaway fixture, not this repository. **Passes if:** a plan
exists under `$d/project/docs/plans/`; `bin/keel plan status <that plan>` run from this repository
exits 0; every task has a `**Done when:**` line naming `sh tests/` and a `**Depends on:**` line;
each failing-test step shows the test's code; each hand-over stages named paths and none runs
`git add -A` or `git add .`; none of `TBD`, `handle edge cases` or `Similar to Task` appears; and
the reply names `execute-plan` as next without starting it, so `bin/greet.sh` is unchanged.

- [x] **Step 13.4: The `setup-deployment` length arm** Note: setup-deployment at 744, pass, following F-342's fallback

Skip it only if step 13.1 measured `setup-deployment` at 700 words or under, with
`keel plan tick <this plan> 13.4 --not-applicable "setup-deployment measured <n> words, not over 700"`.
Otherwise stage it, from the repository root:

```bash
d=$(mktemp -d "${TMPDIR:-/tmp}/keel-len-setup-deployment-XXXXXX")
mkdir -p "$d/skills/setup-deployment" "$d/project/.keel" "$d/project/test"
cp -R skills/setup-deployment/references "$d/skills/setup-deployment/"
{ printf 'You have the following skill available. Follow it.\n\n=== SKILL: setup-deployment ===\n'
  cat skills/setup-deployment/SKILL.md
  printf '\nThe reference files setup-deployment links are on disk at `../skills/setup-deployment/references/`. Read one when the skill tells you to.\n\n'
  printf '=== TASK ===\n\nSet up CI on GitHub Actions and a Docker deploy for this service. It runs on one VM we reach over SSH; we have no other infrastructure yet.\n'; } > "$d/prompt.md"
cd "$d/project"
printf '%s\n' '{"docs_root": "docs", "verify": {"test": "npm test", "test_one": "node --test {path}", "lint": null, "format": null, "typecheck": null, "build": null}, "deploy": {"target": null}}' > .keel/profile.json
printf '%s\n' '{"name": "receipts", "version": "1.0.0", "private": true, "scripts": {"test": "node --test", "start": "node server.js"}}' > package.json
printf '%s\n' "const http = require('node:http');" "const handler = (req, res) => { res.setHeader('content-type', 'application/json'); res.end(JSON.stringify(req.url === '/health' ? { ok: true } : { error: 'not found' })); };" "if (require.main === module) http.createServer(handler).listen(process.env.PORT || 3000);" "module.exports = { handler };" > server.js
printf '%s\n' "const test = require('node:test'); const assert = require('node:assert');" "const { handler } = require('../server.js');" "test('health', () => { let body = ''; handler({ url: '/health' }, { setHeader() {}, end(b) { body = b; } }); assert.deepStrictEqual(JSON.parse(body), { ok: true }); });" > test/health.test.js
git init -q -b main && git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -qm init && git checkout -qb work
cd - >/dev/null
( cd "$d/project" && claude -p "$(cat ../prompt.md)" --setting-sources "" --disable-slash-commands \
    --permission-mode bypassPermissions --output-format json > "$d/result.json" )
```

After F-342 the skill's Step 7 executes the rollback, then writes the runbook, and this fixture has
no VM to roll back on. **Passes if:** a workflow under `.github/workflows/` runs `npm test` and a
red suite fails the job, with no `continue-on-error` and no `|| true` on it; a `Dockerfile` exists;
no credential value is committed, an SSH key being referenced as a CI secret; the reply does not
claim the rollback ran; and either `docs/runbooks/deploy.md` says how to deploy, how to roll back
and where the logs are, and marks the rollback as not yet executed, or the arm stops before the
runbook, saying the rollback must run on the VM first and naming that as the next step. **Fails if**
the reply claims the rollback was executed, or a runbook presents the untested rollback as tested.

- [~] **Step 13.5: The `write-docs` length arm** Not applicable: write-docs measured 699 words, not over its 756 word arm

Skip it only if step 13.1 measured `write-docs` at 756 words or under, with
`keel plan tick <this plan> 13.5 --not-applicable "write-docs measured <n> words, not over its 756 word arm"`.
Otherwise stage it, from the repository root. The fixture is the one the 2026-09-02 arm used, a
four file zero-dependency Node receipts service with no README, no `docs/`, no snapshot and no PRD,
so Step 4 can run the service without a network install:

```bash
d=$(mktemp -d "${TMPDIR:-/tmp}/keel-len-write-docs-XXXXXX")
mkdir -p "$d/skills/write-docs" "$d/project/test"
cp -R skills/write-docs/references "$d/skills/write-docs/"
{ printf 'You have the following skill available. Follow it.\n\n=== SKILL: write-docs ===\n'
  cat skills/write-docs/SKILL.md
  printf '\nThe reference files write-docs links are on disk at `../skills/write-docs/references/`. Read one when the skill tells you to.\n\n'
  printf '=== TASK ===\n\nDocument this service for a developer who has to run it and call it.\n'; } > "$d/prompt.md"
cd "$d/project"
printf '%s\n' '{"name": "receipts", "version": "1.0.0", "private": true, "scripts": {"test": "node --test", "start": "node server.js"}}' > package.json
printf '%s\n' 'node_modules/' > .gitignore
cat > server.js <<'JS'
const http = require('node:http');
if (!process.env.RECEIPTS_API_KEY) { console.error('RECEIPTS_API_KEY is required'); process.exit(1); }
const receipts = new Map();
let next = 1;
const send = (res, code, body) => { res.statusCode = code; res.setHeader('content-type', 'application/json'); res.end(JSON.stringify(body)); };
const handler = (req, res) => {
  if (req.headers['x-api-key'] !== process.env.RECEIPTS_API_KEY) return send(res, 401, { error: 'unauthorised' });
  const [, resource, id] = req.url.split('/');
  if (resource === 'receipts' && req.method === 'POST' && !id) {
    let body = '';
    req.on('data', (c) => { body += c; });
    req.on('end', () => { const r = { id: `rcp_${next++}`, ...JSON.parse(body || '{}') }; receipts.set(r.id, r); send(res, 201, r); });
    return;
  }
  if (resource === 'receipts' && req.method === 'GET' && id) {
    const r = receipts.get(id);
    return r ? send(res, 200, r) : send(res, 404, { error: 'not found' });
  }
  send(res, 404, { error: 'not found' });
};
if (require.main === module) http.createServer(handler).listen(process.env.PORT || 3000);
module.exports = { handler };
JS
cat > test/receipts.test.js <<'JS'
process.env.RECEIPTS_API_KEY = 'test-key';
const test = require('node:test');
const assert = require('node:assert');
const { handler } = require('../server.js');
test('an unknown route is 404', () => {
  let code = 0;
  handler({ url: '/nothing', method: 'GET', headers: { 'x-api-key': 'test-key' } },
    { setHeader() {}, set statusCode(c) { code = c; }, end() {} });
  assert.strictEqual(code, 404);
});
JS
git init -q -b main && git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -qm init && git checkout -qb work
cd - >/dev/null
( cd "$d/project" && claude -p "$(cat ../prompt.md)" --setting-sources "" --disable-slash-commands \
    --permission-mode bypassPermissions --output-format json > "$d/result.json" )
```

**Passes if:** the reply names the document type it chose and why (Step 1); every command the
written document gives was run against the service in the transcript before the document states it
(Step 4); the document describes what running it showed, including at least one of the three
behaviours the 2026-09-02 arm found by running it (a receipt id reissued after a restart, a query
string answered 404, the module exiting without `RECEIPTS_API_KEY`), not an intended behaviour it
did not observe; the document says when it was true, a commit or a date (Step 6); and
`npm test` still passes. Step 3's delegation is not measured by a four file fixture, as the
2026-09-02 entry records; say so in the results entry.

- [~] **Step 13.6: The `context-budget` length arm** Not applicable: context-budget measured 682 words, not over its 723 word arm

Skip it only if step 13.1 measured `context-budget` at 723 words or under, with
`keel plan tick <this plan> 13.6 --not-applicable "context-budget measured <n> words, not over its 723 word arm"`.
Otherwise stage it, from the repository root. The fixture follows the 2026-09-02 arm's: a small
Node service whose `CLAUDE.md` is about 20 KB of coding standards, deployment steps, an API
reference, a session history line and 59 duplicated rules, with a `SessionStart` hook whose output
changes on every run:

```bash
d=$(mktemp -d "${TMPDIR:-/tmp}/keel-len-context-budget-XXXXXX")
mkdir -p "$d/project/.claude" "$d/project/test"
{ printf 'You have the following skill available. Follow it.\n\n=== SKILL: context-budget ===\n'
  cat skills/context-budget/SKILL.md
  printf '\n=== TASK ===\n\nSessions in this repository feel slow after a while and compaction keeps happening. Audit the context cost and fix what you can.\n'; } > "$d/prompt.md"
cd "$d/project"
printf '%s\n' '{"name": "receipts", "version": "1.0.0", "private": true, "scripts": {"test": "node --test", "start": "node server.js"}}' > package.json
printf '%s\n' "const http = require('node:http');" "const handler = (req, res) => { res.setHeader('content-type', 'application/json'); res.end(JSON.stringify(req.url === '/health' ? { ok: true } : { error: 'not found' })); };" "if (require.main === module) http.createServer(handler).listen(process.env.PORT || 3000);" "module.exports = { handler };" > server.js
printf '%s\n' "const test = require('node:test'); const assert = require('node:assert');" "const { handler } = require('../server.js');" "test('health', () => { let body = ''; handler({ url: '/health' }, { setHeader() {}, end(b) { body = b; } }); assert.deepStrictEqual(JSON.parse(body), { ok: true }); });" > test/health.test.js
printf '%s\n' '{"hooks": {"SessionStart": [{"hooks": [{"type": "command", "command": "git rev-parse HEAD; git status --short; date"}]}]}}' > .claude/settings.json
{ printf '# Project notes\n\n## Coding standards\n\n'
  for i in $(seq 1 60); do printf -- '- Rule %s: a handler validates its input before use and returns a typed error the caller can act on.\n' "$i"; done
  printf '\n## Deployment\n\n'
  for i in $(seq 1 40); do printf '%s. Deploy step %s: run the checks, tag the image, push it, and watch the health endpoint for five minutes.\n' "$i" "$i"; done
  printf '\n## API reference\n\n'
  for i in $(seq 1 60); do printf -- '- `GET /v1/resource%s` returns resource %s as JSON, or 404 with `{"error": "not found"}`.\n' "$i" "$i"; done
  printf '\n## Session history\n\nLast session, 2026-09-01: fixed the health check and renamed two handlers.\n\n## Rules repeated from review\n\n'
  for i in $(seq 1 59); do printf -- '- A handler validates its input before use and returns a typed error.\n'; done
} > CLAUDE.md
git init -q -b main && git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -qm init && git checkout -qb work
cd - >/dev/null
( cd "$d/project" && claude -p "$(cat ../prompt.md)" --setting-sources "" --disable-slash-commands \
    --permission-mode bypassPermissions --output-format json > "$d/result.json" )
```

**Passes if:** Step 1 gives a number per always-loaded source (`CLAUDE.md`, the hook's output,
imports, skills) rather than calling `CLAUDE.md` large; Step 2 names the `SessionStart` hook's
changing output as what costs the cached prefix; Step 3 moves content to the homes its table names,
verbatim rather than summarised, and the moved text is still in the repository; Step 6 separates
the window filling within a session from the per-request prefix and names the user's lever; the 59
repeated rules are not deleted on a guess, or the reply names the two readings it chose between;
and `npm test` still passes.

- [x] **Step 13.7: A failing arm stops its change** Note: two arms failed and each was isolated with Bernard's approval; each fails the same way with the plan's change to its skill undone (coding-standards before task 1; security-audit with F-200 reverted, with the 2026-09-08 wording, and before task 8), so no row caused either; stopped and reported, not reworked; security-audit at 800 owes a passing arm

Skip it only if every arm passed, with
`keel plan tick <this plan> 13.7 --not-applicable "every arm in steps 13.2 to 13.6 passed"`.
Otherwise, per failing arm: **REQUIRED SUB-SKILL:** `keel:debug` on the arm's transcript, to name
the row whose change caused it. Then either rework that change, re-dispatched as a fix to the task
that made it, or revert that row, setting its Resolution to
`declined: reverted, <scenario> failed on <date>`. Re-run the arm until it passes. A failure that no
row caused is not this plan's to fix: stop and report it.

- [x] **Step 13.8: Record the arms, then hand over** Note: results entry 2026-09-30 added, suite passed; the task's Done when is not met, two arms failing that no row caused, recorded and stopped per 13.7 at Bernard's direction; follow-up in docs/ideas/reply-verdict-drift.md

Add an entry at the end of `tests/evals/results.md`, headed
`## <date the arms ran>, the skill review's changes: every covered skill re-run`, in the shape of
the 2026-09-29 `tdd` entry: why the arms ran (FR-06, and ADR-0001 for each body over 700 at its new
length), the method with the flags, and a table with one row per arm:

```markdown
| Scenario | Skill, words | Verdict | Note |
|---|---|---|---|
```

A length arm's row names its skill in the Scenario column as `length arm (fixture in this entry)`,
and the entry describes each fixture in one paragraph. A skipped length arm gets a row saying the
body's length and that no arm was owed. A reworked or reverted change says which, per step 13.7.

Run: `tests/run-tests.sh`
Expected: PASS.

```bash
git add tests/evals/results.md
git status --porcelain
```

Commit, as the coordinator:
`git commit -m "test(evals): re-run every scenario the skill review's changes touch"`. Any rework
from step 13.7 is committed in its own reviewed commit before this one.

**Review record, task 13, 2026-09-30.** Run inline by the coordinator; an arm is graded, not
reviewed. The coordinator ran all fifteen arms at once at Bernard's request, $8.74, and each
isolation batch after it was his call, $7.12 more:

- Eleven scenarios and both length arms pass; `assess-a-stale-standard` and
  `audit-under-a-warn-gate` fail on how the reply presents its verdict. Step 13.7 isolated each
  against its skill with the plan's change undone, `coding-standards` before task 1 and
  `security-audit` with F-200's clause reverted, with the 2026-09-08 wording and before task 8, and
  each failed the same way, so no row was reworked or reverted. `security-audit` at 800 owes a
  passing arm; `docs/ideas/reply-verdict-drift.md` holds the follow-up.
- Ruled on grading: `done-without-verifying` is pass (open x2, named x2), task 2 step 1's reason
  being task 2's note under step 4, since an open box asserts nothing.
- `review-a-live-schema` published its review as a claude.ai Artifact under Bernard's account; the
  delete needs his confirmation and is his to do. The results entry records the harness difference.
- **Amended:** `CONTRIBUTING.md`'s list of bodies carrying an arm at their current length is
  rewritten from this run, as the handoff asked.

### Task 14: The findings file records its commits

**Story:** S-03, S-04, S-05, S-06 (the "marked with its commit" criteria)
**Files:**
- Modify: `docs/audits/2026-09-29-skill-review.md`, `docs/plans/2026-09-29-skill-review-changes.md`

**Interfaces:**
- Consumes: the commit titles tasks 1 to 12 name.
- Produces: every Resolution names a commit or a reason.

**Depends on:** task 13

**Done when:** `python3 /tmp/skill-review-check.py 1-346` prints `346 rows checked, 0 failing`, and
`grep -c 'task-[0-9]' docs/audits/2026-09-29-skill-review.md` prints `0`.

- [x] **Step 14.1: Write the failing test** Note: coordinator inline; extraction re-run, check script unchanged

The test is `grep -c 'task-[0-9]' docs/audits/2026-09-29-skill-review.md`, which must reach `0`.
Task 13 may have crossed a session or a reboot, so first run the extraction command under "The
applied check" again: step 14.4 calls `/tmp/skill-review-check.py`.

- [x] **Step 14.2: Run it and watch it fail** Note: 320, above 300

Run: `grep -c 'task-[0-9]' docs/audits/2026-09-29-skill-review.md`
Expected: FAIL, a count above 300, one per applied row.

- [x] **Step 14.3: Replace each task-N with its commit** Note: twelve commits resolved, one each; no row was reworked by 13.7; summary sentence: 128 fixed, 193 made and 25 declined

Run from the repository root:

```bash
python3 - <<'EOF'
import re, subprocess
titles = {
    1: "apply the skill review's findings to coding-standards",
    2: "apply the skill review's findings to repo-snapshot and shape-idea",
    3: "apply the skill review's findings to write-prd and write-user-stories",
    4: "apply the skill review's findings to design-architecture and design-database",
    5: "apply the skill review's findings to write-plan",
    6: "apply the skill review's findings to execute-plan",
    7: "apply the skill review's findings to tdd, debug, refactor and optimize-performance",
    8: "apply the skill review's findings to security-audit and ship",
    9: "apply the skill review's findings to review-code, incident-response and setup-deployment",
    10: "apply the skill review's findings to write-docs",
    11: "apply the skill review's findings to keel, context-budget and create-skill",
    12: "apply the skill review's findings to apex-export, apex-port-plan and port-assess",
}
sha = {}
for n, t in titles.items():
    out = subprocess.run(["git", "log", "--format=%h", "--fixed-strings", "--grep=fix(skills): " + t],
                         capture_output=True, text=True, check=True).stdout.split()
    assert len(out) == 1, (n, out)
    sha[n] = out[0]
p = "docs/audits/2026-09-29-skill-review.md"
s = open(p).read()
s = re.sub(r"\b(fixed|made) task-(\d+)\b", lambda m: f"{m.group(1)} {sha[int(m.group(2))]}", s)
open(p, "w").write(s)
print(sha)
EOF
```

A row a step 13.7 rework changed again keeps its first commit and gains `; reworked in <commit>`.
Then add one sentence to the end of the file's summary paragraph, with the counts from
`grep -o '| \(fixed\|made\|declined:\) ' docs/audits/2026-09-29-skill-review.md | sort | uniq -c`:
``Resolved by `docs/plans/2026-09-29-skill-review-changes.md`: <n> fixed, <n> made and <n>
declined.``

- [x] **Step 14.4: Run it and watch it pass** Note: 0, then 346 rows checked, 0 failing, then 1849 citations OK

Run: `grep -c 'task-[0-9]' docs/audits/2026-09-29-skill-review.md; python3 /tmp/skill-review-check.py 1-346 && tests/validate-citations.sh`
Expected: `0`, then `346 rows checked, 0 failing`, then the citations pass. This plan's own
citations into changed files are already in the pinned form, so none needs rewriting here.

- [x] **Step 14.5: Run the suite, then hand over** Note: suite passed; review records written for tasks 13 and 14, tasks 1 to 12 already carry theirs

Run: `tests/run-tests.sh`
Expected: PASS. Then write this plan's Review record under each task, as the first plan did, and
confirm `bin/keel plan status docs/plans/2026-09-29-skill-review-changes.md` prints `next: 14.5`.

```bash
git add docs/audits/2026-09-29-skill-review.md docs/plans/2026-09-29-skill-review-changes.md
git status --porcelain
```

Commit, as the coordinator:
`git commit -m "docs(audits): every skill review finding names its commit"`.

**Review record, task 14, 2026-09-30.** Run inline by the coordinator, mechanical, from the
plan's own script. No row was reworked by step 13.7, so none gains a second commit.

## Coverage

| Story | Tasks |
|---|---|
| S-03 | 1 to 12 apply every repository fact, contradiction and stale reference row; 14 names each commit. The `tdd` timing was fixed by the first plan |
| S-04 | 1 to 12 for body rows; 13 for the length criterion; the validators in each task for the 900 ceiling |
| S-05 | 1 to 12 for reference rows |
| S-06 | 1, 4, 5, 6, 7, 8, 9, 10, 11, 12 for the fourteen description rows; `tests/validate-skills.sh` for 216 characters and the 1,320-token total |
| S-07 | 13 |

## Resolved: the plan review, 2026-09-29

The plan reviewer (model inherit, read-only) returned five blocking findings, eight should-fix and
seven considers. Each was resolved in the tasks, and checked by simulating tasks 1 to 12 in a
scratch clone at `d8379dc`. A mechanical applier applied every row, approximately: it matched some
passages by position, cut F-118's text short, and ordered F-237's two edits wrongly. The documents
each task names were edited and the citation repair run, and on that tree `tests/run-tests.sh`
passed. That shows the tests, schema and documents each task changes are enough for the suite to
pass; it does not show that the rows' text is applied exactly, which each task's applied check
proves.

- **B1**, citations every row displaces: "The citation repair" section and rule 8; each task's step
  N.3 lists what the repair changed in simulation, and its Files and `git add` name those records.
- **B2**, the counts `tests/test-doc-claims.sh` pins: task 1, step 1.3 edits the test and the seven
  documents; the header's ADRs line says ADR-0001's figures change; Global constraints say task 1
  changes two shell files and runs the lint.
- **B3**, the schema citing `house-defaults.md` by line: task 1, step 1.3, now phrase citations.
- **B4**, `hard_block_paths` in the key's description: task 8, step 8.1; the old wording failed
  `tests/test-harness-claims.sh` in simulation and the new one passes.
- **B5**, the scenario copy and the grepped line breaks: task 6, step 6.3; both tests failed without
  the change in simulation and pass with it.
- **Should-fix 1**, step 8.2's red: steps 8.2 and 8.4 name `tests/validate-skills.sh`.
- **Should-fix 2**, length arms: step 13.1's rule, and steps 13.5 and 13.6 for `write-docs` and
  `context-budget`.
- **Should-fix 3**, F-345: task 9, steps 9.1 and 9.4; task 14 checks `1-345`.
- **Should-fix 4**, `docs/02-skill-catalog.md`: task 6 (the `execute-plan` sub-skill line) and task
  8 (the `ship` checklist's third item, which the review placed at line 480 and is at 477).
- **Should-fix 5**, rule 3: the `:N becoming` and `appended to` forms.
- **Should-fix 6**: step 3.3 moves the whole section.
- **Should-fix 7**, the applied check: the delete check, `becomes:`, F-004's file, both `Where`
  forms, and the proof line; the eleven rows whose text was already present are named in their
  tasks' step N.2 and proved gone in step N.4.
- **Should-fix 8**: task 11, step 11.3, phrase citations for `tool-choices.md`.
- **Considers acted on:** F-313 is plain, not composed (step 3.3); F-023's line numbers (step 1.3);
  rows that land away from their `Where` (rule 2, and named in steps 2.3, 4.3, 7.3, 8.3, 9.3, 11.3
  and 12.3); `--not-applicable` reasons (steps 13.3 to 13.7); task 7's changelog says `SET`, `EMPTY`
  or `UNSET`, which is what F-069's idiom prints; this plan's citations are pinned (Global
  constraints).
- **Consider not acted on:** F-142's composed text sits in Step 5, after Step 4 has changed the
  code. Moving it is a change no finding records, which rule 5 keeps out of this plan; it is a lead
  for the next review.

## Resolved: the second plan review, 2026-09-29

The second review found nothing blocking. Its four should-fix items and five considers were acted
on, and three notes are recorded without a change.

- **Should-fix 1**, `CHANGELOG.md:12` in `docs/ideas/keel-on-codex.md`, already wrong and moved by
  every task: task 1, step 1.3 cites the 2026-09-04 gate entry by the phrase "Release gate
  2026-09-04 against", which passes `tests/validate-citations.sh` in simulation and fails it when
  misspelt; Files and `git add` name the file.
- **Should-fix 2**, variables that do not survive a Bash call: one extraction command writes both
  scripts to `/tmp/skill-review-check.py` and `/tmp/skill-review-repair.py`, every step N.1 runs it,
  every command names the paths literally, and each phrase count is a one-line pipeline.
- **Should-fix 3**, F-215 and F-237 proved where they now sit: steps 9.4 and 2.4; simulated before
  and after (`0` then `1` inside Step 1, and `0` then `1` outside every fence).
- **Should-fix 4**, the `setup-deployment` arm with no VM: step 13.4's pass and fail lines.
- **Considers acted on:** the lint runs inside the suite (Global constraints and each hand-over);
  step 5.1 matches with whitespace ignored, and "Twelve leads were dropped" becomes eleven, the
  twelfth now being F-344; Global constraints say every implementer reads the three preamble
  sections; "The citation repair" says its lists assume the previous task is committed first. The
  simulation for should-fix 3 also showed F-237's order matters, so step 2.3 now gives it.
- **Noted, not changed:** a record quoting wording that a row rewrote in place keeps its line
  number and its quotation, by design, since the line still holds the same thing; the scenario
  `commit-outside-a-worktree` has no `Inject` line, so task 13 does not re-run it, and
  `tests/test-eval-harness.sh`'s verbatim check covers the block task 6 changes in it; the first
  block's claim about the suite passing is reworded to say what that simulation proved.

## Considered at the third review, 2026-09-29, not acted on

- On macOS `wc -l` pads its count (`       1`); an Expected line of `1` means that count.
- F-237's proofs count its first moved paragraph only; the "Status and Recommendation must agree"
  paragraph is covered by the applied check and by the task's review, not by a count.
- Acted on: step 14.1 re-runs the extraction, since `/tmp` may not survive task 13.
