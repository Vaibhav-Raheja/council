# Contributing

## Ground rules

1. **No provider names in the engine.** Routing goes through capabilities in
   `policy/rules.conf`. If you find yourself writing `if [ "$id" = "claude" ]`
   in `lib/`, the fix is a new capability tag instead.
2. **Never gate on an exit code alone.** Real CLIs exit 0 while producing no
   answer. Check for content.
3. **Fail closed.** Guards must refuse when their input is unparseable, never
   fall through to permissive. See `council_hop_depth`.
4. **bash 3.2.** Stock macOS ships it. No associative arrays, no `${x^^}`,
   no `readarray`.
5. **Provider quirks live in the provider.** Do not push a workaround up into
   the engine or into documentation the caller has to remember.

## Before opening a PR

```sh
bash test/run-tests.sh          # must pass, and must not touch the network
for f in council install.sh lib/*.sh providers/*.conf; do bash -n "$f"; done
```

Add a test for any behaviour you change. The suite runs against stubs in
`test/fixtures`, so new tests must not call a real model.

## Adding a provider

See [docs/adding-a-provider.md](docs/adding-a-provider.md). Provider PRs are
welcome. Declare capabilities honestly — the invariants are only as strong as
those claims, and an overstated `explore` or `large-context` will silently
mis-route other people's work.

## Reporting a routing bug

Include `COUNCIL_DEBUG=1 council ask "..." 2>&1 | head -20` and the output of
`council providers`. The debug log names the panel, the arbiter, the verdict and
the tiebreaker, which is usually enough to locate the fault.
