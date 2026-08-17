"""Render extracted APEX metadata into a tree an agent can grep.

Pure functions only. Nothing here opens a connection or reads the network, which is what lets
tests/test-apex-export.sh drive the whole renderer from recorded fixtures with no database. The
I/O half lives in apex_export.py; keep the split, because the moment rendering needs a cursor
the offline tests stop proving anything.

The unit of output is a directory per page. The alternative, one file per application, is what
the native APEX export already produces, and it is unusable: every reference in it is a 14 digit
internal id, so grepping for a table name finds nothing.
"""

import json
import os
import re

# Columns present on nearly every APEX view that carry no porting signal. Dropped before write so
# a page.md stays readable. Theme and template columns are the bulk of it: the UI is being
# rewritten, so which grid template a region used is noise.
NOISE_COLUMN_RE = re.compile(
    r"^(TEMPLATE|.*_TEMPLATE|THEME_.*|.*_THEME|CSS_.*|.*_CSS|"
    r"ICON_CSS_CLASSES|.*_IMAGE|IMAGE_.*|.*_COMMENT|COMMENTS|"
    r"LAST_UPDATED_(BY|ON)|CREATED_(BY|ON)|.*_SEQUENCE|DISPLAY_SEQUENCE|"
    r"WORKSPACE(_ID)?|SECURITY_GROUP_ID|.*_ATTRIBUTE_[0-9]+)$"
)

# Columns whose contents are SQL or PL/SQL. These are written to their own files rather than
# inlined into page.md: an agent porting a report needs the query verbatim, and a query buried in
# a markdown table is a query that has been reformatted and can no longer be trusted.
# Column names verified against a live APEX 22.2 catalog. The guessed names this replaced were
# wrong in the places that mattered most: a computation's code is in `COMPUTATION`, not
# `COMPUTATION_EXPRESSION1`, and an application process's is in `PROCESS`, not `PROCESS_SOURCE`.
# Both guesses produced an export that looked complete and contained no code.
#
# `ATTRIBUTE_01` is deliberately typed as text rather than plsql. It is polymorphic: on the
# authorization view it holds the scheme's PL/SQL, on a region it holds a plugin setting. Naming
# the file `.txt` is honest about not knowing which.
SOURCE_COLUMNS = {
    # Queries
    "REGION_SOURCE": "sql",
    "WHERE_CLAUSE": "sql",
    "ORDER_BY_CLAUSE": "sql",
    "RUNTIME_WHERE_CLAUSE": "sql",
    "LIST_OF_VALUES_QUERY": "sql",
    "LOV_DEFINITION": "sql",
    "LIST_QUERY": "sql",
    "FILTER_LOV_QUERY": "sql",
    "LOV_SOURCE": "sql",
    "SOURCE_EXPRESSION": "sql",
    "COLUMN_EXPR": "sql",
    "HTML_EXPRESSION": "sql",
    "EXTERNAL_FILTER_EXPR": "sql",
    "EXTERNAL_ORDER_BY_EXPR": "sql",
    "CACHE_INVALIDATION_EXPR": "sql",
    # Server side code
    "PROCESS_SOURCE": "plsql",
    "PROCESS": "plsql",
    "COMPUTATION": "plsql",
    "VALIDATION_EXPRESSION1": "plsql",
    "VALIDATION_EXPRESSION2": "plsql",
    "CONDITION_EXPRESSION1": "plsql",
    "CONDITION_EXPRESSION2": "plsql",
    "READ_ONLY_CONDITION_EXP1": "plsql",
    "READ_ONLY_CONDITION_EXP2": "plsql",
    "SERVER_CONDITION_EXPRESSION1": "plsql",
    "SERVER_CONDITION_EXPRESSION2": "plsql",
    "CLIENT_CONDITION_EXPRESSION": "plsql",
    "CACHE_WHEN_EXPRESSION_1": "plsql",
    "CACHE_WHEN_EXPRESSION_2": "plsql",
    "CACHE_CONDITION_EXP_1": "plsql",
    "CACHE_CONDITION_EXP_2": "plsql",
    "CURRENT_FOR_PAGES_EXPRESSION": "plsql",
    "DISPLAY_CONDITION": "plsql",
    "DISPLAY_CONDITION2": "plsql",
    "DEFAULT_EXPRESSION": "plsql",
    "WHEN_EXPRESSION": "plsql",
    "WHEN_CONDITION": "plsql",
    "ITEM_DEFAULT": "plsql",
    "ITEM_SOURCE": "plsql",
    "SOURCE_POST_PROCESSING": "plsql",
    "SOURCE_POST_COMPUTATION": "plsql",
    "PAGE_FUNCTION": "plsql",
    "ERROR_HANDLING_FUNCTION": "plsql",
    "PRE_AUTHENTICATION_PROCESS": "plsql",
    "POST_AUTHENTICATION_PROCESS": "plsql",
    "VERIFICATION_FUNCTION": "plsql",
    "PLSQL_CODE": "plsql",
    "DB_SESSION_INIT_CODE": "plsql",
    "DB_SESSION_CLEANUP_CODE": "plsql",
    # Client side code
    "JAVASCRIPT_CODE": "js",
    "JAVASCRIPT_CODE_ONLOAD": "js",
    "ACTION_CODE": "js",
    "INIT_JAVASCRIPT_CODE": "js",
    "ONCLICK_JAVASCRIPT": "js",
    "RELOAD_ON_SUBMIT_CODE": "js",
    # Prose and markup that still has to be reproduced somewhere
    "REGION_HEADER_TEXT": "text",
    "REGION_FOOTER_TEXT": "text",
    "HEADER_TEXT": "text",
    "FOOTER_TEXT": "text",
    "BODY_HEADER": "text",
    "ENTRY_TEXT": "text",
    "ATTRIBUTE_01": "text",
    "ATTRIBUTE_02": "text",
}

# Region types that do not survive a port as a configuration change. Each one is a mechanic APEX
# implements for you that a React or Next.js front end has no equivalent for, so the port is a
# rebuild of behaviour and not a translation of markup. Matched case insensitively as a substring
# of the region type. The weight is calibrated so that one of these alone lands the page in `high`:
# a single Interactive Grid is never a mechanical port, and a band that said `medium` for one would
# be the tool understating the work in the case that matters most.
HARD_REGION_TYPES = {
    "interactive grid": (22, "Interactive Grid: inline editing, row DML, saved reports and client side model. No equivalent, rebuild deliberately"),
    "tabular form": (22, "Tabular Form: APEX generates the DML and the checksum handling, both must be rebuilt by hand"),
    "interactive report": (14, "Interactive Report: user saved reports, filters, aggregates and downloads are a feature set, not a table. Check which of it is actually used"),
    "calendar": (14, "Calendar region: rebuild against a calendar component"),
    "tree": (14, "Tree region: hierarchical query plus a client component"),
    "map": (14, "Map region: rebuild against a mapping library"),
    "jasper": (12, "Reporting plugin: an external report engine sits behind this"),
    "plugin": (12, "Plugin region: third party code, and its source may not be in this export"),
}

# One page of PL/SQL is roughly this many characters. Used only to turn a character count into a
# number a human can weigh, never as a hard threshold.
PLSQL_CHARS_PER_SCREEN = 1200

# Longest value the attribute table will render inline. Anything longer is written to
# its own file instead, because a clipped value is indistinguishable from a short one.
ATTRIBUTE_CLIP_CHARS = 300

# Words that make the string beside them a secret. Kept as one list so a new one is added in a
# single place, and so the PL/SQL declaration form below stays in step with the assignment form.
SECRET_WORDS = r"password|passwd|pwd|secret|api[_-]?key|apikey|auth[_-]?token|token|private[_-]?key|credential"

REDACTIONS = [
    # Ordered: specific before general, so a password inside a connect string is labelled as a
    # password rather than swallowed by the connect string rule.
    #
    # Two assignment forms are needed, and the second was added because the first missed a real
    # case in the fixture: `l_password varchar2(100) := 'S3ttl3M3nt!2024'`. A PL/SQL declaration
    # puts the type between the name and the value, so a pattern anchored on `name := value` walks
    # straight past the most common way a hardcoded password appears in an APEX process.
    # Group 1 is everything up to and including the operator, so the replacement puts it back
    # verbatim and the surrounding PL/SQL still reads as the declaration it was.
    ("password", re.compile(r"(?i)(\b[a-z0-9_$#]*(?:%s)[a-z0-9_$#]*\s*(?::=|=>|=|:)\s*)'[^']{1,400}'" % SECRET_WORDS)),
    # `{1,3}` words between the name and the assignment covers `l_pwd varchar2(30) :=` and also
    # `l_api_key constant varchar2(64) :=`, which the single word version missed. A comma cannot
    # match, so the run stops at a parameter boundary and cannot reach across a declaration list.
    ("password", re.compile(r"(?i)(\b[a-z0-9_$#]*(?:%s)[a-z0-9_$#]*(?:\s+[a-z0-9_$#]+){1,3}\s*(?:\([0-9,\s]*\))?\s*:=\s*)'[^']{1,400}'" % SECRET_WORDS)),
    ("basic-auth-url", re.compile(r"(?i)\b([a-z][a-z0-9+.-]*://)([^\s:'\"/@]+):([^\s'\"@]+)@")),
    ("connect-string", re.compile(r"(?i)\b([a-z0-9_$#]+)/([^\s'\"@;]{3,})@([a-z0-9_.:/-]+)")),
    ("bearer", re.compile(r"(?i)\b(bearer)\s+([A-Za-z0-9._~+/=-]{20,})")),
]


def slugify(text, fallback="unnamed"):
    """Lowercase, hyphenated, filesystem safe. Truncated hard, because a page title in APEX can be
    a sentence and a 200 character directory name breaks tar on some systems."""
    s = re.sub(r"[^a-zA-Z0-9]+", "-", (text or "")).strip("-").lower()
    s = re.sub(r"-{2,}", "-", s)
    return (s[:48].rstrip("-") or fallback)


def upper_keys(row):
    """SQLcl lowercases column names in JSON output. Everything downstream reads uppercase, which
    matches how the columns are named in the Oracle catalog and in the APEX documentation."""
    return {str(k).upper(): v for k, v in row.items()}


def is_blank(value):
    return value is None or (isinstance(value, str) and value.strip() == "")


def redact(text):
    """Return (redacted_text, [finding_names]).

    Exports carry live credentials more often than anyone expects: a process that calls a partner
    API with a hardcoded key, a database link with an embedded password. The export lands in a
    docs directory that is usually committed, so redaction is on by default and the caller has to
    ask for the raw values.
    """
    if not isinstance(text, str) or not text:
        return text, []
    found = []
    out = text
    for name, pattern in REDACTIONS:
        def _sub(m, _name=name):
            found.append(_name)
            g = m.groups()
            if _name == "basic-auth-url":
                # scheme://user:pass@  ->  scheme://user:[REDACTED]@   The user is left in place:
                # it is not a secret and it is often the only clue to which system is being called.
                return "%s%s:[REDACTED:%s]@" % (g[0], g[1], _name)
            if _name == "connect-string":
                return "%s/[REDACTED:%s]@%s" % (g[0], _name, g[2])
            if _name == "bearer":
                return "%s [REDACTED:%s]" % (g[0], _name)
            # password: group 1 is the whole assignment prefix, replayed verbatim.
            return "%s'[REDACTED:%s]'" % (g[0], _name)
        out = pattern.sub(_sub, out)
    return out, found


# Identifiers that appear in every PL/SQL block and are never the object anyone is looking for.
SQL_NOISE_WORDS = frozenset("""
select from where and or not in is null as by group order having join left right inner outer on
union all distinct insert into values update set delete begin end if then else elsif loop for while
declare exception when others raise return procedure function package body type record table of
commit rollback savepoint cursor open close fetch bulk collect using dual sysdate systimestamp
count sum avg min max nvl nvl2 decode case coalesce trim substr instr upper lower length to_char
to_date to_number trunc round replace lpad rpad rtrim ltrim rownum rowid level connect prior start
apex_application apex_util apex_error apex_json apex_string apex_item apex_lang apex_debug
dbms_output htp htf sys_context user v g p f wwv_flow number varchar2 date clob blob boolean
integer pls_integer binary_integer constant default exists between like escape asc desc fetch next
rows only with over partition row_number rank dense_rank lag lead first last exit continue goto
""".split())

IDENT_RE = re.compile(r"\b([A-Za-z][A-Za-z0-9_$#]{2,29})\b")
# FROM/JOIN/INTO/UPDATE capture the object even when no catalog list is available to match against.
FROM_RE = re.compile(
    r"(?is)\b(?:from|join|into|update|merge\s+into|delete\s+from)\s+([A-Za-z][A-Za-z0-9_$#]*(?:\.[A-Za-z][A-Za-z0-9_$#]*)?)"
)
CALL_RE = re.compile(r"\b([A-Za-z][A-Za-z0-9_$#]{1,29})\.([A-Za-z][A-Za-z0-9_$#]{1,29})\s*\(")


def find_db_references(source, known_objects=None):
    """Identifiers in `source` that name a database object.

    When `known_objects` is supplied (a dict of NAME -> TYPE read from the catalog) it is the
    authority, because matching against what actually exists is the only way to avoid reporting a
    column alias as a table. Without it, fall back to shape: what follows FROM, JOIN, UPDATE, and
    what is called as package.procedure. The fallback over reports; that is the right direction,
    since a missed dependency understates the port and a spurious one is visible on inspection.
    """
    if not isinstance(source, str) or not source.strip():
        return {}
    hits = {}
    if known_objects:
        for m in IDENT_RE.finditer(source):
            name = m.group(1).upper()
            if name not in known_objects:
                continue
            # An object whose name is also a SQL keyword counts only where it is called, never as a
            # bare word. A real schema contained a function named JOIN, and matching bare
            # identifiers put 54 spurious rows in xref.tsv, one for every query with a join in it.
            # That is the file the whole export exists to make greppable, so a flood in it is worse
            # than a miss: it teaches the reader the file is noise.
            if name.lower() in SQL_NOISE_WORDS and not source[m.end():].lstrip().startswith("("):
                continue
            hits[name] = known_objects[name]
        for m in CALL_RE.finditer(source):
            name = m.group(1).upper()
            if name in known_objects:
                hits[name] = known_objects[name]
        return hits
    for m in FROM_RE.finditer(source):
        name = m.group(1).upper().split(".")[-1]
        if name.lower() not in SQL_NOISE_WORDS:
            hits[name] = "TABLE_OR_VIEW?"
    for m in CALL_RE.finditer(source):
        name = m.group(1).upper()
        if name.lower() not in SQL_NOISE_WORDS and not name.startswith(("APEX_", "WWV_", "DBMS_", "UTL_", "SYS_")):
            hits[name] = "PACKAGE?"
    return hits


def score_page(page, components):
    """Return (band, score, reasons), where reasons is a list of (points, explanation).

    Additive: every component that has to end up somewhere in the new application contributes,
    rather than only the excess over a threshold. The first version of this counted excess only,
    and scored a page with eighteen items, two PL/SQL processes and eight dynamic actions as
    `low`, because none of its counts individually cleared a threshold. Understating the work on
    the busiest page is the one failure that makes the whole assessment worthless.

    The reasons are what anyone actually uses; the number only ranks pages against each other.
    """
    reasons = []
    score = 0.0

    def add(points, why):
        nonlocal score
        if points > 0:
            score += points
            reasons.append((round(points, 1), why))

    regions = components.get("regions", [])
    items = components.get("items", [])
    processes = components.get("processes", [])
    validations = components.get("validations", [])
    branches = components.get("branches", [])
    da_events = components.get("da_events", [])
    da_actions = components.get("da_actions", [])
    computations = components.get("computations", [])
    buttons = components.get("buttons", [])

    for region in regions:
        rtype = str(region.get("SOURCE_TYPE") or region.get("REGION_TYPE")
                    or region.get("REGION_SUB_TYPE") or "").lower()
        matched = False
        for needle, (weight, why) in HARD_REGION_TYPES.items():
            if needle in rtype:
                add(weight, why)
                matched = True
                break
        if matched:
            continue
        source = region.get("REGION_SOURCE")
        if isinstance(source, str) and re.search(r"(?i)\bselect\b", source):
            add(1, "region `%s` carries a query to port" % (region.get("REGION_NAME") or rtype or "?"))
        else:
            add(0.3, "region `%s` is static content" % (region.get("REGION_NAME") or rtype or "?"))

    if items:
        add(0.3 * len(items), "%d page items, each one a form field with a source, a default and "
                              "possibly a condition" % len(items))
    if processes:
        add(3.0 * len(processes), "%d page process(es): server side logic that has to move into an "
                                  "API route or a service" % len(processes))
    if validations:
        add(1.0 * len(validations), "%d validation(s) to reimplement, and they must hold on the "
                                    "server as well as in the browser" % len(validations))
    if computations:
        add(1.0 * len(computations), "%d computation(s) on session state" % len(computations))
    if buttons:
        add(0.2 * len(buttons), "%d button(s)" % len(buttons))
    if branches:
        add(0.5 * len(branches), "%d branch(es), so navigation is conditional on page state" % len(branches))

    n_da = len(da_events) + len(da_actions)
    if n_da:
        add(1.5 * len(da_events) + 1.0 * len(da_actions),
            "%d dynamic action event(s) and %d action(s): this is the page's client side logic and "
            "it is not written down anywhere else" % (len(da_events), len(da_actions)))

    plsql_chars = 0
    for group in (processes, validations, computations):
        for row in group:
            for col, kind in SOURCE_COLUMNS.items():
                if kind == "plsql" and isinstance(row.get(col), str):
                    plsql_chars += len(row[col])
    if plsql_chars > 0:
        screens = plsql_chars / float(PLSQL_CHARS_PER_SCREEN)
        add(min(screens, 20), "roughly %.1f screens of PL/SQL in page logic (%d characters)"
            % (screens, plsql_chars))

    js = 0
    for col in ("JAVASCRIPT_CODE", "JAVASCRIPT_CODE_ONLOAD", "JAVASCRIPT_FUNCTION"):
        value = page.get(col)
        if isinstance(value, str):
            js += len(value.strip())
    if js:
        add(min(js / 300.0, 10), "%d characters of inline JavaScript on the page itself" % js)

    if not reasons:
        reasons.append((0, "no components found: either the page is empty or it is a page this "
                           "export could not read"))

    if score >= 35:
        band = "rewrite"
    elif score >= 18:
        band = "high"
    elif score >= 8:
        band = "medium"
    else:
        band = "low"
    return band, round(score, 1), reasons


BAND_ORDER = {"rewrite": 0, "high": 1, "medium": 2, "low": 3}


def group_by_page(rows, page_key="PAGE_ID"):
    out = {}
    for row in rows:
        pid = row.get(page_key)
        if pid is None:
            continue
        out.setdefault(int(pid), []).append(row)
    return out


def component_label(row, index):
    """A stable, readable filename stem for one component.

    The generic `*_NAME` sweep at the end is not decoration. Without it, every shared component
    whose name column this list did not happen to enumerate was written as `01-component.plsql`,
    which is a file an agent cannot connect back to the scheme a page referenced by name.
    """
    for col in ("REGION_NAME", "PROCESS_NAME", "VALIDATION_NAME", "COMPUTATION_ITEM",
                "ITEM_NAME", "BUTTON_NAME", "BRANCH_NAME", "LIST_NAME", "LOV_NAME",
                "AUTHORIZATION_SCHEME_NAME", "AUTHENTICATION_NAME", "BUILD_OPTION_NAME",
                "DYNAMIC_ACTION_NAME", "ACTION_NAME", "EVENT_NAME", "TAB_NAME", "ENTRY_LABEL",
                "COLUMN_ALIAS", "STATIC_ID", "NAME"):
        if not is_blank(row.get(col)):
            return "%02d-%s" % (index, slugify(str(row[col])))
    for col in sorted(row):
        if (col.endswith("_NAME") or col.endswith("_LABEL")) and not is_blank(row.get(col)):
            return "%02d-%s" % (index, slugify(str(row[col])))
    for col in ("REGION_ID", "PROCESS_ID", "ITEM_ID", "ID"):
        if row.get(col) is not None:
            return "%02d-%s" % (index, str(row[col])[-8:])
    return "%02d-component" % index


def write_text(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text if text.endswith("\n") else text + "\n")


def render_attribute_table(row, skip=()):
    """Row attributes as a two column markdown table, noise dropped.

    `skip` is the set of columns already written to their own file. It is not "every source
    column": short code values do not earn a file, and excluding them here as well dropped them
    from the export completely. An authorization scheme whose entire body is
    `return sec_pkg.has_role(:APP_USER, 'MERCHANT_VIEW');` vanished that way, which is the one
    piece of information anyone reads that section for.
    """
    lines = ["| Attribute | Value |", "|---|---|"]
    any_row = False
    for col in sorted(row):
        if col in skip or NOISE_COLUMN_RE.match(col):
            continue
        value = row[col]
        if is_blank(value):
            continue
        text = str(value).replace("|", "\\|").replace("\n", " ")
        if len(text) > ATTRIBUTE_CLIP_CHARS:
            text = text[:ATTRIBUTE_CLIP_CHARS - 3] + "..."
        lines.append("| `%s` | %s |" % (col, text))
        any_row = True
    return "\n".join(lines) if any_row else "_No attributes set._"


class Export:
    """Holds one application's extracted metadata and writes the tree."""

    def __init__(self, data, manifest, do_redact=True, known_objects=None):
        self.sections = {k: [upper_keys(r) for r in v] for k, v in data.items()}
        self.manifest = dict(manifest)
        self.do_redact = do_redact
        self.known_objects = known_objects or {}
        self.xref = []           # (db_object, kind, page_id, artifact_path)
        self.redaction_log = []  # (artifact_path, finding)
        self.app = (self.sections.get("application") or [{}])[0]

    # -- helpers ---------------------------------------------------------------

    def app_id(self):
        for candidate in (self.app.get("APPLICATION_ID"), self.manifest.get("application_id")):
            if candidate is not None:
                return int(candidate)
        return 0

    def _emit_source(self, out_root, rel_dir, stem, row, page_id):
        """Write every SQL or PL/SQL column of `row` to its own file. Returns written paths."""
        written = []
        # Known code columns, plus any column whose value is long enough that the attribute table
        # would clip it. Without the second rule a code-bearing column this map has never heard of
        # is silently truncated to 300 characters: a real export lost 62 inline LOV queries that way,
        # every one of them cut mid-SQL, and the reader has no way to tell a clipped query from a
        # short one. Anything at risk of clipping goes to a file instead, whole.
        candidates = dict(SOURCE_COLUMNS)
        for col, value in row.items():
            if col in candidates or NOISE_COLUMN_RE.match(col):
                continue
            if isinstance(value, str) and len(value.strip()) > ATTRIBUTE_CLIP_CHARS:
                candidates[col] = "text"

        for col, kind in candidates.items():
            value = row.get(col)
            if is_blank(value) or not isinstance(value, str):
                continue
            # A file per value only when the value is actually code. Condition expressions exist on
            # nearly every component and are usually one short line, an item name or a page number.
            # Writing each to its own file buried the real sources: one application produced several
            # thousand files, most of them eleven characters long. Short values stay in the
            # attribute table, where they read perfectly well and cost nothing to scan.
            body_text = value.strip()
            if "\n" not in body_text and len(body_text) < 80:
                continue
            ext = {"sql": "sql", "plsql": "plsql", "js": "js", "text": "txt"}[kind]
            rel = os.path.join(rel_dir, "%s.%s.%s" % (stem, col.lower(), ext))
            body = value
            if self.do_redact:
                body, findings = redact(body)
                for f in findings:
                    self.redaction_log.append((rel, f))
            write_text(os.path.join(out_root, rel), body)
            written.append((rel, col))
            for name, otype in find_db_references(value, self.known_objects).items():
                self.xref.append((name, otype, page_id, rel))
        return written

    # -- writers ---------------------------------------------------------------

    def write(self, out_root):
        os.makedirs(out_root, exist_ok=True)
        pages = sorted(self.sections.get("pages", []), key=lambda r: int(r.get("PAGE_ID") or 0))
        by_page = {name: group_by_page(rows) for name, rows in self.sections.items()
                   if name not in ("application", "pages")}

        summaries = []
        for page in pages:
            summaries.append(self._write_page(out_root, page, by_page))

        self._write_shared(out_root)
        self._write_xref(out_root)
        self._write_index(out_root, summaries)
        self._write_manifest(out_root, summaries)
        if self.redaction_log:
            self._write_redactions(out_root)
        return summaries

    def _write_page(self, out_root, page, by_page):
        pid = int(page.get("PAGE_ID") or 0)
        name = page.get("PAGE_NAME") or page.get("PAGE_TITLE") or "page-%d" % pid
        rel_dir = os.path.join("pages", "%05d-%s" % (pid, slugify(str(name))))

        components = {section: rows.get(pid, []) for section, rows in by_page.items()}
        band, score, reasons = score_page(page, components)

        body = ["# Page %d: %s" % (pid, name), ""]
        body.append("| | |")
        body.append("|---|---|")
        body.append("| Page mode | %s |" % (page.get("PAGE_MODE") or page.get("PAGE_TEMPLATE") or "Unknown"))
        body.append("| Authorization | %s |" % (page.get("AUTHORIZATION_SCHEME") or "none"))
        body.append("| Page access protection | %s |" % (page.get("PAGE_ACCESS_PROTECTION") or "Unknown"))
        body.append("| Port difficulty | **%s** (score %s) |" % (band, score))
        body.append("")
        body.append("## Why this band")
        body.append("")
        body.append("Every contribution is listed so the band can be argued with. The number ranks")
        body.append("this page against the others in this application. It is not an estimate of hours.")
        body.append("")
        body.append("| Points | Contribution |")
        body.append("|---|---|")
        for points, why in reasons:
            body.append("| %s | %s |" % (points, why))
        body.append("")

        for section in ("regions", "items", "buttons", "processes", "validations",
                        "computations", "branches", "da_events", "da_actions", "ig_columns",
                        "ir_columns"):
            rows = components.get(section) or []
            if not rows:
                continue
            body.append("## %s (%d)" % (section.replace("_", " ").title(), len(rows)))
            body.append("")
            for i, row in enumerate(rows, 1):
                stem = component_label(row, i)
                body.append("### %s" % stem)
                body.append("")
                written = self._emit_source(out_root, os.path.join(rel_dir, section), stem, row, pid)
                for rel, _col in written:
                    body.append("- Source: [`%s`](%s)" % (os.path.basename(rel),
                                                          os.path.relpath(rel, rel_dir)))
                if written:
                    body.append("")
                body.append(render_attribute_table(row, skip={c for _r, c in written}))
                body.append("")

        # Page level JavaScript and CSS are page attributes, not components, so they are emitted
        # from the page row itself or they are lost.
        self._emit_source(out_root, rel_dir, "page", page, pid)

        write_text(os.path.join(out_root, rel_dir, "page.md"), "\n".join(body))
        return {
            "page_id": pid,
            "name": str(name),
            "path": os.path.join(rel_dir, "page.md"),
            "band": band,
            "score": score,
            "reasons": reasons,
            "counts": {k: len(v) for k, v in components.items() if v},
            "authorization": page.get("AUTHORIZATION_SCHEME") or "",
        }

    def _write_shared(self, out_root):
        """Shared components, one file each. These are the things a page references by name, so an
        agent reading a page.md needs somewhere to resolve the name to a definition."""
        shared = ("lovs", "lov_entries", "lists", "list_entries", "app_items", "app_processes",
                  "app_computations", "authorization", "authentication", "build_options",
                  "web_sources", "plugins", "tabs", "nav")
        for section in shared:
            rows = self.sections.get(section) or []
            if not rows:
                continue
            rel_dir = os.path.join("shared", section)
            body = ["# %s (%d)" % (section.replace("_", " ").title(), len(rows)), ""]
            for i, row in enumerate(rows, 1):
                stem = component_label(row, i)
                body.append("## %s" % stem)
                body.append("")
                written = self._emit_source(out_root, rel_dir, stem, row, None)
                for rel, _col in written:
                    body.append("- Source: [`%s`](%s)" % (os.path.basename(rel), os.path.basename(rel)))
                if written:
                    body.append("")
                body.append(render_attribute_table(row, skip={c for _r, c in written}))
                body.append("")
            write_text(os.path.join(out_root, rel_dir, "index.md"), "\n".join(body))

    def _write_xref(self, out_root):
        """One fact per line, sorted by object. This is the file that makes the export worth
        producing: `grep EMPLOYEES xref.tsv` answers "what breaks if I change this table"."""
        lines = ["db_object\tkind\tpage_id\tartifact"]
        seen = set()
        for name, kind, page_id, rel in sorted(self.xref, key=lambda t: (t[0], t[2] or -1, t[3])):
            key = (name, kind, page_id, rel)
            if key in seen:
                continue
            seen.add(key)
            lines.append("%s\t%s\t%s\t%s" % (name, kind, "" if page_id is None else page_id, rel))
        write_text(os.path.join(out_root, "xref.tsv"), "\n".join(lines))

    def _write_redactions(self, out_root):
        counts = {}
        for rel, finding in self.redaction_log:
            counts.setdefault(finding, []).append(rel)
        body = ["# Redactions", "",
                "Values matching a credential pattern were replaced with `[REDACTED:kind]` before",
                "this export was written. Re-run with `--no-redact` to keep them, but do not commit",
                "the result.", ""]
        for finding in sorted(counts):
            body.append("## %s (%d)" % (finding, len(counts[finding])))
            body.append("")
            for rel in sorted(set(counts[finding])):
                body.append("- `%s`" % rel)
            body.append("")
        write_text(os.path.join(out_root, "REDACTIONS.md"), "\n".join(body))

    def _write_manifest(self, out_root, summaries):
        manifest = dict(self.manifest)
        manifest["pages"] = len(summaries)
        manifest["bands"] = {}
        for s in summaries:
            manifest["bands"][s["band"]] = manifest["bands"].get(s["band"], 0) + 1
        manifest["sections"] = {k: len(v) for k, v in self.sections.items()}
        manifest["redactions"] = len(self.redaction_log)
        manifest["db_objects_referenced"] = sorted({x[0] for x in self.xref})
        with open(os.path.join(out_root, "manifest.json"), "w", encoding="utf-8") as fh:
            json.dump(manifest, fh, indent=2, sort_keys=True)
            fh.write("\n")

    def _write_index(self, out_root, summaries):
        app_name = self.app.get("APPLICATION_NAME") or "Application %d" % self.app_id()
        m = self.manifest
        body = ["# APEX application %d: %s" % (self.app_id(), app_name), ""]
        body.append("| | |")
        body.append("|---|---|")
        body.append("| APEX version | %s |" % m.get("apex_version", "Unknown"))
        body.append("| Parsing schema | %s |" % (self.app.get("OWNER") or "Unknown"))
        body.append("| Authentication | %s |" % (self.app.get("AUTHENTICATION_SCHEME")
                                                 or self.app.get("AUTHENTICATION") or "Unknown"))
        body.append("| Pages | %d |" % len(summaries))
        body.append("| Extraction method | %s |" % m.get("method", "dictionary views"))
        body.append("| Database objects referenced | %d |" % len({x[0] for x in self.xref}))
        body.append("")

        bands = {}
        for s in summaries:
            bands[s["band"]] = bands.get(s["band"], 0) + 1
        body.append("## Port difficulty")
        body.append("")
        body.append("| Band | Pages | Meaning |")
        body.append("|---|---|---|")
        meanings = {
            "low": "translate the query and render it, mechanical",
            "medium": "translate plus real form or process logic to move",
            "high": "significant page logic or a component with no equivalent",
            "rewrite": "the APEX mechanic is the feature; rebuild it deliberately",
        }
        for band in ("low", "medium", "high", "rewrite"):
            body.append("| %s | %d | %s |" % (band, bands.get(band, 0), meanings[band]))
        body.append("")
        body.append("Scores rank pages against each other in this application. They are not hours.")
        body.append("")

        body.append("## Pages")
        body.append("")
        body.append("| Page | Name | Band | Score | Components | Authorization |")
        body.append("|---|---|---|---|---|---|")
        for s in sorted(summaries, key=lambda x: (BAND_ORDER[x["band"]], -x["score"], x["page_id"])):
            counts = ", ".join("%s %d" % (k[:6], v) for k, v in sorted(s["counts"].items()))
            body.append("| [%d](%s) | %s | %s | %s | %s | %s |" % (
                s["page_id"], s["path"], s["name"].replace("|", "\\|"), s["band"], s["score"],
                counts or "none", s["authorization"] or "none"))
        body.append("")
        body.append("The top reason for each page that is not `low`, so the shape of the work is")
        body.append("visible without opening every file:")
        body.append("")
        for s in sorted(summaries, key=lambda x: (BAND_ORDER[x["band"]], -x["score"], x["page_id"])):
            if s["band"] == "low" or not s["reasons"]:
                continue
            top = max(s["reasons"], key=lambda r: r[0])
            body.append("- **Page %d %s**: %s" % (s["page_id"], s["name"], top[1]))
        body.append("")

        if m.get("warnings"):
            body.append("## What could not be read")
            body.append("")
            body.append("Every line here is scope this export does not cover. Treat it as unknown,")
            body.append("not as absent.")
            body.append("")
            for w in m["warnings"]:
                body.append("- %s" % w)
            body.append("")

        body.append("## Layout")
        body.append("")
        body.append("- `INDEX.md` this file, the page inventory")
        body.append("- `xref.tsv` one line per database object use: `grep TABLE_NAME xref.tsv`")
        body.append("- `manifest.json` probe results, section counts, warnings")
        body.append("- `pages/NNNNN-name/page.md` one page, with its SQL and PL/SQL beside it")
        body.append("- `shared/` LOVs, lists, authorization and authentication schemes")
        body.append("- `db/` DDL for the objects the application references")
        body.append("- `raw/` the native APEX export, kept as ground truth, not for reading")
        body.append("")
        write_text(os.path.join(out_root, "INDEX.md"), "\n".join(body))
