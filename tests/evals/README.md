# Behavioural evals

The static validator checks a skill's shape. These check whether it changes behaviour under
pressure, which is the only claim that matters for a discipline skill.

**Why they are separate from `tests/run-tests.sh`:** they cost API tokens and take minutes. The
static suite is free and runs on every commit; these run before a release.

## Running one

Each scenario is self-contained. Stage it, which prints a directory **outside this repository**,
and dispatch from there:

```bash
dir=$(tests/evals/stage.sh tdd-under-deadline)
cd "$dir/project" && claude -p "$(cat ../prompt.md)" \
    --setting-sources "" --disable-slash-commands \
    --permission-mode bypassPermissions --output-format json > "$dir/result.json"
```

**Every flag there is load bearing**, worked out on 2026-08-19:

- `--setting-sources ""` and `--disable-slash-commands` stop the arm loading the installed keel
  plugin, its skills, hooks and `CLAUDE.md`. Without them a baseline arm is not a baseline: it runs
  with the very skills the scenario is measuring. The treatment arm gets its skills from the prompt
  text, so both arms take the same two flags.
- `--permission-mode bypassPermissions` because a scenario like `done-without-verifying` turns on
  whether the arm **runs a command**, and an arm that cannot run one has been prevented from
  passing. It is safe here only because the working directory is a staged copy outside the tree.
- `--output-format json` records the model and the cost alongside the reply, both of which belong
  in `results.md`.
- `--bare` looks right and is not: it requires `ANTHROPIC_API_KEY` and refuses OAuth.

For a **baseline arm**, replace the staged prompt with the pressure prompt alone, since `run.sh`
always injects the skills:

```bash
sed -n '/^## Prompt$/,$p' tests/evals/scenarios/<name>.md | tail -n +2 > "$dir/prompt.md"
```

Then score the reply against the scenario's pass criteria by reading it. Scoring is deliberately
human: the failures these catch are rhetorical, and a grep for "I will write the test first" is
trivially satisfied by an agent that then does not.

`tests/evals/run.sh <name>` still prints the assembled prompt on its own, which is useful for
reading it. It is not a dispatch route.

**Stage once per arm.** Two arms sharing a directory race on the same files, and the result looks
fine either way. That nearly happened on 2026-08-16 and is recorded in `results.md`.

### Why dispatch happens outside the tree

An arm whose working directory is this repository can read `tests/evals/scenarios/`, which is the
file describing how it will be scored. The 0.10.0 run caught one arm doing it. The 0.11.0 run
suppressed it by telling every arm not to run commands, and recorded that as not a fix: the
exposure was unchanged, and an instruction that suppresses the searching is itself a difference in
treatment between two runs.

`stage.sh` closes it by construction. It copies the assembled prompt to `<dir>/prompt.md`, gives
the arm `<dir>/project` as its working directory, and refuses to run at all if `TMPDIR` points
inside the tree. `tests/test-eval-harness.sh` asserts the isolation rather than trusting it,
including that the pass criteria are nowhere under the staged directory.

**A subagent spawned from a session working in this repository is not isolated**, whatever it is
told. It inherits that working directory. Use the `claude -p` route above.

### Fixtures

A scenario that needs a project to work in has one under `tests/evals/fixtures/<scenario>/`, copied
into `project/` at staging time. A scenario without one gets an empty directory. See
`fixtures/README.md`, which records what each fixture seeds and is deliberately never staged.

## Running all of them before a release

Six scenarios, one dispatch each. Record the result in `results.md` with the date, and in
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
