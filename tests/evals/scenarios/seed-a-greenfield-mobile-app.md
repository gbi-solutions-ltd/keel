# seed a standards document for a project with no code yet

Inject: coding-standards

**Tests:** whether seed writes a starting document that says where it came from, and whether the
library-gap report is produced against a stack the house references do not fully reach.

**Baseline, no skill:** not recorded. This is a treatment-only measurement of a new mode.

**What the arm can see.** An injected skill's references are staged beside the working directory, so
`references/seed.md`, `references/house-defaults.md` and `references/standards-template.md` are
readable at `../skills/coding-standards/references/`, and the assembled prompt names that path.
Step 0 links the mode. Whether the arm opened any of them is observable in the tool calls under
`--output-format stream-json`, and the reply's prose is not evidence that it did. The extraction
counts any tool whose input names the path, `Bash` included.

**The fixture is two files.** A profile and a README, no source of any kind. The profile is the only
statement of what the stack is: a Dart and Flutter application with a user interface. Nothing in the
fixture names a house reference, a gap, or anything about standards.

**What the arm has to work out for itself.** The index in `house-defaults.md` gives each topic
reference a predicate. One of those predicates excludes the only reference covering the user
interface layer for exactly this framework, and no other reference covers that layer. `seed.md`
names neither this stack nor that reference, which `tests/test-doc-claims.sh` pins, so the mode text
hands over nothing. The index names both, because the predicate is what the arm has to apply and
applying it is the measurement.

**Passes if the reply:** enters seed without being told the word "seed", and does not attempt to
derive conventions from a codebase that does not exist; writes `docs/standards.md` and creates
nothing else; leaves both fixture files byte identical; states in that document's header that it was
seeded from the house defaults and not derived from code; folds in only the topic references whose
index predicate holds, and lands every topic reference in exactly one of three states, applied, or
excluded naming the predicate and the decider that settled it, or undecided naming the predicate and
saying no decider settled it, at least one of those exclusions naming as its decider a value the
profile states outright, and leaving undecided no predicate such a value settles; gives the gap
report in the reply, in the five sections in the order the stack, applied, did not apply, not
covered by any reference, nothing to report, with the counting unit stated before any number; names
the user interface layer as covered by no house reference for this stack, as a gap in keel's library
rather than a fault in the project; and keeps the gap report out of `docs/standards.md`.

**Fails if the reply:** writes no document, or writes it anywhere other than `docs/standards.md`;
creates or edits any other file; omits the provenance sentence; folds in every topic reference
without evaluating the predicates, or names no excluded reference, or names no exclusion whose
decider is a value the profile states outright, or leaves undecided a predicate such a value
settles, or leaves a topic reference in none of the three states, or marks one excluded or undecided
without naming its predicate, or marks one excluded without naming the decider that settled it, or
marks one undecided while naming a decider, an exclusion nothing decided being a finding seed
invented; omits the gap report, or gives its sections in another order, or gives a number before
stating the unit; reports no uncovered layer for this stack; puts the gap report into the project's
standards document; or invents a house rule to fill the gap instead of reporting it.

**Declared means stated outright**, for both lines above. `seed.md` names `unknown`, `none` and
false as fallbacks, and its governing sentence is that a detected nothing is not a decided no, which
covers an empty list too: so a reference left undecided on `datastores` alone is not scored against
either clause.

**Ambiguity is a fail.** A verdict needing a judgement the paragraphs above do not settle is
recorded as a fail with the reason, not argued into a pass.

## Prompt

We are starting a new mobile app and nobody has written any code yet, there is just the repo and a
readme. Can you put together the coding standards we should be working to before anyone starts?
