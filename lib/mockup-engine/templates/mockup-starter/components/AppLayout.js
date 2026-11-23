// AppLayout: the shell every page shares. Becomes the app's layout route plus a shell context:
// navigation built from the same permissions as the routes, the page shown to a role without
// access, and the actions every page's fields share.
//
// Shell actions (they merge into every page's actions):
//   setValue     a TextField with action 'setValue' keeps its text in state.values[name], so a
//                re-render never resets what was typed
//   moneyInput   a MoneyField keeps its digits in state.values[name] and its caret after the same
//                digit (the MK.onRender hook below)
//   focusSearch  the '/' key: focus the page's search field, when it has one
// Modules (templates/modules/, each README's Shell) add to this file: the notification bell, the
// account menu, the idle warning, the offline banner.

// Where the caret goes after a money field is regrouped: after as many digits as it was before.
// moneyInput records it, the render hook below applies it.
let moneyCaret = null;

MK.shell({
  layout: 'AppLayout',
  forbidden: 'ForbiddenPage',
  nav: [
    { labelKey: 'shell.nav.invoices', href: './invoices.html', route: '/invoices', permission: 'invoice:read' },
    { labelKey: 'shell.nav.access', href: './access.html', route: '/settings/access', permission: 'role:read' },
  ],
  // A bare key such as '/' never fires while the user types in a field; a chord such as
  // 'mod+enter' or 'ctrl+d' does (skills/mockup/references/mockup-conventions.md, the shell).
  keys: { '/': 'focusSearch' },
  // Shell state may also be a function of the URL's params, for a preview flag:
  // state: ({ params }) => ({ sessionExpiring: params.session === 'expiring' })
  state: {},
  load: (fx) => ({ organisation: fx.organisation.name }),

  actions: {
    focusSearch(_state, _e, _el, ctx) { ctx.focus('invoice-search'); },
    setValue(state, _e, el) { state.values = { ...state.values, [el.name]: el.value }; },
    // A point typed (not pasted) in a currency with no minor unit changes nothing: the amount and
    // the caret stay as they were, instead of the digits after the point being dropped.
    moneyInput(state, e, el) {
      const currency = el.dataset.currency;
      const before = el.selectionStart ?? el.value.length;
      const strayPoint = e?.inputType === 'insertText' && e.data === '.' && !window.money.decimals(currency);
      moneyCaret = { id: el.id, n: el.value.slice(0, strayPoint ? before - 1 : before).replace(/[^\d.]/g, '').length };
      if (strayPoint) return undefined; // drawn again, so the field shows the amount without the point
      state.values = { ...state.values, [el.dataset.field]: window.money.digits(el.value, currency) };
      return undefined;
    },
  },
});

// The money field's caret: after a render regroups the digits, the caret goes back after the same
// number of digits, so typing in the middle of an amount keeps its place. Shell owned, as every
// MK.onRender hook is; in the app it is the money input component's own nextTick or effect.
MK.onRender(() => {
  const c = moneyCaret;
  moneyCaret = null;
  const el = c && document.activeElement;
  if (!el || el.id !== c.id || typeof el.setSelectionRange !== 'function') return;
  const at = window.money.caretAfter(el.value, c.n);
  el.setSelectionRange(at, at);
});

MK.component('AppLayout', ({ page, nav, session, shell, children }) => MK.html`
  <div class="app-layout">
    <header class="app-layout__header">
      <div class="app-layout__bar">
        <a class="app-layout__brand" href="${nav[0]?.href ?? '#'}">${shell.organisation}</a>
        <nav class="app-layout__nav" aria-label="${MK.t('shell.nav.label')}">
          ${nav.map((n) => MK.html`<a href="${n.href}" ${page.route.startsWith(n.route) ? MK.raw('aria-current="page"') : ''}>${n.label}</a>`)}
        </nav>
        <span class="app-layout__role muted">${session.label}</span>
      </div>
    </header>
    <main class="app-layout__main">${children}</main>
  </div>
`, { layer: 'layout' });

MK.component('ForbiddenPage', () => MK.components.ErrorPage({
  code: '403',
  title: MK.t('ForbiddenPage.title'),
  body: MK.t('ForbiddenPage.body'),
}), { layer: 'composite' });
