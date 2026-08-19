#!/usr/bin/env bash
# A small key/value cache with a TTL, standing in for Redis.

CACHE_DIR="${CACHE_DIR:-/tmp/paycache}"
CACHE_TTL_SECONDS="${CACHE_TTL_SECONDS:-300}"

cache_set() {   # cache_set <key> <value>
    mkdir -p "$CACHE_DIR"
    printf '%s\n' "$2" > "$CACHE_DIR/$1"
}

cache_get() {   # cache_get <key>; prints the value, returns 1 on miss or expiry
    local f="$CACHE_DIR/$1" age now mtime
    [ -f "$f" ] || return 1
    now="$(date +%s)"
    mtime="$(date -r "$f" +%s 2>/dev/null || stat -c %Y "$f")"
    age=$(( now - mtime ))
    if [ "$age" -ge "$CACHE_TTL_SECONDS" ]; then
        rm -f "$f"
        return 1
    fi
    cat "$f"
}

cache_delete() {   # cache_delete <key>
    rm -f "$CACHE_DIR/$1"
}
