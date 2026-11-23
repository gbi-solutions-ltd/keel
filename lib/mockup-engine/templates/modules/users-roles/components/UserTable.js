// UserTable: users as a DataTable. Each name links to the user. props { users, roles }
MK.component('UserTable', ({ users, roles }) => MK.components.DataTable({
  caption: 'Users',
  columns: [
    { key: 'name', label: 'Name', cell: (u) => MK.html`<a href="${MK.href(`./user-detail.html?id=${u.id}`)}">${u.name}</a><br><span class="muted">${u.email}</span>` },
    { key: 'role', label: 'Role', cell: (u) => roles[u.role]?.label ?? u.role },
    { key: 'status', label: 'Status', cell: (u) => MK.components.UserStatusBadge({ status: u.status, invitationExpired: u.invitation?.expired }) },
    { key: 'last_active_at', label: 'Last active', cell: (u) => (u.last_active_at ? MK.format.dateTime(u.last_active_at) : MK.html`<span class="muted">Never</span>`) },
  ],
  rows: users,
}), { layer: 'domain' });
