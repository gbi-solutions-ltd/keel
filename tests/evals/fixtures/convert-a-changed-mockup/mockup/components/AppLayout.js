// AppLayout: the shell every page shares. Becomes the app's layout route plus a shell context:
// navigation built from the same permissions as the routes, the page shown to a role without
// access, the offline banner (system-pages module) and the actions every page's fields share.
//
// Shell actions (they merge into every page's actions):
//   setValue     a TextField or TextAreaField with action 'setValue' keeps its text in
//                state.values[name], so a re-render never resets what was typed
//   focusSearch  the '/' key: focus the page's search field, when it has one
//   reloadPage   the error page's reload button
//
// ?system=offline previews the offline banner (the app also shows it when the browser is offline,
// or a request failed at the network level and none has succeeded since). Nothing changes it, so
// the layout reads it from its params. Work done offline is not queued (intake question 10).

MK.shell({
  layout: 'AppLayout',
  forbidden: 'ForbiddenPage',
  nav: [
    { labelKey: 'shell.nav.equipment', href: './equipment.html', route: '/equipment', permission: 'equipment:read' },
    { labelKey: 'shell.nav.myRequests', href: './my-requests.html', route: '/loans/mine', permission: 'loan:request' },
    { labelKey: 'shell.nav.requests', href: './requests.html', route: '/requests', permission: 'loan:manage' },
  ],
  // A bare key such as '/' never fires while the user types in a field.
  keys: { '/': 'focusSearch' },
  state: {},
  load: (fx) => ({ organisation: fx.organisation.name }),

  actions: {
    focusSearch(_state, _e, _el, ctx) { ctx.focus('equipment-search'); },
    setValue(state, _e, el) { state.values = { ...state.values, [el.name]: el.value }; },
    reloadPage() { location.reload(); return false; },
  },
});

MK.component('AppLayout', ({ page, nav, session, shell, params, children }) => MK.html`
  <div class="app-layout">
    <header class="app-layout__header">
      <div class="app-layout__bar">
        <a class="app-layout__brand" href="${nav[0]?.href ?? '#'}">${MK.t('shell.brand')}</a>
        <nav class="app-layout__nav" aria-label="${MK.t('shell.nav.label')}">
          ${nav.map((n) => MK.html`<a href="${n.href}" ${page.route.startsWith(n.route) ? MK.raw('aria-current="page"') : ''}>${n.label}</a>`)}
        </nav>
        <span class="app-layout__role muted">${shell.organisation}, ${session.label}</span>
      </div>
    </header>
    ${params.system === 'offline' ? MK.html`<div class="app-layout__banner">${MK.components.Notice({ tone: 'warning', text: MK.t('shell.offline') })}</div>` : ''}
    <main class="app-layout__main">${children}</main>
  </div>
`, { layer: 'layout' });

MK.component('ForbiddenPage', () => MK.components.ErrorPage({
  code: '403',
  title: MK.t('ForbiddenPage.title'),
  body: MK.t('ForbiddenPage.body'),
}), { layer: 'composite' });
