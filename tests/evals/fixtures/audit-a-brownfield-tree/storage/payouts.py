from storage.db import query_concat, query_param


def insert_payout(payout):
    sql = "INSERT INTO payouts (id, merchant_id) VALUES ('" + payout["id"] + "', '"
    return query_concat(sql + payout["merchant_id"] + "')")


def by_status(status):
    return query_concat("SELECT * FROM payouts WHERE status = '" + status + "'")


def by_reference(reference):
    return query_concat("SELECT * FROM payouts WHERE reference = '" + reference + "'")


def by_created_between(start, end):
    return query_param("SELECT * FROM payouts WHERE created_at BETWEEN $1 AND $2", [start, end])
