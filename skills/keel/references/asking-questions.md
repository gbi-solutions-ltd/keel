# Asking questions well

Read this before building any `AskUserQuestion` call. It is shared by every skill that asks the
user to decide something, so the shape of a question is the same wherever it comes from.

## The rule that matters most

**An unresolved question belongs in a prompt, not only in a document section.** Every skill here
produces artifacts with an Open questions section, and a question filed there has a low chance of
being answered: the reader is reviewing a document, not making decisions. The same question asked
as a choice is usually settled in seconds, and the answer improves the document before anyone
reads it.

So: write the question into the artifact **and** put the ones that block work to the user as
choices. The section is the record. The prompt is how it gets answered.

Ask about what blocks work. A question whose answer changes nothing you are about to do goes in
the section only.

## Single-select and multi-select are different questions

`AskUserQuestion` takes `multiSelect`. Choose it by whether the options are mutually exclusive,
not by how many you expect the user to want.

| | Single-select | Multi-select |
|---|---|---|
| Options are | Mutually exclusive. Picking one rules the others out | Independently valid. Any combination can be right |
| Example | Which datastore | Which environments to deploy to |
| Marking a recommendation | Put it first, and mark the label `(Recommended)` | **Put it first. Never mark a label** |

### Why multi-select carries no `(Recommended)` label

The label is ambiguous the moment more than one answer can be chosen. It reads either as "choose
this one", which contradicts the question, or as "include this one", which says nothing about the
rest. Either way the user has to work out which meaning you intended, which is the opposite of
what a recommendation is for.

Worse, marking one of several independently valid options implies the unmarked ones are wrong.
They are not: that is what made the question multi-select.

**Order carries the recommendation instead.** Put the most appropriate option first and let the
sequence say it. It costs nothing, it cannot be misread, and it stays true when the user picks
three of the four.

## Writing the options

- **Two to four.** One is not a question. Five means the decision has not been thought through
  yet, so think it through and ask a smaller one.
- **Every option gets a `description` that says what happens if it is chosen**, in consequences
  rather than restating the label. "Fails closed: a rate-limiter outage blocks traffic" beats
  "the safe option".
- **Never write a fake option.** An option you would reject if chosen is not a choice, it is
  theatre, and it costs the user's trust for every later question.
- **Never add an "Other" or "Something else" option.** The harness adds one.
- **Options must be distinguishable by someone who has not read the code.** If two options differ
  only in a word, say what actually differs.

## Answer first, wherever you can

You have read the snapshot, the artifact, and the code; you usually have a defensible view. A
question that carries your reading is answerable in one word. A question that does not makes the
user do work you could have done.

This is not the same as leading. State the reading, then let the options include disagreeing with
it.

## When not to ask

- The artifact, the profile, or the code already answers it. Asking teaches people the process is
  theatre.
- The answer is a paragraph, not a choice. Use open text; `AskUserQuestion` is for choices.
- You are asking permission to continue work already agreed. Just do it.
- The decision is reversible and cheap. Pick, say which you picked and why, and move on.

## Batching

Up to four questions can go in one call, and that is right when they are independent and the user
is in review mode. It is wrong when the first answer changes what the later questions should be:
ask that one alone, then decide the rest.

Never batch a question whose answer could make the others moot.
