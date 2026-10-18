# Why `repo-snapshot`'s steps are as they are

The reasons behind `repo-snapshot`'s steps. The steps themselves are in [SKILL.md](../SKILL.md).

## Overview

Every claim cites a `path:line` or is marked `Unknown` because a confident snapshot that is wrong
is worse than none: the next three decisions inherit the error.

## Step 1: Scope and set exclusions

Compare the default branch against HEAD because they diverge often.

Find what agents must not read, because one 500KB generated file eats a budget.

## Step 2: Delegate the reading

Files read inline sit in context all session; a subagent's are discarded.

## Step 3: Verify what will drive action

Never report a figure from a committed report or an agent's count, because stale reports are
confidently wrong by an order of magnitude.

Read the output of each command rather than its exit code, because an errored tool and one that
found nothing both exit non-zero.
