/**
 * production.mjs: the pieces of the production bar (skills/convert-mockup/references/production-bar.md) that need no
 * browser: the gap report's owned and dated rows, the app's security headers as one source, and the
 * contract's drift from a live document.
 *
 * Headers file (the app's, e.g. security-headers.json), the single source for `vite preview`, the
 * server or CDN, and the check of a served URL:
 *   { "headers": { "<Name>": "<value>" | ["<part>", ...] } }
 * A list is joined with "; " (a CSP's directives). Two placeholders:
 *   {nonce}           a fresh 'nonce-...' per response: only a server that writes each response can
 *                     serve it; a static host cannot (emitting for one is refused)
 *   {origin:VAR}      the origin of the URL in environment variable VAR, or nothing when unset or
 *                     a path on this origin (the telemetry collector, or VITE_API_BASE_URL, in
 *                     connect-src: an API on another origin is named, '/api' is 'self' already)
 */
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { isCalendarDate } from './project.mjs';

/** The hex sha256 of a buffer or string: the one hash every record and manifest uses. */
export const sha256 = (buf) => createHash('sha256').update(buf).digest('hex');

// --- Gap report -----------------------------------------------------------------------------------

/** The lines of a "## heading" section, up to the next "## " heading. */
function sectionLines(md, heading) {
  const lines = md.split(/\r?\n/);
  const start = lines.findIndex((l) => l.trim().toLowerCase() === `## ${heading}`.toLowerCase());
  if (start < 0) return [];
  const end = lines.findIndex((l, i) => i > start && l.startsWith('## '));
  return lines.slice(start + 1, end < 0 ? lines.length : end);
}

function tableAfter(md, heading) {
  const lines = md.split('\n');
  const start = lines.findIndex((l) => l.trim().toLowerCase() === `## ${heading}`.toLowerCase());
  if (start < 0) return null;
  const rows = [];
  for (let i = start + 1; i < lines.length && !lines[i].startsWith('## '); i++) {
    if (!lines[i].trim().startsWith('|')) { if (rows.length) break; continue; }
    rows.push(lines[i].trim().replace(/^\||\|$/g, '').split(/(?<!\\)\|/).map((c) => c.trim()));
  }
  if (rows.length < 2) return { header: rows[0] || [], rows: [] };
  return { header: rows[0], rows: rows.slice(2) };
}

/**
 * Problems with a gap report's two owned tables: "Blocking go-live" (every row an Owner and a By
 * date) and "Server-side enforcement the frontend assumes" (Owner, By and a Status from the
 * template). Returns { problems, blocking, enforcement } with the row counts.
 */
export function gapProblems(md) {
  const problems = [];
  const owned = (name, required) => {
    const t = tableAfter(md, name);
    if (!t) { problems.push(`gaps: no "## ${name}" section`); return 0; }
    // A section with no rows says so: a line "None" under the heading. Silence is not "none".
    if (!t.rows.length) {
      if (!sectionLines(md, name).some((l) => /^none\.?$/i.test(l.trim()))) problems.push(`gaps: "${name}" has no rows: list each, or write None under the heading`);
      return 0;
    }
    const col = (h) => t.header.findIndex((c) => c.toLowerCase() === h.toLowerCase());
    for (const h of required) if (col(h) < 0) problems.push(`gaps: "${name}" has no ${h} column`);
    if (required.some((h) => col(h) < 0)) return t.rows.length;
    t.rows.forEach((r, i) => {
      const what = `gaps: "${name}" row ${i + 1} (${(r.find((c) => c && !/^\d+$/.test(c)) || '').slice(0, 50)})`;
      const owner = r[col('Owner')] ?? '';
      const by = r[col('By')] ?? '';
      if (!owner || /^[-?]|\{\{|^tbd$/i.test(owner)) problems.push(`${what}: no owner`);
      if (!isCalendarDate(by)) problems.push(`${what}: no date (By is "${by}", want YYYY-MM-DD)`);
      if (col('Status') >= 0 && !['assumed', 'confirmed by backend', 'verified on staging'].includes((r[col('Status')] || '').toLowerCase())) problems.push(`${what}: status "${r[col('Status')]}" is not assumed, confirmed by backend or verified on staging`);
    });
    return t.rows.length;
  };
  const blocking = owned('Blocking go-live', ['Owner', 'By']);
  const enforcement = owned('Server-side enforcement the frontend assumes', ['Owner', 'By', 'Status']);
  return { problems, blocking, enforcement };
}

// --- Security audit and deploy handoff ----------------------------------------------------------------

/**
 * Problems with a keel security-audit report (its report template): the header row
 * "| Findings | N critical, N high, ... |" must be there, every critical and high finding counted
 * must be written out (a "### C-NN" or "### H-NN" section, or one whose Severity row says Critical
 * or High), and each of those must say "**Closed**". A finding listed as a gap is still open.
 * Returns { problems, critical, high }.
 */
export function auditProblems(md) {
  const row = /^\|\s*Findings\s*\|\s*(\d+)\s+critical\s*,\s*(\d+)\s+high\b/im.exec(md);
  if (!row) return { problems: ['not a keel security-audit report (no "| Findings | N critical, N high" row)'], critical: 0, high: 0 };
  const [critical, high] = [Number(row[1]), Number(row[2])];
  const sections = md.split(/^(?=#{2,3} )/m).filter((s) => s.startsWith('### '));
  const severe = sections.filter((s) => /^### [CH]-\d+/.test(s) || /^\|\s*Severity\s*\|\s*(critical|high)\s*\|/im.test(s));
  const open = severe.filter((s) => !/\*\*closed\*\*/i.test(s)).map((s) => s.split('\n')[0].slice(4).trim());
  const problems = [];
  if (critical + high > severe.length) problems.push(`the report counts ${critical + high} critical or high, ${severe.length} written out`);
  if (open.length) problems.push(`${open.length} critical or high finding open: ${open.join('; ')} (close it, then audit again)`);
  return { problems, critical, high };
}

/** The four sections a deploy handoff names (production-bar.md), each with a body: { missing, empty }. */
export function handoffProblems(md) {
  const want = ['build command', 'environment variables', 'headers', 'health check'];
  const lines = md.split(/\r?\n/);
  const at = (h) => lines.findIndex((l) => l.trim().toLowerCase().startsWith(`## ${h}`));
  const body = (i) => { const end = lines.findIndex((l, j) => j > i && /^#{1,2} /.test(l)); return lines.slice(i + 1, end < 0 ? lines.length : end); };
  const missing = want.filter((h) => at(h) < 0);
  const empty = want.filter((h) => at(h) >= 0 && !body(at(h)).some((l) => l.trim()));
  return { missing, empty };
}

// --- Security headers -------------------------------------------------------------------------------

export function loadHeaders(file) {
  const spec = JSON.parse(readFileSync(file, 'utf8'));
  if (!spec || typeof spec.headers !== 'object' || spec.headers === null || Array.isArray(spec.headers)) throw new Error(`${file}: want { "headers": { "<Name>": "<value>" } }`);
  return spec;
}

const joinValue = (v) => (Array.isArray(v) ? v.join('; ') : String(v));
export const usesNonce = (spec) => Object.values(spec.headers).some((v) => joinValue(v).includes('{nonce}'));

function fillOrigins(value, env) {
  return value.replace(/\{origin:([A-Z0-9_]+)\}/g, (_, name) => {
    const v = env[name];
    if (!v || v.startsWith('/')) return '';
    try { return new URL(v).origin; } catch { throw new Error(`${name}=${v} is not a URL, so {origin:${name}} has no origin`); }
  }).replace(/ {2,}/g, ' ').replace(/ ;/g, ';').trim();
}

/** The headers as served: { name: value }, with origins filled from env and {nonce} as given. */
export function renderHeaders(spec, { env = {}, nonce } = {}) {
  const out = {};
  for (const [name, v] of Object.entries(spec.headers)) {
    let value = fillOrigins(joinValue(v), env);
    if (value.includes('{nonce}')) {
      if (!nonce) throw new Error(`${name} needs a per-response nonce; pass one, or serve it from a server that writes each response`);
      value = value.replaceAll('{nonce}', `'nonce-${nonce}'`);
    }
    out[name] = value;
  }
  return out;
}

const norm = (v) => String(v).replace(/\s+/g, ' ').replace(/\s*;\s*/g, '; ').replace(/;\s*$/, '').trim();

const nonceRe = (want) => new RegExp(`^${want.split('{nonce}').map((p) => p.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join("'nonce-([A-Za-z0-9+/=_-]{16,})'")}$`);
const getter = (actual) => (n) => (typeof actual.get === 'function' ? actual.get(n) : actual[n] ?? actual[n.toLowerCase()] ?? Object.entries(actual).find(([k]) => k.toLowerCase() === n.toLowerCase())?.[1]);

/** The nonce a served response carries where the spec has {nonce} (the first match), else null. */
export function servedNonce(spec, actual, { env = {} } = {}) {
  const get = getter(actual);
  for (const [name, v] of Object.entries(spec.headers)) {
    const want = norm(fillOrigins(joinValue(v), env));
    if (!want.includes('{nonce}') || get(name) == null) continue;
    const m = norm(get(name)).match(nonceRe(want));
    if (m) return m[1];
  }
  return null;
}

/**
 * The minimum set every app's headers file holds (frontend-defaults.md, Headers): a
 * Content-Security-Policy without 'unsafe-inline', X-Content-Type-Options: nosniff, a
 * Referrer-Policy and a Strict-Transport-Security with a max-age above 0. Returns a list of problems.
 */
export function minimumHeaderProblems(spec) {
  const get = getter(spec.headers);
  const value = (n) => (get(n) == null ? null : joinValue(get(n)));
  const problems = [];
  const csp = value('Content-Security-Policy');
  if (csp == null) problems.push('no Content-Security-Policy');
  else if (/'unsafe-inline'/i.test(csp)) problems.push("Content-Security-Policy allows 'unsafe-inline'");
  if ((value('X-Content-Type-Options') ?? '').trim().toLowerCase() !== 'nosniff') problems.push('no X-Content-Type-Options: nosniff');
  if (!value('Referrer-Policy')?.trim()) problems.push('no Referrer-Policy');
  const hsts = value('Strict-Transport-Security');
  if (hsts == null) problems.push('no Strict-Transport-Security');
  else if (!(Number(/max-age=(\d+)/i.exec(hsts)?.[1]) > 0)) problems.push('Strict-Transport-Security has no max-age above 0');
  return problems;
}

/**
 * Fetches a served URL (no redirects followed) and checks it: a 2xx answer (a redirect's headers are
 * not the page's), every header as the spec says, and, when the spec has {nonce}, a second fetch
 * whose nonce differs from the first (one response cannot show a hard-coded nonce).
 * Returns { status, problems }; a network error throws.
 */
export async function checkServed(spec, url, { env = {}, cookie } = {}) {
  const get = async () => { const r = await fetch(url, { redirect: 'manual', headers: cookie ? { cookie } : {} }); await r.arrayBuffer().catch(() => null); return r; };
  const res = await get();
  const problems = [];
  if (res.status < 200 || res.status > 299) problems.push(`${url} answered ${res.status}, not 2xx: check the page itself, not a redirect or an error`);
  problems.push(...headerProblems(spec, res.headers, { env }));
  if (!problems.length && usesNonce(spec)) {
    const again = await get();
    const [a, b] = [servedNonce(spec, res.headers, { env }), servedNonce(spec, again.headers, { env })];
    if (a && a === b) problems.push('the nonce is the same on two responses (hard-coded?): it must be fresh per response');
  }
  return { status: res.status, problems };
}

/**
 * The Cookie header a browser would send to `url` from a saved session (Playwright's storageState,
 * staging-run.mjs --save-session): the cookies whose domain and path match, unexpired. Secure
 * cookies are included for http://127.0.0.1 and localhost, as a browser treats them as secure.
 * Returns '' when none match.
 */
export function sessionCookie(state, url) {
  const u = new URL(url);
  const now = Date.now() / 1000;
  const local = u.hostname === '127.0.0.1' || u.hostname === 'localhost' || u.hostname.endsWith('.localhost');
  return (state?.cookies ?? [])
    .filter((c) => {
      const d = String(c.domain ?? '').replace(/^\./, '');
      const host = u.hostname === d || (String(c.domain).startsWith('.') && u.hostname.endsWith(`.${d}`));
      const path = u.pathname.startsWith(c.path ?? '/');
      const live = c.expires === undefined || c.expires < 0 || c.expires > now;
      const secure = !c.secure || u.protocol === 'https:' || local;
      return host && path && live && secure;
    })
    .map((c) => `${c.name}=${c.value}`)
    .join('; ');
}

/**
 * Compares what a served URL sent (a Headers or a plain object) with the spec: each header present
 * with the expected value (whitespace normalised; any nonce accepted where {nonce} stands, and the
 * same nonce everywhere in one response). Returns a list of problems.
 */
export function headerProblems(spec, actual, { env = {} } = {}) {
  const get = getter(actual);
  const problems = [];
  let seenNonce = null;
  for (const [name, v] of Object.entries(spec.headers)) {
    const got = get(name);
    if (got == null) { problems.push(`header ${name}: missing`); continue; }
    const want = norm(fillOrigins(joinValue(v), env));
    if (!want.includes('{nonce}')) { if (norm(got) !== want) problems.push(`header ${name}: "${norm(got)}" is not "${want}"`); continue; }
    const m = norm(got).match(nonceRe(want));
    if (!m) { problems.push(`header ${name}: "${norm(got)}" does not match "${want}" with a nonce of at least 16 characters`); continue; }
    const nonces = m.slice(1);
    if (new Set(nonces).size > 1 || (seenNonce && nonces[0] !== seenNonce)) problems.push(`header ${name}: the nonce differs within one response`);
    seenNonce ??= nonces[0];
  }
  return problems;
}

/** An nginx server block fragment for a static host. Refused when a header needs a nonce. */
export function emitNginx(spec, { env = {} } = {}) {
  if (usesNonce(spec)) throw new Error('a header needs a per-response nonce, which a static nginx config cannot write: serve the HTML from an app server (or edge function) that sets a fresh nonce per response');
  const h = renderHeaders(spec, { env });
  return `${Object.entries(h).map(([k, v]) => `add_header ${k} "${v.replace(/"/g, '\\"')}" always;`).join('\n')}\n`;
}

// --- Contract drift ---------------------------------------------------------------------------------

const METHODS = ['get', 'put', 'post', 'delete', 'patch', 'head', 'options'];

/** Problems that make a parsed document no OpenAPI 3.x contract: no 3.x version, no paths. */
export function openapiProblems(doc) {
  if (doc == null) return ['empty'];
  if (typeof doc !== 'object' || Array.isArray(doc)) return ['not a mapping'];
  const problems = [];
  if (!/^3(\.\d+){0,2}$/.test(String(doc.openapi ?? ''))) problems.push('no openapi: 3.x version');
  if (!doc.paths || typeof doc.paths !== 'object' || Array.isArray(doc.paths) || !Object.keys(doc.paths).length) problems.push('no paths');
  return problems;
}

function operations(doc) {
  const out = new Map();
  for (const [path, item] of Object.entries(doc.paths || {})) for (const m of METHODS) if (item?.[m]) out.set(`${m.toUpperCase()} ${path}`, { op: item[m], item });
  return out;
}

// A local $ref to components/<kind> resolved (a few hops at most); anything else as it is.
function resolve(doc, obj, kind) {
  for (let i = 0; i < 5 && obj?.$ref?.startsWith(`#/components/${kind}/`); i++) obj = doc.components?.[kind]?.[obj.$ref.slice(`#/components/${kind}/`.length)];
  return obj;
}

const REQ = new Set(['request']);
const RES = new Set(['response']);
const BOTH = new Set(['request', 'response']);
// The directions in which a change breaks a frontend built on the old contract. The frontend writes
// requests (it may send a value the server now refuses) and reads responses (it may get a value it
// does not expect, or miss one it relies on). A kind not listed is additive.
const BREAKS = {
  type: BOTH, ref: BOTH, format: BOTH, propRemoved: BOTH,
  newlyRequired: REQ, enumRemoved: REQ, nullableRemoved: REQ, variantRemoved: REQ,
  noLongerRequired: RES, nullableAdded: RES, variantAdded: RES,
};

const label = (s) => (s?.$ref ? JSON.stringify(s.$ref) : JSON.stringify(s?.type ?? s?.oneOf ?? s?.anyOf ?? s?.allOf ?? null));

function shape(s = {}) {
  const types = s.type === undefined ? null : [].concat(s.type);
  const nonNull = types?.filter((t) => t !== 'null');
  const props = { ...(s.properties || {}) };
  const required = new Set(s.required || []);
  for (const m of s.allOf || []) if (!m.$ref) { Object.assign(props, m.properties || {}); for (const r of m.required || []) required.add(r); }
  return {
    type: nonNull ? JSON.stringify(nonNull.length === 1 ? nonNull[0] : nonNull) : null,
    nullable: s.nullable === true || !!types?.includes('null') || !!s.enum?.includes(null),
    format: s.format ?? null,
    enum: s.enum ? s.enum.filter((v) => v !== null).map(String) : null,
    props, required,
    items: s.items,
    additional: s.additionalProperties && typeof s.additionalProperties === 'object' ? s.additionalProperties : null,
    variants: [...(s.oneOf || s.anyOf || []), ...(s.allOf || []).filter((m) => m.$ref)].map((v) => (v.$ref ? v.$ref : JSON.stringify(v))),
  };
}

// Two schemas at one place (`at`: a property path, '' at the root). A $ref is compared by name only:
// the component it names is diffed once, on its own.
function diffSchema(x, y, at, push) {
  x ??= {}; y ??= {};
  const name = at ? `property ${at}` : '';
  const pre = name ? `${name} ` : '';
  if (x.$ref || y.$ref) {
    if (x.$ref !== y.$ref) push('ref', `${name || 'schema'} changed from ${label(x)} to ${label(y)}`);
    return;
  }
  const a = shape(x), b = shape(y);
  if (a.type !== b.type) { push('type', at ? `${name} changed from ${a.type} to ${b.type}` : `type ${a.type} became ${b.type}`); return; }
  if (a.format !== b.format) push('format', `${pre}format ${a.format ?? 'none'} became ${b.format ?? 'none'}`);
  if (a.nullable && !b.nullable) push('nullableRemoved', `${pre}may no longer be null`);
  if (!a.nullable && b.nullable) push('nullableAdded', `${pre}may now be null`);
  if (a.enum || b.enum) {
    const ev = at ? `${at} value` : 'enum value';
    for (const v of a.enum || []) if (b.enum && !b.enum.includes(v)) push('enumRemoved', `${ev} ${v} removed`);
    for (const v of b.enum || []) if (a.enum && !a.enum.includes(v)) push('enumAdded', `${ev} ${v} added (the UI must show a value it does not know)`);
    if (!a.enum && b.enum) push('enumRemoved', `${pre}now takes only ${b.enum.join(', ')}`);
  }
  const path = (p) => (at ? `${at}.${p}` : p);
  for (const p of Object.keys(a.props)) {
    if (!(p in b.props)) push('propRemoved', `property ${path(p)} removed`);
    else diffSchema(a.props[p], b.props[p], path(p), push);
  }
  for (const p of Object.keys(b.props)) if (!(p in a.props)) push('propAdded', `property ${path(p)} added`);
  const req = (r) => `${at ? `${at}.` : ''}${r}`;
  for (const r of b.required) if (!a.required.has(r)) push('newlyRequired', `${req(r)} is now required`);
  for (const r of a.required) if (!b.required.has(r)) push('noLongerRequired', `${req(r)} is no longer required`);
  if (a.items || b.items) diffSchema(a.items, b.items, `${at}[]`, push);
  if (a.additional && b.additional) diffSchema(a.additional, b.additional, `${at}{}`, push);
  for (const v of a.variants) if (!b.variants.includes(v)) push('variantRemoved', `${pre}variant ${v} removed`);
  for (const v of b.variants) if (!a.variants.includes(v)) push('variantAdded', `${pre}variant ${v} added`);
}

// Every components/schemas name a value refers to, deeply.
function refsIn(value, out = new Set()) {
  if (Array.isArray(value)) for (const v of value) refsIn(v, out);
  else if (value && typeof value === 'object') {
    if (typeof value.$ref === 'string' && value.$ref.startsWith('#/components/schemas/')) out.add(value.$ref.slice('#/components/schemas/'.length));
    for (const v of Object.values(value)) refsIn(v, out);
  }
  return out;
}

const params = (doc, item, op) => {
  const out = new Map();
  for (const p of [...(item.parameters || []), ...(op.parameters || [])]) { const r = resolve(doc, p, 'parameters'); if (r?.name) out.set(`${r.in} ${r.name}`, r); }
  return out;
};
const body = (doc, op) => resolve(doc, op.requestBody, 'requestBodies');
const responses = (doc, op) => Object.fromEntries(Object.entries(op.responses || {}).map(([c, r]) => [c, resolve(doc, r, 'responses')]));

// Which way each component schema travels in `doc`, through the operations and the schemas that
// refer to it. A schema no operation reaches counts both ways.
function directions(doc) {
  const schemas = doc.components?.schemas || {};
  const seen = { request: new Set(), response: new Set() };
  const reach = (dir, names) => { const todo = [...names]; while (todo.length) { const n = todo.pop(); if (seen[dir].has(n)) continue; seen[dir].add(n); todo.push(...refsIn(schemas[n])); } };
  for (const { op, item } of operations(doc).values()) {
    reach('request', refsIn([...params(doc, item, op).values()]));
    reach('request', refsIn(body(doc, op)));
    reach('response', refsIn(Object.values(responses(doc, op))));
  }
  return (n) => (seen.request.has(n) || seen.response.has(n) ? new Set([...(seen.request.has(n) ? ['request'] : []), ...(seen.response.has(n) ? ['response'] : [])]) : BOTH);
}

/**
 * What changed from the signed-off contract (before) to a live one (after), for the frontend that
 * was built on `before`. Operations are compared in depth: parameters (path level and operation
 * level, by in and name), request bodies, response codes and media types, and their schemas, inline
 * or named (type, format, nullable in 3.0 or 3.1 form, enum, properties, required, items, variants).
 * Direction decides: a field newly required, a value no longer accepted, null no longer allowed
 * break a request; a field no longer required, null now possible, a new variant break a response.
 * A component schema is judged by where the operations use it, both ways when none does.
 * Returns { breaking: [..], additive: [..] } as readable lines.
 */
export function contractDiff(before, after) {
  const breaking = [], additive = [];
  const pusher = (prefix, dirs) => (kind, msg) => ([...(BREAKS[kind] || [])].some((d) => dirs.has(d)) ? breaking : additive).push(`${prefix}${msg}`);
  const a = operations(before), b = operations(after);
  for (const k of a.keys()) if (!b.has(k)) breaking.push(`operation ${k} removed`);
  for (const k of b.keys()) if (!a.has(k)) additive.push(`operation ${k} added`);
  for (const [k, x] of a) {
    if (!b.has(k)) continue;
    const y = b.get(k);
    const at = `operation ${k}: `;
    const pa = params(before, x.item, x.op), pb = params(after, y.item, y.op);
    for (const [key, p] of pa) {
      const q = pb.get(key);
      if (!q) { breaking.push(`${at}parameter ${key} removed`); continue; }
      if (!p.required && q.required) breaking.push(`${at}parameter ${key} is now required`);
      if (p.required && !q.required) additive.push(`${at}parameter ${key} is no longer required`);
      diffSchema(p.schema, q.schema, '', pusher(`${at}parameter ${key}: `, REQ));
    }
    for (const [key, q] of pb) if (!pa.has(key)) (q.required ? breaking : additive).push(`${at}parameter ${key} added${q.required ? ', required' : ''}`);
    const ba = body(before, x.op), bb = body(after, y.op);
    if (!ba && bb) (bb.required ? breaking : additive).push(`${at}request body added${bb.required ? ', required' : ''}`);
    else if (ba && !bb) breaking.push(`${at}request body removed`);
    else if (ba && bb) {
      if (!ba.required && bb.required) breaking.push(`${at}request body is now required`);
      if (ba.required && !bb.required) additive.push(`${at}request body is no longer required`);
      const ca = ba.content || {}, cb = bb.content || {};
      const many = Object.keys(ca).length > 1;
      for (const mt of Object.keys(ca)) {
        if (!(mt in cb)) breaking.push(`${at}request body ${mt} no longer accepted`);
        else diffSchema(ca[mt]?.schema, cb[mt]?.schema, '', pusher(`${at}request body${many ? ` ${mt}` : ''}: `, REQ));
      }
      for (const mt of Object.keys(cb)) if (!(mt in ca)) additive.push(`${at}request body ${mt} accepted`);
    }
    const ra = responses(before, x.op), rb = responses(after, y.op);
    for (const code of Object.keys(ra)) {
      if (!(code in rb)) { (/^2/.test(code) ? breaking : additive).push(`${at}response ${code} ${/^2/.test(code) ? 'removed' : 'no longer documented'}`); continue; }
      const ca = ra[code]?.content || {}, cb = rb[code]?.content || {};
      const many = Object.keys(ca).length > 1;
      for (const mt of Object.keys(ca)) {
        if (!(mt in cb)) breaking.push(`${at}response ${code} ${mt} no longer sent`);
        else diffSchema(ca[mt]?.schema, cb[mt]?.schema, '', pusher(`${at}response ${code}${many ? ` ${mt}` : ''}: `, RES));
      }
      for (const mt of Object.keys(cb)) if (!(mt in ca)) additive.push(`${at}response ${code} ${mt} added`);
    }
    for (const code of Object.keys(rb)) if (!(code in ra)) additive.push(`${at}response ${code} added`);
  }
  const sa = before.components?.schemas || {}, sb = after.components?.schemas || {};
  const dirOf = directions(before);
  for (const name of Object.keys(sa)) {
    if (!(name in sb)) { breaking.push(`schema ${name} removed`); continue; }
    diffSchema(sa[name], sb[name], '', pusher(`schema ${name}: `, dirOf(name)));
  }
  for (const name of Object.keys(sb)) if (!(name in sa)) additive.push(`schema ${name} added`);
  return { breaking, additive };
}
