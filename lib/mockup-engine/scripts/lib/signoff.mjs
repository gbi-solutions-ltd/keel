/**
 * signoff.mjs: the sign-off record and the checks Convert's readiness gate runs on it
 * (skills/mockup/references/signoff.md). No browser.
 *
 *   - The contract: project.contract names it (location, default api/openapi.yaml in the mockup).
 *     It is drafted, or vendored from the backend, by sign-off. Each entity schema that the mockup's
 *     data stands for says so with `x-mockup-fixture: <key>` (FIXTURES.<key>: an array is checked
 *     item by item, an object as one value, `<key>.*` checks every value of an object map). Every
 *     mapped fixture must validate. Responses built from several fixtures (a session plus its role's
 *     permissions) are out of reach here; the app's contract test covers them.
 *   - The freeze: a sha256 per file of the signed-off mockup (pages, components, assets, data,
 *     strings, docs/*.json, index.html; not the records under docs/, such as a standalone mockup's
 *     docs/mockups/<name>/brief.md, which change after sign-off), the contract hashed apart, so a
 *     contract the backend amends shows as a contract change and a design change as a mockup
 *     change. Tool caches (.tools, .mockup-engine, node_modules), .git, .DS_Store and the record
 *     itself are left out; baseline PNGs live in .mockup-engine and are renderer output, not
 *     design. Other dotfiles are design and are hashed from manifest version 2 on; a round recorded
 *     before (no manifestVersion) is verified under version 1, which skipped every dot name, so an
 *     old sign-off stays valid. mockup.config.json is not hashed whole: it also holds port-only
 *     answers (tier 2, deferred until Convert) and gate tuning changed during a port. The record
 *     keeps its design part instead (designConfig), compared key by key.
 *   - The record: <mockup>/docs/signoff.json, written by signoff.mjs, read by the gate. Rounds are
 *     appended, never edited: a change after sign-off is signed off again as the next round.
 */
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { isAbsolute, join, normalize, relative, sep } from 'node:path';
import { parse as parseYaml } from 'yaml';
import { readFixtures } from './fixtures.mjs';
import { validate } from './json-schema.mjs';
import { tiers } from './project.mjs';
import { sha256 } from './production.mjs';

export const RECORD = 'docs/signoff.json';
/** Why a config with no screen cannot be signed off (signoff.mjs refuses it; signoffStatus fails it). */
export const NO_SCREENS = 'the config lists no screen, so nothing would be signed off (list the screens first)';
export const DEFAULT_CONTRACT = 'api/openapi.yaml';
const SKIP_DIRS = new Set(['node_modules', '.mockup-engine', '.tools', '.git']);
const SKIP_FILES = new Set(['.DS_Store']);
/** The manifest rule new rounds are recorded under: 2 hashes dotfiles, 1 skipped every dot name. */
export const MANIFEST_VERSION = 2;
const CONFIG = 'mockup.config.json';
// The config keys that describe the design the client signed off. The rest (targetStack, diff,
// quality, spill, domOracle, the tier 2 project answers) belong to the port.
const DESIGN_KEYS = ['name', 'timezoneId', 'locale', 'pins', 'modules', 'checklist', 'roles', 'viewports', 'screens'];

// Keys inside screens that tune a gate rather than describe the design: app-side overrides
// (appName, and any other app*), and what the quality check accepts on purpose (expectStatus,
// expectConsole: a port that calls an API the mockup simulated in the browser provokes a status
// the mockup never did).
const TUNING = new Set(['expectStatus', 'expectConsole']);
const stripAppOnly = (v) => {
  if (Array.isArray(v)) return v.map(stripAppOnly);
  if (v && typeof v === 'object') return Object.fromEntries(Object.entries(v).filter(([k]) => !/^app[A-Z]/.test(k) && !TUNING.has(k)).map(([k, x]) => [k, stripAppOnly(x)]));
  return v;
};

/**
 * The design part of a config: what the client signed off, without port-only answers or gate
 * tuning. Screens lose their app-side overrides (appName) and the quality check's accepted
 * statuses and console text (expectStatus, expectConsole). Absent keys are left out.
 */
export function designConfig(config = {}) {
  const out = {};
  for (const k of DESIGN_KEYS) if (config[k] !== undefined) out[k] = stripAppOnly(config[k]);
  const tier1 = tiers()[1];
  const project = Object.fromEntries(Object.entries(config.project || {}).filter(([k]) => tier1.includes(k)));
  if (Object.keys(project).length) out.project = project;
  return out;
}

/** The design keys that differ between two designConfig values, as 'screens' or 'project.i18n'. */
export function designConfigDiff(before = {}, after = {}) {
  // Both sides through the same projection, so a record written before a key was treated as
  // tuning still compares equal.
  before = { ...before, ...(before.screens ? { screens: stripAppOnly(before.screens) } : {}) };
  after = { ...after, ...(after.screens ? { screens: stripAppOnly(after.screens) } : {}) };
  const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
  const out = [];
  for (const k of new Set([...Object.keys(before), ...Object.keys(after)])) {
    if (k === 'project') {
      const a = before.project || {}, b = after.project || {};
      for (const f of new Set([...Object.keys(a), ...Object.keys(b)])) if (!same(a[f], b[f])) out.push(`project.${f}`);
    } else if (!same(before[k], after[k])) out.push(k);
  }
  return out.sort();
}

/** The contract's path relative to the mockup, or { error } when it cannot be checked here. */
export function contractLocation(config) {
  const c = config?.project?.contract;
  if (!c) return { error: 'project.contract is not answered' };
  if (c.deferred) return { error: `project.contract is deferred (${c.deferred.owner} by ${c.deferred.by}); sign-off needs the contract: drafted from the mockup, or the backend's vendored` };
  const loc = c.location ?? DEFAULT_CONTRACT;
  if (/^[a-z]+:\/\//i.test(loc)) return { error: `project.contract.location ${loc} is a URL; vendor the backend's document into the mockup and point at the file, so it can be checked and hashed` };
  const rel = normalize(loc);
  if (isAbsolute(loc) || rel === '..' || rel.startsWith(`..${sep}`)) return { error: `project.contract.location ${loc} is outside the mockup; vendor the document into the mockup (api/openapi.yaml), so the freeze covers it` };
  return { path: rel.split(sep).join('/') };
}

/**
 * Every file of the mockup that the sign-off freezes, as { 'rel/path': sha256 }, sorted. version
 * is the manifest rule (MANIFEST_VERSION by default; 1 for a round recorded without one).
 */
export function manifest(dir, { exclude = [], version = MANIFEST_VERSION } = {}) {
  const skip = new Set([RECORD, CONFIG, ...exclude]);
  const out = {};
  const walk = (d) => {
    for (const name of readdirSync(d).sort()) {
      if (SKIP_DIRS.has(name) || SKIP_FILES.has(name) || (version < 2 && name.startsWith('.'))) continue;
      const abs = join(d, name);
      if (statSync(abs).isDirectory()) walk(abs);
      else {
        const rel = relative(dir, abs).split(sep).join('/');
        // Under docs/ only the checks' inputs are design (behaviours.json, inventory-accepted.json):
        // the brief, decisions and sign-off page there are records, updated after sign-off.
        if (rel.startsWith('docs/') && !/^docs\/[^/]+\.json$/.test(rel)) continue;
        if (!skip.has(rel)) out[rel] = sha256(readFileSync(abs));
      }
    }
  };
  walk(dir);
  return out;
}

/** Files added, removed and changed from one manifest to the next. */
export function manifestDiff(before, after) {
  const changed = [], added = [], removed = [];
  for (const [k, v] of Object.entries(after)) {
    if (!(k in before)) added.push(k);
    else if (before[k] !== v) changed.push(k);
  }
  for (const k of Object.keys(before)) if (!(k in after)) removed.push(k);
  return { changed, added, removed, count: changed.length + added.length + removed.length };
}

function fixtureValues(fx, spec) {
  const each = spec.endsWith('.*');
  const path = (each ? spec.slice(0, -2) : spec).split('.');
  let v = fx;
  for (const p of path) {
    if (v === null || typeof v !== 'object' || !(p in v)) return { error: `FIXTURES.${path.join('.')} does not exist` };
    v = v[p];
  }
  const name = `FIXTURES.${path.join('.')}`;
  const empty = { error: `${name} is empty, so the mapping checks nothing`, named: true };
  if (each) {
    if (v === null || typeof v !== 'object' || Array.isArray(v)) return { error: `${name} is not an object map, so ${spec} names nothing` };
    if (!Object.keys(v).length) return empty;
    return { values: Object.entries(v).map(([k, x]) => [`${name}.${k}`, x]) };
  }
  if (Array.isArray(v)) return v.length ? { values: v.map((x, i) => [`${name}[${i}]`, x]) } : empty;
  return { values: [[name, v]] };
}

/**
 * Reads the contract and checks the mockup's fixtures against it. Returns { path, sha256, version,
 * problems, warnings, mapped: [{ schema, fixture, count }] }. A missing or unreadable contract, a
 * contract with no x-mockup-fixture at all, and every fixture value that fails its schema are
 * problems; a top-level fixture key no schema maps is a warning (navigation and role tables often
 * are not API data).
 */
export function checkContract(dir, config) {
  const loc = contractLocation(config);
  if (loc.error) return { problems: [loc.error], warnings: [], mapped: [] };
  const file = join(dir, loc.path);
  const base = { path: loc.path, problems: [], warnings: [], mapped: [] };
  if (!existsSync(file)) return { ...base, problems: [`${loc.path} is not there: ${config.project.contract.source === 'drafted' ? 'draft it from needs.api and the fixtures (skills/convert-mockup/references/api-integration.md)' : 'vendor the backend\'s document there'}`] };
  const bytes = readFileSync(file);
  base.sha256 = sha256(bytes);
  let doc;
  try { doc = parseYaml(bytes.toString('utf8')); } catch (e) { return { ...base, problems: [`${loc.path} does not parse: ${e.message.split('\n')[0]}`] }; }
  if (!doc || typeof doc !== 'object' || !/^3\./.test(String(doc.openapi ?? ''))) return { ...base, problems: [`${loc.path} is not an OpenAPI 3 document (no openapi: 3.x)`] };
  // Its schemas are JSON Schema 2020-12 only from 3.1: the sample backend refuses 3.0, and a 3.0
  // schema (nullable, no type lists) would be checked here under rules it was not written for.
  if (!/^3\.1(\.|$)/.test(String(doc.openapi))) return { ...base, problems: [`${loc.path}: openapi ${doc.openapi}: sign-off needs OpenAPI 3.1 (JSON Schema 2020-12), as the sample backend and the app's contract test read it; convert the document first`] };
  base.version = doc.info?.version ?? null;
  base.stray = strayKeys(doc);
  for (const s of base.stray) base.warnings.push(s);
  const schemas = doc.components?.schemas ?? {};
  const maps = Object.entries(schemas).filter(([, s]) => s && s['x-mockup-fixture']);
  if (!maps.length) return { ...base, problems: [`${loc.path}: no schema has x-mockup-fixture, so no fixture is checked against the contract`] };
  let fx;
  try { fx = readFixtures(dir); } catch (e) { return { ...base, problems: [`fixtures: ${e.message}`] }; }
  const covered = new Set();
  for (const [name, schema] of maps) {
    for (const spec of [].concat(schema['x-mockup-fixture'])) {
      const got = fixtureValues(fx, spec);
      if (got.named) covered.add(spec.split('.')[0]);
      if (got.error) { base.problems.push(`${name}: x-mockup-fixture ${spec}: ${got.error}`); continue; }
      covered.add(spec.split('.')[0]);
      let bad = 0;
      for (const [where, value] of got.values) {
        let errs;
        try { errs = validate(schema, value, doc, where); } catch (e) { errs = [`${where}: ${e.message}`]; }
        if (errs.length) bad += 1;
        for (const e of errs.slice(0, 5)) base.problems.push(`${name}: ${e}`);
      }
      base.mapped.push({ schema: name, fixture: spec, count: got.values.length, failing: bad });
    }
  }
  for (const k of Object.keys(fx)) if (!covered.has(k)) base.warnings.push(`FIXTURES.${k}: no schema names it with x-mockup-fixture`);
  return base;
}

// JSON Schema and OpenAPI schema keywords. A key outside them in a schema is almost always a YAML
// slip (an unquoted comma in a flow mapping turns the rest of a description into a key), and
// generators such as Orval refuse the document.
const KEYWORDS = new Set(['$ref', '$id', '$schema', '$defs', '$comment', 'type', 'enum', 'const', 'format', 'title', 'description', 'default', 'examples', 'example', 'properties', 'required', 'additionalProperties', 'patternProperties', 'propertyNames', 'items', 'prefixItems', 'minItems', 'maxItems', 'uniqueItems', 'contains', 'minLength', 'maxLength', 'pattern', 'minimum', 'maximum', 'exclusiveMinimum', 'exclusiveMaximum', 'multipleOf', 'minProperties', 'maxProperties', 'oneOf', 'anyOf', 'allOf', 'not', 'if', 'then', 'else', 'dependentRequired', 'dependentSchemas', 'nullable', 'readOnly', 'writeOnly', 'deprecated', 'discriminator', 'xml', 'externalDocs', 'contentMediaType', 'contentEncoding', 'unevaluatedProperties', 'unevaluatedItems']);

/** Keys in the contract's schemas and parameters that are not fields of them (x-* allowed). */
export function strayKeys(doc) {
  const out = [];
  const walk = (node, where) => {
    if (!node || typeof node !== 'object' || Array.isArray(node)) return;
    for (const [k, v] of Object.entries(node)) {
      if (k.startsWith('x-')) continue;
      if (!KEYWORDS.has(k)) { out.push(`${where}: "${k}" is not a schema keyword (an unquoted comma in YAML?)`); continue; }
      if (k === 'properties' || k === '$defs' || k === 'patternProperties' || k === 'dependentSchemas') for (const [p, s] of Object.entries(v || {})) walk(s, `${where}.${p}`);
      else if (['items', 'additionalProperties', 'not', 'if', 'then', 'else', 'contains', 'propertyNames', 'unevaluatedProperties', 'unevaluatedItems'].includes(k)) walk(v, `${where}.${k}`);
      else if (['oneOf', 'anyOf', 'allOf', 'prefixItems'].includes(k) && Array.isArray(v)) v.forEach((s, i) => walk(s, `${where}.${k}[${i}]`));
    }
  };
  for (const [name, s] of Object.entries(doc?.components?.schemas || {})) walk(s, name);
  // Parameter Objects take the same slip (a description with a comma in a flow mapping).
  const PARAM = new Set(['name', 'in', 'description', 'required', 'deprecated', 'allowEmptyValue', 'style', 'explode', 'allowReserved', 'schema', 'example', 'examples', 'content', '$ref']);
  const params = (list, where) => (Array.isArray(list) ? list : []).forEach((p, i) => {
    if (!p || typeof p !== 'object') return;
    const label = `${where} parameter ${p.name ?? i}`;
    for (const k of Object.keys(p)) if (!k.startsWith('x-') && !PARAM.has(k)) out.push(`${label}: "${k}" is not a parameter field (an unquoted comma in YAML?)`);
    if (p.schema) walk(p.schema, `${label} schema`);
  });
  for (const [path, item] of Object.entries(doc?.paths || {})) {
    params(item?.parameters, path);
    for (const m of ['get', 'put', 'post', 'delete', 'patch', 'head', 'options']) if (item?.[m]) params(item[m].parameters, `${m.toUpperCase()} ${path}`);
  }
  params(Object.values(doc?.components?.parameters || {}), 'components');
  return out;
}

export function readRecord(dir) {
  const file = join(dir, RECORD);
  if (!existsSync(file)) return null;
  return JSON.parse(readFileSync(file, 'utf8'));
}

/**
 * Whether the mockup as it is now is the one signed off. Returns { signed, round, date, by,
 * problems, warnings }: signed is true only with a record, at least one screen in the config, the
 * files unchanged since its last round, the contract unchanged and its fixtures valid.
 */
export function signoffStatus(dir, config) {
  let record;
  try { record = readRecord(dir); } catch (e) { return { signed: false, problems: [`${RECORD} is not valid JSON: ${e.message}`], warnings: [] }; }
  if (!record) return { signed: false, problems: [`no sign-off: ${RECORD} is missing (run signoff.mjs once the client signs off)`], warnings: [] };
  const last = record.rounds?.[record.rounds.length - 1];
  if (!last) return { signed: false, problems: [`${RECORD} has no rounds`], warnings: [] };
  const problems = [];
  if (!(config?.screens || []).length) problems.push(NO_SCREENS);
  const contract = checkContract(dir, config);
  const now = manifest(dir, { exclude: contract.path ? [contract.path] : [], version: last.manifestVersion ?? 1 });
  const d = manifestDiff(last.files || {}, now);
  const configKeys = designConfigDiff(last.config, designConfig(config));
  if (configKeys.length) problems.push(`mockup changed since sign-off round ${last.round}: ${CONFIG} ${configKeys.join(', ')} (sign the change off as round ${last.round + 1})`);
  if (d.count) {
    const list = [...d.changed.map((f) => `${f} changed`), ...d.added.map((f) => `${f} added`), ...d.removed.map((f) => `${f} removed`)];
    problems.push(`mockup changed since sign-off round ${last.round}: ${list.slice(0, 8).join(', ')}${list.length > 8 ? `, and ${list.length - 8} more` : ''} (sign the change off as round ${last.round + 1})`);
  }
  if (contract.sha256 && last.contract?.sha256 && contract.sha256 !== last.contract.sha256) problems.push(`contract changed since sign-off round ${last.round}: ${contract.path} (agree it with the backend, then sign off round ${last.round + 1})`);
  if (contract.path && last.contract?.path && contract.path !== last.contract.path) problems.push(`contract moved since sign-off: ${last.contract.path} to ${contract.path}`);
  problems.push(...contract.problems.map((p) => `contract: ${p}`));
  return { signed: !problems.length, round: last.round, date: last.date, by: last.by, problems, warnings: contract.warnings.map((w) => `contract: ${w}`) };
}
