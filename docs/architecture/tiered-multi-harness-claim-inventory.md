# Claim inventory: sentences that stop being true under multi-harness support

| | |
|---|---|
| Status | draft, planning input |
| Date | 2026-09-05 |
| For | [`tiered-multi-harness-support.md`](tiered-multi-harness-support.md) section 10.5, ADR-0003 |
| Tree | line numbers resolved against `e56b2ca` plus this turn's edits to `docs/01-architecture.md` |

Every row below was re-resolved against the working tree on 2026-09-05, after the edits made to
`docs/01-architecture.md` this turn shifted its line numbers. **Do not reuse the line numbers in
`docs/ideas/keel-on-codex.md` Part 4 for that file; they predate those edits.**

Remedy classes:

| Class | Means | Test that will police it |
|---|---|---|
| **W** word change | The sentence stays and gains a harness qualifier | Tagged claim, checked against the manifest |
| **A** asterisk | The sentence is true as written for Claude Code and needs a pointer, usually because it is a historical decision record that should not be rewritten | Tagged claim plus a link to `docs/harness-support.md` |
| **N** new section | No multi-harness content exists at the location at all; prose has to be written, not edited | Vocabulary scan, which fails on gate words in an untagged sentence |

## The inventory

| # | Location | The claim | Class |
|---|---|---|---|
| 1 | `README.md:16` | "That is the whole install." Describes Claude Code's plugin and PATH mechanism as the install | **N** + W |
| 2 | `README.md:82-84` | The `keel terse` output style, "selectable in `/config`". No Codex counterpart was found; `bin/keel` never references `output-styles/` | **W** |
| 3 | `README.md`, the paragraph opening "Bypassing prompts is bounded" | The headline safety claim: `deny` and `ask` rules in `.claude/settings.json` "both kinds still apply under `bypassPermissions`" | **W**, highest value in the list |
| 4 | `docs/01-architecture.md:22-23` | Layer 1 as "hooks in `.claude/settings.json`" | **W**, done this turn |
| 5 | `docs/01-architecture.md:165` | "Where a rule is genuinely non-negotiable, we put it in a hook" | **W**, done this turn |
| 6 | `docs/01-architecture.md:167-172` | The enforcement table. Every row names a Claude Code mechanism | **W**, table gains a harness column. Not yet done |
| 7 | `docs/07-open-decisions.md:173-175` | Decision 3: `security-audit` on a sensitive diff "should be hard blocked at the hook level" | **A** |
| 8 | `docs/07-open-decisions.md:206-210` | "`ask` is the only decision in the hook protocol the model cannot satisfy for itself... and it survives `bypassPermissions`" | **A** |
| 9 | `docs/03-install-and-distribution.md` | The install code block: `/plugin marketplace add`, `/plugin install`, "installs 25 skills, the SessionStart hooks, and bin/keel on the Bash tool's PATH" | **N** |
| 10 | `docs/03-install-and-distribution.md:30` | "writes `.claude/settings.json` with recommended plugins and hooks" | **W** |
| 11 | `docs/03-install-and-distribution.md:175-181` | `CLAUDE_PLUGIN_ROOT` "is set only for hooks a plugin itself defines", plus thirteen other `CLAUDE_*` variables | **W**, and this is where the Codex compatibility fact belongs: Codex sets `CLAUDE_PLUGIN_ROOT` too (`codex-rs/hooks/src/engine/discovery.rs:266-269`), so this passage is now actively misleading rather than merely partial |
| 12 | `docs/profile-keys.md:51` | `gates.done_verified` "Drives hooks/done-guard on Stop and SubagentStop" | **W** |
| 13 | `docs/profile-keys.md:56` | `hard_block_paths` "Enforced by hooks/sensitive-guard, which asks a human before a commit touching one" | **A**, and the most consequential row here: this is the key whose meaning becomes conditional on the harness |
| 14 | `docs/02-skill-catalog.md:65` | Requirement 5 satisfied by "`security-audit` + `security-guidance` plugin hooks + `ship` gate" | **W** |
| 15 | `docs/02-skill-catalog.md:383` | `security-audit`'s plugin calls: `security-guidance` hooks and the built-in `/security-review` | **W**, and it moves with "Step 5: Plugin and gate" in `skills/security-audit/SKILL.md` or `tests/validate-skills.sh:390-463` fails |
| 16 | `docs/02-skill-catalog.md:536` | `context-budget` "Reads: `CLAUDE.md`, `.claude/settings.json`, `.keel/`, skill sizes" | **W** |
| 17 | `docs/02-skill-catalog.md:568` | `context-budget`'s plugin call to `claude-md-management` | **W** |
| 18 | `docs/04-plugin-strategy.md:11` | `security-guidance` as "Install, required... Hook-based, so it runs without being asked" | **A**, and see the note below: the whole document is Claude-marketplace-shaped |

## Three things the count of eighteen hides

**1. A nineteenth location, and it is the one already owed.**
`docs/03-install-and-distribution.md:475` is the portability paragraph that says "The skills
themselves stay Claude-only for now; porting them is a later decision, not a Phase 1 one." That
sentence is not false today; it becomes false the moment this design ships, and it was already
carrying an unpaid follow-up from the idea record. It is class **N** and it is the natural home for
the Tier B install path.

**2. `docs/04-plugin-strategy.md` is not one sentence, it is 221 lines.**
Row 18 marks line 11, but the document's subject is the Claude Code plugin marketplace end to end.
Treating it as a word change will produce a document that is locally qualified and globally wrong.
Plan it as a section-level rewrite with a stated scope line, not as row 18.

**3. Five locations need prose, not edits.**
Rows 1, 9 and the nineteenth above, plus `docs/04-plugin-strategy.md` and `docs/05-token-and-memory-design.md`.
The last has no row of its own because no single sentence in it is false: its 44-tokens-per-description
and 1,320-token ceiling were derived against Claude Code's preload mechanism, and Codex budgets a
share of the context window instead, shortening or dropping descriptions under pressure. The whole
derivation needs a Codex counterpart or an explicit statement that it is Claude-only. A claim scan
will not find this one, because it is arithmetic rather than a sentence, which is the argument for
reading the document rather than trusting the list.

## Not in this inventory, on purpose

`docs/ideas/*.md` and `docs/plans/*.md` are historical records. They state what was believed on a
date and should not be rewritten to match a later decision, which is the same rule ADRs follow. If
the vocabulary scan flags them, the scan's scope is wrong, not the documents.
