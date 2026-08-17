# Terse By Default Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** make short replies the default in every keel project, written into the profile, with
verbose as the thing the user chooses rather than the thing they get.

**Stories:** none. Scope is a direct instruction, 2026-08-16: "let keel init set output style to be
short by default and also write the setting/profile accordingly. the user should instead decide if
they want verbose output." This reverses decision 1 of
`docs/plans/2026-08-16-terse-chat-output.md`, which chose opt-in, and takes open decision 10.
**ADRs:** none bind. ADR-0001 governs skill bodies and no skill body changes.
**Architecture:** a new profile key, `conventions.response_style`, default `terse`, written by
`keel init`. `hooks/session-start` reads it and appends one short paragraph when it is `terse`. The
already-shipped `output-styles/keel-terse.md` stays as the machine-level alternative and is
unchanged.

## Why not `outputStyle` in `.claude/settings.json`

That was the obvious reading of the instruction and it is not available, for a reason that was
checked rather than assumed.

**The style's addressable name cannot be determined from here.** Three sources were tried on
2026-08-16: the plugins reference does not specify whether a plugin's output style is namespaced the
way agents are (`my-plugin:code-reviewer`) or referenced bare; `claude --debug -p` logs nothing about
output style loading; and the one official plugin that ships this behaviour,
`claude-plugins-official/explanatory-output-style`, **has no `output-styles/` directory at all** and
recreates the style as a SessionStart hook instead.

`bin/keel:470` already records what writing an unverified name into `settings.json` costs: it "lands
in settings.json, fails to resolve, and the user distrusts the whole file". So this plan uses the
mechanism Anthropic's own plugin uses for the same problem, and open decision 10 stays open with the
single observation that would let `keel init` write the settings key as well.

The user-facing outcome is the one asked for either way: terse by default, verbose on request.

## Global constraints

Copied from `.keel/profile.json` and the repository conventions. Every task inherits these.

- Verify commands: test `tests/run-tests.sh`, one test `tests/{name}`, lint
  `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`
- There is no format, typecheck, build or e2e command in this project.
- **The full suite takes upwards of ten minutes.** Run it in the background, never piped to `tail`.
- **The SessionStart injection is 300 tokens against a 250 target and a 400 hard ceiling**, enforced
  by `tests/validate-skills.sh:230` and budgeted in `docs/05-token-and-memory-design.md`. Task 2 has
  roughly 100 tokens, about 360 characters, to spend. Measure, do not estimate.
- Never start on `main`. Lands on `sandbox`.
- Conventional commits, title and body only. No attribution footers, no robot emoji, no em dashes.
- `gates.done_verified` is `required` here, so the guard refuses to end a turn that edited code
  without running `tests/run-tests.sh`.

## Decisions taken while planning

1. **`terse` is the default and `verbose` is the opt-out**, per the instruction. A profile with no
   `response_style` key is treated as `terse`, so existing projects get the new behaviour on the
   next session without re-running `init`, and `keel init` writes the key explicitly so it is
   visible and editable rather than implied.
2. **The hook reads the profile, which bends its own central rule, and the bend is bounded.**
   `hooks/session-start` says "STATIC IS THE POINT ... no reading of any file that changes", because
   one volatile byte costs the prompt cache on every request. A profile read is not volatile: the
   output has exactly two forms, it changes only when someone deliberately edits the key, and that
   costs one cache miss, the same as editing CLAUDE.md. The hook's header is amended to state the
   exception and its bound rather than leaving the next reader to find a contradiction.
3. **The injected text is an instruction, not documentation.** It does not mention the profile key
   or how to turn it off. That sentence would sit in the prefix of every request in every session to
   tell the model something only the user acts on. It goes in the README.
4. **`output-styles/keel-terse.md` is not deleted or forced.** It remains selectable in `/config`
   for anyone who wants it across all projects rather than keel ones. Its `force-for-plugin` stays
   false: that flag overrides the user's own setting invisibly and cannot be declined per project,
   which is the opposite of what this instruction asks for.

---

### Task 1: The profile key

**Files:**
- Modify: `bin/keel`
- Modify: `templates/profile.schema.json`
- Modify: `templates/keel-profile.example.json`
- Modify: `.keel/profile.json`
- Modify: `tests/test-keel.sh`

**Interfaces:**
- Produces: `conventions.response_style`, values `terse` and `verbose`, consumed by task 2's hook

**Done when:** `tests/test-keel.sh` passes including the new case, and
`python3 -c "import json;print(json.load(open('.keel/profile.json'))['conventions']['response_style'])"`
prints `terse`.

- [x] **Step 1: Write the failing test**

In `tests/test-keel.sh`, beside the other `init` assertions, using the file's existing `fixture`,
`ok` and `bad` helpers:

```bash
# Terse is the default a project gets without asking. The key is written explicitly rather than
# left absent and defaulted, so a reader can see it and change it without knowing it exists.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
python3 -c "
import json,sys
c=json.load(open('$d/.keel/profile.json')).get('conventions',{})
sys.exit(0 if c.get('response_style')=='terse' else 1)" \
  && ok "init writes conventions.response_style=terse" \
  || bad "response_style" "init did not write terse: $(python3 -c "import json;print(json.load(open('$d/.keel/profile.json')).get('conventions'))")"
rm -rf "$d"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL, `init did not write terse`, with the conventions block printed and no
`response_style` in it.

- [x] **Step 3: Write the key**

In `bin/keel`, find the `conventions` line in the profile writer (grep for `commit_style`) and add
`"response_style": "terse"` to it, with a comment in the file's voice saying terse is the default
and `verbose` is the opt-out.

In `templates/profile.schema.json`, add to `conventions.properties`:

```json
"response_style": {
  "enum": ["terse", "verbose"],
  "default": "terse",
  "description": "terse keeps conversation replies short and leaves artifacts at full detail; the SessionStart hook injects the rule. verbose turns it off. Absent is treated as terse."
}
```

In `templates/keel-profile.example.json`, add `"response_style": "terse"` to `conventions`.

In `.keel/profile.json`, add the same, so this repository runs what it ships.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`. Expected: PASS, including the new case.

Run the profile's lint command. Expected: clean.

- [x] **Step 5: Commit**

```bash
git add bin/keel templates/ .keel/profile.json tests/test-keel.sh
git commit -m "feat(profile): conventions.response_style, terse by default"
```

---

### Task 2: The hook injects the rule

**Files:**
- Modify: `hooks/session-start`
- Create: `tests/test-session-start.sh`
- Modify: `tests/run-tests.sh`

**Interfaces:**
- Consumes: `conventions.response_style` from task 1
- Produces: the injected paragraph, measured against the 400-token ceiling

**Done when:** `tests/test-session-start.sh` passes all four cases, `tests/validate-skills.sh`
reports no ceiling failure, and `bash hooks/session-start | wc -c` divided by 3.6 is under 400.

- [x] **Step 1: Write the failing test**

Create `tests/test-session-start.sh`. Four cases, each running the hook with a temp profile as cwd
and asserting on the emitted `additionalContext`:

1. `response_style` absent: the brevity text **is** present, because absent means terse.
2. `response_style: "terse"`: present.
3. `response_style: "verbose"`: **absent**, and the routing text still present. This is the opt-out
   and it is the case most likely to be got wrong, because a hook that ignores the key looks
   identical to one that works until someone opts out.
4. No profile at all: the hook still emits valid JSON with the routing text, because a session
   outside a keel project must not break.

Assert the JSON parses in every case. A hook emitting malformed JSON fails the session start.

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-session-start.sh`
Expected: FAIL on cases 1 and 2, which expect text the hook does not yet emit. Cases 3 and 4 pass
against the current hook, which is correct and worth noting: they are regression cover, not new
behaviour.

- [x] **Step 3: Write it**

Amend the hook header. The existing paragraph says no file that changes may be read; add the
exception and its bound, in the file's voice: the profile is read for one key, the output has two
forms, and a change costs one cache miss rather than one per request.

Walk up for `.keel/profile.json` the way `hooks/sensitive-guard` does. Read the key with a builtin
`case` match on the file text, not `python3`: this hook runs before every session and must not
depend on an interpreter or pay its startup.

Append to `CONTEXT` when the style is terse. Draft, to be measured not assumed:

> Replies stay brief; artifacts stay full. Say what changed, where it is, and what needs a decision.
> Never omit which checks ran or were skipped, assumptions, deviations, or a `Done when` command's
> output.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-session-start.sh`. Expected: PASS, four cases.

Measure: `bash hooks/session-start | wc -c`, divide by 3.6. Expected: under 400, and the number
goes in the commit message. If it is over, cut the draft rather than raising the ceiling: the rule
at `docs/standards.md` is that a gate is never weakened so this repository can pass it.

Register in `tests/run-tests.sh`, then run the suite in the background and the lint command.

- [x] **Step 5: Commit**

```bash
git add hooks/session-start tests/test-session-start.sh tests/run-tests.sh
git commit -m "feat(session-start): inject the brevity rule unless the profile opts out"
```

---

### Task 3: Documentation and the reversed decision

**Files:**
- Modify: `README.md`
- Modify: `docs/05-token-and-memory-design.md`
- Modify: `docs/07-open-decisions.md`
- Modify: `docs/ideas/concise-responses.md`
- Modify: `docs/plans/2026-08-16-terse-chat-output.md`

**Done when:** `tests/run-tests.sh` is green and `grep -c response_style README.md` is at least 1.

- [x] **Step 1: There is no test for this**

Prose. The `Done when:` line checks the README mentions the key and that the shipped-file scanners
still pass, not that the sentences are true. That is review.

- [x] **Step 2: README**

Replace the "Optional: shorter replies" subsection written in the previous plan. It now says the
opposite of what ships: replies are short by default, and the way to get the old behaviour is
`"response_style": "verbose"` in `.keel/profile.json`. Keep one line noting the `/config` output
style as the machine-wide alternative for non-keel projects.

- [x] **Step 3: `docs/05-token-and-memory-design.md`**

The section added last commit says the style "costs zero until a user selects it", which is no
longer the shipped default. Correct it: the rule now arrives through the SessionStart injection, it
costs the measured number of tokens in every request of every session, and that cost is the price of
it being on by default. Record the new injection measurement in the budget table.

- [x] **Step 4: `docs/07-open-decisions.md`**

Open decision 10 is now partly resolved. Record: terse by default is taken and shipped through the
hook; writing `outputStyle` into `settings.json` is still open on the same single observation, and
is now an optimisation rather than the mechanism, because the behaviour no longer depends on it.

- [x] **Step 5: Correct the two documents this reverses**

`docs/ideas/concise-responses.md` recommends opt-in and its variants table rejects anything
automatic. `docs/plans/2026-08-16-terse-chat-output.md` decision 1 chose opt-in. Both are now wrong
as written. Amend each with the reversal, the date, and who made it. A superseded document that
still reads as current is worse than one that is deleted, because the next reader trusts it.

- [x] **Step 6: Run the suite and commit**

Run `tests/run-tests.sh` in the background and the lint command. Both green.

```bash
git add README.md docs/
git commit -m "docs: terse is the default, and what that reverses"
```

## Open questions

1. **The settings.json name**, unchanged from open decision 10. One observation settles it: restart
   a session with this version installed, open `/config`, read the name under Output style.
2. **Does the injected rule actually shorten replies?** Nothing measures reply length, and
   `docs/05` now says so. The eval scenarios assert that gates are announced, so they would catch
   the failure that matters, which is a reply going short by dropping a skipped check.
