#!/usr/bin/env bash
# Refuse to ship anything that could harm the machine that installs this plugin.
#
# keel is not a library somebody chooses to call. Its hooks run automatically at session start,
# its skills are instructions a capable agent follows, and it installs into every repository at GBi.
# A hostile line here executes on every engineer's laptop without anyone invoking anything. That is a
# different risk class from an ordinary bug, so it gets a check of its own rather than a paragraph in
# the review rubric.
#
# The threat this exists for is not primarily an outside attacker. It is a plausible-looking
# contribution: a convenience command pasted from a blog, a hook that "just fetches the latest
# version", an agent instruction that reads a credential to be helpful. Each of those is a supply
# chain compromise regardless of intent, and each looks reasonable in a diff.
#
# Usage:
#   tests/supply-chain-scan.sh                 scan the tree, exit non-zero on any finding
#   tests/supply-chain-scan.sh --list-rules    print every rule id, for the coverage test
#
# LIMITS, stated so nobody mistakes this for a guarantee. It is a denylist over patterns we have
# thought of. It cannot recognise a novel technique, it cannot read intent, and a determined author
# who knows these rules can write around them. It raises the cost of a careless change and catches
# the shapes that actually appear. Review is still the control; this is the floor under it.
#
# SUPPRESSION. A line ending with `supply-chain-scan: allow <reason>` is skipped. Every suppression
# is printed on each run and counted in the summary, so growth is visible in CI output rather than
# discovered later. A suppression with no reason is itself a finding.

# The `condition && report_pass || report_fail` idiom is used throughout. It is safe here, and only
# here, because every reporting helper returns 0 explicitly: see the `return 0` on each below. That
# makes the invariant shellcheck cannot see a stated fact in the code rather than an assumption.
# shellcheck disable=SC2015
set -uo pipefail

errors=0
suppressed=0
report() { printf 'FAIL  %s\n' "$1"; errors=$((errors+1)); return 0; }

# ---- rules -----------------------------------------------------------------
#
# One rule per line: id <TAB> scope <TAB> flags <TAB> extended-regex <TAB> why.
# Tab is the delimiter because a regex will contain `|` and must not need escaping.
#
# Scopes, because a pattern that is hostile in a hook is ordinary prose in a runbook:
#   all     every tracked text file
#   exec    bin/, hooks/, lib/, tests/, .github/workflows/, and anything with the executable bit
#   prompt  skills/ and templates/ markdown, which are instructions an agent will follow
#
# Flags: `i` for case-insensitive, `-` for case-sensitive. The agent-facing rules are insensitive
# because an injected instruction arrives however it was typed, and shouted is the common form. The
# rest stay sensitive so that `POST` does not match "posting", which is everywhere in a payments
# vocabulary.
#
# Portability: no empty alternative anywhere, so write `(bash|zsh|ksh|sh)` and never `(ba|z|k|)sh`.
# The empty form is accepted by GNU grep and rejected outright by others, and the first version of
# this file had two rules that silently matched nothing on a developer machine while passing CI.
# `check_patterns` below now makes that failure loud rather than silent.
#
# Each rule's `why` is the sentence that appears in the failure. A finding nobody understands gets
# suppressed rather than fixed.
rules() {
    cat <<'RULES'
net-pipe-shell	all	-	(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(bash|zsh|ksh|sh)	Piping a download into a shell runs whatever that host serves at the moment it is fetched, which is not what anyone reviewed
decode-exec	all	-	base64[^|]*(-d|-D|--decode)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(bash|zsh|ksh|sh)	Decoding then executing is how a payload avoids being read in a diff
eval-remote	all	-	eval[[:space:]]*["']?[[:space:]]*(\$\(|`)[[:space:]]*(curl|wget|base64|nc )	eval over downloaded or decoded content is arbitrary remote code execution
reverse-shell	all	-	(/dev/tcp/|/dev/udp/|nc[[:space:]]+-[a-z]*e[[:space:]]|bash[[:space:]]+-i[[:space:]]*>&)	The shape of a reverse shell
net-in-script	exec	-	\b(curl|wget|ncat|telnet|scp|sftp)\b	A hook runs unattended at session start. Anything here that reaches the network is an outbound channel nobody authorised at the moment it opens
cred-home-dir	all	-	(~|\$HOME|\$\{HOME\})/\.(ssh|aws|gnupg)/	Reading a developer's private keys. There is no legitimate reason for this plugin to touch them
cred-store	all	-	(\.aws/credentials|\.npmrc|\.docker/config\.json|\.claude/\.credentials|\.netrc)	A credential store, read or written
cred-extract	all	-	(security[[:space:]]+find-(generic|internet)-password|gh[[:space:]]+auth[[:space:]]+token|aws[[:space:]]+configure[[:space:]]+get)	Extracting a live credential from the machine's keychain or CLI
persist-shellrc	all	-	\.(bashrc|zshrc|bash_profile|zshenv|zprofile)\b	Writing a shell startup file survives uninstall and runs on every future terminal
persist-global	all	-	(git[[:space:]]+config[[:space:]]+--global|crontab[[:space:]]+-|launchctl[[:space:]]+(load|bootstrap)|systemctl[[:space:]]+enable)	Changing machine-wide state. This tool's blast radius is the repository it is run in
persist-user-claude	all	-	(~|\$HOME|\$\{HOME\})/\.claude/(settings|CLAUDE\.md)	Rewriting the user's own Claude configuration, which governs every project and not only this one
destructive-root	all	-	rm[[:space:]]+-[a-zA-Z]*[rR][a-zA-Z]*[[:space:]]+["']?(/|~|\$HOME|\$\{HOME\})["'`]?([[:space:]]|$)	Recursive delete rooted at the filesystem root or the home directory
history-wipe	all	-	(history[[:space:]]+-c|unset[[:space:]]+HISTFILE|HISTFILE=/dev/null|shred[[:space:]]+-)	Erasing the record of what ran. Nothing legitimate here needs to
obfuscated-blob	all	-	[A-Za-z0-9+/]{160,}={0,2}	A long opaque literal. Whatever it is, no reviewer read it
hex-escape-blob	all	-	(\\x[0-9a-fA-F]{2}){12,}	A hex-escaped payload, which is unreadable by design
agent-override	prompt	i	(ignore|disregard)[[:space:]]+(all[[:space:]]+)?(previous|prior|earlier|the[[:space:]]+above)[[:space:]]+(instruction|rule|guidance|direction)	A skill telling the agent to discard its instructions is prompt injection shipped as a feature
agent-conceal	prompt	i	(do[[:space:]]+not|do[[:space:]]+n.t|never)[[:space:]]+(tell|inform|notify|show|reveal[[:space:]]+to)[[:space:]]+the[[:space:]]+user	A skill instructing the agent to hide what it did. Every gate in this plugin depends on the user seeing what happened
agent-silent-act	prompt	i	without[[:space:]]+(telling|informing|notifying|asking)[[:space:]]+the[[:space:]]+user	Acting behind the user's back, which is the behaviour every escape hatch in this plugin is designed to prevent
agent-exfil	prompt	-	(exfiltrat|POST.{0,40}(secret|credential|token|\.env))	Sending repository contents or credentials somewhere
RULES
}

# A rule whose regex this grep rejects matches nothing, and the run still reports OK with the rule
# counted in the total. That is the exact failure a denylist is supposed to protect against, so it is
# checked before anything is scanned rather than discovered later by a coverage test on a good day.
check_patterns() {
    local id scope flags pat why rc
    while IFS=$'\t' read -r id scope flags pat why; do
        [ -n "$id" ] || continue
        printf '' | grep -qE "$pat" >/dev/null 2>&1
        rc=$?
        # 0 matched, 1 did not match: both mean the regex compiled. 2 and above is a rejection.
        [ "$rc" -ge 2 ] && report "rule '$id' has a regex this grep rejects, so it matches nothing: $pat"
    done < <(rules)
    return 0
}

# ---- what is allowed to be executable --------------------------------------
#
# A hostile contribution needs something that runs. Either it modifies a file that already runs, which
# a reviewer is looking at closely, or it adds one, which nothing was checking. This closes the second
# route: the set of executables is small, enumerated, and any addition has to be argued for here.
#
# The enumeration is only correct for a plugin repository, so the rule runs only where one is present.
# `keel scan` points this scanner at ordinary projects, and in a service repo with thirty legitimate
# scripts a fixed allowlist would produce thirty findings on the first run, which is how a check
# teaches people to skip it.
allowed_executable() {
    case "$1" in
        bin/keel)            return 0 ;;
        hooks/*)             return 0 ;;
        tests/*.sh)          return 0 ;;   # `*` matches `/` here, so this covers tests/evals/ too
        .githooks/*)         return 0 ;;   # written by `keel guard install`, and scanned like everything else
        .claude/keel-nudge)  return 0 ;;   # written by `keel init`, committed so a plugin-less session is told so
        *)                   return 1 ;;
    esac
}

# This scanner and its tests must contain the patterns in order to test for them.
skip_file() {
    case "$1" in
        tests/supply-chain-scan.sh|tests/test-supply-chain.sh) return 0 ;;
        *) return 1 ;;
    esac
}

in_scope() {  # in_scope <scope> <file>
    case "$1" in
        all) return 0 ;;
        exec)
            case "$2" in
                bin/*|hooks/*|lib/*|tests/*|.github/workflows/*) return 0 ;;
                *) [ -x "$2" ] && return 0 || return 1 ;;
            esac ;;
        prompt)
            case "$2" in
                skills/*.md|templates/*.md) return 0 ;;   # `*` matches `/`, so nested references are covered
                *) return 1 ;;
            esac ;;
    esac
    return 1
}

if [ "${1:-}" = "--list-rules" ]; then
    rules | cut -f1
    printf 'structural-binary\nstructural-executable\nstructural-invisible\nstructural-orphan-hook\n'
    printf 'structural-secret-material\n'
    exit 0
fi

# Tracked files plus anything untracked that git is not ignoring.
#
# Tracked alone was the first version and it was wrong in the direction that matters: a file is
# untracked for exactly as long as it takes to write it and commit it, so a scan that skips untracked
# files is blind during the only window in which removing the file is free. It found this by missing
# eight of its own new files on the run that was meant to verify them.
#
# `--exclude-standard` keeps ignored scratch out of it. The cost is that the pre-push hook can flag
# something not actually being pushed, which is a false stop rather than a false pass, and the
# suppression marker is there for it.
list_files() {
    if git rev-parse --git-dir >/dev/null 2>&1; then
        git ls-files --cached --others --exclude-standard
    else
        find . -type f -not -path './.git/*' | sed 's|^\./||'
    fi
}

# ---- pattern rules ---------------------------------------------------------
#
# One grep per rule over the whole file list, not one grep per rule per file. The first version did
# the latter, which is files times rules processes: 7.9 seconds on a 73 file service, and minutes on
# anything real. That matters because this runs as a pre-push hook, and a slow hook is a hook people
# pass with --no-verify by reflex.

check_patterns

# Five lists, built in one walk instead of the four separate walks the structural checks below used
# to do on their own: each of them called list_files() again and, for two of them, redid the same
# LC_ALL=C grep -qI text/binary test this walk already has the answer to. FULL_LIST is every entry
# list_files() prints (what structural-secret-material scans: it does not filter by text/binary).
# BINARY_LIST is the text check's complement (what structural-binary scans). ALL_LIST, EXEC_LIST and
# PROMPT_LIST are unchanged: the scoped, skip_file-filtered, text-only sets the pattern rules use,
# and structural-invisible now reuses ALL_LIST directly since its own filtering was identical to it.
ALL_LIST="$(mktemp)"; EXEC_LIST="$(mktemp)"; PROMPT_LIST="$(mktemp)"
FULL_LIST="$(mktemp)"; BINARY_LIST="$(mktemp)"
trap 'rm -f "$ALL_LIST" "$EXEC_LIST" "$PROMPT_LIST" "$FULL_LIST" "$BINARY_LIST"' EXIT

while IFS= read -r f; do
    [ -n "$f" ] || continue
    printf '%s\n' "$f" >> "$FULL_LIST"
    [ -f "$f" ] || continue
    if LC_ALL=C grep -qI . "$f" 2>/dev/null; then
        skip_file "$f" && continue
        printf '%s\n' "$f" >> "$ALL_LIST"
        in_scope exec "$f"   && printf '%s\n' "$f" >> "$EXEC_LIST"
        in_scope prompt "$f" && printf '%s\n' "$f" >> "$PROMPT_LIST"
    else
        printf '%s\n' "$f" >> "$BINARY_LIST"
    fi
done < <(list_files)

while IFS=$'\t' read -r id scope flags pat why; do
    [ -n "$id" ] || continue
    case "$scope" in
        all)    list="$ALL_LIST" ;;
        exec)   list="$EXEC_LIST" ;;
        prompt) list="$PROMPT_LIST" ;;
        *)      continue ;;
    esac
    [ -s "$list" ] || continue
    case "$flags" in i) gflags=-inHE ;; *) gflags=-nHE ;; esac

    # -H forces the filename prefix even when only one file is passed, so the parse below is uniform.
    while IFS= read -r hit; do
        [ -n "$hit" ] || continue
        f="${hit%%:*}"; rest="${hit#*:}"
        line="${rest%%:*}"; text="${rest#*:}"
        case "$text" in
            *"supply-chain-scan: allow"*)
                reason="${text##*supply-chain-scan: allow}"
                if [ -z "${reason// /}" ]; then
                    report "$f:$line [$id] suppressed with no reason. A suppression states why, or it is not one"
                else
                    printf 'ALLOW %s:%s [%s]%s\n' "$f" "$line" "$id" "$reason"
                    suppressed=$((suppressed+1))
                fi
                continue ;;
        esac
        report "$f:$line [$id] $why
      $(printf '%s' "$text" | sed 's/^[[:space:]]*//' | cut -c1-100)"
    done < <(tr '\n' '\0' < "$list" | xargs -0 grep "$gflags" -- "$pat" 2>/dev/null)
done < <(rules)

# ---- structural rules ------------------------------------------------------

# structural-secret-material: a committed key, keystore or certificate. This one applies everywhere,
# because `house-defaults.md` says never commit one and git keeps it forever: deleting it in a later
# commit leaves it in history, so the only real remedy is rotating the credential with whoever issued
# it. It is a filename rule rather than a content rule because these files are binary and their
# contents say nothing.
#
# It earned its place on the first real run. Scanning a Spring Boot service turned up six PKCS#12
# keystores under src/main/resources, which is the same finding security-audit had reported there
# separately.
#
# A repository with a genuine test fixture key lists it in .keel/scan-allow, one path per line with a
# reason after a space. That file is committed, so the exception is reviewed like anything else.
scan_allowed_path() {
    [ -f .keel/scan-allow ] || return 1
    while IFS= read -r entry; do
        entry="${entry%% *}"
        [ -n "$entry" ] || continue
        case "$entry" in \#*) continue ;; esac
        [ "$entry" = "$1" ] && return 0
    done < .keel/scan-allow
    return 1
}

# Reuses FULL_LIST, built once above: every entry list_files() prints, same as calling it again here
# would give, since this check is deliberately not filtered by text or binary (a keystore is binary).
while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in
        *.pfx|*.p12|*.jks|*.keystore|*.truststore|*.pem|*.key|*.der|*.asc|*id_rsa|*id_dsa|*id_ecdsa|*id_ed25519) ;;
        *) continue ;;
    esac
    if scan_allowed_path "$f"; then
        printf 'ALLOW %s [structural-secret-material] listed in .keel/scan-allow\n' "$f"
        suppressed=$((suppressed+1))
        continue
    fi
    report "$f [structural-secret-material] a committed key, keystore or certificate. git keeps it forever, so the remedy is rotating the credential, not deleting the file"
done < "$FULL_LIST"

# structural-binary: an opaque file nobody can review. Scoped to a plugin repository, where the whole
# tree is markdown, bash and a little Python, so a binary has no legitimate reason to exist.
#
# Not applied elsewhere, and the first real run is why: a Java service legitimately carries a Gradle
# wrapper jar, rotated log archives, and uploaded PDFs. Twenty findings, every one of them wrong. A
# check that fires twenty times on correct code is a check people learn to skip, which would have
# cost the keystore finding above as well.
if [ -f .claude-plugin/plugin.json ]; then
    # Reuses BINARY_LIST, built once above by the same LC_ALL=C grep -qI test this loop used to redo
    # itself: BINARY_LIST already holds exactly the files that test failed.
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        # An entry in scan-allow means the path has been reviewed and accepted, so it covers every
        # file-level rule rather than only the one that happened to fire first. Without this, an
        # accepted fixture key in a plugin repo is allowed by one rule and rejected by the next,
        # which reads as the allow list not working.
        scan_allowed_path "$f" && continue
        report "$f [structural-binary] a tracked binary file. Nothing in a plugin should be unreadable"
    done < "$BINARY_LIST"
fi

# structural-executable: the executable set is enumerated in allowed_executable above, and the
# enumeration only describes a plugin repository. See the note there.
if [ -f .claude-plugin/plugin.json ] && git rev-parse --git-dir >/dev/null 2>&1; then
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        allowed_executable "$f" && continue
        report "$f [structural-executable] has the executable bit and is not in the allowed set. Add it to allowed_executable with a reason, or clear the bit"
    done < <(git ls-files -s | awk '$1=="100755"{ $1=""; $2=""; $3=""; sub(/^[ \t]+/,""); print }')
fi

# structural-invisible: bidirectional and zero-width characters. This is the one rule here a careful
# reviewer genuinely cannot enforce, because the characters render as nothing: a bidi override can
# make a line of code display in an order that differs from the order it executes in.
#
# Reuses ALL_LIST, built once above: its filtering (skip_file, exists, text not binary) is exactly
# what this loop applied itself before checking each file for an invisible character.
while IFS= read -r f; do
    [ -n "$f" ] || continue
    if LC_ALL=C grep -qE "$(printf '\xe2\x80[\xaa-\xae\x8b-\x8f]|\xe2\x81[\xa6-\xa9]')" "$f" 2>/dev/null; then
        report "$f [structural-invisible] contains a bidirectional or zero-width character. It renders as nothing and can make code read differently from how it runs"
    fi
done < "$ALL_LIST"

# structural-orphan-hook: every executable under hooks/ is named in hooks.json. An unregistered hook
# either does nothing, in which case it is dead weight, or it is wired up somewhere else, in which
# case hooks.json is no longer the description of what this plugin runs.
if [ -f hooks/hooks.json ]; then
    while IFS= read -r h; do
        [ -n "$h" ] || continue
        base="$(basename "$h")"
        [ "$base" = "hooks.json" ] && continue
        grep -q "$base" hooks/hooks.json \
          || report "hooks/$base [structural-orphan-hook] is not referenced by hooks/hooks.json. Register it there or delete it"
    done < <(find hooks -maxdepth 1 -type f 2>/dev/null)
fi

# ---- summary ---------------------------------------------------------------

[ "$suppressed" -gt 0 ] && printf '\n%s suppression(s) honoured, listed above.\n' "$suppressed"
if [ "$errors" -eq 0 ]; then
    printf 'OK    supply chain clean (%s rules)\n' "$(rules | grep -c . )"
    exit 0
fi
# The consequence differs by what is being scanned, and a message that names the wrong one is a
# message people stop reading. A plugin's contents run on every machine that installs it; an ordinary
# repository's run wherever it is deployed.
if [ -f .claude-plugin/plugin.json ]; then
    printf '\n%s supply chain finding(s). Each one runs on every machine that installs this plugin.\n' "$errors"
else
    printf '\n%s supply chain finding(s) in what this repository ships.\n' "$errors"
fi
exit 1
