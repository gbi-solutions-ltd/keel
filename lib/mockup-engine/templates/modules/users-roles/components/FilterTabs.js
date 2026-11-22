// FilterTabs: props { options: { value, label }[], value, action }.
// Fires the page action named in `action` with data-value of the pressed tab.
MK.component('FilterTabs', ({ options, value, action, label }) => MK.html`
  <fieldset class="filter-tabs">
    <legend class="visually-hidden">${label}</legend>
    ${options.map((o) => MK.html`
      <button type="button" class="filter-tabs__tab" aria-pressed="${String(o.value === value)}"
        data-action="${action}" data-value="${o.value}">${o.label}</button>`)}
  </fieldset>
`, { layer: 'composite' });
