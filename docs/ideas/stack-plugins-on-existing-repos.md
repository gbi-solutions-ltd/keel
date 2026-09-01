# Idea: make stack plugins reach repositories that already have a settings file

| | |
|---|---|
| Raised by | Bernard, 2026-08-18, from open question 1 of `plsql-stack-detection.md` |
| Status | **built 2026-08-18**, via `docs/plans/2026-08-18-usable-profile.md`, fully ticked. `plugins.recommended` is written at init, `bin/keel:444`, and read back at `bin/keel:196`. Open question 1 was answered by the requester on 2026-08-18 in favour of reporting, which is what shipped. Status corrected 2026-08-30 |
| Recommendation | Build something smaller: write `plugins.recommended` at init so the reporting machinery that already exists starts checking the right list, and have doctor name the install command. Do not silently write into a settings file the project already had |
| Next | `docs/prd/usable-profile.md` (draft, awaiting approval), written jointly with `profile-key-documentation.md` |

## The problem

`keel init` on a repository that already has `.claude/settings.json`, which its own code calls "the
common case on a mature repo", enables no plugins at all: no language server, none of the five
official plugins, and not even `keel@gbi` itself. `keel doctor` cannot report this, because the list
it checks against is a hardcoded fallback that contains no language server. The stack is detected
correctly and nothing acts on it.

**Evidence.** Two fixtures built on 2026-08-18, identical TypeScript projects (`package.json` with a
`typescript` dependency, plus `tsconfig.json`), differing only in whether `.claude/settings.json`
existed beforehand. After `keel init -y`:

| | fresh repo | repo with an existing settings.json |
|---|---|---|
| `enabledPlugins` | `keel@gbi`, `security-guidance`, `code-review`, `skill-creator`, `claude-md-management`, `context7`, `typescript-lsp` | **the key is absent entirely** |
| `profile.plugins` | absent | absent |
| What `plugin_report` checks | the hardcoded three | the hardcoded three |
| What doctor would say | nothing | three official plugins missing, and **no mention of `typescript-lsp` or `keel@gbi`** |

The real repository this was found for is the Oracle repository, which has a
`.claude/` directory and a committed `settings.json` already.

## What was asked for

> my goal was to have keel infer the stack and ensure the appropriate plugins are installed to
> better the coding experience. recommend the best way to do this to ensure all suggested languages
> are catered for

**The inference half already works and is complete.** `lang_lsp` (`lib/detect-stack.sh:581-596`)
maps all thirteen detected languages onto twelve language servers, `detect_plugins` (`:601-608`)
collects one per language in a polyglot repository and adds `frontend-design` and `playwright` when
there is a UI, and every one of those twelve names was verified on 2026-08-18 against the real
`claude-plugins-official` catalogue on this machine. Nothing is missing from the mapping. What is
missing is that two of the three ways a repository could receive the result do not fire.

## The case against

**Strongest argument for not building this at all: the current behaviour is not a policy, and the
fix forces keel to adopt one it deliberately declined to adopt elsewhere.** `.claude/settings.json`
is normally committed, so anything written there decides what loads for everyone who clones the
repository. keel has already reasoned about exactly this and come down against it, at
`bin/keel:608-614`: a committed file setting `bypassPermissions` "turns off every prompt for anyone
who clones the repository, before they have read a line of it. That is a decision each engineer
makes about their own machine, not one a repository makes on their behalf." The same sentence
applies word for word to enabling seven plugins. And yet `write_settings` does precisely that on a
fresh repository. So keel already holds both positions at once, and the reason is not a considered
split: it is the early return at `bin/keel:558-561`, where an existing file takes a path that merges
permissions and returns, and `merge_permissions_into_settings` (`:583-606`) touches `permissions`
and nothing else. Filling this gap therefore means choosing which of the two existing behaviours is
correct, and the answer might be that the fresh-repo path is the one that is wrong.

**Second argument: "ensure the appropriate plugins are installed" is not achievable, and the gap
between enabling and installing is where this will disappoint.** `enabledPlugins` is a reference,
not an installation. keel cannot run `/plugin install`, which is a user action in the client. The
comment at `bin/keel:551-556` asserts that every `@claude-plugins-official` plugin "is enabled
without one and resolves fine", which makes the official ones safe, but nothing in `plugin_report`
(`bin/keel:142-163`) verifies that an entry resolves to anything: it tests presence in the settings
file and stops. So a plugin that is enabled but unavailable looks identical to one that is working,
and the strongest version of this idea still cannot promise what it was asked to promise.

**Third argument: it is the smallest of the three gaps that this session found.** A missing language
server costs some editor intelligence. A repository whose profile says `language: unknown` costs
every skill its facts. If effort is scarce, `plsql-stack-detection.md` is worth more.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Nothing | The mature-repo case is silent rather than broken, and a developer who wants a language server can enable one in `/plugin`. But nothing ever tells them it is missing, which is the part that does not self-correct |
| Do it manually | Six lines of JSON per repository, and knowing which six | Works, and it is what happens today. It requires the reader to know that `lang_lsp` exists and what it would have chosen, which is not written down anywhere a user reads |
| Buy it | Nothing available | No tool maps a repository's stack onto Claude Code plugins |
| Build something smaller | One line in `write_profile`, and doctor's existing report becomes correct | Recommended. It changes nothing the user owns, and it makes the missing plugins visible, which is the precondition for any of the larger variants |

**Variants of building it**

| Variant | What it does | Note |
|---|---|---|
| Write `plugins.recommended` at init from `detect_plugins` | Gives `plugin_report` the right list, so doctor names the missing language server and `keel@gbi` | **Recommended.** Read-only with respect to the user's settings, one line, and it makes a mechanism that already ships correct for the first time |
| Also merge missing entries into an existing `enabledPlugins` | Closes the gap completely | The variant that takes the position argued against above. If chosen, it should be symmetrical with the fresh path and stated in the docs, not left implicit |
| Merge, but only behind a prompt at init | Same, with consent | `keel init -y` needs a default, and the safe default is "do not write", which means CI runs stay in the broken state. Honest, and it makes the flag matter |
| Print the `/plugin install` commands at the end of init | Tells the user exactly what to run, changes nothing | Pairs well with the recommended variant and costs almost nothing. Doctor already does this for the marketplace at `bin/keel:1407` |
| Verify that an enabled plugin resolves | Closes the enable-versus-install gap | Bigger, needs the plugin cache walked, and `boundary_report` (`bin/keel:190-205`) already reads that cache, so the capability exists |
| Reverse it: stop enabling plugins on fresh repos too | Makes the two paths consistent the other way | The honest opposite. Rejected only because the fresh-repo behaviour has shipped and nobody has complained about it |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| The twelve LSP names are real and current | Each resolves in the official marketplace | All twelve found in the catalogue on this machine, 2026-08-18 | **Yes** |
| `lang_lsp` covers every language keel detects | No detected language is left without a server | Thirteen languages, twelve servers, `typescript` and `javascript` sharing one. Complete | **Yes** |
| A committed `settings.json` is the norm on a mature repo | The mature path is the common one | `bin/keel:580` says so in its own comment, and the real Oracle repo matches | Partly |
| A language server measurably improves the experience | The premise of the request | Asserted, not measured. It is a widely held view and cheap to act on | No |
| Writing `plugins.recommended` is safe | Nothing else consumes that key in a conflicting way | `plugin_report` is the only reader (`bin/keel:153`), and the schema already declares it | **Yes** |
| Doctor naming a missing plugin leads to it being installed | The reader acts on a warning | Unknown, and it is the whole theory of change for the recommended variant | **No** |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| The stack-to-plugin mapping is complete | `lib/detect-stack.sh:581-596`, `:601-608` | Nothing needs building for "all suggested languages are catered for". It is done |
| Every mapped name exists in the real marketplace | Catalogue on this machine, checked 2026-08-18 | The mapping is not stale. This was the main risk `snapshot-recommends-tools.md` raised about tool opinions |
| A fresh repo gets seven plugins | Fixture, 2026-08-18; `bin/keel:563-566` | The intended behaviour works |
| A repo with an existing settings file gets none | Fixture, 2026-08-18; `bin/keel:558-561`, `:583-606` | The gap, and it is an early return rather than a decision |
| Not even `keel@gbi` is enabled in that case | Same fixture | The most surprising part. A repository can be initialised by keel and not have keel enabled |
| `plugin_report` reads a key init never writes | `bin/keel:142-163`; `templates/profile.schema.json:397` declares `plugins` | The reporting machinery is built, correct, and starved of input |
| The omission is recorded as deliberate | `tests/validate-skills.sh:358-360`, "which init never writes because a human adds them" | Writing it reverses a stated decision. Small, but it should be reversed knowingly |
| keel already refuses to make machine-level decisions in a committed file | `bin/keel:608-614`, on permission mode | The precedent argues against the merge variant and for the report variant |
| Marketplace absence is already handled by naming the command | `bin/keel:1407` | The pattern for "tell the user what to run" exists and is worth copying |
| No SQL or PL/SQL language server exists in the catalogue | Searched 2026-08-18: `oracledb` is a database client from a third-party URL source, not a server | Answers `plsql-stack-detection.md` open question 2. `lang_lsp` returning nothing is the correct outcome |

## Open questions

1. **Report, or write?** **Answered 2026-08-18 by the requester: report only.** init writes
   `plugins.recommended`, doctor names what is missing and the command to fix it, and nothing is
   written into a settings file the project already had. The merge variant stays on the page as the
   thing to revisit if it turns out people do not act on the warning.
2. **Should the fresh path be reconsidered too?** Now the largest open question, because reporting
   on mature repos while silently enabling seven plugins on fresh ones leaves keel holding both
   positions. Not blocking: the recommended change is correct either way, and this decides only
   whether the fresh path is later narrowed to match.
3. ~~**Should doctor check that an enabled plugin resolves?**~~ **Settled 2026-08-18: out of scope**
   for the first change. It roughly doubles the plugins half, and enabled-but-unavailable will keep
   looking identical to working, which the PRD accepts explicitly in section 11. Worth its own
   record if the warning turns out to be ignored.
4. ~~**Does `plugins.excluded` need writing too?**~~ **Settled 2026-08-18: no, but it gets a
   description.** It stays human-authored; `FR-01` of the PRD requires every declared key to be
   described, which covers it.

## Recommendation

**Build something smaller.** Have `write_profile` emit `plugins.recommended` from `detect_plugins`,
so `plugin_report` checks the language server and `keel@gbi` instead of a hardcoded three, and have
doctor print the `/plugin install` line for each one it names.

Why: the inference the request asked for already exists and is verified complete, so the gap is
reporting rather than detection. This variant makes the missing plugins visible without keel writing
into a file that decides what runs for everyone who clones the repository, which is a position keel
has already taken deliberately in the permissions code.

Next: answer open question 1, then `write-prd`. It should be written together with
`profile-key-documentation.md`, because `plugins.recommended` is one of the seven undocumented keys
and this change makes it one users will need to understand.

## Not decided here

Whether the merge variant is ever built; the exact wording of doctor's new lines; whether the fresh
path keeps enabling plugins; how `plugins.excluded` interacts with a written `recommended`; and
whether resolution checking is worth its cost, which is open question 3.
