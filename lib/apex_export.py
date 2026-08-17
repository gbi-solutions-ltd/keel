"""Export one Oracle APEX application into a tree an agent can grep.

Talks to the database through SQLcl and hands the result to apex_render.py, which is pure. Run it
through `keel apex-export`; the bash wrapper resolves the connection and checks dependencies.

Two design choices are worth stating up front, because both were deliberate.

SQLcl is the only supported client. It needs Java and nothing else, no Oracle Instant Client, and
it serialises CLOB columns to JSON correctly, which sqlplus spooling does not without a page of
formatting directives that still mangles long lines.

The dictionary views are the primary source, not the native export. The native `f100.sql` is kept
under `raw/` as ground truth, but every reference inside it is a 14 digit internal id, so it does
not answer the question anyone actually has. The views hold the same metadata with real names, and
they need lower privileges: any schema mapped to the workspace can read them, where APEX_EXPORT
wants APEX_ADMINISTRATOR_ROLE.
"""

import argparse
import json
import os
import re
import stat
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from apex_render import Export, find_db_references, write_text  # noqa: E402


# Sections read from the APEX dictionary: (name, view, key columns).
#
# There is deliberately no list of wanted columns here. The first version carried one per view, and
# a run against a real APEX 22.2 instance found roughly twenty of the names wrong: the dynamic
# action view calls its event `WHEN_EVENT_NAME`, not `EVENT_NAME`; computations hold their code in
# `COMPUTATION`, not `COMPUTATION_EXPRESSION1`; application processes use `PROCESS`, not
# `PROCESS_SOURCE`. Each wrong name silently dropped a column and wrote a reassuring "absent on this
# version" line, so the export looked complete while missing the actual code.
#
# The catalog is the authority instead. Every column the view has is selected except those matching
# SELECT_NOISE_RE, so a column this tool has never heard of still arrives, and a column Oracle
# renames between releases cannot go missing. The renderer drops blanks, and APEX leaves most
# columns null, so selecting widely costs transfer rather than readability.
#
# `key` columns must all exist or the section is skipped: a section keyed on nothing cannot be
# attached to a page and would be written into a file nobody can trace back.
SECTIONS = [
    ("application",      "APEX_APPLICATIONS",              []),
    ("pages",            "APEX_APPLICATION_PAGES",         ["PAGE_ID"]),
    ("regions",          "APEX_APPLICATION_PAGE_REGIONS",  ["PAGE_ID"]),
    ("items",            "APEX_APPLICATION_PAGE_ITEMS",    ["PAGE_ID"]),
    ("buttons",          "APEX_APPLICATION_PAGE_BUTTONS",  ["PAGE_ID"]),
    ("processes",        "APEX_APPLICATION_PAGE_PROC",     ["PAGE_ID"]),
    ("validations",      "APEX_APPLICATION_PAGE_VAL",      ["PAGE_ID"]),
    ("computations",     "APEX_APPLICATION_PAGE_COMP",     ["PAGE_ID"]),
    ("branches",         "APEX_APPLICATION_PAGE_BRANCHES", ["PAGE_ID"]),
    ("da_events",        "APEX_APPLICATION_PAGE_DA",       ["PAGE_ID"]),
    ("da_actions",       "APEX_APPLICATION_PAGE_DA_ACTS",  ["PAGE_ID"]),
    ("ir_columns",       "APEX_APPLICATION_PAGE_IR_COL",   ["PAGE_ID"]),
    ("ig_columns",       "APEX_APPL_PAGE_IG_COLUMNS",      ["PAGE_ID"]),
    ("lovs",             "APEX_APPLICATION_LOVS",          []),
    ("lov_entries",      "APEX_APPLICATION_LOV_ENTRIES",   []),
    ("lists",            "APEX_APPLICATION_LISTS",         []),
    ("list_entries",     "APEX_APPLICATION_LIST_ENTRIES",  []),
    ("app_items",        "APEX_APPLICATION_ITEMS",         []),
    ("app_processes",    "APEX_APPLICATION_PROCESSES",     []),
    ("app_computations", "APEX_APPLICATION_COMPUTATIONS",  []),
    ("authorization",    "APEX_APPLICATION_AUTHORIZATION", []),
    ("authentication",   "APEX_APPLICATION_AUTH",          []),
    ("build_options",    "APEX_APPLICATION_BUILD_OPTIONS", []),
    ("web_sources",      "APEX_APPL_WEB_SRC_MODULES",      []),
    ("plugins",          "APEX_APPL_PLUGINS",              []),
    ("tabs",             "APEX_APPLICATION_TABS",          []),
    ("nav",              "APEX_APPLICATION_NAV_BAR",       []),
]

# Columns not worth pulling across the wire. Kept tight on purpose: the renderer already hides
# blanks and known noise at display time, so the only job here is to avoid transferring bulk that
# no porting decision can ever turn on. Theme and template columns are the bulk of it, because the
# user interface is the part being deliberately rebuilt.
SELECT_NOISE_RE = re.compile(
    r"^(LAST_UPDATED_(BY|ON)|WORKSPACE(_DISPLAY_NAME)?|APPLICATION_NAME|PAGE_NAME|"
    r"COMPONENT_SIGNATURE|.*_CSS_CLASSES|ICON_[A-Z_]*|IMAGE_[A-Z_]*|"
    r"(ASCENDING|DESCENDING)_IMAGE[A-Z_]*|.*_TEMPLATE|.*_TEMPLATE_ID|.*_TEMPLATE_OPTIONS|"
    r"TRANSLATED?_[A-Z_]*|.*_SCHEME_ID|BUILD_OPTION_ID|THEME_[A-Z_]*|.*_THEME)$"
)

SECTION_BY_NAME = {s[0]: s for s in SECTIONS}

# PL/SQL is read from ALL_SOURCE rather than DBMS_METADATA. all_source needs only select on the
# object, where get_ddl wants SELECT_CATALOG_ROLE, and a read only reporting user rarely has it.
PLSQL_TYPES = ("PACKAGE", "PACKAGE BODY", "PROCEDURE", "FUNCTION", "TRIGGER", "TYPE", "TYPE BODY")
RELATIONAL_TYPES = ("TABLE", "VIEW", "MATERIALIZED VIEW", "SEQUENCE", "SYNONYM")

# MARKER is what to look for in SQLcl's output. MARKER_SQL is what to put in the script to get it
# there, and the `prompt` is not optional: a bare `@@@KEEL-SECTION:pages` line is read by SQLcl as
# the `@@` run-nested-script command, which it swallows silently, with no output and no error. The
# markers then never appear, section naming falls back to positional order, and one section that
# fails to return shifts every section after it onto the wrong name. Found by running it against a
# real instance; no fixture can catch it, because a fixture is the output and this is the input.
MARKER = "@@@KEEL-SECTION:"
MARKER_SQL = "prompt " + MARKER


class ExportError(Exception):
    pass


# -- SQLcl -------------------------------------------------------------------------------------

# `define off` and `scan off` must be set before anything else runs, including the connect. APEX
# region sources are full of `&ITEM.` substitution syntax, and with scanning left on SQLcl treats
# every one of them as a variable to prompt for: the run either hangs waiting on stdin or silently
# substitutes an empty string into the SQL it was supposed to be reporting verbatim.
#
# Text formatting directives (pagesize, linesize, heading) are deliberately absent. Output is JSON,
# SQLcl serialises it itself, and the text directives only confuse that.
#
# `long` is 100MB rather than the 2GB an example would suggest. SQLcl prints a Java memory warning
# above roughly that, and the warning is right: the setting is a per value buffer, and no APEX
# region source is anywhere near 100MB.
SQL_HEADER = """set define off
set scan off
set feedback off
set echo off
set verify off
set termout on
set long 10000000
set longchunksize 32767
set sqlblanklines on
set sqlformat json
whenever sqlerror continue
"""


def run_sqlcl(sqlcl, connect_string, script_body, timeout=900, capture_to=None, label="query"):
    """Run a script through SQLcl and return stdout.

    The connect string is written into a 0600 temp file rather than passed as an argument, because
    an argument is visible in `ps` to every user on the machine for the life of the process.
    """
    tmpdir = tempfile.mkdtemp(prefix="keel-apex-")
    script_path = os.path.join(tmpdir, "driver.sql")
    try:
        with open(script_path, "w", encoding="utf-8") as fh:
            fh.write(SQL_HEADER)
            fh.write("connect %s\n" % connect_string)
            fh.write(script_body)
            fh.write("\nexit\n")
        os.chmod(script_path, stat.S_IRUSR | stat.S_IWUSR)
        proc = subprocess.run(
            [sqlcl, "-S", "/nolog", "@%s" % script_path],
            capture_output=True, text=True, timeout=timeout,
            env=dict(os.environ, NLS_LANG="AMERICAN_AMERICA.AL32UTF8"),
        )
    except subprocess.TimeoutExpired:
        raise ExportError("SQLcl timed out after %ds running %s" % (timeout, label))
    except FileNotFoundError:
        raise ExportError("SQLcl not found at %r" % sqlcl)
    finally:
        try:
            os.remove(script_path)
            os.rmdir(tmpdir)
        except OSError:
            pass

    out = proc.stdout or ""
    if capture_to:
        os.makedirs(capture_to, exist_ok=True)
        write_text(os.path.join(capture_to, "%s.out" % label), out)
        if proc.stderr:
            write_text(os.path.join(capture_to, "%s.err" % label), proc.stderr)

    fatal = first_client_error(out, proc.stderr)
    if fatal:
        raise ExportError("connection failed (%s) running %s. Client output:\n%s"
                          % (fatal, label, (out + (proc.stderr or ""))[:2000]))
    return out


# A failed connect is not an exception in SQLcl: it prints and carries on, so every later statement
# fails too and the run looks like an empty application rather than a bad password. That is the most
# expensive wrong answer this tool could give, so these are checked for.
FATAL_CLIENT_STRINGS = ("ora-01017", "invalid username", "ora-12154", "ora-12541", "ora-12514",
                        "ora-28000", "ora-01005", "ora-28001", "io error", "sp2-0640",
                        "not connected")


def first_client_error(out, err):
    """The first fatal client message in SQLcl's output, or None.

    Lines belonging to a JSON result document are skipped, and that is the whole point. The output
    carries the application's own source code, and an APEX process whose error message reads
    "Invalid username or password" is not a failed login. Scanning the raw text for these strings
    aborted a successful export of a real 27 section application at the last step, after six
    minutes of extraction, because a PL/SQL function happened to contain one of them.

    SQLcl escapes newlines inside JSON string values, so every result line begins with a JSON
    punctuation character and nothing from the database can reach the scan.
    """
    suspects = []
    for line in (out or "").splitlines():
        s = line.strip()
        if not s or s[0] in "{}[],\"" or s.startswith(MARKER):
            continue
        suspects.append(s)
    suspects.extend(s.strip() for s in (err or "").splitlines() if s.strip())
    for line in suspects:
        lowered = line.lower()
        for fatal in FATAL_CLIENT_STRINGS:
            if fatal in lowered:
                return fatal.upper()
    return None


def parse_json_stream(text):
    """Parse SQLcl output into [(section_or_None, payload)] in statement order.

    SQLcl emits one JSON document per statement with `set sqlformat json`, and anything a PROMPT
    wrote sits between them as bare text. Rather than trust either, scan for JSON documents with
    raw_decode and use the nearest preceding marker to name each one. When markers are missing the
    caller falls back to positional order, which is why the section may be None.
    """
    results = []
    decoder = json.JSONDecoder()
    i, n = 0, len(text)
    pending = None
    while i < n:
        ch = text[i]
        if ch in "{[":
            try:
                obj, end = decoder.raw_decode(text, i)
            except ValueError:
                i += 1
                continue
            results.append((pending, obj))
            pending = None
            i = end
            continue
        if text.startswith(MARKER, i):
            eol = text.find("\n", i)
            eol = n if eol == -1 else eol
            pending = text[i + len(MARKER):eol].strip()
            i = eol
            continue
        i += 1
    return results


def rows_of(payload):
    """Pull the item list out of one SQLcl JSON document."""
    if isinstance(payload, dict):
        if "results" in payload and isinstance(payload["results"], list):
            rows = []
            for result in payload["results"]:
                rows.extend(result.get("items") or [])
            return rows
        if "items" in payload:
            return payload.get("items") or []
    if isinstance(payload, list):
        return payload
    return []


def named_sections(text, expected_order):
    """Map parsed documents to section names, by marker where present, by order otherwise."""
    parsed = parse_json_stream(text)
    out = {}
    unnamed = []
    for name, payload in parsed:
        if name:
            out[name] = rows_of(payload)
        else:
            unnamed.append(rows_of(payload))
    if unnamed:
        remaining = [s for s in expected_order if s not in out]
        for name, rows in zip(remaining, unnamed):
            out.setdefault(name, rows)
    return out


# -- probe -------------------------------------------------------------------------------------

# The column probe is what makes this work across APEX 5 through 24 without a version table in the
# code. Rather than assume a view has a column, ask the catalog, then select the intersection. It is
# restricted to the views in SECTIONS because `like 'APEX!_%'` returns roughly twelve thousand rows
# of columns nothing here reads.
PROBE_SQL = """
{marker}release
select * from apex_release;

{marker}app
select application_id, application_name, owner, version
  from apex_applications where application_id = {app};

{marker}columns
select table_name, column_name
  from all_tab_columns
 where table_name in ({views})
 order by table_name, column_id;

{marker}capabilities
select object_name from all_objects
 where object_name in ('APEX_EXPORT','APEX_DICTIONARY','DBMS_METADATA')
 group by object_name;

{marker}whoami
select user as db_user, sys_context('userenv','current_schema') as current_schema from dual;
"""


def probe(sqlcl, conn, app_id, capture_to=None):
    views = ", ".join("'%s'" % s[1] for s in SECTIONS)
    sql = PROBE_SQL.format(marker=MARKER_SQL, app=app_id, views=views)
    text = run_sqlcl(sqlcl, conn, sql, capture_to=capture_to, label="probe")
    return interpret_probe(text, app_id)


def interpret_probe(text, app_id):
    order = ["release", "app", "columns", "capabilities", "whoami"]
    sections = named_sections(text, order)

    release = [{k.upper(): v for k, v in r.items()} for r in sections.get("release", [])]
    if not release:
        raise ExportError(
            "APEX_RELEASE returned nothing. Either this database has no APEX installed, or the "
            "connecting user cannot see it. Client output:\n%s" % text[:1500])
    version = str(release[0].get("VERSION_NO") or "unknown")

    apps = [{k.upper(): v for k, v in r.items()} for r in sections.get("app", [])]
    if not apps:
        raise ExportError(
            "Application %d is not visible to this user. APEX dictionary views only show "
            "applications in workspaces the connecting schema is associated with. Ask for a user "
            "mapped to the right workspace, or check the application id." % app_id)

    columns = {}
    for row in sections.get("columns", []):
        row = {k.upper(): v for k, v in row.items()}
        table = str(row.get("TABLE_NAME") or "").upper()
        col = str(row.get("COLUMN_NAME") or "").upper()
        if table and col:
            columns.setdefault(table, set()).add(col)

    caps = {str(r.get(list(r)[0])).upper() for r in sections.get("capabilities", []) if r}
    who = [{k.upper(): v for k, v in r.items()} for r in sections.get("whoami", [])]

    return {
        "apex_version": version,
        "apex_release": release[0],
        "application_id": app_id,
        "application_name": apps[0].get("APPLICATION_NAME"),
        "parsing_schema": apps[0].get("OWNER"),
        "db_user": (who[0].get("DB_USER") if who else None),
        "columns": {k: sorted(v) for k, v in columns.items()},
        "has_apex_export": "APEX_EXPORT" in caps,
        "has_dbms_metadata": "DBMS_METADATA" in caps,
        "warnings": [],
    }


# -- extraction --------------------------------------------------------------------------------

def plan_sections(probe_info, only=None):
    """Decide which sections to read and with which columns. Returns (plan, warnings).

    Every column the view actually has is selected, minus SELECT_NOISE_RE. The catalog is the
    authority, so a column Oracle renames between releases cannot silently go missing and a column
    this tool has never heard of still arrives.

    Only two things are fatal to a section, and both are recorded as scope rather than swallowed:
    the view not existing on this version, and a key column being absent so its rows could not be
    attached to a page.
    """
    columns = probe_info.get("columns") or {}
    plan, warnings = [], []
    for name, view, keys in SECTIONS:
        if only and name not in only:
            continue
        have = list(columns.get(view, []))
        have_set = set(have)
        if not have:
            warnings.append("section `%s`: view %s is not present on APEX %s, skipped. Any "
                            "component of this kind is unknown, not absent"
                            % (name, view, probe_info.get("apex_version")))
            continue
        if "APPLICATION_ID" not in have_set:
            warnings.append("section `%s`: %s has no APPLICATION_ID to filter on, skipped"
                            % (name, view))
            continue
        missing_keys = [k for k in keys if k.upper() not in have_set]
        if missing_keys:
            warnings.append("section `%s`: %s is missing key column(s) %s, skipped"
                            % (name, view, ", ".join(missing_keys)))
            continue
        selected = [c for c in have if not SELECT_NOISE_RE.match(c)]
        for k in [x.upper() for x in keys] + ["APPLICATION_ID"]:
            if k not in selected:
                selected.insert(0, k)
        plan.append((name, view, selected))
    return plan, warnings


def build_extract_sql(plan, app_id):
    parts = []
    for name, view, cols in plan:
        parts.append("%s%s" % (MARKER_SQL, name))
        parts.append("select %s from %s where application_id = %d;"
                     % (", ".join(cols), view, app_id))
        parts.append("")
    return "\n".join(parts)


def extract(sqlcl, conn, plan, app_id, capture_to=None):
    sql = build_extract_sql(plan, app_id)
    text = run_sqlcl(sqlcl, conn, sql, capture_to=capture_to, label="extract")
    return named_sections(text, [p[0] for p in plan])


# -- database objects --------------------------------------------------------------------------

def collect_source_text(sections):
    """Every SQL and PL/SQL string in the extract, concatenated. Used to find dependencies."""
    from apex_render import SOURCE_COLUMNS
    chunks = []
    for rows in sections.values():
        for row in rows:
            up = {k.upper(): v for k, v in row.items()}
            for col in SOURCE_COLUMNS:
                value = up.get(col)
                if isinstance(value, str) and value.strip():
                    chunks.append(value)
    return "\n".join(chunks)


def fetch_db_objects(sqlcl, conn, schema, capture_to=None):
    sql = "%sobjects\nselect object_name, object_type from all_objects where owner = '%s' " \
          "and object_type in (%s);\n" % (
              MARKER_SQL, schema.upper(),
              ", ".join("'%s'" % t for t in PLSQL_TYPES + RELATIONAL_TYPES))
    text = run_sqlcl(sqlcl, conn, sql, capture_to=capture_to, label="objects")
    rows = named_sections(text, ["objects"]).get("objects", [])
    out = {}
    for row in rows:
        up = {k.upper(): v for k, v in row.items()}
        name = str(up.get("OBJECT_NAME") or "").upper()
        if name:
            # PACKAGE BODY must not overwrite PACKAGE in the map; the name is what gets grepped
            # and the distinction is carried in the DDL files instead.
            out.setdefault(name, str(up.get("OBJECT_TYPE") or ""))
    return out


def fetch_ddl(sqlcl, conn, schema, names, capture_to=None, label="ddl"):
    """Source for PL/SQL objects and a column listing for relational ones.

    A column listing rather than get_ddl for tables is deliberate. Porting needs column names,
    types, nullability, and keys, which is what anyone builds the TypeScript model from. Storage
    clauses and tablespaces are noise, and ALL_TAB_COLUMNS is readable where get_ddl is often not.
    """
    if not names:
        return {}
    in_list = ", ".join("'%s'" % n.replace("'", "''") for n in sorted(names))
    sql = """{m}source
select name, type, line, text from all_source
 where owner = '{s}' and name in ({names}) order by name, type, line;

{m}columns
select table_name, column_name, data_type, data_length, data_precision, data_scale,
       nullable, data_default, column_id
  from all_tab_columns where owner = '{s}' and table_name in ({names}) order by table_name, column_id;

{m}constraints
select c.table_name, c.constraint_name, c.constraint_type, c.search_condition_vc, c.r_constraint_name,
       cc.column_name, cc.position
  from all_constraints c
  join all_cons_columns cc on cc.owner = c.owner and cc.constraint_name = c.constraint_name
 where c.owner = '{s}' and c.table_name in ({names}) order by c.table_name, c.constraint_name, cc.position;

{m}indexes
select table_name, index_name, uniqueness, column_name, column_position
  from all_ind_columns where table_owner = '{s}' and table_name in ({names})
 order by table_name, index_name, column_position;
""".format(m=MARKER_SQL, s=schema.upper(), names=in_list)
    text = run_sqlcl(sqlcl, conn, sql, capture_to=capture_to, label=label)
    return named_sections(text, ["source", "columns", "constraints", "indexes"])


def fetch_trigger_names(sqlcl, conn, schema, tables, capture_to=None):
    """Triggers on the referenced tables.

    Triggers are never named by the application, because they fire on DML rather than being called.
    A reference scan therefore cannot find a single one: the first live run exported 0 triggers from
    a schema containing 123, and every one of them is business logic that runs whether or not the
    new application knows about it. They are pulled in by the table they hang off instead.
    """
    if not tables:
        return {}
    in_list = ", ".join("'%s'" % t.replace("'", "''") for t in sorted(tables))
    sql = ("%striggers\nselect trigger_name, table_name, trigger_type, triggering_event, status\n"
           "  from all_triggers where table_owner = '%s' and table_name in (%s);\n"
           % (MARKER_SQL, schema.upper(), in_list))
    text = run_sqlcl(sqlcl, conn, sql, capture_to=capture_to, label="triggers")
    out = {}
    for row in named_sections(text, ["triggers"]).get("triggers", []):
        up = {k.upper(): v for k, v in row.items()}
        name = str(up.get("TRIGGER_NAME") or "").upper()
        if name:
            out[name] = up
    return out


def source_text_of(ddl):
    """Concatenate the ALL_SOURCE rows in a fetched DDL bundle."""
    return "\n".join(str(r.get("text") or r.get("TEXT") or "") for r in (ddl.get("source") or []))


def merge_ddl(into, extra):
    for key, rows in (extra or {}).items():
        into.setdefault(key, []).extend(rows)
    return into


MAX_CLOSURE_DEPTH = 6


def resolve_db_closure(sqlcl, conn, schema, seeds, known_objects, capture_to=None, log=print):
    """Fetch DDL for `seeds`, then for whatever that DDL references, until nothing new appears.

    One level is not enough and the first live run proved it. An APEX page calls PKG_HTTPS; PKG_HTTPS
    calls PKG_AQ; PKG_AQ is the entire asynchronous messaging layer. Scanning only the page source
    found the first and missed the rest, so the export omitted the packages holding most of the
    business logic while looking complete. Anyone reading it would have scoped the port against the
    thin half.

    Returns (ddl, referenced, rounds).
    """
    ddl = {}
    referenced = set(seeds)
    frontier = set(seeds)
    rounds = 0
    while frontier and rounds < MAX_CLOSURE_DEPTH:
        rounds += 1
        batch = fetch_ddl(sqlcl, conn, schema, frontier,
                          capture_to=capture_to, label="ddl-%d" % rounds)
        merge_ddl(ddl, batch)
        discovered = set(find_db_references(source_text_of(batch), known_objects))
        frontier = discovered - referenced
        if frontier:
            log("  depth %d: %d new object(s) referenced by the code just read" % (rounds, len(frontier)))
        referenced |= frontier
    if frontier:
        log("  closure stopped at depth %d with %d still unresolved" % (rounds, len(frontier)))
    return ddl, referenced, rounds


def write_db_tree(out_root, ddl, objects):
    """Write db/ from the raw catalog rows. Returns a list of what was written."""
    written = []

    by_object = {}
    for row in ddl.get("source", []):
        up = {k.upper(): v for k, v in row.items()}
        key = (str(up.get("NAME") or ""), str(up.get("TYPE") or ""))
        by_object.setdefault(key, []).append((int(up.get("LINE") or 0), up.get("TEXT") or ""))
    for (name, otype), lines in sorted(by_object.items()):
        body = "".join(t for _, t in sorted(lines))
        rel = os.path.join("db", "plsql", "%s.%s.sql" % (name.lower(), otype.lower().replace(" ", "-")))
        write_text(os.path.join(out_root, rel), body)
        written.append(rel)

    cols = {}
    for row in ddl.get("columns", []):
        up = {k.upper(): v for k, v in row.items()}
        cols.setdefault(str(up.get("TABLE_NAME") or ""), []).append(up)
    cons = {}
    for row in ddl.get("constraints", []):
        up = {k.upper(): v for k, v in row.items()}
        cons.setdefault(str(up.get("TABLE_NAME") or ""), []).append(up)
    idx = {}
    for row in ddl.get("indexes", []):
        up = {k.upper(): v for k, v in row.items()}
        idx.setdefault(str(up.get("TABLE_NAME") or ""), []).append(up)

    CTYPE = {"P": "primary key", "R": "foreign key", "U": "unique", "C": "check", "V": "view check"}
    for table in sorted(cols):
        body = ["# %s (%s)" % (table, objects.get(table.upper(), "TABLE")), "",
                "| Column | Type | Null | Default |", "|---|---|---|---|"]
        for c in sorted(cols[table], key=lambda r: int(r.get("COLUMN_ID") or 0)):
            dtype = str(c.get("DATA_TYPE") or "")
            if c.get("DATA_PRECISION") not in (None, ""):
                dtype += "(%s%s)" % (c["DATA_PRECISION"],
                                     "," + str(c["DATA_SCALE"]) if c.get("DATA_SCALE") else "")
            elif c.get("DATA_LENGTH") not in (None, "") and dtype.startswith(("VARCHAR", "CHAR", "RAW")):
                dtype += "(%s)" % c["DATA_LENGTH"]
            default = str(c.get("DATA_DEFAULT") or "").strip().replace("\n", " ")[:60]
            body.append("| `%s` | %s | %s | %s |" % (
                c.get("COLUMN_NAME"), dtype,
                "yes" if str(c.get("NULLABLE") or "").upper() == "Y" else "no", default))
        body.append("")

        if cons.get(table):
            body.append("## Constraints")
            body.append("")
            grouped = {}
            for c in cons[table]:
                grouped.setdefault((c.get("CONSTRAINT_NAME"), c.get("CONSTRAINT_TYPE"),
                                    c.get("R_CONSTRAINT_NAME"), c.get("SEARCH_CONDITION_VC")), []) \
                    .append((int(c.get("POSITION") or 0), c.get("COLUMN_NAME")))
            for (cname, ctype, rname, cond), members in sorted(grouped.items(), key=lambda kv: str(kv[0][0])):
                columns = ", ".join("`%s`" % m[1] for m in sorted(members))
                extra = ""
                if rname:
                    extra = " references `%s`" % rname
                elif cond:
                    extra = " check: %s" % str(cond).replace("\n", " ")[:120]
                body.append("- **%s** %s on %s%s" % (cname, CTYPE.get(str(ctype), str(ctype)), columns, extra))
            body.append("")

        if idx.get(table):
            body.append("## Indexes")
            body.append("")
            grouped = {}
            for i in idx[table]:
                grouped.setdefault((i.get("INDEX_NAME"), i.get("UNIQUENESS")), []) \
                    .append((int(i.get("COLUMN_POSITION") or 0), i.get("COLUMN_NAME")))
            for (iname, uniq), members in sorted(grouped.items(), key=lambda kv: str(kv[0][0])):
                body.append("- **%s** (%s) on %s" % (
                    iname, str(uniq or "").lower(),
                    ", ".join("`%s`" % m[1] for m in sorted(members))))
            body.append("")

        rel = os.path.join("db", "tables", "%s.md" % table.lower())
        write_text(os.path.join(out_root, rel), "\n".join(body))
        written.append(rel)
    return written


# -- native export -----------------------------------------------------------------------------

def native_export(sqlcl, conn, app_id, out_root, capture_to=None):
    """Ask SQLcl for the real APEX export, kept as ground truth under raw/.

    Never the primary artifact. It is here so that when a rendered page.md and the source of truth
    disagree, there is something to diff against.
    """
    raw_dir = os.path.join(out_root, "raw")
    os.makedirs(raw_dir, exist_ok=True)
    script = "apex export -applicationid %d -split -dir %s\n" % (app_id, raw_dir)
    text = run_sqlcl(sqlcl, conn, script, capture_to=capture_to, label="native-export")
    produced = []
    for dirpath, _dirs, files in os.walk(raw_dir):
        for f in files:
            produced.append(os.path.relpath(os.path.join(dirpath, f), out_root))
    if not produced:
        return None, "native export produced no files. SQLcl said: %s" % text.strip()[:400]
    return produced, None


# -- connection resolution ---------------------------------------------------------------------

def resolve_connection(args):
    """Order: --conn, then KEEL_APEX_CONN, then --target looked up in a targets file.

    A targets file is the one that keeps a password out of the shell history and out of an agent
    transcript, so it is the documented path even though it is listed last.
    """
    if args.conn:
        return args.conn
    env = os.environ.get("KEEL_APEX_CONN")
    if env:
        return env
    name = args.target
    for path in (os.path.join(".keel", "apex-targets.json"),
                 os.path.expanduser("~/.keel/apex-targets.json")):
        if not os.path.exists(path):
            continue
        with open(path, encoding="utf-8") as fh:
            targets = json.load(fh)
        if name and name in targets:
            return targets[name]["conn"] if isinstance(targets[name], dict) else targets[name]
        if not name and len(targets) == 1:
            only = list(targets.values())[0]
            return only["conn"] if isinstance(only, dict) else only
    raise ExportError(
        "no connection. Pass --conn user/pass@host:port/service, set KEEL_APEX_CONN, or create "
        "~/.keel/apex-targets.json as {\"name\": {\"conn\": \"user/pass@host:port/service\"}} "
        "and pass --target name.")


def find_sqlcl(explicit=None):
    import shutil
    for candidate in (explicit, os.environ.get("KEEL_SQLCL"), "sql", "sqlcl"):
        if not candidate:
            continue
        found = shutil.which(candidate) or (candidate if os.path.isfile(candidate) else None)
        if found:
            return found
    raise ExportError(
        "SQLcl not found. It needs Java and nothing else: download sqlcl-latest.zip from Oracle, "
        "unzip it, and put its bin/ on PATH, or pass --sqlcl /path/to/bin/sql.")


def docs_root():
    try:
        with open(os.path.join(".keel", "profile.json"), encoding="utf-8") as fh:
            return json.load(fh).get("docs_root") or os.path.join("docs", "keel")
    except (OSError, ValueError):
        return os.path.join("docs", "keel")


# -- main --------------------------------------------------------------------------------------

def build(args, probe_info, sections, known_objects, ddl, warnings, out_root):
    manifest = {
        "apex_version": probe_info.get("apex_version"),
        "application_id": probe_info.get("application_id"),
        "application_name": probe_info.get("application_name"),
        "parsing_schema": probe_info.get("parsing_schema"),
        "db_user": probe_info.get("db_user"),
        "method": "APEX dictionary views",
        "has_apex_export": probe_info.get("has_apex_export"),
        "warnings": warnings,
        "redaction": "off" if args.no_redact else "on",
    }
    export = Export(sections, manifest, do_redact=not args.no_redact, known_objects=known_objects)
    summaries = export.write(out_root)
    if ddl:
        write_db_tree(out_root, ddl, known_objects)
    return export, summaries


def main(argv=None):
    p = argparse.ArgumentParser(prog="keel apex-export", add_help=True)
    p.add_argument("--app", type=int, required=True, help="APEX application id")
    p.add_argument("--conn", help="user/pass@host:port/service")
    p.add_argument("--target", help="name in .keel/apex-targets.json or ~/.keel/apex-targets.json")
    p.add_argument("--out", help="output directory (default <docs_root>/apex/APP-<id>)")
    p.add_argument("--sqlcl", help="path to the SQLcl `sql` binary")
    p.add_argument("--no-redact", action="store_true", help="keep values matching credential patterns")
    p.add_argument("--no-ddl", action="store_true", help="skip database object extraction")
    p.add_argument("--raw", action="store_true", help="also run the native APEX export into raw/")
    p.add_argument("--only", help="comma separated section names, for debugging")
    p.add_argument("--capture", help="write raw client output here, for fixtures and for support")
    p.add_argument("--from-capture", help="render from a previous --capture directory, no database")
    p.add_argument("--probe-only", action="store_true", help="report version and capabilities, write nothing")
    args = p.parse_args(argv)

    out_root = args.out or os.path.join(docs_root(), "apex", "APP-%d" % args.app)

    if args.from_capture:
        return replay(args, out_root)

    sqlcl = find_sqlcl(args.sqlcl)
    conn = resolve_connection(args)

    probe_info = probe(sqlcl, conn, args.app, capture_to=args.capture)
    print("APEX %s, application %d (%s), parsing schema %s, connected as %s" % (
        probe_info["apex_version"], args.app, probe_info.get("application_name"),
        probe_info.get("parsing_schema"), probe_info.get("db_user")))
    if args.probe_only:
        print(json.dumps({k: v for k, v in probe_info.items() if k != "columns"}, indent=2, default=str))
        print("dictionary views visible: %d" % len(probe_info.get("columns") or {}))
        return 0

    only = set(args.only.split(",")) if args.only else None
    plan, warnings = plan_sections(probe_info, only)
    if not plan:
        raise ExportError("no readable sections. " + "; ".join(warnings[:5]))
    print("reading %d sections" % len(plan))
    sections = extract(sqlcl, conn, plan, args.app, capture_to=args.capture)

    for name, _view, _cols in plan:
        if name not in sections:
            warnings.append("section `%s`: the query returned no result document, treat as unknown" % name)

    known_objects, ddl = {}, None
    schema = probe_info.get("parsing_schema")
    if not args.no_ddl and schema:
        known_objects = fetch_db_objects(sqlcl, conn, schema, capture_to=args.capture)
        seeds = set(find_db_references(collect_source_text(sections), known_objects))
        print("%d database objects in %s, %d referenced directly by the application"
              % (len(known_objects), schema, len(seeds)))

        # Triggers hang off the tables, not off any reference, so they are seeded by table name.
        tables = {n for n in seeds if "TABLE" in str(known_objects.get(n, "")).upper()}
        triggers = fetch_trigger_names(sqlcl, conn, schema, tables, capture_to=args.capture)
        if triggers:
            print("  %d trigger(s) on those tables, which no reference scan can find"
                  % len(triggers))
            seeds |= set(triggers)

        if seeds:
            ddl, referenced, rounds = resolve_db_closure(
                sqlcl, conn, schema, seeds, known_objects, capture_to=args.capture)
            print("  %d object(s) after following references %d level(s) deep"
                  % (len(referenced), rounds))
            unresolved = sorted(n for n in referenced if n not in known_objects)
            if unresolved:
                warnings.append(
                    "%d object(s) are referenced but do not exist in schema %s, so their code is "
                    "not in this export: %s" % (len(unresolved), schema, ", ".join(unresolved[:20])))
        if not known_objects:
            warnings.append("no objects readable in schema %s: ALL_OBJECTS returned nothing, so "
                            "database dependencies are heuristic only" % schema)

    export, summaries = build(args, probe_info, sections, known_objects, ddl, warnings, out_root)

    if args.raw:
        produced, err = native_export(sqlcl, conn, args.app, out_root, capture_to=args.capture)
        if err:
            warnings.append(err)
        else:
            print("native export: %d files under raw/" % len(produced))

    report(out_root, summaries, export)
    return 0


def replay(args, out_root):
    """Render from a --capture directory. This is what the offline tests drive."""
    cap = args.from_capture
    def read(label):
        path = os.path.join(cap, "%s.out" % label)
        if not os.path.exists(path):
            return None
        with open(path, encoding="utf-8") as fh:
            return fh.read()

    probe_text = read("probe")
    if probe_text is None:
        raise ExportError("no probe.out in %s" % cap)
    probe_info = interpret_probe(probe_text, args.app)

    only = set(args.only.split(",")) if args.only else None
    plan, warnings = plan_sections(probe_info, only)
    extract_text = read("extract")
    sections = named_sections(extract_text, [p[0] for p in plan]) if extract_text else {}

    known_objects = {}
    objects_text = read("objects")
    if objects_text:
        for row in named_sections(objects_text, ["objects"]).get("objects", []):
            up = {k.upper(): v for k, v in row.items()}
            name = str(up.get("OBJECT_NAME") or "").upper()
            if name:
                known_objects.setdefault(name, str(up.get("OBJECT_TYPE") or ""))

    # Closure fetches DDL in rounds, so a capture holds ddl-1.out, ddl-2.out and so on. The
    # unnumbered name is still read for captures taken before closure existed.
    ddl = None
    import glob
    ddl_files = sorted(glob.glob(os.path.join(cap, "ddl*.out")))
    for path in ddl_files:
        with open(path, encoding="utf-8", errors="replace") as fh:
            merge_ddl(ddl if ddl is not None else (ddl := {}),
                      named_sections(fh.read(), ["source", "columns", "constraints", "indexes"]))

    warnings.append("rendered from a capture directory, not from a live database")
    export, summaries = build(args, probe_info, sections, known_objects, ddl, warnings, out_root)
    report(out_root, summaries, export)
    return 0


def report(out_root, summaries, export):
    bands = {}
    for s in summaries:
        bands[s["band"]] = bands.get(s["band"], 0) + 1
    print("wrote %s" % out_root)
    print("  %d pages: %s" % (len(summaries),
                              ", ".join("%s %d" % (b, bands[b]) for b in sorted(bands)) or "none"))
    print("  %d database object references in xref.tsv" % len({x[0] for x in export.xref}))
    if export.redaction_log:
        print("  %d value(s) redacted, see REDACTIONS.md" % len(export.redaction_log))
    print("  start at %s" % os.path.join(out_root, "INDEX.md"))


if __name__ == "__main__":
    try:
        sys.exit(main())
    except ExportError as exc:
        sys.stderr.write("keel apex-export: %s\n" % exc)
        sys.exit(1)
    except KeyboardInterrupt:
        sys.exit(130)
