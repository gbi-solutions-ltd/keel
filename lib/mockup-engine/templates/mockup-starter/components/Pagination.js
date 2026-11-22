// Pagination: previous and next for cursor pages; there is no total, by design of the API.
// `page` is counted by the page (the cursors it followed, plus one), not sent by the API.
// nextCursor, the list's next_cursor, rides on the next button as data-cursor, so the page's
// nextAction reads it from the element it is given (el.dataset.cursor); null or '' disables it.
// props { page, hasPrev, nextCursor, prevAction, nextAction }
MK.component('Pagination', ({ page, hasPrev, nextCursor, prevAction, nextAction }) => MK.html`
  <nav class="pagination" aria-label="${MK.t('Pagination.label')}">
    <button type="button" class="button" data-action="${prevAction}" ${hasPrev ? '' : MK.raw('disabled')}>${MK.t('Pagination.previous')}</button>
    <span class="muted">${MK.t('Pagination.page', { page })}</span>
    <button type="button" class="button" data-action="${nextAction}" data-cursor="${nextCursor || ''}" ${nextCursor ? '' : MK.raw('disabled')}>${MK.t('Pagination.next')}</button>
  </nav>
`, { layer: 'composite' });
