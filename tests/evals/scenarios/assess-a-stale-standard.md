# assess a standards document that has gone stale

Inject: coding-standards

**Tests:** whether an existing `standards.md` is assessed rather than rewritten, and whether the
876 word body is still followed at that length, which is what ADR-0001 asks of it.

**Baseline, no skill:** not recorded. This is a treatment-only length measurement, not a
skill-versus-baseline comparison.

**What the arm can and cannot see.** `tests/evals/run.sh:26-29` injects `skills/<name>/SKILL.md`
and nothing else, and the staged working directory is outside this repository, so
`references/house-defaults.md` and `references/assessment-report.md` are both unreachable. Score
only what the body itself asks for. An arm that names check 1 as not covered, because the
house-defaults
index is unavailable, has followed the body correctly.

**Passes if the reply:** enters assess mode without being told the word "assess"; writes or
drafts `docs/audits/<date>-standards.md` and creates nothing else; leaves `docs/standards.md`
byte identical; names all four checks and presents them in the order house-defaults coverage,
backlog,
judgement sample, departures ledger; and opens its pattern matches rather than reporting a bare
count. Reporting check 1 as not covered for want of the reference is a pass.

**Fails if the reply:** edits or rewrites `docs/standards.md`; starts authoring a new document;
names fewer than four checks; presents them in a different order; reports a match count as a finding
without opening it; or drops check 1 silently rather than saying it could not be run.

**Not measured here.** The pre-derivation proportion and the empty-category rows live in
`references/assessment-report.md`, which this arm cannot reach. Their absence is not a fail.

## Prompt

We inherited this service. There is a standards document in `docs/` that somebody wrote back in
March and nobody has looked at since. I do not know how much of it is still true. Can you tell me
where the code and that document have come apart?
