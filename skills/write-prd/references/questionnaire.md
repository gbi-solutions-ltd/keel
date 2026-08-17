# Questionnaire

Question banks per mode. Adapted from `cursor-starter/planning/prd-questionnaire.md`, with the
per-mode split and the answer-first rule added.

## How to ask

**One question per message.** Not two, not a numbered list of six. The reason is not politeness:
a wall of questions gets one skimmed answer covering the easiest item, and the rest are silently
lost.

**Offer your own answer as the default.** You have read the snapshot and the code; you usually
have a good guess. "I think X, because Y. Correct?" is answerable in one word. "What is X?" makes
the user do work you could have done.

**Use `AskUserQuestion` when the answer is a choice** between two to four options, which is most
of the time. Use open text when the answer is a paragraph, like the problem statement. How to
shape the options, and when to batch:
[../../keel/references/asking-questions.md](../../keel/references/asking-questions.md).

**Stop when you can write every section.** The bank is a source of questions, not a checklist to
complete. Ten good answers beat thirty shallow ones. If a section can only be `Unknown, needs a
decision`, ask once and move on rather than pressing.

**Never ask what a file already answers.** Every question you ask that the snapshot covers spends
the user's patience and teaches them the process is theatre.

## Order

Same for all modes, because it front-loads the questions whose answers reshape everything after
them:

1. Problem and evidence
2. Users
3. Scope boundaries
4. Requirements detail
5. Success and constraints

Stop early if the answers make later questions moot. If question 3 establishes this is a
throwaway internal tool, do not ask about compliance.

---

## `from-idea`

**First: is there an idea record?** `shape-idea` writes `<docs_root>/ideas/<slug>.md`, and where one
exists it has already settled most of the Problem, Users and Scope bank below, with the evidence and
the alternatives that were rejected.

Read it and **ask nothing it answers**. Two skills asking the same question is how a process starts
feeling like theatre, and it is the specific failure that made the idea record an artifact rather
than a conversation. Carry forward:

| From the record | Becomes |
|---|---|
| The problem, and its evidence | The PRD's problem statement, unchanged where it is already specific |
| Alternatives considered and rejected | Context in the PRD, so nobody re-proposes them |
| The assumptions table | `CON-NN` entries, one per assumption still unchecked |
| Open questions | The PRD's open questions, unresolved ones surfaced as choices |
| The recommendation, if it was "build something smaller" | The scope boundary. This is the one most often lost |

Then ask only what the record leaves open, which is usually Requirements detail and Success.

If there is no record and the idea is still a sentence, stop and run `shape-idea` first. Writing
requirements for an unexamined idea produces a well-formed document nobody should build from.

Where the idea arrived fully formed and the user does not want it questioned, that is their call:
note it in the PRD and carry on.

Nothing is written. You are establishing the whole thing, so most questions are open.

**Problem**
- What happens today that is bad enough to build something? Ask for a specific recent instance,
  not a category. "Reconciliation takes two days each month end" beats "reporting is hard".
- Who currently feels that, and how often?
- What do they do instead right now, including the spreadsheet or the WhatsApp group?
- How would you know it got better? What would you measure?

**Users**
- Who uses this, and are they inside the organisation or outside?
- What are they expert in, and what will they get wrong?
- Is anyone forced to use it, versus choosing to?

**Scope**
- Describe the smallest version that is still useful to someone.
- What are you deliberately not building, and why?
- What must this integrate with on day one?

**Requirements**
- Walk me through the main flow, start to finish, as a user experiences it.
- What must never happen? Those become `NFR` or `CON` entries.
- What happens when the main flow fails halfway?

**Success and constraints**
- What is the deadline, and what forces it?
- Any regulatory, contractual, or platform constraint I should know?
- What does this cost if it goes wrong?

---

## `from-repo`

The snapshot has already told you what the system does. **Do not ask anything it answers.**
Ask only what code cannot know, which is almost entirely intent.

**Purpose, which code never records**
- The snapshot says this service does X. What problem was it built to solve?
- Who asked for it, and is that person still the owner?
- Is it in production, and does anything depend on it that I would not see from here?

**Intent, one question per ambiguity found in step 3**

This is the bulk of the conversation and it is where the mode earns its keep. For each
behaviour you cannot classify, ask with your own reading offered:

- "The code writes `pending` on insert and only ever moves to `approved` or `rejected` via the
  callback. I read that as a requirement: an unconfirmed registration must be visible as
  pending. Is that intended, or an artefact?"
- "Request signing is skipped when the header is absent. That looks like a deliberate migration
  affordance rather than a requirement. Which is it?"
- "The routing engine computes a provider and the payment path then ignores it. I am treating
  that as a bug rather than a requirement. Confirm?"

Ask these in descending order of how much the answer changes the document. Batch nothing.

**Boundaries**
- Which of the behaviours I listed under Observed but not required should become requirements?
- Is anything in here deprecated or awaiting deletion?
- What was deliberately left out, that a reader might expect to find?

**Success and constraints**
- How do you currently tell whether this service is healthy?
- What is the actual cost of it being down or wrong? That sizes every `NFR`.
- Any compliance regime this falls under?

---

## `revise`

A PRD exists. Do not rewrite it from scratch: diagnose it, then fix what is broken.

**There are two reasons to revise, and the second is the common one.** A PRD can be *wrong*: vague,
contradictory, untestable. It can also be *overtaken*, which is a good PRD whose open questions have
since been answered. The second happens to every PRD that gets built, because the template
deliberately writes `Unknown, needs a decision` rather than inventing a number, and something has to
carry the answer back when it arrives. Do not look for defects in a document that has none and
conclude there is nothing to do.

**Diagnose first, without asking anything.** Which list you produce depends on which case it is.

*Wrong:* untestable requirements, missing IDs, "should" statements, invented specifics, internal
contradictions, absent sections.

*Overtaken:* every `Unknown, needs a decision`, every `inferred` or `disputed` requirement, and
every open question, with which of them now has an answer. That is a maturity report rather than a
defect list, and it is what the user needs to see: it says how much of the document is still a
placeholder.

Present that list before asking questions, so the user sees what you are fixing and can veto.

**Keep the question rows.** Strike a settled question through and record its answer and the date in
place, rather than deleting the row. The trace from question to answer is most of why anyone reads
an old PRD, and a deleted row reads as though nobody ever asked.

**Then ask, only about the gaps**
- For each untestable requirement: what would you observe if this were met?
- For each "should": is this a must, or is it out of scope?
- For each conflict: which of these two is right?
- For each invented-looking number: where did this come from?

**Preserve what works.** Keep the original wording of any requirement that is already testable,
including its ID. Rewriting a fine requirement loses reviewer trust and breaks any story already
traced to it.

**Report what changed** when you present the revision: requirements added, reworded, retired,
and split. A diff is more reviewable than a new document.
