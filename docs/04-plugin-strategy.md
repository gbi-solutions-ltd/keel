# Third-Party Plugin Strategy

All nine plugins you named exist in the official Anthropic marketplace, which is already
registered on this machine (`claude-plugins-official`). Currently only `superpowers@6.2.0`
is installed. Everything below is available immediately.

## Verdicts

| Plugin | Marketplace id | Verdict | Why |
|--------|---------------|---------|-----|
| Security Guidance | `security-guidance` | **Install, required** | The single highest-value one. Hook-based, so it runs without being asked |
| Code Review | `code-review` | **Install, required** | Multi-agent review with confidence scoring, better than one inline pass |
| Skill Creator | `skill-creator` | **Install, required** | Real eval and benchmark scripts. We should not rebuild this |
| Context7 | `context7` (external) | **Install, recommended** | Current library docs. Prevents recommending APIs that no longer exist |
| CLAUDE.md Management | `claude-md-management` | **Install, recommended** | Directly serves requirement 14 |
| Language server | one per language, see below | **Install per stack** | Real diagnostics beat grep. Largest accuracy gain on refactors |
| Frontend Design | `frontend-design` | **Conditional** | Only where there is a UI |
| Playwright | `playwright` (external) | **Conditional** | Only where there are browser flows worth testing |
| FeatureDev | `feature-dev` | **Do not install by default** | See below. It conflicts with our pipeline |

### Language servers, per detected language

`keel init` enables one per language it detects, and a polyglot repository gets several. Every id is
checked against `claude-plugins-official`; a language absent from this table gets no server, which
is the honest answer rather than a plausible id that fails to resolve.

| Language | Plugin |
|---|---|
| TypeScript, JavaScript | `typescript-lsp` |
| Python | `pyright-lsp` |
| Go | `gopls-lsp` |
| PHP | `php-lsp` |
| Java | `jdtls-lsp` |
| Kotlin | `kotlin-lsp` |
| Rust | `rust-analyzer-lsp` |
| C# | `csharp-lsp` |
| Ruby | `ruby-lsp` |
| Swift | `swift-lsp` |
| C, C++ | `clangd-lsp` |
| Lua | `lua-lsp` |

### Why FeatureDev is the exception

`feature-dev` ships its own end-to-end workflow: a `code-explorer` agent, a `code-architect`
agent, a `code-reviewer` agent, and a `/feature-dev` command that drives them. That is the
same territory as `repo-snapshot`, `design-architecture`, `write-plan`, `execute-plan`, and
`review-code`.

Two competing workflows in one session is worse than either alone. The model picks one
arbitrarily, and the artifact chain breaks because `feature-dev` does not write to
`docs/keel/`. So: not installed by default, and `keel doctor` warns if it is present
alongside keel.

The counter-argument is worth stating. If in the pilot our pipeline turns out to be heavier
than `feature-dev` for small changes, the right move is to drop several of our skills and
adopt theirs, not to run both. Worth re-testing after the pilot.

## How skills call plugins

The pattern, used identically in every skill that has a plugin dependency:

```markdown
## Plugin: code-review

If the `code-review` plugin is installed, invoke `/code-review` and use its findings as
the correctness pass, then add the GBi-specific checks below. If it is not installed,
tell the user:

> The `code-review` plugin gives a multi-agent review with confidence scoring, which
> catches more than a single pass. Install it with
> `/plugin install code-review@claude-plugins-official`. Continuing with the inline
> review for now.

Then run the inline rubric.
```

Three properties this gives us:

1. **Never a hard failure.** A missing plugin degrades the skill, it does not break it.
2. **The user learns why**, at the moment it matters, not from a setup doc they skimmed.
3. **`keel init` front-runs this.** It detects the stack, recommends the right set, and
   writes them into `.claude/settings.json` so the prompt rarely appears.

## Wiring map

| keel skill | Plugin it calls | What it delegates |
|-----------------|-----------------|-------------------|
| `review-code` | `code-review` | The correctness pass |
| `security-audit` | `security-guidance`, plus built-in `/security-review` | Diff-level vulnerability detection |
| `create-skill` | `skill-creator` | Eval harness, variance benchmarking, packaging |
| `context-budget` | `claude-md-management` | CLAUDE.md quality rubric |
| `design-architecture` | `context7` | Current library versions and API surface |
| `coding-standards` | `context7` | Current lint and framework conventions |
| `debug` | stack LSP | Diagnostics, go-to-definition, find-references instead of grep |
| `refactor` | stack LSP | Safe renames, reference completeness |
| `write-docs` | `frontend-design` | UI component documentation, where a UI exists |
| `execute-plan` | `playwright` | Browser verification of UI tasks |

## `.claude/settings.json` that `keel init` writes

Example for a TypeScript service with a UI:

```jsonc
{
  "enabledPlugins": {
    "keel@gbi": true,
    "security-guidance@claude-plugins-official": true,
    "code-review@claude-plugins-official": true,
    "skill-creator@claude-plugins-official": true,
    "claude-md-management@claude-plugins-official": true,
    "context7@claude-plugins-official": true,
    "typescript-lsp@claude-plugins-official": true,
    "frontend-design@claude-plugins-official": true,
    "playwright@claude-plugins-official": true
  }
}
```

Committing this means a teammate who runs `/plugin` sees the project's expected set already
listed, and installing is one confirmation.

**No `extraKnownMarketplaces`, deliberately.** A marketplace source says where a particular
reader gets keel from, which is a fact about their machine rather than about the project. A
committed declaration asserts one answer for everyone who clones: a reader outside the GitHub
org cannot reach a private repo, and at project scope the declaration shadows whatever that
reader chose at user level. Every `@claude-plugins-official` entry above is enabled without a
declaration and resolves fine, because the marketplace is known at user level; `gbi` is no
different. Adding the marketplace is a one-time per-machine step, and both `keel doctor` and the
nudge hook name the command when it is missing.

## What about superpowers

You already have it installed. Once keel exists there is meaningful overlap:
`tdd`, `debug`, `write-plan`, `execute-plan`, and `create-skill` are all adapted from it.

Running both means two `SessionStart` injections and two competing methodologies, and
superpowers' `using-superpowers` skill instructs the model to invoke superpowers skills
before any response, which will fight our router.

**Recommendation: uninstall superpowers once keel Phase 3 lands.** We keep the parts
that are good, we drop the parts that do not fit GBi, and we stop paying for two bootstraps.
Until then, keep it, since it is currently doing useful work.

Credit where due: superpowers is MIT licensed and our adapted skills should say so in a
`SOURCES.md` at the repo root.

## Boundaries, and why they are reported rather than enforced

Everything above is a judgement made once, in this document, about the plugins we had met by the
time it was written. That does not survive contact with a marketplace: the plugin that collides with
keel next year has not been published yet.

So `keel doctor` checks two things, and only the first depends on this document being current.

**A registry of known competing methodologies.** `feature-dev`, `superpowers`, and `gstack`, each
with the reason rather than a label, because "conflicts" tells a reader nothing they can act on.

**Any plugin shipping a skill name keel also ships**, found by reading the installed plugin
cache rather than a list. This needs no foresight. If somebody installs a plugin with its own `tdd`
or `review-code`, it surfaces the next time doctor runs.

The second is worth more than it looks, because the failure is silent. Two skills under one name is
not an error in Claude Code: the model resolves the name to one of them and nothing records which.
The symptom is a skill that behaves inconsistently between sessions, which reads as the skill being
unreliable rather than as two plugins fighting, and it can burn an afternoon.

**Neither disables anything.** Three reasons, and the third is the one that decided it:

1. A conflicting plugin may be the deliberate choice. Doc 04 says `feature-dev` might turn out to be
   better than our pipeline for small changes, and the pilot exists to find that out.
2. Writing `"feature-dev@...": false` into the committed `.claude/settings.json` imposes it on every
   teammate who clones, which is the same objection that keeps the permission mode out of that file.
3. A tool that silently turns off somebody's plugins is a tool nobody trusts with anything else.

What `keel init` does write is one line of precedence into the managed CLAUDE.md block, so a session
with both loaded has an answer rather than picking arbitrarily. Naming the winner is cheap. Removing
the loser is not ours to do.

## Plugins worth a look that you did not name

Skimmed from the same marketplace, only the ones that would actually earn their place:

| Plugin | Why it might matter to GBi |
|--------|---------------------------|
| `pr-review-toolkit` | Broader than `code-review`, worth comparing in the pilot |
| `code-simplifier` | Directly serves the Simplicity First principle |
| `hookify` | Turns repeated corrections into hooks, complements `create-skill` |
| `commit-commands` | Conventional commit enforcement, cheaper than a skill |
| `terraform`, `gitlab`, `github` | Only if they match your actual infra and forge |

Not recommending any of these yet. Flagging them so the pilot can evaluate one or two.
