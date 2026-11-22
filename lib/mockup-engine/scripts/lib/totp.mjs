/**
 * totp.mjs: RFC 6238 codes (SHA-1, 6 digits, 30 seconds) from a base32 secret, so a staging flow
 * can type an authenticator's code: { "fill": { "label": "Code", "totp": "<base32 secret>" } }.
 * The secret is a seeded test account's, never a real person's.
 */
import { createHmac } from 'node:crypto';

const B32 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
function base32Decode(text) {
  let bits = 0;
  let value = 0;
  const out = [];
  for (const ch of text.replace(/=+$/, '').toUpperCase()) {
    const i = B32.indexOf(ch);
    if (i < 0) throw new Error(`totp: not a base32 secret: ${text}`);
    value = (value << 5) | i;
    bits += 5;
    if (bits >= 8) {
      out.push((value >>> (bits - 8)) & 255);
      bits -= 8;
    }
  }
  return Buffer.from(out);
}

export function totp(secret, at = new Date(), step = 30) {
  const counter = Buffer.alloc(8);
  counter.writeBigUInt64BE(BigInt(Math.floor(at.getTime() / 1000 / step)));
  const mac = createHmac('sha1', base32Decode(secret)).update(counter).digest();
  const o = mac[mac.length - 1] & 15;
  const n = ((mac[o] & 127) << 24) | (mac[o + 1] << 16) | (mac[o + 2] << 8) | mac[o + 3];
  return String(n % 1_000_000).padStart(6, '0');
}
