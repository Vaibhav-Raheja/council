# council

Several AI CLIs, one question, and hard rules about who is allowed to do what.

Advisors answer independently. An arbiter decides whether they actually disagree.
If they do, a model that **was not in the room** casts the deciding vote.

```
$ council ask "should we shard this table or add read replicas?"

## Stalemate — escalating to a model that was not in the room

Point of contention, per the arbiter:
One advisor treats write volume as the binding constraint, the other treats
query latency as the binding constraint.

### Binding verdict
Read replicas first. The write figures quoted do not approach the ceiling of a
single tuned primary, so sharding buys headroom you do not need at a cost —
cross-shard joins — you would pay on every query from then on.
```

## Why

One model gives you one answer and no way to tell whether it is any good. Three
models with no structure gives you three answers and an argument. `council` adds
the structure: independent answers, an explicit agree/disagree ruling, and a
tiebreaker who cannot vote on their own opinion.

## Install

```sh
git clone https://github.com/Vaibhav-Raheja/council.git ~/council
~/council/install.sh
```

The setup is guided and idempotent. It finds your CLIs, offers to install the
ones it can, prints the sign-in command for each, links `council` onto your
PATH, checks the policy can be satisfied, then calls every provider live.

**OAuth is the default and no API key is required.** Each CLI holds its own
subscription token. API keys are supported but entirely optional — see
[Adding a provider](docs/adding-a-provider.md).

## Use

```sh
council ask "<question>"        # panel, arbitration, synthesis or tiebreak
council raw "<question>"        # every advisor verbatim, no judging
council review src/app.py       # code review by the panel
council explore ./repo "<q>"    # hand a repo to a model that reads it itself
council codex "<question>"      # call one provider directly

council providers               # who is registered, and what they can do
council roles                   # what each is best at
council rules                   # the enforced routing rules
council doctor                  # installation and live auth check
```

Questions can arrive on stdin: `cat notes.md | council ask "summarise"`.

## Or never type it at all

`integrations/claude-code/` wires the council to convene ITSELF inside Claude
Code — on a decision with real stakes, a review request, or an architectural
choice that would be expensive to reverse. `install.sh` offers to set this up.
Without it the CLI still works; you just have to remember to run it, which in
practice means it gets built and never used.

## Providers are data, not code

A provider is one `.conf` file. Adding an LLM never means editing the engine:

```sh
cp providers/_template.conf providers/mymodel.conf
$EDITOR providers/mymodel.conf
council doctor
```

Each file declares what the model is good at, how to find its binary, how to log
in, and one `provider_invoke()` function that takes a prompt on stdin and writes
the answer on stdout. Routing then follows the **capabilities** it declares —
never its name. Drop files in `~/.config/council/providers/` to override the
built-ins without touching the repo.

Ships with `sonnet`, `opus`, `fable` (all via the `claude` CLI), `codex` and
`agy` (Antigravity/Gemini), plus a commented
API-key example.

## Hard rules

Routing is enforced by `policy/rules.conf`, not left to a model's judgment.

| Invariant | What it prevents |
|---|---|
| `no-self-judgement` | A provider arbitrating, synthesising or breaking a tie on a round where it was itself an advisor — grading its own homework. |
| `reserve-judge` | Putting every model in the room and leaving nobody eligible to judge. |
| `min-advisors` | A "council" of one quietly pretending to be a panel. |
| `max-advisors` | Unbounded fan-out burning quota. |
| `write-requires-cap` | Advisors touching your disk. They run read-only regardless of what a prompt asks. |

Tasks map to required capabilities (`explore`, `large-context`, `review`,
`chair`, `tiebreak`, `arbiter`, …), so a model is only handed work it has
declared it can do. Edit the rules; the engine obeys them.

## Self-invocation

`council` is on PATH, so a provider can convene the council itself — including
recursively. `COUNCIL_HOP_DEPTH` bounds this, and it **fails closed**: a
non-numeric or corrupted counter is treated as maximum depth, not as zero.
Raise the ceiling with `COUNCIL_MAX_HOPS`.

## Who does what

| Provider | Model | Role in `council ask` |
|---|---|---|
| `sonnet` | Claude Sonnet | panel: fast, precise, answers from what it is given |
| `codex` | GPT via codex | panel: explores a repo itself; precise, falsifiable defects |
| `agy` | Gemini via Antigravity | panel: very large context; must be fed content |
| `opus` | Claude Opus | judge: rules agree/disagree, breaks stalemates |
| `fable` | Claude Fable | final call: reviews every decision, returns the answer |

A round runs in four steps:
1. The panel answers in parallel, blind to each other.
2. Opus rules whether they materially disagree.
3. On a stalemate, Opus issues a provisional verdict.
4. Fable reviews the panel answers, the ruling and any verdict, opens with
   `UPHELD`, `AMENDED` or `OVERTURNED`, and writes the final answer.

When the panel agrees, Fable writes the merged answer directly. On a stalemate,
Opus's verdict is printed as *provisional* because Fable may overturn it. Fable
also runs when the tiebreak fails, deciding the dispute itself, and when only one
advisor answered.

A final call counts only if its first non-blank line is exactly `UPHELD`,
`AMENDED` or `OVERTURNED` and it contains a `## Final answer` section. Anything
else, or a failed call, falls back to Opus. On agreement that means Opus's
synthesis; on a stalemate, its verdict, then labelled *binding*. Set
`COUNCIL_SKIP_FINAL=1` to skip Fable deliberately. The arbiter's reply is parsed
the same strict way: the exact word `AGREE` or `DISAGREE`, so "NOT AGREE" is a
disagreement.

`council_policy_reserved` holds the judge and every `final`-capable provider off
the panel. That applies even if one of them also declares `reason`.

The three Claude providers share one binary and each pins a versioned model id
(`claude-sonnet-5-5`, `claude-opus-5-5`, `claude-fable-5-1`). Every call blanks
Claude Code's `advisorModel`, so no call quietly consults another model. Without
that, the headless system prompt tells Claude to call its advisor, which breaks
panel independence and repeats Fable's review. Tools are `Read,Grep,Glob` under
`--restricted --strict-mcp-config`. File reads are confined to the working
directory, which is the repo under review, so run `council` from inside it.
Command-running tools, user settings and MCP servers are dropped. A judge can
check a claim against the code. An instruction smuggled into an answer cannot
make it run anything or read outside the repo. Prompt section markers carry a
random tag (`[tag …]`). It is fresh for each judging stage and never exported, so
no advisor can read it and no judge has seen the tag of a later stage. Any
`[tag ` inside embedded model output is rewritten before embedding. Judges are
told an untagged "section" is just data. The tag never appears in user-facing
output. `--restricted` needs a Claude Code that supports it; `council` warns if
the installed one doesn't.

`-m` names one model, so `ask`, `raw` and `review` refuse it rather than hand,
say, a Claude alias to codex. Pin panel models in `providers/<id>.conf`. Each
model call is capped by `COUNCIL_CALL_TIMEOUT` (seconds, default 240, `0` for
none). It runs under `timeout -k` (`COUNCIL_KILL_GRACE`, default 10 s), so a hung
or SIGTERM-ignoring CLI cannot stall a round. On BusyBox, which has no `-k`, it
runs without the grace kill. The whole round also has a soft deadline,
`COUNCIL_ROUND_TIMEOUT` (default 540 s). Later stages get only the time left,
and if they run out the round falls back to the decision already made. It is
soft because calls started near the deadline still get 1 s plus the kill grace.
With the defaults the worst case is about 572 s, plus at most 5 s for the
`--restricted` preflight check, which is still under a 600 s caller budget. Without `timeout`/`gtimeout`, calls run uncapped and
council warns.

A leftover `claude.conf` from before this split is ignored whenever `opus`
exists, and council warns about it.

## Design notes

Three behaviours that exist because the alternative was observed to fail:

- **Nothing is gated on exit codes.** Real CLIs exit `0` while producing no
  answer at all — on auth failure, or when a tool call is silently denied. Every
  check is on whether real content came back.
- **A non-zero exit with bytes already written is discarded**, not returned.
  That is a truncated answer, and half an opinion is worse than none.
- **Advisors never see each other's drafts.** Independence in round one is the
  only thing that makes the arbiter's ruling in round two mean anything.

## Tests

```sh
bash test/run-tests.sh
```

90 tests, no network, no quota: they run against stub providers in
`test/fixtures`, including both the agreement and the stalemate branch.

## Requirements

`bash` 3.2+ (stock macOS works), plus the CLI of each provider you enable.
Tested on Windows (Git Bash); written for macOS and Linux by construction.

## Licence

MIT — see [LICENSE](LICENSE).
