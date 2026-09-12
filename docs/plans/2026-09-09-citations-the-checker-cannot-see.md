# The citations the checker cannot see, and four follow-ups: Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go, on output you read.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness, or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** every citation this repository makes about itself is either checked mechanically or is a
dated record that says when it was true, and the four defects the last branch found and could not
fix inside its own scope are fixed.

**Stories:** none. The input is the open questions of
`docs/plans/2026-09-07-declared-profile-keys-take-effect.md` (0, 0a, 0c, 3a, 4) and its handoff,
plus two decisions Bernard took on 2026-09-09 and one defect found while writing this plan. Each
task below traces to one of those rather than to a story id. Recorded here rather than left for a
reader to notice.

**ADRs:** none new. ADR-0001 (body budgets) is untouched: no skill body changes here.

**Architecture:** the citation checker gains two things it never had, coverage of paths with no file
extension and a phrase form, and the repository's live documents move onto the phrase form while its
dated records keep their line numbers and their dates. The profile schema's `x-keel-read-by` gains
the same phrase form and a fifth value, `observed:`, for a key a model was measured reading
unprompted. Three unrelated defects, a false claim in two documents, a stale dogfood profile and a
racy test, are fixed alongside because they are what the last branch left open.

## What was measured, and what it changes

**`tests/validate-citations.sh` has never checked a single citation into `bin/keel`.** Its regex
requires a dot extension:

```
CITATION_RE='[A-Za-z0-9._/-]+[.](md|sh|json|yml|yaml|txt|toml):[0-9]+(-[0-9]+)?'
```

`bin/keel` has no extension, and neither does any file under `hooks/`. Measured on 2026-09-09:
**420 citations in this tree point at an extensionless file, 351 of them at `bin/keel`**, which is
both the most cited and the most edited file in the repository. The checker's summary says
`OK 954 citations checked` and does not mention them, so the number a reader trusts is the count of
the citations that were never in danger.

This reframes what the last branch recorded as a blank-line limitation. Its handoff says a one-line
insertion silently moved 116 citations and that a line-number citation into `bin/keel` has a
half-life of about one task. Both are true, and the reason nothing went red was not only that the
moved citations landed on non-blank lines. **Nothing was looking at them at all.**

Turning the coverage on reports **30 findings**, listed in task 2. Every one is in a dated record.

**A third defect class exists that no rule can see: an inverted range.** `a881010` on this branch
repaired 35 citations mechanically by replacing the start of each, which left the old end behind on
two ranges. Fenced, because the rule this plan adds reads an unfenced one as a claim and these two
are the examples:

```
bin/keel:77-78           became   bin/keel:100-78
CONTRIBUTING.md:132-136  became   CONTRIBUTING.md:138-136
```

The checker reported `OK` on both, because the end is inside the file and the first line is not
blank. Both were fixed in `796105c`; the rule that would have caught them is in task 2.

## The line this plan draws

A document that says what is true **now** cites by phrase. A document that records what was true on
a **date** keeps its line numbers, and its date is what tells a reader how far to trust them.

| Cites by phrase, and a rule enforces it | Keeps line numbers, by decision |
|---|---|
| `templates/profile.schema.json` markers | `docs/plans/`, `docs/prd/`, `docs/stories/` |
| Code comments under `bin/`, `hooks/`, `lib/`, `tests/` | `docs/architecture/`, `docs/decisions/`, `docs/audits/`, `docs/ideas/` |
| `skills/**/*.md` | `docs/07-open-decisions.md`, resolved and dated |
| `README.md`, `CONTRIBUTING.md`, `docs/0[1-6]-*.md` | `CHANGELOG.md`, one entry per released version |
| `docs/profile-keys.md`, generated from the markers | `tests/evals/results.md`, `lib/harness/capabilities`, both dated evidence |

**Why the second column is not laziness.** Converting all 297 line-number citations in that column
would mean choosing a phrase for each without being able to verify what the sentence meant when it
was written. This branch measured the base rate: **five for five, every citation it was forced to
look at closely had been wrong before the insertion that exposed it.** A mechanical conversion of an
unverified citation produces a permanently green pointer at the wrong content, and open question 3a
of the previous plan already names that as the worst outcome available: a green checker on a false
claim is worse than a red one on a true claim, because nothing will look at it again.

## Global constraints

Copied in full. Every task inherits these.

- Verify commands, from `.keel/profile.json`: test `tests/run-tests.sh`, one test `tests/{name}`,
  lint `shellcheck -x bin/keel lib/*.sh lib/harness/*.sh tests/*.sh tests/evals/run.sh tests/evals/stage.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`.
  There is no typecheck, format or build command in this project.
- The branch is `profile-keys-take-effect-or-say-they-do-not`, and PR #62 into `sandbox` is open and
  green. **All nine tasks land on that branch, before it merges.** Never start on `main`.
- `CONTRIBUTING.md` says the too-strict failure is the unrecoverable one: a check that cries wolf
  over a correct citation teaches people to ignore it, and the real stale one then goes past unread.
  **Every rule added here carries a must-not-reject case in its test file**, not only a case proving
  it catches something.
- `docs/standards.md` says a gate is never weakened so this repository can pass it. A finding this
  plan exposes is repaired or recorded, never suppressed.
- A dated record's **pointer** may be repaired. Its **claim** may not be rewritten. Task 6a of the
  previous plan set that precedent, repairing four citations inside a plan while changing no prose.
- No em dashes anywhere, in code, comments, documents or commit messages. Commas, full stops or
  parentheses instead. Commit messages carry no attribution footer and no robot emoji.
- The implementer stages named paths and does not commit. The coordinator commits after review.
- **No concurrent batches.** Tasks 1, 3, 7 and 9 touch disjoint files and could in principle overlap,
  but tasks 2, 5 and 6 each depend on a rule an earlier task adds, task 8 edits `.keel/profile.json`
  which the template forbids in a batch, and the suite takes about four minutes, so a batch buys
  little and costs a worktree join. Sequential, and said out loud rather than left as an omission.

---

### Task 1: A phrase form for prose citations

**Traces to:** open question 0c of the previous plan, and Bernard's decision of 2026-09-09.

**Files:**
- Modify: `tests/validate-citations.sh`
- Test: `tests/test-validate-citations.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: the `` `path#phrase` `` citation form, checked by resolution. Tasks 2 and 5 write
  citations in it.

**Depends on:** none

**Done when:** `tests/test-validate-citations.sh` passes and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

Add to `fixture_valid` in `tests/test-validate-citations.sh`, inside the `docs/ideas/example.md`
heredoc, after the existing range line:

```
The same claim by phrase: `tests/evals/results.md#Checked the exception list explicitly`.
```

Then add these cases after the existing `m_range_starts_blank` case:

```bash
# The phrase form. A line number into a file that changes often dies within about one task, measured
# on the branch that added this rule, and a phrase does not: it goes red when the text it names is
# gone, which is the claim a reader actually wants checked.
m_phrase_gone() {
    sed -i.bak 's|results.md#Checked the exception list explicitly|results.md#A sentence nobody wrote|' \
      "$1/docs/ideas/example.md"
}
run "a phrase citation whose text is not in the cited file is rejected" 1 m_phrase_gone

# The must-not-reject half. An anchor is part of a markdown link, not a citation, and three places in
# the real tree write `references/x.md#a-heading` while explaining exactly that. A rule that reads
# those as claims about this tree reports its own documentation as broken, which is how a checker
# gets ignored.
m_anchor_example() {
    printf 'A link of the form `references/x.md#a-heading` names a file and an anchor.\n' \
      >> "$1/docs/ideas/example.md"
}
run "an anchor-shaped example naming no repository directory is ignored" 0 m_anchor_example

# A phrase carrying a pipe cannot be printed into docs/profile-keys.md, which renders citations
# inside a markdown table, so the pipe would end the cell and the row would lose its columns.
m_phrase_with_pipe() {
    sed -i.bak 's|results.md#Checked the exception list explicitly|results.md#Checked \| the list|' \
      "$1/docs/ideas/example.md"
}
run "a phrase containing a pipe is rejected" 1 m_phrase_with_pipe

# And a phrase citation into a file that does not exist is the same finding as a line one.
m_phrase_missing_file() {
    sed -i.bak 's|tests/evals/results.md#Checked|docs/gone.md#Checked|' "$1/docs/ideas/example.md"
}
run "a phrase citation into a file that does not exist is rejected" 1 m_phrase_missing_file
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-validate-citations.sh`

Expected: FAIL on "a phrase citation whose text is not in the cited file is rejected" (expected exit
1, got 0), FAIL on "a phrase containing a pipe is rejected", and FAIL on "a phrase citation into a
file that does not exist is rejected". The two must-not-reject cases pass already, because nothing
reads the form yet. That asymmetry is the point: they are pinning behaviour that must survive the
implementation, not behaviour that is missing.

- [x] **Step 3: Write the minimal implementation**

In `tests/validate-citations.sh`, after the block that ends with the `if [ -n "$records" ]; then`
awk pass and its closing `fi`, add:

```bash
# ------------------------------------------------------------------ the phrase form
# `path#phrase` rather than `path:line`. A line number into a file that changes often has a half
# life of about one task, measured on the branch that added this: one insertion of 47 lines into
# bin/keel moved 32 citations that resolved correctly before it, and nothing went red. The three
# rules above are every claim a line number can support. A phrase supports the one a reader wants,
# which is that the text this sentence names is still there.
#
# Backticks bound the phrase, and nothing else can: a phrase in running prose has no end delimiter,
# and every citation in this repository is already written inside backticks.
#
# The phrase is matched literally, anywhere in the file, and it is not required to be unique. A
# phrase occurring twice still resolves, and rejecting it would be stricter than correct output,
# which CONTRIBUTING.md calls the unrecoverable failure. The conversion in this plan's task 5
# chooses unique phrases by hand; the rule does not demand it.
# shellcheck disable=SC2016
PHRASE_RE='`[A-Za-z0-9._/-]+([.](md|sh|json|yml|yaml|txt|toml))?#[^`]+`'

phrase_records=""
while IFS=$'\t' read -r citing cline cit; do
    cit="${cit#\`}"; cit="${cit%\`}"
    path="${cit%%#*}"
    phrase="${cit#*#}"
    checked=$((checked+1))

    dir="${citing%/*}"
    [ "$dir" = "$citing" ] && dir="."

    if [ -f "$path" ]; then
        target="$path"
    elif [ -f "$dir/$path" ]; then
        target="$dir/$path"
    else
        # The same rule the line form uses: root anchored means the citation is a claim about this
        # tree. Anything else is an anchor in a markdown link or another repository's path, and is
        # not this check's business.
        seg="${path%%/*}"
        if [ "$seg" != "$path" ] && [ -d "$seg" ]; then
            report "$citing:$cline cites \`$cit\`, and $path does not exist. The file was renamed or deleted and the citation was left behind."
        fi
        continue
    fi

    case "$phrase" in
        *"|"*)
            report "$citing:$cline cites \`$cit\`, and the phrase contains a pipe. docs/profile-keys.md renders these citations inside a markdown table, where a pipe ends the cell. Choose a phrase without one."
            continue ;;
    esac

    phrase_records="$phrase_records$citing:$cline	$target	$phrase	$cit
"
done < <(
    if [ "${#files[@]}" -gt 0 ]; then
        awk -v re="$PHRASE_RE" '
            FNR == 1 { fence = 0 }
            /^ *```/ { fence = !fence; next }
            fence    { next }
            {
                rest = $0
                while (match(rest, re)) {
                    printf "%s\t%d\t%s\n", FILENAME, FNR, substr(rest, RSTART, RLENGTH)
                    rest = substr(rest, RSTART + RLENGTH)
                }
            }
        ' "${files[@]}"
    fi
    if [ "${#code_files[@]}" -gt 0 ]; then
        awk -v re="$PHRASE_RE" '
            /^[ \t]*#/ {
                rest = $0
                while (match(rest, re)) {
                    printf "%s\t%d\t%s\n", FILENAME, FNR, substr(rest, RSTART, RLENGTH)
                    rest = substr(rest, RSTART + RLENGTH)
                }
            }
        ' "${code_files[@]}"
    fi
)

# One read per cited file, cached, for the same reason the line pass caches its counts.
if [ -n "$phrase_records" ]; then
    phrase_problems="$(printf '%s' "$phrase_records" | awk -F'\t' '
        function body(f,   s, line) {
            if (f in cache) return cache[f]
            s = ""
            while ((getline line < f) > 0) s = s line "\n"
            close(f)
            cache[f] = s
            return s
        }
        {
            where = $1; target = $2; phrase = $3; cit = $4
            if (index(body(target), phrase) == 0)
                printf "%s cites `%s`, and that text is not in %s. The phrase was edited or removed: quote it from the file as it reads now, or say what replaced it.\n", where, cit, target
        }
    ')"
    if [ -n "$phrase_problems" ]; then
        while IFS= read -r problem; do
            report "$problem"
        done <<<"$phrase_problems"
    fi
fi
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-validate-citations.sh`
Expected: PASS on all four new cases, and every case that passed before still passes.

Then run `tests/validate-citations.sh` against this repository. Expected: `OK`, with the count
unchanged at 954, because no citation in the tree uses the phrase form yet.

Then `tests/run-tests.sh`, green, and the lint command, clean.

- [x] **Step 5: Hand over**

```bash
git add tests/validate-citations.sh tests/test-validate-citations.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "feat(citations): a phrase form, for a citation that must outlive an insertion"`.

---

### Task 2: The checker sees citations into files with no extension, and an inverted range

**Traces to:** measured on 2026-09-09 while planning this work, and the two ranges `a881010`
inverted.

**Files:**
- Modify: `tests/validate-citations.sh` (`CITATION_RE`, and the range rule)
- Test: `tests/test-validate-citations.sh`
- Modify (repairs, 30 citations across 19 documents): `docs/architecture/tiered-multi-harness-support.md`,
  `docs/ideas/keel-on-codex.md`, `docs/ideas/leon-van-zyl-skill-collection.md`,
  `docs/ideas/profile-schema-drift.md`, `docs/plans/2026-08-17-release-readiness.md`,
  `docs/plans/2026-08-17-schema-version-and-snapshot-handoff.md`,
  `docs/plans/2026-08-18-context-window-at-init.md`, `docs/plans/2026-08-18-plsql-stack-detection.md`,
  `docs/plans/2026-08-18-usable-profile.md`, `docs/plans/2026-08-30-profile-sync.md`,
  `docs/plans/2026-09-05-tiered-multi-harness-support.md`,
  `docs/plans/2026-09-07-declared-profile-keys-take-effect.md`,
  `docs/prd/context-window-at-init.md`, `docs/prd/plain-language-chat.md`,
  `docs/prd/profile-sync.md`, `docs/prd/usable-profile.md`,
  `docs/stories/context-window-at-init.md`, `docs/stories/profile-sync.md`,
  `docs/stories/tiered-multi-harness-support.md`, `docs/stories/usable-profile.md`

**Interfaces:**
- Consumes: the phrase form from task 1, which is what the repairs below are written in.
- Produces: coverage of every citation in the tree, so the summary count becomes a true number.

**Depends on:** task 1

**Done when:** `tests/test-validate-citations.sh` passes, `tests/validate-citations.sh` reports `OK`
with a count above 1,100, and `tests/run-tests.sh` is green.

**The rule and its repairs land together.** Splitting them leaves the suite red between two commits,
and the repairs cannot be written in the phrase form until task 1 exists.

- [x] **Step 1: Write the failing test**

Add to `fixture_valid`, creating a file with no extension and a citation into it. After the
`hooks` directory is made:

```bash
    cat > "$root/hooks/example-hook" <<'HOOK'
#!/usr/bin/env bash
# A comment on the first line.

echo the fourth line
HOOK
```

and add to `docs/ideas/example.md`:

```
The hook does it at `hooks/example-hook:4`.
```

Then the cases:

```bash
# A path with no file extension. bin/keel is the most cited file in the real repository and has no
# extension, so until this rule every one of its 351 citations was invisible to this checker while
# the summary line said "954 citations checked".
m_extensionless_blank() {
    sed -i.bak 's|hooks/example-hook:4|hooks/example-hook:3|' "$1/docs/ideas/example.md"
}
run "a citation at a blank line of a file with no extension is rejected" 1 m_extensionless_blank

m_extensionless_past_end() {
    sed -i.bak 's|hooks/example-hook:4|hooks/example-hook:900|' "$1/docs/ideas/example.md"
}
run "a citation past the end of a file with no extension is rejected" 1 m_extensionless_past_end

# The must-not-reject half. A bare word and a number is not a citation: a time, a ratio and a
# version all have that shape, and the tree is full of them.
m_not_a_citation() {
    printf 'The run took 10:30 and the split was 70/30:1 by volume.\n' >> "$1/docs/ideas/example.md"
}
run "a colon and a number that names no file is ignored" 0 m_not_a_citation

# An inverted range. This is what a mechanical repair produces when it rewrites the start of a range
# and leaves the end: a881010 turned `bin/keel:77-78` into `bin/keel:100-78` and this checker said
# OK, because 78 is inside the file and line 100 is not blank.
m_inverted_range() {
    sed -i.bak 's|tests/evals/results.md:3-6|tests/evals/results.md:6-3|' "$1/docs/ideas/example.md"
}
run "a range whose start is after its end is rejected" 1 m_inverted_range
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-validate-citations.sh`

Expected: FAIL on the two extensionless cases and on the inverted range (expected exit 1, got 0).
"a colon and a number that names no file is ignored" passes already, and must still pass in step 4.

- [x] **Step 3: Write the minimal implementation**

Replace `CITATION_RE` in `tests/validate-citations.sh`:

```bash
# An extensioned path, as before, or any path with a directory in it. The second alternative is what
# reaches bin/keel and hooks/*, which have no extension: 420 citations in this tree point at such a
# file, 351 of them at bin/keel, and until this alternative existed the checker read none of them
# while reporting a count that sounded exhaustive. A bare word with no slash and no extension is not
# matched at all, because "10:30" and "70/30:1" are not citations, and the resolution loop below
# discards anything that does not name a real file under a real directory.
CITATION_RE='([A-Za-z0-9._/-]+[.](md|sh|json|yml|yaml|txt|toml)|[A-Za-z0-9._-]+/[A-Za-z0-9._/-]+):[0-9]+(-[0-9]+)?'
```

And in the awk pass that judges the line records, add the inverted-range rule before the range test:

```awk
            if (end < start) {
                printf "%s cites `%s`, and the range ends before it starts. A mechanical repair that rewrites the start of a range and leaves the end produces exactly this, and every other rule here passes it.\n", where, cit
                next
            }
```

- [x] **Step 4: Run it and watch it pass, then repair what it finds**

Run: `tests/test-validate-citations.sh`
Expected: PASS on all four new cases.

Run: `tests/validate-citations.sh`
Expected: **30 findings**, and this is the table of them, measured on 2026-09-09 against
`796105c`. Repair every one.

The table is fenced. It lists 30 citations that do not resolve, in the citation form, and the
rule this task adds reads an unfenced one as a claim: writing the table plainly turned 30
findings into 60 on the first run. The previous branch recorded the same shape for the line
form, where the first draft of its task 6a listed four broken citations and produced nine
failures.

```
docs/architecture/tiered-multi-harness-support.md:41                   bin/keel:1999            past the end, bin/keel is 1944 lines
docs/ideas/keel-on-codex.md:231                                        bin/keel:576-590         first line blank
docs/ideas/leon-van-zyl-skill-collection.md:262                        bin/keel:1946            past the end
docs/ideas/profile-schema-drift.md:70                                  bin/keel:1207            blank
docs/ideas/profile-schema-drift.md:102                                 bin/keel:1207            blank
docs/plans/2026-08-17-release-readiness.md:78                          bin/keel:1629-1631       blank
docs/plans/2026-08-17-schema-version-and-snapshot-handoff.md:236       bin/keel:1207            blank
docs/plans/2026-08-18-context-window-at-init.md:615                    bin/keel:290             blank
docs/plans/2026-08-18-plsql-stack-detection.md:422                     bin/keel:327             blank
docs/plans/2026-08-18-plsql-stack-detection.md:1289                    bin/keel:358             blank
docs/plans/2026-08-18-usable-profile.md:934                            bin/keel:290             blank
docs/plans/2026-08-18-usable-profile.md:995                            bin/keel:290             blank
docs/plans/2026-08-30-profile-sync.md:151                              bin/keel:1017            blank
docs/plans/2026-08-30-profile-sync.md:533                              bin/keel:1019-1020       blank
docs/plans/2026-09-05-tiered-multi-harness-support.md:36               bin/keel:464-478         blank
docs/plans/2026-09-05-tiered-multi-harness-support.md:931              bin/keel:464-478         blank
docs/plans/2026-09-07-declared-profile-keys-take-effect.md:791         bin/keel:1767            blank
docs/plans/2026-09-07-declared-profile-keys-take-effect.md:792         bin/keel:1788            blank
docs/plans/2026-09-07-declared-profile-keys-take-effect.md:1128        bin/keel:1375            blank
docs/prd/context-window-at-init.md:92                                  bin/keel:290             blank
docs/prd/context-window-at-init.md:93                                  bin/keel:385-389         blank
docs/prd/context-window-at-init.md:173                                 bin/keel:290             blank
docs/prd/plain-language-chat.md:87                                     hooks/session-start:71   blank
docs/prd/profile-sync.md:90                                            bin/keel:931             blank
docs/prd/profile-sync.md:96                                            bin/keel:1019-1020       blank
docs/prd/usable-profile.md:115                                         bin/keel:290             blank
docs/stories/context-window-at-init.md:288                             bin/keel:290             blank
docs/stories/profile-sync.md:260                                       bin/keel:1019-1020       blank
docs/stories/tiered-multi-harness-support.md:152                       bin/keel:1999            past the end
docs/stories/usable-profile.md:453                                     bin/keel:290             blank
```

**How to repair one, in order.** These are dated records, so the pointer is repaired and the
sentence is not touched.

1. Find what the citation named when it was written:

   ```bash
   git log -1 --format=%H --before="<the document's own date>" -- bin/keel
   git show <that sha>:bin/keel | sed -n '<the cited line>p'
   ```

2. Find that content in today's file: `grep -n '<a distinctive part>' bin/keel`.
3. Write the citation as `` `<path>#<phrase>` ``, using task 1's form, with a phrase that is
   unique (`grep -cF '<phrase>' bin/keel` prints 1) and contains no backtick and no pipe.
4. **Where the content is gone, or where the sentence turns out to name something the cited line
   never held, do not invent a pointer.** Record it in the findings section at the foot of this plan,
   with the document, the citation and what the sentence appears to mean, and remove the citation
   from the sentence rather than pointing it somewhere plausible. Five for five is this branch's
   measured rate for citations examined closely, so expect several.

Then run `tests/validate-citations.sh` again. Expected: `OK`, with a count above 1,100, which is the
954 already checked plus the extensionless ones now visible, minus nothing.

Then `tests/run-tests.sh`, green, and the lint command, clean.

- [x] **Step 5: Hand over**

```bash
git add tests/validate-citations.sh tests/test-validate-citations.sh \
        docs/architecture/tiered-multi-harness-support.md docs/ideas/keel-on-codex.md \
        docs/ideas/leon-van-zyl-skill-collection.md docs/ideas/profile-schema-drift.md \
        docs/plans/ docs/prd/ docs/stories/
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "feat(citations): 420 citations into extensionless files were never checked"`.
Paste the `git status --porcelain` output into your report; if it lists a document not in the table
above, say so and leave it unstaged.

---

### Task 3: A phrase form for `x-keel-read-by`

**Traces to:** open question 0a of the previous plan, which records that the ten `unread:` markers
cite a line number that can never go red, and that the grammar has no phrase form to offer.

**Files:**
- Modify: `tests/validate-skills.sh` (the `x-keel-read-by` rule and its report message)
- Modify: `CONTRIBUTING.md` (the bullet stating the grammar)
- Test: `tests/test-validate-skills.sh`

**Interfaces:**
- Consumes: nothing. This grammar is checked by `tests/validate-skills.sh` alone, because
  `tests/validate-citations.sh` does not scan `templates/`.
- Produces: `<code|advisory|unread>:<path>#<phrase>` alongside the existing
  `<code|advisory|unread>:<path>:<line>`. Task 4 adds a fourth prefix and task 5 writes the markers.

**Depends on:** none

**Done when:** `tests/test-validate-skills.sh` passes and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

Add to `tests/test-validate-skills.sh`, beside the other schema cases:

```bash
# The phrase form for a marker. The ten unread: markers cite a line in a table of 22 contiguous
# rows, so an insertion above them retargets a citation onto a neighbouring key's row and nothing
# goes red. A phrase is what that rule was missing.
m_readby_phrase_ok() {
    mkdir -p "$1/templates" "$1/bin"
    printf 'SCHEMA_VERSION=1\n' > "$1/bin/keel"
    cat > "$1/templates/profile.schema.json" <<'JSON'
{ "properties": { "a": { "description": "d", "x-keel-read-by": "code:bin/keel#SCHEMA_VERSION=1" } } }
JSON
}
run_out "a marker citing a phrase that is in the file is accepted" 1 m_readby_phrase_ok "x-keel-read-by" no

m_readby_phrase_gone() {
    mkdir -p "$1/templates" "$1/bin"
    printf 'SCHEMA_VERSION=1\n' > "$1/bin/keel"
    cat > "$1/templates/profile.schema.json" <<'JSON'
{ "properties": { "a": { "description": "d", "x-keel-read-by": "code:bin/keel#SCHEMA_VERSION=9" } } }
JSON
}
run_out "a marker citing a phrase that is not in the file is rejected" 1 m_readby_phrase_gone \
    "x-keel-read-by" yes

# A phrase carrying a pipe would break the markdown table docs/profile-keys.md renders it into.
m_readby_phrase_pipe() {
    mkdir -p "$1/templates" "$1/bin"
    printf 'SCHEMA_VERSION=1\n' > "$1/bin/keel"
    cat > "$1/templates/profile.schema.json" <<'JSON'
{ "properties": { "a": { "description": "d", "x-keel-read-by": "code:bin/keel#SCHEMA|VERSION" } } }
JSON
}
run_out "a marker phrase containing a pipe is rejected" 1 m_readby_phrase_pipe "x-keel-read-by" yes
```

The expected exit is 1 in all three because these fixtures also trip the schema fingerprint rule.
The needle, and whether it must be present or absent, is what each case is really asserting.

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-validate-skills.sh`

Expected: FAIL on "a marker citing a phrase that is in the file is accepted", because the current
grammar rejects it as unreadable and the needle `x-keel-read-by` appears. The other two pass for the
wrong reason today, and step 4 is where they start asserting something.

- [x] **Step 3: Write the minimal implementation**

In `tests/validate-skills.sh`, replace the `form` regex and the checks that follow it:

```python
form = re.compile(r"^(code|advisory|unread):([^:#]+)(?::([0-9]+)|#([^`|]+))$")
```

and replace the body of the `for e in entries:` loop from `f, line = m.group(2), int(m.group(3))`
onward with:

```python
        f, line, phrase = m.group(2), m.group(3), m.group(4)
        if m.group(1) == "advisory" and not f.endswith(".md"):
            problems.append("%s uses advisory: for %s, which is not a markdown file. advisory: is for prose a model may follow; use code: for something that executes." % (path, e))
        if m.group(1) == "code" and f.endswith(".md"):
            problems.append("%s uses code: for %s, which is a markdown file. Prose nothing asserts is advisory:, not code:." % (path, e))
        if not os.path.isfile(f):
            problems.append("%s names %s and that file does not exist" % (path, e))
            continue
        body = open(f, encoding="utf-8", errors="replace").read()
        # A phrase, matched literally anywhere in the file. It is the form to prefer for a file that
        # changes often: bin/keel took 47 lines in one commit on the branch that added this and
        # moved 32 citations that were correct before it. A line number is still legal, because a
        # phrase into a file of near-identical lines is worse, and the caller knows which it has.
        if phrase is not None:
            if phrase not in body:
                problems.append("%s names %s and that text is not in %s" % (path, e, f))
            continue
        lines = body.splitlines()
        line = int(line)
        # Line 0 gets its own sentence. Folded into the range test it reported that a one-line
        # file has 1 lines, which reads as a contradiction and is the same needle the stale-line
        # case asserts, so from the message alone the two faults were indistinguishable and a test
        # pinning one was silently pinning both.
        if line < 1:
            problems.append("%s names %s, and line numbers start at 1" % (path, e))
        elif line > len(lines):
            problems.append("%s names %s and that file has %d lines" % (path, e, len(lines)))
        elif not lines[line - 1].strip():
            problems.append("%s names %s and that line is blank" % (path, e))
```

The regex excludes a backtick and a pipe from the phrase, so a marker carrying either falls through
to the "unreadable entry" branch above. Update that branch's message and the rule's report message
to state the whole grammar:

```python
            problems.append("%s has an unreadable x-keel-read-by entry %r, "
                            "not human and not <code|advisory|unread>:<path> followed by "
                            ":<line> or #<phrase>, where a phrase carries no backtick and no pipe"
                            % (path, e))
```

```bash
      || report "templates/profile.schema.json has an x-keel-read-by problem: $readby. Every key states what reads it: code:<path> or advisory:<path> where something does, human where a person is the reader, unread:<path> naming the record that decided nothing reads it. The path is followed by :<line> or, for a file that changes often, #<phrase>."
```

Then update the `x-keel-read-by` bullet in `CONTRIBUTING.md` to state both forms and say when to
prefer the phrase: any citation into `bin/keel`, `tests/validate-skills.sh` or `tests/test-keel.sh`.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-validate-skills.sh`
Expected: PASS on all three new cases.

Run: `tests/validate-skills.sh`. Expected: `OK`, unchanged, because every existing marker still uses
the line form and that form still works.

Then `tests/run-tests.sh`, green, and the lint command, clean.

- [x] **Step 5: Hand over**

```bash
git add tests/validate-skills.sh tests/test-validate-skills.sh CONTRIBUTING.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "feat(schema): a marker may cite a phrase, not only a line"`.

---

### Task 4: `observed:`, a fifth value, for a key a model reads unprompted

**Traces to:** open question 0 of the previous plan, and Bernard's decision of 2026-09-09.

**Files:**
- Modify: `tests/validate-skills.sh` (the `form` regex and the `.md` rule)
- Modify: `tests/generate-profile-keys.sh` (the `read_by` renderer)
- Modify: `templates/profile.schema.json` (`gates.coding_standards`)
- Modify: `docs/profile-keys.md` (**generated**, regenerate it)
- Modify: `CONTRIBUTING.md`, `CHANGELOG.md`
- Test: `tests/test-validate-skills.sh`, `tests/test-profile-keys.sh`

**Interfaces:**
- Consumes: the phrase form from task 3. `gates.coding_standards` is marked with a phrase, not a
  line, because `tests/evals/results.md` is prepended to and moved 479 lines in one day on
  2026-09-07.
- Produces: `observed:<path>#<phrase>`, a fifth marker value.

**Depends on:** task 3

**Done when:** `tests/test-validate-skills.sh` and `tests/test-profile-keys.sh` pass, and
`tests/run-tests.sh` is green.

**Why a fifth value and not `advisory:`.** `advisory:` means prose a model may follow and nothing
asserts. The evidence here is the opposite direction: `tests/evals/results.md` records an arm titled
"`gates.coding_standards`, read by nothing and acted on anyway", an agent reading the key out of the
profile and setting severity by it with no prose telling it to. Marking that `advisory:` would file
a measurement under a value that means the absence of one. `unread:`, which it carries today, is
false on this repository's own evidence.

- [x] **Step 1: Write the failing test**

Add to `tests/test-validate-skills.sh`:

```bash
# The fifth value. A key nothing is written to read, that a model was measured reading anyway. Its
# citation names the record that measured it, so the claim is checkable rather than remembered.
m_readby_observed() {
    mkdir -p "$1/templates" "$1/bin" "$1/tests/evals"
    printf 'SCHEMA_VERSION=1\n' > "$1/bin/keel"
    printf '# Results\n\nAn arm read the key and acted on it anyway.\n' > "$1/tests/evals/results.md"
    cat > "$1/templates/profile.schema.json" <<'JSON'
{ "properties": { "a": { "description": "d", "x-keel-read-by": "observed:tests/evals/results.md#read the key and acted on it anyway" } } }
JSON
}
run_out "an observed: marker citing the record that measured it is accepted" 1 m_readby_observed \
    "x-keel-read-by" no

# observed: names a record, so it names a document. A path into code would be code:.
m_readby_observed_code() {
    mkdir -p "$1/templates" "$1/bin"
    printf 'SCHEMA_VERSION=1\n' > "$1/bin/keel"
    cat > "$1/templates/profile.schema.json" <<'JSON'
{ "properties": { "a": { "description": "d", "x-keel-read-by": "observed:bin/keel#SCHEMA_VERSION=1" } } }
JSON
}
run_out "an observed: marker naming a file that is not a record is rejected" 1 \
    m_readby_observed_code "x-keel-read-by" yes
```

And add to `tests/test-profile-keys.sh` a case asserting the generated page renders the fifth value,
following the shape of the cases already there:

```bash
# The reference page has to say what observed: means, or a reader meets a fifth phrasing with no
# explanation and reads it as a synonym for one of the four.
grep -q 'a model, unprompted' "$work/a.md" \
  && ok "the generated page renders an observed: marker" \
  || bad "observed:" "the page does not render the fifth value"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-validate-skills.sh` then `tests/test-profile-keys.sh`

Expected: FAIL on "an observed: marker citing the record that measured it is accepted", because
`observed` is not in the grammar and the needle appears. FAIL on the generated-page case, because
nothing renders it.

- [x] **Step 3: Write the minimal implementation**

In `tests/validate-skills.sh`:

```python
form = re.compile(r"^(code|advisory|unread|observed):([^:#]+)(?::([0-9]+)|#([^`|]+))$")
```

and beside the `advisory` file-type rule:

```python
        if m.group(1) == "observed" and not f.endswith(".md"):
            problems.append("%s uses observed: for %s, which is not a markdown file. observed: names the record that measured a model reading the key; a path into code is code:." % (path, e))
```

In `tests/generate-profile-keys.sh`, in `read_by`, before the `advisory:` branch:

```python
        elif one.startswith("observed:"):
            out.append("a model, unprompted, see `%s`" % one.split(":", 1)[1])
```

In `templates/profile.schema.json`, change `gates.coding_standards`:

```json
"x-keel-read-by": "observed:tests/evals/results.md#read by nothing and acted on anyway"
```

and correct its description, which today tells a reader nothing reads the key.

Then regenerate: `tests/generate-profile-keys.sh > docs/profile-keys.md`.

Add the fifth value to `CONTRIBUTING.md`'s grammar bullet, and an entry to `CHANGELOG.md` under
`## Unreleased` recording that the marker set is five, what `observed:` means, and that
`gates.coding_standards` is its first user because this repository measured the behaviour and then
described it as absent for two days.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-validate-skills.sh`, then `tests/test-profile-keys.sh`
Expected: PASS on all three new cases.

Run: `tests/validate-skills.sh`. Expected: `OK`. Then `tests/run-tests.sh`, green, and the lint
command, clean.

- [x] **Step 5: Hand over**

```bash
git add tests/validate-skills.sh tests/generate-profile-keys.sh templates/profile.schema.json \
        docs/profile-keys.md CONTRIBUTING.md CHANGELOG.md \
        tests/test-validate-skills.sh tests/test-profile-keys.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "feat(schema): observed:, for a key a model was measured reading unprompted"`.

---

### Task 5: Convert the live set to phrases

**Traces to:** Bernard's decision of 2026-09-09, and the branch's measurement that a line number
into `bin/keel` has a half-life of about one task.

**Files:**
- Modify: `templates/profile.schema.json` (25 markers)
- Modify: `docs/profile-keys.md` (**generated**, regenerate it)
- Modify: `hooks/sensitive-guard` (2), `tests/test-keel.sh` (6), `tests/test-validate-skills.sh` (2),
  `tests/test-cache-install.sh` (1), `tests/test-harness-resolve.sh` (1),
  `skills/execute-plan/references/preconditions.md` (1)

**Interfaces:**
- Consumes: the phrase forms from tasks 1 and 3.
- Produces: a tree in which every live document cites a hot file by phrase, which is the
  precondition task 6 enforces.

**Depends on:** tasks 1 and 3

**Done when:** `tests/validate-citations.sh` and `tests/validate-skills.sh` both report `OK`,
`tests/test-profile-keys.sh` passes, and `tests/run-tests.sh` is green.

**The 38 citations, measured on 2026-09-09.** The 25 markers are every `x-keel-read-by` in
`templates/profile.schema.json` naming `bin/keel`. The 13 below are the rest of the live set:

Fenced, for the same reason task 2's table is: an unfenced list of citations is a list of
claims, and these name lines that are about to move.

```
hooks/sensitive-guard:13                             bin/keel:581                           merge_profile .keel/profile.json.new .keel/profile.json
hooks/sensitive-guard:31                             bin/keel:598                           # A null command is omitted rather than rendered as the word "null".
skills/execute-plan/references/preconditions.md:44   bin/keel:1346-1348                     the managed block size comment
tests/test-cache-install.sh:28                       bin/keel:35                            the `SCHEMA_VERSION` comment, "field is added, removed, renamed or moved"
tests/test-harness-resolve.sh:5                      tests/test-keel.sh:10                  # shellcheck disable=SC2015
tests/test-keel.sh:1850                              bin/keel:78                            # shellcheck source=lib/merge-claude-md.sh
tests/test-keel.sh:1867                              bin/keel:1358                          fi
tests/test-keel.sh:2054                              bin/keel:1413                          the `--fast` verify line
tests/test-keel.sh:4551                              bin/keel:100-101                       the harness_each rule comment
tests/test-keel.sh:4567                              tests/validate-skills.sh:656-662       a comment block
tests/test-keel.sh:4571                              bin/keel:556                           the observability `printf
tests/test-validate-skills.sh:840                    tests/validate-skills.sh:592           "rule rather than break it. Found in review"
tests/test-validate-skills.sh:842                    tests/validate-skills.sh:475           "Ten pairs on 2026-09-02"
```

**`tests/test-keel.sh:1867` cites `fi`, which names nothing.** Do not convert it to the phrase `fi`.
Read the sentence, find the line it means, and cite that. If the sentence names something that is
gone, remove the citation and record it in the findings section.

- [x] **Step 1: There is no new test for this**

This task writes no behaviour. The tests that gate it exist already and are what make the conversion
checkable: `tests/validate-citations.sh` proves every converted prose and comment citation resolves,
`tests/validate-skills.sh` proves every converted marker resolves, and `tests/test-profile-keys.sh`
proves the generated page still matches its generator. A new test here would assert that a
particular phrase was chosen, which is not a behaviour and would have to be rewritten by the next
person who edits the line.

- [x] **Step 2: Convert, one citation at a time**

For each of the 38, in order:

1. Read the cited line and the sentence that cites it. **They frequently disagree**, and this branch
   measured five for five when it looked.
2. Choose a phrase from the line the sentence actually means. It must be unique
   (`grep -cF '<phrase>' <file>` prints 1) and contain no backtick and no pipe.
3. Write it as `` `<path>#<phrase>` `` in prose and comments, or `code:<path>#<phrase>` in a marker.
4. Where the sentence names content that no longer exists, remove the citation rather than pointing
   it somewhere plausible, and record it in the findings section at the foot of this plan.

Then regenerate the reference page, because 25 of the 38 are markers it renders:

```bash
tests/generate-profile-keys.sh > docs/profile-keys.md
```

- [x] **Step 3: Check it**

Run: `tests/validate-citations.sh`. Expected: `OK`.
Run: `tests/validate-skills.sh`. Expected: `OK`.
Run: `tests/test-profile-keys.sh`. Expected: all pass.
Run: `tests/run-tests.sh`. Expected: green. Then the lint command, clean.

**Then prove the conversion did something**, which no test above can: insert a line at the top of
`bin/keel`'s body, run `tests/validate-skills.sh`, and confirm it still reports `OK` where before
the conversion the same insertion would have moved all 25 markers onto the wrong lines in silence.
Undo the insertion. Report both runs.

- [x] **Step 4: Hand over**

```bash
git add templates/profile.schema.json docs/profile-keys.md hooks/sensitive-guard \
        tests/test-keel.sh tests/test-validate-skills.sh tests/test-cache-install.sh \
        tests/test-harness-resolve.sh skills/execute-plan/references/preconditions.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "docs: the live set cites bin/keel by phrase, not by line"`.

---

### Task 6: A line number into a file that changes often is a finding

**Traces to:** open question 0c, which asks whether the checker should require a phrase for a
citation into a file that changes often rather than accepting a line number and hoping.

**Files:**
- Modify: `tests/validate-citations.sh`
- Test: `tests/test-validate-citations.sh`

**Interfaces:**
- Consumes: the phrase form from task 1 and the conversion from task 5. Without the conversion this
  rule fires on 38 citations in the tree and the suite cannot go green.
- Produces: nothing further.

**Depends on:** tasks 2 and 5

**Done when:** `tests/test-validate-citations.sh` passes, `tests/validate-citations.sh` reports `OK`
against this repository, and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

```bash
# A line number into a file that changes often. bin/keel took 47 lines in one commit on the branch
# that added this rule, and 32 citations that were correct before it were not afterwards. The rule
# applies to documents that say what is true now, and not to the records that say what was true on
# a date: repairing a pointer inside a record is allowed, and rewriting its claims is not, so a rule
# that failed the build over one would be asking for the forbidden repair.
m_hot_line_in_live_doc() {
    mkdir -p "$1/bin"
    printf '#!/usr/bin/env bash\n# A comment.\necho hi\n' > "$1/bin/keel"
    printf 'The CLI does it at `bin/keel:2`.\n' >> "$1/README.md"
}
run_out "a line-number citation into bin/keel from a live document is rejected" 1 \
    m_hot_line_in_live_doc "changes often" yes

m_hot_line_in_dated_record() {
    mkdir -p "$1/bin" "$1/docs/plans"
    printf '#!/usr/bin/env bash\n# A comment.\necho hi\n' > "$1/bin/keel"
    printf '# A plan\n\nThe CLI did it at `bin/keel:2` on 2026-09-01.\n' > "$1/docs/plans/a.md"
}
run_out "a line-number citation into bin/keel from a dated record is left alone" 0 \
    m_hot_line_in_dated_record "changes often" no

m_hot_phrase_in_live_doc() {
    mkdir -p "$1/bin"
    printf '#!/usr/bin/env bash\n# A comment.\necho hi\n' > "$1/bin/keel"
    printf 'The CLI does it at `bin/keel#A comment.`.\n' >> "$1/README.md"
}
run_out "a phrase citation into bin/keel from a live document is accepted" 0 \
    m_hot_phrase_in_live_doc "changes often" no
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-validate-citations.sh`
Expected: FAIL on "a line-number citation into bin/keel from a live document is rejected" (expected
exit 1, got 0). The other two pass already and must still pass in step 4.

- [x] **Step 3: Write the minimal implementation**

In the resolution loop of `tests/validate-citations.sh`, after `target` is resolved and before the
record is appended:

```bash
    # A file that changes often, cited by line, from a document that says what is true now. These
    # three take insertions in most weeks: bin/keel took 47 lines in one commit on the branch that
    # added this rule. The list is written out rather than derived from git history, because a rule
    # whose membership changes when someone commits is one nobody can predict.
    case "$target" in
        bin/keel|tests/validate-skills.sh|tests/test-keel.sh)
            case "$citing" in
                # Records. Each says when it was written, and its date is what tells a reader how
                # far to trust its line numbers. Repairing a pointer in one is allowed and rewriting
                # its claims is not, so requiring a phrase here would be asking for the second.
                docs/plans/*|docs/prd/*|docs/stories/*|docs/architecture/*|docs/decisions/*| \
                docs/audits/*|docs/ideas/*|docs/07-open-decisions.md|docs/harness-support.md| \
                tests/evals/*|CHANGELOG.md) ;;
                *) report "$citing:$cline cites \`$cit\`, and $target changes often enough that a line number there is stale within about one task. Cite a phrase instead: \`$target#<text from the line>\`." ;;
            esac
            ;;
    esac
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-validate-citations.sh`
Expected: PASS on all three new cases.

Run: `tests/validate-citations.sh`. Expected: `OK`, with no finding, because task 5 converted every
live citation into those three files.

Then `tests/run-tests.sh`, green, and the lint command, clean.

- [x] **Step 5: Hand over**

```bash
git add tests/validate-citations.sh tests/test-validate-citations.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "feat(citations): a hot file is cited by phrase, or the check says so"`.

---

### Task 7: Two sentences that cite correctly and say something false

**Traces to:** open question 3a of the previous plan.

**Files:**
- Modify: `docs/prd/plain-language-chat.md` (the NFR-02 evidence cell)
- Modify: `docs/stories/plain-language-chat.md` (the Notes under the last scenario of E-03)
- Test: `tests/test-doc-claims.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

**Depends on:** none

**Done when:** `tests/test-doc-claims.sh` passes and `tests/run-tests.sh` is green.

**What is false.** Both documents say the size check runs `hooks/session-start` "once from the
repository root", so it measures `terse` plus `technical` and nothing else. `tests/validate-skills.sh`
has since been changed to loop over all four combinations of `response_style` and `explain_level` in
a `mktemp` probe directory, writing a profile for each. The PRD's cell is worse than stale: NFR-02
requires the check to cover every combination, its status says `confirmed`, and its evidence
describes the check failing to do exactly that.

- [x] **Step 1: Write the failing test**

Add to `tests/test-doc-claims.sh`, following the shape of the claims already there:

```bash
# NFR-02 of the plain-language PRD requires the size check to cover every combination of
# response_style and explain_level, and its evidence cell described the check measuring one. The
# claim and the code are both checkable, so both are checked here: a cell that goes back to naming
# one combination, or a validator that goes back to measuring one, fails this.
combos="$(grep -c 'for combo in "terse technical" "terse plain" "verbose technical" "verbose plain"' \
  tests/validate-skills.sh)"
[ "$combos" -eq 1 ] \
  && ok "validate-skills.sh loops over all four style combinations" \
  || bad "NFR-02" "the four-combination loop is not in tests/validate-skills.sh"

grep -q 'all four combinations' docs/prd/plain-language-chat.md \
  && ok "the PRD's NFR-02 evidence names all four combinations" \
  || bad "NFR-02" "docs/prd/plain-language-chat.md still describes a check that measures one"

grep -q 'once from the repository root' docs/stories/plain-language-chat.md \
  && bad "NFR-02" "docs/stories/plain-language-chat.md still says the check runs the hook once from the repository root" \
  || ok "the story no longer describes a check that measures one combination"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-doc-claims.sh`

Expected: PASS on the first (the loop is already there), FAIL on the second and third, naming both
documents.

- [x] **Step 3: Write the minimal implementation**

Rewrite the NFR-02 evidence cell in `docs/prd/plain-language-chat.md` to say what the check does
now: it writes a profile for each of the four combinations of `response_style` and `explain_level`
into a `mktemp` probe directory and runs the hook in each, so all four are measured. Keep the
original sentence in the cell, marked with the date it stopped being true, the way NFR-01 and NFR-03
in the same table already keep their superseded wording. Do the same in the story's Notes.

Neither sentence is a claim about a line number, so neither needs a citation change.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-doc-claims.sh`. Expected: all three pass.
Then `tests/run-tests.sh`, green, and the lint command, clean.

- [x] **Step 5: Hand over**

```bash
git add docs/prd/plain-language-chat.md docs/stories/plain-language-chat.md tests/test-doc-claims.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "docs: NFR-02's evidence described the check it requires failing"`.

---

### Task 8: This repository's own profile

**Traces to:** "What this plan does not touch" in the previous plan, and the retirement register it
shipped, which now warns four times on this repository.

**Files:**
- Modify: `.keel/profile.json`
- Test: `tests/test-doc-claims.sh`

**Interfaces:**
- Consumes: `retired_keys` and the doctor rule from the previous plan.
- Produces: a dogfood profile that passes the checks this repository ships.

**Depends on:** none

**Done when:** `tests/test-doc-claims.sh` passes, `keel doctor` prints no retirement warning and no
schema drift warning, and `tests/run-tests.sh` is green.

**What is wrong with it, measured 2026-09-09.** `keel_version` says `0.15.0` against a `VERSION` of
`0.18.0`. `schema_version` says 2 against a `SCHEMA_VERSION` of 4. It sets `gates.tdd`,
`gates.review`, `gates.observability` and `gates.docs_updated`, all retired in schema 4, plus
`observability.log_shipping`, also retired. It carries hand-written keys the schema does not
declare, `_note`, `deploy.note`, `artifacts._note` and `conventions.no_attribution_footers`, and
those stay: `additionalProperties` is true on purpose and the retirement register is a list, not a
diff, so nothing warns about them.

- [x] **Step 1: Write the failing test**

Add to `tests/test-doc-claims.sh`:

```bash
# keel dogfoods itself, so this repository's own profile is the first thing a keel change is tested
# against, and it has been two schema versions behind since 0.16.0. The retirement register shipped
# on this branch made that visible: doctor prints four warnings in this tree, on keys this
# repository retired itself.
own_sv="$(python3 -c "import json;print(json.load(open('.keel/profile.json'))['schema_version'])")"
bin_sv="$(sed -n 's/^SCHEMA_VERSION=\([0-9][0-9]*\)$/\1/p' bin/keel)"
[ "$own_sv" = "$bin_sv" ] \
  && ok "this repository's own profile is at the schema version bin/keel expects" \
  || bad "dogfood profile" "profile says schema $own_sv, bin/keel says $bin_sv"

retired_in_own="$(python3 - <<'PY'
import json, re, subprocess
src = open("bin/keel").read()
block = re.search(r"^retired_keys\(\) \{(.*?)^\}", src, re.S | re.M)
keys = [l.strip().split("|")[0] for l in block.group(1).splitlines() if l.count("|") >= 2]
prof = json.load(open(".keel/profile.json"))
def has(p):
    d = prof
    for seg in p.split("."):
        if not isinstance(d, dict) or seg not in d:
            return False
        d = d[seg]
    return True
print(" ".join(k for k in keys if has(k)))
PY
)"
[ -z "$retired_in_own" ] \
  && ok "this repository's own profile sets no retired key" \
  || bad "dogfood profile" "it still sets: $retired_in_own"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-doc-claims.sh`

Expected: FAIL on both, the first naming schema 2 against 4, the second listing `gates.tdd`,
`gates.review`, `gates.observability`, `gates.docs_updated` and `observability.log_shipping`.

- [x] **Step 3: Write the minimal implementation**

Edit `.keel/profile.json` by hand rather than running `keel init`. Init merges, so it would bump
`schema_version` to 4 and leave every retired key in place, which is the exact failure the previous
plan's open question 3 recorded and this branch's register now reports.

- `keel_version` to `0.18.0`, `schema_version` to `4`.
- Delete `gates.tdd`, `gates.review`, `gates.observability`, `gates.docs_updated` and
  `observability.log_shipping`.
- Change the `_note` at the foot, which says the file is written by hand "until `keel init` exists
  (plan task 1.6)". Init exists. Say instead that the file is maintained by hand, and why: it
  carries keys and notes init does not write.

Leave everything else, including `gates.context_window: 1000000` and the `verify_notes`.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-doc-claims.sh`. Expected: both new cases pass.

Run: `bin/keel doctor`. Expected: `ok profile is at schema version 4, which this keel expects`, and
**no** line containing `retired in schema`. Paste both lines into your report.

Then `tests/run-tests.sh`, green, and the lint command, clean.

- [x] **Step 5: Hand over**

```bash
git add .keel/profile.json tests/test-doc-claims.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "fix(profile): keel's own profile was two schema versions behind"`.

---

### Task 9: The no-python case measures a race, not the hook

**Traces to:** the CI failure on PR 62, 2026-09-09, and the same case's earlier failure recorded in
its own comment.

**Files:**
- Modify: `tests/test-context-watch.sh`
- Test: `tests/test-context-watch.sh` is its own test file.

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

**Depends on:** none

**Done when:** `tests/test-context-watch.sh` passes and `tests/run-tests.sh` is green.

**The diagnosis, and it is not a mystery any more.** The case is written as

```bash
out="$(printf '{...}' | PATH="$work/empty" "$bash_bin" "$HOOK" 2>"$work/no-python.err")"; rc=$?
```

`hooks/context-watch` exits at its `command -v python3 ... || exit 0` line **before it reads stdin**,
which is the behaviour under test. The reader is therefore gone while `printf` is still writing, so
`printf` gets EPIPE or SIGPIPE, and `tests/test-context-watch.sh` runs `set -o pipefail`, which
makes the pipeline's status the writer's. Reproduced on 2026-09-09:

```
set -uo pipefail; printf <200KB> | bash -c "exit 0"            rc=141
set -uo pipefail; trap "" PIPE; printf <200KB> | bash -c "exit 0"   rc=1
```

`rc=1` with empty stdout is exactly what CI reported. **The remedy added after the first occurrence
could never have seen it**: it captures the hook's stderr into `no-python.err`, and the message
belongs to the test's own `printf`, on the test's stderr. That is why the failure report said
`err=` with nothing after it.

The hook is not at fault and must not change. Every path out of it is an explicit `exit 0`, which is
what the case exists to prove.

- [x] **Step 1: Write the failing test**

Add above the existing case, so the race is asserted rather than assumed:

```bash
# The shape of the case below, reduced to its mechanism. A reader that exits before reading makes
# the writer fail, and pipefail hands the pipeline the writer's status, so a test asserting rc of
# the pipeline is asserting the race and not the hook. 200000 characters rather than the event's
# 200, because the flake needs the writer to still be writing when the reader goes and a small
# payload usually beats it: this makes the race certain instead of occasional.
big="$(printf 'x%.0s' $(seq 1 200000))"
out="$(printf '%s' "$big" | PATH="$work/empty" "$bash_bin" "$HOOK" 2>/dev/null)"; rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] \
  && ok "the exit status belongs to the hook, not to the writer feeding it" \
  || bad "no python" "rc=$rc, which is the writer's status: the hook exits before reading stdin, and pipefail promotes the EPIPE"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-context-watch.sh`

Expected: FAIL on "the exit status belongs to the hook, not to the writer feeding it", with `rc=141`
on a machine where SIGPIPE is default, or `rc=1` where it is ignored. That is the CI failure,
reproduced locally and on demand.

- [x] **Step 3: Write the minimal implementation**

Feed the event from a file. There is no pipeline, so there is no race and no writer whose status can
be mistaken for the hook's. Replace both the new case and the existing one:

```bash
# Fed from a file, not through a pipe. The hook exits before reading stdin when python3 is absent,
# which is the behaviour under test, so a pipe leaves printf writing to a reader that has gone: it
# takes EPIPE, and this file's `set -o pipefail` hands the pipeline the writer's status. That is
# rc=141 where SIGPIPE is default and rc=1 where it is ignored, and rc=1 with empty output is what
# CI reported on 2026-09-09 and once before. The remedy added after the first occurrence, keeping
# the hook's stderr, could not see it: the message belongs to this file's own printf.
printf '{"hook_event_name":"UserPromptSubmit","transcript_path":"%s","cwd":"%s","session_id":"s-np","tool_name":"Bash"}' \
  "$work/e2e.jsonl" "$work" > "$work/no-python.json"
out="$(PATH="$work/empty" "$bash_bin" "$HOOK" < "$work/no-python.json" 2>"$work/no-python.err")"; rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "the watchdog is silent and exits 0 when python3 is absent" \
  || bad "no python" "rc=$rc out=$out err=$(head -3 "$work/no-python.err")"
```

Keep the paragraph above it explaining why PATH is emptied and why bash is resolved absolutely.
Replace the paragraph about keeping stderr with the diagnosis, since the fault it was written for is
now known and fixed.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-context-watch.sh`. Expected: PASS, including a hundred consecutive runs of that one
case if you want certainty:

```bash
for i in $(seq 1 100); do tests/test-context-watch.sh >/dev/null 2>&1 || echo "failed on run $i"; done
```

Expected: no output. Then `tests/run-tests.sh`, green, and the lint command, clean.

- [x] **Step 5: Hand over**

```bash
git add tests/test-context-watch.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "fix(tests): the no-python case asserted a race between printf and the hook"`.

---

## Findings this plan expects to produce

Tasks 2 and 5 both read citations closely, and this branch's measured rate for that is five for
five wrong. **Record each one here as you find it**, with the document, the citation, and what the
sentence appears to mean. A finding recorded is a task somebody can pick up; a finding fixed
silently inside a conversion is one nobody can audit.

**Task 2, the count: 954 checked citations became 1,443.** The extensionless alternative brought in
351 citations into `bin/keel` and 69 into `hooks/*`, and it also brought in every citation into a
`.py` file, because `py` was never in the extension list either: `lib/context_watch.py` alone is
cited about 60 times across nine documents. The omission was not only extensionless files.

**Task 2 found six citations the new rule was wrong to report, and the rule was narrowed for them.**
Three are a shorthand that names a numbered document, `docs/03:177` and two more in the same
sentence of `docs/plans/2026-08-18-plsql-stack-detection.md`, and three quote a validator fixture
called `bin/reader` that exists only inside a temp tree. Both shapes are extensionless paths that do
not resolve, and reporting them as renamed files is the too-strict failure `CONTRIBUTING.md` calls
unrecoverable. The rule now reports a missing file only where the path carries an extension: one
that resolves is still checked in full, which is the whole value, and one that does not is shorthand
rather than a rename. A must-not-reject case pins both shapes.

**Task 2, the repairs: four citations named code that no longer exists, and one was wrong the day it
was written.** Line 1207 of `bin/keel`, cited in three documents, named the `[ "$pv" != "$iv" ]` comparison doctor
used to make on `keel_version`, which the schema-version work replaced with a three-way comparison,
so the pointer is removed and the code is quoted in the sentence instead.
`docs/ideas/keel-on-codex.md` named the permission rules at lines 576 to 590 of `bin/keel`, which the harness
refactor moved to `lib/harness/claude.sh`, so the row now says both, with the date implied by the
record. And `docs/prd/context-window-at-init.md`'s FR-06 cited lines 385 to 389 of `bin/keel` for `--force`
replacing the profile: **git blame says line 385 was blank in the very commit that wrote the
citation.** That is the sixth citation this branch has examined closely and the sixth that was
already wrong, and the first where the wrongness predates every insertion.

**Task 3: a backtick in that rule's regex broke the whole validator, and the reason is documented
elsewhere in this repository.** The `x-keel-read-by` rule runs python from a heredoc inside a
`$( )`, and bash 3.2 does not treat a quoted heredoc body as literal there. A literal backtick in
the character class opened a command substitution that swallowed the rest of the file: 77 of 86
cases failed at once, with the parse error reported a hundred lines from the edit.
`bin/keel`'s `json_load` carries the same warning for the apostrophe, in a comment that says
shellcheck cannot see it either. The regex now writes the backtick as `\x60`, with that comment
beside it.

**Task 5, the experiment, and it answers two questions at once.** With the 25 markers converted, one
line inserted near the top of `bin/keel` leaves `tests/validate-skills.sh` reporting `OK`: before the
conversion the same insertion moved all 25 markers onto the wrong lines and reported `OK` anyway.
The same insertion makes `tests/validate-citations.sh` report **14 stale citations**, all in dated
records citing `bin/keel` by line. Both numbers are the design working. The second is also a bill:
**an insertion into `bin/keel` now breaks the build until the dated records' pointers are repaired**,
where before this branch it broke nothing and nobody knew. The repair is mechanical, blame the
citing line and shift, and it is now visible rather than silent. Whether that tax is worth paying on
every `bin/keel` edit, or whether dated records should be exempt from the blank-line rule as well as
from the phrase rule, is open question 3 below.

**Task 5 found two more citations that were wrong, which makes it eight for eight.** `hooks/sensitive-guard`
cited `bin/keel` twice, once for "bypassPermissions, which ... records as verified against a live
session" and once for "permission deny rules ... already warn". Both had pointed at unrelated lines,
and both subjects had moved to `lib/harness/claude.sh` in the harness refactor. The hook is live
code, so both now cite that file by phrase. And `gates.project_kind`'s marker names one of two
readers of `project.kind`: the pipe that distinguishes them cannot appear in a phrase, so the phrase
is the fallback that follows it. That is evidence for open question 0b of the previous plan, which
asked whether a marker lists every reader or one.

**Task 6: the ninth citation examined and the ninth wrong, and this plan predicted this one.**
`tests/test-keel.sh` said "writing an absent path would convert a silent gap into a hard doctor
failure" and pointed at a bare `fi` closing doctor's docs-kind block. The failure it means is the
artifact-existence check two lines below, which the citation now names by phrase. The plan wrote
"do not convert it to the phrase `fi`" because a bare brace is what a citation pointing at nothing
looks like.

**Task 6's own tests asserted nothing on their first draft.** They were written with `run_out`,
which `tests/test-validate-skills.sh` has and `tests/test-validate-citations.sh` does not, so the
three cases printed "command not found" to stderr and were never counted: the file reported the same
28 passes before and after. Caught by the count not moving. They are rewritten with `run`, the
idiom that file actually uses.

**Task 7: a correction that quotes the sentence it corrects fails a grep for that sentence.** The
first draft of this task's test asserted that neither document still said "runs the hook once from
the repository root". The fix keeps that wording beside its correction with the date, which is this
PRD's own convention for NFR-01 and NFR-03, so both assertions failed on the corrected text. They
are positive now: the row must name the four-combination probe, and a revert removes that. It is the
citation lesson in a third costume, a checker that cannot tell a claim from a quotation of one.

**Task 7's first PRD assertion passed on the wrong row.** A document-wide grep for "all four
combinations" matched the intro and FR-12 while NFR-02's cell still said the opposite. The
assertion now reads the NFR-02 row itself.

**Prose about a dead citation is written without the citation form.** Three times in two tasks, a
sentence recording a stale citation created one: the checker cannot tell a claim from a quotation,
and it should not try, because the 70% false positive rate of the phrase-matching rule this
repository already threw away is what that costs. Write "line 1207 of `bin/keel`" rather than the
colon form, or fence it. This belongs in `CONTRIBUTING.md` next to the citation rule.

**Task 2, and this is the plan's own footgun for the second time: a document that lists broken
citations is a document making broken citations.** This plan's repair table listed 30 of them in the
citation form and the new rule read all 30 as claims, so the first run reported 69 findings rather
than 31. The table is now fenced, as are the two inverted ranges quoted in the opening section.
Task 1 hit the same thing in the phrase form, twice, including in the sentence recording it.

**Task 1, on its first run against this repository: writing about the phrase form in the phrase
form creates a phrase citation.** This plan's task 2 gave a worked example of what to write, using
the real name of `bin/keel` followed by a placeholder phrase, in prose rather than in a fence. The
new rule read it as a claim and went red, correctly: `bin/keel` has no line reading `<phrase>`. The
example is now written with a generic
`<path>`, which names no real file and no real directory, so the checker skips it. This is the same
lesson the previous branch recorded for the line form, where the first draft of its task 6a listed
four broken citations in the citation form and turned four failures into nine. The form a document
teaches is a form that document is then making claims in.

**Task 8 shortened the profile and broke two citations into it, and the coordinator did not see
the red.** Removing five retired keys took `.keel/profile.json` from more than 84 lines to 82, and
two sentences, one in `tests/test-harness-resolve.sh` and one in
`docs/plans/2026-09-05-tiered-multi-harness-support.md`, cited line 84 of the profile for the
`verify_notes.lint` note. Both now cite `.keel/profile.json#shellcheck at default severity`, and
the sibling line citation into `test-context-watch.sh` in the same comment went to a phrase with
them. The profile is not on the hot-file list, so nothing warned before the file shrank. The red was
missed for a smaller reason than the handoff feared: the task 8 command was `keel doctor 2>&1 |
grep -E "schema version|retired"`, so doctor's `FAIL verify.test` line was filtered out and the
exit code read was grep's. Doctor itself runs `verify.test` and fails on it, checked in
`bin/keel#fail "verify.$k does not run`. The rule is the one the previous plan wrote for
`done_verified`: never pipe the gate's output through a grep and read the pipeline's status.

**Task 5's eleven code-comment conversions were unchecked, and one of them was already dead.**
`tests/validate-citations.sh` reads a phrase citation only inside backticks, in code comments as in
prose, and ten of the eleven were written bare, so `OK 1407 citations checked` counted none of
them. Backticked on 2026-09-11, the count moved to 1417 and one went red at once:
`tests/test-keel.sh` quoted "must exist." for a line in `bin/keel` that reads "must exist,". That
is eleven for eleven on this branch for citations read closely, and the second time this plan has
found a conversion that satisfied the checker by being invisible to it.

**Task 9, a deviation.** The plan's step 1 case, which feeds 200,000 bytes through a pipe to make
the race certain, was replaced by the file-fed form in step 3 as the plan says, and not kept in any
form: a file-fed large payload asserts nothing the event case does not. The file ran 40 times
consecutively with no failure after the change, on top of the 60 recorded before it.

## Open questions

None blocks execution. Two are recorded because a decision made silently gets reopened.

1. **The hot-file list is three names, and it is hand-maintained.** `bin/keel`,
   `tests/validate-skills.sh` and `tests/test-keel.sh` are the three files that take insertions in
   most weeks, and a fourth will earn its place eventually with nothing to prompt anyone to add it.
   Deriving the list from `git log` was rejected while writing this plan, on the ground that a rule
   whose membership changes when somebody commits is one nobody can predict, and a check people
   cannot predict is the one they learn to ignore. Revisit if a fourth file starts producing the
   same finding.
2. **The phrase form is not required to be unique.** A phrase that appears twice in the cited file
   still resolves, so the checker accepts it, and task 5 chooses unique phrases by hand instead.
   The alternative, rejecting a non-unique phrase, is stricter than correct output, which
   `CONTRIBUTING.md` calls the unrecoverable failure. If a real citation is ever found pointing at a
   phrase that occurs in two meaningfully different places, that is the evidence to revisit this on.

3. **The new coverage puts a repair tax on every `bin/keel` insertion.** Measured in task 5: one
   inserted line turns 14 citations in dated records red. They were equally wrong before and nothing
   said so, which is the improvement, but the build now stops until somebody blames and shifts them.
   The alternatives are to convert those records to phrases, which this plan rejected because their
   sentences cannot be verified, or to exempt a dated record from the blank-line rule as it is
   already exempt from the phrase rule, which would return them to being silently wrong. Decide it
   the first time the tax is actually annoying, with a real number for how long the repair took.

## What this plan does not touch

**The 297 line-number citations in dated records.** They stay, and the table under "The line this
plan draws" says which files those are and why. Converting them would mean choosing a phrase for
each without being able to verify what its sentence meant, which manufactures permanently green
pointers at possibly wrong content.

**`lib/harness/capabilities` and `docs/harness-support.md`.** The capabilities file carries a third
citation grammar in its `probe:` field, with its own validator, and every row carries the harness
version and the date it was measured. It is dated evidence, and generating `docs/harness-support.md`
from it makes that file dated evidence too.

**`skills/coding-standards`.** Wiring `gates.coding_standards` so that something branches on it is
the work `docs/ideas/standards-that-bind.md` owns. Task 4 marks the key `observed:`, which says what
is true today: a model reads it unprompted and nothing in this repository asks it to.

**The eval fixture that seeds `observability.log_shipping`.** Open question 4 of the previous plan
decided to leave it, because changing a fixture changes what a recorded arm was measured against.
Task 8 does not touch `tests/evals/fixtures/`.
