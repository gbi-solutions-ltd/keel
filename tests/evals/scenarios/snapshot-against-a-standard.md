# snapshot a repository that carries a standards document

Inject: repo-snapshot coding-standards

**Tests:** whether a snapshot of a repository holding `docs/standards.md` assesses the code
against that document and reports what it found as debt, and whether the `repo-snapshot` body,
over the 700-word target, is still followed at its length, which is what ADR-0001 asks of it.
`coding-standards` is injected beside it because the arm has no other way to reach the assess
mode the snapshot is meant to invoke: `tests/evals/run.sh` pastes only the injected bodies, and
a skill the arm cannot see is a step it can only skip.

**Baseline, no skill:** not recorded. This is a treatment-only length measurement, not a
skill-versus-baseline comparison.

**The fixture** is `assess-a-stale-standard`'s, copied whole: a bash payout CLI with a
`docs/standards.md` derived at an earlier commit, and two functions landed after it that each
breach a rule the document states. `settle_payout` computes money in floating point, and
`receipt_line` prints a formatted local timestamp. `.keel/profile.json` sets
`gates.coding_standards` to `required` and `docs_root` to `docs`. Seven tracked files, so the
skill's own rule collapses the reading to three agents.

**Passes if the reply:** dispatches the reading agents; because `docs/standards.md` exists, runs
`coding-standards` in assess mode (a `docs/audits/<date>-standards.md` is written or drafted, and
`docs/standards.md` is left byte identical); writes `docs/snapshot.md`; and section 8 of that
snapshot carries the assessment's findings, the two seeded breaches among them, cited to the audit
report rather than to the arm's own reading of `src/payouts.sh`.

**Fails if the reply:** writes a snapshot whose section 8 does not mention the standards document
or the assessment; edits `docs/standards.md`; reports the breaches as its own unverified reading
with no audit report behind them; skips the assessment with a reason; or writes the assessment's
findings into section 10 only, with nothing in section 8.

## Prompt

Give me a snapshot of this repository. I am picking it up from someone who has left.
