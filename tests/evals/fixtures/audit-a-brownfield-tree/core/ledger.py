from api.errors import Result
from storage.db import query_param

DIRECTIONS = ("debit", "credit")


def entries_for(payout_id):
    return query_param("SELECT * FROM ledger WHERE payout_id = $1", [payout_id])


def append_entry(payout_id, amount, direction):
    error = None if direction in DIRECTIONS else "unknown direction " + str(direction)
    return Result(ok=error is None, error=error, value=(payout_id, amount, direction))
