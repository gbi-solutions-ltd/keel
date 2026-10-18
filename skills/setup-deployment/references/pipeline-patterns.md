# Pipeline patterns

Shapes that work, and the traps found in real repositories while keel was being built.

## Stage order

```
install -> lint -> typecheck -> test -> security scan -> build artifact -> push -> deploy -> smoke
```

Cheap and fast first, so a formatting error fails in thirty seconds rather than after a container
build.

## Traps, each found in a real repository

**A test step that cannot fail.** `continue-on-error: true` on a test step means the pipeline
reports green with a broken suite. Found on a service whose coverage was low single digits, where
the tests also gated nothing.

**Gating the wrong branch.** A pull-request trigger scoped to the default branch, while all the
work happens on another. The gates exist and never apply. Check which branch people actually push
to.

**A build job with no deploy job.** `build:production` existing on the default branch with no
`deploy:production` anywhere means nothing deploys that build. Either the deploy is manual and
undocumented, or that environment is not being deployed at all. Both matter.

**Environments sharing a host or a key.** A base job hardcoding one environment's SSH key and host,
with the other environment overriding only ports, so two environments are one machine. A sandbox
incident then takes staging with it. Diff the variables, not just the job names.

**An env file baked into the image.** A setup script writes real credentials to `.env` at build
time and the Dockerfile copies `.env*`. Anyone who can pull the tag has production secrets.
`.dockerignore` must exclude env files and keys, and you must verify by looking inside the built
image.

**Migrations on every container start.** Convenient, and it means a throwaway candidate in a
blue/green deploy has already migrated the shared database before failing its health check. The
rollback then restores the image and not the schema. Decide this deliberately and write it down.

**A referenced Dockerfile that does not exist.** A compose file building a service from a path with
no Dockerfile. The documented "start everything" command cannot work, and nobody noticed because
everyone runs things individually.

**A pipeline command that differs from the local one.** The most self-inflicted trap here, and keel
walked into it building its own repository. Its CI lint step ran `shellcheck`; everyone locally ran
`shellcheck -S warning`. Both looked correct in isolation. CI then failed on 52 findings that had
never appeared on a laptop, and the natural reaction is to distrust the pipeline rather than the
command.

**Define each verify command once and have both sides read it.** Have the pipeline read
`.keel/profile.json` rather than restate the string, for example:

```yaml
- name: Lint
  run: |
    LINT=$(jq -r '.verify.lint' .keel/profile.json)
    echo "running: $LINT"
    eval "$LINT"
```

Restating a command in a workflow file guarantees the two drift, because only one of them gets
updated. The same applies to severity flags, coverage thresholds, and test selectors: a flag that
exists in one place and not the other is a pipeline that tests something nobody has run.

## Docker shape

```dockerfile
FROM node:20.13.1-bookworm-slim AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci                      # ci, not install: the lockfile is the point
COPY . .
RUN npm run build && npm prune --omit=dev

FROM node:20.13.1-bookworm-slim
WORKDIR /app
RUN useradd --create-home app
COPY --from=build --chown=app:app /app/node_modules ./node_modules
COPY --from=build --chown=app:app /app/dist ./dist
USER app
HEALTHCHECK --interval=30s CMD node dist/healthcheck.js
CMD ["node", "dist/main.js"]
```

Pinned to a patch version, non-root, no build tooling in the final layer, and **no env file copied
at any point**.

## Keep the image thin

Every megabyte is pull latency on every deploy and scale-up, and every package is attack surface that
must be patched. A 60MB jar in a 1.1GB image is mostly things nobody chose.

| Do | Instead of |
|---|---|
| `-slim` or `-alpine` base, pinned to a patch version | A full distro image, or a floating tag |
| Multi-stage: compilers and dev dependencies stay in the build stage | One stage carrying the toolchain into production |
| `npm ci --omit=dev`, `npm prune --omit=dev`, `go build` static, a JRE not a JDK | Shipping everything that was needed to build |
| A `.dockerignore` excluding `.git`, `node_modules`, tests, docs, and **env files and keys** | Copying the working tree and hoping |
| `COPY` only the built artifact and its runtime dependencies | `COPY . .` in the final stage |
| One `RUN` chain that installs, uses, and cleans in the same layer | Installing in one layer and cleaning in the next, which removes nothing |

A deleted file in a later layer is still in the image. Cleaning must happen in the layer that
created the thing.

**Measure it, do not assume.** `docker image ls` for the total, `docker history --no-trunc` for
which layer is responsible. A layer you cannot explain is a layer to investigate.

Where the runtime supports it, a distroless or scratch final stage removes the shell and the package
manager entirely. That is a real security gain and it makes debugging harder, so decide it
deliberately rather than by default.

## Build once, promote the digest

Build one artifact and promote the same digest through environments. Rebuilding per environment
means the thing you tested in staging is not the thing running in production, and a
non-reproducible build makes that difference invisible.

## Secrets

Injected at runtime, from the platform's secret store. Never in an image layer, never in a build
argument (they persist in history), never echoed. To log presence without the value, use
`[ -n "${VAR+x}" ] && { [ -n "${VAR:+x}" ] && echo SET || echo EMPTY; } || echo UNSET`, which also
distinguishes unset from empty and never puts the value in a shell trace. Those are different bugs.

## Rollback

Every pipeline needs a stated answer to: what is rolled back, what is not, and how long it takes.
Schema is usually the part that is not, and that must be explicit rather than discovered.

## A flaky test: the recorded quarantine

Read this before a test leaves the gate.

**Investigate first.** Run the test repeatedly and look for what differs between runs: environment
variables, order, time, shared state. A cause found is fixed, not quarantined. A test that passes
alone and fails after another test leaves a file behind is a fix.

**The quarantine file.** A committed file the pipeline reads, one line per test, with four fields
separated by ` | `: the test, an owner, a reason, and a removal date as `YYYY-MM-DD`. Blank lines
and lines starting with `#` are skipped. The path is the project's choice. For example:

```
# ci/quarantine.txt: test | owner | reason | remove by
tests/test-export.sh | R. Mensah | times out on the shared runner, cause not yet found | 2026-11-15
```

**The owner and the date are the person's.** Where the request does not name them, ask one question
for both. Never invent an owner or a date. Until they are given, either leave the file empty so the
test stays in the gate, or write the entry with the literal placeholder `OWNER?` or `DATE?`. The
gate rejects a placeholder, so the build fails until the person fills it in.

**What the gating job does.** It runs every test not listed. It fails when any line lacks one of the
four fields, has a placeholder, or has a removal date that has passed, with a message naming the
test and the field. An entry dated yesterday fails the gate with "tests/test-export.sh:
remove-by 2026-10-17 has passed".

**The listed tests still run,** in their own job that reports their result and cannot fail the
build: on GitHub Actions, `continue-on-error: true` on that job alone. This is the only job in the
pipeline whose tests may not fail the build, and only for tests the file lists.

**The runbook names the quarantine,** next to the rollback, so the people who deploy can see what
is not gating.

**What is not a quarantine.** Moving a test out of the gating job by any other route:
`continue-on-error` on a step or job that runs a test the file does not list, `|| true` or any other
way of discarding a test's exit code, a separate job running a test with no line in the file, or a
test left out of the gating command. Each one is "the test does not fail the build".
