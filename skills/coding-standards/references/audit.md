# Audit mode

Derive what a repository already does, and report it. **An audit is a derivation and not an agreed
standard**, and it says so in its own header. Nothing else is written, and no file that was read is
edited.

Run Step 1 and Step 2 of `SKILL.md`: sample at least ten files across different areas, and split
what a tool can check from what needs judgement. **Step 2's `Goes to` column is author's, not
audit's.** Sort the piles and report which pile each convention landed in; write neither the config
nor the standard those cells name. Then write
`<docs_root>/audits/YYYY-MM-DD-standards-audit.md`. The `-audit` suffix is not decoration: assess
writes `YYYY-MM-DD-standards.md` on the same day in the same directory, and one path for two modes
loses a report.

## The report, in this fixed order

1. **Header.** The commit **where the tree is a repository**, the date, how many files were sampled
   and out of how many, **saying which files the denominator counts**, and the sentence "This is a
   derivation of what the code does, not a standard anybody has agreed."
2. **What was sampled, and what was not.** Named directories, and what a reader should not conclude
   from the ones that were skipped.
3. **The conventions found**, one per entry, each with the rule, a `path:line` that shows it, the
   count of conforming against total sites, and which of Step 2's two piles it fell in.
4. **The splits**, where the tree contradicts itself. **Step 1's counting rule decides these: the
   majority is the convention, except where the majority pattern is the defect**, and there the
   report records the minority as the rule and says why, because writing the majority down would
   sanction it. Give the conforming-to-total ratio on every split, so a reader can see the split was
   counted rather than judged.
5. **What has no convention.** Areas where the code is genuinely inconsistent with no defensible
   reading. Naming them is the honest output, not a gap in the audit.
6. **Not covered**, explicit.

**The counting unit is stated before any number**, the way `assessment-report.md` requires of
assess: one convention is one rule a reader could follow, and a site is one call or declaration that
either follows it or does not.

## What audit never does

Write `<docs_root>/standards.md`. Edit a file it read. Run anything that changes the project. Make a
network request.

## How audit ends

By offering to author, which is [audit-offer.md](audit-offer.md).
