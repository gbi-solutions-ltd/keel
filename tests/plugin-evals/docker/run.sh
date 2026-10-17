#!/usr/bin/env bash
# Runs `claude plugin eval` on this suite inside a Linux container, where git works.
#
#   tests/plugin-evals/docker/run.sh [--branch <name>] <claude plugin eval options>
#
# It clones the branch (default: the one checked out) from this repository into the container, so
# uncommitted changes are not evaluated. The checkout is mounted read-only and only the results
# folder is writable, because the model under test may run shell commands: a writable checkout lets
# it change your tree or plant a .git hook that runs on your machine at the next commit. The suite
# flags (--eval-dir, --scaffold, --ablation none, --no-publish) are added for you. Results are
# copied back to tests/plugin-evals/results/. Needs ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN
# in the environment; each run costs real model calls on that account. CLAUDE_CODE_VERSION picks
# the CLI version baked into the image (default 2.1.299).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
branch="$(git -C "$root" rev-parse --abbrev-ref HEAD)"
if [ "${1:-}" = "--branch" ]; then branch="${2:?--branch needs a name}"; shift 2; fi
if [ -z "${ANTHROPIC_API_KEY:-}${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
    echo "run.sh: set ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN first" >&2; exit 2
fi
version="${CLAUDE_CODE_VERSION:-2.1.299}"
image="keel-plugin-evals:$version"
docker build -q --build-arg "CLAUDE_CODE_VERSION=$version" -t "$image" "$here" >/dev/null
mkdir -p "$root/tests/plugin-evals/results"
exec docker run --rm \
    -e ANTHROPIC_API_KEY -e CLAUDE_CODE_OAUTH_TOKEN -e BRANCH="$branch" \
    -v "$root:/repo:ro" -v "$root/tests/plugin-evals/results:/results" \
    "$image" bash -c '
        set -uo pipefail
        git -c safe.directory=/repo clone -q --branch "$BRANCH" /repo /work/keel || exit 1
        cd /work/keel || exit 1
        echo "branch $BRANCH at $(git rev-parse --short HEAD); $(claude --version); $(git --version)"
        claude plugin eval . --eval-dir tests/plugin-evals --scaffold --ablation none --no-publish "$@"
        rc=$?
        # Only regular report files go back to the host: never a dot entry or a symlink, because
        # the model under test could plant a .git folder whose fsmonitor command runs on the host.
        find tests/plugin-evals/results -mindepth 2 -maxdepth 2 -type f \
            \( -name "*.json" -o -name "*.html" \) ! -path "*/.*" |
        while IFS= read -r f; do
            d="/results/${f#tests/plugin-evals/results/}"
            mkdir -p "${d%/*}" && cp "$f" "$d"
        done
        exit "$rc"
    ' run.sh "$@"
