// SelectField: a labelled native select with an optional hint, drawn like TextField. The browser's own
// arrow is turned off (it ignores the right padding and sits about 4px from the border); the chevron
// is a background image placed with the same inset as the text (mockup-conventions.md, Fields).
// props { id, name = id, label, options: { value, label }[], value, hint, action }
// action names the action that keeps the choice in state; it fires on change. Without one the choice
// is read from the form when it is submitted.
MK.component('SelectField', ({ id, name, label, options, value = '', hint, action }) => MK.html`
  <div class="select-field">
    <label class="select-field__label" for="${id}">${label}</label>
    <select class="select-field__input" id="${id}" name="${name || id}"
      ${hint ? MK.raw(`aria-describedby="${id}-hint"`) : ''}
      ${action ? MK.raw(`data-action="${action}" data-on="change"`) : ''}>
      ${options.map((o) => MK.html`<option value="${o.value}" ${o.value === value ? MK.raw('selected') : ''}>${o.label}</option>`)}
    </select>
    ${hint ? MK.html`<p class="select-field__hint" id="${id}-hint">${hint}</p>` : ''}
  </div>
`, { layer: 'composite' });
