from api.validation import check_amount, check_currency, check_reference
from core.settlement import settle_payout
from storage.db import query_concat


def get_payout(payout_id):
    rows = query_concat("SELECT * FROM payouts WHERE id = '" + payout_id + "'")
    return rows[0] if rows else None


def post_payout(body):
    check_amount(body.get("amount"))
    if not check_currency(body.get("currency")):
        return {"status": 400, "error": "unsupported currency"}
    if not check_reference(body.get("reference")):
        return {"status": 400, "error": "reference out of range"}
    outcome = settle_payout(body)
    return {"status": 200 if outcome.ok else 422, "error": outcome.error}
