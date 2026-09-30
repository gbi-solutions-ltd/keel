# Idea: profile validation checks the value shape, not just membership

| | |
|---|---|
| Raised by | The 2026-09-25 plan's task 1 and task 2 execution notes (findings not taken), and `docs/plans/2026-09-26-guard-hooks-outside-the-working-tree.md:1406` ("Not in this plan"), 2026-09-25 and 2026-09-26 |
| Status | agreed, not built. All three open questions answered 2026-09-27 |
| Recommendation | Build all six: the type, additionalProperties and stderr fixes, plus a WARN for a non-gate enum violation, a doctor warning on a null gate, and an enum walk that consults `schema_version` before failing |
| Next | `write-plan`, for all six |

## The problem

`keel profile set`'s and `keel doctor`'s enum checks, added 2026-09-25 to stop a typo in a gate
value being written and silently read as a weaker gate, check only whether a value the schema
constrains with an `enum` appears in that list, so a value with the wrong severity, the wrong
type, an unrecognised key, or one lost to stray interpreter noise still reads as validated or is
never checked at all.

**Evidence.** This repository, `bin/keel` at `06b8ef2..b7c70f9` on branch `sandbox`, unpushed as of
2026-09-26. Task 1's execution note lists three findings not taken (`null` passes on gate keys and
reads as `off`; `type` is not checked; `gates.additionalProperties` keys go unchecked,
`docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md:203-204`). Task 2's
execution note adds a fourth, considered and not taken (a stderr line from python drops the enum
findings, `docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md:395`). The
2026-09-26 guard-hooks plan's "Not in this plan" table names two more as the review's own consider
items, sent to `shape-idea` rather than decided inline: enum FAIL on non-gate keys, and an older
keel against a newer profile (`docs/plans/2026-09-26-guard-hooks-outside-the-working-tree.md:1406`).

## What was asked for

One record for the gaps left in profile validation after tasks 1 and 2 of the 2026-09-25 plan:
(a) doctor FAILs an out-of-enum value on keys outside `gates.` though the FAIL severity's stated
reason, a weaker gate, applies only to gates, and the review suggested WARN there; (b) an older
keel reads its own bundled schema, so it FAILs a profile a newer keel wrote with a newly added enum
value, and its "Fix it with: keel profile set" undoes a teammate's value, the ping-pong the
three-way `schema_version` comparison exists to prevent; (c) `null` passes both checks on gate
keys and reads as a weaker gate; (d) `profile set` checks enums, not types, so it writes the
string "yes" into a boolean key such as `conventions.no_attribution_footers`; (e)
`gates.additionalProperties` keys are not walked; (f) a stderr warning from python counts as a
parse error and drops the enum findings.

## The case against

**Strongest argument for not building this at all.** Every one of these six gaps is a gap in code
that did not exist before 2026-09-25 and that, before this week, validated nothing at all; in each
case the worst outcome the gap produces is exactly the outcome that shipped with every prior
release of keel, not a new hole opened in an existing guarantee. The feature already went through
a dry run, a first attempt discarded on citation grounds, a second attempt, two review passes and
a maintainer-approved follow-up that took the two worst findings (the message's false claim for
non-gate keys, and a silent skip on an unreadable schema) in the same week it shipped. Asking six
more edge cases, several of them genuinely small, to be resolved before the feature is allowed to
stand is holding new validation to a higher bar than the total absence of validation it replaced.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Nothing | (b) and (d) are silent: a teammate's newer-schema value gets overwritten by the tool's own advice, and a boolean key holding a coerced string does the opposite of what was typed, with no FAIL or WARN either time. Cheap to leave, and the two silent ones are exactly the failure mode this feature exists to end |
| Do it manually | A third review pass, by a person | Already tried twice (spec review, quality review, a maintainer-approved follow-up B) and it still left six items each time, because the review's own job was to ship task 1 and 2, not close every edge case in the class |
| Buy it | Not available | No third party validates keel's own schema against keel's own gate semantics |
| Build something smaller | Half a day, no design or ADR needed | The recommendation. See below |

**Variants of building it**

| Variant | Note |
|---|---|
| Fix all six in one task | (a), (b) and (c) are not bugs so much as unresolved trade-offs against a deliberate design choice (which severity a non-gate key deserves, schema leniency, null-clears-a-value); bundling them with the three mechanical fixes risks the same citation-repair churn a rushed first attempt already hit on this file once |
| Fix nothing until a formal profile-schema validator replaces the hand-rolled walk | Speculative, and no such validator is proposed or scoped anywhere in the plans or ideas read for this record |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| The three mechanical fixes (d, e, f) do not need a design decision | Each is a narrow code change with an existing test pattern to extend | Read the fix against the existing enum-check tests in `tests/test-keel.sh` | **Checked.** Task 1 and 2 already added the fixture and assertion shape (`profile set enum`, `doctor enum`) these would extend |
| (a), (b) and (c) are genuinely different from (d, e, f) | The review itself grouped these three as judgements it did not make, not as defects | Read `docs/plans/2026-09-26-guard-hooks-outside-the-working-tree.md:1406` and the code comments each trades off against | **Checked.** The guard-hooks plan's row lists "enum FAIL on non-gate keys", "an older keel against a newer profile" and "`null` on gate keys" together as "a separate judgement the maintainer has not made"; `null` is separately documented in code as "the documented way to clear a value" (`bin/keel#documented way to clear a value`), and the enum walk reads `$HERE/templates/profile.schema.json`, this keel's own bundled copy, never the profile's `schema_version` |
| Nobody has since decided (a), (b) or (c) | No later commit or plan addresses any of them | Grep the tree for a later fix | **Checked, 2026-09-26.** All three still stand exactly as the guard-hooks plan's "Not in this plan" table left them |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| Every enum violation is a FAIL, gate key or not; only the message's extra clause is conditioned on the key's first segment | `bin/keel#if "enum" in sub and v is not None and v not in sub["enum"]:` runs `fail()` unconditionally, two lines later, in the loop at `bin/keel#while IFS= read -r enum_line; do` and its dispatch `bin/keel#fail "${enum_line#enum`; the "weaker gate" clause is gated with `bin/keel#gate = ", and for a gate that means a weaker one" if here[0] == "gates" else ""` | The wording fix follow-up B already made (only saying "weaker gate" for `gates.*`) did not touch the severity. `observability.backend: "honeycomb"` or `project.kind: "api"` still FAIL doctor for a reason that no longer applies to them |
| The enum check reads the running keel's own bundled schema, never the profile's `schema_version` | `bin/keel#three-way rather than two` explains the schema_version comparison exists precisely so a stale-vs-fresh disagreement does not make each side overwrite the other; the enum walk loads `$HERE/templates/profile.schema.json` with no reference to `schema_version` at all, and its remedy text reads `bin/keel#keel does not recognise it%s. Fix it "` continuing "with: keel profile set" | An older keel's bundled schema does not contain an enum value a newer keel's schema added. It FAILs that value and its own remedy tells the person to overwrite it, which is the exact ping-pong the three-way comparison was built to prevent, just reached through a different check |
| Both checks explicitly exempt `None` | `bin/keel#if "enum" in sub and v is not None and v not in sub["enum"]:` (doctor) and `bin/keel#if isinstance(s, dict) and "enum" in s and val is not None and val not in s["enum"]:` (profile_set) | `null` on a gate key passes silently on both sides. A hook reading an absent or null gate typically treats it as unenforced, so `gates.done_verified: null` is the same silent weakening the whole feature exists to catch, let through by the same clause that legitimately lets `profile set <key> null` clear a value |
| `profile_set`'s literal coercion only recognises `true`, `false` and `null`; anything else becomes an `int` or the raw string | `bin/keel#elif raw == "false": val = False` and the following `else: try: val = int(raw) except ValueError: val = raw` | `conventions.no_attribution_footers` is declared `"type": "boolean"` (`templates/profile.schema.json:402`) and carries no `enum`, so no enum check ever runs against it. `profile set conventions.no_attribution_footers yes` writes the JSON string `"yes"` |
| The message hook that reads that same key does a literal shell string comparison, not a JSON boolean read | `bin/keel#footers="$(sed -n 's/.*"no_attribution_footers": *\([a-z]*\).*/\1/p' .keel/profile.json 2>/dev/null` then `bin/keel#[ "$footers" = true ] && exit 0` | The sed capture group is `[a-z]*` anchored right after the colon; a quoted string value's opening `"` is not in that class, so it captures empty, `$footers` is `""`, and `[ "" = true ]` is false. Typing "yes" to mean true produces the opposite of a boolean `true`: the trailer keeps getting added, with no FAIL or WARN anywhere |
| Both walks iterate only `s.get("properties")`, never a dict's own `additionalProperties` schema | `bin/keel#Keys under gates.additionalProperties are not walked: a path` (profile_set's comment); doctor's `walk()` is the same shape, iterating `(s.get("properties") or {}).items()` with no `additionalProperties` branch | `gates`'s `additionalProperties` is itself `{"enum": ["required", "warn", "off"]}` (`templates/profile.schema.json:277-281`), so a gate key not named in `properties`, arriving by hand edit or surviving from a pre-schema-4 profile as a retired key, is invisible to both checks even though the schema states what values it should hold |
| doctor's profile parse and enum walk share one `2>&1` capture, and anything not prefixed `enum` or `noschema` (each followed by a pipe character) is treated as a parse error | `bin/keel#grep -v -e '^enum` is the filter that builds `profile_err`, followed by `bin/keel#*JSONDecodeError*) fail "profile is not valid JSON: $profile_err"` | An incidental stderr line python emits for any other reason, a `ResourceWarning` named as the example in the task 2 execution note, lands in `profile_err` too. The run falls into the parse-error branch and returns 1 before the enum and noschema lines already printed are read, so every enum finding for that run is discarded though the profile parsed fine |

## Open questions

1. ~~**Should an out-of-schema-value enum violation on a non-`gates.` key stay a FAIL, or become a
   WARN?**~~ **Answered 2026-09-27 by Bernard, asked as a choice: WARN.** A FAIL stays for `gates.*`
   keys only, where its stated reason, a weaker gate, applies. The review that raised this
   (`docs/plans/2026-09-26-guard-hooks-outside-the-working-tree.md:1406`) left it as a judgement
   for the maintainer rather than deciding it. A WARN matches the stated
   reason for FAIL applying only to gates; keeping FAIL treats "this value is not one recognised
   for any reason" as worth blocking on regardless of consequence. This blocks task (a).
2. ~~**Does a `gates.*` key holding `null` need its own rule, separate from `null` clearing any other
   key?**~~ **Answered 2026-09-27 by Bernard, asked as a choice: yes, doctor warns on a null gate.**
   `null` still clears any key, gates included; what changes is that a null gate is reported rather
   than passing silently. Resolving a null gate to the schema's default was offered and not chosen,
   since it changes what is enforced with no message. The current behaviour is one clause serving two purposes: "let a person clear a field"
   and, as a side effect, "let a gate go unenforced with no signal." Splitting them means gate keys
   treat `null` as equivalent to whatever the schema's default or `off` reads as, rather than as
   silently passing. This blocks task (c) and is the maintainer's call, not a defect with one
   answer.
3. ~~**Is the schema-version mismatch in (b) worth a real fix, or a documentation note that `profile
   set`'s remedy text should not be followed on a WARN-level "your keel is older" doctor line?**~~
   **Answered 2026-09-27 by Bernard, asked as a choice: a real fix.** The enum walk consults
   `schema_version` before failing, accepting that this is the largest of the six. The three-way `schema_version` comparison already tells a person their keel is the older one and
   says explicitly not to run `keel init` to silence it; the enum check's FAIL and remedy text
   contradict that advice on the same profile in the same run, but a full fix means the enum walk
   consulting `schema_version` before failing, which is more code than the other three fixes
   combined.

## Recommendation

**Build something smaller.** Fix (d), (e) and (f) in one small follow-up: add a `type` check for
schema entries that declare one; extend the walk to check a key against a dict's own
`additionalProperties` schema when the key is not in `properties`; and separate doctor's stdout
and stderr so an incidental python warning cannot discard already-printed enum findings. Each is a
narrow change with an existing test shape (`profile set enum`, `doctor enum`) from tasks 1 and 2 to
extend, and none needs a design decision.

This record left (a), (b) and (c) as the three named open questions above, since the review that
raised them grouped all three as judgements it did not make. All three were answered on
2026-09-27: (a) becomes a WARN, (b) gets the real fix, and (c) gets a doctor warning. So the
follow-up builds all six, not three.

What happens next: `write-plan` covers the three mechanical fixes and the three decided ones. No
PRD: this is a defect fix
against a feature that shipped this week, the same basis the two idea records already in
`docs/ideas/` for this schema use.

## Not decided here

The exact wording of a WARN message for a non-gate enum violation. Whether `type` checking should
cover every JSON Schema `type` value or only the ones the profile schema actually uses (`boolean`,
`string`, `integer`). Whether `gates.additionalProperties` should stay shaped as
`additionalProperties: true` or gain named entries over time, which is a schema-authoring
question, not a validation one. The CI `permissions` and hash-pinned-ruff and
unquoted-branch-in-generated-YAML items from the same "Not in this plan" row: those are unrelated
to profile validation and are not part of this record.
