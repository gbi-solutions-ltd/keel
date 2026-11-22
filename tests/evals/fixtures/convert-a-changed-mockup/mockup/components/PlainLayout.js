// PlainLayout: a page shown instead of the app (maintenance), with no navigation, since none of
// the app's routes can answer. props { children }
MK.component('PlainLayout', ({ children }) => MK.html`
  <div class="plain-layout">
    <main class="plain-layout__main">
      <p class="plain-layout__brand">${MK.t('shell.brand')}</p>
      ${children}
    </main>
  </div>
`, { layer: 'layout' });
