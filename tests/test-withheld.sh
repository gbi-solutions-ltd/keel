#!/usr/bin/env bash
# Tests for tests/withheld.sh: the one list of paths this repository holds back from its public
# tree, and the three functions the validators ask about it. Run from the repository root.
#
# Why the list exists. The private audits live in docs/audits, which is a clone of a private
# repository and is ignored here. Before the list, each validator would have had to know that path
# for itself: a link or a citation into a clone that is absent on a contributor's machine would
# have been reported as broken, and the audits themselves, which are dated records whose line
# citations go stale as the tree moves, would have been checked as if they were live documents.
# The list replaces a path written into several scripts with one array, and the two validators
# source it.
#
# What is pinned: how a path is normalised without realpath and without the path existing, that a
# withheld target is skipped only while it is absent, that every name the file uses starts with
# _wh_, and that each listed path is ignored by the committed .gitignore and tracked by nothing.
#
# The `condition && ok || bad` idiom is safe here, and only here, because both helpers return 0.
# shellcheck disable=SC2015
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
pass=0
fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }

LIB="$ROOT/tests/withheld.sh"
# load: source the library. One place for the shellcheck directive, because the path is built.
load() {
    # shellcheck source=withheld.sh
    . "$LIB"
}
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# expect <name> <got> <want>: one comparison, one line of output.
expect() {
    if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "got: $2 / want: $3"; fi
    return 0
}

if [ ! -f "$LIB" ]; then
    bad "tests/withheld.sh exists" "tests/withheld.sh does not exist"
    printf '\n%s passed, %s failed\n' "$pass" "$fail"
    exit 1
fi
ok "tests/withheld.sh exists"

# The file is sourced and never run.
first="$(sed -n 1p "$LIB")"
expect "the first line is the env shebang" "$first" "#!/usr/bin/env bash"
if [ -x "$LIB" ]; then bad "the file is not executable" "it has +x"; else ok "the file is not executable"; fi

# sk <function> <dir> <path>: the status of one call, made from inside <dir>.
sk() {
    local fn="$1" dir="$2" p="$3"
    ( cd "$dir" && load && "$fn" "$p" )
    printf 'rc=%s' "$?"
}

# 1. The list, and normalisation with the skip, in a directory with no docs/audits.
EMPTY="$TMP/empty"
mkdir -p "$EMPTY"
expect "withheld_list prints the one path" "$( load && withheld_list )" "docs/audits"

for p in docs/audits/2026-01-01-security.md docs/plans/../audits/x.md \
         skills/a/../../docs/audits/x.md ./docs/audits/x.md docs/audits docs/audits/ \
         docs//audits///x.md; do
    expect "1: $p is skipped while absent" "$(sk withheld_skip "$EMPTY" "$p")" "rc=0"
    expect "1: $p is under a withheld path" "$(sk withheld_under "$EMPTY" "$p")" "rc=0"
done
for p in docs/auditsx/y.md docs/plans/x.md ../docs/audits/x.md docs/audit/x.md \
         /docs/audits/x.md docs; do
    expect "1: $p is not skipped" "$(sk withheld_skip "$EMPTY" "$p")" "rc=1"
    expect "1: $p is not under a withheld path" "$(sk withheld_under "$EMPTY" "$p")" "rc=1"
done

PRESENT="$TMP/present"
mkdir -p "$PRESENT/docs/audits"
expect "1: an empty docs/audits present means no skip" \
    "$(sk withheld_skip "$PRESENT" docs/audits/x.md)" "rc=1"
expect "1: a present docs/audits is still under the withheld path" \
    "$(sk withheld_under "$PRESENT" docs/audits/x.md)" "rc=0"
expect "1: the climbing path is no skip with the directory present either" \
    "$(sk withheld_skip "$PRESENT" ../docs/audits/x.md)" "rc=1"

# 2. Every name the file uses starts with _wh_. Two readings: the variables a source leaves behind,
#    and every name the text assigns or expands, comments left out. A function name is not a
#    variable and is not held to the prefix.
before="$( set | sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' | sort -u )"
after="$( load; set | sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' | sort -u )"
left="$( comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after") | sed '/^_wh_/d; /^before$/d' | tr '\n' ' ' )"
expect "2: sourcing leaves no variable outside _wh_" "$left" ""

awk '!/^[[:space:]]*#/' "$LIB" > "$TMP/code.sh"
names="$( { sed -n 's/[^$]*\$[{]\{0,1\}\([A-Za-z_][A-Za-z0-9_]*\).*/\1/p' "$TMP/code.sh"
            sed -n 's/^[[:space:]]*\(local[[:space:]]\{1,\}\)\{0,1\}\([A-Za-z_][A-Za-z0-9_]*\)[+]\{0,1\}=.*/\2/p' \
                "$TMP/code.sh"
            sed -n 's/^[[:space:]]*local[[:space:]]\{1,\}\(.*\)/\1/p' "$TMP/code.sh" | tr ' ' '\n' \
                | sed 's/=.*//'
          } | sed '/^$/d; /^_wh_/d' | sort -u | tr '\n' ' ' )"
expect "2: every name in the text starts with _wh_" "$names" ""

# And no quiet grep pipeline: a `|`, a grep, and a quiet option, assembled from pieces so this
# file does not match its own rule. The file calls no grep at all.
G="gr""ep"
hits="$( awk -v g="$G" '!/^[[:space:]]*#/ && index($0, g) { n++ } END { print n + 0 }' "$LIB" )"
expect "2: the file calls no grep" "$hits" "0"

# 3. Each listed path is ignored by the committed .gitignore, and nothing is tracked under it.
#    --no-index so a tracked file would not hide the answer, and because .git/info/exclude holds
#    the same pattern on the owner's clone and a contributor's clone has no such exclude: the
#    source git names must be .gitignore.
while IFS= read -r path; do
    [ -n "$path" ] || continue
    src="$( git check-ignore -v --no-index "$path/x.md" 2>&1 | cut -f1 )"
    case "$src" in
        .gitignore:*) ok "3: $path/x.md is ignored by .gitignore" ;;
        *) bad "3: $path/x.md is ignored by .gitignore" "git names: ${src:-nothing}" ;;
    esac
    tracked="$( git ls-files -- "$path" )"
    expect "3: nothing is tracked under $path" "$tracked" ""
done < <( load && withheld_list )

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
