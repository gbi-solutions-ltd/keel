# ADR-0015: sensitive-guard keeps a Codex refusal, and Codex users are pointed at v0.26.0

| | |
|---|---|
| Status | proposed |
| Date | 2026-10-30 |
| Deciders | Bernard Tebandeke, decisions of 2026-10-30; this record awaits acceptance |
| Requirements | None written. Driver is [`docs/architecture/claude-code-only.md`](../architecture/claude-code-only.md), section 7 |
| Amends | [ADR-0013](ADR-0013-claude-code-is-the-only-harness.md) |

## Context

ADR-0013 removes Codex support from this repository. Its Consequences say `sensitive-guard` loses
its exit 2 branch, and its Verification says no file names Codex outside history.

A probe on `codex-cli 0.153.4` showed that Codex still loads keel's hooks from `hooks/hooks.json`
with no `.codex-plugin/` present, so `sensitive-guard` still runs there. Codex discards the `ask`
decision, and `ask` is the only decision this gate makes. Exiting 0 on Codex leaves a repository
that declared `hard_block_paths` believing it has a gate it does not have, which is the one outcome
the hook's header says a gate must never have.

Two signals mark a Codex hook process: `CODEX_VERSION` in the environment, which the probe did not
see in a `SessionStart` hook, and a `turn_id` key, which Codex's schema requires on `PreToolUse`
input. Claude Code's `MessageDisplay` input already carries `turn_id`, so either signal alone could
one day read a Claude Code session as Codex. Claude Code exports `CLAUDE_PROJECT_DIR` to hook
processes and Codex has no such variable.

**The dominant force is that a gate a repository declared must never pass in silence.**

## Decision

We keep one Codex refusal in `sensitive-guard`, detecting Codex by `CODEX_VERSION` or a `turn_id`
key only when `CLAUDE_PROJECT_DIR` is empty, and we name v0.26.0 wherever Codex users are told how
to continue. These are Bernard's decisions of 2026-10-30. ADR-0013's Consequences and Verification
clauses are amended by this record on these two points and stand as written on every other.

The refusal exits 2 with a message on stderr naming keel v0.26.0 as the last keel release that
supports Codex and the line that installs it. It fires only on a command that looks like a commit,
in a repository whose parsed profile declares a non-empty top-level `hard_block_paths` or will not
parse, so a repository declaring nothing is never blocked on a machine with python3. Without python3
the list cannot be parsed, and an unparsed declaration counts as declared: on Codex the refusal then
fires for any profile naming `hard_block_paths`, even an empty list, rather than the ask Codex
discards.

## Alternatives considered

### A: Remove the refusal, as ADR-0013 says

The hook exits 0 or asks on Codex, and Codex discards the ask. A repository that declared sensitive
paths gets no enforcement and no word that it has none.

### B: Detect Codex by one signal

`CODEX_VERSION` alone misses a hook process that does not inherit it, which is what the probe saw.
`turn_id` alone hard-blocks Claude Code if its `PreToolUse` input gains the key that its
`MessageDisplay` input already has.

**Why the chosen option won.** It is the only option where a declared gate on Codex either stops
the commit or says why it cannot, and no Claude Code session is read as Codex.

## Consequences

**What becomes easier.** A Codex user in a repository declaring sensitive paths learns at the first
commit that keel no longer serves Codex, and how to install the release that does.

**What becomes harder.** `hooks/sensitive-guard` and the documents that tell Codex users how to
continue name Codex outside history, so ADR-0013's Verification check reads those as allowed.

**What must be true for this to keep working.** That Claude Code keeps exporting
`CLAUDE_PROJECT_DIR` to hook processes, and that Codex keeps running `hooks/hooks.json`. If Codex
stops loading keel's hooks, the refusal is dead code and can go.

## Verification

Holding if: `tests/test-sensitive-guard.sh` shows the refusal exiting 2 on either signal with
`CLAUDE_PROJECT_DIR` empty, including with python3 absent, the ask and exit 0 with it set, and
silence in a repository whose top-level list is empty; and every Codex-facing instruction outside history names v0.26.0.

Not holding if a Claude Code session ever gets the refusal, or a repository declaring nothing is
ever blocked on a machine with python3.
