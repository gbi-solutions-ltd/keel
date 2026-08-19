#!/usr/bin/env bash
# Pause or resume a payment corridor. Nothing is lost while paused; the queue backs up.
set -eu
printf 'corridor %s %s\n' "${1:-}" "${2:-}"
printf 'corridor %s %s\n' "${1:-}" "${2:-}" >> deploy/state.log
