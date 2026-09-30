# Idea: file names the other two scans misread, and the pattern grep's locale

| | |
|---|---|
| Raised by | The 2026-09-27 quality reviews of tasks 1b and 1c in `docs/plans/2026-09-27-push-scan-reads-pushed-commits.md`: task 1b's findings 3 and 4, and task 1c's finding 2, each reproduced by the review that raised it |
| Status | **recorded, not shaped.** The maintainer chose on 2026-09-27 to fix the supply chain scanner's two name bugs in that plan (tasks 1b and 1c) and to file these two; the locale finding from task 1c's review joined them the same day |
| Next | `shape-idea`, or `debug` then `tdd` if the case against is thin |

The supply chain scanner skipped every file whose name git quotes, a name holding a byte outside
printable ASCII, a tab, a double quote or a backslash, because it read `git ls-files` one name per
line: the quoted form matches no file on disk. Task 1b of that plan fixed it there. The same shape
is in two other places, and neither was in that plan's scope.

**The leak scanner.** `tests/no-internal-leaks.sh` has its own `list_files`, an identical copy of
the scanner's old one (`` tests/no-internal-leaks.sh#Everything tracked, or everything present when not in a repo ``),
still reading `git ls-files` without `-z`. A leak in a file whose name git quotes passes it. Its
walk also runs `` LC_ALL=C grep -qI . "$f" ``, so a file named `-` reads grep's stdin, which is the
walk's own input, the false pass task 1c fixed in the supply chain scanner.

**The key-material step `write_ci` generates.** Every generated workflow refuses committed key
material with `` bin/keel#if git ls-files | grep -qE ``. A committed `docs/café.pem` is listed as
`"docs/caf\303\251.pem"`, the regex anchored at `$` never matches the closing quote, and the key
passes the CI check. The review confirmed it in a scratch repository. Every repository keel has
generated a workflow for carries this step.

Both are false passes in a check whose job is to stop the thing it misses, and both have the fix
task 1b used: ask git for NUL-separated names, or `git -c core.quotePath=false`, which covers the
non-ASCII case though not a tab, a double quote or a backslash.

**The pattern grep's locale.** Found by the review of task 1c's first attempt, and not a file-name
bug, so recorded here rather than fixed there. The walk decides a file is text under `LC_ALL=C`,
but the pattern grep runs in the user's locale. Under `C.UTF-8`, the GitHub runner's default, GNU
grep 3.5 and later treat a line holding a byte that is not valid UTF-8 as binary, print nothing for
the file, and send "binary file matches" to stderr, which the scanner discards. The review
reproduced it in `debian:12` with a payload beside an `\xe9` byte. Task 1c's `-a` stops the binary
treatment, but with `-a` alone under `C.UTF-8` a pattern such as `[^|]*` still does not match the
invalid byte, so the payload with `\xe9` in its URL passes. Running the pattern grep under
`LC_ALL=C` closes that, at a cost the review named: `agent-conceal`'s `n.t` stops matching a
curly apostrophe, three bytes in UTF-8, and would need to become something like `n.{1,3}t`.

**The orphan-hook check.** Found by the review of task 1c's second attempt, in the scanner itself
and outside that task's change. The check runs `grep -qF "$base"` over the hooks manifests, with
the hook's own name where grep reads options, so a hook named `-e` becomes `grep -qF -e
hooks/hooks.json`: grep has no file operand, reads the loop's stdin, the rest of the `find` output,
and matches there. The review reproduced `hooks/-e` going unreported as an orphan. The fix is
`grep -qF -e "$base"`.
