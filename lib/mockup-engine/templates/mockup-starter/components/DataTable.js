// DataTable: a sortable table with chosen columns. Knows nothing of the domain: columns and
// cell renderers are passed in. Sorting is done by the API; this only shows and requests it.
// props { caption, columns: { key, label, sortable, numeric, cell(row) }[], rows, hidden: string[],
//         sort: '-created_at', sortAction }
MK.component('DataTable', ({ caption, columns, rows, hidden = [], sort, sortAction }) => {
  const shown = columns.filter((c) => !hidden.includes(c.key));
  const dir = (key) => (sort === key ? 'ascending' : sort === `-${key}` ? 'descending' : 'none');
  // The scroll container takes focus so a keyboard user can scroll a table wider than the screen.
  return MK.html`
  <section class="data-table" aria-label="${caption}" tabindex="0">
  <table class="data-table__table">
    <caption class="visually-hidden">${caption}</caption>
    <thead>
      <tr>
        ${shown.map((c) => MK.html`
          <th scope="col" class="${c.numeric ? 'numeric' : ''}" ${c.sortable ? MK.raw(`aria-sort="${dir(c.key)}"`) : ''}>
            ${c.sortable
              ? MK.html`<button type="button" class="data-table__sort" data-action="${sortAction}" data-value="${c.key}">${c.label}<span class="data-table__sort-icon" aria-hidden="true">${dir(c.key) === 'ascending' ? '▲' : dir(c.key) === 'descending' ? '▼' : '⇅'}</span></button>`
              : c.label}
          </th>`)}
      </tr>
    </thead>
    <tbody>
      ${rows.map((r) => MK.html`<tr>${shown.map((c) => MK.html`<td class="${c.numeric ? 'numeric' : ''}">${c.cell(r)}</td>`)}</tr>`)}
    </tbody>
  </table>
  </section>`;
}, { layer: 'composite' });
