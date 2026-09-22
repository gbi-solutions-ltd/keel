# Windows: python3 detection is wrong in two ways

Two PRs opened directly against the public repo (`gbi-solutions-ltd/keel`, branches
`fix/python3-presence-is-not-runnability` and `fix/windows-crlf-in-python-output`, gfsekamanya,
2026-09-07) describe real bugs in `bin/keel` that are still present here. The public repo has no
shared history with this one, so those PRs cannot land as-is; the fixes need to be made here and
reach the public tree through the normal release process. Studied 2026-09-22 against `main`.

## Bug 1: `command -v python3` finds a shim that does not run Python

Windows' App Execution Alias puts a `python3.exe` on PATH even when Python is not installed. It
prints "Python was not found; run without arguments to install from the Microsoft Store." and
exits 49, doing nothing. `command -v python3` finds it, so `HAVE_PYTHON` is set to 1 and every
downstream check that gates on `have_python()` believes python3 works.

**Sites, all still using `command -v python3`, none sharing a single fix:**

- `bin/keel:253-254`, the central `HAVE_PYTHON` flag `merge_permissions_into_settings` and others
  read
- `bin/keel:1439-1440`, doctor's profile-parse check, which folds "didn't run" and "invalid JSON"
  into one failure message
- `bin/keel:1910`, the pre-push loosening check, `have_py=1`, does not go through `HAVE_PYTHON`
- `bin/keel:2109`, the pre-commit guard, `if ! command -v python3`, same

**Fix:** replace `command -v python3` with `python3 -c 'pass'` (actually runs the interpreter, so
the Store shim's exit 49 is caught) at all four sites, not just the first. At the doctor call site,
also capture stderr and distinguish "not found" from a genuine JSON parse failure.

## Bug 2: python3 output on Windows carries a trailing CR

Windows' text-mode stdout adds `\r` before the `\n` on every `print()` line. `read -r` does not
strip it, so a real path compared with `[ -e ]` reads as absent because the string carries an
invisible trailing character.

**Sites still present:**

- `bin/keel:288`, `JSON_CACHE`
- `bin/keel:1541` (line moved since the PR; same call), the artifacts loop

**Already moot:** the PR's third site, `SETTINGS_REPORT`, no longer exists, superseded by the
harness capability-manifest system since 2026-09-07.

**Fix:** append `| tr -d '\r'` to both remaining multi-line python3 invocations. No-op on
macOS/Linux.

## What this needs that the original PRs did not have

Neither PR touched `tests/`. Both bugs are Windows-only; nothing in `tests/` or CI runs on
Windows, so there is no coverage and no CI signal would have caught either. Add:

- A stubbed-interpreter test reproducing the Store-alias shape: a `python3` on `PATH` that prints
  the not-found message and exits 49, asserting `have_python()` (or whichever site) reads it as
  absent, not present. One per detection site listed above, since fixing the central flag does not
  fix the three sites that read `command -v python3` directly.
- A CRLF-emitting python3 stub, asserting the two remaining call sites strip it before comparing.

## Disposition

Land as ordinary `fix:` commits through the normal `sandbox` → PR → `main` flow, each with its own
test. Once shipped in a release, close both public PRs and delete both public branches, they were
opened directly against the public repo, which is a fresh export with no relationship to how a fix
actually reaches it.
