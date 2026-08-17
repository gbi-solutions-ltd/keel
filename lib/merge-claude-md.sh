#!/usr/bin/env bash
# Marker-based idempotent merge of the managed block into a CLAUDE.md or AGENTS.md.
# Sourced by bin/keel.
#
# Rules, in order of importance:
#   - Content between the markers is ours and is replaced wholesale.
#   - Content outside them belongs to the project and is never touched.
#   - Duplicate or unbalanced markers are reported, never repaired. Silently "fixing" a file
#     someone has hand-edited is how a tool loses trust permanently.

MARK_START='<!-- keel:start v1 -->'
MARK_END='<!-- keel:end -->'

# 0 clean, 2 duplicate, 3 unbalanced.
check_markers() {
    local f="$1" s e
    [ -f "$f" ] || return 0
    s=$(grep -cF "$MARK_START" "$f"); e=$(grep -cF "$MARK_END" "$f")
    [ "$s" -gt 1 ] || [ "$e" -gt 1 ] && return 2
    [ "$s" -ne "$e" ] && return 3
    return 0
}

# merge_block <file> <block-file>
merge_block() {
    local f="$1" block="$2" tmp
    tmp="$(mktemp)"

    if [ ! -f "$f" ]; then
        cat "$block" > "$f"; return 0
    fi
    if ! grep -qF "$MARK_START" "$f"; then
        # Append, separated by a blank line, leaving the project's content first.
        { cat "$f"; printf '\n'; cat "$block"; } > "$tmp" && mv "$tmp" "$f"; return 0
    fi
    # Replace between the markers, keeping everything either side.
    awk -v start="$MARK_START" -v end="$MARK_END" -v blockfile="$block" '
        index($0, start) { while ((getline line < blockfile) > 0) print line; skip=1; next }
        index($0, end)   { skip=0; next }
        !skip            { print }
    ' "$f" > "$tmp" && mv "$tmp" "$f"
}
