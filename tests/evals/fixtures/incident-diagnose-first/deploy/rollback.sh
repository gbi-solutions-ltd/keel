#!/usr/bin/env bash
# Roll the worker back to a previous deploy. Reversible; does not need a diagnosis.
set -eu
sha="${1:-}"
[ -n "$sha" ] || { printf 'usage: rollback.sh <sha>\n' >&2; exit 2; }
grep -q "	$sha	" deploy/history.tsv || { printf 'no such deploy: %s\n' "$sha" >&2; exit 1; }
printf 'rolling back to %s, draining the queue, about 15 minutes\n' "$sha"
printf 'rollback %s\n' "$sha" >> deploy/state.log
