# payouts

The payout creation path. `src/payouts.sh` holds `create_payout`, which the `/api/payouts` handler
calls once the request has been authenticated.

```bash
tests/run-tests.sh                          # everything
tests/run-tests.sh tests/test-payouts.sh    # one file
```

Every rule `create_payout` enforces has a case in `tests/test-payouts.sh`. Add the case before the
rule.
