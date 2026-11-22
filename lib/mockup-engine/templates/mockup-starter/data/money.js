// money: what a money field (MoneyField) needs to turn typed text into an amount. A data helper
// (skills/mockup/references/mockup-conventions.md, "Data helpers"): pure functions on window, no DOM.
//
// A money field keeps in state the digits the user typed, in major units ('1250000', '12.5'),
// shows them grouped as they type ('1,250,000'), and submits the plain integer in minor units
// from a hidden input (1250000 UGX, 1250 USD cents). The currency's decimals come from Intl, as
// MK.format.money takes them: UGX has none, KES and USD have two.
//
//   money.decimals(currency)          how many decimals the currency has
//   money.digits(text, currency)      typed or pasted text as digits: separators, signs, letters and
//                                     spaces go, leading zeros go, and a decimal part is kept only
//                                     up to the currency's decimals (a pasted 1,250,000.50 in UGX is
//                                     1250000). A trailing point is kept while a USD amount is typed
//   money.group(digits)               digits with thousands separators, as the field shows them
//   money.minorUnits(digits, currency) the integer a form submits ('' is 0)
//   money.fromMinor(amount, currency) the other way: a stored amount (integer minor units) as the
//                                     digits a money field keeps, to prefill an editor
//                                     (125050 KES is '1250.50', 100000 KES is '1000', 1250000 UGX
//                                     is '1250000'). A fraction of all zeros is left out, any other
//                                     keeps every decimal the currency has. null or undefined is ''
//                                     (an empty field); a negative, fractional or non-number amount
//                                     throws. minorUnits(fromMinor(n, c), c) is n
//   money.caretAfter(value, n)        the index just after the n-th digit (or point) of a shown
//                                     value, where the caret goes after the value is regrouped
// In the app these are the money input component's own helpers (lib/money.ts).
(function () {
  'use strict';

  const cache = {};
  function decimals(currency) {
    const c = currency || 'USD';
    if (!(c in cache)) cache[c] = new Intl.NumberFormat('en', { style: 'currency', currency: c }).resolvedOptions().maximumFractionDigits;
    return cache[c];
  }

  function digits(text, currency) {
    const d = decimals(currency);
    const s = String(text ?? '');
    const at = s.indexOf('.');
    const whole = (at < 0 ? s : s.slice(0, at)).replace(/\D/g, '').replace(/^0+(?=\d)/, '');
    if (!d || at < 0) return whole;
    return `${whole || '0'}.${s.slice(at + 1).replace(/\D/g, '').slice(0, d)}`;
  }

  function group(value) {
    const [whole, frac] = String(value ?? '').split('.');
    const grouped = whole.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    return frac === undefined ? grouped : `${grouped}.${frac}`;
  }

  function minorUnits(value, currency) {
    const d = decimals(currency);
    const [whole, frac = ''] = String(value ?? '').split('.');
    return Number(whole || '0') * 10 ** d + Number((frac + '0'.repeat(d)).slice(0, d) || '0');
  }

  function fromMinor(amount, currency) {
    if (amount === null || amount === undefined) return '';
    if (!Number.isSafeInteger(amount) || amount < 0) throw new Error(`money.fromMinor: ${amount} is not a whole, non-negative number of minor units`);
    const d = decimals(currency);
    if (!d) return String(amount);
    const s = String(amount).padStart(d + 1, '0');
    const frac = s.slice(-d);
    return /^0+$/.test(frac) ? s.slice(0, -d) : `${s.slice(0, -d)}.${frac}`;
  }

  function caretAfter(shown, n) {
    let at = 0;
    for (let seen = 0; at < shown.length && seen < n; at++) if (/[\d.]/.test(shown[at])) seen++;
    return at;
  }

  window.money = { decimals, digits, group, minorUnits, fromMinor, caretAfter };
}());
