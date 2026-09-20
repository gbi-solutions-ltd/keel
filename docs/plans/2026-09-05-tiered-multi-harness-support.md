# Tiered multi-harness support Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go, on output you read.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness, or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** keel installs on OpenAI Codex CLI at a named lower tier, and no gate is registered,
written or advertised on a harness that cannot run it.

**Stories:** S-01 to S-18. S-19 is `decide` and has no task here; see Open questions.
**ADRs:** ADR-0003, ADR-0004, ADR-0005, all `proposed`.
**Architecture:** [`../architecture/tiered-multi-harness-support.md`](../architecture/tiered-multi-harness-support.md).
One checked-in capability manifest states what each harness provides and what each gate requires. A
pure-bash resolver answers "is gate G active on harness H" from it, and the hook manifests, `keel
init`'s writes, `keel doctor`'s report and the tier table are all derived rather than written. Two
tests fail the build when a derived artifact is stale or a document claims more than the manifest
grants.

## Global constraints

Copied in full. A task executed by a fresh agent that reads only its own section must still obey
these.

- **Verify commands, from `.keel/profile.json`:**
  - test: `tests/run-tests.sh`
  - one test: `tests/{name}`
  - lint: `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh tests/evals/stage.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`
  - typecheck: none in this project. format: none. build: none.
- **`lib/*.sh` in the lint command is a glob that does not descend.** A task adding a file under
  `lib/harness/` must add `lib/harness/*.sh` to `verify.lint` in `.keel/profile.json`, in that task,
  or CI lints less than it claims to.
- **`verify.lint` is defined once, and `CLAUDE.md` is not a second copy of it.** The shellcheck line
  at `CLAUDE.md:20` and `AGENTS.md:20` is `{{VERIFY_LINT}}`, interpolated from the profile by
  `render_block` (`bin/keel#render_block() {`) inside the managed block at `CLAUDE.md:1-32`. That block is
  owned by keel and replaced wholesale, so **hand-editing it is both wrong and unnecessary**: change
  the profile and re-render. `docs/standards.md`, "One definition per verify command", is the rule,
  and its scar is a CI lint that ran a different severity from the local one, two copies kept.
- **A new test file is not discovered.** `tests/run-tests.sh` hardcodes its list (`:18-37`). A task
  adding one adds an `add "tests/<name>" "tests/<name>"` line in the same task.
- Never start on `main`. `conventions.protect_default_branch` is true.
- No em dash, en dash, or any dash longer than a hyphen, anywhere, including code comments.
  `tests/validate-skills.sh` fails the build on one.
- Commit style is conventional (`conventions.commit_style`). No attribution footers
  (`conventions.no_attribution_footers`).
- **ADR-0003:** a primitive with no source, version and date is treated as not provided. Absent
  evidence fails, never passes.
- **ADR-0004:** every guarantee is a property of `(repository, harness)` and is never stated for a
  repository alone.
- **ADR-0005:** one body per skill. No skill body names a vendor model alias or a harness-specific
  agent type.
- **R-01 is absolute:** no Claude Code behaviour changes. Where a task touches a shared path, its
  test asserts the Claude Code output is byte-identical.
- **`--dangerously-bypass-approvals-and-sandbox` is eval-only.** It may appear under `tests/evals/`
  and nowhere else. Task 18 adds the check that keeps it there. Never put it in README, in
  `docs/harness-support.md`, or anywhere a user could read it as a normal way to run Codex.

**Concurrent batches:** none declared. Tasks 1 and 18 are genuinely independent and could be
batched, but a batch requires a worktree per task and a self-commit per task, and two tasks does not
repay that machinery. Run the plan in order.

**Execution order, revised 2026-09-05 after task 2:** 1, 2, **2A**, **14**, 3, 4, 5, 6, then 7 to
13 and 15 to 18 in number order. Tasks 1, 2, 2A, 14, 3 to 12 are done, **task 13 is struck and was verified struck rather than skipped**, and **every task is done.** Task 13 was verified struck rather than implemented. One design item is unbuilt and named in task 18's note: the five scenario files naming `stream-json` in prose. Task 10 leaves one probe-gated sentence open, named in its note. Task numbers are unchanged; only the order is. Renumbering would
break the dozen places tasks refer to each other by number, and buys nothing.

**Why 2A and 14 moved ahead of 3.** Task 1's manifest resolves Codex to `session-start` alone,
because its final revision split the transcript primitives along Claude Code's own schema. Two
consequences, and the reorder answers both. First, `transcript_jsonl_usage` and
`transcript_jsonl_tool_use` name a wire format rather than a capability, so **no second harness can
ever satisfy them however much evidence it has**, and Tier B would have lost two gates by
construction rather than by evidence. Task 2A renames them. Second, task 3 registers gates and task
6 advertises them, so both must run after the Codex rows exist, not before: registering three gates
and earning two of them afterwards is the "looks installed and is not" failure this design's
dominant force names, committed by the plan itself.

**Critical path:** tasks 1, 2, 2A, 14, 3, 4, 5, 6. Everything that makes a claim checkable runs through the
manifest and the resolver, and **the document repairs in task 6 must not start before task 5 exists**
to police them. Repairing first and checking later leaves a window where the repairs are unverified,
which is the drift this design exists to close.

---

### Task 1: State every harness capability and gate requirement in one file

> **Done 2026-09-05, commit `5ffbf90`.** Delivered on the fourth dispatch; the three discards were
> defects in this task's own text, not in any implementation. Step 2 was watched failing on the
> fourth run at 5 passed, 6 failed. Step 4 landed at 16 passed, which matched the prediction for the
> first time. Every box below is ticked on output the coordinator read in an implementer's report or
> re-ran itself.

**Story:** S-01
**Files:**
- Create: `lib/harness/capabilities`
- Create: `tests/test-harness-resolve.sh`
- Modify: `tests/run-tests.sh`

**Interfaces:**
- Produces: `lib/harness/capabilities`, a pipe-delimited text file with two record kinds,
  `provides|<harness>|<primitive>|<source>|<version>|<date>` and `requires|<gate>|<primitive>`.
- Consumes: nothing.

**Depends on:** none

**Done when:** `tests/test-harness-resolve.sh` passes and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

Create `tests/test-harness-resolve.sh`:

```bash
#!/usr/bin/env bash
# Tests for lib/harness/capabilities and lib/harness/resolve.sh.
#
# shellcheck disable=SC2015  # `a && ok || bad` is this suite's idiom; ok never fails, so the
# warning's scenario cannot arise. tests/test-keel.sh:10 and test-context-watch.sh:16 disable it for
# the same reason. .keel/profile.json:84 records that CI lints at default severity, so an info
# finding is a red build.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
pass=0; fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }

CAP="$ROOT/lib/harness/capabilities"

[ -f "$CAP" ] && ok "capabilities file exists" \
  || bad "capabilities file exists" "not found at lib/harness/capabilities"

grep -q '^provides|claude|pretooluse_ask|' "$CAP" 2>/dev/null \
  && ok "claude provides pretooluse_ask" \
  || bad "claude provides pretooluse_ask" "row absent"

grep -q '^provides|codex|pretooluse_ask|' "$CAP" 2>/dev/null \
  && bad "codex does not provide pretooluse_ask" "row present and must not be" \
  || ok "codex does not provide pretooluse_ask"

# Every requires row names a gate that exists as a file under hooks/. Both directions, because a
# requires row for a gate nobody ships is as wrong as a gate with no requires row.
while IFS='|' read -r k g _; do
    [ "$k" = requires ] || continue
    [ -f "$ROOT/hooks/$g" ] && ok "requires row $g has a hook file" \
      || bad "requires row $g has a hook file" "hooks/$g does not exist"
done < "$CAP"

# ADR-0003: absent evidence fails, never passes. A field holding only spaces is absent evidence
# that would pass a test for emptiness, so match blank rather than empty, and check the field count
# too: a seven-field row would otherwise sail through.
provenance_gaps() {   # provenance_gaps <file>
    awk -F'|' '$1=="provides" && (NF!=6 || $4 ~ /^[[:space:]]*$/ || $5 ~ /^[[:space:]]*$/ || $6 ~ /^[[:space:]]*$/) {print $2"/"$3}' "$1"
}
thin="$(provenance_gaps "$CAP")"
[ -z "$thin" ] && ok "every provides row carries source, version and date" \
  || bad "every provides row carries source, version and date" "$thin"

# A validator with no test proving it fires is worse than none: docs/standards.md, and ADR-0003's
# own verification section says a check that has never fired is a check nobody has tested. Run the
# predicate against a fixture built to break it, in all three ways.
fx="$(mktemp)"
printf 'provides|ghost|a|src|1|2026-01-01\nprovides|ghost|b|src|1|\nprovides|ghost|c| |1|2026-01-01\nprovides|ghost|d|src|1|2026-01-01|extra\n' > "$fx"
got="$(provenance_gaps "$fx" | sort | tr '\n' ' ')"
[ "$got" = "ghost/b ghost/c ghost/d " ] \
  && ok "the provenance check fires on empty, blank and wrong-arity rows" \
  || bad "the provenance check fires on empty, blank and wrong-arity rows" "got: $got"
rm -f "$fx"

# Every source says which kind of evidence it is. A keel file is neither kind.
unkinded="$(awk -F'|' '$1=="provides" && $4 !~ /^(vendor|probe):/ {print $2"/"$3}' "$CAP")"
[ -z "$unkinded" ] && ok "every source is marked vendor: or probe:" \
  || bad "every source is marked vendor: or probe:" "$unkinded"

# A one-character typo in a requires row would disable a gate on every harness, including the one
# where it works. Fail closed is right; a typo indistinguishable from a deliberate absence is not.
# Keyed on gate AND primitive. Keyed on the gate alone, a second requires row overwrites the first
# and only the last is ever checked, which is precisely the shape done-guard now has.
orphan="$(awk -F'|' '$1=="provides"{p[$3]=1} $1=="requires"{r[$2 SUBSEP $3]=1} END{for(k in r){split(k,a,SUBSEP); if(!(a[2] in p)) print a[1]"->"a[2]}}' "$CAP")"
[ -z "$orphan" ] && ok "every required primitive is provided by some harness" \
  || bad "every required primitive is provided by some harness" "$orphan"

# The gate list comes from the tree, not from this file. A fifth gate added under hooks/ with no
# requires row would otherwise pass unnoticed, and resolve.sh would report it active everywhere.
for h in "$ROOT"/hooks/*; do
    [ -f "$h" ] || continue
    g="$(basename "$h")"
    case "$g" in hooks.json|*.json) continue ;; esac
    grep -q "^requires|$g|" "$CAP" 2>/dev/null \
      && ok "gate $g has a requires row" || bad "gate $g has a requires row" "no requires row"
done

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

Add it to the runner, after the `add "tests/test-eval-harness.sh"` line in `tests/run-tests.sh`:

```bash
add "tests/test-harness-resolve.sh"  "tests/test-harness-resolve.sh"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-harness-resolve.sh`
Expected: FAIL, exit 1, opening with "capabilities file exists: not found at
lib/harness/capabilities".

**Not every case fails, and that is expected.** Four assertions pass vacuously with the file absent,
because `grep -q` and `awk` on a missing file produce no output and the emptiness tests hold; and
the `while ... done < "$CAP"` loop emits no assertions at all, because the redirect itself fails.
What makes the run red is the file-exists check, the positive `claude provides pretooluse_ask`
check, and the four gate checks, which read `hooks/` rather than the manifest and so cannot be
silenced by its absence. Report the counts you see rather than matching a number.

- [x] **Step 3: Write the minimal implementation**

Create `lib/harness/capabilities`:

```
# What each harness provides and what each gate requires. The single source of truth.
#
# Read by lib/harness/resolve.sh in pure bash, because hooks/sensitive-guard reads it and must work
# on a machine with no python3. That is why this is pipe-delimited text and not JSON.
#
# provides|<harness>|<primitive>|<source>|<version>|<date>
# requires|<gate>|<primitive>
#
# <source> is one of two kinds and says which. `vendor:` is a published artifact belonging to the
# harness. `probe:` is an observation somebody made and recorded. A keel file is neither: that keel
# ships a Stop hook is not evidence that the harness honours one, and a row citing only our own tree
# would keep asserting `provides` after the harness dropped the primitive. Nine rows were written
# that way on 2026-09-05 and every one was replaced.
#
# <version> is THE HARNESS's version, never keel's. keel doctor prints it beside the version of the
# harness it is running, and that comparison means nothing if this column holds 0.18.0.
#
# THE RULE THIS FILE EXISTS TO EXPRESS, which lives nowhere else in the tree: a gate is active on a
# harness IF AND ONLY IF that harness provides EVERY primitive the gate requires. So a `requires`
# row is not documentation. It is an instruction that silently disables that gate on every harness
# lacking the primitive, and adding one is the most consequential edit anybody makes here.
#
# A gate may carry more than one `requires` row, and `done-guard` does. A new gate needs both a file
# under hooks/ and at least one `requires` row; the test checks both directions and a missing half
# is a red build rather than a quiet hole.
#
# WHY THERE ARE THREE TRANSCRIPT PRIMITIVES. `transcript_path` is only the promise of a path. What
# each gate needs from inside that file is different and neither implies the other:
# lib/context_watch.py needs message.usage carrying four token fields, and hooks/done-guard needs
# message.content[] tool_use blocks plus isSidechain. agent_transcript_path is NOT a transcript row
# field at all: it arrives on the SubagentStop event, so it is its own primitive with a vendor
# source. Bundling it into a transcript probe claimed evidence a transcript cannot carry, and zero
# of 368 transcripts hold that key.
#
# `subagent_transcript_path` is PROVIDED and required by nothing, deliberately. done-guard reads it
# only on SubagentStop and falls back to transcript_path when it is absent (hooks/done-guard:218-220),
# so requiring it would disable the whole gate on a harness whose Stop path works. Under-requiring
# resolved done-guard active on Codex; over-requiring would resolve it inactive where it works. The
# rule is that a gate requires what it cannot function without, not everything it can use. Codex supplies a
# path, so it holds `transcript_path` and neither schema row. Collapsing these into one primitive
# resolved done-guard ACTIVE on Codex on the strength of stop_blocking alone, where it would have
# read a Codex transcript looking for Claude Code rows and failed open in silence. Caught in review
# on 2026-09-05, before it shipped, which is the whole point of the file.
#
# ADR-0003: a primitive with no source, version and date is treated as not provided. Absent
# evidence fails, never passes. Do not add a row you have not checked.

provides|claude|session_context_injection|vendor:code.claude.com/docs/en/hooks SessionStart additionalContext|2.1.261|2026-09-05
provides|claude|stop_blocking|vendor:code.claude.com/docs/en/hooks Stop decision block|2.1.261|2026-09-05
provides|claude|pretooluse_deny|vendor:code.claude.com/docs/en/hooks PreToolUse permissionDecision deny|2.1.261|2026-09-05
provides|claude|pretooluse_ask|vendor:code.claude.com/docs/en/hooks PreToolUse permissionDecision ask|2.1.261|2026-09-05
provides|claude|transcript_path|vendor:code.claude.com/docs/en/hooks common input transcript_path|2.1.261|2026-09-05
provides|claude|transcript_jsonl_usage|probe:69 transcripts under ~/.claude/projects, 12269 assistant rows carrying message.usage with all four summed fields|2.1.261|2026-09-05
provides|claude|transcript_jsonl_tool_use|probe:the same 69 transcripts, 6224 message.content[] tool_use blocks, and 270 subagent transcripts whose 31865 rows are all marked isSidechain|2.1.261|2026-09-05
provides|claude|subagent_transcript_path|vendor:code.claude.com/docs/en/hooks SubagentStop agent_transcript_path|2.1.261|2026-09-05
provides|claude|permission_rules_command_patterns|probe:bin/keel:582-589 command-pattern rules, held under bypassPermissions in the live session at bin/keel:558-560|2.1.261|2026-09-05
provides|claude|permission_rules_path_globs|probe:bin/keel:577-581 path-glob rules, held under bypassPermissions in the live session at bin/keel:558-560|2.1.261|2026-09-05
provides|claude|plugin_marketplace|probe:~/.claude/plugins/known_marketplaces.json lists gbi and keel is installed from it|2.1.261|2026-09-05

provides|codex|session_context_injection|vendor:openai/codex@rust-v0.153.4 codex-rs/hooks/schema/generated/session-start.command.output.schema.json|0.153.4|2026-09-05
provides|codex|stop_blocking|vendor:openai/codex@rust-v0.153.4 codex-rs/hooks/src/events/stop.rs:295|0.153.4|2026-09-05
provides|codex|pretooluse_deny|vendor:openai/codex@rust-v0.153.4 codex-rs/core/tests/suite/hooks.rs::plugin_pre_tool_use_blocks_exec_command_before_execution|0.153.4|2026-09-05
provides|codex|transcript_path|vendor:learn.chatgpt.com/docs/hooks common input transcript_path|0.153.4|2026-09-05
provides|codex|permission_rules_path_globs|vendor:openai/codex@rust-v0.153.4 codex-rs/protocol/src/permissions.rs:105|0.153.4|2026-09-05
provides|codex|plugin_marketplace|vendor:developers.openai.com/plugins/build/plugins|0.153.4|2026-09-05
provides|codex|execpolicy_command_prompt|vendor:openai/codex@rust-v0.153.4 codex-rs/execpolicy/src/decision.rs Decision::Prompt|0.153.4|2026-09-05

requires|session-start|session_context_injection
requires|done-guard|stop_blocking
requires|done-guard|transcript_jsonl_tool_use
requires|context-watch|transcript_jsonl_usage
requires|sensitive-guard|pretooluse_ask
```

**`output_styles` is deliberately absent.** It was probed on 2026-09-05 and the probe came back
partial: the plugin loader does carry `output-styles/keel-terse.md` into the installed plugin cache,
but nothing established that it appears in `/config` under Output style. Under ADR-0003 a partial
probe is not evidence, so the row is not written. It costs nothing, because **no gate requires it**:
the five `requires` rows name `session_context_injection`, `stop_blocking`,
`transcript_jsonl_tool_use`, `transcript_jsonl_usage` and `pretooluse_ask` only; `transcript_path`
and `subagent_transcript_path` are provided and required by nothing. A future task that wants to claim the output style has to probe it first.

**The `codex` line numbers were replaced with a test name where one exists.** A line number in a
4,000-line vendor test file does not survive an upstream rebase and cannot be checked from here; the
function name can. This is the same defect class as the two citation drifts repaired in
`hooks/sensitive-guard` earlier the same day, arriving in a file whose entire purpose is provenance.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-harness-resolve.sh`
Expected: PASS, **16 passed, 0 failed**. Seven straight-line assertions, plus one per `requires`
row (5) and one per gate file under `hooks/` (4). This number was wrong in three earlier drafts of
this plan, each time because the two loops were not counted; if you get a different number, count
the loops before assuming the work is wrong.

- [x] **Step 5: Hand over**

```bash
git add lib/harness/capabilities tests/test-harness-resolve.sh tests/run-tests.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(harness): state harness capabilities and gate requirements in one file"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.

---

### Task 2: Resolve the active gate set for a harness, in pure bash

> **Done 2026-09-05, commit `1d554a9`.** Nine dispatches. Every discard was a defect in this task's
> own text, none in an implementation, and the implementation has been byte-identical since the
> second dispatch. Step 2 was watched failing at 18 passed, 1 failed; step 4 landed at 41 passed, 0
> failed, matching the prediction. Every box below is ticked on output the coordinator read in an
> implementer's report and re-ran itself.
>
> **Both reviewers signed off.** Spec compliance confirmed both code blocks byte-identical by `cmp`,
> all five interfaces exercised outside command substitution, `keel_version` reverted in the worktree
> rather than merely unstaged, and `CLAUDE.md` reproduced from `render_block` to prove regeneration.
> Code quality ran 25 mutants with zero survivors outside the eleven declared fail-closed classes,
> and an earlier pass deleted every conditional in `resolve.sh` and every rule in `malformed_rows` to
> prove nothing else was unpinned.
>
> **One finding is deliberately carried forward rather than fixed here**, because no comment edit can
> close it: changing `fx2` line 20's tab to a space in place leaves the suite green **and** silently
> un-pins the `$3` tab mutation. Insertion and deletion are caught by the pinned line list; in-place
> degradation is not. That needs a fixture-integrity assertion, filed with task 2A's carve-out.

> **Corrected twice on 2026-09-05, both times before this text was believed.** The first round found
> three defects by running the task against the manifest task 1 shipped: it expected codex to
> resolve three gates where the shipped manifest resolves one, it declared an unused `line` local
> which is SC2034 and a red lint, and its no-python3 assertion ran on a PATH holding
> `/usr/bin/python3` and so tested nothing.
>
> **The second round is the one that matters.** The first corrected version was implemented, passed
> its own suite 23 of 23, passed shellcheck, and was still wrong in three ways that each resolved a
> gate ACTIVE against an unmet requirement, which is the precise failure this whole design exists to
> prevent:
>
> 1. **A whitespace-only provenance field granted the primitive.** `[ -n "$f4" ]` accepts a single
>    space. `tests/test-harness-resolve.sh:35-37` had already settled this and says the opposite in
>    its own comment, so the validator and the resolver were applying two different definitions of
>    absent evidence to the same row. A trailing space is invisible in a diff.
> 2. **A manifest with no trailing newline dropped its last row.** `read` returns non-zero on a
>    final unterminated line even though it has populated the variables, and there was no
>    `|| [ -n "$f1" ]` guard. The asymmetry is what makes it dangerous: dropping a trailing
>    `provides` row fails closed and gets noticed, dropping a trailing `requires` row fails OPEN and
>    does not. One editor that strips a final newline turns a gate on.
> 3. **A seven-field `provides` row granted the primitive**, because the sixth read variable
>    swallows the remainder. The suite's own `provenance_gaps` flags `NF!=6` as a gap, so again the
>    two disagreed, with the resolver the more permissive of the two.
>
> **And the reason all three shipped is that two assertions looked like they covered this and did
> not.** The "no date" fixture was `src||`, leaving version and date both empty, so the version
> check alone rejected it and the date column was never exercised: deleting the date check entirely
> still passed 23 of 23. And no assertion checked that `harness_active_gates` returns 0 for a known
> harness, because command substitution and a pipeline each discard the status: replacing its final
> `return 0` with `return 1` also still passed 23 of 23. Both were confirmed by running the suite
> against those deliberately broken implementations.
>
> **Round three found the round-two fix was still one hole short, and that its own mutation evidence
> was overstated.** The implementation was correct and needed no change; the tests did.
>
> - **The serious one, and it survived both earlier rounds.** An indented or misspelled `requires`
>   row is invisible to `resolve.sh` and to every check in the test file, because all of them key on
>   `$1=="requires"`. Putting **one leading space** on `requires|done-guard|transcript_jsonl_tool_use`
>   makes `done-guard` resolve ACTIVE on Codex, which provides neither transcript schema row, and the
>   suite stays green. Nothing in the tree checked that a line is a well-formed record at all. Step 1
>   now carries `malformed_rows`, flagging any line that is not a comment, a blank, or a record of
>   the right arity, with leading whitespace illegal everywhere including comments.
> - Three guards were unpinned: the version field had no blank-but-non-empty fixture, `found=1` could
>   be flipped to `found=0` for a green build (resolving every unknown gate active on every harness),
>   and the no-trailing-newline guard was pinned on one of its four loops.
> - The empty-`KEEL_CAPABILITIES` assertion was unfalsifiable: it went through `harness_gate_active`,
>   where `[ -r "" ]` refuses anyway, so it stayed green against the code it claimed to pin. It now
>   asserts `harness_capabilities_path`'s own status.
>
> **The claim that produced it is worth naming.** Round two said "six single-line mutations, one per
> guard, each caught". That was measured with a single `sed` replacing all three provenance field
> checks at once, so the version field's guard was never independently tested. A mutation that
> changes several guards together proves nothing about any of them.
>
> **Round four closed the last of the family and one trap.** The implementation was again correct
> and unchanged; the tests were again the gap.
>
> - **Blank harness and primitive columns granted a gate on no evidence.** Nothing validated `$2` or
>   `$3`: `provenance_gaps` inspects only `$4` to `$6`, `malformed_rows` inspected only `$1` and
>   `NF`, and the orphan check is satisfied whenever the same blank value sits on both sides. So
>   `provides|codex||...` together with `requires|done-guard|` resolved `done-guard` ACTIVE on Codex,
>   with every structural check green. `malformed_rows` now rejects a blank `$2` or `$3` in either
>   record kind, and a whitespace-only line, which its own comment had claimed was already illegal.
> - **The three record-kind guards were unpinned**, and they are what make keying on the first field
>   mean anything. Deleting `[ "$f1" = "provides" ]` turns this manifest's own format comment into a
>   grant, because its fields align. The two `requires` counterparts are pinned separately, and the
>   one in `harness_active_gates` only changes the ORDER gates come out in, which is why its fixture
>   asserts an unsorted list where everything else here sorts.
> - **The python3 assertion was pinned to Codex's gate list**, which task 14 changes. Nothing about
>   it is Codex-specific, so it now resolves `claude`, whose set does not move when a second harness
>   gains a primitive. Without this, task 14 turns an assertion red for a reason that reads as
>   unrelated to its own change.
>
> Step 1 therefore carries a positive control before every negative fixture, and every guard in step
> 3 has a fixture that fails without it. Verified by sixteen mutations, **one guard at a time**, each
> caught: the three provenance fields separately, the arity guard, the no-trailing-newline guard on
> each of the four loops separately, the record-kind guard in each of the three loops separately,
> `found=1`, the final `return 0`, the empty-override guard, and two manifest mutations, a leading
> space on a `requires` row and a blank primitive on both sides.
>
> **Round five fixed round four's own addition.** No live fail-open this time; the implementation has
> now been unchanged and correct for four rounds. What was wrong was a test that did not test what
> it said, and two comments that described it wrongly.
>
> - **`a provides row is not a requires row` was unfalsifiable against the mutation it named.** Its
>   fixture used a six-field `provides` row, but `harness_gate_active` reads only three variables, so
>   `f3` swallowed `p|src|1|2026-01-01`, the primitive lookup failed, and the gate was refused with
>   or without the guard. Only a **three-field** line reaches that fail-open. The fixture is now a
>   three-field comment, and the assertion is renamed to what it actually proves: **prose in a
>   comment that happens to mention a `requires` row would grant that gate**, and comments are
>   exempt from `malformed_rows`, so nothing else in the suite would see it.
> - **The blank half of the blank-field rule was unpinned.** Every blank case in the fixture used a
>   truly empty field, so `$2 ~ /^[[:space:]]*$/` could be weakened to `$2 == ""` with the suite
>   green. That is ADR-0003's central claim going untested in the check written to enforce it. Five
>   blank-not-empty rows are now in the fixture, one using a tab so `/^ *$/` is not enough either.
> - The `requires` arity check had no over-long row, and the fixture's own comment miscounted its
>   cases. Both corrected.
>
> **Round six closed four more unpinned guards, one of them miscounted.**
>
> - **There are FOUR record-kind guards, not three.** `[ "$f1" = "provides" ]` appears in
>   `harness_known` as well as `harness_provides`, and round five's comment said two `requires`
>   counterparts and stopped there. Deleting the `harness_known` one makes any string in any row's
>   second field a known harness, including `<harness>` from the format comment. **Task 3 gates the
>   CLI on `harness_known`**, so that is what stops `keel harness done-guard` being accepted and then
>   resolving to an empty gate list with status zero, which reads as "this harness has no gates"
>   rather than "there is no such harness".
> - **Tab coverage was on `$2` only.** Mutating just the `$3` branch of the blank-field rule to
>   `/^ *$/` stayed green, and `$3` is the primitive, the column a blank value on both sides grants
>   a gate through. Two tab rows added, one per column.
> - **`_harness_present` was unpinned against tabs on the resolver side.** Every `gate_on` fixture
>   used a space, so `${1//[[:space:]]/}` could be weakened to `${1// /}` with the suite green. That
>   is the resolver and the validator drifting apart on what absent evidence means, in the direction
>   that grants, which is the one thing `resolve.sh`'s own header says must not happen.
> - The `$1=="provides"` conjunct on the arity rule had no six-field `requires` row to pin it.
>
> **Round seven is the convergence point, and the evidence for saying so is specific.** The reviewer
> was asked to enumerate every conditional in `resolve.sh` and every rule in both awk validators, and
> to delete each in turn. **No unpinned guard remains.** Every survivor is one of the declared
> fail-closed classes: the `[ $# -eq N ]` arity guards, the `[ -r "$cap" ]` guards, and dropping the
> `|| return 1` from a `cap=` assignment, all of which leave `cap` empty and refuse anyway.
>
> What round seven itself fixed was **three false comments and two padding fixtures**, no behaviour:
>
> - Round six's own edited comment said "Fifteen ways to be malformed" when the assertion listed
>   nineteen, and swept an arity case into the range it labelled blank-but-not-empty. Both corrected.
> - Round six added two tab rows claiming one per column. **Both were the primitive column**; the
>   harness-column tab was already there from round five. One of the two pinned nothing, because the
>   blank rule runs before any `$1` test and cannot tell the record kinds apart. Removed, and the
>   comment now says so.
> - `requires||b` duplicated an existing case for the same reason. Removed.
> - "an unterminated requires row, which only `harness_active_gates`' own loop can read" was false;
>   `harness_gate_active`'s loop reads them too. It is fixture A that isolates the provides side.
> - A historical note cited a 23-assertion suite that no longer exists in the tree.
>
> Twenty-four mutations now, each caught, eight against the validator rather than the resolver, and
> the two exemption rules (`/^#/` and `/^$/`) are pinned as well. New fixture cases are **appended,
> never inserted**: the assertion pins an exact list of line numbers, so an insertion renumbers every
> later case and the diff stops showing which one was added.
>
> **Round eight, and the reason it exists is worth more than what it changes.** Round seven claimed
> to have corrected a miscounted comment. It did not: it appended the corrected sentence and left the
> false one two lines above, so the block said "Fifteen ways to be malformed" and "Seventeen
> malformed lines" in the same breath. Round eight deletes the stale clause and repairs a stray
> mid-sentence line break. **No behaviour, no fixture, no assertion changed**, and the mutation sweep
> was re-run in full to prove it.
>
> That is the fourth consecutive round whose only defect was in a comment. `lib/harness/resolve.sh`
> has now been byte-identical and correct for seven rounds while the prose around it kept drifting,
> which is its own finding: **in this file the comments have been harder to keep true than the code**,
> because each round edited them in place instead of rewriting the paragraph.
>
> **The evidence that this is finished, and it is worth stating precisely.** The round-seven quality
> pass ran **71 single mutants**, each applied alone to a pristine copy: every conditional in
> `resolve.sh` and every rule in `malformed_rows`. Survivors: exactly eleven, and exactly the
> declared fail-closed classes, the four `[ $# -eq N ]` arity guards, the three `[ -r "$cap" ]`
> guards, and dropping `|| return 1` from the four `cap=` assignments. Each was checked to be
> genuinely fail-closed rather than merely untested. It also attacked the "one tab row per column is
> the whole of it" conclusion with five record-kind-sensitive mutants the stated reasoning would not
> have covered, and the reduced fixture caught all five.
>
> **Round nine, and it names the actual cause of the last five rounds.** Round eight's repair of the
> stray line break introduced its own error: "that is why the **third** assertion below reads an
> unsorted list", when the ordering assertion is the fourth. Round six had inserted the
> `harness_known` assertion into that group and pushed it down one. The implementer's contradiction
> check caught it before either reviewer saw it.
>
> **The cause is a class, not five separate slips: a comment that names a position, a count, or an
> ordinal goes stale the moment anything is inserted near it, and nothing in the build checks
> prose.** Five consecutive rounds had their only defect in a comment while `lib/harness/resolve.sh`
> stayed byte-identical and correct throughout. The fix here is to delete the reference rather than
> renumber it: the point about not sorting is made at the assertion itself, where it cannot drift.
> The counts that remain are the ones the assertion's own expected value pins, so a stale count is a
> red build rather than a lie.
>
> **When editing these comments, rewrite the paragraph. Do not append a correction next to the thing
> it corrects**, which is how "Fifteen ways to be malformed" survived two lines above "Seventeen
> malformed lines" for a whole round.
>
> **The one assertion task 14 must deliberately edit is `codex resolves session-start alone`.** That
> is intended: it is where Tier B visibly changes size, in the same diff as the evidence earning it.
> Confirmed by simulating the Codex rows: exactly that assertion goes red and nothing else moves.
>
> Two further findings are **deliberately not addressed here**, both fail closed, both recorded in
> the handoff for a later cycle: `harness_capabilities_path` resolves lazily from `BASH_SOURCE` on
> every call, so a relative source followed by a `cd` writes a `cd:` error to stderr on every hook
> invocation and every gate goes dark, and reaching the file through a symlink does the same; and it
> forks `dirname` roughly eleven times to answer one question about a 25-line file.

**Story:** S-02
**Files:**
- Create: `lib/harness/resolve.sh`
- Modify: `tests/test-harness-resolve.sh`
- Modify: `.keel/profile.json`
- Regenerate, never hand-edit: `CLAUDE.md`, `AGENTS.md`

**Interfaces:**
- Consumes: `lib/harness/capabilities`, defined in task 1.
- Produces, all five, since task 3 consumes `harness_known` and a reader of task 3 alone needs to
  know it exists: `harness_capabilities_path` printing the manifest path, or returning non-zero if
  `KEEL_CAPABILITIES` is set to the empty string; `harness_provides <harness> <primitive>` returning
  0 or 1; `harness_known <harness>` returning 0 or 1; `harness_gate_active <harness> <gate>`
  returning 0 or 1; `harness_active_gates <harness>` printing one gate name per line, returning 0
  for a known harness and non-zero for an unknown one. All take `KEEL_CAPABILITIES` as an override
  for the manifest path.

**Depends on:** task 1

**Done when:** `tests/test-harness-resolve.sh` passes, `tests/run-tests.sh` is green, and
`shellcheck -x bin/keel lib/*.sh lib/harness/*.sh tests/*.sh tests/evals/run.sh tests/evals/stage.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`
is clean.

- [x] **Step 1: Write the failing test**

Append to `tests/test-harness-resolve.sh`, before the `printf '\n%s passed'` line:

```bash
# Every line is a comment, a blank, or a well-formed record of the right arity. Without this, an
# indented or misspelled requires row is invisible to resolve.sh AND to every other check in this
# file, because all of them key on $1=="requires" or $1=="provides". One leading space turns a
# requirement into a no-op and its gate resolves ACTIVE on a harness that does not meet it: adding
# a single space to the done-guard row makes done-guard active on Codex, which provides neither
# transcript schema row. That is this design's dominant failure reachable by one keystroke, and the
# direction is the dangerous one, because a malformed provides row fails closed and gets noticed
# while a malformed requires row fails open and does not. Leading whitespace is never legal here,
# comments included, which is why an indented comment and a whitespace-only line are both flagged.
# Arity is checked here too: resolve.sh reads seven fields to detect a seventh, but a trailing pipe
# leaves that seventh empty and indistinguishable from a well-formed row, so it is caught here.
# The harness and primitive columns must be non-blank as well, in both record kinds. Nothing else
# looks at them: provenance_gaps inspects only $4 to $6, and the orphan check is satisfied whenever
# the same blank value appears on both sides. A blank primitive on a provides row and a blank
# primitive on a requires row therefore matched each other and granted the gate on no evidence.
malformed_rows() {   # malformed_rows <file>
    awk -F'|' '
        /^$/ { next }
        /^#/ { next }
        $2 ~ /^[[:space:]]*$/ || $3 ~ /^[[:space:]]*$/ { print NR; next }
        $1=="provides" && NF==6 { next }
        $1=="requires" && NF==3 { next }
        { print NR }
    ' "$1"
}
bad_rows="$(malformed_rows "$CAP" | tr '\n' ' ')"
[ -z "$bad_rows" ] && ok "every line is a comment, a blank, or a well-formed record" \
  || bad "every line is a comment, a blank, or a well-formed record" "lines: $bad_rows"

# A validator with no test proving it fires is worse than none. Seventeen malformed lines, 5 to 21,
# and four legal ones: a comment, a blank, and one record of each kind.
#
# Lines 14 to 18 and line 20 are the blank-but-not-empty cases and they are the point
# rather than padding. ADR-0003's whole claim is that blank is not empty, so a fixture holding only
# empty fields lets `$2 ~ /^[[:space:]]*$/` be weakened to `$2 == ""` with the suite still green,
# and a space in a manifest column is invisible in a diff. Lines 18 and 20 use tabs so `/^ *$/` is
# not enough either, and between them they cover both columns: 18 the harness, 20 the primitive.
# One per column is the whole of it. A second tab row in the same column pins nothing extra, because
# the blank rule runs before any `$1` test and so cannot tell the record kinds apart.
#
# New cases are appended rather than inserted. The assertion pins an exact list of line numbers, so
# inserting one renumbers every case after it and the diff stops showing which case was added.
fx2="$(mktemp)"
printf '# c\n\nprovides|a|b|src|1|2026-01-01\nrequires|g|b\n  # indented comment\n requires|g|b\nrequire|g|b\nprovides|a|c|src|1|2026-01-01|\nprovides|a|d|src|1\n   \nprovides|a||src|1|2026-01-01\nprovides||b|src|1|2026-01-01\nrequires|g|\nprovides|a| |src|1|2026-01-01\nprovides| |b|src|1|2026-01-01\nrequires|g| \nrequires| |b\nprovides|\t|b|src|1|2026-01-01\nrequires|g|b|extra\nprovides|a|\t|src|1|2026-01-01\nrequires|g|b|src|1|2026-01-01\n' > "$fx2"
got="$(malformed_rows "$fx2" | tr '\n' ' ')"
[ "$got" = "5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 " ] \
  && ok "the well-formedness check fires on every malformed shape and no legal one" \
  || bad "the well-formedness check fires on every malformed shape and no legal one" "got: $got"
rm -f "$fx2"


# shellcheck source-path=SCRIPTDIR/..
# shellcheck source=lib/harness/resolve.sh
. "$ROOT/lib/harness/resolve.sh" 2>/dev/null || true

if command -v harness_active_gates >/dev/null 2>&1; then
    got="$(harness_active_gates claude | sort | tr '\n' ' ')"
    [ "$got" = "context-watch done-guard sensitive-guard session-start " ] \
      && ok "claude resolves four gates" || bad "claude resolves four gates" "got: $got"

    # One gate, not three. Task 1's manifest splits the transcript primitives by schema, and codex
    # provides transcript_path and neither schema row, so done-guard and context-watch resolve
    # inactive there today. Task 14 is what earns them back, by landing the Codex paths and the
    # probe rows that evidence them. ADR-0003: absent evidence fails, never passes.
    got="$(harness_active_gates codex | sort | tr '\n' ' ')"
    [ "$got" = "session-start " ] \
      && ok "codex resolves session-start alone" \
      || bad "codex resolves session-start alone" "got: $got"

    harness_gate_active codex sensitive-guard \
      && bad "sensitive-guard inactive on codex" "reported active" \
      || ok "sensitive-guard inactive on codex"

    harness_active_gates cursor >/dev/null 2>&1 \
      && bad "an unknown harness is refused" "exit status was zero" \
      || ok "an unknown harness is refused"

    # A known harness must resolve with status 0. Command substitution and a pipeline each discard
    # the status, so every assertion above this one passes against a harness_active_gates that
    # always returns 1. That mutation was run against an earlier version of this suite and every
    # assertion still passed, which is why this one exists.
    if harness_active_gates claude >/dev/null; then
        ok "a known harness resolves with status zero"
    else
        bad "a known harness resolves with status zero" "non-zero status"
    fi

    # Set but empty is an error, not a fallback. A caller whose override path came out empty would
    # otherwise resolve against the developer's own manifest and be told every gate is active.
    # Assert the path function's own status. Going through harness_gate_active proves nothing:
    # with the guard deleted the path is still the empty string, [ -r "" ] still fails, and the
    # gate is still refused, so that assertion stays green against the very code it claims to pin.
    KEEL_CAPABILITIES="" harness_capabilities_path >/dev/null \
      && bad "an empty KEEL_CAPABILITIES is refused" "returned zero" \
      || ok "an empty KEEL_CAPABILITIES is refused"

    # One fixture per way a provides row can be absent evidence while looking populated. Each of
    # these granted its primitive in the first version of resolve.sh, and none is visible in a diff.
    # The positive control is first on purpose: without it every negative below also passes against
    # a resolver that refuses everything.
    gate_on() {   # gate_on <printf-escaped manifest>; echoes active or inactive
        local f rc
        f="$(mktemp)"
        printf '%b' "$1" > "$f"
        KEEL_CAPABILITIES="$f" harness_gate_active ghost done-guard; rc=$?
        rm -f "$f"
        [ "$rc" -eq 0 ] && printf 'active' || printf 'inactive'
    }

    [ "$(gate_on 'provides|ghost|p|src|1|2026-01-01\nrequires|done-guard|p\n')" = "active" ] \
      && ok "a complete row grants its primitive" \
      || bad "a complete row grants its primitive" "the negative cases below would prove nothing"

    [ "$(gate_on 'provides|ghost|p|src|1|\nrequires|done-guard|p\n')" = "inactive" ] \
      && ok "an empty date grants nothing" || bad "an empty date grants nothing" "reported active"

    [ "$(gate_on 'provides|ghost|p|src|1| \nrequires|done-guard|p\n')" = "inactive" ] \
      && ok "a blank date grants nothing" || bad "a blank date grants nothing" "reported active"

    [ "$(gate_on 'provides|ghost|p| |1|2026-01-01\nrequires|done-guard|p\n')" = "inactive" ] \
      && ok "a blank source grants nothing" || bad "a blank source grants nothing" "reported active"

    [ "$(gate_on 'provides|ghost|p|src|1|2026-01-01|extra\nrequires|done-guard|p\n')" = "inactive" ] \
      && ok "a seven-field row grants nothing" \
      || bad "a seven-field row grants nothing" "reported active"

    # No trailing newline, and the asymmetry that makes it dangerous: a dropped trailing provides
    # row fails closed and gets noticed, a dropped trailing requires row fails open and does not.
    # This fixture drops a requires row naming a primitive nobody provides, so a resolver that
    # cannot see it reports the gate ACTIVE with an unmet requirement.
    [ "$(gate_on 'provides|ghost|p|src|1|2026-01-01\nrequires|done-guard|p\nrequires|done-guard|absent')" = "inactive" ] \
      && ok "a final row with no trailing newline is still read" \
      || bad "a final row with no trailing newline is still read" "reported active"

    # A gate with no requires row at all must be inactive. `found=1` is the only thing making that
    # true, and flipping it to 0 resolves every unknown gate ACTIVE on every harness, which is
    # the failure the hooks-directory loop above warns about. Nothing pinned it until now.
    harness_gate_active claude no-such-gate \
      && bad "a gate with no requires row is inactive" "reported active" \
      || ok "a gate with no requires row is inactive"

    [ "$(gate_on 'provides|ghost|p|src| |2026-01-01\nrequires|done-guard|p\n')" = "inactive" ] \
      && ok "a blank version grants nothing" || bad "a blank version grants nothing" "reported active"

    # A tab, not a space. Every fixture above uses a space, which lets `${1//[[:space:]]/}` in
    # _harness_present be weakened to `${1// /}` with the suite green. resolve.sh states that the
    # resolver and the validator must agree on what absent evidence means, and the validator learned
    # about tabs first, so without this the two drift apart in the direction that grants.
    [ "$(gate_on 'provides|ghost|p|src|\t|2026-01-01\nrequires|done-guard|p\n')" = "inactive" ] \
      && ok "a tab-only version grants nothing" || bad "a tab-only version grants nothing" "reported active"

    # The no-trailing-newline guard is on four separate loops and the gate_on fixture above pins
    # only harness_gate_active's. These two reach the other three: A ends on an unterminated
    # provides row, which only harness_provides and harness_known read, and B ends on an
    # unterminated requires row, which reaches harness_active_gates' own loop. B also crosses
    # harness_gate_active's loop, so it is A that isolates the two provides-side guards.
    nl_case() {   # nl_case <printf-escaped manifest>; echoes the resolved gate list
        local f
        f="$(mktemp)"
        printf '%b' "$1" > "$f"
        KEEL_CAPABILITIES="$f" harness_active_gates ghost | tr '\n' ' '
        rm -f "$f"
    }

    [ "$(nl_case 'requires|session-start|p\nprovides|ghost|p|src|1|2026-01-01')" = "session-start " ] \
      && ok "a final provides row with no trailing newline is still read" \
      || bad "a final provides row with no trailing newline is still read" "got: $(nl_case 'requires|session-start|p\nprovides|ghost|p|src|1|2026-01-01')"

    [ "$(nl_case 'provides|ghost|p|src|1|2026-01-01\nrequires|session-start|p')" = "session-start " ] \
      && ok "a final requires row with no trailing newline is still read" \
      || bad "a final requires row with no trailing newline is still read" "got: $(nl_case 'provides|ghost|p|src|1|2026-01-01\nrequires|session-start|p')"

    # The record-kind guards. There are four, not three: `[ "$f1" = "provides" ]` appears in both
    # harness_provides and harness_known, and `[ "$f1" = "requires" ]` in harness_gate_active and
    # harness_active_gates. They are what make keying on the first field mean anything, and all four
    # survived deletion with this suite green. Without the provides guard, any line whose pipe
    # fields happen to align grants a primitive, and this manifest's own format comment is exactly
    # such a line: it reads as harness <harness> providing <primitive>. Without the requires guard
    # in harness_gate_active, a comment doubles as a requirement. Without it in
    # harness_active_gates, a provides row is offered as a candidate gate, which changes the ORDER
    # gates come out in rather than the set of them. The assertion that pins that one says so where
    # it sits, because a comment here that counted its position would go stale the moment anything
    # was inserted between the two, which is exactly how this sentence was wrong before.
    # Line 1 is a six-field comment, so dropping the provides guard reads it as harness <harness>
    # providing <primitive>. Line 2 is a THREE-field comment, and it has to be three: with only
    # `read -r f1 f2 f3`, a six-field provides row puts `p|src|1|2026-01-01` in f3, the primitive
    # lookup fails, and the gate is refused whether the requires guard is there or not. Only a
    # three-field line reaches the fail-open. Note what that means in the real manifest:
    # prose in a comment that happens to mention a requires row would grant that gate, and comments
    # are exempt from malformed_rows, so nothing else would see it.
    kind="$(mktemp)"
    printf '%b' '# provides|<harness>|<primitive>|<source>|<version>|<date>\n# see requires|newgate|p\nprovides|aaa|p|src|1|2026-01-01\nrequires|bbb|p\n' > "$kind"

    KEEL_CAPABILITIES="$kind" harness_provides '<harness>' '<primitive>' \
      && bad "a comment is not a provides row" "granted a primitive from the format comment" \
      || ok "a comment is not a provides row"

    KEEL_CAPABILITIES="$kind" harness_gate_active aaa newgate \
      && bad "a comment is not a requires row" "resolved a gate named only inside a comment" \
      || ok "a comment is not a requires row"

    # The fourth guard, in harness_known, which the other three fixtures do not reach. Without it
    # any string in the second field of any row is a known harness, including <harness> from the
    # format comment. Task 3 gates the CLI on harness_known, so this is what stops
    # `keel harness done-guard` being accepted and then resolving to an empty gate list with status
    # zero, which reads as "this harness has no gates" rather than "there is no such harness".
    KEEL_CAPABILITIES="$kind" harness_active_gates '<harness>' >/dev/null 2>&1 \
      && bad "a comment does not make a harness known" "accepted a harness named only in a comment" \
      || ok "a comment does not make a harness known"
    rm -f "$kind"

    # Here gate aaa IS required, and later in the file than bbb. Drop the requires guard in
    # harness_active_gates and the provides row offers aaa as a candidate first, so aaa comes out
    # ahead of bbb. Only the ORDER changes, the set is the same, which is why this assertion does
    # not sort where every other one here does. That is also what distinguishes this guard from its
    # counterpart in harness_gate_active above: dropping that one suppresses aaa entirely.
    kind2="$(mktemp)"
    printf '%b' 'provides|aaa|p|src|1|2026-01-01\nrequires|bbb|p\nrequires|aaa|p\n' > "$kind2"
    kind_out="$(KEEL_CAPABILITIES="$kind2" harness_active_gates aaa | tr '\n' ' ')"
    [ "$kind_out" = "bbb aaa " ] \
      && ok "gates come from requires rows, in manifest order" \
      || bad "gates come from requires rows, in manifest order" "got: $kind_out"
    rm -f "$kind2"

    # The gate path must not need python3. Assert that against a PATH built to lack one: /usr/bin
    # carries /usr/bin/python3, so the obvious version of this test would prove nothing.
    stub="$(mktemp -d)"
    ln -s "$(command -v dirname)" "$stub/dirname"
    # `command -v` consults bash's hash table before PATH, so a python3 invoked earlier in this
    # shell would be found here and fail this control spuriously. Forget it and test PATH alone.
    hash -r
    PATH="$stub" command -v python3 >/dev/null 2>&1 \
      && bad "the stub PATH has no python3" "found one, so the next assertion proves nothing" \
      || ok "the stub PATH has no python3"
    # Resolve claude here, not codex. Nothing about this assertion is related to Codex, and pinning
    # it to Codex's gate list means task 14, which adds Codex probe rows, turns it red for a reason
    # that reads as unrelated to the change. Claude's list is the R-01 no-regression set and does
    # not move when a second harness gains a primitive.
    out="$(PATH="$stub" /bin/bash -c ". '$ROOT/lib/harness/resolve.sh'; harness_active_gates claude" 2>&1 | sort | tr '\n' ' ')"
    [ "$out" = "context-watch done-guard sensitive-guard session-start " ] \
      && ok "resolves with no python3 on PATH" \
      || bad "resolves with no python3 on PATH" "got: $out"
    rm -rf "$stub"
else
    bad "resolve.sh defines harness_active_gates" "function not found after sourcing"
fi
```

**The `source=` directive is `source-path=SCRIPTDIR/..` and not `source=../lib/...`.** Lint runs
from the repo root, where `../lib/harness/resolve.sh` resolves outside the repository and raises
SC1091, and `.keel/profile.json#shellcheck at default severity` records that CI lints that way, so an
info finding is a red build. `bin/keel:15` uses the same directive for the same reason.

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-harness-resolve.sh`
Expected: FAIL, "18 passed, 1 failed", the one failure being
"resolve.sh defines harness_active_gates: function not found after sourcing". Every one of the 18
cases that do not need the resolver must still pass here, the 16 from task 1 and the two manifest
well-formedness cases this task adds; if any of them fails, stop, because the manifest is not in
the state this task assumes.

- [x] **Step 3: Write the minimal implementation**

Create `lib/harness/resolve.sh`:

```bash
#!/usr/bin/env bash
# Resolve which gates are active on a harness, from lib/harness/capabilities.
#
# Pure bash on purpose. hooks/sensitive-guard sources this to decide whether it can do its job, and
# a gate that needs python3 to know whether it is a gate has the dependency in the wrong place.
#
# ADR-0003: a provides row grants its primitive only when source, version and date are all present.
# Absent evidence fails, never passes. Three ways a row can be absent evidence while looking
# populated, all of which resolved a gate ACTIVE in the first version of this file:
#   - a field holding only spaces is blank, not empty, and [ -n ] accepts it
#   - a row with more than six fields is malformed, and the sixth read variable swallows the rest
#   - a final row with no trailing newline is never seen at all, because read returns non-zero
# The last is the dangerous one: dropping a trailing `provides` row fails closed and gets noticed,
# dropping a trailing `requires` row fails OPEN and does not. `|| [ -n "$f1" ]` is what sees it.
# tests/test-harness-resolve.sh holds one fixture per case and a mutation test per check.

# A field is present only if it holds a non-space character. Same rule as provenance_gaps in
# tests/test-harness-resolve.sh, deliberately: the validator and the resolver disagreeing about
# what "absent evidence" means is how a row passes one and is granted by the other.
_harness_present() {
    [ -n "${1//[[:space:]]/}" ]
}

harness_capabilities_path() {
    # Set but empty is an error, not a fallback. A caller whose override path came out empty (an
    # unset lookup, a failed mktemp) must not silently resolve against the developer's own manifest
    # and be told every gate is active.
    if [ -n "${KEEL_CAPABILITIES+x}" ]; then
        [ -n "$KEEL_CAPABILITIES" ] || return 1
        printf '%s' "$KEEL_CAPABILITIES"; return 0
    fi
    printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/capabilities"
}

harness_provides() {
    [ $# -eq 2 ] || return 1
    local harness="$1" primitive="$2" cap f1 f2 f3 f4 f5 f6 f7
    cap="$(harness_capabilities_path)" || return 1
    [ -r "$cap" ] || return 1
    while IFS='|' read -r f1 f2 f3 f4 f5 f6 f7 || [ -n "$f1" ]; do
        [ "$f1" = "provides" ] || continue
        [ "$f2" = "$harness" ] || continue
        [ "$f3" = "$primitive" ] || continue
        [ -z "$f7" ] || continue
        _harness_present "$f4" || continue
        _harness_present "$f5" || continue
        _harness_present "$f6" || continue
        return 0
    done < "$cap"
    return 1
}

harness_known() {
    [ $# -eq 1 ] || return 1
    local harness="$1" cap f1 f2 rest
    cap="$(harness_capabilities_path)" || return 1
    [ -r "$cap" ] || return 1
    while IFS='|' read -r f1 f2 rest || [ -n "$f1" ]; do
        [ "$f1" = "provides" ] && [ "$f2" = "$harness" ] && return 0
    done < "$cap"
    return 1
}

harness_gate_active() {
    [ $# -eq 2 ] || return 1
    local harness="$1" gate="$2" cap f1 f2 f3 found=1
    cap="$(harness_capabilities_path)" || return 1
    [ -r "$cap" ] || return 1
    while IFS='|' read -r f1 f2 f3 || [ -n "$f1" ]; do
        [ "$f1" = "requires" ] || continue
        [ "$f2" = "$gate" ] || continue
        found=0
        harness_provides "$harness" "$f3" || return 1
    done < "$cap"
    return "$found"
}

harness_active_gates() {
    [ $# -eq 1 ] || return 1
    local harness="$1" cap f1 f2 rest seen=""
    harness_known "$harness" || return 1
    cap="$(harness_capabilities_path)" || return 1
    while IFS='|' read -r f1 f2 rest || [ -n "$f1" ]; do
        [ "$f1" = "requires" ] || continue
        case " $seen " in *" ${f2} "*) continue ;; esac
        seen="$seen $f2"
        harness_gate_active "$harness" "$f2" && printf '%s\n' "$f2"
    done < "$cap"
    return 0
}
```

Then widen the lint so the new directory is checked. **Edit one file: `.keel/profile.json`.** Change
`verify.lint` to insert `lib/harness/*.sh` after `lib/*.sh`:

```
shellcheck -x bin/keel lib/*.sh lib/harness/*.sh tests/*.sh tests/evals/run.sh tests/evals/stage.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard
```

**Then regenerate the managed block rather than editing it.** `CLAUDE.md:20` and `AGENTS.md:20` are
`{{VERIFY_LINT}}`, filled from the profile by `render_block` (`bin/keel#render_block() {`), and they sit
inside the keel-owned block at `CLAUDE.md:1-32` which is replaced wholesale on upgrade. keel
dogfoods itself, so re-running init is the supported way to re-render both:

```bash
bin/keel init -y
```

It merges rather than clobbering, so the project's own values survive. Confirm afterwards that both
files carry the widened command and that they are still byte-identical to each other:

```bash
grep -c 'lib/harness/\*\.sh' CLAUDE.md AGENTS.md   # expect 1 and 1
diff -q CLAUDE.md AGENTS.md                          # expect silence
```

**`bin/keel init -y` is known not to be idempotent on this repository**, and the first dispatch of
this task found exactly what it does. It rewrites `.claude/settings.json` (adding `Bash(curl *)`,
`Bash(wget *)` and `Bash(nc *)` to the deny list, and reflowing the SessionStart hook), it rewrites
`docs/prompting.md`'s trigger table, and **it bumps `keel_version` in `.keel/profile.json` from
0.15.0 to the running `bin/keel`'s version**. That last one is the trap, because `.keel/profile.json`
is a path this task legitimately stages. **Stage the `verify.lint` line and nothing else from that
file**: revert the `keel_version` bump, and leave the other two files alone entirely, unstaged. A
version bump is a release act and does not belong in a lint widening. Report all of it; do not
repair init, which is a change to the project's tooling and appears in no diff your reviewers see.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-harness-resolve.sh`
Expected: PASS, "41 passed, 0 failed". Then run `tests/run-tests.sh`, which now runs the widened
lint from the profile; expected "All test files passed" and "OK    shellcheck clean".

- [x] **Step 5: Hand over**

```bash
git add lib/harness/resolve.sh tests/test-harness-resolve.sh .keel/profile.json CLAUDE.md AGENTS.md
# CLAUDE.md and AGENTS.md are staged because init rewrote them, not because you edited them.
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(harness): resolve the active gate set in pure bash"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
name, say so and leave it unstaged. `.claude/settings.json` and `docs/prompting.md` will appear
there as modified and unstaged; that is init's doing, it is expected, and it stays unstaged.

---

### Task 2A: Rename the transcript primitives to schema-neutral capabilities

> **Done 2026-09-06, commit `0df87d4`.** Implemented by the coordinator directly, not dispatched: the harness this
> session runs under forbids subagents, and `skip-review-for-small-keel-repairs` covers a repair of
> this size by mutation sweep rather than by a reading pass. So **no reviewer signed this off**, and
> the check that stands in its place is a 17 mutant sweep, one mutation at a time, zero survivors.
> Step 2 was watched failing at 44 passed, 1 failed, on exactly the predicted case and with both
> regression assertions already passing. Step 4 landed at 45 passed, 0 failed.
>
> **One deviation from step 1, and it makes the step's own claim true.** Step 1 asked for two rows in
> the `fx` fixture, a space in `$5` and a tab in `$6`, and said all four listed weakenings would then
> turn red. They do not: `$4` weakened to `/^ *$/` still matches row c's space, so that mutation
> survives, and `$5` weakened to `/^ *$/` would survive a space in `$5` for the same reason. The
> fixture landed as three rows instead, a tab in `$4`, `$5` and `$6` on **separate** rows, because a
> row blank in two columns is printed by either disjunct and so pins neither. That is ten
> provenance mutants killed rather than four, and the space-in-`$5` row was dropped as redundant
> against the tab.
>
> **Added 2026-09-05, after task 2.** Task 1 shipped `transcript_jsonl_usage` and
> `transcript_jsonl_tool_use`. Splitting them was right and caught a real defect: `done-guard`
> resolved active on Codex on the strength of `stop_blocking` alone. Naming them after Claude Code's
> wire format was not. A primitive is a capability a gate cannot function without, and the harness
> that supplies it is free to supply it in its own shape. As named, Codex could not hold either row
> even after task 14 gives it a working parser, so Tier B would sit at one gate permanently and the
> manifest would be recording our schema rather than its capability.

**Story:** S-01, amending task 1
**Files:**
- Modify: `lib/harness/capabilities`
- Modify: `tests/test-harness-resolve.sh`
- Modify: `docs/architecture/tiered-multi-harness-support.md`

**Interfaces:**
- Consumes: `lib/harness/capabilities`, `lib/harness/resolve.sh`.
- Produces: no new interface. `transcript_jsonl_usage` becomes `transcript_turn_usage`, and
  `transcript_jsonl_tool_use` becomes `transcript_turn_tool_calls`. Two `provides` rows and two
  `requires` rows carry the names; nothing in the tree consumes them by name, verified by
  `grep -rn 'transcript_jsonl' .`, which matches only the manifest and two documents.

**Depends on:** task 2

**Done when:** `tests/test-harness-resolve.sh` passes, `tests/run-tests.sh` is green, and
`grep -rn 'transcript_jsonl' bin lib hooks tests` prints nothing. **Scoped to the tree, not to the
repository**, because this plan and the architecture doc both record the old names in history notes
that must keep saying what was true at the time; `docs/standards.md` on shipped prose versus
history. Rewriting those to satisfy a grep would delete the reason the rename happened.

- [x] **Step 1: Write the failing test**

**First, one repair carried over from task 2's reviews.** `provenance_gaps`, from task 1, has an
unpinned guard: deleting its `$5 ~ /^[[:space:]]*$/` disjunct leaves the suite green, because the
`fx` fixture has an empty-date row, a blank-source row and a seven-field row but no blank or empty
version row, while the assertion's own label claims it "fires on empty, blank and wrong-arity rows".
It was left out of task 2 as task 1's code rather than task 2's, and this task edits the same file.
Task 2's reviews found three of them, all in the same fixture and all the same shape: `fx` covers
`$4` with a space only, `$6` with an empty value only, and `$5` not at all, and no column with a tab.
So each of these mutations to `provenance_gaps` leaves the suite green: `$5 ~ /^[[:space:]]*$/`
deleted, `$6 ~ /^[[:space:]]*$/` weakened to `$6 == ""`, and either `$4` or `$6` weakened to
`/^ *$/`. Task 2 taught `_harness_present` and `malformed_rows` about tabs and left this validator
space-only, so `lib/harness/resolve.sh:17-19`'s "the validator and the resolver must agree on what
absent evidence means" is currently true of one validator and not the other.

Add two rows to the `fx` fixture, `provides|ghost|e|src| |2026-01-01` (blank version) and
`provides|ghost|f|src|1|\t` (tab date), and extend the expected value to
`"ghost/b ghost/c ghost/d ghost/e ghost/f "`. Confirm by mutation that each of the four listed
weakenings now turns the suite red.

**And one more of the same family, found in task 2's last review.** The `fx2` fixture's pinned line
list catches an insertion or a deletion, because either renumbers it. It does **not** catch in-place
degradation: change line 20's tab to a space and the suite stays green **while the `$3` tab mutation
silently stops being caught**, and the comment above still claims line 20 uses a tab. One invisible
character deletes real coverage. Add an assertion that the fixture itself still holds what the prose
says it holds, asserting the tab columns are tabs, and prove it fires by flipping one to a space.

Then append to `tests/test-harness-resolve.sh`, before the `printf '\n%s passed'` line:

```bash
# A primitive names a capability, never one harness's wire format. A name carrying a schema word
# cannot be satisfied by a second harness however much evidence that harness has, so it does not
# fail closed, it fails permanently. Tier B lost two gates by construction this way on 2026-09-05
# before the rename, which is the scar this assertion exists to keep.
schemaish="$(awk -F'|' '($1=="provides"||$1=="requires") && $3 ~ /jsonl|_json|message|content/ {print $3}' "$CAP" | sort -u | tr '\n' ' ')"
[ -z "$schemaish" ] && ok "no primitive name encodes a harness wire format" \
  || bad "no primitive name encodes a harness wire format" "$schemaish"

# The rename must not move a single gate. These two repeat assertions made earlier in this file on
# purpose: they are the regression guard, and a rename that changes either of them is a rename that
# dropped a requires row.
[ "$(harness_active_gates claude | sort | tr '\n' ' ')" = "context-watch done-guard sensitive-guard session-start " ] \
  && ok "the rename left claude at four gates" \
  || bad "the rename left claude at four gates" "$(harness_active_gates claude | sort | tr '\n' ' ')"
[ "$(harness_active_gates codex | sort | tr '\n' ' ')" = "session-start " ] \
  && ok "the rename left codex at session-start alone" \
  || bad "the rename left codex at session-start alone" "$(harness_active_gates codex | sort | tr '\n' ' ')"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-harness-resolve.sh`
Expected: FAIL, exactly one case, "no primitive name encodes a harness wire format:
transcript_jsonl_tool_use transcript_jsonl_usage". The two regression assertions must PASS before
the rename, or they are not a regression guard: if either fails here, stop, because the manifest is
not in the state this task assumes.

- [x] **Step 3: Write the minimal implementation**

In `lib/harness/capabilities`, rename in all four places, two `provides` rows and two `requires`
rows:

- `transcript_jsonl_usage` becomes `transcript_turn_usage`
- `transcript_jsonl_tool_use` becomes `transcript_turn_tool_calls`

**Leave every `<source>`, `<version>` and `<date>` field exactly as it is.** The Claude probe text
describes `message.usage` and `content[]` blocks, and that stays correct: it is the evidence that
Claude Code provides the capability, in Claude Code's shape. Moving the schema out of the primitive
name and leaving it in the evidence is the whole point of the rename.

Then rewrite the header comment block that currently begins `WHY THERE ARE THREE TRANSCRIPT
PRIMITIVES` so it says what is now true. It must state, and these are the load-bearing sentences:

- The three primitives are still three, and still for the reasons given: a path, per-turn token
  usage, and the turn's tool calls with a subagent marker are three different promises, and none
  implies another.
- **A primitive is a capability, and the `<source>` field is where the harness-specific shape
  belongs.** Two harnesses may satisfy `transcript_turn_usage` with completely different formats and
  both rows are honest; that is what `lib/context_watch.py`'s two parsers exist to absorb.
- Codex holds `transcript_path` and neither of the other two **today**, so `done-guard` and
  `context-watch` resolve inactive there. Task 14 is what earns them, by landing the parsers and
  recording a `probe:` row against a real captured Codex transcript. Until that row exists, ADR-0003
  says the gate is inactive, and the support page says so too.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-harness-resolve.sh`, expected PASS on all cases including the three new ones. Then
`tests/run-tests.sh`, expected "All test files passed" and "OK    shellcheck clean". Then
`grep -rn 'transcript_jsonl' bin lib hooks tests`, expected no output and exit status 1.

- [x] **Step 5: Hand over**

Update `docs/architecture/tiered-multi-harness-support.md`: the two places naming the old primitives
take the new names, and **R-02's "Tier B is three gates" gains the sentence that makes it checkable**,
that the count holds once task 14 records Codex's `transcript_turn_usage` and
`transcript_turn_tool_calls` rows, and that the manifest is what decides it rather than this
document. Documentation lands with the change, not after: `docs/standards.md`.

```bash
git add lib/harness/capabilities tests/test-harness-resolve.sh docs/architecture/tiered-multi-harness-support.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "refactor(harness): name transcript primitives by capability, not by wire format"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.

---

### Task 3: Generate the per-harness hook manifests from the capability manifest

> **Runs after task 14, not before it.** See the execution order in the header. This task's Codex
> assertions expect `session-start`, `done-guard` and `context-watch`, which is true only once task
> 14 has recorded Codex's two transcript rows. Dispatched before task 14 it fails, and "fixing" it
> by registering gates the manifest does not grant is the exact failure this plan exists to prevent.

**Story:** S-08
**Files:**
- Create: `tests/generate-harness-artifacts.sh`
- Create: `hooks/hooks.codex.json`
- Modify: `tests/test-harness-resolve.sh`
- Modify: `.gitignore` (no change expected; confirm the generated files are not ignored)

**Interfaces:**
- Consumes: `harness_active_gates`, from task 2.
- Produces: `tests/generate-harness-artifacts.sh <harness>` printing that harness's hook manifest to
  stdout; `hooks/hooks.codex.json`, generated and checked in.

**Depends on:** task 2

**Done when:** `tests/test-harness-resolve.sh` passes and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

Append to `tests/test-harness-resolve.sh`, before the `printf '\n%s passed'` line:

```bash
GEN="$ROOT/tests/generate-harness-artifacts.sh"

if [ -x "$GEN" ]; then
    # R-01: the Claude Code manifest must come out of the generator byte for byte as committed.
    if diff -q <("$GEN" claude) "$ROOT/hooks/hooks.json" >/dev/null 2>&1; then
        ok "generated claude manifest is byte-identical to hooks/hooks.json"
    else
        bad "generated claude manifest is byte-identical to hooks/hooks.json" "$( "$GEN" claude | diff - "$ROOT/hooks/hooks.json" | head -5 | tr '\n' ' ' )"
    fi

    diff -q <("$GEN" codex) "$ROOT/hooks/hooks.codex.json" >/dev/null 2>&1 \
      && ok "hooks/hooks.codex.json is not stale" \
      || bad "hooks/hooks.codex.json is not stale" "regenerate it"

    grep -q 'sensitive-guard' "$ROOT/hooks/hooks.codex.json" 2>/dev/null \
      && bad "codex manifest omits sensitive-guard" "an entry is present" \
      || ok "codex manifest omits sensitive-guard"

    for g in session-start done-guard context-watch; do
        grep -q "$g" "$ROOT/hooks/hooks.codex.json" 2>/dev/null \
          && ok "codex manifest registers $g" \
          || bad "codex manifest registers $g" "no entry"
    done

    # The exit-2 control path and the Stop decision path both need a synchronous hook.
    # codex-rs/hooks/src/engine/mod.rs:141-156. A silent flip here makes every gate advisory.
    for f in "$ROOT/hooks/hooks.json" "$ROOT/hooks/hooks.codex.json"; do
        n_hooks="$(grep -c '"type": "command"' "$f")"
        n_sync="$(grep -c '"async": false' "$f")"
        [ "$n_hooks" = "$n_sync" ] \
          && ok "$(basename "$f") pins async false on all $n_hooks entries" \
          || bad "$(basename "$f") pins async false on all entries" "$n_hooks commands, $n_sync synchronous"
    done
else
    bad "tests/generate-harness-artifacts.sh is executable" "not found or not executable"
fi
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-harness-resolve.sh`
Expected: FAIL, "tests/generate-harness-artifacts.sh is executable: not found or not executable".

- [x] **Step 3: Write the minimal implementation**

Create `tests/generate-harness-artifacts.sh`, `chmod +x` it:

```bash
#!/usr/bin/env bash
# Generate a harness's hook manifest from lib/harness/capabilities.
#
# Generated rather than written because four things have to agree about which gates a harness gets,
# and a hand-maintained copy is the fourth one that goes stale. A stale file is a failing build here,
# the same bargain tests/generate-profile-keys.sh makes for docs/profile-keys.md.
#
# Deterministic by construction: no date, no path, no counter, nothing from the environment.
#
# Usage: tests/generate-harness-artifacts.sh claude > hooks/hooks.json
#        tests/generate-harness-artifacts.sh codex  > hooks/hooks.codex.json
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/harness/resolve.sh
. "$ROOT/lib/harness/resolve.sh"

harness="${1:-}"
[ -n "$harness" ] || { printf 'usage: %s <harness>\n' "$0" >&2; exit 1; }
harness_known "$harness" || { printf 'unknown harness: %s\n' "$harness" >&2; exit 1; }

active="$(harness_active_gates "$harness")"
is_active() { printf '%s\n' "$active" | grep -qx "$1"; }

# One entry, at the indentation hooks/hooks.json already uses. `async` is false on every entry and
# is not a parameter: a hook that cannot apply control effects is advisory, and an advisory
# sensitive-guard or done-guard is the failure this whole design exists to prevent.
entry() {
    local hook="$1" timeout="$2"
    cat <<ENTRY
          {
            "type": "command",
            "command": "\\"\${CLAUDE_PLUGIN_ROOT}/hooks/$hook\\"",
            "shell": "bash",
            "async": false,
            "timeout": $timeout
          }
ENTRY
}
```

The remainder emits the document, including only the events whose gate is active, in the order
`hooks/hooks.json` already uses. `context-watch` registers on three events and `done-guard` on two,
which is why the event list and the gate list are not the same length:

**`PreToolUse` carries two matcher groups, not one**, and an emitter that assumes one group per
event structurally cannot reproduce `hooks/hooks.json`. Groups are emitted separately from events:

```bash
first_event=1
open_event() { [ "$first_event" = 1 ] || printf ',\n'; first_event=0; printf '    "%s": [\n' "$1"; first_group=1; }
close_event() { printf '\n    ]'; }
group() {   # gate, hook, timeout, [matcher]
    is_active "$1" || return 0
    [ "$first_group" = 1 ] || printf ',\n'
    first_group=0
    printf '      {\n'
    [ -n "${4:-}" ] && printf '        "matcher": "%s",\n' "$4"
    printf '        "hooks": [\n'
    entry "$2" "$3"
    printf '        ]\n      }'
}

printf '{\n  "hooks": {\n'
open_event SessionStart;     group session-start  session-start 30 "startup|clear|compact"; close_event
open_event UserPromptSubmit; group context-watch  context-watch 10;                          close_event
open_event PreToolUse;       group context-watch  context-watch 10
                             group sensitive-guard sensitive-guard 10 "Bash";                close_event
open_event Stop;             group done-guard     done-guard    10;                          close_event
open_event SubagentStop;     group done-guard     done-guard    10;                          close_event
open_event PreCompact;       group context-watch  context-watch 10;                          close_event
printf '\n  }\n}\n'
```

The `sensitive-guard` group returns early on Codex because `is_active` is false there, which is what
keeps it out of that manifest with no conditional anybody has to remember. **An event whose every
group is inactive still emits an empty array**, which `hooks/hooks.json` never contains; guard
`open_event` on at least one active gate, or emit events into a buffer and drop the empty ones.

**Step 4's byte-identity case is the specification.** Adjust the emitters until
`tests/generate-harness-artifacts.sh claude` reproduces the committed file exactly. If it cannot,
the difference is a fact about `hooks/hooks.json` worth knowing, not a reason to relax the test.

Then generate the Codex manifest:

```bash
tests/generate-harness-artifacts.sh codex > hooks/hooks.codex.json
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-harness-resolve.sh`
Expected: PASS on every case, including "generated claude manifest is byte-identical to
hooks/hooks.json". Then run `tests/run-tests.sh`; nothing else may break.

- [x] **Step 5: Hand over**

```bash
git add tests/generate-harness-artifacts.sh hooks/hooks.codex.json tests/test-harness-resolve.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(harness): generate per-harness hook manifests from the capability manifest"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.

---

> **DONE 2026-09-06, inline.** `tests/generate-harness-artifacts.sh claude` reproduces
> `hooks/hooks.json` byte for byte, `hooks/hooks.codex.json` is generated and committed with six
> entries and no `sensitive-guard`, and `tests/run-tests.sh` is green. Three things to record:
>
> 1. **The Files list is short by two, and the missing pair is a guard this task trips.**
>    `tests/supply-chain-scan.sh` carries a `structural-orphan-hook` rule that flags any file under
>    `hooks/` not named in `hooks/hooks.json`, exempting `hooks.json` itself **by name**. Generating
>    a second manifest turned the run red on a correct tree. The rule was fixed rather than
>    suppressed, in both directions, because reading one manifest gets two things wrong: a manifest
>    is not an orphan hook, and **a hook registered only on the second harness is registered**. The
>    latter is a false stop waiting for the first gate that is Codex-only, and a check that cries
>    wolf on a correct tree is the one people learn to ignore. Exemption is now by shape rather than
>    by name, so the third manifest does not do this again. `tests/test-supply-chain.sh` gains a
>    case for each direction, 44 assertions to 46.
> 2. **The emitters buffer the document rather than streaming it**, which is what the step's warning
>    about empty arrays requires: an event's emptiness is only known after all its groups have run.
>    A `first_event`/`first_group` pair of globals cannot decide it. No event is empty on Codex
>    today, since sensitive-guard shares `PreToolUse` with context-watch, so the case is pinned by
>    generating against a manifest with `transcript_turn_tool_calls` cut out and asserting the result
>    is still valid JSON with no empty array.
> 3. **`set -e` already refuses an unknown harness**, because `harness_active_gates` returns 1 and
>    the assignment carries that out. So the explicit `harness_known` check earns its keep through
>    its message alone, and the step's status-only assertion passed with the guard deleted. The case
>    now greps the message. Found by the sweep, not by reading.
>
> **Reviewed by a 10 mutant sweep, one guard at a time, zero survivors**, for the reason task 14
> records: this harness forbids subagents. The plan's two review passes still stand wherever they
> can be run.

---

### Task 4: Fail the build on a stale artifact, a thin manifest row, or an async flag

**Story:** S-12
**Files:**
- Create: `tests/test-harness-claims.sh`
- Modify: `tests/run-tests.sh`

**Interfaces:**
- Consumes: `tests/generate-harness-artifacts.sh`, from task 3.
- Produces: `tests/test-harness-claims.sh`, extended by task 5.

**Depends on:** task 3

**Done when:** `tests/test-harness-claims.sh` passes and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

Create `tests/test-harness-claims.sh`, `chmod +x` it:

```bash
#!/usr/bin/env bash
# Does what keel says about a harness match what keel does on it.
#
# Separate from tests/test-doc-claims.sh deliberately. That file compares a number in a sentence
# against a count derived from the tree, and says so in its own header. Harness support is not a
# count: it is a claim checked against a capability matrix, which is a different question, and
# bundling them would dilute a file whose coherence is the reason it is trusted.
#
# shellcheck disable=SC2015  # see tests/test-harness-resolve.sh for why.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
pass=0; fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }

GEN=tests/generate-harness-artifacts.sh

# 1. A generated artifact that has been hand-edited is stale, and stale is a failing build.
for pair in "claude:hooks/hooks.json" "codex:hooks/hooks.codex.json"; do
    h="${pair%%:*}"; f="${pair#*:}"
    if diff -q <("$GEN" "$h") "$f" >/dev/null 2>&1; then
        ok "$f matches the generator"
    else
        bad "$f matches the generator" "hand-edited or stale. Run: $GEN $h > $f"
    fi
done

# 2. ADR-0003: absent evidence fails. A provides row without source, version and date grants nothing,
# so a row that looks like a capability and is not one must be caught here rather than trusted.
thin="$(awk -F'|' '$1=="provides" && ($4=="" || $5=="" || $6=="") {print $2"/"$3}' lib/harness/capabilities)"
[ -z "$thin" ] && ok "every capability row carries source, version and date" \
  || bad "every capability row carries source, version and date" "$thin"

# 3. async false on every command entry, in both manifests.
#
# This is the quietest way this design can fail. codex-rs/hooks/src/engine/mod.rs:141-156 gates
# every control effect on the hook being synchronous, and that gate covers the exit-2 path in
# pre_tool_use.rs AND the stdout decision path in stop.rs. Flip this one flag and sensitive-guard
# stops blocking and done-guard stops holding the turn open, while both stay installed, registered
# and reported as present. Nothing else in the suite would notice.
for f in hooks/hooks.json hooks/hooks.codex.json; do
    n_cmd="$(grep -c '"type": "command"' "$f")"
    n_sync="$(grep -c '"async": false' "$f")"
    [ "$n_cmd" = "$n_sync" ] \
      && ok "$f: all $n_cmd command hooks are synchronous" \
      || bad "$f: all command hooks are synchronous" "$n_cmd commands, $n_sync with async false"
done

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

Add it to the runner, after the `add "tests/test-harness-resolve.sh"` line:

```bash
add "tests/test-harness-claims.sh"   "tests/test-harness-claims.sh"
```

- [x] **Step 2: Run it and watch it fail**

Before creating the file, run: `tests/test-harness-claims.sh`
Expected: FAIL, "no such file or directory".

Then create it as above and prove the staleness case can fail **without editing the committed file**.
`tests/run-tests.sh` runs up to four test files at once (`:65`, `MAX_JOBS=4`), so a task that mutates
a tracked file mid-run corrupts whatever another job is reading. Point the check at a copy instead:

```bash
cp hooks/hooks.codex.json /tmp/stale.json && printf '\n' >> /tmp/stale.json
diff -q <(tests/generate-harness-artifacts.sh codex) /tmp/stale.json
```

Expected: `differ`. That is the comparison the case makes, proven on a copy, and the tracked file is
never touched.

- [x] **Step 3: Write the minimal implementation**

There is no implementation beyond the test and its runner entry. This task's deliverable is the
check itself; tasks 1 to 3 already produced what it checks. Restore
`hooks/hooks.codex.json` with `tests/generate-harness-artifacts.sh codex > hooks/hooks.codex.json`
if step 2 left it edited.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-harness-claims.sh`
Expected: PASS, "5 passed, 0 failed". Then run `tests/run-tests.sh`; expected "All test files passed".

- [x] **Step 5: Hand over**

```bash
git add tests/test-harness-claims.sh tests/run-tests.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "test(harness): fail on a stale artifact, a thin capability row or an async hook"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.

---

> **DONE 2026-09-06, inline.** `tests/test-harness-claims.sh` is created, executable and in the
> runner. **8 passed, not the 5 step 4 expects**, and the three extra cases are the point rather
> than padding.
>
> 1. **Check 2's predicate as written is weaker than the resolver's, in the two ways this repository
>    has already been bitten by.** `$4=="" || $5=="" || $6==""` passes a field holding one space and
>    passes a seven-field row outright, both of which `lib/harness/resolve.sh` refuses. So the check
>    and the thing it checks would have disagreed about what "absent evidence" means, in the
>    direction where this file calls a row good that grants nothing. It now uses the resolver's
>    predicate character for character, and carries the same seven-row fixture proving it fires.
> 2. **Two of the three checks could not fail, and a sweep is what showed it.** Replacing the
>    staleness `diff` with `true`, and the async comparison with a comparison of a number against
>    itself, left the file green: the committed artifacts are correct, so a check that compares
>    nothing passes every case. That is exactly the hazard this file is named for, applied to
>    itself. Both are now predicates with a case that fires them, the staleness one **on a copy**
>    per step 2, because the runner runs four files at once and a case that edited a tracked file
>    mid-run would corrupt another job's read.
> 3. **`cd "$ROOT"` needs `|| exit`.** Every path in the file is relative to the root, and
>    shellcheck fails the lint gate on the bare form, so the sketch as given does not pass this
>    project's own lint.
>
> The file overlaps `tests/test-harness-resolve.sh` on staleness and async, and the overlap is kept
> deliberately: that file proves the **generator** is correct, this one proves the **committed
> artifact** is not stale. They coincide only while nobody hand-edits an artifact, which is the case
> this file exists for. Both headers say so.
>
> **Reviewed by a 9 mutant sweep, one guard at a time, zero survivors**, six against the artifacts
> and the manifest and three against the checks themselves. Two review passes not run, per task 14.

---

### Task 5: Fail the build when a document claims more than the manifest grants

**Story:** S-13
**Files:**
- Modify: `tests/test-harness-claims.sh`
- Modify: `lib/harness/capabilities`

**Interfaces:**
- Consumes: `harness_provides`, from task 2.
- Produces: the claim tag syntax `<!-- keel:claim gate=<gate> harness=<harness> -->` and
  `<!-- keel:claim property=<primitive> harness=<harness> -->`, which task 6 and task 17 both use.

**Depends on:** task 4

**Done when:** `tests/test-harness-claims.sh` passes and `tests/run-tests.sh` is green.

**This task must land before task 6.** Task 6 repairs the documents this check polices. Repairing
first and adding the check afterwards leaves a window in which the repairs are unverified, which is
the drift the whole design exists to close.

- [x] **Step 1: Write the failing test**

First add the capability row this check needs, to `lib/harness/capabilities`, in the claude block:

```
provides|claude|validated_word_ceiling|docs/decisions/ADR-0001-skill-body-word-ceiling.md|0.18.0|2026-09-05
```

**There is deliberately no codex row.** ADR-0001's 900-word ceiling and its 44-tokens-per-description
figure were calibrated against Claude Code's preload mechanism. Codex budgets a share of the context
window instead and silently shortens or drops descriptions under pressure, so the ceiling is
inherited and unvalidated there until S-19 measures it. **S-19 is deferred and its hazard is live
from the first Tier B release**, which is why the guard ships here and not with the story: any
document that says the ceiling holds on Codex is making a false claim today.

Append to `tests/test-harness-claims.sh`, before the `printf '\n%s passed'` line:

```bash
# shellcheck source=../lib/harness/resolve.sh
. lib/harness/resolve.sh

# Documents in scope: what a reader takes as current truth about keel. That is README, the numbered
# documents at the top of docs/, and the runbooks.
#
# Everything in a subdirectory except runbooks is out, and the reason is the same for all of them:
# they are dated records rather than claims. docs/ideas and docs/plans state what was believed on a
# day; docs/decisions are append-only by ADR rule; docs/architecture describes a mechanism, and gate
# names are its subject matter, so scanning it would demand a claim tag on almost every paragraph
# and teach everybody to tag reflexively, which is how a check stops meaning anything. docs/prd,
# docs/stories and docs/audits are the same case.
# NOT a `case` glob. In a `case` pattern `*` crosses `/`, so `docs/*.md` matches
# `docs/prd/context-window-at-init.md` and sweeps 60 lines of dated PRD and story text into a check
# about current truth. Measured before this was written. Depth is counted instead.
in_scope() {
    local f="$1" depth
    [ "$f" = README.md ] && return 0
    case "$f" in docs/runbooks/*.md) return 0 ;; esac
    case "$f" in docs/*) ;; *) return 1 ;; esac
    depth="$(printf '%s' "$f" | tr -cd '/' | wc -c)"
    [ "$depth" -eq 1 ] || return 1          # docs/NN-name.md only, never docs/sub/name.md
    case "$f" in *.md) return 0 ;; *) return 1 ;; esac
}

# 4. Every tagged claim is granted by the manifest.
bad_claims=""
while IFS= read -r f; do
    in_scope "$f" || continue
    while IFS= read -r tag; do
        subject="$(printf '%s' "$tag" | sed -n 's/.*\(gate\|property\)=\([A-Za-z0-9_-]*\).*/\2/p')"
        kind="$(printf '%s' "$tag" | sed -n 's/.*\(gate\|property\)=.*/\1/p')"
        harness="$(printf '%s' "$tag" | sed -n 's/.*harness=\([A-Za-z0-9_-]*\).*/\1/p')"
        [ -n "$subject" ] && [ -n "$harness" ] || { bad_claims="$bad_claims $f:malformed"; continue; }
        if [ "$kind" = gate ]; then
            harness_gate_active "$harness" "$subject" || bad_claims="$bad_claims $f:$harness/$subject"
        else
            harness_provides "$harness" "$subject" || bad_claims="$bad_claims $f:$harness/$subject"
        fi
    done < <(grep -o '<!-- keel:claim [^>]*-->' "$f" 2>/dev/null)
done < <(git ls-files '*.md')
[ -z "$bad_claims" ] && ok "every tagged claim is granted by the capability manifest" \
  || bad "every tagged claim is granted by the capability manifest" "$bad_claims"

# 5. A sentence using gate or ceiling vocabulary with no claim tag is an unregistered claim.
#
# Two-sided on purpose. The registry above catches a wrong claim and cannot see a new one; this scan
# catches a new one and cannot judge it. A prose regex is a technique tests/test-doc-claims.sh:1-16
# rejects for judging claims, and it is not judging: its only question is whether somebody
# registered the sentence, which is coarse enough for a regex to answer honestly.
VOCAB='sensitive-guard|done-guard|context-watch|session-start|hard_block_paths|900-word|word ceiling|description budget'
untagged=""
while IFS= read -r f; do
    in_scope "$f" || continue
    while IFS= read -r hit; do
        n="${hit%%:*}"
        line="$(sed -n "${n}p" "$f")"
        case "$line" in *'keel:claim'*) continue ;; esac
        # Look back three lines, not one. A tagged claim is prose and wraps, and a lookback of one
        # line fails any claim longer than two lines, including the support page's own paragraph.
        tagged=""
        for back in 1 2 3; do
            prev="$(sed -n "$((n-back))p" "$f" 2>/dev/null)"
            case "$prev" in *'keel:claim'*) tagged=yes; break ;; esac
        done
        [ -n "$tagged" ] && continue
        untagged="$untagged $f:$n"
    done < <(grep -nE "$VOCAB" "$f" 2>/dev/null | cut -d: -f1 | sed 's/$/:/')
done < <(git ls-files '*.md')
[ -z "$untagged" ] && ok "no unregistered harness claim in a document in scope" \
  || bad "no unregistered harness claim in a document in scope" "$untagged"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-harness-claims.sh`
Expected: FAIL on "no unregistered harness claim in a document in scope", listing many locations,
because no document has been tagged yet. That failure is the inventory task 6 works through.

Then prove the registry case fires. Add this line temporarily to `README.md`:

```markdown
<!-- keel:claim gate=sensitive-guard harness=codex -->
```

Run: `tests/test-harness-claims.sh`
Expected: FAIL, "every tagged claim is granted by the capability manifest: README.md:codex/sensitive-guard".
Remove the line.

Then prove the ceiling guard fires, which is the S-19 hazard. Add temporarily to `README.md`:

```markdown
<!-- keel:claim property=validated_word_ceiling harness=codex -->
The 900-word ceiling is validated on both harnesses.
```

Run: `tests/test-harness-claims.sh`
Expected: FAIL, "every tagged claim is granted by the capability manifest:
README.md:codex/validated_word_ceiling". Remove both lines.

- [x] **Step 3: Write the minimal implementation**

There is no implementation beyond the check and the capability row. The failures step 2 produced are
real and are task 6's work; do not silence them here.

- [x] **Step 4: Run it and watch it pass**

`tests/test-harness-claims.sh` **will still fail** on the unregistered-claim case until task 6 lands,
and that is correct. Verify instead that the four cases from task 4 and the registry case from this
task pass, and that the only failure is the unregistered-claim scan.

Run: `tests/test-harness-claims.sh`
Expected: one failure, "no unregistered harness claim in a document in scope", and no other.

Run: `tests/run-tests.sh`
Expected: **red**, on `tests/test-harness-claims.sh` only. Record that in the hand-over. This is the
one task in the plan that lands with the suite red on purpose, because the check must exist before
the repairs it polices. Task 6 turns it green.

- [x] **Step 5: Hand over**

```bash
git add tests/test-harness-claims.sh lib/harness/capabilities
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** Tell the coordinator explicitly that the
suite is red on `tests/test-harness-claims.sh` and why, so it is not read as a broken task. The
coordinator commits after both review passes, with
`git commit -m "test(harness): fail on a document claiming more than the manifest grants"`.

---

> **DONE 2026-09-06, inline, and the suite is RED on purpose.** `tests/test-harness-claims.sh` is
> **12 passed, 1 failed**, and `tests/run-tests.sh` reports exactly one failing file. The single
> failure is `no unregistered harness claim in a document in scope`, listing 23 locations across
> `README.md`, `docs/05`, `docs/06`, `docs/07`, `docs/profile-keys.md` and `docs/standards.md`.
> **That list is task 6's inventory and must not be silenced here.**
>
> Four things the steps did not have right:
>
> 1. **The capability row breaks two of the manifest's own rules as written.** Its `<source>` has no
>    `vendor:` or `probe:` prefix, which `tests/test-harness-resolve.sh:66` fails outright, and its
>    `<version>` is `0.18.0`, which is **keel's** version where the file's header says the column is
>    the harness's and that `keel doctor`'s comparison means nothing if keel's goes there. The row
>    landed as a `probe:` citing ADR-0001 and `tests/evals/results.md` at "Both bodies over the 700
>    word target", at `2.1.261` like every other claude row. The manifest header gained a paragraph
>    explaining why a keel-tree source is honest for **this** primitive and not for the others:
>    `validated_word_ceiling` asks whether keel's own ceiling has been measured on a harness, not
>    what the harness does, so an arm we ran is an observation recorded, which is what `probe:` means.
> 2. **The tag parser used GNU-only regex and would have failed on every tag.** `sed -n
>    's/.*\(gate\|property\)=...'` is a basic regex, and BSD sed has no alternation in BRE, so on
>    macOS every field came out empty and every tag read as `malformed`. It fails closed, which is
>    the safe direction, but it would have made task 6 impossible: every tag that task adds would
>    have been rejected. **Invisible to the case the step supplies**, which passes today only because
>    no document in scope carries a tag yet. Found by the fires-fixture, `sed -E` now.
> 3. **Both checks were unfireable in the same way task 4's were**, so both are predicates over an
>    argument list with a fixture that fires them. The registry fixture covers a withheld gate, an
>    unvalidated property and a malformed tag; the vocabulary fixture puts a claim exactly three
>    lines under its tag, the furthest the lookback reaches, so shortening the lookback reports a
>    correctly tagged document.
> 4. **`in_scope` had nothing pinning it.** Widening the scope only adds findings to a case designed
>    to report none, so the `case`-glob mistake the comment warns about could be reintroduced
>    silently once task 6 turns the scan green. There is a direct assertion on it now.
>
> **Reviewed by a 10 mutant sweep, one guard at a time, zero survivors.** The sweep asserts the
> NAMED case flips from PASS, not that the file goes red, because the file is red by design.

---

### Task 6: Generate the support page and repair every sentence that stops being true

> **One sentence task 14 made incomplete on 2026-09-06, left here rather than repaired then.** The
> `gates.context_window` description in `templates/profile.schema.json` says "A value at or below
> 200000 has no effect, because a floor only ever raises". That is a Claude Code number. A Codex
> rollout states `model_context_window`, 258400 on the probed session, so on Codex the floor has no
> effect below that instead. The sentence is not false, it is a repository-wide statement of a
> `(repository, harness)` property, which is what ADR-0004 forbids and what task 5 exists to catch.
> It was not repaired in task 14 on purpose: this plan's critical path says the document repairs
> must not start before task 5 can police them, and repairing it early is exactly the unverified
> window that ordering closes. **Check that task 5 fails the build on this sentence before task 6
> rewrites it.** `docs/profile-keys.md` is generated from the same description and follows it.

**Story:** S-14
**Files:**
- Modify: `tests/generate-harness-artifacts.sh`
- Create: `docs/harness-support.md`
- Modify: `README.md`, `docs/01-architecture.md`, `docs/02-skill-catalog.md`,
  `docs/03-install-and-distribution.md`, `docs/04-plugin-strategy.md`,
  `docs/05-token-and-memory-design.md`, `docs/07-open-decisions.md`, `docs/profile-keys.md`
- Modify: `tests/test-harness-claims.sh`

**Interfaces:**
- Consumes: the claim tag syntax, from task 5; `harness_active_gates`, from task 2.
- Produces: `docs/harness-support.md`, generated, and the tier table it carries.

**Depends on:** task 5

**Done when:** `tests/test-harness-claims.sh` passes with no failures and `tests/run-tests.sh` is
green.

- [x] **Step 1: Write the failing test**

Append to `tests/test-harness-claims.sh`, before the `printf '\n%s passed'` line:

```bash
# 6. The support page is generated, not written, and is not stale.
if diff -q <("$GEN" support-page) docs/harness-support.md >/dev/null 2>&1; then
    ok "docs/harness-support.md matches the generator"
else
    bad "docs/harness-support.md matches the generator" "run: $GEN support-page > docs/harness-support.md"
fi

# 7. It says what Tier B cannot claim, once, where everything else points.
for phrase in 'sensitive-guard' 'not enforced' 'Codex'; do
    grep -q "$phrase" docs/harness-support.md 2>/dev/null \
      && ok "support page mentions $phrase" \
      || bad "support page mentions $phrase" "absent"
done
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-harness-claims.sh`
Expected: FAIL on "docs/harness-support.md matches the generator", plus the unregistered-claim
failure inherited from task 5.

- [x] **Step 3: Write the minimal implementation**

Extend `tests/generate-harness-artifacts.sh` with a `support-page` mode. **Step 1 asserts byte
identity, so the format is the specification and has to be fixed here rather than left to taste.**
Emit exactly this, from `lib/harness/capabilities` alone, in this order:

1. `# Harness support` as the H1.
2. The sentence `Generated by tests/generate-harness-artifacts.sh. Do not edit by hand.`, which is
   the same self-identifying line `docs/profile-keys.md` carries and which
   `tests/test-profile-keys.sh:82-83` exists to enforce.
3. `## Gates`, then a table whose columns are `| Gate | claude | codex |` in that order, harnesses
   sorted by first appearance in the manifest, gates sorted by first `requires` row. Cells are `yes`
   or `no`, lower case, nothing else.
4. **A claim tag on the line immediately above each gate row**, `<!-- keel:claim gate=<gate>
   harness=<harness> -->` for every harness whose cell is `yes`. Without this the page fails the
   check it exists to serve, because `docs/*.md` at depth one is in scope and every row names a gate.
5. `## Provenance`, then `| Harness | Primitive | Source | Version | Checked |`, one row per
   `provides` record, in manifest order.
6. `## What Tier B cannot claim`, then the paragraph below, verbatim.

```markdown
## What Tier B cannot claim

<!-- keel:claim gate=sensitive-guard harness=claude -->
Codex CLI does not provide a way for a hook to put a command to a human. keel's hard block on
`hard_block_paths` is therefore absent on Codex, not degraded, and `keel init` registers nothing for
it there. A repository that declares `hard_block_paths` and serves Codex is protected for its Claude
Code users and not for its Codex users, and `keel doctor` says so on every run.
```

```markdown
## What Tier B cannot claim

<!-- keel:claim gate=sensitive-guard harness=claude -->
Codex CLI does not provide a way for a hook to put a command to a human. keel's hard block on
`hard_block_paths` is therefore absent on Codex, not degraded, and `keel init` registers nothing for
it there. A repository that declares `hard_block_paths` and serves Codex is protected for its Claude
Code users and not for its Codex users, and `keel doctor` says so on every run.
```

Generate it: `tests/generate-harness-artifacts.sh support-page > docs/harness-support.md`.

Then repair the documents. **The authority is the scan, not the inventory.** Run
`tests/test-harness-claims.sh` and work its unregistered-claim list to empty; the inventory is a
guide to the reasoning, not the list of files. Measured on 2026-09-05 with a path-correct `in_scope`,
the surface is about 23 lines, and **two of the files carrying them are not in the inventory at
all**: `docs/06-repo-layout.md` (9 hits, the repo-layout tree naming each hook) and
`docs/standards.md` (1). Working the inventory alone leaves the check red and the task unfinished.

The inventory at
[`../architecture/tiered-multi-harness-claim-inventory.md`](../architecture/tiered-multi-harness-claim-inventory.md)
gives the 18 locations with line numbers and remedy classes **W** word change, **A** asterisk,
**N** new section. Three of its notes change what the work is rather than adding to it, and each is
the reason a mechanical pass over the 18 would be wrong:

- **A nineteenth location.** `docs/03-install-and-distribution.md:427-432` says "The skills
  themselves stay Claude-only for now". It is true today and false the moment this ships. Class N,
  and it is the natural home for the Tier B install path.
- **`docs/04-plugin-strategy.md` is Claude-shaped across all 221 lines**, not at line 11. Rewrite the
  document with a stated scope line rather than qualifying one row.
- **`docs/05-token-and-memory-design.md` has no false sentence and a false derivation.** Its
  44-tokens-per-description and 1,320-token ceiling were derived against Claude Code's preload
  mechanism. Add the Codex counterpart or state the derivation is Claude-only, tagged
  `property=validated_word_ceiling harness=claude`. **No scan will find this one**, because it is
  arithmetic rather than a sentence.
- **`docs/profile-keys.md` is generated, so tag the generator, not the page.** Two of its rows name
  gates. Task 8 regenerates that file, and a tag written into the output would be silently wiped two
  tasks later with nothing going red. Put the tags in `tests/generate-profile-keys.sh`, regenerate,
  and confirm `tests/test-profile-keys.sh` still passes.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-harness-claims.sh`
Expected: PASS on every case, including the unregistered-claim scan that task 5 left red.

Run: `tests/run-tests.sh`
Expected: "All test files passed". The suite is green again from here on.

- [x] **Step 5: Hand over**

```bash
git add tests/generate-harness-artifacts.sh docs/harness-support.md tests/test-harness-claims.sh \
        README.md docs/01-architecture.md docs/02-skill-catalog.md \
        docs/03-install-and-distribution.md docs/04-plugin-strategy.md \
        docs/05-token-and-memory-design.md docs/07-open-decisions.md docs/profile-keys.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "docs(harness): generate the support page and qualify every harness claim"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.

---

> **DONE 2026-09-06, inline. The suite is green again**, which was this task's job: task 5 landed it
> red and `tests/test-harness-claims.sh` is now 19 passed, 0 failed. `docs/harness-support.md` is
> generated and committed, and the unregistered-claim scan is empty.
>
> **Six deviations, and three of them are things the step text could not have worked as written.**
>
> 1. **Claim tags cannot go on the line above a table row.** An HTML comment on its own line between
>    two rows ends the table in GitHub-flavoured markdown, so the page would have rendered as a
>    header, one row and rubble. Tags ride INSIDE the row instead, which the scan reads identically
>    because it skips any line carrying its own tag. Same for the two tagged rows in
>    `docs/profile-keys.md`.
> 2. **Step 1 and step 3 contradict each other.** Step 1 asserts the page contains "not enforced";
>    the paragraph step 3 specifies says "absent on Codex, not degraded", which is the more precise
>    claim and the one the design argues for, since the gate is not installed there and there is
>    nothing to enforce weakly. Asserting the looser phrase would have forced the page to say
>    something worse than it means. The case pins the section heading and its two nouns instead.
> 3. **The scan had to learn about fenced code blocks.** Nine of the 23 findings were FILENAMES in
>    the repository tree in `docs/06-repo-layout.md`: `hooks/done-guard` the file,
>    `tests/test-session-start.sh` the file. Tagging a directory listing is precisely the reflexive
>    tagging this check's own header says destroys it, so lines inside a fence are skipped and a
>    fixture pins that a fenced line is skipped where an unfenced one is not. **`docs/06` needed no
>    edit at all** once the scan stopped being wrong about it.
> 4. **`README.md:332` was a false positive and was reworded, not tagged.** It is a credit table
>    line reading "session-start hook pattern", crediting a pattern borrowed from another project.
>    Tagging it would assert a gate claim the sentence is not making.
> 5. **`tests/validate-skills.sh` needed the same treatment `tests/supply-chain-scan.sh` needed in
>    task 3.** It compares each `docs/profile-keys.md` description against the schema's, and a tag in
>    the row is inside the cell it compares, so the run went red on a correct page. A claim tag is
>    metadata and not description text, so the comparison strips it. **That opened a hole and it is
>    closed in the same commit**: nothing else diffs that page against its generator, so a tag
>    disappearing would have gone unnoticed. `tests/test-harness-claims.sh` now checks that page for
>    staleness the way it checks the hook manifests, which is what makes "tag the generator, not the
>    page" actually safe.
> 6. **`hard_block_paths`'s schema description now states its own harness scope**, rather than only
>    carrying a tag. It is the key whose meaning becomes conditional on the harness, which the
>    inventory calls the most consequential row in it, and a reader of the schema should not have to
>    find that out from a claim tag.
>
> All five prose locations the inventory says need writing rather than editing are written: the Tier
> B paragraph in `README.md`, the Codex install section in `docs/03`, the scope block on `docs/04`,
> and the Claude-only derivation note in `docs/05`, which no scan can find because it is arithmetic
> rather than a sentence. `docs/01`'s enforcement table gained its harness column.
>
> **Reviewed by an 11 mutant sweep, one guard at a time, zero survivors.** Two of the first sweep's
> three survivors were faults in the sweep rather than gaps, and both are worth naming: deleting one
> of a pair of tags leaves the line tagged, and replacing the first of several occurrences of a word
> leaves the others. A mutation that does not actually remove the thing proves nothing.

---

### Task 7: Move the Claude-only writers behind a harness contract

**Story:** S-03
**Files:**
- Create: `lib/harness/claude.sh`
- Modify: `bin/keel`
- Modify: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `harness_active_gates`, from task 2.
- Produces: the contract `harness_write_config <root>`, `harness_write_local_config <root>`,
  `harness_permission_rules`, `harness_recommend_plugins`, `harness_config_paths`, and
  `harness_doctor_findings`, each defined in `lib/harness/<id>.sh`. Task 9 implements the same six
  for Codex.

**The sixth exists because of what `cmd_doctor` does.** `settings_report_load`, `plugin_report` and
`boundary_report` (`bin/keel:167,242,268`) are read by `cmd_doctor` (`:1316`), which stays in the
neutral file. Moving them into `lib/harness/claude.sh` under a five-function contract would leave
`cmd_doctor` calling functions that exist for one harness only, which breaks the moment `codex.sh`
is the loaded one. `harness_doctor_findings` prints zero or more `level|message` lines and is the
only thing `cmd_doctor` calls; `claude.sh` implements it over the three report functions, and
`codex.sh` implements it as a no-op until it has something to report.

**Depends on:** task 2

**Done when:** `tests/test-keel.sh` passes and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

Append to `tests/test-keel.sh`, in the init section:

```bash
# R-01. The refactor may not change one byte of what a Claude Code user gets.
#
# The baseline is GENERATED from the pre-refactor commit, not committed as a fixture.
# tests/test-keel.sh:1-3 states the policy this suite runs on: "Fixtures are generated per case
# rather than committed, so they cannot go stale against the code they exercise." A committed
# baseline of init output is exactly the fixture that policy forbids.
base="$(mktemp -d)"; after="$(mktemp -d)"
git -C "$ROOT" worktree add -q --detach "$base/repo" "$KEEL_BASELINE_REF" 2>/dev/null
( cd "$base" && git init -q -b main . && "$base/repo/bin/keel" init -y >/dev/null 2>&1 )
( cd "$after" && git init -q -b main . && "$ROOT/bin/keel" init -y >/dev/null 2>&1 )
for f in .claude/settings.json .claude/settings.local.json CLAUDE.md AGENTS.md; do
    if diff -q "$base/$f" "$after/$f" >/dev/null 2>&1; then
        ok "init output unchanged: $f"
    else
        bad "init output unchanged: $f" "$(diff "$base/$f" "$after/$f" | head -3 | tr '\n' ' ')"
    fi
done
git -C "$ROOT" worktree remove --force "$base/repo" 2>/dev/null
rm -rf "$base" "$after"

# The neutral code names no harness OUTSIDE A COMMENT.
#
# `grep -n ... | grep -v '^ *#'` does not do that: grep -n prefixes every line with NNN:, so the
# comment filter matches nothing and the check demands bin/keel stop mentioning .claude even in
# prose. Measured: 50 hits before that filter and 50 after. Strip the prefix before filtering.
leak="$(grep -nE '\.claude|CLAUDE\.md|enabledPlugins|known_marketplaces' "$ROOT/bin/keel" \
        | sed 's/^[0-9]*://' | grep -vE '^[[:space:]]*#' | head -3)"
[ -z "$leak" ] && ok "bin/keel names no harness outside lib/harness/ and its comments" \
  || bad "bin/keel names no harness outside lib/harness/ and its comments" "$leak"
```

- [x] **Step 2: Run it and watch it fail**

Set the baseline reference to the commit this task starts from, so the comparison is against
pre-refactor `bin/keel` rather than against a file somebody has to remember to refresh:

```bash
export KEEL_BASELINE_REF="$(git rev-parse HEAD)"
```

Record that SHA in the hand-over. The test defaults it to `HEAD` when unset, which makes it a no-op
comparison; a reviewer re-running this case needs the SHA to make it mean anything.

Run: `tests/test-keel.sh`
Expected: the four baseline cases PASS, and "bin/keel names no harness outside lib/harness/" FAILS,
listing the first of the 76 coupling points.

- [x] **Step 3: Write the minimal implementation**

Create `lib/harness/claude.sh` and move these functions into it **unchanged**, renaming each to the
contract name and keeping the original as a private helper where the body is long:
`write_settings` (`bin/keel:672-698`), `merge_permissions_into_settings` (`:703-725`),
`write_local_settings` (`:738-761`), `write_nudge` (`:523-553`), `keel_deny_rules` (`:575-591`),
`keel_ask_rules` (`:614-633`), `expected_plugins` (`:665-670`), `settings_report_load` (`:167-238`),
`plugin_report` (`:242-251`), `boundary_report` (`:268-276`).

In `bin/keel`, source the harness file for each harness in the set, next to the existing sourcing
block at `:47-53`, and add `lib/harness/resolve.sh` and `lib/harness/claude.sh` to the
`for _need in ...` completeness check at `:41-46` so a partial install still fails loudly rather
than continuing into undefined functions.

`cmd_init` and `cmd_new` then loop over the harness set and call the contract, rather than calling
the writers by name.

**Move, do not rewrite.** Every byte of output is asserted by step 1. A tidy-up inside a moved
function is how R-01 gets broken by accident.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on all five new cases. Then `tests/run-tests.sh`; expected "All test files passed"
and "OK    shellcheck clean".

- [x] **Step 5: Hand over**

```bash
git add lib/harness/claude.sh bin/keel tests/test-keel.sh tests/fixtures/harness-baseline
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "refactor(keel): move the Claude Code writers behind a harness contract"`.

---

### Task 8: Record which harnesses a repository serves

**Story:** S-04
**Files:**
- Modify: `bin/keel`
- Modify: `templates/profile.schema.json`
- Modify: `tests/test-keel.sh`
- Modify: `docs/profile-keys.md` (regenerated, not edited)

**Interfaces:**
- Consumes: the harness contract, from task 7.
- Produces: `profile.harnesses`, an array of harness ids; `SCHEMA_VERSION=3`;
  `harness_set_for_repo` in `bin/keel`, printing one harness id per line.

**Depends on:** task 7

**Done when:** `tests/test-keel.sh` and `tests/test-profile-keys.sh` pass, and `tests/run-tests.sh`
is green.

- [x] **Step 1: Write the failing test**

Append to `tests/test-keel.sh`:

```bash
h_case() {  # dir-setup-command | flag | expected harnesses json
    local setup="$1" flag="$2" want="$3" w
    w="$(mktemp -d)"; ( cd "$w" && git init -q -b main . && eval "$setup" \
        && "$ROOT/bin/keel" init $flag -y >/dev/null 2>&1 )
    got="$(python3 -c 'import json,sys;print(json.dumps(json.load(open(sys.argv[1])).get("harnesses")))' "$w/.keel/profile.json" 2>/dev/null)"
    [ "$got" = "$want" ] && ok "harnesses $want ($setup $flag)" \
      || bad "harnesses $want ($setup $flag)" "got $got"
    rm -rf "$w"
}

h_case "true"                                             ""                       '["claude"]'
h_case "true"                                             "--harness codex"        '["codex"]'
h_case "true"                                             "--harness claude,codex" '["claude", "codex"]'
h_case "mkdir -p .codex && echo x > .codex/config.toml && git add -A && git commit -qm x" "" '["claude", "codex"]'
h_case "mkdir -p .codex && echo x > .codex/config.toml"    ""                      '["claude"]'
h_case "echo x > AGENTS.md && git add -A && git commit -qm x" ""                   '["claude"]'

# Upgrading an existing schema 2 profile must not infer a harness from anything.
w="$(mktemp -d)"; ( cd "$w" && git init -q -b main . && "$ROOT/bin/keel" init -y >/dev/null 2>&1 \
  && python3 - "$w/.keel/profile.json" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d["schema_version"]=2; d.pop("harnesses",None)
json.dump(d, open(p,"w"), indent=2)
PY
  && "$ROOT/bin/keel" init -y >/dev/null 2>&1 )
got="$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(d.get("schema_version"), json.dumps(d.get("harnesses")))' "$w/.keel/profile.json")"
[ "$got" = '3 ["claude"]' ] && ok "a schema 2 profile upgrades to claude only" \
  || bad "a schema 2 profile upgrades to claude only" "got $got"
rm -rf "$w"

# R-01: init still prompts for nothing.
w="$(mktemp -d)"; ( cd "$w" && git init -q -b main . && "$ROOT/bin/keel" init -y </dev/null >/dev/null 2>&1 )
[ $? -eq 0 ] && ok "init completes with no tty and no prompt" || bad "init completes with no tty" "non-zero exit"
rm -rf "$w"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL on every `harnesses` case with "got null", because the key does not exist yet.

- [x] **Step 3: Write the minimal implementation**

In `bin/keel`, set `SCHEMA_VERSION=3` (`:37`), add `harnesses` to the profile written by
`write_profile`, and add:

```bash
# Which harnesses this repository serves. A set, not a switch: a team with some developers on Claude
# Code and some on Codex works on one repository, and a switch makes that repository's config a
# running argument between the two of them. ADR-0004.
#
# Tracked files only. An untracked .codex/ is one developer's local state and must not change what
# the repository claims for everybody.
#
# AGENTS.md is deliberately NOT a signal. keel has dual written it since long before Codex was
# supported (bin/keel:927-928) and Cursor, Copilot CLI and Gemini CLI read it too, so treating it as
# evidence would mark the whole installed base as Codex-serving in one upgrade.
harness_set_for_repo() {
    local explicit="${1:-}"
    if [ -n "$explicit" ]; then printf '%s\n' "${explicit//,/$'\n'}"; return 0; fi
    if [ -f .keel/profile.json ]; then
        # NOT json_get. bin/keel:105-121 flattens the profile with Python str(), so a list comes
        # back as ['claude', 'codex'], single-quoted and on one line. Verified before writing this.
        # Parse the array from the file directly, and only when python3 is available; the fallback
        # is the default, never a half-parsed harness id.
        local existing=""
        if have_python; then
            existing="$(python3 -c 'import json,sys
try: d=json.load(open(".keel/profile.json"))
except Exception: sys.exit(0)
for h in (d.get("harnesses") or []):
    if isinstance(h,str) and h: print(h)' 2>/dev/null)"
        fi
        [ -n "$existing" ] && { printf '%s\n' "$existing"; return 0; }
    fi
    local out="claude"
    git ls-files --error-unmatch .codex/config.toml >/dev/null 2>&1 && out="$out
codex"
    printf '%s\n' "$out"
}
```

Parse `--harness <list>` in `cmd_init`'s flag loop (`:909`) alongside `-y`, `--team` and `--force`.

**Invalidate the JSON cache before re-reading.** `bin/keel:126-132` caches a flattened profile per
process keyed on filename, and `cmd_init` rewrites `.keel/profile.json` during the run. Anything
reading the profile after the write, `harness_set_for_repo` included when `init` is re-run in a
session, must clear `JSON_CACHE_FILE` first or it reads the pre-write copy.

**Do not regenerate `docs/profile-keys.md` here.** Task 6 tags two harness claims in that file, and
it is generated, so regenerating it wipes them. Add the tags to `tests/generate-profile-keys.sh`
instead, in the task that introduces them, and regenerate from the generator. This task adds the
`harnesses` row to the schema only.
Add `harnesses` to `templates/profile.schema.json`, then regenerate the key reference rather than
editing it: `tests/generate-profile-keys.sh > docs/profile-keys.md`.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`, then `tests/test-profile-keys.sh`
Expected: PASS on both. Then `tests/run-tests.sh`; expected "All test files passed".

- [x] **Step 5: Hand over**

```bash
git add bin/keel templates/profile.schema.json tests/test-keel.sh docs/profile-keys.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(keel): record which harnesses a repository serves"`.

---

> **TASKS 7 AND 8 ARE DONE, 2026-09-06, inline, and in ONE commit rather than two.** The two touch
> the same two files, `bin/keel` and `tests/test-keel.sh`, and by the time task 8 was written task
> 7's changes were interleaved through both. Splitting them would have meant an intermediate commit
> nothing had run the suite against, which is worse than a commit that names both tasks. Baseline
> ref for the R-01 comparison: **`03e2445`**, and `tests/test-keel.sh` prints it, because unset it
> defaults to HEAD and compares the tree against itself.
>
> **Task 7's step 1 and step 3 do not agree, the same way tasks 4, 5 and 6's did not.** Step 1 fails
> unless `bin/keel` stops naming a harness anywhere outside a comment; step 3's move list covers ten
> functions and leaves 31 such mentions behind. Everything below is what closing that gap needed.
>
> 1. **`cmd_doctor`'s Claude Code checks are INTERLEAVED with neutral ones**: plugin set, then the
>    context watchdog, then guardrails, then the handoff, then the editor. A `harness_doctor_findings`
>    called once would group them and reorder a report people read top to bottom. So it **takes a
>    phase**, and `cmd_doctor` calls it where each check already stood. The phases are doctor's own
>    sections and mean nothing harness-specific.
> 2. **Step 1 covers `init` output and not `doctor`'s**, which is the half this task actually
>    rewrites. A doctor baseline comparison was added beside the four init ones, against the same
>    worktree. It earned itself immediately: see item 3.
> 3. **A regression the init comparison could not see.** Re-indenting the marketplace block while
>    moving it de-indented `sys.exit(1)` out of its `if` inside an embedded `python3 -c` string.
>    Python then failed, `age` came back empty, and doctor reported the gbi marketplace as **not
>    registered on a machine where it is**. Only the doctor baseline caught it. The moved body is
>    kept at `cmd_doctor`'s indentation for that reason, with a comment saying so.
> 4. **A seventh contract function, `harness_context_file`.** `CLAUDE.md` is Claude Code's file and
>    `AGENTS.md` is not: keel dual writes `AGENTS.md` for Cursor, Copilot CLI and Gemini CLI too, so
>    it stays neutral. Without this the block writer, the marker checks and the staging list could
>    not stop naming `CLAUDE.md`. `harness_config_paths` prints `committed|` and `local|` rows,
>    because the gitignore line wants the local one and the summary wants the committed one.
> 5. **Task 8's step 3 contradicts itself and the second half is right.** It says do not regenerate
>    `docs/profile-keys.md` here because task 6's tags would be wiped, then says regenerate it. Task
>    6 put those tags in `tests/generate-profile-keys.sh`, so regenerating preserves them, and
>    `tests/test-harness-claims.sh` now fails if the page and its generator disagree. Regenerated.
> 6. **Two gates caught the schema bump, which is what they are for.**
>    `tests/test-doc-claims.sh` pinned `SCHEMA_VERSION=2` for S-12, and
>    `tests/validate-skills.sh`'s `schema_fingerprint_for` had no line for 3. The first now pins 3
>    and names S-04 as the story that moved it; the second gains `3) printf '2313ce09f5c0' ;;`
>    beside the others rather than over one of them, which is the distinction that file's own header
>    draws.
> 7. **The doctor baseline normalises the schema version NUMBER out of both sides, and only the
>    number.** Task 8 bumps it deliberately, so that line differs from every pre-task-8 baseline for
>    the rest of the project's life, and a comparison failing on it would be switched off within a
>    week. The line's wording and level are still compared, proven by a mutant that changes the
>    wording and is caught.
>
> **Reviewed by a 9 mutant sweep, one guard at a time, zero survivors** (7 for task 7, and 6 for
> task 8 of which one was re-run against the right file). Two of task 7's apparent survivors were
> faults in the sweep: `CLAUDE.MD` is the SAME FILE as `CLAUDE.md` on macOS's case-insensitive
> filesystem, so that mutant changed nothing at all. Two review passes not run, per task 14.

---

### Task 9: Write Codex configuration on a repository that serves Codex

> **Carries open question 6 of the architecture, added 2026-09-06. Do not close this task without
> it.** `.codex/config.toml` is a repository file and hook trust is not: it lives in the user's
> `~/.codex/config.toml`, so **keel cannot grant it and must not try**. Writing a repository config
> and saying nothing leaves a Codex user with keel visibly installed and every gate silently doing
> nothing, which is the exact failure this design exists to prevent.
>
> **What this task adds:** `keel init` on a repository serving Codex prints the trust step, says
> plainly that keel cannot perform it, and names where it is done. **Acceptance:** an assertion in
> `tests/test-keel.sh` that the init output for `--harness codex` mentions trusting hooks, in the
> same style as the existing `codex config written` case. A message nothing pins is a message the
> next refactor deletes.
>
> Do not put `--dangerously-bypass-hook-trust` in that message or anywhere a user reads it. The
> global constraint confines it to `tests/evals/`, and it is not the answer for a real user.

**Story:** S-05
**Files:**
- Create: `lib/harness/codex.sh`
- Modify: `tests/test-keel.sh`

**Interfaces:**
- Consumes: the harness contract, from task 7; `harness_set_for_repo`, from task 8.
- Produces: `.codex/config.toml` with a `[permissions.keel.filesystem]` block, and
  `.codex/agents/keel-fanout.toml`, which task 15's delegation profile resolves to.

**Depends on:** task 8

**Done when:** `tests/test-keel.sh` passes and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

Append to `tests/test-keel.sh`:

```bash
w="$(mktemp -d)"; ( cd "$w" && git init -q -b main . && "$ROOT/bin/keel" init --harness codex -y >/dev/null 2>&1 )

[ -f "$w/.codex/config.toml" ] && ok "codex config written" || bad "codex config written" "absent"
[ -f "$w/.claude/settings.json" ] && bad "no Claude settings for a codex-only repo" "written" \
  || ok "no Claude settings for a codex-only repo"
grep -q 'keel:start' "$w/AGENTS.md" 2>/dev/null && ok "AGENTS.md carries the managed block" \
  || bad "AGENTS.md carries the managed block" "absent"

# The five path denies port and get stronger. A path deny also stops `cat`.
n="$(grep -c '"deny"' "$w/.codex/config.toml" 2>/dev/null || echo 0)"
[ "$n" -ge 5 ] && ok "path denies written ($n)" || bad "path denies written" "got $n, wanted at least 5"

# Codex has no command-pattern rule syntax and no ask. Neither may be faked.
grep -qE 'Bash\(|"ask"|prompt' "$w/.codex/config.toml" 2>/dev/null \
  && bad "no command-pattern or ask rule is faked" "$(grep -nE 'Bash\(|"ask"|prompt' "$w/.codex/config.toml" | head -1)" \
  || ok "no command-pattern or ask rule is faked"
rm -rf "$w"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL, "codex config written: absent".

- [x] **Step 3: Write the minimal implementation**

Create `lib/harness/codex.sh` implementing the same five contract functions as
`lib/harness/claude.sh`:

```bash
#!/usr/bin/env bash
# The Codex CLI writers. Tier B.
#
# Codex has no command-pattern rule syntax at all. Permission profiles are path globs and network
# domains: codex-rs/protocol/src/permissions.rs:105 defines FileSystemAccessMode as Read, Write and
# Deny, with no ask, prompt or confirm variant. So of keel's 26 Claude rules, the 5 Read(./.env)
# shaped denies port here and get STRONGER, because a path deny also stops `cat`; the 8
# Bash(cat *.env*) denies become redundant under them; and all 13 ask rules have no counterpart.
#
# Nothing here fakes the missing 13. A rule that looks like a prompt and is not one is the failure
# this whole design exists to prevent.

harness_permission_rules() {
    cat <<'RULES'
[permissions.keel.filesystem.":workspace_roots"]
"**/.env" = "deny"
"**/.env.*" = "deny"
"**/secrets/**" = "deny"
"**/*.pem" = "deny"
"**/*.key" = "deny"
RULES
}

harness_write_config() {
    local root="$1"
    mkdir -p "$root/.codex/agents"
    harness_permission_rules > "$root/.codex/config.toml"
    cat > "$root/.codex/agents/keel-fanout.toml" <<'AGENT'
# The delegation profile keel's fan-out skills name. ADR-0005 moves the pin out of skill prose and
# into here, because "a cheaper, faster model than the driver" cannot be said in a vocabulary of
# four vendor names plus `inherit`.
name = "keel-fanout"
model = "gpt-5-codex-mini"
model_reasoning_effort = "low"
AGENT
}

harness_write_local_config() { :; }   # Codex has no committed/local split to mirror
harness_recommend_plugins() { :; }    # no Codex marketplace equivalent is established
harness_config_paths() { printf '%s\n' ".codex/config.toml" ".codex/agents/keel-fanout.toml"; }
```

**Confirm the model id before committing.** `model = "gpt-5-codex-mini"` is a placeholder for the
cheapest Codex model that clears the fan-out quality bar, and nothing has measured that. Run
`codex exec --help` and the Codex model list, pick the current cheapest, and record the choice and
the date in a comment. If no measurement exists, say so in the comment rather than implying one:
S-19 is the story that measures it.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on all five new cases. Then `tests/run-tests.sh`; expected "All test files passed".

- [x] **Step 5: Hand over**

```bash
git add lib/harness/codex.sh tests/test-keel.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(harness): write Codex configuration for a repository serving Codex"`.

---

> **DONE 2026-09-06, inline, together with the review of 5346a83..HEAD whose findings it folds in.**
> `keel init --harness codex` writes `.codex/config.toml` and `.codex/agents/keel-fanout.toml`, no
> `.claude/` and no `CLAUDE.md`, and says the hook trust step exists. `--harness claude,codex` gets
> both. Suite green.
>
> **The one thing the task text could not have worked as written: sourcing is not selection.**
> Every harness file defines the same function names, so sourcing two leaves only the second
> reachable and a repository serving both gets one of them configured. `harness_each` sources each
> harness's file immediately before calling the contract on it, once per harness, and a case pins
> the both-harnesses repository because that is the case a source-them-all design passes for one
> harness and silently skips for the other.
>
> **`harness_permission_rules` prints `deny|<rule>`, not TOML.** The task sketches it returning the
> Codex config file's contents, which would have broken `cmd_init`'s rule count on that harness:
> the count is `grep -c "^deny|"` and TOML matches neither. The rules stay countable and comparable
> across harnesses, and `harness_write_config` is the only thing that knows Codex's file format.
> Codex reports 5 deny and 0 ask, which is exactly what the manifest says and what the support page
> reports, and nothing fakes the missing 13.
>
> **`harness_context_file` is empty on Codex, deliberately.** AGENTS.md is written for every
> repository because Cursor, Copilot CLI and Gemini CLI read it, so returning it here would merge
> the same block into the same file twice.
>
> **The model id is unmeasured and says so.** `gpt-5-codex-mini` is the cheapest published Codex
> model as of 2026-09-06 and nothing has measured that it clears the fan-out quality bar. Open
> question 1 of the architecture; S-19 measures it.
>
> **Eight review findings against 5346a83..HEAD landed here too.** Two were HIGH or behavioural:
> `keel init --harness` was a silent no-op on any repository that already had a profile, because
> merge_profile defends every human value and `harnesses` is one; and `read_usage` called a valid
> transcript unsupported whenever it had no assistant turn yet, which is every session's first
> prompt. Also: `--harness` accepted anything including the next flag, so `--harness --team` recorded
> a harness called `--team` and silently dropped `--team`; `declared_window` did not fall through
> from tail to whole file, so a large Codex rollout fell back to 200,000 silently; the sniff ran a
> full parse ahead of the measurement cache on every prompt; and three documents claimed things that
> are task 10's and task 11's work. **The interpreter-start budget caught `harness_each` starting
> python3 once per call**, which is now primed once per process and read from the flattened cache
> rather than a second parse.
>
> **Init's own stdout was not in the R-01 comparison and is now.** The refactor changed
> `CLAUDE.md, AGENTS.md` to `CLAUDE.md AGENTS.md` in the summary and nothing noticed.

---

### Task 10: Ship the Codex plugin manifest pointing at the same skills directory

> **Carries open question 6 of the architecture, added 2026-09-06, and two facts probed the same
> day.**
>
> **The facts first, because this task's Files list assumes neither.** The marketplace manifest
> Codex reads is **`.claude-plugin/marketplace.json`**, not a `.codex-plugin` one:
> `codex plugin marketplace add` refuses a root holding only the latter with "marketplace root does
> not contain a supported manifest". keel's existing `.claude-plugin/marketplace.json` is therefore
> already the file Codex reads, and this task adds no marketplace file. And hooks reach Codex
> **only** through a plugin: a project-level `<cwd>/.codex/hooks.json` was tried and never fired, so
> `.codex-plugin/plugin.json` declaring `"hooks": "./hooks/hooks.codex.json"` is the only path.
>
> **The trust step belongs in the install instructions this task writes**, and not only for a first
> install. Codex's hook state carries `trusted_hash`, so trust is bound to the hook file's content:
> **a keel upgrade that changes a hook should drop the user back to running nothing, silently.**
> Confirm that before writing the sentence, by installing the plugin, trusting it, editing a hook
> and running again. If it holds, the instructions say so and `docs/runbooks/cutting-a-release.md`
> gains a line; if it does not, say what was measured instead. Do not write it from this note.

**Story:** S-06
**Files:**
- Create: `.codex-plugin/plugin.json`
- Modify: `tests/test-harness-claims.sh`

**Interfaces:**
- Consumes: `hooks/hooks.codex.json`, from task 3.
- Produces: `.codex-plugin/plugin.json`.

**Depends on:** task 3

**Done when:** `tests/test-harness-claims.sh` passes and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

Append to `tests/test-harness-claims.sh`:

```bash
# 8. One skills directory, two plugin manifests. Drift is impossible because there is nothing to
# drift from: both harnesses load the same skills/ tree.
M=.codex-plugin/plugin.json
if [ -f "$M" ]; then
    [ "$(python3 -c 'import json;print(json.load(open(".codex-plugin/plugin.json"))["skills"])')" = "./skills/" ] \
      && ok "codex manifest points at ./skills/" || bad "codex manifest points at ./skills/" "wrong value"
    [ "$(python3 -c 'import json;print(json.load(open(".codex-plugin/plugin.json"))["hooks"])')" = "./hooks/hooks.codex.json" ] \
      && ok "codex manifest points at the Tier B hook manifest" \
      || bad "codex manifest points at the Tier B hook manifest" "wrong value"
    dupes="$(git ls-files 'skills/*/SKILL.md' | sed 's#.*/\([^/]*\)/SKILL.md#\1#' | sort | uniq -d)"
    [ -z "$dupes" ] && ok "no skill appears twice in the tree" || bad "no skill appears twice" "$dupes"
else
    bad ".codex-plugin/plugin.json exists" "absent"
fi
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-harness-claims.sh`
Expected: FAIL, ".codex-plugin/plugin.json exists: absent".

- [x] **Step 3: Write the minimal implementation**

Create `.codex-plugin/plugin.json`. `skills` and `hooks` are author-chosen relative paths, verified
against `developers.openai.com/plugins/build/plugins` on 2026-09-05, which also states "Keep
manifest paths relative to the plugin root and start them with `./`":

```json
{
  "name": "keel",
  "version": "0.18.0",
  "description": "A standard operating procedure for AI-assisted delivery. Tier B on Codex CLI: skills, the AGENTS.md block, the keel CLI and three of four gates. See docs/harness-support.md.",
  "author": { "name": "GBi Solutions Ltd" },
  "homepage": "https://github.com/gbi-solutions-ltd/keel",
  "repository": "https://github.com/gbi-solutions-ltd/keel",
  "license": "MIT",
  "skills": "./skills/",
  "hooks": "./hooks/hooks.codex.json"
}
```

`skills` points at the same directory `.claude-plugin` uses. Nothing is copied and nothing is
synchronised, which is why there is no drift check for the skills themselves: there is one copy.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-harness-claims.sh`
Expected: PASS. Then `tests/run-tests.sh`; expected "All test files passed". Confirm
`tests/export-public.sh` still exports the new file rather than silently excluding it.

- [x] **Step 5: Hand over**

```bash
git add .codex-plugin/plugin.json tests/test-harness-claims.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(harness): ship the Codex plugin manifest"`.

---

> **DONE 2026-09-06 except for one probe-gated sentence, which is named below and is NOT written.**
> `.codex-plugin/plugin.json` ships, pointing `skills` at the same `./skills/` both harnesses load
> and `hooks` at `hooks/hooks.codex.json`. No marketplace file was added, because Codex reads
> `.claude-plugin/marketplace.json` and refuses a root holding only a `.codex-plugin` one.
>
> **Three things the Files list does not name, each because a second versioned manifest is a new
> surface.**
>
> 1. **`tests/test-keel.sh`'s version-drift check covered one manifest by name.** Codex keys its
>    plugin cache the same way, so a Codex user would have sat on the previous skills after a
>    release with nothing failing, which is the exact scar that check records. It globs
>    `.*-plugin/plugin.json` now, so the third manifest is covered on the day it is added rather
>    than the day it drifts.
> 2. **`docs/runbooks/cutting-a-release.md` said three places and one commit.** It says four.
> 3. **`docs/06-repo-layout.md`'s tree gained `.codex-plugin/`, and its "The two manifests" section
>    is now three files.** `tests/test-doc-claims.sh` failed the build on the missing tree entry,
>    which is that gate doing its job.
>
> **Step 4 asks for a one-off manual confirmation that `tests/export-public.sh` still exports the
> new file. That is a measurement nobody repeats, so it is an assertion instead.** That script had
> no test at all: its exclusion list is a privacy guard covering `.claude/` and `docs/audits/` with
> nothing pinning it, and a manifest that is untracked or newly excluded exports as silently as it
> imports. Both directions are pinned now. The first run of it found the real thing: the manifest is
> absent from the export until it is tracked.
>
> **STILL OPEN, and deliberately not written: whether a keel upgrade silently un-trusts the hooks.**
> The note above says to confirm it by installing the plugin, trusting it, editing a hook and
> running again, and only then to write it into the install instructions and the release runbook.
> That probe installs into the user's own Codex, writes their `~/.codex/config.toml` and spends
> their model quota, so it was put to the user rather than assumed. The inference and its evidence
> (`trusted_hash` in the 0.153.4 hook state, and the "skipping materialized plugin hook trust after
> account changed" log line) stay recorded as an inference in open question 6 and in `codex.sh`.
> **The first-install half of the trust step IS written**, in `docs/03-install-and-distribution.md`
> and in what `keel init --harness codex` prints.
>
> **Reviewed by a 6 mutant sweep, one guard at a time, zero survivors.**

---

### Task 11: Report the running harness and its live gate set in keel doctor

> **Two things added 2026-09-06, and the first changes what "live gate set" means.**
>
> **1. The manifest answers what the harness CAN do. Doctor must answer what THIS installation
> actually does.** They are not the same question, and open question 6 of the architecture is the
> gap between them: Codex runs no hook until its source is trusted, and says nothing when it skips
> one. So `harness_active_gates codex` returning three gates is a true statement about Codex and a
> **false** statement about a user whose hooks are untrusted, for whom all three are dark. Doctor
> reporting the manifest's answer there would be keel agreeing with itself, which is the fault this
> plan has already been bitten by twice.
>
> Trust is readable rather than only observable, and the path is now measured rather than guessed:
> **`hooks.state."<id>"`**, carried as a literal `hooks.state."` prefix in the 0.153.4 binary beside
> the `enabled` and `trusted_hash` fields, in the user's `~/.codex/config.toml`. Probed 2026-09-06
> with the real keel plugin: installing wrote `[plugins."keel@gbi"] enabled = true` and **no trust
> entry of any kind**, and running a session added none. So the absence of `trusted_hash` from that
> file is itself the signal, and it is checkable without knowing which id keys the table. Report an
> untrusted or disabled hook as a gate that is dark, naming the trust step.
>
> **The failure is worse than the note above assumed, and the message should say which half works.**
> The same probe found that **the 25 skills load without trust and the hooks do not**: the session
> advertised every keel skill and fired no hook. An untrusted install therefore does not look
> broken, it looks like most of keel working, which is why "keel is installed" is not evidence of
> anything a gate promises. **Acceptance:** a case where the manifest grants a
> gate and the trust state withholds it, and doctor says dark. Without that case this is a comment.
>
> Absent or unreadable Codex config is not proof of anything and must not be reported as dark: say
> that trust could not be determined. The manifest fails closed on missing evidence because a wrong
> `provides` row is unsafe; a doctor line that cries wolf on every machine gets ignored, which
> costs more than it saves.
>
> **2. The two context window messages at `bin/keel:1546` and `:1552` are Claude Code numbers.**
> They say the watchdog is "assuming 200000" and that a value below "the $cwdef default" has no
> effect. Since 2026-09-06 a Codex rollout states its own window, `model_context_window`, 258400 on
> the probed session, so on Codex both sentences name the wrong baseline. This was left to this task
> deliberately: doctor prints one live answer and cannot give the right one until `harness_running`
> exists, which is what this task adds. `templates/profile.schema.json` and `window_for`'s docstring
> were repaired in task 14, since a static description can state both cases; these two cannot.
> FR-10 of `docs/prd/context-window-at-init.md` names all four locations as one set.

**Story:** S-07
**Files:**
- Modify: `bin/keel`
- Modify: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `harness_active_gates`, from task 2; `harness_set_for_repo`, from task 8.
- Produces: `harness_running`, printing the detected harness id or `unknown`.

**Depends on:** tasks 2, 8

**Done when:** `tests/test-keel.sh` passes and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

Append to `tests/test-keel.sh`:

```bash
w="$(mktemp -d)"; ( cd "$w" && git init -q -b main . && "$ROOT/bin/keel" init --harness claude,codex -y >/dev/null 2>&1 \
  && python3 - .keel/profile.json <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d["hard_block_paths"]=["src/auth/**"]
json.dump(d, open(p,"w"), indent=2)
PY
)

out="$( cd "$w" && CODEX_VERSION=0.153.4 "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -qi 'codex' && ok "doctor names the running harness" \
  || bad "doctor names the running harness" "no mention of codex"
printf '%s' "$out" | grep -qi 'sensitive-guard' && ok "doctor reports the missing gate" \
  || bad "doctor reports the missing gate" "no mention of sensitive-guard"
printf '%s' "$out" | grep -qi 'hard_block_paths' && ok "doctor warns on an unenforceable hard block" \
  || bad "doctor warns on an unenforceable hard block" "no warning"

# Both signals unset. CLAUDECODE=1 is exported by Claude Code, and this repository is developed
# inside it, so `env -u CODEX_VERSION` alone would leave the detector confidently answering
# "claude" locally and "unknown" in CI. Verified set in the development environment before writing
# this case.
out="$( cd "$w" && env -u CODEX_VERSION -u CLAUDECODE "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -qi 'cannot determine' && ok "doctor says when it cannot tell" \
  || bad "doctor says when it cannot tell" "no such line"
rm -rf "$w"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL on all four, because doctor has no harness section.

- [x] **Step 3: Write the minimal implementation**

Add to `bin/keel`:

```bash
# Which harness is running this process.
#
# CLAUDE_PLUGIN_ROOT is NOT a discriminator: Codex sets it deliberately for compatibility, at
# codex-rs/hooks/src/engine/discovery.rs:266-269, and only for plugin hooks at that. Checked rather
# than assumed, because hooks/hooks.json interpolates that variable.
#
# CODEX_VERSION is injected into every shell command Codex's exec tool runs
# (codex-rs/core/src/exec_env.rs:40-49). A hook reads turn_id from its stdin payload instead; that
# path lives in the hooks, not here.
harness_running() {
    [ -n "${CODEX_VERSION:-}" ] && { printf 'codex\n'; return 0; }
    [ -n "${CLAUDECODE:-}" ] && { printf 'claude\n'; return 0; }
    printf 'unknown\n'
}
```

Then add the section to `cmd_doctor`, using its existing `good`/`warn` printers (`bin/keel:1328-1330`)
so the output matches every other check rather than inventing a format:

```bash
    # The harness section. ADR-0004: a guarantee is a property of (repository, harness), so this
    # answers for the harness in front of the person and names what the others do not get.
    running="$(harness_running)"
    if [ "$running" = unknown ]; then
        warn "cannot determine which harness is running, so this reports on every harness this repository serves"
        harnesses="$(harness_set_for_repo)"
    else
        good "running under $running"
        harnesses="$running"
    fi
    for h in $harnesses; do
        active="$(harness_active_gates "$h" | tr '\n' ' ')"
        good "$h gates active: ${active:-none}"
        for g in session-start done-guard context-watch sensitive-guard; do
            harness_gate_active "$h" "$g" || warn "$h does not get $g"
        done
    done
    if grep -q '"hard_block_paths"' .keel/profile.json 2>/dev/null; then
        for h in $(harness_set_for_repo); do
            harness_provides "$h" pretooluse_ask \
              || warn "this repository declares hard_block_paths, which is not enforced for its $h users"
        done
    fi
    # A harness installed here that the repository does not list. A machine fact, so it belongs in
    # doctor and never in init, which writes a committed team fact.
    command -v codex >/dev/null 2>&1 && ! harness_set_for_repo | grep -qx codex \
      && warn "codex is installed on this machine but this repository does not list it in harnesses"
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on all four. Then `tests/run-tests.sh`; expected "All test files passed".

- [x] **Step 5: Hand over**

```bash
git add bin/keel tests/test-keel.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(doctor): report the running harness and the gates active on it"`.


**Landed 2026-09-06.** Staged, not committed, per step 5.

**What was added beyond the snippet, and why.**

- **`harness_hooks_trusted <harness>`, in `bin/keel`.** The acceptance case this task names needs a
  trust state, and there was none. It prints `trusted`, `untrusted` or `unknown` and reads
  `${CODEX_HOME:-$HOME/.codex}/config.toml`, tracking the TOML section rather than grepping it:
  `enabled` and `trusted_hash` are ordinary field names and the answer depends on which table they
  sit in. A `trusted_hash` in an unrelated table grants nothing, and there is a fixture that fires
  on it. It is in `bin/keel` and not in `lib/harness/codex.sh` because `cmd_doctor` asks it for a
  named harness id, including one the repository does not serve, and `harness_each` only walks the
  set the repository does serve. **That placement is the one judgement call worth a second opinion**,
  since it puts a Codex fact in the neutral file, which is the direction `b2b2852` pushed against.
- **`harness_gates()`, beside `harness_ids`.** The snippet hardcoded the four gate names. A fifth
  gate would be silently missing from doctor's report, which is precisely this design's dominant
  failure, so the list comes from the manifest's `requires` rows for the same reason `harness_ids`
  reads its `provides` rows.
- **The untrusted and unknown branches print no "gates active" line.** Two lines, one calling the
  gates live and one calling them dark, is worse than either alone.
- **The R-01 doctor baseline needed scoping.** `tests/test-keel.sh`'s comparison against
  `KEEL_BASELINE_REF` was red for every uncommitted change to doctor output and green again the
  moment somebody committed, which is a comparison that reports when the last commit happened. The
  harness section and the closing tally are filtered from both sides, by anchored alternatives that
  name one line each; everything the filter drops has its own assertion in the same file, and the
  tally has the pre-existing "doctor summary counts its warnings" case.

**Review found a fail-open the sweep could not, and it is the finding worth carrying.** The first
trust reader tracked its three flags across EVERY `[hooks.state.*]` and `[plugins.*]` table, so on
any config holding a second plugin it answered about the wrong one. A stranger's `trusted_hash` made
keel read as trusted and doctor printed three gates active on an installation where none would ever
run. **Sixteen mutants did not catch it because every fixture held exactly one plugin**, which is
the shape of blind spot a sweep has by construction: it tests the code against the cases somebody
already thought of. The tables are now matched on a quoted id of `keel` or `keel@anything`, and
there is a fixture per direction.

Two more from the same pass. `$HOME` was read bare in a file that runs under `set -u`, and the read
sits inside a command substitution, so an unset HOME killed the SUBSHELL, left the verdict empty and
fell through to "gates active" on a machine whose config was never opened: silent, and open. And
`harness_set_for_repo` was called three times where `$HARNESS_SET` was already primed one line
above, against this file's own stated rule and ignoring `HARNESS_FLAG` while doing it.

**Verification.** `tests/test-keel.sh` 513 passed 0 failed. `tests/run-tests.sh` green, exit 0,
including the leak and supply-chain scans and shellcheck. **Mutation sweep: 16 mutants, 16 killed,
0 survivors**, covering both `harness_running` branches, all four trust verdicts, the section guard
in the awk, the keel-id match in both directions, the unset HOME, the two doctor branches that must
not print together, the per-gate loop, the `hard_block_paths` check, the unlisted-install check and
both context window sentences. Five fixtures were added because the sweep or the review found the
checks that had none: a Codex config that exists and never mentions keel, a `trusted_hash` in an
unrelated table, a second plugin trusted beside an untrusted keel, a second plugin disabled beside a
trusted keel, and an unset HOME.

**Three documents said doctor was not harness-aware and now say what it does**: `README.md`,
`docs/07-open-decisions.md`, and `docs/harness-support.md` through its generator at
`tests/generate-harness-artifacts.sh`, regenerated. Rewritten rather than corrected beside.

**Still open after this task.** Open question 6's remaining half is untouched: whether a keel
release that changes a hook drops trust is still an inference from `trusted_hash` being a content
hash, and granting trust is a TUI act nobody has driven. Doctor now reports the state, so the
release runbook question is answerable the next time somebody trusts a build and upgrades it.

---

### Task 12: Refuse loudly when sensitive-guard runs where it cannot work

**Story:** S-09
**Files:**
- Modify: `hooks/sensitive-guard`
- Modify: `tests/test-sensitive-guard.sh`

**Interfaces:**
- Consumes: `harness_provides`, from task 2.
- Produces: nothing new.

**Depends on:** task 2

**Done when:** `tests/test-sensitive-guard.sh` passes and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

Append to `tests/test-sensitive-guard.sh`, after the existing cases. **This file defines no
`ok`/`bad` helpers**; it counts through `pass` and `fail` directly, and it drives the guard by
piping an event from its `event()` helper into the hook's **stdin** (`hooks/sensitive-guard:61`,
`event="$(</dev/stdin)"`). Use its `fixture()` and `event()` rather than hand-rolling either.

The third case is the one that matters most and is easy to omit: **a repository that declares no
`hard_block_paths` must stay silent on Codex too.** The hook's header states that invariant at
`hooks/sensitive-guard:16-17`, and a self-check placed too early breaks it for every Bash call in
every repository on the harness.

```bash
fixture "$tmp/hx" '"src/auth/**"'
ev="$(event "git commit -m x" "$tmp/hx")"

out="$(printf '%s' "$ev" | ( cd "$tmp/hx" && CODEX_VERSION=0.153.4 "$GUARD" ) 2>&1 >/dev/null)"; rc=$?
if [ "$rc" -eq 2 ]; then printf '  PASS  exits 2 where the harness cannot ask\n'; pass=$((pass+1))
else printf '  FAIL  exits 2 where the harness cannot ask (got %s)\n' "$rc"; fail=$((fail+1)); fi

if printf '%s' "$out" | grep -qi 'codex'; then printf '  PASS  names the harness on stderr\n'; pass=$((pass+1))
else printf '  FAIL  names the harness on stderr (got: %s)\n' "${out:0:90}"; fail=$((fail+1)); fi

# The invariant. A repo declaring nothing must cost one builtin string match and produce nothing,
# on every harness. This is the case that catches the self-check being placed too early.
fixture "$tmp/hq" ''
ev="$(event "git commit -m x" "$tmp/hq")"
out="$(printf '%s' "$ev" | ( cd "$tmp/hq" && CODEX_VERSION=0.153.4 "$GUARD" ) 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ]; then printf '  PASS  silent on codex when the repo declares nothing\n'; pass=$((pass+1))
else printf '  FAIL  silent on codex when the repo declares nothing (rc %s: %s)\n' "$rc" "${out:0:90}"; fail=$((fail+1)); fi
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-sensitive-guard.sh`
Expected: FAIL, "exits 2 where the harness cannot ask: exit 0". The guard currently exits 0, which is
exactly the silent-inert behaviour this task removes.

- [x] **Step 3: Write the minimal implementation**

**Placement is the whole of this task, and getting it wrong inverts the gate.** Insert the block
**after** the `hard_block_paths` cheap gate at `hooks/sensitive-guard:55-59` and before the stdin
read at `:61`. Not after `ask()`, and not before the profile walk: the guard exits 0 at `:59` for
every repository that declares no `hard_block_paths`, which is almost all of them, and a self-check
placed above that line would exit 2 on **every Bash tool call in every repository on Codex**. The
hook's own header states the invariant it would break, at `:16-17`, "SILENT UNLESS THE REPOSITORY
ASKS FOR IT".

So the order is: profile found, `hard_block_paths` declared, **then** ask whether this harness can
honour it.

```bash
# WHY EXIT 2 AND NOT 1. On Codex a PreToolUse hook that exits with any non-zero code other than 2
# has its stderr DISCARDED: codex-rs/hooks/src/events/pre_tool_use.rs replaces it with the string
# "hook exited with code N" and the tool call proceeds. Exit 2 takes a different arm entirely, which
# sets should_block and surfaces stderr as the block reason. So exit 1 here would be quieter than
# doing nothing, and exit 2 both stops the command and says why.
#
# This is the payload case. The plugin is distributed by cloning one repository, so this file is on
# every Codex machine whatever hooks/hooks.codex.json registers. It cannot be made absent. It can be
# made impossible to operate through, and that is what this block does.
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)}"
running=claude
[ -n "${CODEX_VERSION:-}" ] && running=codex
if [ ! -r "$ROOT/lib/harness/resolve.sh" ]; then
    # Fails CLOSED. This hook's contract, stated at :19-21, is that it asks whenever it cannot
    # answer. An unreadable resolver is exactly that case, and `if [ -r ... ]; then` would have
    # skipped the check silently, which is the one outcome a gate must never have.
    ask "the harness capability manifest could not be read, so the guard cannot tell whether this gate works here. Approving is a human decision."
fi
# shellcheck source=../lib/harness/resolve.sh
. "$ROOT/lib/harness/resolve.sh"
if ! harness_provides "$running" pretooluse_ask; then
    printf 'keel sensitive-guard: %s does not provide a way to put a command to a human, so this gate cannot work here. It is not installed on %s by keel; if you wired it up by hand, remove it. Blocking rather than pretending. See docs/harness-support.md.\n' "$running" "$running" >&2
    exit 2
fi
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-sensitive-guard.sh`
Expected: PASS on all four new cases and every existing one. Then `tests/run-tests.sh`; expected
"All test files passed" and "OK    shellcheck clean".

- [x] **Step 5: Hand over**

```bash
git add hooks/sensitive-guard tests/test-sensitive-guard.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "fix(sensitive-guard): block and explain where the harness cannot ask"`.


**Landed 2026-09-06.** Staged, not committed, per step 5.

**THE PLACEMENT IN STEP 3 IS WRONG, AND RUNNING IT IS WHAT SHOWED THAT.** Step 3 says to insert the
block after the `hard_block_paths` gate and before the stdin read. It is bounded from the other
side too, by an invariant this task did not look at: the existing case "a non-Bash call is silent
even with python3 absent" exists because the fail-closed branch must not become a prompt on every
Read and Grep. A hard block has exactly the same obligation, and at the position step 3 names it
exits 2 on every Read and Grep in any repository that declares paths. **The block now sits after
the `git commit` filter**, which satisfies both bounds: profile found, `hard_block_paths` non-empty,
this is a commit, then ask whether the harness can honour it. Moving it later is strictly safer
than step 3's position, never less.

**Three more defects the step 3 snippet carries, each found by a red test rather than by reading.**

- **`harness_provides` cannot tell "no ask" from "manifest unreadable", and the snippet treats both
  as a hard block.** `harness_capabilities_path` resolves its own path with `dirname`, so on a PATH
  that does not carry one the resolver answers false for every harness and a **Claude Code** commit
  was hard blocked by a message saying Claude Code cannot ask. `harness_known` separates the two and
  the unreadable case takes the `ask` this hook's contract promises. This is the deferred
  `resolve.sh` finding in the handoff arriving where it does damage: it was recorded as failing
  closed, and closed here meant a lie rather than a prompt.
- **`ROOT` resolved through `dirname`**, an external command, in a hook that runs on whatever PATH
  the harness hands it. `${BASH_SOURCE[0]%/*}` is a builtin and forks nothing.
- **An empty `hard_block_paths` declares nothing and the cheap gate cannot see it**, because it
  matches the key and not the list. `fixture <dir> ''` in `tests/test-sensitive-guard.sh` writes
  `"hard_block_paths": []`, and the suite's own case at :70 calls that "a repository that declares
  no sensitive paths". On Claude Code this has never mattered, since the walk finds no pattern and
  ends in the same silence. Here it was a hard block on a repository that asked for nothing. Checked
  with a builtin, beside the harness check. Claude Code's output is unchanged; it reaches the same
  exit 0 sooner.

**Verification.** `tests/test-sensitive-guard.sh` 24 passed 0 failed, up from 16.
`tests/run-tests.sh` green, exit 0, shellcheck clean. **Mutation sweep: 7 mutants, 7 killed, 0
survivors**, covering the harness check firing at all, exit 2 rather than 1, the Codex detection,
the unreadable resolver, the unresolvable manifest, the empty declaration, and the placement itself.
The unreadable-resolver mutant survived the first sweep and was an honest survivor rather than an
equivalent one: with `harness_known` in place the ask still happens, but by accident, on a
`command not found`. The case now asserts the ask is clean as well as correct.

---

### Task 13: Emit the Stop decision Codex understands

> **Struck 2026-09-05. Do not implement.** This task assumed Claude Code wants `deny` and only Codex
> wants `block`. Both want `block`: Claude Code's Stop protocol defines one blocking value and
> `hooks/done-guard` was emitting `deny` to both, which is why the gate had never fired anywhere.
> Fixed as a defect ahead of this plan, with the protocol value pinned by a test that no longer
> greps keel's own output. **S-10's decision word is delivered.**
>
> **But the fix opened a larger harness dependency than the one it closed, and this note previously
> claimed the opposite.** `stop_blocking` does behave identically on both harnesses. Reading the
> turn's tool calls does not: `done-guard` now requires `transcript_path`, or
> `agent_transcript_path`, and a Claude Code JSONL row schema. On a harness that supplies neither,
> `required` and `warn` mode emit "the turn's transcript could not be read" at the end of every
> turn. `context-watch` already carries the same dependency, which is why S-11 and task 14 exist.
> **`done-guard` now needs the same treatment**, and the capability manifest needs a primitive
> finer than `stop_blocking` to say so: blocking a stop and seeing what the turn did are two
> different things, and Codex provides the first. Fold that into task 14 rather than reviving this
> task. Left in place rather than deleted, because the assumption is worth seeing.

**Story:** S-10
**Files:**
- Modify: `hooks/done-guard`
- Modify: `tests/test-done-guard.sh`

**Interfaces:**
- Consumes: nothing from earlier tasks. Reads `CODEX_VERSION` directly rather than sourcing
  `lib/harness/resolve.sh`, because this hook already reads its event from stdin and starting a
  second dependency in the gate path buys nothing here: the decision word is one string, not a
  capability question.
- Produces: nothing new.

**Depends on:** task 2

**Done when:** `tests/test-done-guard.sh` passes and `tests/run-tests.sh` is green.

- [ ] **Step 1: Write the failing test**

Append to `tests/test-done-guard.sh`, after the existing cases and before the summary. **The hook
reads its event from stdin** (`hooks/done-guard:69`, `event="$(</dev/stdin)"`), not from an
environment variable, and this file already has `event()` and `fixture()` helpers that build one.
Use them rather than hand-rolling JSON; `event()`'s own comment records that hand-rolled JSON is
what made a `sensitive-guard` case pass while testing nothing.

This file does not define `ok`/`bad`. It counts through `pass` and `fail` directly, the way
`check()` does, so these two cases do the same:

```bash
# The word each harness understands. Codex's Stop schema enumerates decision as ["block"] only.
fixture "$tmp/harness" '"done_verified": "required"' '"tests/run-tests.sh"'
ev="$(event "$tmp/harness" 0 "src/a.js" "")"

out="$(printf '%s' "$ev" | ( cd "$tmp/harness" && CODEX_VERSION=0.153.4 "$GUARD" ) 2>/dev/null)"
if printf '%s' "$out" | grep -q '"decision": *"block"'; then
    printf '  PASS  emits block on codex\n'; pass=$((pass+1))
else
    printf '  FAIL  emits block on codex (got: %s)\n' "${out:0:90}"; fail=$((fail+1))
fi

out="$(printf '%s' "$ev" | ( cd "$tmp/harness" && env -u CODEX_VERSION "$GUARD" ) 2>/dev/null)"
if printf '%s' "$out" | grep -q '"decision": *"deny"'; then
    printf '  PASS  emits deny on claude\n'; pass=$((pass+1))
else
    printf '  FAIL  emits deny on claude (got: %s)\n' "${out:0:90}"; fail=$((fail+1))
fi
```

Confirm the `fixture` gate argument and the edits argument produce a denying case by reading the
existing `check ... deny ...` call in this file; if that case uses different arguments, copy those
rather than these, because the point of the two cases is the word, not the condition.

- [ ] **Step 2: Run it and watch it fail**

Run: `tests/test-done-guard.sh`
Expected: FAIL, "emits block on codex", because the hook emits `deny` unconditionally
(`hooks/done-guard:86`).

- [ ] **Step 3: Write the minimal implementation**

In the embedded python of `hooks/done-guard`, change `deny` to choose its word:

```python
def deny(reason):
    # Codex's Stop schema enumerates decision as ["block"] only; Claude Code's is "deny". One word,
    # and the gate is inert on the wrong harness without it.
    word = "block" if os.environ.get("CODEX_VERSION") else "deny"
    emit({"decision": word, "reason": "keel: " + reason})
```

- [ ] **Step 4: Run it and watch it pass**

Run: `tests/test-done-guard.sh`
Expected: PASS on both new cases and every existing one. Then `tests/run-tests.sh`.

- [ ] **Step 5: Hand over**

```bash
git add hooks/done-guard tests/test-done-guard.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "fix(done-guard): emit the Stop decision each harness understands"`.


**Verified struck 2026-09-06, against the tree rather than against this note.** Every claim the
strike rests on was checked, because a task marked "do not implement" is exactly the kind of note
that outlives the thing it describes.

- `hooks/done-guard:94` emits `"decision": "block"`, unconditionally and for both harnesses.
- `tests/test-done-guard.sh:167` pins it against the protocol and not against keel: it requires
  `block` AND rejects `deny`, `allow`, `stop` and `refuse`, so changing the word back fails rather
  than keeping every other case green, which is how the gate stayed inert before.
- The primitive this note says the manifest needs exists. `transcript_turn_tool_calls` is a
  `provides` row on both harnesses in `lib/harness/capabilities`, distinct from `stop_blocking`, and
  `done-guard` carries a `requires` row for each. Blocking a stop and seeing what the turn did are
  separate questions and the manifest now asks both, so a harness with the first and not the second
  resolves `done-guard` inactive instead of emitting "the turn's transcript could not be read" at
  the end of every turn.

**IMPLEMENTING STEP 3 WOULD BE A REGRESSION, and that is worth stating plainly rather than leaving
as an inference from the word "struck".** Its `word = "block" if os.environ.get("CODEX_VERSION")
else "deny"` reintroduces `deny` on Claude Code, which is the defect that kept this gate inert on
every harness. The task is left in place because the assumption it encodes is worth seeing; it is
not left in place to be done.

No files changed. Nothing to stage.

---

### Task 14: Detect an unreadable transcript rather than reporting zero

> **Runs before task 3, and its scope has grown twice. Extend its steps before dispatching it.**
> This is now the task that earns Codex its two transcript gates, so it carries three things its
> steps below do not yet cover:
>
> 1. **`hooks/done-guard`, folded in from struck task 13.** That task's own note says to fold it
>    here. `done-guard` needs the same two-parser treatment as `lib/context_watch.py`: an
>    unrecognised transcript returns unsupported and is surfaced, never treated as "no tool calls",
>    which would fail open and pass a turn that did nothing.
> 2. **The two Codex `provides` rows in `lib/harness/capabilities`**, `transcript_turn_usage` and
>    `transcript_turn_tool_calls`, each with a `probe:` source naming the captured fixture and the
>    counts taken from it, a Codex version, and a date. Without these rows the parsers exist and the
>    gates stay inactive, because ADR-0003 grants nothing without evidence. **Add a row only for a
>    parser that actually works against the fixture**, and if only one of the two lands, add only
>    that one and say so.
> 3. **`tests/test-harness-resolve.sh` moves to three gates on Codex.** Task 2 pinned
>    `codex resolves session-start alone` and task 2A repeated it as a rename guard. Both
>    assertions become `context-watch done-guard session-start ` in this task, and that edit is the
>    point rather than a chore: it is where a human sees Tier B change size, in the same diff as the
>    evidence that earned it.
>
> The fixture is the load-bearing artefact. Section 10.3 of the architecture requires it, with a
> canary test that fails when it stops parsing, and without it `context-watch` should be cut from
> Tier B rather than shipped.
>
> ---
>
> **PROBED 2026-09-06 on codex-cli 0.153.4, and step 3 below parses the wrong file.** A throwaway
> plugin with a `SessionStart` and a `Stop` hook that dumped its own stdin, then copied
> `transcript_path` **from inside the hook** rather than after the run. Four `codex exec` sessions on
> a ChatGPT-plan account. The plugin and its marketplace were uninstalled afterwards and
> `~/.codex/config.toml` is back to its two pre-probe entries. The captured sessions survive under
> `~/.codex/sessions/2026/09/06/`, and the probe is cheap to repeat.
>
> **1. `transcript_path` is the rollout file**, on both events:
> `~/.codex/sessions/<yyyy>/<mm>/<dd>/rollout-<ts>-<session-id>.jsonl`. Step 3's `read_usage` keys
> Codex usage off a top-level `{"type": "turn.completed", "usage": {...}}` record. **That is the
> shape of `codex exec --json`'s stdout stream**, which is what the 2026-09-05 eval gate captured
> into `result.jsonl`, and it is not the shape of anything a hook is handed. Written as sketched,
> the parser returns `unsupported` against every real Codex transcript, and the manifest rows it
> would justify would be false.
>
> **2. The rollout shape, verified.** Every line is `{"timestamp", "ordinal", "type", "payload"}`.
> Usage arrives two ways, and both are present at `Stop` time:
>
> - `type: "token_usage_record"`, with `payload.usage` and `payload.turn_token_usage`. One per model
>   response, so a turn that reasons then answers writes two.
> - `type: "event_msg"` with `payload.type: "token_count"`, carrying `payload.info.total_token_usage`,
>   `payload.info.last_token_usage` and **`payload.info.model_context_window`**.
>
> The token field names are the ones step 3 already expects (`input_tokens`, `cached_input_tokens`,
> `cache_write_input_tokens`, `output_tokens`, plus `reasoning_output_tokens` and `total_tokens`), so
> **only the record selector is wrong**. `model_context_window` arriving in the file is worth taking
> rather than assuming, since `context-watch` otherwise hard-codes a window per harness.
>
> **3. The turn's tool calls are in the same file and are present at `Stop` time**, as
> `type: "response_item"` with `payload.type` of `custom_tool_call` and `custom_tool_call_output`,
> and as `event_msg`/`item_completed`. Proven by a session told to run one shell command: the
> `Stop`-time snapshot holds 23 records including both, where the `SessionStart` snapshot holds 8 and
> neither. So `done-guard` can read what the turn did on Codex, and **both** Codex `provides` rows
> are earnable rather than one.
>
> **4. Open, and this task must settle it before writing the `transcript_turn_tool_calls` row.**
> `lib/harness/capabilities` defines that primitive as the turn's tool calls **carrying a subagent
> marker**, which on Claude Code is `isSidechain`. Nothing in the Codex rollout marks a sidechain,
> because Codex gives a subagent its own file and hands the path over as `agent_transcript_path` on
> `SubagentStop` (its input schema is in the 0.153.4 binary and carries both that and
> `transcript_path`). Either that counts as the marker, in which case say so in the row's `<source>`
> and in the manifest header, or it does not, in which case Codex earns `transcript_turn_usage`
> alone and Tier B is two gates. **Decide it in this task and write down which**; the note above
> already says to add a row only for a parser that works, and this is the same rule one level up.
>
> **5. A finding this task did not go looking for, and it is bigger than this task.** **Codex runs no
> hook until its source is trusted, and says nothing when it skips one.** Three probe sessions fired
> zero hooks with the plugin installed and enabled; the fourth, identical but for
> `--dangerously-bypass-hook-trust`, fired both. No warning, no stderr, no `codex doctor` line. That
> is exactly the "looks installed and is not" failure this whole design exists to prevent, arriving
> from a direction none of R-01 to R-06 covers, and `--dangerously-bypass-hook-trust` cannot be the
> answer for a real user. **It belongs to tasks 9, 10 and 11 rather than here**: `keel doctor` must
> report untrusted hooks as gates that are dark, and the Codex install path must tell the user the
> trust step exists. Raise it as an open question against the architecture before those tasks run.
>
> **6. Two facts tasks 10 and 11 need.** Codex hooks arrive **only** through a plugin: a
> `<plugin>/.codex-plugin/plugin.json` declaring `"hooks": "./hooks/hooks.json"`. A project-level
> `<cwd>/.codex/hooks.json` was tried first and never fired. And the marketplace manifest Codex reads
> is **`.claude-plugin/marketplace.json`**, not a `.codex-plugin` one: `codex plugin marketplace add`
> refuses a root holding the latter with "marketplace root does not contain a supported manifest".
> keel's existing `.claude-plugin/marketplace.json` is therefore already the file Codex would read.

**Story:** S-11, and the canary case of S-12
**Files:**
- Modify: `lib/context_watch.py`
- Modify: `hooks/done-guard`, `tests/test-done-guard.sh` (folded in from struck task 13, item 1 above)
- Create: `tests/fixtures/transcripts/codex.jsonl`, `tests/fixtures/transcripts/claude.jsonl`
- Modify: `tests/test-context-watch.sh`
- Modify: `lib/harness/capabilities` (the Codex `provides` rows, item 2 above)
- Modify: `tests/test-harness-resolve.sh` (the gate count on Codex, item 3 above; **two** assertions
  now, since task 2A added a repeat of task 2's as a rename guard)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `read_usage(path) -> (tokens, "claude"|"codex"|"unsupported")` in `lib/context_watch.py`.

**Depends on:** task 2

**Done when:** `tests/test-context-watch.sh` passes and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

Append to `tests/test-context-watch.sh`:

```bash
FIX="$ROOT/tests/fixtures/transcripts"

got="$(python3 -c 'import sys;sys.path.insert(0,"lib");import context_watch as c;print(c.read_usage(sys.argv[1])[1])' "$FIX/codex.jsonl")"
[ "$got" = codex ] && ok "a Codex transcript is recognised" || bad "a Codex transcript is recognised" "got $got"

n="$(python3 -c 'import sys;sys.path.insert(0,"lib");import context_watch as c;print(c.read_usage(sys.argv[1])[0])' "$FIX/codex.jsonl")"
[ "$n" -gt 0 ] && ok "a Codex transcript yields a token total" || bad "a Codex transcript yields a token total" "got $n"

u="$(mktemp)"; printf 'not a transcript\n' > "$u"
got="$(python3 -c 'import sys;sys.path.insert(0,"lib");import context_watch as c;print(c.read_usage(sys.argv[1])[1])' "$u")"
[ "$got" = unsupported ] && ok "an unknown format reports unsupported" || bad "an unknown format reports unsupported" "got $got"
n="$(python3 -c 'import sys;sys.path.insert(0,"lib");import context_watch as c;print(c.read_usage(sys.argv[1])[0])' "$u")"
[ "$n" != 0 ] && ok "an unknown format does not report zero tokens" || bad "an unknown format does not report zero tokens" "reported 0, which looks like a quiet session"
rm -f "$u"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-context-watch.sh`
Expected: FAIL, "AttributeError: module 'context_watch' has no attribute 'read_usage'".

- [x] **Step 3: Write the minimal implementation**

**Superseded by the probe of 2026-09-06; read item 1 of this task's note first.** The paragraph
below described the `codex exec --json` stream, which no hook is ever handed. What follows replaces
it.

Record the fixture from a **rollout** file, the thing `transcript_path` actually points at. The
probe sessions are under `~/.codex/sessions/2026/09/06/`, and the one to take is the session told to
run a shell command, because it is the only capture holding both usage records and tool calls. If
they are gone, repeat the probe: a plugin whose `.codex-plugin/plugin.json` declares
`"hooks": "./hooks/hooks.json"`, a `Stop` hook that copies its own `transcript_path` before exiting,
`codex plugin marketplace add` on a root holding `.claude-plugin/marketplace.json`, then
`codex exec --skip-git-repo-check --dangerously-bypass-hook-trust`. **The snapshot must be taken
inside the hook**, not after the run: taking it afterwards proves nothing about what the gate can
see, and the `SessionStart` capture is the counter-example, holding 8 records and no usage where the
`Stop` capture holds 23.

Trim it to the `session_meta`, a `turn_context`, one `response_item`/`custom_tool_call` with its
`custom_tool_call_output`, one `token_usage_record` and one `event_msg`/`token_count`. **Strip every
absolute path naming a developer's home directory**, which in a rollout means at least `session_meta`
and `turn_context`, and check the tool call's own arguments too. Save it at
`tests/fixtures/transcripts/codex.jsonl`. Record a Claude Code counterpart the same way at
`tests/fixtures/transcripts/claude.jsonl`, so the sniffer is tested on both shapes rather than on one
shape and one negative.

Then add to `lib/context_watch.py`, which already imports `json`, `os` and `sys` at module level
(`:22-24`), so `read_usage` needs no new import:

```python
UNSUPPORTED = -1

def read_usage(path):
    """Return (tokens, kind). kind is "claude", "codex" or "unsupported".

    Selected by sniffing the file's own shape rather than by which harness is running. A format
    change WITHIN one harness is the case that actually bites, and a harness-keyed switch cannot
    see it. Codex says outright that the transcript is not a stable interface for hooks.

    Never returns 0 for a file it could not read. A watchdog that has stopped working looks exactly
    like a session using no context, and that is the silent-gate failure in miniature.
    """
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            lines = [ln for ln in (l.strip() for l in fh) if ln]
    except OSError:
        return (UNSUPPORTED, "unsupported")

    claude_total = 0
    codex_total = 0
    for ln in lines:
        try:
            rec = json.loads(ln)
        except ValueError:
            continue
        if not isinstance(rec, dict):
            continue
        # Claude Code: per assistant turn, message.usage, sidechain turns excluded.
        msg = rec.get("message")
        if isinstance(msg, dict) and isinstance(msg.get("usage"), dict) and not rec.get("isSidechain"):
            u = msg["usage"]
            claude_total += (u.get("input_tokens") or 0) + (u.get("cache_creation_input_tokens") or 0) \
                          + (u.get("cache_read_input_tokens") or 0) + (u.get("output_tokens") or 0)
            continue
        # Codex: a rollout record, {"timestamp","ordinal","type","payload"}. Verified 2026-09-06 on
        # 0.153.4 against the file transcript_path actually names. One token_usage_record per model
        # RESPONSE, not per turn, so a turn that reasons then answers writes two and the last one
        # wins: payload.usage is cumulative for the response, and taking the max would be wrong for
        # the same reason summing would be. payload.turn_token_usage is the per-turn roll-up if the
        # per-turn number is what is wanted; pick one and say which in the docstring.
        payload = rec.get("payload")
        if rec.get("type") == "token_usage_record" and isinstance(payload, dict) \
                and isinstance(payload.get("usage"), dict):
            u = payload["usage"]
            codex_total = (u.get("input_tokens") or 0) + (u.get("cached_input_tokens") or 0) \
                        + (u.get("cache_write_input_tokens") or 0) + (u.get("output_tokens") or 0)

    if claude_total:
        return (claude_total, "claude")
    if codex_total:
        return (codex_total, "codex")
    return (UNSUPPORTED, "unsupported")
```

**The caller is `hook()`** (`lib/context_watch.py:358`), the entry point that reads
`transcript_path` off the event and today does `if not transcript or not os.path.exists(transcript):
return 0` at `:376-377`. That early return is the behaviour this task changes: a transcript that
exists and does not parse must not take the same silent path as one that is absent. `measure()`
(`:87`) and `_cached_measure()` (`:330`) keep their signatures. In `hook()`:

```python
tokens, kind = read_usage(transcript)
if kind == "unsupported":
    # Say so once, and skip. Reporting 0 here is the failure this function exists to prevent.
    sys.stderr.write("keel context-watch: transcript format not recognised, watchdog inactive\n")
    return 0
```

`keel doctor`'s watchdog section reports the same thing, so the person sees it where they are already
looking rather than only in a hook's stderr.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-context-watch.sh`
Expected: PASS on all four new cases and every existing one. Then `tests/run-tests.sh`.

- [x] **Step 5: Hand over**

```bash
git add lib/context_watch.py tests/fixtures/transcripts/codex.jsonl tests/test-context-watch.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "fix(context-watch): report an unreadable transcript instead of zero"`.

---

> **DONE 2026-09-06, inline, and here is what actually landed.** Both Codex rows are in the
> manifest, `tests/test-harness-resolve.sh` reads `context-watch done-guard session-start ` on both
> assertions, and Tier B is three gates. `tests/run-tests.sh` green. Nine deviations from the steps
> above, all of them found by building the thing rather than by reading it:
>
> 1. **The token sum in step 3's sketch is wrong, and it is the kind of wrong that returns a
>    plausible number.** It adds `input_tokens + cached_input_tokens + cache_write_input_tokens +
>    output_tokens`, by analogy with the Claude branch. Codex reports `cached_input_tokens` INSIDE
>    `input_tokens` and states the answer as `total_tokens`. On the fixture the sketch gives 27079
>    where the file says 14023, so every Codex session would read at roughly twice its occupancy and
>    hard-stop at half the intended threshold. `_measure_codex` takes `total_tokens`.
> 2. **`read_usage` alone would have left `context-watch` dark on Codex, with the manifest calling
>    it active.** `hook()` measures through `measure()`, not `read_usage`, and `measure()` understood
>    Claude rows only: a Codex session measured 0 tokens and returned at `if not tokens`. Granting
>    `transcript_turn_usage` on the strength of a sniffer nothing measures with would have been the
>    "looks installed and is not" failure committed by this plan. So `measure()` gained the Codex
>    parser too, and `tests/test-context-watch.sh` pins the whole chain in one line.
> 3. **The window is read, per item 2 of the note, and it was not optional.** Codex states
>    `model_context_window` 258400. Left to the 200,000 default, every Codex session hard-stops at
>    66% of the room it has. `declared_window()` reads it and `window_for()` gained a `declared`
>    keyword, ordered above the model-string guess and below observation, so it is a better starting
>    point and never a ceiling.
> 4. **Item 4 is settled YES, and the manifest header carries the reasoning.**
>    `transcript_turn_tool_calls` now reads "the turn's tool calls, attributed to the agent that
>    made them" rather than "carrying a subagent marker". Demanding a marker FIELD is the same
>    schema-in-the-name mistake task 2A removed, one level up: `isSidechain` is a Claude Code row
>    field. Codex attributes by never interleaving, one rollout per thread with the subagent's own
>    file handed over as `agent_transcript_path`, plus a thread id and turn id on every record.
>    That is strictly finer than a boolean, so it earns the primitive. Tier B is three gates.
> 5. **No `tests/fixtures/transcripts/claude.jsonl` was created.**
>    `claude-stop-edited-no-test.jsonl` is already a capture from a real Claude Code turn carrying
>    8 rows with `message.usage` and 3 `tool_use` blocks, which is exactly the counterpart the step
>    asks for. A second near-identical recording is duplication that would drift.
> 6. **The fixture holds two `token_usage_record`s, not the one the step lists.** With one, changing
>    `tokens = total` to `tokens += total` leaves the suite green, so the per-response rule is
>    unpinned. The capture's real second record makes 13993 then 14023 distinguishable from 28016.
>    `session_meta.base_instructions` is replaced with `<redacted>`: it is 30KB of OpenAI's own
>    system prompt and nothing parses it. Home directory paths and the timezone are stripped.
> 7. **`hooks/done-guard` reads Codex edits from `apply_patch` headers**, which Codex's own
>    instructions make the only sanctioned way to change a file. Codex exposes one `exec` tool
>    running a snippet, so there is no `Edit` or `Bash` to match on. A file written with a shell
>    redirect instead is not seen, which is the same limit the hook's header already declares for a
>    test suite run through a wrapper.
> 8. **10.3's claim that `unsupported` is "surfaced twice" was never true and is corrected.**
>    `hooks/context-watch` ends in `2>/dev/null` so a broken hook cannot noise up every turn, and
>    the message dies there. Lifting that or emitting a `systemMessage` changes Claude Code
>    behaviour on a shared path, which R-01 forbids. `keel doctor` is the whole surface, and task 11
>    adds it. The test fires at `lib/context_watch.py` directly for that reason.
> 9. **The two findings that were not this task's now have homes**, per the handoff, and since
>    2026-09-06 they have steps rather than only a record. The hook trust finding is open question 6
>    in section 12 of the architecture and a note on each of tasks 9, 10 and 11 saying what that task
>    owes it, because a question that lives only in the architecture is one the executor of task 9
>    never reads. The marketplace and plugin facts are in section 10.2, which is where the plugin
>    layout lives, and in task 10's note; the handoff said 10.6, which is the fan-out skills section.
>
> 10. **One fail-open of my own, found by the sweep rather than by reading, and worth recording
>    because the next harness reader will meet it too.** Codex puts the patch and the command in the
>    same string: an `exec` call carrying `apply_patch` holds the whole patch body in the same field
>    the test-run check searches. So a turn that patched any file quoting `tests/run-tests.sh`, and
>    this repository is full of them, read as having run the suite and the guard went quiet on
>    exactly the edit it exists to catch. `_PATCH_BODY` strips the patch region before that check,
>    which keeps a genuine `apply_patch ... && <test>` visible, and a case pins it.
>
> **Reviewed by a 15 mutant sweep, one guard at a time, not by two review passes.** This harness
> forbids subagents, so the two dispatches the plan's review-depth decision calls for could not be
> run; `skip-review-for-small-keel-repairs` and the precedent set by task 2A are what this follows.
> 14 killed. The one survivor is declared equivalent in `hooks/done-guard` beside the line it
> mutates: relaxing the `custom_tool_call` selector changes nothing today, because no other rollout
> record carries a string `input`. **Two tasks 15 to 18 should not inherit this: the review-depth
> decision of 2026-09-05 still stands wherever subagents are available.**

---

### Task 15: Move the fan-out pin out of skill bodies into a delegation profile

**Story:** S-15
**Files:**
- Modify: `skills/repo-snapshot/SKILL.md`, `skills/port-assess/SKILL.md`,
  `skills/apex-port-plan/SKILL.md`, `skills/write-plan/SKILL.md`, `skills/security-audit/SKILL.md`,
  `skills/shape-idea/SKILL.md`, `skills/write-docs/SKILL.md`
- Modify: `skills/execute-plan/references/parallel-batches.md`
- Modify: `tests/validate-skills.sh`

**Seven skills carry the pin, not five.** `grep -rln 'model \`sonnet\`' skills/` returns
`repo-snapshot`, `port-assess`, `apex-port-plan`, `write-plan`, `security-audit`, **`shape-idea`**
and **`write-docs`**. The last two are not fan-out skills and were missed by the design's inventory,
which counted only the lettered fan-outs. Rewrite all seven or step 4 is unreachable, because the new
check greps the whole of `skills/`.

`skills/write-plan/references/plan-review.md`, `skills/execute-plan/references/subagent-prompts.md`
and `skills/execute-plan/references/preconditions.md` are **not** modified: each names
`model \`inherit\``, which stays. They are listed here only so a reader who greps for `model` and
finds them knows they were considered.

**Interfaces:**
- Consumes: `.codex/agents/keel-fanout.toml`, from task 9.
- Produces: the phrase `delegation profile \`keel-fanout\`` as the marker the validator recognises.

**Depends on:** task 9

**Done when:** `tests/validate-skills.sh` reports 0 FAIL and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

In `tests/validate-skills.sh`, replace the alias list at `:319-323` and the `names_model` helper at
`:344` so that a delegation profile satisfies the rule and a vendor alias does not:

```bash
# Until 2026-09-05 this accepted sonnet, opus, haiku, fable or inherit. Four of those are Anthropic
# model names and mean nothing on Codex; `inherit` is neutral and means "the driver's model", which
# is the opposite of the routing decision docs/ideas/model-routing.md:130-141 measured at 43% off
# the delegated reading. So a body may no longer name a model at all: it names a delegation profile,
# and each harness resolves that to its own model. ADR-0005.
bad_models=$(grep -rhoiE 'model `[a-z0-9.-]+`' skills/*/SKILL.md skills/*/references/*.md 2>/dev/null \
    | sed 's/^[Mm]odel `//; s/`$//' | sort -u \
    | grep -vxE 'inherit' || true)
[ -z "$bad_models" ] \
  || report "a skill names a vendor model alias: $(printf '%s' "$bad_models" | tr '\n' ' '). Name a delegation profile instead; ADR-0005."

names_model() { grep -qiE 'delegation profile `[a-z0-9-]+`|model `inherit`' "$1" 2>/dev/null; }
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/validate-skills.sh`
Expected: FAIL, "a skill names a vendor model alias: sonnet", listing the five bodies that still
pin `sonnet`.

- [x] **Step 3: Write the minimal implementation**

Rewrite the six pins. Each rewrite removes the harness-specific agent type and the vendor alias, and
names the profile instead. The measured word cost of the neutral wording is +2 to +7 words per body
and every body clears the 900 ceiling with over 100 words to spare, so nothing needs trimming to
make room:

- `skills/repo-snapshot/SKILL.md:49`: `Dispatch these subagents concurrently **in one message**, delegation profile \`keel-fanout\`:`
- `skills/port-assess/SKILL.md:37`: `Dispatch these subagents in one message, delegation profile \`keel-fanout\`. Each is told:`
- `skills/apex-port-plan/SKILL.md:30`: `Dispatch these subagents **in one message** so they run concurrently, delegation profile \`keel-fanout\`, and`
- `skills/write-plan/SKILL.md:44`: `one message, delegation profile \`keel-fanout\`, each citing \`path:line\`, said in one line.`
- `skills/security-audit/SKILL.md:46`: `one per phase, delegation profile \`keel-fanout\`, and say`
- `skills/shape-idea/SKILL.md:39` and `skills/write-docs/SKILL.md:55`: same substitution, `model
  \`sonnet\`` to `delegation profile \`keel-fanout\``. Read each line first: neither is a lettered
  fan-out, so confirm the sentence still reads correctly before and after the replacement rather
  than applying it blind.
- `skills/execute-plan/references/parallel-batches.md:40`: replace `isolation: worktree`, which is
  the literal parameter name of Claude Code's Agent tool, with a sentence describing the property:
  each agent works in its own checkout so no two write the same tree.

`model \`inherit\`` stays where it is, at `skills/write-plan/SKILL.md:93`,
`skills/write-plan/references/plan-review.md:3` and
`skills/execute-plan/references/subagent-prompts.md:171`. It is already harness-neutral and it means
what it says there: judgement work runs on the driver's model deliberately
(`docs/ideas/model-routing.md:114-116`). **`execute-plan`'s body needs no edit at all.**

- [x] **Step 4: Run it and watch it pass**

Run: `tests/validate-skills.sh`
Expected: "OK    25 skills validated", 0 FAIL. Warnings about bodies over the 700 target are
pre-existing and unchanged. Then `tests/run-tests.sh`; expected "All test files passed".

- [x] **Step 5: Hand over**

```bash
git add skills/repo-snapshot/SKILL.md skills/port-assess/SKILL.md skills/apex-port-plan/SKILL.md \
        skills/write-plan/SKILL.md skills/security-audit/SKILL.md \
        skills/shape-idea/SKILL.md skills/write-docs/SKILL.md \
        skills/execute-plan/references/parallel-batches.md tests/validate-skills.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "refactor(skills): name a delegation profile instead of a vendor model alias"`.


**Landed 2026-09-06, with one thing left open that this task cannot close on its own.**

**THE PROFILE RESOLVED ON ONE HARNESS, NOT TWO. Raised, decided, and closed in this task.** The
decision was Bernard's on 2026-09-06: declare it in the plugin. `agents/keel-fanout.md` now ships in
the tree, pinned to `sonnet`, which keeps the routing `docs/standards.md` records as measured firing
on 2026-08-20. **No manifest key was added**: `agents/` is auto-discovered from the plugin root,
`.claude-plugin/plugin.json` declares neither `skills` nor `hooks` either, and an explicit `agents`
key REPLACES the default scan rather than adding to it, which is a footgun for the second profile
rather than a help for the first. Checked against code.claude.com/docs/en/plugins-reference rather
than assumed. **R-01 is untouched**: nothing `keel init` writes changed.

**The clause is now a check rather than a sentence**, as item 8 of `tests/test-harness-claims.sh`:
every profile a body names must resolve on both harnesses, and the definition must be TRACKED,
because `tests/export-public.sh` publishes `git ls-files` and nothing else. An untracked agent
definition resolves perfectly inside this repository and ships to nobody.

The paragraph below is what the gap looked like before it was closed, kept because the shape of it
is the argument for the check.

**`keel-fanout` was written by
`lib/harness/codex.sh` to `.codex/agents/keel-fanout.toml` and exists nowhere else: the plugin
manifest declares no `agents` key, there is no `agents/` directory, and `lib/harness/claude.sh`
writes none. So after this task seven skill bodies name a profile a Claude Code session cannot
resolve, and the dispatch there falls back to the driver's model. That is not a broken dispatch, it
is an **unpinned** one, which is the exact failure `tests/validate-skills.sh` says its own rule
exists to catch: an unpinned dispatch inherits whatever the driver is paying for and the output
looks like output either way. `docs/standards.md` records the `sonnet` routing as measured firing on
2026-08-20, so this is a regression on the harness where it was proven, not on the one being added.

**ADR-0005's Verification names it in so many words**: holding requires that "the profile resolves
on both harnesses". One of its three clauses is now met by this task, the vendor aliases and the
harness-specific agent types are gone; the other two are not.

The alternative was writing `.claude/agents/keel-fanout.md` from `lib/harness/claude.sh`, symmetric
with the Codex side. It was not taken: it changes what `keel init` writes on Claude Code, which R-01
forbids, and the byte-identical baseline in `tests/test-keel.sh` would have had to be taught it
deliberately.

**What was rewritten.** Seven bodies, not the six step 3 counts: `repo-snapshot`, `port-assess`,
`apex-port-plan`, `write-plan`, `security-audit`, `shape-idea`, `write-docs`. The preamble already
corrects the count from five to seven; step 3 still says six.

**`Explore` was removed from five bodies, and step 3 only removes it from three.** ADR-0005 bars a
harness-specific agent type as well as a vendor alias, and `Explore` is Claude Code's. Step 3's
given rewrites drop it from `repo-snapshot`, `port-assess` and `apex-port-plan` and leave it in
`write-docs` and `write-plan`, which would have left the ADR half-applied with no check anywhere to
notice. Removed from all five. `grep -rn '`Explore`' skills/` now returns nothing.

**`tests/test-validate-skills.sh` asserted the OLD rule and had to be rewritten, which step 1 does
not mention.** Its case "a known model alias passes" fed `` model `sonnet` `` to the validator and
required exit 0. A rule change that leaves its own fixture behind is a rule the next person reverts
while believing the suite. It is now four cases: a vendor alias rejected, an invented alias rejected,
`inherit` still accepted, and a delegation profile accepted.

**One wrap is load-bearing.** `names_model` matches `delegation profile \`x\`` on a single line, so
wrapping between the words silently fails the rule. `security-audit` was wrapped that way first and
went red; the break belongs before `delegation`, never inside the phrase.

**Two mutants survived the first sweep, and both were checks that could not fail.** The Codex half
of the resolution check grepped `codex.sh` for the profile name and matched the `.toml` FILENAME on
the `cat >` line, so renaming the profile inside the file left it green while Codex resolved
nothing; it now requires the path AND the declared `name =`. And the vendor-alias rule had no
fixture isolating it: every body carrying an alias also failed the dispatch rule, so putting
`sonnet` back on the accepted list kept the suite green. A body that satisfies the dispatch rule and
still names an alias is the case that only the alias rule can catch, and it exists now.

**A new top-level directory tripped `tests/test-doc-claims.sh`**, which requires
`docs/06-repo-layout.md`'s tree to show every entry `git ls-files` produces. That is the third time
this plan has added an artifact a checker's model of the world predated, and the third time the
checker was right. `agents/` is in the tree now.

**Verification.** `tests/validate-skills.sh` 0 FAIL, 25 skills, the same 6 word-count warnings as
before this task. `tests/test-validate-skills.sh` 68 passed, up from 65.
`tests/test-harness-claims.sh` 30 passed, up from 26. **Mutation sweep: 5 mutants, 5 killed**, after
the two above were tightened. `tests/run-tests.sh` green,
exit 0, shellcheck clean. `docs/standards.md` carried the old rule as current prose and now states
the new one, including that `inherit` is not the neutral replacement for the four removed words.

---

### Task 16: Harness-qualify the two skill instructions naming Claude Code plugins

**Story:** S-16
**Files:**
- Modify: `skills/security-audit/SKILL.md`, `skills/create-skill/SKILL.md`
- Modify: `docs/02-skill-catalog.md`, `docs/04-plugin-strategy.md`

**Interfaces:**
- Consumes: the claim tag syntax, from task 5.
- Produces: nothing new.

**Depends on:** task 5

**Done when:** `tests/validate-skills.sh` reports 0 FAIL, `tests/test-harness-claims.sh` passes, and
`tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

Append to `tests/test-harness-claims.sh`:

```bash
# 9. A plugin instruction that only applies to one harness says so where it is given.
for f in skills/security-audit/SKILL.md skills/create-skill/SKILL.md; do
    grep -qi 'claude code' "$f" && ok "$f qualifies its plugin instruction" \
      || bad "$f qualifies its plugin instruction" "names a plugin with no harness"
done
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-harness-claims.sh`
Expected: FAIL on both, because neither body names a harness today.

- [x] **Step 3: Write the minimal implementation**

At "Step 5: Plugin and gate" in `skills/security-audit/SKILL.md`, qualify the `security-guidance`
and `/security-review` instruction: both are Claude Code mechanisms with no established Codex
counterpart, and the paragraph already carries an inline fallback, the pattern eighteen skills use.
Do the same for `skill-creator` at `skills/create-skill/SKILL.md:74-75`.

Keep the plugin name in the body. `tests/validate-skills.sh:390-463` requires a plugin delegation
claimed in `docs/04-plugin-strategy.md` or `docs/02-skill-catalog.md` to be named in the delegating
skill's **body**, so removing it there fails the build. Update the two documents in the same task, so
body and document move together.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-harness-claims.sh`, then `tests/validate-skills.sh`
Expected: PASS and 0 FAIL. Then `tests/run-tests.sh`.

- [x] **Step 5: Hand over**

```bash
git add skills/security-audit/SKILL.md skills/create-skill/SKILL.md \
        docs/02-skill-catalog.md docs/04-plugin-strategy.md tests/test-harness-claims.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "docs(skills): qualify the two Claude Code plugin instructions"`.


**Landed 2026-09-06.** Staged, not committed, per step 5.

**`docs/04-plugin-strategy.md` was NOT modified, and that is the finding rather than an omission.**
Step 3 lists it as a file to update. It already scopes itself, in a block quote at the top: "this
document is about Claude Code, end to end", with the reasoning that qualifying individual rows
"would produce a document that is locally correct and globally wrong", and it already says none of
it carries to Codex. It also names where the per-skill marking belongs: "Where keel's own behaviour
depends on one of these plugins, that dependence is Claude Code only and is marked as such in
`docs/02-skill-catalog.md`." Editing it would have added a second, weaker statement of a rule it
already states well. **The document it points at is the one that was wrong.**

**In `docs/02-skill-catalog.md`, `security-audit` was already marked and `create-skill` was not.**
Line 383 carried "Plugin calls, Claude Code only"; line 529 carried a bare "Plugin call". So doc 04
made a promise about doc 02 that doc 02 kept in one place and broke in the other, which is exactly
the drift a claim with no check acquires. Marked now, in the format the other entries use.

**One word crossed a budget and had to come back.** The first wording of `create-skill`'s step 6 put
its body at 701 words, one over ADR-0001's 700 target, which added a seventh validator warning and
with it an obligation to have a passing eval arm at that length. Step 4 of this task says the
warnings are "pre-existing and unchanged", and it was right to say so: a task that adds an eval
obligation for one word has not done the cheap thing. Reworded to 698.

**Two entries in `docs/02-skill-catalog.md` are still unmarked and this task does not cover them.**
Line 226 hands `design-architecture` to `context7`, and `skills/design-architecture/SKILL.md:43`
gives that instruction unqualified too. `code-review` at line 354 is the same shape. Both are in doc
04's delegation table, so doc 04's promise covers them and doc 02 does not keep it. They are
pre-existing rather than introduced here, and the check added in step 1 names two files by hand
rather than deriving the list, so it will not catch them. **A better check would read doc 04's
delegation table and require every delegating body to name a harness.** Not built here, because the
task's two files are the ones its story covers.

**Verification.** `tests/test-harness-claims.sh` 32 passed, up from 30. `tests/validate-skills.sh`
0 FAIL, 25 skills, the same 6 warnings as before this task. `tests/run-tests.sh` green, exit 0,
shellcheck clean. **Mutation sweep: 2 mutants, 2 killed**, one per qualified body.

---

### Task 17: Pin the release-gate scenario set in a file

**Story:** S-17
**Files:**
- Create: `tests/evals/gate-scenarios`
- Modify: `tests/test-eval-harness.sh`
- Modify: `tests/evals/README.md`

**Interfaces:**
- Consumes: nothing.
- Produces: `tests/evals/gate-scenarios`, one scenario name per line.

**Depends on:** none

**Done when:** `tests/test-eval-harness.sh` passes and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

Append to `tests/test-eval-harness.sh`:

```bash
GATE="$REPO/tests/evals/gate-scenarios"
[ -f "$GATE" ] && ok "the gate scenario set is pinned in a file" \
  || bad "the gate scenario set is pinned in a file" "absent; it lives only in results.md prose"

missing=""
while IFS= read -r s; do
    case "$s" in ''|'#'*) continue ;; esac
    [ -f "$REPO/tests/evals/scenarios/$s.md" ] || missing="$missing $s"
done < "$GATE"
[ -z "$missing" ] && ok "every gate scenario exists" || bad "every gate scenario exists" "$missing"

# README states the count as a word today: tests/evals/README.md:122 reads "six are dispatched at
# the release gate". Task 3 of this step rewrites that sentence to carry the digit, which is also
# what tests/test-doc-claims.sh's claim_in helper requires: its own failure message says "A number a
# check cannot read is the same problem as a wrong one: reword the sentence to carry a digit".
n="$(grep -cvE '^$|^#' "$GATE")"
grep -qE "$n scenarios are dispatched at the release gate" "$REPO/tests/evals/README.md" \
  && ok "README's gate count matches the file ($n)" \
  || bad "README's gate count matches the file" "README does not state the digit $n"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-eval-harness.sh`
Expected: FAIL, "the gate scenario set is pinned in a file: absent; it lives only in results.md prose".

- [x] **Step 3: Write the minimal implementation**

Create `tests/evals/gate-scenarios`:

```
# The scenarios dispatched at every release gate, one per line.
#
# Pinned here on 2026-09-05 because the set existed in no file: README said six, this file's own
# results.md said seven at :2499, and results.md:2864-2870 recorded the disagreement as live and
# unresolved. A second supported harness doubles the matrix, and doubling an undefined set gives two
# undefined sets, so it is settled before the Codex arms are added rather than after.
#
# commit-outside-a-worktree is the scenario whose membership was disputed. It is IN: it is the only
# scenario testing a subagent's behaviour, and that path is exercised by nothing else.
tdd-under-deadline
debug-obvious-cause
ship-with-flaky-tests
build-with-no-prd
done-without-verifying
incident-diagnose-first
commit-outside-a-worktree
```

Rewrite `tests/evals/README.md`. It currently reads "Twelve scenarios exist; six are dispatched
at the release gate, one dispatch each." Replace the word with a digit and name this file as the
source, so both this test and `tests/test-doc-claims.sh`'s digit-seeking `claim_in` can read it:
"Twelve scenarios exist; 7 scenarios are dispatched at the release gate, listed in
`tests/evals/gate-scenarios`, one dispatch each."
Add a line to `tests/evals/results.md` recording that the six-versus-seven question is settled and
which way, so the next reader finds the answer where the disagreement was recorded.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-eval-harness.sh`
Expected: PASS on all three new cases. Then `tests/run-tests.sh`; `tests/test-doc-claims.sh` also
counts scenarios, so confirm it stays green.

- [x] **Step 5: Hand over**

```bash
git add tests/evals/gate-scenarios tests/test-eval-harness.sh tests/evals/README.md tests/evals/results.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "test(evals): pin the release-gate scenario set in a file"`.


**Landed 2026-09-06.** Staged, not committed, per step 5. The gate is **seven**, and
`commit-outside-a-worktree` is in it.

**THE COUNT LIVED IN THREE PLACES, NOT TWO, AND THE THIRD IS THE ONE THAT RAN.** Step 3 names
`tests/evals/README.md` and `tests/evals/results.md`. It misses
`docs/runbooks/cutting-a-release.md`, which carried its own hardcoded
`ARMS="tdd-under-deadline ... incident-diagnose-first"` at `:66`, said "Dispatch all six
concurrently" at `:53`, and repeated the unresolved question in its own "Still open" section. README
and results.md DESCRIBE the gate; the runbook is what somebody copies and runs, so it is the only
one of the three whose disagreement actually dispatches the wrong set. That is why the gate kept
running six while results.md said seven: nobody was reading results.md at dispatch time.

**So the script reads the file rather than being corrected to say seven.** Fixing the number would
have left two copies that can drift again, which is the failure this task exists to end.
`ARMS="$(grep -vE '^$|^#' "$REPO/tests/evals/gate-scenarios")"`, verified under bash rather than
asserted: seven arms, each resolving to a scenario file.

**A fourth check was added beyond step 1's three**, for the runbook count, for the reason above.

**Step 1's test code was rewritten in this file's own style.** It is given as `A && ok || bad`,
which is the idiom every other suite uses under a file-wide `# shellcheck disable=SC2015`.
`tests/test-eval-harness.sh` carries no such disable and its existing cases are all `if/then`, so
the given form put four SC2015 findings into a build whose profile lints at default severity, where
an info finding is a red build.

**Watch the shell.** The interactive shell here is zsh, which does not word-split an unquoted
expansion, so a hand-check of the runbook's `for a in $ARMS` line reported ONE arm and looked like a
bug in the file. The script is `#!/usr/bin/env bash` and splits correctly. Re-checked under
`bash -c` before believing either answer.

**Verification.** `tests/test-eval-harness.sh` 39 passed, up from 35. `tests/run-tests.sh` green,
exit 0, shellcheck clean, `tests/test-doc-claims.sh` still 58. **Mutation sweep: 5 mutants, 5
killed**: a gate entry naming no scenario file, the README count drifting, the runbook count
drifting, a scenario dropped from the set, and the file itself deleted. The first needed care, since
`commit-outside-a-worktree` appears twice in the file and mutating the comment rather than the entry
is a fault in the sweep, not a survivor.

---

### Task 18: Print the dispatch recipe for the harness under test

**Story:** S-18
**Files:**
- Modify: `tests/evals/stage.sh`
- Modify: `tests/evals/README.md`
- Modify: `tests/test-eval-harness.sh`

**Interfaces:**
- Consumes: `tests/evals/gate-scenarios`, from task 17.
- Produces: `stage.sh [--harness claude|codex] <scenario>`.

**Depends on:** task 17

**Done when:** `tests/test-eval-harness.sh` passes and `tests/run-tests.sh` is green.

**This is a `verify` story, not `build`.** `tests/evals/run.sh` is already harness-neutral: it pastes
each injected `SKILL.md` into the prompt as plain text (`run.sh:33`) rather than relying on a plugin
install. `stage.sh` never dispatches anything; `stage.sh:99` is a line inside a heredoc printed to
**stderr** as guidance for a human, and `run.sh:3` says dispatching and scoring are done by an agent,
deliberately. **There is no dispatcher and no scorer to write, and no second output parser is needed
because there is no first one.** Only the guidance text changes.

- [x] **Step 1: Write the failing test**

Append to `tests/test-eval-harness.sh`:

```bash
out="$("$REPO/tests/evals/stage.sh" --harness codex tdd-under-deadline 2>&1 >/dev/null)"
printf '%s' "$out" | grep -q 'codex exec' && ok "codex guidance names codex exec" || bad "codex guidance names codex exec" "$out"
printf '%s' "$out" | grep -q -- '--skip-git-repo-check' \
  && ok "codex guidance carries --skip-git-repo-check" \
  || bad "codex guidance carries --skip-git-repo-check" "the staged fixture is not a git repo and Codex refuses to run outside one"

out="$("$REPO/tests/evals/stage.sh" tdd-under-deadline 2>&1 >/dev/null)"
printf '%s' "$out" | grep -q 'claude -p' && ok "the default guidance is unchanged" || bad "the default guidance is unchanged" "$out"

grep -q 'claude\|codex' "$REPO/tests/evals/run.sh" \
  && bad "run.sh names no harness" "$(grep -n 'claude\|codex' "$REPO/tests/evals/run.sh" | head -1)" \
  || ok "run.sh names no harness"

# The bypass flag is eval-only. It disables the sandbox, and a user who copies it out of a keel
# document as a normal way to run Codex has been handed a footgun by us.
# The flag disables the sandbox. It belongs in eval guidance and in the dated records that explain
# why the eval guidance says it, and nowhere a user reads as instructions. So the rule is a denylist
# of the places a user reads, not an allowlist of one directory: the plan and the design both quote
# the recipe legitimately, and an allowlist would fail the moment they are committed.
stray="$(git -C "$REPO" grep -l -- '--dangerously-bypass-approvals-and-sandbox' \
         -- README.md 'docs/*.md' 'docs/runbooks/*.md' 'skills/**' 'templates/**' 'output-styles/**' || true)"
[ -z "$stray" ] && ok "the bypass flag appears in no user-facing document" \
  || bad "the bypass flag appears in no user-facing document" "$stray"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-eval-harness.sh`
Expected: FAIL, "codex guidance names codex exec", because `stage.sh` takes no `--harness` flag.

The last case passes from the start, and that is intended: the recipe currently lives in
`tests/evals/results.md`, in this plan, and in the design's section 10.4, none of which a user reads
as instructions. The case exists to fail on the day somebody helpfully copies it into the README or
into `docs/harness-support.md`.

- [x] **Step 3: Write the minimal implementation**

Parse `--harness` in `stage.sh` (default `claude`) and select the guidance heredoc at `:94-104`
accordingly. The Codex recipe, proven on 2026-09-05 and recorded in `tests/evals/results.md`:

```
  cd $dir/project && codex exec "$(cat ../prompt.md)" \
      --ignore-user-config --ignore-rules \
      --dangerously-bypass-approvals-and-sandbox \
      --skip-git-repo-check --json > $dir/result.jsonl
```

Add the flag mapping to `tests/evals/README.md` beside the existing "every flag there is load
bearing" list, including the two caveats that are not obvious:

- `--skip-git-repo-check` is **required**, not optional. The staged fixture is not a git repository
  and Codex refuses to run outside one. The Claude recipe needs no equivalent.
- `--ignore-user-config` is only a **partial** counterpart to `--setting-sources ""`. It suppresses
  `$CODEX_HOME/config.toml`. It is **not established** that it suppresses skill discovery from
  `$HOME/.agents/skills` or `AGENTS.md` loading, both of which Codex reads from outside the working
  directory. Until that is checked, a Codex baseline arm is only trustworthy on a machine with
  neither present. Check before relying on it, and record the result here.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-eval-harness.sh`
Expected: PASS on all five new cases. Then `tests/run-tests.sh`; expected "All test files passed".

- [x] **Step 5: Hand over**

```bash
git add tests/evals/stage.sh tests/evals/README.md tests/test-eval-harness.sh \
        docs/architecture/tiered-multi-harness-support.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "test(evals): print the dispatch recipe for the harness under test"`.


**Landed 2026-09-06. This is the last task in the plan.**

**Step 1's denylist pathspec was wrong and the case failed on the design that justifies it.** In a
plain git pathspec `*` CROSSES `/`, exactly as it does in a `case` pattern, which
`tests/test-harness-claims.sh` already records as the trap that swept dated PRD text into a check
about current claims. So `'docs/*.md'` matched `docs/architecture/`, `docs/ideas/` and `docs/plans/`,
which are precisely the three documents this task says quote the recipe legitimately. Fixed with
`:(glob)` magic on the two docs patterns, which is what stops `*` crossing. The case is empty now,
and step 2 is right that it passes from the start: it exists to fail the day somebody copies the
recipe into `README.md` or `docs/harness-support.md`.

**A sixth case beyond step 1's five: an unknown `--harness` must REFUSE.** The mutation sweep found
the refusal had no fixture. Falling back would print the Claude recipe for what the operator
believes is a Codex arm, which is a difference in treatment between two arms of the same comparison
recorded as nothing, the fault this whole harness exists to prevent. It refuses before staging, so a
typo does not leak a directory into TMPDIR either.

**Step 1's test code was rewritten in `if/then`, for the same reason as task 17**: this file carries
no file-wide SC2015 disable and the given `A && ok || bad` form puts info findings into a build that
lints at default severity.

**The design said the recipe would be "driven by a recipe row in the manifest" and it is a flag
instead.** The manifest answers which gates a harness provides; a dispatch recipe is neither a gate
nor a capability, so a row there would be a record kind `resolve.sh` must skip and no `requires` row
can reference. Step 3 of this task already says "parse `--harness` in `stage.sh`", so the plan had
overridden the design; the design row now says so rather than leaving the two disagreeing.

**The design also predicted "Nothing in `tests/test-eval-harness.sh`", and that was wrong.** The
guidance is a staging property: it is chosen at stage time and printed by `stage.sh`. Six cases
were added. That row is corrected rather than left standing.

**STILL OUTSTANDING, and no task in this plan delivers it.** The design lists "Five scenario files
name `stream-json` in prose" as a change the Codex work needs, and task 18's Files list does not
include the scenario bodies. `--output-format stream-json` is a Claude Code flag given as a scorer
instruction in `assess-a-stale-standard`, `audit-a-brownfield-tree`, `author-a-standard`,
`commit-outside-a-worktree` and `seed-a-greenfield-mobile-app`; the Codex counterpart is `--json`,
which is already a stream. This is the same class as task 16, an instruction that is a guarantee in
the imperative, and it is the one design item the plan finishes without. **It needs its own task.**
`commit-outside-a-worktree:60` says "not the `json` the other six", which is still correct after
task 17: seven at the gate, this one plus six.

**Verification.** `tests/test-eval-harness.sh` 45 passed, up from 39 after task 17 and 35 before it.
`tests/run-tests.sh` green, exit 0, shellcheck clean. Both recipes were printed and read rather than
only asserted, and the unknown-harness path was run and refused. **Mutation sweep: 6 mutants, 6
killed**: the flag ignored, the codex recipe dropping `--skip-git-repo-check`, the codex recipe
replacing the claude one, an unknown harness defaulting silently, `run.sh` naming a harness, and the
bypass flag leaking into `docs/harness-support.md`.

---

## Story coverage

| Story | Kind | Task | Note |
|---|---|---|---|
| S-01 | build | 1 | |
| S-02 | build | 2 | |
| S-03 | build | 7 | |
| S-04 | build | 8 | |
| S-05 | build | 9 | |
| S-06 | build | 10 | |
| S-07 | build | 11 | |
| S-08 | build | 3 | |
| S-09 | build | 12 | |
| S-10 | build | ~~13~~ | Delivered by the done-guard defect fix of 2026-09-05, not by a plan task. Task 13 is struck |
| S-11 | build | 14 | |
| S-12 | build | 4, and the canary case in 14 | |
| S-13 | build | 5 | |
| S-14 | fix | 6 | |
| S-15 | build | 15 | |
| S-16 | fix | 16 | |
| S-17 | build | 17 | |
| S-18 | verify | 18 | Confirmed `verify`, not `build`: there is no dispatcher to write |
| S-19 | decide | **none** | Correctly absent. A `decide` story is not a plan; it routes to `design-architecture` for an ADR once a measurement exists. Its hazard is guarded early, in task 5 |

**18 of 18 buildable stories have a task.** S-19 has none by design.

## Review

Reviewed 2026-09-05 by a dispatched reviewer briefed on
`skills/write-plan/references/plan-review.md`, model `inherit`, after the four mechanical checks
passed. It found six defects that would have produced green tests testing nothing. **Every claim it
made was verified first-hand against the source before being acted on, and all ten checked were
correct.** Fixed in place:

| Finding | Verified as | Fixed in |
|---|---|---|
| `ok`/`bad` do not exist in `test-sensitive-guard.sh` or `test-done-guard.sh`; both count `pass`/`fail` directly | `grep -c '^ok()'` returns 0 in both | tasks 12, 13 |
| Both hooks read their event from **stdin**, not an environment variable | `hooks/sensitive-guard:61`, `hooks/done-guard:69` | tasks 12, 13 |
| The self-check placed before the `hard_block_paths` gate would exit 2 on **every Bash call in every repository** on Codex | `hooks/sensitive-guard:16-17,55-61` | task 12 |
| `case` globs are not path-aware, so `docs/*.md` swept `docs/prd/` and `docs/stories/` | reproduced; 60 extra lines | task 5 |
| Seven skills pin `model sonnet`, not five | `grep -rln` lists `shape-idea` and `write-docs` too | task 15 |
| `json_get` on a list returns Python `str()`, `['claude', 'codex']` | `bin/keel:105-121` | task 8 |
| `grep -n ... \| grep -v '^ *#'` filters nothing, because `grep -n` prefixes `NNN:` | measured: 50 hits before and after | task 7 |
| `CLAUDECODE=1` is exported in this repository's own development environment | confirmed set | task 11 |
| `tests/evals/README.md` states the count as the word "six" | quoted | task 17 |
| `CLAUDE.md` and `AGENTS.md` are byte-identical and dual-written | `diff -q` silent | task 2 |
| The `a && ok || bad` idiom is SC2015, and CI lints at default severity | reproduced, 2 findings | tasks 1, 4 |
| `emit_event` could not emit `PreToolUse`'s two matcher groups | read `hooks/hooks.json` | task 3 |
| Task 8's regeneration of `docs/profile-keys.md` would wipe task 6's tags | generator output | tasks 6, 8 |
| Task 4 step 2 mutated a tracked file while `MAX_JOBS=4` jobs read it | `tests/run-tests.sh:65` | task 4 |
| A one-line tag lookback fails any claim that wraps | the support page's own paragraph | task 5 |
| Task 7's committed baseline contradicts the suite's stated policy | `tests/test-keel.sh:1-3` | task 7 |
| `cmd_doctor` would call functions that exist for one harness only | `bin/keel:1316` | task 7, sixth contract function |

### Not fixed, with reasons

- **"18 tasks is a story list relabelled; use 22-24."** Partly right and now moot. The reviewer sized
  task 6 against a 122-line sweep produced by the `case`-glob bug; with `in_scope` path-correct the
  surface is about 23 lines across 8 to 10 files, which is one task. Tasks 4 and 5 stay separate
  because a reviewer could accept the staleness and provenance checks while rejecting the claim
  registry, which is the split test the template sets.
- **"`lib/harness/capabilities` is data under `lib/`, and this repo puts data in `templates/`."**
  True of `profile.schema.json`, and declined. `resolve.sh` finds the manifest relative to its own
  directory, and `hooks/sensitive-guard` reaches both through one plugin-root path. Splitting the
  data from the only code that reads it across two top-level directories lengthens the gate path and
  buys consistency with a directory whose contents are templates rendered into projects, which this
  is not.
- **"Task 15 step 1 is labelled write the failing test but edits the validator."** The label is
  right for this repository: `tests/validate-skills.sh` **is** the test, and tightening its rule is
  how the failing test gets written. Left as is.

### One consequence worth stating

`git ls-files` drives task 5's scan, so **untracked files are invisible to it**. At the time of
writing, `docs/architecture/`, the three ADRs and this plan are untracked, and they carry 48 matches
between them. Whether `tests/test-harness-claims.sh` is green therefore depends on what the
coordinator has committed. This is correct behaviour, since a check over a working tree should see
what the repository contains, but an executing agent needs to know it before reading a surprising
result.

## Open questions

1. **The Codex fan-out model id is a placeholder.** Task 9 writes
   `model = "gpt-5-codex-mini"` into `.codex/agents/keel-fanout.toml`, and nothing has measured that
   any Codex model clears the fan-out quality bar. `docs/ideas/model-routing.md:130-141` is the
   standing evidence that a cheaper model can pass every structural check and be wrong twice as
   often, so this is exactly the choice that cannot be made by reading a price list. Task 9 requires
   the implementer to record the choice and the date and to say plainly that it is unmeasured.
   S-19 is the story that measures it.
2. **ADR-0001's ceiling on Codex is unvalidated and its hazard is live now.** Guarded by task 5,
   which adds `validated_word_ceiling` as a claude-only capability so any document claiming the
   ceiling holds on Codex fails the build. The measurement itself is S-19 and is deferred.

3. **Codex runs no hook until its source is trusted, and says nothing when it skips one.** Raised
   2026-09-06 from a live probe while task 14 was being built, and it is section 12's open question
   6. It does not block the tasks before it, and it **does** block 9, 10 and 11, whose notes now
   carry the concrete step each owes it. Recorded here as well because a question that lives only in
   the architecture is one the executor of task 9 never reads.

None of the three blocks `execute-plan`. All three are recorded in the design's section 12.

## Next

`execute-plan`. Not started here.
