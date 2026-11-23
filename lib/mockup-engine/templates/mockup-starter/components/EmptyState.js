// EmptyState: props { title, body }. Every list page renders it for ?state=empty.
MK.component('EmptyState', ({ title, body }) => MK.html`
  <div class="empty-state"><h2>${title}</h2><p class="muted">${body}</p></div>
`, { layer: 'composite' });
