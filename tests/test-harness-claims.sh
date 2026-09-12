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
# hooks/hooks.codex.json is the day they stop coinciding, which is the day this file earns its keep.
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

for pair in "claude:hooks/hooks.json" "codex:hooks/hooks.codex.json"; do
    h="${pair%%:*}"; f="${pair#*:}"
    if matches_generator "$h" "$f"; then
        ok "$f matches the generator"
    else
        bad "$f matches the generator" "hand-edited or stale. Run: $GEN $h > $f"
    fi
done

# ...and the comparison fires. The two cases above pass just as well against a check that compares
# nothing, because the committed artifacts are correct; that is the whole hazard this file exists
# to name, applied to itself.
#
# ON A COPY, NEVER ON THE TRACKED FILE. tests/run-tests.sh runs four test files at once, so a case
# that edited hooks/hooks.codex.json mid-run would corrupt whatever another job was reading, and a
# suite that fails depending on scheduling is worse than one that does not check.
stale="$(mktemp)"
cp hooks/hooks.codex.json "$stale"; printf '\n' >> "$stale"
matches_generator codex "$stale" \
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
# The same two holes are recorded at tests/test-harness-resolve.sh:36, where they were found.
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

# 3. async false on every command entry, in both manifests.
#
# This is the quietest way this design can fail. codex-rs/hooks/src/engine/mod.rs:141-156 gates
# every control effect on the hook being synchronous, and that gate covers the exit-2 path in
# pre_tool_use.rs AND the stdout decision path in stop.rs. Flip this one flag and sensitive-guard
# stops blocking and done-guard stops holding the turn open, while both stay installed, registered
# and reported as present. Nothing else in the suite would notice.
all_synchronous() {   # all_synchronous <file>
    [ "$(grep -c '"type": "command"' "$1")" = "$(grep -c '"async": false' "$1")" ]
}

for f in hooks/hooks.json hooks/hooks.codex.json; do
    n_cmd="$(grep -c '"type": "command"' "$f")"
    if all_synchronous "$f"; then
        ok "$f: all $n_cmd command hooks are synchronous"
    else
        bad "$f: all command hooks are synchronous" \
          "$n_cmd commands, $(grep -c '"async": false' "$f") with async false"
    fi
done

# ...and it fires. Both manifests are correct, so the two cases above pass against a check that
# compares a number with itself, which is what a mutation sweep found them doing. One flag flipped
# on a copy is the whole difference between three gates and three pieces of advice.
flipped="$(mktemp)"
sed 's/"async": false/"async": true/' hooks/hooks.codex.json > "$flipped"
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

# ...and it fires, on the three shapes it has to catch. Without this the case above passes against a
# predicate that never reports anything, and every document in the tree could claim whatever it
# liked. The ceiling case is the S-19 hazard specifically: ADR-0001's 900 words were calibrated on
# Claude Code's preload and nothing has measured them on Codex, so a sentence saying the ceiling
# holds there is false today and this is what makes it a red build.
cf="$(mktemp -d)"
printf '<!-- keel:claim gate=sensitive-guard harness=codex -->\n' > "$cf/gate.md"
printf '<!-- keel:claim property=validated_word_ceiling harness=codex -->\n' > "$cf/ceiling.md"
printf '<!-- keel:claim harness=codex -->\n' > "$cf/malformed.md"
printf '<!-- keel:claim gate=session-start harness=codex -->\n' > "$cf/good.md"
got="$(claim_gaps "$cf/gate.md" "$cf/ceiling.md" "$cf/malformed.md" "$cf/good.md" | sed "s|$cf/||" | tr '\n' ' ')"
[ "$got" = "gate.md:codex/sensitive-guard ceiling.md:codex/validated_word_ceiling malformed.md:malformed " ] \
  && ok "the claim registry fires on a withheld gate, an unvalidated property and a malformed tag" \
  || bad "the claim registry fires on a withheld gate, an unvalidated property and a malformed tag" "got: $got"
rm -rf "$cf"

# 5. A sentence using gate or ceiling vocabulary with no claim tag is an unregistered claim.
#
# A prose regex is a technique tests/test-doc-claims.sh:1-16 rejects for JUDGING claims, and this is
# not judging: its only question is whether somebody registered the sentence, which is coarse enough
# for a regex to answer honestly.
VOCAB='sensitive-guard|done-guard|context-watch|session-start|hard_block_paths|900-word|word ceiling|description budget'
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

# 7. It says what Tier B cannot claim, once, where everything else points.
#
# The section heading and the two nouns, not a turn of phrase. This task was written asking for the
# string "not enforced" and the paragraph it also specifies says "absent on Codex, not degraded",
# which is the more precise claim and the one the design argues for: the gate is not installed
# there, so there is nothing to enforce weakly. Asserting the looser phrase would have forced the
# page to say something worse than it means. What must not be lost is the section and its subject.
for phrase in '## What Tier B cannot claim' 'sensitive-guard' 'hard_block_paths' 'Codex'; do
    grep -qF "$phrase" docs/harness-support.md 2>/dev/null \
      && ok "support page states: $phrase" \
      || bad "support page states: $phrase" "absent"
done

# 8. One skills directory, two plugin manifests. Drift is impossible because there is nothing to
# drift from: both harnesses load the same skills/ tree, so there is one copy of every skill and
# nothing is vendored, copied or synchronised.
M=.codex-plugin/plugin.json
if [ -f "$M" ]; then
    [ "$(python3 -c 'import json;print(json.load(open(".codex-plugin/plugin.json"))["skills"])')" = "./skills/" ] \
      && ok "codex manifest points at ./skills/" || bad "codex manifest points at ./skills/" "wrong value"
    [ "$(python3 -c 'import json;print(json.load(open(".codex-plugin/plugin.json"))["hooks"])')" = "./hooks/hooks.codex.json" ] \
      && ok "codex manifest points at the Tier B hook manifest" \
      || bad "codex manifest points at the Tier B hook manifest" "wrong value"

    # Both manifests name the SAME skills directory. Pointing them at different trees is the drift
    # this design exists to make impossible, and it would be one edit away with nothing else to
    # notice: the skills would still load on both harnesses, and slowly stop matching.
    cs="$(python3 -c 'import json;print(json.load(open(".claude-plugin/plugin.json")).get("skills","./skills/"))' 2>/dev/null)"
    xs="$(python3 -c 'import json;print(json.load(open(".codex-plugin/plugin.json"))["skills"])')"
    [ "$cs" = "$xs" ] && ok "both plugin manifests name the same skills directory" \
      || bad "both plugin manifests name the same skills directory" "claude=$cs codex=$xs"

    # The hook manifest it names has to exist, or Codex loads a plugin that registers nothing and
    # says nothing about it, which is this design's dominant failure wearing a different hat.
    [ -f hooks/hooks.codex.json ] && ok "the hook manifest the codex plugin names exists" \
      || bad "the hook manifest the codex plugin names exists" "hooks/hooks.codex.json absent"

    dupes="$(git ls-files 'skills/*/SKILL.md' | sed 's#.*/\([^/]*\)/SKILL.md#\1#' | sort | uniq -d)"
    [ -z "$dupes" ] && ok "no skill appears twice in the tree" || bad "no skill appears twice" "$dupes"

    # ...and both manifests actually ship. tests/export-public.sh is what produces the public tree,
    # and it had no test of its own: its exclusion list is a privacy guard with nothing pinning it,
    # and a manifest that is untracked or newly excluded exports as silently as it imports. The task
    # that added this file asked for a one-off manual confirmation, which is a measurement nobody
    # repeats.
    xd="$(mktemp -d)"; rm -rf "$xd"
    if tests/export-public.sh "$xd" >/dev/null 2>&1; then
        miss=""
        for f in .claude-plugin/plugin.json .codex-plugin/plugin.json \
                 hooks/hooks.json hooks/hooks.codex.json skills/keel/SKILL.md; do
            [ -f "$xd/$f" ] || miss="$miss $f"
        done
        [ -z "$miss" ] && ok "the public export ships both plugin manifests and both hook manifests" \
          || bad "the public export ships both plugin manifests and both hook manifests" "absent:$miss"

        leaked=""
        [ -d "$xd/.claude" ] && leaked="$leaked .claude/"
        [ -d "$xd/docs/audits" ] && leaked="$leaked docs/audits/"
        [ -f "$xd/.keel/handoff.md" ] && leaked="$leaked .keel/handoff.md"
        [ -z "$leaked" ] && ok "the public export still excludes what it is meant to" \
          || bad "the public export still excludes what it is meant to" "exported:$leaked"
    else
        bad "tests/export-public.sh runs" "non-zero exit"
    fi
    rm -rf "$xd"
else
    bad ".codex-plugin/plugin.json exists" "absent"
fi

# 8. A delegation profile a skill body names must RESOLVE ON EVERY HARNESS KEEL SERVES.
#
# ADR-0005's Verification clause, made checkable. A body that names a profile no harness defines is
# an unpinned dispatch wearing a pin: it inherits whatever the driver is paying for, and the output
# looks like output either way, which is the failure tests/validate-skills.sh already says its own
# model rule exists to catch. The first version of `keel-fanout` existed for Codex alone and seven
# bodies named it, so on Claude Code the routing that docs/standards.md records as measured firing
# on 2026-08-20 was silently gone. Nothing anywhere said so, which is why this check is here rather
# than in a sentence.
#
# Both halves are checked because they fail independently and in opposite directions: the Claude
# Code side is a file this plugin ships, the Codex side is a file lib/harness/codex.sh writes into
# the project at init. Deleting either leaves the other passing.
# shellcheck disable=SC2016  # the backticks are the pattern being matched, not a substitution
profiles="$(grep -rhoE 'delegation profile `[a-z0-9-]+`' skills/*/SKILL.md skills/*/references/*.md 2>/dev/null \
    | sed 's/^delegation profile `//; s/`$//' | sort -u)"
[ -n "$profiles" ] && ok "a skill body names a delegation profile at all" \
  || bad "a skill body names a delegation profile at all" "none found, so the checks below prove nothing"
for prof in $profiles; do
    [ -f "agents/$prof.md" ] \
      && ok "delegation profile $prof resolves on claude" \
      || bad "delegation profile $prof resolves on claude" "skills name it and this plugin ships no agents/$prof.md"
    # BOTH the path and the declared name, and a mutation sweep is why. `grep -q "$prof"` alone
    # matched the .toml FILENAME on the `cat >` line, so renaming the profile inside the file left
    # this check green while Codex resolved nothing. A check that passes on the wrong content is
    # the one failure mode a claims gate cannot have.
    { grep -q "\.codex/agents/$prof\.toml" lib/harness/codex.sh 2>/dev/null \
      && grep -q "^name = \"$prof\"" lib/harness/codex.sh 2>/dev/null; } \
      && ok "delegation profile $prof resolves on codex" \
      || bad "delegation profile $prof resolves on codex" "lib/harness/codex.sh writes no agent file named $prof"
done

# ...and the Claude Code half has to SHIP. `agents/` is auto-discovered from the plugin root, so no
# manifest key is needed and none was added: `.claude-plugin/plugin.json` declares neither `skills`
# nor `hooks` either, and an explicit `agents` key REPLACES the default scan rather than adding to
# it, which is a footgun for the second profile rather than a help for the first. Checked against
# code.claude.com/docs/en/plugins-reference on 2026-09-06.
#
# What does need checking is that the file is TRACKED. tests/export-public.sh publishes `git
# ls-files` and nothing else, deliberately, so an untracked agent definition is one that exists on
# the author's machine and ships to nobody. That failure is invisible from inside this repository,
# where the profile resolves perfectly.
for prof in $profiles; do
    git ls-files --error-unmatch "agents/$prof.md" >/dev/null 2>&1 \
      && ok "agents/$prof.md is tracked, so it ships" \
      || bad "agents/$prof.md is tracked, so it ships" "untracked, and the export publishes tracked files only"
done

# 9. A plugin instruction that only applies to one harness says so WHERE IT IS GIVEN.
#
# ADR-0004: a guarantee is a property of (repository, harness), and an instruction is a guarantee in
# the imperative. `security-guidance`, `/security-review` and `skill-creator` are Claude Code
# mechanisms with no established Codex counterpart, so an unqualified "recommend it if absent" reads
# on Codex as a step the reader cannot take and has no way to know is not for them. The other
# eighteen skills already carry an inline fallback beside every plugin call; these two did not.
#
# The check is deliberately coarse: it asks whether the harness is NAMED in the body, not whether
# the sentence is well written. A regex cannot judge the second, and tests/test-doc-claims.sh:1-16
# rejects prose regexes for exactly that. What it can do honestly is notice the absence.
for f in skills/security-audit/SKILL.md skills/create-skill/SKILL.md; do
    grep -qi 'claude code' "$f" && ok "$f qualifies its plugin instruction" \
      || bad "$f qualifies its plugin instruction" "names a plugin with no harness"
done

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
