#!/usr/bin/env bash
# Set the public status page.
set -eu
printf 'status page: %s\n' "${2:-${1:-}}"
printf 'status %s %s\n' "${1:-}" "${2:-}" >> deploy/state.log
