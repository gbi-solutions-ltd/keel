/*
 * Fixtures: ALL data shown in the mockup lives here, shaped exactly like the API responses you
 * expect (field names, nesting, casing). The conversion drafts the OpenAPI contract from these
 * shapes, and the app's mocks serve them back, so a field renamed here is renamed everywhere.
 * Replace the sample domain (invoices) with the client's; keep the shape rules.
 *
 * Money: integer minor units of the currency (ISO 4217 exponent; UGX has none, KES and USD have
 * 2). Instants: RFC 3339 in UTC. Business dates: YYYY-MM-DD.
 *
 * Roles and permissions: `session.role` is who is signed in; `?as=<role>` previews another.
 * `permissions` names each permission in words, for the access page.
 *
 * @typedef {{ id: string, name: string, currency: 'UGX'|'KES'|'USD' }} Organisation
 * @typedef {{ id: string, number: string, customer_name: string, amount: number,
 *   currency: 'UGX'|'KES'|'USD', status: 'paid'|'open'|'overdue', issued_on: string,
 *   due_on: string }} Invoice
 * @typedef {{ items: Invoice[], next_cursor: string|null }} InvoicePage  one page of
 *   GET /v1/invoices: cursor paged, no total (pass next_cursor back as ?cursor= for the next page;
 *   null on the last). Not stored here: data/list-query.js makes it from `invoices` in the page's load.
 */
window.FIXTURES = {
  "organisation": { "id": "org_1", "name": "Acme Services", "currency": "USD" },
  "session": { "user_id": "usr_1001", "role": "manager", "name": "Amina Nakato" },
  "roles": {
    "manager": { "label": "Manager", "permissions": ["invoice:read", "invoice:create", "invoice:void", "role:read"] },
    "clerk": { "label": "Clerk", "permissions": ["invoice:read", "invoice:create"] },
    "auditor": { "label": "Auditor", "permissions": ["invoice:read", "role:read"] }
  },
  "permissions": {
    "invoice:read": "See invoices",
    "invoice:create": "Create invoices",
    "invoice:void": "Void an invoice",
    "role:read": "See who can do what"
  },
  "invoices": [
    { "id": "inv_01", "number": "INV-1001", "customer_name": "Kato Hardware", "amount": 125000, "currency": "USD", "status": "paid", "issued_on": "2026-09-01", "due_on": "2026-09-15" },
    { "id": "inv_02", "number": "INV-1002", "customer_name": "Nile Fresh Produce Cooperative Society of Eastern Uganda", "amount": 1849950, "currency": "USD", "status": "open", "issued_on": "2026-09-03", "due_on": "2026-10-03" },
    { "id": "inv_03", "number": "INV-1003", "customer_name": "Bwire and Sons", "amount": 4500, "currency": "USD", "status": "overdue", "issued_on": "2026-08-12", "due_on": "2026-09-12" },
    { "id": "inv_04", "number": "INV-1004", "customer_name": "Lakeside Clinic", "amount": 98000075, "currency": "USD", "status": "open", "issued_on": "2026-09-05", "due_on": "2026-10-05" },
    { "id": "inv_05", "number": "INV-1005", "customer_name": "Mbabazi Tailors", "amount": 30000, "currency": "USD", "status": "paid", "issued_on": "2026-09-06", "due_on": "2026-09-20" },
    { "id": "inv_06", "number": "INV-1006", "customer_name": "Gulu Water Works", "amount": 762510, "currency": "USD", "status": "overdue", "issued_on": "2026-08-20", "due_on": "2026-09-19" },
    { "id": "inv_07", "number": "INV-1007", "customer_name": "Achieng Bakery", "amount": 15999, "currency": "USD", "status": "open", "issued_on": "2026-09-10", "due_on": "2026-10-10" },
    { "id": "inv_08", "number": "INV-1008", "customer_name": "Mukono Motors", "amount": 2400000, "currency": "USD", "status": "paid", "issued_on": "2026-09-11", "due_on": "2026-09-25" },
    { "id": "inv_09", "number": "INV-1009", "customer_name": "Kabale Coffee Exporters", "amount": 5300000, "currency": "USD", "status": "open", "issued_on": "2026-09-14", "due_on": "2026-10-14" },
    { "id": "inv_10", "number": "INV-1010", "customer_name": "Jinja Print House", "amount": 87500, "currency": "USD", "status": "overdue", "issued_on": "2026-08-28", "due_on": "2026-09-27" },
    { "id": "inv_11", "number": "INV-1011", "customer_name": "Entebbe Air Cargo", "amount": 1150000, "currency": "USD", "status": "paid", "issued_on": "2026-09-18", "due_on": "2026-10-02" },
    { "id": "inv_12", "number": "INV-1012", "customer_name": "Soroti Seeds", "amount": 64000, "currency": "USD", "status": "open", "issued_on": "2026-09-20", "due_on": "2026-10-20" }
  ]
};
