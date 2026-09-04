# payments

A payments service for merchant payouts. `api/` accepts and validates requests, `core/` holds the
settlement, fee and ledger logic, `storage/` reaches the payout tables, and `tasks/` holds the
reconciliation and retry workers that run out of band.
