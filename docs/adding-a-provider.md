# Adding a provider

A provider is one file. The engine never learns its name — routing follows the
capabilities it declares.

```sh
cp providers/_template.conf providers/mymodel.conf
$EDITOR providers/mymodel.conf
council providers     # should now list it
council doctor        # calls it live
```

Files in `~/.config/council/providers/` shadow built-ins with the same name, so
you can retune a shipped provider without editing the repo.

## The contract

| Variable | Meaning |
|---|---|
| `PROVIDER_ID` | Slug; must match the filename. |
| `PROVIDER_LABEL` | Human-readable name. |
| `PROVIDER_ROLE` | One word, shown in listings: `chair`, `investigator`, `reader`, `advisor`. |
| `PROVIDER_SUMMARY` | What it is genuinely best at, and any quirk a caller must know. Shown by `council roles`. |
| `PROVIDER_CAPS` | Space-separated capability tags. **This is what routing uses.** |
| `PROVIDER_RANK` | Integer; lower wins when choosing among equals. |
| `PROVIDER_BIN_NAME` | Binary to look for on `PATH`. |
| `PROVIDER_BIN_ENV` | Env var that overrides discovery, e.g. `CODEX_BIN`. |
| `PROVIDER_BIN_CANDIDATES` | Extra absolute paths to try. |
| `provider_invoke()` | Prompt on stdin, **answer only** on stdout. |

Optional: `PROVIDER_DEFAULT_MODEL`, `PROVIDER_MODELS_HINT`, `PROVIDER_AUTH_HINT`,
`PROVIDER_AUTH_KIND`, `PROVIDER_API_KEY_ENV`, `PROVIDER_INSTALL_CMD`,
`PROVIDER_INSTALL_HINT`.

## Capabilities

Declare only what is true. The invariants are only as good as these claims.

| Tag | Meaning |
|---|---|
| `reason` | General advisory opinions. Required to sit on a panel. |
| `review` | Code review. |
| `explore` | Will read a repo itself when handed a directory. |
| `feed` | Must be handed content; cannot explore. |
| `large-context` | Comfortably ingests very large prompts. |
| `arbiter` | May rule on whether two answers actually disagree. |
| `tiebreak` | Eligible to cast a deciding vote. |
| `chair` | May synthesise agreeing answers. |
| `write` | Permitted to modify your disk. Grant sparingly. |

`arbiter`, `tiebreak` and `chair` are all constrained by `no-self-judgement`: a
provider holding them will still be excluded from judging any round it advised in.

## `provider_invoke()`

Inputs available to you:

- `$P_BIN` — the resolved binary path
- `$P_MODEL` — requested model, or `PROVIDER_DEFAULT_MODEL`, possibly empty
- `$P_DIR` — working directory, set only for `explore`-style calls

Rules:

1. Read the prompt from **stdin**.
2. Write **only the answer** to stdout. Diagnostics go to stderr.
3. Exit non-zero on failure.
4. Do not modify the filesystem unless you declared `write`.

The engine already handles what surrounds this: it discards whitespace-only
output, treats a non-zero exit with partial bytes as a truncated answer, shows
captured stderr when a call fails, and isolates every provider in a subshell so
two `provider_invoke` definitions cannot collide.

### Example: a CLI

```sh
provider_invoke() {
  set -- --print
  [ -n "${P_MODEL:-}" ] && set -- "$@" --model "$P_MODEL"
  "$P_BIN" "$@"
}
```

### Example: an HTTP API with a key

API keys are optional throughout `council`; nothing requires one. See
`providers/_openai-api.conf` for a working example using `curl` and `jq`. Enable
it by renaming it without the leading underscore and exporting the key. Note it
is metered per token by the vendor, unlike the OAuth subscription providers.

## Quirks belong in the provider

Anything a caller would otherwise have to remember goes in `provider_invoke()`.
The shipped `agy` provider is the worked example: that CLI reaches for a shell
tool even when the prompt already contains everything it needs, and its print
mode then denies the tool and returns nothing. The provider prepends a no-tools
instruction so callers never see the failure. Push the workaround down here
rather than documenting it upward.

## Checklist

- [ ] `bash -n providers/mymodel.conf` passes
- [ ] `council providers` lists it as installed
- [ ] `council doctor` gets a live `PONG`
- [ ] `council roles` reads accurately — capabilities you do not have are not claimed
- [ ] `bash test/run-tests.sh` still passes
