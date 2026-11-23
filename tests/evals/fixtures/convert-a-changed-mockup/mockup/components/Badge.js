// Badge: props { tone: 'success' | 'warning' | 'danger' | 'neutral', label }. Knows no domain types.
MK.component('Badge', ({ tone, label }) => MK.html`
  <span class="badge badge--${tone}">${label}</span>
`, { layer: 'primitive' });
