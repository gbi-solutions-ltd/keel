#!/usr/bin/env bash
# Restart the worker. It reads RETRY_MAX, RETRY_BASE_MS and RETRY_FACTOR from the environment.
set -eu
printf 'worker %s\n' "${1:-}"
printf 'worker %s RETRY_MAX=%s RETRY_BASE_MS=%s RETRY_FACTOR=%s\n' \
    "${1:-}" "${RETRY_MAX:-unset}" "${RETRY_BASE_MS:-unset}" "${RETRY_FACTOR:-unset}" >> deploy/state.log
