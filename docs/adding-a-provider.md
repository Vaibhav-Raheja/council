# Adding a provider

A provider is one file that tells council how to call a model. You never edit the
engine to add one. Council decides what work to give a model from the
capabilities the file lists, not from its name.

## 1. Copy the template

```sh
cp providers/_template.conf providers/mymodel.conf
```

To change a provider without touching the repo, put your file in
`~/.config/council/providers/` instead. A file there replaces a built-in one with
the same name.

## 2. Fill in the fields

| Field | What it's for | Example |
|---|---|---|
| `PROVIDER_ID` | Short name. Must match the filename. | `mymodel` |
| `PROVIDER_LABEL` | Name shown to people. | `"My Model"` |
| `PROVIDER_ROLE` | One word shown in listings. | `advisor` |
| `PROVIDER_SUMMARY` | What the model is good at, and any quirks. Shown by `council roles`. | `"Fast at code review."` |
| `PROVIDER_CAPS` | What work it may be given (see step 5). | `"reason review tiebreak"` |
| `PROVIDER_CONTAINMENT` | How it is kept read-only (see step 4). **Required.** | `"--sandbox read-only: no writes"` |
| `PROVIDER_RANK` | Lower is preferred when several models qualify. | `40` |
| `PROVIDER_BIN_NAME` | Program to look for on your `PATH`. | `mymodel` |
| `PROVIDER_BIN_ENV` | Variable that points at the program directly. | `MYMODEL_BIN` |
| `PROVIDER_BIN_CANDIDATES` | Other paths to try, separated by spaces. | `"$HOME/.local/bin/mymodel"` |

Optional fields: `PROVIDER_DEFAULT_MODEL`, `PROVIDER_MODELS_HINT`,
`PROVIDER_AUTH_HINT` (how to sign in), `PROVIDER_AUTH_KIND`,
`PROVIDER_API_KEY_ENV`, `PROVIDER_INSTALL_CMD`, `PROVIDER_INSTALL_HINT`.

## 3. Write `provider_invoke`

This function does the actual call. It must:

1. Read the prompt from standard input.
2. Print **only the answer** to standard output. Anything else goes to standard
   error.
3. Exit with a non-zero status if the call failed.

It can use these variables:

- `$P_BIN`: the path to the program
- `$P_MODEL`: the model to use, or `PROVIDER_DEFAULT_MODEL`, or empty
- `$P_DIR`: a directory to work in, set only for `council explore`

```sh
provider_invoke() {
  set -- --print
  [ -n "${P_MODEL:-}" ] && set -- "$@" --model "$P_MODEL"
  "$P_BIN" "$@"
}
```

Council handles the rest: it ignores empty answers, throws away answers cut off
by an error, shows the error output when a call fails, and keeps each provider's
code separate from the others.

If a tool has a quirk, work around it here so nobody else has to remember it.
The built-in `agy` provider adds a line to every prompt telling the model not to
use tools, because that tool otherwise returns nothing.

For a provider that calls a web API with a key, see
`providers/_openai-api.conf`. Remove the leading underscore to turn it on. API
keys are always optional in council.

## 4. Say how it stays read-only

Set `PROVIDER_CONTAINMENT` to one honest line saying which flags stop the tool
from changing files, running commands, or reading more than it should, and how
far they go:

```sh
PROVIDER_CONTAINMENT="--sandbox read-only: writes and network blocked; can still read outside the repo"
```

**A provider without this line is never used.** It still shows up in
`council providers`, but it is left out of every round and refused when called
by name. (A provider that lists the `write` capability is the only exception.)

Council checks that the line exists. It cannot check that the tool obeys its
flags, so test that yourself: ask it to write a file, read a file outside the
repo, and run a command, and make sure it refuses. If the only protection is an
instruction in the prompt, say so, as `agy` does. Then add your provider to the
table in [SECURITY.md](../SECURITY.md).

## 5. Pick capabilities

List only what is true. The rules can only be as reliable as these claims.

| Capability | Meaning |
|---|---|
| `reason` | Gives an opinion on a question. Needed to sit on the panel. |
| `review` | Reviews code. Used by `council review`. |
| `explore` | Reads a project folder by itself. Used by `council explore`. |
| `feed` | Can't explore; must be given the content in the prompt. |
| `large-context` | Handles very large prompts well. |
| `arbiter` | May decide whether the panel's answers really disagree. |
| `tiebreak` | May settle a disagreement. |
| `chair` | May merge answers that agree into one. |
| `final` | May review every decision in a round and give the final answer. |
| `write` | May change files on disk. Give this out rarely. |

A model never judges, merges or settles a round it answered in, whatever it
lists.

## 6. Check it works

```sh
council providers   # lists your provider as installed
council doctor      # calls it for real and expects PONG back
```

## Checklist

- [ ] `bash -n providers/mymodel.conf` passes
- [ ] `PROVIDER_CONTAINMENT` is set, and you tested the flags it names
- [ ] `council providers` shows it as installed
- [ ] `council doctor` gets `PONG` back
- [ ] `council roles` describes it accurately
- [ ] `bash test/run-tests.sh` still passes
