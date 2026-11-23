/**
 * contract.mjs: the signed-off OpenAPI document as the backend's routing table and validator.
 *
 * Every operation becomes one route. Requests are validated against the contract before a handler
 * runs (path, query and header parameters, and the JSON body), and every response is validated
 * after, so the sample backend answers only what the contract says and refuses what it does not.
 * OpenAPI 3.1 schemas are JSON Schema 2020-12: they compile with Ajv2020, never with a draft-07
 * validator. A 3.0 document (nullable, no type lists) is refused: convert it first.
 */
import { readFileSync } from 'node:fs';
import Ajv2020 from 'ajv/dist/2020.js';
import addFormats from 'ajv-formats';
import { parse } from 'yaml';

const METHODS = ['get', 'put', 'post', 'delete', 'patch', 'head', 'options'];

/** Drops the vendor keys (x-mockup-fixture, x-mockup-status) and points local refs at the registered document. */
function clean(node) {
  if (Array.isArray(node)) return node.map(clean);
  if (!node || typeof node !== 'object') return node;
  const out = {};
  for (const [k, v] of Object.entries(node)) {
    if (k.startsWith('x-')) continue;
    out[k] = k === '$ref' && typeof v === 'string' && v.startsWith('#/') ? `contract#${v.slice(1)}` : clean(v);
  }
  return out;
}

// Ajv runs with strict off, because OpenAPI's own schema keywords (example, discriminator, xml,
// externalDocs) are not JSON Schema and strict mode refuses them. So that a typo is never silently
// ignored (minLenght, itmes: no check at all), every key in a schema must be one of these.
// nullable is 3.0's and is not here: in 3.1 write type: [string, 'null'].
const KEYWORDS = new Set([
  // JSON Schema 2020-12: core, applicator, validation, unevaluated, format, content, meta-data
  '$schema', '$id', '$ref', '$anchor', '$dynamicRef', '$dynamicAnchor', '$vocabulary', '$comment', '$defs',
  'allOf', 'anyOf', 'oneOf', 'not', 'if', 'then', 'else', 'dependentSchemas', 'prefixItems', 'items', 'contains',
  'properties', 'patternProperties', 'additionalProperties', 'propertyNames', 'unevaluatedItems', 'unevaluatedProperties',
  'type', 'enum', 'const', 'multipleOf', 'maximum', 'exclusiveMaximum', 'minimum', 'exclusiveMinimum',
  'maxLength', 'minLength', 'pattern', 'maxItems', 'minItems', 'uniqueItems', 'maxContains', 'minContains',
  'maxProperties', 'minProperties', 'required', 'dependentRequired', 'format',
  'contentEncoding', 'contentMediaType', 'contentSchema',
  'title', 'description', 'default', 'deprecated', 'readOnly', 'writeOnly', 'examples',
  // OpenAPI 3.1's Schema Object additions
  'discriminator', 'xml', 'externalDocs', 'example',
]);
const ONE = ['not', 'if', 'then', 'else', 'items', 'contains', 'additionalProperties', 'propertyNames', 'unevaluatedItems', 'unevaluatedProperties', 'contentSchema'];
const MANY = ['allOf', 'anyOf', 'oneOf', 'prefixItems'];
const NAMED = ['$defs', 'properties', 'patternProperties', 'dependentSchemas'];

/**
 * Keys in a schema (and the schemas inside it) that are no keyword: [{ at, slip }], at "where: key".
 * x-* keys are vendor keys. A slip is a key of words with no value: the rest of a description
 * after a comma in a YAML flow mapping ({ description: E.164, for SMS only }). It checks nothing,
 * so it is a warning; any other unknown key may be a keyword's typo, which turns a check off.
 */
export function unknownKeywords(schema, where) {
  if (!schema || typeof schema !== 'object' || Array.isArray(schema)) return [];
  const out = [];
  for (const [k, v] of Object.entries(schema)) {
    if (k.startsWith('x-')) continue;
    if (!KEYWORDS.has(k)) out.push({ at: `${where}: ${k}`, slip: v === null && /\s/.test(k.trim()) });
    else if (ONE.includes(k)) out.push(...unknownKeywords(v, `${where}.${k}`));
    else if (MANY.includes(k) && Array.isArray(v)) v.forEach((s, i) => out.push(...unknownKeywords(s, `${where}.${k}[${i}]`)));
    else if (NAMED.includes(k) && v && typeof v === 'object') for (const [n, s] of Object.entries(v)) out.push(...unknownKeywords(s, `${where}.${k}.${n}`));
  }
  return out;
}

/** Follows a local $ref to a response, parameter or request body object. */
function deref(doc, node) {
  let n = node;
  for (let i = 0; n?.$ref && i < 10; i += 1) n = n.$ref.slice(2).split('/').reduce((o, k) => o?.[k], doc);
  return n;
}

/**
 * Loads the contract and returns { doc, version, prefix, cookieName, operations }, where each
 * operation is { operationId, method, path (OpenAPI form), route (Fastify form), public,
 * validateRequest(req) -> problems[], validateResponse(status, body) -> problems[],
 * idempotent (a required Idempotency-Key header) }.
 */
export function loadContract(file) {
  const text = readFileSync(file, 'utf8');
  const doc = parse(text);
  if (!String(doc.openapi ?? '').startsWith('3.1'))
    throw new Error(`${file}: openapi ${doc.openapi}; the sample backend reads 3.1 (JSON Schema 2020-12)`);
  const ajv = new Ajv2020({ strict: false, allErrors: true });
  addFormats(ajv);
  const unknown = [];
  for (const [name, s] of Object.entries(doc.components?.schemas ?? {})) unknown.push(...unknownKeywords(s, `components.schemas.${name}`));
  // Every schema compiled below is checked where it is compiled (inline ones too).
  const compile = (schema, where) => {
    unknown.push(...unknownKeywords(schema, where));
    return ajv.compile(clean(schema));
  };
  ajv.addSchema({ $id: 'contract', components: clean(doc.components ?? {}) });

  const prefix = (doc.servers?.[0]?.url ?? '').replace(/\/$/, '');
  const cookieScheme = Object.values(doc.components?.securitySchemes ?? {}).find((s) => s.type === 'apiKey' && s.in === 'cookie');
  const globalSecurity = doc.security ?? [];
  const operations = [];

  for (const [path, item] of Object.entries(doc.paths ?? {})) {
    for (const method of METHODS) {
      const op = item[method];
      if (!op) continue;
      const params = [...(item.parameters ?? []), ...(op.parameters ?? [])].map((p) => deref(doc, p));
      const security = op.security ?? globalSecurity;
      const body = deref(doc, op.requestBody);
      const bodySchema = body?.content?.['application/json']?.schema;
      const name = op.operationId ?? `${method.toUpperCase()} ${path}`;
      const bodyCheck = bodySchema ? compile(bodySchema, `${name} request body`) : null;
      const paramChecks = params.map((p) => ({
        name: p.name,
        in: p.in,
        required: Boolean(p.required || p.in === 'path'),
        check: p.schema ? compile(p.schema, `${name} parameter ${p.name}`) : null,
      }));
      const responseChecks = {};
      for (const [code, r] of Object.entries(op.responses ?? {})) {
        const schema = deref(doc, r)?.content?.['application/json']?.schema;
        responseChecks[code] = schema ? compile(schema, `${name} response ${code}`) : null;
      }
      const errs = (fn, where) => (fn.errors ?? []).map((e) => `${where}${e.instancePath} ${e.message}`);

      operations.push({
        operationId: op.operationId ?? `${method} ${path}`,
        method: method.toUpperCase(),
        path,
        route: `${prefix}${path.replace(/\{([^}]+)\}/g, ':$1')}`,
        public: security.length === 0 || security.some((s) => Object.keys(s).length === 0),
        idempotent: params.some((p) => p.in === 'header' && /^idempotency-key$/i.test(p.name) && p.required),
        validateRequest(req) {
          const problems = [];
          for (const p of paramChecks) {
            const source = p.in === 'path' ? req.params : p.in === 'query' ? req.query : p.in === 'header' ? req.headers : {};
            const key = p.in === 'header' ? p.name.toLowerCase() : p.name;
            const value = source?.[key];
            if (value === undefined) {
              if (p.required) problems.push(`${p.in} parameter ${p.name} is required`);
              continue;
            }
            if (!p.check || p.check(value)) continue;
            // A query or path value arrives as text: a number or a boolean is tried as one, and
            // written back, so a handler sees limit as a number.
            const typed = value === 'true' ? true : value === 'false' ? false : value !== '' && Number.isFinite(Number(value)) ? Number(value) : undefined;
            if (typed !== undefined && p.in !== 'header' && p.check(typed)) source[key] = typed;
            else problems.push(...errs(p.check, `${p.in} parameter ${p.name}`).slice(0, 50));
          }
          // A NUL character is refused at the door: Postgres cannot store one in text.
          const nul = (v, at) => {
            if (typeof v === 'string') return v.includes('\u0000') ? [at] : [];
            if (v && typeof v === 'object') return Object.entries(v).flatMap(([k, x]) => nul(x, `${at}/${k}`));
            return [];
          };
          for (const at of [...nul(req.body, 'body'), ...nul(req.query, 'query')].slice(0, 5)) problems.push(`${at} holds a NUL character`);
          if (body?.required && (req.body === undefined || req.body === null)) problems.push('a request body is required');
          else if (bodyCheck && req.body !== undefined && !bodyCheck(req.body)) problems.push(...errs(bodyCheck, 'body').slice(0, 50));
          else if (!bodySchema && req.body !== undefined && req.body !== null && !(typeof req.body === 'object' && !Object.keys(req.body).length))
            problems.push('this operation takes no request body');
          return problems;
        },
        validateResponse(status, payload) {
          const code = String(status);
          const check = code in responseChecks ? responseChecks[code] : `${code[0]}XX` in responseChecks ? responseChecks[`${code[0]}XX`] : responseChecks.default;
          if (check === undefined) return [`status ${status} is not a response the contract lists`];
          if (check === null) return payload === undefined || payload === null || payload === '' ? [] : [`status ${status} has no body in the contract`];
          return check(payload) ? [] : errs(check, `response ${status}`);
        },
      });
    }
  }
  const slips = unknown.filter((u) => u.slip).map((u) => u.at);
  const typos = unknown.filter((u) => !u.slip).map((u) => u.at);
  if (slips.length)
    console.error(`backend: ${file}: ${slips.length} description${slips.length === 1 ? ' was' : 's were'} cut at a comma (quote it in the YAML): ${slips.join('; ')}`);
  if (typos.length)
    throw new Error(`${file}: ${typos.length} schema key${typos.length === 1 ? ' is' : 's are'} no JSON Schema or OpenAPI keyword (a typo, or 3.0's nullable): ${typos.slice(0, 20).join('; ')}`);
  return { doc, version: doc.info?.version ?? '', prefix, cookieName: cookieScheme?.name ?? 'session', operations, text };
}
