# notifications: the list, the settings, the bell and the account menu

Pages: `notifications` (`/notifications`), `notification-settings` (`/account/notifications`).
Components: `NotificationList`, `NotificationMenu`, `AccountMenu`, `ToggleList`, `FilterTabs`.
Fixtures: `notifications`, `notification_preferences`. Screens: 6.

Shell: the bell and the account menu in the header, on every page.
- `window.pageFor(path)`: maps an app path a notification links to (the API sends `/invoices/INV-1`)
  to the mockup's page, falling back to `./not-found.html`. The notifications page and the bell
  call it; define it in `AppLayout.js` with the mockup's own routes.
- `MK.shell` state `notificationsOpen`, `accountOpen`, `readAll`; actions `toggleNotifications`,
  `toggleAccount`, `readAllNotifications`, `signOut`; and in `load`, the bell's summary (the
  latest five and the unread count, from `fx.notifications`).
- In `AppLayout`'s header: `NotificationMenu({ open, unread, items, menuAction:
  'toggleNotifications', readAllAction: 'readAllNotifications' })` and `AccountMenu({ open, label,
  menuAction: 'toggleAccount', signOutAction: 'signOut', links })`, the links to account security
  and notification settings. Load both components' scripts on every page.
