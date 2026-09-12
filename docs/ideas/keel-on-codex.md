# Idea: keel on OpenAI Codex CLI

| | |
|---|---|
| Raised by | Bernard, 2026-09-05 |
| Status | **superseded 2026-09-05. Accepted under a changed constraint: tiered support, documented and enforced.** See [Amendment](#amendment-2026-09-05-the-bar-changed) |
| Original status | declined pending `openai/codex#28437`, under the constraint "same guarantees or not supported" |
| Recommendation | **Build it as Tier B.** The original recommendation below is not withdrawn and not wrong; it was correct under the bar it was given, and the bar moved |
| Next | `design-architecture` on tiered multi-harness support. Not `write-prd`, and not an implementation plan yet |

## Amendment, 2026-09-05: the bar changed

This record answered the question it was asked. The question was asked under a constraint the
requester has since replaced, so the answer no longer follows. Nothing in Parts 1 through 4 is
withdrawn: every finding, every verdict and the cost arithmetic stand as measured. What changed is
the rule applied to them.

**Old constraint:** same guarantees or not supported. A harness missing any Layer 1 gate is not
supported at all.

**New constraint:** tiered support, documented and enforced. A harness is supported at a named tier
that states exactly which gates it delivers, and the tier claim is mechanically checked rather than
asserted in prose.

Under the old rule, one absent gate is decisive on its own and no amount of cheapness elsewhere can
outweigh it, which is why this record's arithmetic never had to be netted out. Under the new rule
the absent gate is a fact about Tier B rather than a veto, and the rest of the record's findings
become the case for building.

### The three reasons the requester gave, and what each one does to the record

**1. keel's own gate does not claim what the bar assumed it claimed.** `hooks/sensitive-guard:31-32`
says the gate "raises the cost of a careless commit; it is not a boundary against a
determined one. The boundary is review." Codex says the same of its own mechanism: "Treat tool
hooks as a useful guardrail, not a complete enforcement boundary." Part 1 quoted the Codex sentence
already, and used it to argue that keel's claim was stronger than the vendor's. The half not
noticed at the time is that keel's own header makes the *weaker* claim too. Both documents describe
the same class of instrument. Declining an entire harness over the absence of a cost-raising
mechanism, described in the repository as cost-raising, is a stricter line than keel's own
documentation supports. This is the load-bearing reason: it says the original bar was
miscalibrated, not merely inconvenient.

**2. The yes is much cheaper than expected, and this record is what established that.** Three of
four gates port. `codex plugin marketplace add gbi-solutions-ltd/keel` is a real one-liner.
`hooks/hooks.json` is nearly drop-in, same event names, same shape, and Codex sets
`CLAUDE_PLUGIN_ROOT` for compatibility. The 25 skill descriptions measure 4,764 characters against
an 8,000-character floor, roughly 40% headroom. Part 4's own words were "several of them more
cheaply than anyone expected." Under the old rule that cheapness was irrelevant. Under the new one
it is the whole point.

**3. The cost side is known and affordable.** 6 eval runs per release gate become 12, roughly $6
against the measured $2.34 and $2.99, plus one-time Codex baselines and re-derived word ceilings,
plus 18 sentences to repair. Part 4 called the standing two-harness obligation "the part that is
not obviously affordable." That judgement was made against a benefit of zero, because the old rule
had already ruled the benefit out. Against Tier B actually shipping, it is affordable, and it is
now a design input rather than an objection.

### What did not change, and is now the hardest requirement in the work

Part 4's strongest paragraph is that **a gate which looks installed and is not is worse than no
gate**. Tiering does not dissolve that risk. It relocates it, and the relocation is not obviously
an improvement.

The old failure mode was concrete and local: a `sensitive-guard` on Codex that is schema-valid,
silent, and lets the command run, in a repository that declared `hard_block_paths` and believes it
has cover. The new failure mode is diffuse and slower: **a tier claim that drifts.** README says
Codex is Tier B, Tier B is defined as delivering three named gates, and at some later commit the
code has quietly stopped delivering one of them. Nobody notices, because the claim lives in prose
and the delivery lives in code, and nothing forces them to agree. The victim is the same person in
the same position, believing they have cover they do not have, and the evidence that would have
told them is now one document further away from the thing that broke.

So this is the central constraint on the design, not a caveat inside it:

- **No gate installs anywhere it does not function.** A hook that is schema-valid and inert must
  not reach disk. This has to be structurally true, enforced by the packaging path, rather than
  true by the convention that whoever edits the installer remembers it.
- **The tier table is generated or checked, never hand-maintained.** A claim about a harness that
  exceeds what the harness delivers is a test failure, not a documentation nit.
- **`keel doctor` reports the harness it is actually running under and which gates are actually
  active there**, so the answer comes from the machine in front of the person rather than from
  README.

Design work that satisfies the tier requirement but not these three has moved the risk rather than
managed it, and should be rejected on the same grounds this record rejected the silent gate.

### What this amendment does not do

It does not revisit any Part 1 verdict. Test 3 still fails and still fails open;
`openai/codex#28437` is still open; whether a Codex `deny` survives `approval_policy = "never"` is
still unverified and still has to be treated as a fail until someone runs it. Tier B is being built
around those facts, not in spite of them. It also does not settle whether Codex's own
`approval_policy` can be scoped to paths or command patterns, which would give `sensitive-guard` a
native approval path without waiting on #28437. That is a bounded question for the design turn, and
if the answer is yes it changes Codex's tier rather than this amendment.

## The problem

keel installs on one harness. Anyone who works in Codex CLI gets the managed `AGENTS.md` block and
nothing else: no skills, no gates, no `keel` CLI. The cost is that keel's reach is bounded by
Claude Code's, and the house cannot standardise delivery across people who have already picked a
different tool.

**Evidence.** Partial. `docs/03-install-and-distribution.md:429` already names Codex as an
`AGENTS.md` reader, so the gap was anticipated at Layer 2 on 2026-08-16. Nobody named a specific
person blocked on this, and no dated instance of someone asking for keel-on-Codex was found in the
repository. **The driver stated for this record is adoption in the abstract, not an observed
request.** That is worth putting first, because it changes what the cost side has to beat: not a
person waiting, but a hypothesis about reach.

## What was asked for

> should keel support OpenAI Codex CLI as a first-class install target, at the same level of
> guarantee it offers on Claude Code?

With three constraints fixed by the requester, not open here: Codex CLI only (Gemini, Cursor,
Copilot and Aider out of scope); **same guarantees or not supported**, a degraded prose-only keel
being an unacceptable outcome; and the install path and the honesty of the README weighted equal to
the mechanisms.

## The case against

**Strongest argument for not building this at all.** keel's claim is not "25 good skills." It is
that four things happen whether or not the model cooperates, and one of those four cannot be made
to happen on Codex today. `hooks/sensitive-guard` exists to be the single gate a sentence in chat
cannot move (`hooks/sensitive-guard:5-14`), and it achieves that with exactly one instrument:
`permissionDecision: "ask"`, which the model cannot satisfy for itself because the harness puts it
to a human. On Codex that value is accepted by the wire schema and then discarded: the hook run is
marked failed **and the command runs anyway**. A ported `sensitive-guard` would be schema-valid,
silent, and useless, and the repository declaring `hard_block_paths` would believe it had cover it
did not have. That failure mode, a gate that looks installed and is not, is worse than no gate,
and it is the one keel spent a decision on avoiding.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Zero | This is the recommendation. keel already dual-writes `AGENTS.md` (`bin/keel:927-928`), so Codex users get Layer 2 today. It is honest, already shipped, and already documented as a deliberate stop (`docs/03-install-and-distribution.md:431-432`) |
| Do it manually | A Codex user clones keel and copies `skills/` into `.agents/skills/` themselves | Actually works, and is worth documenting as an unsupported recipe. It is not "first-class" and makes no guarantee, which is the point: it does not pretend |
| Buy it | Nothing to buy | No product ports an SOP's enforcement layer between agent harnesses. Not an option |
| Build something smaller | Ship Layers 2 and 3 on Codex (skills, `AGENTS.md`, the session router, `done-guard`, `context-watch`) and document `sensitive-guard` as absent | **This is the tempting one and it is what the constraint forbids.** keel with three of four gates is not keel at the same level of guarantee; it is keel with the security gate quietly missing on one of its two supported harnesses |

**Variants of building it** (kept out of the table above on purpose)

| Variant | What it would mean |
|---|---|
| Skills-only on Codex | Package the 25 skills, no hooks. README can claim "the skills work"; can claim no gate at all |
| Skills plus a hook adapter | Everything above plus `session-start`, `done-guard`, `context-watch`. Three of four gates. Cannot claim the hard block |
| `deny` instead of `ask` | Substitute the one decision Codex does implement. Strictly stronger and therefore a *different* gate: no human can approve, so every commit touching `hard_block_paths` is refused outright. `hooks/sensitive-guard:9-11` already rejected this reasoning for Claude Code ("`ask` and not `deny`"), and a gate with no approval path is the gate people delete |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| Adoption is actually blocked on this | Someone wanted keel and could not have it because they use Codex | A named person and a date | **No. Nobody named one.** This is the weakest link in the whole record |
| Codex hooks can inject a session router | `SessionStart` returns model-visible text | Read the output schema | **Yes, verified first-hand. Passes** |
| Codex can refuse to end a turn | `Stop` blocking reaches the model | Read the Stop schema and semantics | **Yes, verified first-hand. Passes** |
| Codex can put a shell command to a human | `PreToolUse` supports an ask decision | Read the PreToolUse schema and the released behaviour | **Yes, verified first-hand. Fails, and fails open** |
| A second harness's guarantees can be inherited from the first | Behaviour under pressure transfers between models and runtimes | Run the eval scenarios on Codex | **No. Never run. `docs/ideas/model-routing.md:118-140` is the standing evidence that behaviour does not transfer even between models on one harness** |
| keel's 25 skill descriptions stay visible on Codex | Total stays under the preload budget alongside everything else installed | Measure | **Partly. 4,764 chars against an 8,000-char floor, but the budget is shared** |

## What the system says

Every row below carries a URL or a `path:line`. Codex facts were checked **2026-09-05** against
`developers.openai.com/codex/*` (which 308-redirects to `learn.chatgpt.com/docs/*`) and
`openai/codex` at commit `459a79eb85400af759e9220c7bafb4429ae07516`, release `rust-v0.153.4`.

### Part 1: the four go/no-go tests

**I opened all four of these pages myself rather than taking them from a subagent**, per the
15% bad-citation rate `docs/ideas/model-routing.md:131-134` measured on sonnet fan-out. The
premise this record was commissioned on turned out to be wrong on three of the four.

| # | Test | Verdict | Evidence |
|---|---|---|---|
| 1 | Session context injection | **PASS** | `SessionStart` output supports `hookSpecificOutput.additionalContext`, and plain stdout is also injected: "Plain text on `stdout` is added as extra developer context." (`developers.openai.com/codex/hooks.md`, SessionStart section). Confirmed independently in the wire schema `codex-rs/hooks/schema/generated/session-start.command.output.schema.json`, which defines `additionalContext` on `SessionStartHookSpecificOutputWire`. Brief A traced where it lands: `codex-rs/core/src/context/hook_additional_context.rs` gives it `role() == "developer"`, so it reaches the model, not just the UI |
| 2 | Stop blocking | **PASS** | `{"decision":"block","reason":...}`, or exit 2 with the reason on stderr. "it tells Codex to continue and automatically creates a new continuation prompt that acts as a new user prompt, using your `reason` as that prompt text." `stop_hook_active` is a required input field, so loop protection exists. `stop.command.output.schema.json` enumerates `decision` as `["block"]` only |
| 3 | Shell interception with `ask` | **FAIL, and fails open** | `tool_input.command` carries the full string for `Bash` and `apply_patch`, and `deny` works. But verbatim: "`permissionDecision: "ask"` ... are parsed but not supported yet. Codex marks the hook run as failed, reports the error, **and continues the tool call**." The wire schema `pre-tool-use.command.output.schema.json` *does* list `ask` in `PreToolUsePermissionDecisionWire`, which is the trap: schema-valid, non-functional. Source test `codex-rs/hooks/src/events/pre_tool_use.rs:556` is named `unsupported_permission_decision_fails_open`. Tracked at `openai/codex#28437`, open since 2026-06-16 |
| 4 | Trust and enablement friction | **PASS, much lower than assumed** | Hooks are **on by default**: "Hooks are enabled by default." `codex-rs/features/src/lib.rs` has `FeatureSpec{ key: "hooks", stage: Stage::Stable, default_enabled: true }`; `codex_hooks` is a deprecated alias, not a required flag. The real friction is a hash-pinned trust review: "Codex records trust against the hook's current hash, so new or changed hooks are marked for review and skipped until trusted", via `/hooks`. Three user actions: place the hooks, start Codex, trust them |

**Two things Codex says about its own gate that keel cannot ship around.** First, on tool coverage:
"Some specialized tool paths can opt out of the default hook path. **Treat tool hooks as a useful
guardrail, not a complete enforcement boundary.**" keel's sentence about a gate a sentence in chat
cannot move is a stronger claim than the vendor makes about the mechanism underneath it. Second,
whether `deny` is still honoured under `--dangerously-bypass-approvals-and-sandbox` (alias
`--yolo`) / `sandbox_mode = "danger-full-access"` / `approval_policy = "never"` is **undocumented**.
Hooks demonstrably still *run* in that mode (`permission_mode` is passed to `PreToolUse` and can be
the literal string `bypassPermissions`, and `codex-rs/core/src/hook_runtime.rs` maps
`AskForApproval::Never => "bypassPermissions"`), but no primary source states that a `deny`
decision still stops the command there. On Claude Code that survival is the entire reason the gate
is worth anything (`bin/keel:558`). **It is unverified on Codex and must be treated as a fail.**

### Part 2: install and distribution

The adoption half is in much better shape than the enforcement half.

| Question | Finding |
|---|---|
| Skill discovery | `$CWD/.agents/skills`, each ancestor's `.agents/skills` up to the repo root, `$REPO_ROOT/.agents/skills`, `$HOME/.agents/skills`, `/etc/codex/skills`, plus system-bundled. `$CODEX_HOME/skills` (`~/.codex/skills`) exists but is marked deprecated in `codex-rs/ext/skills/src/host_roots.rs`. Same-named skills are not merged; both appear |
| Can a package ship them | **Yes.** A plugin bundles them: `.codex-plugin/plugin.json` with `"skills": "./skills/"`. `keel init` does not have to place them |
| Extra frontmatter keys | **Ignored gracefully.** `codex-rs/skills/src/parser.rs` deserialises `name`, `description`, `metadata` with no `#[serde(deny_unknown_fields)]`, so keel's `allowed-tools:` on all 25 skills is silently dropped. `description` is hard-required; `name` is capped at 64 chars (`MAX_NAME_LEN`) |
| Plugin manifest | `.codex-plugin/plugin.json`: `name`, `version`, `description`, `skills`, `hooks`, `mcpServers`, `apps`, `interface{...}`. Skills, hooks and assets sit at the plugin root |
| The one-line install | **`codex plugin marketplace add gbi-solutions-ltd/keel`** is a near-exact counterpart to `/plugin marketplace add gbi-solutions-ltd/keel`, then install from `/plugins` in the CLI browser. Accepts `owner/repo`, `owner/repo@ref`, Git URLs and local paths, with `--ref` and `--sparse` |
| `AGENTS.md` | Read automatically, "before doing any work", rebuilt once per session. Global `~/.codex/AGENTS.md` plus every directory from repo root down to cwd, concatenated root-first with nearer files winning. `AGENTS.override.md` takes precedence per directory. Capped at `project_doc_max_bytes`, 32 KiB default |
| Progressive disclosure | **Holds in principle, differs in the numbers.** "ChatGPT and Codex start with each skill's name and description, then load the full `SKILL.md` instructions when they decide to use that skill." Both implicit (description-matched) and explicit (`$skill`, `/skills`) invocation exist |
| **The budget, and why the ceilings must be rederived** | "this list uses at most 2% of the model's context window, or 8,000 characters when the context window is unknown. If many skills are installed, Codex shortens skill descriptions first. For large skill sets, Codex may omit some skills from the initial list and show a warning." Three differences from Claude Code: it is a share of the window rather than a fixed allowance, the preload list **also includes each skill's file path**, and under pressure Codex silently shortens or drops descriptions. **I measured keel's corpus: 25 descriptions total 4,068 characters, 4,764 including paths, against an 8,000-character floor.** keel fits alone with ~40% headroom. It does not have that budget to itself: it shares it with Codex's own bundled skills and anything the user installed. `docs/05-token-and-memory-design.md:39-147` and ADR-0001's 44-tokens-per-description and 1,320-token ceiling were derived against a different mechanism and **cannot be reused, only rederived** |
| Subagent fan-out | Codex has subagents, built-in `default`/`worker`/`explorer` agents, and custom agents as TOML under `~/.codex/agents/` or `.codex/agents/` that can pin `model` and `model_reasoning_effort`. "Codex can also follow applicable `AGENTS.md` or skill instructions that request delegation." The spawn tool matches `Agent` in `PreToolUse` |

### Part 3: internal coupling inventory

Classified (a) already harness-neutral, (b) portable with an adapter, (c) Claude Code only.

| Mechanism | `file:line` | Class | Why | What an adapter does |
|---|---|---|---|---|
| `lib/merge-claude-md.sh` | whole file, 42 lines | **(a)** | Nothing in it names `.claude`, `CLAUDE.md` or `AGENTS.md`; both functions take the target as a parameter. The filename lies about the file | Nothing |
| `bin/keel:927-928` dual-write | `merge_block CLAUDE.md "$block"` / `merge_block AGENTS.md "$block"` | **(a)** | Same rendered `$block` into both. **Refinement to the starting facts:** "identically" is true of the managed block, not of the whole files, since each merges against its own pre-existing content | Nothing |
| `lib/detect-stack.sh` stack detection | bulk of 940 lines | **(a)** | Pure detection, no harness reference | Nothing |
| `lib/detect-stack.sh` `lang_lsp` / `detect_plugins` | `890-940` | **(b)** | Returns Claude-marketplace plugin names | A Codex plugin list, or drop the recommendation |
| `hooks/hooks.json` | whole file, 95 lines | **(b), and cheaper than expected** | Codex plugins bundle lifecycle hooks at `"hooks": "./hooks/hooks.json"` in the **same** `{event: [{matcher, hooks:[{type:"command", command}]}]}` shape, with the same event names, and **Codex sets `CLAUDE_PLUGIN_ROOT` and `CLAUDE_PLUGIN_DATA` for compatibility**, which is exactly what `hooks/hooks.json:9` interpolates | Close to nothing. `SubagentStop` and `PreCompact` both exist on Codex too |
| `hooks/session-start` | 167 lines | **(b)** | Reads no stdin fields; emits `hookSpecificOutput.additionalContext`, which Codex supports on `SessionStart` | Nothing structural |
| `hooks/done-guard` | 143 lines, emits at `:86` | **(b)** | Emits `{"decision": "deny", ...}`. Codex's `Stop` schema enumerates `decision` as `["block"]` only | A one-word rename, `deny` to `block` |
| `hooks/context-watch` + `lib/context_watch.py` | `lib/context_watch.py#transcript = ev.get("transcript_path") or ""`, `107-116` | **(b), fragile** | Reads `transcript_path`, which **Codex does provide** in common input fields, then sums `message.usage.{input_tokens, cache_creation_input_tokens, cache_read_input_tokens, output_tokens}` per non-sidechain assistant turn. Codex warns: "`transcript_path` points to a chat transcript for convenience, but **the transcript format isn't a stable interface for hooks and may change over time**" | A second parser, on a format the vendor declines to stabilise. This is a maintenance liability, not a one-off port |
| `hooks/sensitive-guard` | 188 lines, emits at `:37` and `:82-83` | **(c)** | Emits `permissionDecision: "ask"`. See Part 1 test 3 | **None exists.** This is the whole decision |
| `bin/keel` `settings_report_load` / `plugin_report` / `boundary_report` | `159-276` | **(c)** | Reads `enabledPlugins` and globs `<cfg>/plugins/cache/*/*/*/skills/*/SKILL.md` | n/a |
| `bin/keel` `write_nudge` | `515-553` | **(c)** | Emits Claude hook JSON and names `/plugin marketplace add` | n/a |
| `bin/keel` `keel_deny_rules` / `keel_ask_rules` | `575-591`, `614-633` | **(b) in part, (c) in part** | 13 deny rules, 13 ask rules. See the permissions row below | n/a |
| `bin/keel` `expected_plugins` | `665-670` | **(c)** | Emits `name@claude-plugins-official` | A Codex marketplace equivalent, or drop |
| `bin/keel` `write_settings` / `merge_permissions_into_settings` / `write_local_settings` | `672-698`, `703-725`, `738-761` | **(c)** | Whole-file writers for `.claude/settings.json` and `.claude/settings.local.json` | n/a |
| `bin/keel` doctor: marketplace, plugin set, permissions, `settings.local.json`, VS Code extension, `CLAUDE.md` budget | `1350-1357`, `1367-1380`, `1476-1493`, `1557-1574`, `1608-1664`, `1666-1738` | **(c)** | Reads `known_marketplaces.json`, `enabledPlugins`, `anthropic.claude-code-*` | n/a |
| `output-styles/keel-terse.md` | 48 lines | **(c)** | **`bin/keel` never references it** (`grep -c output-styles bin/keel` is 0). It is picked up by Claude Code's plugin loader by convention and validated only by `tests/validate-skills.sh:204,296`. No Codex counterpart found | Drop. keel loses the terse output style on Codex |
| `.claude/settings.json` permission rules | written by `bin/keel` when this was recorded, and by `lib/harness/claude.sh#harness_permission_rules` since the harness refactor | **(b) for 5, (c) for 21** | **Codex has no command-pattern rule syntax at all.** Permission profiles are path globs and network domains: `[permissions.<name>.filesystem.":workspace_roots"]` with `"**/*.env" = "deny"`, and `[permissions.<name>.network.domains]`. So: the 5 `Read(./.env)`-style deny rules port to filesystem denies and **get stronger** (a path deny also stops `cat`); the 8 `Bash(cat *.env*)` deny rules become redundant; and **all 13 `ask` rules have no counterpart whatsoever**, because Codex has no "prompt the human for this command pattern" primitive. The three egress rules (`curl`, `wget`, `nc`) map partly onto network domain rules, but only with `features.network_proxy = true` and only for sandboxed commands | Rewrite 5, delete 8, lose 13 |
| The 25 skill bodies | see below | **(b)** | n/a | Per-harness variants of 7 skills |

**Line count for `bin/keel`.** 577 lines are unambiguously Claude-coupled out of 2,020 (28.6%), or
638 (31.6%) if the context-watchdog diagnostic at `1495-1555` is counted as downstream of a
Claude-only hook. **The starting fact of "roughly 630" lands in the right band by the wrong route.**
Three of its four cited ranges are exact (`159-276`, `523-698`, `703-761`), but "doctor's plugin
section (1479-1738)" is not a section: only 109 of those 260 lines are about plugins or the
marketplace, and the estimate omits the `CLAUDE.md` marker and budget checks (`1350-1357`,
`1367-1380`) and the permission-guardrail, `settings.local.json` and VS Code checks (`1608-1664`)
entirely. The over-count and the omission roughly cancel.

**The skill bodies, which is the failure mode most likely to be missed.** Across all 25 skills and
their 60 reference files: 48 body instructions to dispatch a subagent, 5 naming the `Explore`
subagent type, ~12 `model` pins, 3 slash-command invocations, 6 Claude-plugin references, and
**zero** occurrences of `subagent_type`, `TodoWrite`, `NotebookEdit`, `hookSpecificOutput`,
`permissionDecision`, `.claude/` paths, or the words "Claude" or "Anthropic" in an
instruction-bearing position. All 25 carry `allowed-tools:`, which Codex ignores.

Seven skills instruct a mechanism with no *literal* Codex equivalent: `repo-snapshot`
(`SKILL.md:49`), `port-assess` (`:37`), `apex-port-plan` (`:30`), `write-plan` (`:43`),
`security-audit` (`:46`), `execute-plan` (`:47`) and `create-skill` (`:27`). The other 18 run
unchanged or degrade gracefully, because their plugin and slash-command references all carry an
explicit inline fallback.

**Arbitration, and a correction to Brief D.** Brief D classified those seven as BLOCKING, and said
so honestly under a stated assumption it could not test: that Codex might have no subagent
primitive at all. It does have one, so the correct class is **(b), portable with an adapter**:
`Explore` becomes Codex's built-in `explorer`, and the `model: sonnet` pin moves out of the skill
body into a keel-shipped custom agent TOML under `.codex/agents/`. That is a real cost (seven
skills need per-harness bodies, or a harness-neutral rewrite of the delegation language) but it is
not a wall.

**A second refinement to the starting facts:** `shape-idea` was listed as one of four mechanical
fan-outs. It is not. `repo-snapshot`, `port-assess` and `apex-port-plan` each have a lettered A-F
table, one subagent per letter, one message, and a collapse-to-three rule. `shape-idea:38-39` has a
single unstructured sentence with a model pin, no table and no fixed count.

**One defect found in passing, unrelated to Codex.** `hooks/sensitive-guard:13` cites
`bin/keel:393` as where the `bypassPermissions` survival is "recorded as verified against a live
session". Line 393 is `local pm_json; pm_json="$(json_or_null "$pm")"`, stack detection. The real
reference is `bin/keel:558`. The citation has drifted and should be repaired independently of this
decision.

### Part 4: options and cost

| Option | What keel can claim afterwards | What it cannot claim |
|---|---|---|
| **Do nothing beyond today's `AGENTS.md`** | "keel installs on Claude Code. Its principles and verify commands travel to any agent that reads `AGENTS.md`, including Codex." Every current sentence stays true | Nothing on Codex beyond prose. No skills, no gates |
| **Skills-only on Codex** | "25 skills, installable on Claude Code and Codex" | Any gate, on Codex. Layer 1 would be absent and the README would have to say so in the same breath as the install line |
| **Skills plus a hook adapter** | The router, the done gate and the context watchdog all hold. "Three of four gates" | **The hard block.** `docs/07-open-decisions.md:176-178` and `196-199`, `README.md`'s paragraph opening "Bypassing prompts is bounded" and `docs/profile-keys.md:56` would each need a per-harness asterisk, which the governing constraint forbids |
| **An explicit documented no** | Everything keel claims today, unchanged, plus one honest paragraph naming Codex, naming the exact missing primitive, and naming the issue that would change the answer | That keel runs on Codex |

**Cost 1: the test matrix.** The static suite is 13 files and **848 assertions, 0 failing** (run
during this exercise). 114 (13.4%) are pure hook-protocol tests that only mean something against a
harness: `test-session-start.sh` (32), `test-context-watch.sh` (55), `test-sensitive-guard.sh` (16),
`test-done-guard.sh` (11). Adding `test-keel.sh`'s marketplace, `enabledPlugins`, permissions and
nudge sections brings the coupled share to **166 assertions counted exactly (19.6%)**, or ~202
(23.8%) on a line-share estimate. The remaining ~76-80% is stack detection, profile writing and
doc-claim checking, and does not care who invokes `bin/keel`.

The evals are the real bill, and there is one genuinely good piece of news in them:
**`tests/evals/run.sh` is already harness-neutral.** It pastes each injected `SKILL.md` body into
the prompt as plain text (`:29-53`) rather than relying on a plugin install, and `stage.sh` is pure
file-copying. What is coupled is the dispatch and the parse: `stage.sh:99` prints
`claude -p "$(cat ../prompt.md)"`, and `tests/evals/results.md`, under "author mode, the first
recorded run", scores tool calls with `jq` against Anthropic's `stream-json` `tool_use` shape.
Codex does have a headless counterpart
(`codex exec` with `--json`/`--experimental-json` and `--output-last-message`), so a Codex arm is
mechanically buildable, but it needs a second output parser. Scoring is human either way; there is
no model-judge step (`tests/evals/README.md:75-77`).

In runs, not adjectives:

- Today: 12 scenarios exist, **6 are dispatched at each release gate, one arm each. 6 runs.**
- With a second supported harness: **6 runs become 12** per gate. 6 scenarios x 2 harnesses x 1 arm.
- Measured cost of today's 6: **$2.3430 / 2m16s** (0.17.0 gate, 2026-09-01, `tests/evals/results.md`) and **$2.9909 / 3m59s** (2026-09-04 gate, `CHANGELOG.md:12`).
- ESTIMATE at 2x, assuming price parity that nobody has checked: **$2.34 → ~$4.69**, **$2.99 → ~$5.98** per gate. Arithmetic is 2 x the measured figure; the parity assumption is unverified.
- **Not in that number, and larger:** a Codex baseline arm has never been run for any scenario. Baselines are recorded once at authoring time, and "same guarantees" means a Codex baseline must be *observed*, not inherited. That is 6 to 12 one-time runs. And ADR-0001's 700/900-word ceiling was calibrated against Claude Code's skimming behaviour, validated by 5 evals at 692-698 words; re-deriving it for Codex is its own set of arms.
- Evals are **not in CI** (`.github/workflows/ci.yml` runs only `tests/run-tests.sh`, shellcheck and the supply-chain scan on every push and PR). So this doubles a manual per-release cost, not a per-PR bill. Six dollars a release is affordable. **The one-time baseline and ceiling work, and the standing obligation to re-run every scenario on two harnesses forever, is the part that is not obviously affordable.**

**Cost 2: the claims audit.** Under "same guarantees or not supported", **18 sentences become
false**, 7 need an asterisk, and 3 stay true while misleading. The false ones cluster:
`README.md:16` ("That is the whole install"), `README.md:87-89` (the output style in `/config`),
`README.md`'s "Bypassing prompts is bounded" paragraph (deny and ask rules surviving
`bypassPermissions`, the headline safety claim);
`docs/01-architecture.md` and `:152` and `:156-159` (Layer 1 as "enforced by the runtime not
the model", and "where a rule is genuinely non-negotiable, we put it in a hook");
`docs/07-open-decisions.md:176-178` and `:196-199` (the hard block, and `ask` as "the only decision
in the hook protocol the model cannot satisfy for itself");
the install block of `docs/03-install-and-distribution.md`, `:30`, `:175-181`;
`docs/profile-keys.md:51` and `:56`; `docs/02-skill-catalog.md:65`, `:383`, `:536`, `:544`; and
`docs/04-plugin-strategy.md:11`, which takes the whole 221-line document with it.

Five places need a new section rather than a word change: `docs/03-install-and-distribution.md`
(there is no non-plugin install path documented at all today), `docs/04-plugin-strategy.md`,
`docs/07-open-decisions.md` decisions 3 and 12, `docs/05-token-and-memory-design.md`, and README's
Install and Upgrading sections.

`docs/03-install-and-distribution.md:427-432` is confirmed exactly as the requester described it,
and is the sentence to keep true rather than work around:

> The skills themselves stay Claude-only for now; porting them is a later decision, not a Phase 1
> one.

## Open questions

1. **Who is actually blocked?** Nobody was named. A single dated instance of a person who wanted
   keel and could not have it because they use Codex would change the weight of everything above.
2. **Does `openai/codex#28437` land, and when?** Open since 2026-06-16. This is the single fact
   that flips the recommendation.
3. **Does a Codex `deny` survive `--yolo` / `danger-full-access` / `approval_policy = "never"`?**
   Undocumented. Even after #28437 ships, an `ask` that evaporates in full-auto is worth what the
   current one is worth, which is nothing.
4. **Does keel's behaviour under pressure reproduce on Codex at all?** Unknown, and unknowable
   without running the arms. `docs/ideas/model-routing.md:118-140` is the standing evidence that
   this does not transfer for free.

## Recommendation

> **Superseded 2026-09-05, kept verbatim.** This is the answer under the constraint "same
> guarantees or not supported". It was correct under that bar. The bar changed; see
> [Amendment](#amendment-2026-09-05-the-bar-changed) for what replaced it and why. Read this
> section as the record of a decision made honestly on the facts available, not as current
> guidance.

**Do not build it.** Three of the four Layer 1 gates port, several of them more cheaply than
anyone expected, and the install story is genuinely good: `codex plugin marketplace add
gbi-solutions-ltd/keel` is a real one-liner, keel's `hooks/hooks.json` is nearly a drop-in, and
Codex even sets `CLAUDE_PLUGIN_ROOT` for compatibility. None of that helps, because the gate that
does not port is the one keel spent a decision on, and it does not merely fail: `ask` is accepted
by the wire schema and then discarded while the command runs. Under "same guarantees or not
supported", that is a no, and it should be written down as one in
`docs/03-install-and-distribution.md` beside the portability section that already anticipated it,
naming the missing primitive so the next person does not re-derive this.

What happens next is that nothing is built, and `docs/03-install-and-distribution.md:427-432` gains
a paragraph naming Codex, `permissionDecision: "ask"`, and `openai/codex#28437`. Separately and
regardless of this decision, `hooks/sensitive-guard:13` should be repaired to cite `bin/keel:558`.

**The single fact that would flip this:** `openai/codex#28437` shipping `permissionDecision: "ask"`
as a native approval prompt, *and* that prompt surviving `approval_policy = "never"`. Both halves.
The first without the second buys nothing, for the same reason `bin/keel:558` gives.

## Not decided here

Whether keel should offer an unsupported, documented, copy-`skills/`-into-`.agents/skills/` recipe
for Codex users who want the skills without any claim attached. That is a `write-docs` question and
a genuinely cheap one, and it is deliberately left open rather than answered by this record's no.

Also not decided: what a harness-neutral rewrite of the seven fan-out skill bodies would look like,
whether `output-styles/` is worth an equivalent anywhere, and anything at all about Gemini CLI,
Cursor, Copilot or Aider, which were out of scope by instruction and stay out.
