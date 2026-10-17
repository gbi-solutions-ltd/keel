#!/usr/bin/env bash
# keel ci-review: review in CI is opt-in. The workflow file is the switch, so these cases pin what
# the file says (it cannot run on a fork, reads no PR text, grants no write to contents) and that the
# command never overwrites or removes a workflow keel did not write.
#
# The `condition && ok || bad` idiom is safe here, and only here, because both helpers return 0.
# shellcheck disable=SC2015
# Single quotes are deliberate: the marker and the greps are literal text, backticks included.
# shellcheck disable=SC2016
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEEL="$ROOT/bin/keel"
pass=0; fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s\n' "$1"; fail=$((fail+1)); return 0; }

repo() { local d; d="$(mktemp -d)"; ( cd "$d" && git init -q -b main ) >/dev/null 2>&1; printf '%s\n' "$d"; }
W=.github/workflows/keel-review.yml

# 1. Off by default, and status writes nothing.
d="$(repo)"
out="$(cd "$d" && "$KEEL" ci-review status 2>&1)"
case "$out" in *"review in CI: off"*) ok "status says off when no workflow exists" ;; *) bad "status says off: got '$out'" ;; esac
[ ! -e "$d/$W" ] && ok "status writes nothing" || bad "status wrote a file"

# 2. Install writes the workflow, with the mark on its first line. A first install says "wrote".
out="$(cd "$d" && "$KEEL" ci-review install 2>&1)"
first="${out%%$'\n'*}"
case "$first" in
    rewrote*) bad "a first install's first line says rewrote: '$first'" ;;
    "wrote $W."*) ok "a first install's first line starts with wrote" ;;
    *) bad "a first install's first line does not start with wrote: '$first'" ;;
esac
if [ ! -f "$d/$W" ]; then
    bad "install wrote no workflow"
else
    ok "install writes the workflow"
    [ "$(head -n 1 "$d/$W")" = '# installed by `keel ci-review install`. Remove it with `keel ci-review remove`.' ] \
        && ok "the mark is the first line" || bad "the mark is not the first line"

    # 3. What the file says. Inside this branch so a missing file cannot pass a "does not contain".
    grep -q 'pull_request_target' "$d/$W" && bad "uses pull_request_target" || ok "does not use pull_request_target"
    grep -Eq '^[[:space:]]+contents:[[:space:]]*write' "$d/$W" && bad "grants contents: write" || ok "does not grant contents: write"
    grep -Eq 'Edit|Write|git push|git commit' "$d/$W" && bad "allows a tool that changes files" || ok "allows no tool that changes files"
    grep -q 'head.repo.full_name == github.repository' "$d/$W" && ok "skips fork pull requests" || bad "does not skip forks"
    grep -q 'dependabot' "$d/$W" && ok "skips Dependabot, which has no Actions secret" || bad "does not skip Dependabot"
    # github.actor is whoever acted, which on reopened and ready_for_review is not the author.
    grep -Fq "github.event.pull_request.user.login != 'dependabot[bot]'" "$d/$W" \
        && ok "skips a pull request Dependabot authored" || bad "does not skip a pull request Dependabot authored"
    grep -Fq "github.actor != 'dependabot[bot]'" "$d/$W" \
        && ok "skips a run Dependabot acted in" || bad "does not skip a run Dependabot acted in"
    # This line decides whether a secret reaches a job, so the whole of it is pinned: a dropped
    # term, or an && turned into ||, changes who can reach the secret and no per-term case sees it.
    want="    if: github.event.pull_request.draft == false"
    want+=" && github.event.pull_request.head.repo.full_name == github.repository"
    want+=" && github.event.pull_request.user.login != 'dependabot[bot]'"
    want+=" && github.actor != 'dependabot[bot]'"
    ifline="$(grep -E '^[[:space:]]+if:' "$d/$W")"
    [ "$ifline" = "$want" ] && ok "the job's if line is exactly the expected one" || bad "the job's if line is: '$ifline'"
    grep -q 'persist-credentials: false' "$d/$W" && ok "checkout does not persist credentials" || bad "checkout persists credentials"
    grep -Eq 'pull_request\.(title|body)|head\.ref|base\.ref|head_ref|base_ref' "$d/$W" && bad "puts a branch name or PR text in the prompt" || ok "puts no branch name or PR text in the prompt"
    grep -q 'ANTHROPIC_API_KEY' "$d/$W" && ok "reads ANTHROPIC_API_KEY by default" || bad "does not read ANTHROPIC_API_KEY"
    if python3 -c 'import yaml' 2>/dev/null; then
        python3 -c 'import sys,yaml; yaml.safe_load(open(sys.argv[1]))' "$d/$W" 2>/dev/null \
            && ok "parses as YAML" || bad "does not parse as YAML"
    else
        printf '  SKIP  parses as YAML (no pyyaml)\n'
    fi
fi

# The template is installed into projects that have no .github/workflows/ci.yml of keel's, so its
# prose must not name one. A missing template must not pass a "does not contain".
T="$ROOT/templates/ci-review.yml"
if [ -f "$T" ] && ! grep -Fq 'ci.yml' "$T"; then
    ok "the template does not name ci.yml"
else
    bad "the template names ci.yml, or is missing"
fi

# 4. Status once installed, and the oauth variant over keel's own file.
out="$(cd "$d" && "$KEEL" ci-review status 2>&1)"
case "$out" in *"review in CI: on, "*) ok "status says on once installed" ;; *) bad "status says on: got '$out'" ;; esac
out="$(cd "$d" && "$KEEL" ci-review install --oauth 2>&1)"
first="${out%%$'\n'*}"
[ "$first" = "rewrote $W. Local edits to it are replaced." ] \
    && ok "--oauth over keel's file says rewrote on its first line" || bad "--oauth over keel's file: first line '$first'"
if grep -q 'CLAUDE_CODE_OAUTH_TOKEN' "$d/$W" && ! grep -q 'ANTHROPIC_API_KEY' "$d/$W"; then
    ok "--oauth swaps the secret, and re-installing over keel's own file works"
else
    bad "--oauth did not swap the secret"
fi

# 5. Remove deletes keel's file only.
( cd "$d" && "$KEEL" ci-review remove >/dev/null 2>&1 )
[ ! -e "$d/$W" ] && ok "remove deletes keel's workflow" || bad "remove left keel's workflow"

# 6. A workflow keel did not write is never overwritten or removed, even if it quotes the mark.
mkdir -p "$d/.github/workflows"
printf 'name: mine\n' > "$d/$W"
( cd "$d" && "$KEEL" ci-review install >/dev/null 2>&1 ); rc=$?
if [ "$rc" -ne 0 ] && [ "$(cat "$d/$W")" = "name: mine" ]; then
    ok "install refuses over a workflow keel did not write"
else
    bad "install overwrote or accepted a foreign workflow (rc=$rc)"
fi
( cd "$d" && "$KEEL" ci-review remove >/dev/null 2>&1 )
[ "$(cat "$d/$W")" = "name: mine" ] && ok "remove leaves a foreign workflow" || bad "remove deleted a foreign workflow"
printf 'name: mine\n# installed by `keel ci-review install`. Remove it with `keel ci-review remove`.\n' > "$d/$W"
( cd "$d" && "$KEEL" ci-review remove >/dev/null 2>&1 )
[ -e "$d/$W" ] && ok "a quoted mark on a later line does not make a file keel's" || bad "remove deleted a file whose first line is not the mark"

# 7. From a subdirectory it still writes at the repository root, where GitHub reads workflows.
rm -f "$d/$W"; mkdir -p "$d/sub/dir"
( cd "$d/sub/dir" && "$KEEL" ci-review install >/dev/null 2>&1 )
if [ -f "$d/$W" ] && [ ! -e "$d/sub/dir/.github" ]; then
    ok "install from a subdirectory writes at the repository root"
else
    bad "install from a subdirectory wrote in the wrong place"
fi
out="$(cd "$d/sub/dir" && "$KEEL" ci-review status 2>&1)"
case "$out" in *"review in CI: on, "*) ok "status from a subdirectory reads the root file" ;; *) bad "status from a subdirectory: got '$out'" ;; esac

# 8. Outside a git repository, and in a bare one.
n="$(mktemp -d)"
( cd "$n" && "$KEEL" ci-review install >/dev/null 2>&1 ) && bad "installed outside a git repository" || ok "refuses outside a git repository"
b="$(mktemp -d)"; git init -q --bare "$b" >/dev/null 2>&1
( cd "$b" && "$KEEL" ci-review install >/dev/null 2>&1 ) && bad "installed in a bare repository" || ok "refuses in a bare repository"

# 9. Listed in help.
out="$("$KEEL" --help 2>&1)"
case "$out" in *ci-review*) ok "help lists ci-review" ;; *) bad "help does not list ci-review" ;; esac

# 10. No pipe of a command's output into grep with -q. grep -q exits at its first match, so the
# command feeding it can take SIGPIPE, and under pipefail that fails the case at random: `keel
# --help` did, about 6 times in 400 runs under CPU load. Capture the output in a variable and match
# it with case instead. The pattern is built from pieces, so this file does not match itself.
g="gr""ep"
quiet="(-[[:alpha:]]*q|--quiet|--silent)"
pat="(^|[^|])\\|[[:space:]]*[^[:space:]|]*${g}[[:space:]]+(-[^[:space:]]+[[:space:]]+)*${quiet}"
for spec in "yes:-q" "yes:-Eq" "yes:-E -q" "yes:-qE" "yes:--quiet" "no:-c" "no:-E"; do
    line="printf x | ${g} ${spec#*:} x"
    grep -Eq "$pat" <<<"$line" && hit=yes || hit=no
    [ "$hit" = "${spec%%:*}" ] && ok "the pipe check says ${spec%%:*} for a pipe into grep ${spec#*:}" \
        || bad "the pipe check says $hit for a pipe into grep ${spec#*:}"
done
line="${g} -q x file"
grep -Eq "$pat" <<<"$line" && bad "the pipe check flags grep -q on a file" || ok "the pipe check passes grep -q on a file"
hits="$(grep -En "$pat" "${BASH_SOURCE[0]}")"
[ -z "$hits" ] && ok "no command's output is piped into grep -q" || bad "a pipe into grep -q: $hits"

# 11. A write that fails is not reported as a success. bin/keel runs without set -e, so an unchecked
# mkdir, cp or sed redirect printed "wrote" and exited 0 with no file written. Both the cp path and
# the sed path (--oauth) are covered.
write_fails() {
    local label="$1" mode="$2" flag="" r out rc
    [ "$mode" = oauth ] && flag=--oauth
    r="$(repo)"
    case "$label" in
        ".github is a regular file") : > "$r/.github" ;;
        "the workflow directory is read-only") mkdir -p "$r/.github/workflows"; chmod 555 "$r/.github/workflows" ;;
        "the workflow path is a dangling symlink")
            mkdir -p "$r/.github/workflows"; ln -s no-such-dir/keel-review.yml "$r/$W" ;;
    esac
    out="$(cd "$r" && "$KEEL" ci-review install ${flag:+"$flag"} 2>&1)"; rc=$?
    if [ "$rc" -ne 0 ] && [[ "$out" != *wrote* ]] && [[ "$out" == *"could not write"* ]]; then
        ok "install ($mode) fails and says so when $label"
    else
        bad "install ($mode) when $label: rc=$rc, wanted non-zero, no 'wrote', and 'could not write': $out"
    fi
    chmod -R u+w "$r"; rm -rf "$r"
}
for mode in plain oauth; do
    write_fails ".github is a regular file" "$mode"
    write_fails "the workflow path is a dangling symlink" "$mode"
    if [ "$(id -u)" -eq 0 ]; then
        printf '  SKIP  install (%s) fails when the workflow directory is read-only (running as root)\n' "$mode"
    else
        write_fails "the workflow directory is read-only" "$mode"
    fi
done

# 12. A keel install without its template says so and writes nothing. That is a different problem
# from a directory that cannot be written, and the message has to name which. The tree below is a
# copy of bin/keel with the real lib/ and VERSION and no templates/, so HERE resolves to it.
tk="$(mktemp -d)"; mkdir "$tk/bin"; cp -p "$KEEL" "$tk/bin/keel"; ln -s "$ROOT/lib" "$tk/lib"; cp "$ROOT/VERSION" "$tk/VERSION"
t="$(repo)"
out="$(cd "$t" && "$tk/bin/keel" ci-review install 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && [[ "$out" == *"templates/ci-review.yml is missing from this keel install"* ]] && [ ! -e "$t/$W" ]; then
    ok "install without the template says the keel install is missing it, and writes nothing"
else
    bad "install without the template: rc=$rc, file written: $([ -e "$t/$W" ] && echo yes || echo no), output: $out"
fi

# 13. Installing over keel's own file says it rewrote it, on the first line, and that local edits
# are replaced. A bare "wrote" would hide that an edit of the user's was lost.
r3="$(repo)"
( cd "$r3" && "$KEEL" ci-review install >/dev/null 2>&1 )
printf '# local edit\n' >> "$r3/$W"
if grep -Fxq '# local edit' "$r3/$W"; then
    ok "the local edit is in the installed file"
else
    bad "the local edit did not land, so the next two cases prove nothing"
fi
out="$(cd "$r3" && "$KEEL" ci-review install 2>&1)"
first="${out%%$'\n'*}"
[ "$first" = "rewrote $W. Local edits to it are replaced." ] \
    && ok "a second install's first line says rewrote and that local edits are replaced" \
    || bad "a second install's first line: '$first'"
grep -Fxq '# local edit' "$r3/$W" && bad "the local edit survived the second install" || ok "the second install replaced the local edit"

# 14. A CRLF copy of keel's file (a Windows checkout with eol=crlf) is still keel's: the mark is
# compared with the carriage return stripped. The first case proves the fixture has a CR, so a sed
# that wrote none cannot make the other two pass or fail for the wrong reason.
cr="$(printf '\r')"
c="$(repo)"; mkdir -p "$c/.github/workflows"
sed "s/\$/$cr/" "$ROOT/templates/ci-review.yml" > "$c/$W"
crl="$(head -n 1 "$c/$W")"
case "$crl" in
    *"$cr") ok "the CRLF fixture has a carriage return on its first line" ;;
    *) bad "the CRLF fixture has no carriage return on its first line, so the next two cases prove nothing" ;;
esac
out="$(cd "$c" && "$KEEL" ci-review status 2>&1)"
case "$out" in *"review in CI: on, "*) ok "status says on for a CRLF copy of keel's file" ;; *) bad "status for a CRLF copy: got '$out'" ;; esac
( cd "$c" && "$KEEL" ci-review remove >/dev/null 2>&1 )
[ ! -e "$c/$W" ] && ok "remove removes a CRLF copy of keel's file" || bad "remove left a CRLF copy of keel's file"

# 15. Review in CI runs only on GitHub Actions. A repository whose CI is another system, with no
# GitHub workflow beside it, gets nothing written and is told why: keel does not add a second CI
# system.
g1="$(repo)"; : > "$g1/.gitlab-ci.yml"
out="$(cd "$g1" && "$KEEL" ci-review install 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && [ ! -e "$g1/.github" ]; then
    ok "install refuses beside .gitlab-ci.yml and writes no .github"
else
    bad "install beside .gitlab-ci.yml: rc=$rc, .github exists: $([ -e "$g1/.github" ] && echo yes || echo no)"
fi
if [ "$out" = "keel: this repository's CI is gitlab-ci (.gitlab-ci.yml) and it has no GitHub workflow. keel does not add a second CI system, so it wrote nothing." ]; then
    ok "the refusal names gitlab-ci and the file it read, says there is no GitHub workflow, and that keel does not add a second CI system"
else
    bad "the refusal beside .gitlab-ci.yml says: '$out'"
fi

# 16. Status in the same repository says review in CI is not available, and writes nothing.
out="$(cd "$g1" && "$KEEL" ci-review status 2>&1)"
if [ "$out" = "review in CI: not available here. This repository's CI is gitlab-ci (.gitlab-ci.yml) and it has no GitHub workflow, and keel does not add a second CI system." ]; then
    ok "status says not available here, names gitlab-ci and says there is no GitHub workflow"
else
    bad "status beside .gitlab-ci.yml: '$out'"
fi
[ ! -e "$g1/.github" ] && ok "status beside .gitlab-ci.yml writes nothing" || bad "status beside .gitlab-ci.yml wrote .github"

# 17. Another marker in the list is refused too, by its own name.
g2="$(repo)"; : > "$g2/bitbucket-pipelines.yml"
out="$(cd "$g2" && "$KEEL" ci-review install 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && [ ! -e "$g2/.github" ] && [[ "$out" == *bitbucket-pipelines* ]]; then
    ok "install refuses beside bitbucket-pipelines.yml and names bitbucket-pipelines"
else
    bad "install beside bitbucket-pipelines.yml: rc=$rc, output: $out"
fi

# 18. A repository that already runs GitHub Actions beside another system is not refused: adding a
# workflow there adds no second system.
g3="$(repo)"; : > "$g3/.gitlab-ci.yml"; mkdir -p "$g3/.github/workflows"; printf 'name: ci\n' > "$g3/.github/workflows/ci.yml"
out="$(cd "$g3" && "$KEEL" ci-review install 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -f "$g3/$W" ]; then
    ok "install beside .gitlab-ci.yml and a GitHub workflow writes the file"
else
    bad "install beside .gitlab-ci.yml and a GitHub workflow: rc=$rc, output: $out"
fi

# 19. keel's own workflow is not a GitHub workflow for this rule. An install from before the marker
# was added is refused on reinstall, status says why, and remove still deletes it.
g4="$(repo)"
( cd "$g4" && "$KEEL" ci-review install >/dev/null 2>&1 )
if [ -f "$g4/$W" ]; then ok "the fixture for keel's file beside a later marker is installed"; else bad "the fixture was not installed, so the next cases prove nothing"; fi
: > "$g4/.gitlab-ci.yml"
cp "$g4/$W" "$g4/before"
out="$(cd "$g4" && "$KEEL" ci-review install 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && cmp -s "$g4/before" "$g4/$W" && [[ "$out" == *gitlab-ci* ]]; then
    ok "install over keel's own file beside .gitlab-ci.yml refuses and leaves the file"
else
    bad "install over keel's own file beside .gitlab-ci.yml: rc=$rc, output: $out"
fi
out="$(cd "$g4" && "$KEEL" ci-review status 2>&1)"
if [ "$out" = "review in CI: $W is keel's, and this repository's CI is gitlab-ci (.gitlab-ci.yml) and it has no GitHub workflow, so it is a second CI system. 'keel ci-review remove' deletes it." ]; then
    ok "status says keel's file is a second CI system and how to remove it"
else
    bad "status for keel's file beside .gitlab-ci.yml: '$out'"
fi
( cd "$g4" && "$KEEL" ci-review remove >/dev/null 2>&1 )
[ ! -e "$g4/$W" ] && ok "remove deletes keel's file beside .gitlab-ci.yml" || bad "remove left keel's file beside .gitlab-ci.yml"

# 20. The origin's host. A host that is known not to be GitHub is refused, by name. Any other host
# is not, because GitHub Enterprise runs on hosts of any name.
# A fourth argument is text from the URL, a credential, that the output must not contain.
origin_case() {
    local url="$1" want="$2" host="$3" secret="${4:-}" r out rc got
    r="$(repo)"
    ( cd "$r" && git remote add origin "$url" ) >/dev/null 2>&1
    if ! got="$(git -C "$r" remote get-url origin 2>/dev/null)" || [ "$got" != "$url" ]; then
        bad "origin $url: the fixture's git remote add failed, so this case proves nothing"
        rm -rf "$r"
        return 0
    fi
    out="$(cd "$r" && "$KEEL" ci-review install 2>&1)"; rc=$?
    if [ -n "$secret" ] && [[ "$out" == *"$secret"* ]]; then
        bad "origin $url: the output prints the credential '$secret': $out"
    fi
    if [ "$want" = refused ]; then
        if [ "$rc" -ne 0 ] && [ ! -e "$r/.github" ] && [ "$out" = "keel: review in CI runs only on GitHub Actions, and this repository's origin is on $host, where its workflow would never run. keel wrote nothing." ]; then
            ok "origin $url is refused, naming $host"
        else
            bad "origin $url: rc=$rc, wanted a refusal naming $host: $out"
        fi
    else
        if [ "$rc" -eq 0 ] && [ -f "$r/$W" ]; then
            ok "origin $url is not refused"
        else
            bad "origin $url: rc=$rc, wanted the file written: $out"
        fi
    fi
    rm -rf "$r"
}
origin_case https://gitlab.com/acme/pay.git refused gitlab.com
origin_case git@gitlab.example.com:acme/pay.git refused gitlab.example.com
origin_case ssh://git@bitbucket.org:7999/acme/pay.git refused bitbucket.org
origin_case https://dev.azure.com/acme/pay/_git/pay refused dev.azure.com
origin_case git@github.com:acme/pay.git written ''
origin_case https://github.acme.internal/acme/pay.git written ''
# The URL is lower-cased first, every scheme git speaks over a network is read, and Azure DevOps'
# own SSH host, ssh.dev.azure.com, is refused like dev.azure.com.
origin_case https://u:t@GitLab.com/x.git refused gitlab.com 'u:t'
origin_case HTTPS://gitlab.com/x.git refused gitlab.com
origin_case http://gitlab.internal/acme/x.git refused gitlab.internal
origin_case git+ssh://git@gitlab.com/x.git refused gitlab.com
origin_case ssh+git://git@gitlab.com/x.git refused gitlab.com
origin_case git://gitlab.com/x.git refused gitlab.com
origin_case git@ssh.dev.azure.com:v3/acme/pay/pay refused ssh.dev.azure.com
origin_case https://acme.visualstudio.com/pay/_git/pay refused acme.visualstudio.com
origin_case https://bitbucket.acme.com/scm/x.git refused bitbucket.acme.com
# The authority ends at the first '/', '?' or '#', as git ends it, and the host follows the last
# '@' inside it, so an '@' in the path or after a '?' or '#' is not read as userinfo. One trailing
# dot on the host is dropped.
origin_case https://me@acme.com:s3cret@gitlab.com/x.git refused gitlab.com 's3cret'
origin_case https://github.com/a/b@c.git written ''
origin_case https://user@github.com/org/x@gitlab.git written ''
origin_case 'https://github.com?x@gitlab.com/' written ''
origin_case 'https://github.com#x@gitlab.com/' written ''
origin_case https://dev.azure.com./x refused dev.azure.com
# A local path is not a host, even one with gitlab in it, nor with a ':' in it.
origin_case /srv/git/gitlab/x.git written ''
origin_case /srv/git/gitlab.d:2/x.git written ''
# A host holding '[' or ']' does not parse, nor does the remote-helper form <transport>::<address>,
# so none of these is refused.
origin_case '[gitlab.com:2222]:acme/x.git' written ''
origin_case 'ssh://git@[::1]:22/x' written ''
origin_case '[git@gitlab.com:22]:acme/x.git' written ''
origin_case gitlab::x written ''
origin_case gcrypt::git@gitlab.com:x written ''

# 21. Status in a repository whose origin is on gitlab.com says review in CI is not available.
g6="$(repo)"; ( cd "$g6" && git remote add origin https://gitlab.com/acme/pay.git ) >/dev/null 2>&1
out="$(cd "$g6" && "$KEEL" ci-review status 2>&1)"
if [ "$out" = "review in CI: not available here. It runs only on GitHub Actions, and this repository's origin is on gitlab.com." ]; then
    ok "status says not available here for an origin on gitlab.com"
else
    bad "status for an origin on gitlab.com: '$out'"
fi
[ ! -e "$g6/.github" ] && ok "status for an origin on gitlab.com writes nothing" || bad "status for an origin on gitlab.com wrote .github"

# 22. A workflow named only .yaml is a GitHub workflow: install beside .gitlab-ci.yml succeeds.
g7="$(repo)"; : > "$g7/.gitlab-ci.yml"; mkdir -p "$g7/.github/workflows"; printf 'name: ci\n' > "$g7/.github/workflows/ci.yaml"
out="$(cd "$g7" && "$KEEL" ci-review install 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -f "$g7/$W" ]; then
    ok "install beside .gitlab-ci.yml and a ci.yaml workflow writes the file"
else
    bad "install beside .gitlab-ci.yml and a ci.yaml workflow: rc=$rc, output: $out"
fi

# 23. A keel-review.yml keel did not write is a GitHub workflow like any other, so the other CI does
# not refuse; install still will not overwrite it, and status says it is not keel's.
g8="$(repo)"; : > "$g8/.gitlab-ci.yml"; mkdir -p "$g8/.github/workflows"; printf 'name: mine\n' > "$g8/$W"
cp "$g8/$W" "$g8/before"
out="$(cd "$g8" && "$KEEL" ci-review install 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && cmp -s "$g8/before" "$g8/$W" && [[ "$out" == *"keel did not write it"* ]] && [[ "$out" != *gitlab-ci* ]]; then
    ok "install over a user's keel-review.yml beside .gitlab-ci.yml refuses as not keel's file"
else
    bad "install over a user's keel-review.yml beside .gitlab-ci.yml: rc=$rc, output: $out"
fi
out="$(cd "$g8" && "$KEEL" ci-review status 2>&1)"
case "$out" in
    *"exists and is not keel's"*) ok "status says a user's keel-review.yml beside .gitlab-ci.yml is not keel's" ;;
    *) bad "status for a user's keel-review.yml beside .gitlab-ci.yml: '$out'" ;;
esac

# 24. A refused install leaves an unrelated file already in .github byte for byte, and adds nothing.
g5="$(repo)"; : > "$g5/.gitlab-ci.yml"; mkdir -p "$g5/.github"
printf 'version: 2\nupdates: []\n' > "$g5/.github/dependabot.yml"; cp "$g5/.github/dependabot.yml" "$g5/before"
out="$(cd "$g5" && "$KEEL" ci-review install 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && cmp -s "$g5/before" "$g5/.github/dependabot.yml" && [ ! -e "$g5/.github/workflows" ] \
    && [ "$out" = "keel: this repository's CI is gitlab-ci (.gitlab-ci.yml) and it has no GitHub workflow. keel does not add a second CI system, so it wrote nothing." ]; then
    ok "a refused install leaves .github/dependabot.yml byte for byte, adds no workflows directory, and says why"
else
    bad "a refused install beside .github/dependabot.yml: rc=$rc, workflows: $([ -e "$g5/.github/workflows" ] && echo yes || echo no), output: $out"
fi

# 25. Status with keel's own file and an origin on gitlab.com says why the file would never run.
g9="$(repo)"
( cd "$g9" && "$KEEL" ci-review install >/dev/null 2>&1 )
( cd "$g9" && git remote add origin https://gitlab.com/acme/pay.git ) >/dev/null 2>&1
out="$(cd "$g9" && "$KEEL" ci-review status 2>&1)"
if [ "$out" = "review in CI: $W is keel's, but this repository's origin is on gitlab.com, where it would never run. 'keel ci-review remove' deletes it." ]; then
    ok "status says keel's file is on a gitlab.com origin and how to remove it"
else
    bad "status for keel's file and an origin on gitlab.com: '$out'"
fi

# 26. Rule 1 is checked before rule 2: another CI's file and an origin on gitlab.com give rule 1's
# reason.
g10="$(repo)"; : > "$g10/.gitlab-ci.yml"
( cd "$g10" && git remote add origin https://gitlab.com/acme/pay.git ) >/dev/null 2>&1
out="$(cd "$g10" && "$KEEL" ci-review install 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && [ ! -e "$g10/.github" ] \
    && [ "$out" = "keel: this repository's CI is gitlab-ci (.gitlab-ci.yml) and it has no GitHub workflow. keel does not add a second CI system, so it wrote nothing." ]; then
    ok "another CI's file and an origin on gitlab.com give rule 1's reason"
else
    bad "another CI's file and an origin on gitlab.com: rc=$rc, output: $out"
fi

# 27. A refused install run from a subdirectory writes nothing, at the root or there.
g11="$(repo)"; : > "$g11/.gitlab-ci.yml"; mkdir -p "$g11/src/app"
out="$(cd "$g11/src/app" && "$KEEL" ci-review install 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && [ ! -e "$g11/.github" ] && [ ! -e "$g11/src/app/.github" ] \
    && [ "$out" = "keel: this repository's CI is gitlab-ci (.gitlab-ci.yml) and it has no GitHub workflow. keel does not add a second CI system, so it wrote nothing." ]; then
    ok "a refused install from a subdirectory writes nothing at the root"
else
    bad "a refused install from a subdirectory: rc=$rc, root .github: $([ -e "$g11/.github" ] && echo yes || echo no), output: $out"
fi

rm -rf "$d" "$n" "$b" "$tk" "$t" "$r3" "$c" "$g1" "$g2" "$g3" "$g4" "$g5" "$g6" "$g7" "$g8" "$g9" "$g10" "$g11"
printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
