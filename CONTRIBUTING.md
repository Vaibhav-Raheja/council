# Contributing

Thanks for helping. This page covers setup, the checks to run, and a few house
rules.

## Set up

```sh
git clone https://github.com/Vaibhav-Raheja/council.git
cd council
bash test/run-tests.sh
```

The tests run offline against stub models in `test/fixtures`. They never call a
real model, so they cost nothing and need no sign-in.

## Before you open a pull request

Run all three checks. CI runs the same ones on Linux and macOS.

```sh
bash -n council install.sh lib/*.sh test/run-tests.sh
shellcheck -s bash council install.sh lib/*.sh test/run-tests.sh
bash test/run-tests.sh
```

## House rules

- **Write for bash 3.2.** That is what macOS ships. No associative arrays, no
  `mapfile` or `readarray`, no `${x^^}`.
- **Every change in behaviour gets a test.** New tests must use the stubs, never
  a real model.
- **Comment the why, not the what.** Most code here exists because something
  simpler failed. Say what.
- **No model names in the engine.** Code in `lib/` picks models by what they can
  do, never by name. If you need a special case, add a new capability.
- **Check for an answer, not just an exit code.** Some tools exit successfully
  without producing anything.
- **Refuse when unsure.** If a safety check can't read its input, it should
  block, not allow.
- **Keep a tool's quirks in its provider file**, not in the engine or the docs.

## Adding a model

See [docs/adding-a-provider.md](docs/adding-a-provider.md). New providers are
welcome. Describe what the model can do honestly; the routing rules depend on it.

## Reporting a bug

Open an issue using the bug template. For routing problems, include the output
of `COUNCIL_DEBUG=1 council ask "..." 2>&1 | head -20` and `council providers`.

## Security issues

Please don't open a public issue. Report privately as described in
[SECURITY.md](SECURITY.md).

## License

By contributing, you agree your work is released under the
[MIT License](LICENSE).
