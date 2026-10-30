#!/usr/bin/env bash
# Does what keel says about a harness match what keel does on it.
#
# Separate from tests/test-doc-claims.sh deliberately. That file compares a number in a sentence
# against a count derived from the tree, and says so in its own header. Harness support is not a
# count: it is a claim checked against a capability matrix, which is a different question, and
# bundling them would dilute a file whose coherence is the reason it is trusted.
#
# Overlaps tests/test-harness-resolve.sh on two checks, and the overlap is not an oversight. That
# file proves the GENERATOR is correct; this one proves the COMMITTED ARTIFACT is not stale. They
# coincide today only because the artifacts are generated, and the day somebody hand-edits
# hooks/hooks.json is the day they stop coinciding, which is the day this file earns its keep.
#
# shellcheck disable=SC2015  # see tests/test-harness-resolve.sh for why.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# `|| exit` is not decoration. Every path below is relative to the repository root, so a cd that
# silently failed would compare files that do not exist and report the tree stale from anywhere
# but the root.
cd "$ROOT" || exit 1
pass=0; fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }

GEN=tests/generate-harness-artifacts.sh

# 1. A generated artifact that has been hand-edited is stale, and stale is a failing build.
matches_generator() {   # matches_generator <harness> <file>
    diff -q <("$GEN" "$1") "$2" >/dev/null 2>&1
}

if matches_generator claude hooks/hooks.json; then
    ok "hooks/hooks.json matches the generator"
else
    bad "hooks/hooks.json matches the generator" "hand-edited or stale. Run: $GEN claude > hooks/hooks.json"
fi

# ...and the comparison fires. The case above passes just as well against a check that compares
# nothing, because the committed artifact is correct; that is the whole hazard this file exists
# to name, applied to itself.
#
# ON A COPY, NEVER ON THE TRACKED FILE. tests/run-tests.sh runs four test files at once, so a case
# that edited hooks/hooks.json mid-run would corrupt whatever another job was reading, and a
# suite that fails depending on scheduling is worse than one that does not check.
stale="$(mktemp)"
cp hooks/hooks.json "$stale"; printf '\n' >> "$stale"
matches_generator claude "$stale" \
  && bad "the staleness comparison fires on an edited copy" "an edited file matched" \
  || ok "the staleness comparison fires on an edited copy"
rm -f "$stale"

# 2. ADR-0003: absent evidence fails. A provides row without source, version and date grants nothing,
# so a row that looks like a capability and is not one must be caught here rather than trusted.
#
# THE PREDICATE IS THE RESOLVER'S, CHARACTER FOR CHARACTER, and it is not the one this task was
# written with. That was `$4=="" || $5=="" || $6==""`, which passes a field holding a single space
# and passes a seven-field row outright. lib/harness/resolve.sh refuses both, so the check and the
# thing it checks would have disagreed about what "absent evidence" means, and the direction of the
# disagreement is that this file calls a row good which the resolver treats as no evidence at all.
# The same two holes are recorded at tests/test-harness-resolve.sh:42, where they were found.
provenance_gaps() {   # provenance_gaps <file>
    awk -F'|' '$1=="provides" && (NF!=6 || $4 ~ /^[[:space:]]*$/ || $5 ~ /^[[:space:]]*$/ || $6 ~ /^[[:space:]]*$/) {print $2"/"$3}' "$1"
}

thin="$(provenance_gaps lib/harness/capabilities)"
[ -z "$thin" ] && ok "every capability row carries source, version and date" \
  || bad "every capability row carries source, version and date" "$thin"

# A validator with no test proving it fires is worse than none, per docs/standards.md and ADR-0003's
# own verification section. The shipped manifest is clean, so the case above passes just as well
# against a predicate that matches nothing at all. One row per column and per kind of blankness,
# because a row caught on two columns at once pins neither.
fx="$(mktemp)"
printf 'provides|ghost|a|src|1|2026-01-01\nprovides|ghost|b|src|1|\nprovides|ghost|c| |1|2026-01-01\nprovides|ghost|d|src|1|2026-01-01|extra\nprovides|ghost|e|\t|1|2026-01-01\nprovides|ghost|f|src|\t|2026-01-01\nprovides|ghost|g|src|1|\t\n' > "$fx"
got="$(provenance_gaps "$fx" | sort | tr '\n' ' ')"
[ "$got" = "ghost/b ghost/c ghost/d ghost/e ghost/f ghost/g " ] \
  && ok "the provenance check fires on empty, blank and wrong-arity rows" \
  || bad "the provenance check fires on empty, blank and wrong-arity rows" "got: $got"
rm -f "$fx"

# 3. async false on every command entry.
#
# This is the quietest way this design can fail. A hook that runs asynchronously cannot apply a
# control effect: flip this one flag and sensitive-guard stops blocking and done-guard stops holding
# the turn open, while both stay installed, registered and reported as present. Nothing else in the
# suite would notice.
all_synchronous() {   # all_synchronous <file>
    [ "$(grep -c '"type": "command"' "$1")" = "$(grep -c '"async": false' "$1")" ]
}

f=hooks/hooks.json
n_cmd="$(grep -c '"type": "command"' "$f")"
if all_synchronous "$f"; then
    ok "$f: all $n_cmd command hooks are synchronous"
else
    bad "$f: all command hooks are synchronous" \
      "$n_cmd commands, $(grep -c '"async": false' "$f") with async false"
fi

# ...and it fires. The manifest is correct, so the case above passes against a check that compares
# a number with itself, which is what a mutation sweep found it doing. One flag flipped on a copy
# is the whole difference between five gates and five pieces of advice.
flipped="$(mktemp)"
sed 's/"async": false/"async": true/' hooks/hooks.json > "$flipped"
all_synchronous "$flipped" \
  && bad "the synchronous check fires on a flipped flag" "an async manifest passed" \
  || ok "the synchronous check fires on a flipped flag"
rm -f "$flipped"

# ---- documents may not claim more than the manifest grants -------------------
#
# Two checks, and they are two because neither can do the other's job. The registry below catches a
# claim that is WRONG and cannot see one that was never registered; the vocabulary scan after it
# catches a claim that is NEW and cannot judge whether it is true. Either alone leaves the whole of
# the other's failure mode open.

# shellcheck source-path=SCRIPTDIR/..
# shellcheck source=lib/harness/resolve.sh
. lib/harness/resolve.sh

# Documents in scope: what a reader takes as current truth about keel. That is README, the numbered
# documents at the top of docs/, and the runbooks.
#
# Everything in a subdirectory except runbooks is out, and the reason is the same for all of them:
# they are dated records rather than claims. docs/ideas and docs/plans state what was believed on a
# day; docs/decisions are append-only by ADR rule; docs/architecture describes a mechanism, and gate
# names are its subject matter, so scanning it would demand a claim tag on almost every paragraph
# and teach everybody to tag reflexively, which is how a check stops meaning anything. docs/prd,
# docs/stories and docs/audits are the same case.
#
# NOT a `case` glob. In a `case` pattern `*` crosses `/`, so `docs/*.md` matches
# `docs/prd/context-window-at-init.md` and sweeps 60 lines of dated PRD and story text into a check
# about current truth. Measured before this was written. Depth is counted instead.
in_scope() {
    local f="$1" depth
    [ "$f" = README.md ] && return 0
    case "$f" in docs/runbooks/*.md) return 0 ;; esac
    case "$f" in docs/*) ;; *) return 1 ;; esac
    depth="$(printf '%s' "$f" | tr -cd '/' | wc -c)"
    [ "$depth" -eq 1 ] || return 1          # docs/NN-name.md only, never docs/sub/name.md
    case "$f" in *.md) return 0 ;; *) return 1 ;; esac
}

# 4. Every tagged claim is granted by the manifest.
claim_gaps() {   # claim_gaps <file>...
    local f tag subject kind harness
    for f in "$@"; do
        while IFS= read -r tag; do
            # `sed -E`, not a basic-regex `\|`. BSD sed has no alternation in BRE and reads `\|`
            # as a literal pipe, so on macOS every field came out empty and every tag in the tree
            # read as malformed. It fails closed, which is the safe direction, but it would have
            # made task 6 impossible: every tag that task adds would have been rejected. Invisible
            # until the fixture below existed, because no document in scope carried a tag yet.
            subject="$(printf '%s' "$tag" | sed -E -n 's/.*(gate|property)=([A-Za-z0-9_-]*).*/\2/p')"
            kind="$(printf '%s' "$tag" | sed -E -n 's/.*(gate|property)=.*/\1/p')"
            harness="$(printf '%s' "$tag" | sed -E -n 's/.*harness=([A-Za-z0-9_-]*).*/\1/p')"
            if [ -z "$subject" ] || [ -z "$harness" ]; then
                printf '%s:malformed\n' "$f"; continue
            fi
            if [ "$kind" = gate ]; then
                harness_gate_active "$harness" "$subject" || printf '%s:%s/%s\n' "$f" "$harness" "$subject"
            else
                harness_provides "$harness" "$subject" || printf '%s:%s/%s\n' "$f" "$harness" "$subject"
            fi
        done < <(grep -o '<!-- keel:claim [^>]*-->' "$f" 2>/dev/null)
    done
}

scoped=()
while IFS= read -r f; do
    in_scope "$f" && scoped+=("$f")
done < <(git ls-files '*.md')

bad_claims=""
if [ "${#scoped[@]}" -gt 0 ]; then
    bad_claims="$(claim_gaps "${scoped[@]}" | tr '\n' ' ')"
fi
[ -z "${bad_claims// /}" ] && ok "every tagged claim is granted by the capability manifest" \
  || bad "every tagged claim is granted by the capability manifest" "$bad_claims"

# keel serves Claude Code alone (ADR-0013), so a claim marker naming another harness in a current
# document claims something about a plugin that does not exist. The registry above refuses it once
# the ledger holds no row for that harness; this names the leftover directly.
codex_tagged=""
if [ "${#scoped[@]}" -gt 0 ]; then
    codex_tagged="$(grep -l 'harness=codex' "${scoped[@]}" 2>/dev/null | tr '\n' ' ')"
fi
[ -z "${codex_tagged// /}" ] && ok "no current document carries a harness=codex claim marker" \
  || bad "no current document carries a harness=codex claim marker" "$codex_tagged"

# ...and it fires, on the three shapes it has to catch. Without this the case above passes against a
# predicate that never reports anything, and every document in the tree could claim whatever it
# liked. The withheld gate is one with no requires row, and the unvalidated property is one the
# ledger holds no claude row for: a claim either way that nothing in the ledger grants.
cf="$(mktemp -d)"
printf '<!-- keel:claim gate=no-such-gate harness=claude -->\n' > "$cf/gate.md"
printf '<!-- keel:claim property=no_such_primitive harness=claude -->\n' > "$cf/ceiling.md"
printf '<!-- keel:claim harness=claude -->\n' > "$cf/malformed.md"
printf '<!-- keel:claim gate=session-start harness=claude -->\n' > "$cf/good.md"
got="$(claim_gaps "$cf/gate.md" "$cf/ceiling.md" "$cf/malformed.md" "$cf/good.md" | sed "s|$cf/||" | tr '\n' ' ')"
[ "$got" = "gate.md:claude/no-such-gate ceiling.md:claude/no_such_primitive malformed.md:malformed " ] \
  && ok "the claim registry fires on a withheld gate, an unvalidated property and a malformed tag" \
  || bad "the claim registry fires on a withheld gate, an unvalidated property and a malformed tag" "got: $got"
rm -rf "$cf"

# 5. A sentence using gate or ceiling vocabulary with no claim tag is an unregistered claim.
#
# A prose regex is a technique tests/test-doc-claims.sh:1-16 rejects for JUDGING claims, and this is
# not judging: its only question is whether somebody registered the sentence, which is coarse enough
# for a regex to answer honestly.
VOCAB='sensitive-guard|done-guard|context-watch|session-start|hard_block_paths|word ceiling|description budget'
# Lines inside a fenced code block, which are not prose and cannot be claims. Without this the
# repository tree in docs/06-repo-layout.md reports nine findings, every one of them a FILENAME in a
# directory listing: hooks/done-guard the file, tests/test-session-start.sh the file. Tagging those
# would put a claim tag on a `ls` output, and the header above says why that is the worst outcome
# available: it teaches everybody to tag reflexively, which is how a check stops meaning anything.
# The fence markers themselves are outside the block, so a claim on the line before one still counts.
fenced_lines() {   # fenced_lines <file>
    awk '/^```/ { inf = !inf; next } inf { print NR }' "$1"
}

untagged_claims() {   # untagged_claims <file>...
    local f n line back prev tagged fenced
    for f in "$@"; do
        fenced=" $(fenced_lines "$f" | tr '\n' ' ')"
        while IFS= read -r n; do
            [ -n "$n" ] || continue
            case "$fenced" in *" $n "*) continue ;; esac
            line="$(sed -n "${n}p" "$f")"
            case "$line" in *'keel:claim'*) continue ;; esac
            # Look back three lines, not one. A tagged claim is prose and wraps, and a lookback of
            # one line fails any claim longer than two lines, including the support page's own
            # paragraph. That direction is a false stop on a correctly tagged document, which is the
            # kind of check people switch off.
            tagged=""
            for back in 1 2 3; do
                prev="$(sed -n "$((n-back))p" "$f" 2>/dev/null)"
                case "$prev" in *'keel:claim'*) tagged=yes; break ;; esac
            done
            [ -n "$tagged" ] && continue
            printf '%s:%s\n' "$f" "$n"
        done < <(grep -nE "$VOCAB" "$f" 2>/dev/null | cut -d: -f1)
    done
}

untagged=""
if [ "${#scoped[@]}" -gt 0 ]; then
    untagged="$(untagged_claims "${scoped[@]}" | tr '\n' ' ')"
fi
[ -z "${untagged// /}" ] && ok "no unregistered harness claim in a document in scope" \
  || bad "no unregistered harness claim in a document in scope" "$untagged"

# ...and it fires, and stops firing when the sentence is registered. The case above cannot show
# either: it is failing on the whole inventory today and will pass on an empty result once task 6
# has tagged everything, and neither state proves the scan can tell a tagged claim from an untagged
# one. The tagged file sits its claim exactly three lines under its tag, the furthest the lookback
# reaches, so a lookback shortened to one or two lines reports it. That is a false stop on a
# correctly tagged document, which is the kind of check people switch off.
vf="$(mktemp -d)"
printf 'intro\nthe done-guard holds the turn open\n' > "$vf/untagged.md"
printf 'intro\n<!-- keel:claim gate=done-guard harness=claude -->\nprose\nmore prose\nthe done-guard holds the turn open\n' > "$vf/tagged.md"
fence='`''`''`'   # assembled, because shellcheck reads a backtick in a single-quoted string as an
                 # unexpanded expression and this file is on the lint gate
printf 'intro\n%s\nhooks/done-guard\n%s\nthe done-guard holds the turn open\n' "$fence" "$fence" > "$vf/fenced.md"
got="$(untagged_claims "$vf/untagged.md" "$vf/tagged.md" "$vf/fenced.md" | sed "s|$vf/||" | tr '\n' ' ')"
[ "$got" = "untagged.md:2 fenced.md:5 " ] \
  && ok "the vocabulary scan reports an untagged claim, clears a tagged one and skips a fenced one" \
  || bad "the vocabulary scan reports an untagged claim, clears a tagged one and skips a fenced one" "got: $got"
rm -rf "$vf"

# The scope rule, pinned directly. In a `case` pattern `*` crosses `/`, so `docs/*.md` matches
# `docs/prd/context-window-at-init.md` and sweeps dated PRD and story text into a check about
# current truth. Depth is counted for that reason, and nothing else here would notice it changing
# back: widening scope only adds findings to a case that is meant to report none.
scope_report=""
for f in README.md docs/05-token-and-memory-design.md docs/runbooks/cutting-a-release.md; do
    in_scope "$f" || scope_report="$scope_report missing:$f"
done
for f in docs/prd/context-window-at-init.md docs/plans/x.md docs/architecture/y.md skills/z/SKILL.md; do
    in_scope "$f" && scope_report="$scope_report extra:$f"
done
[ -z "$scope_report" ] && ok "scope is README, docs/NN-name.md and the runbooks, and nothing deeper" \
  || bad "scope is README, docs/NN-name.md and the runbooks, and nothing deeper" "$scope_report"

# 6. The support page is generated, not written, and is not stale.
if matches_generator support-page docs/harness-support.md; then
    ok "docs/harness-support.md matches the generator"
else
    bad "docs/harness-support.md matches the generator" "run: $GEN support-page > docs/harness-support.md"
fi

# 6b. docs/profile-keys.md matches ITS generator too, and this one is load-bearing rather than tidy.
# Two of its rows carry a claim tag, written by tests/generate-profile-keys.sh because a tag written
# into the page would be wiped by the next regeneration. tests/validate-skills.sh compares the
# descriptions and strips the tag before comparing, since a tag is not description text, and
# tests/test-profile-keys.sh only checks the generator is deterministic. So without this nothing
# notices a tag disappearing from the page, and the scan below would keep passing on a page that no
# longer registers its claims.
if diff -q <(tests/generate-profile-keys.sh 2>/dev/null) docs/profile-keys.md >/dev/null 2>&1; then
    ok "docs/profile-keys.md matches its generator"
else
    bad "docs/profile-keys.md matches its generator" \
      "run: tests/generate-profile-keys.sh > docs/profile-keys.md"
fi

# 7. The support page describes one harness: a gates table with a single claude column, provenance
# rows for claude alone, and no section about what a second harness cannot claim.
grep -qx '| Gate | claude |' docs/harness-support.md 2>/dev/null \
  && ok "the support page's gates table has the columns Gate and claude" \
  || bad "the support page's gates table has the columns Gate and claude" \
    "header: $(grep -m1 '^| Gate' docs/harness-support.md)"
grep -q '^| codex |' docs/harness-support.md 2>/dev/null \
  && bad "the support page's provenance table has no codex row" "$(grep -c '^| codex |' docs/harness-support.md) rows" \
  || ok "the support page's provenance table has no codex row"
grep -qF 'What Tier B cannot claim' docs/harness-support.md 2>/dev/null \
  && bad "the support page has no Tier B section" "the section is present" \
  || ok "the support page has no Tier B section"

# 8. One skills directory, and what ships is what git tracks.
dupes="$(git ls-files 'skills/*/SKILL.md' | sed 's#.*/\([^/]*\)/SKILL.md#\1#' | sort | uniq -d)"
[ -z "$dupes" ] && ok "no skill appears twice in the tree" || bad "no skill appears twice" "$dupes"

# ...and the manifests actually ship. The export that once produced the public tree is gone
# because the public repository is the tree: what ships is what git tracks. A machine holding
# the private clone also holds docs/audits, so the validators run on a copy of the tracked
# files, which is how that machine sees what a fresh clone sees. That is public CI's condition.
# shellcheck source=tests/withheld.sh
. tests/withheld.sh
miss=""
for f in .claude-plugin/plugin.json hooks/hooks.json skills/keel/SKILL.md; do
    git ls-files --error-unmatch "$f" >/dev/null 2>&1 || miss="$miss $f"
done
[ -z "$miss" ] && ok "the plugin manifest and the hook manifest are tracked, so they ship" \
  || bad "the plugin manifest and the hook manifest are tracked, so they ship" "untracked:$miss"

xd="$(mktemp -d)"
while IFS= read -r f; do
    mkdir -p "$xd/$(dirname "$f")"
    cp -p "$f" "$xd/$f" 2>/dev/null
done < <(git ls-files)
held=""
for w in $(withheld_list); do
    [ -e "$xd/$w" ] && held="$held $w"
done
[ -z "$held" ] && ok "a fresh clone holds no withheld path" \
  || bad "a fresh clone holds no withheld path" "present:$held"
if xc="$(cd "$xd" && tests/validate-citations.sh 2>&1)"; then
    ok "every citation resolves in a fresh clone"
else
    bad "every citation resolves in a fresh clone" "$(printf '%s\n' "$xc" | grep '^FAIL' | head -3)"
fi
if xc="$(cd "$xd" && tests/validate-skills.sh 2>&1)"; then
    ok "every relative link resolves in a fresh clone"
else
    bad "every relative link resolves in a fresh clone" "$(printf '%s\n' "$xc" | grep '^FAIL' | head -3)"
fi
rm -rf "$xd"

# 8. A delegation profile a skill body names must RESOLVE ON CLAUDE CODE.
#
# ADR-0005's Verification clause, made checkable. A body that names a profile no agent file defines
# is an unpinned dispatch wearing a pin: it inherits whatever the driver is paying for, and the
# output looks like output either way, which is the failure tests/validate-skills.sh already says
# its own model rule exists to catch. Seven bodies once named `keel-fanout` while this plugin
# shipped no agent file for it, so the routing that docs/standards.md records as measured firing on
# 2026-08-20 was silently gone. Nothing anywhere said so, which is why this check is here rather
# than in a sentence.
# shellcheck disable=SC2016  # the backticks are the pattern being matched, not a substitution
profiles="$(grep -rhoE 'delegation profile `[a-z0-9-]+`' skills/*/SKILL.md skills/*/references/*.md 2>/dev/null \
    | sed 's/^delegation profile `//; s/`$//' | sort -u)"
[ -n "$profiles" ] && ok "a skill body names a delegation profile at all" \
  || bad "a skill body names a delegation profile at all" "none found, so the checks below prove nothing"
for prof in $profiles; do
    [ -f "agents/$prof.md" ] \
      && ok "delegation profile $prof resolves on claude" \
      || bad "delegation profile $prof resolves on claude" "skills name it and this plugin ships no agents/$prof.md"
done

# ...and the Claude Code half has to SHIP. `agents/` is auto-discovered from the plugin root, so no
# manifest key is needed and none was added: `.claude-plugin/plugin.json` declares neither `skills`
# nor `hooks` either, and an explicit `agents` key REPLACES the default scan rather than adding to
# it, which is a footgun for the second profile rather than a help for the first. Checked against
# code.claude.com/docs/en/plugins-reference on 2026-09-06.
#
# What does need checking is that the file is TRACKED. The public repository is the tracked tree,
# so an untracked agent definition is one that exists on
# the author's machine and ships to nobody. That failure is invisible from inside this repository,
# where the profile resolves perfectly.
for prof in $profiles; do
    git ls-files --error-unmatch "agents/$prof.md" >/dev/null 2>&1 \
      && ok "agents/$prof.md is tracked, so it ships" \
      || bad "agents/$prof.md is tracked, so it ships" "untracked, and the export publishes tracked files only"
done

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
