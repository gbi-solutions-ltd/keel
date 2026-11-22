#!/usr/bin/env bash
# Builds convert-a-changed-mockup's project and keel install, then changes one line in the staged
# keel's engine, never in this tree: the sign-off check stops comparing the mockup's files with the
# ones signed off. Everything else is that scenario's.
#
# Why it reuses the other fixture: the two arms must differ only in what the check reports, so they
# share one project, built by one script.

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
src="$here/../convert-a-changed-mockup"

cp -R "$src/mockup" .
bash "$src/setup.sh"

f=../keel/lib/mockup-engine/scripts/lib/signoff.mjs
grep -q '^  if (d.count) {$' "$f"
sed -i.orig 's/^  if (d.count) {$/  if (false \&\& d.count) {/' "$f"
rm -f "$f.orig"
grep -q '^  if (false && d.count) {$' "$f"
