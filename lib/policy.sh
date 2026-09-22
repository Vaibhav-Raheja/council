# Policy engine. Routing is decided by declared capability, never by hardcoded
# provider names, so a new LLM participates the moment its .conf lands.

council_rules_file() {
  if [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/council/rules.conf" ]; then
    echo "${XDG_CONFIG_HOME:-$HOME/.config}/council/rules.conf"
  else
    echo "${COUNCIL_HOME}/policy/rules.conf"
  fi
}

# Capability required by a task, per the rules file.
council_policy_cap_for() {
  local want line
  want="$1"
  line="$(grep -E "^task:${want}[[:space:]]" "$(council_rules_file)" 2>/dev/null | head -1)"
  [ -n "$line" ] || return 1
  printf '%s' "$line" | sed -E 's/.*requires=([A-Za-z0-9_-]+).*/\1/'
}

council_policy_invariant() {
  local v
  v="$(grep -E "^invariant:$1[[:space:]]*=" "$(council_rules_file)" 2>/dev/null | head -1 |
       sed -E 's/.*=[[:space:]]*//' | tr -d '[:space:]')"
  [ -n "$v" ] && printf '%s' "$v" || printf '%s' "${2:-}"
}

# Providers eligible for a task, best first. Optionally exclude some ids.
#   council_policy_select <task> [exclude ...]
council_policy_select() {
  local task cap id ex skip
  task="$1"; shift || true
  cap="$(council_policy_cap_for "$task")" || {
    echo "council: no rule defines task '$task' (see policy/rules.conf)" >&2; return 2; }
  for id in $(council_providers_with_cap "$cap"); do
    skip=0
    for ex in "$@"; do [ "$id" = "$ex" ] && skip=1; done
    [ "$skip" -eq 0 ] && echo "$id"
  done
}

# Pick ONE provider for a judging task, enforcing no-self-judgement.
#   council_policy_judge <task> <advisor...>
council_policy_judge() {
  local task first
  task="$1"; shift || true
  if [ "$(council_policy_invariant no-self-judgement on)" = "on" ]; then
    first="$(council_policy_select "$task" "$@" | head -1)"
  else
    first="$(council_policy_select "$task" | head -1)"
  fi
  [ -n "$first" ] || return 1
  printf '%s' "$first"
}

# Assemble the advisor panel for a round, honouring min/max invariants.
#   council_policy_panel <task> <requested-count> [exclude ...]
council_policy_panel() {
  local task want min max got n task_list
  task="$1"; want="$2"; shift 2 || true
  min="$(council_policy_invariant min-advisors 2)"
  max="$(council_policy_invariant max-advisors 6)"
  case "$want" in ''|*[!0-9]*) want="$max" ;; esac
  [ "$want" -gt "$max" ] && want="$max"

  task_list="$(council_policy_select "$task" "$@")" || return 2
  got="$(printf '%s\n' "$task_list" | sed '/^$/d' | head -n "$want")"
  n="$(printf '%s\n' "$got" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [ "$n" -lt "$min" ]; then
    echo "council: only $n provider(s) can do '$task'; policy requires $min." >&2
    echo "council: install another CLI, or lower min-advisors in policy/rules.conf." >&2
    return 2
  fi
  printf '%s\n' "$got"
}

# The provider held out of advisory panels so it can judge. Highest-ranked
# arbiter-capable provider; empty when the invariant is off.
council_policy_reserved_judge() {
  [ "$(council_policy_invariant reserve-judge on)" = "on" ] || return 1
  council_providers_with_cap arbiter | head -1
}
