from api.errors import PayoutError
from storage.db import query_param

MAX_ATTEMPTS = 5
BASE_DELAY_MS = 200


def due_retries(now):
    return query_param("SELECT * FROM retries WHERE next_attempt_at <= $1", [now])


def next_delay_ms(attempt):
    if attempt > MAX_ATTEMPTS:
        raise PayoutError("retry_exhausted", "attempt " + str(attempt) + " is past the ceiling")
    return BASE_DELAY_MS * (2 ** attempt)
