// notifications: these keys go into data/fixtures.js's window.FIXTURES (the module's README says how).
  "notifications": [
    {
      "id": "ntf_7",
      "kind": "new_sign_in",
      "created_at": "2026-10-25T08:55:00Z",
      "title": "New sign-in to your account",
      "body": "Chrome on Windows, near Kampala. If this was not you, change your password.",
      "link": "/account/security",
      "read": false
    },
    {
      "id": "ntf_8",
      "kind": "export_ready",
      "created_at": "2026-10-25T08:42:00Z",
      "title": "Your CSV export is ready",
      "body": "Invoices report, 128 rows.",
      "link": "/invoices",
      "read": false
    },
    {
      "id": "ntf_5",
      "kind": "refund_status",
      "created_at": "2026-10-24T16:10:00Z",
      "title": "Refund requested for INV-1004",
      "body": "Waiting for the provider to confirm.",
      "link": "/invoices/INV-1004",
      "read": true
    },
    {
      "id": "ntf_6",
      "kind": "team_change",
      "created_at": "2026-10-24T10:05:00Z",
      "title": "Isaac Mugisha changed role",
      "body": "Isaac is now in Support.",
      "link": "/settings/users/usr_1012",
      "read": false
    },
    {
      "id": "ntf_2",
      "kind": "export_ready",
      "created_at": "2026-10-22T17:46:00Z",
      "title": "Your PDF export is ready",
      "body": "Invoices report, 128 rows.",
      "link": "/invoices",
      "read": true
    },
    {
      "id": "ntf_4",
      "kind": "weekly_summary",
      "created_at": "2026-10-20T06:00:00Z",
      "title": "Your weekly summary",
      "body": "Volume up 12.4% on the week before.",
      "link": "/dashboard",
      "read": true
    },
    {
      "id": "ntf_1",
      "kind": "weekly_summary",
      "created_at": "2026-10-13T06:00:00Z",
      "title": "Your weekly summary",
      "body": "Volume down 3.1% on the week before.",
      "link": "/dashboard",
      "read": true
    },
    {
      "id": "ntf_3",
      "kind": "team_change",
      "created_at": "2026-10-12T08:00:00Z",
      "title": "David Ssemakula changed role",
      "body": "David is now in Finance.",
      "link": "/settings/users/usr_1008",
      "read": true
    }
  ],
  "notification_preferences": [
    {
      "event": "new_sign_in",
      "label": "A new sign-in to your account",
      "email": true,
      "locked": true
    },
    {
      "event": "export_ready",
      "label": "An export is ready",
      "email": false,
      "locked": false
    },
    {
      "event": "refund_status",
      "label": "A refund changes status",
      "email": false,
      "locked": false
    },
    {
      "event": "team_change",
      "label": "Changes to your team",
      "email": true,
      "locked": false
    },
    {
      "event": "weekly_summary",
      "label": "Weekly summary",
      "email": true,
      "locked": false
    }
  ],
