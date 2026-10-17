#!/usr/bin/env bash
# Account lockout after repeated failed sign-ins.

MAX_FAILED_ATTEMPTS="${MAX_FAILED_ATTEMPTS:-3}"

# is_locked_out <failed-attempts-since-the-last-success>; succeeds when the account is locked
is_locked_out() {
    [ "$1" -ge "$MAX_FAILED_ATTEMPTS" ]
}
