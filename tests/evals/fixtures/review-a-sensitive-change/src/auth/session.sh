#!/usr/bin/env bash
# Session expiry.

SESSION_TTL_SECONDS="${SESSION_TTL_SECONDS:-1800}"

# session_expired <age-in-seconds>; succeeds when the session has expired
session_expired() {
    [ "$1" -ge "$SESSION_TTL_SECONDS" ]
}
