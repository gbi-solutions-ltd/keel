<!--
This file is the template for the block `keel init` merges into a project's CLAUDE.md
and AGENTS.md. Content between the markers is owned by keel and replaced on upgrade.
Content outside the markers belongs to the project and is never touched.

Placeholders in {{BRACES}} are filled from .keel/profile.json at init time:

  {{DOCS_ROOT}}        profile.docs_root, default "docs/keel"
  {{VERIFY_TEST}}      profile.verify.test
  {{VERIFY_LINT}}      profile.verify.lint
  {{VERIFY_TYPECHECK}} profile.verify.typecheck

Never hardcode a docs path here. A project may set docs_root elsewhere, and a rendered
block pointing at the wrong directory sends every session to files that do not exist.
`keel doctor` fails on a literal "docs/keel" in this file.

A verify command that is null in the profile is omitted from the rendered block rather
than rendered as the word "null".

Budget: 450 tokens. This sits in every request, so every line must earn its place.
Check with `keel doctor` before changing it.
-->

<!-- keel:start v1 -->
## Engineering standard

This project uses keel. Skills carry the process; these rules apply to every task.

**Before coding.** State assumptions. Give both readings of an ambiguous request, not one
silently. Name any simpler approach. Stop on anything unclear, naming it.

**While coding.** Write the minimum: nothing unasked for, no abstraction for one use, no error
handling for impossible states; if 200 lines could be 50, write 50. Touch only what the task
requires, never adjacent code, in the existing style not yours.

**Verifying.** Turn the task into checkable goals: "add validation" becomes "tests for invalid
input that then pass". Test first, watching it fail. Lint after each file edit, not at the end;
with no lint command, say so and run the nearest check. Before claiming done, run these and say
which you skipped:

```
{{VERIFY_TEST}}
{{VERIFY_LINT}}
{{VERIFY_TYPECHECK}}
```

Docs are part of the gate: a change lands with the documents it makes wrong, each stating what is
true now.

**Where things live.** `.keel/profile.json` holds project facts, verify commands and gates;
everything else is under `{{DOCS_ROOT}}/`. Read what you need.

**Picking a skill.** Before substantive work, including clarifying questions, invoke a keel skill,
saying which and why in one line; `{{DOCS_ROOT}}/prompting.md` maps triggers. Process skills lead,
implementation follows. User instructions override any skill; where a plugin competes, keel wins
and only its skills write these artifacts.
<!-- keel:end -->
