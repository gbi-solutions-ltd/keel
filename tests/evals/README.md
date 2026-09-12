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

**An injected skill's reference files are staged too, and this is what makes a reference-dependent
skill measurable at all.** `stage.sh` copies `skills/<skill>/references/` for every skill the
scenario injects, to `<staged dir>/skills/<skill>/references/`, which is
`../skills/<skill>/references/` from the arm's working directory. The assembled prompt names that
path once per skill that has one.

Until 2026-09-02 it copied only the fixture, so the staged tree had no `skills/` directory and a
skill body pointing at a reference pointed at nothing an arm could open. `results.md` recorded that
on 2026-09-01 as the single most useful thing that run surfaced about this setup.

**Staged rather than injected into the prompt, and the difference is the whole point.** Injecting a
reference as text measures whether its content is obeyed when the model already has it, which no
arm can fail. Staging it measures whether the model goes and reads it, which is the risk a reference
actually carries. Read the arm's tool calls with `--output-format stream-json` to see which
happened; the reply's prose is not evidence that a file was opened.

They are staged beside `project/` and not inside it, for the reason `prompt.md` and `setup.sh` are
kept out: they are not files the arm should find lying around in the repository it is working on.

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

**On Codex the flags are different, and two of the differences are not obvious.**
`tests/evals/stage.sh --harness codex <scenario>` prints the recipe; the staged tree is byte for
byte the same either way, because `run.sh` pastes each injected `SKILL.md` into the prompt as plain
text rather than relying on a plugin install. Proven 2026-09-05 and recorded in `results.md`.

| Claude Code | Codex | |
|---|---|---|
| `claude -p "$(cat ../prompt.md)"` | `codex exec "$(cat ../prompt.md)"` | |
| `--setting-sources ""`, `--disable-slash-commands` | `--ignore-user-config`, `--ignore-rules` | **partial**, see below |
| `--permission-mode bypassPermissions` | `--dangerously-bypass-approvals-and-sandbox` | eval only, never in a user document |
| `--output-format json` | `--json` | |
| nothing | `--skip-git-repo-check` | **required**, see below |

- **`--skip-git-repo-check` is required, not optional.** The staged fixture is not a git repository
  and Codex refuses to run outside one. The Claude recipe needs no equivalent, so this is the one
  flag a reader would not think to look for.
- **`--ignore-user-config` is only a partial counterpart to `--setting-sources ""`.** It suppresses
  `$CODEX_HOME/config.toml`. It is **not established** that it suppresses skill discovery from
  `$HOME/.agents/skills` or `AGENTS.md` loading, both of which Codex reads from outside the working
  directory. `-c project_doc_max_bytes=0` is the candidate for the second. Until that is checked, a
  Codex baseline arm is only trustworthy on a machine with neither present, which is a property of
  the machine rather than of the harness and so cannot be asserted by a test here. Check it before
  relying on a Codex baseline, and record the result in this section.
- **`--dangerously-bypass-approvals-and-sandbox` is eval only.** It disables the sandbox, and it is
  safe here for the same reason `bypassPermissions` is: the working directory is a staged copy
  outside the tree. `tests/test-eval-harness.sh` fails the build if it appears in any document a
  user reads as instructions.

**To check which model a dispatch actually ran on, swap in `--output-format stream-json --verbose`.**
It emits every assistant message, `tool_use` blocks and their inputs included, so an `Agent` call's
`model` parameter is read rather than inferred. This is the standing method for any question about
whether an agent dispatched, and on what: `modelUsage` alone cannot answer it, because an agent that
dispatched and ignored its model looks identical to one that never dispatched. Pair it with a control
run whose model is set explicitly, so absence means something. Worked out 2026-08-20, which is also
where the 2026-08-19 note that the tool calls "cannot be read back" was closed; see `results.md`.

### Reading the tool calls, on either harness

**This is the method every scenario rubric points at**, rather than each one naming a flag. A rubric
asks whether the arm *did* something, and the reply's prose is never evidence that it did; the tool
calls are. The mechanism differs by harness and the rubrics do not, which is why it is written once
here.

| | Dispatch with | What you get |
|---|---|---|
| Claude Code | `--output-format stream-json --verbose` | every assistant message, `tool_use` blocks and their inputs included |
| Codex | `--json` | a JSONL event stream; the tool calls are `custom_tool_call` records, with the command in the call's own `input` |

`--output-format json` on Claude Code and no flag at all on Codex give you the reply and the cost
and nothing about what the arm actually did, which is the state that made the 2026-08-19 note say
the tool calls could not be read back at all.

`hooks/done-guard` parses both shapes already, in `codex_turn_tool_calls` and the Claude reader
beside it, so a scorer who wants the extraction rather than the raw stream has a worked example of
each in the tree.

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
The six-arm gate on 2026-08-20 ran in about two and a half minutes of wall clock rather than nine,
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

Thirteen scenarios exist; 7 scenarios are dispatched at the release gate, listed in
`tests/evals/gate-scenarios`, one dispatch each. That file is the set: the runbook's
dispatch script reads it rather than carrying its own copy, and `tests/test-eval-harness.sh`
fails the build if this sentence, the runbook or the file disagree. Record the result
in `results.md` with the date, and in
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

**The set has one known hole, and it is a hole in evidence rather than in coverage.** One scenario
injects a skill that fans out, and it does not dispatch the fan-out. Checked 2026-09-08 across the
`Inject:` line of all thirteen: the injected skills are `coding-standards` four times, then `debug`,
`write-prd`, `design-database`, `incident-response`, `execute-plan tdd`, `tdd`, `ship` and
`security-audit`. None of `repo-snapshot`, `port-assess`, `apex-port-plan`, `write-plan`,
`shape-idea` or `write-docs`.

`audit-under-a-warn-gate` is the one, added 2026-09-08, and it **narrows the hole rather than
closing it**. `security-audit` delegates a phase per subagent on a `--full` run and on no other, and
that scenario's prompt is a pre-ship check, which is `--diff` on the skill's own scope table. So the
set now injects a fan-out skill and still contains no arm in which the fan-out is reached.

ADR-0005 asks, as a condition of holding, for arms showing fan-out still happening concurrently in
one message on both harnesses. **No arm here can produce that**, so the clause is unfalsifiable
rather than unmeasured, which is the same defect as a check that cannot fail. The nearest thing is
`done-without-verifying`, which injects `execute-plan`: its references are staged and do instruct a
dispatch, so it could show concurrency, but it pins `model \`inherit\`` and says nothing about
whether a delegation profile resolves or routes.

Closing it needs a scenario injecting a fan-out skill against a tree large enough that delegating
the reading is the right call, scored on whether the arm dispatched in one message and named the
profile. That is a scenario with a fixture and a rubric, and a decision about whether it joins
`gate-scenarios`; it is not something a gate run produces on its own. **Do not read a green gate as
evidence about fan-out until this exists.**
