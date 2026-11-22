# Step detail: Mock

Read the section for a step before doing that step. `S` is the scripts folder Step 0's
`toolchain.mjs --project` prints: the project's own install of the engine.

## Step 4: the checks before the client sees it

1. **Behaviours.** Write `docs/behaviours.json`, what each screen must do that a screenshot cannot
   show (a submitted amount, a role's missing control, a value that fits at 320px). Its format,
   every assertion and an example: [mockup-behaviours.md](mockup-behaviours.md).
2. **A pinned baseline.** On the first round, capture every screen, state and viewport:
   `--write-baseline <dir>` writes `<name>--<state>--<viewport>.png` for each case and prints
   `baseline written: N cases (S screens) -> <dir>` (exit 0 when all are written). It honours
   `--screen`, `--state`, `--viewport`, `--skip`, `--clock`, `--seed` and `--tz` (default the
   config's `timezoneId`), and is refused (exit 2) with `--out`, `--app`, `--baseline`,
   `--expected` or `--shard`. On every later round, compare against it with `--baseline <dir>`; a
   difference is either the change you meant or a regression. A case with no baseline PNG fails
   the `--baseline` run and is listed; `--allow-missing-baseline` (baseline mode only) lists it as a
   warning instead. Pass the same `--clock`, `--seed` and `--tz` each time, and keep them with the
   baseline. `--out` is emptied first, so one that is or contains the mockup, the current folder or
   home, or is or holds a git repository, is refused (exit 2). One guard does it
   (`lib/baseline-report.mjs` `outDirRefusal`), for `dom-oracle` and `gate-sharded.sh`'s `OUT` too.
3. Then the checks, each clean before the client sees the mockup:

```bash
node S/check-config.mjs <mockup>                               # the config and the open decisions, no browser
node S/inventory.mjs <mockup>                                  # conventions and the config schema; exits 1 on lint not accepted in docs/inventory-accepted.json, or no pages; 2 with no config, a config that is not a JSON object, or a bad accepted file
node S/quality-check.mjs --mockup <mockup>                     # accessibility, contrast included
node S/spill-check.mjs --mockup <mockup>                       # content wider than its box, 320 to 1920px
node S/spill-check.mjs --mockup <mockup> --text 1.25           # again, with larger default text
node S/spill-check.mjs --mockup <mockup> --locale pseudo       # again, text about 40% longer (project.i18n.expansionCheck); screens with steps are left out and listed
node S/check-behaviours.mjs --mockup <mockup> --clock <iso> --seed <n>
node S/visual-diff.mjs --mockup <mockup> --write-baseline <dir> --clock <iso> --seed <n> --tz <zone>  # first round
node S/visual-diff.mjs --mockup <mockup> --baseline <dir> --clock <iso> --seed <n> --tz <zone>        # later rounds
```

Fix each finding at its cause (the component, token or fixture), never by hiding it. For a long
run, `S/gate-sharded.sh` runs the behaviours and the baseline diff in parallel shards and merges
them.
