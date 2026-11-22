#!/usr/bin/env node
/**
 * staging-run.mjs: the production bar's staging run (skills/convert-mockup/references/production-bar.md): the built app,
 * served against a backend, driven through its flows once, after the contract is checked for drift.
 *
 *   node staging-run.mjs --url <served app> --flows <staging-flows.json> --contract <the app's openapi>
 *                        --live-contract <file or URL> [--build <dist/index.html | .next/BUILD_ID>]
 *                        [--stub | --sample] [--api <origin>] [--record <file>]
 *
 * 1. Drift first: the app's contract against the backend's live one (lib/production.mjs
 *    contractDiff). A breaking change stops the run: the failures that follow would be drift, not
 *    the app.
 * 2. The flows, in order, in one browser session (so the first one usually signs in):
 *      { "flows": [ { "name": "sign in", "path": "/", "steps": [ ...the config's step forms... ],
 *                     "expect": { "path": "/dashboard", "text": "Dashboard", "request": "POST /api/v1/x" },
 *                     "allowStatus": [401] } ] }
 *    A path is on the app (--url); with --api, a flow may name a URL on the API's origin instead
 *    (a sign-out page it serves). Any other URL is refused (exit 2). expect.path is met on the
 *    origin the flow started on (the app's, for a flow with no path), never on another.
 *    With --sample, `request` may also be met by a request the app's own server made (a
 *    server-rendered app reads on the server): the run reads the backend's numbered log of /api
 *    answers (stats.servedLog) before and after each flow, and those answers are held to the same
 *    allowStatus rule as the browser's. The flow's record says which side made the request.
 *    Every flow asserts something: expect has a path, a text or a request (and no other key), else
 *    the run exits 2 before it starts; a flow that only loads a page proves nothing.
 *    A flow fails on: an expected path, text or request (with a 2xx answer) not seen; a response of
 *    400 or more not in allowStatus; a console error; a CSP violation; any request for the mock
 *    service worker (a mocked build is not a staging build).
 * --stub marks the run as one against a stub (it resets it first with POST /__stub/reset, and reads
 * its /__stub/stats after): it proves
 * the frontend's half (cookies sent, CSRF copied, no mocks, headers served), never the backend's.
 * --sample marks the run as one against the engine's sample backend (templates/sample-backend): a
 * server written from the contract, not from the app's mocks, that validates every request and
 * response against it and enforces sessions, CSRF and permissions itself. It resets it first with
 * POST /__sample/reset and reads /__sample/stats after; the run fails when the backend counted a
 * request or a response outside the contract, or an operation it has no handler for. It proves
 * the frontend against an independent backend; the real backend still owes its own run.
 * --api names the API's origin when the app calls one on another origin (VITE_API_BASE_URL, same
 * site: app.example.com and api.example.com): the reset and stats go there, its answers are checked
 * as the app's own are, and the record's crossOrigin says which of the API's cookies the app's
 * page could read (none, when they are its own host's: the CSRF token then reached the app only in
 * the X-CSRF-Token response header). Default: the app's own origin.
 * Both contracts must be OpenAPI 3.x with paths, else exit 2.
 * --build names the production build that is served (dist/index.html for Vite, .next/BUILD_ID for
 * Next.js): its sha256 goes in the record, so production-bar.mjs can tell a run of an older build.
 * --record writes { date, url, api, kind (stub, sample or backend), stub, contract: { file, sha256 },
 * build: { kind, file, sha256 } (with --build), drift, flows, stubStats, sampleStats, ok }.
 * --save-session <file> keeps the session the flows signed in with, for perf-budget.mjs --session.
 * Exit 0 every flow passed, 1 drift or a flow failed, 2 bad arguments (lib/args.mjs) or a crash.
 */
import './lib/browsers-env.mjs'; // first: playwright reads its browsers path when it loads
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { basename } from 'node:path';
import { chromium } from 'playwright';
import { parse } from 'yaml';
import { contractDiff, openapiProblems, sha256 } from './lib/production.mjs';
import { runSteps, settle } from './lib/screens.mjs';
import { cli, usageError } from './lib/args.mjs';

const { values: flags } = cli('staging-run');
const opt = (n) => flags[n];
const fail = (m) => { console.error(`staging-run: ${m}`); process.exit(2); };
for (const k of ['url', 'flows', 'contract', 'live-contract']) if (!opt(k)) usageError('staging-run', `--${k} is required`);
const base = opt('url').replace(/\/$/, '');
const api = (opt('api') ?? base).replace(/\/$/, '');
let origins;
try { origins = new Set([new URL(base).origin, new URL(api).origin]); } catch (e) { fail(`--url or --api: ${e.message}`); }
const crossOrigin = origins.size > 1;
const stub = Boolean(flags.stub);
const sample = Boolean(flags.sample);
if (stub && sample) fail('--stub and --sample: one backend at a time');
let flows, contractBytes;
try { flows = JSON.parse(readFileSync(opt('flows'), 'utf8')).flows; contractBytes = readFileSync(opt('contract')); } catch (e) { fail(e.message); }
if (!Array.isArray(flows) || !flows.length) fail(`${opt('flows')}: no flows`);
// A flow's path is on the app; an absolute URL is allowed only on the app's or the API's origin (a
// sign-out page the API serves, with the API on another origin).
function targetOf(path) {
  if (path.startsWith('/')) return `${base}${path}`;
  try {
    return origins.has(new URL(path).origin) ? new URL(path).href : null;
  } catch {
    return null;
  }
}
// Each flow asserts at least one thing, with keys the run knows.
const EXPECT = ['path', 'text', 'request'];
const flowProblems = flows.flatMap((f, i) => {
  const at = `flow ${i + 1} (${f?.name ?? 'unnamed'})`;
  const e = f?.expect;
  if (e !== undefined && (e === null || typeof e !== 'object' || Array.isArray(e))) return [`${at}: expect is not an object`];
  const unknown = Object.keys(e || {}).filter((k) => !EXPECT.includes(k));
  if (unknown.length) return [`${at}: expect has unknown key ${unknown.join(', ')} (want ${EXPECT.join(', ')})`];
  if (!EXPECT.some((k) => typeof e?.[k] === 'string' && e[k].trim())) return [`${at}: no assertion: give expect a path, text or request`];
  if (e.request && !/^[A-Z]+ \/\S*$/.test(e.request)) return [`${at}: expect.request "${e.request}" is not "METHOD /path"`];
  if (f.path !== undefined && !(typeof f.path === 'string' && (f.path.startsWith('/') || targetOf(f.path))))
    return [`${at}: path "${f.path}" is neither a path on the app nor a URL on the app's or the API's origin`];
  return [];
});
if (flowProblems.length) fail(`${opt('flows')}: ${flowProblems.join('; ')}`);
let build = null;
if (opt('build')) {
  if (!existsSync(opt('build'))) fail(`--build ${opt('build')}: not found (dist/index.html or .next/BUILD_ID of the served build)`);
  build = { kind: basename(opt('build')) === 'BUILD_ID' ? 'next' : 'vite', file: opt('build'), sha256: sha256(readFileSync(opt('build'))) };
} else console.log('staging-run: no --build: the record is not bound to a build (production-bar notes it as unbound)');

const record = { date: new Date().toISOString(), url: base, api, kind: stub ? 'stub' : sample ? 'sample' : 'backend', stub, contract: { file: opt('contract'), sha256: sha256(contractBytes) }, ...(build ? { build } : {}), drift: null, flows: [], stubStats: null, sampleStats: null, ok: false };
const done = (code) => {
  if (opt('record')) writeFileSync(opt('record'), `${JSON.stringify(record, null, 2)}\n`);
  process.exit(code);
};

let live;
try {
  const where = opt('live-contract');
  if (/^https?:\/\//.test(where)) {
    const r = await fetch(where);
    if (!r.ok) throw new Error(`${where}: HTTP ${r.status}`);
    live = Buffer.from(await r.arrayBuffer());
  } else live = readFileSync(where);
} catch (e) { fail(`--live-contract: ${e.message}`); }
const docs = {};
for (const [flag, bytes] of [['contract', contractBytes], ['live-contract', live]]) {
  try { docs[flag] = parse(bytes.toString('utf8')); } catch (e) { fail(`--${flag} ${opt(flag)}: does not parse: ${e.message.split('\n')[0]}`); }
  const p = openapiProblems(docs[flag]);
  if (p.length) fail(`--${flag} ${opt(flag)} is not an OpenAPI 3.x document: ${p.join('; ')}`);
}
const drift = contractDiff(docs.contract, docs['live-contract']);
record.drift = { liveSha: sha256(live), ...drift };
for (const b of drift.breaking) console.log(`drift: breaking: ${b}`);
console.log(`drift: ${drift.breaking.length} breaking, ${drift.additive.length} additive`);
if (drift.breaking.length) { console.log('staging-run: stopped: the live contract breaks the app\'s; agree it, regenerate, then run again'); done(1); }

if (stub) await fetch(`${api}/__stub/reset`, { method: 'POST' }).catch(() => console.log('staging-run: the stub has no /__stub/reset; its data carries over from earlier runs'));
if (sample) {
  const r = await fetch(`${api}/__sample/reset`, { method: 'POST' }).catch(() => null);
  if (!r || r.status !== 204) fail('--sample: POST /__sample/reset did not answer 204: start the sample backend with --dev');
}
const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
await ctx.addInitScript(() => document.addEventListener('securitypolicyviolation', (e) => console.error(`CSP violation: ${e.violatedDirective} blocked ${e.blockedURI || 'inline'}`)));
const page = await ctx.newPage();
let current = null;
const seen = { api: new Set(), readable: new Set() };
page.on('console', (m) => { if (m.type() === 'error' && current) current.console.push(m.text()); });
page.on('pageerror', (e) => { if (current) current.console.push(`page error: ${e.message}`); });
page.on('request', (r) => { if (current && /mockServiceWorker/.test(r.url())) current.mock = true; });
page.on('response', (r) => { if (current && origins.has(new URL(r.url()).origin)) current.responses.push({ method: r.request().method(), path: new URL(r.url()).pathname, status: r.status() }); });
try {
  // The backend's own log of /api answers, so a request the app's server made counts (--sample).
  const servedLog = async () => (sample ? await fetch(`${api}/__sample/stats`).then((r) => r.json()).catch(() => null) : null);
  for (const f of flows) {
    current = { console: [], responses: [], mock: false };
    const problems = [];
    const startedAt = (await servedLog())?.served ?? null;
    let server = [];
    try {
      if (f.path) { await page.goto(targetOf(f.path), { waitUntil: 'load' }); await settle(page); }
      await runSteps(page, f.steps || []);
      await settle(page);
      const e = f.expect || {};
      // On the app's origin, or the API's for a flow that starts there: with the API on another
      // origin, the API's own copy of a page is not the app.
      if (e.path) {
        const origin = f.path && !f.path.startsWith('/') ? new URL(f.path).origin : new URL(base).origin;
        const where = () => { const u = new URL(page.url()); return u.origin === origin ? u.pathname : `${u.origin}${u.pathname}`; };
        await page.waitForURL((u) => u.origin === origin && u.pathname === e.path, { timeout: 5000 }).catch(() => problems.push(`expected to be on ${e.path}, on ${where()}`));
      }
      if (e.text && !(await page.getByText(e.text, { exact: false }).first().isVisible().catch(() => false))) problems.push(`"${e.text}" is not on the page`);
      if (startedAt !== null) {
        // The backend's answers in this flow that the browser did not see: the app's server made them.
        const log = (await servedLog())?.servedLog ?? [];
        const browserSaw = [...current.responses];
        server = log.filter((x) => x.n > startedAt).filter((x) => {
          const i = browserSaw.findIndex((r) => r.method === x.method && r.path === x.path && r.status === x.status);
          if (i < 0) return true;
          browserSaw.splice(i, 1);
          return false;
        });
      }
      if (e.request) {
        const [method, path] = e.request.split(' ');
        // A successful answer meets it wherever it was made; else the first, to say what it answered.
        const all = [...current.responses, ...server].filter((r) => r.method === method && r.path === path);
        const hit = all.find((r) => r.status < 300) ?? all[0];
        if (!hit) problems.push(`no ${e.request} request`);
        else if (hit.status >= 300) problems.push(`${e.request} answered ${hit.status}`);
      }
    } catch (err) { problems.push(String(err.message || err).split('\n')[0]); }
    const allow = new Set(f.allowStatus || []);
    for (const r of current.responses) if (r.status >= 400 && !allow.has(r.status)) problems.push(`${r.method} ${r.path} answered ${r.status}`);
    for (const r of server) if (r.status >= 400 && !allow.has(r.status)) problems.push(`${r.method} ${r.path} answered ${r.status} (made by the app's server)`);
    for (const c of current.console) if (!(allow.size && /status of (\d+)/.test(c) && allow.has(Number(c.match(/status of (\d+)/)[1])))) problems.push(`console: ${c.slice(0, 160)}`);
    if (current.mock) problems.push('the page asked for the mock service worker: this is a mocked build');
    if (crossOrigin) {
      // After every flow: which of the API's cookies the app's page could read (none, when they
      // are its host's own).
      const names = (await ctx.cookies(api)).map((c) => c.name);
      const readable = await page.evaluate(() => document.cookie.split('; ').filter(Boolean).map((c) => c.split('=')[0])).catch(() => []);
      for (const n of names) { seen.api.add(n); if (readable.includes(n)) seen.readable.add(n); }
    }
    record.flows.push({ name: f.name, ok: !problems.length, problems, requests: current.responses.length, ...(startedAt !== null ? { serverRequests: server.length } : {}) });
    console.log(`${problems.length ? 'fail' : 'ok  '}  ${f.name}${problems.length ? `\n      ${problems.join('\n      ')}` : ''}`);
  }
  if (crossOrigin) {
    record.crossOrigin = { app: new URL(base).origin, api: new URL(api).origin, apiCookies: [...seen.api], readableByApp: [...seen.readable] };
    console.log(`cross-origin: the API's cookies ${record.crossOrigin.apiCookies.join(', ') || '(none)'}; readable by the app: ${record.crossOrigin.readableByApp.join(', ') || 'none'}`);
  }
  if (opt('save-session')) await ctx.storageState({ path: opt('save-session') });
} finally { await browser.close(); }
if (stub) record.stubStats = await fetch(`${api}/__stub/stats`).then((r) => r.json()).catch(() => null);
let breaches = [];
if (sample) {
  record.sampleStats = await fetch(`${api}/__sample/stats`).then((r) => r.json()).catch(() => null);
  const st = record.sampleStats;
  if (!st) breaches = ['the sample backend did not answer /__sample/stats'];
  else {
    if (st.invalidRequests) breaches.push(`${st.invalidRequests} request(s) outside the contract`);
    if (st.contractViolations) breaches.push(`${st.contractViolations} response(s) outside the contract`);
    if (st.notImplemented) breaches.push(`${st.notImplemented} call(s) to an operation with no handler`);
    for (const v of st.violations ?? []) console.log(`breach: ${v.operationId} ${v.side}: ${v.problems.join('; ')}`);
  }
  record.breaches = breaches;
}
record.ok = record.flows.every((f) => f.ok) && !breaches.length;
const passed = record.flows.filter((f) => f.ok).length;
const st = record.sampleStats;
console.log(`staging-run: ${passed}/${record.flows.length} flows passed${stub ? ' (against a stub: the frontend half only)' : ''}${sample ? ' (against the sample backend, not the real one)' : ''}${record.stubStats ? `; stub refused ${record.stubStats.noSession} without a session, ${record.stubStats.csrfRefused} of ${record.stubStats.csrfChecked} on CSRF` : ''}${st ? `; ${st.requests} API requests, all checked against the contract; refused ${st.noSession} without a session, ${st.forbidden} forbidden, ${st.csrfRefused} of ${st.csrfChecked} on CSRF` : ''}${breaches.length ? `; contract breaches: ${breaches.join(', ')}` : ''}`);
done(record.ok ? 0 : 1);
