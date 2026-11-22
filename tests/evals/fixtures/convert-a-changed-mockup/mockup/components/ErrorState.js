// ErrorState: props { title, body }. Copy is ours, never a server message.
MK.component('ErrorState', ({ title = MK.t('ErrorState.title'), body = MK.t('ErrorState.body') }) => MK.html`
  <div class="error-state" role="alert"><h2 class="error-state__title">${title}</h2><p class="muted">${body}</p></div>
`, { layer: 'composite' });
