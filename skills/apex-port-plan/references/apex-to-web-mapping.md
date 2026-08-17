# What each APEX mechanic becomes, and the four that become nothing

Written for a React or Next.js target with an API layer. The names differ for other stacks; the
shape of the problem does not.

## The decision that comes before the mapping

**Does the database move?**

Three answers, and the assessment has to pick one before any page can be scoped:

| Choice | What it means | When it is right |
|---|---|---|
| Keep Oracle, wrap the PL/SQL | New front end calls an API that calls the existing packages | The logic is large, correct, and audited. Fastest to a working product, and it is reversible |
| Keep Oracle, rewrite the logic | New front end, new service layer, same tables | The PL/SQL is the problem, the schema is fine |
| Move the database too | Everything is rebuilt | Licence cost is the driver, or the schema is the problem |

The first is the default recommendation for a working application, and it deserves to be stated as
a recommendation rather than assumed. It turns one migration into two smaller ones and it lets the
APEX application keep running beside the new one during the port. Say plainly when the third is
being chosen for licence reasons, because that is a commercial decision and not a technical one.

## The mapping

| APEX | Replacement | Note |
|---|---|---|
| Page | Route | One APEX page is often two routes: a list and a detail |
| Region with a SQL source | A data fetch plus a component | The SQL in `regions/*.sql` is the query, verbatim |
| Page item `P20_X` | A form field plus its state | The `&P20_X.` and `:P20_X` references across the export show where it is read |
| Application item | Session or global state | Check `shared/app_items/` for its protection level first |
| Computation | Derived value, computed where it is used | Most disappear |
| Validation | Server side check, plus a client mirror | The server one is not optional. APEX ran it on the server, and a browser only version is a downgrade in security, not a port |
| Page process | An API route, a server action, or a service call | Processing point (Before Header, After Submit) becomes ordering in the handler |
| Branch | A redirect in the handler | Conditional branches are conditional redirects |
| Dynamic Action | Event handler and component state | The largest single source of undocumented behaviour. Read `da_actions/*.js` |
| LOV | An endpoint, or an enum when static | Static LOVs become a constant. Dynamic ones need an endpoint with the same query |
| Classic Report | A table component | Mechanical |
| Chart | A charting library | Mechanical. The query is the work |
| Form region | A form with a fetch and a submit | APEX generated the DML; the new code writes it |
| Authorization scheme | Middleware, plus a check at the data layer | See below, this is where ports get this wrong |
| Authentication scheme | The identity provider | `shared/authentication/` names the current one |
| Build option set to Exclude | A feature flag, or deletion | Code that ships and never runs. Usually deletion |
| `APEX_MAIL` | The mail service | |
| `apex_web_service.make_rest_request` | A server side fetch | Never move an outbound call with credentials into the browser |
| `apex_application_temp_files`, `wwv_flow_files` | Object storage plus an upload endpoint | |
| Theme, templates, `CSS_INLINE` | The design system | Not portable, and not worth porting. This is the part that should look different |
| Translations | The i18n layer | |
| Automations and scheduled jobs | A queue or a cron worker | Not in this export. Ask, they are easy to forget |
| `:APP_USER` | The session user | |
| `apex_error` | The error handling convention | |

## The four with no equivalent

Do not let these be scoped as translation work.

**Interactive Grid.** Inline editing, add and delete rows, a client side model, saved reports, and
generated DML with lost update detection. Rebuilding it properly is a component project. Rebuilding
it badly produces silent data loss when two people edit the same row, which is the exact thing APEX
was handling for you.

**Interactive Report, when its features are actually used.** A filterable table is a day. User
saved reports, computations, aggregates, highlighting, control breaks, and download are a product
feature. Check which are in use before scoping either way: many Interactive Reports in the wild are
plain tables and port in an afternoon.

**Server side session state.** APEX keeps every page item server side, so a value set on page 10 is
readable on page 20 without either page knowing about the other. Ported naively this becomes global
client state and then a bug. Find the cross page reads first: grep the export for each item name and
see which other pages mention it.

**Declarative session state protection.** Page access protection, item protection levels, and URL
checksums are APEX preventing parameter tampering for you. The new application has no equivalent
switch, and the replacement is authorization enforced at the data layer on every request, not URL
signing. A page listed as `Arguments Must Have Checksum` in the inventory is a page whose ids were
never trustworthy from the URL, and that assumption has to be rebuilt deliberately.

## Two things the export cannot tell you

**Which pages anyone uses.** The application has an activity log: `APEX_WORKSPACE_ACTIVITY_LOG`
holds page views, typically for a few weeks. Ask for a query against it before scoping every page
equally. It is common to find a third of an application unused, and that is the cheapest scope
reduction available.

**What the users actually need.** A port is the one chance to not rebuild the parts that were
wrong. The page inventory is what exists, not what is wanted, and treating it as the requirement
is how a port becomes a slower copy of the thing it replaced.
