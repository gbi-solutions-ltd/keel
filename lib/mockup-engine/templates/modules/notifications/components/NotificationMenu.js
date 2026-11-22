// NotificationMenu: the bell in the header, with the unread count, and a panel of the latest.
// props { open, unread, items, menuAction, readAllAction, allHref }
MK.component('NotificationMenu', ({ open, unread, items, menuAction, readAllAction, allHref }) => MK.html`
  <div class="notification-menu popover-menu">
    <button type="button" id="notification-bell" class="notification-menu__bell" aria-expanded="${String(open)}" aria-controls="notification-menu" data-action="${menuAction}">
      <svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true" focusable="false"><path fill="currentColor" d="M12 22a2.5 2.5 0 0 0 2.45-2h-4.9A2.5 2.5 0 0 0 12 22Zm7-6V11a7 7 0 0 0-5.5-6.84V3.5a1.5 1.5 0 0 0-3 0v.66A7 7 0 0 0 5 11v5l-2 2v1h18v-1l-2-2Z"/></svg>
      <span class="visually-hidden">Notifications${unread ? `, ${unread} unread` : ''}</span>
      ${unread ? MK.html`<span class="notification-menu__count" aria-hidden="true">${unread > 9 ? '9+' : unread}</span>` : ''}
    </button>
    ${open ? MK.html`
    <div class="popover-menu__panel notification-menu__panel" id="notification-menu" role="group" aria-labelledby="notification-menu-heading">
      <div class="row row--between">
        <h2 class="notification-menu__heading" id="notification-menu-heading">Notifications</h2>
        ${unread ? MK.html`<button type="button" class="button button--small" data-action="${readAllAction}">Mark all as read</button>` : ''}
      </div>
      ${items.length ? MK.components.NotificationList({ items, compact: true }) : MK.html`<p class="muted">You are all caught up.</p>`}
      <a href="${allHref}">See all notifications</a>
    </div>` : ''}
  </div>
`, { layer: 'composite' });
