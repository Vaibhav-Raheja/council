# Worker invocations shared by run.sh and canary.sh, so the benchmark and the
# containment canaries always test the same command line.
#   invoke_worker <codex|agy|sonnet> <workdir> <prompt> <timeout-secs> <last-message-file>
# Containment, as measured by canary.sh on this machine:
#   codex  -s workspace-write. Needs unprivileged user namespaces for bwrap; with
#          kernel.apparmor_restrict_unprivileged_userns=1 every shell command fails.
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
      ( cd "$dir" && timeout "$secs" codex exec --ephemeral -s workspace-write -C "$dir" \
          -o "$last" "$prompt" ) ;;
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
