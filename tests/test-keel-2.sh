#!/usr/bin/env bash
# Tests for bin/keel, part 2 of 5: doctor's document checks, keel new, generated CI, and the
# marketplace and plugin checks. Shared helpers and fixtures are in tests/keel-test-lib.sh, which
# says why SC2015 is safe here.
#
# Run from the repository root.

# shellcheck disable=SC2015
# shellcheck disable=SC2016
set -uo pipefail; . "$(dirname "${BASH_SOURCE[0]}")/grep-quiet.sh"
# shellcheck source=tests/keel-test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/keel-test-lib.sh"

# ---- but a project with no tests at all is a different thing ---------------
# Found by running init on a real project with no test script and no runner. verify.test is a WARN
# and verify.test_one a FAIL, so the profile init had just written failed its own doctor on the
# derived field while the root cause was only a warning, and the init note named the warned field
# rather than the failing one. A missing test_one is an oversight only when there are tests to run.

d="$(fixture node-ts)"
printf '{"name":"f"}\n' > "$d/package.json"; rm -f "$d/tsconfig.json"
out="$( cd "$d" && "$KEEL" init -y 2>&1 )"
seed_standards "$d"
case "$out" in *verify.test_one*) ok "the init note names verify.test_one, not just verify.test" ;;
  *) bad "no tests" "the init note never mentioned verify.test_one" ;; esac
out="$( cd "$d" && "$KEEL" doctor 2>&1 )"; rc=$?
case "$out" in *FAIL*test_one*) bad "no tests" "doctor FAILs on test_one where there is no test command either" ;;
  *) ok "doctor does not fail on test_one when verify.test is null too" ;; esac
[ "$rc" -eq 0 ] && ok "and the profile init just wrote passes its own doctor" \
  || bad "no tests" "doctor exited $rc on a project with nothing to run"
rm -rf "$d"

# ---- documents a fresh clone cannot read ----------------------------------
# Both pilots hit this from opposite ends: forex ignored its whole docs root, agroplex ignores 25 of
# its 28 documents and links three of them from the README. The author never sees it, because the
# files are on their disk, and `git status` is structurally blind to ignored files so the natural
# check comes back clean.
#
# Baselined before this check existed. Two agents reviewed agroplex's documentation, one of them
# asked outright what a fresh clone gets. Both read the unreadable files and reported them as
# content problems: "those three linked docs are ~6 months stale" for files that are not in HEAD at
# all, the date coming from `git log`, which answers happily for a path HEAD does not carry. The
# second went on to recommend linking a fourth document that is also ignored.

# The node-ts fixture declares jest, which is not installed, so doctor fails on verify.test alone.
# Without this the exit-code assertions below would hold whether or not the check exists.
runnable_verify() {
    python3 - "$1" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["verify"]={"test":"true","test_one":"true","lint":"true","typecheck":None,"build":None,
             "format":None,"e2e":None,"security":None}
p.write_text(json.dumps(d,indent=2)+"\n")
PY
}

# The agroplex shape exactly: a directory ignored wholesale, one document committed before the rule
# and so still tracked, another removed from the index and now unreachable.
d="$(fixture node-ts)"
( cd "$d" || exit 1
  mkdir -p project_documentation
  printf 'kept\n' > project_documentation/KEPT.md
  printf 'gone\n' > project_documentation/GONE.md
  cat > README.md <<'R'
# f

- [kept](./project_documentation/KEPT.md)
- [gone](./project_documentation/GONE.md)
- [upstream](https://example.com/GONE.md)
R
  git add -A >/dev/null 2>&1 && git commit -q -m init
  git rm -q --cached project_documentation/GONE.md
  printf 'project_documentation/*\n' >> .gitignore
  git add .gitignore >/dev/null 2>&1 && git commit -q -m ignore
  "$KEEL" init -y >/dev/null 2>&1 )
runnable_verify "$d"

out="$( cd "$d" && "$KEEL" doctor 2>&1 || true )"

case "$out" in *"project_documentation/GONE.md"*)
    ok "doctor names a referenced document that is not in HEAD" ;;
  *) bad "referenced docs" "said nothing about a README link a fresh clone cannot open" ;; esac

case "$out" in *"project_documentation/KEPT.md"*)
    bad "referenced docs" "flagged a document that is committed and readable" ;;
  *) ok "doctor leaves the sibling document that is tracked alone" ;; esac

case "$out" in *"example.com"*)
    bad "referenced docs" "flagged an external link, which git cannot carry either way" ;;
  *) ok "doctor ignores links that are not repository paths" ;; esac

# Ignored is a FAIL rather than a WARN: committing does not fix it, the ignore rule has to change
# first, so it is not something the next `git add` clears.
if ( cd "$d" && "$KEEL" doctor >/dev/null 2>&1 ); then
  bad "referenced docs" "doctor passed with a README link no teammate can follow"
else ok "doctor fails on a referenced document the ignore rule keeps out"; fi
rm -rf "$d"

# ---- untracked but not ignored is a warning -------------------------------
# The same defect with a different remedy, and the distinction is the point: this one clears with
# `git add`, so failing on it would fire on every document between being written and being
# committed, which is every document keel itself has just written.

d="$(fixture node-ts)"
( cd "$d" || exit 1
  printf '# f\n\n- [notes](./NOTES.md)\n' > README.md
  printf 'notes\n' > NOTES.md
  git add README.md >/dev/null 2>&1 && git commit -q -m init
  "$KEEL" init -y >/dev/null 2>&1 )
runnable_verify "$d"
seed_standards "$d"

out="$( cd "$d" && "$KEEL" doctor 2>&1 || true )"
case "$out" in *WARN*NOTES.md*) ok "an uncommitted referenced document warns rather than fails" ;;
  *) bad "referenced docs" "expected a WARN naming NOTES.md, got: $(printf '%s\n' "$out" | grep -i notes || echo none)" ;; esac
( cd "$d" && "$KEEL" doctor >/dev/null 2>&1 ) \
  && ok "and doctor still exits 0 on it" \
  || bad "referenced docs" "doctor failed over a document that only needs committing"
rm -rf "$d"

# ---- a link that climbs out of the docs root ------------------------------
# Found by running the finished check against keel itself, which reported five of its own committed
# files missing. `git cat-file -e HEAD:docs/../templates/x.md` does not resolve: git never
# normalises `..` in a tree path, and a document linking a sibling directory is the common case.

d="$(fixture node-ts)"
( cd "$d" || exit 1
  printf '# f\n' > README.md
  mkdir -p templates
  printf 'x\n' > templates/BLOCK.md
  git add -A >/dev/null 2>&1 && git commit -q -m init
  "$KEEL" init -y >/dev/null 2>&1
  printf '\nSee [the block](../templates/BLOCK.md).\n' >> docs/keel/NEXT-STEPS.md
  git add -A >/dev/null 2>&1 && git commit -q -m docs )
runnable_verify "$d"

out="$( cd "$d" && "$KEEL" doctor 2>&1 || true )"
case "$out" in *BLOCK.md*)
    bad "referenced docs" "reported a committed file as unreadable through a '..' link: $(printf '%s\n' "$out" | grep BLOCK.md)" ;;
  *) ok "a '..' link to a committed file resolves" ;; esac
rm -rf "$d"

# ---- CLAUDE.md is read too ------------------------------------------------
# The file most likely to point an agent at a document, and the one keel writes its block into.

d="$(fixture node-ts)"
( cd "$d" || exit 1
  printf '# f\n' > README.md
  mkdir -p internal && printf 'x\n' > internal/RULES.md
  printf 'internal/\n' >> .gitignore
  git add -A >/dev/null 2>&1 && git commit -q -m init
  "$KEEL" init -y >/dev/null 2>&1
  printf '\nSee [the rules](internal/RULES.md).\n' >> CLAUDE.md )

out="$( cd "$d" && "$KEEL" doctor 2>&1 || true )"
case "$out" in *"internal/RULES.md"*) ok "doctor reads CLAUDE.md links, not only the README" ;;
  *) bad "referenced docs" "missed an unreadable document linked from CLAUDE.md" ;; esac
rm -rf "$d"

# ---- no profile at all ---------------------------------------------------

d="$(fixture bare)"
if ( cd "$d" && "$KEEL" doctor >/dev/null 2>&1 ); then bad "doctor no profile" "passed"
else ok "doctor fails when there is no profile"; fi
rm -rf "$d"

# ---- keel new -------------------------------------------------------------
# The property that matters: a freshly created project's only doctor problem is the one action item
# it was told about (write docs/standards.md, NEXT-STEPS.md step 1), and once that is done, doctor is
# clean. gates.coding_standards defaults to required and `new` cannot write the document itself: that
# needs the coding-standards skill's own judgement about which house references apply, which `new`,
# a plain shell script, does not have.

parent="$(mktemp -d)"
( cd "$parent" && "$KEEL" new svc-node --stack node >/dev/null 2>&1 )
d="$parent/svc-node"

[ -d "$d" ] && ok "new creates the project directory" || bad "new" "no directory"
[ -f "$d/.keel/profile.json" ] && ok "new writes a profile" || bad "new" "no profile"
[ -f "$d/CLAUDE.md" ] && ok "new writes the CLAUDE.md block" || bad "new" "no CLAUDE.md"
grep -qF '<!-- keel:start' "$d/CLAUDE.md" 2>/dev/null \
  && ok "new writes no AGENTS.md: CLAUDE.md carries the keel block" \
  || bad "new writes no AGENTS.md" "CLAUDE.md has no keel block"
[ -e "$d/AGENTS.md" ] && bad "new writes no AGENTS.md" "new created AGENTS.md" \
  || ok "new writes no AGENTS.md: no AGENTS.md is created"
[ -d "$d/docs/keel" ] && ok "new scaffolds the docs root" || bad "new" "no docs root"
( cd "$d" && git rev-parse --git-dir >/dev/null 2>&1 ) && ok "new initialises git" || bad "new" "not a repo"
[ -f "$d/.github/workflows/ci.yml" ] && ok "new writes a CI workflow" || bad "new" "no CI"

out="$( cd "$d" && "$KEEL" doctor 2>&1 )"
case "$out" in
  *"gates.coding_standards is required"*"standards.md does not exist"*) ok "a new project names the one thing it still owes doctor" ;;
  *) bad "new" "doctor's only complaint on a fresh project should be the missing standards.md, got: $out" ;;
esac
[ "$(printf '%s\n' "$out" | grep -c '^FAIL')" -eq 1 ] && ok "and that is the only FAIL a fresh project has" \
  || bad "new" "doctor found more than the one named problem: $out"

# The whole point: once the named prerequisite is met, the generated verify commands actually run.
seed_standards "$d"
if ( cd "$d" && "$KEEL" doctor >/dev/null 2>&1 ); then ok "a new project passes keel doctor once standards.md exists"
else bad "new" "doctor still fails on a freshly created project with standards.md in place"; fi

# And the sample test must genuinely pass, not just exist.
tc="$(prof_of "$d" verify.test)"
if ( cd "$d" && eval "$tc" >/dev/null 2>&1 ); then ok "the generated test command passes"
else bad "new" "generated test command '$tc' fails"; fi

# One commit, so the project has a baseline.
n="$( cd "$d" && git rev-list --count HEAD 2>/dev/null || echo 0 )"
[ "$n" = "1" ] && ok "new makes one initial commit" || bad "new" "expected 1 commit, got $n"
rm -rf "$parent"

# --- keel doctor --json ---------------------------------------------------------------------
dj="$(fixture bare)"
( cd "$dj" && "$KEEL" init -y >/dev/null 2>&1 )
out="$( cd "$dj" && "$KEEL" doctor --json --fast 2>/dev/null )"
printf '%s' "$out" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null \
  && ok "keel doctor --json prints one parseable JSON document" \
  || bad "doctor --json" "output did not parse as JSON: $out"

sv="$(printf '%s' "$out" | python3 -c "import json,sys; print(json.load(sys.stdin).get('schema_version'))")"
[ "$sv" != "None" ] && [ -n "$sv" ] && ok "doctor --json reports schema_version" \
  || bad "doctor --json" "schema_version missing or null"

nfindings="$(printf '%s' "$out" | python3 -c "import json,sys; print(len(json.load(sys.stdin)['findings']))")"
[ "$nfindings" -gt 0 ] && ok "doctor --json reports at least one finding" \
  || bad "doctor --json" "findings array is empty"

# The harness set is retired in schema 7, and doctor --json no longer reports one.
has_h="$(printf '%s' "$out" | python3 -c "import json,sys; print('harnesses' in json.load(sys.stdin))")"
[ "$has_h" = False ] && ok "doctor --json has no harnesses key" \
  || bad "doctor --json has no harnesses key" "harnesses is still reported"

# --fast without --json still behaves exactly as before
( cd "$dj" && "$KEEL" doctor --fast >/dev/null 2>&1 )
rc_text=$?
( cd "$dj" && "$KEEL" doctor --json --fast >/dev/null 2>&1 )
rc_json=$?
[ "$rc_text" -eq "$rc_json" ] && ok "doctor --json exits the same as text mode on the same project" \
  || bad "doctor --json" "exit code differs from text mode: text=$rc_text json=$rc_json"
rm -rf "$dj"

# --- keel doctor --json without python3 -----------------------------------------------------
# Simulates python3 being absent: a PATH built from symlinks to everything the real PATH offers
# except python3 itself, so git, sed, and the rest doctor shells out to still work. Before this
# fix, the python3 call cmd_doctor makes to build the JSON failed silently to stdout (just a
# "command not found" on stderr) while still exiting however cmd_doctor_text exited, leaving a
# fleet script with an empty "JSON" and no explanation.
dnp="$(fixture bare)"
( cd "$dnp" && "$KEEL" init -y >/dev/null 2>&1 )
nopy_dir="$(mktemp -d)"
oldifs="$IFS"; IFS=':'
for pd in $PATH; do
  [ -d "$pd" ] || continue
  for f in "$pd"/*; do
    [ -e "$f" ] || continue
    b="$(basename "$f")"
    case "$b" in python3|python3.*|python) continue ;; esac
    [ -e "$nopy_dir/$b" ] || ln -s "$f" "$nopy_dir/$b" 2>/dev/null
  done
done
IFS="$oldifs"
nopy_stdout="$(mktemp)"
nopy_err="$( cd "$dnp" && PATH="$nopy_dir" "$KEEL" doctor --json --fast 2>&1 1>"$nopy_stdout" )"
nopy_rc=$?
[ "$nopy_rc" -ne 0 ] && ok "doctor --json exits non-zero when python3 is absent" \
  || bad "doctor --json" "exited 0 with python3 hidden from PATH"
case "$nopy_err" in *python3*) ok "doctor --json's error names python3 when it is absent" ;;
  *) bad "doctor --json" "stderr did not mention python3: $nopy_err" ;; esac
[ -s "$nopy_stdout" ] && bad "doctor --json" "stdout was not empty with python3 hidden: $(cat "$nopy_stdout")" \
  || ok "doctor --json prints nothing to stdout when python3 is absent, rather than garbage"
rm -rf "$dnp" "$nopy_dir"; rm -f "$nopy_stdout"

# --- have_python: a Windows Store python3 alias must read as absent, not present ---------------
# Windows' App Execution Alias puts a python3.exe on PATH even when Python is not installed: it
# prints a not-found message and exits 49 without doing anything. `command -v python3` only checks
# that the name resolves on PATH, not that it runs, so it reported this shim as present and every
# check gated on have_python believed python3 worked. Distinct from the doctor --json case above,
# which is a python3 truly absent from PATH; this one is present and broken.
hpd="$(fixture bare)"
( cd "$hpd" && "$KEEL" init -y >/dev/null 2>&1 )
storeshim="$(mktemp -d)"
cat > "$storeshim/python3" <<'SHIM'
#!/bin/sh
printf 'Python was not found; run without arguments to install from the Microsoft Store.\n'
exit 49
SHIM
chmod +x "$storeshim/python3"
hp_out="$( cd "$hpd" && PATH="$storeshim:$PATH" "$KEEL" doctor --fast 2>&1 )"
case "$hp_out" in
  *"profile is not valid JSON"*) bad "have_python" "doctor treated the Store alias as a working python3, reporting 'profile is not valid JSON' instead of 'python3 absent'. Got: $hp_out" ;;
  *"python3 absent"*) ok "have_python reads a Store-alias python3 (runs, prints not-found, exits 49) as absent" ;;
  *) bad "have_python" "doctor reported neither outcome. Got: $hp_out" ;;
esac
rm -rf "$hpd" "$storeshim"

# --- doctor's profile-parse check distinguishes "python3 did not run" from "invalid JSON" ------
# Before this fix, any nonzero exit from the `import json` check was folded into "profile is not
# valid JSON", even when the profile parses fine and python3 failed for an unrelated reason. The
# stub below passes have_python's own probe (`python3 -c pass` exits 0) but fails this specific
# check with a message that names no JSON error, simulating any interpreter failure that is not
# the profile being invalid.
dpd="$(fixture bare)"
( cd "$dpd" && "$KEEL" init -y >/dev/null 2>&1 )
dualshim="$(mktemp -d)"
cat > "$dualshim/python3" <<'SHIM'
#!/bin/sh
if [ "$1" = "-c" ] && [ "$2" = "pass" ]; then
    exit 0
fi
printf 'boom: unrelated interpreter failure\n' >&2
exit 3
SHIM
chmod +x "$dualshim/python3"
dp_out="$( cd "$dpd" && PATH="$dualshim:$PATH" "$KEEL" doctor --fast 2>&1 )"
case "$dp_out" in
  *"profile is not valid JSON"*) bad "doctor profile-parse" "a non-JSON interpreter failure was reported as 'profile is not valid JSON'. Got: $dp_out" ;;
  *"boom: unrelated interpreter failure"*) ok "doctor's profile-parse check surfaces python3's own stderr instead of assuming invalid JSON" ;;
  *) bad "doctor profile-parse" "the failure was silently swallowed instead of naming what python3 said. Got: $dp_out" ;;
esac
rm -rf "$dpd" "$dualshim"

# --- json_load strips a CRLF-emitting python3's trailing \r before caching ---------------------
# Windows' text-mode stdout adds \r before \n on every printed line. `read -r` does not strip it,
# so a cached value carried an invisible trailing CR that broke exact-string comparisons downstream.
crd="$(fixture bare)"
( cd "$crd" && "$KEEL" init -y >/dev/null 2>&1 )
crlfdir="$(mktemp -d)"
real_python="$(command -v python3)"
cat > "$crlfdir/python3" <<CRLF
#!/usr/bin/env bash
"$real_python" "\$@" | awk '{printf "%s\r\n", \$0}'
exit "\${PIPESTATUS[0]}"
CRLF
chmod +x "$crlfdir/python3"
crlf_got="$( cd "$crd" && PATH="$crlfdir:$PATH" "$KEEL" profile get project.kind 2>/dev/null )"
case "$crlf_got" in
  *$'\r') bad "json_load" "profile get returned a trailing CR: [$crlf_got]" ;;
  *) ok "json_load strips a CRLF-emitting python3's trailing CR before caching" ;;
esac
rm -rf "$crd" "$crlfdir"

# --- keel doctor --json when the docs root is gitignored -------------------------------------
# check_docs_ignored's failure branch used to print only to stderr (via err, not fail), so no
# FAIL line reached stdout for the JSON reshaper even though problems was incremented and the
# real exit code was nonzero: a --json consumer could see problems: 0 and an empty findings entry
# for this check while the process exited nonzero. Reuses the "gitignored docs root" setup used
# against `keel init` in tests/test-keel.sh, against `keel doctor --json` instead.
ddi="$(fixture bare)"
( cd "$ddi" && "$KEEL" init -y >/dev/null 2>&1 )
printf 'docs/\n' >> "$ddi/.gitignore"
dout="$( cd "$ddi" && "$KEEL" doctor --json --fast 2>/dev/null )"
drc=$?
dproblems="$(printf '%s' "$dout" | python3 -c "import json,sys; print(json.load(sys.stdin)['problems'])" 2>/dev/null)"
[ "$drc" -ne 0 ] && [ "${dproblems:-0}" -ge 1 ] \
  && ok "doctor --json's problems count agrees with a nonzero exit when the docs root is gitignored" \
  || bad "doctor --json" "exit=$drc problems=$dproblems: the docs-root check's outcome must reach both"
case "$dout" in *"is ignored by git"*) ok "doctor --json's findings include the gitignored docs root" ;;
  *) bad "doctor --json" "findings did not mention the gitignored docs root: $dout" ;; esac
rm -rf "$ddi"

# ---- gates.coding_standards: required needs a document to check against ---------------------
# A required gate with no <docs_root>/standards.md enforces nothing and reads as configured, which
# is the one state doctor has to name. FR-10, docs/prd/coding-standards-enforcement.md.
cs="$(fixture node-ts)"
( cd "$cs" && "$KEEL" init -y >/dev/null 2>&1 )
( cd "$cs" && "$KEEL" profile set gates.coding_standards required >/dev/null 2>&1 )
out="$( cd "$cs" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"FAIL"*"standards.md does not exist"*) ok "doctor fails a required gate with no standards document" ;;
  *) bad "coding_standards" "no FAIL naming the missing standards document. Got: $out" ;;
esac
mkdir -p "$cs/docs/keel" && printf '# Standards\n' > "$cs/docs/keel/standards.md"
out="$( cd "$cs" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"standards.md exists"*) ok "doctor reports ok once the document exists" ;;
  *) bad "coding_standards" "no ok line for the present document. Got: $out" ;;
esac
rm -f "$cs/docs/keel/standards.md"
( cd "$cs" && "$KEEL" profile set gates.coding_standards warn >/dev/null 2>&1 )
out="$( cd "$cs" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"standards.md does not exist"*) bad "coding_standards" "warn must not fail on a missing document. Got: $out" ;;
  *) ok "a warn gate does not fail on a missing standards document" ;;
esac
( cd "$cs" && "$KEEL" profile set gates.coding_standards off >/dev/null 2>&1 )
out="$( cd "$cs" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"standards.md does not exist"*) bad "coding_standards" "off must not fail on a missing document. Got: $out" ;;
  *) ok "an off gate does not fail on a missing standards document" ;;
esac
rm -rf "$cs"

# ---- init sets strict type checking where the project has not decided --------------------------
# house-defaults.md, "Types and tooling": strict type checking on. The compiler can hold this one,
# so init sets it where tsconfig.json is silent and leaves any value the project chose, either way.
# FR-05, FR-07, NFR-01, docs/prd/coding-standards-enforcement.md.
ts="$(fixture node-ts)"                      # this fixture's tsconfig.json is `{}`
( cd "$ts" && "$KEEL" init -y >/dev/null 2>&1 )
strict="$(python3 -c "import json;print(json.load(open('$ts/tsconfig.json')).get('compilerOptions',{}).get('strict'))")"
[ "$strict" = "True" ] && ok "init sets compilerOptions.strict on a tsconfig that does not decide it" \
  || bad "tsconfig" "compilerOptions.strict is '$strict' after init, want True"
before="$(cat "$ts/tsconfig.json")"
( cd "$ts" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(cat "$ts/tsconfig.json")" = "$before" ] && ok "re-running init leaves a tsconfig it already set byte identical" \
  || bad "tsconfig" "second init changed tsconfig.json"
rm -rf "$ts"

ts2="$(fixture node-ts)"
printf '{ "compilerOptions": { "strict": false, "target": "es2022" } }\n' > "$ts2/tsconfig.json"
( cd "$ts2" && "$KEEL" init -y >/dev/null 2>&1 )
strict="$(python3 -c "import json;print(json.load(open('$ts2/tsconfig.json'))['compilerOptions']['strict'])")"
[ "$strict" = "False" ] && ok "a strict the project set to false is left alone" \
  || bad "tsconfig" "init overrode a deliberate strict: false"
rm -rf "$ts2"

ts2b="$(fixture node-ts)"
printf '{ "compilerOptions": { "strict": false } }\n' > "$ts2b/tsconfig.base.json"
printf '{ "extends": "./tsconfig.base.json" }\n' > "$ts2b/tsconfig.json"
( cd "$ts2b" && "$KEEL" init -y >/dev/null 2>&1 )
strict="$(python3 -c "import json;print(json.load(open('$ts2b/tsconfig.json')).get('compilerOptions',{}).get('strict'))")"
[ "$strict" = "None" ] && ok "a tsconfig that extends another config is left alone" \
  || bad "tsconfig" "init set compilerOptions.strict on a tsconfig with extends, overriding the base config's own strict: false"
rm -rf "$ts2b"

ts3="$(fixture node-ts)"
printf '{\n  // a comment makes this JSONC, which json.load rejects\n  "compilerOptions": {}\n}\n' > "$ts3/tsconfig.json"
before="$(cat "$ts3/tsconfig.json")"
out="$( cd "$ts3" && "$KEEL" init -y 2>&1 )"
[ "$(cat "$ts3/tsconfig.json")" = "$before" ] && ok "a tsconfig init cannot parse is left byte identical" \
  || bad "tsconfig" "init rewrote a tsconfig it could not parse"
case "$out" in *"could not be parsed"*) ok "init says when it left tsconfig.json alone" ;;
  *) bad "tsconfig" "no message about the unparsed tsconfig. Got: $out" ;; esac
rm -rf "$ts3"

py="$(fixture python)"
( cd "$py" && "$KEEL" init -y >/dev/null 2>&1 )
[ ! -e "$py/tsconfig.json" ] && ok "a non-TypeScript project gets no tsconfig.json" \
  || bad "tsconfig" "init created tsconfig.json in a python project"
rm -rf "$py"

# --- write_ci reaches every verify.* command, and keel init writes it too ------------------------
w="$(fixture node-ts)"
( cd "$w" && "$KEEL" init -y >/dev/null 2>&1 )
[ -f "$w/.github/workflows/ci.yml" ] && ok "init writes a CI workflow when none exists" \
  || bad "write_ci" "keel init did not write .github/workflows/ci.yml"
for step in lint build typecheck; do
    grep -q "name: $step" "$w/.github/workflows/ci.yml" \
      && ok "generated CI has a $step step" \
      || bad "write_ci" "no '$step' step in the generated workflow, though verify.$step is set by the node-ts fixture"
done
grep -q 'name: e2e\|name: security' "$w/.github/workflows/ci.yml" \
  && bad "write_ci" "e2e or security step present though both are null on this fixture" \
  || ok "write_ci adds no step for a null verify command"
rm -rf "$w"

# init never overwrites a hand-authored workflow
w2="$(fixture node-ts)"
mkdir -p "$w2/.github/workflows"
printf 'name: hand-authored\n' > "$w2/.github/workflows/ci.yml"
( cd "$w2" && "$KEEL" init -y >/dev/null 2>&1 )
grep -q 'hand-authored' "$w2/.github/workflows/ci.yml" \
  && ok "init leaves an existing .github/workflows/ci.yml alone" \
  || bad "write_ci" "init overwrote a hand-authored CI file"
rm -rf "$w2"

# and never writes a GitHub workflow into a project that declares another CI platform
w3="$(fixture node-ts)"
: > "$w3/.gitlab-ci.yml"
( cd "$w3" && "$KEEL" init -y >/dev/null 2>&1 )
[ ! -e "$w3/.github/workflows/ci.yml" ] \
  && ok "init writes no GitHub workflow where deploy.ci already names a platform" \
  || bad "write_ci" "init wrote .github/workflows/ci.yml into a project holding .gitlab-ci.yml"
rm -rf "$w3"

# and never writes one where two CI markers make the platform ambiguous, which detect_ci reports
# as null too, the same as no marker at all
w4="$(fixture node-ts)"
: > "$w4/.gitlab-ci.yml"
: > "$w4/Jenkinsfile"
( cd "$w4" && "$KEEL" init -y >/dev/null 2>&1 )
[ ! -e "$w4/.github/workflows/ci.yml" ] \
  && ok "init writes no GitHub workflow where two CI markers make the platform ambiguous" \
  || bad "write_ci" "init wrote .github/workflows/ci.yml into a project holding both .gitlab-ci.yml and Jenkinsfile"
rm -rf "$w4"

# ---- the generated CI audits dependencies, keyed on the package manager ----------------------
# house-defaults.md, "Dependencies": an advisory scan runs in CI and fails the build on a high
# severity finding. Keyed on the manager, because `npm audit` in a pnpm project fails for the
# wrong reason; pip-audit is pointed at requirements.txt where one exists, because a bare runner
# has nothing installed for it to read. FR-06, FR-07, NFR-01, docs/prd/coding-standards-enforcement.md.
a="$(fixture node-ts)"                       # no lockfile: npm by definition
( cd "$a" && "$KEEL" init -y >/dev/null 2>&1 )
grep -q 'run: npm audit --audit-level=high' "$a/.github/workflows/ci.yml" \
  && ok "an npm project's CI audits with npm audit" \
  || bad "write_ci" "no npm audit step: $(grep 'run:' "$a/.github/workflows/ci.yml" | tr '\n' ' ')"
rm -rf "$a"

a2="$(fixture node-ts)"; : > "$a2/pnpm-lock.yaml"
( cd "$a2" && "$KEEL" init -y >/dev/null 2>&1 )
grep -q 'run: pnpm audit --audit-level high' "$a2/.github/workflows/ci.yml" \
  && ok "a pnpm project's CI audits with pnpm audit" || bad "write_ci" "no pnpm audit step"
grep -q 'npm audit --audit-level=high' "$a2/.github/workflows/ci.yml" \
  && bad "write_ci" "npm audit written into a pnpm project" || ok "a pnpm project's CI never runs npm audit"
rm -rf "$a2"

a3="$(fixture node-ts)"; : > "$a3/yarn.lock"
( cd "$a3" && "$KEEL" init -y >/dev/null 2>&1 )
grep -q 'run: yarn npm audit --severity high' "$a3/.github/workflows/ci.yml" \
  && ok "a yarn project's CI audits with yarn npm audit" || bad "write_ci" "no yarn audit step"
rm -rf "$a3"

a4="$(fixture python)"; printf 'requests==2.32.3\n' > "$a4/requirements.txt"
( cd "$a4" && "$KEEL" init -y >/dev/null 2>&1 )
grep -q 'run: pip install pip-audit && pip-audit -r requirements.txt' "$a4/.github/workflows/ci.yml" \
  && ok "a pip project with requirements.txt audits that file" || bad "write_ci" "no pip-audit -r step"
rm -rf "$a4"

a5="$(fixture python)"
( cd "$a5" && "$KEEL" init -y >/dev/null 2>&1 )
grep -q 'run: pip install pip-audit && pip-audit$' "$a5/.github/workflows/ci.yml" \
  && ok "a pip project with no requirements.txt audits the environment" || bad "write_ci" "no plain pip-audit step"
rm -rf "$a5"

a6="$(fixture python)"; : > "$a6/poetry.lock"
out="$( cd "$a6" && "$KEEL" init -y 2>&1 )"
grep -q 'name: Audit dependencies' "$a6/.github/workflows/ci.yml" \
  && bad "write_ci" "an audit step was written for poetry, which has no mapping" \
  || ok "a package manager with no audit mapping gets no step"
case "$out" in *"no dependency audit step"*"poetry"*) ok "init says why no audit step was written" ;;
  *) bad "write_ci" "init did not say the audit step was skipped. Got: $out" ;; esac
rm -rf "$a6"

a8="$(fixture go)"
out="$( cd "$a8" && "$KEEL" init -y 2>&1 )"
case "$out" in *"no dependency audit step"*) bad "write_ci" "a go project was told about an audit mapping that was never for it" ;;
  *) ok "the missing-audit note is silent outside the ecosystems the mapping covers" ;; esac
rm -rf "$a8"

# re-running init does not touch a workflow it already wrote, so the step cannot duplicate
a7="$(fixture node-ts)"
( cd "$a7" && "$KEEL" init -y >/dev/null 2>&1 )
before="$(cat "$a7/.github/workflows/ci.yml")"
( cd "$a7" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(cat "$a7/.github/workflows/ci.yml")" = "$before" ] \
  && ok "a second init leaves the generated workflow, audit step included, byte identical" \
  || bad "write_ci" "second init changed the generated workflow"
rm -rf "$a7"

# Refuses to write into a non-empty directory.
parent="$(mktemp -d)"; mkdir -p "$parent/taken"; echo x > "$parent/taken/file"
if ( cd "$parent" && "$KEEL" new taken --stack node >/dev/null 2>&1 ); then
  bad "new" "overwrote a non-empty directory"
else ok "new refuses a non-empty directory"; fi
rm -rf "$parent"

# Python stack.
parent="$(mktemp -d)"
( cd "$parent" && "$KEEL" new svc-py --stack python >/dev/null 2>&1 )
got="$(prof_of "$parent/svc-py" stack.language)"
[ "$got" = "python" ] && ok "new supports the python stack" || bad "new python" "got '$got'"
seed_standards "$parent/svc-py"
if ( cd "$parent/svc-py" && "$KEEL" doctor >/dev/null 2>&1 ); then ok "a new python project passes doctor once standards.md exists"
else bad "new python" "doctor fails"; fi
rm -rf "$parent"

# ---- pre-code repos, and the artifact map --------------------------------
# Found by running init on a real repo that had 30k words of requirements and no code: doctor
# failed on verify.test_one, which a documents-only project can never satisfy, and the skills would
# have looked for a PRD in docs/keel/prd/ while one already existed under another name.

d="$(fixture bare)"
printf '# Requirements\n' > "$d/requirements.md"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
got="$(prof_of "$d" project.kind)"
[ "$got" = "docs" ] && ok "a repo with no source is detected as kind docs" || bad "pre-code" "kind is '$got', want 'docs'"
seed_standards "$d"
if ( cd "$d" && "$KEEL" doctor >/dev/null 2>&1 ); then ok "doctor passes on a pre-code repo"
else bad "pre-code" "doctor fails on a documents-only repo, which it can never satisfy"; fi
rm -rf "$d"

# A repo with source is still expected to have a test command.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
got="$(prof_of "$d" project.kind)"
[ "$got" = "service" ] && ok "a repo with source is not marked docs" || bad "kind" "got '$got'"
rm -rf "$d"

# The artifact map: init seeds it, and doctor validates any path that is set.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
seed_standards "$d"
if python3 -c "import json,sys;d=json.load(open('$d/.keel/profile.json'));sys.exit(0 if 'artifacts' in d else 1)"; then
  ok "init seeds an artifacts map"; else bad "artifacts" "no artifacts key in the profile"; fi

python3 - "$d" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["artifacts"]["prd"]="docs/PROD-042-requirements.md"
p.write_text(json.dumps(d,indent=2)+"\n")
PY
if ( cd "$d" && "$KEEL" doctor >/dev/null 2>&1 ); then
  bad "artifacts" "doctor passed with a mapped path that is missing"
else ok "doctor fails when an artifact path does not exist"; fi

mkdir -p "$d/docs" && printf '# PRD\n' > "$d/docs/PROD-042-requirements.md"
# Neutralise the verify commands, so this case tests the artifact map and nothing else. The fixture's
# `npm test` runs jest, which is not installed, and would fail doctor for an unrelated reason.
python3 - "$d" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["verify"]={k:("true" if k in ("test","test_one","lint") else None) for k in d["verify"]}
p.write_text(json.dumps(d,indent=2)+"\n")
PY
if ( cd "$d" && "$KEEL" doctor >/dev/null 2>&1 ); then ok "doctor passes once the mapped path exists"
else bad "artifacts" "doctor still fails with a valid mapped path"; fi
rm -rf "$d"

# --- doctor's artifact-path check strips a CRLF-emitting python3's trailing \r -----------------
# The artifacts loop compares a path read from python3's stdout against the filesystem with
# [ -e ]. A real file's path carries no CR, so a value read verbatim off Windows' CRLF stdout
# compared as absent even though the file is right there.
crfd="$(fixture node-ts)"
( cd "$crfd" && "$KEEL" init -y >/dev/null 2>&1 )
seed_standards "$crfd"
python3 - "$crfd" <<'PY'
import json, sys, pathlib
p = pathlib.Path(sys.argv[1]) / ".keel/profile.json"
d = json.loads(p.read_text())
d["artifacts"]["prd"] = "docs/PROD-CRLF-requirements.md"
d["verify"] = {k: ("true" if k in ("test", "test_one", "lint") else None) for k in d["verify"]}
p.write_text(json.dumps(d, indent=2) + "\n")
PY
mkdir -p "$crfd/docs" && printf '# PRD\n' > "$crfd/docs/PROD-CRLF-requirements.md"
crlfdir2="$(mktemp -d)"
real_python2="$(command -v python3)"
cat > "$crlfdir2/python3" <<CRLF2
#!/usr/bin/env bash
"$real_python2" "\$@" | awk '{printf "%s\r\n", \$0}'
exit "\${PIPESTATUS[0]}"
CRLF2
chmod +x "$crlfdir2/python3"
crlf2_out="$( cd "$crfd" && PATH="$crlfdir2:$PATH" "$KEEL" doctor 2>&1 )"
case "$crlf2_out" in
  *"artifacts.prd points at"*"does not exist"*) bad "artifacts CRLF" "a real file compared as missing because its path carried a trailing CR. Got: $crlf2_out" ;;
  *) ok "the artifacts path check strips a CRLF-emitting python3's trailing CR before comparing" ;;
esac
rm -rf "$crfd" "$crlfdir2"

# ---- the marketplace check is advisory, and never mentions gh --------------
# This replaced a check on gh. Doctor used to report that gh was needed to install from the
# private marketplace; it is not, as an install on a machine with no gh proved. The old wording
# sent people to install a tool they did not need. The check that matters is whether the
# marketplace is registered at all, since that is what decides whether a session has any skills.
#
# It stays advisory for the reason the gh check was made advisory, found by CI: a GitHub Actions
# runner has no marketplace registered and is a legitimate state, so failing on it makes doctor
# unusable in every pipeline.

d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
python3 - "$d" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["verify"]={k:("true" if k in ("test","test_one") else None) for k in d["verify"]}
p.write_text(json.dumps(d,indent=2)+"\n")
PY
seed_standards "$d"

# An absent marketplace warns and must not fail, which is the CI case.
if ( cd "$d" && CLAUDE_CONFIG_DIR="$d/empty-config" HOME="$d/empty-home" "$KEEL" doctor >/dev/null 2>&1 ); then
  ok "an unregistered marketplace does not fail doctor"
else bad "marketplace" "doctor failed because no marketplace was registered"; fi

out="$( cd "$d" && CLAUDE_CONFIG_DIR="$d/empty-config" HOME="$d/empty-home" "$KEEL" doctor 2>&1 )"
case "$out" in *"marketplace is not registered"*) ok "doctor names the install command when the marketplace is absent" ;;
  *) bad "marketplace" "doctor said nothing about the missing marketplace" ;; esac

# Registered in CLAUDE_CONFIG_DIR, which is where a profile-based setup keeps it.
mkdir -p "$d/cfg/plugins"
printf '{"keel":{"source":{"source":"github","repo":"gbi-solutions-ltd/keel"}}}\n' \
  > "$d/cfg/plugins/known_marketplaces.json"
out="$( cd "$d" && CLAUDE_CONFIG_DIR="$d/cfg" HOME="$d/empty-home" "$KEEL" doctor 2>&1 )"
case "$out" in *"marketplace is registered"*) ok "doctor finds the marketplace in CLAUDE_CONFIG_DIR" ;;
  *) bad "marketplace" "doctor missed a marketplace in CLAUDE_CONFIG_DIR" ;; esac

# And in the default directory, which is where it lands when CLAUDE_CONFIG_DIR is unset. Both are
# checked because they can differ, and saying "not registered" while it sits in the other one is
# worse than saying nothing. Found on a machine where exactly that was true.
#
# Neither fixture above carries lastUpdated, so both also exercise the unknown-age branch below for
# free. That is why they still pass unchanged: an absent timestamp adds a warning and warnings do
# not fail doctor.
mkdir -p "$d/home/.claude/plugins"
printf '{"keel":{"source":{"source":"github","repo":"gbi-solutions-ltd/keel"}}}\n' \
  > "$d/home/.claude/plugins/known_marketplaces.json"
out="$( cd "$d" && CLAUDE_CONFIG_DIR="$d/empty-config" HOME="$d/home" "$KEEL" doctor 2>&1 )"
case "$out" in *"marketplace is registered"*) ok "doctor falls back to the default config directory" ;;
  *) bad "marketplace" "doctor missed a marketplace in the default directory" ;; esac

# ---- marketplace clone freshness -------------------------------------------
# Registration is a boolean and freshness is not. The clone only moves on `/plugin marketplace
# update`, so an install can sit a full release behind while the clone, the installed copy and its
# gitCommitSha all agree with each other and all disagree with the marketplace. lastUpdated is the
# only local record of when that was last known current.
#
# Every timestamp here is generated relative to now. A hardcoded date makes the suite start failing
# on a day nobody chose.
# Two argument, and deliberately so. A single argument taking either a day count or a literal JSON
# value cannot tell 12345 the number of days from 12345 the numeric lastUpdated, and the first
# version of this helper silently generated a timestamp 12345 days old for the case that was meant
# to prove a non-string is rejected. The test passed the wrong thing and reported it as a product
# failure. An explicit mode is one word longer and cannot do that.
mp_at() {   # mp_at days <n> | mp_at raw <literal-json-value> | mp_at absent
    local ts
    case "$1" in
        days)
            ts="$(python3 -c "
import datetime, sys
print((datetime.datetime.now(datetime.timezone.utc)
       - datetime.timedelta(days=int(sys.argv[1]), hours=1)).strftime('%Y-%m-%dT%H:%M:%S.000Z'))" "$2")"
            printf '{"gbi":{"source":{"source":"github","repo":"gbi-solutions-ltd/keel"},"lastUpdated":"%s"}}\n' "$ts" ;;
        absent) printf '{"gbi":{"source":{"source":"github","repo":"gbi-solutions-ltd/keel"}}}\n' ;;
        raw)    printf '{"gbi":{"source":{"source":"github","repo":"gbi-solutions-ltd/keel"},"lastUpdated":%s}}\n' "$2" ;;
    esac > "$d/cfg/plugins/known_marketplaces.json"
}
mp_doctor() { ( cd "$d" && CLAUDE_CONFIG_DIR="$d/cfg" HOME="$d/empty-home" "$KEEL" doctor 2>&1 ); }

# Well past the threshold. The number is echoed back so the reader can act on it.
mp_at days 30; out="$(mp_doctor)"
case "$out" in *"was last fetched 30 days ago"*) ok "doctor names the age of a stale marketplace clone" ;;
  *) bad "marketplace" "doctor said nothing about a 30 day old marketplace clone" ;; esac

# A stale clone is advisory, never a failure, for the same reason an absent marketplace is: a CI
# runner is a legitimate state and doctor has to stay usable in a pipeline.
mp_at days 30
if ( cd "$d" && CLAUDE_CONFIG_DIR="$d/cfg" HOME="$d/empty-home" "$KEEL" doctor >/dev/null 2>&1 ); then
  ok "a stale marketplace clone does not fail doctor"
else bad "marketplace" "doctor failed because the marketplace clone was stale"; fi

# The boundary, both sides. Seven is inclusive and six is not, which is what makes the threshold a
# tested number rather than a comment. An hour is subtracted in mp_at so a whole-day count cannot
# land on the boundary by rounding.
mp_at days 7; out="$(mp_doctor)"
case "$out" in *"was last fetched 7 days ago"*) ok "seven days is inside the stale threshold" ;;
  *) bad "marketplace" "a seven day old clone did not warn; the threshold is meant to be inclusive" ;; esac

mp_at days 6; out="$(mp_doctor)"
case "$out" in
  *"was last fetched"*) bad "marketplace" "a six day old clone warned; the threshold is meant to exclude it" ;;
  *"was fetched 6 day(s) ago"*) ok "six days is inside the fresh threshold and says so" ;;
  *) bad "marketplace" "doctor said nothing at all about a six day old clone" ;;
esac

# The fresh branch must not read as "you are current". This check measures fetch age, and a local
# check cannot tell fetch age from staleness: a three day old clone was several releases behind
# during the burst of nine tags between 2026-08-17 and 2026-08-20.
mp_at days 1; out="$(mp_doctor)"
case "$out" in *"fetch age and not currency"*) ok "the fresh branch says what it is not measuring" ;;
  *) bad "marketplace" "the fresh branch reads as a currency guarantee" ;; esac

# Absence reads as unknown, never as fine. This is the case the whole check turns on: a silent pass
# here is indistinguishable from a check that never ran.
for spec in "absent||no lastUpdated at all" "raw|12345|a numeric lastUpdated" "raw|\"not-a-date\"|an unparseable lastUpdated"; do
    mode="${spec%%|*}"; rest="${spec#*|}"; val="${rest%%|*}"; label="${rest#*|}"
    mp_at "$mode" "$val"; out="$(mp_doctor)"
    case "$out" in
      *"That is unknown, not current"*)
        case "$out" in
          *"was fetched"*) bad "marketplace" "$label reported an age as well as unknown" ;;
          *) ok "$label reads as unknown rather than current" ;;
        esac ;;
      *) bad "marketplace" "$label did not report the age as unknown" ;;
    esac
done

# A clock skewed forward yields a negative age. It must clamp to today rather than printing a
# negative, which would read as fresher than fresh.
mp_at days -5; out="$(mp_doctor)"
case "$out" in
  *"was fetched 0 day(s) ago"*) ok "a future lastUpdated clamps to zero rather than going negative" ;;
  *"-"[0-9]*" day"*) bad "marketplace" "a future lastUpdated printed a negative age" ;;
  *) bad "marketplace" "a future lastUpdated did not clamp to zero" ;;
esac

case "$out" in *" gh "*) bad "marketplace" "doctor still tells people they need gh" ;;
  *) ok "doctor no longer claims gh is required" ;; esac
rm -rf "$d"

# ---- doctor checks the recommended plugin set -----------------------------
# Specified in docs/04 and never written. Found by the plan sweep.

d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
python3 - "$d" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["verify"]={k:("true" if k in ("test","test_one") else None) for k in d["verify"]}
p.write_text(json.dumps(d,indent=2)+"\n")
PY
seed_standards "$d"
# feature-dev ships a competing pipeline that writes to none of the artifact chain.
python3 - "$d" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".claude/settings.json"; d=json.loads(p.read_text())
d["enabledPlugins"]["feature-dev@claude-plugins-official"]=True
p.write_text(json.dumps(d,indent=2)+"\n")
PY
out="$( cd "$d" && "$KEEL" doctor 2>&1 )"
case "$out" in *feature-dev*) ok "doctor warns when feature-dev is enabled alongside keel" ;;
  *) bad "doctor plugins" "no warning about feature-dev" ;; esac
# A warning, not a failure: it is a judgement call the user may have made deliberately.
if ( cd "$d" && "$KEEL" doctor >/dev/null 2>&1 ); then ok "feature-dev warns without failing"
else bad "doctor plugins" "feature-dev made doctor fail; it is advisory"; fi

# A missing recommended plugin is named, not silently ignored. Isolated from the developer
# machine's own global settings file (`plugin_report` in `lib/harness/claude.sh` reads it
# unconditionally, alongside CLAUDE_CONFIG_DIR, so a user scope that already has
# security-guidance enabled, which this machine's does, masks the project-scope removal below and
# the check never fires): same isolation the marketplace checks above already use.
python3 - "$d" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".claude/settings.json"; d=json.loads(p.read_text())
d["enabledPlugins"]={k:v for k,v in d["enabledPlugins"].items() if "security-guidance" not in k and "feature-dev" not in k}
p.write_text(json.dumps(d,indent=2)+"\n")
PY
out="$( cd "$d" && CLAUDE_CONFIG_DIR="$d/empty-config" HOME="$d/empty-home" "$KEEL" doctor 2>&1 )"
case "$out" in *security-guidance*) ok "doctor names a missing recommended plugin" ;;
  *) bad "doctor plugins" "silent about a missing recommended plugin" ;; esac

# ---- the managed block's budget --------------------------------------------
#
# doc 05 said "enforced by keel doctor" for this budget from the beginning, and nothing enforced it.
# The block sits in the prefix of every request in the repository, so the cost of a line added here
# is paid per request per engineer, forever, and nothing about a session makes that visible.

b="$(fixture node-ts)"
( cd "$b" && "$KEEL" init -y >/dev/null 2>&1 )
out="$( cd "$b" && "$KEEL" doctor 2>&1 )"
case "$out" in *"keel block is about"*) ok "doctor reports the managed block's token cost" ;;
  *) bad "block budget" "doctor said nothing about the block size" ;; esac

# The shipped block must be inside the ceiling, not merely measured. This is the assertion that
# fails when someone adds a paragraph to the template.
case "$out" in *"over the 700 ceiling"*) bad "block budget" "the shipped block exceeds its own ceiling" ;;
  *) ok "the shipped block is within the 700 token ceiling" ;; esac

# The ceiling is where doctor fails, not what the template aims at. Only the ceiling was asserted
# here, so the template drifted to 518 tokens against its own header's stated 450 and shipped that
# way: every project keel configured then opened with a doctor warning about a block keel wrote,
# which teaches people to read the warning as noise. The target needs its own assertion or it is a
# comment.
case "$out" in *"over the 450 target"*) bad "block budget" "the shipped block exceeds its own 450 token target" ;;
  *) ok "the shipped block is within the 450 token target" ;; esac

# And the check has to bite, or it is a number printed for decoration.
python3 - "$b" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]) / "CLAUDE.md"
t = p.read_text()
t = t.replace("<!-- keel:end -->", ("Filler that costs tokens and says nothing at all. " * 90) + "\n<!-- keel:end -->")
p.write_text(t)
PY
if ( cd "$b" && "$KEEL" doctor >/dev/null 2>&1 ); then
    bad "block budget" "an oversized block did not fail doctor"
else
    out="$( cd "$b" && "$KEEL" doctor 2>&1 )"
    case "$out" in *"over the 700 ceiling"*) ok "doctor fails on a block over the ceiling" ;;
      *) bad "block budget" "doctor failed but not because of the block size" ;; esac
fi
rm -rf "$b"

# ---- boundaries against a plugin nobody anticipated ------------------------
#
# The registry of known competing plugins can only name the ones we have met. This is the check that
# does not need to: a plugin shipping a skill name keel also ships is found by reading the
# installed cache, whoever wrote it. The collision is silent in a real session, which is why it is
# worth a warning at all: the model resolves the name to one of the two and records nothing.
rival_cfg="$(mktemp -d)"
mkdir -p "$rival_cfg/plugins/cache/somemarket/rival/1.0.0/skills/tdd"
printf -- '---\nname: tdd\ndescription: Use when writing tests.\n---\n\n# TDD\n' \
  > "$rival_cfg/plugins/cache/somemarket/rival/1.0.0/skills/tdd/SKILL.md"
printf '{"enabledPlugins":{"rival@somemarket":true}}\n' > "$rival_cfg/settings.json"

out="$( cd "$d" && CLAUDE_CONFIG_DIR="$rival_cfg" "$KEEL" doctor 2>&1 )"
case "$out" in *"skill named 'tdd'"*) ok "doctor finds a duplicate skill name from an unknown plugin" ;;
  *) bad "boundaries" "no warning about two plugins shipping 'tdd'" ;; esac
case "$out" in *rival*) ok "the duplicate warning names the other plugin" ;;
  *) bad "boundaries" "the duplicate warning did not say which plugin" ;; esac

# Advisory, like every other boundary finding. Disabling a plugin is the user's call.
if ( cd "$d" && CLAUDE_CONFIG_DIR="$rival_cfg" "$KEEL" doctor >/dev/null 2>&1 ); then
    ok "a duplicate skill name warns without failing"
else bad "boundaries" "a duplicate skill name made doctor fail; it is advisory"; fi

# A plugin whose skills do not overlap must produce nothing. A boundary check that fires on every
# installed plugin is noise, and noise is how a real collision gets scrolled past.
mv "$rival_cfg/plugins/cache/somemarket/rival/1.0.0/skills/tdd" \
   "$rival_cfg/plugins/cache/somemarket/rival/1.0.0/skills/unrelated-thing"
out="$( cd "$d" && CLAUDE_CONFIG_DIR="$rival_cfg" "$KEEL" doctor 2>&1 )"
case "$out" in *"skill named"*) bad "boundaries" "warned about a plugin with no overlapping skill" ;;
  *) ok "a plugin with no overlapping skill produces no boundary warning" ;; esac
rm -rf "$rival_cfg"
rm -rf "$d"

# ---- profile get speaks JSON, not Python ----------------------------------
# Found by running `keel profile set stack.has_ui true` from design-architecture and reading it
# back: the profile holds JSON true and `profile get` returned Python's True, so the value cannot
# round-trip and no shell comparison against `true` works. bin/keel had already grown a workaround
# for this at one call site, accepting both "False" and "false", and not at the other.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
( cd "$d" && "$KEEL" profile set stack.has_ui true >/dev/null 2>&1 )
[ "$( cd "$d" && "$KEEL" profile get stack.has_ui )" = "true" ] \
  && ok "profile get returns a JSON true, not Python's True" \
  || bad "profile get" "returned '$( cd "$d" && "$KEEL" profile get stack.has_ui )', want 'true'"

( cd "$d" && "$KEEL" profile set stack.has_ui false >/dev/null 2>&1 )
[ "$( cd "$d" && "$KEEL" profile get stack.has_ui )" = "false" ] \
  && ok "and a JSON false" \
  || bad "profile get" "returned '$( cd "$d" && "$KEEL" profile get stack.has_ui )', want 'false'"

# What set writes is what get reads. Without this the two halves of one command disagree.
( cd "$d" && "$KEEL" profile set stack.has_ui "$( cd "$d" && "$KEEL" profile get stack.has_ui )" >/dev/null 2>&1 )
python3 -c "
import json,sys
v=json.load(open('$d/.keel/profile.json'))['stack']['has_ui']
sys.exit(0 if v is False else 1)" \
  && ok "a value read back and set again survives as a boolean" \
  || bad "profile get" "round-tripping through get turned the boolean into something else"
rm -rf "$d"

# The internal reader that compared against Python's spelling must still fire. It is the only thing
# that tells a project its has_ui is wrong, and a silent regression here is invisible.
d="$(fixture node-ts)"
mkdir -p "$d/public"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
( cd "$d" && "$KEEL" profile set stack.has_ui false >/dev/null 2>&1 )
out="$( cd "$d" && "$KEEL" doctor 2>&1 || true )"
case "$out" in *"stack.has_ui is false, but this project looks like it has a user interface"*)
    ok "doctor still catches a wrong has_ui after the boolean change" ;;
  *) bad "profile get" "the has_ui mismatch warning stopped firing" ;; esac
rm -rf "$d"

# ---- doctor's summary counts its warnings ---------------------------------
# Three warnings scrolled past, then "keel doctor: no problems". Writing the PR body for 0.6.1
# meant counting them by hand to say "no problems and one warning", which is the tell.
d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && "$KEEL" init -y >/dev/null 2>&1 )
seed_standards "$d"
out="$( cd "$d" && "$KEEL" doctor 2>&1 || true )"
warns="$(printf '%s\n' "$out" | grep -c '^WARN')"
[ "$warns" -gt 0 ] || bad "doctor summary" "fixture produced no warnings, so this proves nothing"
case "$out" in *"keel doctor: no problems, $warns warning"*)
    ok "doctor's summary names the warning count" ;;
  *) bad "doctor summary" "summary ignored $warns warnings: $(printf '%s\n' "$out" | tail -1)" ;; esac
rm -rf "$d"

# ---- what init tells a project to do next ---------------------------------
# Found by running init on an empty directory for a real greenfield project, 2026-08-15. It closed
# by suggesting `use repo-snapshot on this codebase` when there was no codebase, and separately
# demanded verify.test be set by hand on a project that doctor itself excuses. Both messages are the
# first thing a new project reads, and both were wrong for the case the plan calls the more
# important pilot.

d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && "$KEEL" init -y >/dev/null 2>&1 )
out="$( cd "$d" && "$KEEL" init -y 2>&1 )"

case "$out" in *repo-snapshot*) bad "next step" "a project with no code was told to snapshot a codebase" ;;
  *) ok "init does not suggest repo-snapshot where there is no code" ;; esac
case "$out" in *shape-idea*|*write-prd*) ok "init points a pre-implementation project at the artifact chain" ;;
  *) bad "next step" "no useful next step for a greenfield project: $out" ;; esac

# doctor treats kind 'docs' as pre-implementation and says verify commands are not expected. init
# telling the same project to set them by hand is the same state answered two contradictory ways,
# and init's answer is the one read first.
case "$out" in *"no test command was detected"*) bad "next step" "init demanded a test command on a pre-implementation project" ;;
  *) ok "init does not demand verify.test before there is code" ;; esac
rm -rf "$d"

# A project that does have code still gets both, because both are right there.
d="$(fixture node-ts)"
( cd "$d" && rm -f package.json && printf 'const x = 1;\n' > app.ts && git add -A && git commit -qm code )
out="$( cd "$d" && "$KEEL" init -y 2>&1 )"
case "$out" in *repo-snapshot*) ok "a project with code is still pointed at repo-snapshot" ;;
  *) bad "next step" "repo-snapshot was dropped for a project that has code" ;; esac
case "$out" in *"no test command was detected"*) ok "a code project with no test command is still told" ;;
  *) bad "next step" "the missing test command went unreported on a code project" ;; esac
rm -rf "$d"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
