# Idea: adopt what Claude Code 2.1.312 offers that keel's guarantees need

| | |
|---|---|
| Raised by | Bernard, 2026-10-29, asking for an assessment of the plugin against current Claude Code features, explored by Sonnet subagents |
| Status | agreed 2026-10-29: items 1, 2, 3, 4 and 9, with the open questions answered by Bernard below |
| Recommendation | Build something smaller: items 1 to 4 and 9. Do not build items 5, 6 and 8. Item 7 waits for its first instance |
| Next | Waits on the decision to strip Codex support from this plugin, raised by Bernard on 2026-10-29: that removes the case against's ADR-0004 argument and reopens item 8. Once its ADR lands, revise the case against, then `write-plan` for items 1 to 4 and 9 |

## The problem

keel's two Bash guards can still let a tool call through when they fail, and two pieces of keel
wait on, or reimplement, harness behaviour that Claude Code now documents. The fail-open gap costs
the one promise `hard_block_paths` makes, on any commit where the guard does not answer in time.

**Evidence.**

- **2026-10-25, the guard failed open on a crash.** `1580dae` records that an event whose
  `tool_input` is a string made the embedded Python in `hooks/sensitive-guard` raise, the hook
  exited 1, and the commit went through without asking. The fix, an `EXIT` trap that answers
  `ask`, sat on no branch until 2026-10-29 and is the first commit of
  `fix/sensitive-guard-exit-trap`.
- **The trap does not cover a timeout or a hook that cannot start.** The hooks reference, "Block
  the action when a hook fails": "On `PreToolUse`, a timed-out `command`, `http`, or `mcp_tool`
  hook doesn't block the tool call ... so don't count on a stalled hook to act as a gate."
  `hooks/hooks.json:47-50` gives `sensitive-guard` a 10 second timeout and no `onFailure`. **No
  timeout is on record**, so this half rests on the documented gap and not on an incident.
- **Decision 10 has waited on one observation since 2026-08.** `docs/07-open-decisions.md:495`
  leaves writing `outputStyle` open until someone sees how a plugin style is named. On
  2026-10-29, `claude -p "/output-style"` on 2.1.312 listed `keel:keel terse` among the styles.

## What was asked for

> assess the current status of this claude code plugin and identify points of improvement (if any)
> based on the available claude features. use sonnet subagents for the exploration

> pull to update main, switch to another branch where the rescued sensitive-guard fix will be the
> first commit then go ahead to write the idea record as suggested

## The case against

**Strongest argument for not building this at all.** Every item here makes keel depend on a
Claude Code version it never declares. `onFailure` needs 2.1.295, the `userConfig` picker needs
2.1.271, plugin `dependencies` resolution has its own version notes, and nothing in `README.md`,
`docs/03-install-and-distribution.md` or `lib/harness/capabilities` states a minimum. On an older
client a new field either does nothing, which leaves the gap open while the docs say it is closed,
or stops the plugin loading, which is worse than the gap. Each item is also Claude only, so per
ADR-0004 it adds another guarantee held at two strengths, and Codex users get none of it.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Nothing beyond landing the `EXIT` trap, which is already built | A guard that stalls for 10 seconds still lets the commit through, and decision 10 stays open after its observation exists |
| Do it manually | Tell users in `README.md` to keep Claude Code current and to pick `keel:keel terse` with `/output-style` | Moves a guarantee into prose a user may never read. The style half is defensible on its own |
| Buy it | Managed settings: an administrator sets `enabledPlugins` and `outputStyle` | Only for organisations on managed settings, and it does nothing for a guard that fails |
| Build something smaller | Item 1 alone, behind a stated minimum version | The recommendation, with items 2, 4 and 9 because each is a record or a check, not new machinery, and item 3 because the open questions chose it |

**The items assessed**

| Item | What it adds | Verdict |
|---|---|---|
| 1. `"onFailure": "block"` on `sensitive-guard` | A timeout, a hook that cannot start, or a crash the trap misses blocks the call instead of letting it through | **Build**, after the `EXIT` trap lands. It blocks as exit 2 does, not `ask`, so a failure costs a retry rather than a prompt. Not on `review-guard`, which runs on every Bash call, so its failure would block the main session too, and not on the advisory `context-watch` or the Stop-time `done-guard` |
| 2. Record the output-style observation | A `provides|claude|...` row with source, version and date, per ADR-0004, and decision 10's open half answered | **Build** the record, and have `keel init` write `"outputStyle": "keel:keel terse"`, per the answer to open question 2 |
| 3. `dependencies` in `plugin.json` | The required plugins in `docs/04-plugin-strategy.md` install with keel, replacing the `enabledPlugins` that `lib/harness/claude.sh:324` writes | **Build**, per the answer to open question 1, with `allowCrossMarketplaceDependenciesOn: ["claude-plugins-official"]` in `marketplace.json`. Building it overrules this record's default answer, and the cost is recorded there |
| 4. `claude plugin validate --strict` in CI | Manifest and marketplace errors fail the build instead of a user's install | **Build**, if open question 3 comes back cheap |
| 5. An `if` condition on `sensitive-guard`, such as `Bash(git commit*)` | Spares a process on Bash calls that are not commits | **Do not build.** The docs call `if` best-effort, and a commit written `cd x && git commit` or `git -C x commit` could skip a gate the hook's own parser already handles |
| 6. `userConfig` for per-user switches such as `KEEL_CONTEXT_WATCH` | A `/config` row instead of an environment variable | **Do not build.** No complaint about the variable is on record, and most of keel's switches are project facts that belong in `.keel/profile.json`, committed and shared, not per user. Compatibility is not the reason: only the `options` picker field stops older clients (before 2.1.271) loading the plugin, plain fields only lack a `/config` row before 2.1.269, and the 2.1.295 minimum from open question 4 covers both |
| 7. `argument-hint` and `$ARGUMENTS` on user-invoked skills | `/keel:ship <branch>` style invocation | **Not yet, revisit on the first instance.** Cheap and low risk, so the only reason against is that no user passing arguments to a keel skill is on record. The cost when built is a second invocation path the evals would cover |
| 8. Plugin `workflows/` for the review and execute-plan fan-outs | Deterministic orchestration instead of prose dispatch | **Do not build.** ADR-0005 keeps one skill body across harnesses, and Codex has no workflow runtime |
| 9. Two doc corrections | The docs state what is true now | **Build.** `docs/04-plugin-strategy.md:14` says every plugin named is in `claude-plugins-official`, while `:24` and `:28` mark Context7 and Playwright external. `docs/07-open-decisions.md:12` and `:54` say the repo is private, and `gh repo view` reports it `PUBLIC` |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| `onFailure` blocks a timed-out PreToolUse command hook | The hooks reference says so | "To block the call when a `command` or `http` hook times out, set `onFailure: \"block\"`", requires 2.1.295 | **Checked against the docs** 2026-10-29. Not probed |
| A client older than 2.1.295 ignores `onFailure` rather than refusing the hook | An unknown hook field is dropped | Load the plugin on an older client and run a commit | **Not checked.** If it refuses, item 1 needs a declared minimum first |
| A plugin style is selected by `keel:keel terse` | The `/output-style` listing names it that way | `claude -p "/output-style"` on 2.1.312 | **Checked 2026-10-29**, listing only. Setting it in a settings file was not tried |
| A cross-marketplace dependency installs | `marketplace.json` lists the target in `allowCrossMarketplaceDependenciesOn` | Plugin dependencies docs: without it, a `plugin.json` dependency "install completes without the dependency and your plugin then fails to load" | **Checked against the docs.** Not probed |
| `claude plugin validate` runs in CI without signing in | It reads files only | Run it on a runner with no credentials | **Not checked** |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| `maxTurns` on `keel-fanout` was dropped on purpose, not missed | `docs/plans/2026-10-13-harness-held-dispatch-guarantees.md:95`: "a turn cap ends a read silently" | The 2026-10-29 assessment listed it as a gap. It is not one, and it is not an item here |
| `AGENTS.md` is not read twice beside `CLAUDE.md` | Memory docs: by default Claude reads `AGENTS.md` "only when you have no `CLAUDE.md` in your working directory or above it" | The dual write ADR-0004 describes costs no context on Claude Code. Nothing to change |
| Every skill uses only `name`, `description` and `allowed-tools` | `skills/*/SKILL.md` frontmatter | `allowed-tools` pre-approves tools and does not restrict them, per the skills docs. No skill text was found relying on it as a restriction |
| The Claude capability rows stop at 2.1.302 | `lib/harness/capabilities:99-113` | Items 1 and 2 each add a row, and the version column is where a minimum would first show |
| The guard's wiring has no failure policy | `hooks/hooks.json:42-53` | Item 1 is one key on one entry |

## Open questions

All four answered by Bernard on 2026-10-29.

1. **Should keel's load depend on third-party plugins?** With `dependencies`, a missing or refused
   dependency stops keel loading. Today a missing one costs a `keel doctor` warning. The default
   offered was no, keep `enabledPlugins`. **Answer: yes, declare dependencies.** The accepted
   cost: a required plugin that cannot install now stops keel loading, where before it was a
   warning.
2. **Should `keel init` write `"outputStyle": "keel:keel terse"`?** It saves the 56 tokens decision
   10 counts, but it writes a user-visible setting the hook does not need, and the style name has
   a space in it that a rename would break. The default offered was to record the observation
   only. **Answer: record it, and have `keel init` write it.** The style keeps its name, so a
   future rename has to migrate the setting.
3. **What does `claude plugin validate` cost in CI?** It needs the Claude Code CLI on the runner.
   **Answer: add it only if it runs without credentials; otherwise record why and drop it.**
4. **What minimum Claude Code version does keel declare?** Item 1 forces the question. **Answer:
   2.1.295, stated in `README.md` and checked by `keel doctor`.**

## Recommendation

Build something smaller: land the `EXIT` trap, then add `onFailure: "block"` to `sensitive-guard`
behind a declared 2.1.295 minimum that `keel doctor` checks, record the output-style observation
and have `keel init` write the style, declare the required plugins as `dependencies`, add `plugin
validate` to CI if it runs unsigned, and correct the two docs. Do not build `if`, `userConfig` or
workflows, and build skill arguments when someone first needs them. Next is `write-plan` for those
items.

## Not decided here

How `keel doctor` checks the Claude Code version, where the minimum is stated, the wording of the
capability rows, and whether item 1 needs its own probe in `docs/harness-support.md` before it
lands. Those belong to the plan.
