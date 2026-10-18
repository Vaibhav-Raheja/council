# Security

## Reporting a vulnerability

Please report security problems privately, never in a public issue. On
[Vaibhav-Raheja/council](https://github.com/Vaibhav-Raheja/council), open the
**Security** tab and choose **Report a vulnerability**.

Include your `council` version (`council --version`), your operating system, the
AI command-line tools you use and their versions, and the smallest question or
file that shows the problem. We aim to reply within a week.

## Supported versions

| Version | Supported |
|---|---|
| Latest release (0.1.x) | Yes |
| `main` | Yes |
| Older | No |

## What to know before you use it

`council` is a shell script. It sends your question to several AI command-line
tools, then has other models judge the answers. It runs as you, with your
permissions. It does not lock those tools down itself. Instead, it starts each
one with that tool's own read-only options.

### Where your data goes

- Your question goes to every model in the round. One `council ask` can reach
  five models from three companies: Anthropic (`sonnet`, `opus`, `fable`),
  OpenAI (`codex`) and Google (`agy`).
- `council review` sends the full text of every file you name.
- A model that can read files can read anything in its reach, and what it reads
  can end up with its vendor.

Don't send anything you wouldn't paste into each of those companies' chat apps.

### What the models can read

| Provider | What it can read | Can it write or run commands? |
|---|---|---|
| `sonnet`, `opus`, `fable` | Only the folder you run `council` from | No |
| `codex` | Files outside that folder too | It can run commands, but its sandbox blocks writing files and network access |
| `agy` | Not limited by `council` | It is asked not to. This is an instruction, not a hard block, and setting `COUNCIL_AGY_ALLOW_TOOLS` removes it |
| `openai-api` (example, off by default) | Nothing | No |

### Files you are trusting

Provider files (`providers/*.conf`) and rules files are shell code that
`council` runs. That includes any you add under `~/.config/council/`. A rules
file there replaces the built-in one, so anyone who can edit it can switch off
council's safety rules. Only install a provider or rules file you would be happy
to run as a script.

### Credentials

Each AI tool keeps its own sign-in. `council` does not read or copy it. But
`council` does not clean up your environment before starting a tool, so every
variable you export, API keys included, is visible to every tool it starts.

### Text that tries to give orders

A model could be tricked by instructions hidden in a file you review or in
another model's answer (this is called prompt injection). `council` makes this
harder. It marks where each file and each answer starts and ends with random
tags that a file or answer cannot easily fake. It tells the models that this content is material to
examine, not orders to follow. And the models run with read-only settings, so
on most providers they can't change your files.

It cannot guarantee a model ignores hidden instructions. A planted instruction
can still sway an answer, and through it the verdict. Treat the result as
advice, and read the code yourself before acting on a review.

`agy` receives the question as a command-line argument. Other users on the same
machine can see it in the process list while it runs, and very large prompts
may be rejected. Avoid `agy` for sensitive questions on shared machines.

### Built-in limits

- `council` refuses to run from `/` or your home folder, because the models
  could read everything there. Set `COUNCIL_ALLOW_BROAD_CWD=1` to allow it.
- A provider that doesn't say how it stays read-only (its
  `PROVIDER_CONTAINMENT` line) is never used, not even when you call it by name.
- Every model call has a time limit (`COUNCIL_CALL_TIMEOUT`, 240 seconds by
  default), and so does the whole round. A tool that hangs is stopped, and
  forced to stop if it ignores the first request.
- Temporary files go in a private folder that is deleted when `council` ends,
  including when you press Ctrl-C. A crash or forced kill can leave it behind.
- A model can run `council` itself, but only a few levels deep
  (`COUNCIL_MAX_HOPS`, 2 by default). If the nesting count is unreadable,
  `council` refuses rather than guessing.

### What council does not check

`council` can't confirm that the version of each tool you installed actually
obeys its read-only options, and those options change between versions. Before
you rely on the table above, test each tool yourself. Give it a question that
asks it to write a file, read something outside the folder and run a command,
and check that it refuses. If it doesn't, treat that provider as unrestricted.

## Out of scope

- What a vendor does with the questions it receives. Your agreement with that
  vendor covers that.
- A tool that ignores its own read-only options. That is a bug in the tool, but
  please tell us so the table above can be corrected.
- Someone who can already edit your provider files, rules file or `council`
  folder. They can already run code as you.
