#!/usr/bin/env node
/**
 * signoff.mjs: records that the client signed the mockup off, as it is now (skills/mockup/references/signoff.md).
 *
 *   node signoff.mjs <mockup-dir> --by <who signed off> [--date YYYY-MM-DD] [--note <text>]
 *                    [--docs <docs_root>/mockups/<name>] [--freeze <dir>]
 *
 * Refuses (exit 1, nothing written) unless:
 *   - the config lists at least one screen (nothing else would be signed off);
 *   - the config is valid and every decision is answered or deferred (check-config.mjs
 *     --ready-to-port's decision lines), the contract above all: it cannot stay deferred past here;
 *   - pins.clock, pins.seed and timezoneId are set, so the signed-off screens can be reproduced;
 *   - the contract is there and every fixture it maps validates (lib/signoff.mjs).
 * Then appends a round to <mockup>/docs/signoff.json: who, the date, the note, the screens and
 * states signed off, the pins, the contract's path, version and sha256, a sha256 per file of the
 * mockup and the design part of mockup.config.json (the freeze; port-only answers and gate tuning
 * are not frozen). Round 1 is the first sign-off; a change after it is signed off as the next
 * round, listing the files that changed. With --docs, also writes <docs>/signoff.md from the record
 * (generated: edit the record, not the page). With --freeze, copies the frozen files and the
 * contract to <dir>, which must not exist yet (large ports run every tool on that copy). A re-run on
 * a mockup unchanged since its last round records nothing new ("unchanged since round N; no new
 * round") but still honours --docs and --freeze, from the last round.
 * Each round records the manifest rule it was hashed under (manifestVersion, lib/signoff.mjs): a
 * mockup is compared with its last round under that round's rule, so an older round is not
 * reported changed by files the newer rule hashes (dotfiles).
 * Run the checks in skills/mockup/references/step-detail.md first: this records a sign-off, it does not judge one.
 * Exit 0 written, 1 refused, 2 bad arguments (lib/args.mjs; a --date that is not a calendar date),
 * no config, a config that is not JSON or not a JSON object, or a crash.
 */
import { cpSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { configProblems, configLocale, configZone, isCalendarDate, isConfigObject, openDecisions } from './lib/project.mjs';
import { MANIFEST_VERSION, NO_SCREENS, RECORD, checkContract, designConfig, designConfigDiff, manifest, manifestDiff, readRecord } from './lib/signoff.mjs';
import { casesFor } from './lib/screens.mjs';
import { cli, usageError } from './lib/args.mjs';

const { values: flags, positional } = cli('signoff');
const opt = (name) => flags[name];
const bad = (msg) => usageError('signoff', msg);
const dir = resolve(positional[0]);
const by = opt('by');
if (!by) bad('--by is required: who signed the mockup off');
const date = opt('date') ?? new Date().toISOString().slice(0, 10);
if (!isCalendarDate(date)) bad(`--date ${date} is not a calendar date in YYYY-MM-DD`);
const cfgFile = join(dir, 'mockup.config.json');
if (!existsSync(cfgFile)) bad(`no mockup.config.json in ${dir}`);
let config;
try { config = JSON.parse(readFileSync(cfgFile, 'utf8')); } catch (e) { bad(`mockup.config.json is not valid JSON: ${e.message}`); }
if (!isConfigObject(config)) bad('mockup.config.json is not a JSON object');

const refusals = [];
for (const p of configProblems(config)) refusals.push(`config: ${p}`);
if (!casesFor(config).length) refusals.push(`screens: ${NO_SCREENS}`);
for (const o of openDecisions(config).open) refusals.push(`open: ${o.field}: ${o.detail}`);
if (!config.pins?.clock || config.pins?.seed === undefined) refusals.push('pins: set pins.clock and pins.seed, so the signed-off screens can be captured again exactly');
if (!config.timezoneId) refusals.push('timezoneId: set the business time zone (intake question 7)');
const contract = checkContract(dir, config);
for (const p of contract.problems) refusals.push(`contract: ${p}`);
for (const s of contract.stray || []) refusals.push(`contract: ${s}; a code generator will refuse the document`);
const freeze = opt('freeze') && resolve(opt('freeze'));
if (freeze && existsSync(freeze)) refusals.push(`--freeze ${freeze} exists; a frozen copy is never written over`);
else if (freeze && !relative(dir, freeze).startsWith('..') && !relative(dir, freeze).startsWith(sep)) refusals.push(`--freeze ${freeze} is inside the mockup; the copy would join the next round's files`);
let record;
try { record = readRecord(dir) ?? { rounds: [] }; } catch (e) { refusals.push(`${RECORD} is not valid JSON: ${e.message}`); }
if (refusals.length) {
  for (const r of refusals) console.log(`refused: ${r}`);
  console.log(`not signed off: ${refusals.length} to fix first; nothing written`);
  process.exit(1);
}

const files = manifest(dir, { exclude: [contract.path] });
const prev = record.rounds[record.rounds.length - 1];
// Compared under the last round's own rule: a round from before dotfiles were hashed is not
// changed by a dotfile it never covered.
const diff = prev ? manifestDiff(prev.files || {}, manifest(dir, { exclude: [contract.path], version: prev.manifestVersion ?? 1 })) : null;
const contractChanged = Boolean(prev && prev.contract?.sha256 !== contract.sha256);
const design = designConfig(config);
const configKeys = prev ? designConfigDiff(prev.config, design) : [];
if (prev && !diff.count && !contractChanged && !configKeys.length) {
  console.log(`unchanged since round ${prev.round} (${prev.date}, ${prev.by}); no new round`);
  outputs(prev.files || {});
  process.exit(0);
}
const viewports = (config.viewports || []).map((v) => v.name);
const cases = casesFor(config);
const round = {
  round: (prev?.round ?? 0) + 1,
  by,
  date,
  ...(opt('note') ? { note: opt('note') } : {}),
  technicalOwner: config.project?.people?.technicalOwner ?? null,
  pins: { clock: config.pins.clock, seed: config.pins.seed, timezoneId: configZone(config), locale: configLocale(config) },
  viewports,
  screens: cases,
  contract: { path: contract.path, version: contract.version, sha256: contract.sha256, mapped: contract.mapped.map(({ schema, fixture, count }) => ({ schema, fixture, count })) },
  ...(diff ? { changedSinceLast: { ...diff, count: undefined, config: configKeys, contract: contractChanged } } : {}),
  config: design,
  manifestVersion: MANIFEST_VERSION,
  files,
};
record.rounds.push(round);
mkdirSync(join(dir, 'docs'), { recursive: true });
writeFileSync(join(dir, RECORD), `${JSON.stringify(record, null, 2)}\n`);
console.log(`signed off: round ${round.round} (${date}, ${by}): ${cases.length} screens and states at ${viewports.length} viewports, ${Object.keys(files).length} files frozen, contract ${contract.path}${contract.version ? ` ${contract.version}` : ''}`);
if (diff) console.log(`  since round ${prev.round}: ${diff.changed.length} changed, ${diff.added.length} added, ${diff.removed.length} removed${configKeys.length ? `, config ${configKeys.join(', ')}` : ''}${contractChanged ? ', the contract changed' : ''}`);
for (const w of contract.warnings) console.log(`  warning: ${w}`);
console.log(`  -> ${RECORD}`);

outputs(files);

/** --docs and --freeze, from the record as it now is; frozen are the last round's files. */
function outputs(frozen) {
  if (opt('docs')) {
    const out = join(resolve(opt('docs')), 'signoff.md');
    mkdirSync(dirname(out), { recursive: true });
    writeFileSync(out, renderPage(config, record));
    console.log(`  -> ${out}`);
  }
  if (freeze) {
    mkdirSync(freeze, { recursive: true });
    for (const f of [...Object.keys(frozen), 'mockup.config.json', contract.path, RECORD]) cpSync(join(dir, f), join(freeze, f), { recursive: true });
    console.log(`  frozen copy -> ${freeze}`);
  }
}

function renderPage(cfg, rec) {
  const last = rec.rounds[rec.rounds.length - 1];
  const name = cfg.name || 'mockup';
  const states = new Map();
  for (const c of last.screens) states.set(c.name, [...(states.get(c.name) || []), c.state]);
  return [
    `# Sign-off: ${name}`,
    '',
    `Generated by signoff.mjs from the mockup's \`${RECORD}\`; edit the record, not this page.`,
    '',
    '| | |',
    '|---|---|',
    `| Signed off by | ${last.by} |`,
    `| Date | ${last.date} |`,
    `| Round | ${last.round} |`,
    `| Technical owner | ${last.technicalOwner ?? 'not recorded'} |`,
    `| Pins | clock ${last.pins.clock}, seed ${last.pins.seed}, zone ${last.pins.timezoneId}, locale ${last.pins.locale} |`,
    `| Viewports | ${last.viewports.join(', ')} |`,
    `| Contract | \`${last.contract.path}\`${last.contract.version ? ` ${last.contract.version}` : ''}, sha256 \`${last.contract.sha256.slice(0, 16)}\` |`,
    `| Frozen files | ${Object.keys(last.files).length} |`,
    ...(last.note ? [`| Note | ${last.note} |`] : []),
    '',
    '## Screens and states signed off',
    '',
    '| Screen | States |',
    '|---|---|',
    ...[...states].map(([s, st]) => `| ${s} | ${st.join(', ')} |`),
    '',
    '## Fixtures checked against the contract',
    '',
    '| Schema | Fixture | Values |',
    '|---|---|---|',
    ...last.contract.mapped.map((m) => `| ${m.schema} | \`${m.fixture}\` | ${m.count} |`),
    '',
    '## Rounds',
    '',
    '| Round | Date | By | Changed | Note |',
    '|---|---|---|---|---|',
    ...rec.rounds.map((r) => `| ${r.round} | ${r.date} | ${r.by} | ${r.changedSinceLast ? `${r.changedSinceLast.changed.length} changed, ${r.changedSinceLast.added.length} added, ${r.changedSinceLast.removed.length} removed${r.changedSinceLast.config?.length ? `, config ${r.changedSinceLast.config.join(', ')}` : ''}${r.changedSinceLast.contract ? ', contract' : ''}` : 'first sign-off'} | ${r.note ?? ''} |`),
    '',
  ].join('\n');
}
