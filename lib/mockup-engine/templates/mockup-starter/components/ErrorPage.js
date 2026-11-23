// ErrorPage: a whole-page refusal, miss or failure (403, 404, a page that could not be shown).
// props { code, title, body, link: { label, href }, reference, reloadAction }
MK.component('ErrorPage', ({ code, title, body, link, reference, reloadAction }) => MK.html`
  <div class="error-page">
    <p class="error-page__code">${code}</p>
    <h1>${title}</h1>
    <p class="muted">${body}</p>
    ${reference ? MK.html`<p class="error-page__reference">${MK.t('ErrorPage.reference')} <span class="mono" data-diff-ignore>${reference}</span></p>` : ''}
    ${reloadAction || link ? MK.html`<div class="row error-page__actions">
      ${reloadAction ? MK.html`<button type="button" class="button button--primary" data-action="${reloadAction}">${MK.t('ErrorPage.reload')}</button>` : ''}
      ${link ? MK.html`<a class="button" href="${link.href}">${link.label}</a>` : ''}
    </div>` : ''}
  </div>
`, { layer: 'composite' });
