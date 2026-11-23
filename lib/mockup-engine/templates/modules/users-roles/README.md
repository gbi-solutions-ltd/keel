# users-roles: users, a user, roles

Pages: `users` (`/settings/users`), `user-detail` (`/settings/users/:id`, the mockup passes the id
as `?id=`), `roles` (`/settings/roles`). Components: `UserTable`, `UserStatusBadge`, `RoleCard`,
`DetailList`, `Dialog`, `FilterTabs`, `Notice`, `RadioGroup`. Fixtures: `users`,
`permission_labels`, and `action_permissions` (each user action to the permission it needs; merge
it with the mockup's own map if it has one). Screens: 21.

Roles: each role in `fixtures.roles` needs a `description`, which the role dialog shows; the
sample users name the starter's roles. Permissions: `user:read` to see the pages, `user:manage` to invite, change a role, deactivate and
reactivate. Give them to the roles that hold them.

Shell: a Users entry in the nav (`./users.html`, route `/settings/users`, permission `user:read`).
