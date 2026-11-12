# Plan execution is slow, and most of it is not the work

**Raised:** 2026-11-11, by Bernard, from keel running in two sample projects
(`posta-accounts-billing-api` and `sms-gateway`).
**Agreed:** 2026-11-11, by Bernard: all five changes below, item 1 as suite checkpoints and item 2
as leaner reports plus a plan run that carries on through compaction.

## What was measured

Two read-only investigations, 2026-11-11. posta from its 29 session transcripts; sms-gateway from
git and plan tick notes only, because none of its transcripts are on this machine.

posta's cleanest run, `2026-11-09-tax-codes-and-bank-accounts` (10 tasks, 294 minutes, about 29 per
task):

| Where the time went | Share of wall clock |
|---|---|
| Implementers | 63% (median 14 min, p90 30) |
| Full `go test ./...` inside implementers | 22% (14 runs over 11 implementer dispatches) |
| Spec review | 15% (median 3 min) |
| Rework rounds | 13% (23% of November tasks took a second round) |
| Waiting on the person | 10% |
| Quality review | 3% |
| Coordinator writing dispatches | about 2% (median 11 s each) |

The rows overlap: suite runs and rework sit inside implementer and review time.

sms-gateway, estimated from gaps between task commits: about 12 minutes per task on its follow-ups
plan, 35 on operators, 70 on walking-skeleton.

## Findings and the change each one gets

1. **The suite runs twice per task.** posta's `api/v1test` package takes 244 of the suite's ~300
   seconds and holds nearly every task's tests, so selecting tests by changed package
   (`verify.test_affected`, ADR-0009) would still run it every time. Each implementer is a fresh
   `keel:tdd` session, so it pays one `verify.test` for its first start record and one at its unit
   boundary. **Change:** under `execute-plan` the whole suite runs at checkpoints, every N tasks and
   at the plan's end, run by the coordinator; the implementer is handed the last checkpoint's record
   as its start record and ends on its own `Done when:` plus lint. Recorded as ADR-0017.
2. **Context stops hand the run back to the person.** posta had 17 `/clear` hand-offs against one
   compaction, 8 to 9 minutes each with the person needed at the keyboard. The window is genuinely
   200k (largest context seen 162,732 tokens, session `07cd31ed`). Subagent notifications were the
   largest part of the coordinator's context: 186,525 characters over 10 tasks, because the brief
   asks for the exact output of every verify command. **Change:** reports quote summary lines and
   failures, not whole outputs; at context-watch's stop threshold a coordinator of a plan run writes
   the handoff, names the plan and its next step, and carries on, since `keel plan status` restores
   its place after compaction.
3. **A rejected full-loop task starts again from nothing.** The light loop already allows one scoped
   fix pass. **Change:** the full loop gets one too, before falling back to discard and redispatch.
4. **A review was dispatched on a half-finished tree.** Session `07cd31ed`, 2026-11-09: the task 7
   implementer notified "finished" at 12:07:31, the spec review went out at 12:07:45, and the
   implementer woke on its own background work and finished again at 12:15:45, so the task needed a
   second review. Task 9 repeated it (12:59:09, then 13:04:50). **Change:** subagents run commands
   in the foreground and do not end a turn with work still running; the coordinator reviews only a
   report that ends with its `git status --porcelain` line, and voids a review whose author notifies
   again.
5. **`done-guard` counts edits outside the repository.** A read-only investigation agent writing
   scratch scripts under the system temp directory was told to run keel's whole suite. **Change:**
   an edit whose path resolves outside the repository is not code for this hook.

## Not changed here

- posta's own profile: suite speed in `api/v1test` is that project's work.
- Concurrent batches: posta's tasks all touch `docs/openapi.yaml` or `README.md` and one test
  database, so `keel plan batches` correctly runs each alone.
- Sonnet implementers: two dispatches in the data, an experiment rather than a finding.
- sms-gateway's walking-skeleton rework (4 and 5 rounds on security tasks, plan amended between
  rounds) points at under-specified tasks, a `write-plan` question.
- Laptop sleep, Docker disk and the person being away inflate the raw numbers; keel cannot fix them.
