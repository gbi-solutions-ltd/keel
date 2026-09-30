# Idea: keel's own checks cannot run in a target project's CI

| | |
|---|---|
| Raised by | `docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md`, "Not in this plan", row 2, 2026-09-25 |
| Status | agreed, not built. Open questions 1 and 2 answered 2026-09-27 |
| Recommendation | Build something smaller: ship the `gates.coding_standards` existence check into `write_ci` now, failing on `required` and reporting on `warn` the way `doctor` does, no ADR needed. Leave `keel scan` and the profile-loosening diff to two separate ADRs |
| Next | `tdd`, for the standards-gate check. `design-architecture`, two ADRs, one for `keel scan` and one for the profile-loosening diff |

## The problem

A repository configured by keel gets three mechanical checks keel itself builds and runs: a
supply-chain scanner (`keel scan`), a ratchet against a weakened `.keel/profile.json`
(the pre-push guard's loosening check), and a check that `gates.coding_standards` is honest about
whether `standards.md` exists (`keel doctor`). None of the three reaches the one surface that fires
on every push and every merge regardless of who or what made it: the generated CI workflow.
`write_ci` (`bin/keel#write_ci() {`, called once from `cmd_new`) writes `.github/workflows/ci.yml`
with one step per non-null `verify.*` key
(`bin/keel#Every other verify command that is a real, runnable string`), a dependency audit, and a
key-material grep. It never invokes `keel` and never reads a `gates.*` key or `.keel/profile.json`'s
git history, because nothing installs `keel` in that workflow.

**Evidence.** This repository's own hand-authored CI is the instance, dated to its most recent
commit, `f62d2ae`, 2026-09-26. `.github/workflows/ci.yml` has exactly four jobs: `validate`,
`test-macos`, `python-lint` and `supply-chain` (`.github/workflows/ci.yml:14,43,61,77`). The last
one calls `tests/supply-chain-scan.sh` directly (`.github/workflows/ci.yml:85`), the same script
`keel scan` wraps (`bin/keel#SCANNER="$HERE/tests/supply-chain-scan.sh"`, `bin/keel#cmd_scan() {`).
No job anywhere in the file touches `.keel/profile.json`'s gates or checks `gates.coding_standards`.
This is the repository that dogfoods keel most closely and whose maintainer wrote the recommendation
this record answers (`docs/snapshot.md`, recommendation 7), and even it does not run these two
checks in CI. The only place they run today is a git hook installed by `keel guard install`
(`bin/keel#guard_hook_body() {`, opt-in, per repository, reads refs from stdin,
`bin/keel#Only when git is feeding the hook`) and `keel doctor`
(`bin/keel#gates.coding_standards is required and $root/standards.md exists`), which runs inside a
session or a manual invocation, never inside the generated workflow.

## What was asked for

> Run keel's own checks (`keel scan`, the profile loosening check, the standards gate) in a target
> project's CI. Generated CI (`bin/keel`, function `write_ci`) cannot call `keel` because nothing
> installs it there; vendoring, fetching a release, or re-expressing the checks are three different
> designs.

The brief already names the reason (nothing installs `keel`) and three candidate designs. It treats
the three checks as one decision. Reading each mechanism shows they are not the same shape, which is
the finding this record adds.

## The case against

**Strongest argument for not building this at all.** Nobody can name an actual instance of a
bypass causing harm: not a profile weakened through a platform merge, not a scan-flagged pattern
that reached a protected branch because CI never ran the scanner. The case for building this rests
entirely on architectural symmetry with what the git hook and `doctor` already do, not on a
demonstrated failure, and every one of the three named designs is a new synchronisation surface that
has to be kept current in every downstream repository every time keel's own rules or schema change,
which is the exact cost this repository already priced and rejected once for the analogous
per-repo question of distributing skills at all: "Vendored copy... Rejected. Version drift within a
month" and "npm or pip package... Rejected. Forces a Node or Python dependency onto every repo"
(`docs/03-install-and-distribution.md:7,9`). Paying that recurring cost against a bypass nobody has
yet observed is a bet, not a fix.

**This argument does not apply evenly, and that is why "build something smaller" survives it.** It
applies in full to `keel scan`, whose ruleset is 19 pattern rules plus a coverage test that changes
over time (`tests/supply-chain-scan.sh`, 362 lines). It applies substantially to the
profile-loosening diff: its comparator hardcodes the gate list it checks
(`bin/keel#for gate in ("commit_guard", "done_verified", "security_audit", "coding_standards"):`),
and this same 2026-09-25 plan moved `SCHEMA_VERSION` from 4 to 5 by adding
`conventions.no_attribution_footers` (`bin/keel#SCHEMA_VERSION=5`), a key the comparator's gate
tuple does not cover, since it is a convention, not a gate; that tuple would need the same kind of
update, kept current, wherever a copy of it lives. It does not apply to the standards-gate check at
all: its "ruleset" is a single file-existence test against a value the target project's own profile
already owns; there is nothing to keep in sync because there is nothing beyond the profile itself.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Nothing | This repository's own CI is the demonstrated cost: it dogfoods the scanner directly but runs neither the loosening check nor the standards gate, so a PR merged through GitHub's UI, or a contributor who never ran `keel guard install`, reaches `main` here with both unchecked |
| Do it manually | A reviewer re-reads the `.keel/profile.json` diff and re-runs the scanner locally on every PR | Attention that decays exactly as `docs/ideas/profile-loosening-goes-unnoticed.md` already found for the git hook, and does nothing for a PR opened by a bot, a fork, or the platform's own merge button, which is the population this idea exists to reach |
| Buy it | Nothing found that covers all three | GitHub's native secret scanning or a generic tool such as Gitleaks overlaps with some of `keel scan`'s rules (credential stores, opaque blobs) but covers none of its prompt-injection rules (`bin/keel` shares scope with `tests/supply-chain-scan.sh`'s `agent-override`, `agent-conceal`, `agent-silent-act` rules) and knows nothing of `.keel/profile.json`'s gate vocabulary. Buying something substitutes for a slice of one of the three checks, not for any of them fully |
| Build something smaller | See Recommendation | The three checks do not cost the same to reach from CI. Treating them as one decision, as the source plan's single row does, prices the cheap one at the expensive one's rate |

**Variants of building it**

| Variant | Note |
|---|---|
| Vendor a copy of each check's own artifact into the target repo | Cheapest for the standards-gate check, which is one file-existence test against a key the project already owns. Carries real drift for `keel scan` and the loosening comparator, whose rules and gate list change with keel's own schema, the same cost `docs/03-install-and-distribution.md` priced against Option A |
| Fetch a built release at CI time | keel has version tags (`v0.17.0` through `v0.21.0`) but no workflow that publishes an installable artifact from one. This is new infrastructure to build, not a redirect of infrastructure that already exists |
| Re-express each check as a small, free-standing CI step, independent of `bin/keel` | Already the shape `write_ci` uses for `verify.*` and the shape this repository's own `ci.yml` uses for `verify.lint` (`jq -r '.verify.lint' .keel/profile.json`) and for the scanner, called directly rather than through `keel scan`. The standards-gate check is already this cheap. The loosening check is not: its comparator needs a base and a head commit, and a `push` event and a `pull_request` event hand CI that pair differently, which is a real design question, not a restatement |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| A weakened profile or a scan-flagged pattern can reach a protected branch without ever passing through a machine with the pre-push hook installed | A platform web-UI merge, a bot-authored PR, or a fresh clone that skipped `keel guard install` | `docs/ideas/profile-loosening-goes-unnoticed.md:53` states the hook is "blind to a change landed through the hosting platform's web UI or API rather than `git push`" | Checked, by that record's own text |
| No such bypass has actually caused harm yet | Nobody names an instance | Searched `docs/audits/`, `docs/snapshot.md`, and both 2026-09-25/26 plans in scope; none records an incident, only the architectural gap | Checked, and the answer is none named |
| A target project's generated CI runner reliably has `jq` (or an equivalent) available | `write_ci` only ever emits GitHub Actions YAML | This repository's own `ci.yml` notes "shellcheck and jq are preinstalled on ubuntu-latest" | Checked for GitHub-hosted `ubuntu-latest`/`macos-latest` runners; unchecked for self-hosted runners or any other CI provider, which `write_ci` does not target at all |
| The standards-gate check is genuinely cheaper to reach than the other two, not just apparently so | Comparing what each needs beyond `.keel/profile.json` itself | The gate check needs one file-existence test; the scanner needs 362 lines of rules kept current; the loosening check needs a base/head pair CI does not hand it uniformly | Checked, by reading each mechanism directly |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| `write_ci` never invokes `keel` or reads a `gates.*` key | `bin/keel#write_ci() {`; loop is `bin/keel#Every other verify command that is a real, runnable string` over `VERIFY_KEYS` only | The brief's premise is correct: generated CI has no path to any of the three checks today |
| Keel's own dogfooded CI runs the scanner directly but not the other two checks | `.github/workflows/ci.yml:14,43,61,77,85`, no job reads `.keel/profile.json`'s gates | The scanner's underlying artifact is already reachable without the `keel` CLI; the other two are not proven that way anywhere, including here |
| `keel scan` is a thin wrapper, not a distinct mechanism | `bin/keel#cmd_scan() {`, `bin/keel#SCANNER="$HERE/tests/supply-chain-scan.sh"` | Vendoring or re-expressing this check means distributing `tests/supply-chain-scan.sh`, not `bin/keel` |
| The scanner is written to be pointed at arbitrary projects, not only keel's own tree | `tests/supply-chain-scan.sh`, comment on `allowed_executable`: "`keel scan` points this scanner at ordinary projects" | The generic-use case this idea needs is one the scanner's own author already anticipated |
| The loosening check is a git hook, opt-in, fires on `git push` only | `bin/keel#guard_hook_body() {`, `bin/keel#Only when git is feeding the hook` | It cannot see a platform-UI merge or a repo that never ran `keel guard install`; CI is the one surface that would |
| The loosening comparator hardcodes the gates it checks | `bin/keel#for gate in ("commit_guard", "done_verified", "security_audit", "coding_standards"):` | A schema change that adds a gate (or, as here, a convention) needs this list updated wherever a copy lives |
| The schema changed size in the very plan that raised this idea | `bin/keel#SCHEMA_VERSION=5`, added by task 5 of the source plan for `conventions.no_attribution_footers` | Concrete instance of the drift risk priced in the case against, inside this repository's own single copy |
| The standards gate is a doctor-only, existence-level check | `bin/keel#gates.coding_standards is required and $root/standards.md exists` | It is unrelated to whether code *complies* with `standards.md`, which is `docs/ideas/standards-that-bind.md`'s subject, not this one's |
| The coding-standards-enforcement PRD wires the gate only into `ship` and `doctor`, by name excluding a new hook | `docs/prd/coding-standards-enforcement.md:112,148,161`, CON-02: "No new git-hook mechanism. FR-01 through FR-03 act through `keel:ship`, an existing skill" | Confirms the gate has zero CI-reachability today by a deliberate, dated decision, not an oversight |
| Vendoring and a language-package install were both rejected once already, for the analogous per-repo distribution question | `docs/03-install-and-distribution.md:7,9` | Direct precedent for the drift cost of two of the three CI designs named in the brief |
| Version tags exist; a publishable release artifact does not | `git tag` lists `v0.17.0` through `v0.21.0`; no workflow under `.github/workflows/` builds or publishes anything from a tag | "Fetching a release" needs new infrastructure, not a redirect of infrastructure keel already runs |

## Open questions

1. ~~Does the design-architecture ADR treat `keel scan` and the profile-loosening diff as one
   decision or two?~~ **Answered 2026-09-27 by Bernard, asked as a choice: two.** They differ in how
   CI supplies a base/head pair (the scanner needs none; the loosening diff needs one) and in how
   their rulesets stay current, though
   `docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md`'s row treats them as one.
2. ~~Should the standards-gate check, once in `write_ci`, also read `gates.coding_standards` at
   `warn` (report only) the way `doctor` already distinguishes `required` from `warn`, or is
   `write_ci` only ever going to fail the build the way its `verify.*` steps do?~~ **Answered
   2026-09-27 by Bernard, asked as a choice: mirror `doctor`.** `required` fails the build, `warn`
   reports and passes.
3. Is there a real target project, outside keel's own repository, whose CI this gap has already
   affected? Not found in the sources searched; if one exists it would sharpen the case-against's
   "no named victim" objection considerably, in either direction.

## Recommendation

**Build something smaller.** Ship the `gates.coding_standards` existence check into `write_ci` now:
it needs no vendoring, no release artifact, and no re-expression decision, because it is already a
one-line file-existence test against a value the target project's own `.keel/profile.json` holds,
the same shape this repository's own `ci.yml` already uses for `verify.lint` via `jq`. It closes a
real, dated gap (this repository's own CI does not run it) at the cost the source plan's own bar for
"cheap and mechanical" sets, and needs no ADR. Like `doctor`, it fails the build on `required` and
only reports on `warn` (open question 2).

Leave `keel scan` and the profile-loosening diff to design-architecture, as two ADRs rather than
the one the source plan named (open question 1). Both genuinely need a design decision this record does not make: `keel scan`'s
ruleset has to reach the target repository somehow and stay current there, and the loosening diff
needs CI to supply a base/head pair that its two trigger types (`push`, `pull_request`) do not hand
it the same way. Bundling either into "build it now" would be picking a design under a skill that is
not supposed to.

## Not decided here

Which of vendoring, fetching a release, or re-expressing is right for `keel scan` and the
profile-loosening diff; whether a release-publishing workflow is worth building for this reason alone or only
if something else also wants it; and whether the standards-gate check belongs in `write_ci` verbatim
or as a `doctor --fast`-style step reused from the same source `bin/keel` already has at
`bin/keel#gates.coding_standards is a promise about a document. required with no`. All belong with
`tdd` for the small piece and `design-architecture` for the rest.
