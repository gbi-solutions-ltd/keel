# Idea: set the context window at init, and automate the handoff

| | |
|---|---|
| Raised by | Bernard, 2026-08-18 |
| Status | agreed, 2026-08-18. Pieces one and two are specified in `docs/prd/context-window-at-init.md`; piece three remains unscoped |
| Recommendation | Build it, in three independent pieces, and only in this order: make a configured window a floor rather than a ceiling, then write it at init, then inject a bounded pointer at session start. The `/clear` itself cannot be automated |
| Next | `docs/prd/context-window-at-init.md` (draft, awaiting approval). Piece three still depends on open question 2 |

## The problem

Two problems, related but separately fixable.

Every keel project needs `gates.context_window` typed in by hand, and until someone does, the
watchdog assumes 200,000 and `keel doctor` prints a nudge on every run. Second, when the watchdog
fires at the stop threshold, the session tells the user to run `/clear` and then point the next
session at `.keel/handoff.md` themselves, so the two ends of a handoff are manual even though both
files involved are written mechanically.

**Evidence.** This repository's own `.keel/profile.json` carries `"context_window": 1000000`, and
`write_profile` never emits that key (`bin/keel:364` writes the gates object and it is not in it), so
it was added by hand. `bin/keel:1271` exists solely to tell the reader to do the same: "If sessions
here use a larger context, set gates.context_window in .keel/profile.json". The handoff half is
`lib/context_watch.py:452`, step 3 of the stop instruction: "Tell the user to run /clear and resume
by pointing at that file."

## What was asked for

> At init, every project could be set to an appropriate context_window e.g. 200k (based on your
> recommendations) and then keel ensures automatic handoff when context is filled. Instead of asking
> the user to clear and refer to the handoff doc, keel could do this automatically.

## The case against

**Strongest argument for not building this as stated: writing 200,000 at init would make the
watchdog worse than it is today, on exactly the sessions that have the most room.** `window_for`
returns a configured value immediately at `lib/context_watch.py:142-146`, before it ever reaches the
upward correction at `:149-150`. Observation can currently rescue a wrong assumption: a session that
provably exceeds 200,000 tokens proves the window is larger, because the API would have refused the
request otherwise, and the watchdog lifts itself. An explicit setting removes that. So a 1M session
in a repository where init had written 200,000 would hard-stop at 170,000 tokens and stay stopped,
with the user's only escape being to edit the file the tool just wrote. That is precisely the
failure the docstring at `:125-127` says the function was rewritten to prevent: "a watchdog that
reports 200% hard-stops the session immediately and never lifts, on exactly the sessions with the
most room left." This repository would have been broken by its own idea, had 1,000,000 not already
been set by hand.

**This was put to the requester on 2026-08-18 and answered:** make a configured window a floor
rather than a ceiling, so observation can still correct it upward. That makes writing 200,000 at
init safe, and it turns the objection into the first task rather than a reason to stop. It is
recorded here because the order matters: piece two is harmful before piece one lands.

**Second argument: half of the second request cannot be built at all.** `/clear` is a user
keystroke. No hook output clears a session, and a plugin has no mechanism to start a new one.
Everything on either side of that keystroke is automatable and one side already is, but "keel could
do this automatically" cannot become true for the clear itself, and a record that implied otherwise
would be promising a thing the harness does not offer.

**Third argument: the obvious way to build the resume side breaks prompt caching, expensively.**
`hooks/session-start:4-7` is unambiguous: "STATIC IS THE POINT. Prompt caching holds only while the
front of the request is byte-identical... No date, no branch, no git status, no counter, no reading
of any file that changes. One volatile byte here costs the cache on every request in every session."
`.keel/handoff.md` is the single most volatile file keel writes, rewritten on every stop and every
compact, and `render_handoff` (`lib/context_watch.py:200-235`) emits up to five trimmed prompts and
thirty file paths, roughly 1,300 tokens. Reading its contents into the always-loaded prefix would be
the exact thing the hook forbids, at about thirty times the cost of the rule it already carries.

That is answerable and the answer constrains the design: inject a **pointer**, not the handoff. The
hook already reads a file that changes, `.keel/profile.json`, and `:9-14` sets the bound that makes
it acceptable, which is that the output has a fixed number of forms and moves between them only on a
deliberate edit. "A handoff exists" versus "it does not" is two forms. The handoff's contents are
unbounded and would be a new class of thing entirely.

**Fourth argument: the always-loaded budget is nearly gone.** Measured 2026-08-18, the hook injects
about 356 tokens against a 250 target and a 400 ceiling enforced at `tests/validate-skills.sh:283-284`.
A pointer is perhaps 15 tokens and fits. It does not fit twice, and
`docs/ideas/plain-language-chat.md` is competing for the same 44 tokens. The two ideas must be
costed together or the second one to land fails the build.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Nothing | The watchdog already self-corrects upward and already writes the handoff before compaction. What remains is one manual edit per project and one instruction per handoff, which is small |
| Do it manually | One line in `.keel/profile.json`, and typing `/clear` then "read `.keel/handoff.md`" | This is today, and it works. It is also two things a person must remember at the exact moment their context ran out, which is the worst moment to rely on memory |
| Buy it | Nothing available | No product manages a Claude Code session's context budget |
| Build something smaller | The floor fix alone, which is a bug fix regardless of whether the rest is built | Genuinely tempting. It removes the only case where the watchdog is actively wrong, and leaves both conveniences unbuilt |

**Variants of building it**

| Variant | Note |
|---|---|
| A configured window is a floor; observation may still raise it | Recommended, and chosen by the requester. One function, existing tests. Prerequisite for everything else |
| init writes 200,000 unconditionally | Safe **only** after the floor change. Conservative, correct for most sessions, and self-correcting for the rest |
| init asks, defaulting to 200,000 | Rejected by the requester. `keel init -y` in CI would silently write the wrong value for every 1M project, and nothing would correct it |
| init detects the window from the running session | Rejected. `window_for`'s own docstring at `:121-127` records that no field in the transcript carries it, which is why the setting exists |
| SessionStart injects a bounded pointer when `.keel/handoff.md` exists | Recommended for the resume side. Two forms, ~15 tokens, within the hook's stated bound |
| SessionStart injects the handoff contents | Rejected on `hooks/session-start:4-7`. About 1,300 volatile tokens in the cached prefix |
| The stop instruction stops naming `/clear` | Rejected. The keystroke is the user's and the instruction is the only way they learn it is needed |
| Delete the handoff once consumed | Open. It is already git-ignored (`bin/keel:1364-1368`) and already stale-by-design, but a pointer that outlives its work sends the next session to a file about something else |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| Observation only ever proves the window is **larger** | A floor can never be wrong in the dangerous direction | Stated at `lib/context_watch.py:134-136` and it follows from the API refusing oversized requests | Yes |
| 200,000 is the right default to write | Most sessions are not 1M | True of the default model tier. This session is `[1m]`, and so is this repository's setting | Partly, and the floor change makes being wrong cheap |
| A pointer at session start is enough to resume | The model reads the file when told it exists | Nobody has tried it. It is one line and easily tested | **No** |
| The handoff is fresh when the pointer fires | The file relates to the work about to resume | Not guaranteed. A handoff from last week's task would misdirect a new session | **No, and it is the main risk of piece three** |
| 44 tokens of headroom is enough for both open ideas | Only one of them adds | The plain-language record swaps rather than adds, so it costs nothing. This costs ~15 | Yes, if built in that shape |
| SCHEMA_VERSION need not move | `gates.context_window` is already declared | `templates/profile.schema.json:284` declares it, so init writing it is not a new field | Yes |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| A configured window defeats the upward correction | `lib/context_watch.py:142-146` returns before `:149-150` | The idea as stated is harmful without the floor change. This inverts the build order |
| The correction exists because of a real 401,247-token session | `lib/context_watch.py:121-127` | The failure mode is not hypothetical; it was found against a real transcript |
| init never writes `gates.context_window` | `bin/keel:364` | The gap is real and the fix is one field |
| The schema already declares it | `templates/profile.schema.json:284` | No schema version bump, no drift report on existing profiles |
| doctor exists to nag about it | `bin/keel:1271` | The nudge is a workaround for the missing write and could be simplified afterwards |
| The handoff is already written automatically before compaction | `lib/context_watch.py:369-372`, on `PreCompact` | Half of "automatic handoff" already ships. Only the resume side is manual |
| SessionStart already fires on `clear` | `hooks/hooks.json`, matcher `startup|clear|compact` | The hook that would carry the pointer already runs at exactly the right moment |
| `hooks/session-start` never reads the handoff | No `handoff` match anywhere in the file | This is the actual gap, and it is small |
| The hook forbids reading volatile files, with one bounded exception | `hooks/session-start:4-14` | A pointer is permissible under the stated bound; the contents are not |
| The handoff is roughly 1,300 tokens | `lib/context_watch.py:200-235`: 5 prompts at 300 chars, 30 paths | Far too large for the cached prefix |
| The hook is at 356 of a 400 ceiling | Measured 2026-08-18; `tests/validate-skills.sh:283-284` | ~44 tokens for this and `plain-language-chat.md` combined |
| Write, Edit and Read stay allowed at the stop | `lib/context_watch.py:260-263` | The session can always write its handoff. No deadlock to design around |
| The handoff is git-ignored and doctor enforces it | `bin/keel:1364-1368` | Nothing here risks committing session state |

## Open questions

1. **Floor or ceiling for a configured window?** **Answered 2026-08-18 by the requester: floor.**
   Observation may still raise a configured value. Recorded rather than left open, because the whole
   build order depends on it.
2. **How does the pointer know the handoff is current?** The main unsolved question in piece three,
   and the reason piece three is out of scope in the PRD, where it is `Q3`.
   A mtime compared against the session start, or a session id written into the handoff and checked
   on resume, are both plausible; the second is more honest because `render_handoff` already records
   the session id at `:217`. Until this is settled, piece three should not ship.
3. **Should the handoff be deleted once resumed?** It would make staleness impossible, and it would
   also destroy the record before anyone confirmed the resume worked. Recommended answer: no, and
   solve staleness with the session id instead.
4. ~~**Does 200,000 stay the right default?**~~ **Settled 2026-08-18 in the PRD**, as `CON-03` and
   assumption `A2`: written knowing it understates a 1M session, because the floor change makes
   being wrong recoverable in-session. Recorded here rather than deleted, so the reasoning keeps its
   trace.

5. **Does `KEEL_CONTEXT_WINDOW` get the same floor treatment as the profile key?** Not asked when
   this record was written. **Answered 2026-08-18 by the requester during the PRD: no.** The profile
   key is a floor, the environment variable is absolute, so a hard override survives for testing and
   for a session that knows better. Now `FR-02` and `FR-03`.

6. **What counts as success?** **Answered 2026-08-18: the test suite**, per section 9 of the PRD. No
   live-session measurement is claimed, consistent with `tests/test-context-watch.sh:9-10`.

## Recommendation

**Build it, as three pieces, in order.** First make a configured window a floor that observation may
raise (`lib/context_watch.py:142-150`), which is a bug fix that stands on its own. Then have init
write `gates.context_window: 200000`, which is safe only once the first has landed. Then, separately
and later, have `hooks/session-start` inject a bounded pointer when a current handoff exists.

Why: the gap you named is real and the first two pieces are small, but the order is load-bearing,
because piece two before piece one converts a self-correcting assumption into a permanent wrong
answer. Piece three is worth doing and is not urgent, and it must not carry the handoff's contents
into the cached prefix.

Next: `write-prd` covering pieces one and two together, since neither is useful alone. Piece three
waits on open question 2. Note for whoever writes it: `/clear` itself stays the user's keystroke,
and the stop instruction should keep saying so.

## Not decided here

The wording of the pointer, and how a stale handoff is detected, which is open question 2. Whether
`context_warn_pct` and `context_stop_pct` are also written at init.

Two items that were listed here are now settled in the PRD: doctor's nudge at `bin/keel:1271` is
reworded rather than removed, along with the three other places that document the precedence
(`FR-09`, `FR-10`), and the floor change does get a doctor line saying a configured window can be
raised (`FR-09`). The PRD also added an upper bound of 1,000,000 that this record never considered
(`FR-11` to `FR-13`, `CON-06`).
