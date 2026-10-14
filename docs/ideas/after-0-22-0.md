# Idea: three follow-ups from cutting 0.22.0

| | |
|---|---|
| Raised by | The coordinator, 2026-09-30, while cutting and publishing 0.22.0 |
| Status | open |
| Recommendation | 1 first: it is the one that cost release-day time. 2 and 3 are small and independent |
| Next | Bernard to pick which, if any, to plan |

## 1. The export's suite runs only on release day

`tests/export-public.sh` withholds `docs/audits/`, `.claude/` and `.keel/handoff.md`, and its
output has to pass its own `tests/run-tests.sh` before it is published. Nothing runs that check
before then. On 2026-09-30 the 0.22.0 export failed it: four line-number citations into
`docs/audits/` resolved in this repository and pointed at nothing in the export. Neither the
internal suite nor CI (four jobs in `.github/workflows/ci.yml`, none of which exports) could see it.
The fix was a second PR and moving the internal `v0.22.0` tag, both after the release PR had merged.

**Proposed.** A CI job that runs `tests/export-public.sh` into a scratch directory, commits inside
it, and runs its suite, as the runbook's section 4 step 2 does by hand. The leak sweep cannot move
with it: the deny list lives outside the tree, at `~/.config/keel/internal-deny-list.txt`, and
without it the sweep degrades to two generic patterns and still prints `OK`. That step stays manual.

**Cheaper alternative.** A check in `tests/validate-citations.sh` that fails a root-anchored,
line-number citation into a path the export withholds, from a file the export keeps. It catches
this class and no other.

## 2. Seven more `printf | grep -q` checks under `pipefail`

PR #75 fixed check 22 of `tests/test-eval-harness.sh`. It piped a long assembled prompt into
`grep -q` under `pipefail`, and when `grep` exited on the first match before `printf` had written
the rest, the check failed as though the text were missing. It failed once in CI. Seven checks in
the same file keep the shape, at lines 39, 166, 345, 753, 761, 768 and 779. Each reads a short
output (an error message or a printed recipe), which makes the race much less likely, not
impossible.
Line 166 reads `$full`, which may be long.

**Proposed.** The same `case "$var" in *'text'*)` match, or `grep -q ... <<< "$var"`, at all seven.
Mechanical, no behaviour change.

## 3. Three edge cases in L-01's rule

0.22.0's fix for L-01 (`docs/audits/2026-09-30-security.md`) has `security-audit` Step 1 and
`ship` item 4 read `gates.security_audit` and `hard_block_paths` from the default branch when the
diff changes either. Its review left three cases unstated:

- **No default branch yet**, as in a new repository whose first branch is the one being shipped.
- **No `.keel/profile.json` on the default branch**, as when keel is adopted on the branch itself.
- **How to read it.** Nothing says to use `git show <default>:.keel/profile.json` rather than check
  the branch out, and a checkout mid-audit would break Step 2's rule that an audit modifies nothing.

Every probe at the new text passed, and the probes at the old text passed too, so none of these has
been seen to go wrong. **Proposed**, if taken: one clause naming `git show`, and one saying that
with nothing to read on the default branch the branch's own values stand and the report says so.
`security-audit` is at 840 words and `ship` at 751, so either change owes a re-run of its arms.
