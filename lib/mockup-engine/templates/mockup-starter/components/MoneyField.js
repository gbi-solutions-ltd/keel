// MoneyField: an amount typed in. The field shows the amount with thousands separators after every
// keystroke, state keeps the digits only (in major units), and the form submits the plain integer
// in minor units from a hidden input that carries the name; the visible input has no name. The
// shell's moneyInput action (AppLayout.js) keeps the digits in state.values[name] and the caret
// after the same digit. Helpers: data/money.js.
// props { id, name, label, value (digits, as state keeps them), currency, hint, error, required,
//         action = 'moneyInput' }
MK.component('MoneyField', ({ id, name, label, value = '', currency, hint, error, required, action = 'moneyInput' }) => {
  const digits = String(value ?? '');
  const described = [hint && `${id}-hint`, error && `${id}-error`].filter(Boolean).join(' ');
  return MK.html`
  <div class="money-field">
    <label class="money-field__label" for="${id}">${label}<span class="visually-hidden"> ${MK.t('MoneyField.currency', { currency })}</span></label>
    <div class="money-field__wrap">
      <span class="money-field__currency" aria-hidden="true">${currency}</span>
      <input class="money-field__input" id="${id}" type="text" inputmode="${window.money.decimals(currency) ? 'decimal' : 'numeric'}" autocomplete="off"
        value="${window.money.group(digits)}"
        ${required ? MK.raw('required') : ''} ${described ? MK.html`aria-describedby="${described}"` : ''} ${error ? MK.raw('aria-invalid="true"') : ''}
        data-action="${action}" data-on="input" data-field="${name}" data-currency="${currency}">
      <input type="hidden" name="${name}" value="${String(window.money.minorUnits(digits, currency))}">
    </div>
    ${hint ? MK.html`<p class="money-field__hint" id="${id}-hint">${hint}</p>` : ''}
    ${error ? MK.html`<p class="money-field__error" id="${id}-error">${error}</p>` : ''}
  </div>`;
}, { layer: 'composite' });
