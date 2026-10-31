# ADR-0013: Claude Code is keel's only harness, and other harnesses are served by ports

| | |
|---|---|
| Status | accepted, amended by ADR-0015 |
| Date | 2026-10-29 |
| Deciders | Bernard Tebandeke, accepted 2026-10-29 |
| Requirements | None written. Driver is the request recorded in [`docs/architecture/claude-code-only.md`](../architecture/claude-code-only.md) |
| Supersedes | [ADR-0004](ADR-0004-a-guarantee-belongs-to-a-repository-and-harness-pair.md), [ADR-0005](ADR-0005-one-skill-body-per-skill-across-harnesses.md) |

## Context

Since 2026-09-05 keel has served Claude Code at Tier A and Codex CLI at Tier B from one repository.
ADR-0004 made every guarantee a property of a (repository, harness) pair, and ADR-0005 kept one skill
body per skill, written in wording that reads correctly on both harnesses. Together they mean that
any Claude Code feature adopted here either has a Codex equivalent or is disclosed as a gap, and that
skill bodies cannot use Claude Code body syntax such as `` !`cmd` `` or `${CLAUDE_SKILL_DIR}` at all.

Two facts changed. A separate `keel-cursor` repository already serves Cursor by generating from a
pinned keel tag with its own rewrite rules, hooks and capability manifest, and keel has never needed
to know it exists. And an independent `keel-codex` port is planned on the same pattern. Codex support
here then serves nobody the port will not, while costing 8 Codex-only files, Codex branches in about
45 shared files and about 600 test assertions, and holding back every Claude Code feature behind the
question of what Codex lacks.

**The dominant force is that no decision in this repository is held back by another harness.**

## Decision

We remove Codex support from this repository entirely and make it a Claude Code plugin only. Skills,
agents, hooks and settings may use any Claude Code feature. Other harnesses are served by ports that
generate from a pinned keel tag and own their translation; this repository promises them its tags and
its CHANGELOG and nothing else. `keel init` stops writing `AGENTS.md`, and the release that removes
Codex names v0.26.0 as the last one with Codex support.

## Alternatives considered

### A: Keep Codex here at Tier B (do nothing)

Costs nothing now. Every future Claude Code feature keeps paying the two-harness tax: a capability
row for each harness, a disclosed gap, and neutral wording in skill bodies. With `keel-codex` planned,
it also means two Codex implementations to keep consistent.

### B: Claude-native, with a portable core for skill bodies

Remove Codex but keep ADR-0005's rule for skill bodies, with Claude-only features confined to
frontmatter, agents and hooks. Ports get bodies they can copy unchanged. It loses because body syntax
is exactly the feature class the request wants available, and the cost it saves lands on the ports,
which already rewrite bodies today (`keel-cursor`'s generator carries about 40 literal rewrite
rules).

### C: A shared skills repository with per-harness overlays

Skills move to their own repository and every plugin builds from it. It adds a repository, an overlay
format and a build step here, and puts Claude features in an overlay rather than in the skill, which
is the limitation the request names with more machinery around it.

**Why the chosen option won.** It is the only option where nothing in this repository is shaped by
another harness, and the precedent for the cost it moves onto the ports already works: `keel-cursor`
has been generating from a pinned tag since v0.25.0 without this repository knowing it exists.

## Consequences

**What becomes easier.** Adopting a Claude Code feature becomes one decision rather than two. Skill
bodies may use dynamic context, skill directory variables and any frontmatter field. `keel init` and
`keel doctor` lose the harness set, the `--harness` flag and the Codex trust parser. The test suite
loses about 600 Codex assertions. `sensitive-guard` loses its exit 2 branch.

**What becomes harder.** Every Claude-only feature adopted here is text a port must translate or
drop. `keel-cursor`'s generator passes unknown frontmatter through and treats a rule that no longer
matches as a warning, so today a port can ship untranslated text without noticing. Codex users have
no current release until `keel-codex` exists.

**What this forecloses.** A skill body that is correct on every harness by construction. Mixed teams
served by one plugin: a repository used from Claude Code and from Codex now needs both keel-claude
and keel-codex, each writing its own instruction file. ADR-0004's (repository, harness) statements
become one harness's statements again.

**What ADR-0005 leaves behind.** Its delegation profile mechanism stays, because it is how a skill
names `keel-fanout` and the Claude Code agent file already resolves it. Only the requirement that a
profile resolve on every harness, and that bodies stay harness-neutral, is superseded.

**What must be true for this to keep working.** That the ports keep up. If every keel release
leaves `keel-cursor` and `keel-codex` further behind, the cost this moved downstream is not being
paid, and either the ports need tooling or option B needs revisiting.

## Verification

Holding if: no file in this repository names Codex outside history (`CHANGELOG.md`, `docs/plans/`,
`docs/audits/`, superseded documents); `keel init` on a fresh repository writes no `AGENTS.md` and no
`.codex/`; and a Codex user following the README reaches the v0.26.0 tag.

Not holding if a Claude Code feature is declined here because of how a port would handle it, which
would be ADR-0005's rule returning without a decision.
