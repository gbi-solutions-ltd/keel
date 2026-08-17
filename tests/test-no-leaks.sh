#!/usr/bin/env bash
# Tests for no-internal-leaks.sh.
#
# The plugin is generic and ships to every project. A client name, a partner name, a specific
# repository name, or a developer's absolute path in a skill is confusing at best: a reader assumes
# it means something to keel. At worst it discloses who we work with.
#
# EVERY IDENTIFIER IN THIS FILE IS INVENTED. Until 2026-08-17 the real client names were here,
# because the coverage assertion at the bottom feeds one sample file through the scanner and checks
# that every declared pattern fired, which needs the names. This file was therefore the second copy
# of the disclosure, alongside the deny list itself, and both had to be clean before the repository
# could be published.
#
# What is proven here is the mechanism: that an external list is loaded, that its patterns match,
# that an absent list degrades to the generic patterns rather than to silence, and that the mode is
# announced either way. The invented names deliberately mirror the shapes of the real ones, a company
# name, an acronym, a document identifier, a repository name, a domain noun, so the regex families
# stay exercised.
#
# What this gives up, stated because it is a real reduction: a pattern in the real internal list that
# has stopped matching anything is no longer caught by anything here. The format that would restore
# it is recorded in tests/no-internal-leaks.sh.
#
# Run from the repository root.

# The `condition && report_pass || report_fail` idiom is used throughout. It is safe here, and only
# here, because every reporting helper returns 0 explicitly: see the `return 0` on each below. That
# makes the invariant shellcheck cannot see a stated fact in the code rather than an assumption.
# shellcheck disable=SC2015
# shellcheck disable=SC2016
set -uo pipefail

SCANNER="$(cd "$(dirname "$0")/.." && pwd)/tests/no-internal-leaks.sh"
pass=0
fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }

# The invented deny list every fixture gets. One entry per line, which is the real file's format.
#
# It is written OUTSIDE the fixture root on purpose, which is also where the real one lives. Writing
# it inside made the four expected-clean cases fail, because the scanner reads every file in the tree
# and the deny list contains the patterns by construction. The scanner is right to report it: a deny
# list committed inside a repository is a leak, and teaching the scanner to skip its own list would
# hide exactly that. So the test puts the file where production puts it.
DENY_DIR="$(mktemp -d)"
trap 'rm -rf "$DENY_DIR"' EXIT

write_deny() {
    cat > "$DENY_DIR/deny.txt" <<'DENY'
# Invented identifiers. See the header: the real ones live outside the tree.
AcmePay
acmepay
Northwind
northwind
northwindapi
\bZENITHCO\b
WIDGET-CREDIT
partnerintake
ledger-platform
bulk-card-processor
acmepay-agent-api-v2
clinic[Aa]ccount
clinicDao
cliniccode
clinicref
registerclinic
settleclinic
AUDIT-FINDINGS
\bWXYZ\b
\bwxyz\b
exampleapex
\bFIRSTCO
\bSECONDCO
DENY
}

fixture() {
    local root; root="$(mktemp -d)"
    mkdir -p "$root/skills/example" "$root/templates" "$root/docs" "$root/tests"
    printf '# Example\n\nA generic skill mentioning a partner bank and payments-api generically.\n' \
      > "$root/skills/example/SKILL.md"
    printf '# Doc\n\nInstall with gbi-solutions-ltd/keel.\n' > "$root/docs/install.md"
    write_deny "$root"
    printf '%s' "$root"
}

# run <name> <expected> <mutate>            with the invented list loaded
# run_no_list <name> <expected> <mutate>    with no list at all, so only the generic patterns run
run() {
    local name="$1" expected="$2" mutate="$3"
    local root; root="$(fixture)"
    "$mutate" "$root"
    ( cd "$root" && KEEL_DENY_FILE="$DENY_DIR/deny.txt" "$SCANNER" >/dev/null 2>&1 )
    local actual=$?
    [ "$actual" -eq "$expected" ] && ok "$name" \
      || bad "$name" "expected exit $expected, got $actual"
    rm -rf "$root"
}

run_no_list() {
    local name="$1" expected="$2" mutate="$3"
    local root; root="$(fixture)"
    "$mutate" "$root"
    ( cd "$root" && KEEL_DENY_FILE="$DENY_DIR/definitely-absent.txt" "$SCANNER" >/dev/null 2>&1 )
    local actual=$?
    [ "$actual" -eq "$expected" ] && ok "$name" \
      || bad "$name" "expected exit $expected, got $actual"
    rm -rf "$root"
}

noop() { :; }

run "a clean tree passes" 0 noop

# Client and partner names, in any file, from the loaded list.
m_client()   { printf '\nWe integrate with AcmePay rails.\n' >> "$1/skills/example/SKILL.md"; }
run "a client name in a skill is rejected" 1 m_client

m_partner()  { printf '\nExample: the Northwind integration signs its body.\n' >> "$1/skills/example/SKILL.md"; }
run "a partner name in a skill is rejected" 1 m_partner

m_in_ref()   { mkdir -p "$1/skills/example/references"; printf 'AcmePay does this.\n' > "$1/skills/example/references/r.md"; }
run "a client name in a reference is rejected" 1 m_in_ref

m_in_tmpl()  { printf 'docs/WIDGET-CREDIT-009-product-requirements.md\n' >> "$1/templates/t.md"; }
run "a project document identifier in a template is rejected" 1 m_in_tmpl

m_in_test()  { printf 'partnerintake\n' >> "$1/tests/t.sh"; }
run "a specific repository name in a test is rejected" 1 m_in_test

# A client's business domain identifies them as surely as their name. The real list gained this
# family after a sweep turned up a domain class name in a worked example.
m_domain()   { printf '\nExample: `clinicDao.java:40` writes the row.\n' >> "$1/skills/example/SKILL.md"; }
run "client domain vocabulary is rejected" 1 m_domain

m_doc_id()   { printf '\nRecorded in AUDIT-FINDINGS.md V-22.\n' >> "$1/skills/example/SKILL.md"; }
run "a client internal document identifier is rejected" 1 m_doc_id

# An APEX export names its parsing schema in the manifest and its host in every connect string, so
# both are one paste away from a worked example.
m_apex_schema() { printf '\nExample: parsing schema WXYZ owns the wallet tables.\n' >> "$1/skills/example/SKILL.md"; }
run "an APEX workspace schema is rejected" 1 m_apex_schema

m_apex_host()   { printf '\nConnect with user/pass@host.exampleapex.net:1521/ORCLPDB1\n' >> "$1/skills/example/SKILL.md"; }
run "an APEX hosting provider is rejected" 1 m_apex_host

m_cotenant()    { printf '\nOther workspaces on the instance: FIRSTCO, SECONDCO.\n' >> "$1/docs/install.md"; }
run "a co-tenant schema is rejected" 1 m_cotenant

# Generic patterns, which stay in the tree because they disclose nothing. These must fire whether or
# not a list is loaded, and the second case is the one that matters: an absent list must degrade the
# scan, not silence it.
m_abs_path() { printf '\nSee /Users/someone/Projects/thing for an example.\n' >> "$1/skills/example/SKILL.md"; }
run "an absolute home path is rejected" 1 m_abs_path
run_no_list "an absent list still catches a developer path" 1 m_abs_path

m_generic()  { printf '\nExample: `payments-api` integrates with a partner bank over a signed webhook.\n' >> "$1/skills/example/SKILL.md"; }
run "generic placeholder names are allowed" 0 m_generic
run_no_list "an absent list passes a clean tree" 0 m_generic

# With no list loaded, a name that is only on the list must pass. That is the honest consequence of
# moving the list out, and asserting it stops anyone assuming the scan is fully armed everywhere.
m_client_no_list() { printf '\nWe integrate with AcmePay rails.\n' >> "$1/skills/example/SKILL.md"; }
run_no_list "without a list, a listed name is not caught" 0 m_client_no_list

# Must NOT be rejected: our own org, which the install instructions need.
m_own_org()  { printf '\n/plugin marketplace add gbi-solutions-ltd/keel\n' >> "$1/docs/install.md"; }
run "our own org name is allowed" 0 m_own_org

# ---- the mode line ---------------------------------------------------------
#
# A scanner that silently drops to half its rules and still prints OK is worse than one that fails,
# and nothing else would tell the reader which mode it ran in. Both modes announce themselves.
mode_root="$(fixture)"
loaded_out="$( cd "$mode_root" && KEEL_DENY_FILE="$DENY_DIR/deny.txt" "$SCANNER" 2>&1 )"
absent_out="$( cd "$mode_root" && KEEL_DENY_FILE="$DENY_DIR/absent.txt" "$SCANNER" 2>&1 )"
rm -rf "$mode_root"

printf '%s' "$loaded_out" | grep -q 'internal deny list loaded' \
  && ok "a loaded list is announced" \
  || bad "mode line" "a loaded run did not say so: $(printf '%s' "$loaded_out" | head -1)"

printf '%s' "$absent_out" | grep -q 'generic patterns only' \
  && ok "an absent list is announced" \
  || bad "mode line" "an absent run did not say so: $(printf '%s' "$absent_out" | head -1)"

# ---- coverage of the loaded set --------------------------------------------
#
# Every pattern actually loaded must be exercised by a sample, so a hand written regex cannot stop
# matching without anyone noticing. The regexes are hand written, and a rename or an escaping change
# turns one into dead weight silently.
#
# This now covers the generic patterns plus the invented ones, which is the mechanism rather than the
# real client list. That difference is the reduction the header describes.
cov_root="$(fixture)"
printf '%s' '
AcmePay and acmepay both appear here, via acmepay-agent-api-v2.
Northwind and northwind, hosted at northwindapi.
ZENITHCO is a partner bank.
Recorded in docs/WIDGET-CREDIT-009-product-requirements.md and AUDIT-FINDINGS.md.
Repositories: partnerintake, ledger-platform, bulk-card-processor.
The clinicDao writes a clinicaccount row; also clinicAccount, cliniccode, clinicref.
Callers: registerclinic and settleclinic.
Parsing schema WXYZ, lowercase wxyz, hosted at exampleapex.net.
Co-tenants FIRSTCO and SECONDCO share the instance.
Paths like /Users/someone/Projects and /home/someone/src date instantly.
' > "$cov_root/docs/every-identifier.md"
fired="$( ( cd "$cov_root" && KEEL_DENY_FILE="$DENY_DIR/deny.txt" "$SCANNER" 2>&1 ) | sed -n "s/.*matching '\(.*\)' ->.*/\1/p" | sort -u )"
declared="$( KEEL_DENY_FILE="$DENY_DIR/deny.txt" "$SCANNER" --list-patterns | sort -u )"
missing="$(comm -23 <(printf '%s\n' "$declared") <(printf '%s\n' "$fired"))"
rm -rf "$cov_root"

if [ -z "$missing" ]; then
    ok "every loaded pattern is exercised by a sample ($(printf '%s\n' "$declared" | wc -l | tr -d ' ') patterns)"
else
    bad "deny pattern coverage" "never fired, so they may match nothing: $(printf '%s' "$missing" | tr '\n' ' ')"
fi

# ---- the organisation name in shipped content ------------------------------
#
# Decision 2 keeps GBi out of shipped content so publishing is a deletion rather than an audit.
# Nothing enforced it until 2026-08-17, by which point eight files had the name including four
# SKILL.md bodies the decision forbids outright.
m_gbi_in_skill() { printf '\nBoth were found in real GBi repositories.\n' >> "$1/skills/example/SKILL.md"; }
run "GBi in a SKILL.md is rejected" 1 m_gbi_in_skill

m_gbi_in_ref()   { mkdir -p "$1/skills/example/references"; printf 'GBi builds payments systems.\n' > "$1/skills/example/references/r.md"; }
run "GBi in an undeclared reference is rejected" 1 m_gbi_in_ref

# docs/ and README name GBi legitimately and are not part of the extraction.
m_gbi_in_docs()  { printf '\nGBi ships this to every repository.\n' >> "$1/docs/install.md"; }
run "GBi outside the shipped directories is allowed" 0 m_gbi_in_docs

# output-styles/ ships into every project exactly as skills/ and templates/ do, and it was missing
# from the first version of this rule. Found in review. The same directory was missed once before
# when the validator's content rules were written, which is why it gets its own case rather than
# trusting the scope line in the scanner.
m_gbi_in_style() { mkdir -p "$1/output-styles"; printf '# Style\n\nThe GBi house voice.\n' > "$1/output-styles/t.md"; }
run "GBi in a shipped output style is rejected" 1 m_gbi_in_style

# The same leak, repeated past a pipe buffer, used to scan clean.
#
# `if hit=$(grep -nE "$pat" "$f" | head -1)` skips its own branch when the file has more matches
# than a pipe holds: head exits after the first line, grep dies on SIGPIPE with 141, and
# `set -o pipefail` makes that the pipeline's status, so the `if` is false while `hit` holds a real
# finding. The scanner reported OK on a file full of leaks.
#
# Reproduces from about 5,000 matching lines on this machine; 20,000 keeps a margin on machines with
# a larger pipe buffer, and costs about a megabyte in a temp directory.
m_many_hits() {
    mkdir -p "$1/skills/example/references"
    awk 'BEGIN{for(i=0;i<20000;i++) print "See /Users/someone/Projects/thing line " i}' \
      > "$1/skills/example/references/big.md"
}
run "a leak repeated past a pipe buffer is still rejected" 1 m_many_hits

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
