#!/usr/bin/env bash
# Deterministic tests. Uses stub providers under test/fixtures, so nothing here
# calls a real model, costs quota, or needs network.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$TEST_DIR/.." && pwd)"
FIX="$TEST_DIR/fixtures"

PASS=0; FAIL=0
ok()   { PASS=$(( PASS + 1 )); printf '  PASS  %s\n' "$1"; }
bad()  { FAIL=$(( FAIL + 1 )); printf '  FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected [$3] got [$2]"; fi; }

# The stub tree is a complete COUNCIL_HOME: its own providers, policy and lib.
run() { COUNCIL_HOME="$FIX" "$REPO/council" "$@" 2>&1; }

echo "council test suite"
echo

# ---------------------------------------------------------------- guards
echo "guards"
( . "$REPO/lib/common.sh"
  COUNCIL_HOP_DEPTH=abc; d="$(council_hop_depth)"
  [ "$d" = "99" ] && exit 0 || exit 1 ) \
  && ok "non-numeric hop depth fails CLOSED (99, not 0)" \
  || bad "non-numeric hop depth fails closed"

( . "$REPO/lib/common.sh"
  COUNCIL_HOP_DEPTH=""; d="$(council_hop_depth)"
  [ "$d" = "0" ] && exit 0 || exit 1 ) \
  && ok "empty hop depth reads as 0" \
  || bad "empty hop depth reads as 0"

out="$(COUNCIL_HOP_DEPTH=9 run ask "x")"; rc=$?
check "recursion refused past the hop limit" "$rc" "3"

( . "$REPO/lib/common.sh"
  f="$(mktemp)"; printf '   \n\t\n' > "$f"
  council_has_content "$f" && { rm -f "$f"; exit 1; }; rm -f "$f"; exit 0 ) \
  && ok "whitespace-only output is not an answer" \
  || bad "whitespace-only output is not an answer"

# A copy of the script separated from its repo must say so, not emit a cascade
# of "command not found" from every missing helper.
detached="$(mktemp -d)"
cp "$REPO/council" "$detached/council"; chmod +x "$detached/council"
out="$(env -u COUNCIL_HOME "$detached/council" doctor 2>&1)"; rc=$?
rm -rf "$detached"
if [ "$rc" = "4" ] && case "$out" in *"cannot find the council library"*) true ;; *) false ;; esac; then
  ok "detached script fails loudly with a clear cause"
else
  bad "detached script fails loudly" "rc=$rc out=$(echo "$out" | head -1)"
fi

# ---------------------------------------------------------------- registry
echo
echo "registry"
ids="$(run providers | awk 'NR>1{print $1}' | sort | tr '\n' ' ')"
check "stub providers discovered" "$ids" "alpha beta judge "

caps="$(COUNCIL_HOME="$FIX" bash -c '. "$0/lib/common.sh"; . "$0/lib/registry.sh"; council_provider_meta alpha PROVIDER_CAPS' "$FIX")"
check "provider metadata readable" "$caps" "reason review"

# Providers must not leak provider_invoke into each other.
leak="$(COUNCIL_HOME="$FIX" bash -c '
  . "$0/lib/common.sh"; . "$0/lib/registry.sh"
  a="$(printf x | council_invoke alpha)"; b="$(printf x | council_invoke beta)"
  case "$a" in *PostgreSQL*) ;; *) echo LEAK; exit ;; esac
  case "$b" in *MongoDB*)    ;; *) echo LEAK; exit ;; esac
  echo CLEAN' "$FIX")"
check "provider isolation (no provider_invoke leak)" "$leak" "CLEAN"

# ---------------------------------------------------------------- policy
echo
echo "policy"
res="$(COUNCIL_HOME="$FIX" bash -c '
  . "$0/lib/common.sh"; . "$0/lib/registry.sh"; . "$0/lib/policy.sh"
  council_policy_reserved_judge' "$FIX")"
check "highest-ranked arbiter is reserved" "$res" "judge"

panel="$(COUNCIL_HOME="$FIX" bash -c '
  . "$0/lib/common.sh"; . "$0/lib/registry.sh"; . "$0/lib/policy.sh"
  council_policy_panel advise "" "$(council_policy_reserved_judge)" | tr "\n" " "' "$FIX")"
check "reserved judge excluded from the panel" "$panel" "alpha beta "

judge="$(COUNCIL_HOME="$FIX" bash -c '
  . "$0/lib/common.sh"; . "$0/lib/registry.sh"; . "$0/lib/policy.sh"
  council_policy_judge arbitrate alpha beta' "$FIX")"
check "no-self-judgement: arbiter is not an advisor" "$judge" "judge"

# With every eligible provider already an advisor there must be NO judge left.
none="$(COUNCIL_HOME="$FIX" bash -c '
  . "$0/lib/common.sh"; . "$0/lib/registry.sh"; . "$0/lib/policy.sh"
  council_policy_judge arbitrate alpha beta judge || echo EMPTY' "$FIX")"
check "no-self-judgement holds when all are advisors" "$none" "EMPTY"

cap="$(COUNCIL_HOME="$FIX" bash -c '
  . "$0/lib/common.sh"; . "$0/lib/registry.sh"; . "$0/lib/policy.sh"
  council_policy_select explore | wc -l | tr -d " "' "$FIX")"
check "no stub declares 'explore', so none is selected" "$cap" "0"

out="$(run explore "$REPO" "x")"
case "$out" in *"explore"*) ok "explore fails loudly with no capable provider" ;;
               *) bad "explore fails loudly" "$out" ;; esac

# ---------------------------------------------------------------- consensus
echo
echo "consensus"
out="$(COUNCIL_TEST_VERDICT=AGREE run ask "postgres or mongo?")"
case "$out" in *SYNTHESIS*) ok "AGREE -> chair synthesises" ;;
               *) bad "AGREE -> chair synthesises" "$out" ;; esac

out="$(COUNCIL_TEST_VERDICT=DISAGREE run ask "postgres or mongo?")"
case "$out" in *Stalemate*) ok "DISAGREE -> stalemate declared" ;;
               *) bad "DISAGREE -> stalemate declared" "$out" ;; esac
case "$out" in *TIEBREAK-VERDICT*) ok "DISAGREE -> third model issues a verdict" ;;
               *) bad "DISAGREE -> third model issues a verdict" "$out" ;; esac

out="$(run raw "postgres or mongo?")"
case "$out" in *PostgreSQL*MongoDB*) ok "raw shows every advisor verbatim" ;;
               *) bad "raw shows every advisor verbatim" "$out" ;; esac

# ---------------------------------------------------------------- summary
echo
echo "─────────────────────────"
printf 'passed %d, failed %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
