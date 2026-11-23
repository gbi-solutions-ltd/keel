#!/bin/zsh
# gate-sharded.sh: an example runner, not a gate of its own. It runs check-behaviours.mjs in
# BEH_SHARDS processes at once, then visual-diff.mjs --baseline in DIFF_SHARDS processes at once,
# then visual-diff.mjs --app in APP_SHARDS processes at once, then quality-check.mjs in
# QUALITY_SHARDS processes at once (on APP when set, else on the mockup), and merges each with merge-shards.mjs,
# so the output equals one serial run of each. Copy it and add a mockup's own checks around it.
#
#   MOCKUP=<mockup-dir> [BASELINE=<png-dir>] [APP=<base-url>] [PIN_ARGS='--clock <iso> --seed <int>'] \
#   [BEH_ARGS='--file f --only p --tz zone'] [DIFF_ARGS='--expected f --skip re'] \
#   [APP_ARGS='--expected f --route re'] [BEH_SHARDS=4] [DIFF_SHARDS=3] [DIFF_WORKERS=2] \
#   [APP_SHARDS=3] [QUALITY_SHARDS=0] [QUALITY_ARGS='--screen re'] [SEQUENTIAL=1] [OUT=<work-dir>] zsh gate-sharded.sh
#
# PIN_ARGS go to every tool, BEH_ARGS to check-behaviours and its merge (it plans again from --file
# and --only), DIFF_ARGS to visual-diff --baseline, APP_ARGS to visual-diff --app. The baseline phase
# is skipped when BASELINE is unset, the app phase when APP is unset, the behaviours phase when
# BEH_SHARDS=0, the quality phase unless QUALITY_SHARDS is above 0 (QUALITY_ARGS go to quality-check,
# which takes no pins; their --warnings also goes to the quality merge, which writes the report). Each shard starts its own server and Chromium; lower the shard counts or
# DIFF_WORKERS if timings get flaky. SEQUENTIAL=1 runs each phase's shards one after another
# instead of at once: on a loaded machine (load average well above the core count) parallel shards
# time out, shards in sequence do not.
# Work dir (default <mockup-dir>/.mockup-engine/gate-sharded): beh-K.out/.err/.code, behaviours.txt,
# diff-K/ (each shard's report), diff-K.log/.code, diff/ (the merged report.json and report.md),
# app-K/, app-K.log/.code, app/ (the merged app report), quality-K/, quality-K.log/.code, quality/.
# Exit with the highest code a merge returned: 1 when any merge fails, 2 when one could not run
# (lib/args.mjs's rule; a 2 is never folded into 1). Exit 2 before anything runs when a shard count is not a
# non-negative integer (DIFF_SHARDS and DIFF_WORKERS must be 1 or more when BASELINE is set,
# APP_SHARDS when APP is set), or when no phase is enabled. The behaviours phase prints the merge's
# failing rows and shard problems, then its tally; the whole merge is in beh-merge.log.
set -u
HERE=${0:A:h}
: ${MOCKUP:?set MOCKUP to the mockup folder}
MOCKUP=${MOCKUP:A}
BEH_SHARDS=${BEH_SHARDS:-4}
DIFF_SHARDS=${DIFF_SHARDS:-3}
DIFF_WORKERS=${DIFF_WORKERS:-2}
APP_SHARDS=${APP_SHARDS:-$DIFF_SHARDS}
QUALITY_SHARDS=${QUALITY_SHARDS:-0}
SEQUENTIAL=${SEQUENTIAL:-0}
OUT=${OUT:-$MOCKUP/.mockup-engine/gate-sharded}
# a count is digits only (zsh's <-> pattern), so 4x, -1 and 1.5 never reach arithmetic or {1..N}
count() { # name value minimum
  [[ $2 == <-> ]] && (( $2 >= $3 )) && return 0
  print -u2 "gate-sharded.sh: $1 must be an integer >= $3, got '$2'"
  exit 2
}
count BEH_SHARDS $BEH_SHARDS 0
count QUALITY_SHARDS $QUALITY_SHARDS 0
if [[ -n ${BASELINE:-} ]]; then count DIFF_SHARDS $DIFF_SHARDS 1; count DIFF_WORKERS $DIFF_WORKERS 1; fi
[[ -n ${APP:-} ]] && count APP_SHARDS $APP_SHARDS 1
if (( BEH_SHARDS == 0 && QUALITY_SHARDS == 0 )) && [[ -z ${BASELINE:-} && -z ${APP:-} ]]; then
  print -u2 'gate-sharded.sh: no phase is enabled (BEH_SHARDS=0, no BASELINE, no APP, QUALITY_SHARDS=0); nothing would run'
  exit 2
fi
# split as the shell would, then drop the quotes
pin=(${(Q)${(z)${PIN_ARGS:-}}})
beh=(${(Q)${(z)${BEH_ARGS:-}}})
dif=(${(Q)${(z)${DIFF_ARGS:-}}})
app=(${(Q)${(z)${APP_ARGS:-}}})
qua=(${(Q)${(z)${QUALITY_ARGS:-}}})
# the quality merge writes the report, so it takes the shards' --warnings (and only that: it has no --screen)
qwarn=()
(( ${qua[(I)--warnings]} )) && qwarn=(--warnings ${qua[${qua[(I)--warnings]}+1]})
# OUT is emptied: refuse the mockup, the current folder, home or a git root (visual-diff's own rule)
refusal=$(node --input-type=module -e "import { outDirRefusal } from '$HERE/lib/baseline-report.mjs'; const r = outDirRefusal(process.argv[1], { mockupDir: process.argv[2] }); if (r) console.log(r.replace(/^--out/, 'OUT'));" "$OUT" "$MOCKUP")
if [[ -n $refusal ]]; then print -u2 "gate-sharded.sh: $refusal"; exit 2; fi
rm -rf $OUT && mkdir -p $OUT
status_all=0
# the gate's code is the highest a merge returned: 2 (a merge could not run) outranks 1 (a fail)
keep() { (( $1 > status_all )) && status_all=$1; return 0 }
t0=$SECONDS
pids=()
# start one shard: in the background, or in the foreground with SEQUENTIAL=1
launch() {
  if [[ $SEQUENTIAL == 1 ]]; then "$@"; else "$@" & pids+=$!; fi
}
beh_shard() {
  node $HERE/check-behaviours.mjs --mockup $MOCKUP $pin $beh --shard $1/$BEH_SHARDS > $OUT/beh-$1.out 2> $OUT/beh-$1.err
  print $? > $OUT/beh-$1.code
}
diff_shard() {
  node $HERE/visual-diff.mjs --mockup $MOCKUP --baseline $BASELINE $pin $dif --workers $DIFF_WORKERS --shard $1/$DIFF_SHARDS --out $OUT/diff-$1 > $OUT/diff-$1.log 2>&1
  print $? > $OUT/diff-$1.code
}
app_shard() {
  node $HERE/visual-diff.mjs --mockup $MOCKUP --app $APP $pin $app --shard $1/$APP_SHARDS --out $OUT/app-$1 > $OUT/app-$1.log 2>&1
  print $? > $OUT/app-$1.code
}
quality_shard() {
  local target=()
  [[ -n ${APP:-} ]] && target=(--app $APP)
  node $HERE/quality-check.mjs --mockup $MOCKUP $target $qua --shard $1/$QUALITY_SHARDS --out $OUT/quality-$1 > $OUT/quality-$1.log 2>&1
  print $? > $OUT/quality-$1.code
}

if (( BEH_SHARDS > 0 )); then
  pids=()
  for k in {1..$BEH_SHARDS}; do launch beh_shard $k; done
  (( ${#pids} )) && wait $pids
  node $HERE/merge-shards.mjs behaviours --dir $OUT --shards $BEH_SHARDS --mockup $MOCKUP $beh > $OUT/beh-merge.log 2>&1
  keep $?
  # every row that is not ok (fails, shard problems, a merge error), then the tally
  grep -v ': ok$' $OUT/beh-merge.log
  print -u2 "# behaviours: $(( SECONDS - t0 ))s"
fi

if [[ -n ${BASELINE:-} ]]; then
  t1=$SECONDS
  pids=()
  for k in {1..$DIFF_SHARDS}; do launch diff_shard $k; done
  (( ${#pids} )) && wait $pids
  node $HERE/merge-shards.mjs diff --dir $OUT --shards $DIFF_SHARDS
  keep $?
  print -u2 "# baseline diff: $(( SECONDS - t1 ))s"
fi

if [[ -n ${APP:-} ]]; then
  t2=$SECONDS
  pids=()
  for k in {1..$APP_SHARDS}; do launch app_shard $k; done
  (( ${#pids} )) && wait $pids
  node $HERE/merge-shards.mjs app --dir $OUT --shards $APP_SHARDS
  keep $?
  print -u2 "# app diff: $(( SECONDS - t2 ))s"
fi

if (( QUALITY_SHARDS > 0 )); then
  t3=$SECONDS
  pids=()
  for k in {1..$QUALITY_SHARDS}; do launch quality_shard $k; done
  (( ${#pids} )) && wait $pids
  node $HERE/merge-shards.mjs quality --dir $OUT --shards $QUALITY_SHARDS --mockup $MOCKUP $qwarn
  keep $?
  print -u2 "# quality: $(( SECONDS - t3 ))s"
fi
exit $status_all
