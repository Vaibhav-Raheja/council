# Claude Code integration

This lets Claude Code run the council on its own, without you typing `council`.
It kicks in for decisions with real tradeoffs, code review requests, and choices
that would be costly to undo. It then reports what each model said, including
where they disagreed.

## Install

The easiest way is the installer, which asks before changing anything:

```sh
./install.sh
```

To install by hand, run this from your council folder. Both files contain the
placeholder `@COUNCIL_HOME@`, which these commands replace with the folder's
path:

```sh
mkdir -p ~/.claude/skills/council
sed "s|@COUNCIL_HOME@|$PWD|g" integrations/claude-code/SKILL.md > ~/.claude/skills/council/SKILL.md
sed "s|@COUNCIL_HOME@|$PWD|g" integrations/claude-code/CLAUDE.md.snippet >> ~/.claude/CLAUDE.md
```

If your folder's path contains `|`, `&` or `\`, use `./install.sh` instead.

## What the two files do

- **`SKILL.md`** loads when your request matches its description. Edit the
  description to make it run more or less often.
- **`CLAUDE.md.snippet`** is always loaded. It repeats when to run the council
  and says how to report the result: give the council's real answer, always
  show disagreement, and say which model found what.

## Check it works

Restart Claude Code and ask something with a real tradeoff, such as "should we
use Postgres or SQLite for this?". It should run the council without being asked
and tell you what each model said.

If it runs too often, add to the "do not run for" list in the snippet.

## Remove it

```sh
rm -r ~/.claude/skills/council
```

Then delete the section starting with `# Multi-model council` from
`~/.claude/CLAUDE.md`.
