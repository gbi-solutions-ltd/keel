#!/usr/bin/env bash
# Tests for keel apex-export. No database: every case renders the committed capture fixture in
# tests/fixtures/apex/capture, which is byte for byte what SQLcl emits with `set sqlformat json`.
#
# The renderer is a separate module from the connection handling precisely so this file can exist.
# If a test here starts needing a live instance, that split has been broken.
#
# Run from the repository root.

# The `condition && ok || bad` idiom is used throughout. It is safe here, and only here, because
# every reporting helper returns 0 explicitly: see the `return 0` on each below.
# shellcheck disable=SC2015
# Single quoted strings holding backticks and $ are grep patterns for markdown, not expansions.
# shellcheck disable=SC2016
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEEL="$ROOT/bin/keel"
CAPTURE="$ROOT/tests/fixtures/apex/capture"
pass=0
fail=0

ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }

command -v python3 >/dev/null 2>&1 || {
    printf 'SKIP  test-apex-export.sh: python3 is absent. CI has it.\n'
    exit 0
}

[ -f "$CAPTURE/probe.out" ] || {
    printf '  FAIL  fixture: %s/probe.out is missing\n' "$CAPTURE"
    exit 1
}

OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

# ---- the export runs -------------------------------------------------------

render_log="$OUT/render.log"
if "$KEEL" apex-export --app 100 --from-capture "$CAPTURE" --out "$OUT/app" >"$render_log" 2>&1; then
    ok "renders the capture fixture with no database"
else
    bad "renders the capture fixture" "exit non-zero: $(tail -3 "$render_log" | tr '\n' ' ')"
fi

has() {  # has <label> <file> <pattern>
    [ -f "$OUT/app/$2" ] || { bad "$1" "$2 was not written"; return 0; }
    grep -q "$3" "$OUT/app/$2" && ok "$1" || bad "$1" "$2 has no match for $3"
}

has "writes an index"                INDEX.md      'APEX application 100: Merchant Portal'
has "records the APEX version"       INDEX.md      '22\.2\.0'
has "records the parsing schema"     INDEX.md      'PORTAL'
has "writes a manifest"              manifest.json '"apex_version"'
has "writes the page inventory"      INDEX.md      'Merchant Detail'

# ---- xref is the point of the export ---------------------------------------

if [ -f "$OUT/app/xref.tsv" ]; then
    # The promise the whole artifact makes: one grep for a table name finds every use of it.
    n=$(grep -c '^MERCHANTS	' "$OUT/app/xref.tsv")
    [ "$n" -ge 3 ] && ok "xref maps MERCHANTS to every page that uses it ($n rows)" \
      || bad "xref maps MERCHANTS" "expected at least 3 rows, got $n"

    grep -q '^MERCHANT_PKG	PACKAGE' "$OUT/app/xref.tsv" \
      && ok "xref resolves a called package against the catalog" \
      || bad "xref resolves a package" "MERCHANT_PKG is not typed as PACKAGE"

    # A column alias must never be reported as a table. `balance` is an alias in the page 10 query.
    grep -qi '^BALANCE	' "$OUT/app/xref.tsv" \
      && bad "xref excludes column aliases" "BALANCE was reported as a database object" \
      || ok "xref excludes column aliases"
else
    bad "xref.tsv" "was not written"
fi

# ---- source lands in its own file, verbatim --------------------------------

region="$OUT/app/pages/00010-merchants/regions/01-merchant-list.region_source.sql"
if [ -f "$region" ]; then
    grep -q 'join countries c on c.country_code = m.country_code' "$region" \
      && ok "region SQL is written verbatim, not reformatted" \
      || bad "region SQL verbatim" "the join line is not intact"
    grep -q ':P10_STATUS' "$region" \
      && ok "bind variables survive extraction" \
      || bad "bind variables survive" ":P10_STATUS is missing"
else
    bad "region source file" "$region was not written"
fi

# ---- redaction -------------------------------------------------------------

if grep -rq 'S3ttl3M3nt!2024' "$OUT/app" 2>/dev/null; then
    bad "redacts a PL/SQL declaration password" "the plaintext password is still in the output"
else
    ok "redacts a PL/SQL declaration password"
fi
# The regression this case pins: `l_password varchar2(100) := 'x'` puts the type between the name
# and the value, and the first pattern written here matched only `name := value`, so it walked past
# the most common way a hardcoded password appears in an APEX process.
if grep -rq 'EXAMPLE-NOT-A-REAL-TOKEN-0123456789abcdef' "$OUT/app" 2>/dev/null; then
    bad "redacts a bearer token" "the plaintext token is still in the output"
else
    ok "redacts a bearer token"
fi
has "reports what was redacted" REDACTIONS.md 'REDACTED\|password\|bearer'

# The redaction has to leave the surrounding PL/SQL readable, or the file it protects is useless.
grep -q "l_password varchar2(100) := '\[REDACTED:password\]'" \
     "$OUT/app/pages/00030-settlements/processes/01-settle-batch.process_source.plsql" 2>/dev/null \
  && ok "redaction preserves the declaration around the value" \
  || bad "redaction preserves the declaration" "the surrounding PL/SQL was mangled"

# ---- port difficulty -------------------------------------------------------

# Page 20 has 18 items, 2 PL/SQL processes, 8 dynamic actions, 2 validations and inline JavaScript.
# An earlier scorer counted only the excess over per component thresholds and called it `low`.
# Understating the busiest page is the one failure that makes the assessment worthless.
band_of() { grep -o "^| \[$1\]([^)]*) | [^|]* | [a-z]*" "$OUT/app/INDEX.md" | awk '{print $NF}'; }
b20="$(band_of 20)"
[ "$b20" = "high" ] || [ "$b20" = "rewrite" ] \
  && ok "page 20 is scored high or above (got $b20)" \
  || bad "page 20 scoring" "expected high or rewrite, got '$b20'"

b30="$(band_of 30)"
[ "$b30" = "high" ] || [ "$b30" = "rewrite" ] \
  && ok "an Interactive Grid page is scored high or above (got $b30)" \
  || bad "Interactive Grid scoring" "expected high or rewrite, got '$b30'"

b1="$(band_of 1)"
[ "$b1" = "low" ] \
  && ok "a static content page is scored low" \
  || bad "static page scoring" "expected low, got '$b1'"

has "explains every band with its contributions" pages/00020-merchant-detail/page.md '| Points | Contribution |'
grep -q 'not an estimate of hours' "$OUT/app/pages/00020-merchant-detail/page.md" \
  && ok "states that the score is not an estimate" \
  || bad "score disclaimer" "page.md does not say the score is not hours"

# ---- version tolerance -----------------------------------------------------

# The fixture withholds two views that genuinely postdate older APEX releases. A missing view must
# degrade to a recorded warning, never to a crash or to silence.
has "reports a view absent on this version"   INDEX.md 'APEX_APPL_WEB_SRC_MODULES is not present'
has "labels unread scope as unknown"          INDEX.md 'Treat it as unknown'

# Columns come from the catalog, not from a list in the code. A run against a real APEX 22.2
# instance found roughly twenty hand-written column names wrong, each one silently dropping a
# column while printing a reassuring "absent on this version" line. The catalog is the authority
# now, so what is asserted is that everything real is selected and only noise is dropped.
column_report="$(python3 - <<PY
import sys
sys.path.insert(0, "$ROOT/lib")
from apex_export import interpret_probe, plan_sections
probe = open("$CAPTURE/probe.out", encoding="utf-8").read()
plan, _warnings = plan_sections(interpret_probe(probe, 100))
by = {name: cols for name, _view, cols in plan}
problems = []
# Real columns that carry code or identity must survive the noise filter.
for section, col in [("regions", "REGION_SOURCE"), ("regions", "IS_EDITABLE"),
                     ("computations", "COMPUTATION"), ("app_processes", "PROCESS"),
                     ("da_events", "WHEN_EVENT_NAME"), ("da_events", "WHEN_ELEMENT"),
                     ("validations", "VALIDATION_FAILURE_TEXT"),
                     ("authorization", "ATTRIBUTE_01"),
                     ("lovs", "LIST_OF_VALUES_NAME"), ("processes", "PROCESS_SOURCE")]:
    if col not in by.get(section, []):
        problems.append("%s.%s was not selected" % (section, col))
# Noise planted in the fixture catalog must not be.
for section in by:
    for col in ("LAST_UPDATED_BY", "WORKSPACE", "COMPONENT_SIGNATURE", "AUTHORIZATION_SCHEME_ID"):
        if col in by[section]:
            problems.append("%s.%s is noise and should have been filtered" % (section, col))
# Every section must still carry what it is keyed on.
for section, cols in by.items():
    if "APPLICATION_ID" not in cols:
        problems.append("%s lost APPLICATION_ID" % section)
print("; ".join(problems))
PY
)"
[ -z "$column_report" ] \
  && ok "selects every real column from the catalog and drops only noise" \
  || bad "catalog column selection" "$column_report"

# ---- component naming ------------------------------------------------------

# Every shared component whose name column was not in the label list used to be written as
# `01-component.plsql`, which cannot be traced back to the scheme a page referenced by name.
if find "$OUT/app" -name '*-component.*' | grep -q .; then
    bad "names every component from its own name column" "$(find "$OUT/app" -name '*-component.*' | head -1) is unnamed"
else
    ok "names every component from its own name column"
fi
grep -q '^## 01-view-merchants' "$OUT/app/shared/authorization/index.md" 2>/dev/null \
  && ok "names authorization schemes from AUTHORIZATION_SCHEME_NAME" \
  || bad "names authorization schemes" "the scheme is not headed by its name"

# A source value too short to earn its own file must still appear, inline. It used to be dropped
# from both places at once: the length rule sent it to the attribute table, and the attribute table
# excluded every source column on principle. An authorization scheme whose entire body is one line
# vanished from the export, which is the only thing anyone opens that section to read.
if grep -rq "sec_pkg.has_role(:APP_USER, 'MERCHANT_VIEW')" "$OUT/app/shared/authorization/"; then
    ok "a short source value is kept inline rather than dropped"
else
    bad "short source values" "the authorization scheme body is in neither a file nor the table"
fi

# The counterpart: a multi-line source still gets its own file, verbatim.
[ -f "$OUT/app/shared/lovs/02-countries.list_of_values_query.sql" ] \
  && ok "a multi-line source still gets its own file" \
  || bad "multi-line source" "the dynamic LOV query was not written to a file"

# ---- database objects ------------------------------------------------------

has "writes a column listing per table" db/tables/merchants.md '| `LEGAL_NAME` | VARCHAR2(200) | no |'
has "writes constraints"                db/tables/settlements.md 'foreign key'
has "writes package source"             db/plsql/merchant_pkg.package.sql 'function is_valid_iban'

# ---- failure modes ---------------------------------------------------------

if "$KEEL" apex-export --app 100 --from-capture "$OUT/empty-capture" --out "$OUT/x" >"$OUT/err.log" 2>&1; then
    bad "fails on a capture directory that does not exist" "exited zero"
else
    grep -q 'no probe.out' "$OUT/err.log" \
      && ok "fails on a missing capture with a message naming the file" \
      || bad "missing capture message" "got: $(head -2 "$OUT/err.log" | tr '\n' ' ')"
fi

"$KEEL" apex-export --help >/dev/null 2>&1 \
  && ok "keel apex-export --help exits zero" \
  || bad "help" "keel apex-export --help exited non-zero"

"$KEEL" apex-export >/dev/null 2>&1 \
  && bad "bare invocation" "exited zero with no arguments; it should print usage and fail" \
  || ok "keel apex-export with no arguments prints usage and fails"

# ---- the modules are importable and the split holds ------------------------

python3 -c "
import sys; sys.path.insert(0, '$ROOT/lib')
import apex_render, apex_export
src = open('$ROOT/lib/apex_render.py').read()
# The renderer must stay pure. A database import here means the offline tests above stopped
# proving anything about what a live run produces.
for banned in ('subprocess', 'run_sqlcl', 'import socket'):
    assert banned not in src, banned
" 2>/dev/null \
  && ok "the renderer imports cleanly and stays free of I/O" \
  || bad "renderer purity" "apex_render.py imports a database or process dependency"

# ---- every generated marker is a prompt ------------------------------------

# The bug this pins was found only by running against a live instance. A bare `@@@KEEL-SECTION:x`
# line is read by SQLcl as the `@@` run-nested-script command: it is swallowed with no output and
# no error, so no section is ever named, parsing falls back to positional order, and a single
# section that fails to return shifts every section after it onto the wrong name. Silent
# misattribution of data, which is the worst failure this tool has available to it.
#
# No capture fixture can catch this, because a fixture is the output and the bug is in the input.
# So the input is asserted directly.
marker_report="$(python3 - <<PY
import sys
sys.path.insert(0, "$ROOT/lib")
import apex_export as ax
scripts = {
    "probe": ax.PROBE_SQL.format(marker=ax.MARKER_SQL, app=100,
                                 views=", ".join("'%s'" % s[1] for s in ax.SECTIONS)),
    "extract": ax.build_extract_sql([("pages", "APEX_APPLICATION_PAGES", ["PAGE_ID"])], 100),
}
problems = []
for name, sql in scripts.items():
    if ax.MARKER not in sql:
        problems.append("%s emits no section marker at all" % name)
    for line in sql.splitlines():
        if ax.MARKER in line and not line.strip().startswith("prompt "):
            problems.append("%s has a bare marker SQLcl will swallow: %r" % (name, line.strip()))
print("; ".join(problems))
PY
)"
[ -z "$marker_report" ] \
  && ok "every section marker is emitted as a prompt, not as a bare line" \
  || bad "section markers" "$marker_report"

# ---- no value is silently clipped ------------------------------------------

# The attribute table renders long values clipped to 300 characters. A code-bearing column that
# this tool's source map has never heard of therefore lost its content with no signal: a real
# export clipped 62 inline LOV queries mid-SQL, and a clipped query is indistinguishable from a
# short one to whoever reads it. Any value long enough to be clipped now goes to its own file
# instead, whatever its column is called.
clip_report="$(python3 - <<PY
import sys
sys.path.insert(0, "$ROOT/lib")
from apex_render import Export, ATTRIBUTE_CLIP_CHARS

long_sql = "select " + ", ".join("col_%02d" % i for i in range(60)) + " from some_table"
assert len(long_sql) > ATTRIBUTE_CLIP_CHARS
rows = {
    "application": [{"APPLICATION_ID": 1, "APPLICATION_NAME": "T"}],
    "pages": [{"APPLICATION_ID": 1, "PAGE_ID": 1, "PAGE_TITLE": "P"}],
    # A column deliberately absent from SOURCE_COLUMNS, holding SQL.
    "items": [{"APPLICATION_ID": 1, "PAGE_ID": 1, "ITEM_NAME": "P1_X",
               "SOME_UNKNOWN_QUERY_COLUMN": long_sql}],
}
import tempfile, os
out = tempfile.mkdtemp()
Export(rows, {"application_id": 1}).write(out)

problems = []
page_md = open(os.path.join(out, "pages", "00001-p", "page.md"), encoding="utf-8").read()
if "..." in page_md:
    problems.append("the value was clipped into page.md instead of written to a file")
hits = []
for dirpath, _d, files in os.walk(out):
    for f in files:
        body = open(os.path.join(dirpath, f), encoding="utf-8").read()
        if long_sql in body:
            hits.append(f)
if not hits:
    problems.append("the long value was not written anywhere, whole")
print("; ".join(problems))
PY
)"
[ -z "$clip_report" ] \
  && ok "a long value in an unknown column is written whole, not clipped" \
  || bad "silent clipping" "$clip_report"

# ---- database dependency closure -------------------------------------------

# The first live run exported 44 PL/SQL files from a schema of 559 objects and 0 triggers from a
# schema containing 123. An APEX page calls PKG_HTTPS, PKG_HTTPS calls PKG_AQ, and PKG_AQ is the
# entire asynchronous messaging layer: scanning only page source found the first and missed the
# rest. The export looked complete while omitting most of the business logic, which is the worst
# possible failure for an artifact whose stated purpose is scoping a port.
closure_report="$(python3 - <<PY
import sys
sys.path.insert(0, "$ROOT/lib")
import apex_export as ax

known = {"PKG_HTTPS": "PACKAGE BODY", "PKG_AQ": "PACKAGE BODY", "PKG_DEEP": "PACKAGE BODY",
         "MERCHANTS": "TABLE"}
bodies = {
    "PKG_HTTPS": "begin pkg_aq.notify(1); end;",
    "PKG_AQ":    "begin pkg_deep.enqueue(2); end;",
    "PKG_DEEP":  "begin insert into merchants values (1); end;",
}
calls = []

def fake_fetch_ddl(sqlcl, conn, schema, names, capture_to=None, label="ddl"):
    calls.append(sorted(names))
    return {"source": [{"NAME": n, "TYPE": "PACKAGE BODY", "LINE": 1,
                        "TEXT": bodies.get(n, "")} for n in sorted(names)]}

ax.fetch_ddl = fake_fetch_ddl
ddl, referenced, rounds = ax.resolve_db_closure(
    None, None, "S", {"PKG_HTTPS"}, known, log=lambda m: None)

problems = []
for want in ("PKG_AQ", "PKG_DEEP"):
    if want not in referenced:
        problems.append("%s was never reached: closure stopped too early" % want)
if rounds < 3:
    problems.append("closure ran only %d round(s); it did not follow the chain" % rounds)
if len(ddl.get("source", [])) < 3:
    problems.append("DDL from later rounds was not merged into the result")
# It must terminate rather than re-fetching what it already has.
if any(len(c) > 1 and set(c) == {"PKG_HTTPS"} for c in calls):
    problems.append("closure refetched an object it already had")
print("; ".join(problems))
PY
)"
[ -z "$closure_report" ] \
  && ok "database references are followed transitively, not one level deep" \
  || bad "dependency closure" "$closure_report"

# ---- an object named like a SQL keyword ------------------------------------

# Found on a real schema that contains a function named JOIN. Matching bare identifiers against the
# catalog put 54 rows in xref.tsv, one for every query with a join in it. A flood in the file the
# export exists to make greppable is worse than a miss, because it teaches the reader to ignore it.
keyword_report="$(python3 - <<PY
import sys
sys.path.insert(0, "$ROOT/lib")
from apex_render import find_db_references
known = {"JOIN": "FUNCTION", "MERCHANTS": "TABLE", "COUNT": "FUNCTION", "MERCHANT_PKG": "PACKAGE"}
problems = []

plain = "select m.id from merchants m join countries c on c.code = m.code"
if "JOIN" in find_db_references(plain, known):
    problems.append("the JOIN keyword was reported as the function named JOIN")
if "MERCHANTS" not in find_db_references(plain, known):
    problems.append("an ordinary table stopped being detected")

called = "select join(cursor(select 1 from dual), ',') from merchants"
if "JOIN" not in find_db_references(called, known):
    problems.append("a genuine call to the function named JOIN was missed")

if "MERCHANT_PKG" not in find_db_references("begin merchant_pkg.save(1); end;", known):
    problems.append("a package call stopped being detected")
print("; ".join(problems))
PY
)"
[ -z "$keyword_report" ] \
  && ok "an object named like a SQL keyword is matched only where it is called" \
  || bad "keyword collision" "$keyword_report"

# ---- redaction unit cases --------------------------------------------------

redaction_report="$(python3 - <<PY
import sys
sys.path.insert(0, "$ROOT/lib")
from apex_render import redact
# A false positive is cheap and visible. A miss ships a live credential into a document that gets
# committed, so every shape seen in real APEX source earns a case here.
cases = [
    ("l_pwd varchar2(30) := 'hunter2';", "hunter2"),
    ("p_password => 'letmein'", "letmein"),
    ("l_api_key constant varchar2(64) := 'ak_live_9911';", "ak_live_9911"),
    ("'Bearer abcdefghijklmnopqrstuvwxyz012345'", "abcdefghijklmnopqrstuvwxyz012345"),
    ("https://svc:s3cret@api.example.com/v1", "s3cret"),
    ("scott/tiger@orcl", "tiger"),
]
problems = ["missed: %s" % text for text, secret in cases if secret in redact(text)[0]]
for kept in ("select amount from payouts where status = 'PENDING'",
             "l_error_message varchar2(200) := 'Your token has expired';"):
    if redact(kept)[0] != kept:
        problems.append("over-redacted: %s" % kept)
print("; ".join(problems))
PY
)"
[ -z "$redaction_report" ] \
  && ok "redaction catches every credential shape and leaves ordinary SQL alone" \
  || bad "redaction unit cases" "$redaction_report"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
exit 0
