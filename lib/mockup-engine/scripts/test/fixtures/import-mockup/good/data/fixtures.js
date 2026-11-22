/*
 * @typedef {{ id: string, number: string, amount: number }} Invoice
 */
window.FIXTURES = {
  "session": { "user_id": "usr_1", "role": "clerk" },
  "invoices": [
    { "id": "inv_1", "number": "INV-0412", "amount": 125000, "note": null },
    { "id": "inv_2", "number": "INV-0413", "amount": 4500, "note": "Quote \"rush\" </script>" }
  ],
  "default": { "kept": "only in the default export: a reserved word" },
  "page-size": 25
};
