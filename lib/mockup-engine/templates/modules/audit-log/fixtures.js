// audit-log: these keys go into data/fixtures.js's window.FIXTURES (the module's README says how).
  "audit_events": [
    {
      "id": "evt_9000",
      "occurred_at": "2026-10-25T08:55:00Z",
      "actor": {
        "type": "user",
        "id": "usr_1001",
        "name": "Amina Nakato"
      },
      "action": "auth.signed_in",
      "target": null,
      "outcome": "success",
      "ip": "102.85.10.20",
      "request_id": "req_a1b2c3",
      "details": {}
    },
    {
      "id": "evt_8999",
      "occurred_at": "2026-10-25T08:41:00Z",
      "actor": {
        "type": "user",
        "id": "usr_1003",
        "name": "Grace Atim"
      },
      "action": "export.created",
      "target": {
        "type": "report",
        "id": "invoices",
        "label": "Invoices report"
      },
      "outcome": "success",
      "ip": "102.85.11.27",
      "request_id": "req_a1b694",
      "details": {
        "format": "CSV"
      }
    },
    {
      "id": "evt_8998",
      "occurred_at": "2026-10-25T07:40:00Z",
      "actor": {
        "type": "user",
        "id": "usr_1003",
        "name": "Grace Atim"
      },
      "action": "auth.signed_in",
      "target": null,
      "outcome": "success",
      "ip": "102.85.12.34",
      "request_id": "req_a1ba65",
      "details": {}
    },
    {
      "id": "evt_8997",
      "occurred_at": "2026-10-25T06:30:00Z",
      "actor": {
        "type": "user",
        "id": "usr_1005",
        "name": "Sarah Namutebi"
      },
      "action": "auth.signed_in",
      "target": null,
      "outcome": "success",
      "ip": "102.85.13.41",
      "request_id": "req_a1be36",
      "details": {}
    },
    {
      "id": "evt_8996",
      "occurred_at": "2026-10-25T06:12:00Z",
      "actor": {
        "type": "anonymous",
        "id": null,
        "name": "Not signed in"
      },
      "action": "auth.sign_in_failed",
      "target": null,
      "outcome": "failure",
      "ip": "102.85.14.48",
      "request_id": "req_a1c207",
      "details": {
        "email": "sarah@example.com"
      }
    },
    {
      "id": "evt_8995",
      "occurred_at": "2026-10-24T16:02:00Z",
      "actor": {
        "type": "user",
        "id": "usr_1001",
        "name": "Amina Nakato"
      },
      "action": "refund.requested",
      "target": {
        "type": "invoice",
        "id": "INV-1004",
        "label": "INV-1004"
      },
      "outcome": "success",
      "ip": "102.85.15.55",
      "request_id": "req_a1c5d8",
      "details": {}
    },
    {
      "id": "evt_8994",
      "occurred_at": "2026-10-24T15:05:00Z",
      "actor": {
        "type": "user",
        "id": "usr_1004",
        "name": "Peter Okello"
      },
      "action": "auth.signed_in",
      "target": null,
      "outcome": "success",
      "ip": "102.85.16.62",
      "request_id": "req_a1c9a9",
      "details": {}
    },
    {
      "id": "evt_8993",
      "occurred_at": "2026-10-24T11:30:00Z",
      "actor": {
        "type": "user",
        "id": "usr_1001",
        "name": "Amina Nakato"
      },
      "action": "user.role_changed",
      "target": {
        "type": "user",
        "id": "usr_1012",
        "label": "Isaac Mugisha"
      },
      "outcome": "success",
      "ip": "102.85.17.69",
      "request_id": "req_a1cd7a",
      "details": {
        "from": "Finance",
        "to": "Support"
      }
    },
    {
      "id": "evt_8992",
      "occurred_at": "2026-10-23T12:10:00Z",
      "actor": {
        "type": "user",
        "id": "usr_1006",
        "name": "Moses Kato"
      },
      "action": "auth.signed_in",
      "target": null,
      "outcome": "success",
      "ip": "102.85.18.76",
      "request_id": "req_a1d14b",
      "details": {}
    },
    {
      "id": "evt_8991",
      "occurred_at": "2026-10-23T09:00:00Z",
      "actor": {
        "type": "user",
        "id": "usr_1001",
        "name": "Amina Nakato"
      },
      "action": "user.invited",
      "target": {
        "type": "user",
        "id": "usr_1009",
        "label": "Joan Akello"
      },
      "outcome": "success",
      "ip": "102.85.19.83",
      "request_id": "req_a1d51c",
      "details": {
        "role": "Support"
      }
    },
    {
      "id": "evt_8990",
      "occurred_at": "2026-10-22T17:45:00Z",
      "actor": {
        "type": "user",
        "id": "usr_1003",
        "name": "Grace Atim"
      },
      "action": "export.created",
      "target": {
        "type": "report",
        "id": "invoices",
        "label": "Invoices report"
      },
      "outcome": "success",
      "ip": "102.85.20.90",
      "request_id": "req_a1d8ed",
      "details": {
        "format": "PDF"
      }
    },
    {
      "id": "evt_8989",
      "occurred_at": "2026-10-22T09:45:00Z",
      "actor": {
        "type": "user",
        "id": "usr_1007",
        "name": "Esther Achieng"
      },
      "action": "auth.signed_in",
      "target": null,
      "outcome": "success",
      "ip": "102.85.21.97",
      "request_id": "req_a1dcbe",
      "details": {}
    },
    {
      "id": "evt_8988",
      "occurred_at": "2026-10-21T14:00:00Z",
      "actor": {
        "type": "user",
        "id": "usr_1004",
        "name": "Peter Okello"
      },
      "action": "auth.mfa_added",
      "target": {
        "type": "user",
        "id": "usr_1004",
        "label": "Peter Okello"
      },
      "outcome": "success",
      "ip": "102.85.22.104",
      "request_id": "req_a1e08f",
      "details": {
        "method": "Authenticator app"
      }
    },
    {
      "id": "evt_8987",
      "occurred_at": "2026-10-20T11:00:00Z",
      "actor": {
        "type": "user",
        "id": "usr_1008",
        "name": "David Ssemakula"
      },
      "action": "auth.signed_in",
      "target": null,
      "outcome": "success",
      "ip": "102.85.23.111",
      "request_id": "req_a1e460",
      "details": {}
    },
    {
      "id": "evt_8986",
      "occurred_at": "2026-10-19T10:15:00Z",
      "actor": {
        "type": "user",
        "id": "usr_1005",
        "name": "Sarah Namutebi"
      },
      "action": "auth.password_changed",
      "target": {
        "type": "user",
        "id": "usr_1005",
        "label": "Sarah Namutebi"
      },
      "outcome": "success",
      "ip": "102.85.24.118",
      "request_id": "req_a1e831",
      "details": {}
    },
    {
      "id": "evt_8985",
      "occurred_at": "2026-10-18T14:20:00Z",
      "actor": {
        "type": "user",
        "id": "usr_1012",
        "name": "Isaac Mugisha"
      },
      "action": "auth.signed_in",
      "target": null,
      "outcome": "success",
      "ip": "102.85.25.125",
      "request_id": "req_a1ec02",
      "details": {}
    },
    {
      "id": "evt_8984",
      "occurred_at": "2026-10-17T09:00:00Z",
      "actor": {
        "type": "system",
        "id": null,
        "name": "The system"
      },
      "action": "user.invitation_expired",
      "target": {
        "type": "user",
        "id": "usr_1010",
        "label": "Brian Tumusiime"
      },
      "outcome": "success",
      "ip": null,
      "request_id": "req_a1efd3",
      "details": {}
    },
    {
      "id": "evt_8983",
      "occurred_at": "2026-10-16T13:30:00Z",
      "actor": {
        "type": "user",
        "id": "usr_1001",
        "name": "Amina Nakato"
      },
      "action": "user.invite_resent",
      "target": {
        "type": "user",
        "id": "usr_1010",
        "label": "Brian Tumusiime"
      },
      "outcome": "success",
      "ip": "102.85.27.139",
      "request_id": "req_a1f3a4",
      "details": {}
    },
    {
      "id": "evt_8982",
      "occurred_at": "2026-10-15T08:20:00Z",
      "actor": {
        "type": "anonymous",
        "id": null,
        "name": "Not signed in"
      },
      "action": "auth.sign_in_failed",
      "target": null,
      "outcome": "failure",
      "ip": "102.85.28.146",
      "request_id": "req_a1f775",
      "details": {
        "email": "unknown@example.com"
      }
    },
    {
      "id": "evt_8981",
      "occurred_at": "2026-10-14T16:40:00Z",
      "actor": {
        "type": "user",
        "id": "usr_1003",
        "name": "Grace Atim"
      },
      "action": "export.created",
      "target": {
        "type": "report",
        "id": "invoices",
        "label": "Invoices report"
      },
      "outcome": "success",
      "ip": "102.85.29.153",
      "request_id": "req_a1fb46",
      "details": {
        "format": "Excel"
      }
    },
    {
      "id": "evt_8980",
      "occurred_at": "2026-10-12T10:00:00Z",
      "actor": {
        "type": "user",
        "id": "usr_1001",
        "name": "Amina Nakato"
      },
      "action": "auth.recovery_codes_replaced",
      "target": {
        "type": "user",
        "id": "usr_1001",
        "label": "Amina Nakato"
      },
      "outcome": "success",
      "ip": "102.85.30.160",
      "request_id": "req_a1ff17",
      "details": {}
    },
    {
      "id": "evt_8979",
      "occurred_at": "2026-10-10T09:00:00Z",
      "actor": {
        "type": "user",
        "id": "usr_1001",
        "name": "Amina Nakato"
      },
      "action": "user.invited",
      "target": {
        "type": "user",
        "id": "usr_1010",
        "label": "Brian Tumusiime"
      },
      "outcome": "success",
      "ip": "102.85.31.167",
      "request_id": "req_a202e8",
      "details": {
        "role": "Finance"
      }
    },
    {
      "id": "evt_8978",
      "occurred_at": "2026-10-08T15:10:00Z",
      "actor": {
        "type": "user",
        "id": "usr_1001",
        "name": "Amina Nakato"
      },
      "action": "refund.requested",
      "target": {
        "type": "invoice",
        "id": "INV-1009",
        "label": "INV-1009"
      },
      "outcome": "success",
      "ip": "102.85.32.174",
      "request_id": "req_a206b9",
      "details": {}
    },
    {
      "id": "evt_8977",
      "occurred_at": "2026-10-05T12:00:00Z",
      "actor": {
        "type": "user",
        "id": "usr_1006",
        "name": "Moses Kato"
      },
      "action": "auth.mfa_removed",
      "target": {
        "type": "user",
        "id": "usr_1006",
        "label": "Moses Kato"
      },
      "outcome": "success",
      "ip": "102.85.33.181",
      "request_id": "req_a20a8a",
      "details": {
        "method": "Text messages"
      }
    },
    {
      "id": "evt_8976",
      "occurred_at": "2026-09-30T16:30:00Z",
      "actor": {
        "type": "user",
        "id": "usr_1001",
        "name": "Amina Nakato"
      },
      "action": "user.deactivated",
      "target": {
        "type": "user",
        "id": "usr_1002",
        "label": "Daniel Ochieng"
      },
      "outcome": "success",
      "ip": "102.85.34.188",
      "request_id": "req_a20e5b",
      "details": {}
    },
    {
      "id": "evt_8975",
      "occurred_at": "2026-09-12T09:20:00Z",
      "actor": {
        "type": "user",
        "id": "usr_1001",
        "name": "Amina Nakato"
      },
      "action": "user.role_changed",
      "target": {
        "type": "user",
        "id": "usr_1008",
        "label": "David Ssemakula"
      },
      "outcome": "success",
      "ip": "102.85.35.195",
      "request_id": "req_a2122c",
      "details": {
        "from": "Support",
        "to": "Finance"
      }
    },
    {
      "id": "evt_8974",
      "occurred_at": "2026-08-30T10:30:00Z",
      "actor": {
        "type": "user",
        "id": "usr_1001",
        "name": "Amina Nakato"
      },
      "action": "user.deactivated",
      "target": {
        "type": "user",
        "id": "usr_1011",
        "label": "Christine Nansubuga"
      },
      "outcome": "success",
      "ip": "102.85.36.202",
      "request_id": "req_a215fd",
      "details": {}
    }
  ],
