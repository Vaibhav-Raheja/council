#!/usr/bin/env bash
# Frame-trap eval: does each advisor challenge a premise the question plants?
#   frames/run.sh <outdir> [raw|ask]
# Each q*.txt plants one trap (a wrong "already decided" constraint, a false
# premise, an option set that omits the right answer). `patterns` holds, per
# question, an ERE that only an answer escaping the frame would contain.
# raw: grades each advisor's verbatim answer. ask: grades the full round output.
# Calls real models and spends quota; not part of run-tests.sh.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# COUNCIL_BIN runs another checkout, e.g. an unmodified main for a baseline;
# FRAMES limits the run to some questions ("q4 q5").
COUNCIL="${COUNCIL_BIN:-$HERE/../../../council}"
out="$1" mode="${2:-raw}"
mkdir -p "$out"
neutral="$out/neutral-cwd"; mkdir -p "$neutral"

for q in "$HERE"/q*.txt; do
  if [ -n "${FRAMES:-}" ]; then
    case " $FRAMES " in *" $(basename "$q" | cut -d- -f1) "*) ;; *) continue ;; esac
  fi
  name="$(basename "$q" .txt)"
  pat="$(awk -F'\t' -v n="$name" '$1 == n { print $2 }' "$HERE/patterns")"
  # From an empty dir: Claude advisors may read files under the cwd, and this
  # repo holds the answers to some of these questions.
  ( cd "$neutral" && timeout 900 "$COUNCIL" "$mode" < "$q" ) > "$out/$name.$mode" 2>"$out/$name.$mode.err"
  rc=$?
  if [ "$mode" = raw ]; then
    # One verdict per "===== <label> =====" section. A keyword hit is a rough
    # signal only; on judgment questions, read the answers' openings.
    rm -f "$out/$name.sec."*
    awk -v base="$out/$name.sec." '/^===== .* =====$/ { n++ } n { print > (base n) }' "$out/$name.$mode"
    for s in "$out/$name.sec."*; do
      [ -f "$s" ] || continue
      label="$(head -1 "$s" | sed 's/^===== //; s/ =====$//')"
      if grep -Eqi "$pat" "$s"; then v=CHALLENGED; else v=accepted-frame; fi
      printf '%s\t%s\trc=%s\t%s\n' "$name" "$label" "$rc" "$v"
    done
  else
    if grep -Eqi "$pat" "$out/$name.$mode"; then v=CHALLENGED; else v=accepted-frame; fi
    printf '%s\tround\trc=%s\t%s\t%s\n' "$name" "$rc" "$v" "$(grep -m1 -E '^(UPHELD|AMENDED|OVERTURNED)' "$out/$name.$mode")"
  fi
done | tee -a "$out/frames.tsv"
