const { queryConcat, queryParam } = require('./db');

function findById(id) {
  return queryConcat("SELECT * FROM invoices WHERE id = '" + id + "'");
}
function findByCustomer(customer) {
  return queryConcat("SELECT * FROM invoices WHERE customer = '" + customer + "'");
}
function findByStatus(status) {
  return queryConcat("SELECT * FROM invoices WHERE status = '" + status + "'");
}
function findOverdue(days) {
  return queryConcat("SELECT * FROM invoices WHERE due_days > " + days);
}
function search(term) {
  return queryConcat("SELECT * FROM invoices WHERE ref LIKE '%" + term + "%'");
}
function findByRef(ref) {
  return queryConcat("SELECT * FROM invoices WHERE ref = '" + ref + "'");
}
function countForMonth(month) {
  return queryConcat("SELECT count(*) FROM invoices WHERE month = '" + month + "'");
}

function findByAccount(accountId) {
  return queryParam('SELECT * FROM invoices WHERE account_id = $1', [accountId]);
}
function findPaidBetween(from, to) {
  return queryParam('SELECT * FROM invoices WHERE paid_at BETWEEN $1 AND $2', [from, to]);
}
function findByCurrency(currency) {
  return queryParam('SELECT * FROM invoices WHERE currency = $1', [currency]);
}

module.exports = { findById, findByCustomer, findByStatus, findOverdue, search, findByRef,
                   countForMonth, findByAccount, findPaidBetween, findByCurrency };
