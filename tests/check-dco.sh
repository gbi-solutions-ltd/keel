#!/usr/bin/env bash
# The Developer Certificate of Origin check for the commits of a pull request.
# Usage: tests/check-dco.sh <base> <head>   (from inside the repository; CI passes the pull
# request's base and head). Its cases are in tests/test-check-dco.sh.
#
# What it checks. Every commit of `git rev-list --no-merges <base>..<head>` must hold a line
# `Signed-off-by: <any name> <email>` in its message whose email equals the commit's author email,
# compared without case. That is what the Developer Certificate of Origin asks of the author: that
# the person who wrote the change certifies they may contribute it. Exit 0 when every checked
# commit is signed off, 1 when any is not, 2 on a usage error or a revision that is not a commit.
#
# Why it is a script here and not a third-party app (decision 6). The usual DCO check is a GitHub
# App that needs installing on the repository, holds permissions on it, and runs code we neither
# read nor version; its result is a status we cannot reproduce on a laptop or pin in a test. This
# is a short bash script that reads nothing but git, needs no network, runs the same on a
# contributor's machine as in CI, and has tests that prove both directions.
#
# Why merges and bots are exempt. A merge commit carries no change of its own to certify, and the
# merge GitHub makes for a pull request is not in the range at all. A commit whose author name ends
# in [bot] was written by an automation, which cannot certify anything: it is printed as SKIP and
# not counted, so the maintainer who merges it is the one who vouches for it.
#
# How to fix a failure. Add a sign-off to each commit it names, then push the branch again:
#
#   git rebase --signoff <base>
#   git push --force-with-lease
#
# or, for the last commit only, `git commit --amend --signoff --no-edit`. `git commit -s` signs
# off a new commit with the author's configured name and email, which is the address checked here.
#
# Plain bash, bash 3.2 included: no case-conversion expansion, no mapfile, no associative array.
set -uo pipefail

if [ "$#" -ne 2 ]; then
    echo "usage: tests/check-dco.sh <base> <head>"
    exit 2
fi
base="$1"
head="$2"

# A revision that is not a commit, or one that git would read as an option, is a usage error.
for rev in "$base" "$head"; do
    case "$rev" in -*) echo "not a commit: $rev" >&2; exit 2 ;; esac
    if ! git rev-parse --verify --quiet "$rev^{commit}" >/dev/null 2>&1; then
        echo "not a commit: $rev" >&2
        exit 2
    fi
done

if ! revs="$(git rev-list --no-merges "$base..$head" 2>/dev/null)"; then
    echo "cannot list $base..$head" >&2
    exit 2
fi

# lower <text>: the text in lower case, without bash 4 expansions.
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# A sign-off line: the trailer, a name, then an address in angle brackets, and nothing after it.
signoff_re='^Signed-off-by: [^<]+ <([^<>]+)>[[:space:]]*$'

signed=0
unsigned=0
while IFS= read -r sha; do
    [ -n "$sha" ] || continue
    name="$(git log -1 --format=%an "$sha")"
    email="$(git log -1 --format=%ae "$sha")"
    short="$(git rev-parse --short=7 "$sha")"
    case "$name" in
        *"[bot]") echo "SKIP  $short authored by $name, a bot"; continue ;;
    esac
    want="$(lower "$email")"
    found=0
    while IFS= read -r line; do
        if [[ $line =~ $signoff_re ]] && [ "$(lower "${BASH_REMATCH[1]}")" = "$want" ]; then
            found=1
            break
        fi
    done <<EOF
$(git log -1 --format=%B "$sha")
EOF
    if [ "$found" -eq 1 ]; then
        signed=$((signed+1))
    else
        echo "FAIL  $short: no Signed-off-by for $email"
        unsigned=$((unsigned+1))
    fi
done <<EOF
$revs
EOF

if [ "$unsigned" -gt 0 ]; then
    echo "$unsigned commit(s) without a sign-off. Add one to each with: git rebase --signoff $base"
    exit 1
fi
echo "OK    $signed commit(s) signed off"
