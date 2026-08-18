#!/usr/bin/env bash
# Stack detection. Sourced by bin/keel; not executable on its own.
#
# Reads verify commands from what the project actually declares rather than inferring them from
# the stack. A project's real test command is frequently not the idiomatic one, and a guessed
# command produces a profile that fails at first use.

# Every script in package.json, read once. Filled on the first lookup and never again in this
# process, so a project with no package.json and a stack that never asks still costs nothing.
#
# One interpreter start per lookup was seventeen of init's twenty-four on a node project, because
# detect_verify is called once per verify key and asks for up to three script names each time.
PKG_SCRIPTS=""
PKG_SCRIPTS_LOADED=""

pkg_scripts_load() {
    [ -n "$PKG_SCRIPTS_LOADED" ] && return 0
    [ -f package.json ] || return 0
    have_python || return 0
    # Set after the guards, not before: the flag means loaded, and marking it against a package.json
    # that did not exist yet would serve an empty cache for the rest of the process.
    PKG_SCRIPTS_LOADED=1
    # A name containing a newline is left out, because the format is one line per script and every
    # lookup passes a fixed name anyway. A value containing one is flattened rather than dropped:
    # callers read the value as a presence test and write `npm run <name>`, never the body, so
    # dropping the entry would answer no such script for a project that declares it.
    #
    # No apostrophe in the heredoc below: bash 3.2 does not treat a quoted heredoc body as literal
    # inside a $( ), so one of them breaks the parse of the whole file. shellcheck does not see it.
    PKG_SCRIPTS="$(python3 - <<'PY' 2>/dev/null
import json
try:
    for k, v in json.load(open("package.json")).get("scripts", {}).items():
        k, v = str(k), str(v)
        if "\n" not in k:
            print(f"{k}\t" + v.replace("\n", " "))
except Exception:
    pass
PY
)"
    return 0
}

# Print a package.json script by name, or nothing.
pkg_script() {
    [ -f package.json ] || return 0
    pkg_scripts_load
    [ -n "$PKG_SCRIPTS" ] || return 0
    local k v tab; tab="$(printf '\t')"
    # The redirect is on the loop, not a pipe, so this runs in the current shell and spawns nothing.
    while IFS="$tab" read -r k v; do
        if [ "$k" = "$1" ]; then printf '%s' "$v"; return 0; fi
    done <<< "$PKG_SCRIPTS"
    return 0
}

# Whether any path matching one of the given patterns exists within $1 levels. Depth-bounded and
# stopped at the first hit, because a detector that walks a monorepo costs seconds on every init.
# Only the languages whose manifest is routinely in a subdirectory need this; a top-level `[ -f ]`
# is checked first everywhere it can be, so most repositories never reach a find at all.
find_marker() {   # find_marker <maxdepth> <pattern>...
    local depth="$1" p; shift
    for p in "$@"; do
        # -prune, not -not -path: the latter discards the matches after walking the directory
        # anyway, which on a repository with a large node_modules is the whole cost.
        [ -n "$(find . -maxdepth "$depth" \
                  \( -name node_modules -o -name .git \) -prune -o \
                  -name "$p" -print -quit 2>/dev/null)" ] && return 0
    done
    return 1
}

# Whether this tree is a PL/SQL project. Clauses one to three of the marker, and the fourth through
# has_oracle_token.
#
# NOT MEMOISED, AND THE REASON IS COST RATHER THAN IMPOSSIBILITY. One `keel init` calls this eight
# times, traced by printing FUNCNAME from sql_census during a real init rather than counted by
# reading the caller graph: detect_stack reaches it from write_profile, from project_kind and three
# times by way of detect_has_ui; expected_plugins reaches it four times, twice through detect_has_ui
# and twice directly; and detect_also accounts for one more. This count changes whenever a caller of
# detect_stack, detect_has_ui or detect_also is added or removed, and has to be re-traced rather than
# reasoned about when it does.
#
# A cache is possible: it cannot be filled from inside this function, because every call sits in its
# own `$( )`, but pkg_scripts_load one file over solves exactly that by being called from
# write_profile's own shell at bin/keel:363, and the same shape here would take eight walks to one.
#
# It is not done because the cost does not warrant a new global and a second call site: one census
# measured 0.024 seconds on a 2,200 file tree, so eight of them are about 0.19 seconds, once, at
# init. FR-04 is what keeps that bounded, since a repository declaring any of the thirteen never
# reaches this function at all. Revisit if the census ever grows more expensive.
#
# The same applies to has_oracle_token, which is the second walk and the more expensive one. Its
# worst case is a large manifest-less SQL tree with no Oracle token anywhere, where grep reads every
# file and finds nothing: measured at 102 ms over 800 .sql files, so about 0.8 seconds across the
# eight calls of one init. A tree that fails the count or the dominance test never reaches it, and a
# tree that is genuinely PL/SQL stops at the first match.
is_plsql_tree() {
    local census sqlc othermax
    census="$(sql_census)"
    sqlc="${census%% *}"; othermax="${census##* }"
    [ "${sqlc:-0}" -ge 10 ] && [ "${sqlc:-0}" -gt "${othermax:-0}" ] && has_oracle_token
}

# Echo: two integers, the number of .sql plus .plsql files and the largest number sharing any other
# single extension. One find and one awk, because lib/detect-stack.sh uses neither sed, sort, uniq
# nor tr and this must not be the change that introduces them.
#
# Extensionless files are not counted on either side. They are not a competing extension, so a tree
# of 191 .sql files and 300 Makefiles is still SQL-dominant, which is the intended reading.
#
# The extension is what follows the last dot rather than the first, so .oracle.sql is a .sql file.
# A dot in first position is not an extension and neither is one in last: .gitignore and a name
# ending in a dot are both skipped, the second because every such name shared one empty bucket and
# that bucket could outvote .sql.
#
# -print here, not the -print0 has_oracle_token's fallback uses, and the difference is deliberate.
# Reading NUL-separated records back needs RS="\0", which macOS's default /usr/bin/awk does not
# support: `printf 'a\0b\0c\0' | awk 'BEGIN{RS="\0"}{print}'` prints a and silently drops the
# rest, verified on this project's awk on 2026-08-18. grep and xargs can be assumed to take -0
# portably; awk cannot. The residue is that a filename containing a newline arrives as two records,
# so its extension is read from the tail and a count can move by one. RS="\0" would instead make
# the census read one file and stop.
sql_census() {
    find . \( -name node_modules -o -name .git \) -prune -o -type f -print 2>/dev/null | awk '
        { n = split($0, p, "/"); base = p[n]
          if (!match(base, /\.[^.]+$/) || RSTART == 1) next
          ext = tolower(substr(base, RSTART + 1))
          if (ext == "sql" || ext == "plsql") { s++; next }
          # Package specs and bodies do not count as evidence, because a machine-wide search on
          # 2026-08-18 found none anywhere and PRD A2 ruled them out as markers on that basis. They
          # must not count against the evidence either: 30 .pks plus 30 .pkb plus 12 .sql censused
          # as "12 30" and went undetected. Taking them out of the denominator is the whole of it:
          # they are still not evidence, so 200 .pkb plus 9 .sql censuses as "9 0" and returns
          # nothing. The idiomatic Oracle layout is detected only where ten or more plain .sql sit
          # alongside it. Same principle the line above applies to extensionless files, applied here.
          if (ext == "pks" || ext == "pkb" || ext == "prc" || ext == "fnc") next
          c[ext]++; if (c[ext] > m) m = c[ext] }
        END { print s+0, m+0 }'
}

# Whether any .sql or .plsql file carries a token no other SQL dialect uses. This is clause 4 of the
# PL/SQL marker and it is what stops a PostgreSQL migrations repository being called Oracle.
#
# No other dialect uses the three tokens natively, which is weaker than exclusive: PostgreSQL's
# orafce extension really does provide varchar2 and dbms_output, and a comment reading "these were
# VARCHAR2 columns" matches as readily as a declaration. Outside comments and compatibility shims
# they do not appear, so this is an accepted heuristic and not a proof. %TYPE and %ROWTYPE were
# considered and rejected: PL/pgSQL supports both, so keying on them puts the false positive
# straight back. Do not add them.
#
# -q stops at the first match, which is FR-13: on a repository that is PL/SQL the scan ends at the
# first file, and only a tree with no Oracle token anywhere is read in full.
has_oracle_token() {
    local rc hit
    # Case-folded globs, not -i. The -i flag folds the pattern, never the --include glob, so an
    # all-uppercase Oracle tree passed the census and was invisible here. Verified on BSD grep
    # 2.6.0 and GNU grep 3.11: both match K.SQL, k.sql and k.PlSql, and reject k.txt.
    #
    # [[:blank:]] rather than [[:space:]], because grep is line-based: a class that includes the
    # newline claims a reach across lines that this scan does not have.
    #
    # A file named exactly `.sql` is scanned here and not counted by the census, so a tree can be
    # called PL/SQL on evidence its own census does not acknowledge. Left alone deliberately: the
    # clean fix is a glob that excludes bare dotfiles and there is no portable one, because BSD grep
    # matches --include against the whole path and GNU against the basename, so `?*.[sS][qQ][lL]`
    # still matched ./.sql here. The residue is one file name, and it can only produce a positive on
    # a tree that is already SQL-dominant.
    grep -qriE 'VARCHAR2|DBMS_|PACKAGE[[:blank:]]+BODY' \
        --include='*.[sS][qQ][lL]' --include='*.[pP][lL][sS][qQ][lL]' \
        --exclude-dir=node_modules --exclude-dir=.git . 2>/dev/null
    rc=$?
    [ "$rc" -eq 0 ] && return 0
    [ "$rc" -eq 1 ] && return 1
    # Anything above 1 means either this grep rejected --include, which busybox grep does and which
    # would make every repository on an Alpine host silently not-PL/SQL, or something under the tree
    # could not be read: both GNU and BSD grep also return 2 on an ordinary read error, reproduced
    # with a mode-000 file present and no match anywhere. The answer is not trustworthy in either
    # case, so re-scan with flags every grep has. -print0 and -0 carry an odd filename through
    # intact, which is why they stay.
    #
    # -l into a non-empty test, not -q. xargs runs grep once per batch and fails if any batch fails,
    # so `xargs grep -q` loses a match found in an earlier batch: 60 files in 20-file batches with
    # the token in the first returned 1. Measured 2026-08-18. head -n 1 keeps the early stop.
    #
    # Checked for at least one match before xargs runs at all: GNU xargs runs its command once even
    # on empty input unless given -r, and grep with no file operand then reads the inherited stdin,
    # which is a hang rather than a quick "no match" on Linux. BSD xargs does not have this failure
    # mode, which is why it went unnoticed here. -print -quit is the same idiom find_marker already
    # uses for the same reason: stop at the first hit rather than collect them all.
    [ -n "$(find . \( -name node_modules -o -name .git \) -prune -o \
        -type f \( -name '*.[sS][qQ][lL]' -o -name '*.[pP][lL][sS][qQ][lL]' \) -print -quit 2>/dev/null)" ] \
      || return 1
    hit="$(find . \( -name node_modules -o -name .git \) -prune -o \
        -type f \( -name '*.[sS][qQ][lL]' -o -name '*.[pP][lL][sS][qQ][lL]' \) -print0 2>/dev/null \
      | xargs -0 grep -liE 'VARCHAR2|DBMS_|PACKAGE[[:blank:]]+BODY' 2>/dev/null | head -n 1)"
    [ -n "$hit" ]
}

# The manager this project actually uses. The lockfile is the declaration; the binaries on the
# machine running init are not, because a teammate's machine has a different set.
#
# Two lockfiles are not two declarations, they are none. Whichever this checked first would be a
# precedence rule wearing a declaration's clothes, and the caller would write commands for a manager
# the project abandoned. Nothing is printed, and every command that needs a manager stays null.
# No lockfile at all is different: a bare package.json is npm by definition, not an ambiguity.
detect_js_pm() {
    local pm='' n=0
    if [ -f bun.lockb ] || [ -f bun.lock ]; then pm=bun; n=$((n + 1)); fi
    if [ -f pnpm-lock.yaml ]; then pm=pnpm; n=$((n + 1)); fi
    if [ -f yarn.lock ]; then pm=yarn; n=$((n + 1)); fi
    if [ -f package-lock.json ]; then pm=npm; n=$((n + 1)); fi
    [ "$n" -gt 1 ] && return 0
    [ "$n" -eq 1 ] && { printf '%s' "$pm"; return 0; }
    printf 'npm'
}

# What runs this project's pipeline. Read the way a lockfile is read: a config committed to the
# repository is a declaration, its absence is not, and two of them are not two declarations.
#
# Nothing here opens a file. Naming the cloud a workflow deploys to needs the deep read repo-snapshot
# does, and inferring it from a marker is how a profile ends up authoritative and wrong.
detect_ci() {
    local ci='' n=0 pair
    # A directory, not a file: an empty .github/workflows is what deleting the last workflow leaves.
    if [ -n "$(find .github/workflows -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) \
                 -print -quit 2>/dev/null)" ]; then
        ci=github-actions; n=$((n + 1))
    fi
    for pair in '.gitlab-ci.yml:gitlab-ci' '.circleci/config.yml:circleci' 'Jenkinsfile:jenkins' \
                'azure-pipelines.yml:azure-pipelines' 'bitbucket-pipelines.yml:bitbucket-pipelines' \
                '.drone.yml:drone'; do
        if [ -f "${pair%%:*}" ]; then ci="${pair##*:}"; n=$((n + 1)); fi
    done
    [ "$n" -eq 1 ] && printf '%s' "$ci"
    return 0
}

# Where it ships to, from the manifests that name a destination.
#
# A Dockerfile is deliberately not one of them. It says how the thing is packaged, never where it
# runs: the project this was written for has one and ships the image to a VM over ssh, so reading it
# as a target would be wrong in a field nobody would think to check.
detect_deploy_target() {
    local t='' n=0 pair
    for pair in 'fly.toml:fly' 'vercel.json:vercel' 'netlify.toml:netlify' 'render.yaml:render'; do
        if [ -f "${pair%%:*}" ]; then t="${pair##*:}"; n=$((n + 1)); fi
    done
    [ "$n" -eq 1 ] && printf '%s' "$t"
    return 0
}

# How this project runs a declared package script.
#
# `bun test` is the trap: it runs bun's own test runner and ignores the package script entirely, so
# bun has to use `run` even where the other three do not. Getting this wrong runs a different suite
# than the one the project declared.
pkg_run() {   # pkg_run <script>
    local pm; pm="$(detect_js_pm)"
    case "$pm" in
      '')   ;;
      bun)  printf 'bun run %s' "$1" ;;
      yarn) printf 'yarn %s' "$1" ;;
      *)
        if [ "$1" = test ]; then printf '%s test' "$pm"
        else printf '%s run %s' "$pm" "$1"; fi ;;
    esac
}

# The manager this project actually uses, from its lockfile or its pyproject table.
detect_py_pm() {
    if [ -f uv.lock ]; then printf 'uv'
    elif [ -f poetry.lock ] || grep -qs '\[tool.poetry\]' pyproject.toml; then printf 'poetry'
    elif [ -f pdm.lock ]; then printf 'pdm'
    elif [ -f Pipfile ]; then printf 'pipenv'
    else printf 'pip'; fi
}

# The prefix that runs a tool inside the project environment, empty under plain pip. Without it
# every command assumes the developer has already activated a virtualenv, which is the single most
# common reason a verify command works on one machine and not the next.
py_run() {
    case "$(detect_py_pm)" in
      uv)     printf 'uv run ' ;;
      poetry) printf 'poetry run ' ;;
      pdm)    printf 'pdm run ' ;;
      pipenv) printf 'pipenv run ' ;;
    esac
}

# Whether a tool is named anywhere the project declares its dependencies.
py_declares() {   # py_declares <name>
    grep -qs "$1" pyproject.toml requirements.txt requirements-dev.txt Pipfile setup.cfg tox.ini
}

# Every language with a marker in this tree, one per line, most specific first. The order is the
# priority order: the first line is the primary stack and drives the verify commands, and the rest
# become stack.also. A language appears at most once.
detect_languages() {
    local out=""
    if [ -f package.json ]; then
        if [ -f tsconfig.json ] || grep -q '"typescript"' package.json 2>/dev/null
        then out="$out typescript"; else out="$out javascript"; fi
    fi
    [ -f go.mod ] && out="$out go"
    [ -f composer.json ] && out="$out php"
    { [ -f pyproject.toml ] || [ -f requirements.txt ] || [ -f setup.py ]; } && out="$out python"
    [ -f Cargo.toml ] && out="$out rust"
    [ -f Gemfile ] && out="$out ruby"
    [ -f Package.swift ] && out="$out swift"
    { [ -f .luarc.json ] || [ -f init.lua ] || find_marker 2 '*.rockspec'; } && out="$out lua"
    { [ -f CMakeLists.txt ] || [ -f meson.build ] || [ -f Makefile.am ]; } && out="$out cpp"
    { [ -f global.json ] || find_marker 3 '*.csproj' '*.sln' '*.fsproj'; } && out="$out csharp"

    # Kotlin before java, because a Gradle build is the marker for both and Kotlin is the specific
    # case. Read from the build files rather than the source tree: a Java project with one Kotlin
    # test is still a Java project, and a Gradle build that applies the Kotlin plugin is not.
    #
    # What the build applies, not what it is written in. `build.gradle.kts` was a marker on its own
    # until a plain Java project on the Kotlin DSL, which is the default for new Gradle builds, was
    # called Kotlin and handed `./gradlew compileKotlin`, a task no such build has.
    grep -qs kotlin build.gradle build.gradle.kts && out="$out kotlin"
    if [ -f pom.xml ] || [ -f build.gradle ] || [ -f build.gradle.kts ]; then
        # Where Kotlin already matched, Java is added only if the tree really has Java sources.
        # Otherwise every Kotlin project built with a Groovy build file is reported as Java as well.
        case " $out " in
          # Depth 7, because the conventional path is src/main/java/<group>/<artifact>/A.java and
          # a shallower bound never found the Java half of the mixed repo this branch exists for.
          *" kotlin "*) find_marker 7 '*.java' && out="$out java" ;;
          *)            out="$out java" ;;
        esac
    fi

    # PL/SQL, and it is the only inferred language here. Every branch above reads a file the project
    # declares; PL/SQL has no manifest format, so this infers from the shape of the tree instead.
    #
    # It runs last and only when nothing else matched, which is what makes it safe: any repository
    # carrying a manifest has already been classified and never reaches the census. That ordering is
    # a requirement, FR-04, not an optimisation.
    if [ -z "$out" ] && is_plsql_tree; then
        out="$out plsql"
    fi

    # Word splitting is the point here, and the first occurrence wins so the primary is stable
    # whatever a repository adds later.
    # shellcheck disable=SC2086
    [ -n "$out" ] && printf '%s\n' $out | awk '!seen[$0]++'
    return 0
}

# Echo: language runtime framework pkgmgr, for one language. Split out of detect_stack so the
# primary stack and every secondary language read the same table.
lang_profile() {
    local l="$1"
    case "$l" in
      typescript|javascript)
        local fw=none marker
        # Each framework has its own marker. An earlier version OR'd the nestjs marker into
        # every iteration, so the first name in the list always won and every NestJS service was
        # reported as Next.js.
        for f in nest next nuxt express fastify react vue svelte angular; do
            case "$f" in
              nest) marker='"@nestjs/core"' ;;
              *)    marker="\"$f\"" ;;
            esac
            grep -q "$marker" package.json 2>/dev/null && { fw=$f; break; }
        done
        printf '%s node %s %s\n' "$l" "$fw" "$(detect_js_pm)" ;;
      go)     printf 'go go none go\n' ;;
      php)
        local fw=none
        grep -q 'laravel/framework' composer.json 2>/dev/null && fw=laravel
        grep -q 'symfony/' composer.json 2>/dev/null && fw=symfony
        printf 'php php %s composer\n' "$fw" ;;
      python) printf 'python python none %s\n' "$(detect_py_pm)" ;;
      rust)   printf 'rust rust none cargo\n' ;;
      java|kotlin)
        local g=gradle fw=none
        [ -f pom.xml ] && g=maven
        # Framework, not assumed. Every JVM project was reported as spring, which put a wrong
        # framework in front of every skill that reads the profile.
        grep -qs 'springframework\|spring-boot' pom.xml build.gradle build.gradle.kts && fw=spring
        grep -qs 'io.quarkus' pom.xml build.gradle build.gradle.kts && fw=quarkus
        grep -qs 'io.micronaut' pom.xml build.gradle build.gradle.kts && fw=micronaut
        printf '%s jvm %s %s\n' "$l" "$fw" "$g" ;;
      csharp)
        local fw=none
        grep -rqs 'Microsoft.AspNetCore' --include='*.csproj' . && fw=aspnetcore
        printf 'csharp dotnet %s nuget\n' "$fw" ;;
      ruby)
        local fw=none
        grep -qs "rails" Gemfile && fw=rails
        grep -qs "sinatra" Gemfile && fw=sinatra
        printf 'ruby ruby %s bundler\n' "$fw" ;;
      swift)
        local pm=swiftpm
        find_marker 2 '*.xcodeproj' && pm=xcode
        printf 'swift swift none %s\n' "$pm" ;;
      cpp)
        local pm=make
        [ -f CMakeLists.txt ] && pm=cmake
        [ -f meson.build ] && pm=meson
        printf 'cpp native none %s\n' "$pm" ;;
      lua)    printf 'lua lua none luarocks\n' ;;
      plsql)
        # The framework marker is keel's own apex-export output, written by lib/apex_render.py, so
        # it is self-declaring and cannot be claimed by another tool's manifest.json. The
        # apex_version key is what distinguishes it, not the filename.
        #
        # Matched as a key (quote, name, quote, colon), not a bare substring: a manifest whose value
        # happens to be the string "apex_version" is not an APEX export.
        local fw=none
        grep -qE '"apex_version"[[:space:]]*:' manifest.json 2>/dev/null && fw=apex
        # No package manager exists for PL/SQL. `none` is the honest value and it is what a skill
        # reads to know not to look for one.
        printf 'plsql oracle %s none\n' "$fw" ;;
      *)      printf 'unknown unknown none none\n' ;;
    esac
}

# Echo: language runtime framework pkgmgr, for the primary stack.
detect_stack() {
    local l; l="$(detect_languages | head -n 1)"
    lang_profile "${l:-unknown}"
}

# Every language other than the primary. Empty when the repository is single-stack.
detect_also() {
    detect_languages | tail -n +2
}

# Whether composer.json requires a package. The declaration is the manifest, not the vendor
# directory: vendor/ is gitignored on essentially every PHP project, so a detector that waits for
# it produces an empty profile on every fresh clone.
composer_declares() {   # composer_declares <package>
    grep -qs "\"$1" composer.json
}

# Echo one verify command for $1, or the empty string when the project declares none.
# Never guesses: an absent command becomes null in the profile so a skill knows to ask.
detect_verify() {
    # The language is passed in by write_profile, which already knows it. Detection now touches the
    # filesystem, and this function is called once per verify key.
    local what="$1" lang="${2:-}"
    [ -n "$lang" ] || lang="$(detect_stack | cut -d' ' -f1)"
    case "$lang" in
      typescript|javascript)
        local s; s="$(pkg_script "$what")"
        case "$what" in
          test)
            if [ -n "$s" ]; then pkg_run test
            # No script, but a runner in devDependencies is still the project declaring one. `vitest`
            # alone watches forever, so the non-interactive form is the only correct fallback.
            elif grep -q '"vitest"' package.json 2>/dev/null; then printf 'npx vitest run'
            elif grep -q '"jest"' package.json 2>/dev/null; then printf 'npx jest'; fi ;;
          test_integration) [ -n "$(pkg_script 'test:integration')" ] && pkg_run 'test:integration' ;;
          test_one)
            if [ -n "$(pkg_script test)" ]; then
                case "$(detect_js_pm)" in
                  '')   ;;
                  yarn) printf 'yarn test {path}' ;;
                  bun)  printf 'bun run test -- {path}' ;;
                  pnpm) printf 'pnpm test -- {path}' ;;
                  *)    printf 'npm test -- {path}' ;;
                esac
            elif grep -q '"vitest"' package.json 2>/dev/null; then printf 'npx vitest run {path}'
            elif grep -q '"jest"' package.json 2>/dev/null; then printf 'npx jest {path}'; fi ;;
          build) [ -n "$s" ] && pkg_run build ;;
          lint)
            if [ -n "$s" ]; then pkg_run lint
            elif [ -f biome.json ] || [ -f biome.jsonc ]; then printf 'npx biome check .'
            elif ls eslint.config.* >/dev/null 2>&1 || ls .eslintrc* >/dev/null 2>&1; then printf 'npx eslint .'; fi ;;
          # `npm run format` rewrites files, so it cannot be the gate. Only a declared
          # format:check earns that slot; the writing one is recorded as format_fix, which is
          # what a refusal names as the remedy.
          format)
            if [ -n "$(pkg_script 'format:check')" ]; then pkg_run 'format:check'
            elif [ -f biome.json ] || [ -f biome.jsonc ]; then printf 'npx biome format .'
            # Two tests, not one operand list: `ls a* b*` exits non-zero when either matches
            # nothing, so the single call was an AND and a plain .prettierrc produced null.
            elif ls .prettierrc* >/dev/null 2>&1 || ls prettier.config.* >/dev/null 2>&1; then
                printf 'npx prettier --check .'; fi ;;
          format_fix)
            if [ -n "$(pkg_script format)" ]; then pkg_run format
            elif [ -f biome.json ] || [ -f biome.jsonc ]; then printf 'npx biome format --write .'
            elif ls .prettierrc* >/dev/null 2>&1 || ls prettier.config.* >/dev/null 2>&1; then
                printf 'npx prettier --write .'; fi ;;
          typecheck)
            # A declared script wins. It was previously detected and then discarded for the generic
            # command, which is a different thing on any project whose script passes flags or names
            # a second tsconfig.
            if [ -n "$(pkg_script typecheck)" ]; then pkg_run typecheck
            elif [ -n "$(pkg_script type-check)" ]; then pkg_run type-check
            elif [ -f tsconfig.json ]; then printf 'npx tsc --noEmit'; fi ;;
          e2e) [ -n "$(pkg_script 'test:e2e')" ] && pkg_run 'test:e2e' ;;
        esac ;;
      go)
        case "$what" in
          test) printf 'go test ./...' ;; test_one) printf 'go test {path}' ;;
          build) printf 'go build ./...' ;;
          # The config file in the repository is the declaration, not the binary on this machine.
          # Checking the PATH here freezes one laptop's answer into a file every teammate reads,
          # which is the same mistake the gofmt comment below exists to avoid.
          lint) { [ -f .golangci.yml ] || [ -f .golangci.yaml ] || [ -f .golangci.toml ]; } && printf 'golangci-lint run' ;;
          typecheck) printf 'go vet ./...' ;;
          # gofmt ships with the toolchain, so naming it is not a guess. `gofmt -l` exits 0 even
          # when it lists a file, so the gate has to be the emptiness of its output.
          format)
            # The single quotes are the point: this string is written into the profile and expanded
            # by whoever runs it later, so expanding it here would freeze one machine's answer in.
            # shellcheck disable=SC2016
            printf 'test -z "$(gofmt -l .)"' ;;
          format_fix) printf 'gofmt -w .' ;;
        esac ;;
      python)
        local r; r="$(py_run)"
        case "$what" in
          test)
            if py_declares pytest || [ -f pytest.ini ]; then printf '%spytest' "$r"
            # No pytest anywhere, but a tests directory: the standard library runner is the only
            # thing that is certainly present. Previously `pytest` was written regardless, and
            # doctor then failed on a command the project never had.
            elif [ -d tests ] || [ -d test ]; then printf '%spython -m unittest discover' "$r"; fi ;;
          test_one)
            if py_declares pytest || [ -f pytest.ini ]; then printf '%spytest {path}' "$r"
            elif [ -d tests ] || [ -d test ]; then printf '%spython -m unittest {name}' "$r"; fi ;;
          lint)
            if [ -f .ruff.toml ] || [ -f ruff.toml ] || py_declares ruff; then printf '%sruff check .' "$r"
            elif [ -f .flake8 ] || py_declares flake8; then printf '%sflake8' "$r"
            elif [ -f .pylintrc ] || py_declares pylint; then printf '%spylint .' "$r"; fi ;;
          typecheck)
            if py_declares mypy; then printf '%smypy .' "$r"
            elif [ -f pyrightconfig.json ] || py_declares pyright; then printf '%spyright' "$r"; fi ;;
          # Declared tools only. Nothing ships a formatter with the runtime here, so an assumed
          # one is a command that fails the first time a gate runs it.
          format|format_fix)
            local w=--check; [ "$what" = format_fix ] && w=
            if [ -f .ruff.toml ] || [ -f ruff.toml ] || py_declares ruff; then
                printf '%sruff format %s.' "$r" "${w:+$w }"
            elif py_declares black; then
                printf '%sblack %s.' "$r" "${w:+$w }"
            fi ;;
        esac ;;
      java)
        local g; g=gradle; [ -f pom.xml ] && g=maven
        case "$what:$g" in
          test:gradle) printf './gradlew test' ;; test_one:gradle) printf "./gradlew test --tests '*{name}'" ;;
          build:gradle) printf './gradlew build' ;; typecheck:gradle) printf './gradlew compileJava' ;;
          test:maven) printf 'mvn test' ;; test_one:maven) printf 'mvn test -Dtest={name}' ;;
          build:maven) printf 'mvn package' ;; typecheck:maven) printf 'mvn compile' ;;
          format:gradle)     grep -qs spotless build.gradle build.gradle.kts && printf './gradlew spotlessCheck' ;;
          format_fix:gradle) grep -qs spotless build.gradle build.gradle.kts && printf './gradlew spotlessApply' ;;
          format:maven)      grep -qs spotless pom.xml && printf 'mvn spotless:check' ;;
          format_fix:maven)  grep -qs spotless pom.xml && printf 'mvn spotless:apply' ;;
          lint:gradle) grep -qs checkstyle build.gradle build.gradle.kts && printf './gradlew checkstyleMain' ;;
          lint:maven)  grep -qs maven-checkstyle-plugin pom.xml && printf 'mvn checkstyle:check' ;;
        esac ;;
      php)
        case "$what" in
          test)
            if [ -f artisan ]; then printf 'php artisan test'
            elif composer_declares 'pestphp/pest'; then printf 'vendor/bin/pest'
            elif composer_declares 'phpunit/phpunit' || [ -f phpunit.xml ] || [ -f phpunit.xml.dist ] \
                 || [ -f vendor/bin/phpunit ]; then
                printf 'vendor/bin/phpunit'; fi ;;
          test_one)
            if composer_declares 'pestphp/pest'; then printf 'vendor/bin/pest {path}'
            elif composer_declares 'phpunit/phpunit' || [ -f phpunit.xml ] || [ -f phpunit.xml.dist ] \
                 || [ -f vendor/bin/phpunit ]; then
                printf 'vendor/bin/phpunit {path}'; fi ;;
          typecheck)
            if composer_declares 'phpstan/phpstan' || [ -f phpstan.neon ]; then printf 'vendor/bin/phpstan analyse'
            elif composer_declares 'vimeo/psalm' || [ -f psalm.xml ]; then printf 'vendor/bin/psalm'; fi ;;
          # An installed vendor binary counts as a declaration too. It is not a lookup on the
          # machine's PATH: it is inside the project and it is there because the manifest asked
          # for it, so a repository that has one has said which tool it uses.
          format)
            if composer_declares 'laravel/pint' || [ -f pint.json ] || [ -f vendor/bin/pint ]; then printf 'vendor/bin/pint --test'
            elif composer_declares 'friendsofphp/php-cs-fixer'; then printf 'vendor/bin/php-cs-fixer fix --dry-run --diff'
            elif composer_declares 'squizlabs/php_codesniffer'; then printf 'vendor/bin/phpcs'; fi ;;
          format_fix)
            if composer_declares 'laravel/pint' || [ -f pint.json ] || [ -f vendor/bin/pint ]; then printf 'vendor/bin/pint'
            elif composer_declares 'friendsofphp/php-cs-fixer'; then printf 'vendor/bin/php-cs-fixer fix'
            elif composer_declares 'squizlabs/php_codesniffer'; then printf 'vendor/bin/phpcbf'; fi ;;
        esac ;;
      rust)
        case "$what" in
          test) printf 'cargo test' ;; test_one) printf 'cargo test {name}' ;;
          build) printf 'cargo build' ;; lint) printf 'cargo clippy' ;; typecheck) printf 'cargo check' ;;
          format) printf 'cargo fmt --check' ;; format_fix) printf 'cargo fmt' ;;
        esac ;;
      csharp)
        case "$what" in
          test)     printf 'dotnet test' ;;
          test_one) printf 'dotnet test --filter FullyQualifiedName~{name}' ;;
          build)    printf 'dotnet build' ;;
          # `dotnet format` ships with the SDK, so naming it is not a guess. There is no separate
          # typecheck: the compiler runs as part of build, and a second command that compiles again
          # is a slower way to learn the same thing.
          format)     printf 'dotnet format --verify-no-changes' ;;
          format_fix) printf 'dotnet format' ;;
        esac ;;
      ruby)
        local bx='bundle exec '
        [ -f Gemfile ] || bx=
        case "$what" in
          test)
            if [ -d spec ]; then printf '%srspec' "$bx"
            elif [ -d test ]; then printf '%srake test' "$bx"; fi ;;
          test_one)
            if [ -d spec ]; then printf '%srspec {path}' "$bx"
            elif [ -d test ]; then printf '%sruby -Itest {path}' "$bx"; fi ;;
          # Rubocop reports offences and exits non-zero, so it is the lint gate. Its autocorrect is
          # the fix command. There is no separate check-only formatter to put in `format`, and
          # inventing one would mean running rubocop twice for one answer.
          lint)       { [ -f .rubocop.yml ] || grep -qs rubocop Gemfile; } && printf '%srubocop' "$bx" ;;
          format_fix) { [ -f .rubocop.yml ] || grep -qs rubocop Gemfile; } && printf '%srubocop -A' "$bx" ;;
          typecheck)
            if grep -qs sorbet Gemfile; then printf '%ssrb tc' "$bx"
            elif grep -qs steep Gemfile; then printf '%ssteep check' "$bx"; fi ;;
        esac ;;
      kotlin)
        case "$what" in
          test)      printf './gradlew test' ;;
          test_one)  printf "./gradlew test --tests '*{name}'" ;;
          build)     printf './gradlew build' ;;
          typecheck) printf './gradlew compileKotlin' ;;
          lint)      grep -qs detekt build.gradle build.gradle.kts && printf './gradlew detekt' ;;
          format)
            if grep -qs ktlint build.gradle build.gradle.kts; then printf './gradlew ktlintCheck'
            elif grep -qs spotless build.gradle build.gradle.kts; then printf './gradlew spotlessCheck'; fi ;;
          format_fix)
            if grep -qs ktlint build.gradle build.gradle.kts; then printf './gradlew ktlintFormat'
            elif grep -qs spotless build.gradle build.gradle.kts; then printf './gradlew spotlessApply'; fi ;;
        esac ;;
      swift)
        # An .xcodeproj build needs a scheme name that is not in the repository in any readable
        # form, so nothing is emitted for it. A wrong `xcodebuild -scheme` line is worse than null.
        [ -f Package.swift ] || return 0
        case "$what" in
          test)      printf 'swift test' ;;
          test_one)  printf 'swift test --filter {name}' ;;
          build)     printf 'swift build' ;;
          lint)      [ -f .swiftlint.yml ] && printf 'swiftlint' ;;
          format)     [ -f .swift-format ] && printf 'swift-format lint -r -s .' ;;
          format_fix) [ -f .swift-format ] && printf 'swift-format format -i -r .' ;;
        esac ;;
      cpp)
        case "$what" in
          build) [ -f CMakeLists.txt ] && printf 'cmake --build build' ;;
          test)
            # ctest only has tests to run if the build declares them.
            grep -qs 'enable_testing\|add_test' CMakeLists.txt && printf 'ctest --test-dir build' ;;
          test_one)
            grep -qs 'enable_testing\|add_test' CMakeLists.txt && printf 'ctest --test-dir build -R {name}' ;;
          format)
            # shellcheck disable=SC2016
            [ -f .clang-format ] && printf 'git ls-files "*.c" "*.h" "*.cc" "*.cpp" "*.hpp" | xargs clang-format --dry-run --Werror' ;;
          format_fix)
            # shellcheck disable=SC2016
            [ -f .clang-format ] && printf 'git ls-files "*.c" "*.h" "*.cc" "*.cpp" "*.hpp" | xargs clang-format -i' ;;
          lint)
            # shellcheck disable=SC2016
            [ -f .clang-tidy ] && printf 'git ls-files "*.c" "*.cc" "*.cpp" | xargs clang-tidy -p build' ;;
        esac ;;
      lua)
        case "$what" in
          test)     { [ -f .busted ] || grep -qrs busted --include='*.rockspec' .; } && printf 'busted' ;;
          test_one) { [ -f .busted ] || grep -qrs busted --include='*.rockspec' .; } && printf 'busted {path}' ;;
          lint)     [ -f .luacheckrc ] && printf 'luacheck .' ;;
          # lua-language-server is the same tool the lua-lsp plugin drives, so a project that has
          # configured it has already declared this command.
          typecheck)  [ -f .luarc.json ] && printf 'lua-language-server --check .' ;;
          format)     { [ -f stylua.toml ] || [ -f .stylua.toml ]; } && printf 'stylua --check .' ;;
          format_fix) { [ -f stylua.toml ] || [ -f .stylua.toml ]; } && printf 'stylua .' ;;
        esac ;;
    esac
}

# Whether the project has a user interface. Printed as `true` or `false`, so it can go straight
# into the profile's stack.has_ui, which is what decides whether the frontend standard applies.
#
# This lived inside detect_plugins and was used only to recommend plugins, while write_profile
# wrote a hardcoded false. Every project, including a Next.js one, was told it had no UI.
detect_has_ui() {
    local fw; fw="$(detect_stack | cut -d' ' -f3)"
    # apex is a UI, but not a local one: its pages are stored in the database, so a repository can
    # be a genuine APEX application with no public/ or index.html for the fallback below to find.
    case "$fw" in next|react|vue|svelte|angular|apex) printf 'true'; return 0 ;; esac
    if [ -d public ] || [ -f index.html ]; then printf 'true'; else printf 'false'; fi
}

# Which datastores this project talks to, one per line, for the profile's stack.datastores.
#
# The field was a hardcoded empty list, which is the defect has_ui had above: a profile that always
# says none reads as a detected none. Found on the existing-service pilot, whose repository declared
# postgres and redis in both of the places checked here and was recorded as using neither.
#
# Two signals, because either alone is wrong on a real repository. A dependency list names the client
# library but says nothing in a language keel does not parse; a compose file names what a developer
# runs locally but misses a managed database that exists only as a connection string. The union is
# reported, and a store named twice is still one store.
#
# Deliberately not lockfiles: a transitive driver pulled in by something else is not a declaration
# that this project uses that store, and package-lock.json names every one of them.
detect_datastores() {   # detect_datastores [lang]
    # The language is passed in by write_profile, which already knows it, the same reason
    # detect_verify takes one: detection touches the filesystem, and re-running detect_languages
    # here would repeat sql_census and has_oracle_token's tree walks for a membership check the
    # caller already paid for.
    local lang="${1:-}" files='' f pair
    [ -n "$lang" ] || lang="$(detect_stack | cut -d' ' -f1)"
    for f in package.json requirements.txt pyproject.toml Pipfile go.mod composer.json Gemfile \
             Cargo.toml pom.xml build.gradle build.gradle.kts \
             docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
        [ -f "$f" ] && files="$files $f"
    done
    # PL/SQL first, and outside the manifest loop below. That loop greps dependency files and a
    # PL/SQL repository has none, so a ninth pair in the list could never fire on one. CON-04.
    #
    # PL/SQL is never combined with another language, FR-11, so the primary language alone is
    # exactly the membership test detect_languages used to run a whole second cascade to answer.
    [ "$lang" = plsql ] && printf 'oracle\n'
    [ -z "$files" ] && return 0
    # `"pg"` is quoted rather than bare: the bare token appears inside half the package names on npm.
    for pair in 'postgres:postgres|psycopg|pgx|npgsql|"pg"' \
                'mysql:mysql|mariadb' \
                'redis:redis' \
                'mongodb:mongo' \
                'sqlite:sqlite' \
                'elasticsearch:elasticsearch|opensearch' \
                'cassandra:cassandra' \
                'dynamodb:dynamodb'; do
        # shellcheck disable=SC2086  # $files is a list of names this function built from literals
        grep -qiE "${pair#*:}" $files 2>/dev/null && printf '%s\n' "${pair%%:*}"
    done
    return 0
}

# The language server for one language, or nothing. Every id here is in claude-plugins-official.
# Checked against its marketplace.json rather than assumed: a suggested plugin that does not exist
# fails to resolve in settings.json, which is worse than suggesting nothing.
lang_lsp() {
    case "$1" in
      typescript|javascript) printf 'typescript-lsp' ;;
      python) printf 'pyright-lsp' ;;
      go)     printf 'gopls-lsp' ;;
      php)    printf 'php-lsp' ;;
      java)   printf 'jdtls-lsp' ;;
      kotlin) printf 'kotlin-lsp' ;;
      rust)   printf 'rust-analyzer-lsp' ;;
      csharp) printf 'csharp-lsp' ;;
      ruby)   printf 'ruby-lsp' ;;
      swift)  printf 'swift-lsp' ;;
      cpp)    printf 'clangd-lsp' ;;
      lua)    printf 'lua-lsp' ;;
    esac
}

# Plugins worth recommending for this repository. A polyglot repository gets a server per language,
# because the reason to have one at all is diagnostics in the file being edited, and that file is
# as likely to be in the second language as the first.
detect_plugins() {
    local l s
    for l in $(detect_languages); do
        s="$(lang_lsp "$l")"
        [ -n "$s" ] && printf '%s\n' "$s"
    done
    if [ "$(detect_has_ui)" = true ]; then printf 'frontend-design\nplaywright\n'; fi
}
