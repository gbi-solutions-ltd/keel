# session-password: password reset, signing out, the idle warning

Pages: `forgot-password` (`/forgot-password`), `reset-password` (`/reset-password?token=`),
`signed-out` (`/signed-out?reason=`), all public, on `AuthLayout`. Components: `AuthLayout`,
`Dialog`, `Notice`, `SessionTimeoutDialog`. Screens: 11. Fixtures: none of its own: the session's
`idle_timeout_seconds` and `idle_warning_seconds` go on `session` in `data/fixtures.js`.

Shell: the idle warning. In `MK.shell`, `state: ({ params }) => ({ sessionExpiring: params.session
=== 'expiring' })` (the preview flag `?session=expiring`), actions `staySignedIn` (clears it) and
`signOut` (navigates to `./signed-out.html?reason=manual`), and in `AppLayout`, after `main`:
`state.sessionExpiring ? MK.components.SessionTimeoutDialog({ minutes, stayAction: 'staySignedIn',
signOutAction: 'signOut' }) : ''`, with the minutes from `idle_warning_seconds`. Load
`SessionTimeoutDialog.js` on every page.
