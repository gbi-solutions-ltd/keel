# Port assessment template

Write `<docs_root>/apex/APP-<id>/PORT-ASSESSMENT.md` with these sections, in this order. Drop a
section only when the export genuinely has nothing for it, and say so rather than removing it
silently.

Every claim cites a path inside the export. A claim that cannot cite one is written as `Unknown`.

---

## 1. What this application is

Three to six sentences. What it does, who uses it, what it owns. Written for someone who has never
opened it and has to decide whether to fund the port.

## 2. Recommendation

One of: keep Oracle and wrap the PL/SQL, keep Oracle and rewrite the logic, or move the database
too. State it in the first sentence, then the reasoning, then what would change your mind.

A recommendation with no stated way to be wrong is not a recommendation, it is a preference.

## 3. Scope

| | Count | Source |
|---|---|---|
| Pages | | `INDEX.md` |
| Of which low, medium, high, rewrite | | `INDEX.md` |
| Tables written by the application | | agent A |
| PL/SQL packages | | `db/plsql/` |
| Distinct authorization schemes | | `shared/authorization/` |
| Outbound integrations | | agent E |

## 4. Data model

The entity list with keys and relationships. Which tables the application writes and which it only
reads, because a read only table may not need to move at all.

**Objects referenced but not readable.** Every name in `xref.tsv` with no file under `db/tables/`
or `db/plsql/`. Each is unscoped work. List them; do not summarise the count.

## 5. Business logic

Per package: what it does, which pages call it, and keep behind an API or rewrite. Name every
package that does DML across several tables in one call: that is a transaction boundary the new
stack has to reproduce, and it is the most common source of a port that corrupts data quietly.

## 6. Route map

Page id, current purpose, proposed route, band, and whether the band was revised from `INDEX.md`.

Revised bands carry the reason inline. An unrevised band was still a judgement someone made.

## 7. Authentication and authorization

The current mechanism and the proposed one. Every distinct authorization scheme and which pages
use it. **Every page with no scheme and no page access protection is listed by id**, because that
is either a public page or an existing hole, and the port is when it gets decided which.

## 8. What should not be ported

The section that pays for the exercise. Candidates:

- Pages behind a build option set to Exclude
- Pages unused in `APEX_WORKSPACE_ACTIVITY_LOG`, when that query was run
- Navigation only pages that a router makes unnecessary
- Features the users stopped needing

If nothing is here, say that it was looked for and nothing was found. An empty section reads as an
omission.

## 9. Risks

Each risk names what breaks, not a category. "Session state is read across pages 10, 20, and 40,
and a naive port turns that into global client state" is a risk. "Complexity" is not.

Start from the four mechanics with no equivalent, then agent F's gaps, then anything in
`REDACTIONS.md`.

## 10. What this assessment does not know

The export's "What could not be read" section, verbatim, plus anything the agents marked `Unknown`.

This section is not a disclaimer. It is the list of questions to answer before anyone commits to a
date, and it should be the first thing read after the recommendation.

---

## Rules for the whole document

**No hours, no story points, no ranges of either.** The bands rank pages against each other. The
moment a number that looks like an estimate appears in this document it will be quoted as one, and
it will have been derived from counting page items.

**Cite paths, not summaries.** `pages/00020-merchant-detail/processes/01-save-merchant.process_source.plsql`
is checkable. "The save process is complex" is not.

**Name the pages, do not count them.** A count of 14 high pages is unactionable. Fourteen page ids
can be assigned, split, or argued about.
