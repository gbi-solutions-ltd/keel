// TextAreaField: a labelled multi-line field with an optional hint and error, laid out as
// TextField is (hint below the field; the field described by the hint and the error).
// props { id, name = id, label, value, hint, error, required, maxlength, rows, action }
MK.component('TextAreaField', ({ id, name, label, value = '', hint, error, required, maxlength, rows = 3, action }) => MK.html`
  <div class="text-area-field">
    <label class="text-area-field__label" for="${id}">${label}</label>
    <textarea class="text-area-field__input" id="${id}" name="${name || id}" rows="${rows}"
      ${maxlength ? MK.raw(`maxlength="${maxlength}"`) : ''}
      ${required ? MK.raw('required') : ''}
      ${hint || error ? MK.raw(`aria-describedby="${[hint && `${id}-hint`, error && `${id}-error`].filter(Boolean).join(' ')}"`) : ''}
      ${error ? MK.raw('aria-invalid="true"') : ''}
      ${action ? MK.raw(`data-action="${action}" data-on="input"`) : ''}>${value}</textarea>
    ${hint ? MK.html`<p class="text-area-field__hint" id="${id}-hint">${hint}</p>` : ''}
    ${error ? MK.html`<p class="text-area-field__error" id="${id}-error">${error}</p>` : ''}
  </div>
`, { layer: 'composite' });
