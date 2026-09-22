# Agreement detection and stalemate resolution.
#
# Protocol:
#   1. advisors answer independently, in parallel, seeing none of each other
#   2. an ARBITER (never an advisor — no-self-judgement) rules AGREE or DISAGREE
#   3. on DISAGREE a TIEBREAKER (never an advisor) issues a binding verdict
# Independence in step 1 is what makes step 2 mean anything; do not "optimise"
# it by showing advisors each other's drafts.

# Render the collected answers as a labelled block.
council_render_answers() {
  local i=1 f id
  for f in "$@"; do
    id="${f##*/}"; id="${id%%.*}"
    echo "--- ADVISOR $i ($id) ---"
    if council_has_content "$f"; then cat "$f"; else echo "(no answer)"; fi
    echo
    i=$(( i + 1 ))
  done
}

# Ask the arbiter whether the advisors materially disagree.
# Echoes "AGREE" or "DISAGREE"; full reasoning goes to $2.
council_arbitrate() {
  local question_file out arbiter prompt verdict
  question_file="$1"; out="$2"; shift 2
  arbiter="$(council_policy_judge arbitrate "$@")" || {
    council_warn "no eligible arbiter (all candidates were advisors); assuming DISAGREE"
    echo DISAGREE; return 0; }
  council_log "arbiter: $arbiter"

  prompt="$(mktemp)"
  {
    echo "You are judging whether two or more advisors MATERIALLY disagree."
    echo
    echo "Material disagreement means they recommend incompatible actions, or"
    echo "make claims that cannot both be true. Different emphasis, extra detail,"
    echo "or different wording for the same recommendation is AGREEMENT."
    echo
    echo "Reply with exactly one word on the FIRST line: AGREE or DISAGREE."
    echo "Then, briefly, the single most important point of contention (or of"
    echo "agreement). Do not resolve the dispute — only classify it."
    echo
    echo "QUESTION:"; cat "$question_file"; echo
    council_render_answers "${COUNCIL_ANSWER_FILES[@]}"
  } > "$prompt"

  if council_invoke "$arbiter" "" "" < "$prompt" > "$out" 2>/dev/null; then
    verdict="$(head -1 "$out" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')"
    case "$verdict" in
      *DISAGREE*) echo DISAGREE ;;
      *AGREE*)    echo AGREE ;;
      *)          council_warn "arbiter gave no clear verdict; treating as DISAGREE"
                  echo DISAGREE ;;
    esac
  else
    council_warn "arbiter '$arbiter' failed; treating as DISAGREE"
    echo DISAGREE
  fi
  rm -f "$prompt"
}

# Binding verdict from a provider that was not one of the disputing advisors.
council_tiebreak() {
  local question_file contention out tb prompt
  question_file="$1"; contention="$2"; out="$3"; shift 3
  tb="$(council_policy_judge tiebreak "$@")" || {
    council_warn "no eligible tiebreaker outside the advisor panel"
    return 1; }
  council_log "tiebreaker: $tb"
  echo "$tb" > "${COUNCIL_TIEBREAKER_FILE:-/dev/null}" 2>/dev/null || true

  prompt="$(mktemp)"
  {
    echo "The advisors below reached a STALEMATE. You were not one of them."
    echo "You are the deciding vote. Settle it."
    echo
    echo "Rules for your verdict:"
    echo "  - Pick a side, or state a third position if both are wrong."
    echo "  - Say WHY the losing position loses, in one or two sentences."
    echo "  - If the dispute turns on a fact you cannot verify, say so and give"
    echo "    the decision rule the reader should apply instead of guessing."
    echo "  - Do not split the difference to be diplomatic."
    echo
    echo "QUESTION:"; cat "$question_file"; echo
    [ -s "$contention" ] && { echo "WHAT THE ARBITER SAW:"; cat "$contention"; echo; }
    council_render_answers "${COUNCIL_ANSWER_FILES[@]}"
  } > "$prompt"

  council_invoke "$tb" "" "" < "$prompt" > "$out" 2>/dev/null
  local rc=$?
  rm -f "$prompt"
  return $rc
}

# Merge agreeing answers into one. Chair must not have been an advisor.
council_synthesize() {
  local question_file out chair prompt
  question_file="$1"; out="$2"; shift 2
  chair="$(council_policy_judge synthesize "$@")" || return 1
  council_log "chair: $chair"
  prompt="$(mktemp)"
  {
    echo "You are the chair. The advisors below answered the same question and"
    echo "an arbiter judged them to be in agreement."
    echo
    echo "Write ONE answer. State the shared conclusion plainly. Where advisors"
    echo "differ in emphasis, say which framing is better supported and why."
    echo "Do not invent consensus that is not there, and do not pad."
    echo
    echo "QUESTION:"; cat "$question_file"; echo
    council_render_answers "${COUNCIL_ANSWER_FILES[@]}"
  } > "$prompt"
  council_invoke "$chair" "" "" < "$prompt" > "$out" 2>/dev/null
  local rc=$?
  rm -f "$prompt"
  return $rc
}
