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

  rc=0
  (
    set +u
    . "$file" >/dev/null 2>&1
    P_BIN="$bin"
    P_MODEL="${model:-${PROVIDER_DEFAULT_MODEL:-}}"
    P_DIR="$dir"
    export COUNCIL_HOP_DEPTH=$(( $(council_hop_depth) + 1 ))
    provider_invoke < "$prompt_file" > "$answer" 2> "$err"
  ) || rc=$?

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
