// UserStatusBadge: a user's status as a badge. props { status, invitationExpired }
const USER_STATUS = {
  active: { tone: 'success', label: 'Active' },
  invited: { tone: 'warning', label: 'Invited' },
  deactivated: { tone: 'neutral', label: 'Deactivated' },
  revoked: { tone: 'neutral', label: 'Invitation revoked' },
};
MK.component('UserStatusBadge', ({ status, invitationExpired }) => (invitationExpired
  ? MK.components.Badge({ tone: 'danger', label: 'Invitation expired' })
  : MK.components.Badge(USER_STATUS[status])), { layer: 'domain' });
