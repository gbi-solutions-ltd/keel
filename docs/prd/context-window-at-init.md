# PRD: context window set at init, and correctable by observation

| | |
|---|---|
| Status | approved |
| Mode | from-idea |
| Author | Bernard, with Claude |
| Date | 2026-08-18 |
| Derived from | `docs/ideas/context-window-at-init.md` (uncommitted, working tree at `7e03a08`), and this conversation |
| Approved by | Bernard, 2026-08-18 |

> Requirement IDs are permanent. `write-user-stories` and `write-plan` trace to them.
> Retire an ID rather than renumbering.

## 1. Executive summary

Every keel project currently needs `gates.context_window` typed into its profile by hand, and until
somebody does, the context watchdog assumes a 200,000 token window and `keel doctor` prints a nudge
on every run. This PRD covers writing that key automatically at `keel init`, and the change that has
to land first to make doing so safe: an explicitly configured window must become a floor that
observation can raise, rather than a ceiling that silences the watchdog's only self-correcting
mechanism. It also bounds the value above, at the largest window any Claude model offers, so a
mistyped setting cannot silence the watchdog in the other direction, and it brings the four places
that document the precedence back into line with what the code does. It is for anyone running keel on a project, and it matters now because two of the three
ideas raised on 2026-08-18 trace back to this key being unset and undocumented.

The automatic handoff described in the second half of the source idea is **not** in this PRD. Its
resume side is buildable and is deferred to a follow-up; the `/clear` keystroke it depends on cannot
be automated at all.

## 2. Problem statement

A keel project's context watchdog protects against a session running to its limit mid-task and
losing the reasoning that got it there. To do that it needs to know how large the window is, and
there is no reliable way to read it: a genuine 1M session records its model as plain
`claude-opus-5`, with no marker, and no field in the transcript names the window
(`lib/context_watch.py:121-127`). The only correct mechanism is the explicit setting, and nothing
writes it.

**What that costs today.** `write_profile` emits the gates object at `bin/keel:364` and
`context_window` is not among its eight keys, so no profile has it unless a human added one. This
repository's own profile carries `"context_window": 1000000`, added by hand.  `bin/keel:1271` exists
purely to tell the next reader to do the same: "If sessions here use a larger context, set
gates.context_window in .keel/profile.json". The residual error, recorded in the code, is that a 1M
session below 200,000 tokens is assumed to be in a full 200,000 window and warned early.

**Why the obvious fix is dangerous, which is the real finding.** `window_for` returns a configured
value immediately at `lib/context_watch.py:142-146`, before reaching the upward observation
correction at `:149-150`. Today an unset project self-corrects: occupancy above a tier is proof the
window is larger, because the API would have refused the request otherwise. Writing 200,000 into
every profile would remove that. A 1M session in such a project would hard-stop at 170,000 tokens
and never lift, with the user's only escape being to edit the file keel had just written. That is
the precise failure `lib/context_watch.py:125-127` records the function as having been rewritten to
prevent, found against a real 2.4MB transcript holding 401,247 tokens.

## 3. Goals and non-goals

**Goals**

- A newly initialised project has a working context window setting without anyone editing JSON.
- A configured window that is too small stops being able to permanently disable the watchdog's
  protection of large sessions.
- The value keel writes is safe to be wrong, because being wrong is recoverable in-session.
- A mistyped window cannot disable the watchdog silently in either direction.
- Every place that documents how the window is decided says the same, correct thing.

**Non-goals**

- Automating `/clear`. It is a user keystroke and no hook output can produce it.
- Injecting the handoff, or a pointer to it, at session start. Deferred, see Out of scope.
- Detecting the window. `lib/context_watch.py:121-127` records that it cannot be read, which is why
  the setting exists.
- Changing the warn and stop thresholds, or how occupancy is counted.

## 4. Users and personas

| Who | What they are trying to do | What they know |
|---|---|---|
| A developer running `keel init` on a new project | Get a working profile without reading keel's source | That a profile exists. Not that `gates.context_window` does: it is undocumented, per `docs/ideas/profile-key-documentation.md` |
| A developer in a long session | Not lose their work to a mid-task compaction | Only what the watchdog tells them, when it fires |
| The watchdog itself, as a consumer of the profile | Decide whether to stay silent, warn, or stop | `gates.context_window`, `KEEL_CONTEXT_WINDOW`, the model string, and observed occupancy |
| `keel doctor` | Report which window is in use | The profile key only (`bin/keel:1267-1271`) |

## 5. Functional requirements

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-01 | `gates.context_window` must act as a floor: the effective window is the larger of the configured value and the window that observed occupancy supports. | confirmed | Chosen by Bernard, 2026-08-18. Current behaviour at `lib/context_watch.py:142-150` returns the configured value before the correction |
| FR-02 | `KEEL_CONTEXT_WINDOW` must be used exactly as set, subject only to FR-11, and must never be raised by observation. | confirmed | Chosen by Bernard, 2026-08-18, to keep a hard override for testing and for a session that knows better |
| FR-03 | Where both `KEEL_CONTEXT_WINDOW` and `gates.context_window` are set, the environment variable must determine the window. | confirmed | Follows from FR-02; preserves the existing precedence at `lib/context_watch.py:142` |
| FR-04 | `keel init` must write `gates.context_window` with the value `200000` into the gates object of a profile it creates. | confirmed | Requested by Bernard, 2026-08-18. Gates object at `bin/keel:364` |
| FR-05 | Re-running `keel init` on a project whose profile already sets `gates.context_window` must leave that value unchanged. | inferred | `merge_profile` at `bin/keel:290` already gives a non-empty human value precedence. Asserting it so the guarantee is not lost later |
| FR-06 | After `keel init --force` on a project whose profile set a different `gates.context_window`, the value must be `200000`. | inferred | Consistent with `--force` replacing the profile at `bin/keel:385-389`. Safe only because FR-01 makes the resulting value self-correcting |
| FR-07 | The watchdog must remain silent below the warn threshold in a project where the written value understates the true window. | confirmed | The cost argument at `hooks/context-watch:9-12`. This is the observable consequence of FR-01 |
| FR-08 | `keel doctor` must continue to report the window in use and its source. | inferred | Existing behaviour at `bin/keel:1267-1271`; no requirement to change it, and losing it would hide FR-01's effect |
| FR-09 | For a profile that sets `gates.context_window`, `keel doctor` must state that the value is a floor which observation can raise. | confirmed | Bernard, 2026-08-18, answering Q1. The current message at `bin/keel:1269` names the value and its source only, which stops being the whole truth under FR-01 |
| FR-10 | Every location that documents the window precedence must describe the behaviour FR-01 to FR-03 and FR-11 define. Those locations are the `gates.context_window` description at `templates/profile.schema.json:287`, both doctor messages at `bin/keel:1269` and `:1271`, and the priority list in `window_for`'s docstring at `lib/context_watch.py:130-140`. | confirmed | Bernard, 2026-08-18: "let's re-word so that the documentation is up to date". All four currently state that a configured value simply wins |
| FR-11 | The effective window must never exceed 1,000,000 tokens. A configured value above that, from either source, must be treated as 1,000,000. | confirmed | Bernard, 2026-08-18, answering Q2: bound it by the largest window that exists, else 1M. Those are the same number, see CON-06 |
| FR-12 | The bound in FR-11 must be the existing `LONG_WINDOW` constant rather than a second literal. | inferred | `lib/context_watch.py:28`. One constant then governs both the observed ceiling at `:148-150` and the configured ceiling, so a larger window ships as one edit |
| FR-13 | When a configured value is reduced by FR-11, `keel doctor` must say so and name both values. | inferred | A silent clamp is the failure mode FR-11 exists to prevent, relocated rather than removed |

## 6. Non-functional requirements

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| NFR-01 | The floor computation must add no filesystem or network reads to `window_for`. | inferred | It already receives `configured` and `observed` as arguments (`lib/context_watch.py:120`). The hook runs on every prompt and every tool call |
| NFR-02 | This change must add zero tokens to what `hooks/session-start` injects. | confirmed | Piece three is out of scope. The hook measured 356 estimated tokens against a 400 ceiling on 2026-08-18 (`tests/validate-skills.sh:283-284`) |
| NFR-03 | The watchdog must continue to do nothing when `python3` is absent, rather than reporting an error. | inferred | `hooks/context-watch:14-16, 22` |
| NFR-04 | Every existing assertion in `tests/test-context-watch.sh` must still pass unmodified after FR-01. | inferred | Verified 2026-08-18: every configured value in that file (500000 at `:86`, 1000000 at `:91`) exceeds the observed occupancy in its fixture, so the floor rule yields the same result |

## 7. Constraints

| ID | Constraint | Imposed by |
|---|---|---|
| CON-01 | `SCHEMA_VERSION` must not move for this change. `gates.context_window` is already declared at `templates/profile.schema.json:284`, so writing it adds no field. | The existing schema, and the drift rule at `tests/validate-skills.sh:351-365` |
| CON-02 | Between the true window and 1,000,000, a configured value that overstates the window cannot be corrected downward. FR-11 bounds the damage but does not eliminate it: setting 1,000,000 on a 200,000 session still silences the watchdog. | The platform: occupancy proves a lower bound on the window and never an upper one (`lib/context_watch.py:134-136`) |
| CON-03 | `200000` is correct for the default model tier and understates a 1M session. It is written knowing it is sometimes wrong, because FR-01 makes being wrong recoverable. | The absence of any readable window field (`lib/context_watch.py:121-127`) |
| CON-04 | `/clear` cannot be triggered by keel. No hook output clears a session and a plugin cannot start one. | Claude Code's hook interface |
| CON-05 | The watchdog is advisory infrastructure, not a correctness gate, and must fail silently. | `hooks/context-watch:14-16` |
| CON-06 | 1,000,000 is the largest context window any current Claude model offers. Verified 2026-08-18: Fable 5, Opus 5, Opus 4.8, 4.7 and 4.6, Sonnet 5 and Sonnet 4.6 are all 1M; Haiku 4.5 is 200K. | Anthropic's published model table. It is also already the highest value the watchdog can reach by observation (`LONG_WINDOW`, `lib/context_watch.py:28`, reached at `:148-150`), so FR-11 imposes no ceiling that the observed path did not already have |

## 8. Observed but not required

Not applicable: this is `from-idea` mode. The section exists for `from-repo`, where the job is
separating what the code does from what it must do.

One note that would otherwise belong here: `bin/keel:1271`'s nudge is not a requirement, it is a
workaround for FR-04 being absent. Whether it is reworded once FR-04 lands is Q1.

## 9. Success metrics

The test suite is the measure, chosen by Bernard on 2026-08-18. Specifically, all of:

| Measure | Source | Target |
|---|---|---|
| A configured window smaller than observed occupancy is raised to the observed tier | New assertion in `tests/test-context-watch.sh` | Passes |
| A configured window larger than observed occupancy is left alone | New assertion, same file | Passes |
| `KEEL_CONTEXT_WINDOW` is honoured exactly, including below observed occupancy | New assertion, same file | Passes |
| A profile produced by `keel init` on a fixture contains `gates.context_window` | New assertion in `tests/test-keel.sh`, alongside the existing `response_style` check at `:1537-1539` | Passes |
| A profile with a hand-set window survives `keel init` | New assertion, same file | Passes |
| A configured window above 1,000,000 is reported as 1,000,000, from both sources | New assertion in `tests/test-context-watch.sh` | Passes |
| `keel doctor` names both values when a configured window is clamped | New assertion in `tests/test-keel.sh` | Passes |
| No location listed in FR-10 still describes a configured window as simply winning | `grep` over the four sites | Zero matches |
| Projects needing a manual `context_window` edit after init | `keel init` on a fixture | Zero |

No live-session measurement is claimed. `tests/test-context-watch.sh:9-10` already records that
whether Claude Code calls the hook with the assumed fields cannot be proven by this suite, and this
PRD does not change that.

## 10. Milestones

Unknown, needs a decision. No deadline was given. Bernard has said a merge to `main` and a release
follow this batch of work, which orders it but does not date it.

## 11. Out of scope

| Excluded | Why |
|---|---|
| Injecting a handoff pointer at session start | Piece three of the source idea. It depends on detecting whether a handoff is current, which is unsolved (`docs/ideas/context-window-at-init.md`, open question 2). Building it before that is how a session gets pointed at last week's work |
| Injecting the handoff's contents anywhere | About 1,300 tokens of the most volatile file keel writes, into a prefix that `hooks/session-start:4-7` requires to be byte-identical forever |
| Automating `/clear` | CON-04 |
| Writing `context_warn_pct` or `context_stop_pct` at init | Both are already documented and both have working defaults. Adding them is a separate argument about whether init writes optional keys generally |
| Removing `bin/keel:1271` | The message stays, for every profile that predates FR-04. Its wording is now in scope as part of FR-10 |
| Documenting `gates.context_window` for users | Genuinely needed, and it is `docs/ideas/profile-key-documentation.md`'s job. Doing it here would put one key in a second place |

## 12. Assumptions

| # | Assumption | Falsified if | Checked |
|---|---|---|---|
| A1 | Observed occupancy above a tier proves the window is larger than that tier | A request could succeed while exceeding the window | Yes. Stated at `lib/context_watch.py:134-136`, and it follows from the API rejecting oversized requests |
| A2 | `200000` is the right conservative default to write | Most sessions in keel projects use a larger window | Partly. True of the default model tier; this session and this repository are both 1M |
| A3 | No existing test breaks under the floor rule | Any current fixture configures a window below its observed occupancy | Yes, verified 2026-08-18. See NFR-04 |
| A4 | `merge_profile` preserves a hand-set value on re-init | A non-empty existing value could be replaced by the generated one | Yes, `bin/keel:290` |
| A5 | Writing one more key does not make the generated profile invalid | The profile fails its own JSON check at `bin/keel:381` | No. Cheap to verify during build |
| A6 | A developer benefits from the watchdog being right rather than merely quiet | The warn and stop thresholds are themselves wrong | No. Out of scope, and unchanged by this PRD |
| A7 | No legitimate session has a window above 1,000,000 | A Claude model ships with a larger context window | Yes, as of 2026-08-18. It expires the day that changes, which is why FR-12 makes it one constant. A larger model would need `LONG_WINDOW` moved, and the observed path would need it anyway |
| A8 | Applying FR-11 to `KEEL_CONTEXT_WINDOW` as well as the profile key is what was wanted | Bernard intended the bound for the written key only | **No.** Read from "if there's value beyond which a context window can't be" as a property of windows rather than of one key. Flagged for approval |

## 13. Open questions

| # | Question | Needs | Blocks |
|---|---|---|---|
| Q1 | ~~Once FR-04 lands, is `bin/keel:1271`'s nudge reworded, kept as-is for older profiles, or removed?~~ **Answered 2026-08-18: reworded, and so is every other place that documents the precedence.** Now `FR-09` and `FR-10` | Answered | Was: nothing |
| Q2 | ~~Does a configured window need an upper sanity bound, so a typo of `200000000` cannot silence the watchdog entirely?~~ **Answered 2026-08-18: yes, bounded by the largest window that exists, which is 1,000,000.** Now `FR-11` to `FR-13`, `CON-06` | Answered | Was: nothing |
| Q5 | ~~Does the FR-11 bound apply to `KEEL_CONTEXT_WINDOW`, or to the profile key only?~~ **Answered 2026-08-18: both.** Flagged in the approval request and approved as written. `A8` stands as the reasoning; `S-02`'s second scenario is where it is now asserted | Answered | Was: `FR-02`, `FR-11` |
| Q3 | How is a stale handoff detected, so a session-start pointer cannot send a new session to last week's work? | Bernard | The follow-up PRD for piece three. Not this one |
| Q4 | Does `keel init` write optional keys generally, or is `context_window` a special case justified by the watchdog? | Bernard | Nothing here, but it decides `docs/ideas/stack-plugins-on-existing-repos.md`'s shape too, since `plugins.recommended` is the same question |

Q1 and Q2 were answered by Bernard on 2026-08-18 after the first draft, and their answers are now
requirements rather than questions. The rows are struck through rather than deleted so the decision
keeps its trace. Q3 and Q4 belong to other documents and are cross-referenced so they are not
answered twice. Q5 is new, raised by writing Q2's answer down.
