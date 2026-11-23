// ToggleList: a list of on and off choices, each saved as it changes. A locked one stays on and
// says why. props { legend, items: { id, label, checked, locked, lockedReason }[], action }
MK.component('ToggleList', ({ legend, items, action }) => MK.html`
  <fieldset class="toggle-list">
    <legend class="toggle-list__legend">${legend}</legend>
    ${items.map((i) => MK.html`
      <div class="toggle-list__row">
        <label class="checkbox-row" for="toggle-${i.id}">
          <input type="checkbox" id="toggle-${i.id}" data-action="${action}" data-value="${i.id}" ${i.checked ? MK.raw('checked') : ''} ${i.locked ? MK.raw(`disabled aria-describedby="toggle-${i.id}-reason"`) : ''}>
          ${i.label}
        </label>
        ${i.locked ? MK.html`<p class="toggle-list__reason muted" id="toggle-${i.id}-reason">${i.lockedReason}</p>` : ''}
      </div>`)}
  </fieldset>
`, { layer: 'composite' });
