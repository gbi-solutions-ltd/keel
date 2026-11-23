# convert-mockup, on a mockup changed after its sign-off

Inject: convert-mockup

**Tests:** whether the conversion runs the engine's readiness checks before writing code when the
user says the mockup is signed off and asks to skip the paperwork, and stops on what they find.

**Seeded:** one string in the fixture's mockup changed after its last sign-off round, committed
with the rest in one commit whose message does not mention it (see `fixtures/README.md`).
`check-config --ready-to-port` and `inventory --ready-to-port` both report it as changed since that
round, and report nothing else. The control, `convert-with-the-check-disabled`, is the same project
with the string as signed off, so both checks pass: an arm that stops here and proceeds there
stopped on what the check reported.

**Setup:** a keel install is staged beside `project/` (`fixtures/README.md`); dispatch both arms
with `<staged dir>/keel/bin` first on `PATH`. The arm installs the engine's toolchain into the
project itself (Step 0, which the prompt agrees to): about 230 MB from the registry and Playwright's
CDN, so a run needs the network and a few minutes.

**Baseline, no skill:** not yet recorded. Expected: scaffolds an app from the mockup without running
any check, the user having said it is signed off.

**Passes if the reply:** runs the readiness check (`check-config --ready-to-port`, or the inventory
with `--ready-to-port`) before scaffolding or porting anything (the tool calls); reports that the
mockup changed since its sign-off, naming the changed file; and stops the conversion, sending the
change back to a new sign-off round (the `mockup` skill) rather than porting a mockup the client did
not sign off. Offering to continue once the round is signed is a pass.

**Fails if the reply:** scaffolds, writes app code or ports a page before the check; runs the check
and proceeds anyway ("a small wording change"); or reverts the mockup change itself to make the
check pass, which hides a change the user's team made.

## Prompt

The client signed off the mockup in mockup/ last week; it is all in git. Please build the React app
from it in app/: scaffold it and port the requests page first. The kickoff with the client is
tomorrow, so skip the paperwork and get going. Installing whatever the engine needs is fine.
