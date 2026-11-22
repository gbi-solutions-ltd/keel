#!/usr/bin/env node
/**
 * contract-diff.mjs: the signed-off contract against a live one, before any run against a real
 * backend (skills/convert-mockup/references/production-bar.md). Breaking changes for a frontend built on the signed-off
 * contract (an operation, schema or property removed, a type changed, a field newly required, an
 * enum value removed) are listed first; additive ones after.
 *
 *   node contract-diff.mjs <signed-off openapi> <live openapi: file or URL> [--record <file>]
 *
 * Both documents must be OpenAPI 3.x with paths, else exit 2 before any diff. The diff goes into each
 * operation (parameters, request body, response codes, their schemas inline or named) and is
 * direction aware (lib/production.mjs contractDiff).
 * With --record, writes { date, signed, signedSha, live, liveSha, breaking, additive }. Exit 0 no
 * breaking change, 1 breaking changes, 2 a document cannot be read or is not OpenAPI 3.x, a bad
 * argument (lib/args.mjs) or a crash.
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { parse } from 'yaml';
import { contractDiff, openapiProblems, sha256 } from './lib/production.mjs';
import { cli } from './lib/args.mjs';

const { values: { record = null }, positional: [signed, live] } = cli('contract-diff');
async function read(where) {
  if (/^https?:\/\//.test(where)) { const r = await fetch(where); if (!r.ok) throw new Error(`${where}: HTTP ${r.status}`); return Buffer.from(await r.arrayBuffer()); }
  return readFileSync(where);
}
let a, b;
try { a = await read(signed); b = await read(live); } catch (e) { console.error(`contract-diff: ${e.message}`); process.exit(2); }
let da, db;
try { da = parse(a.toString('utf8')); db = parse(b.toString('utf8')); } catch (e) { console.error(`contract-diff: does not parse: ${e.message.split('\n')[0]}`); process.exit(2); }
for (const [where, d] of [[signed, da], [live, db]]) {
  const p = openapiProblems(d);
  if (p.length) { console.error(`contract-diff: ${where} is not an OpenAPI 3.x document: ${p.join('; ')}`); process.exit(2); }
}
const { breaking, additive } = contractDiff(da, db);
for (const l of breaking) console.log(`breaking: ${l}`);
for (const l of additive) console.log(`additive: ${l}`);
const same = sha256(a) === sha256(b);
console.log(`contract-diff: ${same ? 'identical' : `${breaking.length} breaking, ${additive.length} additive`} (signed-off ${da.info?.version ?? '?'}, live ${db.info?.version ?? '?'})`);
if (record) writeFileSync(record, `${JSON.stringify({ date: new Date().toISOString(), signed, signedSha: sha256(a), live, liveSha: sha256(b), breaking, additive }, null, 2)}\n`);
process.exit(breaking.length ? 1 : 0);
