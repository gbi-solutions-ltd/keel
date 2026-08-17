# Connections, privileges, and what goes wrong

## The user to ask for

A read only database user, mapped to the workspace that owns the application.

That last clause is the one people miss. `APEX_APPLICATION_PAGES` and its siblings filter on the
workspaces the connecting schema is associated with. A user with `SELECT ANY DICTIONARY` and no
workspace association sees an empty application list and no error, which reads exactly like an
application that does not exist.

The association is made in the APEX builder under Workspace, Manage, Schema Association, or by an
administrator running `apex_instance_admin.add_schema`. Ask for it explicitly.

### What each privilege buys

| Grant | What stops working without it |
|---|---|
| Workspace association for the schema | Everything. The application is invisible. |
| `SELECT` on the application's tables | `db/tables/*.md` is empty, so no column types for the data model |
| `SELECT` on `ALL_SOURCE` for the parsing schema | `db/plsql/` is empty, and the business logic is the largest part of the port |
| `APEX_ADMINISTRATOR_ROLE` | Only `--raw` (the native export). Not needed otherwise, do not ask for it |
| `SELECT_CATALOG_ROLE` | Nothing this tool uses. `DBMS_METADATA.GET_DDL` is deliberately not used |

`ALL_SOURCE` is worth pressing for. Without it the export still lists which packages a page calls,
from `xref.tsv`, but not what they do, and an APEX application is a thin skin over its PL/SQL.

## Connection strings

Easy Connect, which needs no `tnsnames.ora`:

```
user/pass@host:1521/service_name
user/pass@//host:1521/service_name
```

TNS alias, when `TNS_ADMIN` points at a directory holding `tnsnames.ora`:

```
user/pass@ALIAS
```

Autonomous Database with a wallet: unzip the wallet, set `TNS_ADMIN` to that directory, and use
the alias from its `tnsnames.ora`, usually something like `dbname_high`.

```
TNS_ADMIN=/path/to/wallet keel apex-export --app 100 --target prod-ro
```

## Where the connection is read from

In order: `--conn`, then `KEEL_APEX_CONN`, then `--target` looked up in `.keel/apex-targets.json`
and then `~/.keel/apex-targets.json`.

The targets file is last in the list and first in preference. `--conn` puts the password in shell
history and in an agent transcript; the environment variable puts it in whatever set it. A file at
mode 600 that the user wrote themselves is the only one of the three that keeps the password out
of a conversation log.

The home directory copy is the right place for a shared instance. The project copy is for a
throwaway local database, and it belongs in `.gitignore` before it is created, not after.

## Error messages and what they actually mean

| Symptom | Cause |
|---|---|
| `ORA-01017` | Wrong username or password. The tool stops here rather than reporting an empty application |
| `ORA-12154`, `ORA-12541` | The connect string or listener, not APEX. Check host, port, service name |
| `ORA-28001` | Password expired. Common on accounts created for a one off export |
| "Application N is not visible to this user" | Almost always the missing workspace association above, not a wrong application id |
| "APEX_RELEASE returned nothing" | No APEX in this database, or the user cannot see the public synonym. Check `select * from apex_release` by hand |
| The run hangs | Something is prompting. The tool sets `define off` and `scan off` before connecting for exactly this reason, so if it still hangs, capture with `--capture` and read the output |

## Version differences that matter

The tool asks the catalog which columns exist and selects the intersection, so it does not carry a
version table. What changes across versions is coverage, and every gap is written into the
"What could not be read" section of `INDEX.md`.

Roughly: Interactive Grid views (`APEX_APPL_PAGE_IG_COLUMNS`) arrived in 5.1, REST data source
views (`APEX_APPL_WEB_SRC_MODULES`) around 19.1, and `APEX_EXPORT` around 18.1. On APEX 5.0 and
earlier there is no `APEX_EXPORT` package, so `--raw` will not work and the dictionary views are
the only path. That is fine: they are the primary source anyway.

Do not trust that list over the export's own output. The manifest records what was actually found.

## Capture and replay

`--capture <dir>` saves the raw client output. `--from-capture <dir>` re-renders from it with no
database.

Two uses. A capture from a customer site can be re-rendered locally when the rendering is wrong,
without asking for access again. And a capture is what `tests/test-apex-export.sh` runs against,
which is why the renderer is pure and lives in a separate file from the connection handling.

A capture contains the application's SQL and PL/SQL verbatim, before redaction. Treat it as
sensitive: it is the one artifact here that has not been through the credential scrubber.
