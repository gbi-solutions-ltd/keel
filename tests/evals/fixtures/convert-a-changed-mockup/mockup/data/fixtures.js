/*
 * Fixtures: ALL data shown in the mockup lives here, shaped exactly like the API responses
 * (field names, nesting, casing). The contract (api/openapi.yaml) is drafted from these shapes, and
 * the app's mocks serve them back. Every person, organisation and item here is fictional.
 *
 * No money in this app. Instants: RFC 3339 in UTC. Business dates (a loan's from and to, a due
 * date): YYYY-MM-DD, whole days in the organisation's zone (Europe/Dublin).
 *
 * Roles and permissions: `session.role` is who is signed in; `?as=<role>` previews another.
 * Per-record actions come from the server as `allowed_actions`; `action_permissions` says which
 * permission each needs, so a page's load can drop the ones the role lacks, as the server does.
 *
 * @typedef {{ id: string, name: string, time_zone: string }} Organisation
 * @typedef {{ user_id: string, name: string, role: 'staff'|'coordinator' }} Session
 * @typedef {{ label: string, permissions: string[] }} Role
 * @typedef {'laptop'|'camera'|'projector'|'audio'} ItemCategory
 * @typedef {{ status: 'free'|'on_loan', due_back_on: string|null }} Availability
 *   whether the item is free today; due_back_on is the last day of the current loan (null when free)
 * @typedef {{ id: string, asset_tag: string, name: string, category: ItemCategory,
 *   description: string, availability: Availability }} Item
 * @typedef {{ items: Item[], next_cursor: string|null }} ItemPage  one page of GET /v1/items,
 *   ordered by name; cursor paged, no total. Made from `items` by data/list-query.js in load.
 * @typedef {{ id: string, asset_tag: string, name: string }} ItemSummary
 * @typedef {{ id: string, name: string }} Person
 * @typedef {'requested'|'approved'|'declined'|'on_loan'|'returned'} LoanStatus
 * @typedef {'approve'|'decline'|'hand_out'|'return'} LoanAction
 * @typedef {{ id: string, reference: string, item: ItemSummary, requester: Person, from: string,
 *   to: string, purpose: string, status: LoanStatus, decline_reason: string|null,
 *   requested_at: string, allowed_actions: LoanAction[] }} Loan  decline_reason is the coordinator's
 *   reason, set when declined and null otherwise (decision D-1)
 * @typedef {{ items: Loan[], next_cursor: string|null }} LoanPage  one page of GET /v1/loans or
 *   GET /v1/me/loans, newest request first; made from `loans` in load.
 * @typedef {{ from: string, to: string }} Booking  days an item is approved or on loan, made by
 *   the server from the loans (GET /v1/items/{id}/bookings); never stored on its own
 * @typedef {{ maintenance_until: string }} SystemStatus  details.until of a 503 maintenance answer
 */
window.FIXTURES = {
  "organisation": { "id": "org_1", "name": "Larkfield Community Arts", "time_zone": "Europe/Dublin" },
  "session": { "user_id": "usr_1001", "name": "Niamh Ferris", "role": "staff" },
  "roles": {
    "staff": { "label": "Staff", "permissions": ["equipment:read", "loan:request"] },
    "coordinator": { "label": "Coordinator", "permissions": ["equipment:read", "loan:manage"] }
  },
  "permissions": {
    "equipment:read": "See the equipment catalogue",
    "loan:request": "Request a loan and see your own requests",
    "loan:manage": "See every request, approve or decline it, hand items out and record returns"
  },
  "action_permissions": {
    "approve": "loan:manage",
    "decline": "loan:manage",
    "hand_out": "loan:manage",
    "return": "loan:manage"
  },
  "system": { "maintenance_until": "2026-11-23T11:00:00Z" },
  "items": [
    { "id": "itm_01", "asset_tag": "LT-014", "name": "Laptop, 14-inch", "category": "laptop", "description": "For presentations and travel. The charger is in the sleeve.", "availability": { "status": "free", "due_back_on": null } },
    { "id": "itm_02", "asset_tag": "LT-015", "name": "Laptop, 14-inch (spare)", "category": "laptop", "description": "Same as LT-014, kept as the spare.", "availability": { "status": "on_loan", "due_back_on": "2026-11-26" } },
    { "id": "itm_03", "asset_tag": "LT-021", "name": "Laptop, 16-inch, with video editing software", "category": "laptop", "description": "The only laptop with the editing suite installed. Bring your own drive.", "availability": { "status": "free", "due_back_on": null } },
    { "id": "itm_13", "asset_tag": "LT-030", "name": "Laptop, 13-inch", "category": "laptop", "description": "Light, for note taking at events.", "availability": { "status": "free", "due_back_on": null } },
    { "id": "itm_04", "asset_tag": "CM-003", "name": "Mirrorless camera with 24 to 70 mm lens", "category": "camera", "description": "Two batteries and a 128 GB card in the bag.", "availability": { "status": "on_loan", "due_back_on": "2026-11-25" } },
    { "id": "itm_05", "asset_tag": "CM-004", "name": "Compact camera", "category": "camera", "description": "Point and shoot, for quick event photos.", "availability": { "status": "free", "due_back_on": null } },
    { "id": "itm_06", "asset_tag": "CM-007", "name": "Video camera kit with tripod, two batteries and a shoulder bag for carrying it all between sites", "category": "camera", "description": "Records to SD card. The tripod head is fluid, for smooth pans.", "availability": { "status": "free", "due_back_on": null } },
    { "id": "itm_07", "asset_tag": "PJ-001", "name": "Portable projector", "category": "projector", "description": "HDMI and USB-C. The case holds the remote and both cables.", "availability": { "status": "free", "due_back_on": null } },
    { "id": "itm_08", "asset_tag": "PJ-002", "name": "Short-throw projector", "category": "projector", "description": "For small rooms: a large picture from a metre away.", "availability": { "status": "on_loan", "due_back_on": "2026-12-01" } },
    { "id": "itm_09", "asset_tag": "PJ-005", "name": "Projector screen, 2 metre", "category": "projector", "description": "Free-standing, folds into its own bag.", "availability": { "status": "free", "due_back_on": null } },
    { "id": "itm_10", "asset_tag": "AU-002", "name": "Wireless microphone pair", "category": "audio", "description": "Two handheld microphones and one receiver. Spare batteries in the lid.", "availability": { "status": "free", "due_back_on": null } },
    { "id": "itm_11", "asset_tag": "AU-006", "name": "PA speaker with stand", "category": "audio", "description": "Battery powered, about six hours a charge.", "availability": { "status": "on_loan", "due_back_on": "2026-11-24" } },
    { "id": "itm_12", "asset_tag": "AU-009", "name": "Field audio recorder", "category": "audio", "description": "Stereo, with a windshield for outdoor interviews.", "availability": { "status": "free", "due_back_on": null } },
    { "id": "itm_14", "asset_tag": "AU-011", "name": "Conference speakerphone", "category": "audio", "description": "For hybrid meetings of up to twelve people.", "availability": { "status": "free", "due_back_on": null } }
  ],
  "loans": [
    { "id": "ln_1052", "reference": "LN-1052", "item": { "id": "itm_07", "asset_tag": "PJ-001", "name": "Portable projector" }, "requester": { "id": "usr_1003", "name": "Tomasz Wilk" }, "from": "2026-11-27", "to": "2026-11-28", "purpose": "Client workshop in the main hall", "status": "requested", "decline_reason": null, "requested_at": "2026-11-23T08:40:00Z", "allowed_actions": ["approve", "decline"] },
    { "id": "ln_1051", "reference": "LN-1051", "item": { "id": "itm_03", "asset_tag": "LT-021", "name": "Laptop, 16-inch, with video editing software" }, "requester": { "id": "usr_1001", "name": "Niamh Ferris" }, "from": "2026-11-25", "to": "2026-11-26", "purpose": "Editing the autumn showcase video", "status": "requested", "decline_reason": null, "requested_at": "2026-11-23T08:15:00Z", "allowed_actions": ["approve", "decline"] },
    { "id": "ln_1050", "reference": "LN-1050", "item": { "id": "itm_10", "asset_tag": "AU-002", "name": "Wireless microphone pair" }, "requester": { "id": "usr_1005", "name": "Priya Raman" }, "from": "2026-12-02", "to": "2026-12-02", "purpose": "Panel discussion at the library, with questions from the floor", "status": "requested", "decline_reason": null, "requested_at": "2026-11-22T16:05:00Z", "allowed_actions": ["approve", "decline"] },
    { "id": "ln_1049", "reference": "LN-1049", "item": { "id": "itm_12", "asset_tag": "AU-009", "name": "Field audio recorder" }, "requester": { "id": "usr_1006", "name": "Ciarán Ó Súilleabháin-Fitzgerald" }, "from": "2026-11-24", "to": "2026-11-28", "purpose": "Recording oral history interviews with residents for the neighbourhood archive, five sessions across the week", "status": "requested", "decline_reason": null, "requested_at": "2026-11-21T11:30:00Z", "allowed_actions": ["approve", "decline"] },
    { "id": "ln_1048", "reference": "LN-1048", "item": { "id": "itm_01", "asset_tag": "LT-014", "name": "Laptop, 14-inch" }, "requester": { "id": "usr_1001", "name": "Niamh Ferris" }, "from": "2026-11-20", "to": "2026-11-21", "purpose": "Team away day", "status": "declined", "decline_reason": "LT-014 is kept for the board on those days. LT-030 is free if that helps.", "requested_at": "2026-11-19T09:10:00Z", "allowed_actions": [] },
    { "id": "ln_1047", "reference": "LN-1047", "item": { "id": "itm_07", "asset_tag": "PJ-001", "name": "Portable projector" }, "requester": { "id": "usr_1004", "name": "Daniel Okafor" }, "from": "2026-11-27", "to": "2026-11-28", "purpose": "Board meeting presentation", "status": "approved", "decline_reason": null, "requested_at": "2026-11-18T14:00:00Z", "allowed_actions": ["hand_out"] },
    { "id": "ln_1046", "reference": "LN-1046", "item": { "id": "itm_04", "asset_tag": "CM-003", "name": "Mirrorless camera with 24 to 70 mm lens" }, "requester": { "id": "usr_1001", "name": "Niamh Ferris" }, "from": "2026-11-20", "to": "2026-11-25", "purpose": "Photographing the winter market", "status": "on_loan", "decline_reason": null, "requested_at": "2026-11-17T10:20:00Z", "allowed_actions": ["return"] },
    { "id": "ln_1045", "reference": "LN-1045", "item": { "id": "itm_02", "asset_tag": "LT-015", "name": "Laptop, 14-inch (spare)" }, "requester": { "id": "usr_1002", "name": "Aoife Brennan" }, "from": "2026-11-21", "to": "2026-11-26", "purpose": "Grant application week", "status": "on_loan", "decline_reason": null, "requested_at": "2026-11-16T12:45:00Z", "allowed_actions": ["return"] },
    { "id": "ln_1044", "reference": "LN-1044", "item": { "id": "itm_11", "asset_tag": "AU-006", "name": "PA speaker with stand" }, "requester": { "id": "usr_1003", "name": "Tomasz Wilk" }, "from": "2026-11-22", "to": "2026-11-24", "purpose": "Outdoor reading in the square", "status": "on_loan", "decline_reason": null, "requested_at": "2026-11-15T15:30:00Z", "allowed_actions": ["return"] },
    { "id": "ln_1043", "reference": "LN-1043", "item": { "id": "itm_08", "asset_tag": "PJ-002", "name": "Short-throw projector" }, "requester": { "id": "usr_1005", "name": "Priya Raman" }, "from": "2026-11-23", "to": "2026-12-01", "purpose": "Film club, two screenings", "status": "on_loan", "decline_reason": null, "requested_at": "2026-11-14T09:05:00Z", "allowed_actions": ["return"] },
    { "id": "ln_1041", "reference": "LN-1041", "item": { "id": "itm_09", "asset_tag": "PJ-005", "name": "Projector screen, 2 metre" }, "requester": { "id": "usr_1001", "name": "Niamh Ferris" }, "from": "2026-11-30", "to": "2026-12-01", "purpose": "Volunteer evening", "status": "approved", "decline_reason": null, "requested_at": "2026-11-13T17:20:00Z", "allowed_actions": ["hand_out"] },
    { "id": "ln_1042", "reference": "LN-1042", "item": { "id": "itm_06", "asset_tag": "CM-007", "name": "Video camera kit with tripod, two batteries and a shoulder bag for carrying it all between sites" }, "requester": { "id": "usr_1001", "name": "Niamh Ferris" }, "from": "2026-11-10", "to": "2026-11-12", "purpose": "Filming the youth theatre rehearsal", "status": "returned", "decline_reason": null, "requested_at": "2026-11-05T10:00:00Z", "allowed_actions": [] },
    { "id": "ln_1040", "reference": "LN-1040", "item": { "id": "itm_14", "asset_tag": "AU-011", "name": "Conference speakerphone" }, "requester": { "id": "usr_1002", "name": "Aoife Brennan" }, "from": "2026-11-03", "to": "2026-11-04", "purpose": "Funders call", "status": "returned", "decline_reason": null, "requested_at": "2026-10-30T08:30:00Z", "allowed_actions": [] },
    { "id": "ln_1039", "reference": "LN-1039", "item": { "id": "itm_10", "asset_tag": "AU-002", "name": "Wireless microphone pair" }, "requester": { "id": "usr_1006", "name": "Ciarán Ó Súilleabháin-Fitzgerald" }, "from": "2026-10-28", "to": "2026-10-29", "purpose": "Open mic night", "status": "returned", "decline_reason": null, "requested_at": "2026-10-21T13:15:00Z", "allowed_actions": [] }
  ]
};
