#!/usr/bin/env bash
# Run every task for one worker, one at a time (one job per provider keeps
# rate limits from being misread as task failures).
#   suite.sh <codex|agy|sonnet> <outdir>
BENCH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for t in implement refactor debug largectx; do
  "$BENCH/run.sh" "$1" "$t" "$2"
done
