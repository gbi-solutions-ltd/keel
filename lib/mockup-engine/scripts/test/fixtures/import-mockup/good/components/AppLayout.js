// AppLayout: the shell.
const PAGES = [[/^\/invoices$/, () => './invoices.html']];
window.pageFor = (path) => MK.href(PAGES[0][1]());

MK.shell({
  layout: 'AppLayout',
  forbidden: 'ForbiddenPage',
  nav: [
    { label: 'Invoices', href: './invoices.html', route: '/invoices', permission: 'invoice:read' },
    { label: 'Help', href: './help.html' },
  ],
  keys: { '/': 'focusSearch' },
  state: ({ params }) => ({ open: params.open === '1' }),
  load: (fx) => ({ organisation: fx.organisation.name }),
  actions: { focusSearch(_s, _e, _el, ctx) { ctx.focus('search'); } },
});

MK.onRender(() => {});
MK.component('AppLayout', ({ nav, children }) => MK.html`<nav>${nav.map((n) => n.label)}</nav>${children}`);
MK.component('ForbiddenPage', () => MK.components.ErrorPage({ title: 'No access' }));
