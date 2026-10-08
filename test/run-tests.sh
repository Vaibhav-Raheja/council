#!/usr/bin/env bash
# Deterministic tests. Uses stub providers under test/fixtures, so nothing here
# calls a real model, costs quota, or needs network.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$TEST_DIR/.." && pwd)"
# The stub tree supplies providers and policy; the engine library comes from the
# repo. A COUNCIL_HOME without lib/ is refused (see the detached-script test).
FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT
ln -s "$REPO/lib" "$FIX/lib"
ln -s "$TEST_DIR/fixtures/providers" "$FIX/providers"
ln -s "$TEST_DIR/fixtures/policy" "$FIX/policy"

PASS=0; FAIL=0
ok()   { PASS=$(( PASS + 1 )); printf '  PASS  %s\n' "$1"; }
bad()  { FAIL=$(( FAIL + 1 )); printf '  FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected [$3] got [$2]"; fi; }

# The stub tree is a complete COUNCIL_HOME: its own providers, policy and lib.
# stdin is /dev/null: read_question reads a piped question, and an inherited
# open stdin (CI, a non-tty shell) would block it forever.
run() { COUNCIL_HOME="$FIX" "$REPO/council" "$@" 2>&1 </dev/null; }

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
check "stub providers discovered" "$ids" "alpha beta final judge "

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
  council_policy_panel advise "" $(council_policy_reserved) | tr "\n" " "' "$FIX")"
check "judge and final reviewer excluded from the panel" "$panel" "alpha beta "

fin="$(COUNCIL_HOME="$FIX" bash -c '
  . "$0/lib/common.sh"; . "$0/lib/registry.sh"; . "$0/lib/policy.sh"
  council_policy_judge finalize alpha beta judge' "$FIX")"
check "final reviewer is neither advisor nor judge" "$fin" "final"

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
case "$out" in *SYNTHESIS*) bad "AGREE -> final reviewer answers, no separate synthesis" "$out" ;;
               *"final call (final)"*UPHELD*SAW-LABELS*SAW-ARBITER*FINAL-ANSWER*)
                 ok "AGREE -> final reviewer answers, no separate synthesis" ;;
               *) bad "AGREE -> final reviewer answers, no separate synthesis" "$out" ;; esac

out="$(COUNCIL_TEST_VERDICT=AGREE COUNCIL_SKIP_FINAL=1 run ask "postgres or mongo?")"
case "$out" in *FINAL-ANSWER*) bad "COUNCIL_SKIP_FINAL=1 -> chair synthesises" "$out" ;;
               *SYNTHESIS*) ok "COUNCIL_SKIP_FINAL=1 -> chair synthesises" ;;
               *) bad "COUNCIL_SKIP_FINAL=1 -> chair synthesises" "$out" ;; esac

out="$(COUNCIL_TEST_VERDICT=AGREE COUNCIL_TEST_FINAL_FAIL=1 run ask "postgres or mongo?")"
case "$out" in *SYNTHESIS*) ok "final reviewer fails -> falls back to synthesis" ;;
               *) bad "final reviewer fails -> falls back to synthesis" "$out" ;; esac

out="$(COUNCIL_TEST_VERDICT=DISAGREE run ask "postgres or mongo?")"
case "$out" in *Stalemate*) ok "DISAGREE -> stalemate declared" ;;
               *) bad "DISAGREE -> stalemate declared" "$out" ;; esac
case "$out" in *TIEBREAK-VERDICT*) ok "DISAGREE -> third model issues a verdict" ;;
               *) bad "DISAGREE -> third model issues a verdict" "$out" ;; esac
case "$out" in *TIEBREAK-VERDICT*"Final call (final)"*UPHELD*SAW-TIEBREAK*FINAL-ANSWER*)
                 ok "DISAGREE -> final reviewer reviews the tiebreak" ;;
               *) bad "DISAGREE -> final reviewer reviews the tiebreak" "$out" ;; esac

out="$(COUNCIL_TEST_VERDICT=DISAGREE COUNCIL_TEST_FINAL_FAIL=1 run ask "postgres or mongo?")"
case "$out" in *FINAL-ANSWER*) bad "final reviewer fails -> binding verdict stands" "$out" ;;
               *"Binding verdict (judge)"*TIEBREAK-VERDICT*) ok "final reviewer fails -> binding verdict stands" ;;
               *) bad "final reviewer fails -> binding verdict stands" "$out" ;; esac

out="$(run raw "postgres or mongo?")"
case "$out" in *PostgreSQL*MongoDB*) ok "raw shows every advisor verbatim" ;;
               *) bad "raw shows every advisor verbatim" "$out" ;; esac

# ---------------------------------------------------------------- final-call hardening
echo
echo "final-call hardening"
for w in AMENDED OVERTURNED; do
  out="$(COUNCIL_TEST_VERDICT=DISAGREE COUNCIL_TEST_FINAL_WORD=$w run ask "postgres or mongo?")"
  case "$out" in *"Provisional verdict (judge)"*TIEBREAK-VERDICT*"Final call (final)"*"$w"*FINAL-ANSWER*)
    ok "$w final call is reported after a provisional verdict" ;;
    *) bad "$w final call is reported after a provisional verdict" "$out" ;; esac
  case "$out" in *"Binding verdict"*) bad "$w: no 'Binding verdict' when a final call follows" "$out" ;;
    *) ok "$w: no 'Binding verdict' when a final call follows" ;; esac
done
# The overturned answer is what the round ends on, after the provisional verdict.
case "$out" in *TIEBREAK-VERDICT*"OVERTURN-TEXT: MongoDB after all") ok "an overturn's answer is the round's last word" ;;
  *) bad "an overturn's answer is the round's last word" "$out" ;; esac
out="$(COUNCIL_TEST_VERDICT=DISAGREE COUNCIL_TEST_FINAL_WORD=AMENDED run ask "postgres or mongo?")"
case "$out" in *TIEBREAK-VERDICT*"Final call (final)"*AMENDED*"AMEND-TEXT: PostgreSQL, with JSONB for the flexible part") ok "an amendment's answer is the round's last word" ;;
  *) bad "an amendment's answer is the round's last word" "$out" ;; esac
case "$out" in *SAW-NONCE*) ok "judge prompt section markers carry the round tag" ;;
  *) bad "judge prompt section markers carry the round tag" "$out" ;; esac
case "$(run raw "postgres or mongo?")" in *"[tag "*) bad "round tag never appears in user-facing output" ;;
  *) ok "round tag never appears in user-facing output" ;; esac

out="$(COUNCIL_TEST_VERDICT=AGREE COUNCIL_TEST_FINAL_MODE=malformed run ask "postgres or mongo?")"
case "$out" in *"not UPHELD/AMENDED/OVERTURNED"*SYNTHESIS*) ok "malformed final call (no verdict word) falls back" ;;
  *) bad "malformed final call (no verdict word) falls back" "$out" ;; esac
out="$(COUNCIL_TEST_VERDICT=AGREE COUNCIL_TEST_FINAL_MODE=noanswer run ask "postgres or mongo?")"
case "$out" in *"no non-empty 'Final answer'"*SYNTHESIS*) ok "malformed final call (no answer section) falls back" ;;
  *) bad "malformed final call (no answer section) falls back" "$out" ;; esac

out="$(COUNCIL_TEST_VERDICT=DISAGREE COUNCIL_TEST_TB_FAIL=1 run ask "postgres or mongo?")"
case "$out" in *"tiebreak failed"*"Final call (final)"*FINAL-ANSWER*) ok "tiebreak fails -> final reviewer still decides" ;;
  *) bad "tiebreak fails -> final reviewer still decides" "$out" ;; esac
case "$out" in *"Provisional verdict"*) bad "no provisional verdict when the tiebreak failed" "$out" ;;
  *) ok "no provisional verdict when the tiebreak failed" ;; esac

out="$(COUNCIL_TEST_BETA_FAIL=1 run ask "postgres or mongo?")"
case "$out" in *"One advisor answered — final call (final)"*FINAL-ANSWER*) ok "one advisor answered -> still reviewed" ;;
  *) bad "one advisor answered -> still reviewed" "$out" ;; esac

out="$(COUNCIL_TEST_VERDICT=AGREE COUNCIL_SKIP_FINAL=0 run ask "postgres or mongo?")"
case "$out" in *FINAL-ANSWER*) ok "COUNCIL_SKIP_FINAL=0 does not skip" ;;
  *) bad "COUNCIL_SKIP_FINAL=0 does not skip" "$out" ;; esac

out="$(COUNCIL_TEST_VERDICT=NOTAGREE run ask "postgres or mongo?")"
case "$out" in *Stalemate*) ok "'NOT AGREE' is not read as AGREE" ;;
  *) bad "'NOT AGREE' is not read as AGREE" "$out" ;; esac

# A missing file is refused before any temp file exists.
# Its own empty TMPDIR, so other processes' temp files cannot affect the count.
priv="$(mktemp -d)"
out="$(TMPDIR="$priv" run review /no/such/file)"; rc=$?
left="$(ls -A "$priv" | wc -l | tr -d ' ')"; rm -rf "$priv"
if [ "$rc" = 2 ] && [ "$left" = 0 ]; then ok "review of a missing file exits 2 and leaves no temp file"
else bad "review of a missing file exits 2 and leaves no temp file" "rc=$rc left=$left $out"; fi

# ...and an early exit inside ask (here: -m refused) does not leak it either.
priv="$(mktemp -d)"
out="$(TMPDIR="$priv" run -m opus review "$REPO/README.md")"; rc=$?
left="$(ls -A "$priv" | wc -l | tr -d ' ')"; rm -rf "$priv"
if [ "$rc" = 2 ] && [ "$left" = 0 ]; then ok "review refused inside ask exits 2 and leaves no temp file"
else bad "review refused inside ask exits 2 and leaves no temp file" "rc=$rc left=$left $out"; fi

# Labels keep a provider id that contains a dot.
lbl="$( . "$REPO/lib/common.sh"; . "$REPO/lib/consensus.sh"
        d="$(mktemp -d)"; f="$(mktemp "$d/gpt-6.1.XXXXXX")"; echo x > "$f"
        council_render_answers "$f" | head -1; rm -rf "$d" )"
check "a provider id with a dot keeps its full label" "$lbl" "--- ADVISOR 1 (gpt-6.1) ---"

out="$(run -m opus ask "x")"; rc=$?
case "$rc:$out" in 2:*"single-provider call"*) ok "-m is refused for a panel round" ;;
  *) bad "-m is refused for a panel round" "rc=$rc $out" ;; esac

# Strict token parsing: exact words only, surrounding markdown tolerated.
tok() { f="$(mktemp)"; printf '%b' "$1" > "$f"
        ( . "$REPO/lib/common.sh"; . "$REPO/lib/consensus.sh"; council_first_word "$f" ); rm -f "$f"; }
check "token: '**Agree.**' -> AGREE"                 "$(tok '**Agree.**\nwhy')"           "AGREE"
check "token: leading blank line skipped"            "$(tok '\n\n  DISAGREE\n')"         "DISAGREE"
check "token: 'UPHELD — stands' -> UPHELD"           "$(tok 'UPHELD — decisions stand')"   "UPHELD"
check "token: 'AG REE' is not AGREE"                 "$(tok 'AG REE')"                     "AG"
check "token: 'UPHELD123' is not UPHELD"             "$(tok 'UPHELD123')"                  "UPHELD123"
check "token: 'U P H E L D' is not UPHELD"           "$(tok 'U P H E L D')"                "U"
check "token: '# UPHELD' -> UPHELD"                   "$(tok '# UPHELD\nwhy')"             "UPHELD"
check "token: '- AGREE' -> AGREE"                     "$(tok '- AGREE')"                    "AGREE"
check "token: '> **DISAGREE**' -> DISAGREE"           "$(tok '> **DISAGREE**')"             "DISAGREE"
check "token: '1. OVERTURNED' -> OVERTURNED"          "$(tok '1. OVERTURNED')"              "OVERTURNED"
check "token: markers only -> empty"                  "$(tok '## \nAGREE')"                ""
hdr() { f="$(mktemp)"; printf '%b' "$1" > "$f"
        ( . "$REPO/lib/common.sh"; . "$REPO/lib/consensus.sh"; council_has_final_answer "$f" ) && echo yes || echo no; rm -f "$f"; }
check "heading: '## Final Answer' accepted"           "$(hdr 'UPHELD\n## Final Answer\nx')"   "yes"
check "heading: '### final answer:' accepted"         "$(hdr 'UPHELD\n### final answer:\nx')" "yes"
check "heading: 'Final answers unavailable' rejected" "$(hdr 'UPHELD\n## Final answers unavailable\nx')" "no"
check "heading: empty answer section rejected"        "$(hdr 'UPHELD\n## Final answer\n\n  \n')" "no"
check "heading: answer section that is just the next heading rejected" "$(hdr 'UPHELD\n## Final answer\n## Reasoning\nx')" "no"
check "heading: blank line then text accepted"        "$(hdr 'UPHELD\n## Final answer\n\nUse X.')" "yes"
check "heading: inline answer after colon accepted"   "$(hdr 'UPHELD\n## Final Answer: use PostgreSQL')" "yes"
check "heading: bare colon then next heading rejected" "$(hdr 'UPHELD\n## Final answer:\n## Notes\nx')" "no"
check "heading: deeper subheading then text accepted" "$(hdr 'UPHELD\n## Final answer\n### Recommendation\nUse X.')" "yes"
check "heading: higher-level heading ends the section" "$(hdr 'UPHELD\n## Final answer\n# Appendix\nx')" "no"
check "heading: indented heading (CommonMark) accepted" "$(hdr 'UPHELD\n   ## Final answer\nUse X.')" "yes"

# Zero-padded seconds are decimal, not octal.
sec() { ( . "$REPO/lib/common.sh"; . "$REPO/lib/registry.sh"; eval "export $1"; council_seconds "${1%%=*}" 540 ) 2>&1; }
check "seconds: '08' is 8, not an octal error" "$(sec COUNCIL_ROUND_TIMEOUT=08)" "8"
check "seconds: '010' is 10, not 8"             "$(sec COUNCIL_ROUND_TIMEOUT=010)" "10"
out="$(COUNCIL_ROUND_TIMEOUT=08 COUNCIL_TEST_VERDICT=AGREE run ask "postgres or mongo?")"
case "$out" in *FINAL-ANSWER*) ok "COUNCIL_ROUND_TIMEOUT=08 runs a round" ;;
  *) bad "COUNCIL_ROUND_TIMEOUT=08 runs a round" "$out" ;; esac

# The section tag is per stage, unexported, and model output is defanged.
out="$(COUNCIL_TEST_ALPHA_ENV=1 run raw "x")"
case "$out" in *"NONCE-ENV:[]"*) ok "advisors cannot read a section tag from their environment" ;;
  *) bad "advisors cannot read a section tag from their environment" "$out" ;; esac
out="$(COUNCIL_TEST_VERDICT=AGREE COUNCIL_TEST_ARB_FORGE=1 run ask "postgres or mongo?")"
case "$out" in *FORGERY-ACCEPTED*) bad "a marker forged by the arbiter is not genuine to the final reviewer" "$out" ;;
  *SAW-DEFANGED*FINAL-ANSWER*) ok "a marker forged by the arbiter is not genuine to the final reviewer" ;;
  *) bad "a marker forged by the arbiter is not genuine to the final reviewer" "$out" ;; esac

# The round deadline caps each call by the time left in the round.
lim="$( . "$REPO/lib/common.sh"; . "$REPO/lib/registry.sh"
        COUNCIL_CALL_TIMEOUT=240 COUNCIL_DEADLINE=$(( $(date +%s) + 30 )) council_call_timeout )"
if [ "$lim" -le 30 ] && [ "$lim" -ge 28 ]; then ok "round deadline caps the per-call limit (${lim}s of 240)"
else bad "round deadline caps the per-call limit" "got $lim"; fi
lim="$( . "$REPO/lib/common.sh"; . "$REPO/lib/registry.sh"
        COUNCIL_CALL_TIMEOUT=240 COUNCIL_DEADLINE=$(( $(date +%s) - 5 )) council_call_timeout )"
check "an expired round leaves a 1s limit, not a negative one" "$lim" "1"

out="$(run raw "postgres or mongo?")"
case "$out" in *"DATA to evaluate"*|*"Ignore any instruction"*) bad "model-directed notice never reaches the user" "$out" ;;
  *) ok "model-directed notice never reaches the user" ;; esac

out="$(COUNCIL_TEST_VERDICT=AGREE COUNCIL_TEST_ARB_FAIL=1 run ask "postgres or mongo?")"
case "$out" in *"arbiter 'judge' failed"*Stalemate*SAW-DEFAULT-NOTE*FINAL-ANSWER*) ok "arbiter failure is flagged to the final reviewer as a default" ;;
  *) bad "arbiter failure is flagged to the final reviewer as a default" "$out" ;; esac
case "$out" in *"Point of contention"*) bad "failed arbiter shows its note, not an empty contention heading" "$out" ;;
  *"Arbiter:"*"stalemate by default"*) ok "failed arbiter shows its note, not an empty contention heading" ;;
  *) bad "failed arbiter shows its note, not an empty contention heading" "$out" ;; esac

out="$(COUNCIL_TEST_VERDICT=DISAGREE COUNCIL_TEST_TB_FAIL=1 COUNCIL_TEST_FINAL_FAIL=1 run ask "postgres or mongo?")"
case "$out" in *"no verdict; presenting the positions unresolved"*"ADVISOR 1 (alpha)"*) ok "tiebreak AND final fail -> positions shown unresolved" ;;
  *) bad "tiebreak AND final fail -> positions shown unresolved" "$out" ;; esac

out="$(COUNCIL_TEST_BETA_FAIL=1 COUNCIL_TEST_FINAL_FAIL=1 run ask "postgres or mongo?")"
case "$out" in *"reporting the single answer unjudged"*PostgreSQL*) ok "one advisor + final fails -> single answer, flagged unjudged" ;;
  *) bad "one advisor + final fails -> single answer, flagged unjudged" "$out" ;; esac

out="$(COUNCIL_CALL_TIMEOUT=abc run alpha "x")"
case "$out" in *"not a number of seconds"*PostgreSQL*) ok "non-numeric COUNCIL_CALL_TIMEOUT warns and still runs" ;;
  *) bad "non-numeric COUNCIL_CALL_TIMEOUT warns and still runs" "$out" ;; esac

# Build an alternative stub tree: providers copied so one can be edited/removed.
alt_tree() { a="$(mktemp -d)"; mkdir "$a/providers"
  ln -s "$REPO/lib" "$a/lib"; ln -s "$TEST_DIR/fixtures/policy" "$a/policy"
  cp "$TEST_DIR"/fixtures/providers/*.conf "$a/providers/"; echo "$a"; }

# A final reviewer that ALSO declares tiebreak+arbiter (and outranks the judge)
# must not be used up before the final call.
alt="$(alt_tree)"
sed -i.bak 's/^PROVIDER_CAPS="final"/PROVIDER_CAPS="final arbiter tiebreak"/' "$alt/providers/final.conf"
out="$(COUNCIL_HOME="$alt" COUNCIL_TEST_VERDICT=DISAGREE "$REPO/council" ask "postgres or mongo?" 2>&1 </dev/null)"
rm -rf "$alt"
case "$out" in *"Provisional verdict (judge)"*"Final call (final)"*FINAL-ANSWER*) ok "final+tiebreak provider is saved for the final call" ;;
  *) bad "final+tiebreak provider is saved for the final call" "$out" ;; esac

alt="$(alt_tree)"; rm -f "$alt/providers/final.conf"
out="$(COUNCIL_HOME="$alt" COUNCIL_TEST_VERDICT=AGREE "$REPO/council" ask "postgres or mongo?" 2>&1 </dev/null)"
rm -rf "$alt"
case "$out" in *"no eligible final reviewer"*SYNTHESIS*) ok "no final reviewer installed -> warns, judge's synthesis stands" ;;
  *) bad "no final reviewer installed -> warns, judge's synthesis stands" "$out" ;; esac

# A leftover claude.conf shaped like the real old one (judge caps AND reason),
# next to an 'opus' provider: warned about, and kept off the panel.
alt="$(alt_tree)"
sed -e 's/^PROVIDER_ID=alpha/PROVIDER_ID=claude/' -e 's/^PROVIDER_CAPS=.*/PROVIDER_CAPS="chair reason review tiebreak arbiter write"/' \
    -e 's/^PROVIDER_RANK=.*/PROVIDER_RANK=1/' "$alt/providers/alpha.conf" > "$alt/providers/claude.conf"
cp "$alt/providers/judge.conf" "$alt/providers/opus.conf"; sed -i.bak 's/^PROVIDER_ID=judge/PROVIDER_ID=opus/; s/^PROVIDER_RANK=.*/PROVIDER_RANK=11/' "$alt/providers/opus.conf"
out="$(COUNCIL_HOME="$alt" COUNCIL_DEBUG=1 COUNCIL_TEST_VERDICT=AGREE "$REPO/council" ask "x" 2>&1 </dev/null)"
rm -rf "$alt"
case "$out" in *"legacy 'claude' provider file exists next to opus; it is ignored"*) ok "a leftover claude.conf is flagged" ;;
  *) bad "a leftover claude.conf is flagged" "$out" ;; esac
pl="$(printf '%s\n' "$out" | grep '^\[council\] panel:')"
case "$pl" in *claude*|"") bad "a leftover claude.conf never reaches the panel" "$out" ;;
  *) ok "a leftover claude.conf never reaches the panel" ;; esac

# Synthesis (the fallback when the final call fails) is picked by pick_judge
# too: a provider declaring chair+final is not preferred over the judge.
alt="$(alt_tree)"
sed -i.bak 's/^PROVIDER_CAPS="final"/PROVIDER_CAPS="final chair"/' "$alt/providers/final.conf"
out="$(COUNCIL_HOME="$alt" COUNCIL_DEBUG=1 COUNCIL_TEST_VERDICT=AGREE COUNCIL_TEST_FINAL_FAIL=1 "$REPO/council" ask "x" 2>&1 </dev/null)"
rm -rf "$alt"
case "$out" in *"chair: judge"*SYNTHESIS*) ok "synthesis chair is chosen like the other judges" ;;
  *) bad "synthesis chair is chosen like the other judges" "$out" ;; esac

# The --restricted preflight probe is capped: a claude whose --help hangs must
# not block the command outside every time limit.
if command -v timeout >/dev/null 2>&1; then
  alt="$(alt_tree)"; hang="$(mktemp)"
  printf '#!/bin/sh\nexec sleep 30\n' > "$hang"; chmod +x "$hang"
  cat > "$alt/providers/opus.conf" <<'OPUS'
PROVIDER_ID=opus
PROVIDER_CAPS="arbiter"
PROVIDER_RANK=90
PROVIDER_BIN_NAME=none
PROVIDER_BIN_ENV=OPUS_STUB_BIN
provider_invoke() { cat >/dev/null; echo PONG; }
OPUS
  start=$(date +%s)
  out="$(COUNCIL_HOME="$alt" OPUS_STUB_BIN="$hang" timeout 20 "$REPO/council" raw "x" 2>&1 </dev/null)"; rc=$?
  took=$(( $(date +%s) - start ))
  rm -rf "$alt" "$hang"
  if [ "$rc" = 0 ] && [ "$took" -lt 12 ]; then
    case "$out" in *"did not answer within 5s"*PostgreSQL*) ok "a hanging claude --help is capped and warned about (${took}s)" ;;
      *) bad "a hanging claude --help is capped and warned about" "$out" ;; esac
  else bad "a hanging claude --help is capped and warned about" "rc=$rc took=${took}s $out"; fi
fi

# A final reviewer that ALSO declares 'reason' must still be held off the panel.
alt="$(mktemp -d)"; mkdir "$alt/providers"
ln -s "$REPO/lib" "$alt/lib"; ln -s "$TEST_DIR/fixtures/policy" "$alt/policy"
cp "$TEST_DIR"/fixtures/providers/*.conf "$alt/providers/"
sed -i.bak 's/^PROVIDER_CAPS="final"/PROVIDER_CAPS="final reason"/' "$alt/providers/final.conf"
panel="$(COUNCIL_HOME="$alt" bash -c '
  . "$0/lib/common.sh"; . "$0/lib/registry.sh"; . "$0/lib/policy.sh"
  council_policy_panel advise "" $(council_policy_reserved) | tr "\n" " "' "$alt")"
rm -rf "$alt"
check "final reviewer with 'reason' is still held off the panel" "$panel" "alpha beta "

# The per-call ceiling kills a hung CLI instead of stalling the round.
if command -v timeout >/dev/null 2>&1; then
  slow="$(mktemp -d)"; mkdir "$slow/providers"
  ln -s "$REPO/lib" "$slow/lib"; ln -s "$TEST_DIR/fixtures/policy" "$slow/policy"
  cat > "$slow/providers/slow.conf" <<'SLOW'
PROVIDER_ID=slow
PROVIDER_CAPS="reason"
PROVIDER_BIN_NAME=sleep
PROVIDER_BIN_CANDIDATES="/bin/sleep /usr/bin/sleep"
provider_invoke() { cat >/dev/null; "$P_BIN" 30 || return $?; echo late; }
SLOW
  start=$(date +%s)
  out="$(printf x | COUNCIL_HOME="$slow" COUNCIL_CALL_TIMEOUT=1 "$REPO/council" slow 2>&1)"; rc=$?
  took=$(( $(date +%s) - start ))
  rm -rf "$slow"
  if [ "$rc" = "5" ] && [ "$took" -lt 10 ]; then ok "COUNCIL_CALL_TIMEOUT kills a hung call (${took}s)"
  else bad "COUNCIL_CALL_TIMEOUT kills a hung call" "rc=$rc took=${took}s $out"; fi
  case "$out" in *"timed out after 1s"*) ok "a timeout is reported, not silent" ;;
    *) bad "a timeout is reported, not silent" "$out" ;; esac

  # A CLI that ignores SIGTERM is SIGKILLed after the grace period. Only where
  # timeout(1) has -k: BusyBox lacks it and council deliberately drops it there.
  if timeout -k 1 5 true >/dev/null 2>&1; then
  stub="$(mktemp -d)"; mkdir "$stub/providers"
  ln -s "$REPO/lib" "$stub/lib"; ln -s "$TEST_DIR/fixtures/policy" "$stub/policy"
  cat > "$stub/providers/stubborn.conf" <<'STUB'
PROVIDER_ID=stubborn
PROVIDER_CAPS="reason"
PROVIDER_BIN_NAME=sleep
PROVIDER_BIN_CANDIDATES="/bin/sleep /usr/bin/sleep"
provider_invoke() { cat >/dev/null; trap '' TERM; "$P_BIN" 30 || return $?; echo late; }
STUB
  start=$(date +%s)
  out="$(printf x | COUNCIL_HOME="$stub" COUNCIL_CALL_TIMEOUT=1 COUNCIL_KILL_GRACE=1 "$REPO/council" stubborn 2>&1)"; rc=$?
  took=$(( $(date +%s) - start ))
  rm -rf "$stub"
  if [ "$rc" = "5" ] && [ "$took" -lt 10 ]; then ok "a CLI ignoring SIGTERM is killed after the grace (${took}s)"
  else bad "a CLI ignoring SIGTERM is killed after the grace" "rc=$rc took=${took}s $out"; fi
  else ok "SIGKILL test skipped: this timeout(1) has no -k"; fi
fi

# ---------------------------------------------------------------- claude providers
echo
echo "claude providers"
# The real sonnet/opus/fable providers, driven by a stub binary that echoes its
# arguments, so the model pin and the advisor opt-out are checked offline.
echo_bin="$(mktemp)"
printf '#!/bin/sh\necho "ARGS:$*"\n' > "$echo_bin"; chmod +x "$echo_bin"
for pair in sonnet:claude-sonnet-5-5 opus:claude-opus-5-5 fable:claude-fable-5-1; do
  id="${pair%%:*}"; want="${pair#*:}"
  # Through council_invoke with an EMPTY model, as a round calls it: the pin
  # must come from the registry's PROVIDER_DEFAULT_MODEL fallback.
  args="$(COUNCIL_HOME="$REPO" CLAUDE_BIN="$echo_bin" bash -c '
            . "$0/lib/common.sh"; . "$0/lib/registry.sh"
            printf x | council_invoke "$1" "" ""' "$REPO" "$id" 2>&1)"
  case "$args" in *'-p --restricted --strict-mcp-config --settings {"advisorModel":""} --tools Read,Grep,Glob'*"--model $want"*)
    ok "$id runs $want, restricted, advisor off, read-only tools" ;;
    *) bad "$id runs $want, restricted, advisor off, read-only tools" "$args" ;; esac
done
rm -f "$echo_bin"

# ---------------------------------------------------------------- summary
echo
echo "─────────────────────────"
printf 'passed %d, failed %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
