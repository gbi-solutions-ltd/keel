# Standards document template

The structure of `<docs_root>/standards.md`. This file holds **only** what a tool cannot check.

## Header

```markdown
# Coding standards: <project>

| | |
|---|---|
| Derived from | N files sampled across <areas>, at commit `<sha>` |
| Date | YYYY-MM-DD |
| Enforced by | `<the check-only lint command>` |
| Departures from the house defaults | listed in the last section |

> Anything a linter can check is not in this file, by design. If you find a formatting rule
> here, move it into the tooling and delete it.
```

The `Enforced by` row matters: a reader needs to know which rules are checked for them and which
they must remember.

## Per-entry shape

```markdown
### Controllers hold no business logic

**Rule:** a controller validates input, calls one service method, and maps the result to a
response. No conditionals on domain state.

**Why:** the logic then has no test that does not go through HTTP, which makes it slow to test
and impossible to reuse.

**Example, from this codebase:** `PayoutController.java:48` delegates to `PayoutService`
immediately. Compare `LegacyController.java:51`, which builds an auth header inline; that is the
pattern being moved away from.
```

Rule, reason, example from this codebase. All three. A rule without a reason gets relitigated, a
rule without an example gets misread, and a rule with an invented example gets ignored once
someone checks.

## Sections worth having

Only include a section where this project has something real to say.

| Section | Covers |
|---|---|
| Structure | What belongs in each layer, and what may not depend on what |
| Naming | Only where it needs judgement, such as what counts as a service versus a helper |
| Error handling | What is caught, what propagates, what the caller sees |
| Logging | What is logged at which level, and what must never be logged |
| Testing | What gets a unit test versus an integration test, and what may be mocked |
| Data access | Where queries live, transaction boundaries, who owns which table |
| Configuration | Where values come from, what is required, what may have a default |
| Dependencies | When adding one is acceptable, and who decides |
| Documentation | What a comment must explain rather than restate, and which surface carries a doc comment where the linter cannot yet require one |

## Recording an inconsistency you did not fix

```markdown
### Known inconsistency: package naming

`Dao`, `Models`, and `Services` are capitalised, against Java convention, and `accountDao` is
lower case. 54 of 54 files follow this, so it is the convention here, not drift.

**Do not fix piecemeal.** Renaming touches every import and gains nothing. Match it.
```

This is often the most useful section, because it stops a well-meaning contributor "fixing" a
consistent oddity into an inconsistency.

## Departures from the house defaults

```markdown
## Departures from the house defaults

| Default | This project | Why |
|---|---|---|
| Strict type checking on | `strictNullChecks` off | Inherited. Being turned on per directory; see ADR-0009 |
| Check-only lint command exists | `lint` runs `--fix` | Not yet split. Tracked in story S-21 |
```

Every departure is either temporary with a tracking reference, or permanent with an ADR. A
departure with neither is drift that has been written down, which is worse than undocumented
drift because it looks sanctioned.
