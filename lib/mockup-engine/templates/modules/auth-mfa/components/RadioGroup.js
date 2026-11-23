// RadioGroup: one choice from a short list. props { name, legend, value, options: { value, label }[], action }
MK.component('RadioGroup', ({ name, legend, value, options, action }) => MK.html`
  <fieldset class="radio-group">
    <legend class="radio-group__legend">${legend}</legend>
    ${options.map((o) => MK.html`
      <label class="radio-group__option">
        <input type="radio" name="${name}" value="${o.value}" ${o.value === value ? MK.raw('checked') : ''} data-action="${action}">
        ${o.label}
      </label>`)}
  </fieldset>
`, { layer: 'composite' });
