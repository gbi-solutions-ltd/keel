# ADR-0005: Keep one body per skill, and move the fan-out pin from a model alias to a delegation profile

| | |
|---|---|
| Status | accepted |
| Date | 2026-09-05 |
| Deciders | Bernard Tebandeke, accepted 2026-09-05 |
| Requirements | none written; driver is `docs/ideas/keel-on-codex.md` as amended 2026-09-05 |
| Supersedes | none |
| Revised | 2026-09-05, after design review. The first draft asserted that keel's validator rejects harness-neutral wording. It does not. See Context |

## Context

Seven skills instruct subagent fan-out in Claude Code's vocabulary. Codex has subagents, so the
mechanism ports; six lines name the `Explore` agent type or pin a model alias, and
`execute-plan/references/parallel-batches.md:40` instructs `isolation: worktree`, the literal
parameter of Claude Code's Agent tool.

**A claim in the first draft of this ADR was wrong and is withdrawn.** It said the validator rejects
the wording that makes the skills portable. It does not. `names_model()`
(`tests/validate-skills.sh:344`) is satisfied by any of `sonnet|opus|haiku|fable|inherit`
(`:319-323`), and **`inherit` is harness-neutral**: it names a relationship to the driver, not a
vendor's model. `execute-plan` already relies on `inherit` exclusively.

Established by running the real validator against three variants of a clean full-repository copy on
2026-09-05, each differing only in the dispatch sentences of the five skills concerned. The baseline
copy reported zero failures, so the variants are trustworthy in a way the first draft's evidence was
not:

| Variant | Dispatch wording | Failures |
|---|---|---|
| 1 | Harness-neutral, model sentence removed | **5 FAILs**, one per skill |
| 2 | Harness-neutral, `` model `inherit` `` kept | **clean** |
| 3 | Harness-neutral (`Explore` removed), `` model `sonnet` `` kept | **clean** |

Variant 1 is what the first draft measured, and it measured its own rewrite deleting the pin, not
the checker objecting to neutral prose. The rule at `:335-358` rejects an **unpinned** dispatch,
which is correct and was added deliberately: its own comment records that `security-audit` had been
fanning out unpinned since it was written.

**So the checker is not a constraint, and the real one is narrower and semantic.** Four of the five
accepted aliases are Anthropic model names; `inherit` is the only relative one, and it means "the
model already driving this session". The five fan-out skills pin `sonnet` as a measured decision, not
a default: `docs/ideas/model-routing.md:130-141` records 43% off the delegated reading, and records
haiku being rejected for it on quality, at 35% citations that do not support their claim against
sonnet's 15%. In that measurement the dispatcher was `claude-opus-5[1m]`.

**`inherit` is therefore portable and lossy.** It passes every check today and sends wide mechanical
reading to whatever expensive model is driving, discarding the decision `model-routing.md` paid to
establish. The dominant force is that a Codex reader must not be handed a false instruction; the
constraint that survives review is that **there is no way to say "a cheaper, faster model than the
driver" in a vocabulary of four vendor names plus `inherit`.**

`execute-plan` needs no change at all: `model-routing.md:114-116` records that everything in it
stays `inherit` deliberately, because it writes code under the TDD gate or judges another agent's
verdict.

## Decision

One body per skill. Harness-specific vocabulary (`Explore`, `isolation: worktree`) is rewritten
neutrally. The fan-out pin moves from a model alias in prose to a **delegation profile name**
resolved per harness from keel-shipped configuration (`.codex/agents/*.toml` on Codex, the existing
mechanism on Claude Code), and `tests/validate-skills.sh` changes from "names an alias from a
five-item list" to "names a delegation profile that resolves for every harness in the set".

The validator change is made to preserve the routing decision on both harnesses. It is **not** made
because the checker rejects neutral wording, and this ADR no longer claims that it does.

## Alternatives considered

### A: Keep a Claude alias in the body

Leave `` model `sonnet` `` in place, remove only `Explore`. Passes the validator today, variant 3
above. Costs nothing.

It loses because it writes a vendor's model name into a body a Codex reader is expected to follow,
where it names nothing. The routing decision is preserved for one harness by stating it falsely to
the other.

### B: Neutral wording pinned to `inherit`

Variant 2 above. **The cheapest option that is not wrong**: it is portable, it passes the validator
unchanged, it needs no new configuration and no validator work, and it could ship this week.

It loses on cost and on measured quality, not on correctness. It routes six mechanical reading
briefs per `repo-snapshot` run to the driver's model, discarding the 43% saving
`model-routing.md:130-141` measured, and it does so silently, because nothing in the body would any
longer say that the reading is meant to be cheap. It is the option to take if the delegation-profile
work proves expensive, and it should be recorded as the fallback rather than forgotten.

### C: Two bodies per skill

Preserves both harnesses' vocabulary exactly and needs no validator change.

It loses on coverage more than on effort. The validator's checks glob `skills/*/SKILL.md` literally,
so a second body escapes the word ceiling, the description budget and the model-pin rule entirely;
only the generic dash and link sweep would see it. It doubles the maintained surface of seven skills
and removes checking from the copy most likely to drift.

**Why the chosen option won.** Against B, it keeps a decision the repository measured and paid for.
Against C, it keeps one body under full checking. Against A, it does not lie. Its cost is a validator
rule that resolves a profile rather than matching a string, and configuration keel must ship
correctly, and if that cost proves higher than expected, **B is the documented retreat** and this ADR
should be superseded rather than stretched.

## Consequences

**What becomes easier.** One body per skill forever. The pin lives where a harness can read it. A
third harness needs configuration, not seven more bodies.

**What becomes harder.** The validator rule becomes more complex than a string match. keel ships
agent configuration into repositories, a new class of file to keep correct. A reader of a skill body
can no longer see which model the fan-out uses without opening the profile, which is a real loss of
locality and is the strongest argument for B.

**What this forecloses.** Per-harness skill text as a general technique.

**What must be true for this to keep working.** That both harnesses can express "cheaper and faster
than the driver" in their own agent configuration. Codex custom agents pin `model` and
`model_reasoning_effort`, so this holds today. If a harness offers no such control, the profile
cannot resolve there and B becomes the answer for that harness.

**What is not yet known.** Whether sonnet-class routing is even the right choice on Codex. The 43%
and the 15%-versus-35% figures were measured on Claude Code with a Claude dispatcher, and
`model-routing.md`'s own lesson is that this does not transfer for free. The profile for Codex is a
guess until an arm is run.

## Verification

Holding if: no skill body names a vendor model alias or a harness-specific agent type; the profile
resolves on both harnesses; and eval arms show fan-out still happening concurrently in one message on
both.

Not holding if a rewrite quietly loses the instruction, or if the Codex profile turns out to route
wide reading to a model whose citation accuracy is the haiku result rather than the sonnet one. That
is the specific failure `model-routing.md` already documented once, and it is what the arms are for.

**Checked 2026-09-06, two clauses of three.** No skill body names a vendor model alias or a
harness-specific agent type: `tests/validate-skills.sh` fails on the first and
`grep -rn '`Explore`' skills/` returns nothing. The profile resolves on both harnesses:
`agents/keel-fanout.md` ships in the plugin for Claude Code, `lib/harness/codex.sh` writes
`.codex/agents/keel-fanout.toml` for Codex, and item 8 of `tests/test-harness-claims.sh` fails the
build if a body names a profile either side lacks, or if the Claude Code definition is untracked and
so ships to nobody.

**The third clause cannot hold, and the reason is worse than "not measured yet."** It asks for eval
arms showing fan-out still happening concurrently in one message on both harnesses. **No scenario in
`tests/evals/scenarios/` injects any of the seven skills that fan out.** Checked 2026-09-06 against
the `Inject:` line of all twelve: the injected skills are `coding-standards` four times, then
`debug`, `write-prd`, `design-database`, `incident-response`, `execute-plan tdd`, `tdd` and `ship`.
Not `repo-snapshot`, `port-assess`, `apex-port-plan`, `write-plan`, `security-audit`, `shape-idea`
or `write-docs`. So running the gate today would produce no evidence about this clause at all, and
"the evals have not been re-run" understates it: **there is no arm to re-run.**

The partial exception is `done-without-verifying`, which injects `execute-plan`, whose references are
staged and do instruct a dispatch. That arm could show concurrency, and it pins `model \`inherit\``
rather than the profile, so it says nothing about whether a delegation profile resolves or routes.

**What would close it is a scenario, not a gate run.** One that injects a fan-out skill against a
tree large enough to make delegating the reading the right call, scored on whether the arm dispatched
in one message and named the profile. Until that exists, the clause is unfalsifiable, and an
unfalsifiable verification clause is the same defect as a check that cannot fail. Recorded here
rather than quietly carried, because the cost of the alternative is believing a decision was
verified when nothing could have verified it.

**And the Codex model behind the profile is still chosen from a price list.** `gpt-5-codex-mini` was
picked on 2026-09-06 as the cheapest published option and nothing has measured that it clears the
fan-out quality bar. `docs/ideas/model-routing.md` is the standing evidence that exactly this choice
can pass every structural check and be wrong twice as often.
