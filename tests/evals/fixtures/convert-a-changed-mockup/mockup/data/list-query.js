// listQuery: the search, filters, sort and paging a list page does in its `load`, in one place.
// A data helper (references/mockup-conventions.md, "Data helpers"): a pure function on window, no
// DOM, no state of its own. In the app the API does this work from the query string
// (?q=&status=&sort=&cursor=&limit=), and the page's composable or hook passes the same keys.
// Paging is by cursor, as every collection in the contract is (references/api-integration.md):
// there is no total and no page number; a page that shows "Page N" counts the cursors it followed.
//
// window.listQuery(rows, { search, searchKeys, filters, sort, cursor, limit })
//   -> { rows, next_cursor, limit }
//   search      text; a row matches when the trimmed text, in any case, is in the values of
//               searchKeys joined with spaces. A search with no searchKeys throws, so a page that
//               forgets them fails loudly instead of showing an empty list
//   filters     { key: value }, or [{ key, value, fn }]; an empty value is no filter. With fn a row
//               is kept when fn(row, value) is true, otherwise when its field equals the value as text
//   sort        'key' ascending or '-key' descending; numbers compare as numbers, text with numeric
//               collation (INV-3 before INV-20); ties keep their order
//   cursor      the next_cursor of the page before, opaque (never build or read one); '', null or
//               absent is the first page. A cursor this helper did not make throws, as the API
//               answers 400. A cursor is only good for the search, filters and sort that made it,
//               so a page drops its cursors when any of them changes
//   limit       rows per page, 20 by default, capped at 100 (the API's cap)
// `next_cursor` is the cursor of the following page, or null on the last one. The input is not
// changed.
(function () {
  'use strict';

  const LIMIT = 20;
  const LIMIT_MAX = 100;
  const text = (v) => (v === null || v === undefined ? '' : String(v));

  function compare(x, y) {
    if (typeof x === 'number' && typeof y === 'number') return x - y;
    return text(x).localeCompare(text(y), 'en', { numeric: true, sensitivity: 'base' });
  }

  // The cursor carries the offset of the page's first row. Opaque to pages: only this helper (and
  // in the app, only the server) reads it.
  function offsetOf(cursor) {
    if (cursor === '' || cursor === null || cursor === undefined) return 0;
    const m = /^o(\d+)$/.exec(String(cursor));
    if (!m) throw new Error(`listQuery: ${cursor} is not a cursor this list gave`);
    return Number(m[1]);
  }

  function listQuery(rows, opts) {
    const o = opts || {};
    let out = rows.slice();
    const q = (o.search || '').trim().toLowerCase();
    if (q) {
      const keys = o.searchKeys || [];
      if (!keys.length) throw new Error('listQuery: a search needs searchKeys, the row fields it looks in');
      out = out.filter((r) => keys.map((k) => text(r[k])).join(' ').toLowerCase().includes(q));
    }
    const filters = Array.isArray(o.filters) ? o.filters : Object.entries(o.filters || {}).map(([key, value]) => ({ key, value }));
    for (const f of filters) {
      const v = f.value;
      if (v === '' || v === null || v === undefined) continue;
      out = out.filter((r) => (f.fn ? f.fn(r, v) : text(r[f.key]) === String(v)));
    }
    if (o.sort) {
      const desc = o.sort.startsWith('-');
      const key = desc ? o.sort.slice(1) : o.sort;
      out = out.map((r, i) => ({ r, i })).sort((a, b) => (desc ? -1 : 1) * compare(a.r[key], b.r[key]) || a.i - b.i).map((x) => x.r);
    }
    const limit = Math.min(Math.max(1, Math.floor(Number(o.limit)) || LIMIT), LIMIT_MAX);
    const start = offsetOf(o.cursor);
    const end = start + limit;
    return { rows: out.slice(start, end), next_cursor: end < out.length ? `o${end}` : null, limit };
  }

  window.listQuery = listQuery;
}());
