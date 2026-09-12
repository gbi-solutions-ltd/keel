#!/usr/bin/env bash
# Everything keel writes and reads that belongs to Claude Code, and nothing that does not.
#
# THE CONTRACT. Six functions, and lib/harness/codex.sh implements the same six. bin/keel calls
# these and never a writer by name, so adding a harness is a file here rather than a branch there:
#
#   harness_write_config <root>        write this harness's committed configuration
#   harness_write_local_config <root>  write its uncommitted, per-developer configuration
#   harness_permission_rules           print `deny|<rule>` and `ask|<rule>` lines, one per rule
#   harness_recommend_plugins          print the plugin ids this harness should have, one per line
#   harness_config_paths               print the paths this harness owns, one per line
#   harness_doctor_findings            print `level|message` lines for cmd_doctor, zero or more
#
# THE SIXTH EXISTS BECAUSE OF WHAT cmd_doctor DOES. settings_report_load, plugin_report and
# boundary_report are Claude Code readers, and cmd_doctor stays in the neutral file. Under a
# five-function contract cmd_doctor would call functions that exist for one harness only, which
# breaks the moment codex.sh is the loaded one. harness_doctor_findings is the only thing it calls;
# this file implements it over the three readers, and a harness with nothing to report implements
# it as a no-op.
#
# THE BODIES BELOW WERE MOVED, NOT REWRITTEN. Every byte of what `keel init` writes on Claude Code
# is asserted against the pre-refactor commit by tests/test-keel.sh, which builds the baseline from
# a worktree at KEEL_BASELINE_REF rather than from a committed fixture. A tidy-up inside a moved
# function is how that assertion gets broken by accident, so there were none.

# Both reports below read the same settings files, so they are one interpreter start and one parse
# rather than two of each. Filled on the first lookup and never again in this process.
#
# Doctor reads it through two process substitutions, and neither can fill it for the other, so
# cmd_doctor primes it in its own shell first. Same shape as pkg_scripts_load, same reason.
SETTINGS_REPORT=""
SETTINGS_REPORT_LOADED=""

settings_report_load() {
    [ -n "$SETTINGS_REPORT_LOADED" ] && return 0
    have_python || return 0
    SETTINGS_REPORT_LOADED=1
    # No apostrophe anywhere below, and this is now load-bearing: the heredoc sits inside a $( ),
    # and bash 3.2 does not treat a quoted heredoc body as literal there, so one of them swallows
    # the rest of this file and reports the parse error hundreds of lines away. shellcheck does not
    # see it. json_load one file up carries the same warning for the same reason.
    SETTINGS_REPORT="$(KEEL_HERE="$HERE" python3 - <<'PY' 2>/dev/null
import json, os, glob
# Every scope Claude Code merges, in its order. Project scope
# alone was harmless while the fallback list was three plugins nobody enables per project. Once init
# wrote keel@gbi into plugins.recommended it was not: keel is normally enabled at user scope, so
# every project reported it missing, next to the doctor line saying the marketplace is registered,
# and the /plugin install it suggested wrote to the scope this never looked at.
#
# Names are compared whole here. The duplicate check below strips the marketplace suffix because it
# is matching skill names across plugins; the recommended list carries qualified names and so must
# this.
dirs = [d for d in (os.environ.get("CLAUDE_CONFIG_DIR"), os.path.expanduser("~/.claude")) if d]
# Later files win, which is the order Claude Code merges them in.
merged = {}
for p in [os.path.join(d, "settings.json") for d in dirs] + [".claude/settings.json", ".claude/settings.local.json"]:
    try:
        merged.update(json.load(open(p)).get("enabledPlugins", {}))
    except Exception:
        pass
enabled_full = {k for k, v in merged.items() if v}
try:
    plugs = json.load(open(".keel/profile.json")).get("plugins", {})
except Exception:
    plugs = {}
if not isinstance(plugs, dict):
    plugs = {}
# Both lists are checked, elements included, and outside the try on purpose. The except above is
# sized for "the profile does not load", so a TypeError swallowed there would discard the list this
# project wrote and report against the hardcoded three instead. Unchecked they are worse than that.
# A string iterates character by character, so a recommended of "abc" prints missing:a, missing:b,
# missing:c, which doctor renders as three plugins named a, b and c. A non-string element raises
# out of set() past this block entirely, which empties SETTINGS_REPORT and silences the conflict
# and duplicate reports along with this one: before this change a malformed excluded was inert
# because nothing read it, so that failure is one this change would introduce. Nothing validates a
# profile against the schema at runtime. All three measured 2026-09-08.
def _names(v):
    return [x for x in v if isinstance(x, str)] if isinstance(v, list) else None
rec = _names(plugs.get("recommended"))
exc = set(_names(plugs.get("excluded")) or [])
if not rec:
    rec = ["security-guidance@claude-plugins-official",
           "code-review@claude-plugins-official",
           "skill-creator@claude-plugins-official"]
# Excluded is subtracted AFTER the fallback, never before. Before it, a project that excluded every
# plugin on its own recommended list would empty rec, hit `if not rec`, and be handed the hardcoded
# three back: the exclusion would produce the opposite of what it asked for.
#
# Excluded wins over recommended because it is the later and more specific decision: a team lists a
# plugin here after deciding against one a curated recommended list still carries. Dropped silently
# rather than reported, since a project that wrote the exclusion does not need telling about it.
#
# keel itself is the one exception. Every other name here warns that a skill degrades to an inline
# fallback; the keel@ branch warns that no keel skill loads at all, which is not the same kind of
# advice, so a project cannot switch it off by listing the name. Decided 2026-09-08.
for r in rec:
    if r in exc and not r.startswith("keel@"):
        continue
    if r not in enabled_full:
        print("missing:" + r)

# Each reason is a sentence a reader can act on. A label ("conflicts") tells nobody what to do.
KNOWN = {
    "feature-dev": "it ships its own explorer, architect and reviewer agents behind a /feature-dev command, covering the same ground as repo-snapshot, design-architecture, write-plan, execute-plan and review-code, and it writes to none of the artifact chain",
    "superpowers": "its using-superpowers skill tells the model to invoke a superpowers skill before any response, which competes directly with the keel router, and it injects its whole methodology at session start",
    "gstack": "it carries its own planning and review workflow plus a session preamble running to several thousand tokens",
}

enabled = {k.split("@")[0] for k in enabled_full}

# What each installed plugin ships, from the cache: <cfg>/plugins/cache/<market>/<plugin>/<version>/skills/<skill>/SKILL.md
shipped = {}
for d in dirs:
    for path in glob.glob(os.path.join(d, "plugins", "cache", "*", "*", "*", "skills", "*", "SKILL.md")):
        parts = path.split(os.sep)
        shipped.setdefault(parts[-5], set()).add(parts[-2])

# Ours comes from the working tree, not from the cache. The cached copy is whatever version was last
# installed, which is routinely older than the CLI and would under-report a brand new collision.
ours = {os.path.basename(os.path.dirname(p))
        for p in glob.glob(os.path.join(os.environ["KEEL_HERE"], "skills", "*", "SKILL.md"))}

for name in sorted(enabled):
    if name in KNOWN:
        print("conflict:%s|%s" % (name, KNOWN[name]))
    if name == "keel":
        continue
    for s in sorted(shipped.get(name, set()) & ours):
        print("dup:%s|%s" % (s, name))
PY
)"
    return 0
}

# Prints "missing:<plugin>" per recommended plugin that is not enabled. Silent when there is nothing
# to say. Conflicts are the other two shapes, which see more than this file does.
plugin_report() {
    settings_report_load
    [ -n "$SETTINGS_REPORT" ] || return 0
    local line
    # The redirect is on the loop, not a pipe, so this runs in the current shell and spawns nothing.
    while IFS= read -r line; do
        case "$line" in missing:*) printf '%s\n' "$line" ;; esac
    done <<< "$SETTINGS_REPORT"
    return 0
}

# Where keel ends and another plugin begins.
#
# Two kinds of collision, and the second is the one no hardcoded list can catch:
#
#   conflict:<plugin>|<why>   a plugin known to ship a competing end-to-end methodology
#   dup:<skill>|<plugin>      any enabled plugin shipping a skill name keel also ships
#
# The duplicate check reads the installed plugin cache rather than a registry, so a plugin nobody
# anticipated surfaces the moment it ships its own `tdd` or `review-code`. Two skills under one name
# is not an error in Claude Code, which is what makes it worth reporting: the model picks one, and
# neither the session nor the transcript records which.
#
# It reports and stops there. Disabling somebody's plugin from a tool they ran to configure a
# repository would be a larger decision than this command is entitled to make, and the conflicting
# plugin may be the deliberate choice.
boundary_report() {
    settings_report_load
    [ -n "$SETTINGS_REPORT" ] || return 0
    local line
    while IFS= read -r line; do
        case "$line" in conflict:*|dup:*) printf '%s\n' "$line" ;; esac
    done <<< "$SETTINGS_REPORT"
    return 0
}

# Committed into the project, not shipped in the plugin. With skills living in the plugin rather
# than the repo, this is the only thing that tells a session without the plugin that a standard
# exists.
#
# It states the condition rather than testing it. A hook registered in a project's settings.json
# receives nothing that names a loaded plugin: CLAUDE_PLUGIN_ROOT is set only for hooks a plugin
# itself defines, and a project hook's environment carries CLAUDE_PROJECT_DIR and no plugin field at
# all. The reader knows its own skill list, so the message asks it to look there.
write_nudge() {
    mkdir -p .claude
    cat > .claude/keel-nudge <<'NUDGE'
#!/usr/bin/env bash
# SessionStart hook, committed to this repository by `keel init`.
#
# A project hook cannot see which plugins a session loaded, so this states the condition and leaves
# the check to the reader. It prints in every session and sits in that session's context, which is
# why it is short.
set -eu

read -r -d '' MSG <<'TXT' || true
If you have no skills named `keel:*`, the keel plugin is not loaded in this session and the rest of
this note applies. If you do have them, ignore it.

This project expects the plugin. Without it its gates on tests, security, and review do not apply,
and .keel/profile.json is what is left: read it before running any test, lint, or build command
rather than assuming the stack's usual one.

Install it:
  /plugin marketplace add gbi-solutions-ltd/keel
  /plugin install keel@gbi

Continuing without it is fine for a small change.
TXT

escape() { local s="$1"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; printf '%s' "$s"; }
printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": "%s"\n  }\n}\n' "$(escape "$MSG")"
NUDGE
    chmod +x .claude/keel-nudge
}

# The guardrails. Both lists are checked in and shared by the team, which is why neither contains
# a permission mode: see write_local_settings for why that stays per-developer.
#
# `deny` and `ask` are the only instruments that still work once a session is in bypassPermissions
# mode. Verified against a live session rather than taken from the documentation: a denied Read
# and an asked Bash command both held while an ordinary write went through unprompted. Allow rules
# have no effect in that mode, so protection expressed as an allowlist is not protection at all.
#
# deny is for what is never legitimate for an agent to do in a repository. Reading a secret is on
# that list because the secret then lives in the transcript, and because settings files in the
# wild already contain pasted production passwords.
#
# THE READ RULES DO NOT COVER BASH, and that is worth knowing rather than discovering. A `Read` deny
# matches the Read tool only, so `cat .env` reaches the same bytes through a different door. Found
# when a subagent working under these exact rules reported .env contents it had obtained via Bash.
#
# The Bash entries below close the common shapes. They are defence in depth and not a boundary: a
# command string cannot be matched exhaustively, and `sh -c`, `xargs`, `env`, a python one-liner or a
# here-doc all get past them. Treat a secret in the working tree as reachable by any agent that can
# run commands, and keep the real secrets out of the tree.
keel_deny_rules() {
    cat <<'R'
Read(./.env)
Read(./.env.*)
Read(./secrets/**)
Read(./**/*.pem)
Read(./**/id_rsa*)
Bash(cat *.env*)
Bash(cat *secrets/*)
Bash(cat *id_rsa*)
Bash(head *.env*)
Bash(tail *.env*)
Bash(less *.env*)
Bash(more *.env*)
Bash(strings *.env*)
R
}

# ask is for what is destructive but sometimes right. It restores the prompt for exactly those
# commands and leaves everything else flowing, which is the whole point of pairing it with bypass
# mode. Rebasing a feature branch and force-pushing it is normal work; doing it without a human
# reading the command first is not.
#
# Deliberately not here: a recursive delete rooted at the filesystem root or at the home directory,
# which Claude Code already circuit-breaks in every mode. A rule that duplicates a built-in check
# reads as protection while adding none.
#
# The last three are the egress rules, and they guard a different thing from the rest of the list.
# Everything above destroys something the user can see is gone. These send something out, and the
# loss is silent: whatever a session can read, it can post. Decision 12 in docs/07-open-decisions.md
# recorded that gap when it accepted the bypassPermissions default, and this closes it. The vendor's
# own hardening guidance names denying these commands as the way to do it; ask rather than deny,
# because fetching a page is ordinary work and a prompt is enough to make it a decision.
#
# THESE ARE NOT AN EGRESS BOUNDARY, for the same reason the Bash entries in the deny list are not a
# read boundary. Not covered, and not an exhaustive list of what is not covered: a remote shell or
# file copy over ssh, a git push to a remote nobody looked at, a python or node one-liner opening a
# socket, and any of those reached through sh -c or xargs. A machine that must not talk to the
# internet needs a sandbox or a firewall, not a rule list.
keel_ask_rules() {
    cat <<'R'
Bash(git push --force*)
Bash(git push -f *)
Bash(git reset --hard*)
Bash(git clean *)
Bash(git branch -D *)
Bash(terraform apply*)
Bash(terraform destroy*)
Bash(kubectl delete *)
Bash(docker system prune*)
Bash(npm publish*)
R
    # The egress three are emitted rather than written into the heredoc above, because a heredoc
    # line cannot carry a scanner suppression: its text is the rule, so a trailing comment would
    # land inside the rule string. supply-chain-scan reads this file as an executable and its
    # net-in-script rule cannot tell a command named in a permission rule from one being run, which
    # is the same false positive the two test files already suppress.
    printf 'Bash(%s *)\n' curl wget nc  # supply-chain-scan: allow these name the commands to prompt for, nothing here runs them
}

# No extraKnownMarketplaces here, deliberately. A marketplace source says where this reader gets
# keel from, which is a fact about their machine and not about the project, so a committed file
# asserting one is wrong for everyone whose answer differs: a reader outside the GitHub org cannot
# reach a private repo, and at project scope the declaration shadows whatever the reader chose at
# user level. Every @claude-plugins-official plugin below is enabled without one and resolves fine.
# Doctor names the install command when the marketplace is absent, and so does the nudge.
#
# That paragraph is about write_settings, two functions below. expected_plugins comes first because
# both writers read it.

# The plugin set this project expects, one name per line, marketplace-qualified.
#
# Both writers read this: write_settings enables them in .claude/settings.json on a fresh repository,
# and write_profile records them in plugins.recommended so doctor can report what is missing. They
# were two lists for one turn of this change and immediately disagreed: the profile carried only the
# language servers, so doctor stopped naming the five official plugins it had always named, and an
# existing assertion caught it. One definition, read twice.
expected_plugins() {
    printf 'keel@gbi\n'
    for p in security-guidance code-review skill-creator claude-md-management context7 $(detect_plugins); do
        printf '%s@claude-plugins-official\n' "$p"
    done
}

write_settings() {
    mkdir -p .claude
    if [ -f .claude/settings.json ]; then
        merge_permissions_into_settings
        return 0
    fi
    {
      printf '{\n  "enabledPlugins": {'
      local first_plugin=1 ep
      while IFS= read -r ep; do
          [ -n "$ep" ] || continue
          [ $first_plugin -eq 1 ] && first_plugin=0 || printf ','
          printf '\n    "%s": true' "$ep"
      done <<EOF_PLUGINS
$(expected_plugins)
EOF_PLUGINS
      printf '\n  },\n'
      printf '  "permissions": {\n    "deny": '
      keel_deny_rules | json_rule_array
      printf ',\n    "ask": '
      keel_ask_rules | json_rule_array
      printf '\n  },\n'
      printf '  "hooks": {\n    "SessionStart": [\n      {\n        "matcher": "startup|clear",\n'
      printf '        "hooks": [ { "type": "command", "command": "./.claude/keel-nudge", "shell": "bash" } ]\n'
      printf '      }\n    ]\n  }\n}\n'
    } > .claude/settings.json
}

# An existing settings.json is the common case on a mature repo, and it is exactly the case that
# most needs the guardrails. Add only what is missing: rules the project already lists are left
# alone, and nothing else in the file is touched.
merge_permissions_into_settings() {
    have_python || { err "python3 absent: could not add permission guardrails to the existing .claude/settings.json. Add them by hand, or delete the file and re-run."; return 0; }
    local deny ask
    deny="$(keel_deny_rules)"; ask="$(keel_ask_rules)"
    DENY="$deny" ASK="$ask" python3 - <<'PY'
import json, os
p = ".claude/settings.json"
try:
    d = json.load(open(p))
except Exception as e:
    raise SystemExit(f"keel: {p} is not valid JSON ({e}); leaving it alone")
perms = d.setdefault("permissions", {})
added = 0
for key, env in (("deny", "DENY"), ("ask", "ASK")):
    have = perms.setdefault(key, [])
    for rule in os.environ[env].splitlines():
        if rule and rule not in have:
            have.append(rule); added += 1
if added:
    json.dump(d, open(p, "w"), indent=2); open(p, "a").write("\n")
    print(f"  added {added} permission guardrail(s) to .claude/settings.json")
PY
}

# The permission mode is per-developer and stays out of version control, deliberately.
#
# A committed file that sets bypassPermissions turns off every prompt for anyone who clones the
# repository, before they have read a line of it. The split stops that: the shared file carries the
# guardrails, the local file carries the mode, and the mode never reaches anyone else's machine.
#
# Be accurate about what it does not do. keel picks this default and the engineer overrides it, so
# this is keel's call for the machine it is run on, announced in init's summary, not a choice each
# engineer makes unprompted. Recorded as decision 12 in docs/07-open-decisions.md with the residual
# it accepts. Claude Code merges both files and the deny and ask rules still apply under the mode,
# verified twice and cited there, which is what makes the split cost nothing.
write_local_settings() {
    mkdir -p .claude
    local f=.claude/settings.local.json
    if [ ! -f "$f" ]; then
        printf '{\n  "permissions": {\n    "defaultMode": "bypassPermissions"\n  }\n}\n' > "$f"
        return 0
    fi
    # Never clobber this file. It accumulates a developer's own allow rules over months of work,
    # and losing them is worse than not setting the mode.
    have_python || { err "python3 absent: left $f alone. Set permissions.defaultMode by hand if you want bypass mode."; return 0; }
    python3 - <<'PY'
import json
p = ".claude/settings.local.json"
try:
    d = json.load(open(p))
except Exception as e:
    raise SystemExit(f"keel: {p} is not valid JSON ({e}); leaving it alone")
perms = d.setdefault("permissions", {})
if "defaultMode" not in perms:
    perms["defaultMode"] = "bypassPermissions"
    json.dump(d, open(p, "w"), indent=2); open(p, "a").write("\n")
    print("  set permissions.defaultMode in .claude/settings.local.json")
PY
}

# ---- the contract ----------------------------------------------------------
#
# Thin on purpose. Each one names the writers above rather than inlining them, so the diff that
# moved them is readable and the bodies stay comparable with the pre-refactor file.

# The context file this harness reads. AGENTS.md is deliberately NOT here: keel writes it for every
# repository because Cursor, Copilot CLI and Gemini CLI read it too, so it is neutral ground rather
# than one harness's file. CLAUDE.md is Claude Code's alone.
harness_context_file() {
    printf 'CLAUDE.md\n'
}

harness_write_config() {
    write_nudge
    write_settings
}

harness_write_local_config() {
    write_local_settings
}

# One line per rule, kind first, so a caller can count or print either without knowing that this
# harness happens to keep them in two functions.
harness_permission_rules() {
    keel_deny_rules | sed 's/^/deny|/'
    keel_ask_rules  | sed 's/^/ask|/'
}

harness_recommend_plugins() {
    expected_plugins
}

# `committed|<path>` and `local|<path>`, because the two are used for opposite purposes: the
# committed one is staged and reported, the local one is git-ignored precisely so it is not. One
# function rather than two, matching harness_permission_rules, so a caller that wants both makes one
# call and a caller that wants one filters.
harness_config_paths() {
    printf 'committed|.claude/settings.json\n'
    printf 'local|.claude/settings.local.json\n'
}

# The directories those paths live in, for the one caller that stages a tree rather than a file.
# Derived rather than listed, so it cannot disagree with harness_config_paths.
harness_config_dirs() {
    harness_config_paths | sed 's/^[a-z]*|//' | sed -n 's|/[^/]*$||p' | sort -u
}

# `level|message`, where level is `ok`, `warn` or `fail`, matching cmd_doctor's three reporters.
# Nothing here decides whether to print or in what order: doctor owns the ordering, the formatting
# and the counters; this owns the harness knowledge.
#
# IT TAKES A PHASE, and that is not decoration either. cmd_doctor's Claude Code checks are
# INTERLEAVED with neutral ones: the plugin set, then the context watchdog, then the guardrails,
# then the handoff, then the editor. Emitting every harness finding at one call point would group
# them together and reorder a report people read top to bottom, which R-01 forbids as surely as
# changing what init writes. The phases are doctor's own sections and mean nothing harness-specific;
# a harness with nothing to say in one returns nothing, which is what codex.sh does for all of them.
harness_doctor_findings() {
    case "${1:-}" in
        prime)        settings_report_load ;;
        plugins)      _claude_doctor_plugins ;;
        boundaries)   _claude_doctor_boundaries ;;
        context-block) _claude_doctor_context_block ;;
        permissions)  _claude_doctor_permissions ;;
        local-state)  _claude_doctor_local_state ;;
        editor)       _claude_doctor_editor ;;
        marketplace)  _claude_doctor_marketplace ;;
        *)            : ;;
    esac
}

# Plugin set. Advisory in both directions: a missing plugin degrades a skill rather than breaking
# it, and feature-dev being present may be a deliberate choice. Specified in docs/04 and found
# unwritten by a sweep of the plan against the repository.
_claude_doctor_plugins() {
    [ -f .claude/settings.json ] && have_python || return 0
    local line
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        case "$line" in
          missing:keel@*)
                      printf 'warn|keel itself is not enabled here: %s. Install it with '"'"'/plugin install %s'"'"'. Without it no keel skill loads at all, which is not a degraded mode.\n' "${line#missing:}" "${line#missing:}" ;;
          missing:*)  printf 'warn|recommended plugin not enabled: %s. Install it with '"'"'/plugin install %s'"'"'. The skill that uses it degrades to an inline fallback.\n' "${line#missing:}" "${line#missing:}" ;;
        esac
    done < <(plugin_report)
}

# Boundaries. Advisory by design: a competing plugin may be a deliberate choice, and nothing here
# disables one on somebody's behalf. What it does is make the collision visible, because the failure
# mode is silent. Two plugins answering to one skill name produce a session that picks one
# arbitrarily and never says so, which reads as the skill behaving inconsistently.
_claude_doctor_boundaries() {
    have_python || return 0
    local line t
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        case "$line" in
          conflict:*)
            t="${line#conflict:}"
            printf 'warn|%s is enabled alongside keel: %s. Running both means two answers to '"'"'which methodology applies'"'"'. Disable one for this project, or accept it deliberately. See docs/04.\n' "${t%%|*}" "${t#*|}" ;;
          dup:*)
            t="${line#dup:}"
            printf 'warn|both keel and %s ship a skill named '"'"'%s'"'"'. Claude Code does not error on this: it picks one and does not record which, so the skill will look inconsistent rather than broken. Disable one plugin for this project.\n' "${t#*|}" "${t%%|*}" ;;
        esac
    done < <(boundary_report)
}

# Estimated at chars/3.6 rather than counted. The count-tokens endpoint needs an API key, and a
# budget check that only works where a key happens to be configured is a budget check that is
# absent exactly where nobody is watching. The estimate is within a few percent, which is all a
# ceiling this coarse requires.
_claude_doctor_context_block() {
    [ -f CLAUDE.md ] || return 0
    local blk_chars blk_tokens
    # awk counts it rather than printing it for `wc -c` to count: same number, one process
    # instead of three. The +1 per line is the newline the old pipeline's print emitted.
    blk_chars=$(awk '/keel:start/,/keel:end/{c+=length($0)+1} END{print c+0}' CLAUDE.md)
    blk_tokens=$(( blk_chars * 10 / 36 ))
    if [ "$blk_tokens" -gt 700 ]; then
        printf 'fail|the CLAUDE.md keel block is about %s tokens, over the 700 ceiling. It is in the prefix of every request here. Move detail into the docs root, which loads on demand.\n' "$blk_tokens"
    elif [ "$blk_tokens" -gt 450 ]; then
        printf 'warn|the CLAUDE.md keel block is about %s tokens, over the 450 target though under the 700 ceiling.\n' "$blk_tokens"
    else
        printf 'ok|CLAUDE.md keel block is about %s tokens, within budget\n' "$blk_tokens"
    fi
}

# Permission guardrails. These are what make a bypassPermissions default defensible, so their
# absence is a real finding rather than an advisory: deny and ask are the only rules that still
# apply once prompts are off.
_claude_doctor_permissions() {
    [ -f .claude/settings.json ] && have_python || return 0
    local missing_rules
    missing_rules="$(DENY="$(keel_deny_rules)" ASK="$(keel_ask_rules)" python3 - <<'PYP' 2>/dev/null
import json, os
try:
    perms = json.load(open(".claude/settings.json")).get("permissions", {})
except Exception:
    raise SystemExit(0)
missing = [r for key, env in (("deny", "DENY"), ("ask", "ASK"))
           for r in os.environ[env].splitlines()
           if r and r not in perms.get(key, [])]
print(len(missing))
PYP
)"
    if [ "${missing_rules:-0}" -eq 0 ] 2>/dev/null; then
        printf 'ok|permission guardrails present in .claude/settings.json\n'
    else
        printf 'fail|%s permission guardrail(s) missing from .claude/settings.json. Re-run '"'"'keel init'"'"' to add them. They are the only protection that survives bypassPermissions mode.\n' "$missing_rules"
    fi
}

# The local file must stay out of git: it sets a permission mode, and committing it turns off
# prompts for everyone who clones rather than for the one person who chose it.
_claude_doctor_local_state() {
    [ -f .claude/settings.local.json ] && git rev-parse --git-dir >/dev/null 2>&1 || return 0
    if repo_ignores .claude/settings.local.json; then
        printf 'ok|.claude/settings.local.json is git-ignored\n'
    else
        printf 'fail|.claude/settings.local.json is not git-ignored. It carries a permission mode; committing it imposes that mode on everyone who clones. Add it to .gitignore.\n'
    fi
}

# Advisory, and the answer to "I set defaultMode and nothing happened". A session the VS Code
# extension starts resolves its own starting mode and ignores defaultMode from every settings
# file. Two extension settings are needed instead, and neither lives in this repository.
_claude_doctor_editor() {
    [ -f .claude/settings.local.json ] && ls -d "$HOME"/.vscode/extensions/anthropic.claude-code-* >/dev/null 2>&1 || return 0
    local vs="$HOME/Library/Application Support/Code/User/settings.json"
    [ -f "$vs" ] || vs=""
    if [ -n "$vs" ] && grep -q '"claudeCode.initialPermissionMode"' "$vs" 2>/dev/null; then
        printf 'ok|the VS Code extension has its own initial permission mode set\n'
    else
        printf 'warn|the Claude Code VS Code extension is installed. Sessions it starts ignore permissions.defaultMode from settings files, so this project'"'"'s mode applies only to CLI sessions. To match it in the extension, set claudeCode.allowDangerouslySkipPermissions and claudeCode.initialPermissionMode in VS Code user settings.\n'
    fi
}


# The gbi marketplace's freshness. Hardcoded rather than a profile field: a new field bumps
# SCHEMA_VERSION, and the comment on that constant says to move it only when a field changes,
# precisely so a release that changed nothing else does not warn everybody.
#
# The body is at cmd_doctor's indentation, not this file's, and deliberately so: the `python3 -c`
# string below carries its own Python indentation, and re-indenting the shell around it silently
# de-indented `sys.exit(1)` out of its `if`. Python then failed, `age` came back empty, and doctor
# reported the marketplace as not registered on a machine where it is. Caught by the doctor baseline
# comparison in tests/test-keel.sh, which is the only thing that would have.
_claude_doctor_marketplace() {
    local found="" cfg age="" stale_days=7
    for cfg in "${CLAUDE_CONFIG_DIR:-}" "$HOME/.claude"; do
        # Two separate guards rather than `A && B || continue`. That shorthand is not if-then-else
        # and shellcheck 0.9.0, the release CI installs, says so as SC2015; 0.11.0 no longer does,
        # so the file linted clean on every laptop and failed the pipeline on 2026-09-07. Written
        # out, it also reads as what it means: skip an unset directory, then skip one with no
        # marketplace file.
        [ -n "$cfg" ] || continue
        [ -f "$cfg/plugins/known_marketplaces.json" ] || continue
        age="$(MP="$cfg/plugins/known_marketplaces.json" python3 -c "
import json, os, sys, datetime
d = json.load(open(os.environ['MP']))
# The same selection the registration check used, kept identical so the two reports can never mean
# different entries in the same file.
hits = [v for v in d.values() if 'keel' in json.dumps(v)]
if not hits:
    sys.exit(1)
ts = hits[0].get('lastUpdated')
if isinstance(ts, str):
    try:
        t = datetime.datetime.fromisoformat(ts.replace('Z', '+00:00'))
        now = datetime.datetime.now(datetime.timezone.utc)
        # Clamped at zero. A clock skewed forward yields a negative age, which is not a fresh clone
        # and must never print as one. It reads as today and the next run corrects it.
        print(max(0, (now - t).days))
    except ValueError:
        pass
" 2>/dev/null)" \
          && { found="$cfg"; break; }
    done
    if have_python; then
        if [ -z "$found" ]; then
            printf 'warn|%s\n' "the gbi marketplace is not registered on this machine, so a session here has no keel skills. Run '/plugin marketplace add gbi-solutions-ltd/keel' then '/plugin install keel@gbi'."
        else
            printf 'ok|%s\n' "the gbi marketplace is registered ($found)"
            case "$age" in
                ''|*[!0-9]*)
                    printf 'warn|%s\n' "cannot tell how fresh the gbi marketplace list is: known_marketplaces.json in $found records no usable lastUpdated. That is unknown, not current. Run '/plugin marketplace update gbi' then '/plugin install keel@gbi' to set it." ;;
                *)
                    if [ "$age" -ge "$stale_days" ]; then
                        printf 'warn|%s\n' "the gbi marketplace list was last fetched $age days ago, so a newer keel may have been released since and nothing on this machine would know. Run '/plugin marketplace update gbi' then '/plugin install keel@gbi'."
                    else
                        printf 'ok|%s\n' "the gbi marketplace list was fetched $age day(s) ago, recent enough not to warn. That is fetch age and not currency: a release landing since then is not visible here either."
                    fi ;;
            esac
        fi
    fi
}
