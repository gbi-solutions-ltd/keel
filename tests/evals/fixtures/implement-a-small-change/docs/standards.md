# Standards

- Bash, with `set -uo pipefail` in every test file.
- Functions are named in snake_case and documented with a one-line usage comment above them.
- Every behaviour has a case in `tests/test-<source file>.sh`, written before the code.
- Never commit to `main`: work on a branch and merge by pull request.
