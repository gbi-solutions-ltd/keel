// PermissionGrid: which role holds each permission, as an ARIA grid (the WAI-ARIA grid pattern).
// The grid is one Tab stop: the active cell has tabindex="0" and every other cell "-1" (roving
// tabindex). Arrow keys move one cell, Home and End to the ends of the row, Ctrl+Home and Ctrl+End
// to the first and last cell; data/grid.js says where a key goes. The page keeps the active cell
// in state, its keyAction moves it and puts focus on the new cell (ctx.focus), and its
// clickAction makes a clicked cell the active one. Cell ids are `${id}-${row}-${col}`.
// props { id, caption, columns: { label }[], rows: { label, cells: boolean[] }[],
//         active: { row, col }, keyAction, clickAction }
MK.component('PermissionGrid', ({ id, caption, columns, rows, active, keyAction, clickAction }) => MK.html`
  <div class="permission-grid">
    <table class="permission-grid__table" role="grid" id="${id}" data-rows="${rows.length}" data-cols="${columns.length}"
      data-action="${keyAction}" data-on="keydown">
      <caption class="visually-hidden">${caption}</caption>
      <thead>
        <tr><th scope="col">${MK.t('PermissionGrid.permission')}</th>${columns.map((c) => MK.html`<th scope="col">${c.label}</th>`)}</tr>
      </thead>
      <tbody>
        ${rows.map((r, i) => MK.html`<tr>
          <th scope="row">${r.label}</th>
          ${r.cells.map((held, j) => MK.html`<td id="${id}-${i}-${j}" class="permission-grid__cell ${held ? 'permission-grid__cell--held' : ''}"
            tabindex="${i === active.row && j === active.col ? '0' : '-1'}" data-action="${clickAction}" data-row="${i}" data-col="${j}">${held ? MK.t('PermissionGrid.held') : MK.t('PermissionGrid.notHeld')}</td>`)}
        </tr>`)}
      </tbody>
    </table>
  </div>
`, { layer: 'composite' });
