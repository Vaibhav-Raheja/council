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

council_provider_dirs() {
  echo "${COUNCIL_HOME}/providers"
  [ -d "${XDG_CONFIG_HOME:-$HOME/.config}/council/providers" ] && \
    echo "${XDG_CONFIG_HOME:-$HOME/.config}/council/providers"
  return 0
}

# All provider ids, user overrides shadowing builtins by filename.
council_provider_ids() {
  local d f id
  for d in $(council_provider_dirs); do
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
  done | sort -u
}

council_provider_file() {
  local d f
  # Later dirs win, so walk in reverse preference order and keep the last hit.
  f=""
  for d in $(council_provider_dirs); do
    [ -f "$d/$1.conf" ] && f="$d/$1.conf"
  done
  [ -n "$f" ] || return 1
  printf '%s' "$f"
}

# Read one metadata field. Runs in a subshell so providers never leak state
# into each other — critical, since every one defines provider_invoke().
council_provider_meta() {
  local id var file
  id="$1"; var="$2"
  file="$(council_provider_file "$id")" || return 1
  (
    set +u
    . "$file" >/dev/null 2>&1 || exit 1
    eval "printf '%s' \"\${$var:-}\""
  )
}

council_provider_bin() {
  local id file
  id="$1"
  file="$(council_provider_file "$id")" || return 1
  (
    set +u
    . "$file" >/dev/null 2>&1 || exit 1
    council_resolve_bin "$(eval "printf '%s' \"\${${PROVIDER_BIN_ENV:-__none}:-}\"")" \
                        "${PROVIDER_BIN_NAME:-}" ${PROVIDER_BIN_CANDIDATES:-}
  )
}

council_provider_available() { council_provider_bin "$1" >/dev/null 2>&1; }

council_provider_has_cap() {
  local caps c
  caps="$(council_provider_meta "$1" PROVIDER_CAPS)" || return 1
  for c in $caps; do [ "$c" = "$2" ] && return 0; done
  return 1
}

# Providers with a capability, available, ordered by PROVIDER_RANK.
council_providers_with_cap() {
  local id rank
  for id in $(council_provider_ids); do
    council_provider_has_cap "$id" "$1" || continue
    council_provider_available "$id" || continue
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

  local limit tmo
  limit="$(council_call_timeout)"
  tmo="$(council_timeout_cmd)"

  rc=0
  if [ -n "$tmo" ] && [ "$limit" != "0" ]; then
    # Per-call ceiling over the WHOLE provider_invoke, not just its binary: a
    # fresh bash re-loads the provider under timeout(1); -k follows SIGTERM with
    # SIGKILL for a CLI that ignores it. No temp executable, nothing to clean up.
    # BusyBox timeout has no -k; probe once per call (cheap) and drop it there.
    local killafter=""
    "$tmo" -k 1 5 true >/dev/null 2>&1 && killafter="-k $(council_seconds COUNCIL_KILL_GRACE 10)"
    COUNCIL_HOP_DEPTH=$(( $(council_hop_depth) + 1 )) \
    "$tmo" $killafter "$limit" bash -c '
      set +u
      . "$COUNCIL_HOME/lib/common.sh"
      . "$1" >/dev/null 2>&1
      P_BIN="$2"; P_MODEL="${3:-${PROVIDER_DEFAULT_MODEL:-}}"; P_DIR="$4"
      provider_invoke' council-call "$file" "$bin" "$model" "$dir" \
      < "$prompt_file" > "$answer" 2> "$err" || rc=$?
    case "$rc" in
      124|137) echo "council: $id timed out after ${limit}s (COUNCIL_CALL_TIMEOUT)" >&2 ;;
    esac
  else
    (
      set +u
      . "$file" >/dev/null 2>&1
      P_BIN="$bin"
      P_MODEL="${model:-${PROVIDER_DEFAULT_MODEL:-}}"
      P_DIR="$dir"
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
  for d in $(council_provider_dirs); do [ -f "$d/$1.conf" ] && return 0; done
  return 1
}

# A non-negative integer from env var $1, else default $2 (warning on garbage).
council_seconds() {
  local v
  eval "v=\"\${$1:-$2}\""
  case "$v" in
    ''|*[!0-9]*) echo "council: $1='$v' is not a number of seconds; using $2" >&2
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

# Start the round clock: export COUNCIL_DEADLINE = now + COUNCIL_ROUND_TIMEOUT
# (default 540, under a 600 s caller budget; 0 = no round deadline).
council_start_round_clock() {
  local r
  r="$(council_seconds COUNCIL_ROUND_TIMEOUT 540)"
  if [ "$r" = 0 ]; then unset COUNCIL_DEADLINE
  else COUNCIL_DEADLINE=$(( $(date +%s) + r )); export COUNCIL_DEADLINE; fi
}

# timeout(1) or GNU gtimeout (Homebrew coreutils on macOS); empty if neither.
council_timeout_cmd() { command -v timeout 2>/dev/null || command -v gtimeout 2>/dev/null || true; }

# Warn once per command when calls would run uncapped, and when a provider from
# before the sonnet/opus/fable split is still loaded (e.g. a user override at
# ~/.config/council/providers/claude.conf): it carries the old judge caps and
# 'reason', so it would sit on the panel next to its own replacements.
council_preflight_warnings() {
  local f
  if [ -z "$(council_timeout_cmd)" ] && [ "$(council_call_timeout 2>/dev/null)" != "0" ]; then
    council_warn "no timeout(1)/gtimeout found: model calls run uncapped (install coreutils)"
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
    else help="$("$cbin" --help 2>/dev/null)" || rc=$?; fi
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
