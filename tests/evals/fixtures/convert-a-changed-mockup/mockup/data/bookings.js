// Bookings: the server's loan date rules, in one place, for the pages that stand in for it.
// A data helper (references/mockup-conventions.md, "Data helpers"): pure functions on window, no
// DOM, no state of their own. In the app the API does this work: GET /v1/items/{id}/bookings
// returns the days an item is taken, and POST /v1/loans and POST /v1/loans/{id}/approve answer
// 409 dates_unavailable when the days overlap an approved loan or one on loan (PRD requirement 5).
//
// window.bookings.taken(loans, itemId, { except })   -> [{ from, to }] sorted by from
//   the days the item is approved or on loan; except leaves one loan out (the one being approved)
// window.bookings.overlaps({ from, to }, taken)      -> boolean
//   whole days, both ends included: 27 to 28 overlaps 28 to 30
// window.bookings.today(timeZone)                    -> 'YYYY-MM-DD'
//   today in the organisation's zone, the day the server counts from
(function () {
  'use strict';

  const TAKEN = ['approved', 'on_loan'];

  function taken(loans, itemId, { except } = {}) {
    return loans
      .filter((l) => l.item.id === itemId && TAKEN.includes(l.status) && l.id !== except)
      .map((l) => ({ from: l.from, to: l.to }))
      .sort((a, b) => a.from.localeCompare(b.from));
  }

  // Business dates compare as text: YYYY-MM-DD sorts as it reads.
  const overlaps = (range, list) => list.some((b) => range.from <= b.to && b.from <= range.to);

  // en-CA writes a date as YYYY-MM-DD.
  const today = (timeZone) => new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date());

  window.bookings = { taken, overlaps, today };
})();
