from api.errors import Result
from storage.db import query_concat


def unmatched_for_day(day):
    return query_concat("SELECT * FROM payouts WHERE settled_on = '" + day + "' AND matched = 0")


def provider_rows_for_day(day):
    return query_concat("SELECT * FROM provider_rows WHERE settled_on = '" + day + "'")


def reconcile_day(day):
    ours = unmatched_for_day(day)
    theirs = provider_rows_for_day(day)
    error = None if len(ours) == len(theirs) else "row counts differ for " + day
    return Result(ok=error is None, error=error, value=len(ours))
