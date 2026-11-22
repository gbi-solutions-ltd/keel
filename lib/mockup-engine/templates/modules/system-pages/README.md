# system-pages: 404, a failed page, maintenance, offline

Pages: `not-found` (route `*`), `server-error` (a page that failed to render), `maintenance`, all
public. Components: `AuthLayout` (the maintenance page's frame) and `Notice` (the banner). Fixtures: `system`. Screens: 3.

The 404 page links to the app's first page (`./invoices.html` in the starter): point it at the
mockup's. The starter's `ErrorPage` and `ForbiddenPage` (403) are already in the starter.

Shell: the offline banner, previewed with `?system=offline`: in `AppLayout`, before `main`,
`params.system === 'offline' ? MK.html`<div class="app-layout__banner">${MK.components.Notice({
tone: 'warning', text: '...', action })}</div>` : ''`, with a `reloadPage` action; load
`Notice.js` on every page.
