# Sign-off: the package a port is built from

Read this when the client is about to approve the mockup, and again whenever a signed-off mockup
changes. Sign-off turns a reviewed mockup into the input Convert builds from, the way keel's
`shape-idea` record is what `write-prd` builds from: nothing after it asks again what the package
answers, and nothing in it changes without a new round.

## What sign-off writes

| Record | Where | What it holds |
|---|---|---|
| The contract | `project.contract.location` in the mockup (default `api/openapi.yaml`) | the API the screens need, drafted from the mockup, or the backend's document vendored there. Every fixture it maps validates |
| The sign-off record | `<mockup>/docs/signoff.json`, written by `scripts/signoff.mjs` | each round: who signed off, the date, the screens and states, the viewports, the pins, the contract's path, version and hash, and a hash per file of the mockup (the freeze) |
| The sign-off page | `<docs_root>/mockups/<name>/signoff.md` (`signoff.mjs --docs`) | the same, for people; generated from the record, never edited |
| Decisions | `<docs_root>/mockups/<name>/decisions.md` | the design decisions made in review rounds, numbered (below) |

With the brief and the `project` block from the intake ([intake.md](intake.md)), the token and
component maps for a design framework ([design-frameworks.md](design-frameworks.md)),
`docs/behaviours.json` and the inventory, that is the package.

## Before signing off

1. The config lists at least one screen, and every check in [step-detail.md](step-detail.md) is clean on the mockup (inventory, quality,
   spill, behaviours, the baseline), each finding fixed or recorded. `signoff.mjs` records a
   sign-off; it does not judge one.
2. `check-config.mjs --ready-to-port` shows `ready to port (decisions only): yes`. A tier 2 answer
   may stay deferred with its owner, **except the contract**: it is drafted by now.
3. `pins.clock`, `pins.seed` and `timezoneId` are set, so every signed-off screen can be captured
   again exactly.
4. **The contract is drafted, or vendored into the mockup** (a location outside it is refused), per [api-integration.md](../../convert-mockup/references/api-integration.md), as OpenAPI 3.1 (a 3.0 document is refused), and says
   which fixtures stand for which schema: `x-mockup-fixture: invoices` on the `Invoice` schema
   checks each item of `FIXTURES.invoices`; an object fixture is checked as one value;
   `roles.*` checks every value of the `roles` map; a mapping whose fixture is empty is refused (it
   checks nothing). Fixtures are validated with Ajv 2020 and ajv-formats, as the sample backend
   does. Map every entity the API returns. A response
   assembled from several fixtures (a session with its role's permissions) cannot be mapped this
   way; the app's contract test covers it. Fixture keys no schema names are listed as warnings:
   right for a menu or a role table, wrong for API data.
5. The person who signs off has seen every screen, state, role and viewport in the config. Say so
   in the note when they saw a subset in a round.

Then:

```sh
node scripts/signoff.mjs <mockup> --by "<who signed off>" --docs <docs_root>/mockups/<name> \
  [--date YYYY-MM-DD] [--note "<what this round covered>"] [--freeze <dir>]
```

It refuses (exit 1), writing nothing, while the config lists no screen or any of 2 to
4 is open, and prints each reason; a `--date` that is not a real calendar date exits 2. On success it
appends round 1, prints the screens and files frozen, and warns about unmapped fixtures. Run again
on an unchanged mockup, it records no round ("unchanged since round N; no new round") but still
writes `--docs` and makes the `--freeze` copy.

## A mockup signed off before this record existed

`--ready-to-port` refuses a mockup with no `docs/signoff.json`, including one the client approved
before sign-off was recorded. Record that approval once, as it happened, before the next Convert:

1. Find who approved it and when (the brief, the review thread). Run the checks first: what is
   recorded must be what was approved, so a mockup changed since needs that change approved too.
2. Vendor the contract into the mockup if it lives elsewhere (an app's `api/openapi.yaml`): copy it
   to the mockup's `api/openapi.yaml`, mark its entity schemas with `x-mockup-fixture`, and set
   `project.contract`. From then on the mockup's copy is the source and the app imports it.
3. `signoff.mjs <mockup> --by "<who approved it>" --date <the approval's date> --note "recorded
   after the fact; approved <how>"`. That is round 1; later changes are rounds as usual.

A port already finished does not need it: the gate guards the next Convert, not a past one.

## After sign-off

- **The mockup is frozen by hash.** `check-config.mjs --ready-to-port` and `inventory.mjs
  --ready-to-port` print `signed off: yes, round N` while every frozen file and the contract are
  unchanged, and `not ready: signoff: <problem>` otherwise, naming the files; a config that lists no
  screen is never signed off. Dotfiles are frozen
  too (never `.git`, `.DS_Store`, `.tools`, `.mockup-engine`, `node_modules`); a round recorded
  before this (no `manifestVersion`) is verified under the old rule, which skipped them. The gate
  never reads markdown, only the record.
- **The config is frozen by its design part only**: screens (without app-side overrides such as
  `appName`), roles, viewports, modules, checklist, pins, zone, locale and the tier 1 answers,
  compared key by key. Answering a deferred tier 2 question at Convert, or tuning `diff`,
  `quality`, `spill` or `domOracle` during the port, is not a design change and needs no round.
- **A change after sign-off is a new round**, never an edit of the record: change the mockup, run
  the checks, have the change approved, run `signoff.mjs` again. The round lists what changed. A
  tier 1 answer that changes is also a change log row in the brief.
- **A contract change is its own kind**: when the backend amends the agreed contract, the gate says
  "contract changed", not "mockup changed". Agree it, check the fixtures still validate, sign it off
  as the next round with a note.
- **Large ports** run every tool on a frozen copy (`--freeze <dir>`: the frozen files, the contract
  and the record, never written over); [large-ports.md](../../convert-mockup/references/large-ports.md) has the rest.

Baseline PNGs are not frozen: they are renderer output, kept in `.mockup-engine/`, and rebuilt
from the pins on another machine. Keep one baseline per round (`.mockup-engine/baseline-round-N`):
a later round is compared against the previous round's, every case that changed is named in the
round's note, and the new round writes its own.

**Try the contract before signing.** Before the first sign-off, `check-config.mjs` prints the
contract's check on its own (`contract: <path> <version>: N fixture mappings, M problems`).
`signoff.mjs` also refuses a schema key that is not a schema keyword: an unquoted comma in a YAML
flow mapping turns the rest of a description into a key, and code generators refuse the document.

## decisions.md

The brief records the intake's answers; keel's `decisions/ADR-*` record architecture. Between them
sit the design decisions taken in review rounds: what a role may not see, why a flow has a confirm
step, a convention the client chose. Number them, and never renumber. No file is right when no round has decided anything yet (often at round 1):

```markdown
# Decisions: <app name>

| # | Date | Decision | Why | Decided by | Reversible | Affects |
|---|---|---|---|---|---|---|
| D-1 | 2026-11-20 | Auditors see amounts but never customer contact details | data minimisation; the auditor role does not need them | client product owner | yes, a permission | invoices, customers |
| D-2 | 2026-11-24 | Voiding an invoice asks for a reason, kept in the audit log | the finance team's audit rule | client finance lead | no, the API stores it | invoice detail, contract |
```

A decision that changes a signed-off screen is made in a round, so its row and the round's note cite
each other ("round 2: D-4"). Convert carries them into the conversion plan's assumptions and reads
"not reversible" as "the backend depends on it".
