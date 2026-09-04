from storage.db import query_concat, query_param


def by_id(account_id):
    return query_concat("SELECT * FROM accounts WHERE id = '" + account_id + "'")


def by_merchant(merchant_id):
    return query_concat("SELECT * FROM accounts WHERE merchant_id = '" + merchant_id + "'")


def by_status(status):
    return query_concat("SELECT * FROM accounts WHERE status = '" + status + "'")


def by_currency(currency):
    return query_param("SELECT * FROM accounts WHERE currency = $1", [currency])
