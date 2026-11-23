// AccountMenu: the account button in the header and its menu. props { open, label, menuAction, signOutAction, links: { label, href, current }[] }
MK.component('AccountMenu', ({ open, label, menuAction, signOutAction, links }) => MK.html`
  <div class="account-menu popover-menu">
    <button type="button" class="account-menu__button" aria-expanded="${String(open)}" aria-controls="account-menu" data-action="${menuAction}">${label}</button>
    ${open ? MK.html`
    <div class="popover-menu__panel" id="account-menu" role="group" aria-label="Account">
      ${links.map((l) => MK.html`<a class="account-menu__link" href="${l.href}" ${l.current ? MK.raw('aria-current="page"') : ''}>${l.label}</a>`)}
      <button type="button" class="button button--block" data-action="${signOutAction}">Sign out</button>
    </div>` : ''}
  </div>
`, { layer: 'composite' });
