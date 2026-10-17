# payouts

Payout receipts for the payouts service, in bash.

- `format_amount 1500` prints `1,500`.
- `receipt_line Amina 1500` prints `Paid Amina 1,500`.
- A signed receipt link is valid for 15 minutes.

Run the tests with `tests/run-tests.sh`, or one file with `tests/run-tests.sh tests/test-format.sh`.
