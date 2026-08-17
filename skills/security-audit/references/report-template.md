# Audit report template

The structure of `<docs_root>/audits/YYYY-MM-DD-security.md`.

## Header

```markdown
# Security audit: <scope>

| | |
|---|---|
| Commit | `<sha>` on branch `<branch>` |
| Default branch | `<name>`, and whether it matches |
| Scope | `--diff` or `--full`, and which phases ran |
| Date | YYYY-MM-DD |
| Findings | 3 critical, 2 high, 4 medium, 1 low |
| Not covered | Named explicitly. See the last section |
```

The `Default branch` row is here because a service can be remediated on a working branch while its
default branch still carries the vulnerability. That has happened.

## Finding shape

```markdown
### C-01 Every credential ships inside the container image

| | |
|---|---|
| Severity | Critical |
| Confidence | Confirmed |
| Location | `Dockerfile:40`, `.dockerignore:50` |
| Phase | 1, secrets |

**What.** `setup_prod_env.sh` writes real credentials into `.env` at CI build time.
`.dockerignore` deliberately does not exclude it, and `Dockerfile:40` copies `.env*` into the
image, which is pushed with a commit tag and `latest`.

**Exploit.** Anyone with pull access to the registry runs `docker create` against the tag,
`docker cp` the `.env` out, and holds the production database password, the partner client
secret, and the signing keystore password. No exploitation of the application is required.

**Verified by.** `unzip -l` on the built artifact lists the files. Not inferred from the Dockerfile.

**Blast radius.** Every environment sharing those credentials. Rotation is required, not just a
code fix, because the secrets are already in every pulled copy.

**Fix.** Inject at runtime. Then rotate everything that has appeared in a pushed tag.
```

Every finding carries: severity, confidence, location, what, exploit, how it was verified, blast
radius, and fix. Missing the exploit makes it an opinion; missing the verification makes it a
guess.

## Confidence

| Value | Means |
|---|---|
| `Confirmed` | You reproduced it or read the decisive lines yourself |
| `Probable` | The code says so, but you could not execute the path |
| `Worth checking` | A lead. **Goes in its own section, never in the findings list** |

Keeping leads out of the findings list is what stops a report reading as forty problems when it has
three.

## Severity

Rank by exploitability multiplied by impact, not by a scanner's label.

| Severity | Test |
|---|---|
| Critical | Exploitable now, by someone who plausibly has the access, with serious consequence |
| High | Exploitable with a precondition that is likely to hold |
| Medium | Real, but needs an unlikely precondition or has limited consequence |
| Low | A weakened control with no direct path to harm |

An unauthenticated default branch is Critical, not High, even if nobody currently deploys from it,
because nothing prevents it.

## Sections

1. Summary, three sentences and the counts
2. Findings, ordered by severity
3. Worth checking, the unverified leads
4. Positive observations, controls that are genuinely good
5. **Not covered**, explicit
6. Trend, if a previous audit exists: what closed, what is new, what has been open longest

Section 4 is not politeness. Naming what is well built stops the report reading as a list of
failures and tells the team which controls to keep when they refactor.

## Not covered

```markdown
## Not covered

- No dynamic testing. Nothing was executed against a running instance.
- Dependency advisories not checked; `npm audit` was not run.
- The frontend workspace was out of scope.
- Business logic beyond the payments checklist was not reviewed.
```

An audit that implies completeness it does not have is worse than a narrow one, because it stops
the next person looking.
