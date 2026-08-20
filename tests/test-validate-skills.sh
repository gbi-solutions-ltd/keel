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

# A brief dispatched to a model alias that does not exist is dispatched to nothing, and the failure
# is silent. Both cases matter: the rule has to accept the aliases that work as much as it rejects
# the ones that do not, or the first correct pin gets reverted.
m_model_alias_unknown() {
    printf '\nDispatch these agents with model `sonnet-4-turbo`.\n' >> "$1/skills/example/SKILL.md"
}
run "an unknown model alias is rejected" 1 m_model_alias_unknown

m_model_alias_known() {
    printf '\nDispatch these agents with model `sonnet`, and say so in one line.\n' \
      >> "$1/skills/example/SKILL.md"
}
run "a known model alias passes" 0 m_model_alias_known

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

# The check is guarded on the file existing, like every other repository-only check in the
# validator, because the fixture roots these tests run in have no templates/profile.schema.json.
run_out "no profile schema present means the fingerprint check stays quiet" 0 noop "fingerprint" no

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
    printf '{"properties":{"a":{"type":"string","description":"A."},"b":{"type":"string","description":"B."}}}\n' \
      > "$root/templates/profile.schema.json"
    { printf '# Profile keys\n\ngenerate-profile-keys.sh\n\n'
      printf '| Key | Type | Set by | Description |\n|---|---|---|---|\n'
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

m_keys_ok()      { profile_keys_fixture "$1" '| `a` | string | `keel init` | A. |
| `b` | string | **you** | B. |
'; }
check_reports "a reference matching the schema is not reported" no "profile-keys.md disagrees" m_keys_ok

m_keys_missing() { profile_keys_fixture "$1" '| `a` | string | `keel init` | A. |
'; }
check_reports "a key absent from the reference is reported" yes "no row for b" m_keys_missing

m_keys_stale()   { profile_keys_fixture "$1" '| `a` | string | `keel init` | Something else entirely. |
| `b` | string | **you** | B. |
'; }
check_reports "a stale description is reported" yes "a stale description for a" m_keys_stale

m_keys_extra()   { profile_keys_fixture "$1" '| `a` | string | `keel init` | A. |
| `b` | string | **you** | B. |
| `c` | string | **you** | Not in the schema. |
'; }
check_reports "a row the schema does not declare is reported" yes "which the schema does not declare" m_keys_extra

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
