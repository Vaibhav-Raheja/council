#!/usr/bin/env bash
# Delegation benchmark: hand one task to one worker CLI, then score it.
#   run.sh <codex|agy|sonnet> <task> <outdir>
# The worker edits a throwaway git repo under <outdir>/<task>-<worker>/work.
# Hidden acceptance tests live in tasks/<task>/hidden and never enter the
# worker's tree; scoring runs them in a separate copy.
# This calls real models and spends quota. It is not part of run-tests.sh.
set -uo pipefail

BENCH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$BENCH/workers.sh"
worker="$1" task="$2" out="$3"
T="$BENCH/tasks/$task"
R="$out/$task-$worker"
rm -rf "$R"; mkdir -p "$R"
W="$R/work"

cp -r "$T/repo" "$W"
mkdir -p "$R/hidden"; cp -r "$T/hidden/." "$R/hidden/"
[ -f "$T/gen.py" ] && python3 "$T/gen.py" "$W" "$R/hidden"
git -C "$W" init -q
git -C "$W" -c user.name=bench -c user.email=bench@local add -A
git -C "$W" -c user.name=bench -c user.email=bench@local commit -qm base
base="$(git -C "$W" rev-parse HEAD)"

prompt="$(cat "$T/prompt.md")"
case "$worker" in
  agy) prompt="$prompt

Shell commands are not available to you, so you cannot run the tests. Read and edit the files directly. Do not search the web or use the browser: everything you need is in this repository. When finished, say what you changed." ;;
  *)   prompt="$prompt

You may run the tests with: python3 -m pytest -q
When finished, say what you changed and whether the tests pass." ;;
esac

start=$(date +%s)
invoke_worker "$worker" "$W" "$prompt" "${BENCH_TIMEOUT:-900}" "$R/last.txt" >"$R/transcript.txt" 2>&1
rc=$?
secs=$(( $(date +%s) - start ))

# Everything the worker changed against base: committed, staged, unstaged, untracked.
git -C "$W" add -A -N 2>/dev/null
git -C "$W" diff "$base" >"$R/diff.patch"
changed="$(git -C "$W" diff --name-only "$base" | grep -v '__pycache__\|\.pytest_cache' || true)"
outside=""
for f in $changed; do
  in=0
  for s in $(cat "$T/scope"); do case "$f" in "$s"*) in=1 ;; esac; done
  [ $in = 1 ] || outside="$outside $f"
done

# Score in a copy so the worker's tree is never touched by the hidden tests.
S="$R/score"; rm -rf "$S"; cp -r "$W" "$S"; rm -rf "$S/.git"
mkdir -p "$S/hidden_tests"; cp -r "$R/hidden/." "$S/hidden_tests/"
res="$(cd "$S" && timeout 120 python3 -m pytest -q -p no:cacheprovider hidden_tests 2>&1 | tail -1)"
own="$(cd "$S" && timeout 120 python3 -m pytest -q -p no:cacheprovider tests 2>&1 | tail -1)"

printf '%s\t%s\trc=%s\t%ss\thidden: %s\town: %s\tfiles=%s\toutside_scope=%s\n' \
  "$task" "$worker" "$rc" "$secs" "$res" "$own" "$(echo $changed | wc -w)" "${outside:-none}" \
  | tee -a "$out/results.tsv"
