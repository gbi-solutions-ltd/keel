# Why `tdd`'s steps are as they are

The reasons behind each step of `tdd`, kept out of its body; the steps themselves are in `SKILL.md`.

## Overview

**Core principle:** if you did not watch it fail, you do not know it tests anything.

**Violating the letter violates the spirit.**

## RED: write the unit's failing tests

**The iron law is unchanged when cases are batched:** batching changes how many cases go red
together, never whether the cases asserting new behaviour were watched failing.

## Unit boundary: run the tests

One `verify.test_affected` run is enough at the boundary because it runs what the unit could have
broken, and `review-code` and `ship` still run the suite.

## Exceptions, stated out loud

The spike is deleted before implementing properly because "I will tidy it later" means the spike is
production code with no tests.
