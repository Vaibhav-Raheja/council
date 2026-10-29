# Model routing evidence by task kind (compiled 2026-10-28)

Question: which model family is measurably best at which kind of coding-agent or reasoning task?
Families: OpenAI (GPT-6.1 Sol via Codex CLI), Anthropic (Sonnet 5.5, Opus 5.5, Fable 5.1), Google (Gemini 3.8 Flash; Gemini 4 Argon is not generally available).

## How to read this report

- Method: web searches plus fetches of aggregator pages (BenchLM, Vals.ai, benchmarklist, MyClaw, Lansweeper). I could not reach primary leaderboards (swebench.com, tbench.ai, arena.ai, METR, Epoch) directly; they were seen only through aggregators. Page summaries were produced by a small model, so re-check exact digits on the live page before citing them.
- Names are inconsistent across sources. Vals.ai and Lansweeper use "GPT-5.6 Sol/Terra/Luna" on some pages and "GPT-6.1 Sol" on others. I treat GPT-6.1 Sol as the Codex model the user runs; a "5.6 Sol" row is a different (earlier) model and is labelled so.
- The same model gets different scores on the same benchmark depending on who ran it. Sonnet 5.5 on Terminal-Bench 4.0 is 70.6% (Anthropic launch post) but 63.6% (Artificial Analysis, mini-swe-agent harness). Opus 5.5 is 66.4% (Anthropic), 59.6% (AA), 65.15% (Vals). Vendor numbers run 3 to 7 points above independent ones. Gaps of that size are harness and effort effects, not model effects.
- Contamination: SWE-bench Verified is saturated, and the official swebench.com Verified board has no entry after 2026-02-26 (read 2026-10-17 via Developers Digest). Aggregator Verified numbers of 95%+ are self-reported; ignore them for routing. This report uses SWE-bench Pro, DeepSWE, Terminal-Bench 4.0, FrontierCode and Vals benchmarks. Terminal-Bench 2.x is near ceiling (80 to 90%) and no longer discriminates.
- Age: nearly all numbers are from 2026-09-02 to 2026-10-28 (0 to 8 weeks old). Long-context and code-review numbers are older (Jan to May 2026) and name older models; flagged where relevant.

## 1. Debugging / root-causing a failing test in an existing repo

No benchmark isolates this. Proxies: SWE-bench Pro, DeepSWE, Bug Hunt Bench, SWE Multilingual.

| Benchmark | Date | Scores | Source | Caveats |
|---|---|---|---|---|
| SWE-bench Pro | Sep-Oct 2026 | Opus 5.5 89.9%, Sonnet 5.5 81.3%, Fable 5.1 81.2%. GPT-6.1 Sol: not published by OpenAI. Gemini 3.8 Flash: not listed | Anthropic system cards via https://benchlm.ai/md/models/claude-opus-5-5.md | Vendor-reported. No GPT or Gemini number, so no cross-family comparison |
| DeepSWE v1.1 | 2026-09-29 | GPT-6.1 Sol 75.2% (high effort; 71.9% max, unconfirmed transcription), Opus 5.5 74.2%, Gemini 3.8 Flash 73.8%, Sonnet 5.5 71.0%, Fable 5.1 67.4% | https://benchmarklist.com/models/openai-gpt-6.1-sol/ ; BenchLM model pages | Mixed publishers (OpenAI post, Anthropic cards, DeepSWE leaderboard). Top three within 1.4 points: noise |
| Bug Hunt Bench (fixes) | 2026 | Sonnet 5.5 51.3, Fable 5.1 43.0, Opus 5.5 41.7, Gemini 3.8 Flash 18.0. Sol not listed | https://benchlm.ai/md/models/claude-sonnet-5-5.md | Public data, small coverage; Sonnet above Opus is probably noise |
| SWE-bench (Vals) | 2026 | Gemini 3.8 Flash 80.0%. Others not retrieved | https://benchlm.ai/md/models/gemini-3-8-flash.md | One family only |
| SWE Multimodal (Vals) | Oct 2026 | Opus 5.5 70.2% vs Sol 43.5% | https://www.vals.ai/comparisons/anthropic_claude-opus-5-5-vs-openai_gpt-6.1-sol | Independent, same harness, 26.7 point gap. Needs image input, so not plain debugging |

Reading: Claude leads where a same-harness comparison exists. On DeepSWE, Sol, Opus 5.5 and Flash are within noise.

## 2. Implementing a new module from a written spec

Proxies: ProgramBench, Vibe Code Bench, FrontierCode, CursorBench.

| Benchmark | Date | Scores | Source | Caveats |
|---|---|---|---|---|
| ProgramBench (Vals) | Oct 2026 | Opus 5.5 18.5% vs Sol 3.0%; Fable 5.1 7.0% vs GPT-5.6 Sol 1.5% | https://www.vals.ai/comparisons/anthropic_claude-opus-5-5-vs-openai_gpt-6.1-sol ; https://www.vals.ai/comparisons/anthropic_claude-fable-5-1-vs-openai_gpt-5.6-sol | Independent. Low absolute scores. Anthropic's own run reports 80 to 91% on a different harness; do not compare |
| Vibe Code Bench v1.1 (Vals) | Oct 2026 | Opus 5.5 90.3% vs Sol 88.9% (within error); Fable 5.1 90.3% vs GPT-5.6 Sol 80.5% | Vals pages above | Sol vs Opus is inside noise; Sol costs $6.23 vs $57.92 |
| FrontierCode (AA run) | 2026-10-26 | Opus 5.5 52.2%, Sol 49.1%, Sonnet 5.5 45.8%, Gemini 4 Argon (high) 43.5% | https://myclaw.ai/blog/gpt-6-1-sol-for-coding (citing Artificial Analysis) | Cognition's FrontierCode 2.0 gives other numbers (Opus 45.5, Sonnet 41.0, Fable 32.4) |
| CursorBench 4.0 | Oct 2026 | Opus 5.5 57.8, Sonnet 5.5 55.5, Fable 5.1 51.8, Flash 39.6. Sol not listed | Cursor via BenchLM | Cursor harness |

Reading: Claude (Opus first, Sonnet close) leads on independent same-harness tests, mostly by small margins except ProgramBench. Sol is competitive at about one eighth the cost.

## 3. Large mechanical refactors across many files

No dedicated public benchmark. Proxies: Vals Code Migration, SWE Multilingual, SWE-Marathon.

| Benchmark | Date | Scores | Source | Caveats |
|---|---|---|---|---|
| Code Migration v1.1 (Vals) | Oct 2026 | Opus 5.5 81.0% vs Sol 77.3%; cost $72.40 vs $9.51; latency 3h29m vs 1h39m | Vals Opus vs Sol page | Gap about 1 SE. Sol is half the time at one eighth the cost |
| SWE Multilingual | Oct 2026 | Opus 5.5 93.9%, Sonnet 5.5 90.3%, Fable 5.1 89.1% | Anthropic cards | Vendor-reported; no GPT or Gemini counterpart |
| SWE-Marathon | 2026-10-03 | Sol 68 of 160 trials passing (max effort) | https://benchmarklist.com/models/openai-gpt-6.1-sol/ | Only one model retrieved |

Reading: thin. Mechanical refactors are cost and throughput dominated, which favors Sol or Sonnet, but no head-to-head isolates the task.

## 4. Finding relevant code / long-context reading

| Benchmark | Date | Scores | Source | Caveats |
|---|---|---|---|---|
| AA-LCR | 2026-10-18 | Fable 5.1 85.3%, Opus 5.5 84.7%, Sol 84.0%, Sonnet 5.5 82.7%, Gemini 3.8 Flash 81.3% | Artificial Analysis via BenchLM / benchmarklist | Independent. All within about 4 points: a tie |
| GraphWalks BFS 256K to 1M | Oct 2026 | Opus 5.5 66.8%, Fable 5.1 65.0% | Google Gemini 4 Argon launch chart (via BenchLM) | Competitor chart; Sol and Flash not retrieved |
| MRCR v2 at 1M, 8 needle | Mar-Apr 2026 | Opus 4.6 about 76 to 78%; GPT-5.5 74.0% (512K to 1M, OpenAI figure); GPT-5.4 36.6%; Gemini 3 Pro / 3.1 Pro about 25 to 26% | https://dev.to/owen_fox/long-context-llm-benchmarks-2026-which-model-actually-holds-accuracy-past-200k-tokens-17ka | OLD (7 months), previous generations; sources disagree (Opus 4.6 listed 76.0, 78.3, 92.9). No 5.x MRCR numbers found |

Reading: the one fresh independent score ties all families. Older MRCR suggested Claude and GPT beat Gemini at 1M tokens, but for previous-generation models. No current winner.

## 5. Terminal / agentic tool use

| Benchmark | Date | Scores | Source | Caveats |
|---|---|---|---|---|
| Terminal-Bench 4.0, Artificial Analysis | 2026-10-26 | Sonnet 5.5 63.6% ($12.65/task), Opus 5.5 59.6% ($13.11), GPT-6 Astra 59.1%, Gemini 4 Argon (high) 57.1% ($6.78), Sol 56.1% ($1.82), Gemini 3.8 Flash 19.7% | https://myclaw.ai/blog/gpt-6-1-sol-for-coding ; https://benchlm.ai/md/models/gemini-3-8-flash.md | 66 tasks, mini-swe-agent harness, pass@1 over 3 runs. Argon not at max effort. Sol emits about 108K output tokens per task |
| Terminal-Bench 4.0, Vals | Oct 2026 | Opus 5.5 65.15% vs Sol 55.05%; Fable 5.1 58.1% vs GPT-5.6 Sol 37.9% | Vals comparison pages | Independent, same harness. Sol cost $1.72 vs $13.20 |
| Terminal-Bench 4.0, vendor | Sep-Oct 2026 | Sonnet 5.5 70.6%, Opus 5.5 66.4%, Fable 5.1 55.8%, Flash 19.1% | Anthropic and Google cards via BenchLM | Vendor-reported, higher than independent runs |
| Terminal-Bench-Science 0.1 | Sep-Oct 2026 | OpenAI: Sol 57.0%. Anthropic: Sonnet 5.5 59.9%, Opus 5.5 58.7%. Vals: Sol 52.9% vs Opus 47.1%; Fable 40.0 vs GPT-5.6 Sol 20.0 | Cards, Vals | Sol vs Opus inside noise |
| SRE Bench (Vals) | Oct 2026 | Sol 50.8% vs Opus 33.6%; GPT-5.6 Sol 30.5 vs Fable 22.9 | Vals | GPT leads clearly |
| OSWorld 2.0 / 2.1 | Sep-Oct 2026 | Sol 71.4% (OpenAI, 2.0); Opus 5.5 48.7% (2.0); Flash 59.0% (2.0); Sonnet 5.5 80.1% (2.1) | Cards | Versions differ, not comparable. Computer use, not shell |
| Terminal-Bench 2.1 | Oct 2026 | Gemini 3.8 Flash 89.4% (Google), 81.3% (Vals); Fable 5.1 85.0% (Vals) | BenchLM | Near saturated; overstates Flash given its 19% on 4.0 |

Reading: Claude leads independent Terminal-Bench 4.0 (Vals about 10 points over Sol; AA 3 to 7 points). Sol is about 7x cheaper per task and stronger on SRE-style tasks. Flash is far behind on the harder set. Sonnet 5.5 matches or beats Opus 5.5 at similar cost on AA.

## 6. Code review (bugs in a diff, precision vs recall)

The thinnest area. No source compares the current models head to head on one bug set.

| Benchmark | Date | Result | Source | Caveats |
|---|---|---|---|---|
| Martian Code Review Bench | early 2026 | Best tool about 51.7% F1 (52.2% precision, 51.1% recall); 17 tools, 200K PRs | https://www.codeant.ai/blogs/ai-code-review-benchmark-results-from-200-000-real-pull-requests | Tool-level, not model-level; vendor write-up |
| GitHub ReviewBench | 2026-01 | 219 PRs, 19 languages; per-model results not retrieved | https://github.blog/2026-01-14-reviewbench-an-open-benchmark-for-ai-code-review/ | No model comparison found |
| Tenki benchmark | 2026-05 | Top recall 68.9% at 29.9% precision (Tenki's own product); other tools 25 to 36% recall | https://tenki.cloud/benchmarks/code-reviewer | Vendor-run |
| Factory review benchmark | 2026-04 | 13 models, 50 PRs, 167 bugs; numbers did not render | https://docs.factory.com/benchmarks/review-benchmark.md | Open in a browser to read |
| dev.to study | 2025 | GPT-4o higher recall, Claude Sonnet 4.5 higher precision | https://dev.to/rahulxsingh/claude-sonnet-45-code-review-benchmark-aig | OLD, previous generations; weak |

Reading: no usable current evidence. A weak old hint says GPT leans recall and Claude leans precision.

## 7. Architectural / tradeoff reasoning, math and logic

| Benchmark | Date | Scores | Source | Caveats |
|---|---|---|---|---|
| FrontierMath v2 T1-3 / T4 | Oct 2026 | Opus 5.5 91.2 / 95.0, Fable 5.1 90.2 / 87.8, Sonnet 5.5 88.8 / 80.5, Gemini 3.8 Flash 68.4 / 22.0. Sol not retrieved | Epoch AI via BenchLM | Independent |
| ArxivMath | Oct 2026 | Sol 95.0% (2026-10-03); Opus 5.5 96.9% with tools, 91.2% without | MatharenA; Anthropic card | Different tool settings; tie |
| ProofBench v1.1 (Vals) | Oct 2026 | Opus 5.5 100% vs Sol 99%; Fable 100% vs GPT-5.6 Sol 83% | Vals | Saturated |
| GPQA Diamond | Oct 2026 | Flash 95.3% (AA), Fable 93.7% (AA), GPT-5.6 Sol 95.2% (Vals) | AA, Vals | Saturated |
| AA-HLE | Oct 2026 | Opus 5.5 61.4%, Fable 5.1 59.1%, Sonnet 5.5 55.0%, Sol 52.9%, Flash 47.8% | AA | Independent |
| AA Intelligence Index | 2026-10-18 | Opus 5.5 58.4, Sonnet 5.5 54.2, Sol 51.8, Fable 5.1 49.0, Flash 30.6; Argon about 53 | AA via BenchLM | Index weights vary by source |
| CritPt | Oct 2026 | Sol 31.7, Opus 5.5 31.7, Sonnet 5.5 31.4, Fable 29.7, Flash 18.3 | AA | Three-way tie |

No benchmark measures architectural or tradeoff judgement. Math proxies put Opus 5.5 at or near the top, Sol close, Flash clearly weaker on hard problems.

## 8. Frontend / UI generation

| Benchmark | Date | Scores | Source | Caveats |
|---|---|---|---|---|
| Code Arena WebDev | 2026-09-23 | claude-opus-5.5-max 1818 +/-21, first | https://aiidelist.com/blog/claude-opus-5-5-code-arena-webdev.md | Secondary source; live board, re-check arena.ai |
| Code Arena WebDev | 2026-10-17 | Opus 5.5 (Max) rank 1 | https://www.developersdigest.tech/benchmarks/lmarena | Secondary. Polymarket (Oct 10) gave Anthropic 91.5% to lead in October |
| Code Arena WebDev | 2026-09-12 | GPT-6 Astra 1796 first, Fable 5.1 1764 | https://digg.com/ai/fw9cf6np | Older snapshot, superseded; Astra is not Sol |
| Design Arena Website | Oct 2026 | Opus 5.5 1326, Sonnet 5.5 1323, Fable 5.1 1312, Gemini 3.8 Flash 1299 | BenchLM (OpenRouter data) | Sol not retrieved; Claude models within each other's error |
| Vibe Code Bench v1.1 (Vals) | Oct 2026 | Opus 5.5 90.3 vs Sol 88.9 | Vals | Inside noise |

Reading: Claude leads; Sonnet 5.5 is nearly equal to Opus 5.5. Preference arenas reward polish, not correctness.

## 9. Speed, cost, instruction following and scope

| Benchmark | Date | Result | Source | Caveats |
|---|---|---|---|---|
| Vals cost and latency, Opus 5.5 vs Sol | Oct 2026 | Sol cheaper on every shared benchmark, about 5 to 12x (Terminal-Bench 4.0 $1.72 vs $13.20; Vals Index $3.61 vs $28.12); wall-clock roughly half | https://www.vals.ai/comparisons/anthropic_claude-opus-5-5-vs-openai_gpt-6.1-sol | Opus faster on a few tiny tasks |
| AA Terminal-Bench 4.0 cost | 2026-10-26 | Sol $1.82, Argon $6.78, Sonnet 5.5 $12.65, Opus 5.5 $13.11 per task. Sol average decode 1,736 s and first token 247 s at max effort | https://myclaw.ai/blog/gpt-6-1-sol-for-coding | Sol is cheap in dollars but max effort can be slow |
| Lansweeper matched runs | 2026-08-11 | Codex (GPT-5.6 Sol/Terra/Luna) won 12 of 15 vs Claude (Opus 5/Sonnet 5/Haiku 4.5); 2 Claude wins, 1 tie. Only Claude modified runtime code or exceeded scope. Rubric fails: 36 Claude vs 12 Codex | https://engineering.lansweeper.com/posts/does-the-same-coding-model-perform-differently-via-subscription-and-api/ | One task, 5 runs per pair, previous-generation models. Authors call it a snapshot |
| The New Stack scope study | 2026 | Removing a consent sentence raised Claude Code's out-of-scope actions from 0% to 17.1% | https://thenewstack.io/coding-agents-overstep-scope/ | Claude Code only, no cross-family comparison |
| Gray Swan IPI (prompt injection, lower is better) | Oct 2026 | Opus 5.5 1.0%, Fable 5.1 1.0%, Gemini 3.8 Flash 5.5% | Google launch chart | Competitor chart; not a scope measure |

Reading: Sol is far cheaper and about twice as fast on wall-clock. The one direct scope test favors Codex but is a single small experiment on older models.

## Cross-cutting facts

- Vals Opus 5.5 vs Sol: Opus scores higher on 22 of 29 shared benchmarks, Sol on 6 (Vals Science Index, Robo-bench, Terminal-Bench-Science, SRE Bench, IOI, BioMysteryBench), most within error. Vals Index 70.2% vs 63.9% (SE about 1) is a real gap. Vals pages disagree with each other on some numbers (Opus Vals Index 66.2% on its model page vs 70.2% on the comparison page).
- Fable 5.1 vs GPT-5.6 Sol (earlier model) on Vals: Fable ahead on most tests (Terminal-Bench 4.0 58.1 vs 37.9) except GPQA, CyberBench, SRE Bench and IOI (tie).
- Gemini 4 Argon (not generally available; Fairwind program only as of Oct 1) is reported to beat Opus 5.5 and GPT-6 Astra on 12 of 18 Google-selected benchmarks, but Google's table omits Sol and independent Terminal-Bench 4.0 puts Argon (57.1%) below Opus 5.5 and Sonnet 5.5. Not usable for routing yet.
- Gemini 3.8 Flash: fine on easy or saturated benchmarks (Terminal-Bench 2.1, DeepSWE 73.8%, GPQA), but Terminal-Bench 4.0 19.7%, FrontierMath Tier 4 22%, Bug Hunt 18 and AA Intelligence Index 30.6 (vs 49 to 58 for the others) show a large gap on hard tasks.

## Routing implications

Confidence: High = independent, same-harness, gap larger than noise, several benchmarks. Medium = independent evidence but thin or partly vendor-reported. Low = proxies only, old data, or gaps within noise.

| Task kind | Recommendation | Confidence | Why / where evidence is thin |
|---|---|---|---|
| 1. Debug failing test | No clear winner between Claude and GPT; avoid Flash | Low | SWE-bench Pro numbers exist only for Claude. DeepSWE has Sol, Opus and Flash within 1.4 points. Sonnet did best on Bug Hunt |
| 2. Implement module from spec | Claude (Opus 5.5; Sonnet 5.5 as cheaper option) | Medium | Vals ProgramBench favors Claude strongly, but Vibe Code Bench and FrontierCode gaps are small. Sol is 8x cheaper, so value-adjusted this is close |
| 3. Large mechanical refactor | No clear winner; lean Sol or Sonnet 5.5 for cost | Low | No dedicated benchmark. Code Migration gap (81.0 vs 77.3) is inside noise; Sol is half the time at one eighth the cost |
| 4. Find code / long context | No clear winner | Low | One fresh independent score (AA-LCR) ties all families within 4 points. Older MRCR favored Claude and GPT over Gemini but is 7 months old and for prior models |
| 5. Terminal / agentic shell | Claude for hard multi-step work; GPT for cost-sensitive or ops/SRE work; not Flash | Medium-High | Vals: Opus about 10 points over Sol on Terminal-Bench 4.0; AA: Sonnet 5.5 about 7 over Sol. Sol wins SRE Bench and is 7x cheaper. Flash 19% on 4.0 |
| 6. Code review | No clear winner; use a mixed panel | Low | No current head-to-head found. Old weak hint: GPT recall, Claude precision |
| 7. Architecture / math / logic | Claude (Opus 5.5, Fable 5.1 as final judge); GPT close behind | Medium | Opus tops AA Intelligence Index (58.4 vs Sol 51.8), FrontierMath, HLE. Sol ties on CritPt, ArxivMath. Nothing measures architectural judgement directly. Flash behind |
| 8. Frontend / UI | Claude (Opus 5.5; Sonnet 5.5 nearly equal) | Medium | Code Arena WebDev first for Opus 5.5 in Sep/Oct per secondary sources; one older snapshot had GPT-6 Astra first. Preference arenas, Sol not listed on Design Arena |
| 9a. Speed and cost | GPT (Sol) | High | Cheaper on every shared Vals benchmark (5 to 12x) and about 2x faster wall-clock. Caveat: long first token at max effort |
| 9b. Instruction following / scope | Slight lean GPT (Codex) | Low | One small Lansweeper experiment (Aug 2026, prior-generation models) plus anecdotes. Not enough to override capability or cost. Test locally |

Family summary:
- Claude: best on average across independent suites (Vals Index, AA Intelligence Index, Terminal-Bench 4.0, ProgramBench, WebDev). Costly. Sonnet 5.5 gets most of Opus 5.5's agentic results at similar per-task price, so Opus is not clearly worth a premium for terminal work.
- GPT-6.1 Sol: within noise of Claude on most coding benchmarks, ahead on SRE-type tasks, far cheaper and quicker, possibly more literal on instructions. Weakest where Claude's lead is largest (Terminal-Bench 4.0 on Vals, ProgramBench, SWE Multimodal).
- Gemini 3.8 Flash: do not route hard work to it; fine for bulk or easy tasks. Re-check when a Pro tier (such as Gemini 4 Argon) is available and independently benchmarked.

## Data gaps worth closing

1. Read primary leaderboards directly (tbench.ai, arena.ai, swebench.com Pro, METR, Epoch); this run saw them only through aggregators.
2. A same-bug-set code review comparison of Sol vs Sonnet 5.5 vs Opus 5.5 (Factory's 13-model benchmark is the best candidate; its page needs a browser).
3. Long-context: any MRCR v2 or similar run on the 5.x and 6.x generations.
4. Local measurement: this repo's delegation benchmark is better evidence for this project than any public number above, especially for instruction following and scope.
