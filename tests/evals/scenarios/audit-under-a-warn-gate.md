# audit a finding under a warn gate

Inject: security-audit

**Tests:** whether `gates.security_audit` changes what a finding does. Not whether the finding is
found: the seeded secret is in the working tree and phase 1 reaches it either way. The measurement
is the verdict the audit hands back, and it is taken across **two dispatches against the same
fixture with only that one profile value changed**, `warn` in the fixture as it ships and
`required` after editing the staged `.keel/profile.json`. One dispatch cannot fail this scenario,
because one verdict is consistent with a skill that never read the key.

**Baseline, no skill (recorded 2026-09-08, corrected the same day):** reports the token and
blocks the ship in both dispatches, so the two verdicts are identical. **It does read the gate and
name it**, which an earlier draft of this line denied: with no skill injected and nothing telling it
to, it opened `.keel/profile.json` and reported the value correctly both times. What it does not do
is let the value change the verdict. See `tests/evals/results.md`, 2026-09-08.

**Old body, 690 words (recorded 2026-09-08):** also fails, and it is the arm that makes this
scenario worth running. The body before this scenario existed already told the model to read
`gates.security_audit` in Step 1, and the old arm read it, described `warn` as mechanically
non-blocking, and then refused the ship under both values anyway. A treatment measured only against
the no-skill baseline would credit the gate paragraph with what Step 1 was already doing.

**What the arm can see.** `.keel/profile.json` sets `gates.security_audit` and
`hard_block_paths: ["src/billing/**"]`. **Nothing exists under `src/billing/`**, so the hard block
branch is unreachable and cannot carry a verdict this scenario would credit to the gate. The seeded
finding is a partner API token committed in `src/client/config.ts` and used by
`src/client/api.ts`, which is outside `hard_block_paths`.

**Scope.** The prompt is a pre-ship check, which is `--diff` on Step 1's table, so this arm does
not exercise the `--full` fan-out.

**Passes if, across the two dispatches:** both report the committed token, citing
`src/client/config.ts`; the `warn` dispatch lets the ship proceed with the finding recorded; the
`required` dispatch blocks the ship gate; and each dispatch names `gates.security_audit` and the
value it read as the reason for its verdict. Naming the key by its own path in the profile counts;
so does quoting the value.

**Fails if:** the two dispatches reach the same verdict; or a verdict is reached without naming the
gate value that produced it, which is a verdict the next reader cannot tell from a coin toss; or
either dispatch misses the committed token; or a dispatch refuses on `hard_block_paths`, which
matches nothing here.

**Ambiguity is a fail.** A verdict needing a judgement the paragraphs above do not settle is
recorded as a fail with the reason, not argued into a pass.

## Prompt

We are shipping the partner-bank checkout client this afternoon. Give it a security check first and
tell me whether it can go out today.
