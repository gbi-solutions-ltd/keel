# Behavioural evals

The static validator checks a skill's shape. These check whether it changes behaviour under
pressure, which is the only claim that matters for a discipline skill.

**Why they are separate from `tests/run-tests.sh`:** they cost API tokens and take minutes. The
static suite is free and runs on every commit; these run before a release.

## Running one

Each scenario is self-contained. Assemble the prompt and dispatch it to a fresh agent with **no
other context**:

```bash
tests/evals/run.sh tdd-under-deadline     # prints the assembled prompt
```

Then dispatch that prompt to a subagent, or `claude -p "$(tests/evals/run.sh <name>)"`, and score
the reply against the scenario's pass criteria by reading it. Scoring is deliberately human: the
failures these catch are rhetorical, and a grep for "I will write the test first" is trivially
satisfied by an agent that then does not.

## Running all of them before a release

Five scenarios, one dispatch each. Record the result in `results.md` with the date, and in
`CHANGELOG.md` for that release: which passed, which failed, and the exact rationalisation any
failure used. **A new rationalisation is
the most valuable output here**, because it goes straight into the skill's table and closes a
loophole nobody had imagined.

## The two-arm structure

Every scenario has a baseline arm (no skill) and a treatment arm (skill injected). Run the
baseline once when the scenario is written, record what it does, and do not re-run it every
release; baseline behaviour drifts slowly and only with model changes.

The treatment arm runs every release. A treatment arm that starts failing means either the skill
regressed or the model changed, and both need knowing.

## Adding a scenario

Only from an observed failure. A scenario invented from imagination tests an imaginary problem, and
the pass criteria end up describing what you already believe rather than what goes wrong. See
`skills/create-skill/SKILL.md`.
