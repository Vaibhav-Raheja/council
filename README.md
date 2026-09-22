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
git clone https://github.com/<you>/council ~/council
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

Ships with `claude`, `codex` and `agy` (Antigravity/Gemini), plus a commented
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

17 tests, no network, no quota: they run against stub providers in
`test/fixtures`, including both the agreement and the stalemate branch.

## Requirements

`bash` 3.2+ (stock macOS works), plus the CLI of each provider you enable.
Tested on Windows (Git Bash); written for macOS and Linux by construction.

## Licence

MIT — see [LICENSE](LICENSE).
