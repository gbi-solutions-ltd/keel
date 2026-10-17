# Rework link

Name the planned feature a fix reworks, so that `keel plan report` counts the fix against it.

## When

After the fix is verified (phase 4, step 3), before it is committed. Whoever commits the fix writes
the line, `ship` included.

## Procedure

1. **Find the commit that introduced the cause.** The fix is still uncommitted, so plain
   `git blame` reports "Not Committed Yet" for it. Run `git blame HEAD -L <start>,<end> -- <file>`,
   or `git log -L <start>,<end>:<file>`, which already reads `HEAD`, on the lines the fix changed,
   as they were before the fix. When the fix only adds lines, blame the lines around where it adds
   them.
2. **Ask whether that commit changed a plan.** List its files with `git show --name-only <commit>`
   and look for one under `profile.artifacts.plans`, or under `<docs_root>/plans` where that key is
   not set.
3. **If it did, put one line in the fix commit's message body**, as shown under "The line" below.
   The path is from the repository root, spelled exactly as `git` lists it.
4. **If it did not, write no line**, and tell the person, in the reply that hands over the fix,
   that no plan was found for the cause.

## The line

It goes at the start of a line, with nothing before it and nothing after the path, because
`keel plan report` matches the whole line exactly. Copy it without any indent:

```text
Reworks <root-relative path of that plan>
```

For example `Reworks docs/plans/2026-10-16-measure-delivery-and-implementer-model.md`.

## A body line, not a trailer

The line sits in the message body. It is not a `Co-Authored-By` style trailer and not an attribution
footer, so it stays correct where `conventions.no_attribution_footers` is true.
