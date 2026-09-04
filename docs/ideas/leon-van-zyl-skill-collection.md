# Idea: augment keel from the Leon van Zyl skill collection

| | |
|---|---|
| Raised by | Bernard, 2026-08-31 |
| Status | **built 2026-08-31**, by [`docs/plans/2026-08-31-release-operations-and-claims-audit.md`](../plans/2026-08-31-release-operations-and-claims-audit.md). The import stayed blocked and was never pursued: the collection carries no licence grant, so nothing in it was copied or adapted, and waiting on one was not worth the delay. keel filled the five gaps this assessment found from its own practice instead, in keel's own words, with no `SOURCES.md` row, no `THIRD-PARTY-LICENSES.md` entry and no adaptation of the collection. The Recommendation row below is superseded by that decision and kept as the record of what was assessed, not as live advice |
| Recommendation | **Closed permanently, 2026-08-31.** No licence can be obtained for this collection (decided by Bernard, 2026-08-31), so the conditional below can never become live and is kept only as the record of what was assessed. As assessed: take nothing, because the collection carries no licence at all, which is a harder blocker than any of its technical costs; had a licence been obtained, four reference files into three existing skills, costing zero description budget, and no new skill |
| Next | Two new reference files and four rules landed on 2026-08-31 and are recorded in `CHANGELOG.md` under Unreleased. One thing is open, and it is the only one: none of the new content has a behavioural eval arm, which the changelog states as a limitation rather than a footnote. One thing is closed, permanently: the import, because no licence can be obtained for the collection (decided by Bernard, 2026-08-31), so the Recommendation row can never become live |

**A note on the quotations below.** `tests/validate-skills.sh:171-172` fails any file under
`docs/` containing an em or en dash, and 1,061 em dashes appear across 46 of the collection's 48
files. Every quotation here has had its em dashes replaced with a comma, a full stop or brackets.
The words are otherwise verbatim. Nothing else has been changed.

---

## 1. The budget

`tests/run-tests.sh` was run in full on 2026-08-31 against `sandbox` at `e60dcee`. It passed. Its
`validate-skills.sh` section, quoted exactly:

```
== tests/validate-skills.sh (against this repo) (4s)
WARN  execute-plan: body is 884 words, 16 from the 900 ceiling and over the 700 target. Adding a sentence fails the suite: take the words out of this body, or move a section a reader needs at one step into references/. ADR-0001 requires a passing eval arm at this length.
WARN  tdd: body is 793 words, over the 700 target (ceiling 900). ADR-0001 requires a passing eval arm at this length.
WARN  write-docs: body is 738 words, over the 700 target (ceiling 900). ADR-0001 requires a passing eval arm at this length.
WARN  write-plan: body is 897 words, 3 from the 900 ceiling and over the 700 target. Adding a sentence fails the suite: take the words out of this body, or move a section a reader needs at one step into references/. ADR-0001 requires a passing eval arm at this length.
WARN  write-prd: body is 793 words, over the 700 target (ceiling 900). ADR-0001 requires a passing eval arm at this length.
OK    25 skills validated, descriptions about 1121 tokens, 5 warning(s)
```

The rest of the run: `test-keel.sh` and the other suites all green, `no-internal-leaks.sh` clean,
`supply-chain-scan.sh` clean at 19 rules with 6 honoured suppressions, and
`SKIP  shellcheck is absent locally. CI will run it: install it to see what CI sees.`
Lint was therefore not run here. That is the standing local state and not a new gap.

**The numbers.**

| | Value | Source |
|---|---|---|
| Sum of skill descriptions, when this was written | **about 1,121 tokens**, about 1,130 today (4,037 characters over 25 skills) | the `OK` line above |
| Ceiling | **1,320 tokens** | `DESC_TOTAL_MAX_TOKENS=1320`, `tests/validate-skills.sh:54` |
| Headroom | **199 tokens** | 1320 minus 1121 |
| Measured mean per description | **44.84 tokens** (161 characters) | 4,037 / 25, taken from the same run |
| Per-skill ceiling | **216 characters**, about 60 tokens | `DESC_MAX_CHARS=216`, `tests/validate-skills.sh:39` |

**How many new skills the headroom actually buys.** 199 divided by 44.84 is 4.4, so **four**, and
the fifth fails the build. Checked arithmetically against the estimator the validator uses
(`desc_chars * 10 / 36`, `tests/validate-skills.sh:156`):

- Four skills at the measured mean: 4,037 + 644 = 4,681 chars, **1,300 tokens**. Passes, with 20
  tokens left over.
- Five at the mean: 4,842 chars, **1,345 tokens**. Fails.
- Three at the legal per-skill ceiling of 216 chars: 4,685 chars, **1,301 tokens**. Passes.
- **Four at the per-skill ceiling: 4,901 chars, 1,361 tokens. Fails.** So "four" is only true if
  each new description is written at or under the current mean. A skill with a wide trigger
  surface, which every candidate here has, will not be.

The honest number to plan against is therefore **three, comfortably, or four if each is unusually
narrow**. That is the whole budget, forever, until something is removed.

**What decision 6 says the remedy is when the ceiling is reached.**
`docs/07-open-decisions.md:339-345`:

> **Since 2026-08-16 that revisit has a trigger rather than a good intention.** Plan task 7.5 caps
> the descriptions sum at 1,320 tokens in `tests/validate-skills.sh`, which is 30 skills at the
> measured 44-token mean, so the count reaching the number this decision named is now a failing
> build. **The check's own message says the remedy is fewer skills, because "how short can a
> description be" is the answer this decision already rejected.**

And earlier in the same decision, at `docs/07-open-decisions.md:335`: **"Revisit before 30, not
after, and revisit it as 'which of these should merge', not 'how short can a description be'."**

The check's own failure text, `tests/validate-skills.sh:158`, says the same thing to whoever
breaks it: *"The remedy is fewer skills, not shorter descriptions."*
[`docs/05-token-and-memory-design.md`](../05-token-and-memory-design.md), lines 112 to 118, gives
the reason: *"A description trimmed below the point where it states when to use the skill costs
more in bad routing than it saves."*

**Every recommendation in section 7 is costed against 199 tokens.** A reference file costs zero of
it. A new skill costs about 45. That asymmetry decides the whole answer.

---

## 2. The size problem

ADR-0001 ([`docs/decisions/ADR-0001-skill-body-word-ceiling.md`](../decisions/ADR-0001-skill-body-word-ceiling.md))
sets the hard ceiling at 900 words with 700 enforced as a warning. Body word counts here exclude
YAML frontmatter, matching `body_of()` at `tests/validate-skills.sh:85`.

| Skill | Body words | Ratio to the 900 ceiling | Ratio to the 700 target |
|---|---|---|---|
| `start-an-app/SKILL.md` | **7,891** | **8.77x** | 11.27x |
| `deploy-an-app/SKILL.md` | **2,554** | **2.84x** | 3.65x |
| `review-an-app/SKILL.md` | **1,815** | **2.02x** | 2.59x |
| `create-brand-kit/SKILL.md` | **1,585** | **1.76x** | 2.26x |

The four bodies together are 13,845 words. keel's largest body is `write-plan` at 897, and the
whole collection's smallest body is still 1.76 times keel's hard ceiling.

**What that mechanically implies about wholesale import: it is not possible.** Not "inadvisable".
`tests/validate-skills.sh:122-123` emits `FAIL` and increments `errors` on any body over 900,
`tests/run-tests.sh` fails on a non-zero exit, and CI runs that suite. Copying any one of these
four `SKILL.md` files into `skills/` turns the build red on the same commit. There is no flag and
no warning tier above the ceiling.

`start-an-app` is the extreme case and it is worth stating separately: at 7,891 words it would have
to lose **87 percent** of its body to become a legal keel skill. What survives that cut is not an
adaptation of the file, it is a different file that happens to share a topic. ADR-0001's own
context section already establishes that the relief valve, moving substance into `references/`,
has a floor: `coding-standards` sits at 795 words with 17 references carrying 22,752 words. Moving
material out does not pull a body below roughly 680, so "put the other 7,200 words in references"
does not rescue this either; it produces a body that still has to be written from scratch.

The reference files themselves are a different matter, and are treated per file in section 4. Those
are unbounded in length by design (`tests/validate-skills.sh:160-161`: *"References are unbounded
in length but not in what they may contain"*).

---

## 3. create-skill Step 0

[`skills/create-skill/SKILL.md:16`](../../skills/create-skill/SKILL.md) requires this before
anything else: *"Ask whether an existing skill already covers this. Overlapping skills are worse
than a missing one: the router picks arbitrarily and neither gets improved."*

Bodies were read, not descriptions. Where a cell says "covered", the covering line is quoted.

| The job | Which keel skill claims it | Which keel skill body actually does it | Verdict |
|---|---|---|---|
| Whole-repo security review against OWASP Top 10 | `security-audit`: *"Use when about to ship, asked whether something is secure or needs a vulnerability check, or when working on authentication, payments, personal data, secrets, or external input"* | Yes, and more deeply. `security-audit/SKILL.md:40-41` runs *"OWASP Top 10 against the diff or the repo"* via a 1,990 word `owasp-checklist.md` with 15 sections. `SKILL.md:21` already has a `--full` scope for *"New engagement, monthly, or after an incident"* | **covered** |
| Requiring a proven exploit path per finding | `security-audit` | `security-audit/SKILL.md:13-14`: *"every finding needs a concrete exploit and a `file:line`. A report of forty maybes gets ignored; three real ones get fixed."* And `:54-56`: *"state the exploit as a sequence someone could follow. If you cannot say who does what and what they get, it does not go in the report."* | **covered** |
| Naming what was not checked | `security-audit` | `security-audit/SKILL.md:66-67`: *"Say plainly what you did not cover. An audit that implies completeness it does not have is worse than a narrow one."* | **covered** |
| Reviewing a whole app rather than a diff | `review-an-app` vs `review-code` and `security-audit` | `review-code/SKILL.md:18` is diff-scoped: *"Read the diff, and read the plan or story it claims to implement."* `security-audit` `--full` covers the repo-wide case | **router collision.** `review-an-app`'s description explicitly claims *"a whole codebase rather than a diff"*, which is the exact seam between the two skills that already exist. Three skills would then answer "review this app" |
| Independent parallel reviewers over one shared evidence pack | nobody claims it as a job | `security-audit/SKILL.md:46-48` does it: *"Delegate phases to parallel subagents on a `--full` run, one per phase, model `sonnet`"*. It does not have the evidence-pack isolation rule | **covered in mechanism, gap in one rule.** The rule at `review-an-app/SKILL.md:53`, that a lens sees only its own brief because *"three agreeing agents read as corroboration when they are only an echo"*, has no keel equivalent |
| SEO, sitemap, `robots.txt`, `llms.txt`, structured data | **nobody** | **nobody.** `grep -rln "sitemap\|robots.txt\|llms.txt\|SEO" skills/` returns no files | **genuine gap** |
| Documentation and marketing claims that the code no longer keeps | `write-docs`, weakly | `write-docs/SKILL.md:33` warns prose *"goes stale silently"* and `:90` and `:101` require a date and a commit so staleness is judgeable. `review-code/SKILL.md:83` gates on it: *"Passing a behaviour change with stale docs \| Documentation is part of the gate, not a follow-up"*. **None of them audits an existing app's claims against its code** | **genuine gap**, narrow. keel prevents new drift and does not detect existing drift |
| Setting up CI, containers, environments, rollback | `setup-deployment`: *"Use when a project has no pipeline, when asked to add CI, containerise a service, set up environments, or when an existing deployment needs fixing or documenting"* | Yes, thoroughly. `setup-deployment/SKILL.md:38-49` builds the stage order and the four non-negotiables; `:81-86` writes the runbook and requires *"Then execute the rollback once, by hand. An untested rollback is a hope."* | **covered** |
| Performing one deploy of one app to one PaaS | `deploy-an-app` vs `setup-deployment` | `setup-deployment` builds the *path*; it never performs a deploy. `ship/SKILL.md:79` hands off: *"Name `setup-deployment` if there is no pipeline to run this"* | **router collision.** Both would answer "deploy this". The seam is real (build a pipeline vs drive a vendor CLI once) but neither description states it, which is the failure `create-skill` Step 0 names |
| A ledger of provisioned cloud resources and how to remove them | nobody | nobody. `setup-deployment` Step 6 covers *"what differs, where secrets come from, who can deploy"* and `pipeline-patterns.md:126-131` covers rollback of a **deploy**. Neither covers rollback of a **provisioning run** | **genuine gap** |
| Classifying every environment variable before writing it | `setup-deployment` claims environments | `setup-deployment/SKILL.md:75` asks *"where secrets come from"*; `pipeline-patterns.md:120-124` says secrets are *"Injected at runtime, from the platform's secret store"*. There is no per-variable method and no denylist of values that deploy successfully and break the app | **genuine gap**, narrow |
| Verifying the deployed thing against its live URL | `setup-deployment` | The word "smoke test" appears once, `setup-deployment/SKILL.md:39`, as the last stage name. Nothing says what a smoke test checks | **genuine gap**, narrow |
| Interviewing a user to establish what to build | `start-an-app` vs the `shape-idea` chain | `shape-idea/SKILL.md:22-34` finds the problem under the solution and will refuse: *"If nobody can name a specific recent instance, that is the finding."* Then `write-prd`, `write-user-stories`, `design-architecture`, `write-plan`, `execute-plan` | **covered, and the collision is severe.** `start-an-app` collapses five keel skills into one, and it starts at the scaffold rather than at the problem |
| Scaffolding a new project with the SOP layer | `start-an-app` vs `keel new` | `bin/keel:1232-1300`. `keel new` creates the repo, the profile, the CLAUDE.md block, a passing sample test, CI and `NEXT-STEPS.md`, whose first line is *"Start here, not with code"* and which routes to `write-prd` before implementation (`bin/keel:1284-1291`) | **covered.** Two scaffolders that disagree about what comes first is worse than one |
| Choosing a stack | `design-architecture`: *"choosing a stack or datastore though not its schema"*. Body at `SKILL.md:38-41` requires two or three approaches, then *"recommend one and say why the others lost"* | Yes | **covered, and directly contradicted.** `start-an-app/SKILL.md:22`: *"The stack is fixed: Next.js, TypeScript, Tailwind, shadcn/ui, Drizzle, Better Auth."* `design-architecture/SKILL.md:14-15`: *"never present one option. A decision with no stated alternative is a preference wearing a decision's clothes."* |
| Brand identity: logomark, wordmark, favicon, icon set | nobody | nobody. `coding-standards/references/frontend.md` covers design **tokens** and theming (*"if the brand colour changes, how many files change?"*, `:28`) and nothing about producing a brand | **genuine gap, and out of scope.** keel is an engineering SOP. Producing a logo is a design deliverable, not a delivery process |

**Summary of Step 0.** Two router collisions that would degrade skills that already work
(`review-an-app`, `deploy-an-app`), one collision severe enough to break the artifact chain
(`start-an-app`), one out-of-scope gap (`create-brand-kit`), and **five narrow genuine gaps**: SEO
and discoverability, claim-versus-code drift, a provisioning ledger, environment variable
classification, and live-URL verification. All five are reference-shaped, not skill-shaped. That is
section 7.

---

## 4. Per-file disposition

All 48 content files plus the one incidental file, so nothing is left without a disposition.

**On the count.** The brief says 45 files and about 478KB. The tree holds **48 content files plus
one `.DS_Store`**, totalling 481,591 bytes, or 489,787 bytes including `.DS_Store`, which is 478.3
KB and is where that figure comes from. The three extra files are not identified; the count is
stated here so the difference is visible rather than silently reconciled.

**Stack-boundedness** is the sum of case-insensitive matches for the eight named terms, using
`next\.js|nextjs`, `vercel`, `drizzle`, `better[- ]auth`, `resend`, `inngest`, `stripe`, `polar`.
It **understates** coupling in several files: `evidence.md` scores 0 while running `pnpm build` over
`src/app/**/page.tsx`, and `wire-auth.md` scores 0 while configuring Better Auth without naming it.
Where that happens the note says so.

### `start-an-app`, 18 files

| Path | Contents | Stack | Disposition |
|---|---|---|---|
| `skills/start-an-app/SKILL.md` | 8-step orchestrator: interview, research, build sheet, scaffold, personalise, verify, critic, hand-off | **40** | **reject.** 7,891 word body, 8.8x the ceiling; `:22` fixes the stack, which contradicts `design-architecture`; `:33` bans all version pinning, which contradicts `setup-deployment`. The job is covered by `keel new` plus the `shape-idea` chain |
| `references/stack.md` | Creates the Next.js/TypeScript/Tailwind/shadcn project in the cwd | 3 (plus shadcn 8, tailwind 3) | **reject.** Pure vendor scaffolding. One portable idea at `:34` (resolve collisions deliberately rather than letting `mv` decide) is already covered by `bin/keel:1241-1246`, which refuses to write into a non-empty directory |
| `references/database.md` | Drizzle setup, SQLite and Postgres branches, migration workflow | **33** | **reject.** Two rules are good and already keel's: generate-then-read-then-apply rather than `push` (`:143`, `:152`) is `design-database`'s territory, and `:78` deliberately leaves the Postgres image tag unpinned, which contradicts `setup-deployment/SKILL.md:53` |
| `references/auth.md` | Better Auth email and Google OAuth on Drizzle | **27** | **reject.** Vendor wiring end to end |
| `references/email.md` | Resend transactional email, log-first send wrapper, React Email | **59** | **reject** as a file. One idea worth stealing and rewriting: `:234` avoids a timing oracle by not awaiting the send. **Already covered** by `security-audit/references/owasp-checklist.md`, section "Identification and authentication failures" |
| `references/payments.md` | Polar and Stripe through Better Auth plugins | **103**, the highest in the tree | **reject.** `:7` mandates one vendor path *"Always... without exception"*. `security-audit/references/payments-checklist.md` owns this domain for keel and is vendor-neutral |
| `references/jobs.md` | Inngest durable step functions, app-owned `jobs` table | **58** | **reject** as a file. The architectural rule at `:7`, keep your own record rather than trusting a provider's retention, is genuinely portable and is a **seed for a paragraph in `design-architecture`**, not for a skill or a file |
| `references/storage.md` | Uploads, local folder in dev and Vercel Blob in production | **13** | **reject.** `:9` (switch on credential presence, not a mode flag) is a nice pattern with no home in keel |
| `references/mcp.md` | Full MCP server over Better Auth's OAuth plugin, 5,611 words | **32** | **reject** as a file. `:7` (*"every tool takes the user from the token and scopes every query to them. Never trust an id the model passed you"*) is real and general. **Already covered**: `security-audit/references/owasp-checklist.md:6-29`, "Broken access control", opens *"The most common serious finding, and the one scanners miss entirely"* and asks whether authorisation is enforced by default |
| `references/ai.md` | Vercel AI SDK plus OpenRouter chat route, 342 words | 0 (openrouter 14) | **reject.** Vendor wiring |
| `references/pages.md` | Landing page and dashboard decision, built to `DESIGN.md` | 1 | **reject** as a file. Two rules are keel-shaped and **already covered**: `:47` bans fabricated testimonials and logos, and `:79` says middleware is not the security boundary, which is `owasp-checklist.md:6-29` again |
| `references/design.md` | Turns the interview answer into `DESIGN.md` and theme tokens | 5 | **reject.** `coding-standards/references/frontend.md:26-43` already owns theming, and owns it better: *"if the brand colour changes, how many files change?"* plus a lint rule banning hex colours outside the token file. Also carries the collection's only `@` link, `:154-156` |
| `references/settings.md` | Account settings area on Better Auth's API | 17 | **reject** as a file. `:53` (`input: false` on `role`, or a user sets their own to admin) is a clean mass-assignment example. **Already covered** by `owasp-checklist.md` "Broken access control" |
| `references/ops.md` | In-app `/settings/system` page: integration health, activity log | 16 | **reject** as a file. `:9` (never render a secret or part of one, not even a masked tail) and `:100` (log the app's verbs, never a full payload) are **already covered** by `coding-standards/references/observability.md` and `owasp-checklist.md:154-181`, "Personal data, beyond what reaches a log" |
| `references/legal.md` | Decision table for privacy policy, terms, cookie banner | 12 | **reject** as a file, and note the reason. `:7` (*"never write a legal claim the code cannot keep"*) is the drift idea again and is picked up under `drift.md`. The rest is jurisdictional guidance, and `coding-standards/references/data-protection.md:8` already draws keel's line: *"This is a set of engineering defaults, not legal advice"* |
| `references/seo.md` | Builds sitemap, robots.txt, llms.txt, OG image, structured data from one list | 0 | **seed for a reference**, second choice behind `review-an-app/references/seo.md`. This one builds; the other one audits, and auditing is the keel-shaped job. `:26` and `:50` (one list, three consumers, or they drift within a week) is the reusable part |
| `references/docs.md` | A 4 to 6 page in-app MDX documentation section | 2 | **reject.** `:9` (every page documents something a person can do today) is worth one line in `write-docs`; the rest is a Next.js MDX build |
| `references/verify.md` | Ten-check closing gate plus a four-lens critic review, 5,544 words | 8 | **reject, with the reason recorded.** `:7` (*"the gate is passed by fixing the code, never by widening the gate"*) is excellent and is **already covered** by `ship/SKILL.md:34-35`: *"Do not fix it as part of shipping: a gate that repairs its own failures is not a gate."* And `:277` puts *"tests, CI"* out of scope entirely, which is the direct contradiction named in section 5 |

### `deploy-an-app`, 14 files

| Path | Contents | Stack | Disposition |
|---|---|---|---|
| `skills/deploy-an-app/SKILL.md` | 11-step orchestrator from local app to live URL on Vercel | 4 | **reject.** 2,554 word body, 2.8x the ceiling, and a router collision with `setup-deployment` and `ship`. Its ten framing rules at `:19-30` are the valuable part and most are already keel's |
| `references/preflight.md` | Read-only discovery: CLI capability probe, stack detection, env manifest, git cleanliness | **12**, the highest in this skill | **reject** as a file. `:7` (*"nothing here mutates anything... Preflight that changes things cannot be re-run after a failure"*) is a good rule with a home in `setup-deployment` Step 1. `:118` (a dirty tree stops the pipeline) is **already covered** by `ship/SKILL.md:16-31`, whose whole shape is a gate that refuses |
| `references/project-and-url.md` | Settles the production URL and custom domain before anything else | 6 | **reject.** `:7` (read the URL back from the platform, never construct it) and `:59` (bare versus www splits the session cookie) are true and narrow |
| `references/provision-database.md` | Provisions the production database, SQLite to Postgres conversion | 2 | **reject.** `:78` admits its own best-value check applies real migrations to a real database, which keel would want gated rather than recommended |
| `references/provision-storage.md` | Creates and connects a blob store | 1 | **reject.** Vendor procedure |
| `references/env.md` | The seven-class method for resolving every environment variable to production, plus a denylist | 3 | **import as a reference into `setup-deployment`.** The strongest candidate in the tree. Fills the gap named in section 3. See section 7 for what survives |
| `references/recovery.md` | The provisioning ledger, the fail-closed policy, the retry taxonomy, check-then-create | **0**, the most stack-agnostic file in the collection | **import as a reference into `setup-deployment`.** Fills the second gap. Almost nothing has to change |
| `references/gate.md` | Nine-point post-deploy check against the live URL, plus a critic pass | 3 | **import as a reference into `setup-deployment`**, partially. The four-state vocabulary at `:15-18` and the live checks fill the third gap. The critic pass at `:139-186` duplicates `review-code` and is dropped. `:158` contradicts keel, see section 5 |
| `references/deploy.md` | The single deploy: mechanism, terminal state, commit equality | 5 | **already covered by `keel`'s `ship` and `setup-deployment`.** `:9` and `:75` are `ship/SKILL.md:20-31`; `:62` (do not retry a failed build unchanged) belongs to `recovery.md`'s taxonomy, which is being taken. `:38-44` contradicts keel, see section 5 |
| `references/wire-auth.md` | Production sign-in: origin, fresh signing secret, OAuth callbacks | **0** (never names Better Auth despite configuring it) | **already covered by `security-audit`.** `:7` (never weaken authentication to make something work) and `:15-21` (regenerate the signing secret, never copy the dev value) are `owasp-checklist.md:119-127`, "Security misconfiguration", and `:138-146` |
| `references/wire-email.md` | Verifies a sending domain, scoped production key | 1 | **reject.** `:45` (*"Delivery is not checkable"*) is a good honesty rule with no home |
| `references/wire-jobs.md` | Moves background jobs to production, sync after deploy | 2 | **reject.** `:7` (the development flag disables signature verification and must never reach production) is **already covered** by `setup-deployment/SKILL.md:36-37`, *"anything that fails open where it should fail closed"* |
| `references/wire-mcp.md` | Publishing an MCP endpoint: one canonical URL in four places | **0** | **reject.** Narrow and protocol-specific. `:9` (changing the value invalidates every issued token) is a fact, not a rule |
| `references/wire-payments.md` | Test mode by default, going live as a separate confirmation, webhook idempotency | 5 | **seed for an addition to `security-audit/references/payments-checklist.md`.** `:7` (going live is its own explicit confirmation), `:25-31` (list before creating, or every event is delivered twice) and `:61` (live prices cannot be deleted, read the values back first) are the go-live half of payments, which keel's checklist does not cover |

### `review-an-app`, 5 files

| Path | Contents | Stack | Disposition |
|---|---|---|---|
| `skills/review-an-app/SKILL.md` | Read-only whole-app review across three parallel lenses | 3 (all on `:30`) | **reject as a skill, mine for two rules.** 1,815 word body, 2.0x the ceiling, and the router collision named in section 3. `:53` (each lens gets its own brief and nothing else, or *"three agreeing agents read as corroboration when they are only an echo"*) is a **seed for one sentence in `security-audit` Step 2**, which already dispatches parallel subagents with no such rule. `:15` contradicts keel, see section 5 |
| `references/security.md` | OWASP Top 10 as it appears in a Next.js, Better Auth, Drizzle app | **9**, the highest in this skill | **already covered by `security-audit/references/owasp-checklist.md`.** keel's is 1,990 words across 15 sections and is both broader and vendor-neutral. One item is not covered: `:110-114`, verify a webhook against the **raw** body and return without touching the database on failure. That is a **seed for one bullet in `owasp-checklist.md`** |
| `references/evidence.md` | The shared evidence pack: route inventory, HTTP probe sweep, consented isolation probe, cleanup | 0 by regex, heavily Next.js-shaped in its commands (`pnpm build`, `src/app/**/page.tsx`, `POSTGRES_URL`) | **seed for `security-audit`, small.** `:13-17` (*"This is somebody's working app, not a scaffold... Never modify a file to make a check work"*) and `:71` (do not blind-probe a POST handler, *"it is a write to somebody's database"*) have no keel equivalent and matter on a client engagement. The rest is Next.js command scaffolding and is dropped |
| `references/drift.md` | Audits an app's own claims (landing page, docs, privacy policy) against its code | **0**, entirely stack-agnostic | **import as a reference into `write-docs`.** Fills the fourth gap. `:11` (a finding is a contradiction, never an absence) and `:13` (quote both halves, the claim and the file that fails to keep it) are the method, and it survives adaptation nearly intact |
| `references/seo.md` | Audits sitemap, robots.txt, llms.txt and metadata for accuracy, explicitly not for ranking | 1 | **import as a reference into `write-docs`**, merged with `drift.md` or beside it. Fills the fifth gap. `:11` (*"you are not an SEO consultant"*) is what makes it keel-shaped: it audits truthfulness, not marketing |

### `create-brand-kit`, 10 files

| Path | Contents | Stack | Disposition |
|---|---|---|---|
| `skills/create-brand-kit/SKILL.md` | Six-phase brand identity pipeline with parallel designer agents and adversarial review | 0 | **reject.** Out of keel's scope: a design deliverable, not a delivery process. 1,585 word body, 1.8x the ceiling. `:29-30` also asserts that its own prose is authorisation to call the Workflow tool, and `:36` defaults to 300k to 600k agent tokens with no cost gate |
| `references/deliverables.md` | Asset manifest, SVG contract, construction maths, Codex merch mockups | 0 | **reject.** `:78-80` (generate the guidelines page from the shipped assets so it cannot drift) is a genuinely good idea already present in keel at `write-docs/SKILL.md:33`, *"Prose restating what the code already declares goes stale silently. Prefer the generator."* `:141` also bakes in `--skip-git-repo-check`, routinely disabling another tool's trust check |
| `references/design.md` | Style routes, SVG construction rules, typography, the designer agent prompt | 0 | **reject.** Out of scope |
| `references/review.md` | 11-item kill list, 0 to 60 rubric, critic and judge prompts | 0 | **reject.** Out of scope. `:81-82` (select by ceiling score, not current score) is a nice triage idea with no home |
| `evals/evals.json` | Two eval cases with 13 and 8 machine-checkable assertions | 0 | **reject as content, note the format.** keel's own eval harness is prose scenarios scored by a human, deliberately: `tests/evals/README.md` says *"Scoring is deliberately human: the failures these catch are rhetorical, and a grep for 'I will write the test first' is trivially satisfied by an agent that then does not."* A JSON assertion suite is the thing that decision rejected |
| `scripts/context.mjs` | Renders a mark into six usage contexts as one PNG via headless Chrome | 0 | **reject.** Out of scope. Depends on a hardcoded Chrome binary path |
| `scripts/preview.mjs` | The render-and-look harness: dark, light, mono, size ladder, ink gain | 0 | **reject.** Out of scope |
| `scripts/sheet.mjs` | Contact sheet of every SVG in a directory at five sizes | 0 | **reject.** Out of scope |
| `scripts/optics.py` | Measures ink percentage, centroid and max radius from a rendered alpha channel | 0 | **reject.** Out of scope. Requires Pillow and Chrome |
| `scripts/outline.py` | fontTools: instantiate a variable font, apply kerning, emit SVG paths | 0 | **reject.** Out of scope. Requires fontTools and brotli |

### Root, 2 files

| Path | Contents | Stack | Disposition |
|---|---|---|---|
| `README.md` | Install instructions and a marketing overview of the four skills | 5 | **reject as content. Retain as the licence evidence**, since it is the only ownership statement in the tree and section 6 rests on it |
| `.DS_Store` | macOS Finder metadata, 8,196 bytes | 0 | **reject.** Not a content file. It is also the difference between 481,591 and the 489,787 bytes that give the brief's ~478KB |

---

## 5. The adaptation cost, stated before anything is built

### The mechanical costs, all measured

| Rule | Where keel enforces it | The collection's state |
|---|---|---|
| No em dash, no en dash | `tests/validate-skills.sh:171-172` for shipped content, `:203-204` for `docs/` | **1,061 em dashes across 46 of 48 files. 13 en dashes across 3 files.** Every imported file needs a full prose pass. This is not a find and replace: an em dash carries a clause break, and replacing it with a comma sometimes changes what the sentence says |
| Description states triggers only | `tests/validate-skills.sh:104-107` requires the literal prefix `Use when` | **None of the four starts with it.** All four state the workflow first and the trigger second: `deploy-an-app` opens *"Take a Next.js app that runs on the user's machine and put it into production on Vercel"*; `review-an-app` opens *"Review a web app that already exists and report what is actually wrong with it"* |
| Description under 216 characters | `tests/validate-skills.sh:39, 109` | **1,036, 902, 901 and 850 characters.** Between 3.9x and 4.8x the ceiling. Each has to be rewritten from nothing, not trimmed |
| Body under 900 words | `tests/validate-skills.sh:122-123` | 1.8x to 8.8x. Section 2 |
| No `@` links | `tests/validate-skills.sh:130-132` | One instance, `start-an-app/references/design.md:154-156`, inside a `CLAUDE.md` template the skill writes. **Note the check is scoped to `SKILL.md` bodies**, so an `@` inside a reference passes today. That is a hole worth knowing about independently of this assessment |
| `<docs_root>` notation, never a literal path | `tests/validate-skills.sh:135-138` | Zero `docs/keel` hits, but the reverse problem applies: the collection writes to fixed repository-root paths (`DESIGN.md`, `AGENTS.md`, `BRIEF.md`, `brand/LAW.md`). keel skills resolve every artifact path from `profile.docs_root` and `profile.artifacts` |
| Relative links resolve | `tests/validate-skills.sh:149-153`, `:177-182` | Not yet a defect. It becomes one the moment a file is moved into `skills/`, because its sibling links change |
| Verify commands come from the profile | `setup-deployment/SKILL.md:30`: *"Every pipeline stage runs a command from `profile.verify`. If a command is `null`, the pipeline cannot check that thing and you must say so rather than substituting a guess"* | Every command is hardcoded: `pnpm build`, `npx tsc`, `pnpm audit`, `npx --yes vercel@latest`. **This is the single largest rewrite cost per file** and it is invisible until you try |
| Vendor-neutral stack detection | `lib/detect-stack.sh:306-369` emits fifteen language values (dart, typescript, javascript, go, php, python, rust, ruby, swift, lua, cpp, csharp, kotlin, java, plsql) from fourteen marker checks. `bin/keel:1946` offers `--stack node\|python\|go\|minimal` | One target. `start-an-app/SKILL.md:22`: *"The stack is fixed: Next.js, TypeScript, Tailwind, shadcn/ui, Drizzle, Better Auth."* **445 mentions of the eight named vendors across the tree** |

**On the "13 languages" in the brief.** The current count is fifteen emitted values, not thirteen.
Thirteen was correct before PL/SQL and Dart were added; `docs/ideas/plsql-stack-detection.md:53`
and `docs/stories/plsql-stack-detection.md:50` still say "thirteen". The point is unaffected and
strengthened: the gap between keel's target surface and Leon's is wider than the brief assumed.

### The rules that contradict a rule keel already ships

Each pair is named, both sides quoted.

**1. Absence is not a finding, versus keel's checklists, which are lists of absences.**
`review-an-app/SKILL.md:15`: *"Absence is not a finding. 'No rate limiting', 'no tests', 'consider
adding structured data', none of these are things the app got wrong."*
Against `security-audit/references/owasp-checklist.md:79-101`, an entire section titled "Rate
limiting and resource abuse" whose items are absences: *"Is there any bound at all on request body
size, page size, upload size, and query depth? An unbounded `limit` parameter is a denial of
service with a query string."* And against `ship/SKILL.md:21-22`: *"New code has new tests. A diff
adding behaviour with no test added is incomplete, not finished."*
**Irreconcilable as stated.** Leon is reviewing a hobby app where a maturity checklist is noise;
keel audits payment services where a missing bound is the finding. Any import of `review-an-app`
must drop this rule, and dropping it removes the thing that gives that skill its shape.

**2. Tests and CI are never in scope, versus the tdd gate.**
`start-an-app/references/verify.md:277` and `deploy-an-app/references/gate.md:158`, both:
*"Never in scope: tests, CI..."*
Against `.keel/profile.json` `gates.tdd: "required"`, `skills/tdd`, and `ship/SKILL.md:20-22`.
The collection contains **no automated test framework anywhere**: no unit tests, no integration
tests, no Jest, Vitest or Playwright, in 48 files. Its entire correctness proof is a build, a lint,
a `curl` sweep and an LLM critic. **This is the deepest philosophical difference between the two
bodies of work** and it is why `verify.md`, which is otherwise the best-written file in the
collection, cannot be imported.

**3. Never write a version number, versus pin everything.**
`start-an-app/SKILL.md:33`: *"Never write or accept a version number. Not in an install command,
not in a `package.json` snippet, not in prose, not a Docker image tag."* And
`references/database.md:78`: *"The tag carries no version on purpose."*
Against `setup-deployment/SKILL.md:53`: *"Multi-stage, a pinned base image..."*;
`pipeline-patterns.md:96`: *"`-slim` or `-alpine` base, pinned to a patch version \| A full distro
image, or a floating tag"*; `pipeline-patterns.md:72`: *"`RUN npm ci` # ci, not install: the
lockfile is the point"*; and `owasp-checklist.md:134`: *"A pipeline step pinned to a moving tag
rather than a commit."*
**Both are right about different things,** and this is the pair most likely to be imported by
accident. Leon's rule is about **skill files**: a version written into documentation goes stale
silently, which is true and which keel should probably adopt for its own references. keel's rule is
about **shipped artifacts**: a floating base image tag is a supply chain finding. Importing the
first without the second turns a security rule off.

**4. Deploy straight to production, versus build once and promote the digest.**
`deploy-an-app/references/deploy.md:38`: *"A project this run created deploys straight to
production... There are no users to protect."*
Against `pipeline-patterns.md:114-118`: *"Build one artifact and promote the same digest through
environments. Rebuilding per environment means the thing you tested in staging is not the thing
running in production."*
**Reconcilable, and Leon's own file already reconciles it** at `deploy.md:46`: with an existing
production site *"the posture inverts."* keel's rule is unconditional; his is conditional on
whether users exist. If `gate.md` is imported, this conditional has to be dropped or restated,
because keel does not build pipelines for apps with no users.

**5. Absence of a licence, versus keel's own attribution rule.** Section 6.

### What survives, per file proposed for import

| File | What has to change | Roughly what survives |
|---|---|---|
| `deploy-an-app/references/recovery.md`, 838 words | 9 em dashes. One GitHub CLI mention at `:18`. Reframe from "this skill's run" to "a provisioning run". Nothing else | **about 85 percent.** The ledger table, the fail-closed policy, the retry taxonomy and check-then-create carry over intact |
| `deploy-an-app/references/env.md`, 1,076 words | 16 em dashes. Three Vercel CLI invocations become "the platform's secret store", which is `pipeline-patterns.md:120`'s existing wording. `:9` (never `vercel env pull`) becomes a general rule about not overwriting local config | **about 70 percent.** The seven classes and the denylist table are the value and are vendor-neutral already. `:53-54` (`printf` not `echo`, a trailing newline is stored) is shell truth |
| `review-an-app/references/drift.md`, 1,597 words | 26 em dashes. The privacy-policy cross-reference table at `:52-61` has to be reconciled with `coding-standards/references/data-protection.md`, which is the existing owner. Cap of eight findings has to match `review-code`'s cap of ten or state why it differs | **about 75 percent.** No stack coupling at all, which is why this is the cleanest candidate |
| `review-an-app/references/seo.md`, 1,490 words | 17 em dashes. `:72` names a Next.js default title. `:15, :50` name `src/app/robots.ts` and `sitemap.ts`, which become "wherever the framework generates them". `:66`'s claim about AI crawler adoption is time-sensitive and needs a date | **about 65 percent** |
| `deploy-an-app/references/gate.md`, 1,757 words, partial | 34 em dashes, the highest in that skill. Drop `:139-186` entirely, the critic pass, which duplicates `review-code`. Drop `:158`, the tests-out-of-scope line, per contradiction 2. Restate `:47`, the never-sign-up rule, whose stated reason (first account becomes admin) is specific to what `start-an-app` builds, although the general rule (a health check must not mutate production) is sound | **about 40 percent.** The four-state vocabulary and the live checks; not the review process |

**The cost that is not in the table.** Each of these lands in a skill whose body is already
counted. `setup-deployment` is at 683 words and `write-docs` at 738, already over the 700 target and
carrying a `WARN`. A reference costs its body one link plus a when-to-read sentence, which
ADR-0001's context section measures at roughly the floor of a body's size. **`write-docs` at 738
cannot absorb two new reference links without approaching the ceiling**, so taking `drift.md` and
`seo.md` means taking words out of `write-docs` first. That is real work and it is not optional.

---

## 6. The licence position

**Established, 2026-08-31.**

- **No licence file anywhere.** `find resources/skills-main -iname '*licen*' -o -iname 'copying*'
  -o -iname 'notice*'` returns nothing. `ls -la` on every directory in the tree shows no hidden
  file other than a single `.DS_Store`.
- **No licence statement in the README.** The full 519-word `README.md` was read. It contains no
  "MIT", no "open source", no "free to use", no grant, no restriction, no warranty disclaimer.
  Its only ownership statements are `README.md:1`, *"# Leon's Agent Skills"*, and `README.md:3`,
  *"Skills by [Leon van Zyl](https://github.com/leonvanzyl)"*.
- **No licence statement in any of the 48 files.** A recursive case-insensitive search for
  `copyright|license|licence|all rights reserved|mit license|permission is hereby` across the whole
  tree returns exactly one hit, `start-an-app/references/legal.md:127`, and it is guidance about
  what a **generated app's** terms of service should say. It is not about this collection.
- **The upstream repository confirms it.** `https://api.github.com/repos/leonvanzyl/skills` returns
  `"license": null`, and the repository page shows no licence in the sidebar. So this is not an
  artifact of how the copy was taken.

### How keel has handled this before

[`SOURCES.md`](../../SOURCES.md) opens: *"keel is assembled from four open source projects, **all
MIT licensed**. Some of our skills are close adaptations of theirs; others take only a structural
idea. This file records which is which, per source and per file, so the obligation is discharged
precisely rather than by a blanket credit."*

Two of those four shipped no `LICENSE` file, and keel did not treat that as a small thing. The
final section of [`THIRD-PARTY-LICENSES.md`](../../THIRD-PARTY-LICENSES.md), quoted in full:

> ## Note on the two missing licence files
>
> Both gaps are recorded rather than papered over. We are relying on a README statement of MIT,
> which is a real grant of permission but leaves the copyright holder line undocumented. That is
> acceptable for a private internal repository. It should be resolved before keel is published or
> shared outside the house, and it is listed as a prerequisite in
> `docs/07-open-decisions.md` decision 2.

And for each of those two, an explicit action: *"**Action before any public release:** ask the
author to add a `LICENSE` file, or obtain the copyright line in writing, so this section can carry
the full notice."*

### What keel's own rule therefore requires

Read the precedent precisely. What keel accepted for `andrej-karpathy-skills` and `cursor-starter`
was a **missing copyright line under an existing grant**. `cursor-starter`'s README says *"This
collection is open source and available under the MIT licence. Use these prompts freely in your
projects!"* That is a real permission, and `THIRD-PARTY-LICENSES.md` calls it one: *"a real grant of
permission but leaves the copyright holder line undocumented."*

**This collection has no grant.** Not an undocumented copyright line under a grant. No grant at all.
Under copyright law the default for a published work with no licence is that all rights are
reserved: it may be read, and it may not be copied, adapted or redistributed. Publishing it on
GitHub grants forking and viewing through GitHub's own terms of service, and nothing beyond that.

**So, plainly: taking content from this source is not currently permissible on keel's own terms.**
Not "risky", not "to be documented later". keel's rule, as written in `SOURCES.md` and enforced by
the existence of `THIRD-PARTY-LICENSES.md`, is that every borrowing names a source and reproduces
its notice. There is no notice to reproduce, so there is no compliant way to write the `SOURCES.md`
row that an import would require. The fact that keel's own weakest precedent was still a real grant
makes this worse rather than better: the bar has already been set and this falls under it.

This is inconvenient, because `recovery.md`, `env.md` and `drift.md` are genuinely good and would
fill genuine gaps. It does not change the answer.

**One distinction that matters and is not a loophole.** Copyright protects expression, not ideas.
Reading this collection and then writing keel's own reference on environment variable
classification, in keel's own words, from keel's own experience, is lawful and is how
`SOURCES.md`'s "structural" rows already work (the gstack section: *"We take no content from
gstack, only structural decisions"*). But `SOURCES.md`'s per-file table exists precisely to record
where that line falls, and anything close enough to need a "close adaptation" row is on the wrong
side of it. **Do not use "it is only the idea" as cover for a paraphrase.** If the resulting file
would need a `SOURCES.md` row naming this collection, it needed a licence.

### What would have to happen first

**Outcome, 2026-08-31: step 1 cannot be satisfied.** No licence can be obtained for this
collection, decided by Bernard on 2026-08-31. The collection carries no grant, and that is now
permanent rather than pending. Steps 2 and 3 are therefore unreachable. They are recorded rather
than deleted because the conditions they state are still the right conditions if keel is ever
offered material by anyone else.

1. **Ask Leon van Zyl to add a `LICENSE` file to `github.com/leonvanzyl/skills`**, or to grant
   permission in writing with the copyright line. This is the same action
   `THIRD-PARTY-LICENSES.md` already prescribes twice; the difference is that here it is a
   prerequisite to using anything at all, not a prerequisite to publishing.
   **Closed, 2026-08-31: no licence can be obtained for this collection.**
2. **Unreachable: step 1 cannot be satisfied.** On a grant, add a `SOURCES.md` section and a
   `THIRD-PARTY-LICENSES.md` entry **in the same commit as the first imported file**, per
   `SOURCES.md`'s statement that attribution lives in those two files rather than in each
   `SKILL.md`.
3. **Unreachable: step 1 cannot be satisfied.** Only then do sections 5 and 7 become actionable.

Step 1 cannot land, so the correct disposition for all 48 files is permanently "read, not taken",
whatever the technical merits.

### Where the collection now stands

The local copy at `resources/skills-main` sits outside this git repository, so nothing from it has
ever been committed or redistributed, and none of it is to be imported. Its one remaining use is as
the comparison corpus for the n-gram overlap check that found the seven phrasings.

---

## 7. The recommendation, costed

**The condition failed.** Every item below was conditional on section 6, and that condition can
never be met: no licence can be obtained for this collection, decided by Bernard on 2026-08-31.
What follows is a costing that was never spent, kept as the record of what was assessed. Ranked by
value per token of description budget spent, which is the only budget that scales with every
request in every keel project.

### Rank 1: three reference files. Cost: 0 tokens of description budget.

References are loaded on demand, not in the prefix. `docs/05-token-and-memory-design.md` calls this
*"The mechanism that makes 25 skills cost what 25 descriptions cost."* So these are free against
the 199 tokens, and are the entire reason the answer is not a new skill.

| Reference | Into | Fills | Body cost |
|---|---|---|---|
| A provisioning ledger and recovery policy, from `recovery.md` | `setup-deployment` | The gap at section 3 row 10. `pipeline-patterns.md:126-131` covers rolling back a deploy and nothing covers unwinding a provisioning run | One link plus a sentence in Step 6. `setup-deployment` is at 683, which has room |
| Environment variable classification and the denylist, from `env.md` | `setup-deployment` | The gap at section 3 row 11. Step 6 asks *"where secrets come from"* and never says how to decide per variable | Fold into the same Step 6 link, or a second one |
| Claim-versus-code drift, from `drift.md` and `seo.md` merged | `write-docs` | The gaps at section 3 rows 7 and 6 | **This one is not free.** `write-docs` is at 738 words with a live `WARN` and must lose words before it gains a link |

**Why `write-docs` and not `review-code`.** `review-code/SKILL.md:18` is diff-scoped by its first
instruction. Drift is a property of the repository, not of a change. `write-docs` already owns
whether documentation is true (`:33`, `:90`, `:101`) and only lacks the audit direction.

### Rank 2: four single-paragraph additions to existing references. Cost: 0 tokens.

Each is one rule with no home, small enough that it does not justify a file:

- **Webhook signature verification against the raw body**, from `review-an-app/references/security.md:110-114`,
  into `security-audit/references/owasp-checklist.md`. Not currently covered.
- **Going live with payments as a separate explicit confirmation**, and list-before-creating a
  webhook endpoint, from `deploy-an-app/references/wire-payments.md:7, :25-31, :61`, into
  `security-audit/references/payments-checklist.md`, which covers the code and not the go-live.
- **Reviewer isolation**, from `review-an-app/SKILL.md:53`, into `security-audit` Step 2. keel
  already dispatches parallel subagents at `SKILL.md:46-48` with no rule that they cannot see each
  other's findings.
- **Do not modify the system under test to make a check pass, and do not blind-probe a write
  endpoint**, from `review-an-app/references/evidence.md:13-17, :71`, into `security-audit` Step 1.
  This matters on a client engagement and keel does not say it.

### Rank 3: the live-deploy gate. Cost: 0 tokens, but the most adaptation work.

The four-state vocabulary from `gate.md:15-18` (`passed`, `failed`, `blocked`, `not attempted`) and
the live-URL checks, into `setup-deployment` Step 8, which currently reports what gates and does not
verify that the deployed thing works. About 40 percent of that file survives; see section 5.

### What justifies a new skill: nothing.

**No new skill is recommended.** Costed explicitly:

| Candidate | Description cost | Sum after | Verdict |
|---|---|---|---|
| An SEO and discoverability skill | about 45 tokens | 1,166 of 1,320 | **No.** It is a genuine gap, but a single-lens audit is a reference, and adding a 26th skill spends 23 percent of the remaining headroom on the narrowest job in this document |
| A claim-drift audit skill | about 45 tokens | 1,166 | **No.** Router collision with `write-docs` and `review-code`, which is exactly what `create-skill/SKILL.md:16-17` says is worse than a missing skill |
| A `review-an-app` equivalent | about 50 tokens | 1,171 | **No.** Three-way collision with `security-audit --full` and `review-code`, on a job `security-audit` already does better |
| A `deploy-an-app` equivalent | about 50 tokens | 1,171 | **No.** Collision with `setup-deployment` and `ship`, and inherently vendor-bound |
| All four, as ported | **1,024 tokens as written** | **2,146, which is 63 percent over the ceiling** | **Fails the build.** Even rewritten at the 216-char legal maximum: 1,361 tokens, still failing |

**"No new skill" is an acceptable and previously recorded outcome.**
`skills/create-skill/SKILL.md:21-23`: *"'No new skill' is a correct outcome. Observed: a repo-audit
workflow run three times looked like an obvious candidate, and the baseline showed a capable agent
already doing it well. What it lacked was already covered by `repo-snapshot` and `security-audit`.
Strengthen those instead."* And `docs/ideas/database-design-and-review.md` records the same
conclusion reached a second time on its own evidence.

### The baseline that would be required, per create-skill Step 1

Recorded so that a future change of mind has to pay for it rather than argue for it.
`skills/create-skill/SKILL.md:25-33`: *"Before writing any skill content, run the scenario against a
subagent without the skill. Record exactly how it fails, and quote the reasoning it used."*

For the only candidate with any case, an SEO and discoverability audit, the baseline would be:

- **Scenario:** a fixture web application whose `robots.txt` disallows a path its `sitemap.xml`
  lists, whose landing page advertises a feature the routes do not implement, and whose privacy
  policy promises data export with no export endpoint. Prompt: "review this app's discoverability
  and check whether what it says about itself is true."
- **Arms:** a no-skill arm and a skill arm, both dispatched per `tests/evals/README.md` with
  `--setting-sources "" --disable-slash-commands --permission-mode bypassPermissions
  --output-format json`, staged outside the repository by `tests/evals/stage.sh`, and scored by
  reading, not by grep.
- **The skill earns its place only if the no-skill arm misses the seeded contradictions.** The
  database-design record is the warning here: its baseline *"performed well, and better than the
  seeding"*, found an unseeded defect more urgent than any planted one, and the skill that resulted
  was written around four systematic omissions rather than around review technique. Expect the same
  outcome. A capable agent asked to check a sitemap against a route list will check it.
- **If the baseline passes, the answer is a reference, which is where this document already lands
  without spending the token to find out.**

### What to reject outright

All 10 `create-brand-kit` files, out of scope. All 18 `start-an-app` files, covered by `keel new`
plus the `shape-idea` chain and contradicting `design-architecture` on stack choice. Nine of the 14
`deploy-an-app` files, vendor procedure. `review-an-app/references/security.md`, covered better by
`owasp-checklist.md`. The three `SKILL.md` orchestrators that are not already listed, on the word
ceiling alone. `evals.json`'s format, which is the assertion-suite approach
`tests/evals/README.md` deliberately rejected.

---

## 8. What could not be established

Named rather than left silent.

**Checks not run.**

- **`shellcheck`.** `SKIP  shellcheck is absent locally.` It is not installed on this machine, and
  `tests/run-tests.sh` skips it silently rather than failing. Nothing in this assessment touches
  shell, so it changes nothing here, but the suite's green is one check short of CI's.
- **No eval arm was run.** No baseline, no treatment, for any candidate. Section 7's "no new skill"
  rests on Step 0 reasoning and on the token arithmetic, not on Step 1 evidence.
  `create-skill/SKILL.md:86` calls that out: *"Writing the skill first \| Baseline first. Otherwise
  you are guessing at the failure."* This document does not propose writing anything, so it is not
  that mistake, but the SEO recommendation would become wrong if a baseline showed a skill-less arm
  failing the fixture badly. **This is the item most likely to change the answer.**
- **Nothing was validated by construction.** No imported file was drafted, so the "roughly what
  survives" percentages in section 5 are estimates from reading, not from a rewrite. The
  database-design record's own cost prediction *"was wrong in the cheap direction"*, so treat these
  as an upper bound on effort and a lower bound on what has to be cut.
- **The `write-docs` word arithmetic was not proved.** It is at 738 with a `WARN`, and the claim
  that it cannot absorb two reference links without work follows from ADR-0001's finding that a
  link plus a when-to-read sentence has a floor. The exact number of words that would have to come
  out was not computed against a draft.

**Questions the files cannot settle.**

- **The file count.** The brief says 45; the tree holds 48 content files plus `.DS_Store`. The byte
  total reconciles exactly (489,787 bytes with `.DS_Store` is 478.3 KB), so the size figure came
  from the same tree. The three-file difference is unexplained. All 49 are dispositioned above, so
  no file is missing a verdict either way.
- **Whether a licence would ever be granted. No longer open; settled outside the files.** The files
  could not settle it and still cannot. It was decided instead: no licence can be obtained for this
  collection, decided by Bernard on 2026-08-31. Section 7 was blocked on this and is now closed
  permanently rather than pending. Amended here rather than moved out, so the question and its
  answer stay in one place.
- **Whether the collection has changed since this copy was taken.** The upstream repository's
  `pushed_at` is `2026-08-25T14:24:40Z`, six days before this assessment. Whether the local copy is
  that commit was not checked, and there is no vendored commit hash in the tree to check against.
  A licence may have been added since; the API check on 2026-08-31 says not.
- **Whether the SEO gap is a real gap for the house.** keel covers no SEO because no engagement has needed
  it. Whether client web applications need discoverability auditing is a question about the book of
  work, not about the code, and it decides whether Rank 1's third item is worth the `write-docs`
  surgery.
- **Whether `review-an-app`'s "absence is not a finding" rule is wrong or merely different.** It is
  stated as a contradiction in section 5 because it contradicts keel as written. It is also the
  single best rule in that skill for its own context. The question of whether keel's audits are
  padded with maturity-checklist items, which is what that rule exists to prevent, was not measured
  and cannot be from these files.
- **Whether the `@`-link check's scoping is a defect.** `tests/validate-skills.sh:130-132` checks
  `SKILL.md` bodies only, so an `@` link inside a `references/*.md` file passes today. Noticed while
  checking the collection against the rule. Not investigated, not this document's job, and worth
  someone's attention independently.
