# Building into an existing repo

Read this when `project.target` is `existing-repo` (intake question 12): the app is a new area of,
or a replacement for part of, a repository the client already runs, with its own conventions, CI,
spec and change process. Convert then builds into that repo from the first file, to its
conventions, so nothing is built twice and translated later.

**Status.** The checks before Convert are built and tested on fixture repos (`check-config.mjs`,
`scripts/lib/target.mjs`). Building into a real client repo is not proven yet. Treat the sections
from Checks on as a checklist of decisions, and correct them after the first real run.

**Never change the client's repo without the user's go**, for each change: a target named in the
config is not approval to write to it.

## Before Convert: read the repo

1. **Snapshot it.** Run keel `repo-snapshot` on the repo, so its layout, stack, CI and debt are
   written down (`<docs_root>/snapshot.md`, the repo's own `docs_root` from its
   `.keel/profile.json`). The engine does not do that skill's work.
2. **Its standards.** When the repo has `<docs_root>/standards.md`, it binds the port; run keel
   `coding-standards` in assess mode to see where the repo already departs from it. Without one,
   Convert Step 5 seeds it from the repo, never from the engine's defaults.
3. **Check it against the package.** `check-config.mjs <mockup> --ready-to-port` reads the repo's
   `package.json` and prints, as `not ready:` lines:
   - no snapshot yet;
   - a stack other than `project.stack` (the repo's stack decides unless its owners agree a change,
     recorded as an ADR by keel `design-architecture`);
   - a design framework the package names and the repo lacks, or the repo has and the package does
     not (`none` against a repo on a component kit is the fallback route of
     [design-frameworks.md](../../mockup/references/design-frameworks.md));
   - two or more locales and no i18n library in the repo.

   And as `note:` lines, work for Convert: the repo's i18n library (import strings with
   `import-mockup --i18n <it>`), a framework version that differs from the pinned one, no standards
   file yet. Each `not ready:` line is a question for the repo's owners through the technical owner;
   record the answer in the brief and, when it changes the package, as a new sign-off round.

## Building to the repo's conventions

- **The output folder is the repo**, on a branch, never pushed without the user's go.
- **The scaffold is merged, not copied over it**: copy only the files the repo lacks and merge the
  rest into its own (`templates/app-scaffold/README.md`, "Existing repo").
- **The repo's layout wins** over the engine's defaults: its test location, linter, formatter, file
  names, folder for API code. The stack reference's folder layout applies only where the repo has
  none.
- **Imports land where the repo keeps them.** `import-mockup --only contract --contract-out <path>`
  puts the signed-off contract where the repo's Orval (or other generator) config reads it. The
  other parts write under `src/` (`src/mocks/fixtures.ts`, `src/locales/`, `src/styles/`,
  `src/lib/`); where the repo's layout differs, move them by a script step run after the import, in
  the repo's own build scripts, and list it in the conversion plan. Never by hand.
- **The repo's CI runs from the first commit**, with the engine's gates added beside it: the visual
  diff and quality check against the mocked build, `import-mockup --check`. Commit
  `.import-mockup.json`: a plain `--check` includes the contract (from wherever the record says it
  went) and fails on a byte copy changed by hand or an orphan. With no record, or a record with no
  entry for the file, a byte copy the repo already holds with other bytes is refused unless
  `--force`, and `--check` lists it as unrecorded.

## Checks: uphold, meet by script, or change

List every check the repo enforces (CI, hooks, the spec's rules) and put each in one column, and
confirm the table against the real CI before any change:

- **Uphold unchanged**: rules guarding the contract, the spec link, commits and product behaviour.
- **Meet by script**: mechanical gaps closed by a script, never by hand edits page by page (moving
  tests into the repo's test layout, generating route meta from the port's tables, running the
  repo's formatter and `lint --fix`). The repo's conventions win over the engine's defaults.
- **Change through the spec's change record**: rules that only shape how pages are built. The
  change record merges before the code.

The lint remainder after `--fix` is the user's call: fix it, or a one-time import baseline that can
only shrink, authorised by the change record. Do not take the baseline without the user's OK.

## Spike first

Before the first page, build the slice (sign-in, the shell, one data page) in the repo, locally,
nothing pushed. Measure install, generation from the shared contract, typecheck, build, tests and the
lint and format counts. Diff the live API against the contract first, so contract drift is told
apart from client bugs. Name the real risks: the first run against the real backend, the repo's
HTTP client rules, demo-only UI to keep out (a persona switcher, sign-in persona cards) while
test-side fixture selection stays.
