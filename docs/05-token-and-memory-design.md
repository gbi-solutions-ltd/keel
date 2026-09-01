# Token Budget, Prompt Caching, and Memory

Requirement 14, and the one most likely to be quietly violated by the other thirteen. A
methodology that costs three times as many tokens per task is a methodology people turn off.

## How prompt caching actually constrains the design

Claude caches a **prefix** of the request. The cache hits only while the bytes at the front
are identical to last time. One changed character invalidates everything after it.

The always-loaded prefix in a Claude Code session is roughly:

```
system prompt  ->  tool definitions  ->  skill descriptions  ->  CLAUDE.md  ->  hook injections  ->  conversation
                                         [ we control from here on ]
```

Two rules follow, and they are the whole design:

**Rule 1: nothing volatile in the prefix.** A timestamp, a git branch name, a session id,
a "you have 47 skills available today" counter, or the output of `git status` injected at
session start invalidates the cache on every single session, forever. gstack's preamble
runs bash and injects live values. It is a genuinely expensive choice and we are not
copying it.

**Rule 2: order by stability.** Most stable first. The CLAUDE.md managed block changes only
on upgrade, so it goes at the top. Project-specific notes people edit weekly go below it.

### Concretely, what this forbids

| Tempting | Why not | Do instead |
|----------|---------|------------|
| Inject `git status` or the branch name at session start | Changes constantly, kills the cache | Let a skill run `git status` when it needs it |
| Inject "last session you were working on X" | Changes every session | Write it to `docs/keel/` and let a skill read it on demand |
| Inject the full skill list with descriptions | Already in the prefix via the skill mechanism, duplicating it doubles the cost | Inject a 250-word router pointer only |
| Put the whole coding standards doc in CLAUDE.md | Grows without bound, and 90% of it is irrelevant to any given task | `docs/keel/standards.md`, read by `coding-standards` and `review-code` |
| A skill that reads a config file into the prefix | Any config edit invalidates | Skill reads it at invocation time |

## Budget

| Layer | Target | Hard ceiling | Enforced by |
|-------|--------|--------------|-------------|
| CLAUDE.md managed block | 450 tokens | 700 | `keel doctor` |
| CLAUDE.md project section | 500 tokens | 1,200 | `context-budget` warns |
| SessionStart hook injection | 250 tokens | 400 | `tests/validate-skills.sh`, which also requires it to name every skill |
| Each skill `description` | 44 tokens, see below | 60 | `tests/validate-skills.sh`, at 216 chars |
| **All descriptions together** | 44 x skill count | **1,320** | `tests/validate-skills.sh`, which states the total on every run |
| Skill body | 700 words | 900 | `tests/validate-skills.sh`, which warns over the target |
| Skill reference files | unbounded | n/a | loaded on demand only |

**One band, per ADR-0001, and the history is the reason.** This table used to carry two: 400 words
for a single linear path and 600 for a skill that fans out or carries modes, both under a hard 700.
Measured across all 24 skills on 2026-08-16, **no skill met 400 and only four were under 600**,
while fifteen sat within 20 words of the ceiling and eight within six.

The targets were documented and unchecked; the ceiling was enforced. Bodies went where the check
was. That is the whole mechanism, and it is why the replacement is a target the validator warns on
rather than a third documented number.

The relief this document used to assume, moving substance into `references/`, does not work at the
margin. `coding-standards` carries **12 reference files and 17,816 words** in them and its body is
still 683. A body's floor is set by its step count and by the sentence each reference costs to
introduce, not by how much detail it holds.

What survives from the old reasoning is why a fan-out skill is irreducibly larger: a body that
dispatches subagents carries the per-agent briefs inline, because a brief in a reference file is one
the model may not have loaded when it builds the dispatch. `repo-snapshot`'s six-row table plus its
verbatim brief suffix is 175 words on its own. That is now an explanation of why bodies differ, not
a second budget line.

Total always-loaded keel cost, measured 2026-08-19: **1,891 tokens** at 24 skills, being 1,066 for
the descriptions, 469 for the CLAUDE.md block as this repository renders it, and 356 for the
SessionStart injection.

**Re-measured 2026-08-30 at 25 skills: 1,941 tokens**, being 1,121 for the descriptions, 469
unchanged, and 351 for the injection. The descriptions grew by one skill and the injection shrank,
because adding `design-database` to the router needed 17 characters against the 1 it had spare and
four phrases were trimmed to pay for it. The net is 50 tokens for a skill, which is what the
mechanism below is meant to cost. The injection
was 300 until the brevity rule was made the default later the same day; see below. For comparison,
superpowers injects its entire `using-superpowers` skill body at session start, which is around 900
tokens on its own, and gstack's tier-4 preamble runs into several thousand.

**One line is over target and under ceiling, which is a decision rather than an oversight.** The
injection is at 356 tokens against a 250 target, because it names every skill, the count grew, and it
now also carries the brevity rule that ships on by default. It is checked mechanically, so the next
overrun fails a build instead of waiting for a token audit.

**The managed block met its target on 2026-08-19, by trimming rather than by moving the number.** It
had drifted to 598 tokens rendered, against a 450 target its own header declared, because
`tests/test-keel.sh` asserted only the 700 ceiling and nothing asserted the target. The template now
renders at 421 tokens on the `node-ts` fixture, a 30 percent cut with every rule intact: the section
headings became bold run-in leads and the prose was rewritten, which is where the words were.

**A rendered block is not one number, and the target applies to the rendered one.** The three verify
commands and the docs root are substituted per project, so a repository whose commands are long
renders a larger block than the fixture. This repository is the extreme case at 469 tokens, because
`verify.lint` is a single 160 character `shellcheck` invocation naming every file. That overrun is a
property of one profile value rather than of the template, and it is recorded in `docs/standards.md`.

**The descriptions are the line to watch, and since 2026-08-16 the only one bounded as a sum.** They
scale linearly with the skill count: at roughly 44 tokens each, another ten skills is another 440
tokens in every request forever. The per-skill ceiling never bounded this, and the gap was wider than
the growth it was there to catch. At 24 skills, every description sitting legally at 216 chars totals
1,440 tokens against the 1,066 actually measured, so a third of the budget could arrive with no skill
added and nothing anywhere saying a word.

The estimate is taken once over the summed characters, not per description and then added up.
Estimating each of 24 first truncates 24 times and lands about ten tokens under the real total, which
is a check leaning the wrong way: this is the number that says whether the count is too high, so it
should not quietly under-report.

**The ceiling is 1,320, which is 30 skills at the measured 44-token mean.** The number is not chosen
for headroom, it is decision 6's own trigger: `docs/07-open-decisions.md` says to revisit skill
granularity **before** the count reaches 30. So the check fires at the point that decision already
named, and it fires for the reason this section gives, that when descriptions become the largest line
here the answer is fewer skills rather than shorter descriptions. A description trimmed below the
point where it states when to use the skill costs more in bad routing than it saves.

`tests/validate-skills.sh` states the total on every clean run, breach or not. A budget nobody sees
until it fails is one that gets breached by the change that had no idea it was near.

**The 40-token target was set before any skill existed, and it is not reachable.** A sweep at 0.5.0
removed every intra-description synonym across all 24 (merging "asked whether something is secure" with
"a vulnerability check is requested", dropping "migrate or port" to "port", and so on) and saved 55
tokens per request. The mean landed at 44, not 40, and the only four skills under 40 are the ones with
the narrowest trigger surface: `tdd`, `ship`, `execute-plan`, `write-user-stories`.

That is not padding, it is the job. A description carries the phrasings a user might actually use, and
four distinct triggers do not fit in 144 characters. **Three of the sweep's cuts had to be reverted**
because they removed a distinct trigger rather than a synonym: `security-audit` lost "asked whether
something is secure", which is the most natural way anyone raises it; `design-architecture` lost
"system structure", leaving only the narrower "service boundaries"; `refactor` lost "a file has grown
hard to change" as a standalone situation, which is not the same as "before adding a feature".

So the target is 44, measured rather than guessed, and the 60 ceiling is what the validator enforces.
A description over 60 tokens is carrying a workflow summary, which is a separate defect the "Use when"
rule already forbids.

## Progressive disclosure

The mechanism that makes 25 skills cost what 25 descriptions cost.

```
Always loaded         ->  24 descriptions (~1,066 tokens, ceiling 1,320)
On invocation         ->  one SKILL.md body (~500 tokens)
On explicit need      ->  that skill's references/*.md (500 to 3,000 tokens)
Never automatic       ->  docs/keel/* (read only when a skill asks for it)
```

Enforced by two rules in every skill:

- **No `@file` links.** `@` force-loads at parse time. Use a relative markdown link and a
  sentence saying when to read it.
- **Reference files carry the detail, bodies carry the decisions.** If a section is
  "here are 40 OWASP checks", it is a reference file. If it is "stop and ask when X", it
  is the body.

## Subagent delegation as a context strategy

The largest single saving of **main-thread context** available, and it is why `repo-snapshot`
and `execute-plan` are built the way they are. It is not a saving of money, and the section
title is the accurate one: this is a context strategy.

Reading twenty files to answer one question costs 40,000 tokens in the main context, and
those tokens stay for the rest of the session. The same work in a subagent costs 40,000
tokens in a context that is discarded, and returns a 400-token answer.

**The arithmetic above understates what the subagent spends.** It counts the delegated read as
the same 40,000 tokens, but a subagent starts cold and re-reads what the main thread already
holds. Measured on `repo-snapshot` 2026-08-20: the six-agent fan-out re-read 1,737,695 cache
tokens to return 39,852, and the same 187-file tree read inline cost **$1.48 less in total**
than delegating it. Reading those files inline cost the main thread $0.55 more, which is inside
the run-to-run noise floor; delegating the same reading cost $2.03. See
`tests/evals/results.md`.

The context claim on this page is **untested in either direction** and is not what that run
measured. The money reading of it is measured and false at that size.

Skills that must delegate:

| Skill | What it delegates |
|-------|-------------------|
| `repo-snapshot` | One `Explore` agent per area, in parallel. Returns findings, not file contents |
| `execute-plan` (delegated mode) | One agent per task. Implementation noise never enters the main thread |
| `security-audit --full` | One agent per phase |
| `review-code` | The `code-review` plugin already does this internally |

The cost is real and should be stated: a subagent cannot ask you a question mid-task, and
it does not see the conversation. Delegate discovery and mechanical execution. Do not
delegate judgement.

## Project memory

`docs/keel/` is the memory. It is on disk, committed, human-readable, and loaded on demand.
Nothing is auto-injected.

```
docs/keel/
  snapshot.md            # what this repo is. Regenerated quarterly or on major change
  standards.md           # conventions. Read by coding-standards and review-code
  ideas/                 # shaped ideas, including the ones decided against. Read by write-prd
  prd/                   # requirements
  stories/               # user stories
  architecture/          # system design
  decisions/             # ADRs, append-only, never edited after acceptance
  plans/                 # implementation plans, checkboxes ticked as work proceeds
  port/                  # port assessments for a non-APEX codebase
  runbooks/              # operational docs
  audits/                # security and standards audit history
  context-audit.md       # output of context-budget
```

Why files and not a database or a vector store: it survives `/clear`, it survives a new
engineer, it diffs in PRs, and it needs no infrastructure. The recall mechanism is a skill
knowing which path to read, which is deterministic and free.

**Rule: append-only where history matters.** ADRs and audits are never edited, only
superseded. A decision reversed in March is more useful than a decision doc that was
silently rewritten.

## The context watchdog, which is the part that does not depend on anyone remembering

Everything above is a budget. A budget assumes somebody is watching the number, and in a long
session nobody is: the context fills, compaction runs, and the reasoning that produced the current
state is summarised into a paragraph. The work continues on a worse foundation and the cost lands on
whoever picks it up next.

`hooks/context-watch` measures it instead. Registered on three events:

| Event | What it does |
|---|---|
| `UserPromptSubmit` | Silent below 70%. Between 70 and 85, one short warning naming the number. Past 85, the stop instruction |
| `PreToolUse` | Nothing below 85%. Past it, denies tool calls until a handoff is written |
| `PreCompact` | Writes a mechanical handoff before the session's own memory is rewritten |

**Occupancy is read, not estimated.** Claude Code's transcript records the usage the API reported for
each request, so the last main-thread assistant turn gives the answer directly:

```
input_tokens + cache_creation_input_tokens + cache_read_input_tokens + output_tokens
```

The cache fields are the entire measurement, and missing them is the obvious mistake. On a long
session `input_tokens` is routinely 1, because everything before the last message is a cache read. A
watchdog reading `input_tokens` alone reports a session at 99% of its window as using one token.

**Sidechain entries are excluded.** A subagent's context is discarded when it returns, which is the
whole reason for the delegation table above. Counting its usage would report the main thread as full
because a subagent read twenty files, and the watchdog would punish exactly the behaviour this
document recommends.

**It does not violate rule 1.** The hook is silent below the warn threshold, so an ordinary session
emits nothing. What it does emit is appended after the conversation rather than into the prefix, so
no cached bytes move either way. This is the one place a volatile value is acceptable, and only
because of where it lands.

**The stop is a pause, not a wall.** `Write`, `Edit` and `Read` stay available past the threshold,
because a session told to write a handoff while writing is refused cannot comply. The block lifts as
soon as the handoff is refreshed. A wall would be turned off permanently after the first time it cost
somebody an hour, and then nothing would be watching at all.

**Escape hatches**, per decision 3: `KEEL_CONTEXT_WATCH=off` for a shell, `gates.context_watch: false`
for a project, and `gates.context_warn_pct` and `gates.context_stop_pct` to move the thresholds. 85
is a judgement, not a fact about any model.

**The handoff lands in `.keel/handoff.md`, git-ignored, and not in the docs tree.** It is session
state rather than project knowledge: it is stale the moment work resumes, and a file the tooling
writes into a committed tree is swept into the next commit by `git add -A`, which happened twice
before this moved. `.keel/` is where keel's own state already lives, beside `profile.json`, and
`keel doctor` fails if the file is committable.

The rule that makes ignoring it safe, and which is why the stop instruction and the written template
both carry it: **anything durable in a handoff moves to its real home before the file is discarded**,
a decision to an ADR under `decisions/`, everything else to the artifact it belongs to. One handoff
in this repository's own history carried six decisions recorded nowhere else. Ignoring the file
without that rule turns a scratch file into a shredder.

The accepted cost, stated so nobody rediscovers it as a bug: an ignored handoff does not travel. A
teammate picking up the branch from GitHub gets the branch without the note, and `git add -f` covers
the rare case where sharing it is wanted.

## Session hygiene, the part skills cannot enforce

`context-budget` documents this and the prompting cheatsheet repeats it, because it is
the user's lever, not the model's:

- `/clear` between unrelated tasks. The artifact chain means nothing is lost.
- Start a task by pointing at its plan file, not by re-explaining the project.
- Prefer "read `docs/keel/architecture/payouts.md` then do X" over pasting the architecture.
- Long debugging sessions accumulate dead ends. Once the root cause is found, `/clear` and
  fix in a fresh session with just the finding.

## Reply length is output cost, and it was ungoverned

Everything above budgets **input**: what sits in the prefix of every request. Reply length is
**output**, and until 2026-08-16 nothing here addressed it, even though the same request that
carries the block also carries however many tokens the model chooses to write back.

**The rule is on by default and it is not free.** `hooks/session-start` selects one paragraph from
`conventions.response_style` and `conventions.explain_level` together, so there are four forms and
not two. Measured 2026-08-18:

| `response_style` | `explain_level` | Injected | Chars | Tokens |
|---|---|---|---|---|
| `terse` | `technical` | the brevity paragraph | 1,284 | 356 |
| `terse` | `plain` | brevity and define-on-first-use | 1,283 | 356 |
| `verbose` | `technical` | nothing | 1,082 | 300 |
| `verbose` | `plain` | define-on-first-use | 1,273 | 353 |

The defaults cost **356** against a 250 target and a 400 ceiling. That is 56 tokens of input in
every request of every session, spent to shorten output in some of them, and the direction of that
trade has never been measured. It was taken as an explicit instruction on 2026-08-16, not as an
inference, and it is recorded here rather than buried because the 44 tokens of remaining headroom
are now the tightest budget in this document.

`NFR-01` of `docs/prd/plain-language-chat.md` holds every combination at or under 356 for exactly
that reason, so adding a dial did not spend the headroom. `tests/validate-skills.sh` measures all
four rather than whichever one the local profile selects.

`output-styles/keel-terse.md` still ships and still costs zero, but it is now the machine-wide
alternative for non-keel repositories rather than the mechanism. The managed block was never an
option for either: it sits in every request, and its budget is the tightest in the table.

**What it governs.** Chat only. The rule it encodes is that artifact detail and reply length are
separate dials: a PRD or a plan is as long as its skill requires, and the reply stops restating it.
The statements keel's gates depend on are exempt by name, because they are all short and a brevity
instruction would otherwise trade them away first.

**Three limits, stated rather than discovered.**

1. **It does not reach subagents.** A subagent runs its own system prompt and the SessionStart
   injection is the main thread's, so a delegated report comes back at whatever length that agent
   chose. `repo-snapshot`, `port-assess`, `apex-port-plan`, `shape-idea` and `execute-plan` all
   delegate, so fan-out work is unaffected by either mechanism.
2. **keel's share of reply length has never been measured.** Open question 1 in
   `docs/ideas/concise-responses.md`: if keel is a small fraction of it, the saving is small and the
   value is the artifact-versus-chat rule rather than the tokens.
3. **Nothing enforces it.** Unlike every budget in the table above, there is no check. A reply is
   not a file, so `keel doctor` cannot size one.

## Measuring it

`context-budget` produces `docs/keel/context-audit.md`. The three keel-owned rows below are this
plugin's real figures. The block row was re-measured on 2026-08-19 after the template was trimmed;
the other two are unchanged since 2026-08-16. The project rows are one repository's and vary. The
descriptions row carries two numbers, because they answer different questions. Its budget is derived
at the per-skill target of 44 times the skill count, so it moves every time a skill is added and says
whether the descriptions are the right size; the fixed 1,320 ceiling beside it says whether there are
too many of them. `tests/validate-skills.sh` enforces the second:

```markdown
# Context audit, 2026-08-16

## Always loaded
| Source                             | Tokens | Budget | Status |
|------------------------------------|--------|--------|--------|
| CLAUDE.md keel block               |    469 |    450 | OVER   |
| CLAUDE.md project                  |  1,890 |    500 | OVER   |
| SessionStart injection             |    356 |    250 | OVER   |
| Skill descriptions (24, ceil 1,320)|  1,066 |  1,056 | OVER   |
| Total                              |  3,781 |  2,256 | OVER   |

## Cache hazards
- CLAUDE.md line 84 embeds a "last updated" date. Changing it invalidates the cache
  for every request. Remove it or move it below the managed block.

## Recommendations
1. Move the 40-line deployment section out of CLAUDE.md into
   docs/keel/runbooks/deploy.md. Saves ~1,100 tokens per request.
2. Three skills are over the 700-word target: security-audit, setup-deployment,
   write-docs. Each needs a passing eval arm at that length, per ADR-0001.
```

Token counts come from the Anthropic count-tokens endpoint where an API key is available,
and a `chars / 3.6` estimate otherwise, which is close enough for budgeting.
