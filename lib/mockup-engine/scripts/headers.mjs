#!/usr/bin/env node
/**
 * headers.mjs: the app's security headers from one file (lib/production.mjs has its format), for
 * the server and for the check of a served URL (skills/convert-mockup/references/production-bar.md).
 *
 *   node headers.mjs <headers.json> --emit nginx [--env NAME=value ...]
 *       prints an nginx fragment (add_header ... always;); refused when a header needs a nonce,
 *       which only a server that writes each response can serve
 *   node headers.mjs <headers.json> --check <url> [--session <file>] [--env NAME=value ...] [--record <file>]
 *       fetches the URL (no redirects followed) and compares every header with the file; the
 *       answer must be 2xx (a redirect's headers are not the page's), and when the file has
 *       {nonce} the URL is fetched twice and the nonces must differ (a hard-coded one fails); with
 *       --record, writes { date, url, status, ok, problems, headersSha } for production-bar.mjs;
 *       --session sends a saved session's cookies (staging-run.mjs --save-session), for a page
 *       behind sign-in, and fails when none of them is for the URL
 *
 * --env fills {origin:NAME} (default: the process environment). Exit 0 ok, 1 a mismatch (a non-2xx
 * answer included) or a refused emit; 2 when it cannot run (lib/args.mjs's rule): bad arguments
 * (--record without --check), a file that is unreadable, not of the format or names no header, and
 * a URL that cannot be fetched (unreachable, refused).
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { checkServed, emitNginx, loadHeaders, sessionCookie, sha256 } from './lib/production.mjs';
import { cli, usageError } from './lib/args.mjs';

const { values: flags, positional: [file] } = cli('headers');
const opt = (n) => flags[n];
const fail = (m) => { console.error(`headers: ${m}`); process.exit(2); };
if (flags.emit !== undefined && flags.check !== undefined) usageError('headers', 'pass --emit or --check, not both');
for (const f of ['record', 'session']) if (flags[f] !== undefined && flags.check === undefined) usageError('headers', `--${f} applies to --check only`);
let spec;
try { spec = loadHeaders(file); } catch (e) { fail(e.message); }
// An empty set checks nothing and emits nothing: "all 0 match" is not a pass (production-bar.mjs
// holds the file to the minimum set, lib/production.mjs minimumHeaderProblems)
if (!Object.keys(spec.headers).length) fail(`${file}: names no header; list the app's security headers (at least the minimum set: skills/convert-mockup/references/production-bar.md)`);
const env = { ...process.env };
for (const e of flags.env ?? []) { const [k, ...v] = e.split('='); if (!k || !v.length) fail(`--env ${e}: want NAME=value`); env[k] = v.join('='); }

if (opt('emit')) {
  if (opt('emit') !== 'nginx') fail(`--emit ${opt('emit')}: only nginx; hand other targets to keel setup-deployment with this file`);
  try { process.stdout.write(emitNginx(spec, { env })); } catch (e) { console.error(`headers: refused: ${e.message}`); process.exit(1); }
} else if (opt('check')) {
  const url = opt('check');
  let status, problems, cookie;
  if (opt('session')) {
    let state;
    try { state = JSON.parse(readFileSync(opt('session'), 'utf8')); } catch (e) { fail(`--session ${opt('session')}: ${e.message}`); }
    cookie = sessionCookie(state, url);
    if (!cookie) fail(`--session ${opt('session')}: no live cookie in it for ${url}`);
  }
  // Not fetched (unreachable, refused, a bad URL or origin): the check could not run, exit 2
  try { ({ status, problems } = await checkServed(spec, url, { env, cookie })); } catch (e) { console.error(`headers: could not fetch ${url}: ${e.cause?.message ?? e.message}`); process.exit(2); }
  for (const p of problems) console.log(`not ok: ${p}`);
  console.log(problems.length ? `headers: ${problems.length} problem${problems.length > 1 ? 's' : ''} on ${url}` : `headers: all ${Object.keys(spec.headers).length} match on ${url}`);
  if (opt('record')) writeFileSync(opt('record'), `${JSON.stringify({ date: new Date().toISOString(), url, status, ok: !problems.length, problems, headersSha: sha256(readFileSync(file)) }, null, 2)}\n`);
  process.exit(problems.length ? 1 : 0);
} else fail('pass --emit nginx or --check <url>');
