#!/usr/bin/env bash
# APEX application export. Sourced by bin/keel; not executable on its own.
#
# This is the one command in keel that requires python3 rather than treating it as optional.
# The work is parsing several megabytes of JSON out of a database client, intersecting a column
# list against a live catalog, and writing a file tree. Every bash attempt at that is a worse
# version of what python does in the standard library, and a half-working export is more dangerous
# than none: the whole point of the artifact is that an agent trusts what it reads.
#
# The departure is recorded in docs/standards.md.

# Print what is missing, or nothing when the dependencies are satisfied.
apex_missing_deps() {
    have_python || printf 'python3 '
    command -v java >/dev/null 2>&1 || printf 'java '
}

cmd_apex_export() {
    case "${1:-}" in
        -h|--help|"")
            say "keel apex-export --app <id> [options]"
            say ""
            say "Export one Oracle APEX application into a tree an agent can grep."
            say ""
            say "  --app <id>          APEX application id, required"
            say "  --conn <str>        user/pass@host:port/service"
            say "  --target <name>     a name in ~/.keel/apex-targets.json, keeps the password"
            say "                      out of shell history and out of an agent transcript"
            say "  --out <dir>         default <docs_root>/apex/APP-<id>"
            say "  --sqlcl <path>      path to the SQLcl 'sql' binary"
            say "  --probe-only        report APEX version and capabilities, write nothing"
            say "  --raw               also run the native APEX export into raw/"
            say "  --no-ddl            skip database object extraction"
            say "  --no-redact         keep values matching credential patterns"
            say "  --capture <dir>     save raw client output, for fixtures and for support"
            say "  --from-capture <d>  render from a capture directory, no database needed"
            say ""
            say "Connection is read from --conn, then KEEL_APEX_CONN, then --target."
            [ -z "${1:-}" ] && return 1
            return 0 ;;
    esac

    local missing; missing="$(apex_missing_deps)"
    [ -z "$missing" ] || die "apex-export needs: ${missing% }. java is required because SQLcl runs on it."

    [ -f "$HERE/lib/apex_export.py" ] || die "incomplete install: lib/apex_export.py not found under $HERE"

    python3 "$HERE/lib/apex_export.py" "$@"
}
