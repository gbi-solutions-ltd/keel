#!/usr/bin/env bash
# The Codex CLI writers. Tier B. Same seven functions as lib/harness/claude.sh, and the differences
# between the two files are the whole of what Tier B means in practice.
#
# CODEX HAS NO COMMAND-PATTERN RULE SYNTAX AT ALL, and no ask. Permission profiles are path globs
# and network domains: openai/codex@rust-v0.153.4 codex-rs/protocol/src/permissions.rs:105 defines
# FileSystemAccessMode as Read, Write and Deny, with no ask, prompt or confirm variant. So of keel's
# 26 Claude Code rules, the 5 `Read(./.env)` shaped denies port here and get STRONGER, because a
# path deny also stops `cat`; the 8 `Bash(cat *.env*)` denies become redundant under them; and all
# 13 ask rules have no counterpart.
#
# NOTHING HERE FAKES THE MISSING 13. A rule that looks like a prompt and is not one is the failure
# this whole design exists to prevent, and tests/test-keel.sh fails the build on a `Bash(`, an
# `"ask"` or a `prompt` appearing in what this writes.

# `deny|<path glob>` and `ask|<rule>`, the same shape claude.sh prints, because cmd_init counts both
# kinds to report them and a caller that had to know which harness it was counting would defeat the
# contract. There are no ask rules to print, and printing none is the honest answer rather than an
# omission: harness_permission_rules on Codex returning 5 deny and 0 ask is exactly what the
# capability manifest says, and what the support page reports.
harness_permission_rules() {
    printf 'deny|%s\n' '**/.env' '**/.env.*' '**/secrets/**' '**/*.pem' '**/*.key'
}

# The TOML those rules become. Separate from the rules themselves so the rules stay countable and
# comparable across harnesses, and only this function knows Codex's file format.
# KEEL OWNS ONE TABLE IN THIS FILE AND NOTHING ELSE IN IT. An existing .codex/config.toml is the
# common case on any team already using Codex, and it is exactly the case that most needs the
# denies. It is also the file that OPTS THE REPOSITORY IN: harness_set_for_repo reads a tracked
# .codex/config.toml as the signal that this repository serves Codex, so truncating it destroyed the
# team's model choice, MCP servers and their own permission profiles, on a command documented as
# re-runnable, and took the opt-in signal with it. The Claude writer has branched on an existing
# settings.json since it was written; this one did not, and that asymmetry was the bug.
#
# MARKERS RATHER THAN A TOML PARSE. `#` is a comment in TOML, the markers are the same idiom
# lib/merge-claude-md.sh uses on CLAUDE.md, and they say exactly which lines a person may not edit.
# The whole managed region is replaced rather than merged into, so a rule keel stops writing
# actually leaves; merging into it would mean the region only ever grows.
CODEX_MARK_START='# keel:start v1 - managed by keel init, edits here are overwritten'
CODEX_MARK_END='# keel:end'

harness_write_config() {
    local root="${1:-}" rule block
    mkdir -p .codex/agents
    block="$(
        printf '%s\n' "$CODEX_MARK_START"
        printf '# Path denies only: Codex has no command-pattern rule syntax and no ask, so keel\047s\n'
        printf '# 13 ask rules have no counterpart here and none is faked.\n'
        printf '# See docs/harness-support.md for what this harness does and does not enforce.\n'
        printf '[permissions.keel.filesystem.":workspace_roots"]\n'
        while IFS= read -r rule; do
            printf '"%s" = "deny"\n' "${rule#deny|}"
        done < <(harness_permission_rules | grep '^deny|')
        printf '%s\n' "$CODEX_MARK_END"
    )"
    if [ -f .codex/config.toml ]; then
        # Everything outside the markers is copied through untouched. awk and not sed, because the
        # region is a range and sed's range syntax would need the markers escaped as patterns.
        local kept
        kept="$(awk -v s="$CODEX_MARK_START" -v e="$CODEX_MARK_END" '
            $0 == s { drop = 1; next }
            $0 == e { drop = 0; next }
            !drop   { print }
        ' .codex/config.toml)"
        # The block goes LAST, and that is not cosmetic. A TOML table runs to the next table
        # header, so keel's table placed anywhere but the end would swallow every key written
        # under whatever table followed it. Last, nothing of theirs can fall into it.
        {
            [ -n "${kept//[[:space:]]/}" ] && printf '%s\n\n' "$kept"
            printf '%s\n' "$block"
        } > .codex/config.toml
    else
        printf '%s\n' "$block" > .codex/config.toml
    fi

    # The delegation profile keel's fan-out skills name. Task 15 moves the pin out of skill prose
    # and into here, because "a cheaper, faster model than the driver" cannot be said in a
    # vocabulary of four vendor names plus `inherit`.
    #
    # THE MODEL IS UNMEASURED, stated rather than implied. Chosen 2026-09-06 as the cheapest Codex
    # model in the published list, and NOTHING HAS MEASURED that it clears the fan-out quality bar.
    # docs/ideas/model-routing.md is the standing evidence that a cheaper model can pass every
    # structural check and be wrong twice as often, so this is exactly the choice that cannot be
    # made from a price list. S-19 is the story that measures it; open question 1 of the
    # architecture is where the decision is recorded.
    cat > .codex/agents/keel-fanout.toml <<'AGENT'
name = "keel-fanout"
model = "gpt-5-codex-mini"
model_reasoning_effort = "low"
AGENT
    [ -n "$root" ] || true
}

# Codex has no committed and local split to mirror, so there is nothing to write and nothing to
# git-ignore. Empty rather than absent: the contract is what cmd_init calls, and a missing function
# is an undefined command on somebody's machine.
harness_write_local_config() { :; }

# No Codex marketplace equivalent to keel's recommended set is established, so this recommends
# nothing rather than guessing. A recommendation nobody can act on is noise in `keel doctor`.
harness_recommend_plugins() { :; }

# AGENTS.md is NOT returned here, and that is the point. keel writes AGENTS.md for every repository
# because Cursor, Copilot CLI and Gemini CLI read it too, so cmd_init writes it as neutral ground
# and this harness has no context file of its own to add. Returning AGENTS.md would merge the same
# block into the same file twice.
harness_context_file() { :; }

harness_config_paths() {
    printf 'committed|.codex/config.toml\n'
    printf 'committed|.codex/agents/keel-fanout.toml\n'
}

# Open question 6 of the architecture, and the reason this function is not empty on a harness that
# has no doctor readers of its own.
#
# CODEX RUNS NO HOOK UNTIL ITS SOURCE IS TRUSTED, AND SAYS NOTHING WHEN IT SKIPS ONE. Measured
# 2026-09-06 on codex-cli 0.153.4, twice: first with a throwaway plugin, where three sessions with
# it installed and enabled fired zero hooks and a fourth, identical but for the bypass flag, fired
# both; then with this plugin itself. No warning, no stderr, no `codex doctor` line, and no trust
# entry written by either the install or the run.
#
# THE FAILURE IS NOT "NOTHING WORKS", IT IS WORSE THAN THAT. The real install advertised all 25 keel
# skills into the session and fired no hook, so the skills half of Tier B arrives without trust and
# the gates half does not. An untrusted install therefore looks like most of keel working, which is
# why "keel is installed" is not evidence of anything a gate promises, and why the message below
# says which half a person is looking at rather than only that something is wrong.
#
# WHAT THIS STILL CANNOT DO. The config key is `hooks.state."<id>"`, carried as a literal
# `hooks.state."` prefix in the 0.153.4 binary beside the `enabled` and `trusted_hash` fields, so
# task 11 has what it needs to read it. This says the step exists rather than claiming to have
# checked it, because a doctor line that says "trusted" without having looked is worse than one that
# says nothing.
harness_doctor_findings() {
    case "${1:-}" in
        install)
            printf 'warn|Codex runs no hook until you have trusted the plugin that ships them, and says nothing when it skips one. The skills arrive either way, so an untrusted install looks like most of keel working while every gate is silently dark. keel cannot grant that trust: it lives in your own ~/.codex configuration, not in this repository. Trust keel\047s hooks in Codex before relying on a gate.\n' ;;
        *) : ;;
    esac
}
