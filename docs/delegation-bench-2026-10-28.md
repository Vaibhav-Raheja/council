# Delegation benchmark, round 2 (2026-10-28)

Question: should `council delegate` route a task to a different worker
depending on what kind of task it is?

Round 1 (`delegation-bench-2026-10-21.md`) had both workers pass all four
tasks, so it could not tell them apart. Round 2 adds three tasks built to
break that ceiling, each aimed at a known failure mode:

| Task | What it tests |
|---|---|
| `rootcause` | The failing test points at a report; the bug is in a shared date helper used by two other modules. Patching the report is the tempting wrong fix. |
| `convention` | A spec that leaves error type and time source unstated, so the answer must follow the package's existing conventions (`NotFound`, injectable `clock=`). |
| `audit` | Code against a rules document: two real mismatches next to two decoys that look wrong (a `TODO: should this be >=`?) but match the docs. |

`test/bench/selfcheck.sh` confirms every hidden suite fails on the untouched
repo and passes with the reference fix.

Workers: `codex` (gpt-6.1-sol, contained permission profile), `sonnet`
(claude-sonnet-5-5, file tools plus pytest), n=3 each. `agy` (Gemini 3.8 Flash
High, no shell) n=1 for reference. Models used: whatever each CLI served on
2026-10-28.

## Results

| Task | Worker | Hidden tests | Seconds | Diff lines | Files |
|---|---|---|---|---|---|
| rootcause | codex | 3/3 runs pass | 31, 44, 46 | 60 to 84 | 4 |
| rootcause | sonnet | 3/3 runs pass | 12, 14, 16 | 14 to 19 | 2 |
| rootcause | agy | 1/1 pass | 126 | 2 | 1 |
| convention | codex | 3/3 runs pass | 50, 69, 69 | 163 to 176 | 2 |
| convention | sonnet | 3/3 runs pass | 16, 21, 23 | 110 to 131 | 2 |
| convention | agy | 0/1 (no change made) | 38 | 0 | 0 |
| audit | codex | 3/3 runs pass | 30, 42, 47 | 18 to 59 | 2 |
| audit | sonnet | 3/3 runs pass | 14, 15, 23 | 6 to 20 | 1 to 2 |
| audit | agy | 1/1 pass | 272 | 6 | 1 |

No run touched a file outside its scope. Every codex and sonnet run fixed the
root cause in the shared helper, followed the package conventions, and left
both audit decoys alone.

What separates them:

- **Correctness: nothing.** 18 of 18 runs passed. Together with round 1, both
  workers are 7 of 7 task types.
- **Speed: Sonnet, about 3x.** Median 16 s against 46 s.
- **Diff size: Codex writes more tests.** Its extra lines are new test files
  (31 to 93 passing own tests on `rootcause` against Sonnet's 4 or 5). The
  source change itself was the same one line. This is thoroughness, not scope
  creep, but it is more for a reviewer to read.
- **Gemini Flash:** right when it acted (2 of 3), but on `convention` it
  started a subagent, announced it would wait for it, and exited with no edit.
  Slow (126 s and 272 s). Gemini Pro is not offered on this account
  (`agy models` lists only 3.8 Flash), so it could not be tested.

## Public evidence

`docs/research/model-routing-evidence-2026-10-28.md` surveys public
leaderboards. Its summary: GPT (Sol) wins clearly on cost and speed per task;
Claude leads hard multi-step terminal work, reasoning and frontend; Gemini
Flash trails on agentic coding; for debugging, refactors, long-context
reading and code review the gaps are within noise or untested. Most of those
numbers are from aggregators and vendor reports, so treat them as directional.

## Decision

Do not build per-task-kind routing (`kind:` in task files) yet. Neither the
local benchmark nor public data shows one worker beating the other at a kind
of task this repo delegates. The defensible routing is by cost and latency:

- default worker: whichever quota is cheaper to spend; on these subscriptions
  Sonnet is faster, Codex writes more tests;
- keep Gemini off `delegate`; keep it in the panel and the `digest`
  (large input) slot;
- revisit if a task type appears that one worker fails, or if Gemini Pro
  becomes available.

Limits: n=3 per cell, synthetic Python tasks under 200 lines of change, one
day. A ceiling result means these tasks are too easy to separate the two, not
that the two are equal on hard work.
