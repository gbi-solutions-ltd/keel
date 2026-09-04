from api.errors import Result

RATES = {"standard": 250, "promotional": 50, "enterprise": 120}


def fee_for(payout):
    rate = RATES.get(payout.get("tier"))
    error = None if rate is not None else "unknown tier " + str(payout.get("tier"))
    return Result(ok=error is None, error=error, value=rate)


def fee_amount(payout):
    rate = fee_for(payout)
    amount = None if rate.error else payout["amount"] * rate.value // 10000
    return Result(ok=rate.error is None, error=rate.error, value=amount)
