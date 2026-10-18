# How `setup-deployment`'s steps are done

The how of `setup-deployment`'s steps. What each step requires is in [SKILL.md](../SKILL.md).

## Step 4: Containerise properly

Measure the image with `docker image ls` and `docker history`, and record the size in the
runbook. The specifics are in
[pipeline-patterns.md](pipeline-patterns.md#keep-the-image-thin).

To look inside, `docker create` a container from the image and `docker cp` its contents out, or
run `unzip -l` on a jar.
