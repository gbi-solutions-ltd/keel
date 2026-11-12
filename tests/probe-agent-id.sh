#!/usr/bin/env bash
# Re-runs, against the installed Claude Code, the three observations hooks/review-guard rests on to
# tell a subagent from the main session (ADR-0016): the main session's Bash call carries no
# agent_id; a main session started with `--agent` carries an agent_type and still no agent_id; and a
# project agent dispatched as a subagent carries both. Task 7 of
# docs/plans/2026-11-02-hold-a-subagents-git-stash.md. docs/runbooks/cutting-a-release.md runs it
# when Claude Code is newer than the last release recorded.
#
# NOT IN tests/run-tests.sh. It needs a signed-in Claude Code and spends tokens: three `claude -p`
# sessions on haiku, each capped at a few turns. Run it by hand.
#
# How. A throwaway plugin, loaded with `--plugin-dir`, logs every PreToolUse Bash event to a file;
# a throwaway project under the system temp directory holds the agent `helper`. Each case runs one
# session and is judged on the events it logged, by the marker command it was told to run. A case
# that logged no matching call fails, and prints that session's output. Sessions run in `dontAsk`
# mode with only the two marker commands and the Agent tool allowed, so any other call is denied
# without a prompt; they load project settings only (no user settings, hooks or plugins) and no MCP
# servers. Only the temp directory is removed on exit: each session's transcript stays under Claude
# Code's config directory (`CLAUDE_CONFIG_DIR`, default `~/.claude`), in `projects/`.
#
# Exit: 0 when all three hold, 1 on any FAIL, 2 when `claude` or `python3` is missing.
# Usage: tests/probe-agent-id.sh

set -uo pipefail

for cmd in claude python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        printf 'probe-agent-id: %s not found on PATH\n' "$cmd" >&2
        exit 2
    fi
done

tmp="$(mktemp -d "${TMPDIR:-/tmp}/probe-agent-id.XXXXXX")"; [ -d "$tmp" ] || { echo "$0: mktemp -d failed" >&2; kill $$; exit 1; }
trap 'rm -rf "$tmp"' EXIT

plugin="$tmp/plugin"; project="$tmp/project"; log="$tmp/events.jsonl"
mkdir -p "$plugin/.claude-plugin" "$plugin/hooks" "$project/.claude/agents"

printf '{"name": "probe-agent-id", "version": "0.0.0"}\n' > "$plugin/.claude-plugin/plugin.json"
# shellcheck disable=SC2016  # ${CLAUDE_PLUGIN_ROOT} is for Claude Code to expand, not this shell
printf '{"hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "\\"${CLAUDE_PLUGIN_ROOT}/hooks/log\\""}]}]}}\n' \
    > "$plugin/hooks/hooks.json"
# The hook writes one event per line, so a case is read by line. The log path reaches it through
# PROBE_LOG, so no character in TMPDIR can break the script.
cat > "$plugin/hooks/log" <<'EOF'
#!/bin/sh
tr -d '\n' >> "$PROBE_LOG"
echo >> "$PROBE_LOG"
EOF
chmod +x "$plugin/hooks/log"

cat > "$project/.claude/agents/helper.md" <<'EOF'
---
name: helper
description: Runs one marker command for the agent_id probe.
tools: Bash
model: haiku
---
Run exactly this one Bash command and nothing else, then stop: echo probe-helper
EOF

# judge <case> <marker> reads $log and prints what it saw; exit 0 when the case holds.
read -r -d '' JUDGE <<'PY'
import json, sys
case, marker, path = sys.argv[1:4]
seen = []
try:
    lines = open(path).read().splitlines()
except OSError:
    lines = []
for line in lines:
    try:
        ev = json.loads(line)
    except ValueError:
        continue
    if marker in str((ev.get("tool_input") or {}).get("command", "")):
        seen.append(ev)
if not seen:
    print("no Bash call running %s was logged" % marker)
    sys.exit(1)
def nonempty(v):
    return isinstance(v, str) and v != ""
ok = True
for ev in seen:
    t, i = ev.get("agent_type"), ev.get("agent_id")
    if case == "main":
        ok = ok and not nonempty(i)
    elif case == "agent":
        ok = ok and nonempty(t) and not nonempty(i)
    else:
        ok = ok and t == "helper" and nonempty(i)
    print("agent_type=%r agent_id=%r" % (t, i))
sys.exit(0 if ok else 1)
PY

fails=0
run_case() {   # run_case <case> <marker> <label> <claude args>...
    local case="$1" marker="$2" label="$3" out="$tmp/$1.out" seen
    shift 3
    : > "$log"
    (cd "$project" && PROBE_LOG="$log" claude -p --plugin-dir "$plugin" --model haiku \
        --allowedTools "Bash(echo probe-main),Bash(echo probe-helper),Agent" \
        --permission-mode dontAsk --setting-sources project --strict-mcp-config --max-turns 3 \
        "$@" >"$out" 2>&1)
    if seen="$(python3 -c "$JUDGE" "$case" "$marker" "$log")"; then
        printf 'PASS  %s\n' "$label"
    else
        printf 'FAIL  %s (saw: %s)\n' "$label" "$(printf '%s' "$seen" | tr '\n' ' ')"
        sed 's/^/      /' "$out"
        fails=$((fails + 1))
    fi
}

printf 'Claude Code %s\n' "$(claude --version 2>&1)"
run_case main probe-main "main session: no agent_id" \
    "Run exactly this one Bash command and nothing else, then stop: echo probe-main"
run_case agent probe-helper "main session started with --agent: agent_type set, no agent_id" \
    --agent helper "Go."
run_case subagent probe-helper "project agent subagent: agent_type and agent_id set" \
    "Dispatch the helper agent with the Agent tool, with the prompt Go. Run nothing yourself."

[ "$fails" -eq 0 ] || exit 1
exit 0
