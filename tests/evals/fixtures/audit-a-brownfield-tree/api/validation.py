from api.errors import PayoutError

SETTLED_CURRENCIES = ("GBP", "EUR", "USD")


def check_amount(amount):
    if amount is None or amount <= 0:
        raise PayoutError("amount_invalid", "amount must be positive minor units")
    return amount


def check_currency(currency):
    return currency in SETTLED_CURRENCIES


def check_reference(reference):
    return reference is not None and 6 <= len(reference) <= 32
