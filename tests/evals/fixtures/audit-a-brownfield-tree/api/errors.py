"""Error and outcome types shared across the service."""


class PayoutError(Exception):
    """A payout that cannot be accepted at all."""

    def __init__(self, code, detail):
        super().__init__(code + ": " + detail)
        self.code = code
        self.detail = detail


class Result:
    """An outcome carrying either a value or an error string."""

    def __init__(self, ok, error=None, value=None):
        self.ok = ok
        self.error = error
        self.value = value
