/**
 * args.mjs: one argument parser for every script, from a declared flag table per script (SPECS).
 *
 * A flag is `boolean` (present or not), `value` (takes the next argument; given at most once) or
 * `repeatable` (a value, given any number of times; an array in order). Anything not starting with
 * `--` and not taken as a value is a positional, counted against the script's [min, max]. A value
 * may start with a single `-` (`--skip "-tour$"`, `--seed -1`), never with `--`: a value flag
 * followed by another flag, or by nothing, is an error.
 *
 * One exit-code rule for every script:
 *   0  passed (or wrote what it was asked to);
 *   1  the check ran and found a failure (a mismatch, a fail row, drift, a refusal of what it read);
 *   2  it could not run: bad usage, a missing or invalid input file or config, a selection that
 *      matches nothing, an unreachable target, or a crash.
 * A flag that does not apply to the mode given is refused (2), never ignored.
 *
 * Errors exit 2 with the script's usage: an unknown flag, a value flag with no value or another flag
 * as its value, a value flag given twice, too few or too many positionals. `--help` prints the usage
 * and exits 0. cli() also makes an uncaught error exit 2 (a crash), never 1, which every script
 * keeps for "checked, and failed"; isCrash tells a crash from a refusal for a script that catches
 * errors itself. check-frontend.mjs, copied into apps standalone, keeps the same rule on its own.
 *
 * Import-safe: nothing happens until a script calls cli() in its entry point.
 */

const V = 'value';
const B = 'boolean';
const R = 'repeatable';
const PIN = { clock: V, seed: V, tz: V };
const SELECT = { screen: V, viewport: V, state: V };

/** Per script: flags, positional [min, max] (and a name for the message), usage. */
export const SPECS = {
  'visual-diff': {
    flags: { mockup: V, app: V, baseline: V, 'write-baseline': V, out: V, expected: V, shard: V, skip: V, workers: V, route: V, 'exclude-route': V, 'settle-steps': B, 'allow-missing-baseline': B, ...SELECT, ...PIN },
    usage: [
      'usage: visual-diff.mjs --mockup <dir> --app <base-url> [--out <dir>] [--expected <file>] [--shard K/N]',
      '       visual-diff.mjs --mockup <dir> --baseline <png-dir> [--out <dir>] [--expected <file>] [--shard K/N] [--skip <regex>] [--workers N] [--allow-missing-baseline]',
      '       visual-diff.mjs --mockup <dir> --write-baseline <png-dir> [--skip <regex>] [--workers N]',
      '  every mode: [--screen <substr>] [--viewport <name>] [--state <name>] [--route <regex>] [--exclude-route <regex>]',
      '              [--clock <iso-instant>] [--seed <int>] [--tz <zone>] [--settle-steps]',
    ].join('\n'),
  },
  'quality-check': {
    flags: { mockup: V, app: V, out: V, screen: V, shard: V, warnings: V },
    usage: 'usage: quality-check.mjs --mockup <dir> [--app <url>] [--out <dir>] [--screen <substr>] [--shard K/N] [--warnings summary|all]',
  },
  'dom-oracle': {
    flags: { mockup: V, app: V, out: V, root: V, 'app-root': V, reference: V, diff: B, strict: B, config: V, ...SELECT, ...PIN },
    positional: [0, 2, 'the two files --diff compares'],
    usage: [
      'usage: dom-oracle.mjs --mockup <dir> --app <base-url> [--out <dir>] [--screen <substr>] [--state <name>] [--viewport <name>]',
      '                      [--clock <iso-instant>] [--seed <int>] [--tz <zone>] [--root <selector>] [--app-root <selector>] [--reference <report.json | out-dir>]',
      '       dom-oracle.mjs --diff <mockup.html> <app.html> [--strict] [--config <mockup.config.json>]',
    ].join('\n'),
  },
  'check-behaviours': {
    flags: { mockup: V, file: V, only: V, shard: V, ...PIN },
    usage: 'usage: check-behaviours.mjs --mockup <dir> [--file <behaviours.json>] [--only <id prefixes, comma separated>] [--shard K/N] [--clock <iso-instant>] [--seed <int>] [--tz <zone>]',
  },
  inventory: {
    flags: { mockup: V, out: V, accepted: V, 'ready-to-port': B },
    positional: [0, 1, 'the mockup folder'],
    usage: 'usage: inventory.mjs [<mockup-dir> | --mockup <dir>] [--out <dir>] [--accepted <file>] [--ready-to-port]',
  },
  'spill-check': {
    flags: { mockup: V, screen: V, widths: V, text: V, locale: V, out: V },
    usage: 'usage: spill-check.mjs --mockup <dir> [--screen <substr>] [--widths 320,1024] [--text 1.25] [--locale pseudo] [--out <dir>]',
  },
  'merge-shards': {
    // tz: a check-behaviours flag the merge ignores, accepted because gate-sharded.sh passes BEH_ARGS
    // (--file, --only, --tz) to the shards and the merge alike
    flags: { dir: V, shards: V, mockup: V, file: V, only: V, out: V, warnings: V, tz: V },
    positional: [1, 1, 'the subcommand (behaviours, diff, app or quality)'],
    usage: [
      'usage: merge-shards.mjs behaviours --dir <dir> --shards N --mockup <mockup-dir> [--file f] [--only p] [--tz zone: as the shards ran, ignored]',
      '       merge-shards.mjs diff --dir <dir> --shards N [--out <merged-dir>]',
      '       merge-shards.mjs app --dir <dir> --shards N [--out <merged-dir>]',
      '       merge-shards.mjs quality --dir <dir> --shards N [--out <merged-dir>] [--mockup <dir>] [--warnings all]',
    ].join('\n'),
  },
  'check-config': {
    flags: { 'ready-to-port': B },
    positional: [0, 1, 'the mockup folder'],
    usage: 'usage: check-config.mjs [<mockup-dir>] [--ready-to-port]',
  },
  headers: {
    flags: { emit: V, check: V, record: V, env: R, session: V },
    positional: [1, 1, 'the headers.json'],
    usage: 'usage: headers.mjs <headers.json> (--emit nginx | --check <url> [--session <file>] [--record <file>]) [--env NAME=value ...]',
  },
  toolchain: {
    flags: { dir: V, 'runtime-only': B, project: V, install: V },
    usage: 'usage: toolchain.mjs --project <dir> | --install <dir> | [--dir <scripts dir>] [--runtime-only]',
  },
  'check-lock': {
    flags: { packages: V },
    positional: [0, Infinity, 'the folders to check'],
    usage: 'usage: check-lock.mjs              (every entry of lockfiles.json)\n       check-lock.mjs <dir>... [--packages N]',
  },
  'release-age': {
    flags: { days: V, since: V, prune: B, registry: V },
    positional: [1, Infinity, 'the folders whose lockfiles to check'],
    usage: 'usage: release-age.mjs <dir>... [--days N] [--since <git-ref>] [--prune] [--registry <url>]',
  },
  'check-links': {
    flags: { list: V, file: R },
    positional: [0, 1, 'the root'],
    usage: 'usage: check-links.mjs [<root>] [--list <target substring>] [--file <extra.md>]...',
  },
  'contract-diff': {
    flags: { record: V },
    positional: [2, 2, 'the signed-off contract and the live one'],
    usage: 'usage: contract-diff.mjs <signed-off openapi> <live openapi file or URL> [--record <file>]',
  },
  'perf-budget': {
    flags: { budget: V, dist: V, next: V, url: V, mockup: V, route: V, runs: V, session: V, record: V },
    usage: 'usage: perf-budget.mjs --budget <perf-budget.json> (--dist <dist> | --next <.next> --url <base> --mockup <dir>) [--url <base> --mockup <dir>] [--route <regex>] [--runs N] [--session <file>] [--record <file>]',
  },
  'staging-run': {
    flags: { url: V, flows: V, contract: V, 'live-contract': V, api: V, build: V, record: V, 'save-session': V, stub: B, sample: B },
    usage: 'usage: staging-run.mjs --url <served app> --flows <staging-flows.json> --contract <openapi> --live-contract <file or URL> [--build <dist/index.html | .next/BUILD_ID>] [--stub | --sample] [--api <origin>] [--record <file>] [--save-session <file>]',
  },
  'production-bar': {
    flags: { docs: V, gaps: V, url: V, contract: V, env: R },
    positional: [1, 1, 'the app folder'],
    usage: 'usage: production-bar.mjs <app> [--docs <docs_root>] [--gaps <gaps.md>] [--url <served app>] [--contract <path in the app>] [--env NAME=value ...]',
  },
  signoff: {
    flags: { by: V, date: V, note: V, docs: V, freeze: V },
    positional: [1, 1, 'one mockup folder'],
    usage: 'usage: signoff.mjs <mockup-dir> --by <who> [--date YYYY-MM-DD] [--note <text>] [--docs <dir>] [--freeze <dir>]',
  },
  'import-mockup': {
    flags: { mockup: V, app: V, stack: V, only: V, i18n: V, 'contract-out': V, check: B, flat: B, force: B },
    usage: 'usage: import-mockup.mjs --mockup <dir> --app <dir> [--stack react-vite|vue|nextjs] [--only fixtures,icons,css,nav,strings,contract] [--i18n vue-i18n|i18next|icu] [--contract-out <path>] [--flat] [--check] [--force]',
  },
  'vendor-library': {
    flags: { from: V, to: V, include: R, exclude: R, package: V, app: V, allow: R, check: B, force: B, 'no-default-excludes': B },
    usage: 'usage: vendor-library.mjs --from <library dir> --to <app>/vendor/<name> [--include <globs>] [--exclude <globs>] [--no-default-excludes] [--package <package.json>] [--app <dir>] [--allow <globs>] [--force] | --check --to <dir> [--from <dir>]',
  },
  'split-css': {
    flags: { inventory: V },
    positional: [2, 2, 'the mockup folder and the app components folder'],
    usage: 'usage: split-css.mjs <mockup-dir> <app-components-dir> [--inventory <inventory.json>]',
  },
};

export class ArgError extends Error {}

/**
 * Parses argv against a spec ({ flags, positional? }). Returns { values, positional }: values holds
 * true for a boolean given, the string for a value, an array for a repeatable; `help` when --help
 * is given (nothing else is then checked). Throws ArgError.
 */
export function parseArgs(argv, spec) {
  const values = {};
  const positional = [];
  if (argv.includes('--help') || argv.includes('-h')) return { values: { help: true }, positional };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (!a.startsWith('--')) { positional.push(a); continue; }
    const name = a.slice(2);
    const kind = Object.hasOwn(spec.flags, name) ? spec.flags[name] : null;
    if (!kind) throw new ArgError(`unknown flag ${a}`);
    if (kind === B) {
      if (values[name]) throw new ArgError(`${a} given twice`);
      values[name] = true;
      continue;
    }
    const v = argv[i + 1];
    if (v === undefined) throw new ArgError(`${a} needs a value`);
    if (v.startsWith('--')) throw new ArgError(`${a} needs a value, got the flag ${v}`);
    i += 1;
    if (kind === R) (values[name] ??= []).push(v);
    else if (Object.hasOwn(values, name)) throw new ArgError(`${a} given twice`);
    else values[name] = v;
  }
  const [min, max, what = 'argument'] = spec.positional ?? [0, 0];
  if (positional.length > max) throw new ArgError(max ? `too many arguments: ${positional.join(' ')} (want ${max === min ? max : `at most ${max}`}: ${what})` : `unexpected argument ${positional[0]}`);
  if (positional.length < min) throw new ArgError(`missing ${what}`);
  return { values, positional };
}

/** Makes an uncaught error or rejection exit 2 (a crash), with the script's name. */
export function crashExits2(name) {
  const crash = (e) => {
    console.error(`${name}: crashed: ${e?.stack || e}`);
    process.exit(2);
  };
  process.on('uncaughtException', crash);
  process.on('unhandledRejection', crash);
}

/**
 * A crash (a bug or the system), not a script's own refusal: a TypeError, ReferenceError,
 * RangeError or SyntaxError, or a system error (a string code such as ENOENT). A script that
 * catches errors itself exits 2 on these and 1 on its refusals.
 */
export const isCrash = (e) => e instanceof TypeError || e instanceof ReferenceError || e instanceof RangeError || e instanceof SyntaxError || typeof e?.code === 'string';

/**
 * A script's entry: crash handling, then its argv parsed against SPECS[name]. A bad argument
 * prints `<name>: <problem>` and the usage and exits 2; --help prints the usage and exits 0.
 */
export function cli(name, argv = process.argv.slice(2)) {
  const spec = SPECS[name];
  if (!spec) throw new Error(`args.mjs: no spec for ${name}`);
  crashExits2(name);
  let r;
  try { r = parseArgs(argv, spec); } catch (e) {
    if (!(e instanceof ArgError)) throw e;
    usageError(name, e.message);
  }
  if (r.values.help) { console.log(spec.usage); process.exit(0); }
  return r;
}

/** Prints `<name>: <msg>` and the script's usage, and exits 2. For checks a script makes after parsing. */
export function usageError(name, msg) {
  console.error(`${name}: ${msg}\n${SPECS[name].usage}`);
  process.exit(2);
}
