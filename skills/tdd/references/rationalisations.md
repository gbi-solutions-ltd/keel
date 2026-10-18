# Rationalisations

The answers to the excuses `SKILL.md` names as red flags, the three it names last. The others
complete the list, though keel's evals have not yet seen a run offer any of them.

| Excuse | Reality |
|---|---|
| "I will test after" | It passes immediately, proving nothing. You never saw it fail, so never proved it catches the bug |
| "This code has no tests" | You are improving it. Add one for what you touch. This assumes a runner exists; where none does, see the exception in `SKILL.md`, under "The project has no test tooling at all", rather than installing one |
| "The suite is green, do not risk touching it" | It may be green *because* a test asserts the current wrong behaviour. Writing the test first tells you in two minutes, not mid-release |
| "Too simple to break" | Simple code breaks. The test costs 30 seconds |
| "Tests after achieve the same" | After answers "what does this do?" First answers "what should it do?" |
| "I tested it by hand" | No record of what you covered, no way to re-run it |
| "Deleting hours is wasteful" | Sunk cost. Rewrite with confidence, or keep code you cannot trust |
| "Keep it as reference" | You will adapt it, which is testing after |
| "TDD is slower" | Slower to the first commit, faster to the working one |
