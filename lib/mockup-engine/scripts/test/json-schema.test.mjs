/**
 * json-schema.test.mjs: lib/json-schema.mjs, the validator the config check and the sign-off's
 * fixture check share. It must agree with the sample backend's (Ajv 2020 with ajv-formats), so a
 * fixture that passes sign-off cannot fail the backend, and keep its "path: problem" messages.
 * No browser. Run: node --test test/json-schema.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { resolveRef, validate } from '../lib/json-schema.mjs';

test('oneOf does not skip the sibling keywords of its node', () => {
  const schema = { type: 'object', required: ['a'], properties: { a: { type: 'string' } }, oneOf: [{ required: ['b'] }, { required: ['c'] }] };
  assert.notDeepEqual(validate(schema, {}), [], 'required a is checked beside oneOf');
  assert.notDeepEqual(validate(schema, { a: 1, b: 1 }), [], 'properties are checked beside oneOf');
  assert.notDeepEqual(validate({ type: 'object', anyOf: [{ required: ['b'] }] }, 'x'), [], 'type is checked beside anyOf');
  assert.deepEqual(validate(schema, { a: 'x', b: 1 }), []);
});

test('a data key named like an Object.prototype member is still an unknown key', () => {
  const schema = { type: 'object', additionalProperties: false, properties: { a: { type: 'string' } } };
  assert.deepEqual(validate(schema, JSON.parse('{"constructor": 1}')), ['(top): unknown key "constructor"']);
  assert.deepEqual(validate(schema, JSON.parse('{"toString": 1}')), ['(top): unknown key "toString"']);
});

test('the keywords the sign-off accepts are enforced, not ignored', () => {
  const bad = [
    [{ type: 'array', uniqueItems: true }, [1, 1]],
    [{ type: 'number', multipleOf: 5 }, 7],
    [{ not: { type: 'string' } }, 'x'],
    [{ if: { properties: { kind: { const: 'card' } } }, then: { required: ['last4'] } }, { kind: 'card' }],
    [{ type: 'array', contains: { const: 'admin' } }, ['user']],
    [{ type: 'array', prefixItems: [{ type: 'string' }, { type: 'integer' }] }, ['a', 'b']],
    [{ type: 'object', minProperties: 1 }, {}],
    [{ type: 'object', propertyNames: { pattern: '^[a-z]+$' } }, { A: 1 }],
    [{ type: 'object', dependentRequired: { a: ['b'] } }, { a: 1 }],
  ];
  for (const [schema, value] of bad) assert.notDeepEqual(validate(schema, value), [], JSON.stringify(schema));
});

test('formats are checked as the backend checks them: impossible dates fail', () => {
  assert.deepEqual(validate({ type: 'string', format: 'date' }, '2026-02-28'), []);
  assert.deepEqual(validate({ type: 'string', format: 'date' }, '2026-02-30'), ['(top): "2026-02-30" is not a date']);
  assert.deepEqual(validate({ type: 'string', format: 'date' }, '2025-02-29', undefined, 'x.due'), ['x.due: "2025-02-29" is not a date']);
  assert.deepEqual(validate({ type: 'string', format: 'date' }, '2028-02-29'), []);
  assert.notDeepEqual(validate({ type: 'string', format: 'date-time' }, '2026-13-01T00:00:00Z'), []);
  assert.notDeepEqual(validate({ type: 'string', format: 'email' }, 'not an email'), [], 'formats the backend knows are checked too');
  assert.deepEqual(validate({ type: 'string', format: 'x-unknown-format' }, 'anything'), [], 'an unknown format is ignored, as by the backend');
});

test('messages keep their "path: problem" shape', () => {
  const root = {
    $defs: { money: { type: 'integer', minimum: 0 } },
    type: 'object',
    additionalProperties: false,
    required: ['id'],
    properties: {
      id: { type: 'string', pattern: '^inv_' },
      name: { type: 'string', minLength: 1 },
      code: { type: 'string', maxLength: 3 },
      status: { enum: ['draft', 'paid'] },
      kind: { const: 'invoice' },
      amount: { $ref: '#/$defs/money' },
      note: { type: ['string', 'null'] },
      rate: { type: 'number', maximum: 1, exclusiveMinimum: 0 },
      lines: { type: 'array', minItems: 1, maxItems: 2, items: { type: 'object', required: ['sku'] } },
    },
  };
  const problems = validate(root, { id: 'x1', name: '', code: 'ABCD', status: 'void', kind: 'bill', amount: -1, note: 3, rate: 0, lines: [{}, {}, {}], extra: 1 }, root, 'FIXTURES.invoices[0]');
  const want = [
    'FIXTURES.invoices[0]: unknown key "extra"',
    'FIXTURES.invoices[0].id: "x1" does not match ^inv_',
    'FIXTURES.invoices[0].name: must not be empty',
    'FIXTURES.invoices[0].code: must be at most 3 characters',
    'FIXTURES.invoices[0].status: "void" is not one of draft, paid',
    'FIXTURES.invoices[0].kind: must be "invoice"',
    'FIXTURES.invoices[0].amount: must be at least 0',
    'FIXTURES.invoices[0].note: must be a string or a null',
    'FIXTURES.invoices[0].rate: must be above 0',
    'FIXTURES.invoices[0].lines: has more than 2 items',
    'FIXTURES.invoices[0].lines[0]: sku is required',
  ];
  for (const w of want) assert.ok(problems.includes(w), `${w}\n--- got\n${problems.join('\n')}`);
  assert.deepEqual(validate(root, {}), ['(top): id is required']);
  assert.deepEqual(validate({ type: 'integer' }, 1.5, undefined, 'n'), ['n: must be an integer']);
});

test('a oneOf that fails explains with its closest shape; one that matches twice says so', () => {
  const root = {
    $defs: { deferred: { type: 'object', additionalProperties: false, required: ['deferred'], properties: { deferred: { type: 'object', required: ['owner', 'by'] } } } },
    type: 'object',
    properties: { stack: { oneOf: [{ $ref: '#/$defs/deferred' }, { type: 'object', additionalProperties: false, required: ['name'], properties: { name: { type: 'string' } } }] } },
  };
  assert.deepEqual(validate(root, { stack: { deferred: { owner: 'a' } } }), ['stack.deferred: by is required']);
  assert.deepEqual(validate(root, { stack: { name: 1 } }), ['stack.name: must be a string']);
  assert.deepEqual(validate({ oneOf: [{ type: 'integer' }, { type: 'number' }] }, 1), ['(top): matches more than one allowed shape']);
  assert.deepEqual(validate({ anyOf: [{ type: 'integer' }, { type: 'string' }] }, 1), []);
});

test('a node inside the root resolves its refs against the root, as the contract check calls it', () => {
  const doc = { openapi: '3.1.0', components: { schemas: { Money: { type: 'integer', minimum: 0 }, Invoice: { type: 'object', properties: { amount: { $ref: '#/components/schemas/Money' } } } } } };
  assert.deepEqual(validate(doc.components.schemas.Invoice, { amount: 5 }, doc, 'FIXTURES.x'), []);
  assert.deepEqual(validate(doc.components.schemas.Invoice, { amount: -5 }, doc, 'FIXTURES.x'), ['FIXTURES.x.amount: must be at least 0']);
  assert.throws(() => validate({ $ref: '#/components/schemas/Nope' }, 1, doc), /Nope/);
  assert.equal(resolveRef(doc, '#/components/schemas/Money').minimum, 0);
  assert.deepEqual(validate(true, 1), []);
  assert.deepEqual(validate(false, 1, undefined, 'x'), ['x: no value is allowed here']);
});
