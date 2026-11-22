// ColumnMenu: choose which table columns to show. A disclosure: a button and a panel of
// checkboxes. props { columns: { key, label, locked }[], hidden, open, menuAction, toggleAction }
MK.component('ColumnMenu', ({ columns, hidden, open, menuAction, toggleAction }) => MK.html`
  <div class="column-menu popover-menu">
    <button type="button" class="button" aria-expanded="${String(open)}" aria-controls="column-menu" data-action="${menuAction}">Columns</button>
    ${open ? MK.html`
    <fieldset class="popover-menu__panel" id="column-menu">
      <legend class="popover-menu__legend">Show columns</legend>
      ${columns.map((c) => MK.html`
        <label class="checkbox-row">
          <input type="checkbox" data-action="${toggleAction}" data-value="${c.key}" ${hidden.includes(c.key) ? '' : MK.raw('checked')} ${c.locked ? MK.raw('disabled') : ''}>
          ${c.label}
        </label>`)}
    </fieldset>` : ''}
  </div>
`, { layer: 'composite' });
