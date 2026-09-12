#!/usr/bin/env bash
# Tests for validate-skills.sh.
#
# validate-skills.sh is a real program with real logic, so it gets tests proving it catches what
# it claims to catch. A validator that silently passes everything is worse than no validator.
#
# Each case builds a throwaway skill tree in a temp dir, runs the validator against it, and
# asserts on the exit code. Run from the repo root.

# Single quotes are deliberate throughout: these printf strings must emit literal backticks,
# literal {{DOCS_ROOT}}, and literal docs/keel for the validator to find them.
# shellcheck disable=SC2016

set -uo pipefail

VALIDATOR="$(cd "$(dirname "$0")/.." && pwd)/tests/validate-skills.sh"
pass=0
fail=0

# Build a minimal valid skill tree in $1
fixture_valid() {
    local root="$1"
    mkdir -p "$root/skills/example/references"
    cat > "$root/skills/example/SKILL.md" <<'SKILL'
---
name: example
description: Use when a test needs a valid skill to exist.
allowed-tools: [Read]
---

# Example

## Overview

A body short enough to pass the budget and containing no forbidden constructs.

See [references/thing.md](references/thing.md) for detail.
SKILL
    echo "# Thing" > "$root/skills/example/references/thing.md"
    mkdir -p "$root/templates"
    echo "Uses {{DOCS_ROOT}}/snapshot.md" > "$root/templates/a-template.md"
}

check() {
    local name="$1" expected="$2" root="$3"
    ( cd "$root" && "$VALIDATOR" >/dev/null 2>&1 )
    local actual=$?
    if [ "$actual" -eq "$expected" ]; then
        printf '  PASS  %s\n' "$name"; pass=$((pass+1))
    else
        printf '  FAIL  %s (expected exit %s, got %s)\n' "$name" "$expected" "$actual"; fail=$((fail+1))
    fi
}

run() {
    local name="$1" expected="$2" mutate="$3"
    local root; root="$(mktemp -d)"
    fixture_valid "$root"
    "$mutate" "$root"
    check "$name" "$expected" "$root"
    rm -rf "$root"
}

noop() { :; }

# A valid tree passes.
run "valid skill tree passes" 0 noop

# Frontmatter
m_no_name() { sed -i.bak '/^name:/d' "$1/skills/example/SKILL.md"; }
run "missing name is rejected" 1 m_no_name

m_no_desc() { sed -i.bak '/^description:/d' "$1/skills/example/SKILL.md"; }
run "missing description is rejected" 1 m_no_desc

m_bad_desc() { sed -i.bak 's/^description:.*/description: Writes a thing and then does another thing./' "$1/skills/example/SKILL.md"; }
run "description not starting with Use when is rejected" 1 m_bad_desc

# The ceiling had no test at all, which is how it sat at 260 chars (~72 tokens) while doc 05's
# documented ceiling was 60 tokens. Every description could exceed the budget the check existed to
# enforce, and pass. Now 216 chars, and pinned in both directions.
m_desc_at_ceiling() {
    local d; d="Use when $(head -c 200 < /dev/zero | tr '\0' 'x')"   # 209 chars, inside 216
    sed -i.bak "s/^description:.*/description: $d/" "$1/skills/example/SKILL.md"
}
run "a description just inside the ceiling is allowed" 0 m_desc_at_ceiling

m_desc_over_ceiling() {
    local d; d="Use when $(head -c 260 < /dev/zero | tr '\0' 'x')"
    sed -i.bak "s/^description:.*/description: $d/" "$1/skills/example/SKILL.md"
}
run "a description over the ceiling is rejected" 1 m_desc_over_ceiling

# Budget. Per ADR-0001 the ceiling is 900 and 700 is a warning, so exit code alone no longer says
# whether the check fired: a body at 800 must be visible and must not fail. These assert on output.
check_out() {
    local name="$1" expected="$2" root="$3" pattern="$4" want="$5"
    local out actual ok=1
    out="$( cd "$root" && "$VALIDATOR" 2>&1 )"
    actual=$?
    [ "$actual" -eq "$expected" ] || ok=0
    if printf '%s' "$out" | grep -q "$pattern"; then
        [ "$want" = yes ] || ok=0
    else
        [ "$want" = no ] || ok=0
    fi
    if [ "$ok" -eq 1 ]; then
        printf '  PASS  %s\n' "$name"; pass=$((pass+1))
    else
        printf '  FAIL  %s (expected exit %s, got %s; output: %s)\n' \
          "$name" "$expected" "$actual" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-140)"
        fail=$((fail+1))
    fi
}

run_out() {
    local name="$1" expected="$2" mutate="$3" pattern="$4" want="$5"
    local root; root="$(mktemp -d)"
    fixture_valid "$root"
    "$mutate" "$root"
    check_out "$name" "$expected" "$root" "$pattern" "$want"
    rm -rf "$root"
}

pad() { local n="$1" f="$2"; local i; for i in $(seq 1 "$n"); do printf 'word%s ' "$i" >> "$f"; done; }

m_over_ceiling() { pad 950 "$1/skills/example/SKILL.md"; }
run "body over the 900 word ceiling is rejected" 1 m_over_ceiling

# The case the ADR turns on. Before it, this body was simply illegal; after it, it is legal and
# must still be visible, because a ceiling with no warning below it is what bodies migrate to.
m_over_target() { pad 750 "$1/skills/example/SKILL.md"; }
run_out "body between 700 and 900 warns" 0 m_over_target "over the 700 target" yes

# And the warning must not fire on a body inside the target, or it carries no information.
run_out "body inside the target is not warned about" 0 noop "over the 700 target" no

# A body close to the ceiling says how close, because "over the 700 target" reads the same at 750 and
# at 897 and only one of those is a body where the next edit fails the suite. write-plan sat at 897,
# three words of headroom, and nothing said so until someone tried to add a sentence. The number has
# to reach whoever is about to edit the file, and the moment they run the suite is when that is.
m_near_ceiling() { pad 870 "$1/skills/example/SKILL.md"; }
run_out "a body near the ceiling reports its headroom" 0 m_near_ceiling "from the 900 ceiling" yes

# It must stay quiet on a body that is over target with room to work, or every warned skill carries a
# number that means nothing and the ones that matter stop standing out.
run_out "a body with room to work does not report headroom" 0 m_over_target "from the 900 ceiling" no

# Forbidden constructs
m_at_link() { printf '\nSee @references/thing.md for detail.\n' >> "$1/skills/example/SKILL.md"; }
run "@ link is rejected" 1 m_at_link

m_hardcoded_path() { printf '\nWrites to `docs/keel/prd/x.md`.\n' >> "$1/skills/example/SKILL.md"; }
run "hardcoded docs path in a skill is rejected" 1 m_hardcoded_path

m_placeholder_in_skill() { printf '\nWrites to `{{DOCS_ROOT}}/x.md`.\n' >> "$1/skills/example/SKILL.md"; }
run "render placeholder in a skill is rejected" 1 m_placeholder_in_skill

m_hardcoded_in_template() { printf '\nAlso docs/keel/standards.md\n' >> "$1/templates/a-template.md"; }
run "hardcoded docs path in a template is rejected" 1 m_hardcoded_in_template

m_em_dash() { printf '\nA sentence with an em dash \xe2\x80\x94 which is banned.\n' >> "$1/skills/example/SKILL.md"; }
run "em dash is rejected" 1 m_em_dash

m_en_dash() { printf '\nA range 1\xe2\x80\x933 using an en dash.\n' >> "$1/skills/example/SKILL.md"; }
run "en dash is rejected" 1 m_en_dash

# Links
m_broken_link() { rm "$1/skills/example/references/thing.md"; }
run "broken relative link is rejected" 1 m_broken_link

# A link inside a reference, resolved relative to that reference rather than to the skill. Added
# when the index of topic references moved out of the coding-standards body into house-defaults.md to
# stay inside the word budget: ten links, in the one file whose entire job is routing a reader to
# the right topic, and nothing checked any of them. A dead link there does not error, it silently
# drops a whole standard.
m_ref_broken_link() {
    printf '\nSee [sibling.md](sibling.md) for detail.\n' >> "$1/skills/example/references/thing.md"
}
run "a broken link inside a reference is rejected" 1 m_ref_broken_link

m_ref_good_link() {
    printf '\nSee [sibling.md](sibling.md) for detail.\n' >> "$1/skills/example/references/thing.md"
    echo "# Sibling" > "$1/skills/example/references/sibling.md"
}
run "a resolving link inside a reference is allowed" 0 m_ref_good_link

# Things that must NOT be rejected. These are the false positives found while building the
# skills, each of which a naive check flagged.
m_mentions_default() { printf '\nThe default docs root is `docs/keel`, named here as prose.\n' >> "$1/skills/example/SKILL.md"; }
run "a bare mention of the default docs root is allowed" 0 m_mentions_default

m_template_comment() { printf '\n<!-- substitutes {{DOCS_ROOT}}, default "docs/keel" -->\n' >> "$1/templates/a-template.md"; }
run "a template comment naming the default is allowed" 0 m_template_comment

# The router must route only to skills that exist. A route to a deleted skill is a dead end the
# model follows confidently.
m_router_ok() {
    mkdir -p "$1/skills/keel"
    cat > "$1/skills/keel/SKILL.md" <<'R'
---
name: keel
description: Use when routing a request to the right skill.
---

# keel

| Sounds like | Invoke |
|---|---|
| a valid destination | `example` |
R
}
run "router pointing at an existing skill is allowed" 0 m_router_ok

m_router_dangling() {
    m_router_ok "$1"
    printf '| something else | `no-such-skill` |\n' >> "$1/skills/keel/SKILL.md"
}
run "router pointing at a missing skill is rejected" 1 m_router_dangling

# The router and the shipped cheatsheet are the same table twice: one the model reads, one the user
# reads. Nothing checked they agreed, and they had already drifted. `incident-response` was routable
# by the model and absent from the document that ships into every project, so a user would never
# learn to ask for it. A skill nobody is told about is indistinguishable from one that does not
# exist.
m_cheatsheet_agrees() {
    m_router_ok "$1"
    printf '# Prompting\n\n| Say | Invoke | Output |\n|---|---|---|\n| "do it" | `example` | a thing |\n' \
      > "$1/templates/prompting-cheatsheet.md"
}
run "a route the cheatsheet also lists is allowed" 0 m_cheatsheet_agrees

m_cheatsheet_missing() {
    m_router_ok "$1"
    printf '# Prompting\n\nNo table here at all.\n' > "$1/templates/prompting-cheatsheet.md"
}
run "a route missing from the shipped cheatsheet is rejected" 1 m_cheatsheet_missing

# The SessionStart injection is the only routing map a session has before loading anything, and it is
# in the prefix of every request. Three skills had gone missing from it, including incident-response,
# which is the one that most needs to fire without the user naming it.
hook_stub() {
    mkdir -p "$1/hooks"
    printf '#!/usr/bin/env bash\nprintf %%s "%s"\n' "$2" > "$1/hooks/session-start"
    chmod +x "$1/hooks/session-start"
}

m_hook_names_all() { hook_stub "$1" 'Pick a skill: example.'; }
run "an injection naming every skill is allowed" 0 m_hook_names_all

m_hook_missing_skill() { hook_stub "$1" 'Pick a skill: something else entirely.'; }
run "a skill missing from the session-start injection is rejected" 1 m_hook_missing_skill

# Budget, per doc 05: 250 target, 400 hard. The ceiling is what fails a build.
m_hook_oversized() {
    local filler; filler="$(head -c 2000 < /dev/zero | tr '\0' 'x')"
    hook_stub "$1" "Pick a skill: example. $filler"
}
run "an oversized session-start injection is rejected" 1 m_hook_oversized

# The sum of the descriptions, which is the always-loaded cost that scales with the skill count.
# Every description is in the prefix of every request in every keel project, and until now only the
# individual ones were bounded: at 24 skills all sitting legally at 216 chars the total would be
# 1,440 tokens against today's 1,066, a 35 percent rise with no skill added and nothing to say so.
#
# Each filler carries a 216-char description, the per-skill ceiling, which is 60 tokens at the
# chars/3.6 estimate used throughout. The fixture's own `example` contributes 12. So 22 fillers is
# 1,332 and over, 21 is 1,272 and inside, and one more maximum-width skill is what flips it.
add_skills() {
    local root="$1" n="$2" desc i
    desc="Use when $(head -c 207 < /dev/zero | tr '\0' 'x')"
    for i in $(seq 1 "$n"); do
        mkdir -p "$root/skills/filler$i"
        printf -- '---\nname: filler%s\ndescription: %s\n---\n\n# Filler %s\n\nA body.\n' \
          "$i" "$desc" "$i" > "$root/skills/filler$i/SKILL.md"
    done
}

# Asserted on the message, not on the exit code alone. Every filler carries a description at exactly
# DESC_MAX_CHARS, so if that per-skill ceiling is ever lowered, all 22 would fail the per-skill check
# and this case would still exit 1 and stay green with the total check broken or deleted outright.
m_descs_over_total() { add_skills "$1" 22; }
run_out "descriptions totalling over the ceiling are rejected" 1 m_descs_over_total \
  "total about 1332 tokens, over the 1320 ceiling" yes

# One maximum-width skill below the ceiling, and it must pass. This pins the boundary from the other
# side: a ceiling set even one skill too low fails here rather than being discovered by someone whose
# legitimate new skill will not land.
m_descs_under_total() { add_skills "$1" 21; }
run_out "descriptions totalling just inside the ceiling are allowed" 0 m_descs_under_total \
  "descriptions about 1272 tokens" yes

# The total is reported whether or not it is near the ceiling. This is the number task 7.5 was
# written about: it was uncapped and also unstated, so nobody could see it move.
run_out "the descriptions total is reported on a clean run" 0 noop "descriptions about" yes

# Link resolution is already covered above. These three cover the shapes it got wrong or had never
# seen, found while adding `references/preconditions.md` to execute-plan and checking the link by
# hand: an anchor, a path into a sibling skill, and an external URL.

# An anchor is part of the link and not part of the path. `references/x.md#a-heading` names a file
# that exists, and rejecting it made the check stricter than correct output, which is the failure
# this repository's own standards warn about: a check that rejects correct work teaches people to
# ignore checks. This was a real defect, not a hypothetical.
m_link_anchor() {
    sed -i.bak 's|(references/thing.md)|(references/thing.md#a-heading)|' "$1/skills/example/SKILL.md"
}
run "a link carrying an anchor still resolves" 0 m_link_anchor

# Links out of the skill directory are normal: skills point at ../keel/references/ for the shared
# conventions. Those must be resolved relative to the skill, not to the repository root.
m_link_parent() {
    mkdir -p "$1/skills/keel/references"
    echo "# Shared" > "$1/skills/keel/references/shared.md"
    printf '\nSee [../keel/references/shared.md](../keel/references/shared.md).\n' \
      >> "$1/skills/example/SKILL.md"
}
run "a link into a sibling skill resolves" 0 m_link_parent

m_link_parent_missing() {
    printf '\nSee [../keel/references/absent.md](../keel/references/absent.md).\n' \
      >> "$1/skills/example/SKILL.md"
}
run "a link into a sibling skill that does not exist is rejected" 1 m_link_parent_missing

# An external link has nothing on disk to resolve and must not be treated as a broken path.
m_link_external() {
    printf '\nSee [the spec](https://example.com/spec.md).\n' >> "$1/skills/example/SKILL.md"
}
run "an external link is not treated as a path" 0 m_link_external

# The plan template's Done when marker. Checked only when the template exists, the same way the
# session-start rules are, so a fixture without write-plan is not failed for lacking a file it was
# never going to have.
m_plan_template_no_marker() {
    mkdir -p "$1/skills/write-plan/references"
    printf '# Plan template\n\n**Interfaces:**\n\n- [ ] **Step 1**\n' \
      > "$1/skills/write-plan/references/plan-template.md"
}
run "a plan template with no Done when marker is rejected" 1 m_plan_template_no_marker

m_plan_template_marker() {
    mkdir -p "$1/skills/write-plan/references"
    printf '# Plan template\n\n**Done when:** `npm test` passes.\n\n- [ ] **Step 1**\n' \
      > "$1/skills/write-plan/references/plan-template.md"
}
run "a plan template carrying the marker passes" 0 m_plan_template_marker

# A dispatch that names no model at all inherits whatever the driver is paying for, silently, and
# the output looks like output either way. That is why the rule exists. What it accepts changed on
# 2026-09-06: ADR-0005 removed the vendor vocabulary rather than adding to it, because sonnet, opus,
# haiku and fable are Anthropic model names and mean nothing on a second harness. A body names a
# delegation profile now, and each harness resolves that to its own model.
#
# THE SECOND CASE USED TO ASSERT THAT `model `sonnet`` PASSES. That was the old rule written down as
# a test, and a rule change that leaves its own fixture behind is a rule the next person reverts
# while believing the suite. Both directions are still pinned, in both vocabularies.
m_model_alias_vendor() {
    printf '\nDispatch these agents with model `sonnet`.\n' >> "$1/skills/example/SKILL.md"
}
run "a vendor model alias is rejected" 1 m_model_alias_vendor

m_model_alias_invented() {
    printf '\nDispatch these agents with model `sonnet-4-turbo`.\n' >> "$1/skills/example/SKILL.md"
}
run "an invented model alias is rejected too" 1 m_model_alias_invented

# `inherit` survives the removal, and it is not the neutral replacement for the four: it says the
# driver's model, which is the deliberate pin on judgement work and the opposite of what a fan-out
# wants.
m_model_inherit() {
    printf '\nDispatch these agents with model `inherit`, and say so in one line.\n' \
      >> "$1/skills/example/SKILL.md"
}
run "model inherit still passes" 0 m_model_inherit

m_delegation_profile() {
    printf '\nDispatch these agents, delegation profile `keel-fanout`, and say so in one line.\n' \
      >> "$1/skills/example/SKILL.md"
}
run "a delegation profile satisfies the dispatch rule" 0 m_delegation_profile

# The alias rule and the dispatch rule are separate, and until this case existed only one of them
# was actually pinned: every fixture that carried a vendor alias also failed the dispatch rule, so
# putting `sonnet` back on the accepted list left the suite green. This body satisfies the dispatch
# rule and still names an alias, which only the alias rule can catch.
m_alias_beside_profile() {
    printf '\nDispatch these agents, delegation profile `keel-fanout`, and say so in one line.\n' \
      >> "$1/skills/example/SKILL.md"
    printf '\nA later paragraph naming model `sonnet` is still a vendor alias.\n' \
      >> "$1/skills/example/SKILL.md"
}
run "a vendor alias is rejected even beside a valid profile" 1 m_alias_beside_profile

# A language keel detects with no row in the tool table is a gap the snapshot will improvise on,
# differently each time. The table is only trustworthy while it covers what detection produces.
#
# The fixture builds lib/ and both skills itself: fixture_valid creates neither, and the rule is
# guarded on their existence, so without this the cases would pass by skipping the rule entirely.
tool_table_fixture() {
    local root="$1" langs="$2"
    mkdir -p "$root/lib" "$root/skills/keel/references" "$root/skills/repo-snapshot/references"
    printf 'detect_languages() {\n    local out=""\n%s    printf "%%s\\n" "$out"\n}\n' \
      "$langs" > "$root/lib/detect-stack.sh"
    printf '# Tool choices\n\n| Language | Pick |\n|---|---|\n| `typescript` | Vitest |\n' \
      > "$root/skills/keel/references/tool-choices.md"
    printf '## 10. Recommendations\n\nSee [../../keel/references/tool-choices.md](../../keel/references/tool-choices.md).\nsecurity-audit --full, coding-standards, did not check.\n\n## 11. Proposed profile\n' \
      > "$root/skills/repo-snapshot/references/section-templates.md"
}

m_tools_covered()  { tool_table_fixture "$1" '    out="$out typescript"
'; }
run "a tool table covering every detected language passes" 0 m_tools_covered

m_tools_missing()  { tool_table_fixture "$1" '    out="$out typescript"
    out="$out go"
'; }
run "a detected language missing from the tool table is rejected" 1 m_tools_missing

# A rule that reads no languages passes while checking nothing, which is how the section-10 grep and
# the spawn-count assertions both went quiet. Found in review: the extraction is coupled to one
# spelling of the accumulator, so a rename inside detect_languages would disable the rule silently.
m_tools_no_langs() { tool_table_fixture "$1" '    out+=" typescript"
'; }
run "a tool rule that reads no languages is rejected" 1 m_tools_no_langs

# ---- documentation obeys the writing rules too -----------------------------
#
# Everything above covers skills/, templates/ and output-styles/. Every plan, ADR, idea record,
# runbook and root document was exempt from the rules it is written under, which is latent while two
# people write them and stops being latent the moment anyone else does.
#
# Two of these cases are must-not-rejects, and they are the point. Both were measured against the
# real tree before the rule was written, and a naive version rejected correct documents.
m_docs_em_dash() {
    mkdir -p "$1/docs/plans"
    printf '# Plan\n\nA %s dash in a plan.\n' "$(printf '\xe2\x80\x94')" > "$1/docs/plans/p.md"
}
run "an em dash in a plan is rejected" 1 m_docs_em_dash

m_root_md_en_dash() {
    printf '# Notes\n\nA %s dash at the repo root.\n' "$(printf '\xe2\x80\x93')" > "$1/NOTES.md"
}
run "an en dash in a root document is rejected" 1 m_root_md_en_dash

m_docs_broken_link() {
    mkdir -p "$1/docs/runbooks"
    printf '# Runbook\n\nSee [the thing](missing-thing.md).\n' > "$1/docs/runbooks/r.md"
}
run "a broken link in a runbook is rejected" 1 m_docs_broken_link

# MUST NOT REJECT. A plan quotes the markdown it is telling someone to write, links included, inside
# fenced blocks. Measured: a check that does not strip fences rejects
# docs/plans/2026-08-17-release-readiness.md nine times, twice on `sed` patterns that are not links.
m_docs_link_in_fence() {
    mkdir -p "$1/docs/plans"
    { printf '# Plan\n\nWrite this into another file:\n\n'
      printf '```markdown\n[the thing](../../elsewhere/thing.md)\n```\n'
    } > "$1/docs/plans/p.md"
}
run "a quoted link inside a fenced block is allowed" 0 m_docs_link_in_fence

# MUST NOT REJECT. A plan quotes an assertion and the assertion carries a link pattern, so the
# pattern sits in an inline code span. A span renders as code, which means it is not a link, and
# resolving one is the same too-strict failure as resolving a fenced block. Measured: with the
# strip the docs loop extracts no target at all from
# docs/plans/2026-09-02-the-four-mode-router-and-audit.md, and without it one per link-shaped
# pattern that plan quotes, each to a file it never named as one. The number of them is left
# unwritten on purpose: it grows every time the plan quotes another pattern, and it already has.
#
# Both delimiter lengths are in the one fixture because one clause was not enough. Against a
# double-backtick span a single-delimiter strip matches the empty run between the two opening
# backticks and the empty run between the two closing ones, deletes both, and leaves the contents
# standing as a link. A fixture carrying only the single form passes over the bug that shipped.
m_docs_link_in_span() {
    mkdir -p "$1/docs/plans"
    { printf '# Plan\n\nAssert this: `[the thing](../../elsewhere/one.md)` in the single form,\n'
      printf 'and ``[the thing](../../elsewhere/two.md)`` in the double form.\n'
    } > "$1/docs/plans/p.md"
}
run "a link quoted inside an inline code span is allowed" 0 m_docs_link_in_span

# MUST REJECT. The link text is a code span and the target is a real relative path outside it. This
# is the shape at skills/write-prd/references/questionnaire.md:15, whose own target is an anchor
# that the ^(https?:|#) filter drops with or without the strip, so it proves nothing; this fixture
# uses that shape against a path instead. The strip removes the text and the target is still
# extracted and still resolved. That is the one shape the strip provably cannot blind the checker
# to; it is not a general guarantee, and the two shapes that defeat it, escaped backticks and a
# span wrapped across two lines, are named in the comment above the docs loop in
# validate-skills.sh.
#
# A SECOND SPAN SITS AFTER THE LINK, and it is load bearing. With only the one span this case
# tolerates the obvious greedy widening s/BACKTICK.*BACKTICK//g, because that mutant deletes the
# link text and leaves the target standing, so the case still rejects and passes over the bug. With
# a span on each side of the link the mutant swallows the link too, nothing is extracted, and the
# case fails. Verified both ways.
m_docs_broken_link_span_text() {
    mkdir -p "$1/docs/plans"
    printf '# Plan\n\nSee [`the thing`](missing-thing.md) for `detail`.\n' > "$1/docs/plans/p.md"
}
run "a broken link whose text is a code span is rejected" 1 m_docs_broken_link_span_text

# MUST NOT REJECT. Skills must write <docs_root>, but a document explaining the default layout has to
# name it. Measured: this rule fires on five correct documents, including the one that defines the
# layout, so it does not carry over to documentation.
m_docs_names_default_root() {
    mkdir -p "$1/docs"
    printf '# Design\n\nArtifacts default to `docs/keel/snapshot.md` unless `profile.docs_root` says otherwise.\n' \
      > "$1/docs/d.md"
}
run "a document naming the default docs root is allowed" 0 m_docs_names_default_root

# The citation is the other half: a table nothing points at is a table nobody reads.
m_tools_uncited()  {
    tool_table_fixture "$1" '    out="$out typescript"
'
    printf '## 10. Recommendations\n\nsecurity-audit --full, coding-standards, did not check.\n\n## 11. Proposed profile\n' \
      > "$1/skills/repo-snapshot/references/section-templates.md"
}
run "section 10 not citing the tool table is rejected" 1 m_tools_uncited

# The shipped style is shipped text, so it obeys the same content rules as skills and templates. It
# was not covered when output-styles/ was added, which is how a directory acquires its own quietly
# different standard.
m_style_em_dash() {
    mkdir -p "$1/output-styles"
    printf -- '---\nname: t\ndescription: d\nkeep-coding-instructions: true\n---\n\nA %s dash.\n' \
      "$(printf '\xe2\x80\x94')" > "$1/output-styles/t.md"
}
run "an em dash in an output style is rejected" 1 m_style_em_dash

m_style_no_keep_coding() {
    mkdir -p "$1/output-styles"
    printf -- '---\nname: t\ndescription: d\n---\n\nBody.\n' > "$1/output-styles/t.md"
}
run "an output style without keep-coding-instructions is rejected" 1 m_style_no_keep_coding

m_style_valid() {
    mkdir -p "$1/output-styles"
    printf -- '---\nname: t\ndescription: d\nkeep-coding-instructions: true\n---\n\nBody.\n' \
      > "$1/output-styles/t.md"
}
run "a valid output style passes" 0 m_style_valid

# The rule this guards: a field added to the profile schema without SCHEMA_VERSION moving is a
# release that silently expects a field nobody's profile has. Decision 11's lesson, applied to the
# schema: the thing nobody witnessed is the thing that needs a mechanical check.
#
# There is no fixture-based positive case on purpose. A fixture whose fingerprint matched would have
# to hard-code the real repository's field set, which is the thing under test. The positive case is
# the repository's own validate-skills.sh run staying green, which CI asserts.
# Each case writes a bin/keel too. Without one the validator cannot read a SCHEMA_VERSION and every
# case lands in the "no fingerprint recorded" branch, so a test named for the mismatch would pass
# without ever reaching it.
m_schema_drift() {
    mkdir -p "$1/templates" "$1/bin"
    printf 'SCHEMA_VERSION=1\n' > "$1/bin/keel"
    cat > "$1/templates/profile.schema.json" <<'JSON'
{ "properties": { "a_field_nobody_declared": { "type": "string" } } }
JSON
}
run_out "a profile schema whose fields do not match the fingerprint is rejected" 1 m_schema_drift "changed its field set" yes

# The other branch: a SCHEMA_VERSION nobody has recorded a fingerprint for, which is what a bump
# without a new line looks like.
m_schema_unknown_version() {
    mkdir -p "$1/templates" "$1/bin"
    printf 'SCHEMA_VERSION=99\n' > "$1/bin/keel"
    cat > "$1/templates/profile.schema.json" <<'JSON'
{ "properties": { "a_field_nobody_declared": { "type": "string" } } }
JSON
}
run_out "a schema version with no recorded fingerprint is rejected" 1 m_schema_unknown_version "records no fingerprint" yes

# The phrase form for a marker. The ten unread: markers cite their own row in a table of 22
# contiguous rows, so an insertion above them retargets a citation onto a neighbouring key's row and
# nothing goes red. A line number into bin/keel is worse: 47 lines landed in it in one commit on the
# branch that added these cases, moving 32 citations that had been correct. A phrase is what the
# grammar was missing.
m_readby_phrase_ok() {
    mkdir -p "$1/templates" "$1/bin"
    # "reads key a" is here for the leaf check below, not the phrase check this fixture exists for:
    # the marker's phrase is still exactly SCHEMA_VERSION=1, on the same line.
    printf 'reads key a via SCHEMA_VERSION=1\n' > "$1/bin/keel"
    cat > "$1/templates/profile.schema.json" <<'JSON'
{ "properties": { "a": { "description": "d", "x-keel-read-by": "code:bin/keel#SCHEMA_VERSION=1" } } }
JSON
}
run_out "a marker citing a phrase that is in the file is accepted" 1 m_readby_phrase_ok "x-keel-read-by" no

m_readby_phrase_gone() {
    mkdir -p "$1/templates" "$1/bin"
    printf 'SCHEMA_VERSION=1\n' > "$1/bin/keel"
    cat > "$1/templates/profile.schema.json" <<'JSON'
{ "properties": { "a": { "description": "d", "x-keel-read-by": "code:bin/keel#SCHEMA_VERSION=9" } } }
JSON
}
run_out "a marker citing a phrase that is not in the file is rejected" 1 m_readby_phrase_gone "x-keel-read-by" yes

# A phrase carrying a pipe would break the markdown table docs/profile-keys.md renders it into, and
# the generator has no way to say which marker did it.
m_readby_phrase_pipe() {
    mkdir -p "$1/templates" "$1/bin"
    printf 'SCHEMA_VERSION=1\n' > "$1/bin/keel"
    cat > "$1/templates/profile.schema.json" <<'JSON'
{ "properties": { "a": { "description": "d", "x-keel-read-by": "code:bin/keel#SCHEMA|VERSION" } } }
JSON
}
run_out "a marker phrase containing a pipe is rejected" 1 m_readby_phrase_pipe "x-keel-read-by" yes

# The fifth value. A key nothing is written to read, that a model was measured reading anyway.
# gates.coding_standards is the first user: tests/evals/results.md records an arm reading it out of
# the profile and setting severity by it with nothing telling it to, while the marker said unread:.
# Its citation names the record that measured it, so the claim is checkable rather than remembered.
m_readby_observed() {
    mkdir -p "$1/templates" "$1/bin" "$1/tests/evals"
    printf 'SCHEMA_VERSION=1\n' > "$1/bin/keel"
    printf '# Results\n\nAn arm read the key and acted on it anyway.\n' > "$1/tests/evals/results.md"
    cat > "$1/templates/profile.schema.json" <<'JSON'
{ "properties": { "a": { "description": "d", "x-keel-read-by": "observed:tests/evals/results.md#read the key and acted on it anyway" } } }
JSON
}
run_out "an observed: marker citing the record that measured it is accepted" 1 m_readby_observed "x-keel-read-by" no

# observed: names a record, so it names a document. A path into code would be code:.
m_readby_observed_code() {
    mkdir -p "$1/templates" "$1/bin"
    printf 'SCHEMA_VERSION=1\n' > "$1/bin/keel"
    cat > "$1/templates/profile.schema.json" <<'JSON'
{ "properties": { "a": { "description": "d", "x-keel-read-by": "observed:bin/keel#SCHEMA_VERSION=1" } } }
JSON
}
run_out "an observed: marker naming a file that is not a record is rejected" 1 m_readby_observed_code "x-keel-read-by" yes

# The check is guarded on the file existing, like every other repository-only check in the
# validator, because the fixture roots these tests run in have no templates/profile.schema.json.
run_out "no profile schema present means the fingerprint check stays quiet" 0 noop "fingerprint" no

# A key bin/keel says schema 4 retired, still declared in the schema. The register in bin/keel is
# what doctor reads to tell a person their profile carries a dead key, and a register naming a key
# that is still live tells them to remove one that still works. Nothing else can catch it: the
# fingerprint above is a hash of the field set, so it sees that the set changed and never which way.
m_retired_key_still_declared() {
    mkdir -p "$1/templates" "$1/bin"
    cat > "$1/bin/keel" <<'KEEL'
SCHEMA_VERSION=1
retired_keys() {
    cat <<RETIRED
gates.tdd|4|it does nothing now.
RETIRED
}
KEEL
    cat > "$1/templates/profile.schema.json" <<'JSON'
{ "properties": { "gates": { "properties": { "tdd": { "type": "string" } } } } }
JSON
}
run_out "a key listed as retired that the schema still declares is rejected" 1 \
    m_retired_key_still_declared "retired" yes

# And the register stays quiet when it agrees with the schema, or every commit reports it.
m_retired_key_absent() {
    mkdir -p "$1/templates" "$1/bin"
    cat > "$1/bin/keel" <<'KEEL'
SCHEMA_VERSION=1
retired_keys() {
    cat <<RETIRED
gates.tdd|4|it does nothing now.
RETIRED
}
KEEL
    cat > "$1/templates/profile.schema.json" <<'JSON'
{ "properties": { "gates": { "properties": { "coding_standards": { "type": "string" } } } } }
JSON
}
run_out "a register that agrees with the schema says nothing" 1 \
    m_retired_key_absent "retired" no

# Every key the example template sets is declared in the schema, or a project that copies the
# example sets a key that does nothing. conventions.branch_prefix was exactly this, pre-existing
# and undetected: in the example, in neither schema revision, read by nothing.
m_example_key_undeclared() {
    mkdir -p "$1/templates"
    cat > "$1/templates/profile.schema.json" <<'JSON'
{ "properties": { "conventions": { "type": "object", "additionalProperties": true,
  "properties": { "default_branch": { "type": "string" } } } } }
JSON
    cat > "$1/templates/keel-profile.example.json" <<'JSON'
{ "conventions": { "default_branch": "main", "branch_prefix": "feat/" } }
JSON
}
run_out "an example key the schema does not declare is rejected" 1 \
    m_example_key_undeclared "does not declare" yes

# And the check stays quiet on an example that only sets declared keys, including the two
# legitimate escapes: _note under an object that allows one, and a key under a field the schema
# itself declares as an open map (verify_notes).
m_example_keys_all_declared() {
    mkdir -p "$1/templates"
    cat > "$1/templates/profile.schema.json" <<'JSON'
{ "properties": {
    "conventions": { "type": "object", "additionalProperties": true,
      "properties": { "default_branch": { "type": "string" } } },
    "verify_notes": { "type": "object", "additionalProperties": { "type": "string" } },
    "observability": { "type": "object", "additionalProperties": true,
      "properties": { "backend": { "type": "string" } } }
  } }
JSON
    cat > "$1/templates/keel-profile.example.json" <<'JSON'
{ "$schema": "irrelevant",
  "conventions": { "default_branch": "main" },
  "verify_notes": { "test_one": "why it is what it is" },
  "observability": { "backend": "signoz", "_note": "backend is one of ..." } }
JSON
}
run_out "an example whose keys are all declared, or _note, or under an open map, says nothing" 1 \
    m_example_keys_all_declared "does not declare" no

# The floor: an example that parses to nothing checked would otherwise pass silently, the same
# failure mode the reader rule above guards against with its own "read no keys at all" line.
m_example_empty() {
    mkdir -p "$1/templates"
    cat > "$1/templates/profile.schema.json" <<'JSON'
{ "properties": { "keel_version": { "type": "string" } } }
JSON
    printf '{}\n' > "$1/templates/keel-profile.example.json"
}
run_out "an empty example template reports rather than passing silently" 1 \
    m_example_empty "checking nothing" yes

# The size check ran the hook once, from the repository root, so it measured whichever form the
# local profile selects and nothing else. A paragraph that fits terse and technical while breaking
# verbose and plain would have shipped green. This fixture is what says otherwise: its hook is small
# for every combination except verbose plus plain.
m_hook_one_combo_oversized() {
    mkdir -p "$1/hooks"
    cat > "$1/hooks/session-start" <<'HOOK'
#!/usr/bin/env bash
# Names the fixture's skill, example, so the only finding this case can produce is the size one.
set -euo pipefail
text="short"
profile="$(cat .keel/profile.json 2>/dev/null || true)"
case "$profile" in
    *'"response_style": "verbose"'*)
        case "$profile" in
            *'"explain_level": "plain"'*) text="$(head -c 1500 /dev/zero | tr '\0' 'x')" ;;
        esac ;;
esac
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$text"
HOOK
    chmod +x "$1/hooks/session-start"
}
run_out "a combination over the ceiling is reported, not just the local one" 1 \
    m_hook_one_combo_oversized "response_style=verbose explain_level=plain" yes

# A hook that does not run measures 0 characters, which is 0 tokens, which is under every ceiling.
# The size check would report nothing and the run would go green with the hook broken. That is the
# failure tests/test-session-start.sh already carries a floor for, with a comment saying a bound
# with no floor cannot tell "unchanged" from "produced nothing". This block had four such
# measurements and no floor. Caught in review.
m_hook_produces_nothing() {
    mkdir -p "$1/hooks"
    cat > "$1/hooks/session-start" <<'HOOK'
#!/usr/bin/env bash
# Names the fixture's skill, example, so the only finding this case can produce is the size one.
exit 1
HOOK
    chmod +x "$1/hooks/session-start"
}
run_out "a hook that produces nothing is reported, not counted as small" 1 \
    m_hook_produces_nothing "produced no output" yes

# The rule is guarded on both files existing, so the fixture has to build them or the case passes
# by checking nothing. Same reason tool_table_fixture exists a few rules above.
profile_keys_fixture() {
    local root="$1" page_rows="$2"
    mkdir -p "$root/docs" "$root/templates"
    printf '{"properties":{"a":{"type":"string","description":"A.","x-keel-read-by":"human"},"b":{"type":"string","description":"B.","x-keel-read-by":"human"}}}\n' \
      > "$root/templates/profile.schema.json"
    { printf '# Profile keys\n\ngenerate-profile-keys.sh\n\n'
      printf '| Key | Type | Set by | Read by | Description |\n|---|---|---|---|---|\n'
      printf '%s' "$page_rows"
    } > "$root/docs/profile-keys.md"
}

# Exit code cannot isolate this rule. Declaring a schema in a fixture also activates the fingerprint
# rule, which reads SCHEMA_VERSION from a bin/keel a small fixture has no reason to carry, so the
# validator exits 1 whatever the reference says. Three of these four cases would then have passed
# while asserting nothing. Assert on the message instead, which is what actually distinguishes the
# rule firing from the rule staying quiet.
check_reports() {   # check_reports <name> <yes|no> <needle> <mutate-fn>
    local name="$1" want="$2" needle="$3" mutate="$4"
    local root; root="$(mktemp -d)"
    fixture_valid "$root"
    "$mutate" "$root"
    local out; out="$( cd "$root" && "$VALIDATOR" 2>&1 )"
    rm -rf "$root"
    local saw=no
    case "$out" in *"$needle"*) saw=yes ;; esac
    if [ "$saw" = "$want" ]; then
        printf '  PASS  %s\n' "$name"; pass=$((pass+1))
    else
        printf '  FAIL  %s (wanted saw=%s, got saw=%s)\n' "$name" "$want" "$saw"; fail=$((fail+1))
    fi
}

m_keys_ok()      { profile_keys_fixture "$1" '| `a` | string | `keel init` | a person | A. |
| `b` | string | **you** | a person | B. |
'; }
check_reports "a reference matching the schema is not reported" no "profile-keys.md disagrees" m_keys_ok

m_keys_missing() { profile_keys_fixture "$1" '| `a` | string | `keel init` | a person | A. |
'; }
check_reports "a key absent from the reference is reported" yes "no row for b" m_keys_missing

m_keys_stale()   { profile_keys_fixture "$1" '| `a` | string | `keel init` | a person | Something else entirely. |
| `b` | string | **you** | a person | B. |
'; }
check_reports "a stale description is reported" yes "a stale description for a" m_keys_stale

m_keys_extra()   { profile_keys_fixture "$1" '| `a` | string | `keel init` | a person | A. |
| `b` | string | **you** | a person | B. |
| `c` | string | **you** | a person | Not in the schema. |
'; }
check_reports "a row the schema does not declare is reported" yes "which the schema does not declare" m_keys_extra


# ---- every declared profile key says what reads it ------------------------
#
# 22 of 61 keys were read by nothing on 2026-09-07 and CHANGELOG.md recorded seven. This rule is
# what stops that recurring. Asserted on the message and not the exit code, for the reason stated
# above profile_keys_fixture: a fixture that declares a schema trips the fingerprint rule too.
readby_fixture() {   # readby_fixture <root> <json-value-for-x-keel-read-by> <read-by-cell>
    local root="$1" entry="$2" cell="$3"
    mkdir -p "$root/templates" "$root/docs" "$root/bin"
    printf 'a real line a citation can point at\n' > "$root/bin/reader"
    printf '{"properties":{"a":{"type":"string","description":"A.","x-keel-read-by":%s}}}\n' "$entry" \
      > "$root/templates/profile.schema.json"
    { printf '# Profile keys\n\ngenerate-profile-keys.sh\n\n'
      printf '| Key | Type | Set by | Read by | Description |\n|---|---|---|---|---|\n'
      printf '| `a` | string | **you** | %s | A. |\n' "$cell"
    } > "$root/docs/profile-keys.md"
}

m_readby_code()   { readby_fixture "$1" '"code:bin/reader:1"' '`bin/reader:1`'; }
check_reports "a key naming a reader that exists is not reported" no \
  "x-keel-read-by" m_readby_code

m_readby_human()  { readby_fixture "$1" '"human"' 'a person'; }
check_reports "a key declared human-read is not reported" no \
  "x-keel-read-by" m_readby_human

# THE MUST-NOT-REJECT CASE FOR generic:, and it needs its own fixture rather than reusing
# readby_fixture.
#
# Six of the 55 real keys, all six artifacts.*, ride on a genuine parent-map read: cmd_doctor's
# `d=json.load(...).get('artifacts',{})` iterates a Python dict, so the loop variable is `k`, and
# no line anywhere near the citation contains the individual key's own name,
# `stories` or `snapshot` or any of the other five. code:'s leaf check below would reject every one
# of them and be right to: the citation is real but the individual key genuinely cannot be pointed
# at. generic: is the escape built for exactly this, and it is the only marker form the leaf check
# does not run against.
#
# THIS IS NOT THE SAME SHAPE as verify.lint, verify.typecheck, verify.build, verify.e2e,
# verify.security and verify.format, which also ride on a shared loop. Those loops
# (`for k in test lint typecheck build`, `for k in e2e security`, `for k in format lint typecheck`)
# enumerate literal barewords, so the leaf sits one line above the citation and code:'s ordinary
# leaf-in-window check passes them without help; converting them to generic: too would hide a real
# drift the same way the case below is built to reject. Only a read through actual dynamic data,
# where the key name is nowhere in the source, needs generic:.
#
# A fixture reusing readby_fixture cannot show this: its schema is flat, so there is no parent, and
# bin/reader contains neither a leaf name nor a parent name to withhold. This one is nested and its
# reader line names the parent only, so it is what the leaf check would wrongly reject as code: and
# is what generic: exists to carry instead. It is also the only case in this file that exercises the
# recursive branch of the walk, which builds the dotted path artifacts.stories from two levels.
m_readby_parent() {
    local root="$1"
    mkdir -p "$root/templates" "$root/docs" "$root/bin"
    printf 'for k in prof["artifacts"]:\n' > "$root/bin/reader"
    printf '%s\n' '{"properties":{"artifacts":{"type":"object","properties":{"stories":{"type":"string","description":"S.","x-keel-read-by":"generic:bin/reader:1"}}}}}' \
      > "$root/templates/profile.schema.json"
    { printf '# Profile keys\n\ngenerate-profile-keys.sh\n\n'
      printf '| Key | Type | Set by | Read by | Description |\n|---|---|---|---|---|\n'
      printf '| `artifacts.stories` | string | **you** | `bin/reader:1` | S. |\n'
    } > "$root/docs/profile-keys.md"
}
check_reports "a key covered only by a parent-map read, declared generic:, is not reported" no \
  "x-keel-read-by" m_readby_parent

# generic: still gets the base resolution checks, only not the leaf check: a markdown file is
# rejected the same way code: rejects one, because generic: also names executing code, not prose.
m_readby_generic_md() {
    local root="$1"
    mkdir -p "$root/templates" "$root/docs" "$root/bin"
    printf 'irrelevant\n' > "$root/bin/reader.md"
    printf '%s\n' '{"properties":{"a":{"type":"string","description":"A.","x-keel-read-by":"generic:bin/reader.md:1"}}}' \
      > "$root/templates/profile.schema.json"
    { printf '# Profile keys\n\ngenerate-profile-keys.sh\n\n'
      printf '| Key | Type | Set by | Read by | Description |\n|---|---|---|---|---|\n'
    } > "$root/docs/profile-keys.md"
}
check_reports "generic: naming a markdown file is reported" yes \
  "not generic:" m_readby_generic_md

# generic: naming a file that does not exist fails the same floor code: does.
m_readby_generic_gone() {
    local root="$1"
    mkdir -p "$root/templates" "$root/docs"
    printf '%s\n' '{"properties":{"a":{"type":"string","description":"A.","x-keel-read-by":"generic:bin/nosuchreader:1"}}}' \
      > "$root/templates/profile.schema.json"
    { printf '# Profile keys\n\ngenerate-profile-keys.sh\n\n'
      printf '| Key | Type | Set by | Read by | Description |\n|---|---|---|---|---|\n'
    } > "$root/docs/profile-keys.md"
}
check_reports "generic: naming a file that does not exist is reported" yes \
  "that file does not exist" m_readby_generic_gone

# ---- code: markers must name their key, in a small window, or declare generic: instead ----
#
# project.kind's real marker was found citing a phrase with no relation to any reader of the key,
# and the rule that checks citations resolve had no way to see it: the phrase resolved, so the rule
# was satisfied, and nobody but a person reading both sides caught the mismatch. This is the check
# that would have caught it on its own, without demanding every parent-map read carry a lie instead:
# the key's own leaf name must appear on the cited line or within the three lines above it.
#
# Three above and not zero, because a jq read three lines above the marker's own line is a
# legitimate reader and must not fail; the fixture below pins that directly. Leaf and not the full
# dotted path, because a single-purpose read of a nested key almost never repeats the parent segment
# (hooks/session-start:111 reads "response_style", not "conventions.response_style"), and demanding
# the parent too would reject every real single-purpose citation in this tree bar none.
m_readby_code_leaf_present() {
    local root="$1"
    mkdir -p "$root/templates" "$root/docs" "$root/bin"
    printf 'v = prof.get("widgets")\n' > "$root/bin/reader"
    printf '%s\n' '{"properties":{"widgets":{"type":"string","description":"W.","x-keel-read-by":"code:bin/reader:1"}}}' \
      > "$root/templates/profile.schema.json"
    { printf '# Profile keys\n\ngenerate-profile-keys.sh\n\n'
      printf '| Key | Type | Set by | Read by | Description |\n|---|---|---|---|---|\n'
    } > "$root/docs/profile-keys.md"
}
check_reports "a code: marker whose cited line names the key is not reported" no \
  "the three above it" m_readby_code_leaf_present

# THE MUST-NOT-BREAK CASE, named directly in the task that asked for this rule.
m_readby_code_leaf_three_above() {
    local root="$1"
    mkdir -p "$root/templates" "$root/docs" "$root/bin"
    printf 'widgets are read a few lines up from here\nfiller line two\nfiller line three\nv = jq(prof)\n' \
      > "$root/bin/reader"
    printf '%s\n' '{"properties":{"widgets":{"type":"string","description":"W.","x-keel-read-by":"code:bin/reader:4"}}}' \
      > "$root/templates/profile.schema.json"
    { printf '# Profile keys\n\ngenerate-profile-keys.sh\n\n'
      printf '| Key | Type | Set by | Read by | Description |\n|---|---|---|---|---|\n'
    } > "$root/docs/profile-keys.md"
}
check_reports "a code: marker whose leaf sits three lines above the citation is not reported" no \
  "the three above it" m_readby_code_leaf_three_above

# One line further out than the case above, to prove the window has an edge and is not accidentally
# unbounded.
m_readby_code_leaf_four_above() {
    local root="$1"
    mkdir -p "$root/templates" "$root/docs" "$root/bin"
    printf 'widgets are read here\nfiller line two\nfiller line three\nfiller line four\nv = jq(prof)\n' \
      > "$root/bin/reader"
    printf '%s\n' '{"properties":{"widgets":{"type":"string","description":"W.","x-keel-read-by":"code:bin/reader:5"}}}' \
      > "$root/templates/profile.schema.json"
    { printf '# Profile keys\n\ngenerate-profile-keys.sh\n\n'
      printf '| Key | Type | Set by | Read by | Description |\n|---|---|---|---|---|\n'
    } > "$root/docs/profile-keys.md"
}
check_reports "a code: marker whose leaf sits four lines above the citation is reported" yes \
  "the three above it" m_readby_code_leaf_four_above

# THE DEFECT THIS RULE EXISTS FOR. project.kind's real marker was exactly this shape: a phrase that
# resolves to a real line in bin/keel, naming neither project.kind nor kind, unrelated to any of its
# readers. A citation that resolves and still names nothing this key owns is not a legitimate
# parent-map read, which is what generic: is for and this fixture is not declaring; it is a wrong
# citation, and this is the shape that should be rejected rather than waved through.
m_readby_code_no_leaf() {
    local root="$1"
    mkdir -p "$root/templates" "$root/docs" "$root/bin"
    printf 'echo service\n' > "$root/bin/reader"
    printf '%s\n' '{"properties":{"widgets":{"type":"string","description":"W.","x-keel-read-by":"code:bin/reader:1"}}}' \
      > "$root/templates/profile.schema.json"
    { printf '# Profile keys\n\ngenerate-profile-keys.sh\n\n'
      printf '| Key | Type | Set by | Read by | Description |\n|---|---|---|---|---|\n'
    } > "$root/docs/profile-keys.md"
}
check_reports "a code: marker whose citation names nothing of the key is reported" yes \
  "the three above it" m_readby_code_no_leaf

# A phrase repeating in its target file is legal by design (the comment above the phrase branch
# says so, and tests/validate-citations.sh gives the same ruling): rejecting a phrase that occurs
# twice is stricter than correct output. The leaf check has to honour that too, not just the
# existence check. This fixture's phrase resolves at line 1, with no leaf nearby, and again at
# line 5, where the leaf sits on the cited line itself; a leaf check anchored only to the first
# occurrence would reject a real citation for a reason that is really about a different, unrelated
# line sharing its text.
m_readby_code_leaf_second_occurrence() {
    local root="$1"
    mkdir -p "$root/templates" "$root/docs" "$root/bin"
    printf 'irrelevant marker text\nfiller line two\nfiller line three\nfiller line four\nirrelevant marker text naming widgets\n' \
      > "$root/bin/reader"
    printf '%s\n' '{"properties":{"widgets":{"type":"string","description":"W.","x-keel-read-by":"code:bin/reader#irrelevant marker text"}}}' \
      > "$root/templates/profile.schema.json"
    { printf '# Profile keys\n\ngenerate-profile-keys.sh\n\n'
      printf '| Key | Type | Set by | Read by | Description |\n|---|---|---|---|---|\n'
    } > "$root/docs/profile-keys.md"
}
check_reports "a code: marker whose phrase repeats, with the leaf near the second, is not reported" no \
  "the three above it" m_readby_code_leaf_second_occurrence

m_readby_absent() {
    local root="$1"
    mkdir -p "$root/templates" "$root/docs"
    printf '{"properties":{"a":{"type":"string","description":"A."}}}\n' \
      > "$root/templates/profile.schema.json"
    { printf '# Profile keys\n\ngenerate-profile-keys.sh\n\n'
      printf '| Key | Type | Set by | Read by | Description |\n|---|---|---|---|---|\n'
      printf '| `a` | string | **you** | _undeclared_ | A. |\n'
    } > "$root/docs/profile-keys.md"
}
check_reports "a key that declares no reader is reported" yes \
  "a declares no x-keel-read-by" m_readby_absent

m_readby_stale()  { readby_fixture "$1" '"code:bin/reader:99"' '`bin/reader:99`'; }
check_reports "a key naming a line its reader does not have is reported" yes \
  "that file has 1 lines" m_readby_stale

m_readby_gone()   { readby_fixture "$1" '"code:bin/nosuchreader:1"' '`bin/nosuchreader:1`'; }
check_reports "a key naming a file that does not exist is reported" yes \
  "that file does not exist" m_readby_gone

m_readby_bad_type() { readby_fixture "$1" '7' 'a person'; }
check_reports "a marker that is not a string or a list is reported" yes \
  "not a string or a list of strings" m_readby_bad_type

# THE RC BACKSTOP KEEPS A CASE, and it can no longer be a marker. Before the type guard, 7 and true
# reached the backstop by crashing the entry loop, and this suite pinned it there. The guard now
# catches every marker shape ahead of the loop, which is the point of it, so a marker case pins the
# guard and nothing pins the backstop. That is the half-asserted clause this task exists to remove.
# A property whose value is not an object crashes the schema walk itself, before any marker is
# looked at, so it is what a genuine last resort now looks like: the rule stopped, and the operator
# is told it stopped rather than being told nothing.
m_readby_walk_crashes() {
    local root="$1"
    mkdir -p "$root/templates" "$root/docs"
    printf '%s\n' '{"properties":{"a":"not an object"}}' > "$root/templates/profile.schema.json"
    { printf '# Profile keys\n\ngenerate-profile-keys.sh\n\n'
      printf '| Key | Type | Set by | Read by | Description |\n|---|---|---|---|---|\n'
    } > "$root/docs/profile-keys.md"
}
check_reports "a schema that stops the rule mid-run is reported, not read as quiet" yes \
  "could not run to completion" m_readby_walk_crashes

# THE TYPED CASE, and it is not a duplicate of the one above. 7 and true crash the entry loop and
# land on the rc backstop; 0 and false do not, they are falsy, so `if not entries` reported them as
# "has an empty x-keel-read-by", which is the wrong diagnosis for the wrong-type fault. The two
# cases together hold the guard and the backstop apart: this one must name the type, and the one
# above must still reach the rc capture.
m_readby_zero_marker() { readby_fixture "$1" '0' 'a person'; }
check_reports "a marker of 0 is reported as the wrong type, not as empty" yes \
  "not a string or a list of strings" m_readby_zero_marker

m_readby_zero()  { readby_fixture "$1" '"code:bin/reader:0"' '`bin/reader:0`'; }
check_reports "a marker citing line zero is reported" yes \
  "line numbers start at 1" m_readby_zero

m_readby_advisory_code() { readby_fixture "$1" '"code:bin/reader.md:1"' '`bin/reader.md:1`'; }
check_reports "code: naming a markdown file is reported" yes \
  "Prose nothing asserts is advisory" m_readby_advisory_code

# BOTH DIRECTIONS OF THE FILE-TYPE CLAUSE ARE PINNED, and this is the half that was missing. With
# only the code:-naming-markdown case above, deleting the advisory: half of the clause in
# tests/validate-skills.sh left this whole suite green, so the clause was half unasserted: exactly
# the "an assertion that cannot distinguish quiet from broken is not an assertion" failure the
# comments in that rule condemn, thirty lines away from where it happened.
m_readby_advisory_nonmd() { readby_fixture "$1" '"advisory:bin/reader:1"' '`bin/reader:1`'; }
check_reports "advisory: naming a file that is not markdown is reported" yes \
  "which is not a markdown file" m_readby_advisory_nonmd

# THE FLOOR. A schema with no properties yields no keys, so the rule checks nothing and would pass
# everything. Copied from the tool-table floor at `tests/validate-skills.sh#rule rather than break it. Found in review, before it happened.`, pinned at
# tests/test-validate-skills.sh:425, and deliberately NOT from the delegation floor at
# `tests/validate-skills.sh#Ten pairs on 2026-09-02`, which is pinned in neither direction.
m_readby_no_keys() {
    local root="$1"
    mkdir -p "$root/templates" "$root/docs"
    printf '{"definitions":{"a":{"type":"string"}}}\n' > "$root/templates/profile.schema.json"
    { printf '# Profile keys\n\ngenerate-profile-keys.sh\n\n'
      printf '| Key | Type | Set by | Read by | Description |\n|---|---|---|---|---|\n'
    } > "$root/docs/profile-keys.md"
}
check_reports "a reader rule that extracts no keys is reported" yes \
  "read no keys at all" m_readby_no_keys


# ---- the documented-delegation rule, and the pipeline race that made it lie ------------------
#
# On 2026-09-04 CI went red on main with six delegation failures against a tree that had passed the
# identical check on the pull request minutes earlier, and passes it on a developer machine. The
# rule read the skill body through `body_of file | grep -q`, under `set -o pipefail`. grep -q exits
# at the first match; the producer then dies on its next write, and pipefail turns its 141 into a
# failed pipeline, so a match that was found is reported as a body that never names the plugin.
# The four skills it accused all had bodies over one stdio block with the match in the first block,
# and the two it let through had bodies under a block, so the producer had finished before grep
# left. Timing decided it, which is why the same commit passed and failed.
#
# The fixture makes the race certain rather than likely: the mention is on the first line of the
# body and is followed by more filler than a pipe will hold, so the producer is still blocked on a
# write when grep matches and leaves. Under the old pipeline this case fails every run.
#
# SEVEN FILLER ROWS, ALWAYS NAMED. This fixture builds one delegation pair, which is one short of
# the floor tests/validate-skills.sh#Ten pairs on 2026-09-02 sets at 8: every run of the two cases
# below tripped that floor and printed its message, which neither case looks for or asserts against.
# The filler rows always name a plugin the skill body always names, regardless of the `mention`
# argument, so they clear the floor without engaging the row-level assertion the two cases exist to
# test.
delegation_fixture() {   # delegation_fixture <root> <body-mentions-plugin: yes|no>
    local root="$1" mention="$2" i
    mkdir -p "$root/docs"
    { printf '# Plugins\n\n'
      printf '| keel skill | Plugin it calls | What it delegates |\n'
      printf '|---|---|---|\n'
      printf '| `example` | `some-plugin` | A thing |\n'
      for i in 1 2 3 4 5 6 7; do
          printf '| `example` | `filler-plugin-%s` | Filler |\n' "$i"
      done
    } > "$root/docs/04-plugin-strategy.md"
    { printf -- '---\nname: example\ndescription: Use when a test needs a valid skill to exist.\n---\n\n'
      for i in 1 2 3 4 5 6 7; do
          printf 'Delegates to `filler-plugin-%s` when it is installed.\n' "$i"
      done
      [ "$mention" = yes ] && printf 'Delegates to the `some-plugin` plugin when it is installed.\n\n'
      # Larger than any pipe buffer, so the producer cannot finish before the consumer matches.
      head -c 200000 < /dev/zero | tr '\0' 'x' | fold -w 100
    } > "$root/skills/example/SKILL.md"
}

m_delegation_named()   { delegation_fixture "$1" yes; }
check_reports "a delegation named early in a long body is not reported" \
  no "never names it" m_delegation_named

m_delegation_missing() { delegation_fixture "$1" no; }
check_reports "a delegation the body never names is reported" \
  yes "never names it" m_delegation_missing

# THE FLOOR ITSELF, pinned in neither direction until now. A table reformatted past what the awk
# above parses yields zero pairs, which every assertion in the block above passes vacuously, exactly
# the failure mode tests/validate-skills.sh#Ten pairs on 2026-09-02 exists to catch. Copied from the
# reader-rule floor at m_readby_no_keys, tests/test-validate-skills.sh#THE FLOOR.
m_delegation_table_unparseable() {
    mkdir -p "$1/docs"
    printf '# Plugins\n\nThis table has been reformatted and no longer has the header row the parser looks for.\n' \
      > "$1/docs/04-plugin-strategy.md"
}
check_reports "a delegation table reformatted past parsing trips the floor" yes \
  "documented delegations, against 10" m_delegation_table_unparseable

# And the floor stays quiet at 8 documented pairs, or it is not a floor at 8, it is one at whatever
# count the fixtures happen to carry.
m_delegation_healthy() {
    local root="$1" i
    mkdir -p "$root/docs"
    { printf '# Plugins\n\n'
      printf '| keel skill | Plugin it calls | What it delegates |\n'
      printf '|---|---|---|\n'
      for i in 1 2 3 4 5 6 7 8; do
          printf '| `example` | `healthy-plugin-%s` | A thing |\n' "$i"
      done
    } > "$root/docs/04-plugin-strategy.md"
    { printf -- '---\nname: example\ndescription: Use when a test needs a valid skill to exist.\n---\n\n'
      for i in 1 2 3 4 5 6 7 8; do
          printf 'Delegates to `healthy-plugin-%s` when it is installed.\n' "$i"
      done
    } > "$root/skills/example/SKILL.md"
}
check_reports "a delegation table with 8 documented pairs does not trip the floor" no \
  "documented delegations, against 10" m_delegation_healthy

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
