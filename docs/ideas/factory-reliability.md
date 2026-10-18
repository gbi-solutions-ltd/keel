# Idea: make keel a reliable and efficient factory, not only a careful one

| | |
|---|---|
| Raised by | Bernard, 2026-10-17, after 0.24.0 shipped, asking for an honest assessment of what else would make keel "a reliable and efficient software factory", and agreeing to proceed as recommended |
| Status | partly built. Items 5a, the script half of 1a and 1c are built by `docs/plans/2026-10-17-factory-basics.md`; Bernard decided questions 1 to 3 on 2026-10-17 (see Decided): ADR-0001 is pruned to the target, hooks are a probe then a reviewer guard, and item 3 is "not yet; harden bash", which task 1 of that plan began; item 2 is built by `docs/plans/2026-10-17-reviewer-git-guard.md` (`6392076`, `cfea067`) and recorded as ADR-0010; item 4 is built by `docs/plans/2026-10-17-prune-to-the-target.md` and recorded as ADR-0011; items 1b, 5b, 6 and 7, and the pass-rate half of 1a, are not planned |
| Recommendation | Take the four items that conflict with nothing recorded first, as small plans. Put the three decisions to Bernard with their evidence, and plan each only once decided |
| Next | Nothing planned. Built: follow-up 1, the recorded quarantine for `setup-deployment` (`1f54be8`, `7451daf`, `04cd972`), and the changes for the other four (`40f0a0b`, `9670d48`, `1621463`, `8743c73`, `7053952`), recorded under the two `tests/evals/results.md` entries "2026-10-18, setup-deployment's recorded quarantine" and "2026-10-18, the prune's other four follow-ups". Left unplanned: items 1b, the pass-rate half of 1a, 5b, 6 and 7; and a generated `review-code` worktree name, since two concurrent arms chose the same four letters |

## The problem

keel's gates make each change careful, and the 0.24.0 cycle showed where that care is thin, where
it is held only by prose, and where it costs more than it measures. A factory needs the opposite
profile from a workshop: fewer checks that hold harder, evidence that is a rate rather than a
sample, and tooling that does not regress on the platform it runs on.

**Evidence, all from 2026-10-16 and 2026-10-17.**

- **One run per gate arm.** The 0.24.0 gate recorded seven passes, each a single dispatch on one
  model, and its "shifts" (one case where the previous arm wrote two, a fallback returning) are
  indistinguishable from noise. `tests/evals/results.md` says so of itself in earlier entries ("one
  run per arm cannot separate from noise").
- **A scorer over-credited a baseline.** The `run-a-short-path-plan` baseline was first recorded as
  passing; an independent check of the transcripts showed it failed criteria 1 and 4.
- **Graders drift from the skills they grade.** The three `review-code-leaves-the-tree-alone` runs
  on Linux left the author's tree untouched and scored 0 of 3, because their graders forbid the
  throwaway worktree that `review-code`'s mutation step now creates
  (`tests/plugin-evals/README.md#Run on Linux without it`).
- **The plan tooling regressed on macOS after the release commit.** `keel plan batches` stopped
  with a `towc` error on a dash in a `Depends on` line under a UTF-8 locale, caught by the macOS CI
  job only once a pull request existed, after `release: 0.24.0` was committed (`5b50a83`). The
  same parser took three adversarial spec passes and a strict grammar to stop leaking
  (`docs/plans/2026-10-16-plans-declare-batches.md`).
- **The release was assembled by hand.** Four scripts were written in a scratch directory, the
  `gh` account had to be found, the pull request was merged outside the script, and the runbook's
  own open item, `tests/evals/gate.sh`, still does not exist.
- **The rules that matter most are prose.** ADR-0002's "the coordinator writes no production code"
  has no harness check. The `run-a-short-path-plan` baseline dispatched and reviewed with no skill
  in its prompt, because a line in the plan told it to: the line did the work.
- **The ceiling's own trigger has fired.** ADR-0001's Verification section says the ADR "needs
  superseding rather than amending" when the bodies within 20 words of 900 grow "past two or
  three". Four are: `tdd` 898, `execute-plan` 894, `write-plan` 893, `ship` 885.
- **Output is not measured.** `keel plan report` exists and no lead time from it appears anywhere
  in `docs/`, `results.md` or `CHANGELOG.md`. The short path's plan says "No measurement of the
  short path separately". The only pilots on record are two one-day audits from 2026-08-15.

## What was asked for

> from your honest assessment of the Keel current offering, what else could be improved to make it
> a reliable and efficient software factory?

> i am agreeable. proceed as you would recommend

## The case against

**Strongest argument for doing none of this now.** 0.24.0 has just shipped with every gate green,
and the items below are mostly about evidence and machinery rather than a user-visible defect. The
repository has a standing rule that machinery waits for a named instance
(`docs/ideas/independence-of-a-delegated-review.md`, open question 1), and only some of these items
have one. Pausing to run keel on real work for two weeks would produce the measurements item 6 asks
for and might reorder everything else.

That argument holds for items 2 and 3, which is why they are open questions below and not plans.
It does not hold for items 5a and 1c, which are defects with instances on record, or for item 4,
whose trigger is written into an accepted ADR.

## The seven items, and where each stands

| # | Item | Instance on record | Conflicts with | Proposed |
|---|---|---|---|---|
| 1a | Three runs per gate arm, pass rates tracked across releases | One run per arm, noted in `results.md`; shifts unreadable | Nothing | Script half built: `gate.sh --runs N` (`f295a2a`). Tracking pass rates across releases is not planned |
| 1b | Script the mechanical criteria (git state, files, tool order) | The scorer that over-credited a baseline | `tests/evals/README.md`: "Scoring is deliberately human" | Not planned. The proposal stands: script only what the scenario already scores on an artifact; reading stays for the reply |
| 1c | Graders read the author's tree, not the commands | `review-code-leaves-the-tree-alone`, 0 of 3 on clean runs | Nothing | Built (`b1c32eb`); three runs after the change scored 3 of 3 |
| 2 | Hooks that hold the coordinator, reviewer and commit rules | The 2026-10-12 `git stash` (answered by prompt text); no coordinator-edit instance | `docs/07-open-decisions.md` section 3 reserves hook blocking for the payments case; ADR-0003 and ADR-0004 make it a Claude Code only guarantee | Decided 2026-10-17: probe that `agent_id` separates the main session, then block tree-changing git in keel reviewers only (option b). Built 2026-10-17: `hooks/review-guard` and the `keel-reviewer` agent type (`6392076`), every judging dispatch run as it (`cfea067`), ADR-0010 |
| 3 | Plan tooling in Python, with a structured plan block | The batches parser saga, the macOS awk regression | `docs/standards.md`: `python3` optional; `docs/architecture/tiered-multi-harness-support.md`: "no new language"; `docs/ideas/addressable-plan-steps.md` rejects structured plans | Decided 2026-10-17: not yet, harden bash (option a). Task 1 of the factory-basics plan began it (`37b1a31`); revisit if the plan tooling regresses again |
| 4 | Supersede ADR-0001 and prune the four bodies at the ceiling | The ADR's own trigger | Nothing: the ADR asks for it | Decided 2026-10-17: prune to the target and supersede ADR-0001, in a later plan; each pruned body owes an eval arm. Built 2026-10-18 by `docs/plans/2026-10-17-prune-to-the-target.md`: all eleven bodies over 700 pruned under it, 700 the hard ceiling (`3a4f93d`), every pruned body's arm run, ADR-0011 |
| 5a | CI on pushes to `sandbox`; `tests/evals/gate.sh` committed | `5b50a83` found after the release commit; the runbook's "Still open" | Nothing recorded | Built: CI on `sandbox` (`37b1a31`) and `tests/evals/gate.sh` (`f295a2a`) |
| 5b | A `keel release` command over the runbook | The four scratch scripts of 2026-10-17 | Nothing recorded | Not yet planned; 5a is built, so `gate.sh` is its first piece. From the scripts in `.git/keel-release/`, made generic |
| 6 | Real-repository fixtures and a pilot measured with `keel plan report` | No lead time on record; 1.0.0 held for two team pilots | Nothing | Needs Bernard's teams, so it is his to schedule |
| 7 | Measure the short path's cost | Its plan says it is not measured | Nothing | Folded into 6: the same report, filtered to one-task plans |

## What the system says

| Finding | Evidence | What it means |
|---|---|---|
| A hook can tell a subagent's tool call from the main session's | Claude Code hooks reference: `agent_id` is the "Unique identifier for the subagent ... the hook fires in"; plugin hooks "apply inside subagents" | Item 2 is buildable on Claude Code. That a missing `agent_id` means the main session is an inference and needs a probe |
| A hook cannot see the dispatch's description | The same docs carry `agent_type`, not the `description` | A reviewer guard needs reviews to run as a named keel agent type, as `keel-fanout` does, not as a general agent with a label |
| A Bash guard matches strings | `tool_input.command` is the full command; matchers match tool names only | It catches `git stash` as written and not `sh -c "git stash"`. It is a speed bump against a model, not a boundary against an attacker |
| Hooks hold on one harness | ADR-0004: a guarantee belongs to a repository and harness pair | Codex keeps the prose. The capability manifest gains a row per hook |
| Plans are parsed in one bash file | `bin/keel`, 4,676 lines; the batches grammar was settled by spec passes | A Python module would be testable in isolation; making `python3` required reverses a permanent, recorded departure |
| CI does not build `sandbox` | `.github/workflows/ci.yml` triggers on `push: branches: [main]` and `pull_request` only | The fix is one trigger line, and the macOS job's "week of green runs" condition has long passed |

## Open questions

All three were answered by Bernard on 2026-10-17; the answers are in "Decided" below. The questions
stay as asked, struck through, so the record shows what was put to him.

1. ~~**Supersede ADR-0001, and with what?** Its trigger has fired. The candidates: move each long
   body's rationale into a reference and hold the body to the 700 target; or keep 900 and accept
   that an edit at the ceiling first removes words. Raising the ceiling is excluded by the ADR.~~
   **Answered: prune to the target.** Each long body's reasoning moves into a reference and the
   bodies go back under 700, with an eval arm owed for each pruned body. That supersedes ADR-0001,
   in a later plan.
2. ~~**Should hooks enforce the coordinator, reviewer and commit rules, against open decision 3?**
   Options: (a) no, keep prose and evals; (b) a probe first, proving `agent_id` separates the main
   session, then the reviewer git guard only, which has a named instance; (c) all three guards,
   advisory first (warn, do not block), blocking after a release of clean runs.~~
   **Answered: option (b).** Probe first, then block tree-changing git in keel reviewers only. A
   later plan.
3. ~~**Should plan tooling move to Python, against "python3 optional"?** Options: (a) no, keep bash
   and add the macOS UTF-8 locale to every plan test; (b) `python3` required for `keel plan` only, a
   second scoped departure like `apex-export`, plans staying markdown; (c) (b) plus a structured
   block in each plan, which reverses `addressable-plan-steps`.~~
   **Answered: option (a), "not yet; harden bash".** Every plan test runs under a UTF-8 locale
   too, and the question is revisited if the plan tooling regresses again. Task 1 of
   `docs/plans/2026-10-17-factory-basics.md` began it (`37b1a31`).

## Recommendation

**Build the uncontested items now, in this order: 5a, then 1c, then 1a with 5b.** 5a closes the gap
that let a macOS regression reach the release commit, and puts the gate script where the runbook
says it belongs, so 1a has a home. 1c is a small fix to graders that now fail correct runs.

**Put questions 1 to 3 to Bernard.** The recommendation on each, for the record: question 1, move
rationale into references and hold the body to the target, since the ceiling exists to stop
growth; question 2, option (b), because the reviewer guard has an instance and a probe settles the
inference; question 3, option (a) now, revisited if the plan tooling regresses again, because the
batches parser is fail-closed and the cost of the departure is every user's install.

Items 6 and 7 wait on Bernard's teams and are not planned here.

## Decided

Bernard, 2026-10-17, on the three open questions above:

1. **ADR-0001:** he chose "Prune to the target": "Move each long body's reasoning into a
   reference; bodies go back under 700. Each pruned body owes an eval arm". That supersedes
   ADR-0001, in a later plan.
2. **Hooks:** he chose "Probe, then reviewer guard": "Prove agent_id separates the main session,
   then block tree-changing git in keel reviewers only". A later plan.
3. **Plan tooling:** he chose "Not yet, harden bash": "Run every plan test under macOS's UTF-8
   locale too; revisit if the plan tooling regresses again". Task 1 of
   `docs/plans/2026-10-17-factory-basics.md` began that, with the runner's locales recorded and
   the dash cases run under a UTF-8 locale that exists.

Built by `docs/plans/2026-10-17-factory-basics.md`: item 5a (CI on `sandbox`, `37b1a31`, and
`tests/evals/gate.sh`, `f295a2a`), the script half of item 1a (`gate.sh --runs N`), and item 1c
(`b1c32eb`, proved by three runs scoring 3 of 3 in `tests/plugin-evals/README.md`).

Built by `docs/plans/2026-10-17-reviewer-git-guard.md`: item 2. Two probes on Claude Code 2.1.302
showed a hook's input names a plugin agent's type and omits it for the main session, and that a
deny holds under `bypassPermissions`. `hooks/review-guard` refuses an agent of type
`keel-reviewer` the git commands that would change the author's tree (`6392076`), and every judging
dispatch runs as that agent type where the harness has it (`cfea067`). ADR-0010 records the
decision. On Linux, `review-code-dispatches-rubric-subagent` passed 3 of 3 with every rubric pass
dispatched as `keel:keel-reviewer`, and `review-code-leaves-the-tree-alone` passed 3 of 3 after a
first batch of 2 of 3. The guard holds on Claude Code only, and is a speed bump, not a boundary.

Built by `docs/plans/2026-10-17-prune-to-the-target.md`: item 4, by the commits in
`d9bd7cb..2b47ef2` and ADR-0011. All eleven bodies over 700 were pruned under it, reasons first into
a `references/rationale.md` each: `tdd` (`a282126`), `execute-plan` (`ea82fda`), `write-plan`
(`ba8231d`), `ship` (`49fb06e`), `security-audit` (`77168df`), `write-prd` (`f69750a`),
`repo-snapshot` (`74c0cec`), `incident-response` (`82ee809`), `setup-deployment` (`9e445e1`, its
reasons beside the gating steps restored after its arms in `d6ccba9`), `review-code` (`ff3310f`) and
`coding-standards` (`a4ebddc`). A `setup-deployment` scenario, `add-ci-that-gates` (`ed34318`); the
citations into the pruned bodies repointed (`520d67b`); and the validator's ceiling at 700, warned
within 30 (`3a4f93d`). Every pruned body's arm ran on Claude Code 2.1.302 for $23.76, and ADR-0011
supersedes ADR-0001.

## Not decided here

- Whether a gate arm's pass rate below 3 of 3 blocks a release, or is recorded and owned.
- Which real repository becomes a standing fixture, and how its client identifiers stay out of the
  public export.
- Whether `keel release` covers the public export, or stops at the internal tag.
