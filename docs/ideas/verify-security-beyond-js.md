# Idea: `verify.security` detection for pip, and for stacks with no lockfile audit

| | |
|---|---|
| Raised by | The 2026-09-25 plan's "Not in this plan" table, last row, 2026-09-25 |
| Status | declined |
| Recommendation | Do not build it |
| Next | Nothing |

## The problem

No one has a problem yet. `detect_verify`'s python branch has no `security` case at all
(`lib/detect-stack.sh:644-669`), and no stack outside npm, pnpm and a yarn 2+ lockfile gets one
either (task 6, landed 2026-09-25, covers only those three). A pip, go, java, php, rust or dart
project's `verify.security` stays `null` forever, and `keel doctor` reports that as `ok`, not a
warning, by the same decision that shipped task 6: "keel detects one only from an npm, pnpm or
yarn lockfile, so set it if this project has another" (`bin/keel`, the message task 6 wrote for
the null case). Nothing in the sources shows anyone hitting that and minding.

**Evidence.** Unknown, and nobody could name one. No plan, audit, idea record or open decision in
the given sources names a Python (or go, java, php, rust, dart) project that asked for
`verify.security` detection, hit a false "ok" on a missing scan, or filed a complaint about it. The
only place this appears is the plan's own "Not in this plan" row, written by the maintainer as a
forward-looking placeholder, not as a report of a request that arrived
(`docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md:1924`, "a separate
decision, if a Python project asks").

## What was asked for

The plan's own words, from its "Not in this plan" table: "`verify.security` for pip, and for
stacks with no lockfile audit", with the reason given as "pip-audit installs a package, and
`doctor` executes verify commands", and the next step named as "a separate decision, if a Python
project asks" (`docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md:1924`).
Nobody has since asked; this record exists because the deferred row was flagged for a follow-up
surface, not because a user raised it.

## The case against

**Nobody has a problem, and the safe self-service path already exists.**
`keel profile set verify.security '<command>'` works on every stack today, pip included, and
`keel doctor` already tells a user with a null `verify.security` to set one themselves. Building
detection ahead of a named user spends exactly the process cost this repository charges every change
it lands (a written test that fails first, a spec review, a quality review, a citation repair pass,
a `CHANGELOG.md` and `docs/profile-keys.md` update, all visible in task 6's own execution note) to
close a gap nobody has reported feeling. The same plan that flagged this row also decided, in the
same sentence, why it excluded pip on purpose: `pip-audit` has no equivalent of `npm audit`, which
ships with the package manager itself and only reads a lockfile against a registry. Running
`pip-audit` means `pip install pip-audit && pip-audit` first
(`bin/keel#audit='pip install pip-audit && pip-audit -r requirements.txt'`, `write_ci`'s own pip
mapping), and full `doctor` executes every non-null `verify.*` command
(`bin/keel#for k in test lint typecheck build security; do`, the loop task 6 added). Detecting it
the same way task 6 detected npm, pnpm and yarn would make `keel doctor` install a package into
whatever Python interpreter is on the project's `PATH` on every full run, a side effect none of the
three JavaScript package managers' audit commands carry. That is not an oversight to close; it is
the reason the row exists.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Nothing. Every affected stack already gets an honest `null` and a message pointing at `profile set` | This is the recommendation: no named user has hit the gap, so there is nothing to weigh it against |
| Do it manually | `keel profile set verify.security '<command>'`, which already works on any stack, pip included, right now | Requires the user to know the key exists and to accept `pip-audit`'s install step themselves, but costs no new code |
| Buy it | A hosted scanner (Dependabot, Snyk, or similar) attached to the repository or its CI host, independent of keel | Fixes the same gap without `doctor` ever installing anything locally, but is a different product with its own account and config, not a keel change |
| Build something smaller | Detect `verify.security` for pip only when the project already declares `pip-audit` itself, the same `py_declares` pattern `detect_verify` already uses for `ruff`, `mypy` and `black` (`lib/detect-stack.sh:305-307,655-657,665-668`); leave go, java, php, rust and dart undetected | Avoids the install side effect entirely, but still solves a problem nobody named, for the subset of pip projects that happen to have already added `pip-audit` before anyone asked |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| A Python project has actually hit the missing `verify.security` for pip | Someone names a specific project and date | Search the plans, audits, idea records and open decisions for a raised instance | Checked: none found in the given sources |
| Stacks with no lockfile audit (go, java, php, rust, dart) feel the same gap pip would | Their users hit the same null `verify.security` in `doctor` or `ship` and mind it | Same search as above | Checked: none found; `write_ci` already treats them as never having had a mapping, and skips even the "add one by hand" note for them on purpose (`bin/keel#no dependency audit step in the CI workflow`, limited to `javascript|typescript|python`) |
| `pip-audit`'s install-then-run shape is the only way to run it on a pip project | No already-declared alternative exists that `py_declares` could key off instead | Read the existing `py_declares` gated branches for `ruff`, `mypy`, `black` | Checked: the pattern exists and would avoid the install step, but nobody has asked for it either |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| `detect_verify`'s python branch has no `security` case | `lib/detect-stack.sh:644-669` | The gap is real and total for pip, not partial |
| `write_ci` already maps pip to an install-then-run audit, and the plan that shipped task 6 named that as the reason to exclude it from `detect_verify` | `bin/keel#audit='pip install pip-audit && pip-audit -r requirements.txt'`; `docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md:1203-1204` | The exclusion is a recorded decision, not an omission task 6 forgot |
| Full `doctor` executes every non-null `verify.*` command, including `verify.security` | `bin/keel#for k in test lint typecheck build security; do` (the loop `for k in test lint typecheck build security`) | Any pip detection that reuses the `write_ci` audit string makes every full `doctor` run install a package |
| Every stack outside npm, pnpm and yarn 2+ gets `pm=""` in `write_ci`, so `audit=""` and the workflow gets no audit step and no "add one by hand" note | `bin/keel#*)    audit="" ;;`, `bin/keel#no dependency audit step in the CI workflow` | Go, java, php, rust and dart were never given even a CI-side mapping; detecting `verify.security` for them is a larger, separate per-stack tool decision, not a small addition alongside pip |
| The snapshot's own correction after task 6 records the scope as final for that task, not partial pending a follow-up | `docs/snapshot.md#Every other stack still gets none.` | The maintainer already treated task 6 as done at its stated scope, consistent with no open ask to extend it |
| `py_declares` already gates `ruff`, `mypy`, `pyright` and `black` detection on the project having declared the tool itself | `lib/detect-stack.sh:305-307,655-657,665-668` | A no-install pip variant is technically straightforward to build later, if a named user ever asks for it |

## Open questions

1. If a named Python project does surface this gap later, should the fix be the narrow pip-only
   variant (detect only when `pip-audit` is already declared, no install step), or should it wait
   for a single decision that also picks an audit tool for go, java, php, rust and dart together?
   Not blocking now, since no such project exists yet in the sources.

## Recommendation

Do not build it. No source shows a Python, go, java, php, rust or dart project asking for this, and
`keel doctor` already offers a self-service path (`profile set verify.security`) for anyone who has
one. Revisit only when a named project raises it, at which point the open question above decides
the shape.

## Not decided here

Whether a future pip detector should key off `py_declares` (no install) or reuse `write_ci`'s
install-then-run string, and which tool each of go, java, php, rust and dart would use, are left
open rather than ruled out. Nothing here rules out building this later; it says only that nothing in
the sources justifies building it now.
