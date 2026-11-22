# Large ports: waves, agents and gating at scale

Read this when a conversion is too big for one session: roughly more than 20 pages, or more than a
few hundred gate cases. It applies to every stack. Proven on one Vue port of about 100 pages, 613
screens and 1,956 gate captures, in a slice and six waves, with parallel agents per area.

## Before the first wave

- **Freeze the mockup.** The sign-off already froze it by hash ([signoff.md](../../mockup/references/signoff.md)); for a
  large port also take a frozen copy, `signoff.mjs --freeze <dir>` (the frozen files, the contract
  and the record, without tool caches, never written over). Run every tool on that copy, and
  never change it; `check-config.mjs <copy> --ready-to-port` proves it is still the signed-off one. A design fix found later goes to the live mockup separately, with the user's OK;
  then prove the app against both (see Design defects).
- **A vertical slice first**, in the main session: sign-in, the shell, one data page, to 0% and
  Done when. Correct the stack reference from what it teaches before fanning out.
- **Plan the waves** in a written plan: areas, screen counts, wave order, owners.

## Seams that let agents work without touching each other

Built by the main session before any agent starts:

- **Shared foundations with tests**: the components every area needs (a record sheet, a summary
  bar, a stepper) and any folder moves. Agents start from a settled base.
- **One mock module and one route file per area**, already wired: each area's handlers in
  `mocks/areas/<area>.ts` (concatenated by `createHandlers`), each area's routes in
  `router/routes/<area>.ts` (spread before the catch-all), and an empty `reset<Area>Store()`
  already called in the shared test teardown. Agents fill their own files and never edit setup.
- **Shared endpoints fall through.** When several areas serve one endpoint (an audit-events read, a
  lookup), each area's handler returns nothing for entity types it does not own, and a last
  catch-all answers the rest with an empty result. Handler order matters: a gating flow's handlers
  go first.
- **One id source per mock entity, one module for reference data.** When two areas read the same
  reference data, move it into one shared mock module at once; an entity given two ids in two
  places breaks matching. Map mockup identifiers to contract identifiers in one idempotent adapter
  every area uses.

## Waves and ownership

- **Each shared component family is proven on a pilot page in the first wave**, at 0%, before any
  other area uses it. Later waves only extend it. A shared component no pilot draws moves to the
  wave with the first page that draws it.
- **Areas that share components go in different waves**, the first owning the components.
- **One owner per shared component**, not only per area. Pages of one area that draw another area's
  shared component go to that component's owner.
- **Split by endpoint owner, not only by menu.** A page goes to the agent that owns the endpoint it
  reads.
- **Each agent owns a written file list** and reports, never makes, any change outside it ("Outside
  changes needed": a route meta field, a shared component's prop, a setup reset).
- **Each agent runs its own dev server on its own port** (5174, 5175, ...), so it never gates
  against another agent's edits or the user's server.

## The agent brief

A common brief every agent reads, plus an area brief. The common brief holds:

- the stack reference, this file, and the previous wave's notes (known DOM oracle difference kinds,
  the shared pieces);
- the file list it owns, and that work outside it is reported, not done;
- **no local workarounds around shared code**: no casts around a narrow prop, no page-local copy
  of a shared component, no focus workaround on one page. Report the need instead;
- every layer is allowed (a brief limited to composites and domain forced primitives into the wrong
  layer); a component that draws a domain component is domain;
- the commands to gate its screens, and to report per case the visual diff result and the DOM
  oracle's diff and edge line counts;
- **its full report as its final message**, as text. A sub-agent's file writes may be refused, and
  its scratch folder is cleared; the main session saves the report.

## Closing a wave

1. **Merge.** A merge agent, or the main session, applies every "Outside changes needed" as a
   numbered list, replaces page-local stand-ins with the shared fix, removes casts, and dedupes
   copies (three copies of one helper become one).
2. **Checks**: typecheck, lint, the full test suite, a dash grep. Run the suite only once agents
   have stopped: a run while one is editing gives false failures.
3. **A smoke shard** of only the screens the merge touched, then the merged gate over every ported
   screen so far, on the dev server.
4. **The DOM oracle against the previous merged run, case by case** (`dom-oracle.mjs --reference
   <previous report>`): list "worse than reference" (a changed difference at the same line count
   included) and "better than reference", each with its cause. No case may get worse. The match count alone
   hides regressions.
5. **Prune the expected-diffs file**: a run with `--expected` lists the entries it did not need;
   measure every entry again, drop the entries now at or under
   the limit, treat 0.01 points as noise, keep a copy of the file per wave.
6. **Wave notes**, in the repo (below), and the open questions to the user.

The production build gate and the quality check run at milestone waves and at the end, not every
wave.

## Gating at scale

- **Run shards one after another, not in parallel, on a loaded machine** (`SEQUENTIAL=1 zsh
  gate-sharded.sh`; `APP=<url>` adds the app diff, `QUALITY_SHARDS=N` the quality check). Under a load average of
  13 to 18 captures time out; ten shards in sequence finished 1,808 captures with none. Do not run
  the test suite while a gate or the oracle runs. `gate-sharded.sh` exits 2 on a shard count that is
  not a non-negative integer, when no phase is enabled, or on an `OUT` the out-folder guard refuses;
  otherwise it exits with the highest code a merge returned (a 2 is never folded into 1), and prints
  the failing behaviours rows. `QUALITY_ARGS`' `--warnings` also reaches the quality merge, which
  writes the report.
- **A test that fails in the full run and passes alone is load**; rerun it alone, then in an idle
  full run, before calling it a failure. One that fails alone is real. Report both.
- **The app and quality merges state "N of N planned captures measured, not measured: 0"**, with
  each failure's shard log and cause. Without that line a dead shard reads as a pass. `merge-shards.mjs
  app` and `quality` print it and fail (exit 1) when anything was not measured; the app merge with
  nothing planned cannot run (exit 2).
- **Run gate servers on ports other than the defaults** and build the mocked build into its own
  folder (`dist-mocked`), so the production `dist` stays clean for the fixture grep and a mocked
  build cannot be deployed by mistake.

## Named failures

A case that cannot reach its threshold is a named failure with a measured cause, never a raised
threshold:

- **The mockup itself is unstable**: a page that grows after a focus call has scrolled (a log
  filling in, a late font), or a row drawn short for one frame that clamps the scroll. Measure it
  (heights before and after, scroll offsets) and name it. Never copy the glitch.
- **Overlay screens amplify their base screen**: a tour popover or a menu anchored to a card that is
  a little taller moves, or flips above its anchor. A base case at 0.5 to 6% becomes 5 to 15%. Plan
  them as named failures with the base case.
- **A screen that does not run the behaviour in its name proves nothing**: an "autostart" screen
  with no steps equals the plain screen. Add a case that can fail without the behaviour.

## Design defects found by the port

Fix it in the port, record the pixel change as an expected difference, and report it to design.
Change the live mockup only with the user's OK and a backup; never the frozen copy. Then prove the
app both ways: against the frozen copy and against the updated mockup.

## Records

Everything an agent or the main session produces lands in the repo: reports in `docs/`, generator
scripts in `scripts/`, each wave's gate config and expected-diffs copy in `gate/`. Session scratch
folders are cleared, and a summary citing a scratch path stops resolving.

**Wave notes**, one per wave, same headings: Before the fan-out; What it built; Merge (numbered);
Checks; Gate results; Decisions; Deviations the gate cannot see; Contract gaps; Open for later
waves; Gate config for the next wave.

**Running unattended**: one numbered decision log across every wave. Each decision is marked
reversible or not, cites the expected-diffs entry where the gate sees it and the backend ask where
there is one. Open items go to an "Open for the user" list; the user's answers are appended as
further numbered decisions, followed by "Applying the answers".
