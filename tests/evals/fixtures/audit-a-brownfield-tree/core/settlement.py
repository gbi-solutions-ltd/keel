from api.errors import Result
from core.fees import fee_amount
from storage.payouts import insert_payout


def settle_payout(payout):
    fee = fee_amount(payout)
    error = None
    if payout.get("merchant_id") is None:
        error = "payout has no merchant"
    elif not fee.ok:
        error = fee.error
    else:
        insert_payout(payout)
    return Result(ok=error is None, error=error, value=payout.get("id"))


def cancel_settlement(payout_id, reason):
    error = None if reason else "a cancellation needs a reason"
    return Result(ok=error is None, error=error, value=payout_id)
