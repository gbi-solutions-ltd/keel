// TextField: a labelled input with an optional hint and error. The hint sits below the input, where
// help text goes in a form, and the input is described by the hint and the error.
// props { id, name = id, label, type, autocomplete, value, hint, error, inputmode, required, action }
// action names the page or shell action that keeps the typed text in state; it fires on input.
MK.component('TextField', ({ id, name, label, type = 'text', autocomplete = 'off', value = '', hint, error, inputmode, required, action }) => MK.html`
  <div class="text-field">
    <label class="text-field__label" for="${id}">${label}</label>
    <input class="text-field__input" id="${id}" name="${name || id}" type="${type}" autocomplete="${autocomplete}" value="${value}"
      ${inputmode ? MK.raw(`inputmode="${inputmode}"`) : ''}
      ${required ? MK.raw('required') : ''}
      ${hint || error ? MK.raw(`aria-describedby="${[hint && `${id}-hint`, error && `${id}-error`].filter(Boolean).join(' ')}"`) : ''}
      ${error ? MK.raw('aria-invalid="true"') : ''}
      ${action ? MK.raw(`data-action="${action}" data-on="input"`) : ''}>
    ${hint ? MK.html`<p class="text-field__hint" id="${id}-hint">${hint}</p>` : ''}
    ${error ? MK.html`<p class="text-field__error" id="${id}-error">${error}</p>` : ''}
  </div>
`, { layer: 'composite' });
