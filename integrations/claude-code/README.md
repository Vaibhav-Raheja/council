# Claude Code integration

Makes the council convene **itself**. You stop typing `council` and it fires when
the situation calls for it — a decision with real stakes, a review request, an
architectural choice that would be expensive to reverse.

Without this, the CLI still works; you just have to remember to run it, which in
practice means it gets built and never used.

## Install

`install.sh` offers to do this for you. To wire it by hand:

```sh
mkdir -p ~/.claude/skills/council
cp integrations/claude-code/SKILL.md ~/.claude/skills/council/SKILL.md
cat integrations/claude-code/CLAUDE.md.snippet >> ~/.claude/CLAUDE.md
```

Restart Claude Code, then ask it something with a genuine tradeoff. It should
convene the panel unprompted and tell you what each model said.

## The two pieces

**`SKILL.md`** is loaded on demand when its description matches what you asked.
The description carries the trigger list, so edit that rather than the body if
you want it to fire more or less often.

**`CLAUDE.md.snippet`** is always in context, so it still applies when no skill
matches. It repeats the triggers deliberately — belt and braces — and adds the
reporting rules.

## Why the reporting rules matter

The default failure of any "ask several models" setup is that the orchestrator
quietly smooths a disagreement into a confident consensus, which reads well and
tells you nothing. The rules therefore require it to:

- give the council's actual answer, not a paraphrase
- always surface disagreement, naming who lost the tiebreak and why
- attribute findings to the model that made them
- say plainly when the council contradicts what it told you earlier

## Tuning

Convening costs minutes and subscription quota, so the snippet also lists when
**not** to: factual lookups, mechanical edits, anything the assistant can simply
do. If it fires too eagerly, tighten that list first — it is more effective than
weakening the triggers.

## Other assistants

Nothing here is specific to `council` internals; it is prompt text plus a CLI
call. Adapting it to another agent means giving that agent the same four rules:
when to convene, when not to, the command, and how to report. Contributions for
other harnesses are welcome.
