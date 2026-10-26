# Changelog

All notable changes to this project are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- Advisors now test the question before answering it. They name the premises,
  "already decided" constraints, proposed answer and option set it takes for
  granted, and say first if one is wrong. Judges still see the question as
  asked. On a "Kafka for 200 messages a day" question, all three advisors now
  lead with the Kafka doubt instead of one, and the final answer changed from
  "use managed Kafka" to "don't run Kafka for this".
- Agreement no longer ends the debate. When the panel agrees, or only one
  advisor answers, a model outside the panel must attack the consensus with
  evidence (or reply `NO MATERIAL FLAW`) before the final call. Set
  `COUNCIL_SKIP_CHALLENGE=1` to skip it; it is skipped automatically when under
  150 s of the round remain.
- The arbiter also records whether the advisors only echoed the question's
  framing (`FRAME: ECHOED` or `FRAME: TESTED`). The final reviewer must engage
  any challenge, may uphold only by saying why it fails, and names the strongest
  objection to its own answer.

### Added

- `council delegate [-w <worker>] [--keep] <task-file>`: a worker model makes
  a code change in a fresh git worktree on its own branch, and council decides
  whether to keep it without trusting the worker. The diff must stay inside the
  task's `scope:`, avoid `forbid:` and a protected list (git metadata, CI,
  hooks, lockfiles, `.env`, `policy/`), keep the worktree's git link intact and
  stay under `COUNCIL_DELEGATE_MAX_LINES`; council then commits and runs the
  task's `accept:` command under bubblewrap with no network and only the
  worktree writable. Exit 0 accepted, 8 rejected. Nothing is merged for you.
- Worker providers `codex-worker` (reads and writes only its worktree; network,
  web search, apps and browser off) and `sonnet-worker` (file tools only, no
  shell). A new invariant, `write-requires-isolation`, keeps workers off every
  panel and judging seat, refuses calling them directly, and `doctor` skips
  them. Live check: both fixed the benchmark's debug task, including its
  hidden second bug.
- Decision records. Every top-level `ask`, `review` and `revisit` round that
  decides something writes a private Markdown record (question, challenge,
  final call) under `~/.local/state/council/decisions` (`COUNCIL_STATE_DIR`;
  `COUNCIL_NO_RECORD=1` skips it). `council decisions` lists them.
- `council revisit <id|file> [evidence]`: reopen a past decision with new
  evidence. A fresh panel must first give the strongest reasons it may now be
  wrong, then rule STAND, CHANGE or REVERSE. The new round records a link to
  the one it reopened. Takes a hand-written file for decisions made before
  records existed.
- `test/bench/frames/`: a frame-trap eval that checks whether advisors
  challenge a planted premise, a false "already decided" constraint or a
  closed option set.
- `test/bench/`: a delegation benchmark for worker CLIs, with hidden tests and
  sandbox-escape canaries.

## [0.1.0]

First public release.

### Added

- `council ask`: several models answer on their own, a judge decides whether
  they really disagree, and a model that did not answer settles any
  disagreement. A final reviewer then upholds, amends or overturns the result.
- `council raw`, `council review`, `council explore`, direct calls to one model,
  and `council providers`, `roles`, `rules`, `doctor` and `--version`.
- Models are added as one config file each and picked by what they can do. You
  can override them in `~/.config/council/providers/`. Ships with `sonnet`,
  `opus`, `fable`, `codex` and `agy`, plus an example that uses an API key.
- Rules in `policy/rules.conf` that the engine enforces: no model judges its own
  answer, a judge is always kept free, panels have a minimum and maximum size,
  and every model must say how it stays read-only.
- Time limits for each model call and for the whole round. They work on stock
  macOS too, with no extra tools.
- A limit on how many times council can call itself.
- A guided installer, and a Claude Code integration that runs the council on its
  own.
- Tests that run offline against stub models, and CI on Linux and macOS.

### Security

- Models that don't say how they stay read-only are never used, whether in a
  round or called by name. `council doctor` skips them.
- Council refuses to run from `/` or your home folder, where models could read
  private files. Set `COUNCIL_ALLOW_BROAD_CWD=1` to override.
- `council review` marks file contents as material to review, not instructions
  to follow, and stops a file from faking those markers.
- Answers passed between models are marked so one model's output can't pose as
  part of the instructions.
- Each run keeps its temporary files in a private folder, deleted when it ends
  or is interrupted.
- Pressing Ctrl-C stops every model call in progress, including `council
  review` and calls that ignore the first request to stop.
- `SECURITY.md` explains what data goes where, how each model is kept
  read-only, and how to report a problem.

### Fixed

- Folder paths with spaces work, both for council itself and for the launcher
  the installer creates.
- The Claude Code files are installed with your real folder path.
- `council doctor` and the installer report failure through their exit status.
- The installer no longer deletes an unrelated program named `council`.
- Bad values for time limits and the self-call counter fall back to safe
  defaults instead of causing errors.
- `council review` picks models that can review code.

[Unreleased]: https://github.com/Vaibhav-Raheja/council/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Vaibhav-Raheja/council/releases/tag/v0.1.0
