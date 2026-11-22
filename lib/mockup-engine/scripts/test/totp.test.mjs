/**
 * totp.test.mjs: the staging flows' authenticator codes match RFC 6238's SHA-1 test vectors.
 * Run: node --test test/totp.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { totp } from '../lib/totp.mjs';

// RFC 6238 appendix B: the secret "12345678901234567890" (base32 below), 8 digits there, 6 here.
const SECRET = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
for (const [t, code] of [[59, '94287082'], [1111111109, '07081804'], [1234567890, '89005924'], [2000000000, '69279037']])
  test(`at ${t}s: ${code.slice(-6)}`, () => assert.equal(totp(SECRET, new Date(t * 1000)), code.slice(-6)));

test('a secret that is not base32 is refused', () => assert.throws(() => totp('not base32!'), /not a base32 secret/));
