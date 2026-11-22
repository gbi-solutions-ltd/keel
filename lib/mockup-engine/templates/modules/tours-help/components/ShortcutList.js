// ShortcutList: keyboard shortcuts, each keys and what they do.
// props { shortcuts: { keys: string[], label }[] }; keys are alternatives ("Ctrl K" or "/")
MK.component('ShortcutList', ({ shortcuts }) => MK.html`
  <dl class="shortcut-list">
    ${shortcuts.map((s) => MK.html`
      <div class="shortcut-list__row">
        <dt>${s.keys.map((k, i) => MK.html`${i ? MK.html`<span class="muted"> or </span>` : ''}<kbd class="shortcut-list__key">${k}</kbd>`)}</dt>
        <dd>${s.label}</dd>
      </div>`)}
  </dl>
`, { layer: 'composite' });
