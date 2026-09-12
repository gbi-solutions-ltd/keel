# ADR-0004: A repository may serve several harnesses, and a guarantee belongs to the pair

| | |
|---|---|
| Status | accepted |
| Date | 2026-09-05 |
| Deciders | Bernard Tebandeke, accepted 2026-09-05 |
| Requirements | none written; driver is `docs/ideas/keel-on-codex.md` as amended 2026-09-05 |
| Supersedes | none |

## Context

Once a second harness is supported, `keel init` has to know which one it is configuring. The
question that decides the shape is not "how does it detect", it is **whether a repository has one
harness or several.**

The real case answers it. A team where some developers use Claude Code and some use Codex CLI works
on one repository. Under a switch, that repository's configuration is whatever the last person to
run `keel init` chose, and the two of them take turns undoing each other. keel already accepts this
in one place: `keel init` dual-writes the same managed block to `CLAUDE.md` and `AGENTS.md`
(`bin/keel:927-928`) precisely because both readers exist at once.

So it is a set. And a set produces a fact this repository has never had to state before:
`.keel/profile.json` declares `hard_block_paths`, and that declaration is enforced for the people
using Claude Code and not enforced for the people using Codex, **in the same repository, on the same
commits, at the same time.** There is no longer any sentence about a repository's enforcement that
is true for everyone working in it.

The dominant force is the same one as ADR-0003: nobody may hold a belief about a gate that the code
does not deliver. Here it arrives at repository level rather than document level, and it is worse,
because a repository-level belief feels like a property of the code.

## Decision

`.keel/profile.json` gains `harnesses`, an array, bumping `SCHEMA_VERSION` from 2 to 3. `keel init`
detects what is present and confirms it; `--harness` overrides. Every guarantee keel makes is a
property of the pair `(repository, harness)` and is never stated for a repository alone. `keel
doctor` answers for the harness it is running under, and separately names the other harnesses the
repository serves and what they do not get. A repository that declares `hard_block_paths` while
serving a harness without `pretooluse_ask` gets a standing warning at `init` and on every `doctor`
run.

## Alternatives considered

### A: One harness per repository, chosen at `init`

`profile.harness` is a string. Simplest to implement, simplest to explain, and every existing
repository-level sentence stays true as written.

It loses on the case that motivated the work. A mixed team is the reason a second harness is worth
supporting at all, and a switch serves that team worst: the configuration becomes contested state,
and the losing developer silently gets no keel rather than reduced keel. It also contradicts the
dual-write already in the tree, which would have to be undone.

### B: A set, with the repository's guarantee defined as the intersection

Support several harnesses, and define the repository's enforcement as what *all* of its harnesses
deliver. This keeps a single true repository-level sentence, which is genuinely attractive.

It loses because it degrades Tier A to pay for honesty. Under the intersection rule, adding Codex to
a repository removes the hard block from the Claude Code developers who had it, which is a
regression on a harness that did nothing wrong, and it violates the stated Tier A requirement that
nothing regresses. Honesty about a difference is cheaper than deleting the difference.

**Why the chosen option won.** It is the only one that serves the mixed team without either
contesting the configuration or taking a working gate away from people who have it. The cost it
accepts, that no repository-level sentence about enforcement is true any more, is paid in warnings
and in `keel doctor` answering from the machine in front of the person rather than from a document.

## Consequences

**What becomes easier.** A mixed team is served without anyone choosing. Adding a harness to a
repository is additive and takes nothing away. `keel doctor` becomes the authoritative answer to
"what do I actually have", which is where a person already looks.

**What becomes harder.** `hard_block_paths` acquires a conditional meaning it did not have, and the
documentation for it has to carry that. `keel doctor` output grows a section. Every existing
repository-level claim about enforcement has to be re-read and qualified, which is most of the
nineteen documents this design touches.

**What this forecloses.** Any future statement of the form "a keel repository enforces X". That
sentence is now unwritable, and the checks in ADR-0003 will refuse it.

**What must be true for this to keep working.** That the running harness can be identified reliably
at runtime. **This condition is met, and was checked rather than assumed.** `CLAUDE_PLUGIN_ROOT` is
**not** a discriminator: Codex sets it deliberately for compatibility
(`codex-rs/hooks/src/engine/discovery.rs:266-269`). Two Codex-only signals do discriminate: the
`turn_id` field in a hook's stdin payload (`codex-rs/hooks/src/schema.rs:275-295`) and the
`CODEX_VERSION` environment variable in any shell command Codex's exec tool runs
(`codex-rs/core/src/exec_env.rs:40-49`). Section 10.7 of the design carries the detail and the one
gap: neither signal is present when a human runs `keel doctor` in an ordinary terminal beside a
Codex session, where detection returns `unknown` and `doctor` reports against every harness in
`profile.harnesses` rather than guessing one.

That degradation over-reports what is missing rather than under-reporting it, so it does not
threaten this decision. What would threaten it is a future harness with no reliable signal at all:
there `--harness` becomes mandatory rather than an override, and this ADR should be revisited.

## Verification

Holding if: `keel doctor` in a dual-harness repository names both harnesses and the gates each
lacks; a repository declaring `hard_block_paths` alongside a harness without `pretooluse_ask` warns
every run rather than once; and no document states an enforcement guarantee without naming a
harness.

Not holding if the warning becomes something people learn to ignore. A standing warning that fires
on every run in a common configuration decays into noise, and if that happens the answer is to make
the configuration less common, not to make the warning quieter.
