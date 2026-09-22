# Idea: `doctor` answers one repository at a time, and the December programme needs a fleet

| | |
|---|---|
| Raised by | Bernard, 2026-09-19, "plan the work that makes keel enforceable outside the agent" |
| Status | shaped |
| Recommendation | Add `keel doctor --json`, then a small fan-out script over it. Judge this by whether it serves the gateways, not by elegance |
| Next | `write-plan`, as one increment of the outside-the-agent plan |

## The problem

`keel doctor` reports on one repository at a time. With five engineers across six repositories, the
question that matters is fleet-shaped: which repositories are on which schema version, which run an
old `keel_version`, which have a null `verify.test`, which fail their own verify commands. Nothing
answers that today; someone would have to run `doctor` six times and read six scrollbacks by eye.

## What it costs

**Evidence.** `cmd_doctor` (`bin/keel:1268`, ~430 lines) is entirely printf-driven: three closures
`fail()`/`warn()`/`good()` (`bin/keel:1253-1255`) print a line immediately and only increment
counters; nothing accumulates findings as data. Every check funnels through these three, including
the harness-plugin sections via `harness_section`, which itself reads lines already tagged
`fail|`/`warn|`/`ok|`. That consistent grammar is the exploit: a `--json` mode does not need every
call site touched. The cheapest approach captures `cmd_doctor`'s stdout, strips the interstitial
progress lines (e.g. `bin/keel:1579`, "verify.%s: running: ..."), and parses the remaining lines
into a JSON array, adding the fields the fleet script actually needs (`schema_version`,
`keel_version`, `verify.test` nullness) as their own top-level keys rather than re-parsed prose,
since those are already read via `json_get` (`bin/keel:1403-1404,1567-1568`).

Estimated medium, ~100-180 LOC given this repository's comment density, plus a `--json`
flag alongside the existing `--fast` (`bin/keel:1246`) and test coverage in `tests/test-keel.sh`.
The progress-printf lines need to move to stderr or be suppressed in `--json` mode; that is a design
decision to state explicitly, since silently swallowing "running: <slow command>" feedback changes
the experience of anyone piping `--json` while the full suite still runs underneath it.

The fan-out script is genuinely new (no fleet or multi-repo tooling exists anywhere in the tree
today) but small: a bash or python wrapper that shells `keel doctor --json` per repo path and
renders one table, blocked on `--json` landing first. Estimated small-medium, ~60-100 LOC.

## The constraint this must respect

ADR-0004 established that no guarantee belongs to a repository alone; it belongs to a
(repository, harness) pair. A fleet table that collapses "compliant: yes/no" per repository, without
a harness dimension, reintroduces exactly the false belief ADR-0004 was written to prevent. The
`--json` output and the fan-out table must carry `harnesses[]` (or per-harness gate status) rather
than a single flattened boolean.

## Recommendation

Build `doctor --json` first (self-contained, one repository, immediately useful on its own even
before any fan-out exists), then the fan-out script as a second, independently landable step. Share
the profile-loosening detection from `docs/ideas/profile-loosening-goes-unnoticed.md` through this
surface rather than building it twice: the pre-push hook blocks locally, `doctor --json` reports it
into the fleet view.

## Open questions

1. Where does the fan-out script live, and does it need its own repo list, or does it read one from
   somewhere (a config file, an argument list)? Not decided here.
2. Should `--json` output be versioned (a `schema_version`-style field on the JSON itself), given it
   will be consumed by a separate script that ships independently?
