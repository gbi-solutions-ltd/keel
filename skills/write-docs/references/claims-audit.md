# Claims audit

Checking that what a repository says about itself is still true. This produces findings, not a
document: there is no output path, and repairing what it turns up is a different job that has to
be asked for.

## What counts as a finding, and what does not

Every finding is a claim the repository publishes, set against the code that fails to keep it. Two
things, both quoted, both located. Neither one on its own will do.

`skills/review-code/SKILL.md` already sets the shape for a single location: never a finding without
a location, and never a location without a reason. A drift finding has two locations rather than
one, and both are required, because the interesting question is which of the two is wrong. Often it
is the code, and the document was right all along.

**What is missing does not belong in this report, and that limit holds here and nowhere else.**
Elsewhere in keel a gap is very much a finding:
`skills/security-audit/references/owasp-checklist.md` spends a whole section on what is not there,
and `skills/ship/SKILL.md` treats a diff that adds behaviour with no test as incomplete rather
than finished. The distinction is what the audit is for. A claims audit that starts listing what a
larger project would have has stopped auditing claims and started designing a different project,
and it does that under the authority of an audit, which is worse than doing it openly.

So say the seam out loud in the report rather than silently dropping what you noticed. A missing
control belongs to `keel:security-audit`. A defect in a change belongs to `keel:review-code`. Name
the one you saw, name the owner, and hand it over. An unstated seam between two owners is a defect
in its own right: this repository already carries one recorded in `docs/02-skill-catalog.md`, where
a skill shipped with no catalog section because the gap belonged to nobody in particular.

## What a finding must carry

Every finding carries:

- **The claim, verbatim**, with the file and line it appears on. Not a summary of the claim. A
  paraphrase is where the audit's own reading gets smuggled in as the document's words.
- **The `path:line` of the code that fails to keep it**, and one sentence on how it fails.

`skills/security-audit/SKILL.md` states the principle this rests on: every finding needs a concrete
exploit and a `file:line`, because a report of forty maybes gets ignored while three real ones get
fixed. A drift finding with one of the two missing is a maybe. It does not go in the report, and
it does not go in as a hedge either. If you cannot find the code side, what you have is a question
for the author, and it goes in the closing list of what could not be checked.

## The surfaces to sweep

Sweep these surfaces. Each over-claims in a way of its own.

| Surface | What it typically gets wrong |
|---|---|
| The README | Counts, feature lists, and a quickstart nobody has run since the layout changed |
| Documents under the docs root | A described flow that was refactored, and options that were renamed |
| A public site or landing copy | Capabilities stated in the present tense that are planned |
| An API reference | Endpoints, fields and error codes that the handlers no longer match |
| A changelog | An entry for work that was reverted, or a version that was never released |
| A privacy or terms page | Retention periods, third parties, and data categories that the code contradicts |
| The project's own configuration | A declared command or gate naming something that no longer exists |

**Counts are the highest yield thing on that list**, and this repository is the evidence.
`tests/test-doc-claims.sh` exists because `README.md` stated counts that the tree contradicted, and
it now pins five of them mechanically: the skill count, the eval scenario count, two supply chain
rule counts and the open decision count. Every one of those was a sentence somebody wrote in good
faith and nothing rechecked. Where a claim is countable, the fix is usually a test rather than an
edit, and saying so is part of the finding.

**The configuration surface is not speculative either.** `docs/runbooks/going-public.md` records the
shape in this repository: an allowlist naming a path that no longer exists is a rule protecting
nothing, and nothing would report it. A gate that names a file, a command or a path is making a
claim about the tree, and it can go stale exactly like prose can, while looking more authoritative
than prose because it is executable.

## Discoverability artifacts

A sitemap lists routes. A `robots.txt` grants or refuses access to them. An `llms.txt` and a
page's own metadata describe what is there. All four state those things in a form a machine reads,
which makes every one of them a claim, and puts every one of them in scope. Check each against the
routes the application actually serves, never against the other files.

- **A listed route that does not resolve.** The sitemap is an assertion that the address is there.
- **A path one file advertises and another forbids.** A sitemap entry for a path `robots.txt`
  refuses is a contradiction on its face, and whichever one is right, one of them is wrong.
- **A canonical address that disagrees with the one being served.** Including the plain forms of
  disagreement: a scheme, a trailing slash, a subdomain.
- **Metadata describing a page's content wrongly.** A title or summary left over from the page the
  template was copied from is a claim in the same sense a README sentence is.
- **Structured data asserting facts the system has no record of.** A rating, a price, an
  availability or an author that nothing in the application can produce.

## What is out of scope

**This is truthfulness, not marketing.** None of these is a finding and none of them belongs in
the report: that a page could carry more content, that it could word what it carries differently,
that other sites could link to it, that it could place better in a result list, or anything else
phrased as "consider adding". Not one of them is a claim the code contradicts, and a claim the
code contradicts is the only thing this audit measures. `skills/review-code/SKILL.md` already
separates a genuine preference, which is said once and not insisted on, from what blocks. A
preference about how a project should present itself is not even that, and a file that wandered
into ranking advice would be claiming a competence keel does not have and cannot check.

**A project that has chosen not to be found is not a defect.** Where every artifact says the same
thing, stay out, the project is keeping a decision, and a decision being kept is precisely what
this audit measures. Record it as consistent and move on.

## Reporting

Rank by who is affected and how badly. A quickstart that fails for every new joiner outranks a
stale sentence in an internal document, whatever the size of the contradiction.

**Cap it.** `skills/review-code/SKILL.md` caps at around ten findings, on the reasoning that more
than that means the change is too large to review and that is itself the finding. The same applies
here: a repository with forty drift findings has a documentation practice that is not working, and
that sentence is more useful than findings eleven through forty.

**Close with what could not be checked, and why**, named rather than omitted.
`skills/security-audit/SKILL.md` requires exactly this: an audit that implies completeness it does
not have is worse than a narrow one. A surface you did not have access to, a claim whose code side
you could not find, a route you could not reach: each gets a line.

**The audit is read-only.** It says what is wrong; somebody else fixes it, which is the same rule
`skills/review-code/SKILL.md` sets for a reviewer who is tempted to rewrite the code in the review.
Being able to see the fix is not permission to make it, and a report that arrives with the edits
already applied has removed the author's chance to say the code was the side that was wrong.
