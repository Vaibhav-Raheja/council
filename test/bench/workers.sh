# Worker invocations shared by run.sh and canary.sh, so the benchmark and the
# containment canaries always test the same command line.
#   invoke_worker <codex|agy|sonnet> <workdir> <prompt> <timeout-secs> <last-message-file>
# Containment, as measured by canary.sh on this machine:
#   codex  a permission profile. Plain -s workspace-write reads the whole disk
#          and keeps hosted web search, so the canary leaked the decoy. Needs
#          user namespaces for bwrap: with kernel.apparmor_restrict_unprivileged_userns=1
#          every shell command fails until /usr/bin/bwrap has an AppArmor
#          profile granting userns (Codex prefers the system bwrap on PATH).
#   agy    accept-edits + --sandbox. Shell is auto-denied headless (and still exits 0).
#   sonnet dontAsk with path-scoped rules. A bare "Write"/"Read" allow rule
#          approves ANY path; the canary caught that, so rules are scoped to ./**.
#          Reads outside cwd are allowed by default even then; --restricted closes it,
#          but also drops Bash unless --tools names it. Edit(path) rules cover Write
#          too (a Write(path) rule is ignored). Edits under ~/.claude are always
#          refused, so the work dir must live elsewhere (run.sh's outdir).
invoke_worker() {
  local worker="$1" dir="$2" prompt="$3" secs="$4" last="$5"
  case "$worker" in
    codex)
      # A permission profile instead of -s workspace-write (they cannot be
      # combined): reads and writes only in the workspace, plus the node/codex
      # install it re-executes from; no network; web search and browser off.
      # web_search="disabled" alone is not enough: the hosted codex_apps
      # connector (search_service.web_run) still fetches pages until apps is off.
      local nodedir
      nodedir="$(dirname "$(dirname "$(readlink -f "$(command -v node)")")")"
      ( cd "$dir" && timeout "$secs" codex exec --ephemeral -C "$dir" \
          -c 'default_permissions="council-worker"' -c 'web_search="disabled"' \
          -c "permissions.council-worker.filesystem={\":root\"=\"deny\",\":minimal\"=\"read\",\"$nodedir\"=\"read\",\":workspace_roots\"={\".\"=\"write\"}}" \
          -c 'permissions.council-worker.network.enabled=false' \
          --disable browser_use --disable in_app_browser --disable apps \
          -o "$last" "$prompt" </dev/null ) ;;
    agy)
      ( cd "$dir" && timeout "$secs" agy --output-format "${BENCH_AGY_FORMAT:-text}" --mode accept-edits --sandbox \
          --model gemini-3.8-flash-high --print-timeout "$(( secs - 20 ))s" -p="$prompt" ) | tee "$last" ;;
    sonnet)
      ( cd "$dir" && timeout "$secs" claude -p --restricted --tools "Read,Edit,Write,Glob,Grep,Bash" \
          --model claude-sonnet-5-5 --strict-mcp-config \
          --settings '{"advisorModel":""}' --permission-mode dontAsk \
          --allowedTools "Edit(./**)" "Bash(python3 -m pytest:*)" \
          -- "$prompt" ) | tee "$last" ;;
    *) echo "unknown worker $worker" >&2; return 2 ;;
  esac
}
