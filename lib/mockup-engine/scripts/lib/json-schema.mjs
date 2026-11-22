/**
 * json-schema.mjs: the engine's JSON Schema validator, for the two schemas it reads:
 * lib/mockup-engine/mockup-config.schema.json (draft 2020-12) and the schemas of an OpenAPI 3.1 contract,
 * which the sign-off checks fixtures against.
 *
 * A thin wrapper over Ajv 2020 with ajv-formats, the version and draft the sample backend
 * validates with (templates/sample-backend/lib/contract.mjs), so a fixture that passes sign-off
 * passes the backend too: every 2020-12 keyword is enforced, formats are checked as the backend
 * checks them (2026-02-30 is not a date), an unknown format is ignored. Strict mode is off, as in
 * the backend: OpenAPI's own keywords (example, discriminator, xml) and x-* keys are not JSON
 * Schema, and lib/signoff.mjs's strayKeys reports the keys that are neither.
 *
 * What the wrapper adds: Ajv's errors become "path: problem" strings (FIXTURES.invoices[0].status:
 * "settled" is not one of open, paid), and a oneOf or anyOf that fails is explained by its closest
 * shape alone (the branch with the fewest problems), not by every branch.
 * $ref is resolved within the root document only (#/$defs/X, #/components/schemas/X).
 */
import Ajv2020 from 'ajv/dist/2020.js';
import addFormats from 'ajv-formats';

const ajv = new Ajv2020({ strict: false, allErrors: true, verbose: true, logger: { log() {}, warn() {}, error: console.error } });
addFormats(ajv);

const an = (t) => (t === 'integer' ? 'an integer' : t === 'array' || t === 'object' ? `an ${t}` : `a ${t}`);

/** The node a local $ref names ("#/a/b"), or throws when it is not in the root document. */
export function resolveRef(root, ref) {
  if (!ref.startsWith('#/')) throw new Error(`$ref ${ref}: only refs within the document are supported`);
  let node = root;
  for (const part of ref.slice(2).split('/').map((p) => decodeURIComponent(p).replace(/~1/g, '/').replace(/~0/g, '~'))) {
    if (node === undefined || node === null) break;
    node = node[part];
  }
  if (node === undefined) throw new Error(`$ref ${ref} names nothing in the document`);
  return node;
}

// Every root is registered once under an id of its own; every node compiled from it has its local
// refs pointed at that id, so any subschema (a oneOf branch) compiles on its own too.
const roots = new WeakMap();
const NO_ROOT = {};
let next = 0;
function absolute(node, id) {
  if (Array.isArray(node)) return node.map((n) => absolute(n, id));
  if (!node || typeof node !== 'object') return node;
  const out = {};
  for (const [k, v] of Object.entries(node)) {
    if (k === '$ref' && typeof v === 'string') {
      if (!v.startsWith('#')) throw new Error(`$ref ${v}: only refs within the document are supported`);
      out[k] = `${id}${v}`;
    } else if (k !== '$id' && k !== '$schema') out[k] = absolute(v, id);
  }
  return out;
}
function registered(root) {
  let r = roots.get(root);
  if (!r) {
    const id = `mockup-engine-root-${(next += 1)}`;
    ajv.addSchema({ ...absolute(root, id), $id: id });
    r = { id, compiled: new WeakMap() };
    roots.set(root, r);
  }
  return r;
}
function compile(node, r) {
  if (typeof node === 'boolean') return ajv.compile(node);
  let fn = r.compiled.get(node);
  if (!fn) {
    try { fn = ajv.compile(absolute(node, r.id)); } catch (e) {
      if (e.missingRef) throw new Error(`$ref ${e.missingRef.replace(r.id, '')} names nothing in the document`);
      throw e;
    }
    r.compiled.set(node, fn);
  }
  return fn;
}
// A oneOf branch, as Ajv hands it back, already has absolute refs: compiled as it is.
const branchFns = new WeakMap();
function compileBranch(node) {
  if (typeof node === 'boolean') return ajv.compile(node);
  let fn = branchFns.get(node);
  if (!fn) { fn = ajv.compile(node); branchFns.set(node, fn); }
  return fn;
}

/**
 * Ajv's raw errors with each failed oneOf and anyOf replaced by its closest branch's errors.
 * Ajv lists a combinator's branch errors just before the combinator's own error, so the slice is
 * found by validating each branch alone and counting. Paths stay relative to the data validated.
 */
function closest(errors) {
  const out = [...errors];
  for (let k = out.length - 1; k >= 0; k -= 1) {
    const e = out[k];
    if ((e.keyword !== 'oneOf' && e.keyword !== 'anyOf') || !Array.isArray(e.schema)) continue;
    const branches = e.schema.map((b) => {
      const fn = compileBranch(b);
      fn(e.data);
      return fn.errors ? [...fn.errors] : [];
    });
    const raw = branches.reduce((n, b) => n + b.length, 0);
    const start = k - raw;
    if (start < 0 || out.slice(start, k).some((x) => !x.instancePath.startsWith(e.instancePath))) continue;
    let replace;
    if (e.keyword === 'oneOf' && Array.isArray(e.params?.passingSchemas)) replace = [{ ...e, keyword: 'oneOf:many' }];
    else {
      const shaped = branches.map((b) => closest(b).map((x) => ({ ...x, instancePath: e.instancePath + x.instancePath })));
      replace = shaped.sort((a, b) => a.length - b.length)[0] ?? [];
    }
    out.splice(start, k - start + 1, ...replace);
    k = start;
  }
  return out;
}

/** "/lines/0/sku" in value, under prefix "FIXTURES.x", as "FIXTURES.x.lines[0].sku". */
function pathOf(pointer, value, prefix) {
  let path = prefix;
  let v = value;
  for (const raw of pointer.split('/').slice(1)) {
    const part = raw.replace(/~1/g, '/').replace(/~0/g, '~');
    path = Array.isArray(v) ? `${path}[${part}]` : path ? `${path}.${part}` : part;
    v = v?.[part];
  }
  return path || '(top)';
}

function message(e, at) {
  const p = e.params || {};
  const value = JSON.stringify(e.data);
  switch (e.keyword) {
    case 'oneOf:many': return `${at}: matches more than one allowed shape`;
    case 'false schema': return `${at}: no value is allowed here`;
    case 'required': return `${at}: ${p.missingProperty} is required`;
    case 'additionalProperties': return `${at}: unknown key "${p.additionalProperty}"`;
    case 'unevaluatedProperties': return `${at}: unknown key "${p.unevaluatedProperty}"`;
    case 'type': return `${at}: must be ${[].concat(Array.isArray(p.type) ? p.type : String(p.type).split(',')).map(an).join(' or ')}`;
    case 'enum': return `${at}: ${value} is not one of ${p.allowedValues.join(', ')}`;
    case 'const': return `${at}: must be ${JSON.stringify(p.allowedValue)}`;
    case 'minLength': return p.limit === 1 ? `${at}: must not be empty` : `${at}: must be at least ${p.limit} characters`;
    case 'maxLength': return `${at}: must be at most ${p.limit} characters`;
    case 'pattern': return `${at}: ${value} does not match ${p.pattern}`;
    case 'format': return `${at}: ${value} is not a ${p.format}`;
    case 'minimum': return `${at}: must be at least ${p.limit}`;
    case 'maximum': return `${at}: must be at most ${p.limit}`;
    case 'exclusiveMinimum': return `${at}: must be above ${p.limit}`;
    case 'exclusiveMaximum': return `${at}: must be below ${p.limit}`;
    case 'minItems': return `${at}: needs at least ${p.limit} item${p.limit > 1 ? 's' : ''}`;
    case 'maxItems': return `${at}: has more than ${p.limit} items`;
    case 'uniqueItems': return `${at}: items ${p.j} and ${p.i} are the same; items must be unique`;
    case 'multipleOf': return `${at}: must be a multiple of ${p.multipleOf}`;
    case 'not': return `${at}: matches a shape that is not allowed`;
    case 'if': return null; // the failing then or else branch says what is wrong
    default: return `${at}: ${e.message}`;
  }
}

/** Validates value against a schema node within root. Returns a list of "path: problem" strings. */
export function validate(node, value, root = node, path = '') {
  if (node === undefined) return [];
  const r = registered(root && typeof root === 'object' ? root : NO_ROOT);
  const fn = compile(node, r);
  if (fn(value)) return [];
  const out = [];
  for (const e of closest(fn.errors)) {
    const m = message(e, pathOf(e.instancePath, value, path));
    if (m && !out.includes(m)) out.push(m);
  }
  return out;
}
