# audit-log: the audit log

Page: `audit` (`/audit`). Components: `AuditTable`, `ColumnMenu`, `ExportMenu`, `FilterTabs`.
Fixtures: `audit_events`. A sample export: `data/exports/audit.csv`. Screens: 9.

Permission: `audit:read`. The event types and their labels are in `AuditTable`: replace them with
the client's.

Shell: an Audit log entry in the nav (`./audit.html`, route `/audit`, permission `audit:read`).
