const { test } = require('node:test');
const assert = require('node:assert');
const billing = require('../src/billing');
test('charge rejects a missing invoice', () => {
  assert.equal(billing.chargeInvoice(null).error, 'INVOICE_REQUIRED');
});
test('refund rejects an unpaid invoice', () => {
  assert.equal(billing.refundInvoice({ paid: false }).error, 'NOT_PAID');
});
