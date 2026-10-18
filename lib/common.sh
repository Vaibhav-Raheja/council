# Shared primitives. Sourced, never executed.
# Targets bash 3.2+ (macOS ships 3.2): no associative arrays, no ${x^^}.

council_die() { echo "council: $*" >&2; exit 1; }
council_warn() { echo "council: $*" >&2; }

council_os() {
  case "$(uname -s 2>/dev/null)" in
    Linux*)               echo linux ;;
    Darwin*)              echo macos ;;
    MINGW*|MSYS*|CYGWIN*) echo windows ;;
    *)                    echo unknown ;;
  esac
}

# Windows binaries cannot resolve Git Bash's /c/... paths.
council_native_path() {
  if [ -n "${1:-}" ] && command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1"
  else
    printf '%s' "${1:-}"
  fi
}

# A non-numeric hop counter must never read as "safe": `[ abc -ge 2 ]` errors and
# returns 2, which an `if` treats as false — that would let the recursion guard
# fail OPEN, which is its one job to prevent. Empty and unset both mean depth 0.
# Leading zeros are stripped ("08" would be invalid octal in $(( )), which the
# caller's `+ 1` hits), and more than 6 digits — far past any real depth, and
# enough to overflow arithmetic — also reads as maximum depth.
council_hop_depth() {
  local v
  v="${COUNCIL_HOP_DEPTH:-0}"
  case "$v" in *[!0-9]*) echo 99; return 0 ;; esac
  [ "${#v}" -gt 6 ] && { echo 99; return 0; }
  echo "$(( 10#$v ))"
}

# Same normalisation; garbage or an absurd ceiling falls back to the default.
council_max_hops() {
  local v
  v="${COUNCIL_MAX_HOPS:-2}"
  case "$v" in ''|*[!0-9]*) echo 2; return 0 ;; esac
  [ "${#v}" -gt 6 ] && { echo 2; return 0; }
  v=$(( 10#$v ))
  # Garbage depth reads as 99, so a ceiling at or above it would let a corrupted
  # counter pass the guard: clamp it below the sentinel.
  [ "$v" -gt 98 ] && v=98
  echo "$v"
}

council_depth_guard() {
  if [ "$(council_hop_depth)" -ge "$(council_max_hops)" ]; then
    echo "${1:-council}: hop depth $(council_hop_depth) reached (max $(council_max_hops));" >&2
    echo "${1:-council}: refusing to recurse." >&2
    exit 3
  fi
}

council_require_stdin() {
  if [ -t 0 ]; then
    echo "${1:-council}: pipe the prompt on stdin" >&2
    exit 2
  fi
}

# `command -v` can name a builtin, function or alias rather than an executable.
council_which() {
  local found
  found="$(command -v "$1" 2>/dev/null)" || return 1
  [ -n "$found" ] && [ -x "$found" ] || return 1
  printf '%s' "$found"
}

# Resolve a binary: $override, then PATH, then candidate paths.
council_resolve_bin() {
  local override name c
  override="${1:-}"; name="${2:-}"
  # shift fails only when fewer than 2 args remain; then drop what is there.
  # shellcheck disable=SC2015
  [ $# -ge 2 ] && shift 2 || shift $#
  if [ -n "$override" ]; then
    [ -x "$override" ] && { printf '%s' "$override"; return 0; }
    return 1
  fi
  council_which "$name" && return 0
  for c in "$@"; do
    [ -n "$c" ] && [ -x "$c" ] && { printf '%s' "$c"; return 0; }
  done
  return 1
}

# True when $1 is a legal shell variable name. Names read from provider files
# are checked before ${!name} indirection, so a malformed one reads as unset
# instead of being evaluated.
council_is_ident() {
  case "${1:-}" in ''|[!A-Za-z_]*|*[!A-Za-z0-9_]*) return 1 ;; esac
  return 0
}

# An answer must contain something other than whitespace.
council_has_content() { [ -f "${1:-}" ] && grep -q '[^[:space:]]' "$1" 2>/dev/null; }

council_log() { [ -n "${COUNCIL_DEBUG:-}" ] && echo "[council] $*" >&2; return 0; }
