#!/usr/bin/env bash
# Tests for bin/keel, part 5 of 5: schema enums, guard status, moving and coexisting with other
# hooks, the slow suite warning, and the interpreter budget. Shared helpers and fixtures are in
# tests/keel-test-lib.sh, which says why SC2015 is safe here.
#
# Run from the repository root.

# shellcheck disable=SC2015
# shellcheck disable=SC2016
set -uo pipefail; . "$(dirname "${BASH_SOURCE[0]}")/grep-quiet.sh"
# shellcheck source=tests/keel-test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/keel-test-lib.sh"

# ---- profile set checks a value against the schema's enum ---------------------------------------
# A gate holding a typo reads as a weaker gate: hooks/done-guard treats anything that is not `off`
# or `required` as `warn`. So a value the schema does not list is refused where it is typed.
pe="$(fixture node-ts)"
( cd "$pe" && "$KEEL" init -y >/dev/null 2>&1 )
out="$( cd "$pe" && "$KEEL" profile set gates.done_verified requird 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && ok "profile set refuses a gate value outside the schema enum" \
  || bad "profile set enum" "exit $rc for gates.done_verified requird"
case "$out" in
  *required*warn*off*) ok "the enum refusal names the accepted values" ;;
  *) bad "profile set enum" "refusal did not list required, warn, off: '$out'" ;;
esac
got="$(prof_of "$pe" gates.done_verified)"
[ "$got" = "warn" ] && ok "the refused enum value was not written" \
  || bad "profile set enum" "gates.done_verified is '$got', not the init default warn"
( cd "$pe" && "$KEEL" profile set gates.done_verified required >/dev/null 2>&1 ) \
  && ok "profile set still accepts a value the enum lists" \
  || bad "profile set enum" "refused gates.done_verified required"
( cd "$pe" && "$KEEL" profile set project.kind null >/dev/null 2>&1 ) \
  && ok "profile set still accepts null on an enum key, which clears it" \
  || bad "profile set enum" "refused null for project.kind"
rm -rf "$pe"

# ---- doctor fails a value outside the schema's enum ---------------------------------------------
# profile set now refuses one, but a hand edit or an older keel can still write it, and doctor is
# where a project is told its profile means something other than it reads.
de="$(fixture node-ts)"
( cd "$de" && "$KEEL" init -y >/dev/null 2>&1 )
seed_standards "$de"
out="$( cd "$de" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"which is not one of"*) bad "doctor enum" "a fresh init profile was reported out of enum: $out" ;;
  *) ok "doctor reports no enum problem on a profile init wrote" ;;
esac
python3 - "$de/.keel/profile.json" <<'PY'
import json, sys
p = json.load(open(sys.argv[1]))
p["gates"]["security_audit"] = "reqired"
json.dump(p, open(sys.argv[1], "w"), indent=2)
PY
out="$( cd "$de" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"FAIL  gates.security_audit is 'reqired', which is not one of required, warn, off"*)
    ok "doctor fails a gate value outside the schema enum" ;;
  *) bad "doctor enum" "no FAIL for gates.security_audit: $(printf '%s\n' "$out" | grep -n security_audit)" ;;
esac
# The weaker-gate clause is true only of a gate: said of project.kind or a convention it tells the
# reader something enforces less when nothing enforces that key at all.
case "$(printf '%s\n' "$out" | grep 'gates.security_audit is')" in
  *"for a gate that means a weaker one"*) ok "doctor's enum FAIL on a gate says it reads as a weaker one" ;;
  *) bad "doctor enum" "the gate FAIL lost its weaker-gate clause: $(printf '%s\n' "$out" | grep security_audit)" ;;
esac
python3 - "$de/.keel/profile.json" <<'PY'
import json, sys
p = json.load(open(sys.argv[1]))
p["gates"]["security_audit"] = "required"
p["conventions"]["response_style"] = "tersee"
json.dump(p, open(sys.argv[1], "w"), indent=2)
PY
out="$( cd "$de" && "$KEEL" doctor --fast 2>&1 )"
line="$(printf '%s\n' "$out" | grep 'conventions.response_style is' || true)"
case "$line" in
  *"for a gate"*) bad "doctor enum" "a non-gate key's FAIL claims a weaker gate: $line" ;;
  *"FAIL  conventions.response_style is 'tersee', which is not one of terse, verbose"*"keel profile set conventions.response_style"*)
    ok "doctor's enum FAIL on a non-gate key names no gate" ;;
  *) bad "doctor enum" "no FAIL for conventions.response_style: $line" ;;
esac

# A schema doctor cannot read means the enum check did not run, and saying only "profile parses"
# reads as a profile that passed it. A copy of keel with its schema removed stands in for a broken
# install, since doctor resolves the schema from its own directory and the repo's must stay intact.
dk="$(mktemp -d)"
cp -R "$ROOT/bin" "$ROOT/lib" "$ROOT/templates" "$ROOT/VERSION" "$dk/"
rm "$dk/templates/profile.schema.json"
out="$( cd "$de" && "$dk/bin/keel" doctor --fast 2>&1 )"
case "$out" in
  *"WARN  the profile schema at"*"could not be read"*) ok "doctor warns when the profile schema cannot be read" ;;
  *) bad "doctor noschema" "no WARN for an unreadable schema: $out" ;;
esac
case "$out" in
  *"FAIL  "*"which is not one of"*) bad "doctor noschema" "an enum FAIL with no schema: $out" ;;
  *"FAIL  "*"could not check the profile"*) bad "doctor noschema" "the noschema line was read as an error: $out" ;;
  *) ok "doctor raises no enum FAIL when the schema cannot be read" ;;
esac
rm -rf "$dk"
rm -rf "$de"

# ---- generated CI triggers on the recorded default branch ---------------------------------------
# write_ci hardcoded `branches: [main]`, so a master repository got a workflow that never ran on a
# push to its own default branch, while the profile beside it said master.
mb="$(mktemp -d)"
( cd "$mb" && git init -q -b master . && git config user.email t@t.t && git config user.name t \
  && printf '{"name":"f","scripts":{"test":"jest"}}\n' > package.json \
  && git add package.json && git commit -qm init && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(prof_of "$mb" conventions.default_branch)" = master ] \
  || bad "write_ci branch" "fixture precondition: profile did not record master"
grep -q 'branches: \[master\]' "$mb/.github/workflows/ci.yml" \
  && ok "generated CI runs on the default branch the profile records" \
  || bad "write_ci branch" "workflow trigger: $(grep -n 'branches' "$mb/.github/workflows/ci.yml")"
rm -rf "$mb"

# The same master repository with python3 unavailable (the Windows Store alias shim, which
# have_python reads as absent). write_ci reads the branch through json_get, which needs python3,
# while write_profile records it with printf, so the profile said master and the workflow fell
# back to main.
mbn="$(mktemp -d)"
storeshim4="$(mktemp -d)"
cat > "$storeshim4/python3" <<'SHIM'
#!/bin/sh
printf 'Python was not found; run without arguments to install from the Microsoft Store.\n'
exit 49
SHIM
chmod +x "$storeshim4/python3"
( cd "$mbn" && git init -q -b master . && git config user.email t@t.t && git config user.name t \
  && printf '{"name":"f","scripts":{"test":"jest"}}\n' > package.json \
  && git add package.json && git commit -qm init \
  && PATH="$storeshim4:$PATH" "$KEEL" init -y >/dev/null 2>&1 )
[ "$(prof_of "$mbn" conventions.default_branch)" = master ] \
  || bad "write_ci branch" "fixture precondition without python3: profile did not record master"
grep -q 'branches: \[master\]' "$mbn/.github/workflows/ci.yml" \
  && ok "generated CI runs on the recorded default branch without python3" \
  || bad "write_ci branch" "workflow trigger without python3: $(grep -n 'branches' "$mbn/.github/workflows/ci.yml")"
rm -rf "$mbn" "$storeshim4"

# ---- doctor reports whether the push guard is installed ------------------------------------------
# protect_default_branch is true by default and only the push guard enforces it outside a session,
# and init does not install the guard. Nothing said so until this line.
pg="$(fixture node-ts)"
( cd "$pg" && "$KEEL" init -y >/dev/null 2>&1 )
seed_standards "$pg"
out="$( cd "$pg" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"WARN  conventions.protect_default_branch is not false and the push guard is not installed"*)
    ok "doctor warns when the push guard is not installed" ;;
  *) bad "doctor guard" "no guard warning without an install: $(printf '%s\n' "$out" | grep -in guard)" ;;
esac
( cd "$pg" && "$KEEL" guard install >/dev/null 2>&1 )
out="$( cd "$pg" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"ok    push guard installed"*) ok "doctor reports an installed push guard as ok" ;;
  *) bad "doctor guard" "no ok line after guard install: $(printf '%s\n' "$out" | grep -in guard)" ;;
esac
rm -rf "$pg"

# The hook protects on anything that is not false, the absent key included (the schema default is
# true), so doctor must report the guard on exactly those values: a line that stays quiet where the
# hook refuses, or speaks where it allows, describes a guard that is not the one installed.
pg="$(fixture node-ts)"
( cd "$pg" && "$KEEL" init -y >/dev/null 2>&1 )
seed_standards "$pg"
( cd "$pg" && "$KEEL" profile set conventions.protect_default_branch false >/dev/null 2>&1 )
out="$( cd "$pg" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"push guard"*) bad "doctor guard" "a guard line with protect_default_branch false: $(printf '%s\n' "$out" | grep -in 'push guard')" ;;
  *) ok "doctor says nothing about the push guard when protect_default_branch is false" ;;
esac
python3 -c "import json;p='$pg/.keel/profile.json';j=json.load(open(p));del j['conventions']['protect_default_branch'];json.dump(j,open(p,'w'),indent=2)"
out="$( cd "$pg" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"WARN  conventions.protect_default_branch is not false and the push guard is not installed"*)
    ok "doctor warns about the push guard when protect_default_branch is absent, as the hook enforces it" ;;
  *) bad "doctor guard" "no guard warning with the key absent: $(printf '%s\n' "$out" | grep -in 'push guard')" ;;
esac
# The hook's sed reads the string "false" as empty and refuses the push, so doctor must warn. This
# pins the sed read: a json_get read with `!= false` passes the cases above and prints nothing here.
python3 -c "import json;p='$pg/.keel/profile.json';j=json.load(open(p));j['conventions']['protect_default_branch']='false';json.dump(j,open(p,'w'),indent=2)"
out="$( cd "$pg" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"WARN  conventions.protect_default_branch is not false and the push guard is not installed"*)
    ok "doctor warns about the push guard when protect_default_branch is the string \"false\", as the hook enforces it" ;;
  *) bad "doctor guard" "no guard warning with the key the string \"false\": $(printf '%s\n' "$out" | grep -in 'push guard')" ;;
esac
rm -rf "$pg"

# ---- the message hook honours conventions.no_attribution_footers ---------------------------------
# A trailer is a footer, and a repository that declares it wants none gets none.
nf="$(fixture bare)"
( cd "$nf" && "$KEEL" init -y >/dev/null 2>&1 && "$KEEL" guard install >/dev/null 2>&1 )
# Without the hook the case below passes over nothing, so its absence is a failure of its own.
[ -x "$nf/.git/hooks/prepare-commit-msg" ] \
  || bad "no footers" "fixture precondition: guard install wrote no prepare-commit-msg hook"
python3 - "$nf/.keel/profile.json" <<'PY'
import json, sys
p = json.load(open(sys.argv[1]))
p["conventions"]["no_attribution_footers"] = True
json.dump(p, open(sys.argv[1], "w"), indent=2)
PY
( cd "$nf" && git add -A && git commit -q -m "no footer wanted" )
# Both halves can pass the case below over nothing: with no hooks path the hook never runs, and a
# commit that failed leaves the fixture's own init commit on top, which carries no trailer either.
[ -z "$(git -C "$nf" config core.hooksPath)" ] \
  || bad "no footers" "fixture precondition: core.hooksPath is set, so .git/hooks does not run"
[ "$(git -C "$nf" log -1 --format=%s)" = "no footer wanted" ] \
  || bad "no footers" "fixture precondition: the commit did not happen"
msg="$( cd "$nf" && git log -1 --format=%B )"
case "$msg" in
  *Keel-Version*) bad "no footers" "the trailer was added although no_attribution_footers is true: $msg" ;;
  *) ok "the message hook adds no trailer when conventions.no_attribution_footers is true" ;;
esac
rm -rf "$nf"

# ---- guard status says what the message hook will do -------------------------------------------
# The message guard line must describe the hook as installed, and a hook body is fixed at install
# time: one written before the hook read conventions.no_attribution_footers still adds the trailer.
gs="$(fixture bare)"
( cd "$gs" && "$KEEL" init -y >/dev/null 2>&1 && "$KEEL" guard install >/dev/null 2>&1 )
# Without the hook or the hooks path, status never reaches the message guard line and the cases
# below fail for a reason they do not name, so each absence is a failure of its own.
[ -x "$gs/.git/hooks/prepare-commit-msg" ] \
  || bad "guard status" "fixture precondition: guard install wrote no prepare-commit-msg hook"
[ -z "$(git -C "$gs" config core.hooksPath)" ] \
  || bad "guard status" "fixture precondition: core.hooksPath is set, so .git/hooks does not run"
# The first case is about the key absent, so a profile that already carries it proves nothing.
! grep -q no_attribution_footers "$gs/.keel/profile.json" \
  || bad "guard status" "fixture precondition: a fresh profile already carries no_attribution_footers"
mg="$( cd "$gs" && "$KEEL" guard status 2>&1 | grep '^message guard:' )"
[ "$mg" = "message guard: active. commits get a Keel-Version trailer" ] \
  && ok "guard status keeps the Keel-Version trailer line when conventions.no_attribution_footers is absent" \
  || bad "guard status" "with the key absent the message guard line was: $mg"
python3 - "$gs/.keel/profile.json" <<'PY'
import json, sys
p = json.load(open(sys.argv[1]))
p["conventions"]["no_attribution_footers"] = True
json.dump(p, open(sys.argv[1], "w"), indent=2)
PY
mg="$( cd "$gs" && "$KEEL" guard status 2>&1 | grep '^message guard:' )"
case "$mg" in
  *"adds no trailer"*) ok "guard status says the message guard adds no trailer when conventions.no_attribution_footers is true" ;;
  *) bad "guard status" "with the key true the message guard line was: $mg" ;;
esac
# A hook body from before the key: the same file with every line that reads the key taken out.
sed '/no_attribution_footers/d;/footers/d' "$gs/.git/hooks/prepare-commit-msg" > "$gs/old-hook"
cat "$gs/old-hook" > "$gs/.git/hooks/prepare-commit-msg"
rm -f "$gs/old-hook"
[ -x "$gs/.git/hooks/prepare-commit-msg" ] \
  || bad "guard status" "fixture precondition: the replaced hook is not executable"
! grep -q no_attribution_footers "$gs/.git/hooks/prepare-commit-msg" \
  || bad "guard status" "fixture precondition: the replaced hook still reads no_attribution_footers"
mg="$( cd "$gs" && "$KEEL" guard status 2>&1 | grep '^message guard:' )"
case "$mg" in
  *"installed before conventions.no_attribution_footers"*"Re-run 'keel guard install'"*)
    ok "guard status tells a hook from before conventions.no_attribution_footers to be reinstalled" ;;
  *) bad "guard status" "with an old hook and the key true the message guard line was: $mg" ;;
esac
rm -rf "$gs"

# ---- guard status says what the push hook scans ------------------------------------------------
# A hook body is fixed at install time, and one written before `keel scan --push` scans the working
# tree, not the commits being pushed. status called it active all the same.
gs="$(fixture bare)"
( cd "$gs" && "$KEEL" guard install >/dev/null 2>&1 )
pg="$( cd "$gs" && "$KEEL" guard status 2>&1 | grep '^push guard:' )"
[ "$pg" = "push guard: active" ] \
  && ok "guard status calls a hook that scans the pushed commits active" \
  || bad "guard status" "with a current hook the push guard line was: $pg"
# A hook body from before --push: the same file with every line that runs it taken out.
sed '/scan --push/d' "$gs/.git/hooks/pre-push" > "$gs/old-hook"
cat "$gs/old-hook" > "$gs/.git/hooks/pre-push"
rm -f "$gs/old-hook"
pg="$( cd "$gs" && "$KEEL" guard status 2>&1 | grep '^push guard:' )"
case "$pg" in
  *"scans the working tree"*"Re-run 'keel guard install'"*) ok "guard status tells a hook that scans the working tree to be reinstalled" ;;
  *) bad "guard status" "with a hook from before --push the push guard line was: $pg" ;;
esac
rm -rf "$gs"

# ---- verify.security is detected from a JavaScript lockfile --------------------------------------
# write_ci mapped the package manager to an audit and never told the profile, so doctor and ship
# saw no security command on any project. Only with the lockfile the audit reads: npm audit exits
# non-zero without one.
sl="$(fixture node-ts)"; printf '{"lockfileVersion": 3}\n' > "$sl/package-lock.json"
( cd "$sl" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(verify_of "$sl" security)" = "npm audit --audit-level=high" ] \
  && ok "init detects verify.security from a package-lock.json" \
  || bad "verify.security" "got '$(verify_of "$sl" security)'"
grep -q 'name: security' "$sl/.github/workflows/ci.yml" \
  && ok "generated CI runs verify.security as its own step" \
  || bad "verify.security" "no security step in the generated workflow"
[ "$(grep -c 'npm audit --audit-level=high' "$sl/.github/workflows/ci.yml")" -eq 1 ] \
  && ok "generated CI runs the audit once, as the security step" \
  || bad "verify.security" "audit steps: $(grep -n 'audit' "$sl/.github/workflows/ci.yml" | tr '\n' ' ')"
seed_standards "$sl"
out="$( cd "$sl" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"ok    verify.security set (not run, --fast)"*) ok "doctor --fast names verify.security without running it" ;;
  *) bad "verify.security" "no --fast line: $(printf '%s\n' "$out" | grep -n 'verify.security')" ;;
esac
rm -rf "$sl"
sn="$(fixture node-ts)"
( cd "$sn" && "$KEEL" init -y >/dev/null 2>&1 )
[ -z "$(verify_of "$sn" security)" ] && ok "no lockfile means no verify.security" \
  || bad "verify.security" "detected '$(verify_of "$sn" security)' with no lockfile"
seed_standards "$sn"
out="$( cd "$sn" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"ok    verify.security is null: keel detects one only from an npm, pnpm or yarn 2+ lockfile"*)
    ok "a null verify.security is an ok line, not a warning" ;;
  *) bad "verify.security" "null line: $(printf '%s\n' "$out" | grep -n 'verify.security')" ;;
esac
rm -rf "$sn"
# `yarn npm audit` exists only on yarn 2 and later, and yarn 1 answers it with `Command "npm" not
# found`, so a classic lockfile gets no command and full doctor does not fail on every yarn 1 project.
sy="$(fixture node-ts)"; printf '# yarn lockfile v1\n' > "$sy/yarn.lock"
( cd "$sy" && "$KEEL" init -y >/dev/null 2>&1 )
[ -z "$(verify_of "$sy" security)" ] && ok "a yarn 1 lockfile means no verify.security" \
  || bad "verify.security" "detected '$(verify_of "$sy" security)' from a yarn 1 lockfile"
rm -rf "$sy"
sy="$(fixture node-ts)"; printf '__metadata:\n  version: 8\n' > "$sy/yarn.lock"
( cd "$sy" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(verify_of "$sy" security)" = "yarn npm audit --severity high" ] \
  && ok "a yarn 2+ lockfile detects yarn npm audit" \
  || bad "verify.security" "yarn 2+ lockfile: got '$(verify_of "$sy" security)'"
rm -rf "$sy"
# A security command that is not the audit, such as a code scanner, runs beside the dependency
# audit and does not replace it. init writes CI only when there is none, so the second init, after
# the workflow is removed, is the one that reads the hand-set command.
sd="$(fixture node-ts)"; printf '{"lockfileVersion": 3}\n' > "$sd/package-lock.json"
( cd "$sd" && "$KEEL" init -y >/dev/null 2>&1 \
  && "$KEEL" profile set verify.security 'echo scan' >/dev/null 2>&1 \
  && rm -rf .github && "$KEEL" init -y >/dev/null 2>&1 )
grep -q 'run: echo scan' "$sd/.github/workflows/ci.yml" \
  && grep -q 'run: npm audit --audit-level=high' "$sd/.github/workflows/ci.yml" \
  && ok "generated CI keeps the audit beside a different verify.security" \
  || bad "verify.security" "run steps: $(grep 'run:' "$sd/.github/workflows/ci.yml" | tr '\n' ' ')"
rm -rf "$sd"

# ---- a checkout cannot run a branch's own hooks --------------------------------------------------
# The guard used core.hooksPath=.githooks, a path inside the working tree, so every checkout
# replaced the hooks with the checked-out branch's own, and a fork's pull request ran its code the
# moment anyone checked it out. The guard now lives in git's hooks directory, which no checkout
# writes. Reproduced on git 2.50.1 before the fix.
xh="$(fixture node-ts)"
( cd "$xh" && "$KEEL" init -y >/dev/null 2>&1 && "$KEEL" guard install >/dev/null 2>&1 )
[ -x "$xh/.git/hooks/pre-push" ] \
  || bad "guard location" "fixture precondition: guard install wrote no .git/hooks/pre-push"
( cd "$xh" && git checkout -q -b fork-pr && mkdir -p .githooks \
  && printf '#!/bin/sh\ntouch "%s/checkout-ran-a-branch-hook"\n' "$xh" > .githooks/post-checkout \
  && chmod +x .githooks/post-checkout && git add .githooks \
  && git commit -q --no-verify -m "a branch that ships its own hook" \
  && git checkout -q - && git checkout -q fork-pr ) >/dev/null 2>&1
[ -e "$xh/.githooks/post-checkout" ] \
  || bad "guard location" "fixture precondition: the branch's hook file is not checked out"
# The positive control: without it, a checkout that silently failed would leave no hook to run and
# pass the assertion below for the wrong reason.
[ "$(git -C "$xh" rev-parse --abbrev-ref HEAD)" = fork-pr ] \
  || bad "guard location" "fixture precondition: HEAD is '$(git -C "$xh" rev-parse --abbrev-ref HEAD)', not fork-pr"
[ ! -e "$xh/checkout-ran-a-branch-hook" ] \
  && ok "checking out a branch does not run that branch's own hooks" \
  || bad "guard location" "a checked-out branch's .githooks/post-checkout ran"
rm -rf "$xh"

# ---- an install at the old .githooks path is recognised and moved --------------------------------
# Every guard installed before 2026-09-26 sits in .githooks with core.hooksPath pointing there.
# status must say so, and install must move it rather than leave both.
lg="$(fixture node-ts)"
( cd "$lg" && "$KEEL" init -y >/dev/null 2>&1 && "$KEEL" guard install >/dev/null 2>&1 \
  && mkdir -p .githooks \
  && mv .git/hooks/pre-push .git/hooks/pre-commit .git/hooks/prepare-commit-msg .githooks/ \
  && git config core.hooksPath .githooks )
out="$( cd "$lg" && "$KEEL" guard status 2>&1 )"; rc=$?
case "$out" in
  *"working-tree path"*) [ "$rc" -ne 0 ] && ok "guard status names an install at .githooks and exits non-zero" \
                           || bad "guard legacy" "status named it but exited 0" ;;
  *) bad "guard legacy" "status did not name the .githooks install: $out" ;;
esac
( cd "$lg" && "$KEEL" guard install >/dev/null 2>&1 )
[ -z "$(git -C "$lg" config core.hooksPath)" ] && [ -x "$lg/.git/hooks/pre-push" ] \
  && ok "guard install moves a .githooks install into .git/hooks and unsets core.hooksPath" \
  || bad "guard legacy" "after install: core.hooksPath='$(git -C "$lg" config core.hooksPath)', pre-push $( [ -x "$lg/.git/hooks/pre-push" ] && echo present || echo missing )"
( cd "$lg" && "$KEEL" guard status >/dev/null 2>&1 ) \
  && ok "guard status is 0 once the .githooks install is moved" \
  || bad "guard legacy" "status non-zero after the move"
rm -rf "$lg"

# ---- another tool's hooks are never taken over ---------------------------------------------------
# A core.hooksPath keel did not set belongs to husky, lefthook or a global scanner; replacing it
# switches that tool's hooks off. A same-named hook file in .git/hooks is another tool's too.
# install refuses both, and leaves them exactly as they were.
fp="$(fixture node-ts)"
( cd "$fp" && "$KEEL" init -y >/dev/null 2>&1 && git config core.hooksPath .husky )
( cd "$fp" && "$KEEL" guard install >/dev/null 2>&1 ) \
  && bad "guard foreign" "install exited 0 with core.hooksPath pointing at .husky" \
  || ok "guard install refuses while core.hooksPath points at another tool's hooks"
[ "$(git -C "$fp" config core.hooksPath)" = ".husky" ] && [ ! -e "$fp/.git/hooks/pre-push" ] \
  && ok "the refused install leaves core.hooksPath and .git/hooks untouched" \
  || bad "guard foreign" "core.hooksPath='$(git -C "$fp" config core.hooksPath)', pre-push $( [ -e "$fp/.git/hooks/pre-push" ] && echo written || echo absent )"
out="$( cd "$fp" && "$KEEL" guard status 2>&1 )"
case "$out" in
  *"which keel did not set"*) ok "guard status names a foreign core.hooksPath" ;;
  *) bad "guard foreign" "status: $out" ;;
esac
rm -rf "$fp"
fh="$(fixture node-ts)"
( cd "$fh" && "$KEEL" init -y >/dev/null 2>&1 \
  && printf '#!/bin/sh\n# another tool\nexit 0\n' > .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit )
( cd "$fh" && "$KEEL" guard install >/dev/null 2>&1 ) \
  && bad "guard foreign" "install exited 0 over another tool's pre-commit" \
  || ok "guard install refuses to overwrite another tool's hook"
grep -q 'another tool' "$fh/.git/hooks/pre-commit" && [ ! -e "$fh/.git/hooks/pre-push" ] \
  && ok "the refused install leaves the other tool's hook in place and writes nothing" \
  || bad "guard foreign" "the other tool's pre-commit was replaced, or pre-push was written"
out="$( cd "$fh" && "$KEEL" guard status 2>&1 )"
case "$out" in
  *"pre-commit is another tool's hook"*) ok "guard status names another tool's pre-commit" ;;
  *) bad "guard foreign" "status with a foreign pre-commit: $out" ;;
esac
rm -rf "$fh"
# .githooks is also a common name for a project's own committed hooks. Without keel's mark it is
# theirs, and install must not unset core.hooksPath as if it were keel's old install.
ph="$(fixture node-ts)"
( cd "$ph" && "$KEEL" init -y >/dev/null 2>&1 && mkdir -p .githooks \
  && printf '#!/bin/sh\n# the project own hook\nexit 0\n' > .githooks/pre-commit \
  && chmod +x .githooks/pre-commit && git config core.hooksPath .githooks )
( cd "$ph" && "$KEEL" guard install >/dev/null 2>&1 ) \
  && bad "guard foreign" "install exited 0 over a project's own .githooks" \
  || ok "guard install refuses a .githooks that holds a project's own hooks"
[ "$(git -C "$ph" config core.hooksPath)" = ".githooks" ] \
  && grep -q 'the project own hook' "$ph/.githooks/pre-commit" \
  && ok "the project's own .githooks stays in core.hooksPath, untouched" \
  || bad "guard foreign" "core.hooksPath='$(git -C "$ph" config core.hooksPath)', or .githooks/pre-commit was replaced"
rm -rf "$ph"

# ---- a legacy move never switches off hooks that are not keel's ---------------------------------
# A fixture holding keel's old install: the three hooks in .githooks, core.hooksPath pointing there.
# Each case below takes its own, so one case's install cannot decide another's result.
legacy_fixture() {
    local r; r="$(fixture node-ts)"
    ( cd "$r" && "$KEEL" init -y >/dev/null 2>&1 && "$KEEL" guard install >/dev/null 2>&1 \
      && mkdir -p .githooks \
      && mv .git/hooks/pre-push .git/hooks/pre-commit .git/hooks/prepare-commit-msg .githooks/ \
      && git config core.hooksPath .githooks )
    printf '%s' "$r"
}
# A .githooks holding keel's pre-push can hold the project's own commit-msg beside it. Unsetting
# core.hooksPath to move keel's three would stop that one running too, so install refuses instead.
lo="$(legacy_fixture)"
printf '#!/bin/sh\n# the project own commit-msg\nexit 0\n' > "$lo/.githooks/commit-msg"
chmod +x "$lo/.githooks/commit-msg"
out="$( cd "$lo" && "$KEEL" guard install 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && [ "$(git -C "$lo" config core.hooksPath)" = ".githooks" ] \
  && grep -q 'the project own commit-msg' "$lo/.githooks/commit-msg" \
  && ok "guard install refuses to move a .githooks install that also holds another hook" \
  || bad "guard legacy" "rc=$rc, core.hooksPath='$(git -C "$lo" config core.hooksPath)': $out"
case "$out" in
  *"holds commit-msg"*) ok "the refusal names the hook that would stop running" ;;
  *) bad "guard legacy" "the refusal did not name commit-msg: $out" ;;
esac
rm -rf "$lo"
# git resolves a relative core.hooksPath against the top of the working tree, so status run from a
# subdirectory must still find keel's old install rather than call it another tool's setting.
ls="$(legacy_fixture)"; mkdir -p "$ls/sub/deeper"
out="$( cd "$ls/sub/deeper" && "$KEEL" guard status 2>&1 )"
case "$out" in
  *"working-tree path"*) ok "guard status from a subdirectory names an install at .githooks" ;;
  *) bad "guard legacy" "status from a subdirectory: $out" ;;
esac
rm -rf "$ls"
# The move unsets the local setting only. A global core.hooksPath then takes over, and git would run
# none of the hooks just written, so install must say so rather than report success.
lx="$(legacy_fixture)"
printf '[core]\n\thooksPath = /nonexistent/elsewhere\n' > "$lx/global-config"
out="$( cd "$lx" && GIT_CONFIG_GLOBAL="$lx/global-config" "$KEEL" guard install 2>&1 )"; rc=$?
case "$rc:$out" in
  0:*) bad "guard legacy" "install exited 0 with a global core.hooksPath in effect: $out" ;;
  *global*) ok "guard install refuses when a global core.hooksPath takes over after the move, and names its scope" ;;
  *) bad "guard legacy" "install refused without naming the global setting: $out" ;;
esac
rm -rf "$lx"
lu="$(legacy_fixture)"
( cd "$lu" && "$KEEL" guard uninstall >/dev/null 2>&1 )
[ -z "$(git -C "$lu" config core.hooksPath)" ] \
  && ok "guard uninstall unsets core.hooksPath for an install at .githooks" \
  || bad "guard legacy" "core.hooksPath survived uninstall: '$(git -C "$lu" config core.hooksPath)'"
rm -rf "$lu"
# The same project commit-msg beside it: unsetting core.hooksPath would stop that hook running, so
# uninstall leaves the setting and says which hook it is keeping alive.
lk="$(legacy_fixture)"
printf '#!/bin/sh\n# the project own commit-msg\nexit 0\n' > "$lk/.githooks/commit-msg"
chmod +x "$lk/.githooks/commit-msg"
out="$( cd "$lk" && "$KEEL" guard uninstall 2>&1 )"
case "$(git -C "$lk" config core.hooksPath):$out" in
  .githooks:*"holds commit-msg"*) ok "guard uninstall leaves core.hooksPath on a .githooks that also holds another hook, and names it" ;;
  *) bad "guard legacy" "core.hooksPath='$(git -C "$lk" config core.hooksPath)' after uninstall: $out" ;;
esac
rm -rf "$lk"
# git runs only executable hook files, and never a *.sample, so neither kind in .githooks is a hook
# the move would stop: a README.md or an executable commit-msg.sample must not block it.
ln="$(legacy_fixture)"
printf 'These are our hooks.\n' > "$ln/.githooks/README.md"
printf '#!/bin/sh\nexit 0\n' > "$ln/.githooks/commit-msg.sample"; chmod +x "$ln/.githooks/commit-msg.sample"
( cd "$ln" && "$KEEL" guard install >/dev/null 2>&1 ) && [ -z "$(git -C "$ln" config core.hooksPath)" ] \
  && ok "guard install moves a .githooks install beside a README.md and an executable .sample" \
  || bad "guard legacy" "install refused or left core.hooksPath='$(git -C "$ln" config core.hooksPath)' beside a README.md and a .sample"
rm -rf "$ln"
# keel's old install reached through a global core.hooksPath only. This repository cannot unset a
# global setting, so neither install nor uninstall may claim to have, and each names the scope.
lg2="$(legacy_fixture)"; git -C "$lg2" config --unset core.hooksPath
printf '[core]\n\thooksPath = .githooks\n' > "$lg2/global-config"
out="$( cd "$lg2" && GIT_CONFIG_GLOBAL="$lg2/global-config" "$KEEL" guard install 2>&1 )"; rc=$?
case "$rc:$out" in
  0:*) bad "guard legacy" "install exited 0 with .githooks set only globally: $out" ;;
  *"set in the global git config"*) ok "guard install refuses a .githooks install set only globally, and names the scope" ;;
  *) bad "guard legacy" "install refused without naming the global scope: $out" ;;
esac
out="$( cd "$lg2" && GIT_CONFIG_GLOBAL="$lg2/global-config" "$KEEL" guard uninstall 2>&1 )"
case "$out" in
  *"unset core.hooksPath, which pointed"*) bad "guard legacy" "uninstall claimed to unset a global core.hooksPath: $out" ;;
  *"set in the global git config"*) ok "guard uninstall says a global core.hooksPath remains, and names the scope" ;;
  *) bad "guard legacy" "uninstall did not name the global scope: $out" ;;
esac
rm -rf "$lg2"

# ---- another tool's pre-commit beside keel's pre-push -------------------------------------------
# `pre-commit install` writes .git/hooks/pre-commit over keel's. The push guard still runs, so the
# status is installed, but the commit guard line must not call the other tool's hook keel's.
oc="$(fixture node-ts)"
( cd "$oc" && "$KEEL" init -y >/dev/null 2>&1 && "$KEEL" guard install >/dev/null 2>&1 \
  && printf '#!/bin/sh\n# another tool\nexit 0\n' > .git/hooks/pre-commit )
out="$( cd "$oc" && "$KEEL" guard status 2>&1 )"; rc=$?
case "$rc:$out" in
  0:*"push guard: active"*"pre-commit is another tool's hook"*) ok "guard status is active beside another tool's pre-commit, and names it" ;;
  *) bad "guard foreign" "status rc=$rc: $out" ;;
esac
rm -rf "$oc"
# uninstall removes keel's files only.
ou="$(fixture node-ts)"
( cd "$ou" && "$KEEL" init -y >/dev/null 2>&1 && "$KEEL" guard install >/dev/null 2>&1 \
  && printf '#!/bin/sh\n# another tool\nexit 0\n' > .git/hooks/pre-commit \
  && "$KEEL" guard uninstall >/dev/null 2>&1 )
grep -q 'another tool' "$ou/.git/hooks/pre-commit" 2>/dev/null && [ ! -e "$ou/.git/hooks/pre-push" ] \
  && ok "guard uninstall removes keel's hooks and leaves another tool's pre-commit" \
  || bad "guard foreign" "after uninstall: pre-commit $( grep -q 'another tool' "$ou/.git/hooks/pre-commit" 2>/dev/null && echo kept || echo gone ), pre-push $( [ -e "$ou/.git/hooks/pre-push" ] && echo kept || echo gone )"
rm -rf "$ou"

# ---- a lost executable bit, and a core.hooksPath naming .git/hooks ------------------------------
# git skips a hook that is not executable, so a keel pre-push without the bit guards nothing.
xb="$(fixture node-ts)"
( cd "$xb" && "$KEEL" init -y >/dev/null 2>&1 && "$KEEL" guard install >/dev/null 2>&1 \
  && chmod -x .git/hooks/pre-push )
( cd "$xb" && "$KEEL" guard status >/dev/null 2>&1 ) \
  && bad "guard" "status exited 0 with a pre-push that is not executable" \
  || ok "guard status is non-zero when keel's pre-push is not executable"
( cd "$xb" && "$KEEL" guard install >/dev/null 2>&1 )
[ -x "$xb/.git/hooks/pre-push" ] && ok "guard install restores the executable bit" \
  || bad "guard" "pre-push still not executable after install"
rm -rf "$xb"
# A core.hooksPath naming git's own hooks directory redirects nothing, so it is not another tool's.
gh="$(fixture node-ts)"
( cd "$gh" && "$KEEL" init -y >/dev/null 2>&1 && git config core.hooksPath .git/hooks )
( cd "$gh" && "$KEEL" guard install >/dev/null 2>&1 ) && ( cd "$gh" && "$KEEL" guard status >/dev/null 2>&1 ) \
  && ok "core.hooksPath set to .git/hooks is not foreign: install succeeds and status is 0" \
  || bad "guard" "install or status failed with core.hooksPath=.git/hooks"
rm -rf "$gh"

# ---- doctor names the guard's real state, and never sends anyone to replace another tool --------
# doctor tested core.hooksPath=.githooks plus an executable .githooks/pre-push, so any project's own
# .githooks/pre-push read as keel's guard, and every other state got "Run: keel guard install",
# which for a husky or lefthook project meant switching those hooks off.
dg="$(fixture node-ts)"
( cd "$dg" && "$KEEL" init -y >/dev/null 2>&1 )
seed_standards "$dg"
( cd "$dg" && git config core.hooksPath .husky )
out="$( cd "$dg" && "$KEEL" doctor --fast 2>&1 )"
line="$(printf '%s\n' "$out" | grep 'push guard')"
case "$line" in
  *"which keel did not set"*)
    case "$line" in
      *"Run: keel guard install"*) bad "doctor guard state" "a foreign core.hooksPath was told to run guard install: $line" ;;
      *) ok "doctor names a foreign core.hooksPath and does not send it to guard install" ;;
    esac ;;
  *) bad "doctor guard state" "foreign core.hooksPath line: $line" ;;
esac
( cd "$dg" && git config --unset core.hooksPath \
  && printf '#!/bin/sh\n# another tool\nexit 0\n' > .git/hooks/pre-push && chmod +x .git/hooks/pre-push )
out="$( cd "$dg" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"ok    push guard installed"*) bad "doctor guard state" "another tool's pre-push counted as keel's guard" ;;
  *"another tool's hook"*) ok "doctor does not count another tool's pre-push as the guard" ;;
  *) bad "doctor guard state" "foreign pre-push line: $(printf '%s\n' "$out" | grep 'push guard')" ;;
esac
( cd "$dg" && rm -f .git/hooks/pre-push \
  && printf '#!/bin/sh\n# another tool\nexit 0\n' > .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit )
out="$( cd "$dg" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"pre-commit is another tool's hook"*) ok "doctor names another tool's pre-commit rather than calling the guard absent" ;;
  *) bad "doctor guard state" "foreign pre-commit line: $(printf '%s\n' "$out" | grep 'push guard')" ;;
esac
( cd "$dg" && rm -f .git/hooks/pre-commit && "$KEEL" guard install >/dev/null 2>&1 \
  && mkdir -p .githooks \
  && mv .git/hooks/pre-push .git/hooks/pre-commit .git/hooks/prepare-commit-msg .githooks/ \
  && git config core.hooksPath .githooks )
out="$( cd "$dg" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"WARN  the push guard is installed in .githooks/, a working-tree path"*)
    ok "doctor warns that an install at .githooks runs a checked-out branch's hooks" ;;
  *) bad "doctor guard state" "legacy line: $(printf '%s\n' "$out" | grep 'push guard')" ;;
esac
# install refuses to move a .githooks install beside hooks keel did not write, so neither doctor nor
# status may send anyone straight to it: both name those hooks first.
( cd "$dg" && printf '#!/bin/sh\nexit 0\n' > .githooks/commit-msg && chmod +x .githooks/commit-msg )
out="$( cd "$dg" && "$KEEL" doctor --fast 2>&1 )"
line="$(printf '%s\n' "$out" | grep 'push guard')"
case "$line" in
  *"Run: keel guard install"*) bad "doctor guard state" "a legacy install beside another hook was sent straight to guard install: $line" ;;
  *commit-msg*) ok "doctor names the other hooks in .githooks rather than sending anyone straight to guard install" ;;
  *) bad "doctor guard state" "legacy beside another hook line: $line" ;;
esac
out="$( cd "$dg" && "$KEEL" guard status 2>&1 )"
case "$out" in
  *"Re-run 'keel guard install' to move it"*) bad "guard legacy" "status sent a legacy install beside another hook straight to install: $out" ;;
  *commit-msg*) ok "guard status names the other hooks in .githooks rather than sending anyone straight to install" ;;
  *) bad "guard legacy" "status on a legacy install beside another hook: $out" ;;
esac
rm -rf "$dg"
# A global core.hooksPath is one nothing in this repository can undo, so doctor and status both
# name the config it came from, which is the file the user has to edit.
dgg="$(fixture node-ts)"
( cd "$dgg" && "$KEEL" init -y >/dev/null 2>&1 && mkdir -p elsewhere )
printf '[core]\n\thooksPath = %s\n' "$dgg/elsewhere" > "$dgg/global-config"
out="$( cd "$dgg" && GIT_CONFIG_GLOBAL="$dgg/global-config" "$KEEL" doctor --fast 2>&1 )"
line="$(printf '%s\n' "$out" | grep 'push guard')"
case "$line" in
  *"global git config"*) ok "doctor names the global config a foreign core.hooksPath comes from" ;;
  *) bad "doctor guard state" "global core.hooksPath line: $line" ;;
esac
out="$( cd "$dgg" && GIT_CONFIG_GLOBAL="$dgg/global-config" "$KEEL" guard status 2>&1 )"
case "$out" in
  *"global git config"*) ok "guard status names the global config a foreign core.hooksPath comes from" ;;
  *) bad "guard foreign" "status with a global core.hooksPath: $out" ;;
esac
rm -rf "$dgg"

# ---- a failing verify.security is reported as an audit result, not a broken command -------------
# An audit exits non-zero on a finding at or above its threshold, and when it cannot reach its
# registry. "does not run" sent the reader to debug a command that ran.
fs="$(fixture node-ts)"
( cd "$fs" && "$KEEL" init -y >/dev/null 2>&1 \
  && "$KEEL" profile set verify.security 'exit 3' >/dev/null 2>&1 )
seed_standards "$fs"
[ "$(verify_of "$fs" security)" = "exit 3" ] \
  || bad "verify.security result" "fixture precondition: verify.security is '$(verify_of "$fs" security)'"
out="$( cd "$fs" && "$KEEL" doctor 2>&1 )"
case "$out" in
  *"FAIL  verify.security exited 3"*"run it to see which"*)
    ok "doctor reports a failing verify.security as an exit code and how to read it" ;;
  *) bad "verify.security result" "line: $(printf '%s\n' "$out" | grep 'verify.security')" ;;
esac
case "$out" in
  *"verify.security does not run"*) bad "verify.security result" "still says 'does not run'" ;;
  *) ok "a failing verify.security no longer reads as a command that does not run" ;;
esac
rm -rf "$fs"

# ---- write_ci follows the profile's branch, not git's ---------------------------------------------
# Both default-branch cases above use a master repository where git and the profile agree, so
# deleting write_ci's read of the profile left them green. Here they disagree.
tb="$(fixture node-ts)"
( cd "$tb" && "$KEEL" init -y >/dev/null 2>&1 \
  && "$KEEL" profile set conventions.default_branch trunk >/dev/null 2>&1 \
  && rm -rf .github && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(prof_of "$tb" conventions.default_branch)" = trunk ] \
  || bad "write_ci branch" "fixture precondition: the profile does not record trunk"
grep -q 'branches: \[trunk\]' "$tb/.github/workflows/ci.yml" \
  && ok "generated CI triggers on the profile's branch where git names another" \
  || bad "write_ci branch" "workflow trigger: $(grep -n 'branches' "$tb/.github/workflows/ci.yml")"
rm -rf "$tb"

# ---- pnpm detection has a case of its own -------------------------------------------------------
# The CI case for pnpm reads write_ci's own mapping, so deleting detect_verify's pnpm arm left
# every case green.
sp="$(fixture node-ts)"; : > "$sp/pnpm-lock.yaml"
( cd "$sp" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(verify_of "$sp" security)" = "pnpm audit --audit-level high" ] \
  && ok "init detects verify.security from a pnpm-lock.yaml" \
  || bad "verify.security" "pnpm: got '$(verify_of "$sp" security)'"
rm -rf "$sp"

# ---- a slow suite is named as a cost, and verify.test_affected is declared ---------------------
# docs/plans/2026-10-16-manage-test-speed.md task 1, behaviours 2 to 8; ADR-0009 is the decision
# these cases hold to. tdd runs verify.test at every unit boundary, so full doctor says what a slow
# suite costs, and a project whose runner can select the affected tests declares that command in
# verify.test_affected instead of paying for the whole suite each time.
#
# Every doctor case reads doctor's own output, because the line is the product. The node-ts fixture
# and not a bare one: a bare repository detects as project.kind "docs", and doctor then prints no
# verify line at all (see the verify.e2e cases above).

# One JSON value written into a fixture's profile exactly as a hand edit would write it. `keel
# profile set` cannot write a bare 0, a quoted word or a null the way a person editing the file
# does, and it cannot delete a key, which "absent means 60" needs. $3 is a JSON literal, or UNSET
# to remove the key.
setj() {   # setj <dir> <dotted.path> <json literal | UNSET>
    python3 - "$1/.keel/profile.json" "$2" "$3" <<'PY'
import json, sys
p, path, lit = sys.argv[1:4]
root = d = json.load(open(p))
*parents, leaf = path.split(".")
for k in parents:
    d = d[k]
if lit == "UNSET":
    d.pop(leaf, None)
else:
    d[leaf] = json.loads(lit)
json.dump(root, open(p, "w"), indent=2)
open(p, "a").write("\n")
PY
}

# Full or --fast doctor in a fixture, both streams, so a WARN and an ok are read the same way.
doc_run() {   # doc_run <dir> [flag...]
    local d="$1"; shift
    ( cd "$d" && "$KEEL" doctor "$@" 2>&1 )
}

# One initialised node-ts fixture, copied for each case below. Initialising once keeps this block
# cheap, which matters in a plan about the cost of a suite, and the lint, typecheck and build
# commands are cleared so that doctor does not start npm three times per run to learn nothing this
# block reads.
speed_tpl="$(fixture node-ts)"
( cd "$speed_tpl" && "$KEEL" init -y >/dev/null 2>&1 )
for k in lint typecheck build; do setj "$speed_tpl" "verify.$k" null; done

# A copy of that template whose verify.test is the given command.
speed_fixture() {   # speed_fixture <verify.test command>
    local d; d="$(mktemp -d)"
    cp -R "$speed_tpl/." "$d/"
    setj "$d" verify.test "\"$1\""
    printf '%s' "$d"
}

# Full doctor in a fixture, started in the background with its output sent to a file, so that the
# cases that need a suite to take real seconds wait for them together and not one after another.
# Collected by `wait` below; the fixtures share nothing, so the runs cannot disturb each other.
start_doc() {   # start_doc <dir> <output file>
    ( doc_run "$1" > "$2" ) &
}

# The seconds doctor printed on its own "verify.test runs (Ns)" line.
ran_seconds() {   # ran_seconds <doctor output>
    printf '%s\n' "$1" | sed -n 's/^ok    verify\.test runs (\([0-9][0-9]*\)s).*/\1/p' | head -1
}

# The behaviour 3 warning, built from the seconds doctor itself reports, so the case holds whatever
# $SECONDS happened to give (a 2 second suite measures as 2 or 3). The minutes are the plan's
# (seconds * 10 + 30) / 60 in whole numbers, written out here and not read from bin/keel, so the
# formula is checked and not echoed.
slow_warning_ok() {   # slow_warning_ok <doctor output> <threshold>
    local line el m phrase want
    line="$(printf '%s\n' "$1" | grep '^WARN  verify\.test took ' | head -1)"
    el="$(ran_seconds "$1")"
    [ -n "$line" ] && [ -n "$el" ] || return 1
    m=$(( (el * 10 + 30) / 60 ))
    case "$m" in 0) phrase="under a minute" ;; 1) phrase="about 1 minute" ;; *) phrase="about $m minutes" ;; esac
    want="WARN  verify.test took ${el}s, over gates.suite_warn_seconds ($2s): tdd runs it at every unit boundary, so ten units spend $phrase in it. Set verify.test_affected, or raise gates.suite_warn_seconds if ${el}s is this suite's honest cost."
    [ "$line" = "$want" ]
}

# ---- behaviour 2: the keys exist, init writes both, a person's value survives a re-run
sd="$(fixture node-ts)"
( cd "$sd" && "$KEEL" init -y >/dev/null 2>&1 )
got="$(prof_of "$sd" verify.test_affected gates.suite_warn_seconds | tr '\n' '|')"
[ "$got" = "None|60|" ] \
  && ok "init writes verify.test_affected null and gates.suite_warn_seconds 60" \
  || bad "init writes verify.test_affected null and gates.suite_warn_seconds 60" "got '$got'"
( cd "$sd" && "$KEEL" profile set verify.test_affected 'npx vitest run --changed {base}' >/dev/null 2>&1 )
( cd "$sd" && "$KEEL" profile set gates.suite_warn_seconds 90 >/dev/null 2>&1 )
( cd "$sd" && "$KEEL" init -y >/dev/null 2>&1 )
got="$(prof_of "$sd" verify.test_affected gates.suite_warn_seconds | tr '\n' '|')"
[ "$got" = "npx vitest run --changed {base}|90|" ] \
  && ok "re-running init keeps a verify.test_affected and a gates.suite_warn_seconds a person set" \
  || bad "re-running init keeps what a person set" "got '$got'"
rm -rf "$sd"

got="$(python3 - "$ROOT/templates/profile.schema.json" <<'PY' 2>&1
import json, sys
s = json.load(open(sys.argv[1]))["properties"]
ta = s["verify"]["properties"]["test_affected"]
sw = s["gates"]["properties"]["suite_warn_seconds"]
print(ta["type"], sw["type"], sw["minimum"], bool(ta["x-keel-read-by"]), bool(sw["x-keel-read-by"]))
PY
)"
[ "$got" = "['string', 'null'] integer 1 True True" ] \
  && ok "the schema declares both keys, with the types the plan names and a reader each" \
  || bad "the schema declares both keys" "got '$got'"

got="$(python3 - "$ROOT/templates/keel-profile.example.json" <<'PY' 2>&1
import json, sys
d = json.load(open(sys.argv[1]))
print("test_affected" in d["verify"], "suite_warn_seconds" in d["gates"])
PY
)"
[ "$got" = "True True" ] && ok "the example profile shows both keys" \
  || bad "the example profile shows both keys" "got '$got'"

# keel's own profile is at the schema bin/keel declares and carries both keys, so keel's doctor does
# not call it stale. verify.test_affected stays null there: no runner of this repository selects
# affected tests, and the suite warning doctor prints for keel's own suite is true.
sv_now="$(sed -n 's/^SCHEMA_VERSION=\([0-9][0-9]*\)$/\1/p' "$ROOT/bin/keel")"
got="$(python3 - "$ROOT/.keel/profile.json" <<'PY' 2>&1
import json, sys
d = json.load(open(sys.argv[1]))
print(d["schema_version"], d["verify"]["test_affected"], d["gates"]["suite_warn_seconds"])
PY
)"
[ "$got" = "$sv_now None 60" ] \
  && ok "keel's own profile is at the current schema and carries both keys" \
  || bad "keel's own profile is at the current schema and carries both keys" "got '$got', want '$sv_now None 60'"

# ---- behaviours 3 to 6: the suites that take real seconds are started together, then read
# Each needs a suite that really runs longer than its threshold, and $SECONDS has one second
# granularity, so these are the slow part of this block. They start here and are read below.
tmp_out="$(mktemp -d)"
sw="$(speed_fixture 'sleep 2')";               setj "$sw" gates.suite_warn_seconds '"001"'
sp="$(speed_fixture 'sleep 3')";               setj "$sp" gates.suite_warn_seconds 1
sf="$(speed_fixture 'sleep 2; exit 1')";       setj "$sf" gates.suite_warn_seconds 1
sm="$(speed_fixture 'sleep 2')";               setj "$sm" gates.suite_warn_seconds 1
setj "$sm" verify.test_affected '"echo affected"'
sa="$(speed_fixture 'sleep 2')";               setj "$sa" gates.suite_warn_seconds 1
setj "$sa" verify.test_affected '"sleep 2"'
sb="$(speed_fixture 'sleep 2')";               setj "$sb" gates.suite_warn_seconds 1
setj "$sb" verify.test_affected '"sleep 2 "'
sc="$(speed_fixture 'sleep 2')";               setj "$sc" gates.suite_warn_seconds 1
setj "$sc" verify.test_affected '"  sleep 2"'
s0="$(speed_fixture 'sleep 1')";               setj "$s0" gates.suite_warn_seconds 0
sn="$(speed_fixture 'sleep 1')";               setj "$sn" gates.suite_warn_seconds null
sq="$(speed_fixture true)";                    setj "$sq" gates.suite_warn_seconds '"fast"'
sg="$(speed_fixture true)";                    setj "$sg" gates.suite_warn_seconds 1234567890
start_doc "$sw" "$tmp_out/sw"; start_doc "$sp" "$tmp_out/sp"; start_doc "$sf" "$tmp_out/sf"
start_doc "$sm" "$tmp_out/sm"; start_doc "$sa" "$tmp_out/sa"; start_doc "$sb" "$tmp_out/sb"
start_doc "$sc" "$tmp_out/sc"; start_doc "$s0" "$tmp_out/s0"; start_doc "$sn" "$tmp_out/sn"
start_doc "$sq" "$tmp_out/sq"; start_doc "$sg" "$tmp_out/sg"
wait

# ---- behaviour 3: a suite over the threshold warns, and says what it costs
# The threshold here is the string "001": a string of digits reads as that number, zeros and all, so
# this is the plan's 1 second threshold and a 2 second suite measures as 2 or 3.
out="$(cat "$tmp_out/sw")"
if slow_warning_ok "$out" 1; then
    ok "a passing suite over gates.suite_warn_seconds warns, naming the cost"
else
    bad "a passing suite over gates.suite_warn_seconds warns, naming the cost" \
        "$(printf '%s\n' "$out" | grep 'verify\.test ')"
fi
printf '%s\n' "$out" | grep -qE '^ok    verify\.test runs \([0-9]+s\): sleep 2$' \
  && ok "the warning sits beside doctor's existing verify.test runs line, which stays" \
  || bad "the verify.test runs line stays" "$(printf '%s\n' "$out" | grep 'verify\.test ')"
printf '%s\n' "$out" | grep -qE 'verify\.test took [0-9]+s, over gates\.suite_warn_seconds \(1s\)' \
  && ok "the warning matches the plan's pattern, and \"001\" was read as 1" \
  || bad "the warning matches the plan's pattern" "$(printf '%s\n' "$out" | grep 'verify\.test ')"

# Three seconds is the first suite whose cost reads in minutes, and it measures as 3 or 4, which
# both give 1: the arithmetic and the singular hold whichever it is. The plural "about N minutes"
# branch is checked by reading bin/keel, as the exclusive threshold is: a suite long enough to
# reach 2 minutes would hold the parallel group about six seconds longer, for a word.
out="$(cat "$tmp_out/sp")"
if slow_warning_ok "$out" 1 && printf '%s\n' "$out" | grep -q 'ten units spend about 1 minute in it\.'; then
    ok "a three second suite is costed at about 1 minute for ten units"
else
    bad "a three second suite is costed at about 1 minute for ten units" \
        "$(printf '%s\n' "$out" | grep 'verify\.test ')"
fi

# A run that fails gets its existing line and no warning, however long it took.
out="$(cat "$tmp_out/sf")"
case "$out" in
  *"verify.test took"*|*"verify.test takes"*) bad "a failing suite gets no slow-suite line" "$out" ;;
  *"FAIL  verify.test does not run ("*) ok "a failing suite keeps its existing line and gets no slow-suite line" ;;
  *) bad "a failing suite keeps its existing line" "$(printf '%s\n' "$out" | grep 'verify\.test ')" ;;
esac

# ---- behaviour 4: at or under the threshold, nothing new is said
# `true` under the default 60. The comparison is exclusive (a run equal to the threshold does not
# warn), which no real run lands on reliably, so a reviewer reads it in bin/keel. Absent, a
# 9 digit maximum and the digit strings are all quiet, and absent is quiet without a word.
sq0="$(speed_fixture true)"
for lit in 60 UNSET 999999999 '"90"' '"090"'; do
    setj "$sq0" gates.suite_warn_seconds "$lit"
    out="$(doc_run "$sq0")"
    case "$out" in
      *"suite_warn_seconds"*|*"verify.test took"*|*"verify.test takes"*)
        bad "a fast suite says nothing new (threshold $lit)" "$(printf '%s\n' "$out" | grep 'suite_warn\|verify\.test ')" ;;
      *"ok    verify.test runs ("*) ok "a fast suite says nothing new (threshold $lit)" ;;
      *) bad "a fast suite says nothing new (threshold $lit)" "no verify.test runs line: $out" ;;
    esac
done

# ---- behaviour 5: a suite managed by verify.test_affected is not warned about
out="$(cat "$tmp_out/sm")"
el="$(ran_seconds "$out")"
want="ok    verify.test takes ${el}s, over 1s; tdd runs verify.test_affected at unit boundaries instead, so the suite runs once at the start of each task, in review-code, ship and CI"
if [ -n "$el" ] && printf '%s\n' "$out" | grep -qxF "$want" \
   && ! printf '%s\n' "$out" | grep -q '^WARN  verify\.test took'; then
    ok "a slow suite managed by verify.test_affected is an ok line that says why"
else
    bad "a slow suite managed by verify.test_affected is an ok line that says why" \
        "want '$want', got: $(printf '%s\n' "$out" | grep 'verify\.test ')"
fi

# The same string as verify.test saves nothing, so the warning fires and says so. Compared with the
# whitespace at either end removed: `sleep 2 ` is the command `sleep 2`.
for pair in "identical:sa" "with a trailing space:sb" "with a leading space:sc"; do
    label="${pair%%:*}"; out="$(cat "$tmp_out/${pair##*:}")"
    line="$(printf '%s\n' "$out" | grep '^WARN  verify\.test took ' | head -1)"
    case "$line" in
      *"same command as verify.test"*)
        printf '%s\n' "$out" | grep -q '^ok    verify\.test takes' \
          && bad "verify.test_affected $label equals verify.test" "also printed the ok line: $out" \
          || ok "verify.test_affected $label equals verify.test: the warning fires and says so" ;;
      *) bad "verify.test_affected $label equals verify.test" \
             "no warning naming the same command: $(printf '%s\n' "$out" | grep 'verify\.test ')" ;;
    esac
done

# ---- behaviour 6: a bad threshold is named, and 60 is used
bad_threshold_case() {   # bad_threshold_case <label> <doctor output file> <how doctor shows the value>
    local out want
    out="$(cat "$2")"
    want="WARN  gates.suite_warn_seconds is $3, which is not a whole number from 1 to 999999999, so 60 was used. Set it with: keel profile set gates.suite_warn_seconds <seconds>"
    # "60 was used" is checked as behaviour and not only as words: a 1 second suite is over a
    # threshold of 0 and under 60, so a doctor that obeyed the 0 would warn about it too.
    if printf '%s\n' "$out" | grep -qxF "$want" \
       && ! printf '%s\n' "$out" | grep -q '^WARN  verify\.test took'; then
        ok "a threshold of $1 is named, and 60 is used"
    else
        bad "a threshold of $1 is named, and 60 is used" \
            "want '$want', got: $(printf '%s\n' "$out" | grep 'suite_warn\|verify\.test ')"
    fi
}
bad_threshold_case 0 "$tmp_out/s0" 0
# A present null is a bad value and not an absent key: it is what someone writes to turn the
# warning off, and reading it as 60 without a word would leave them believing it worked.
bad_threshold_case null "$tmp_out/sn" "null or empty"
bad_threshold_case '"fast"' "$tmp_out/sq" "'fast'"
# Whole, and still out of range: the message names the range rather than calling it not a number.
bad_threshold_case 1234567890 "$tmp_out/sg" 1234567890
out="$(doc_run "$s0" --fast)"
case "$out" in
  *suite_warn_seconds*) bad "doctor --fast does not read gates.suite_warn_seconds" "$out" ;;
  *) ok "doctor --fast says nothing about a bad gates.suite_warn_seconds: it runs no suite" ;;
esac
rm -rf "$tmp_out" "$sw" "$sp" "$sf" "$sm" "$sa" "$sb" "$sc" "$s0" "$sn" "$sq" "$sg" "$sq0"

# ---- behaviour 7: verify.test_affected is reported and never run
st="$(speed_fixture true)"
for flag in "" --fast; do
    out="$(doc_run "$st" ${flag:+"$flag"})"
    printf '%s\n' "$out" | grep -qxF 'ok    verify.test_affected is null: tdd runs verify.test at each unit boundary' \
      && ok "a null verify.test_affected is an ok line (doctor ${flag:-full})" \
      || bad "a null verify.test_affected is an ok line (doctor ${flag:-full})" \
             "$(printf '%s\n' "$out" | grep 'test_affected')"
done
# A command that leaves evidence behind, as the verify.e2e cases do: it needs a commit only a tdd
# unit has, so doctor must not run it, and the files are a fact on disk where the output is a claim.
setj "$st" verify.test_affected '"touch affected-ran-sentinel {base}"'
for flag in "" --fast; do
    out="$(doc_run "$st" ${flag:+"$flag"})"
    printf '%s\n' "$out" | grep -qxF 'ok    verify.test_affected is set (declared, not run): touch affected-ran-sentinel {base}' \
      && ok "a set verify.test_affected is shown (doctor ${flag:-full})" \
      || bad "a set verify.test_affected is shown (doctor ${flag:-full})" \
             "$(printf '%s\n' "$out" | grep 'test_affected')"
    if [ -e "$st/affected-ran-sentinel" ] || [ -e "$st/{base}" ]; then
        bad "doctor does not execute verify.test_affected (doctor ${flag:-full})" "the sentinel exists, so it ran"
    else
        ok "doctor does not execute verify.test_affected (doctor ${flag:-full})"
    fi
done
# A runner that tracks changes itself needs no {base}, and is not a finding.
setj "$st" verify.test_affected '"echo changed"'
out="$(doc_run "$st")"
printf '%s\n' "$out" | grep -qxF 'ok    verify.test_affected is set (declared, not run): echo changed' \
  && ! printf '%s\n' "$out" | grep -qE '^(WARN|FAIL) .*test_affected' \
  && ok "a verify.test_affected without {base} is accepted" \
  || bad "a verify.test_affected without {base} is accepted" "$(printf '%s\n' "$out" | grep 'test_affected')"
rm -rf "$st"

# ---- behaviour 8: a templated key is kept out of the places that run bare commands
# The setup goes through `keel profile set`, which refuses a path the profile lacks, and the value
# is checked before the assertion: a key init never wrote would otherwise leave both cases green
# for want of anything to skip.
sc="$(fixture node-ts)"
( cd "$sc" && "$KEEL" init -y >/dev/null 2>&1 \
  && "$KEEL" profile set verify.test_affected 'npx vitest run --changed {base}' >/dev/null 2>&1 \
  && rm -rf .github && "$KEEL" init -y >/dev/null 2>&1 )
if [ "$(prof_of "$sc" verify.test_affected)" != 'npx vitest run --changed {base}' ]; then
    bad "write_ci skips verify.test_affected" "fixture precondition: the profile does not hold it"
elif [ ! -f "$sc/.github/workflows/ci.yml" ]; then
    bad "write_ci skips verify.test_affected" "fixture precondition: no workflow was written"
elif grep -qF '{base}' "$sc/.github/workflows/ci.yml"; then
    bad "write_ci skips verify.test_affected" "{base} reached CI: $(grep -nF '{base}' "$sc/.github/workflows/ci.yml")"
else
    ok "the generated CI workflow has no line containing {base}"
fi
rm -rf "$sc"

tp="$(fixture bare)"
( cd "$tp" && "$KEEL" init -y >/dev/null 2>&1 )
( cd "$tp" && "$KEEL" guard install >/dev/null 2>&1 )
( cd "$tp" && "$KEEL" profile set conventions.protect_default_branch false >/dev/null 2>&1 )
( cd "$tp" && "$KEEL" profile set verify.test_affected 'npx vitest run --changed {base}' >/dev/null 2>&1 )
( cd "$tp" && "$KEEL" profile set verify.security 'npm audit' >/dev/null 2>&1 )
# Checked before anything is committed, on the baseline: setj below would create the key on a
# profile that never had it, and the case would then compare null with nothing and pass.
tp_pre=1
[ "$(prof_of "$tp" verify.test_affected)" = 'npx vitest run --changed {base}' ] || tp_pre=0
( cd "$tp" && git add -A && git commit -q -m "baseline: both are commands" )
ta_old="$( cd "$tp" && git rev-parse HEAD )"
setj "$tp" verify.test_affected null
( cd "$tp" && git add -A && git commit -q -m "verify.test_affected is now null" )
ta_new="$( cd "$tp" && git rev-parse HEAD )"
push_check() {   # push_check <new sha> <old sha>: the pre-push hook's output, and its status
    ( cd "$tp" && printf 'refs/heads/main %s refs/heads/main %s\n' "$1" "$2" \
        | PATH="$(dirname "$KEEL"):$PATH" .git/hooks/pre-push origin git@example.invalid:gbi/f.git 2>&1 )
}
if [ "$tp_pre" -eq 0 ]; then
    bad "pre-push does not refuse verify.test_affected going null" \
        "fixture precondition: the baseline profile does not hold a verify.test_affected command"
else
    out="$(push_check "$ta_new" "$ta_old")"; rc=$?
    [ "$rc" -eq 0 ] && ok "pre-push does not refuse verify.test_affected going from a command to null" \
      || bad "pre-push does not refuse verify.test_affected going null" "exit $rc: $out"
fi
# The control, in the same repository and through the same hook: a verify command that is run
# bare going null is still refused, with a non-zero exit and not only a mention. Without it the case
# above would pass on a hook that refused nothing.
setj "$tp" verify.security null
( cd "$tp" && git add -A && git commit -q -m "verify.security is now null" )
sec_new="$( cd "$tp" && git rev-parse HEAD )"
out="$(push_check "$sec_new" "$ta_new")"; rc=$?
if [ "$rc" -ne 0 ]; then
    case "$out" in
      *verify.security*) ok "the control: pre-push still refuses verify.security going to null (exit $rc)" ;;
      *) bad "the control: pre-push refuses verify.security going null" "exit $rc but unnamed: $out" ;;
    esac
else
    bad "the control: pre-push refuses verify.security going null" "exit 0: the hook refused nothing"
fi
rm -rf "$tp"

# ---- the interpreter budget: two keys read, no start spent
# doctor's python3 starts are capped at 10 above. A profile written before the keys existed lacks
# both, and json_get spends a start confirming an absence, so the new reads must not go through it
# for a key the profile does not name. A profile without the keys costs no more than one with them.
count_doctor_starts() {   # count_doctor_starts <dir>
    local shimdir real_python n
    shimdir="$(mktemp -d)"; real_python="$(command -v python3)"
    printf '#!/bin/sh\nprintf "x\\n" >> "%s/count"\nexec "%s" "$@"\n' "$shimdir" "$real_python" > "$shimdir/python3"
    chmod +x "$shimdir/python3"; : > "$shimdir/count"
    ( cd "$1" && PATH="$shimdir:$PATH" "$KEEL" doctor >/dev/null 2>&1 )
    n="$(grep -c x "$shimdir/count" 2>/dev/null || true)"
    rm -rf "$shimdir"
    printf '%s' "${n:-99}"
}
# A fixture whose verify.test passes, so that doctor reaches the threshold read: on a suite that
# fails, suite_cost_note is never called, and the case would count starts that skip the read it
# guards.
sk="$(speed_fixture true)"
fresh_starts="$(count_doctor_starts "$sk")"
setj "$sk" verify.test_affected UNSET
setj "$sk" gates.suite_warn_seconds UNSET
setj "$sk" schema_version 5
stale_starts="$(count_doctor_starts "$sk")"
[ "$stale_starts" -ge 1 ] && [ "$stale_starts" -le "$fresh_starts" ] && [ "$fresh_starts" -le 10 ] \
  && ok "a schema 5 profile without the two keys costs doctor no more python3 starts than a schema 6 one ($stale_starts, $fresh_starts)" \
  || bad "doctor's python3 starts with the two keys absent" "$stale_starts on a schema 5 profile against $fresh_starts on a schema 6 one"
rm -rf "$sk" "$speed_tpl"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
