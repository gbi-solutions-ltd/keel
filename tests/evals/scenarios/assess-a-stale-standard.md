# assess a standards document that has gone stale

Inject: coding-standards

**Tests:** whether an existing `standards.md` is assessed rather than rewritten, and whether the
795 word body is still followed at that length, which is what ADR-0001 asks of it.

**Baseline, no skill:** not recorded. This is a treatment-only length measurement, not a
skill-versus-baseline comparison.

**What the arm can see. Changed 2026-09-02, and the change inverts three clauses below.** Until
then `run.sh` injected `skills/<name>/SKILL.md` and nothing else and the staged tree held no
`skills/` directory, so `references/house-defaults.md` and `references/assessment-report.md` were
both unreachable and an arm reporting check 1 as not covered had followed the body correctly.
`stage.sh` now stages an injected skill's references at `../skills/coding-standards/references/`
and the prompt names that path, so both files are readable. **Checks 1 and 1b are therefore both
scored, and skipping either is a fail rather than a pass.** Whether the arm chose to open a
reference is observable in the tool calls under `--output-format stream-json`, and the reply's
prose is not evidence that a file was read.

**Passes if the reply:** enters assess mode without being told the word "assess"; writes or
drafts `docs/audits/<date>-standards.md` and creates nothing else; leaves `docs/standards.md`
byte identical; names all five checks and presents them in the order check 1 house-defaults
coverage, check 1b house-defaults coverage as its own number, check 2 the follow-up backlog, check 3
the judgement sample, check 4 the departures ledger; and opens its pattern matches rather than
reporting a bare count. Checks 1 and 1b are both reachable and both must be run.

**Fails if the reply:** edits or rewrites `docs/standards.md`; starts authoring a new document;
names fewer than five checks; gives those five in a sequence other than the one written out above,
decided by where each check is first named in the reply and nowhere else; reports a match count as a
finding without opening it; or drops check 1 or check 1b, silently or with a reason. Both are
reachable since 2026-09-02 and skipping either is a fail however it is explained.

**Five checks since 2026-09-03, four before it.** S-10 gave assess a check 1b, so an arm that
follows `references/assess.md` reports five, and against the four-check rubric that arm scored a
fail. The order clause is now written out as a fixed sequence with a stated place to read it from,
rather than as "presents them in a different order", because the old wording named no sequence: its
verdict was settled by the scorer's reading of the arm rather than by anything written down before
the run.

**Measured since 2026-09-02.** The pre-derivation proportion and the empty-category rows live in
`references/assessment-report.md`, which the arm can now reach, so their absence is a finding rather
than an exemption. They are the two honesty requirements `tests/evals/results.md` recorded on
2026-09-01 as "not reachable and not scored", and making them reachable is what the staging change
was for.

## Prompt

We inherited this service. There is a standards document in `docs/` that somebody wrote back in
March and nobody has looked at since. I do not know how much of it is still true. Can you tell me
where the code and that document have come apart?
