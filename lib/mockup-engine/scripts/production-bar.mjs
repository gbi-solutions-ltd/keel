#!/usr/bin/env node
/**
 * production-bar.mjs: checks the production bar on a converted app (skills/convert-mockup/references/production-bar.md).
 * It reads records the other tools wrote and the repo's files; it runs nothing heavy itself, and it
 * never does keel security-audit's or setup-deployment's work, only checks that it was done.
 *
 *   node production-bar.mjs <app> [--docs <docs_root>] [--gaps <gaps.md>] [--url <served app>]
 *                           [--contract <path in the app, default api/openapi.yaml>] [--env NAME=value ...]
 *
 * <docs_root> is the app's .keel/profile.json docs_root, else docs. Records under
 * <docs_root>/production/:
 *   headers.json  headers.mjs --check <url> --record: ok, and from the current security-headers.json,
 *                 which holds the minimum set (lib/production.mjs minimumHeaderProblems). With --url,
 *                 the check is run again now instead: 2xx, every header, {origin:VAR} filled from the
 *                 environment and --env, a nonce fresh on each of two fetches
 *   perf.json     perf-budget.mjs --record: no problem, from the current build (dist/index.html), with
 *                 initial JS measured, and vitals on at least one screen when vitals were measured
 *   staging.json  staging-run.mjs --record: every flow passed, no breaking drift, on the current
 *                 contract (--contract, default api/openapi.yaml) and the current build (its build
 *                 field, staging-run.mjs --build; a record without one is a note, "unbound")
 * And:
 *   gaps          <docs_root>/mockups/<name>/gaps.md (the only one, or --gaps): every blocking and
 *                 enforcement row owned and dated, and each table with a row or "None" under its
 *                 heading (lib/production.mjs gapProblems)
 *   security      the latest keel security-audit report, <docs_root>/audits/YYYY-MM-DD-security.md, with
 *                 its "| Findings |" row and no critical or high finding open (auditProblems)
 *   deploy        a CI definition in the repo with a job or step that deploys, keel setup-deployment's
 *                 <docs_root>/runbooks/deploy.md (not empty), or a recorded handoff,
 *                 <docs_root>/production/deploy-handoff.md, with a body under each of build command,
 *                 environment variables, headers and health check
 * Prints "ok: <item>" or "not met: <item>: <why>" per item, "note:" for what is met but partial (a
 * staging run against a stub or the sample backend), then "production bar: met" or "not met, N". Exit 0 met, 1 not, 2 bad
 * arguments (lib/args.mjs; the app folder must exist) or a crash.
 */
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join, relative, resolve } from 'node:path';
import { auditProblems, checkServed, gapProblems, handoffProblems, loadHeaders, minimumHeaderProblems, sha256 } from './lib/production.mjs';
import { cli, usageError } from './lib/args.mjs';

const { values: flags, positional: [appArg] } = cli('production-bar');
const opt = (n) => flags[n];
const app = resolve(appArg);
if (!existsSync(app)) usageError('production-bar', `${app}: not found`);
let docsRoot = 'docs';
try { docsRoot = JSON.parse(readFileSync(join(app, '.keel/profile.json'), 'utf8')).docs_root || 'docs'; } catch { /* no keel profile: docs */ }
const docs = resolve(app, opt('docs') ?? docsRoot);
const prod = join(docs, 'production');
const read = (f) => { try { return JSON.parse(readFileSync(f, 'utf8')); } catch { return null; } };
const results = [];
const ok = (item, detail = '') => results.push({ item, ok: true, detail });
const notMet = (item, detail) => results.push({ item, ok: false, detail });
const notes = [];
const env = { ...process.env };
for (const e of flags.env ?? []) { const [k, ...v] = e.split('='); if (!k || !v.length) usageError('production-bar', `--env ${e}: want NAME=value`); env[k] = v.join('='); }

// headers
const headersFile = join(app, 'security-headers.json');
let spec = null, specError = null;
try { spec = existsSync(headersFile) ? loadHeaders(headersFile) : null; } catch (e) { specError = e.message; }
const minimum = spec ? minimumHeaderProblems(spec) : [];
if (!existsSync(headersFile)) notMet('headers', 'no security-headers.json: the app\'s headers need one source the server and the check share');
else if (specError) notMet('headers', specError);
else if (minimum.length) notMet('headers', `security-headers.json lacks the minimum set: ${minimum.join('; ')}`);
else if (opt('url')) {
  const res = await checkServed(spec, opt('url'), { env }).catch((e) => ({ error: e.message }));
  if (res.error) notMet('headers', `${opt('url')}: ${res.error}`);
  else res.problems.length ? notMet('headers', res.problems.join('; ')) : ok('headers', `all match on ${opt('url')}`);
} else {
  const r = read(join(prod, 'headers.json'));
  if (!r) notMet('headers', `no ${docsRoot}/production/headers.json (headers.mjs --check <served url> --record)`);
  else if (r.headersSha !== sha256(readFileSync(headersFile))) notMet('headers', 'security-headers.json changed since the recorded check; check the served app again');
  else if (!r.ok) notMet('headers', r.problems.join('; '));
  else ok('headers', `matched on ${r.url}, ${r.date.slice(0, 10)}`);
}

// performance budget
const perf = read(join(prod, 'perf.json'));
// A Vite build is identified by dist/index.html, a Next.js build by .next/BUILD_ID.
const index = perf?.build === 'next' ? join(app, '.next', 'BUILD_ID') : join(app, 'dist', 'index.html');
if (!perf) notMet('performance', `no ${docsRoot}/production/perf.json (perf-budget.mjs --record)`);
else if (!existsSync(index) || perf.buildSha !== sha256(readFileSync(index))) notMet('performance', `the recorded budget run is not of the current production build (${relative(app, index)} differs); build and measure again`);
else if (perf.problems.length) notMet('performance', perf.problems.join('; '));
else if (!(perf.bundle?.initialJsKb > 0)) notMet('performance', 'the record measured no initial JS: run perf-budget.mjs on the production build again');
else if (Array.isArray(perf.vitals) && !perf.vitals.length) notMet('performance', 'the record measured vitals on no screen: run perf-budget.mjs --url with a screen selected');
else {
  ok('performance', `initial JS ${perf.bundle.initialJsKb} KB, CSS ${perf.bundle.initialCssKb} KB gzip${perf.vitals ? `; ${perf.vitals.length} screens measured` : ''}`);
  if (!perf.vitals) notes.push('performance: no vitals measured (perf-budget.mjs --url); bundle only');
  for (const w of perf.warnings || []) notes.push(`performance: ${w}`);
}

// staging run
const staging = read(join(prod, 'staging.json'));
const contractFile = join(app, opt('contract') ?? 'api/openapi.yaml');
const stagingBuild = staging?.build?.kind === 'next' ? join(app, '.next', 'BUILD_ID') : join(app, 'dist', 'index.html');
if (!staging) notMet('staging', `no ${docsRoot}/production/staging.json (staging-run.mjs --record)`);
else if (!existsSync(contractFile) || staging.contract?.sha256 !== sha256(readFileSync(contractFile))) notMet('staging', 'the staging run was on another contract than the app\'s current one; run it again');
else if (staging.build && (!existsSync(stagingBuild) || staging.build.sha256 !== sha256(readFileSync(stagingBuild)))) notMet('staging', `the staging run was of another build than the current one (${relative(app, stagingBuild)} differs); run it again`);
else if (staging.drift?.breaking?.length) notMet('staging', `breaking drift: ${staging.drift.breaking.join('; ')}`);
else if (!staging.ok) notMet('staging', staging.flows.filter((f) => !f.ok).map((f) => `${f.name}: ${f.problems[0]}`).join('; '));
else {
  ok('staging', `${staging.flows.length} flows passed on ${staging.url}, ${staging.date.slice(0, 10)}`);
  if (!staging.build) notes.push('staging: unbound: the record names no build (staging-run.mjs --build), so a frontend change after the run is not caught; run it again with --build');
  if (staging.stub) notes.push('staging: run against a stub, which proves the frontend half only; the run against the real staging backend is still owed (a blocking gap with an owner and a date)');
  else if (staging.kind === 'sample')
    notes.push(`staging: run against the sample backend (written from the contract, ${staging.sampleStats?.requests ?? 0} API requests checked against it, sessions, CSRF and permissions enforced on its side), which proves the frontend against an independent backend; the run against the real staging backend is still owed (a blocking gap with an owner and a date)`);
}

// gap report
let gapsFile = opt('gaps');
if (!gapsFile) {
  const dir = join(docs, 'mockups');
  const found = existsSync(dir) ? readdirSync(dir).map((n) => join(dir, n, 'gaps.md')).filter(existsSync) : [];
  if (found.length === 1) gapsFile = found[0];
  else if (found.length > 1) notMet('gaps', `${found.length} gap reports under ${docsRoot}/mockups; name one with --gaps`);
  else notMet('gaps', `no ${docsRoot}/mockups/<name>/gaps.md`);
}
if (gapsFile) {
  const g = gapProblems(readFileSync(gapsFile, 'utf8'));
  g.problems.length ? notMet('gaps', `${g.problems.length} problems: ${g.problems.slice(0, 4).join('; ')}${g.problems.length > 4 ? '; ...' : ''}`) : ok('gaps', `${g.blocking} blocking and ${g.enforcement} enforcement rows, each owned and dated`);
}

// security audit
const audits = existsSync(join(docs, 'audits')) ? readdirSync(join(docs, 'audits')).filter((f) => /^\d{4}-\d{2}-\d{2}-security\.md$/.test(f)).sort() : [];
if (!audits.length) notMet('security', `no ${docsRoot}/audits/YYYY-MM-DD-security.md: run keel security-audit on the app`);
else {
  const latest = `${docsRoot}/audits/${audits.at(-1)}`;
  const a = auditProblems(readFileSync(join(docs, 'audits', audits.at(-1)), 'utf8'));
  if (a.problems[0]?.startsWith('not a keel')) notMet('security', `${latest} is ${a.problems[0]}: run keel security-audit on the app`);
  else if (a.problems.length) notMet('security', `${a.problems.join('; ')}, in ${latest}`);
  else ok('security', `keel security-audit report ${latest}, no critical or high finding open`);
}

// deploy
// A CI definition counts only when a job or step deploys: one that only tests is not a deploy.
// Comments are dropped first; a release trigger or a package publish is not a deploy of the app.
const DEPLOYS = /\b(deploy\w*|rsync|scp|kubectl|helm|terraform|pulumi|wrangler|vercel|netlify|flyctl|gh-pages|docker\s+push|aws\s+s3\s+(sync|cp)|gcloud\s+(run|app)|az\s+(webapp|storage|staticwebapp))\b/i; // supply-chain-scan: allow a regex that names deploy commands to recognise a deploy in CI files; it runs none
const ciFiles = ['.github/workflows', '.gitlab-ci.yml', 'Jenkinsfile', 'azure-pipelines.yml', 'bitbucket-pipelines.yml', '.circleci/config.yml'].filter((f) => existsSync(join(app, f)))
  .map((f) => [f, f.endsWith('workflows') ? readdirSync(join(app, f)).filter((x) => /\.ya?ml$/.test(x)).map((x) => join(app, f, x)) : [join(app, f)]]).filter(([, files]) => files.length);
const ci = ciFiles.find(([, files]) => files.some((x) => DEPLOYS.test(readFileSync(x, 'utf8').replace(/(^|\s)(#|\/\/).*$/gm, '$1'))))?.[0];
const runbookFile = join(docs, 'runbooks', 'deploy.md');
const runbook = existsSync(runbookFile) && readFileSync(runbookFile, 'utf8').split(/\r?\n/).some((l) => l.trim() && !l.startsWith('#'));
const handoff = join(prod, 'deploy-handoff.md');
const noCi = ciFiles.length ? `no CI definition that deploys (${ciFiles.map(([f]) => f).join(', ')} has no deploy job or step)` : 'no CI definition';
if (ci || runbook) ok('deploy', ci ? `CI definition ${ci}, with a deploy step` : `${docsRoot}/runbooks/deploy.md (keel setup-deployment)`);
else if (existsSync(handoff)) {
  const h = handoffProblems(readFileSync(handoff, 'utf8'));
  if (h.missing.length) notMet('deploy', `deploy-handoff.md has no section for ${h.missing.join(', ')}`);
  else if (h.empty.length) notMet('deploy', `deploy-handoff.md has an empty section for ${h.empty.join(', ')}`);
  else ok('deploy', `handoff recorded in ${docsRoot}/production/deploy-handoff.md, for keel setup-deployment`);
} else notMet('deploy', `${noCi}, no ${docsRoot}/runbooks/deploy.md and no ${docsRoot}/production/deploy-handoff.md`);

for (const r of results) console.log(r.ok ? `ok: ${r.item}: ${r.detail}` : `not met: ${r.item}: ${r.detail}`);
for (const n of notes) console.log(`note: ${n}`);
const failed = results.filter((r) => !r.ok).length;
console.log(failed ? `production bar: not met, ${failed} of ${results.length}` : `production bar: met (${results.length} items)`);
process.exit(failed ? 1 : 0);
