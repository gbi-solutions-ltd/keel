#!/usr/bin/env bash
# The subagent status line: the settings.json that registers it, and the lib/subagent_statusline.py
# it is generated from. Idea record docs/ideas/harness-held-dispatch-guarantees.md, variant A.
#
# What it must do: put the resolved model beside the label keel wrote, keep the model when the row
# is narrow, override only the rows keel labelled, and print nothing for anything it cannot read.
# Printing nothing is the safe failure: the harness keeps its default row for any task the script
# does not name, so a script that cannot parse its input leaves the panel as it was rather than
# blank, and another plugin's subagents keep their elapsed time and live progress.
#
# Every behaviour case runs the command read out of settings.json, with `sh -c` and a minimal
# environment, as the harness does, and not the source file: the shipped artifact is what has to
# work. settings.json inlines the script because ${CLAUDE_PLUGIN_ROOT} does not resolve in a plugin
# settings.json (task 1 of docs/plans/2026-10-13-harness-held-dispatch-guarantees.md).
#
# The `condition && ok || bad` idiom is safe here because both helpers return 0.
# shellcheck disable=SC2015
# Single quotes are deliberate: the fixtures are literal JSON.
# shellcheck disable=SC2016
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
pass=0; fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }

# The command the harness runs. Empty when settings.json is missing or unreadable, and every case
# below then fails, because an empty command prints nothing and "prints nothing" is also what a
# correct script does for input it cannot read: without that guard a missing file passed.
CMD="$(python3 -I -c 'import json; print(json.load(open("settings.json"))["subagentStatusLine"]["command"])' 2>/dev/null)"
row() { [ -n "$CMD" ] && printf '%s' "$1" | env -i PATH="$PATH" LC_ALL=C sh -c "$CMD" 2>/dev/null; }

# 1. The point of the script: the model sits after the label, and the label is what the dispatch
#    wrote, so a label that fits whole is never cut: on a narrow pane the agent name or type in
#    front of it goes first, then the token count, then the end of the label, and the model never
#    (cases 4 to 6 and 17 to 21).
got="$(row '{"columns":120,"tasks":[{"id":"t1","type":"local_agent","status":"running","description":"inherit: review task 4","model":"claude-opus-5-5","tokenCount":12345}]}')"
want='{"id": "t1", "content": "inherit: review task 4 · claude-opus-5-5 · 12.3k tokens"}'
[ "$got" = "$want" ] && ok "a row with a model shows it after the label" || bad "a row with a model shows it after the label" "got: $got"

# 2. A model is omitted until it resolves. No line means the harness's default row, not a guess.
got="$(row '{"columns":120,"tasks":[{"id":"t2","type":"local_agent","status":"running","description":"keel-fanout: read lib","tokenCount":10}]}')"
[ -n "$CMD" ] && [ -z "$got" ] && ok "a row with no model yet keeps the default rendering" || bad "a row with no model yet keeps the default rendering" "got: $got"

# 3. Each task is judged on its own. The default row leads with the subagent name, or the agent type
#    when it has no name, and an override replaces the whole row, so the lead has to be kept: for an
#    unnamed agent the agent type is how a keel-fanout: label is checked against the agent that
#    carries it. A task with both leads with its name, as the default row does, so a named agent's
#    type is not on the row (task d).
got="$(row '{"columns":120,"tasks":[{"id":"a","name":"rev","description":"inherit: x","model":"m1","tokenCount":1},{"id":"b","description":"keel-fanout: y","tokenCount":5},{"id":"c","agentType":"keel:keel-fanout","description":"keel-fanout: z","model":"m2","tokenCount":2},{"id":"d","name":"rev","agentType":"keel:keel-fanout","description":"keel-fanout: w","model":"m3","tokenCount":3}]}')"
want='{"id": "a", "content": "rev · inherit: x · m1 · 1 token"}
{"id": "c", "content": "keel:keel-fanout · keel-fanout: z · m2 · 2 tokens"}
{"id": "d", "content": "rev · keel-fanout: w · m3 · 3 tokens"}'
[ "$got" = "$want" ] && ok "only labelled rows with a model are overridden, and the row leads with its name, or its agent type when unnamed" || bad "only labelled rows with a model are overridden, and the row leads with its name, or its agent type when unnamed" "got: $got"

# 4. Narrow: a label that does not fit whole beside the model loses its token count and then its
#    end, and the model never gives way. The label is 39 characters and the model with its
#    separator takes 20, so at 40 columns the label is cut to the 20 left: 17 characters and an
#    ellipsis. The count would have fit beside a shorter label, and it is dropped all the same,
#    because a label that fits whole is worth more than the count (case 19).
got="$(row '{"columns":40,"tasks":[{"id":"n","description":"keel-fanout: read every file under lib/","model":"claude-sonnet-5-5","tokenCount":500}]}')"
want='{"id": "n", "content": "keel-fanout: read... · claude-sonnet-5-5"}'
[ "$got" = "$want" ] && ok "a narrow row drops its token count and shortens the label before the model" || bad "a narrow row drops its token count and shortens the label before the model" "got: $got"

got="$(row '{"columns":20,"tasks":[{"id":"n","description":"keel-fanout: read every file under lib/","model":"claude-sonnet-5-5","tokenCount":500}]}')"
want='{"id": "n", "content": "claude-sonnet-5-5"}'
[ "$got" = "$want" ] && ok "a row too narrow for anything else still shows the model" || bad "a row too narrow for anything else still shows the model" "got: $got"

# 5. No `columns` value means no width to fit, so the row is shown whole. Comparing a length with a
#    missing width raises, a raise prints nothing, and nothing printed drops the model from every
#    row for a harness that leaves the field out.
got="$(row '{"tasks":[{"id":"a","description":"keel-fanout: read every file under lib/ and more","model":"m","tokenCount":5}]}')"
want='{"id": "a", "content": "keel-fanout: read every file under lib/ and more · m · 5 tokens"}'
[ "$got" = "$want" ] && ok "a missing columns value shows the whole row" || bad "a missing columns value shows the whole row" "got: $got"

# 6. The token count gives way before the model. At 30 columns the label does not fit whole beside
#    the model, so the count is gone and the label is cut to the 10 columns the model leaves it: 7
#    characters and an ellipsis, and the model fills the other 20. The model is the one thing on
#    the row nothing else shows, so it is the last to go.
got="$(row '{"columns":30,"tasks":[{"id":"n","description":"keel-fanout: read every file under lib/","model":"claude-sonnet-5-5","tokenCount":500}]}')"
want='{"id": "n", "content": "keel-fa... · claude-sonnet-5-5"}'
[ "$got" = "$want" ] && ok "the token count gives way before the model" || bad "the token count gives way before the model" "got: $got"

# 7. Unreadable input prints nothing and exits 0, for every shape it can arrive in.
all_quiet=yes
[ -n "$CMD" ] || all_quiet="no: settings.json holds no command"
for input in 'not json' '[]' '{}' '{"tasks":"x"}' '{"tasks":[1,"a",null]}'; do
    out="$(printf '%s' "$input" | env -i PATH="$PATH" LC_ALL=C sh -c "$CMD" 2>&1)"; rc=$?
    { [ -z "$out" ] && [ "$rc" -eq 0 ]; } || { all_quiet="no: input $input gave rc=$rc out=$out"; break; }
done
[ "$all_quiet" = yes ] && ok "unreadable input prints nothing and exits 0" || bad "unreadable input prints nothing and exits 0" "$all_quiet"

# 8. A description cut inside a surrogate pair (a JS string cut by index) arrives as a lone
#    surrogate escape. It is not printable, so the label is cleaned of it. The id is echoed back
#    untouched, and encoding a lone surrogate as strict UTF-8 raises, so one bad row would lose
#    every other row in the same tick unless it is replaced: the id of row s carries one for that
#    reason. The backslash is built with printf because the fixture needs a JSON escape inside a
#    shell string.
bs="$(printf '\134')"
got="$(row '{"columns":120,"tasks":[{"id":"s'"${bs}"'ud83d","description":"inherit: x '"${bs}"'ud83d","model":"m"},{"id":"t","description":"inherit: ok","model":"m"}]}')"
want='{"id": "s?", "content": "inherit: x  · m"}
{"id": "t", "content": "inherit: ok · m"}'
[ "$got" = "$want" ] && ok "a lone surrogate in one row does not lose the others" || bad "a lone surrogate in one row does not lose the others" "got: $got"

# 9. Control characters in a label cannot reach the terminal. The harness parses the JSON and draws
#    `content` as it is, escape sequences included, so a description holding an ESC and an OSC 8
#    opener (the dispatching model writes descriptions) could leave a sequence open that swallows
#    the model after it. The JSON escapes are built with $bs, so the fixture is valid JSON and the
#    script receives a real ESC and BEL. The output is checked twice: the exact line, and the
#    decoded content, because the line itself carries any control character as a JSON escape, which
#    a byte check on it would pass.
got="$(row '{"columns":120,"tasks":[{"id":"c","description":"inherit: x'"${bs}"'u001b]8;;http://example.invalid'"${bs}"'u0007click","model":"m"}]}')"
want='{"id": "c", "content": "inherit: x]8;;http://example.invalidclick · m"}'
[ "$got" = "$want" ] && ok "control characters in a label are dropped before the model is placed" || bad "control characters in a label are dropped before the model is placed" "got: $got"
if printf '%s' "$got" | python3 -I -c 'import json, sys
rows = [json.loads(l) for l in sys.stdin.buffer.read().decode("utf-8").splitlines() if l.strip()]
sys.exit(0 if rows and all(ch.isprintable() for r in rows for ch in r["content"]) else 1)'
then ok "no control character survives in the decoded content"
else bad "no control character survives in the decoded content" "got: $got"
fi

# 10. The lead is cleaned too, and each candidate is cleaned before one is chosen. A name made only
#     of an ESC and a BEL is not printable, so once cleaned it is no name, and the row leads with
#     the agent type as it does for an unnamed agent. Cleaning after the choice,
#     `_clean(name or agentType)`, picks the name, cleans it to nothing and leaves no lead at all.
got="$(row '{"columns":120,"tasks":[{"id":"n","name":"'"${bs}"'u001b'"${bs}"'u0007","agentType":"keel:keel-fanout","description":"inherit: d","model":"m","tokenCount":1}]}')"
want='{"id": "n", "content": "keel:keel-fanout · inherit: d · m · 1 token"}'
[ "$got" = "$want" ] && ok "a name that cleans to nothing gives way to the agent type" || bad "a name that cleans to nothing gives way to the agent type" "got: $got"

# 11. The model is cleaned like the label. The harness draws `content` as it is, so an ESC in the
#     model is the same hazard as one in a description. Here an OSC title opener and its BEL sit
#     inside the model, and only the printable remainder may be shown. Checked as case 9 does: the
#     exact line, and the decoded content, because the line carries a control character as a
#     JSON escape that a byte check on it would pass.
got="$(row '{"columns":120,"tasks":[{"id":"m","description":"inherit: d","model":"m'"${bs}"'u001b]0;x'"${bs}"'u0007z"}]}')"
want='{"id": "m", "content": "inherit: d · m]0;xz"}'
[ "$got" = "$want" ] && ok "control characters in the model are dropped" || bad "control characters in the model are dropped" "got: $got"
if printf '%s' "$got" | python3 -I -c 'import json, sys
rows = [json.loads(l) for l in sys.stdin.buffer.read().decode("utf-8").splitlines() if l.strip()]
sys.exit(0 if rows and all(ch.isprintable() for r in rows for ch in r["content"]) else 1)'
then ok "no control character survives in the decoded content when the model held one"
else bad "no control character survives in the decoded content when the model held one" "got: $got"
fi

# 12. A model that cleans to nothing is no model. Its row keeps the default rendering, as for a
#     missing model (case 2), and is not printed with a blank where the model should be. The second
#     row is well formed, so the case also shows that the bad row does not lose its neighbour.
got="$(row '{"columns":120,"tasks":[{"id":"x","description":"inherit: d","model":"'"${bs}"'u001b'"${bs}"'u0007"},{"id":"y","description":"inherit: ok","model":"m"}]}')"
want='{"id": "y", "content": "inherit: ok · m"}'
[ "$got" = "$want" ] && ok "a model made only of control characters keeps the default row and spares the next one" || bad "a model made only of control characters keeps the default row and spares the next one" "got: $got"

# 13. The command is isolated from the directory it runs in. The harness runs it with the project
#     directory as the working directory, and a plain `python3 -c` imports from there first, so a
#     json.py in a user project would run on every refresh tick as the user. The decoy prints a loud
#     line and defines nothing else, so a command that imports it prints that line and no row.
decoy="$(mktemp -d)"
printf 'print("DECOY RAN")\n' > "$decoy/json.py"
got="$(cd "$decoy" && row '{"columns":120,"tasks":[{"id":"t1","description":"inherit: review task 4","model":"claude-opus-5-5","tokenCount":12345}]}')"
rm -rf "$decoy"
want='{"id": "t1", "content": "inherit: review task 4 · claude-opus-5-5 · 12.3k tokens"}'
[ "$got" = "$want" ] && ok "the command ignores a json.py in its working directory" || bad "the command ignores a json.py in its working directory" "got: $got"

# 14. The registration. Only `agent` and `subagentStatusLine` take effect from a plugin
#     settings.json and every other key is dropped at load, so a second key here would be a setting
#     nobody reads. The command must not lean on the plugin root, which is the variable that does
#     not resolve, and must start with the isolated interpreter that case 13 depends on.
if python3 -I - <<'PY'
import json
s = json.load(open("settings.json"))
assert set(s) == {"subagentStatusLine"}, s
c = s["subagentStatusLine"]
assert set(c) == {"type", "command"} and c["type"] == "command", c
cmd = c["command"]
assert cmd.startswith("python3 -I -c '") and cmd.endswith("'"), cmd[:40]
assert "CLAUDE_PLUGIN_ROOT" not in cmd
PY
then ok "settings.json registers one inline command and nothing else"
else bad "settings.json registers one inline command and nothing else" "see the assertion above"
fi

# 15. The file is the generator's output for the current source, byte for byte. Without this a
#     person edits lib/subagent_statusline.py, every case above still passes against the old
#     inlined copy, and what ships is not what was reviewed.
if tests/generate-harness-artifacts.sh subagent-settings 2>/dev/null | cmp -s - settings.json
then ok "settings.json is what the generator makes from lib/subagent_statusline.py"
else bad "settings.json is what the generator makes from lib/subagent_statusline.py" "regenerate it: tests/generate-harness-artifacts.sh subagent-settings > settings.json"
fi

# 16. Only rows keel labelled are overridden. An override replaces the whole row, so a row without a
#     label would lose its elapsed time, live progress and queued count for a subagent keel never
#     dispatched: another plugin's, or the user's own. The labels are the three the standard names,
#     `inherit: `, `keel-fanout: ` and `keel-implementer: ` (docs/standards.md, "A dispatch names
#     its model, and says so"), as written, at the start of the description. Each case sets the
#     rows to be left alone beside a labelled neighbour, because "prints nothing" is also what a
#     broken script does.
#
#     (a) A row with a model and no label is left alone: one with an agent type, and one with no
#     description at all.
got="$(row '{"columns":120,"tasks":[{"id":"u","agentType":"other:agent","description":"review the diff","model":"m1","tokenCount":3},{"id":"v","model":"m2"},{"id":"l","description":"inherit: review","model":"m3","tokenCount":4}]}')"
want='{"id": "l", "content": "inherit: review · m3 · 4 tokens"}'
[ "$got" = "$want" ] && ok "a row with a model and no label keeps the default rendering" || bad "a row with a model and no label keeps the default rendering" "got: $got"

#     (b) The label has to start the description and be written as the standard writes it. Label
#     text later in a description, or a label missing its space, is not a keel label.
got="$(row '{"columns":120,"tasks":[{"id":"p","description":"please run inherit: the plan","model":"m1"},{"id":"q","description":"note keel-fanout: read lib","model":"m2"},{"id":"r","description":"inherit:x","model":"m3"},{"id":"l","description":"keel-fanout: read lib","model":"m4"}]}')"
want='{"id": "l", "content": "keel-fanout: read lib · m4"}'
[ "$got" = "$want" ] && ok "label text that does not start the description, or lacks its space, is not a label" || bad "label text that does not start the description, or lacks its space, is not a label" "got: $got"

#     (c) The label is judged on the cleaned description, which is the text the row draws. A BEL
#     before the label is dropped by the cleaning, so the person sees a description that starts
#     with the label and the row is overridden. Judging the raw text would leave a row that visibly
#     starts with a keel label on the default rendering, with no model shown.
got="$(row '{"columns":120,"tasks":[{"id":"c","description":"'"${bs}"'u0007inherit: x","model":"m"}]}')"
want='{"id": "c", "content": "inherit: x · m"}'
[ "$got" = "$want" ] && ok "a label that starts the description once it is cleaned is a label" || bad "a label that starts the description once it is cleaned is a label" "got: $got"

# 17. The lead gives way before the label. The row is lead, label, model, token count, and the label
#     is the text the feature exists to show, so on a narrow pane the agent name or type in front of
#     it is cut first, then the token count, then the end of the label. The lead is shortened with
#     an ellipsis when that keeps at least three of its characters, and dropped when it does not.
#     Fixture: agent type keel:keel-fanout (16 characters), label "keel-fanout: read lib" (21),
#     model claude-sonnet-5-5 (17), "500 tokens" (10), and a separator is 3. The tail after the
#     label is 3 + 17 + 3 + 10 = 33, so the label and tail take 54 and the whole row takes 73.
#
#     (a) At 62 columns 8 are spare, short of the 9 that a lead of three characters, an ellipsis and
#     a separator take, so the lead is dropped and the label and the count stay.
got="$(row '{"columns":62,"tasks":[{"id":"n","agentType":"keel:keel-fanout","description":"keel-fanout: read lib","model":"claude-sonnet-5-5","tokenCount":500}]}')"
want='{"id": "n", "content": "keel-fanout: read lib · claude-sonnet-5-5 · 500 tokens"}'
[ "$got" = "$want" ] && ok "a row that fits only without its lead drops the lead and keeps its whole label" || bad "a row that fits only without its lead drops the lead and keeps its whole label" "got: $got"

#     (b) At 63 columns 9 are spare: the lead keeps three characters and an ellipsis. At 68, 14 are
#     spare and it keeps eight.
got="$(row '{"columns":63,"tasks":[{"id":"n","agentType":"keel:keel-fanout","description":"keel-fanout: read lib","model":"claude-sonnet-5-5","tokenCount":500}]}')"
want='{"id": "n", "content": "kee... · keel-fanout: read lib · claude-sonnet-5-5 · 500 tokens"}'
[ "$got" = "$want" ] && ok "a row with spare room for a few characters shortens its lead and keeps its whole label" || bad "a row with spare room for a few characters shortens its lead and keeps its whole label" "got: $got"

got="$(row '{"columns":68,"tasks":[{"id":"n","agentType":"keel:keel-fanout","description":"keel-fanout: read lib","model":"claude-sonnet-5-5","tokenCount":500}]}')"
want='{"id": "n", "content": "keel:kee... · keel-fanout: read lib · claude-sonnet-5-5 · 500 tokens"}'
[ "$got" = "$want" ] && ok "a lead takes the spare room it has when it cannot be shown whole" || bad "a lead takes the spare room it has when it cannot be shown whole" "got: $got"

#     (c) A row too narrow even for its whole label shows no lead and no count, and cuts the label.
#     The label "keel-fanout: read every file under lib and more" is 47 and the model with its
#     separator takes 20, so the label and model alone take 67 and no form of the row holds the
#     whole label at 60 columns. The model leaves 40 for the label: 37 characters and an ellipsis.
#     Before the count gave way ahead of the end of the label this row showed
#     `keel-fanout: read ever... · claude-sonnet-5-5 · 12.3k tokens`, the label cut mid-word while
#     the count stayed.
got="$(row '{"columns":60,"tasks":[{"id":"n","agentType":"keel:keel-fanout","description":"keel-fanout: read every file under lib and more","model":"claude-sonnet-5-5","tokenCount":12345}]}')"
want='{"id": "n", "content": "keel-fanout: read every file under li... · claude-sonnet-5-5"}'
[ "$got" = "$want" ] && ok "a row too narrow for its whole label cuts the label and shows no lead or count" || bad "a row too narrow for its whole label cuts the label and shows no lead or count" "got: $got"

# 18. A row that fits exactly is shown whole, and one column less degrades it. Without these a fit
#     test written `<` instead of `<=` passes every case above, and a row would be cut one column
#     before it had to be.
#
#     (a) The fixture of case 17 without a lead: the label and tail take 54, so 54 columns show the
#     row whole and 53 drop the count, which leaves the whole label beside the model (41).
got="$(row '{"columns":54,"tasks":[{"id":"n","description":"keel-fanout: read lib","model":"claude-sonnet-5-5","tokenCount":500}]}')"
want='{"id": "n", "content": "keel-fanout: read lib · claude-sonnet-5-5 · 500 tokens"}'
[ "$got" = "$want" ] && ok "a row that fits its width exactly is shown whole" || bad "a row that fits its width exactly is shown whole" "got: $got"

got="$(row '{"columns":53,"tasks":[{"id":"n","description":"keel-fanout: read lib","model":"claude-sonnet-5-5","tokenCount":500}]}')"
want='{"id": "n", "content": "keel-fanout: read lib · claude-sonnet-5-5"}'
[ "$got" = "$want" ] && ok "a row one column too wide for its width drops the token count and keeps the label" || bad "a row one column too wide for its width drops the token count and keeps the label" "got: $got"

#     (b) The same with the lead, which makes the whole row 73: 73 columns show it whole, and 72 cut
#     the lead to 12 characters and an ellipsis, with the label and the count kept.
got="$(row '{"columns":73,"tasks":[{"id":"n","agentType":"keel:keel-fanout","description":"keel-fanout: read lib","model":"claude-sonnet-5-5","tokenCount":500}]}')"
want='{"id": "n", "content": "keel:keel-fanout · keel-fanout: read lib · claude-sonnet-5-5 · 500 tokens"}'
[ "$got" = "$want" ] && ok "a row with a lead that fits its width exactly is shown whole" || bad "a row with a lead that fits its width exactly is shown whole" "got: $got"

got="$(row '{"columns":72,"tasks":[{"id":"n","agentType":"keel:keel-fanout","description":"keel-fanout: read lib","model":"claude-sonnet-5-5","tokenCount":500}]}')"
want='{"id": "n", "content": "keel:keel-fa... · keel-fanout: read lib · claude-sonnet-5-5 · 500 tokens"}'
[ "$got" = "$want" ] && ok "a row with a lead one column too wide for its width shortens the lead" || bad "a row with a lead one column too wide for its width shortens the lead" "got: $got"

#     (c) The exact fit once the lead has given way: 54 columns hold the label and tail and nothing
#     else.
got="$(row '{"columns":54,"tasks":[{"id":"n","agentType":"keel:keel-fanout","description":"keel-fanout: read lib","model":"claude-sonnet-5-5","tokenCount":500}]}')"
want='{"id": "n", "content": "keel-fanout: read lib · claude-sonnet-5-5 · 500 tokens"}'
[ "$got" = "$want" ] && ok "a row that fits exactly once its lead is dropped keeps its whole label" || bad "a row that fits exactly once its lead is dropped keeps its whole label" "got: $got"

#     (d) The exact fit after the token count has given way. Label "inherit: x" (10), model "m" and
#     "12.3k tokens" (12) make a 29 column row, and the count leaves a 14 column one. At 14 the
#     count is dropped and the rest fits exactly; at 13 the label is cut to 6 characters and an
#     ellipsis, so the model keeps its place.
got="$(row '{"columns":14,"tasks":[{"id":"n","description":"inherit: x","model":"m","tokenCount":12345}]}')"
want='{"id": "n", "content": "inherit: x · m"}'
[ "$got" = "$want" ] && ok "a row that fits exactly once its token count is dropped is shown whole" || bad "a row that fits exactly once its token count is dropped is shown whole" "got: $got"

got="$(row '{"columns":13,"tasks":[{"id":"n","description":"inherit: x","model":"m","tokenCount":12345}]}')"
want='{"id": "n", "content": "inheri... · m"}'
[ "$got" = "$want" ] && ok "a row one column too wide once its token count is dropped cuts the label" || bad "a row one column too wide once its token count is dropped cuts the label" "got: $got"

# 19. Widening a pane never shortens the label. A label that fits whole is the text the feature
#     exists to show, and a row that cut the label while it still carried its token count could
#     show less of it one column wider. Two rows: the fixture of case 17 (a lead, a label, a model
#     and a count), and a row with no lead and a count of 0, which at 18 columns showed
#     `inherit: x · m` and at 19 showed `i... · m · 0 tokens`. The command is run for every width
#     from 10 to 120, and once a row holds its whole label every wider width has to hold it too.
#     A row that never holds it fails as well, or the case would pass by finding nothing to check.
if CMD="$CMD" python3 -I - <<'PY'
import json, os, subprocess, sys
rows = [
    {"id": "a", "agentType": "keel:keel-fanout", "description": "keel-fanout: read lib", "model": "claude-sonnet-5-5", "tokenCount": 500},
    {"id": "b", "description": "inherit: x", "model": "m", "tokenCount": 0},
]
env = {"PATH": os.environ["PATH"], "LC_ALL": "C"}
whole = {r["id"]: [] for r in rows}
for columns in range(10, 121):
    payload = json.dumps({"columns": columns, "tasks": rows}).encode()
    out = subprocess.run(["sh", "-c", os.environ["CMD"]], input=payload, env=env, capture_output=True).stdout
    content = {}
    for line in out.decode("utf-8").splitlines():
        got = json.loads(line)
        content[got["id"]] = got["content"]
    for r in rows:
        whole[r["id"]].append(r["description"] in content.get(r["id"], ""))
for r in rows:
    first = None
    for i, held in enumerate(whole[r["id"]]):
        if held and first is None:
            first = i
        if first is not None and not held:
            sys.exit("row %s: the whole label shows at %d columns and is cut at %d" % (r["id"], i + 9, i + 10))
    if first is None:
        sys.exit("row %s: the whole label never shows" % r["id"])
PY
then ok "widening a pane never shortens the label"
else bad "widening a pane never shortens the label" "see the line above"
fi

# 20. The label is cut only when the ellipsis leaves it something to show. Its room is the width
#     less the model and its separator (4, for a model of one character). With 3 left, a bare `...`
#     would say nothing, so the row is the model alone; with 4 left the label keeps one character.
#     Fixture: "inherit: x" (10), model m and a count of 12345, which no width here holds: 7 columns
#     leave 3, and 8 leave 4.
got="$(row '{"columns":7,"tasks":[{"id":"n","description":"inherit: x","model":"m","tokenCount":12345}]}')"
want='{"id": "n", "content": "m"}'
[ "$got" = "$want" ] && ok "a label with room for only an ellipsis is dropped for the model alone" || bad "a label with room for only an ellipsis is dropped for the model alone" "got: $got"

got="$(row '{"columns":8,"tasks":[{"id":"n","description":"inherit: x","model":"m","tokenCount":12345}]}')"
want='{"id": "n", "content": "i... · m"}'
[ "$got" = "$want" ] && ok "a label with room for one character and an ellipsis is cut to that" || bad "a label with room for one character and an ellipsis is cut to that" "got: $got"

# 21. The lead gives way against the row without the count as well. Fixture: name nm (2), label
#     "inherit: x" (10), model m and a count of 12345 ("12.3k tokens", 12). With the lead the row
#     takes 5 + 10 + 4 = 19 and with the count 34. From 14 to 18 columns neither fits, and the
#     label and model alone take 14, so the lead is dropped and the label stays whole. If the lead
#     gave way only beside the count, these widths would cut the label instead (`inheri... · m`).
all_whole=yes
for columns in 14 15 16 17 18; do
    got="$(row '{"columns":'"$columns"',"tasks":[{"id":"n","name":"nm","description":"inherit: x","model":"m","tokenCount":12345}]}')"
    want='{"id": "n", "content": "inherit: x · m"}'
    [ "$got" = "$want" ] || { all_whole="no: $columns columns gave $got"; break; }
done
[ "$all_whole" = yes ] && ok "a lead that does not fit beside the model alone is dropped and the label kept whole" || bad "a lead that does not fit beside the model alone is dropped and the label kept whole" "$all_whole"

# 22. A name or type of spaces only is no lead. The harness draws the row's lead as it is, so a name
#     of spaces would put blank space at the start of the row, and choosing it over the agent type
#     would hide the type. Each candidate is stripped once it is cleaned, before one is chosen: row
#     a has a blank name and a type, row b a padded name, row c a blank name and a blank type.
got="$(row '{"columns":120,"tasks":[{"id":"a","name":"   ","agentType":"keel:keel-fanout","description":"inherit: d","model":"m"},{"id":"b","name":" rev ","description":"inherit: d","model":"m"},{"id":"c","name":"  ","agentType":" ","description":"inherit: d","model":"m"}]}')"
want='{"id": "a", "content": "keel:keel-fanout · inherit: d · m"}
{"id": "b", "content": "rev · inherit: d · m"}
{"id": "c", "content": "inherit: d · m"}'
[ "$got" = "$want" ] && ok "a name or type of spaces only gives way to the agent type, or to no lead" || bad "a name or type of spaces only gives way to the agent type, or to no lead" "got: $got"

# 23. A dispatch labelled `keel-implementer: ` is a keel label (ADR-0008), so its row shows the
#     model the profile resolved to. Row b is the control: a description that merely contains the
#     label later on is not one. Without row l the empty output a broken script gives would pass.
got="$(row '{"columns":120,"tasks":[{"id":"l","agentType":"keel:keel-implementer","description":"keel-implementer: task 2","model":"claude-sonnet-5-5","tokenCount":500},{"id":"b","description":"note keel-implementer: task 2","model":"m"}]}')"
want='{"id": "l", "content": "keel:keel-implementer · keel-implementer: task 2 · claude-sonnet-5-5 · 500 tokens"}'
[ "$got" = "$want" ] && ok "a keel-implementer: row shows the model it runs on" || bad "a keel-implementer: row shows the model it runs on" "got: $got"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
