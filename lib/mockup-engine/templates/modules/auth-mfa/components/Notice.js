// Notice: an inline message. Errors are alerts (announced at once); the rest are status messages.
// props { tone: 'info' | 'success' | 'warning' | 'danger', text }
MK.component('Notice', ({ tone = 'info', text }) => MK.html`
  <p class="notice notice--${tone}" role="${tone === 'danger' ? 'alert' : 'status'}">${text}</p>
`, { layer: 'composite' });
