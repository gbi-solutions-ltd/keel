# Mockup modules

The seven optional modules a mockup may opt into (`skills/mockup/references/modules.md` says what
each is for and which checklist items it settles). Each folder holds one module's files, written
to the starter's layout: copy the starter first, then add only the modules the client opted into.

| Folder | What it adds |
|---|---|
| [`auth-mfa/`](auth-mfa/README.md) | sign in, the second step, account security, authenticator set-up |
| [`tours-help/`](tours-help/README.md) | the help centre and guided tours (driver.js) |
| [`users-roles/`](users-roles/README.md) | users, a user, roles and permissions |
| [`audit-log/`](audit-log/README.md) | the audit log, filterable and exportable |
| [`session-password/`](session-password/README.md) | forgot and reset password, signed out, the idle warning |
| [`notifications/`](notifications/README.md) | notifications, their settings, the bell and the account menu |
| [`system-pages/`](system-pages/README.md) | 404, a page that failed to render, maintenance, the offline banner |

## Adding a module

1. Copy its `pages/`, `components/` and any `assets/` and `data/` files into the mockup, at the
   same paths. A component the mockup already has (two modules share `Dialog`, `Notice` and
   others) is the same file: keep one.
2. Append its `components.css` to `assets/components.css`.
3. Paste its `fixtures.js` keys into `data/fixtures.js`, inside `window.FIXTURES`, and reshape the
   sample records to the client's domain. They are shaped like the API's responses, which is what
   the contract is drafted from.
4. Add `screens.json`'s entries to `mockup.config.json`'s `screens`, and the module's name to
   `modules`.
5. Give the mockup's roles the permissions its pages need (the module's README names them).
6. Make the shell changes its README lists, in `components/AppLayout.js`, and add any shell
   component's script to every page that renders the shell.
7. Move the module's text into `strings/<locale>.js` through `MK.t`, as the rest of the mockup's
   text is: the module pages carry literal English. That is part of the Mock build, checked by the
   inventory like any other page.

Then run the inventory: a declared module whose routes have no page fails it (`module-page`).

These files are extracted from the engine's proving repository, which holds the full example
mockup and its React port, and held to it there; change them there, not here.
