# Dependencies

The engine runs Node code on its users' machines, and its scaffold puts a dependency tree into
their applications. This file covers what that code depends on, the rules that keep the trees
stable and reviewed, and how they move. There are three sets of dependencies, each with its own
lockfile:

| Set | Where | Packages | Installed by |
|---|---|---|---|
| The scripts | `scripts/` | 13 | `npm ci --ignore-scripts` into the project, after the preflight asks |
| The sample backend | `templates/sample-backend/` (copied into each backend) | 69 | `npm ci --omit=dev --ignore-scripts` in its image |
| The apps the scaffold seeds | `templates/app-scaffold/<stack>/` | 343 (React), 461 (Vue), 374 (Next.js) | the app's own `npm ci` |

The package counts are recorded in `scripts/lockfiles.json` and held by `check-lock.mjs`.

## The runtime

- **Node LTS releases only, from the lines tested:** 24 ("Krypton", from 24.18.0) and 26
  ("Lithium", from 26.13.0, its first LTS release). Every package.json carries
  `"engines": { "node": "^24.18.0 || ^26.13.0", "npm": ">=11.16.0" }` and every `.npmrc` carries <!-- supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read -->
  `engine-strict=true`, so `npm ci` refuses any other runtime before installing anything.
- **Why those floors:** npm 11.16.0 is the first release with `allowScripts` and
  `strict-allow-scripts`, which the app `.npmrc` relies on. `min-release-age` arrived earlier, in <!-- supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read -->
  11.10. An older npm ignores a setting it does not know without saying so, so the floor is what
  keeps the rules in force. Node bundles npm 11.16 or later from 24.18.0 and in every 26 LTS release.
- **The preflight** is `scripts/toolchain.mjs`, which every step that needs Node runs first. It
  exits 2 with the reason on any of these:
  - a release that is not LTS (`process.release.lts` is unset);
  - a line the engine is not tested on, or a version below its line's floor;
  - an older npm;
  - a variable that sends Playwright's browser download elsewhere;
  - a toolchain that is not installed exactly as locked. Here it prints the one install command,
    for the caller to ask about first.
- **The sample backend's image** is based on `node:24.20-alpine`, pinned by digest, and moves with
  the runtime line.

## The rules, and what holds each

| Rule | Set by | Checked by |
|---|---|---|
| Every direct dependency and flat override is an exact version | `save-exact=true` | `check-lock.mjs` |
| The lockfile matches its package.json (the dependencies, the engines, and each direct dependency's installed copy) and is complete: every dependency of every entry resolves to an entry | `npm install --package-lock-only` | `check-lock.mjs` |
| Every package comes from `https://registry.npmjs.org/` with a sha512 hash. A package bundled in another's tarball counts only when that parent declares it | npm | `check-lock.mjs` |
| No version is younger than 14 days | `min-release-age=14` when npm resolves | `release-age.mjs`, at every update |
| Every package's registry signature verifies | the registry | `npm audit signatures`, at every update |
| No advisory of high or critical severity | | `npm audit --audit-level=high`, at every update and at the production bar |
| The engine's own toolchains run no install script | `ignore-scripts=true`, and `npm ci --ignore-scripts` | `check-lock.mjs` (any `hasInstallScript` fails) |
| An app runs only install scripts someone reviewed | `allowScripts` in package.json (`false` denies; `name@version: true` approves one version), with `strict-allow-scripts=true` | `check-lock.mjs`, and npm refuses the install |
| The trees grow only by decision | `scripts/lockfiles.json` counts | `check-lock.mjs` |
| The engine's toolchains hold one copy of each package unless one is allowed | `scripts/lockfiles.json` duplicates | `check-lock.mjs` |
| No prerelease installs unless a reason is recorded (an optional binary for another platform is exempt) | `scripts/lockfiles.json` prereleases | `check-lock.mjs` |

Three of these work differently from how they look:

- **`npm ci` does not apply `min-release-age` to a version that is already locked.** It applies the
  rule only when npm resolves a version. A lockfile written before the rule, or by a machine
  without it, installs as it stands. `release-age.mjs` is therefore the check, run over every
  lockfile at each update. It reads the registry's publish time for each version, and
  `--since <ref>` limits it to what the update brought in.
- **`ignore-scripts=true` does not belong in an app's `.npmrc`.** It also skips the app's own pre- <!-- supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read -->
  and post-scripts, and `prebuild`, `pretest` and `pretypecheck` are what generate the API client.
  So apps deny install scripts one package at a time instead. The proven apps install `esbuild`,
  `fsevents` and `vue-demi` with their scripts denied and build and test the same. An
  unreviewed install script fails the install.
- **Playwright's browser download is checked only for its size,** so the toolchain checks it.
  Playwright 1.63 fetches Chromium over HTTPS from Microsoft's CDN and compares the bytes with
  `Content-Length`; there is no hash or signature check. On macOS the build carries an ad-hoc
  signature with no team, so there is no publisher to verify. `browsers.json` records a SHA-256 of
  the extracted headless shell per platform (every file of its folder, `scripts/lib/browsers.mjs`),
  measured from Playwright's own download, and the install compares against it: a mismatch is not
  used. A platform with no recorded hash runs and is reported unverified. The preflight also
  refuses the variables that redirect the download.

## Installing on a user's machine

`toolchain.mjs --install <project>`, run only after the user agrees, puts the engine's toolchain in
the project's `.mockup-engine/toolchain/` and nowhere else: a copy of the engine, its packages
from `npm ci --ignore-scripts`, and the pinned browser in its own `browsers/` folder, which the
scripts use whatever the machine's shared cache holds (`scripts/lib/browsers-env.mjs`). A
`.gitignore` of `*` keeps `.mockup-engine/` out of the project's git, and removing the folder
removes it all. It is about 230 MB, the browser about 200 of them. `install.json` records the
engine's fingerprint, so a toolchain from another engine version reads as stale and is installed
again. `toolchain.mjs --project <project>` checks all of it before every step.

## Direct dependencies

Each row is a decision. A new direct dependency needs a row and a reason here before it is added.
`scripts/test/check-lock.test.mjs` fails on a direct dependency of the engine's own toolchains that
has no row. Each row gives the version pinned, its publish date, and the major line followed.

### The scripts

| Package | Pinned | Needed for | Maintainer | Releases |
|---|---|---|---|---|
| `playwright` | 1.63.0 (2026-09-04) | the browser behind every rendered check | Microsoft | a minor about monthly, no LTS line; moved deliberately, since the Chromium revision (1243) moves with it and the gate's pixels depend on it |
| `playwright-core` | 1.63.0, an override | holds `@axe-core/playwright`'s open peer range (`>= 1.0.0`) to Playwright's own core, so the tree has one copy | Microsoft | with `playwright` |
| `@axe-core/playwright` | 4.13.0 (2026-08-11) | the accessibility rules in the quality check | Deque | follows axe-core's minors |
| `ajv` | 8.20.0 (2026-04-24) | JSON Schema validation of configurations and records | ajv-validator | semver, line 8 |
| `ajv-formats` | 3.0.1 (2024-03-30) | the formats for `ajv` | ajv-validator | semver, line 3 |
| `pixelmatch` | 7.2.0 (2026-04-29) | the pixel comparison | Mapbox | semver; no dependencies; 8.0.0 exists and has not been taken |
| `pngjs` | 7.0.0 (2023-02-20) | reading and writing screenshots | pngjs | infrequent releases; no dependencies |
| `yaml` | 2.9.1 (2026-09-11) | contracts and configurations | Eemeli Aro | semver, line 2 |

### The sample backend

| Package | Pinned | Needed for | Maintainer | Releases |
|---|---|---|---|---|
| `fastify` | 5.12.8 (2026-11-02) | the HTTP server | Fastify | a published LTS policy for each major; line 5 |
| `@fastify/cookie` | 11.1.5 (2026-10-27) | session and CSRF cookies | Fastify | follows Fastify's majors |
| `ajv` | 8.20.0 | the contract, validated in both directions | ajv-validator | as above |
| `ajv-formats` | 3.0.1 | the contract's formats | ajv-validator | as above |
| `nodemailer` | 10.3.1 (2026-10-29) | sign-in codes over SMTP | Andris Reinman | semver, line 10 |
| `openid-client` | 6.8.9 (2026-11-02) | sign-in through an identity provider | Filip Skokan | semver, line 6; 6.9.1 was taken first, two days after it was published, and moved back to 6.8.9 when the 14 days were applied |
| `pg` | 8.23.1 (2026-09-30) | Postgres | Brian Carlson | semver, line 8 |
| `yaml` | 2.9.1 | the contract | Eemeli Aro | as above |

### Licences

From the lockfiles' own `license` fields. None of these packages is shipped: a user's install
fetches them from the registry. `axe-core` and `@axe-core/playwright` are MPL-2.0 (file-level
copyleft: a change to their own files would be shared under it; using them is not affected).
Playwright is Apache-2.0. The one third-party file the engine does ship, driver.js 1.9.0 in the
tours module, is MIT and carries its licence beside it.

| Set | Licences (distinct package names) |
|---|---|
| The scripts | MIT (6); MPL-2.0 (2); ISC (2); Apache-2.0 (2); BSD-3-Clause (1) |
| The sample backend | MIT (58); ISC (5); BSD-3-Clause (3); MIT-0 (1) |

### The apps the scaffold seeds

Each stack's `package.json` pins exactly what its proven example pins, and its lockfile is that
example's lockfile with the placeholder name. `scripts/test/app-scaffold.test.mjs` and
`check-lock.test.mjs` hold both. The proven examples are `examples/equipment-loans-app` (in the proving repository) (React),
`examples/equipment-loans-vue` (in the proving repository) and `examples/equipment-loans-next`. A version moves in the example
first, through its gates, and then into the scaffold.

## Updating

Once a month, or for a named advisory, in each folder that moves:

1. Run `npm update` (or change a pin). The `.npmrc` keeps resolution to versions at least 14 days old. <!-- supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read -->
2. Run `node scripts/release-age.mjs <dir> --since HEAD`. When a version is too young, `--prune`
   removes it and `npm install --package-lock-only` resolves it again under the rule. One pass may
   not put back everything a pruned entry provided (an override can keep npm from re-adding it), so
   repeat the install until `check-lock.mjs` finds the lockfile complete.
3. Run `node scripts/check-lock.mjs`, then `npm audit signatures` and `npm audit --audit-level=high`.
4. Run the engine suite, the backends' suites on Postgres, and the gates of any example the change
   reaches. Then copy the example's lockfile into the scaffold.
5. In the commit, list every version that moved and what its changelog says about breaking or
   security changes. A new package raises the count in `scripts/lockfiles.json` in the same commit,
   with its reason.

A security fix may enter before 14 days. That needs an entry in `min-release-age-exclude` for the
one package, the advisory named in the commit, and the release read by hand. A bot may open the
pull request, and a person merges it.
