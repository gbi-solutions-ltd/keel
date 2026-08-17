# Runbook: making this repository public

Nothing here has been executed. It is the ordered list of what publishing actually requires,
written while the repository is private so the work is known rather than discovered.

**Two steps are decisions, not actions.** Step 1 and step 5 need an answer from an owner before
anybody runs a command. The rest are mechanical once those two are settled.

**Read this first, because it changes the order.** Publishing is not reversible in the way people
assume. Making a repository private again does not recall clones or forks, and a fork network keeps
objects reachable after the parent is locked down. Everything below assumes one attempt.

## 1. Decide the licence. DECISION

`LICENSE` is currently proprietary and all rights reserved: internal use by GBi Solutions Ltd and
its authorised personnel only. A public repository under that notice is published source that
nobody may use, which is usually not what "make it public" means.

MIT is the honest fit, because four of the projects keel adapts are MIT and roughly a third of the
skill set derives from them. Relicensing keel does not relicense their portions: those keep their
own notices in `THIRD-PARTY-LICENSES.md`, and `SOURCES.md` records which part came from where.

Do not skip this by publishing under the current notice and deciding later. The licence at the
moment of the first clone is the one that clone carries.

## 2. Move the deny list outside the tree

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

## 3. Deal with the five GBi reference files

Decision 2 confined GBi-specific content to five files so that publishing would be a deletion. Since
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
| `gbi-defaults.md` | House conventions, most of which any team would adopt | Rename to `house-defaults.md`, remove the two GBi sentences, update the link in `skills/coding-standards/SKILL.md` |
| `observability.md` | Generic, plus SigNoz named as the default backend | Keep. Replace the named default with "whatever `profile.observability.backend` says" |
| `authorisation.md` | Separation-of-duties rules written for a payments business | Keep. The rules are good for anyone handling money; only the framing sentence names us |
| `payments-checklist.md` | Domain checklist. Read it line by line | Keep, after a read for any trap traceable to one client's incident |
| `pipeline-patterns.md` | Shapes that work, and traps found in real repositories | Keep, after the same read. "Found in a real repository" is fine; a recognisable one is not |

After the renames, run `tests/no-internal-leaks.sh` and update `GBI_ALLOWED` to match. A path in that
array that no longer exists is a rule protecting nothing, and nothing would report it.

## 4. Update the repository name and its URLs

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
several were removed by the sweeps decision 2 records. The eight GBi neutralisations of 2026-08-17
are in there too.

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

```bash
tests/run-tests.sh                    # all test files pass
tests/supply-chain-scan.sh            # clean, with every honoured suppression printed
tests/no-internal-leaks.sh            # clean, and printing that it ran in fallback mode
```

Then change visibility.

## 8. What changes the moment it is public

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
