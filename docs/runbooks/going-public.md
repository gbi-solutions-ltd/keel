# Runbook: making this repository public

**EXECUTED 2026-08-17.** This repository is `gbi-solutions-ltd/keel-internal` and remains private.
The public repository is `gbi-solutions-ltd/keel`, a fresh tree of 158 files at two commits, MIT
licensed, CI green. Executed as `docs/plans/2026-08-17-go-public.md`.

The three decisions taken first, by Bernard:

| Decision | Answer |
|---|---|
| Vehicle | A fresh public repository, one initial commit, **no history** |
| Licence | MIT |
| Path | This repository renamed `keel-internal`; the public one took `keel`, so every committed URL was already correct |

**Why the history stayed behind, which is the finding that decided the vehicle.** Sweeping every
commit found **all 27 deny patterns reachable**. Six real-content files carried client names in old
worked examples: `prd-template.md`, `standards-template.md`, `design-template.md`, `docs/03`, and two
pre-rename `gbai` files. The deny list itself carried them across its 8-commit history. Two commit
messages carry one each, `940effdd` and `bb0132bd`. `HEAD` by contrast was already clean. A rewrite
was possible and a fresh tree was cheaper and safer, so the 159 commits stayed private.

**What was excluded from the published tree:** `docs/audits/`, `.claude/`, `.keel/handoff.md`.
Verified absent through the GitHub API after publishing. `IMPLEMENTATION-PLAN.md` was on that list
and came off it, which is the only exclusion that was tested and reversed: it was excluded for naming
both pilot repositories, those were genericised, it then swept clean, and excluding it broke three
README links.

**The steps below are kept as written, each annotated with what actually happened.** They are no
longer instructions for this repository. They are the record, and they are the instructions for the
next repository anyone publishes.

**Read this first, because it changes the order.** Publishing is not reversible in the way people
assume. Making a repository private again does not recall clones or forks, and a fork network keeps
objects reachable after the parent is locked down. Everything below assumes one attempt.

## 1. Decide the licence. DECISION

**DONE: MIT.** One thing was learned that this runbook did not anticipate and that the next reader
needs. The first `LICENSE` kept the third-party paragraph appended to the MIT text, and GitHub then
reported the published repository's licence as **not detected**, because the detector needs a close
match to canonical text. A public repository whose licence cannot be detected shows no licence to
anyone browsing it or to any tool that reads one. `LICENSE` is now canonical MIT and nothing else,
and the third-party relationship lives in `NOTICE`.

`LICENSE` is currently proprietary and all rights reserved: internal use by GBi Solutions Ltd and
its authorised personnel only. A public repository under that notice is published source that
nobody may use, which is usually not what "make it public" means.

MIT is the honest fit, because four of the projects keel adapts are MIT and roughly a third of the
skill set derives from them. Relicensing keel does not relicense their portions: those keep their
own notices in `THIRD-PARTY-LICENSES.md`, and `SOURCES.md` records which part came from where.

Do not skip this by publishing under the current notice and deciding later. The licence at the
moment of the first clone is the one that clone carries.

## 2. Move the deny list outside the tree

**DONE.** `KEEL_DENY_FILE`, defaulting to `~/.config/keel/internal-deny-list.txt`, 25 patterns. An
absent list degrades to the two generic path patterns rather than to silence, and the mode prints on
every run. Both the scanner and its test are now clean of client names; the test uses invented
identifiers that mirror the real shapes.

Two things learned. **The deny file must live outside the scanned tree**, which is where production
puts it: a fixture written inside made the scanner report it, and that is correct behaviour rather
than a bug to skip around, because a deny list committed inside a repository is a leak. And the
coverage guarantee is genuinely reduced: the test proves the mechanism, not that every pattern in the
real list still matches something. A `pattern<TAB>sample` format would restore it.

`tests/no-internal-leaks.sh` is the file that enumerates our clients, because it must contain their
names in order to search for them. The guard against disclosure is the disclosure. Its own header
says this and so does decision 2.

What to do, per that decision:

- Move the `DENY` array into a file outside the public tree. A sibling private repository, or a path
  read from an environment variable, both work. A private submodule does not: a submodule URL is
  public even when its contents are not, and the URL alone is a pointer at the list.
- Have the script read it, and **fall back to the generic patterns when it is absent**: developer
  home paths and document identifiers, which disclose nothing. A CI runner on a fork has no list and
  is a legitimate state, exactly as an unregistered marketplace is.
- Print which mode it ran in, on every run. A scanner that silently degrades to half its rules and
  still prints `OK` is worse than one that fails.
- Fix the coverage assertion in `tests/test-no-leaks.sh` in the same change. It compares every
  declared pattern against the ones that fired, so with an absent list it must assert coverage of
  the loaded patterns only, not of a list it cannot see.

**The `GBI_ALLOWED` rule beside it does not move.** It names five paths, discloses nothing, and is
the thing that keeps step 3 a deletion rather than an audit.

## 3. Deal with the five house-specific reference files

**DONE, and it went further than this section proposed.** All five are generic once the name comes out
of their prose, so `GBI_ALLOWED` is gone and the rule is now that shipped content names no
organisation at all.

Three things this section got wrong or missed. The `house-defaults.md` rename touched **thirteen**
references across eleven files, not the one link predicted below: the file was cited as prose
throughout the coding-standards reference set, and prose citations are invisible to the link checker.
**SigNoz stays the documented default**, because de-defaulting it would change what `keel init`
writes, which is a behaviour change rather than de-branding. And the read of the two domain checklists
found **one** item needing redaction rather than none: `pipeline-patterns.md` attributed a trap to "a
payment platform with 3.6% coverage", and a sector plus an exact figure identifies an engagement to
anyone who has read that audit.

Decision 2 confined house-specific content to five files so that publishing would be a deletion. Since
2026-08-17 that is enforced by `tests/no-internal-leaks.sh`, so the list is trustworthy:

- `skills/coding-standards/references/gbi-defaults.md`
- `skills/coding-standards/references/observability.md`
- `skills/coding-standards/references/authorisation.md`
- `skills/security-audit/references/payments-checklist.md`
- `skills/setup-deployment/references/pipeline-patterns.md`

**Do not simply delete them.** `tests/validate-skills.sh` fails when a relative link does not
resolve, and `skills/coding-standards/SKILL.md` links to `gbi-defaults.md`. A deletion turns a
documented file into a broken link and the build goes red.

Per file:

| File | What it actually contains | Do |
|---|---|---|
| `gbi-defaults.md` | House conventions, most of which any team would adopt | Rename to `house-defaults.md`, remove the two sentences naming the organisation, update the link in `skills/coding-standards/SKILL.md` |
| `observability.md` | Generic, plus SigNoz named as the default backend | Keep. Replace the named default with "whatever `profile.observability.backend` says" |
| `authorisation.md` | Separation-of-duties rules written for a payments business | Keep. The rules are good for anyone handling money; only the framing sentence names us |
| `payments-checklist.md` | Domain checklist. Read it line by line | Keep, after a read for any trap traceable to one client's incident |
| `pipeline-patterns.md` | Shapes that work, and traps found in real repositories | Keep, after the same read. "Found in a real repository" is fine; a recognisable one is not |

After the renames, run `tests/no-internal-leaks.sh` and update `GBI_ALLOWED` to match. A path in that
array that no longer exists is a rule protecting nothing, and nothing would report it.

## 4. Update the repository name and its URLs

**DONE, and it was nearly a no-op**, because the public repository took the path `gbi-solutions-ltd/keel`.
All five touchpoints below were already correct and none was edited.

What this section missed: `.claude-plugin/` is shipped content that no rule scopes to and nothing had
read. `marketplace.json` advertised "GBi internal AI engineering tooling" on a repository about to
stop being internal, and `plugin.json` declared `"license": "SEE LICENSE IN LICENSE"` after the MIT
change. Both fixed. That directory stays outside the organisation-name rule on purpose, because `owner.name`
legitimately names the marketplace owner.

`gbi-solutions-ltd/keel` is load-bearing in five places, and two of them break silently:

- `README.md` install instructions and the private-repo paragraph
- `.claude-plugin/marketplace.json` and `.claude-plugin/plugin.json`
- `tests/test-keel.sh`, which asserts the marketplace source lands in `settings.json`
- `templates/profile.schema.json`, as the schema's canonical `$id`
- `templates/keel-profile.example.json`, as its `$schema`

The last two are raw `githubusercontent.com` URLs. If the repository is renamed or moved, they
become 404s in every project that already has a profile, and nothing in `doctor` checks a schema URL
resolves. Decide whether the repository keeps its path before publishing, not after.

The README paragraph saying "the repository is private and this works anyway" also stops being true
and should go, along with the credential-helper explanation it exists to give.

## 5. Decide what happens to the documents that name real work. DECISION

**DONE: option 1, publish a subset, but a much narrower exclusion than this section imagined.** Only
`docs/audits/` is withheld. Everything else publishes, including `docs/01` to `docs/07`,
`docs/standards.md`, `decisions/`, `ideas/`, `plans/`, `runbooks/` and `IMPLEMENTATION-PLAN.md`.

Two facts made that safe, and both were measured rather than argued. `HEAD` carried no client
identifier outside the deny list and its test. And exactly **one** file under `docs/` named a house
service, `2026-08-15-existing-service-pilot.md`, which is withheld. Note also that the audits name
**the house's own** services rather than a third party's, so that exposure was ours to accept.

Accepted knowingly: the published tree names Bernard Tebandeke and Edrine Kamya as reviewers, with 17
further references to "Bernard". Put to the author explicitly and authorised twice.

This is the largest exposure and it is not covered by step 3's list, because those five files are
about conventions and these are about clients.

| Where | What is in it |
|---|---|
| `docs/audits/` | Five audits of real services, naming the repository, its defects and its security posture |
| `IMPLEMENTATION-PLAN.md` | Pilot repositories named outright, plus both reviewers |
| `docs/07-open-decisions.md` | The org, the reviewers, the client engagement that produced three skills |
| `docs/plans/`, `docs/ideas/`, `CHANGELOG.md` | Real repositories and real incidents, used as the reason a rule exists |

Three options, and the choice is an owner's:

1. **Publish a subset.** Ship the plugin (`skills/`, `bin/`, `lib/`, `hooks/`, `templates/`, `tests/`,
   `README.md`) and leave `docs/` and `IMPLEMENTATION-PLAN.md` behind. Cleanest, and it loses the
   thing that makes the repository worth reading: every rule states the failure that produced it.
2. **Redact in place.** Keep the documents, replace each named repository with a generic one. Slow,
   and a redaction that leaves the incident intact often still identifies the client.
3. **Publish as is.** Only if an owner has read all five audits and accepts it. They are the most
   detailed public statement about a client's security posture that we could make.

## 6. Scan the history, not the working tree

**DONE, and it is what decided everything else.** All 27 patterns reachable; see the header. The
history was never published rather than rewritten, so `git filter-repo` was never needed and never
installed.

The working tree being clean says nothing. Git keeps everything, and a name removed in a later
commit is public the moment the repository is.

```bash
# Every deny pattern against every commit, not just HEAD.
for pat in $(tests/no-internal-leaks.sh --list-patterns); do
    git rev-list --all | while read -r sha; do
        git grep -I -nE "$pat" "$sha" 2>/dev/null
    done
done | sort -u | head -50
```

Expect hits. Every client identifier this repository ever removed is still in its history, and
several were removed by the sweeps decision 2 records. The eight organisation-name neutralisations of
2026-08-17 are in there too.

If there are hits, publishing the existing history is not an option, and there are two ways out:

- **Rewrite** with `git filter-repo`. Keeps the history, invalidates every existing clone and every
  commit sha referenced in any document, including the `f135e23` and `a1b2c3d` style references
  scattered through `docs/` and `CHANGELOG.md`.
- **Start fresh.** A new repository with one squashed initial commit. Loses the history, which for a
  tool whose main asset is "this rule exists because of that failure" costs more than it looks like.

Whichever is chosen, `tests/supply-chain-scan.sh`'s `structural-secret-material` rule states the
same principle for credentials and it applies here: the remedy for something git has kept is not
deleting the file.

## 7. Re-run the whole gate, then flip

**DONE, and one step was added that this section did not have: run the suite inside the export.** That
is the step that caught the manifest defect, and a subset that fails its own validator is not a
release. Add it to this list for the next repository.

**Push protection rejected the publish twice, and neither cause was a real secret.** Both were test
fixtures, and both were fixed at the cause rather than by clicking the unblock link, so a contributor
or a fork never trips them either:

1. `tests/test-supply-chain.sh` carried a literal PEM private-key opening line, as a fixture proving
   the supply-chain scanner rejects a committed key. Its body was the single character `x`. The header
   is now assembled from two pieces, and the generated file is byte-identical, verified with `cmp`.
2. `tests/fixtures/apex/capture/extract.out` carried a synthetic token shaped like a Stripe live
   secret key, exercising the APEX exporter's bearer-token redaction. The redaction rule matches
   `Bearer` plus twenty or more token characters, so the provider shape was never what the test
   pinned.

**The lesson worth keeping: sweep per provider, not with one regex.** The first sweep missed the
Stripe key because it used the OpenAI hyphen shape, `sk-`, and not Stripe's underscore shape,
`sk_live_`. Expect push protection to reveal one detection at a time.

```bash
tests/run-tests.sh                    # all test files pass
tests/supply-chain-scan.sh            # clean, with every honoured suppression printed
tests/no-internal-leaks.sh            # clean, and printing that it ran in fallback mode
```

Then change visibility.

## 7a. Publishing an update, after the first release

**For a release, use [`cutting-a-release.md`](cutting-a-release.md) instead.** It carries this
section's export and sync steps plus the eval gate, the version bump, the tags and the release
itself, as one procedure, executed for 0.17.0. What follows stays here as the route for a change
that is not a release.

Written on 2026-08-19, the first time the public repository took a change that was not a release.
The public tree is separate and has no history in common with this one, so an update is a fresh
commit built from an export rather than a merge or a cherry pick.

```bash
tests/export-public.sh /tmp/keel-export
( cd /tmp/keel-export && git init -q && git add -A \
    && git -c user.name=export -c user.email=export@local commit -qm export \
    && tests/run-tests.sh )                       # must be green before anything is pushed
git clone git@github-personal:gbi-solutions-ltd/keel.git /tmp/keel-public
rsync -a --delete --exclude '.git/' /tmp/keel-export/ /tmp/keel-public/
( cd /tmp/keel-public && git status --short && git ls-files | wc -l )
```

**Commit inside the export before running the suite, not after.** The step above used to be
`git init -q && git add -A && tests/run-tests.sh`, and it now fails: `tests/test-cache-install.sh`
builds its copy with `git archive HEAD`, and a repository with a staged index and no commit has no
HEAD to archive. It reports `fatal: not a valid object name: HEAD` and the suite is red for a reason
that has nothing to do with the export. This is the same commit-then-verify ordering that a release
needs, arriving in a second place.

**Committing afterwards is worse than committing first.** A suite run writes files. The run leaves
`lib/__pycache__/*.pyc` behind, and a commit taken after the run sweeps whatever it created into the
tree being verified. They are gitignored, so they never reach a commit, but `rsync` does not read
`.gitignore` and will copy them into the clone.

**Check the file count against the export's own number.** `tests/export-public.sh` prints how many
files it wrote. After the `rsync`, `git ls-files | wc -l` in the clone must equal it: 187 on
2026-08-19. The three `.pyc` files above were caught exactly this way, by a count that disagreed with
the export by three.

**An update that is not a release gets no tag and no version bump.** Plugin installs are keyed by
version, so an untagged commit on the public `main` reaches no installed user. A release is the other
thing, and Decision 9 gates one on the behavioural evals, which cost agent runs. Do not quietly turn
a documentation or test change into a release to get it published.

## 8. What changes the moment it is public

**Checked after publishing.** No workflow references a secret, and the public repository has no
secrets configured, so the `pull_request` trigger hands a fork nothing. Actions are enabled with all
actions allowed and no SHA pinning required, which is worth revisiting if outside contributions start.

- **Actions run on pull requests from forks.** Read every workflow trigger and every secret it uses
  before publishing, not after. A `pull_request` trigger with access to a secret is a credential
  handed to anyone who opens a PR.
- **`keel doctor`'s marketplace check** is unaffected: it asks whether a marketplace is registered on
  this machine, not whether it is reachable.
- **Issues arrive from strangers.** Decision 9 assigns review to two named people and says either may
  review but never the author. That holds for external contributions too, and it means a contributor
  cannot merge their own skill change. Say so in `CONTRIBUTING.md` before the first PR arrives, not
  in reply to it.
- **The writing rules now cover documentation**, so an outside contributor's first plan or ADR is
  checked the same way a skill is: `tests/validate-skills.sh` reports an em or en dash and an
  unresolvable relative link in anything under `docs/` or at the repository root. Two limits are
  deliberate and both were measured rather than assumed. Links inside fenced code blocks are skipped,
  because a plan quotes the markdown it is telling someone else to write. And the docs-root rule does
  not apply: a skill must write `<docs_root>`, but a document explaining the default layout has to
  name it, and five correct documents do.
