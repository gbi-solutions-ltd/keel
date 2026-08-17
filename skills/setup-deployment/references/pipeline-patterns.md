# Pipeline patterns

Shapes that work, and the traps found in real repositories during this work.

## Stage order

```
install -> lint -> typecheck -> test -> security scan -> build artifact -> push -> deploy -> smoke
```

Cheap and fast first, so a formatting error fails in thirty seconds rather than after a container
build. Every stage fails the build.

## Traps, each found in a real repository

**A test step that cannot fail.** `continue-on-error: true` on a test step means the pipeline
reports green with a broken suite. Found on a service whose coverage was low single digits, where the
tests also gated nothing. Read the conditions, not the step names.

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

**A pipeline command that differs from the local one.** The most self-inflicted trap here, and I
walked into it building this repository. The lint step in CI ran `shellcheck`; everyone locally ran
`shellcheck -S warning`. Both looked correct in isolation. CI then failed on 52 findings that had
never appeared on a laptop, and the natural reaction is to distrust the pipeline rather than the
command.

**Define each verify command once and have both sides read it.** In keel the pipeline reads
`.keel/profile.json` rather than restating the string:

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
HEALTHCHECK --interval=30s CMD node healthcheck.js
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

**Measure it, do not assume.** `docker image ls` for the total, `docker history --no-trunc` for which
layer is responsible. A layer you cannot explain is a layer to investigate. Record the size in the
runbook so growth is visible rather than gradual.

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
`${VAR:+SET}${VAR:-UNSET}`, which also distinguishes unset from empty. Those are different bugs.

## Rollback

Every pipeline needs a stated answer to: what is rolled back, what is not, and how long it takes.
Schema is usually the part that is not, and that must be explicit rather than discovered.

Then execute it once by hand and record that you did. An untested rollback is a hope.
