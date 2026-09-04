# Seed mode

Write a starting standards document where there is no code to derive one from, and say in the
document that this is what happened.

**Seed inverts Step 1, and the inversion is stated rather than hidden.** Step 1 says derive and do
not impose, and that rule assumes a codebase that exists. Where there is none there is nothing to
derive from, and the choice is between the house defaults and nothing. Seed is the honest answer to
a question Step 1 does not address rather than an exception to it, and a reader who meets seed and
Step 1 without this paragraph is right to distrust one of them.

## Before anything is written

Confirm the two facts that routed here. **Where the repository has source after all, name the files
and offer audit instead**, which derives from the tree rather than importing defaults: do not seed
over a repository that has something to read. Where `<docs_root>/standards.md` turns out to exist,
name it and ask before writing, per Step 0.

Read `.keel/profile.json` for `stack`, `verify.lint` and `docs_root`. Where the profile was
generated from a tree with no code, the stack fields read `unknown`, `none` and false by fallback
rather than by finding, and a detected nothing is not a decided no. Where the profile declares a
real value, that is a statement about the project and you use it. Several of the index's predicates
ask about a running system that does not exist yet, and the profile cannot settle those at all. Two
deciders are available: a profile value that was declared rather than defaulted, and what the
request actually says the project is, not what it suggests. Where neither settles a predicate,
record it in the document as undecided, naming the predicate, rather than as excluded. An
exclusion that nothing decided is a finding seed invented.

## What seed writes

`<docs_root>/standards.md`, and nothing else. Follow
[standards-template.md](standards-template.md), and take the content from
[house-defaults.md](house-defaults.md) and the topic references its index says apply.

**Only the topic references whose index predicate holds.** The index gives every reference its own
condition, and evaluating each condition against this project is the work. Fold in the ones that
hold, and record in the document which did not and what decided it. Record a reference no decider
settled as undecided instead: this record has three states, and no reference leaves it without one.
Folding in all of them is the failure the index exists to prevent, and it is invisible in the output
unless the document says what it left out.

**The document states its provenance in its own header:** that it was seeded from the house defaults
and not derived from code, and that it becomes a derived standard only once there is code and
somebody runs audit or author against it. Without that sentence an inherited default reads later as
an observed convention, which is worse than having written nothing.

### Where the template asks for something there is no code to give

`standards-template.md` was written for a document derived from a codebase, and three of the things
it requires cannot be given here as it expects them. Two of them cannot exist at all. The third,
`Enforced by`, exists only where the profile carries a lint command, and not otherwise. **Say what
is missing in the document rather than inventing it or dropping the row silently.** A blank where a
reader expects a commit is a question; an invented commit is a lie the reader has no way to catch.

- **`Derived from`** carries the provenance sentence instead of a sample and a commit: seeded from
  the house defaults, no files sampled, because there were none.
- **`Enforced by`** carries `profile.verify.lint` where the project has one. Where it is `null`,
  say so and say that adding a check-only lint command is the first thing to do here, which is
  Step 3's rule and the highest value work available before any code exists.
- **The per-entry example is omitted**, and each entry says so in one clause: no example, because
  there is no code to take one from. Rule and reason are still required and are both available from
  the house defaults. **Do not write an example from another project, from the house reference's own
  illustration, or from an imagined file in this one.** An invented example is the failure the
  template's own closing line names, and it is worse here than elsewhere, because a reader who finds
  one assumes the rest was observed too.

The departures ledger is written with its heading and no entries. A project that disagrees with a
house default records the departure there, with a reason, and that is the only mechanism there is.

### The record the template has no section for

The template never mentions the index, so the record of what the index decided has no section
there. Seed writes it as one, headed `House references, and what decided each`, immediately before
the departures ledger, one row per file the index lists, every run, including the run where every
predicate held:

```markdown
| Reference | State | Predicate | Decided by |
|---|---|---|---|
| `<reference>.md` | Applied | <the index's condition> | |
| `<reference>.md` | Excluded | <the index's condition> | <what settled it> |
| `<reference>.md` | Undecided | <the index's condition> | |
```

`Decided by` is filled on an excluded row and left empty on the other two, because an applied row
was settled by its predicate holding and a decider on an undecided row invents the exclusion.

## The gap report

`house-defaults.md`'s index is keel's own library, and a stack it does not reach is **keel's gap
rather than the project's**. Report it **in the reply**, not in the document and not in a file: the
audience is whoever maintains keel, and a note to them left inside somebody else's repository is
addressed to a reader who is not there. Sections 2 and 3 restate what the document's own
record already carries, deliberately and for a different reader: the document serves the project,
so satisfying the reply does not excuse leaving that record out.

**State the counting unit first, before any number:** write that one house reference is one file
the index lists, and that each one is counted exactly once, as applied, as excluded, or as
undecided. That sentence opens the report and section 1 follows it. A count whose unit was never
stated is a number the reader it is addressed to cannot check.

**Then, in this fixed order, every run, including the runs with nothing to report:**

1. **The stack**, as read from the profile: language, framework, and whether it has a user
   interface.
2. **Applied.** The references whose predicate held, by name.
3. **Did not apply.** By name, each marked as excluded or as undecided. An excluded entry
   names the predicate that excluded it and the decider that settled it. An undecided entry
   names the predicate nothing settled and names no decider, because an exclusion nothing
   decided is one seed invented. Every reference the index lists appears in section 2 or in
   this one.
4. **Not covered by any reference.** The finding. A layer this stack has that no listed reference
   reaches, named as a layer rather than as a file that ought to exist. A predicate that excludes
   the only reference covering a layer this project actually has is the shape to look for.
5. **Nothing to report**, in those words, where section 4 is empty. An absent gap report and an
   empty one read identically, and only one of them means the question was asked.

Do not invent a rule to fill a gap. The report is the output; a house default written to cover a
layer keel has no reference for is exactly the imposition seed's opening paragraph disclaims.

## What seed never does

Write a rule it cannot source from the house defaults, however usual that rule is for the stack.
Claim a convention was observed. Write an example, a sampled file count or a commit into a template
row that has none. Edit any file other than the one it writes. Run anything that changes the
project. Make a network request.
