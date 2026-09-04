# audit a repository that has conventions and no document

Inject: coding-standards

**Tests:** whether audit derives and reports rather than authoring, and whether Step 1's counting
rule survives being applied by a mode that is not author.

**Baseline, no skill:** not recorded. This is a treatment-only measurement of a new mode.

**What the arm can see.** An injected skill's references are staged beside the working directory, so
`references/audit.md` and `references/audit-offer.md` are readable at
`../skills/coding-standards/references/`, and the assembled prompt names that path. Step 0 links
both. Whether the arm opened either is observable in the tool calls under
`--output-format stream-json`, and the reply's prose is not evidence that it did. The extraction
counts any tool whose input names the path, `Bash` included.

**The fixture's two deliberate splits.** Nine call sites build SQL by concatenation through
`query_concat` and four use placeholders through `query_param`; both helpers are defined in
`storage/db.py`, which is not a call site. Six functions return a `Result` object and two raise a
domain exception. The first split is the one where the majority is the defect, so Step 1's rule
requires the minority to be recorded as the rule; the second is an ordinary majority convention
where neither form is wrong. An arm has to tell them apart. **Only the SQL split is scored below.**

**Passes if the reply:** enters audit mode without being told the word "audit"; writes
`docs/audits/<date>-standards-audit.md` and creates nothing else; leaves every file it read byte
identical; carries all six report sections in the order header, what was sampled and what was not,
the conventions found, the splits, what has no convention, not covered, decided by where each
section is first named in the report and nowhere else; states in the header that this is a
derivation and not an agreed standard; records the minority as the rule on the SQL split, gives the
conforming-to-total ratio and it is 4 of 13, and says why; and offers to author at the end without
doing it.

**Fails if the reply:** writes `docs/standards.md`; edits or appends to any file it read; omits any
of the six sections named above, or gives them in a sequence other than the one written out there;
records the majority as the convention on the SQL split; gives no conforming-to-total ratio for it,
or gives one other than 4 of 13; omits the derivation disclaimer from the header; or authors without
being asked.

**Ambiguity is a fail.** A verdict needing a judgement the paragraphs above do not settle is
recorded as a fail with the reason, not argued into a pass.

## Prompt

We took this service over last month. There is no standards document and the people who wrote it
have gone. Can you tell me what conventions it actually follows?
