#!/usr/bin/env bash
# A `grep` function for test files: a quiet grep that reads all of its input.
#
# What it is for. `producer | grep -q needle` under `set -o pipefail` is a race: grep exits at the
# first match, the producer is killed by SIGPIPE on its next write, and pipefail turns that into a
# failed pipeline. The race is recorded in the comment under `set -uo pipefail` in
# tests/validate-skills.sh, and in the entry "2026-10-21, the step-shape pair for ADR-0012" in
# tests/evals/results.md (five failures in 18,000 runs). This function removes the quiet option and
# sends grep's standard output to /dev/null, so grep reads its input to the end and the producer
# is never cut off. The exit status is grep's own. A test file loads it by replacing its first
# `set -uo pipefail` line with exactly this line, so no later line moves:
#
#   set -uo pipefail; . "$(dirname "${BASH_SOURCE[0]}")/grep-quiet.sh"
#
# What it changes. A call with a quiet option (-q, a single-dash bundle holding q, --quiet or
# --silent) and no file operand and no recursive option. Every other call is passed to grep with
# its arguments unchanged.
#
# Its limits:
#   - A call with a file operand, or with -r, -R, --recursive or --dereference-recursive, passes
#     through untouched. It is not reading a pipe, and dropping -q there would turn a call that both
#     matches and meets an error from status 0 into 2. An operand of - is standard input.
#   - Options written after the first operand (`grep pat -q`) are left as they are.
#   - A test file that loads this resolves grep's path with `type -P`, because `command -v grep`
#     prints `grep`, the function's name.
#   - Every variable here starts with `_gq_`. shellcheck -x follows the source into every test file
#     and does not scope a function's locals, so a bare name would be reported against the test's
#     own variables of the same name.
#
# What it does not cover:
#   - `-m N` with a quiet option still stops grep early, so the race stays for `-qm 1`. None is in
#     the tree when this was written.
#   - Since the function reads to the end, a quiet grep on a producer that never ends, such as
#     `tail -f`, waits for ever instead of stopping at the first match.
#
# It is a function and is not exported, so a script under test, which runs as a child process, still
# gets the real grep. Only test files source this; nothing under bin/, lib/, hooks/ or tests/evals/.
# It is not executable. Written for bash 3.2: no associative arrays, and an array that can be empty
# expands as ${a[@]+"${a[@]}"}.

grep() {
  local _gq_w _gq_c _gq_i _gq_kept
  local -a _gq_out
  local _gq_skip _gq_pat _gq_stop _gq_n _gq_quiet _gq_files _gq_rec _gq_isop
  _gq_skip=0
  _gq_pat=0
  _gq_stop=0
  _gq_n=0
  _gq_quiet=0
  _gq_files=0
  _gq_rec=0

  for _gq_w in ${1+"$@"}; do
    _gq_isop=0
    if [ "$_gq_skip" -eq 1 ]; then
      # The argument of an option that takes one: data, never a flag.
      _gq_skip=0
      _gq_out+=("$_gq_w")
      continue
    fi
    if [ "$_gq_stop" -eq 1 ]; then
      _gq_isop=1
    else
      case "$_gq_w" in
        --)
          _gq_stop=1
          _gq_out+=("$_gq_w")
          ;;
        --quiet | --silent)
          _gq_quiet=1
          ;;
        --recursive | --dereference-recursive)
          _gq_rec=1
          _gq_out+=("$_gq_w")
          ;;
        --regexp | --file)
          _gq_pat=1
          _gq_skip=1
          _gq_out+=("$_gq_w")
          ;;
        --regexp=* | --file=*)
          _gq_pat=1
          _gq_out+=("$_gq_w")
          ;;
        --max-count | --after-context | --before-context | --context | --devices | --directories | \
          --include | --exclude | --exclude-dir | --exclude-from | --label | --binary-files | \
          --group-separator)
          _gq_skip=1
          _gq_out+=("$_gq_w")
          ;;
        --*)
          _gq_out+=("$_gq_w")
          ;;
        - | "" | [!-]*)
          _gq_isop=1
          ;;
        -*)
          # A single-dash bundle: drop q, note r and R, and stop at a letter that takes an argument,
          # which owns the rest of the bundle or, ending it, the next word.
          _gq_kept=""
          _gq_i=1
          while [ "$_gq_i" -lt "${#_gq_w}" ]; do
            _gq_c="${_gq_w:$_gq_i:1}"
            case "$_gq_c" in
              q)
                _gq_quiet=1
                ;;
              r | R)
                _gq_rec=1
                _gq_kept="$_gq_kept$_gq_c"
                ;;
              e | f | m | A | B | C | d | D)
                _gq_kept="$_gq_kept${_gq_w:$_gq_i}"
                if [ "$_gq_c" = e ] || [ "$_gq_c" = f ]; then
                  _gq_pat=1
                fi
                if [ $((_gq_i + 1)) -ge "${#_gq_w}" ]; then
                  _gq_skip=1
                fi
                break
                ;;
              *)
                _gq_kept="$_gq_kept$_gq_c"
                ;;
            esac
            _gq_i=$((_gq_i + 1))
          done
          if [ -n "$_gq_kept" ]; then
            _gq_out+=("-$_gq_kept")
          fi
          ;;
      esac
    fi
    if [ "$_gq_isop" -eq 1 ]; then
      # The first operand is the pattern unless -e, -f, --regexp or --file gave it; the rest are
      # files, except -, which is standard input. Option scanning ends at the first operand.
      _gq_n=$((_gq_n + 1))
      _gq_stop=1
      if [ "$_gq_w" != "-" ]; then
        if [ "$_gq_pat" -eq 1 ] || [ "$_gq_n" -ge 2 ]; then
          _gq_files=1
        fi
      fi
      _gq_out+=("$_gq_w")
    fi
  done

  if [ "$_gq_quiet" -eq 1 ] && [ "$_gq_files" -eq 0 ] && [ "$_gq_rec" -eq 0 ]; then
    command grep ${_gq_out[@]+"${_gq_out[@]}"} > /dev/null
  else
    command grep ${1+"$@"}
  fi
}
