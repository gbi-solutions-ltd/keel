#!/usr/bin/env bash
# Builds convert-a-changed-mockup's project and keel install with --as-signed: the same project, the
# same commit message and an unmodified engine, with the one string left as the client signed it off.
# The readiness checks then report the mockup signed off and ready.
#
# Why it reuses the other fixture: the two arms must differ only in whether the mockup changed since
# its sign-off, which is what the checks read, so they share one project, built by one script.
#
# Why the engine is not edited: an earlier control switched the comparison off in the staged engine
# and left the change in place. The arm found the change anyway, from the history, from hashing the
# files against the sign-off record, and from the edited line in the engine, so that control could
# not separate the check's catch from the arm's own reading.

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
src="$here/../convert-a-changed-mockup"

cp -R "$src/mockup" .
bash "$src/setup.sh" --as-signed
