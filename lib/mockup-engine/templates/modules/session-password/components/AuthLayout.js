// AuthLayout: the frame for signed-out pages (sign in, verify). No menu, no search.
MK.component('AuthLayout', ({ children }) => MK.html`
  <div class="auth-layout">
    <main class="auth-layout__main">
      <p class="auth-layout__brand">Your app</p>
      <div class="card auth-layout__card">${children}</div>
    </main>
  </div>
`, { layer: 'layout' });
