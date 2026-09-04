# author a standards document for a repository that has none

Inject: coding-standards

**Tests:** whether author mode derives from the code rather than importing a style guide, and
whether it applies Step 1's rule that counting decides style and never correctness. Author mode had
never been exercised in a recorded run before 2026-09-02, and two proposed modes depend on it:
`audit` ends by offering it, and `seed` is its Step 4 with a different source.

**Baseline, no skill:** not recorded. This is a treatment-only measurement of one mode, not a
skill-versus-baseline comparison.

**What the arm can see.** Since 2026-09-02 `tests/evals/stage.sh` stages an injected skill's
references beside the working directory, so `references/house-defaults.md` is readable at
`../skills/coding-standards/references/`. Step 4 asks for it by name. Whether the arm goes and reads
it is observable in the tool calls under `--output-format stream-json` and is not scored here.

**The fixture's two deliberate splits.** `src/invoices.js` builds SQL by string concatenation at
seven call sites and uses parameters at three. `src/billing.js` returns a typed error object in six
functions and throws in two. The first is the split where the majority is a defect; the second is an
ordinary majority convention. An arm has to tell them apart.

**Routing, and why the prompt names the artefact.** This fixture has code and no
`docs/standards.md`, so the two facts in Step 0 route it to audit, which derives and reports rather
than writing the document. The prompt therefore asks for a standards document by name: the request's
words win where they conflict with the two facts, and **this scenario scores the author path**. An
arm that reports an audit and stops is a fail, and the reason recorded is that it followed the facts
over the words. **The prompt changed on 2026-09-03 for this reason**, so the arm recorded on
2026-09-02 ran against different words and a two-mode Step 0. That entry is a record and not a
comparison.

**Passes if the reply:** cites at least three conventions by `path:line` from the fixture; records
the minority as the rule on the 7-to-3 SQL split, per Step 1's rule that counting decides style and
never correctness; writes `docs/standards.md`; and gives it a departures section.

**Fails if the reply:** writes any rule with no basis in the fixture, which is the "importing a
generic style guide" failure the Common mistakes table forbids; records the SQL majority as the
convention, which would sanction an injection; writes no document; or omits the departures section.

**Ambiguity is a fail.** A verdict needing a judgement the paragraphs above do not settle is
recorded as a fail with the reason, not argued into a pass.

## Prompt

Nobody here has written down how we do things and a new engineer starts on Monday. Can you write us
a standards document from the conventions this codebase already follows?
