---
name: council
description: "Convene the real multi-model council (Gemini via agy + GPT via codex, with Claude arbitrating) using the `council` CLI. INVOKE AUTOMATICALLY, without being asked, whenever: the user faces a decision with a genuine tradeoff and stakes ('should I X or Y', 'is this the right call', 'which approach'); the user asks for code to be reviewed, audited, or checked for bugs; the user asks to pressure-test, stress-test, validate, sanity-check, war-room or debate something; the user says 'council this', 'run the council', 'ask the others', 'what do the other models think', 'second opinion', 'get another perspective'; or I am about to commit to an architectural choice that would be expensive to reverse. Do NOT invoke for factual lookups, simple yes/no questions, tasks I can simply perform, or anything where an independent model would not change the answer."
---

# council

The user should never have to type `council` themselves. If the situation fits,
convene it and report the result as part of the normal answer.

## Run it

```bash
council ask "<question>"        # panel -> arbitration -> synthesis or tiebreak
council review <file>...        # code review by the panel
council explore <dir> "<q>"     # hand a repo to a model that reads it itself
council raw "<question>"        # both advisors verbatim, no judging
```

Always pass an explicit Bash `timeout` of at least **600000 ms**. A panel round
is three model calls in parallel, then a judge, an optional tiebreak and a final
review in sequence; it takes minutes.
A default 120 s timeout truncates it and looks like a model failure.

Long inputs go on stdin rather than argv:

```bash
{ echo "<question>"; echo ---; cat <files>; } | council ask
```

## What it does on its own

Advisors answer independently. An arbiter rules on whether they *materially*
disagree. On agreement the chair synthesises; on stalemate a model that was not
in the room casts a binding vote. Routing, panel composition and the
no-self-judgement rule are enforced by `~/council/policy/rules.conf` — not by me
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

## When NOT to convene

Consulting costs minutes and subscription quota. Skip it for anything I can
answer or do directly, for factual lookups, and for mechanical edits. The test
is whether an independent model or a larger context window would genuinely
change the answer — not whether the topic sounds important.

## If it fails

`council doctor` reports installation and live auth for every provider. Exit
codes: 2 usage, 3 hop-depth refused, 4 binary missing, 5 no answer produced,
6 truncated after a mid-stream failure. A non-zero exit is never an answer —
report the failure rather than relaying partial output as advice.
