// AuditTable: audit events as a DataTable. The API sends an action code (user.invited); the UI
// names it here, and an action it does not know shows as the code, never as nothing.
// props { events, hidden }
const AUDIT_ACTIONS = {
  'auth.signed_in': 'Signed in',
  'auth.sign_in_failed': 'Sign-in failed',
  'auth.mfa_added': 'Added a sign-in method',
  'auth.mfa_removed': 'Removed a sign-in method',
  'auth.recovery_codes_replaced': 'Replaced recovery codes',
  'auth.password_changed': 'Changed password',
  'user.invited': 'Invited a user',
  'user.invite_resent': 'Resent an invitation',
  'user.invitation_expired': 'Invitation expired',
  'user.role_changed': 'Changed a role',
  'user.deactivated': 'Deactivated a user',
  'export.created': 'Exported a report',
  'refund.requested': 'Requested a refund',
};
const auditDetails = (d) => (d.from && d.to ? `${d.from} to ${d.to}` : Object.values(d).join(', '));
MK.component('AuditTable', ({ events, hidden }) => MK.components.DataTable({
  caption: 'Audit log',
  hidden,
  columns: [
    { key: 'occurred_at', label: 'Time', cell: (e) => MK.format.dateTime(e.occurred_at) },
    { key: 'actor', label: 'Who', cell: (e) => (e.actor.type === 'user' ? e.actor.name : MK.html`<span class="muted">${e.actor.type === 'system' ? 'The system (automatic)' : 'Not signed in'}</span>`) },
    { key: 'action', label: 'Action', cell: (e) => AUDIT_ACTIONS[e.action] ?? e.action },
    { key: 'target', label: 'Target', cell: (e) => e.target?.label ?? '' },
    { key: 'details', label: 'Details', cell: (e) => auditDetails(e.details) },
    { key: 'outcome', label: 'Outcome', cell: (e) => MK.components.Badge(e.outcome === 'success' ? { tone: 'success', label: 'Succeeded' } : { tone: 'danger', label: 'Failed' }) },
    { key: 'ip', label: 'IP address', cell: (e) => (e.ip ? MK.html`<span class="mono">${e.ip}</span>` : '') },
    { key: 'request_id', label: 'Request ID', cell: (e) => MK.html`<span class="mono">${e.request_id}</span>` },
  ],
  rows: events,
}), { layer: 'domain' });
