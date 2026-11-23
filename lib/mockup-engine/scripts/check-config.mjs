#!/usr/bin/env node
/**
 * check-config.mjs: mockup.config.json alone, with no browser and no pages: the schema
 * (lib/mockup-engine/mockup-config.schema.json) and the decisions a port needs (lib/project.mjs). Run it
 * straight after the intake, before any screen or module file exists; the inventory runs the same
 * checks with the pages once there are some.
 *
 *   node check-config.mjs <mockup-dir> [--ready-to-port]
 *
 * Prints each problem as "config: <path>: <problem>", then "ready to port (decisions only): yes" or
 * "no, N open" (with "not ready: <field>: <why>" lines under --ready-to-port), and each deferral as
 * "deferred: <field>: <owner> by <date>", and "warning: deferred: <field>: overdue since <date>
 * (<owner>); ..." once that date has passed (a warning: the exit code is unchanged). The checklist
 * counts as a decision: an undecided item is open. Then the sign-off (lib/signoff.mjs): "signed
 * off: yes, round N (<date>, <by>)" or "signed off: no", with "not ready: signoff: <problem>" lines
 * under --ready-to-port (no record, no screen in the config, the mockup or the contract changed since
 * the last round, a fixture the contract rejects).
 * For an existing-repo target (lib/target.mjs): "target: existing repo <path>, read: <snapshot,
 * standards>", each disagreement between the repo and the package as "not ready: <field>: <why>"
 * under --ready-to-port, and "note: ..." for what Convert must do with the repo.
 * Exit 1 on any config problem, or with --ready-to-port on anything open, no valid sign-off or a
 * target disagreement; 2 when the config is missing, not JSON or not a JSON object, on a bad
 * argument (lib/args.mjs: an unknown flag such as a mistyped --ready-to-port, a second folder) or a
 * crash.
 */
import { existsSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { configProblems, isConfigObject, openDecisions, overdue } from './lib/project.mjs';
import { checkContract, signoffStatus } from './lib/signoff.mjs';
import { targetStatus } from './lib/target.mjs';
import { cli } from './lib/args.mjs';

const { values: flags, positional } = cli('check-config');
const dir = resolve(positional[0] || '.');
const gate = Boolean(flags['ready-to-port']);
const file = join(dir, 'mockup.config.json');
if (!existsSync(file)) { console.error(`check-config: missing ${file}`); process.exit(2); }
let config;
try { config = JSON.parse(readFileSync(file, 'utf8')); } catch (e) { console.error(`check-config: ${file} is not valid JSON: ${e.message}`); process.exit(2); }
if (!isConfigObject(config)) { console.error(`check-config: ${file} is not a JSON object`); process.exit(2); }

const problems = configProblems(config);
for (const p of problems) console.log(`config: ${p}`);

const { open, deferred } = openDecisions(config);
console.log(`ready to port (decisions only): ${open.length ? `no, ${open.length} open` : 'yes'}${deferred.length ? ` (${deferred.length} deferred)` : ''}`);
if (gate) for (const o of open) console.log(`not ready: ${o.field}: ${o.detail}`);
for (const d of deferred) console.log(`deferred: ${d.field}: ${d.owner} by ${d.by}`);
for (const d of overdue(deferred)) console.log(`warning: deferred: ${d.field}: overdue since ${d.by} (${d.owner}); decide it, or defer it again with a new date`);
const sign = signoffStatus(dir, config);
// Before the first sign-off, the contract's check alone, so it can be tried before signing.
if (!existsSync(join(dir, 'docs/signoff.json')) && config.project?.contract && !config.project.contract.deferred) {
  const c = checkContract(dir, config);
  console.log(`contract: ${c.path ?? 'none'}${c.version ? ` ${c.version}` : ''}: ${c.mapped.length} fixture mappings, ${c.problems.length} problem${c.problems.length === 1 ? '' : 's'}`);
  for (const p of c.problems) console.log(`contract problem: ${p}`);
  for (const w of c.warnings) console.log(`warning: contract: ${w}`);
}
console.log(sign.signed ? `signed off: yes, round ${sign.round} (${sign.date}, ${sign.by})` : `signed off: no${sign.problems.length ? `, ${sign.problems.length} problem${sign.problems.length > 1 ? 's' : ''}` : ''}`);
if (gate) for (const p of sign.problems) console.log(`not ready: signoff: ${p}`);
for (const w of sign.warnings) console.log(`warning: ${w}`);
const target = targetStatus(config, dir);
if (target.path) {
  const read = [target.snapshot?.join(', '), target.standards].filter(Boolean).join(', ');
  console.log(`target: existing repo ${target.path}${read ? `, read: ${read}` : ''}${target.detected?.stack ? `, ${target.detected.stack}` : ''}${target.open.length ? `; ${target.open.length} open` : ''}`);
  if (gate) for (const o of target.open) console.log(`not ready: ${o.field}: ${o.detail}`);
  for (const n of target.notes) console.log(`note: ${n}`);
}
process.exit(problems.length || (gate && (open.length || !sign.signed || target.open.length)) ? 1 : 0);
