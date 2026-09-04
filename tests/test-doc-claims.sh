#!/usr/bin/env bash
# Countable claims in README.md must match the tree.
#
# Not prose. A test that asserts on wording fails whenever somebody improves a sentence, which
# teaches people to ignore checks, and CONTRIBUTING.md says the too-strict failure is the
# unrecoverable one. A count is different: one right answer, derivable from the tree, and the
# class of claim that goes stale in total silence.
#
# Every assertion here was wrong when this file was written. README said four eval scenarios when
# there were six, four structural scan rules when there were five, and "Nine decisions: 5 resolved,
# 4 open" when all eleven were resolved. Nothing had noticed for months.
#
# Usage: tests/test-doc-claims.sh   (from the repository root)

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

pass=0
fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }

# claim <name> <actual> <phrase containing exactly one [0-9]+>
# Matches the phrase in README.md, pulls the number out of what matched, and compares.
#
# Two numbers in one phrase would make the first one win silently, so each phrase below carries
# exactly one. And the phrase is matched with grep -o rather than captured with sed: a leading `.*`
# in an ERE is greedy, so `.*([0-9]+) skills built` captures `4` out of `24 skills built` and this
# whole file would have asserted the wrong thing while looking correct.
claim_in() {
    local file="$1" name="$2" actual="$3" phrase="$4" matched claimed
    matched="$(grep -oE "$phrase" "$file" | head -1)"
    if [ -z "$matched" ]; then
        bad "$name" "no claim in $file matched /$phrase/. A number a check cannot read is the same problem as a wrong one: reword the sentence to carry a digit, or delete this case if the claim is gone"
        return 0
    fi
    # Thousands separators are stripped before comparing, because the documents write 20,146 and the
    # tree counts 20146. Matching digits only would read 20 out of 20,146 and pass on nothing.
    claimed="$(printf '%s' "$matched" | grep -oE '[0-9][0-9,]*' | head -1 | tr -d ',')"
    if [ "$claimed" = "$actual" ]; then
        ok "$name ($actual)"
    else
        bad "$name" "$file says '$matched', the tree says $actual"
    fi
}

claim() { claim_in README.md "$@"; }

claim "skill count" \
      "$(find skills -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" \
      '[0-9]+ skills built'

claim "eval scenario count" \
      "$(find tests/evals/scenarios -name '*.md' | wc -l | tr -d ' ')" \
      '[0-9]+ scenarios'

# The same figure, in the repository layout's tree comment. Nothing else reads it: the case above
# asserts README.md only, so `# 10 scenarios, 10 fixtures` went on shipping green while the tree
# held eleven. The phrase carries the scenario count and not the fixture count, because a phrase
# with two numbers lets the first one win silently, which is what the header of this file warns
# about. Case 7 of tests/test-eval-harness.sh already requires a fixture per scenario, so the two
# figures cannot drift apart without that case going red first.
claim_in docs/06-repo-layout.md "eval scenario count in 06-repo-layout.md" \
      "$(find tests/evals/scenarios -name '*.md' | wc -l | tr -d ' ')" \
      '[0-9]+ scenarios'

claim "supply chain pattern rules" \
      "$(tests/supply-chain-scan.sh --list-rules | grep -vc structural)" \
      '[0-9]+ pattern rules'

claim "supply chain structural rules" \
      "$(tests/supply-chain-scan.sh --list-rules | grep -c structural)" \
      'and [0-9]+ structural'

claim "open decision count" \
      "$(grep -cE '^## [0-9]+\.' docs/07-open-decisions.md)" \
      'of [0-9]+ resolved'

# ---- the coding-standards reference figure, in every live copy --------------
#
# One counted fact, quoted in eight documents, wrong in six of them on 2026-09-02. It began as
# "12 reference files, 17,816 reference words, a body of 683", measured 2026-08-16 for ADR-0001, and
# was copied outward as evidence that moving substance into references/ has a floor. The skill
# gained a mode and the figure became 13 / 20,146 / 876. Three documents were corrected by hand and
# went stale again; three were never corrected at all. A fourth round of hand correction was the
# wrong fix, so this is the check instead.
#
# WHICH COPIES THIS ASSERTS, AND THE RULE, stated here rather than left to whoever adds the ninth.
# **A dated citation is a record and is left alone. An undated present-tense claim is live and is
# asserted.** docs/plans/2026-08-30-design-database.md and
# docs/plans/2026-08-31-release-operations-and-claims-audit.md cite the old figure as the precedent
# available when they were written, which is true and stays true, so neither is here.
# docs/decisions/ADR-0001-skill-body-word-ceiling.md holds one of each in adjacent sentences and is
# the case that shows the difference: "as measured on 2026-08-16" is the record, "now routes four
# modes and stands at" is live. Only the second is asserted.
#
# It is a fixed list of locations and phrases rather than a prose parser. A general rule would have
# to recognise six different sentence shapes, and a check that half-works on prose is worse than a
# short list somebody has to extend deliberately: the extension is the moment to decide whether the
# new copy is a record or a claim.
#
# THE NINTH, added 2026-09-02. tests/evals/scenarios/assess-a-stale-standard.md said "the 876 word
# body", written when that was true and left behind by the move of assess's checks into
# references/assess.md. It is not a document, and it is asserted anyway: it is an undated
# present-tense claim, it is the length the scenario tells a reader it measures, and it had already
# gone stale twice by hand. A scenario that misstates what it measures is worse than a document that
# does, because the next arm is scored against it.
cs_refs="$(find skills/coding-standards/references -name '*.md' | wc -l | tr -d ' ')"
cs_words="$(cat skills/coding-standards/references/*.md | wc -w | tr -d ' ')"
# The same body_of that tests/validate-skills.sh uses, so the document and the validator cannot
# disagree about what a body is.
cs_body="$(awk 'f;/^---$/{c++; if(c==2) f=1}' skills/coding-standards/SKILL.md | wc -w | tr -d ' ')"

# ---- check 1b's denominator, computed rather than pinned ---------------------
#
# S-10 defines check 1b's unit as one ## section of house-defaults.md, excluding exactly two by
# name. The number that follows from that definition is asserted here rather than written down
# twice, because the failure mode for this figure is the one this whole file exists for: the
# document keeps its number while the reference grows a section.
hd="skills/coding-standards/references/house-defaults.md"
# Fence-aware, because `grep -c '^## '` counts a heading inside a fenced example as a section.
# house-defaults.md carries no fence today, so both spellings answer 14 and the denominator is the
# same either way; the pattern is live in this directory all the same, since assessment-report.md
# holds a fenced `## Not covered` in its template block. Left as a bare grep, the day somebody adds
# a fenced example to house-defaults.md this file fails loudly and names the wrong cause: the two
# claim_in cases below would report the documents as stale when nothing about the definition of a
# house rule had moved.
hd_all="$(awk '/^```/ {fence = !fence; next} !fence && /^## / {n++} END {print n + 0}' "$hd")"
hd_excluded=2
hd_rules=$((hd_all - hd_excluded))

# The two exclusions are asserted by name before the arithmetic that depends on them. A rename
# would leave hd_excluded=2 subtracting two sections that are no longer the two S-10 names, and the
# denominator would stay 12 while meaning something else.
if grep -q '^## The other references, and when each applies$' "$hd" \
   && grep -q '^## What is deliberately not here$' "$hd"; then
    ok "check 1b's two excluded headings exist under the names S-10 names"
else
    bad "check 1b's two excluded headings exist under the names S-10 names" \
        "a heading was renamed, so the exclusion no longer subtracts what it says it does"
fi

# claim_in takes the FIRST match of its phrase in the file. Both phrases below are unique today:
# "denominator is" does not otherwise occur in assessment-report.md, and assess.md spells its only
# other count as the word "ten". A sentence added above either one carrying a digit in the same
# shape would silently make these read the wrong number and still pass.
claim_in skills/coding-standards/references/assessment-report.md \
         "check 1b denominator in assessment-report.md" "$hd_rules" \
         'denominator is [0-9]+'

claim_in skills/coding-standards/references/assess.md \
         "check 1b denominator in assess.md" "$hd_rules" \
         'all [0-9]+ house defaults'

# The header must carry both coverage figures under distinct names. A single "coverage <n>" is the
# shape S-10 exists to remove, so the check fails on its absence rather than on its presence.
arp="skills/coding-standards/references/assessment-report.md"
if grep -q 'coverage <n>, house defaults <n>, backlog <n>, sample <n>, departures <n>' "$arp"; then
    ok "the report header names both coverage figures separately"
else
    bad "the report header names both coverage figures separately" \
        "the Findings row does not carry check 1 and check 1b as two named numbers"
fi

# S-12: the inheritance rule is stated, and no mechanism is added to soften it. The current
# SCHEMA_VERSION is read from bin/keel so the failure message can name the value it found; the 2 it
# is compared against is pinned here deliberately, because that pin is the tripwire.
hd_s12="skills/coding-standards/references/house-defaults.md"
if grep -q 'inherit it unchanged' "$hd_s12" && grep -q 'departures ledger' "$hd_s12"; then
    ok "house-defaults states the inheritance rule and where disagreement goes"
else
    bad "house-defaults states the inheritance rule and where disagreement goes" \
        "the opening does not say adopters inherit unchanged and disagree through their own ledger"
fi

# S-12's "no overlay file exists" scenario. Checked as an absence at the paths an overlay would
# plausibly take, because a grep of house-defaults.md would not see a file created beside it.
overlay=""
for p in skills/coding-standards/references/house-defaults-overlay.md \
         skills/coding-standards/references/overrides.md \
         templates/house-defaults.md .keel/house-defaults.json; do
    [ -e "$p" ] && overlay="$overlay $p"
done

# The overlay case reads this file with grep. A missing file exits 2, which `!` would invert into a
# pass, so its existence is asserted before the case that depends on it.
schema_s12="templates/profile.schema.json"
if [ -f "$schema_s12" ]; then
    ok "the profile schema the overlay case reads exists"
else
    bad "the profile schema the overlay case reads exists" \
        "$schema_s12 is gone, so the overlay case below passes on grep's exit 2 rather than on an absent key"
fi

if [ -z "$overlay" ] && [ -f "$schema_s12" ] \
   && ! grep -q '"house[_-]defaults"' "$schema_s12"; then
    ok "no overlay file and no profile key for house defaults"
else
    bad "no overlay file and no profile key for house defaults" \
        "S-12 forbids an overlay mechanism; found:$overlay and any schema key named above"
fi

sv="$(grep -oE '^SCHEMA_VERSION=[0-9]+' bin/keel | head -1 | cut -d= -f2)"
if [ "$sv" = "2" ]; then
    ok "SCHEMA_VERSION has not moved for S-12 ($sv)"
else
    bad "SCHEMA_VERSION has not moved for S-12" \
        "bin/keel is at $sv, expected 2. S-12 adds no schema change, so a bump is either a different change riding along or the overlay S-12 forbids"
fi

# Plan 0 left these two changes of its own untested. Both are literal strings in a file that exists
# for this class of claim, and the only other record of the section order is an eval result from
# 2026-09-01 that predates check 1b and records the old four-check shape.
#
# The order is asserted as the whole list rather than as a count of entries, because a count of
# eight passes on any permutation of eight, and the order is the entire reason two reports of the
# same repository can be compared without re-reading either tree.
want_order='1. Summary, three sentences and the counts
2. Check 1, house-defaults coverage
3. Check 1b, house-defaults coverage as its own number
4. Check 2, the follow-up backlog
5. Check 3, the judgement sample
6. Check 4, the departures ledger
7. Trend, where a previous assessment exists
8. Not covered, explicit'
got_order="$(awk '/^## Section order, fixed$/ {inside = 1; next}
                  inside && /^## / {exit}
                  inside && /^[0-9]+[.)] /
                  inside && /^[-*+] /' "$arp")"
if [ "$got_order" = "$want_order" ]; then
    ok "the report's section order is the eight entries S-10 fixed, in that order"
else
    bad "the report's section order is the eight entries S-10 fixed, in that order" \
        "assessment-report.md's Section order list is not those eight entries in that sequence. A missing file reads as an empty list here and fails, which is the intent"
fi

# The never-summed paragraph, matched on two of its lines. grep is line-oriented and the paragraph
# wraps, so the first line carries the rule and the last carries the instruction that makes it
# actionable; asserting only the heading sentence would pass on a paragraph gutted below it.
if grep -q '^\*\*Check 1 and check 1b are never added together\.\*\*' "$arp" \
   && grep -q 'Report both, name both' "$arp"; then
    ok "assessment-report.md forbids adding check 1 and check 1b together"
else
    bad "assessment-report.md forbids adding check 1 and check 1b together" \
        "the paragraph saying the two coverage figures are never summed, and to report and name both, is not there in the shape S-10 wrote it"
fi

# S-03: the router names four modes and every reference it points at resolves. validate-skills.sh
# already fails a broken link; this asserts the cells are present, which a link check cannot see.
# The failure it prevents is a router that silently routes three ways.
#
# Three things this check does that an earlier draft of it did not, each closing a way it could
# pass without earning it.
#
# It reads Step 0's own section rather than the whole file. A mention of references/audit.md in the
# Common mistakes table would satisfy a file-wide grep while the router routed three ways.
#
# It matches the markdown link form. The "Relative links must resolve" rule in validate-skills.sh,
# the one that scans each SKILL.md, resolves only `](...)`, so a prose citation ("see
# references/audit.md") passes a bare-text grep AND passes the link check, and goes on passing
# after the file it names is deleted. docs/07-open-decisions.md:143-144 records thirteen such
# citations across eleven files in this very reference set, invisible to the link checker. The rule
# is cited by name because this file cited it by line and the line moved.
#
# It asserts the fourth mode. The other three have a reference file and are caught by the loop;
# author has none, so a router that dropped it would route three ways with this case green, which
# is the exact failure the comment above claims to prevent. Mode, not cell: the four cells of the
# two-fact table are not asserted here, and the document-with-no-code cell is FR-14 and task 4.
sk="skills/coding-standards/SKILL.md"
step0="$(awk '/^## Step 0/ {f = 1; next} f && /^## / {exit} f' "$sk")"
missing=""
for mode in assess audit seed; do
    printf '%s' "$step0" | grep -q "](references/$mode\.md)" || missing="$missing $mode"
done
printf '%s' "$step0" | grep -q '\*\*Author\*\*' || missing="$missing author"
# And the guard, which is the clause that was actually dropped once. A router that loses "or author"
# from the precondition sentence leaves an unguarded overwrite of an existing standards.md, and it
# passes every other check in this repository: the four names are still there, the three links still
# resolve, and the body is still in band. Two review passes caught it by reading. This line is so
# that the next one does not have to. Both of these extractions are flattened with tr first: grep is
# line-oriented, and a future re-wrap of Step 0 that splits "author" from "over one" would fail a
# router that is behaviourally identical, which is the too-strict failure docs/standards.md forbids.
printf '%s' "$step0" | tr '\n' ' ' | tr -s ' ' | grep -q 'author over one' || missing="$missing author-guard"
# And the tie-break, which is the whole basis on which a request that contradicts the two facts is
# scoreable. Delete that sentence and every other check here stays green while the mode a user asked
# for silently stops winning.
printf '%s' "$step0" | tr '\n' ' ' | tr -s ' ' | grep -q 'words win' || missing="$missing words-win"
if [ -z "$missing" ]; then
    ok "Step 0 links every mode that has its own reference, and names the fourth"
else
    bad "Step 0 links every mode that has its own reference, and names the fourth" \
        "Step 0 is missing:$missing"
fi

# The audits/ naming rule is stated twice: in this repository's docs/README.md, and in the heredoc
# at bin/keel that writes every new project's copy of it. docs/prd/standards-assessment.md:279-280
# names the heredoc as the place the rule is stated, so the generator is canonical and this repo's
# copy is derived. Correcting one and not the other ships a rule this repository has already
# retracted, and nothing else in the suite compares them.
#
# Both are flattened and their runs of spaces squeezed before comparing, because the two wrap
# differently and always will: every backtick in the heredoc is escaped, costing two source
# characters and rendering as one, so a 100-column source line renders shorter.
readme_rule="$(sed -n '/^A dated report in/,/named for its slug\./p' docs/README.md \
               | tr '\n' ' ' | tr -s ' ')"
# The sed script is a literal: it strips the backslash bin/keel writes before every backtick, so
# it must stay single-quoted and nothing in it expands. CI lints at default severity.
# shellcheck disable=SC2016
keel_rule="$(sed -n '/^A dated report in/,/named for its slug\./p' bin/keel \
             | sed 's/\\`/`/g' | tr '\n' ' ' | tr -s ' ')"
if [ -n "$readme_rule" ] && [ "$readme_rule" = "$keel_rule" ]; then
    ok "the audits naming rule is the same in docs/README.md and in bin/keel's scaffold"
else
    bad "the audits naming rule is the same in docs/README.md and in bin/keel's scaffold" \
        "the repository's copy and the copy every scaffolded project is given have drifted apart"
fi

# FR-07: audit and assess must not write the same path. The two filenames are asserted here because
# the collision is silent: the second mode to run simply overwrites the first mode's report.
au="skills/coding-standards/references/audit.md"
as="skills/coding-standards/references/assess.md"
# Flattened, because these paths wrap. audit.md already puts "Then write" at the end of one line and
# the path at the start of the next, so a line-oriented grep never sees the two together. An edit
# that wrapped between `audits/` and `YYYY-MM-DD-standards.md` would put assess's path in audit's
# write instruction and pass every line-oriented clause. A missing file makes tr fail, leaves the
# variable empty, and fails the first assertion, so nothing inverts into a pass.
#
# Two [[:space:]]* rather than one: flattening turns a newline into a space, and the path can wrap
# at either of its two natural break points, after `audits/` or after `YYYY-MM-DD-`. Watched both
# ways against a mutated copy; the single-gap spelling misses the second.
au_flat="$(tr '\n' ' ' < "$au")"
as_flat="$(tr '\n' ' ' < "$as")"
if printf '%s' "$au_flat" | grep -q 'YYYY-MM-DD-standards-audit\.md' \
   && printf '%s' "$as_flat" | grep -q 'YYYY-MM-DD-standards\.md' \
   && ! printf '%s' "$as_flat" | grep -q 'YYYY-MM-DD-standards-audit\.md' \
   && ! printf '%s' "$au_flat" | grep -q 'audits/[[:space:]]*YYYY-MM-DD-[[:space:]]*standards\.md'; then
    ok "audit and assess write different report paths"
else
    bad "audit and assess write different report paths" \
        "FR-07 requires audit at DATE-standards-audit.md and assess at DATE-standards.md, and neither file may name the other's path"
fi

# The six-entry report order in audit.md, pinned the way assessment-report.md's eight are. Task 5's
# scenario and task 6's rubric both score an arm against this sequence, so a reword here rescores
# every arm already recorded. Matched on the bolded lead label of each numbered entry, because the
# prose after it is free to change and the order is not. The awk filter takes every numbered line
# rather than only the bolded ones, so an entry added without a bold label survives into the
# comparison and mismatches, instead of being dropped and leaving the list six long. It takes
# bullets too, and the numbers are compared rather than discarded, because both were ways a seventh
# section could be added invisibly: a bulleted one is not numbered at all, and renumbering the six
# to 1 2 3 7 4 5 leaves the labels in order and the check green while the document reads wrong.
want_audit_order='1 Header
2 What was sampled, and what was not
3 The conventions found
4 The splits
5 What has no convention
6 Not covered'
got_audit_order="$(awk '/^## The report, in this fixed order$/ {inside = 1; next}
                        inside && /^## / {exit}
                        inside && /^[0-9]+[.)] /
                        inside && /^[-*+] /' "$au" \
                   | sed -E 's/^([0-9]+)\. \*\*([^*]+)\*\*.*/\1 \2/; s/[.,]$//')"
if [ "$got_audit_order" = "$want_audit_order" ]; then
    ok "audit's six report sections are in the order NFR-08 fixes"
else
    bad "audit's six report sections are in the order NFR-08 fixes" \
        "audit.md's report list is not those six entries in that sequence. A missing file reads as an empty list here and fails, which is the intent"
fi

# S-05: the offer file exists, carries both halves of FR-06 and its existing-document guard as
# literal strings, and is still reached from audit.md. That is all this case proves. It does not
# prove a run behaves like an offer; it proves the sentences that tell it to are present and linked.
#
# The link clause is the one an ordinary edit reaches. Delete "## How audit ends" from audit.md
# and the offer is orphaned while the whole suite stays green: validate-skills.sh fails a link that
# does not resolve and says nothing about a file nothing points at. $au is bound to audit.md by the
# FR-07 case above and is reused rather than rebound.
#
# That clause is defeated by backticking audit.md's link. A backticked link still contains the
# literal characters this grep looks for, so it passes here, while validate-skills.sh's span strip
# stops the link resolving at all, so it passes there too and the offer is unreachable with the
# suite green. That is not an ordinary edit, and closing it would mean parsing markdown in a grep.
# It is written down so the next reader does not have to rediscover it.
#
# The existing-document clause is the fifth, and the one the plan defends at length while nothing
# held it. It matches "would replace" and not "already exists", which is not a preference: strip
# "or an existing document is not to be replaced" and "and say that authoring would replace" from
# the offer and "already exists" is still standing in the untouched first half of that sentence, so
# an "already exists" clause passes on exactly the edit it was added to catch. Measured on the
# stripped file, not reasoned about. "would replace" fails on it. Audit routes on "no document and
# code", but Step 0 lets the request's words win, so audit is reachable in a repository that
# already has a standards.md, and an offer with no such clause proposes overwriting it.
#
# The phrase greps read a flattened copy, for the reason the Step 0 pair above is flattened: grep
# is line-oriented, audit-offer.md is wrapped prose, and a re-wrap that split any of these phrases
# across two lines would fail a file whose meaning had not changed, which is the too-strict failure
# docs/standards.md forbids. The link clause is not flattened because "](audit-offer.md)" cannot be
# split by wrapping.
#
# The literal-string clauses are stricter than behaviour: a legitimate reword of "without being
# asked", "declined" or "would replace" breaks a file that is still correct. That trade is
# accepted here for the reason it is accepted for 'words win' above, because these sentences are
# the whole of FR-06 and nothing else in the suite would notice their going.
of="skills/coding-standards/references/audit-offer.md"
off=""
[ -f "$of" ] && off="$(tr '\n' ' ' < "$of" | tr -s ' ')"
if [ -f "$of" ] \
   && printf '%s' "$off" | grep -q 'without being asked' \
   && printf '%s' "$off" | grep -q 'declined' \
   && printf '%s' "$off" | grep -q 'would replace' \
   && grep -q '](audit-offer.md)' "$au"; then
    ok "audit's offer is an offer, guards an existing document, says what happens when it is declined, and audit.md links it"
else
    bad "audit's offer is an offer, guards an existing document, says what happens when it is declined, and audit.md links it" \
        "audit-offer.md is missing, does not state both halves of FR-06, does not say that authoring would replace an existing document, or audit.md no longer links it"
fi

# FR-14: the bottom-right cell is answered rather than dropped. The failure this prevents is an
# assess run on a document with no code reporting empty checks as a coverage failure, which reads
# as "the standard is not followed" when nothing was there to follow it.
# Flattened and reusing $as_flat from the FR-07 case above, for the reason that case gives: these
# are phrases in wrapped prose, and a re-wrap that split one across lines would fail a file whose
# meaning had not changed. Two clauses rather than one, because FR-14 has two halves that a later
# edit could separate: what checks 2 and 3 do, and what check 4 does with a basis it cannot
# re-verify. Neither pins the whole requirement, and the case name says so.
if printf '%s' "$as_flat" | grep -q 'no corpus' \
   && printf '%s' "$as_flat" | grep -q 'not re-verified'; then
    ok "assess names what it does where there is no code, for checks 2, 3 and 4"
else
    bad "assess names what it does where there is no code, for checks 2, 3 and 4" \
        "FR-14's answer is not in assess.md, so the fourth cell routes here and finds nothing"
fi

# S-07: seed's four load bearing clauses, plus the one that says it writes nothing else. None of
# these is derivable from Step 0's seed cell, which names the mode and links here and says no more.
#
# Flattened, for the reason the audit-offer cases above are flattened: grep is line oriented, this
# is wrapped prose, and a re-wrap that split a phrase across two lines would fail a file whose
# meaning had not changed, which is the too-strict failure docs/standards.md forbids.
#
# Not squeezed, and that is the one way this binding departs from the audit-offer precedent it
# cites. `off` chains `tr -s ' '`; this deliberately does not, and the reason is specific to what
# these clauses have to tell apart.
#
# Flattening turns a newline into one space. seed.md's prose wraps at column 100 with no indent, so
# a prose phrase split by a re-wrap arrives here with a single space and every pattern below still
# matches it, which is the whole job. Its sixteen indented lines are all bullet continuations, so
# squeezing would change exactly one thing: it would let a phrase that wraps inside a bullet match
# too.
#
# That is not free here, because two of these clauses have to distinguish a sentence that
# commissions a requirement from a bullet further down that restates it. "seeded from the house
# defaults" appears twice in seed.md, once in the provenance header and once, wrapped, inside the
# `Derived from` bullet. Unsqueezed, the flattened string carries it once and the FR-10 case reads
# the header. Squeezed, it carries it twice, and gutting the header leaves that case passing on the
# bullet alone. Measured both ways against a mutated copy: with the squeeze the gutted header scores
# 56 passed, without it the case goes red.
#
# So the squeeze would trade a too-strict failure this file cannot actually suffer for a too-lenient
# one it can, and a claim test that passes on a claim that is gone is the failure this whole file
# exists to prevent. `au_flat` and `as_flat` above are unsqueezed for a different reason again:
# their positive clauses are single tokens with no space in them, and the one clause that must cross
# a wrap spells the gap itself as [[:space:]]*. Three bindings, three answers, each stated where it
# is used.
#
# Each clause is a separate case rather than one case with five conditions, because the failure
# message has to say which clause went missing. A mode that keeps its provenance sentence and loses
# its Step 1 inversion is a different defect from one that loses both.
sd="skills/coding-standards/references/seed.md"
sd_flat="$(tr '\n' ' ' < "$sd")"

# FR-11, read as the mode's own text and not the skill body. The whole reason seed is defensible is
# that it says out loud it is doing the opposite of Step 1 and why. A seed mode without this
# paragraph is a style guide import with a citation attached, which is the thing Step 1 exists to
# prevent, and a reader who met both without it would be right to distrust one of them.
if printf '%s' "$sd_flat" | grep -q 'inverts Step 1' \
   && printf '%s' "$sd_flat" | grep -q 'assumes a codebase that exists'; then
    ok "seed.md states the Step 1 inversion and why"
else
    bad "seed.md states the Step 1 inversion and why" \
        "FR-11's two halves are not both in seed.md: that seed inverts Step 1, and that Step 1's rule assumes a codebase that exists"
fi

# FR-10. The provenance sentence goes in the document seed writes, not only in this file, so the
# clause asserted here is the instruction to write it. The failure it prevents is an inherited
# default being read six months later as an observed convention, which is the one thing that makes
# seeding worse than writing nothing.
if printf '%s' "$sd_flat" | grep -q 'seeded from the house defaults' \
   && printf '%s' "$sd_flat" | grep -q 'not derived from code'; then
    ok "seed.md requires the document to state its provenance"
else
    bad "seed.md requires the document to state its provenance" \
        "FR-10's sentence, that the document was seeded from the house defaults and not derived from code, is not commissioned in seed.md"
fi

# S-07's fourth scenario. Seed routes on there being no code, and the router decides before anything
# is read, so the mode is where a wrong precondition gets caught. Without this branch an arm that
# finds source files seeds over them anyway and the derivation that should have happened never does.
if printf '%s' "$sd_flat" | grep -q 'offer audit instead'; then
    ok "seed.md names the branch where code turns up after all"
else
    bad "seed.md names the branch where code turns up after all" \
        "seed.md does not tell a run that finds source files to name them and offer audit instead"
fi

# FR-08's second half, and the clause the gap report in task 2 is computed against. Folding in all
# ten references is the failure the index exists to prevent, and it is the likelier failure: reading
# everything is easier than evaluating ten predicates and is indistinguishable in the output unless
# the document says what it left out.
if printf '%s' "$sd_flat" | grep -q 'whose index predicate holds' \
   && printf '%s' "$sd_flat" | grep -q 'which did not and what decided it'; then
    ok "seed.md folds in only the applicable topic references, and names the rest"
else
    bad "seed.md folds in only the applicable topic references, and names the rest" \
        "seed.md does not restrict itself to the references whose index predicate holds, or does not require the excluded ones to be named with what decided them"
fi

# The third state, which no case pinned until now. The case above pins the two-state half, that seed
# folds in only the holding predicates and names what decided the rest, and its wording predates the
# undecided state entirely: it is green on a seed.md that knows only applied and excluded. The whole
# rubric the seed arm is scored on turns on the third state, so it is asserted here rather than left
# to a case that cannot see it.
#
# Three clauses, because they fail independently. An arm can be told the record has three states and
# still be left to invent a decider for the third, which is the exclusion seed did not make.
if printf '%s' "$sd_flat" | grep -q 'this record has three states' \
   && printf '%s' "$sd_flat" | grep -q 'no reference leaves it without one' \
   && printf '%s' "$sd_flat" | grep -q 'record it in the document as undecided' \
   && printf '%s' "$sd_flat" | grep -q 'names no decider'; then
    ok "seed.md requires the undecided state and forbids an invented decider"
else
    bad "seed.md requires the undecided state and forbids an invented decider" \
        "one of the three-state clauses is missing from seed.md: that the record has three states and no reference leaves it without one, that a predicate nothing settles is recorded as undecided rather than excluded, or that an undecided entry names no decider"
fi

# The blocking finding of the 2026-09-03 review, held as a check.
#
# standards-template.md:12 and :14 require a "Derived from" row naming a sample and a commit and an
# "Enforced by" row naming the check-only lint command, and :40-42 requires rule, reason and an
# example from this codebase, "All three". None of the three exists when there is no code, and the
# fixture's profile sets lint to null. seed.md told the arm to follow that template and separately
# forbade it to claim a convention was observed, which is a contradiction the arm resolves by
# guessing: it invents a commit, or it drops the rows, or it takes an example from a house
# reference's own illustration. The scenario's "Ambiguity is a fail" clause then converts a mode
# defect into a seed-drops verdict, which is the arm failing for the wrong reason.
#
# So the override is written down and pinned. Three clauses, one per row, because they fail
# independently: an arm can get the header right and still invent a per-entry example.
if printf '%s' "$sd_flat" | grep -q 'no files sampled' \
   && printf '%s' "$sd_flat" | grep -q 'adding a check-only lint command' \
   && printf '%s' "$sd_flat" | grep -q 'per-entry example is omitted'; then
    ok "seed.md says what the template's three code-dependent fields become with no code"
else
    bad "seed.md says what the template's three code-dependent fields become with no code" \
        "seed.md points at standards-template.md without saying what Derived from, Enforced by and the per-entry example become when there is no commit, no sample, no lint command and no file to cite"
fi

# The case above's mirror image, and the half that had no home. That one covers what the template
# asks for and seed cannot give; this one covers what seed must write and the template does not ask
# for. seed.md tells the arm to record every house reference in one of three states and points at
# standards-template.md for the document's shape, and that template never mentions the index, so
# until 2026-09-04 "record it in the document" named no section, no columns and no place in the
# file. The first seed arm invented a table, which is recorded as passing at tests/evals/results.md
# under condition 5, and an invented shape is not a shape two runs can be compared across.
#
# Three clauses, because they fail independently. Losing the heading leaves the record somewhere a
# reader has to hunt for; losing the per-run row rule lets an arm drop the section on the run where
# every predicate held, which is the run that most needs to say so; and losing the empty-cell rule
# reopens the invented decider through the one affordance that invites it, a column with a blank in
# it.
if printf '%s' "$sd_flat" | grep -q 'House references, and what decided each' \
   && printf '%s' "$sd_flat" | grep -q 'one row per file the index lists, every run' \
   && printf '%s' "$sd_flat" | grep -q 'a decider on an undecided row invents the exclusion'; then
    ok "seed.md gives the three-state record a named section and a rule for the empty cell"
else
    bad "seed.md gives the three-state record a named section and a rule for the empty cell" \
        "seed.md requires the three-state record without saying where it goes in the document, that every reference the index lists gets a row on every run, or that an undecided row leaves the decider cell empty"
fi

# The worked table itself, which the case above cannot see. Every clause up there matches prose, so
# the first version of this pair was green on a seed.md whose table had been deleted outright: the
# section still said a record exists and said nothing an arm could lay out. Only the six reference
# word-count cases fired, and those fire on any edit at all, so they name the wrong cause.
#
# Four clauses. The header row is one, because the columns are the shape: drop `Predicate` and an
# excluded entry stops naming what excluded it, which is the requirement three cases above. The
# three state cells are one each, spelled with their surrounding pipes so they match in the table
# and not in the prose that also uses these words, and asserted separately because an arm copies
# the rows it can see: a table showing only Applied and Excluded is the two-state ledger the
# undecided state was added to replace, and it would be green on a single presence check for the
# word.
if printf '%s' "$sd_flat" | grep -q '| Reference | State | Predicate | Decided by |' \
   && printf '%s' "$sd_flat" | grep -q '| Applied |' \
   && printf '%s' "$sd_flat" | grep -q '| Excluded |' \
   && printf '%s' "$sd_flat" | grep -q '| Undecided |'; then
    ok "seed.md's worked record shows four columns and all three state cells"
else
    bad "seed.md's worked record shows four columns and all three state cells" \
        "seed.md's record table is gone, has lost a column, or does not show all three of Applied, Excluded and Undecided as rows an arm can copy the shape of"
fi

# Seed writes one file. This is the property task 5 verifies with diff -r against the fixture, and
# it is asserted here so the file cannot quietly grow a second output between arms.
if printf '%s' "$sd_flat" | grep -q 'and nothing else' \
   && printf '%s' "$sd_flat" | grep -q 'Make a network request'; then
    ok "seed.md writes one file and makes no network request"
else
    bad "seed.md writes one file and makes no network request" \
        "seed.md does not say it writes standards.md and nothing else, or has lost the no-network clause audit.md carries"
fi

# NFR-08: the gap report is comparable between two runs the way references/assessment-report.md
# requires of assess. Fixed section order and a counting unit stated before any number. The five
# labels are compared in sequence rather than for presence, because an order that drifts makes two
# runs incomparable while every section is still there, and that is invisible to a presence check.
#
# This is the shape the audit report order case above uses. It is preferred to a file-wide grep
# for the five labels as a precaution, not as a response to a live collision: no label occurs
# twice in seed.md today with the same capitalisation, but these are ordinary words that recur
# in prose, and a file-wide grep would break the first time one of them did.
#
# It reads the gap report's own section, takes numbered lines and bulleted ones, and compares the
# numbers rather than discarding them. Each of those closes a way a sixth section could be added
# invisibly: a bulleted entry is not numbered at all, and renumbering the five to 1 2 3 7 4 leaves
# the labels in order and the check green while the document reads wrong.
want_gap_order='1 The stack
2 Applied
3 Did not apply
4 Not covered by any reference
5 Nothing to report'
got_gap_order="$(awk '/^## The gap report$/ {inside = 1; next}
                      inside && /^## / {exit}
                      inside && /^[0-9]+[.)] /
                      inside && /^[-*+] /' "$sd" \
                 | sed -E 's/^([0-9]+)\. \*\*([^*]+)\*\*.*/\1 \2/; s/[.,]$//')"
if [ "$got_gap_order" = "$want_gap_order" ]; then
    ok "seed.md fixes the gap report's five sections in order"
else
    bad "seed.md fixes the gap report's five sections in order" \
        "seed.md's gap report is not those five entries in that sequence. A missing section reads as an empty list here and fails, which is the intent"
fi

# FR-09 and the placement settled 2026-09-03. Three clauses: the unit is stated, the report goes in
# the reply, and it is addressed to keel rather than to the project. The third is the one that
# decides where it goes, so it is asserted rather than left implied by the second.
if printf '%s' "$sd_flat" | grep -q 'one house reference is one file the index lists' \
   && printf '%s' "$sd_flat" | grep -q 'in the reply' \
   && printf '%s' "$sd_flat" | grep -q "keel's gap rather than the project"; then
    ok "seed.md states the counting unit and puts the gap report in the reply, addressed to keel"
else
    bad "seed.md states the counting unit and puts the gap report in the reply, addressed to keel" \
        "one of FR-09's three clauses is missing: the counting unit before any number, the report going in the reply, or the finding belonging to keel rather than to the project"
fi

# The defect the first seed arm failed on, held as a check. Recorded at tests/evals/results.md under
# the 2026-09-03 seed entry, condition 6: the arm's report opened at section 1 and stated no unit
# anywhere, then gave a number in section 4.
#
# The case above asserts the sentence is in the file. It was, and the arm still did not write it,
# because it sat above the numbered list as a definition of the unit to count in rather than as
# something the report must contain. The list is what an arm follows, and section 5's "Nothing to
# report, in those words" is what an output requirement looks like in this file. So the imperative
# spelling is pinned, not just the clause: "write that one house reference is..." rather than "one
# house reference is...".
#
# The placement is checked as well as the wording, because a correctly imperative sentence moved
# below section 1 asks for the unit after the first number and the file would still read as fixed.
# Counted within the gap report's own section, so a numbered list elsewhere in the file cannot
# satisfy or break it.
gap_unit_at="$(awk '/^## The gap report$/ {inside = 1; n = 0; next}
                    inside && /^## / {exit}
                    inside {n++}
                    inside && /^\*\*State the counting unit/ {print n; exit}' "$sd")"
gap_num_at="$(awk '/^## The gap report$/ {inside = 1; n = 0; next}
                   inside && /^## / {exit}
                   inside {n++}
                   inside && /^[0-9]+[.)] / {print n; exit}' "$sd")"
if printf '%s' "$sd_flat" | grep -q 'State the counting unit first, before any number' \
   && printf '%s' "$sd_flat" | grep -q 'write that one house reference is one file the index lists' \
   && [ -n "$gap_unit_at" ] && [ -n "$gap_num_at" ] && [ "$gap_unit_at" -lt "$gap_num_at" ]; then
    ok "seed.md commands the counting unit as output, ahead of the first numbered section"
else
    bad "seed.md commands the counting unit as output, ahead of the first numbered section" \
        "the counting unit is not written as an instruction to state it, or it no longer sits ahead of section 1 in the gap report. This is the requirement the first seed arm read as a definition and did not print"
fi

# The answer-leak guard, and the reason it is a case rather than a note.
#
# The fixture the arm runs against is the Flutter case, which is the known true positive NFR-07
# names. seed.md is staged into that arm whole. A worked example naming flutter or frontend.md would
# hand the arm the finding it is scored on producing, and the reply would look like a pass on a
# derivation that never happened. That is finding 4 of the previous plan's review, in the mode next
# door: references/audit.md narrated its own fixture's split and the fixture had to be reseeded.
#
# A comment saying "do not name it" is what audit.md had. This is the check.
if ! printf '%s' "$sd_flat" | grep -qi 'flutter' \
   && ! printf '%s' "$sd_flat" | grep -q 'frontend\.md'; then
    ok "seed.md states the gap mechanism without naming its own worked example"
else
    bad "seed.md states the gap mechanism without naming its own worked example" \
        "seed.md names flutter or frontend.md, which is the finding the staged arm is scored on producing"
fi

# S-13, first scenario: no enforcement is added. Three places a mode could acquire it, and none of
# them counts anything, for the reason the plan gives: a count goes red on every unrelated addition.
# $au is already set to references/audit.md at the FR-07 case above, and $sd to references/seed.md
# by task 1's cases. Reused rather than redefined, which is what the FR-14 case above does with
# $as_flat: a second assignment of the same path is one more place for the two to drift apart.
#
# Both files are asserted to exist before the negated grep, and that is not defensive noise. `!
# grep -q` inverts grep's exit 2 on a missing file into a pass, so deleting references/seed.md would
# turn this case green while proving nothing. tests/test-doc-claims.sh:186-193 already guards the
# same shape for schema_s12 and says so; this is that guard.
#
# The missing-file branch is separate, and for the reason b6e8662 separated the empty-block branch
# in the tree case below: a detail that assumes the guard's precondition held is a true failure with
# a false explanation. Folded into one else, this case's detail re-greps the two files it has just
# failed to find, so a deleted references/seed.md prints a red case with an empty detail and the
# reader is told nothing at all. The branch is first because it is the precondition the message
# after it depends on.
mode_files_missing=""
for f in "$au" "$sd"; do
    [ -f "$f" ] || mode_files_missing="$mode_files_missing $f"
done
if [ -n "$mode_files_missing" ]; then
    bad "neither audit nor seed names a hook or a gate" \
        "not found:${mode_files_missing}. The negated grep passes on a missing file, so this case is reporting that it cannot look rather than that the modes name a hook"
elif /usr/bin/grep -qiE 'hook|gate' "$au" "$sd"; then
    bad "neither audit nor seed names a hook or a gate" \
        "$(/usr/bin/grep -niE 'hook|gate' "$au" "$sd" | head -3 | tr '\n' ' ')"
else
    ok "neither audit nor seed names a hook or a gate"
fi

# The registration side of the same question. A mode that names no hook but is wired into one is
# enforced anyway, and hooks/hooks.json is where wiring that ships to an installer lives, which is
# the property this story protects. It is not the only hooks block in the tree:
# .claude/settings.json:39-46 wires SessionStart to ./.claude/keel-nudge. That file is this
# repository's own development-time configuration, and this case deliberately does not read it.
#
# Split the same way as the case above, and here the folded message was the worse of the two: it
# asserted a cause outright rather than printing one, so an absent hooks/hooks.json produced a red
# case naming two files that are both fine.
wiring_files_missing=""
for f in hooks/hooks.json .keel/profile.json; do
    [ -f "$f" ] || wiring_files_missing="$wiring_files_missing $f"
done
if [ -n "$wiring_files_missing" ]; then
    bad "no hook is registered for the modes and no gate key names one" \
        "not found:${wiring_files_missing}. Both negated greps pass on a missing file, so this case is reporting that it cannot look rather than that a mode has been wired up"
elif /usr/bin/grep -qE 'coding-standards|audit|seed' hooks/hooks.json \
     || /usr/bin/grep -qE '"(audit|seed)"[[:space:]]*:' .keel/profile.json; then
    bad "no hook is registered for the modes and no gate key names one" \
        "hooks/hooks.json names one of the modes, or .keel/profile.json has grown a gate key for one"
else
    ok "no hook is registered for the modes and no gate key names one"
fi

# S-13, third scenario: both modes run offline. Asserted as the clause each file carries rather than
# by scanning for a URL. No other check backs that up: the one rule in tests/supply-chain-scan.sh
# that matches a plain network command is net-in-script at line 66, whose scope is exec, and
# in_scope at lines 128-134 limits exec to bin, hooks, lib, tests and .github/workflows, or a file
# carrying the executable bit. Both mode files sit under skills/ and are not executable, so that
# scanner never reads them for a network command. What this case does is check that the promise is
# written down where a reader of the mode meets it.
# Flattened, and not optionally: audit.md wraps this very phrase across lines 39 and 40, as
# "Make a" then "network request.", so the line-oriented spelling of this case fails on a correct
# file. Measured against the tree while the plan was written, which is the only way it was going to
# be found. Both flattened copies are already in scope, $au_flat from the FR-07 case above and
# $sd_flat from task 1's cases, and are reused rather than re-flattened.
if printf '%s' "$au_flat" | grep -q 'Make a network request' \
   && printf '%s' "$sd_flat" | grep -q 'Make a network request'; then
    ok "audit and seed both state that they make no network request"
else
    bad "audit and seed both state that they make no network request" \
        "one of the two mode files has lost its no-network clause"
fi

# The repo tree in docs/06-repo-layout.md shows every top-level entry `git ls-files` produces.
#
# That document opens by calling itself "the repo as it actually is", and nothing checked the tree
# it says that about. The tree was regenerated from `git ls-files` on 2026-09-01 and the output
# silently left out four top-level entries, `bin/` among them, so a reader who believed the opening
# sentence read the absence of `bin/` as evidence there is no `bin/`. The full account is in
# docs/ideas/repo-layout-omits-its-own-executable.md.
#
# Top-level only, and deliberately. Asserting that every tracked path is either shown or sits under
# a directory the tree collapses would catch more, and it needs a maintained list of sanctioned
# collapses: a second thing to keep true, and a second thing to go quietly wrong. The top level is
# small and slow moving, so this fires when a top-level entry appears and almost never otherwise,
# which is what keeps the failure informative rather than routine.
#
# One direction. An entry the tree shows and the repository no longer has is not asserted here;
# that is the interior's problem, and the interior is curated on purpose.
#
# The two sets are compared whole rather than one grep per entry, so that a single failure names
# every absent entry instead of the first one to be looked for. Both sides keep the trailing slash
# `git ls-files` puts on a directory, and that slash is load bearing rather than decoration:
# `.claude/` and `.claude-plugin/` are both top-level entries, a test for `.claude/` does not match
# `.claude-plugin/`, and a test for the slash-less `.claude` does.
# The connector is matched as an alternation of two literals rather than as a bracket
# expression, which in a byte-oriented locale would match the first byte of the nested connector
# too. Only the first fenced block is read: the second is the installed-project tree, which is what
# `keel init` writes into someone else's project rather than a claim about this repository.
tree_block="$(awk '/^```$/{n++; next} n==1' docs/06-repo-layout.md)"
tree_tops="$(printf '%s\n' "$tree_block" | /usr/bin/grep -oE '^(├|└)── [^ ]+' | awk '{print $2}' | sort -u)"
git_tops="$(git ls-files | awk -F/ '{if (NF==1) print $0; else print $1"/"}' | sort -u)"
absent="$(comm -23 <(printf '%s\n' "$git_tops") <(printf '%s\n' "$tree_tops") | tr '\n' ' ' | sed 's/ *$//')"
# The empty-block case is branched on rather than folded into the message above it. `comm -23`
# against an empty right side returns the whole left side, so if the first fence stops being the
# tree then every entry is reported absent and a fallback on `$absent` can never fire. That is a
# true failure with a false explanation: the reader is told 23 entries were dropped from the tree
# when what happened is that the case read the wrong block.
if [ -z "$tree_tops" ]; then
    bad "06-repo-layout.md's tree shows every top-level entry git ls-files produces" \
        "no tree entries were read at all: the first fenced block of docs/06-repo-layout.md is no longer the repo tree, so this case is reading the wrong block rather than finding the tree short"
elif [ -n "$absent" ]; then
    bad "06-repo-layout.md's tree shows every top-level entry git ls-files produces" \
        "absent from the tree: $absent"
else
    ok "06-repo-layout.md's tree shows every top-level entry git ls-files produces"
fi

while IFS='|' read -r file which phrase; do
    [ -n "$file" ] || continue
    case "$which" in
        refs)  want="$cs_refs" ;;
        words) want="$cs_words" ;;
        body)  want="$cs_body" ;;
    esac
    claim_in "$file" "coding-standards $which in $(basename "$file")" "$want" "$phrase"
done <<'CLAIMS'
docs/05-token-and-memory-design.md|refs|\*\*[0-9]+ reference files
docs/05-token-and-memory-design.md|words|and [0-9,]+ words\*\* in them
docs/05-token-and-memory-design.md|body|still [0-9]+, against
tests/validate-skills.sh|refs|It is [0-9]+,
tests/validate-skills.sh|words|[0-9,]+ and [0-9]+ today
tests/validate-skills.sh|body|and [0-9]+ today
docs/standards.md|refs|carries [0-9]+ and
docs/standards.md|words|and [0-9,]+ against
docs/standards.md|body|against [0-9]+ today
docs/decisions/ADR-0001-skill-body-word-ceiling.md|refs|^[0-9]+ references,
docs/decisions/ADR-0001-skill-body-word-ceiling.md|words|references, [0-9,]+ reference words
docs/decisions/ADR-0001-skill-body-word-ceiling.md|body|a body of [0-9]+
docs/ideas/leon-van-zyl-skill-collection.md|refs|with [0-9]+ references carrying
docs/ideas/leon-van-zyl-skill-collection.md|words|carrying [0-9,]+ words
docs/ideas/leon-van-zyl-skill-collection.md|body|sits at [0-9]+ words
docs/ideas/database-design-and-review.md|refs|precedent at [0-9]+ references
docs/ideas/database-design-and-review.md|words|references, [0-9,]+ words, and
docs/ideas/database-design-and-review.md|body|a body of [0-9]+
tests/evals/scenarios/assess-a-stale-standard.md|body|[0-9]+ word body
CLAIMS

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
