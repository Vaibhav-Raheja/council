# council delegate: hand a code change to a worker CLI and decide, without
# trusting the worker, whether to keep it.
#
#   1. a fresh git worktree on a new branch from HEAD, outside the repo
#   2. the worker edits it (its own sandbox: see providers/*-worker.conf)
#   3. council checks the diff against the task's scope, forbidden paths and a
#      protected list, and that the worktree's git link was not tampered with
#   4. council commits on the branch and runs the task's acceptance command in
#      a sandbox with no network and only the worktree writable
# The worker's own summary is recorded as an untrusted self-report; the diff
# and the acceptance command decide.

# A "key: value" line from a task file's header (everything before '---').
council_task_field() {
  awk -v k="$2" '
    /^---[[:space:]]*$/ { exit }
    { line = $0; sub(/^[[:space:]]+/, "", line) }
    index(line, k ":") == 1 { v = substr(line, length(k) + 2); sub(/^[[:space:]]+/, "", v); print v; exit }
  ' "$1"
}

# The task's free text: everything after the first '---' line.
council_task_body() {
  awk 'seen { print; next } /^---[[:space:]]*$/ { seen = 1 }' "$1"
}

# True when <path> is inside one of the space-separated <prefixes>.
# "." matches everything; "lib/" and "lib" both match lib/x.
council_path_in() {
  local p s
  p="$1"; shift
  for s in $*; do
    s="${s%/}"
    [ "$s" = "." ] && return 0
    [ "$p" = "$s" ] && return 0
    case "$p" in "$s"/*) return 0 ;; esac
  done
  return 1
}

# Paths a worker may touch only when the task's scope names them explicitly:
# git metadata (a .gitignore can hide files from this very check), council's
# own policy, CI, hooks, agent settings, secrets files and lockfiles.
council_path_protected() {
  case "$1" in
    .git|.git/*|.gitignore|*/.gitignore|.gitattributes|*/.gitattributes|.gitmodules) return 0 ;;
    .github/*|.gitlab-ci.yml|.circleci/*|.husky/*|.pre-commit-config.yaml) return 0 ;;
    policy/*|.claude/*|.codex/*|.agy/*|.gemini/*|.envrc|.env|.env.*|*/.env|*/.env.*) return 0 ;;
  esac
  case "${1##*/}" in
    package-lock.json|yarn.lock|pnpm-lock.yaml|Cargo.lock|poetry.lock|uv.lock|Gemfile.lock|go.sum|composer.lock) return 0 ;;
  esac
  return 1
}

# A protected path is allowed when a scope entry other than "." names it or a
# protected directory holding it ("lib" does not unlock lib/package-lock.json).
council_path_unlocked() {
  local p s
  p="$1"; shift
  for s in $*; do
    s="${s%/}"
    [ "$s" = "." ] && continue
    council_path_protected "$s" || council_path_protected "$s/x" || continue
    [ "$p" = "$s" ] && return 0
    case "$p" in "$s"/*) return 0 ;; esac
  done
  return 1
}

# Print one line per changed path that breaks the task's rules; silent if none.
#   council_delegate_violations <scope> <forbid> < changed-paths
council_delegate_violations() {
  local scope forbid p
  scope="$1"; forbid="$2"
  # Scope entries are split on spaces below; never let one expand as a glob.
  set -f
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    if [ -n "$forbid" ] && council_path_in "$p" $forbid; then
      echo "forbidden: $p"
    elif council_path_protected "$p" && ! council_path_unlocked "$p" $scope; then
      echo "protected: $p"
    elif ! council_path_in "$p" ${scope:-.}; then
      echo "outside scope: $p"
    fi
  done
  set +f
}

# The prompt the worker gets. The task body is the user's text, between tagged
# markers so a worker can tell the rules from the request.
#   council_delegate_prompt <task-file> <scope> <forbid> <accept> <tag>
council_delegate_prompt() {
  local task scope forbid accept tag
  task="$1"; scope="$2"; forbid="$3"; accept="$4"; tag="$5"
  echo "You are a coding worker. Make the change the task below describes, in the"
  echo "current directory: a fresh git worktree of the project."
  echo
  echo "Rules:"
  echo "  - Change only files under: ${scope:-anywhere in the repository}."
  [ -n "$forbid" ] && echo "  - Never touch: $forbid."
  echo "  - Never touch git metadata, CI config, hooks, lockfiles, .env files or"
  echo "    policy/ unless the scope above names them."
  echo "  - Do not commit, push or change git configuration. Council commits."
  echo "  - After you finish, council runs this acceptance command in a sandbox:"
  echo "      $accept"
  echo "    If you can run commands, run it yourself first. If you cannot, read the"
  echo "    code carefully instead."
  echo "  - Do not use the network. Everything you need is in this repository."
  echo "  - When done, reply with a short summary of what you changed and why. The"
  echo "    summary is not trusted: the diff and the acceptance command decide."
  echo
  echo "----- BEGIN TASK [task $tag] -----"
  council_task_body "$task" | sed 's/\[task /[untagged /g'
  echo "----- END TASK [task $tag] -----"
}

# Run the acceptance command on code the worker just wrote: no network, only
# the worktree writable, private /tmp and HOME. Without a usable bubblewrap it
# refuses (125) unless COUNCIL_DELEGATE_SANDBOX=off.
#   council_delegate_accept <worktree> <command>
council_delegate_accept() {
  local dir cmd limit tmo
  dir="$1"; cmd="$2"
  limit="$(council_seconds COUNCIL_DELEGATE_ACCEPT_TIMEOUT 600)"
  tmo="$(council_timeout_cmd)"
  [ -n "$tmo" ] && [ "$limit" != 0 ] && tmo="$tmo $limit" || tmo=""
  if [ "${COUNCIL_DELEGATE_SANDBOX:-bwrap}" = off ]; then
    echo "council: acceptance runs UNSANDBOXED (COUNCIL_DELEGATE_SANDBOX=off)" >&2
    # tmo is "" or "timeout N", split on purpose.
    # shellcheck disable=SC2086
    ( cd "$dir" && $tmo bash -c "$cmd" )
    return
  fi
  if ! command -v bwrap >/dev/null 2>&1 || ! bwrap --ro-bind / / true >/dev/null 2>&1; then
    echo "council: no usable bubblewrap; refusing to run the acceptance command unsandboxed" >&2
    echo "council: (on Ubuntu 24.04+ it needs an AppArmor userns profile; COUNCIL_DELEGATE_SANDBOX=off overrides)" >&2
    return 125
  fi
  # shellcheck disable=SC2086
  $tmo bwrap --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp \
    --bind "$dir" "$dir" --unshare-net --unshare-pid --die-with-parent \
    --chdir "$dir" --setenv HOME /tmp --setenv TMPDIR /tmp \
    bash -c "$cmd"
}
