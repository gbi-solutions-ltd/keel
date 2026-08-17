#!/usr/bin/env bash
# Static validation for keel skills and templates. Free, fast, runs on every commit.
#
# Every rule here exists because it was violated during development, usually by the person who
# had just written the rule. See docs/05-token-and-memory-design.md for the budgets and
# docs/01-architecture.md for the docs-root notation.
#
# Usage: tests/validate-skills.sh   (from the repository root)
# Exits 0 when clean, 1 when any rule is broken.

# The `condition && report_pass || report_fail` idiom is used throughout. It is safe here, and only
# here, because every reporting helper returns 0 explicitly: see the `return 0` on each below. That
# makes the invariant shellcheck cannot see a stated fact in the code rather than an assumption.
# shellcheck disable=SC2015
set -uo pipefail

# Per ADR-0001. The ceiling was 700 with 400 and 600 documented as targets, and because the ceiling
# was the only number enforced, bodies migrated to it: 15 of 24 skills landed within 20 words of it
# and none met 400. The remedy the standard named, moving substance into references/, is exhausted,
# which coding-standards demonstrates at 12 reference files and 17,816 reference words with a body
# still at 683. So the ceiling moves and the target below it is enforced as a warning, because a
# ceiling with nothing under it is simply where bodies settle.
CEILING_WORDS=900
TARGET_WORDS=700

# 216 chars is doc 05's 60-token description ceiling, at the chars/3.6 estimate used everywhere else
# here. It was 260, which is about 72 tokens, so the check was looser than the budget it existed to
# enforce and every description could exceed the documented ceiling while passing.
#
# The target in doc 05 is 40 tokens and it is not reachable for most skills: a description's whole
# job is to carry the phrasings a user might actually use, and four distinct triggers do not fit in
# 144 characters. Measured across 24 skills after removing every intra-description synonym, the mean
# is 44. Only the four skills with the narrowest trigger surface come in under 40. So the ceiling is
# enforced and the target is documented as aspirational, rather than pretending 22 skills are in
# violation of something.
DESC_MAX_CHARS=216

# The sum of the descriptions, which the per-skill ceiling above does not bound. Every description
# sits in the prefix of every request in every keel project, and the total scales with the skill
# count: 1,066 tokens at 24 skills, and 1,440 if all 24 sat legally at 216 chars.
#
# 1,320 is 30 skills at the measured 44-token mean. The number comes from decision 6 in
# docs/07-open-decisions.md, which says to revisit skill granularity before the count reaches 30,
# so crossing this ceiling means what doc 05 says the remedy is: fewer skills, not shorter
# descriptions. A description trimmed below the point where it states when to use the skill costs
# more in bad routing than it saves.
#
# Characters accumulate and the estimate is taken once at the end, rather than per description and
# summed. Estimating each one first truncates 24 times and reports about ten tokens under the real
# total, which is a check quietly leaning in the wrong direction.
DESC_TOTAL_MAX_TOKENS=1320

# The profile schema's field set, fingerprinted once per schema version. bin/keel's SCHEMA_VERSION
# tells doctor whether a project's profile is missing fields, and that is only true if somebody
# bumps it when the fields change.
#
# One line per version, and the check reads the one matching the installed SCHEMA_VERSION. That
# shape is deliberate. A single constant made the lazy path the wrong one: the failure message hands
# you a new fingerprint, pasting it satisfies the check, and SCHEMA_VERSION never moves, which is
# exactly the state this whole feature exists to prevent. With a line per version, the cheap way out
# is to add a line and bump, and overwriting a released version's fingerprint is a visibly different
# act from adding one.
#
# **It still cannot force the bump, and pretending otherwise would be the same lie.** Nothing here
# can: on a fresh clone or a depth-1 CI checkout there is no earlier state to compare against, so
# the check knows what the fields hash to and not whether that changed. What it does is make
# forgetting take deliberate effort and leave a diff a reviewer can see.
schema_fingerprint_for() {
    case "$1" in
        1) printf '2128b5ddbcc7' ;;
    esac
}

errors=0
warnings=0
desc_chars=0
report() { printf 'FAIL  %s\n' "$1"; errors=$((errors+1)); return 0; }
warn()   { printf 'WARN  %s\n' "$1"; warnings=$((warnings+1)); return 0; }

# Body is everything after the closing frontmatter delimiter.
body_of() { awk 'f;/^---$/{c++; if(c==2) f=1}' "$1"; }

frontmatter_of() { awk '/^---$/{c++; if(c>=2) exit} c==1' "$1"; }

for skill in skills/*/SKILL.md; do
    [ -e "$skill" ] || continue
    dir=$(dirname "$skill")
    name=$(basename "$dir")
    fm=$(frontmatter_of "$skill")
    body=$(body_of "$skill")

    # Frontmatter must carry name and description.
    printf '%s' "$fm" | grep -q '^name:' || report "$name: frontmatter has no name"
    if ! printf '%s' "$fm" | grep -q '^description:'; then
        report "$name: frontmatter has no description"
    else
        desc=$(printf '%s' "$fm" | sed -n 's/^description:[[:space:]]*//p')
        # The description states when to use the skill, never what it does. A description that
        # summarises the workflow becomes a shortcut the model takes instead of reading the body.
        case "$desc" in
            "Use when"*) : ;;
            *) report "$name: description must start with \"Use when\", got \"${desc:0:40}...\"" ;;
        esac
        chars=$(printf '%s' "$desc" | wc -c | tr -d ' ')
        [ "$chars" -le "$DESC_MAX_CHARS" ] || report "$name: description is $chars chars, ceiling $DESC_MAX_CHARS"
        desc_chars=$(( desc_chars + chars ))
    fi

    # Body budget. Past the ceiling the model starts skimming, which is the failure the budget
    # exists to prevent.
    words=$(printf '%s' "$body" | wc -w | tr -d ' ')
    if [ "$words" -gt "$CEILING_WORDS" ]; then
        report "$name: body is $words words, ceiling $CEILING_WORDS"
    elif [ "$words" -gt "$TARGET_WORDS" ]; then
        warn "$name: body is $words words, over the $TARGET_WORDS target (ceiling $CEILING_WORDS). ADR-0001 requires a passing eval arm at this length."
    fi

    # @ links force-load at parse time and burn context before it is needed.
    if printf '%s' "$body" | grep -qE '(^|[[:space:]])@[A-Za-z0-9_./-]+'; then
        report "$name: contains an @ link. Use a relative markdown link instead"
    fi

    # Skills resolve the docs root from profile.docs_root at invocation. A literal path fails
    # silently: the skill writes successfully, to a directory nobody reads.
    if grep -qE 'docs/keel/[A-Za-z]' "$skill"; then
        report "$name: hardcodes a docs/keel path. Use <docs_root>"
    fi
    # {{DOCS_ROOT}} is substituted by keel init. Skills are never rendered, so it would ship literal.
    if grep -q '{{DOCS_ROOT}}' "$skill"; then
        report "$name: contains {{DOCS_ROOT}}. That is for templates; skills read profile.docs_root"
    fi

    # Relative links must resolve, or the progressive-disclosure model breaks at the moment of use.
    # An anchor is part of the link and not part of the path, so it is stripped before resolving:
    # `references/x.md#a-heading` is a correct link to a file that exists, and rejecting it would
    # make the check stricter than correct output, which teaches people to ignore checks.
    while IFS= read -r target; do
        target="${target%%#*}"
        [ -n "$target" ] || continue
        [ -e "$dir/$target" ] || report "$name: broken link to $target"
    done < <(grep -o '](\([^)]*\))' "$skill" | sed 's/](\(.*\))/\1/' | grep -Ev '^(https?:|#)')
done

desc_tokens=$(( desc_chars * 10 / 36 ))
if [ "$desc_tokens" -gt "$DESC_TOTAL_MAX_TOKENS" ]; then
    report "the skill descriptions total about $desc_tokens tokens, over the $DESC_TOTAL_MAX_TOKENS ceiling. They are in the prefix of every request in every keel project. The remedy is fewer skills, not shorter descriptions."
fi

# Everything shipped, skills and templates alike, obeys the content rules. References are
# unbounded in length but not in what they may contain.
while IFS= read -r f; do
    # A path is forbidden; a bare mention of the default as prose is not.
    if grep -qE 'docs/keel/[A-Za-z]' "$f"; then
        case "$f" in
            templates/*) report "$f: template hardcodes a docs path. Use {{DOCS_ROOT}}" ;;
            *)           report "$f: hardcodes a docs/keel path. Use <docs_root>" ;;
        esac
    fi
    LC_ALL=C grep -q "$(printf '\xe2\x80\x94')" "$f" && report "$f: contains an em dash"
    LC_ALL=C grep -q "$(printf '\xe2\x80\x93')" "$f" && report "$f: contains an en dash"

    # Links inside a reference resolve too. This was added when the index of topic references moved
    # out of a skill body into a reference, to stay inside the body's word budget: ten links that
    # nothing checked, in the one file whose whole job is routing a reader to the right file. A
    # broken link there sends the model to a topic it then silently skips.
    fdir=$(dirname "$f")
    while IFS= read -r target; do
        target="${target%%#*}"
        [ -n "$target" ] || continue
        [ -e "$fdir/$target" ] || report "$f: broken link to $target"
    done < <(grep -o '](\([^)]*\))' "$f" | sed 's/](\(.*\))/\1/' | grep -Ev '^(https?:|#)')
done < <(find skills templates output-styles -name '*.md' 2>/dev/null)

# Documentation obeys the writing rules too. Everything above covers shipped content only, so every
# plan, ADR, idea record, runbook and root document was exempt from the rules it is written under.
# That is latent while two people write them and stops being latent the moment anyone else does.
#
# Two of the three shipped-content rules carry over. One deliberately does not, and both decisions
# were measured against this repository before the rule was written rather than reasoned about:
#
#   - Em and en dashes: checked, over the whole file including fenced blocks, because a plan quotes
#     prose destined for a skill and that prose obeys the same rule. Zero hits across 48 files, so
#     this rule starts green rather than requiring a cleanup.
#   - Relative links: checked, with fenced blocks stripped first. Without stripping, this rejects
#     docs/plans/2026-08-17-release-readiness.md nine times: a plan legitimately quotes links
#     destined for other files, and two of the nine are `sed` patterns that are not links at all. A
#     check that rejects a correct plan is the failure CONTRIBUTING.md calls unrecoverable.
#   - The docs/keel path rule: NOT applied. It fires on five correct documents, among them
#     docs/05-token-and-memory-design.md, which is the document that defines the layout and has to
#     name it. A skill must write <docs_root>; prose about the default is prose.
while IFS= read -r f; do
    [ -f "$f" ] || continue
    LC_ALL=C grep -q "$(printf '\xe2\x80\x94')" "$f" && report "$f: contains an em dash"
    LC_ALL=C grep -q "$(printf '\xe2\x80\x93')" "$f" && report "$f: contains an en dash"

    ddir=$(dirname "$f")
    while IFS= read -r target; do
        target="${target%%#*}"
        [ -n "$target" ] || continue
        [ -e "$ddir/$target" ] || report "$f: broken link to $target"
    done < <(awk '/^ *```/{fence=!fence; next} !fence' "$f" \
        | grep -o '](\([^)]*\))' | sed 's/](\(.*\))/\1/' | grep -Ev '^(https?:|#)')
done < <({ find docs -name '*.md' 2>/dev/null
           find . -maxdepth 1 -name '*.md' 2>/dev/null | sed 's|^\./||'; })

# A style that drops keep-coding-instructions replaces Claude Code's software engineering
# instructions rather than adding to them, which changes how work is scoped and verified. The goal
# of the one style shipped here is shorter replies, not a different engineer, and the difference is
# invisible until someone wonders why the tests stopped being run.
for style in output-styles/*.md; do
    [ -e "$style" ] || continue
    fm="$(frontmatter_of "$style")"
    case "$fm" in
        *"keep-coding-instructions: true"*) ;;
        *) report "$style: no 'keep-coding-instructions: true'. A style without it drops the built-in software engineering instructions." ;;
    esac
    case "$fm" in *"name:"*) ;;        *) report "$style: no name" ;; esac
    case "$fm" in *"description:"*) ;; *) report "$style: no description" ;; esac
done

# A brief dispatched to a model alias that does not exist is a brief dispatched to nothing, and the
# failure is silent. The five aliases below are the ones Claude Code accepts. A full model id is
# also valid and is deliberately not permitted here: an id pinned in a skill goes stale without
# anything noticing, while an alias tracks the current model.
#
# The marker is the word `model` before the alias, not `on`. `on \`x\`` was the first pattern and it
# collided with seven existing phrases, `on \`main\`` three times among them, so the rule would have
# failed on correct prose the moment it was added.
# shellcheck disable=SC2016  # the $ in s/`$// is an end anchor, not an expansion; single quotes are required
bad_models=$(grep -rhoE 'model `[a-z0-9.-]+`' skills/*/SKILL.md skills/*/references/*.md 2>/dev/null \
    | sed 's/^model `//; s/`$//' | sort -u \
    | grep -vxE 'sonnet|opus|haiku|fable|inherit' || true)
[ -z "$bad_models" ] \
  || report "unknown model alias in a skill: $(printf '%s' "$bad_models" | tr '\n' ' '). Claude Code accepts sonnet, opus, haiku, fable or inherit."

# A plan task without a done condition is where "done" becomes an adjective the implementer applies
# to their own work. The template is the only place the requirement can be stated once, so this
# guards it against a well meaning trim.
#
# It checks the template, not the plans. It cannot tell whether a written condition is a real
# command or a sentence dressed as one, and a rule that pretended to would reject correct plans and
# pass plausible ones. The limit is stated rather than papered over: what checks the plans is
# execute-plan refusing to tick a box without the command's output.
if [ -f skills/write-plan/references/plan-template.md ]; then
    grep -q '\*\*Done when:\*\*' skills/write-plan/references/plan-template.md \
      || report "skills/write-plan/references/plan-template.md has no **Done when:** marker. A plan task with no done condition leaves done as an adjective."
fi

# The router's destinations must exist. A route to a deleted skill is a dead end the model
# follows confidently, and nothing else would catch it.
# shellcheck disable=SC2016  # literal backticks and $ below are the pattern, not expansions
if [ -f skills/keel/SKILL.md ]; then
    while IFS= read -r dest; do
        [ -n "$dest" ] || continue
        [ -d "skills/$dest" ] || report "keel: routes to \"$dest\", which does not exist"

        # The cheatsheet is the user-facing copy of the same table, and it ships into every project.
        # Nothing checked that the two agreed, and they had already drifted: incident-response was
        # routable by the model and absent from the document the user reads. A skill missing here is
        # a skill nobody knows to ask for, which is indistinguishable from one that does not exist.
        if [ -f templates/prompting-cheatsheet.md ]; then
            grep -qF "\`$dest\`" templates/prompting-cheatsheet.md \
              || report "keel: routes to \"$dest\", which the shipped cheatsheet does not mention"
        fi
    done < <(grep -oE '\| `[a-z-]+` \|$' skills/keel/SKILL.md | tr -d '| `')
fi

# The SessionStart injection is the only routing map a session gets without loading anything, and it
# sits in the prefix of every request. A skill missing from it is a skill the model will not think of
# unless the user names it. Three had gone missing before this check existed, including
# incident-response, which is the one that most needs to fire without being asked for.
if [ -f hooks/session-start ]; then
    while IFS= read -r s; do
        [ -n "$s" ] || continue
        grep -q "$s" hooks/session-start || report "hooks/session-start does not name the skill \"$s\""
    done < <(find skills -maxdepth 1 -mindepth 1 -type d -exec basename {} \; 2>/dev/null)

    # Doc 05 budgets this at 250 tokens, 400 hard. Estimated at chars/3.6, the same way doctor sizes
    # the CLAUDE.md block, because a count-tokens call needs an API key and a check that only runs
    # where a key happens to exist is absent exactly where nobody is watching.
    hook_chars=$(bash hooks/session-start 2>/dev/null | wc -c | tr -d ' ')
    hook_tokens=$(( hook_chars * 10 / 36 ))
    if [ "$hook_tokens" -gt 400 ]; then
        report "hooks/session-start injects about $hook_tokens tokens, over the 400 ceiling. It is in every request of every session."
    fi
fi

# repo-snapshot deliberately does not audit: section-templates.md section 8 says so. A document that
# omits both the refusal and the referral reads as a clean bill of health, which is the one thing a
# snapshot must never accidentally be.
#
# Guarded on the files existing, like the checks above, because tests/test-validate-skills.sh runs
# this validator from fixture roots that contain no skills/repo-snapshot, and an unguarded read
# would fail every one of those cases instead of this rule.
# The needles are matched inside section 10 only, not anywhere in the file. `coding-standards`
# already appears in section 7's table of missing documents, so a whole-file grep passed while
# section 10 said nothing, which is an assertion that cannot fail and therefore checks nothing.
snapshot_tpl=skills/repo-snapshot/references/section-templates.md
if [ -f "$snapshot_tpl" ]; then
    section10="$(awk '/^## 10\./{f=1} f&&/^## 11\./{f=0} f' "$snapshot_tpl")"
    for needed in 'security-audit --full' 'coding-standards' 'did not check'; do
        printf '%s' "$section10" | grep -qF -- "$needed" \
          || report "$snapshot_tpl section 10 does not require '$needed'. A snapshot that names neither what it skipped nor who does it reads as a clean bill of health."
    done
fi
# Scoped to step 6, for the reason the block above is scoped to section 10. A whole-file grep here
# would keep passing if the phrase migrated into Common mistakes and step 6 stopped requiring
# anything, while the message still claimed to be about step 6.
if [ -f skills/repo-snapshot/SKILL.md ]; then
    step6="$(awk '/^## Step 6/{f=1} f&&/^## [A-Z]/&&!/^## Step 6/{f=0} f' skills/repo-snapshot/SKILL.md)"
    printf '%s' "$step6" | grep -qF -- 'did not check' \
      || report "skills/repo-snapshot/SKILL.md step 6 does not require the snapshot to say what it did not check."
fi

# A gap the snapshot names without naming a tool leaves the reader a research project, and a tool
# the snapshot picks without a written-down reason is an opinion nobody can correct. The table is
# only worth citing while it covers what lib/detect-stack.sh actually produces: a language added to
# detection with no row is a gap the snapshot will improvise on, differently every time.
#
# The languages come from detect_languages' assignments, which is the function whose entire job is
# to produce the list. lang_profile's case labels were the obvious source and they are wrong: its
# typescript branch contains an inner `case "$f" in nest)` for framework detection, so the labels
# yield `nest` as a fourteenth language and this rule would demand a tool row for NestJS. Checked
# before the rule was written, which is the only reason it is not in it.
#
# Both files are guarded on existence, like the checks above, because tests/test-validate-skills.sh
# runs this validator from fixture roots that build only what a case needs.
tool_tbl=skills/keel/references/tool-choices.md
if [ -f "$tool_tbl" ] && [ -f lib/detect-stack.sh ]; then
    # shellcheck disable=SC2016  # the literal $ is the pattern being searched for, not an expansion
    langs="$(awk '/^detect_languages\(\)/{f=1} f&&/^}/{f=0} f' lib/detect-stack.sh \
        | grep -oE 'out="\$out [a-z]+"' | sed -E 's/.* ([a-z]+)"/\1/' | sort -u)"
    # An empty list makes the loop below run zero times and the rule pass while checking nothing,
    # which is the failure mode this repository keeps rediscovering: the section-10 grep that could
    # not fail, and the spawn-count assertions that passed at zero. The extraction is coupled to one
    # spelling of the accumulator, so a rename inside detect_languages would silently disable the
    # rule rather than break it. Found in review, before it happened.
    [ -n "$langs" ] \
      || report "no languages could be read from lib/detect-stack.sh's detect_languages. The tool-table rule is checking nothing. If the accumulator was renamed or its assignments reshaped, update the extraction in this rule."

    for l in $langs; do
        grep -qE "^\| *\`?$l\`?[ |]" "$tool_tbl" \
          || report "$tool_tbl has no row for '$l', which lib/detect-stack.sh detects. A gap in a language the snapshot will meet is one it improvises a tool for."
    done

    snapshot_s10="$(awk '/^## 10\./{f=1} f&&/^## 11\./{f=0} f' skills/repo-snapshot/references/section-templates.md 2>/dev/null)"
    printf '%s' "$snapshot_s10" | grep -qF -- 'tool-choices.md' \
      || report "skills/repo-snapshot/references/section-templates.md section 10 does not cite tool-choices.md, so a gap gets a skill but no tool."
fi

# A field added, removed, renamed or moved without SCHEMA_VERSION moving is a release that expects a
# field nobody's profile has, and doctor would stay quiet about it because doctor compares the
# version, not the fields. Guarded on the file existing, like the checks above, because this
# validator is run from fixture roots by tests/test-validate-skills.sh.
#
# It fingerprints the schema document, which is not the same thing as what `keel init` writes.
# write_profile is the writer and the two already differ in both directions: init emits
# `artifacts._note`, which the schema does not declare, and the schema declares `hard_block_paths`,
# `verify_notes` and `plugins`, which init never writes because a human adds them. So a field added
# to write_profile alone trips nothing here. Fingerprinting init's actual output would need init to
# run, and this validator is the free, fast check that runs on every commit. Stated rather than
# implied, because a guard whose coverage you have to infer gets trusted for more than it does.
if [ -f templates/profile.schema.json ] && command -v python3 >/dev/null 2>&1; then
    schema_got="$(python3 - <<'PY'
import hashlib, json
d = json.load(open("templates/profile.schema.json"))
paths = []
for k, v in d.get("properties", {}).items():
    paths.append(k)
    if isinstance(v, dict):
        paths += ["%s.%s" % (k, c) for c in v.get("properties", {})]
print(hashlib.sha256("\n".join(sorted(paths)).encode()).hexdigest()[:12])
PY
)"
    schema_sv="$(sed -n 's/^SCHEMA_VERSION=\([0-9][0-9]*\)$/\1/p' bin/keel 2>/dev/null)"
    schema_want="$(schema_fingerprint_for "${schema_sv:-0}")"
    if [ -z "$schema_want" ]; then
        report "bin/keel declares SCHEMA_VERSION=${schema_sv:-none}, and schema_fingerprint_for records no fingerprint for it. Add a \"${schema_sv:-none}) printf '$schema_got' ;;\" line beside the others."
    elif [ "$schema_got" != "$schema_want" ]; then
        report "templates/profile.schema.json changed its field set (fingerprint $schema_got, expected $schema_want for schema version ${schema_sv:-none}). Bump SCHEMA_VERSION in bin/keel and add a new line to schema_fingerprint_for for it, in the same commit. Do not edit the ${schema_sv:-none}) line: that is a released version's record, and rewriting it leaves every existing profile claiming a field set it does not have."
    fi
fi

if [ "$errors" -eq 0 ]; then
    count=$(find skills -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')
    # The total is stated on every clean run, not only when it is breached. A budget nobody sees
    # until it fails is one that gets breached by the change that had no idea it was near.
    if [ "$warnings" -gt 0 ]; then
        printf 'OK    %s skills validated, descriptions about %s tokens, %s warning(s)\n' \
          "$count" "$desc_tokens" "$warnings"
    else
        printf 'OK    %s skills validated, descriptions about %s tokens\n' "$count" "$desc_tokens"
    fi
    exit 0
fi
printf '\n%s problem(s) found, %s warning(s)\n' "$errors" "$warnings"
exit 1
