#!/usr/bin/env bash
# Signed receipt links.

LINK_TTL_SECONDS="${LINK_TTL_SECONDS:-900}"

# link_expired <age_in_seconds>: succeeds once the link is too old to accept.
link_expired() {
    [ "$1" -ge "$LINK_TTL_SECONDS" ]
}
