#!/usr/bin/env bash
# Validate the benchmark itself, without calling any model: every task's hidden
# tests must FAIL on the untouched repo and PASS with tasks/<task>/reference
# overlaid (largectx's reference is a sed applied to the generated rule).
set -uo pipefail
BENCH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail=0

prep() {  # prep <task> <dir>
  cp -r "$BENCH/tasks/$1/repo/." "$2/"
  mkdir -p "$2/hidden_tests"; cp -r "$BENCH/tasks/$1/hidden/." "$2/hidden_tests/"
  [ -f "$BENCH/tasks/$1/gen.py" ] && python3 "$BENCH/tasks/$1/gen.py" "$2" "$2/hidden_tests"
  return 0
}
hidden() { (cd "$1" && python3 -m pytest -q -p no:cacheprovider hidden_tests >/dev/null 2>&1); }

for t in ${BENCH_TASKS:-implement refactor debug largectx rootcause convention audit}; do
  d="$TMP/$t-base"; mkdir -p "$d"; prep "$t" "$d"
  if hidden "$d"; then echo "BAD   $t: hidden tests pass on the untouched repo"; fail=1
  else echo "ok    $t: hidden tests fail on base"; fi

  d="$TMP/$t-ref"; mkdir -p "$d"; prep "$t" "$d"
  if [ "$t" = largectx ]; then
    sed -i 's/ > 100:/ >= 100:/' "$d/pricing/rules/r27.py"
  else
    cp -r "$BENCH/tasks/$t/reference/." "$d/"
  fi
  if hidden "$d"; then echo "ok    $t: hidden tests pass with reference"
  else echo "BAD   $t: reference fails hidden tests"; (cd "$d" && python3 -m pytest -q -p no:cacheprovider hidden_tests 2>&1 | tail -15); fail=1; fi
done
exit $fail
