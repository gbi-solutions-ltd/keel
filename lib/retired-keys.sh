#!/usr/bin/env bash
# The retired-key register. Sourced by bin/keel, and by tests/validate-skills.sh and
# tests/test-doc-claims.sh, which run retired_keys to read it. It defines that one function and runs
# nothing, so sourcing it runs no part of keel. Sourced and never run, so it is not executable.
#
# The keys a schema version removed, the version that removed each, and what to do instead. Read by
# cmd_doctor, which is the only thing that can tell a person their profile still carries one.
#
# A register rather than a walk of the schema, because every object in
# templates/profile.schema.json is additionalProperties: true on purpose: a project may carry keys
# of its own, and a rule reporting anything the schema does not declare would warn at people for
# using a documented affordance, and could name no remedy for the keys that do matter.
#
# Append a line here in the same commit that removes a key from the schema. Nothing detects a
# removal you did not record. The fingerprint in tests/validate-skills.sh is a hash of the field
# set, so it proves the set changed and cannot say which way; that validator checks only the other
# direction, that no key named here is still declared in the schema.
retired_keys() {
    cat <<'RETIRED'
gates.tdd|4|skills/tdd/SKILL.md asks for the cycle unconditionally and always did, so removing the key changes nothing.
gates.review|4|skills/ship/SKILL.md runs its review step every time, so a project that set required already had it and one that set off never had the effect it expected.
gates.docs_updated|4|skills/ship/SKILL.md runs its docs step every time, on the same terms as gates.review.
gates.observability|4|nothing was asking, so removing the key changes nothing.
conventions.working_branch|4|record the branch in CONTRIBUTING.md or in notes, where a person will read it.
observability.log_shipping|4|set observability.backend to none for stdout only, which is the distinction the table in skills/coding-standards/references/observability.md keys on.
RETIRED
    # Outside the heredoc, so the line can carry the comment that marks it.
    printf '%s\n' 'harnesses|7|This plugin serves Claude Code only, and Codex support ended at v0.26.0. Delete the key.' # names Codex: the v0.26.0 notice
}
