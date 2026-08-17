# Port assessment template

The structure of `<docs_root>/port/<service>-assessment.md`.

**Why this is not shared with `apex-port-plan`.** It was, for one release, on the reasoning that two
templates drift. A run against a real Spring Boot service showed that was the wrong trade: the APEX
template is APEX-shaped throughout, in twenty-one places, and names `INDEX.md`, `xref.tsv`, page
ids, PL/SQL packages, build options and `REDACTIONS.md`. The agent following it rewrote four sections
and ignored its output path, then said so. A shared template that every user has to rewrite is not
shared, it is a detour. The two now cross-reference instead: read the other one before changing the
rules section here, because those rules genuinely are common.

```markdown
# Port assessment: <service> to <target stack>

| | |
|---|---|
| Source assessed | branch, commit, and date. Not "the repo" |
| Target | The stack as named by the requester |
| Recommendation | One line |
| Confidence | Per section, in section 9 |

## 1. Which codebase this describes

**First section, always, even when there is nothing to report.** State the branch and commit
assessed, and whether the snapshot describes the same tree.

Where it does not, tabulate the divergence before anything else. A run found a snapshot describing a
different branch: different framework version, different test count, different SQL safety, and one
tree had no authentication at all. Every conclusion drawn from the wrong one would have been about a
service nobody was porting.

| The snapshot says | This tree has |
|---|---|

Also list any project document whose contents describe a different system. Generated docs go stale
and, worse, get copied between projects.

## 2. What this service is

Routes, size, datastores, partners, scheduled work. Enough that a reader who has not seen it can
follow the rest. Cite `path:line`.

## 3. What has no source to port from

The part that stops new build being sold as translation. For each element of the target stack, say
what exists today to port from. Anything with nothing behind it is scoped separately or split out.

| Target element | Source today | Verdict |
|---|---|---|

## 4. Recommendation

One of: port it, port part of it, do not port it yet, do not port it. Then preconditions, each
labelled port work or not port work.

**And what would change this.** Name the specific fact that would move the recommendation, and how
to get it. This is usually the most actionable paragraph in the document.

## 5. The wire contract

Everything the far side validates byte by byte, and whether the target reproduces it. Each row
`verified` (you ran both and diffed) or `inferred`.

| Property | Source behaviour | Target default | Same bytes? | How known |
|---|---|---|---|---|

A property that matters and was not executed is `inferred`, and says so in the row. Do not describe
an experiment you did not run.

## 6. Contract oddities a correct-looking port will break

Behaviour a caller may depend on that a competent rewrite would tidy away. Status codes that lie,
media types that disagree with bodies, error shapes, field naming that varies per endpoint, absent
transactions.

Each row: what it is, where, and what breaks if it is corrected.

## 7. What should not be ported

Usually the section that pays for the exercise. Dead code, test and sandbox surfaces, duplicated
routes, anything unauthenticated that should never have shipped, and any tracked data that should
not be carried forward.

## 8. Risks

Ranked by what threatens the engagement, not by severity label.

| # | Risk | Severity | Verified or inferred | Mitigation |
|---|---|---|---|---|

Every unresolved finding from the snapshot appears here. A port closes none of them, and it must not
be sold as if it does.

## 9. Inputs read, and inputs not read

**The completeness ledger, and it is not optional.** One row per input the snapshot, the agents, or
a finding named. This exists because two separate runs judged a document's contents from its name or
a grep count and only admitted it afterwards, unprompted.

| Input | Read? | If not, why, and what that costs this assessment |
|---|---|---|

A grep count is not reading a file. Neither is reading its first twelve lines.

## 10. Confidence

Per section: verified, mostly verified, inferential, or estimated. A reader deciding whether to take
this to a client needs to know which parts survive being challenged.
```

## Rules for the whole document

**No hours, no story points, no ranges of either, and no aggregate size.** Rank work against itself
where ranking helps, and name the driver. Nobody can size this work without knowing the team, and a
number in a document like this becomes a quote in somebody else's slide.

Be honest that bands read as effort anyway. Say what the bands are relative to.

**Every claim carries `verified`, `inferred`, or `estimated`.** The distinction is the document's
whole value: a reader who cannot tell them apart has to re-derive everything or trust all of it.

**Cite `path:line` or mark `Unknown`.** Never a recollection of how services like this usually work.

**The same rules apply to `apex-port-plan`'s template.** Read the other one before changing them
here, so the part that genuinely is common stays common.
