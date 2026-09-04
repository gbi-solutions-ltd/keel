function chargeInvoice(inv) {
  if (!inv) return { ok: false, error: 'INVOICE_REQUIRED' };
  return { ok: true, value: inv.amountMinor };
}
function refundInvoice(inv) {
  if (!inv.paid) return { ok: false, error: 'NOT_PAID' };
  return { ok: true, value: inv.amountMinor };
}
function voidInvoice(inv) {
  if (inv.paid) return { ok: false, error: 'ALREADY_PAID' };
  return { ok: true, value: null };
}
function applyCredit(inv, credit) {
  if (credit < 0) return { ok: false, error: 'NEGATIVE_CREDIT' };
  return { ok: true, value: inv.amountMinor - credit };
}
function settle(inv) {
  if (!inv.approved) return { ok: false, error: 'NOT_APPROVED' };
  return { ok: true, value: inv.amountMinor };
}
function reconcile(inv, ledger) {
  if (inv.amountMinor !== ledger.amountMinor) return { ok: false, error: 'LEDGER_MISMATCH' };
  return { ok: true, value: 0 };
}
function exportInvoice(inv) {
  if (!inv.ref) throw new Error('ref is required');
  return inv.ref;
}
function archiveInvoice(inv) {
  if (!inv.closedAt) throw new Error('invoice is not closed');
  return true;
}
module.exports = { chargeInvoice, refundInvoice, voidInvoice, applyCredit, settle, reconcile,
                   exportInvoice, archiveInvoice };
