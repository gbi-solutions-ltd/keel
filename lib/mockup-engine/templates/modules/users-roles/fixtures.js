// users-roles: these keys go into data/fixtures.js's window.FIXTURES (the module's README says how).
  "users": [
    {
      "id": "usr_1001",
      "name": "Amina Nakato",
      "email": "amina@example.com",
      "role": "manager",
      "status": "active",
      "last_active_at": "2026-10-25T08:55:00Z",
      "created_at": "2026-03-02T09:00:00Z",
      "protected_reason": "last_admin",
      "allowed_actions": []
    },
    {
      "id": "usr_1002",
      "name": "Daniel Ochieng",
      "email": "daniel@example.com",
      "role": "manager",
      "status": "deactivated",
      "last_active_at": "2026-09-30T16:20:00Z",
      "created_at": "2026-03-02T09:10:00Z",
      "protected_reason": null,
      "allowed_actions": [
        "reactivate"
      ]
    },
    {
      "id": "usr_1003",
      "name": "Grace Atim",
      "email": "grace@example.com",
      "role": "clerk",
      "status": "active",
      "last_active_at": "2026-10-25T07:40:00Z",
      "created_at": "2026-04-11T10:00:00Z",
      "protected_reason": null,
      "allowed_actions": [
        "change_role",
        "deactivate"
      ]
    },
    {
      "id": "usr_1004",
      "name": "Peter Okello",
      "email": "peter@example.com",
      "role": "clerk",
      "status": "active",
      "last_active_at": "2026-10-24T15:05:00Z",
      "created_at": "2026-04-11T10:05:00Z",
      "protected_reason": null,
      "allowed_actions": [
        "change_role",
        "deactivate"
      ]
    },
    {
      "id": "usr_1005",
      "name": "Sarah Namutebi",
      "email": "sarah@example.com",
      "role": "auditor",
      "status": "active",
      "last_active_at": "2026-10-25T06:30:00Z",
      "created_at": "2026-05-20T08:00:00Z",
      "protected_reason": null,
      "allowed_actions": [
        "change_role",
        "deactivate"
      ]
    },
    {
      "id": "usr_1006",
      "name": "Moses Kato",
      "email": "moses@example.com",
      "role": "auditor",
      "status": "active",
      "last_active_at": "2026-10-23T12:10:00Z",
      "created_at": "2026-05-20T08:05:00Z",
      "protected_reason": null,
      "allowed_actions": [
        "change_role",
        "deactivate"
      ]
    },
    {
      "id": "usr_1007",
      "name": "Esther Achieng",
      "email": "esther@example.com",
      "role": "auditor",
      "status": "active",
      "last_active_at": "2026-10-22T09:45:00Z",
      "created_at": "2026-06-01T08:00:00Z",
      "protected_reason": null,
      "allowed_actions": [
        "change_role",
        "deactivate"
      ]
    },
    {
      "id": "usr_1008",
      "name": "David Ssemakula",
      "email": "david@example.com",
      "role": "clerk",
      "status": "active",
      "last_active_at": "2026-10-20T11:00:00Z",
      "created_at": "2026-06-15T08:00:00Z",
      "protected_reason": null,
      "allowed_actions": [
        "change_role",
        "deactivate"
      ]
    },
    {
      "id": "usr_1009",
      "name": "Joan Akello",
      "email": "joan@example.com",
      "role": "auditor",
      "status": "invited",
      "last_active_at": null,
      "created_at": "2026-10-23T09:00:00Z",
      "invitation": {
        "sent_at": "2026-10-23T09:00:00Z",
        "expires_at": "2026-10-30T09:00:00Z",
        "expired": false
      },
      "protected_reason": null,
      "allowed_actions": [
        "change_role",
        "resend_invite",
        "revoke_invite"
      ]
    },
    {
      "id": "usr_1010",
      "name": "Brian Tumusiime",
      "email": "brian@example.com",
      "role": "clerk",
      "status": "invited",
      "last_active_at": null,
      "created_at": "2026-10-10T09:00:00Z",
      "invitation": {
        "sent_at": "2026-10-10T09:00:00Z",
        "expires_at": "2026-10-17T09:00:00Z",
        "expired": true
      },
      "protected_reason": null,
      "allowed_actions": [
        "change_role",
        "resend_invite",
        "revoke_invite"
      ]
    },
    {
      "id": "usr_1011",
      "name": "Christine Nansubuga",
      "email": "christine@example.com",
      "role": "auditor",
      "status": "deactivated",
      "last_active_at": "2026-08-30T10:00:00Z",
      "created_at": "2026-05-20T08:10:00Z",
      "protected_reason": null,
      "allowed_actions": [
        "reactivate"
      ]
    },
    {
      "id": "usr_1012",
      "name": "Isaac Mugisha",
      "email": "isaac@example.com",
      "role": "auditor",
      "status": "active",
      "last_active_at": "2026-10-18T14:20:00Z",
      "created_at": "2026-07-01T08:00:00Z",
      "protected_reason": null,
      "allowed_actions": [
        "change_role",
        "deactivate"
      ]
    }
  ],
  "permission_labels": {
    "dashboard:read": "See the dashboard",
    "invoice:read": "See invoices",
    "invoice:export": "Export invoices",
    "invoice:refund": "Refund invoices",
    "user:read": "See users and roles",
    "user:manage": "Invite and manage users",
    "audit:read": "See the audit log"
  },
  "action_permissions": {
    "change_role": "user:manage",
    "deactivate": "user:manage",
    "reactivate": "user:manage",
    "resend_invite": "user:manage",
    "revoke_invite": "user:manage"
  },
