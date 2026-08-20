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

**To check which model a dispatch actually ran on, swap in `--output-format stream-json --verbose`.**
It emits every assistant message, `tool_use` blocks and their inputs included, so an `Agent` call's
`model` parameter is read rather than inferred. This is the standing method for any question about
whether an agent dispatched, and on what: `modelUsage` alone cannot answer it, because an agent that
dispatched and ignored its model looks identical to one that never dispatched. Pair it with a control
run whose model is set explicitly, so absence means something. Worked out 2026-08-20, which is also
where the 2026-08-19 note that the tool calls "cannot be read back" was closed; see `results.md`.

For a **baseline arm**, replace the staged prompt with the pressure prompt alone, since `run.sh`
injects the skills:

```bash
sed -n '/^## Prompt$/,$p' tests/evals/scenarios/<name>.md | tail -n +2 > "$dir/prompt.md"
```

A scenario whose arm is a subagent injects no skill at all, because an implementer or a reviewer
receives a prompt and nothing else. Its assembled prompt is the pressure prompt, with none of the
skill framing, and its baseline is made by editing the staged `prompt.md`; the scenario says which
lines. `commit-outside-a-worktree` is the only one so far, and it is also the one scenario dispatched
with `--output-format stream-json --verbose` rather than `json`, because one of its criteria is
whether a command ran and a reply cannot settle that.

Then score the reply against the scenario's pass criteria by reading it. Scoring is deliberately
human: the failures these catch are rhetorical, and a grep for "I will write the test first" is
trivially satisfied by an agent that then does not.

`tests/evals/run.sh <name>` still prints the assembled prompt on its own, which is useful for
reading it. It is not a dispatch route.

**Stage once per arm.** Two arms sharing a directory race on the same files, and the result looks
fine either way. That nearly happened on 2026-08-16 and is recorded in `results.md`.

**Arms can be dispatched concurrently, and a full gate should be.** Staging once per arm is what makes
that safe: each arm's working directory is its own, outside the tree, so nothing is shared to race on.
The seven-arm gate on 2026-08-20 ran in about two and a half minutes of wall clock rather than nine,
at the same cost, because the dispatches overlapped. Wait on all of them and score afterwards; a
dispatch takes one to three minutes, so a foreground timeout under about five is a timeout on work
that is still running, and re-dispatching on it pays for every arm twice.

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

**A fixture that needs more than files carries a `setup.sh`**, run after the copy with the staged
`project/` as its working directory. A setup that exits non-zero fails the stage and prints no path,
because a half-built fixture dispatches an arm that produces something which looks like a result. It
exists for one thing a fixture cannot ship: a `.git` directory, which cannot be committed inside this
repository, and which `commit-outside-a-worktree` is scored on.

## Running all of them before a release

Seven scenarios, one dispatch each. Record the result in `results.md` with the date, and in
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
