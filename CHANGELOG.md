# Changelog

All notable changes to this project are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

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
