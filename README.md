# council

Ask several AI models the same question, and get one answer you can check.

`council` sends your question to three models at once. Each answers on its own,
without seeing the others. A separate judge decides whether they really
disagree, settles it if they do, and a final reviewer writes the answer you get.

Example (shortened):

```
$ council ask "should we shard this table or add read replicas?"

## Panel agreed — final call (fable)

UPHELD
All three advisors recommend read replicas first.

## Final answer
Add read replicas. The write volume you quoted is well within what one tuned
database handles, so sharding adds cost you do not need yet.
```

## Install

```sh
git clone https://github.com/Vaibhav-Raheja/council.git
cd council
./install.sh
```

The installer is guided and safe to run again. It finds the AI command-line
tools you have, tells you how to sign in to each, puts `council` on your PATH,
and checks that every model answers.

You sign in to each tool with your normal account. No API key is needed.

## Quick start

| Command | What it does |
|---|---|
| `council ask "<question>"` | Ask the panel and get one judged answer |
| `council raw "<question>"` | Show every model's answer as-is, no judging |
| `council review <file>...` | Have the panel review files |
| `council explore <dir> "<question>"` | Let one model read a folder itself and answer |
| `council <model> "<question>"` | Ask one model directly, for example `council codex "..."` |
| `council providers` | List the models and whether they are installed |
| `council roles` | Show what each model is good at |
| `council rules` | Show the routing rules |
| `council doctor` | Check that everything is installed and signed in |
| `council --version` | Print the version |

You can also pipe text in: `cat notes.md | council ask "summarise this"`.

Options: `-m <model>` picks the model for a single-model call, `-n <count>` sets
how many advisors to use, and `-C <dir>` sets the folder handed to models that
explore code themselves.

Run `council` from inside the project you are asking about. It refuses to run
from your home folder or `/`.

## How a round works

1. **Panel.** Claude Sonnet, GPT (via `codex`) and Gemini (via `agy`) answer in
   parallel. None of them sees the others' answers.
2. **Judge.** Claude Opus reads the answers and decides whether they really
   disagree or just word things differently.
3. **Tiebreak.** If they disagree, Opus picks a side and says why.
4. **Final call.** Claude Fable checks everything above, starts with `UPHELD`,
   `AMENDED` or `OVERTURNED`, and writes the final answer.

If Fable fails or is skipped, Opus's decision stands. A model never judges a
round it answered in. [docs/how-it-works.md](docs/how-it-works.md) covers the
details.

## Configuration

Set these as environment variables.

| Variable | Default | What it does |
|---|---|---|
| `COUNCIL_CALL_TIMEOUT` | `240` | Seconds one model call may take (`0` for no limit) |
| `COUNCIL_ROUND_TIMEOUT` | `540` | Seconds a whole round may take (`0` for no limit) |
| `COUNCIL_SKIP_FINAL` | off | Set to `1` to skip the final reviewer |
| `COUNCIL_ALLOW_BROAD_CWD` | off | Set to `1` to allow running from your home folder or `/` |
| `COUNCIL_MAX_HOPS` | `2` | How many times `council` may call itself (up to 98) |
| `COUNCIL_DEBUG` | off | Set to `1` to print which model was picked for what |

Time limits work on macOS without installing anything extra.

## Adding a model

Each model is one small config file in `providers/`. Copy
`providers/_template.conf`, fill it in, and run `council doctor`. No changes to
the main code are needed. See [docs/adding-a-provider.md](docs/adding-a-provider.md).

## Safety

- **Your prompts leave your machine.** Questions, and any file you `review`, go
  to every model on the panel, which means to several companies.
- **Models run read-only, with different strength.** Claude models can only read
  the current folder. Codex cannot write but can read outside it. Gemini (`agy`)
  is told not to use tools, which is an instruction, not a hard block.
- **A model that does not say how it stays read-only is never used.**
- **It refuses to run from your home folder or `/`,** so the Claude models are
  never handed your whole home folder to read. `COUNCIL_ALLOW_BROAD_CWD=1`
  overrides this.
- **Files under review are marked as data,** so a file cannot easily pose as
  instructions. This makes tricks harder; it does not make them impossible.
- **Each run's temporary files are deleted,** including when you press Ctrl-C.

Read [SECURITY.md](SECURITY.md) before using it on sensitive code, and to report
a problem.

## Use with Claude Code

`council` can be set up so Claude Code runs it on its own: for decisions with
real trade-offs, for code reviews, and for choices that are hard to undo.
`install.sh` offers this. See
[integrations/claude-code/README.md](integrations/claude-code/README.md).

## Requirements

- `bash` 3.2 or newer (the version that ships with macOS is fine)
- The command-line tool for each model you want: `claude`, `codex`, `agy`

The automated tests run on macOS and Linux. It has been used on Windows (Git
Bash), but Windows is not tested automatically.

## Tests

```sh
bash test/run-tests.sh
```

The tests use fake models, so they need no network and no account. `council
doctor` checks the real ones, and exits with an error if any check fails.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
