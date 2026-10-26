# Provider registry. A provider is a .conf file; adding an LLM means adding a
# file, never editing the engine.
#
# CONTRACT — every provider .conf must define:
#   PROVIDER_ID          short slug, must match the filename
#   PROVIDER_LABEL       human name
#   PROVIDER_ROLE        one word: chair | investigator | reader | ...
#   PROVIDER_SUMMARY     what it is best at (shown by `council roles`)
#   PROVIDER_CAPS        space-separated capability tags (see policy/rules.conf)
#   PROVIDER_RANK        integer; lower is preferred when choosing among equals
#   PROVIDER_BIN_NAME    binary to look for on PATH
#   PROVIDER_BIN_ENV     env var that overrides discovery (e.g. CODEX_BIN)
#   PROVIDER_BIN_CANDIDATES  extra absolute paths to try, space separated
#   provider_invoke()    reads prompt on stdin, writes ANSWER ONLY on stdout.
#                        Inputs: $P_BIN $P_MODEL $P_DIR. Must exit non-zero on
#                        failure and must never print its answer to stderr.
#
# Optional:
#   PROVIDER_DEFAULT_MODEL, PROVIDER_MODELS_HINT, PROVIDER_AUTH_HINT
#   PROVIDER_CONTAINMENT one line: HOW the adapter keeps its CLI read-only. While
#                        invariant write-requires-cap is on, a provider that
#                        declares neither this nor the 'write' cap is never
#                        selected for any task. The engine cannot verify the
#                        claim; it only refuses providers that make none.

council_provider_dirs() {
  echo "${COUNCIL_HOME}/providers"
  [ -d "${XDG_CONFIG_HOME:-$HOME/.config}/council/providers" ] && \
    echo "${XDG_CONFIG_HOME:-$HOME/.config}/council/providers"
  return 0
}

# All provider ids, user overrides shadowing builtins by filename.
# Every walk over council_provider_dirs reads it line by line: `for d in $(...)`
# would split a checkout or config path that contains a space.
council_provider_ids() {
  local d f id
  while IFS= read -r d; do
    for f in "$d"/*.conf; do
      [ -f "$f" ] || continue
      id="$(basename "$f" .conf)"
      case "$id" in _*) continue ;; esac   # _template.conf and friends
      # A 'claude' provider predates the sonnet/opus/fable split. Next to its
      # replacements it would carry the old judge caps AND 'reason' onto the
      # panel, so it is ignored (preflight warns) whenever 'opus' exists.
      if [ "$id" = claude ] && council_provider_dirs_have opus; then continue; fi
      echo "$id"
    done
  done < <(council_provider_dirs) | sort -u
}

council_provider_file() {
  local d f
  # Later dirs win, so walk in reverse preference order and keep the last hit.
  f=""
  while IFS= read -r d; do
    [ -f "$d/$1.conf" ] && f="$d/$1.conf"
  done < <(council_provider_dirs)
  [ -n "$f" ] || return 1
  printf '%s' "$f"
}

# Read one metadata field. Runs in a subshell so providers never leak state
# into each other — critical, since every one defines provider_invoke().
# The field is read by ${!var} indirection, never eval; an illegal name is empty.
council_provider_meta() {
  local id var file
  id="$1"; var="$2"
  file="$(council_provider_file "$id")" || return 1
  (
    set +u
    . "$file" >/dev/null 2>&1 || exit 1
    council_is_ident "$var" || exit 0
    printf '%s' "${!var:-}"
  )
}

council_provider_bin() {
  local id file
  id="$1"
  file="$(council_provider_file "$id")" || return 1
  (
    set +u
    . "$file" >/dev/null 2>&1 || exit 1
    # The override variable is NAMED by the provider; read it by indirection.
    override=""
    council_is_ident "${PROVIDER_BIN_ENV:-}" && override="${!PROVIDER_BIN_ENV:-}"
    # Candidates are split on purpose: the field is a space-separated list.
    # shellcheck disable=SC2086
    council_resolve_bin "$override" "${PROVIDER_BIN_NAME:-}" ${PROVIDER_BIN_CANDIDATES:-}
  )
}

council_provider_available() { council_provider_bin "$1" >/dev/null 2>&1; }

council_provider_has_cap() {
  local caps c
  caps="$(council_provider_meta "$1" PROVIDER_CAPS)" || return 1
  for c in $caps; do [ "$c" = "$2" ] && return 0; done
  return 1
}

# True when a provider may be handed work under write-requires-cap: it either
# declares 'write' (it is allowed to touch disk) or says how it is kept from it.
council_provider_contained() {
  council_provider_has_cap "$1" write && return 0
  [ -n "$(council_provider_meta "$1" PROVIDER_CONTAINMENT)" ]
}

# Whether write-requires-cap is being enforced. Fails CLOSED: anything but an
# explicit "off" enforces it, including a caller that never sourced policy.sh.
council_write_cap_enforced() {
  if type council_policy_invariant >/dev/null 2>&1; then
    [ "$(council_policy_invariant write-requires-cap on)" != "off" ]
  else
    return 0
  fi
}

# Providers with a capability, available, ordered by PROVIDER_RANK. Under
# write-requires-cap, providers that make no containment claim are dropped:
# listing them (council providers) is fine, handing them a prompt is not.
council_providers_with_cap() {
  local id rank enforce=0
  council_write_cap_enforced && enforce=1
  for id in $(council_provider_ids); do
    council_provider_has_cap "$id" "$1" || continue
    council_provider_available "$id" || continue
    if [ "$enforce" -eq 1 ] && ! council_provider_contained "$id"; then
      council_log "skipping $id: no PROVIDER_CONTAINMENT and no 'write' cap (write-requires-cap)"
      continue
    fi
    rank="$(council_provider_meta "$id" PROVIDER_RANK)"
    case "$rank" in ''|*[!0-9]*) rank=50 ;; esac
    printf '%s %s\n' "$rank" "$id"
  done | sort -n | awk '{print $2}'
}

# Run a provider. Prompt on stdin, answer on stdout. Isolated in a subshell.
council_invoke() {
  local id model dir file bin prompt_file answer err rc
  id="$1"; model="${2:-}"; dir="${3:-}"
  file="$(council_provider_file "$id")" || { echo "council: unknown provider '$id'" >&2; return 4; }
  bin="$(council_provider_bin "$id")"  || { echo "council: '$id' is not installed" >&2; return 4; }

  prompt_file="$(mktemp)"; answer="$(mktemp)"; err="$(mktemp)"
  cat > "$prompt_file"
  if ! council_has_content "$prompt_file"; then
    rm -f "$prompt_file" "$answer" "$err"
    echo "council: empty prompt for '$id'" >&2; return 2
  fi

  local limit tmo call
  limit="$(council_call_timeout)"
  tmo="$(council_timeout_cmd)"
  # Per-call ceiling over the WHOLE provider_invoke, not just its binary: a
  # fresh bash re-loads the provider under the limit. No temp executable,
  # nothing to clean up. Single-quoted: it expands in the child, not here.
  # shellcheck disable=SC2016
  call='
      set +u
      . "$COUNCIL_HOME/lib/common.sh"
      . "$1" >/dev/null 2>&1
      P_BIN="$2"; P_MODEL="${3:-${PROVIDER_DEFAULT_MODEL:-}}"; P_DIR="$4"
      provider_invoke'

  rc=0
  if [ "$limit" != "0" ]; then
    if [ -n "$tmo" ]; then
      # timeout(1): -k follows SIGTERM with SIGKILL for a CLI that ignores it.
      # BusyBox timeout has no -k; probe once per call (cheap) and drop it there.
      local killafter=""
      "$tmo" -k 1 5 true >/dev/null 2>&1 && killafter="-k $(council_seconds COUNCIL_KILL_GRACE 10)"
      # killafter is "" or two words, split on purpose.
      # shellcheck disable=SC2086
      COUNCIL_HOP_DEPTH=$(( $(council_hop_depth) + 1 )) \
      "$tmo" $killafter "$limit" bash -c "$call" council-call "$file" "$bin" "$model" "$dir" \
        < "$prompt_file" > "$answer" 2> "$err" || rc=$?
    else
      # No timeout(1) — stock macOS. The built-in watchdog enforces the same
      # TERM-then-KILL contract. In a subshell so the hop-depth export stays
      # local to this call.
      # shellcheck disable=SC2030
      ( export COUNCIL_HOP_DEPTH=$(( $(council_hop_depth) + 1 ))
        council_run_capped "$limit" "$(council_seconds COUNCIL_KILL_GRACE 10)" \
          bash -c "$call" council-call "$file" "$bin" "$model" "$dir"
      ) < "$prompt_file" > "$answer" 2> "$err" || rc=$?
    fi
    case "$rc" in
      124|137) echo "council: $id timed out after ${limit}s (COUNCIL_CALL_TIMEOUT)" >&2 ;;
    esac
  else
    # shellcheck disable=SC2034  # P_* are read by the sourced provider_invoke
    (
      set +u
      . "$file" >/dev/null 2>&1
      P_BIN="$bin"
      P_MODEL="${model:-${PROVIDER_DEFAULT_MODEL:-}}"
      P_DIR="$dir"
      # shellcheck disable=SC2031
      export COUNCIL_HOP_DEPTH=$(( $(council_hop_depth) + 1 ))
      provider_invoke < "$prompt_file" > "$answer" 2> "$err"
    ) || rc=$?
  fi

  if ! council_has_content "$answer"; then
    echo "council: $id produced no answer (exit $rc)" >&2
    [ -s "$err" ] && { echo "--- stderr from $id ---" >&2; head -c 2000 "$err" >&2; }
    rm -f "$prompt_file" "$answer" "$err"; return 5
  fi
  # Non-zero exit WITH bytes written means a mid-stream failure: the answer is
  # truncated. Half an opinion is worse than none.
  if [ "$rc" -ne 0 ]; then
    echo "council: $id exited $rc after partial output; discarding truncated answer" >&2
    [ -s "$err" ] && head -c 1000 "$err" >&2
    rm -f "$prompt_file" "$answer" "$err"; return 6
  fi
  cat "$answer"
  rm -f "$prompt_file" "$answer" "$err"
  return 0
}

# True if any provider dir holds <id>.conf (no recursion into council_provider_ids).
council_provider_dirs_have() {
  local d
  while IFS= read -r d; do [ -f "$d/$1.conf" ] && return 0; done < <(council_provider_dirs)
  return 1
}

# A non-negative integer from env var $1, else default $2 (warning on garbage).
council_seconds() {
  local v
  council_is_ident "$1" || { echo "$2"; return 0; }
  v="${!1:-$2}"
  case "$v" in
    ''|*[!0-9]*) echo "council: $1='$v' is not a number of seconds; using $2" >&2
                 echo "$2" ;;
    # Longer than 6 digits (11+ days) would only overflow later arithmetic.
    ???????*) echo "council: $1='$v' is out of range; using $2" >&2
              echo "$2" ;;
    # 10# forces base 10: "08" would otherwise be invalid octal, "010" eight.
    *) echo "$(( 10#$v ))" ;;
  esac
}

# Per-call limit in seconds: COUNCIL_CALL_TIMEOUT (default 240, 0 = none),
# further capped by what is left of the round's deadline (COUNCIL_DEADLINE, set
# by ask/raw from COUNCIL_ROUND_TIMEOUT). Without the deadline, three sequential
# 240 s judge calls could overrun a caller's 600 s budget; with it, late stages
# get a short limit, time out, and fall back to the decision already made.
council_call_timeout() {
  local limit rem
  limit="$(council_seconds COUNCIL_CALL_TIMEOUT 240)"
  case "${COUNCIL_DEADLINE:-}" in
    ''|*[!0-9]*) ;;
    *) rem=$(( COUNCIL_DEADLINE - $(date +%s) ))
       [ "$rem" -lt 1 ] && rem=1
       if [ "$limit" = 0 ] || [ "$rem" -lt "$limit" ]; then limit="$rem"; fi ;;
  esac
  echo "$limit"
}

# True when the round has no deadline or at least $1 seconds of it remain.
council_round_has() {
  case "${COUNCIL_DEADLINE:-}" in
    ''|*[!0-9]*) return 0 ;;
    *) [ $(( COUNCIL_DEADLINE - $(date +%s) )) -ge "$1" ] ;;
  esac
}

# Start the round clock: export COUNCIL_DEADLINE = now + COUNCIL_ROUND_TIMEOUT
# (default 540, under a 600 s caller budget; 0 = no round deadline).
council_start_round_clock() {
  local r
  r="$(council_seconds COUNCIL_ROUND_TIMEOUT 540)"
  if [ "$r" = 0 ]; then unset COUNCIL_DEADLINE
  else COUNCIL_DEADLINE=$(( $(date +%s) + r )); export COUNCIL_DEADLINE; fi
}

# timeout(1) or GNU gtimeout (Homebrew coreutils on macOS); empty if neither,
# and the built-in watchdog (council_run_capped) takes over.
# COUNCIL_FORCE_WATCHDOG=1 is TEST-ONLY: it hides timeout(1) so the watchdog
# path is exercised on machines that have it.
council_timeout_cmd() {
  [ "${COUNCIL_FORCE_WATCHDOG:-}" = 1 ] && return 0
  command -v timeout 2>/dev/null || command -v gtimeout 2>/dev/null || true
}

# A pid and all its descendants, parents first. Collected BEFORE any signal is
# sent: a child reparented by its parent's death can no longer be found by
# pgrep -P. Without pgrep only the pid itself is known.
council_proc_tree() {
  local c
  echo "$1"
  command -v pgrep >/dev/null 2>&1 || return 0
  for c in $(pgrep -P "$1" 2>/dev/null); do council_proc_tree "$c"; done
}

#   council_signal_tree <SIG> <pid>
council_signal_tree() {
  local pids
  pids="$(council_proc_tree "$2")"
  # One pid per line, split on purpose.
  # shellcheck disable=SC2086
  kill -"$1" $pids 2>/dev/null
  return 0
}

# Run a command with a time limit, without timeout(1). After <limit> seconds the
# command's whole process tree gets SIGTERM, and after <grace> more, SIGKILL.
# Returns 124 when SIGTERM ended it and 137 when SIGKILL had to, like
# `timeout -k`; otherwise the command's own status. stdio is inherited.
#   council_run_capped <limit> <grace> cmd...
# No new process group (no set -m), so a Ctrl-C at the terminal still reaches
# the CLI. The watchdog polls once a second rather than sleeping the whole
# limit, so it notices an early finish and leaves no long-lived sleep behind.
council_run_capped() {
  local limit grace pid wd rc mark
  limit="$1"; grace="$2"; shift 2
  mark="$(mktemp)"
  # An async command's stdin is /dev/null unless redirected explicitly.
  "$@" <&0 &
  pid=$!
  (
    n=0
    while [ "$n" -lt "$limit" ]; do
      sleep 1; kill -0 "$pid" 2>/dev/null || exit 0; n=$(( n + 1 ))
    done
    # A command that finished during the last second did not time out.
    kill -0 "$pid" 2>/dev/null || exit 0
    # The tree is collected ONCE, before SIGTERM: once the wrapper dies its
    # children are reparented and pgrep -P can no longer find them, so a
    # descendant ignoring TERM would survive a tree recomputed for SIGKILL.
    tree="$(council_proc_tree "$pid")"
    echo 124 > "$mark"
    # shellcheck disable=SC2086  # one pid per line, split on purpose
    kill -TERM $tree 2>/dev/null
    alive() { for p in $tree; do kill -0 "$p" 2>/dev/null && return 0; done; return 1; }
    n=0
    while [ "$n" -lt "$grace" ]; do
      sleep 1; alive || exit 0; n=$(( n + 1 ))
    done
    alive || exit 0
    echo 137 > "$mark"
    # shellcheck disable=SC2086
    kill -KILL $tree 2>/dev/null
  ) </dev/null >/dev/null 2>&1 &
  wd=$!
  # stderr of wait is dropped: bash reports a signalled job ("Terminated").
  wait "$pid" 2>/dev/null; rc=$?
  if [ -s "$mark" ]; then
    # Timed out: the wrapper is gone, but a descendant ignoring SIGTERM may
    # not be. Let the watchdog finish its grace and SIGKILL any survivor.
    wait "$wd" 2>/dev/null
  else
    # Finished in time: stop the watchdog and the one-second sleep it may be in.
    council_signal_tree TERM "$wd"
    wait "$wd" 2>/dev/null
  fi
  [ -s "$mark" ] && rc="$(cat "$mark")"
  rm -f "$mark"
  return "$rc"
}

# Warn once per command when calls would run uncapped, and when a provider from
# before the sonnet/opus/fable split is still loaded (e.g. a user override at
# ~/.config/council/providers/claude.conf): it carries the old judge caps and
# 'reason', so it would sit on the panel next to its own replacements.
council_preflight_warnings() {
  local f
  # Without timeout(1) calls are still capped, by the built-in watchdog.
  if [ -z "$(council_timeout_cmd)" ] && [ "$(council_call_timeout 2>/dev/null)" != "0" ]; then
    council_log "no timeout(1)/gtimeout; model calls are capped by the built-in watchdog"
  fi
  # The Claude providers pass --restricted; a Claude Code too old to know it
  # would fail every call. Probe only when one of them is installed. The probe
  # runs before the round clock, so it gets its own 5 s cap: a hung binary must
  # not block the command outside every time limit. Timeout = "could not
  # verify", a warning, not a failure.
  local cbin tmo help rc
  if council_provider_dirs_have opus && cbin="$(council_provider_bin opus 2>/dev/null)"; then
    tmo="$(council_timeout_cmd)"
    rc=0
    if [ -n "$tmo" ]; then help="$("$tmo" -s KILL 5 "$cbin" --help 2>/dev/null)" || rc=$?
    else help="$(council_run_capped 5 0 "$cbin" --help 2>/dev/null </dev/null)" || rc=$?; fi
    case "$rc" in
      124|137) council_warn "claude --help did not answer within 5s; could not verify --restricted support" ;;
      *) printf '%s' "$help" | grep -q -- '--restricted' ||
           council_warn "installed claude CLI lacks --restricted; sonnet/opus/fable calls will fail — update Claude Code" ;;
    esac
  fi
  if council_provider_dirs_have claude && council_provider_dirs_have opus; then
    council_warn "a legacy 'claude' provider file exists next to opus; it is ignored — remove it"
  fi
  return 0
}
