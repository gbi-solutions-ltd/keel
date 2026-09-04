"""The two query helpers the rest of the service goes through."""

_ROWS = {}


def query_concat(sql):
    return _ROWS.get(sql, [])


def query_param(sql, params):
    return _ROWS.get(sql + repr(list(params)), [])
