// NotificationList: notifications, newest first. An unread one is marked in words, not only by
// its dot, and can be marked read. props { items: { id, title, body, time, href, read }[], markAction?, compact? }
MK.component('NotificationList', ({ items, markAction, compact }) => MK.html`
  <ul class="notification-list ${compact ? 'notification-list--compact' : ''}">
    ${items.map((n) => MK.html`
      <li class="notification-list__item ${n.read ? '' : 'notification-list__item--unread'}">
        <span class="notification-list__dot" aria-hidden="true"></span>
        <div class="notification-list__text">
          <div class="notification-list__title">${n.read ? '' : MK.html`<span class="visually-hidden">Unread: </span>`}${n.href ? MK.html`<a href="${n.href}">${n.title}</a>` : n.title}</div>
          ${compact ? '' : MK.html`<p class="notification-list__body">${n.body}</p>`}
          <p class="notification-list__time muted">${n.time}</p>
        </div>
        ${markAction && !n.read ? MK.html`<button type="button" class="button button--small" data-action="${markAction}" data-value="${n.id}" aria-label="Mark as read: ${n.title}">Mark as read</button>` : ''}
      </li>`)}
  </ul>
`, { layer: 'composite' });
