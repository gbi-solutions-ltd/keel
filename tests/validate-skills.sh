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

# NOTHING IN THIS FILE PIPES INTO `grep -q`. Use a here-string, which is a redirect and not a
# pipeline, so the status is grep's alone. `producer | grep -q needle` under `set -o pipefail` is a
# race: grep exits at the first match, the producer dies on its next write, and pipefail turns its
# 141 into a failed pipeline. On 2026-09-04 that turned four found matches into "SKILL.md never
# names it" on main, against a tree that had passed the same check on the pull request minutes
# before. The bodies it accused were over one stdio block with the match in the first block; the
# ones it passed were under a block, so the producer had already finished. Timing decided it.

# Per ADR-0001. The ceiling was 700 with 400 and 600 documented as targets, and because the ceiling
# was the only number enforced, bodies migrated to it: 15 of 24 skills landed within 20 words of it
# and none met 400. The remedy the standard named, moving substance into references/, is exhausted,
# which coding-standards demonstrated at 12 reference files and 17,816 reference words with a body
# still at 683, measured 2026-08-16. It is 17, 22,752 and 795 today, and tests/test-doc-claims.sh
# asserts that rather than leaving it to the next reader to notice. So the ceiling moves and the
# target below it is enforced as a warning, because a ceiling with nothing under it is simply where
# bodies settle.
CEILING_WORDS=900
TARGET_WORDS=700
# How close to the ceiling a body has to be before the warning says how close. Wide enough that a
# body reaches it before an ordinary edit does, narrow enough that the number still means something.
HEADROOM_WORDS=30

# 216 chars is doc 05's 60-token description ceiling, at the chars/3.6 estimate used everywhere else
# here. It was 260, which is about 72 tokens, so the check was looser than the budget it existed to
# enforce and every description could exceed the documented ceiling while passing.
#
# The target in doc 05 is 40 tokens and it is not reachable for most skills: a description's whole
# job is to carry the phrasings a user might actually use, and four distinct triggers do not fit in
# 144 characters. Measured across 24 skills on 2026-08-16, after removing every intra-description synonym, the mean
# is 44. Only the four skills with the narrowest trigger surface come in under 40. So the ceiling is
# enforced and the target is documented as aspirational, rather than pretending 22 skills are in
# violation of something.
DESC_MAX_CHARS=216

# The sum of the descriptions, which the per-skill ceiling above does not bound. Every description
# sits in the prefix of every request in every keel project, and the total scales with the skill
# count: 1,066 tokens at 24 skills when this was written, about 1,130 at 25 today, and 1,440 if
# every skill sat legally at 216 chars.
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
        2) printf '24e947eee3ce' ;;
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
    grep -q '^name:' <<<"$fm" || report "$name: frontmatter has no name"
    if ! grep -q '^description:' <<<"$fm"; then
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
    #
    # Within HEADROOM_WORDS of the ceiling the warning says how many words are left, because "over
    # the 700 target" reads the same at 750 and at 897 and only one of those is a body where the next
    # edit fails the suite. write-plan sat at 897 and nothing said so until someone tried to add a
    # sentence and had the suite refuse it. Whoever is about to edit a body runs this, so this is
    # where the number reaches them.
    words=$(printf '%s' "$body" | wc -w | tr -d ' ')
    if [ "$words" -gt "$CEILING_WORDS" ]; then
        report "$name: body is $words words, ceiling $CEILING_WORDS"
    elif [ "$words" -gt $(( CEILING_WORDS - HEADROOM_WORDS )) ]; then
        warn "$name: body is $words words, $(( CEILING_WORDS - words )) from the $CEILING_WORDS ceiling and over the $TARGET_WORDS target. Adding a sentence fails the suite: take the words out of this body, or move a section a reader needs at one step into references/. ADR-0001 requires a passing eval arm at this length."
    elif [ "$words" -gt "$TARGET_WORDS" ]; then
        warn "$name: body is $words words, over the $TARGET_WORDS target (ceiling $CEILING_WORDS). ADR-0001 requires a passing eval arm at this length."
    fi

    # @ links force-load at parse time and burn context before it is needed.
    if grep -qE '(^|[[:space:]])@[A-Za-z0-9_./-]+' <<<"$body"; then
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
    # An inline code span is stripped first, for the same reason, and the same strip runs in all
    # three link loops. That makes the three agree about spans and no more: only the docs loop
    # strips fenced blocks, so a fence still means one thing here and another there. The comment
    # above the docs loop says why, and names the two shapes the span strip does not handle.
    # shellcheck disable=SC2016  # the backticks are the pattern; in double quotes they would be a
    # command substitution, so single quotes are required and SC2016 fires on them either way
    while IFS= read -r target; do
        target="${target%%#*}"
        [ -n "$target" ] || continue
        [ -e "$dir/$target" ] || report "$name: broken link to $target"
    done < <(sed 's/``[^`]*``//g; s/`[^`]*`//g' "$skill" \
        | grep -o '](\([^)]*\))' | sed 's/](\(.*\))/\1/' | grep -Ev '^(https?:|#)')
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
    # shellcheck disable=SC2016  # the backticks are the pattern, not a command substitution
    while IFS= read -r target; do
        target="${target%%#*}"
        [ -n "$target" ] || continue
        [ -e "$fdir/$target" ] || report "$f: broken link to $target"
    done < <(sed 's/``[^`]*``//g; s/`[^`]*`//g' "$f" \
        | grep -o '](\([^)]*\))' | sed 's/](\(.*\))/\1/' | grep -Ev '^(https?:|#)')
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
#
#     Inline code spans are stripped for exactly the same reason, and the strip is repeated in the
#     two skill link loops above. That makes the three agree about spans and about nothing else:
#     only this loop strips fenced blocks, so the three still disagree about what a fence means,
#     and deliberately, because only documentation quotes markdown destined for another file. A
#     span renders as code, so it is not a link, and resolving one is the same too-strict failure
#     as resolving a fenced block. The pattern that forced it: task 3 of
#     docs/plans/2026-09-02-the-four-mode-router-and-audit.md instructs an implementer to add the
#     assertion `grep -q '](audit-offer.md)'`, and the docs loop extracted audit-offer.md from that
#     span, resolved it against docs/plans/, and reported a broken link to a file the plan had
#     never named as one.
#
#     TWO DELIMITER LENGTHS, LONGEST FIRST. The plan writes that pattern both ways, once in single
#     backticks and once in double, and a single-delimiter strip is not enough: against a ``...``
#     span it deletes the empty run between the two opening backticks and the empty run between the
#     two closing ones, and leaves the contents standing as a link. That is the false positive
#     surviving the fix written to remove it, so the double-backtick clause runs first. Which run
#     lengths survive was measured across n = 1 to 8 rather than reasoned about: runs of one, two,
#     three, five, six and seven are handled, and runs of four and eight are not. The survivors are
#     the multiples of four, because the double clause consumes them in pairs and leaves nothing
#     over for the single clause. The only four-backtick runs in this repository are fence markers,
#     each alone on its line, and the awk above removes them before the strip sees them. The
#     failure mode if a four-run ever wrapped a link is the too-strict one this comment is about, a
#     false broken link, not a missed real one.
#
#     Measured before it was added: across every file this loop scans it changes exactly one file's
#     extracted targets, and across every SKILL.md and every file under skills, templates and
#     output-styles it changes nothing. No number of false positives is written down here, because
#     it moves every time that plan quotes another link-shaped pattern and it has already moved
#     once. The property is what holds: with the strip this loop extracts no target at all from
#     docs/plans/2026-09-02-the-four-mode-router-and-audit.md, and without it one per quoted
#     pattern.
#
#     WHAT IT PROVABLY CATCHES. A link whose text is backticked and whose target is not: the strip
#     removes the text, and the target is still extracted and still resolved.
#     tests/test-validate-skills.sh holds a case in each direction, so a later widening of the
#     strip that swallowed a real link would fail rather than pass quietly. That is one shape, and
#     it does not generalise to "cannot blind the check to a real link", which two shapes disprove.
#
#     GAP ONE: escaped backticks, which are delimiters to this strip and are not delimiters to
#     CommonMark. A link written between \` and \` renders as a live link with literal backticks
#     around it, and the strip deletes it, so its target is never resolved and a broken one is
#     never reported. Nothing in this repository writes that shape.
#
#     GAP TWO, and the worse of the two because the shape is everywhere: a code span wrapped across
#     two lines. sed is line-oriented, so a span that opens on one line and closes on the next
#     leaves an odd backtick on each of them, and the odd one pairs with the next span's opener and
#     deletes everything between, a real link included. Hard wrapping at 100 columns splits spans
#     routinely, and over twenty documents here already carry at least one span split that way.
#     Both gaps were reproduced, not reasoned about. Neither mis-resolves anything on the tree as
#     it stands, and closing either needs a parser rather than a sed, which is why they are
#     recorded here instead.
#   - The docs/keel path rule: NOT applied. It fires on five correct documents, among them
#     docs/05-token-and-memory-design.md, which is the document that defines the layout and has to
#     name it. A skill must write <docs_root>; prose about the default is prose.
while IFS= read -r f; do
    [ -f "$f" ] || continue
    LC_ALL=C grep -q "$(printf '\xe2\x80\x94')" "$f" && report "$f: contains an em dash"
    LC_ALL=C grep -q "$(printf '\xe2\x80\x93')" "$f" && report "$f: contains an en dash"

    ddir=$(dirname "$f")
    # shellcheck disable=SC2016  # the backticks are the pattern, not a command substitution
    while IFS= read -r target; do
        target="${target%%#*}"
        [ -n "$target" ] || continue
        [ -e "$ddir/$target" ] || report "$f: broken link to $target"
    done < <(awk '/^ *```/{fence=!fence; next} !fence' "$f" \
        | sed 's/``[^`]*``//g; s/`[^`]*`//g' \
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
# The match is case-insensitive because `skills/write-plan/references/plan-review.md` writes
# `Model \`inherit\`` at the start of a sentence. Until 2026-08-20 that pin was invisible here, so a
# capital M was a way to hold an unchecked alias.
# shellcheck disable=SC2016  # the $ in s/`$// is an end anchor, not an expansion; single quotes are required
bad_models=$(grep -rhoiE 'model `[a-z0-9.-]+`' skills/*/SKILL.md skills/*/references/*.md 2>/dev/null \
    | sed 's/^[Mm]odel `//; s/`$//' | sort -u \
    | grep -vxE 'sonnet|opus|haiku|fable|inherit' || true)
[ -z "$bad_models" ] \
  || report "unknown model alias in a skill: $(printf '%s' "$bad_models" | tr '\n' ' '). Claude Code accepts sonnet, opus, haiku, fable or inherit."

# The check above rejects a model that does not exist. It says nothing about a dispatch that names
# no model at all, so until 2026-08-20 a wrong pin was caught and a missing one was invisible, which
# is the worse of the two: an unpinned dispatch silently inherits whatever the driver is paying for,
# and the output looks like output either way. Found by the same sweep that measured the pins firing;
# `security-audit` had been fanning out one subagent per phase unpinned since it was written.
#
# Detection is per paragraph: a block that instructs a dispatch and names an agent must have a model.
# The dispatch verb must open a sentence, follow a comma or colon, or open a bold run-in. Bare
# containment was tried first and flagged `prd-template.md`'s "Run this yourself, not as a subagent
# dispatch", which is an instruction not to dispatch, so position is doing real work here.
#
# The model may sit anywhere in the file, or in a reference the file links to, because
# `execute-plan/SKILL.md` legitimately keeps its briefs and their `inherit` pin in
# `references/subagent-prompts.md`. Paragraph-level detection with file-level satisfaction is what
# lets that pass while `references/parallel-batches.md`, which links to no such file, still fails.
#
# What it cannot do: tell a real dispatch from prose that reads like one. It is a marker, like the
# `model` marker above, and a skill that dispatches without using either word is not covered.
# shellcheck disable=SC2016  # the backticks are the pattern, not a command substitution
names_model() { grep -qiE 'model `[a-z0-9.-]+`' "$1" 2>/dev/null; }
for skill_doc in skills/*/SKILL.md skills/*/references/*.md; do
    [ -e "$skill_doc" ] || continue
    dispatch=$(awk 'BEGIN{RS="";FS="\n"}
        $0 ~ /(^|\*\*|[.,:;>] )([Dd]ispatch|[Dd]elegat)/ && $0 ~ /[Aa]gents?|[Ss]ubagents?/ {print $1; exit}' "$skill_doc")
    [ -n "$dispatch" ] || continue
    names_model "$skill_doc" && continue
    linked=""
    for ref in $(grep -oE '\(([A-Za-z0-9_./-]*references/[A-Za-z0-9_.-]+\.md)\)' "$skill_doc" 2>/dev/null | tr -d '()'); do
        cand="$(dirname "$skill_doc")/$ref"
        [ -e "$cand" ] || cand="$(dirname "$skill_doc")/${ref#*references/}"
        names_model "$cand" && { linked=yes; break; }
    done
    [ -n "$linked" ] && continue
    report "$skill_doc: dispatches subagents without naming a model. \"$(printf '%s' "$dispatch" | cut -c1-60)...\" An unpinned dispatch inherits the driver's model silently."
done

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

# Every documented delegation must be one the skill actually makes.
#
# Three separate audits found this class and each fixed only the instances in front of it. The
# wiring map in docs/04-plugin-strategy.md was false in six of its ten rows on 2026-09-02, four of
# them since the table was written, and the column header says "Plugin it calls" in the present
# tense. docs/02-skill-catalog.md carried the same false claim about context-budget. A documented
# delegation nobody made is worse than an undocumented one: a reader plans around it.
#
# TWO SOURCES, TWO SHAPES, because the documents differ and converting one to suit a checker is the
# tail wagging the dog. In docs/04 it is the table under the `| keel skill |` header. In docs/02 it
# is prose introduced by a bold `**Plugin call` lead, which is consistent across every instance.
#
# THIS COMMITS docs/04 TO A PARSEABLE TABLE. The header row is the anchor and the first two columns
# are load bearing: skill in one, plugin in the other, each in backticks. Reformatting that table
# breaks this check rather than silently disabling it, because a table this cannot parse yields no
# pairs, and the count assertion below is what makes that loud.
#
# BODY ONLY, NOT references/, decided deliberately. A reference file mention is satisfiable without
# the skill delegating at all: the body is what the model reads on every invocation, and a pointer
# buried in a reference the run never loads is exactly the gap being guarded. All six true rows name the
# plugin in the body today, so the stricter rule costs nothing now and is the one worth having.
#
# A COMMAND IS NOT A PLUGIN. Backticked tokens starting with `/` are skipped: `/security-review` is
# built in and `/code-review` is provided by a plugin already named on the same row, so requiring
# them would check the same fact twice under a name that can change.
if [ -f docs/04-plugin-strategy.md ] || [ -f docs/02-skill-catalog.md ]; then
    delegation_pairs=0
    while IFS="$(printf '\t')" read -r src skill plugin; do
        [ -n "$skill" ] && [ -n "$plugin" ] || continue
        delegation_pairs=$(( delegation_pairs + 1 ))
        if [ ! -f "skills/$skill/SKILL.md" ]; then
            report "$src claims $skill delegates to $plugin, and skills/$skill/SKILL.md does not exist"
        elif ! grep -q -- "$plugin" <<<"$(body_of "skills/$skill/SKILL.md")"; then
            report "$src says \`$skill\` calls \`$plugin\`, and skills/$skill/SKILL.md never names it. Wire the skill, or take the row out. A reference file does not count: the body is what the model reads on every invocation."
        fi
    done <<EOF
$(
    [ -f docs/04-plugin-strategy.md ] && awk '
        /^\| keel skill \|/ { t=1; next }
        t && /^\|---/ { next }
        t && !/^\|/ { t=0; next }
        t {
            n = split($0, cell, "|")
            if (n < 3) next
            s = cell[2]; p = cell[3]
            if (match(s, /`[^`]+`/) == 0) next
            skill = substr(s, RSTART + 1, RLENGTH - 2)
            while (match(p, /`[^`]+`/)) {
                tok = substr(p, RSTART + 1, RLENGTH - 2)
                if (substr(tok, 1, 1) != "/") print "docs/04-plugin-strategy.md\t" skill "\t" tok
                p = substr(p, RSTART + RLENGTH)
            }
        }' docs/04-plugin-strategy.md
    [ -f docs/02-skill-catalog.md ] && awk '
        /^### `/ { if (match($0, /`[^`]+`/)) skill = substr($0, RSTART + 1, RLENGTH - 2) }
        /^\*\*Plugin call/ {
            line = $0
            while (match(line, /`[^`]+`/)) {
                tok = substr(line, RSTART + 1, RLENGTH - 2)
                if (substr(tok, 1, 1) != "/") print "docs/02-skill-catalog.md\t" skill "\t" tok
                line = substr(line, RSTART + RLENGTH)
            }
        }' docs/02-skill-catalog.md
)
EOF

    # A parse that silently yields nothing passes every assertion above, which is the failure mode of
    # every checker built on a format somebody may reformat. This is the floor that tells the two
    # apart. Ten pairs on 2026-09-02, six in the table and four in the prose.
    [ "$delegation_pairs" -ge 8 ] || \
      report "the delegation check found only $delegation_pairs documented delegations, against 10 on 2026-09-02. Either the wiring map in docs/04-plugin-strategy.md or the \`**Plugin call\` leads in docs/02-skill-catalog.md have been reformatted past what this parses, and a check that reads nothing passes everything."
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

    # Doc 05 budgets this at 250 tokens, 400 hard, and NFR-01 of docs/prd/plain-language-chat.md
    # tightens it to 356 for every combination. Estimated at chars/3.6, the same way doctor sizes
    # the CLAUDE.md block, because a count-tokens call needs an API key and a check that only runs
    # where a key happens to exist is absent exactly where nobody is watching.
    #
    # All four combinations of response_style and explain_level, not just the one this repository's
    # profile selects. Measuring only the local configuration is how a paragraph that fits terse and
    # technical reaches a release while breaking verbose and plain.
    #
    # Split with parameter expansion rather than `set --`. This is top level, not a function, so
    # `set --` would clobber the script's own positional parameters, and it needs an unquoted
    # expansion that shellcheck is right to flag.
    # The mktemp guard is load bearing. Without it a failed mktemp leaves $probe empty, the profile
    # writes fail, and `cd "" && bash "$hook_abs"` still succeeds, because cd with an empty argument
    # is a no-op returning 0. The loop would then measure this repository's own profile four times
    # and report green, which is the exact check this block exists to be. Caught in review.
    hook_abs="$PWD/hooks/session-start"
    if probe="$(mktemp -d)"; then
        mkdir -p "$probe/.keel"
        for combo in "terse technical" "terse plain" "verbose technical" "verbose plain"; do
            rs="${combo%% *}"; el="${combo##* }"
            printf '{"conventions": {"response_style": "%s", "explain_level": "%s"}}\n' "$rs" "$el" \
                > "$probe/.keel/profile.json"
            hook_chars=$( cd "$probe" && bash "$hook_abs" 2>/dev/null | wc -c | tr -d ' ' )
            hook_tokens=$(( hook_chars * 10 / 36 ))
            # The floor first. A hook that fails to run measures 0, which is under every ceiling, so
            # a bound with no floor cannot tell "within budget" from "produced nothing".
            #
            # The floor is zero and not a size. This validator runs against arbitrary repositories
            # and against fixtures whose hooks legitimately emit one short line, so any positive
            # floor rejects a valid hook. Zero output is the one length that always means failure.
            if [ "$hook_chars" -eq 0 ]; then
                report "hooks/session-start produced no output for response_style=$rs explain_level=$el. It failed to run, and a size check with no floor would have counted that as comfortably within budget."
            elif [ "$hook_chars" -gt 1285 ]; then
                # Characters, and checked before the token bounds below, because NFR-01 is written
                # in characters and this is the number a person can count. The token estimate is
                # derived from it and rounds in a way that surprises: 1285*10/36 truncates to 356,
                # which is not over 356, so the token bound alone first fails at 1286. Stating the
                # limit twice in two units is deliberate, and the character one fails first so the
                # message names the unit the requirement uses.
                report "hooks/session-start injects $hook_chars characters for response_style=$rs explain_level=$el, over the 1285 of NFR-01 in docs/prd/plain-language-chat.md. Take words out, or re-measure and move the requirement deliberately."
            elif [ "$hook_tokens" -gt 400 ]; then
                report "hooks/session-start injects about $hook_tokens tokens for response_style=$rs explain_level=$el, over the 400 ceiling. It is in every request of every session."
            elif [ "$hook_tokens" -gt 356 ]; then
                report "hooks/session-start injects about $hook_tokens tokens for response_style=$rs explain_level=$el, over the 356 rule in docs/prd/plain-language-chat.md NFR-01. The 44 tokens below the 400 ceiling are spoken for."
            fi
        done
        rm -rf "$probe"
    else
        report "cannot create a temporary directory to size hooks/session-start"
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
        grep -qF -- "$needed" <<<"$section10" \
          || report "$snapshot_tpl section 10 does not require '$needed'. A snapshot that names neither what it skipped nor who does it reads as a clean bill of health."
    done
fi
# Scoped to step 6, for the reason the block above is scoped to section 10. A whole-file grep here
# would keep passing if the phrase migrated into Common mistakes and step 6 stopped requiring
# anything, while the message still claimed to be about step 6.
if [ -f skills/repo-snapshot/SKILL.md ]; then
    step6="$(awk '/^## Step 6/{f=1} f&&/^## [A-Z]/&&!/^## Step 6/{f=0} f' skills/repo-snapshot/SKILL.md)"
    grep -qF -- 'did not check' <<<"$step6" \
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
# yield `nest` as a sixteenth language and this rule would demand a tool row for NestJS. Checked
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
    grep -qF -- 'tool-choices.md' <<<"$snapshot_s10" \
      || report "skills/repo-snapshot/references/section-templates.md section 10 does not cite tool-choices.md, so a gap gets a skill but no tool."
fi

# The reference page is generated, so the only way it goes wrong is by not being regenerated. This
# compares the page against the schema and nothing else: the set-by column needs a real profile and
# is checked in tests/test-keel.sh, because this validator runs on every commit and must stay fast.
#
# NO BACKTICK AND NO APOSTROPHE IN THE HEREDOC BELOW. bash 3.2 does not treat a quoted heredoc body
# as literal inside a $( ), so either character breaks the parse of this whole file, and shellcheck
# does not see it. Same trap lib/detect-stack.sh records above its own heredoc. \x60 is a backtick.
if [ -f docs/profile-keys.md ] && [ -f templates/profile.schema.json ] && command -v python3 >/dev/null 2>&1; then
    stale="$(python3 - <<'PYK'
import json, re
schema = json.load(open("templates/profile.schema.json"))
def declared(node, p=""):
    out = {}
    for k, v in (node.get("properties") or {}).items():
        path = "%s.%s" % (p, k) if p else k
        if isinstance(v, dict) and v.get("properties"):
            out.update(declared(v, path))
        else:
            out[path] = (v.get("description") or "").strip()
    return out
want = declared(schema)
page = open("docs/profile-keys.md").read()
got = {}
row = re.compile("^\\| \x60([^\x60]+)\x60 \\| [^|]* \\| [^|]* \\| (.*) \\|$", re.M)
for m in row.finditer(page):
    got[m.group(1)] = m.group(2).replace("\\|", "|")
problems = []
problems += ["no row for %s" % k for k in sorted(set(want) - set(got))]
problems += ["a row for %s, which the schema does not declare" % k for k in sorted(set(got) - set(want))]
problems += ["a stale description for %s" % k
             for k in sorted(set(want) & set(got))
             if got[k] != (want[k] or "_No description yet._")]
print("; ".join(problems))
PYK
)"
    [ -z "$stale" ] \
      || report "docs/profile-keys.md disagrees with templates/profile.schema.json: $stale. Regenerate it with tests/generate-profile-keys.sh > docs/profile-keys.md"
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
    # A key with no description is a key a reader cannot act on, and the generated reference has a
    # blank cell where its answer should be. 35 of 59 were empty on 2026-08-18.
    bare="$(python3 - <<'PYB'
import json
d = json.load(open("templates/profile.schema.json"))
def walk(node, p=""):
    out = []
    for k, v in (node.get("properties") or {}).items():
        path = "%s.%s" % (p, k) if p else k
        if isinstance(v, dict) and v.get("properties"):
            out += walk(v, path)
        elif not (v.get("description") or "").strip():
            out.append(path)
    return out
print(" ".join(walk(d)))
PYB
)"
    [ -z "$bare" ] \
      || report "templates/profile.schema.json has keys with no description: $bare. Every key a user may set has to say what it does; the generated reference shows a blank cell otherwise."

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
