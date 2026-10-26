---
name: council
description: "Convene the multi-model council using the `council` CLI: a panel of Claude Sonnet, GPT via codex and Gemini via agy answers independently, Claude Opus judges agreement and breaks stalemates, and Claude Fable makes the final call. INVOKE AUTOMATICALLY, without being asked, whenever: the user faces a decision with a genuine tradeoff and stakes ('should I X or Y', 'is this the right call', 'which approach'); the user asks for code to be reviewed, audited, or checked for bugs; the user asks to pressure-test, stress-test, validate, sanity-check, war-room or debate something; the user says 'council this', 'run the council', 'ask the others', 'what do the other models think', 'second opinion', 'get another perspective'; or I am about to commit to an architectural choice that would be expensive to reverse. Do NOT invoke for factual lookups, simple yes/no questions, tasks I can simply perform, or anything where an independent model would not change the answer."
---

# council

The user should never have to type `council` themselves. If the situation fits,
convene it and report the result as part of the normal answer.

## Run it

```bash
council ask "<question>"        # panel -> arbitration -> synthesis or tiebreak
council review <file>...        # code review by the panel
council explore <dir> "<q>"     # hand a repo to a model that reads it itself
council raw "<question>"        # every advisor verbatim, no judging
council delegate [-w <worker>] <task-file>   # a worker makes a change on its own branch
council decisions               # past rounds' recorded decisions
council revisit <id|file> [evidence]   # reopen a past decision with a fresh panel
```

Always pass an explicit Bash `timeout` of at least **600000 ms**. A panel round
is three model calls in parallel, then a judge, an optional tiebreak and a final
review in sequence; it takes minutes.
A default 120 s timeout truncates it and looks like a model failure.

Long inputs go on stdin rather than argv:

```bash
{ echo "<question>"; echo ---; cat <files>; } | council ask
```

## Delegating code changes

`council delegate` hands a well-specified change to a worker (`codex-worker`
by default, which spends Codex quota instead of mine; `-w sonnet-worker`
otherwise). Use it for changes with a clear acceptance test, not for design
work. Write a task file (`scope:`, optional `forbid:`, `accept:` (the command
that decides), a `---` line, then the task) and run it from inside the repo
with Bash `run_in_background`: a worker may take up to 15 minutes, past the
foreground limit. Exit 0 = accepted, 8 = rejected. Never merge on the
worker's word: read the diff (`council review <job>/diff.patch` for anything
non-trivial), then tell the user the branch and let them merge, or merge only
if they asked me to.

## Asking it

The frame I hand the council decides most of the answer: advisors tend to debate
inside it. They catch false technical premises, but they accept the question's
goal. On a replay of a real round, no advisor asked whether the thing I proposed
to build was worth building at all, even with the frame-testing preamble.

- Do not lead with my own recommendation. If I include it, label it a proposal
  under attack and ask for the strongest case against it.
- Mark earlier decisions (mine, the user's, a previous council round's) as
  hypotheses, unless one is a hard external constraint; then say which and why.
- Never hand over a closed list of options without asking what lies outside it.
- Give the evidence (measurements, errors, constraints), not just my conclusion.
- A past verdict is not settled. When new evidence arrives (a benchmark, a
  failure, a changed constraint), run `council revisit <id> < evidence.md`
  instead of building on the old verdict. Every round is recorded; `council
  decisions` lists them. A decision from before records existed can be
  revisited from a file that states the question and what was decided.

## What it does on its own

Advisors answer independently, behind a preamble that makes them test the
question's premises first. An arbiter rules on whether they *materially*
disagree, and whether they only echoed the question's frame. On agreement a
model outside the panel attacks the consensus before Fable may uphold it; on
stalemate a model that was not in the room casts a binding vote. Routing, panel composition and the
no-self-judgement rule are enforced by `@COUNCIL_HOME@/policy/rules.conf` — not by me
and not by the prompt. I do not pick which model answers.

Panel: Sonnet, Codex, Gemini. Opus judges: it rules agree or disagree and
breaks stalemates. Fable reviews every decision and makes the final call,
opening with UPHELD, AMENDED or OVERTURNED. That word is the first line of
Fable's `## ... final call (fable)` section, not of stdout. Always report that word, and if
Fable changed anything, say what and whose decision it overrode.

## Reporting back

- Give the council's answer, not a paraphrase that smooths it over.
- **Always surface disagreement.** If it went to a tiebreak, say so and say who
  lost and why. The disagreement is usually worth more than the consensus.
- If the council contradicts something I already told the user, say that
  plainly rather than quietly switching position.
- Attribute: "Codex found X, Gemini found Y." Do not present their findings as
  my own.
- Report the "Challenge to the consensus" section: what it attacked, and
  whether Fable accepted or rejected it. An UPHELD that survived a real
  challenge means more than one that met none.

## When NOT to convene

Consulting costs minutes and subscription quota. Skip it for anything I can
answer or do directly, for factual lookups, and for mechanical edits. The test
is whether an independent model or a larger context window would genuinely
change the answer — not whether the topic sounds important.

## If it fails

`council doctor` reports installation and live auth for every provider. Exit
codes: 2 usage, 3 hop-depth refused, 4 binary missing, 5 no answer produced,
6 truncated after a mid-stream failure, 8 delegated work rejected. A non-zero exit is never an answer:
report the failure rather than relaying partial output as advice.
