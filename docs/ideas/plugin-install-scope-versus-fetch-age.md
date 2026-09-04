# Idea: a `/plugin install` that did not take is a scope pin, not a stale fetch

| | |
|---|---|
| Raised by | The coordinating session, 2026-09-02, from the install that did not reach the sessions it was run for. Decided 2026-09-03 |
| Status | **recorded, not planned.** A cause written down because every visible signal names a different one |
| Recommendation | Record it and add no check yet. The cost of the wrong diagnosis is known and small; the cost of a check that gets scope precedence wrong is not |
| Next | nothing. Revisit if this costs a second debugging session, or the next time `doctor` grows a plugin check |

## The problem

`/plugin install keel@gbi` was run to pick up 0.17.0, and the sessions it was run for went on
loading 0.16.1 skills. Every signal a user can reach says the machine is current: the marketplace
clone was fetched minutes earlier, `keel doctor` reports it green in the same run, and
`installed_plugins.json` genuinely holds 0.17.0.

**The stale thing is the scope of the entry that moved, not the age of the fetch.**
`~/.claude/plugins/installed_plugins.json` keys `keel@gbi` to a list of installations, one per
scope, and an install writes the entry for the scope it ran in. The user-scope entry moved to
0.17.0. Nine of the ten project-scope entries did not.

## What was read, 2026-09-03

`~/.claude/plugins/installed_plugins.json`, eleven entries under `keel@gbi`. Project paths are
omitted deliberately: the entries are one per project on this machine and the names are not this
repository's to write down.

| Scope | Entries | Version | `installPath` root | `lastUpdated` |
|---|---|---|---|---|
| user | 1 | 0.17.0 | `~/.claude/plugins/cache/` | 2026-09-02T10:21Z |
| project | 9 | 0.16.1 | `~/.claude-shared/plugins/cache/` | 2026-08-20 to 2026-08-29 |
| project | 1 | 0.17.0 | `~/.claude/plugins/cache/` | 2026-09-02T19:01Z |

The nine carry `gitCommitSha` `d86c5f0`; the two 0.17.0 entries carry `8b3e4f2`. The tenth project
entry has `installedAt` equal to its `lastUpdated`, which is the shape of an entry created that
evening rather than an old entry moved forward, and it is the only project on this machine that
would load 0.17.0 today.

**This is not a stale fetch, and that is an observation rather than an argument.** 0.17.0 is already
unpacked at `~/.claude-shared/plugins/cache/gbi/keel/0.17.0`, the same cache root the nine pinned
entries read 0.16.1 from. Nothing needs fetching. The bytes are on disk in the right place, and the
JSON points nine projects at the older directory sitting beside them.

## Why doctor cannot see it

`keel doctor --fast`, run in this repository on 2026-09-03 while all nine entries were pinned:

```
ok    the gbi marketplace list was fetched 0 day(s) ago, recent enough not to warn. That is fetch
      age and not currency: a release landing since then is not visible here either.
```

That line is correct and it is the whole of what `doctor` knows about plugin freshness. It reads
`known_marketplaces.json` and its `lastUpdated`, which records when the marketplace clone was last
pulled, and `bin/keel` already states in its own comment that this measures fetch age rather than
staleness. A scope pin is a third thing: the clone is current, the fetch is current, the release is
present on disk, and the entry a session resolves through is a fortnight behind. Nothing reads
`installed_plugins.json` for a version at all.

## Why the version line cannot report it either

`hooks/session-start` prints the version of the plugin copy the session loaded, added in `09e5ddd`
for exactly this class of drift. It cannot report this instance of it, for two reasons, and the
second outlives the first.

**Today, no copy carries the line.** `09e5ddd` is unpushed: `git branch -r --contains 09e5ddd` names
no remote branch and `git tag --contains 09e5ddd` is empty. The 0.17.0 cache copy's
`hooks/session-start` holds no version string, so the line is absent from the newest release as well
as from 0.16.1. The decision that commissioned this record put the cause as 0.16.1's hook lacking
the line, which is true of a pinned project and understates it: no released copy has it yet.

**After it ships, the old copy still will not.** A project pinned to 0.16.1 runs 0.16.1's hook, and
that file will never carry a line added after it was cut, however many releases follow. A version
report lives inside the copy it reports on, so the one state it can never announce is a copy too old
to carry it. The failure it is meant to make visible is the failure that silences it, and silence
reads as "the hook did not run".

## What a session can observe instead

The skill inventory differs between the two: 0.16.1 ships 24 skill directories, 0.17.0 ships 25, and
`design-database` is the difference. A session that lists `keel:design-database` loaded 0.17.0. This
session did, because this repository has no project-scope entry at all and falls back to the user
scope.

That is a usable discriminator for a person debugging once. It is a bad basis for a check, because
it goes stale at the next release that adds a skill.

## The assumption this rests on, untested

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| A project-scope entry wins over the user-scope entry for a session in that project | The loader resolves by project path first | Observed only in the negative: this repository has no project entry and loaded the user-scope 0.17.0 | **No.** The nine pinned projects were not opened to confirm they load 0.16.1 |

The record is worth keeping either way. If the assumption is false, the nine entries are inert and
the confusion is milder but still real, because the visible signals still disagree with each other.

## What a fix would need

A `doctor` check that reads `installed_plugins.json`, selects the entry a session in this project
would resolve through, and compares its version against the newest copy under the cache root. Three
questions come first, and none is answered here:

1. **What is the real precedence** between a project entry and a user entry, tested rather than
   inferred from the one negative observation above.
2. **Is a project pin ever deliberate?** Holding a project on an older keel is a legitimate thing to
   want, and a warning that cannot tell that from neglect is the warning people learn to ignore.
3. **What does it say when the two cache roots disagree?** Entries here point at two different
   roots, `~/.claude/plugins/cache/` and `~/.claude-shared/plugins/cache/`, and both hold both
   versions.

The wording would matter more than the mechanism, and the existing fetch-age warning is the model
for it: it says which of two things it measures, in the sentence it prints, because the two are easy
to confuse. A scope check has to do the same or it becomes a third signal to misread.

## What this record is not

It is not a claim that the fetch-age check is wrong. It measures what it says it measures and its
comment already separates fetch age from currency. This is a second and independent way to be
behind, which that check does not measure and does not claim to. Both can be green while a session
loads a fortnight-old skill, and the next person to debug it will start where the green signals
point, which is at the marketplace.
