#!/usr/bin/env bash
# Guided setup. Idempotent — safe to re-run at any time.
set -uo pipefail

COUNCIL_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export COUNCIL_HOME
. "$COUNCIL_HOME/lib/common.sh"
. "$COUNCIL_HOME/lib/registry.sh"
. "$COUNCIL_HOME/lib/policy.sh"

STEP=0
step() { STEP=$(( STEP + 1 )); echo; echo "── $STEP. $* ──"; }

ask_yes() {
  # Never auto-install when running non-interactively.
  [ -t 0 ] || return 1
  printf '   %s [y/N] ' "$1"
  read -r a
  case "$a" in [yY]*) return 0 ;; *) return 1 ;; esac
}

echo "council setup — $(council_os)"
echo "home: $COUNCIL_HOME"

# ---------------------------------------------------------------- 1. providers
step "Providers"
MISSING=""
for id in $(council_provider_ids); do
  label="$(council_provider_meta "$id" PROVIDER_LABEL)"
  if bin="$(council_provider_bin "$id" 2>/dev/null)"; then
    printf '   %-10s installed   %s\n' "$id" "$bin"
  else
    printf '   %-10s MISSING\n' "$id"
    MISSING="$MISSING $id"
    hint="$(council_provider_meta "$id" PROVIDER_INSTALL_HINT)"
    [ -n "$hint" ] && echo "              install: $hint"
  fi
done

if [ -n "$MISSING" ]; then
  echo
  echo "   Missing providers are simply skipped — council works with whatever"
  echo "   is present, as long as the policy invariants can still be met."
  for id in $MISSING; do
    cmd="$(council_provider_meta "$id" PROVIDER_INSTALL_CMD)"
    [ -n "$cmd" ] || continue
    if ask_yes "Install $id now?  ($cmd)"; then
      sh -c "$cmd" || council_warn "install of $id failed; continuing"
    fi
  done
fi

# --------------------------------------------------------------------- 2. auth
step "Sign in"
cat <<'EOS'
   OAuth is the default and needs no secrets on disk. Each CLI keeps its own
   token. These are interactive browser flows, so a headless call can never
   complete one — if a provider fails the live check below, sign in first.
EOS
echo
for id in $(council_provider_ids); do
  council_provider_available "$id" || continue
  hint="$(council_provider_meta "$id" PROVIDER_AUTH_HINT)"
  [ -n "$hint" ] && printf '   %-10s %s\n' "$id" "$hint"
done

cat <<'EOS'

   API keys are OPTIONAL. Nothing here requires one. If a provider you add
   supports a key, set its env var in your shell profile and that provider
   will use it; providers that use OAuth ignore keys entirely.
EOS
for id in $(council_provider_ids); do
  keyenv="$(council_provider_meta "$id" PROVIDER_API_KEY_ENV)"
  [ -n "$keyenv" ] || continue
  if [ -n "$(eval "printf '%s' \"\${$keyenv:-}\"")" ]; then
    printf '   %-10s %s is set\n' "$id" "$keyenv"
  else
    printf '   %-10s %s is unset (optional)\n' "$id" "$keyenv"
  fi
done

# --------------------------------------------------------------------- 3. PATH
step "Put council on PATH"
BINDIR="${COUNCIL_BINDIR:-$HOME/.local/bin}"
mkdir -p "$BINDIR"
if ln -sf "$COUNCIL_HOME/council" "$BINDIR/council" 2>/dev/null; then
  echo "   linked $BINDIR/council -> $COUNCIL_HOME/council"
else
  cp "$COUNCIL_HOME/council" "$BINDIR/council" 2>/dev/null &&
    echo "   copied to $BINDIR/council (symlink unavailable)" ||
    council_warn "could not install into $BINDIR"
fi
case ":$PATH:" in
  *":$BINDIR:"*) echo "   $BINDIR is already on PATH" ;;
  *) echo "   NOTE: $BINDIR is not on PATH. Add this to your shell profile:"
     echo "         export PATH=\"$BINDIR:\$PATH\"" ;;
esac

# ------------------------------------------------------------------ 4. policy
step "Policy check"
echo "   rules: $(council_rules_file)"
printf '   reserved judge: %s\n' "$(council_policy_reserved_judge 2>/dev/null || echo none)"
if panel="$(council_policy_panel advise "" "$(council_policy_reserved_judge 2>/dev/null || true)" 2>&1)"; then
  echo "   advisory panel: $(echo "$panel" | tr '\n' ' ')"
else
  echo "   PANEL UNSATISFIED:"
  echo "$panel" | sed 's/^/     /'
  echo "     Install another provider, or lower min-advisors in policy/rules.conf."
fi

# ------------------------------------------------------------------ 5. verify
step "Live check"
"$COUNCIL_HOME/council" doctor | sed -n '/live check/,$p' | sed 's/^/   /'

cat <<'EOS'

Setup complete. Next:

   council roles                 who is good at what
   council providers             capabilities and availability
   council ask "<question>"      convene the panel
   council review <file>         code review by the panel

Adding another LLM:
   cp providers/_template.conf providers/<yourmodel>.conf   and edit it.
   No engine changes are needed — routing follows the capabilities you declare.
EOS
