---
name: capture-learning
description: Record a lesson whenever something goes wrong so the agent never repeats it. Use this skill the moment a mistake, failure, or correction happens - a command errors out, a test fails unexpectedly, an approach gets abandoned, the user corrects the agent or says "no, do it this way", an assumption turns out wrong, or any avoidable rework occurs. Writes one timestamped Markdown file per learning into the current project's .claude/learnings/ directory, capturing what happened, the root cause, and the correct approach. Trigger proactively even when the user does not explicitly say to "log", "save", or "remember" it - capturing the lesson in the moment is the entire point. Pairs with the update-skills-from-learnings skill, which later folds these lessons back into the agent's skills.
metadata:
  version: 1.1.0
  tags: learning, mistakes, self-improvement, postmortem, notes
---

# Capture Learning

Turn mistakes into a durable, searchable record. Every time something goes wrong, write a single small Markdown file describing what happened and how to avoid it next time. One file per learning, timestamped, stored inside the project you're working in.

The goal is a low-friction reflex: notice a failure, jot the lesson, keep working. Over time these files become the raw material that the `update-skills-from-learnings` skill uses to permanently improve the agent's other skills.

## When to capture (trigger signals)

Capture a learning as soon as any of these occur. Don't wait to be asked.

- A command, build, test, or script fails in a way that wasn't expected.
- The user corrects you: "that's wrong", "no, do it this way", "you forgot X", "why did you do Y".
- You abandon an approach partway through because it wasn't working.
- An assumption you acted on turned out to be false.
- You repeated a mistake you (or a past session) had already made.
- A task took noticeably longer than it should have because of an avoidable misstep.

Do **not** capture trivia: ordinary tool output, successful steps, transient network blips that resolved on retry, or anything that carries no reusable lesson. Aim for signal, not a diary.

**Learnings vs. durable memory.** A learning is a *project-scoped record of a mistake and its fix*, meant to be folded back into a skill later. It is not the place for durable facts about the user or their stable preferences ("prefers tabs", "deploys on Fridays") — if you have a persistent memory system, those belong there. Rule of thumb: a correctable *mistake the agent made* → learning here; a *standing fact or preference* → memory.

## Where learnings live

Learnings are stored **per project**, one Markdown file each, under `.claude/learnings/` at the project root.

Resolve the project root and create the directory before writing:

```bash
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
mkdir -p "$ROOT/.claude/learnings"
```

If the work isn't inside a git repository, the current working directory is used as the root. (Tip: the project may want `/.claude/learnings/` in its `.gitignore` if these notes should stay local, or committed if the whole team should share them — leave that choice to the user.)

## Capture procedure

1. **Resolve the directory** as shown above.
2. **Generate a timestamp and a short slug.** The slug is a few kebab-case words naming the lesson.
   ```bash
   TS="$(date +"%Y-%m-%d_%H%M%S")"      # for the filename
   WHEN="$(date +"%Y-%m-%d %H:%M:%S %Z")"  # human-readable, for the file body
   SLUG="forgot-to-activate-venv"        # you choose this from the lesson
   ```
3. **Check for a near-duplicate.** Skim existing filenames in the directory. If essentially the same lesson is already recorded, don't create a second file — it's fine to skip, or to append a brief note to the existing one instead.
4. **Reflect honestly** on four things: what you were doing, what actually went wrong, the underlying cause (not just the symptom), and the corrected approach. Then name the early-warning signal that should make a future agent recall this.
5. **Write the file** at `$ROOT/.claude/learnings/${TS}_${SLUG}.md` using the template below.
6. **Confirm in one line** and continue the original task. Capturing a learning should not derail what you were doing — note it and move on.

## Filename convention

```
YYYY-MM-DD_HHMMSS_short-slug.md
```

Example: `2026-06-03_143002_forgot-to-activate-venv.md`

The leading timestamp keeps files in chronological order and prevents collisions; the slug makes the directory scannable by a human.

## File template

Every learning file starts with YAML frontmatter (so the `update-skills-from-learnings` skill can parse it) followed by four short sections. Keep each section tight — a few sentences, not an essay.

```markdown
---
title: "Forgot to activate the virtualenv before installing"
date: "2026-06-03 14:30:02 IST"
tags: [python, venv, dependencies]
related_skills: []          # folder name(s) of skills this might affect, if known
status: unprocessed         # unprocessed | folded-in | wont-fold
severity: medium            # low | medium | high
---

## What happened
Ran `pip install -r requirements.txt` and packages landed in the global
environment instead of the project venv, polluting the system Python.

## Root cause
Assumed the shell already had the venv active. It didn't — a fresh shell
starts with no environment activated.

## Correct approach
Always confirm the venv is active first (`which python` should point inside
`.venv/`), or run `source .venv/bin/activate` before any pip command.

## How to recognize this next time
About to run pip/poetry/uv in a project that has a `.venv/` directory and the
prompt doesn't show an active environment — stop and activate first.
```

### Frontmatter field notes

- **title** — one short sentence naming the lesson.
- **date** — local date and time from `date`; quote it so YAML treats it as a string.
- **tags** — a few lowercase keywords for grouping (language, tool, area).
- **related_skills** — if you know which skill was in play when the mistake happened, put its folder name here (e.g. `[docx]`). This makes the folding step far more accurate. Leave `[]` if unsure.
- **status** — always `unprocessed` at creation. The `update-skills-from-learnings` skill flips it to `folded-in` once the lesson is baked into a skill, or `wont-fold` if the user decides it shouldn't be.
- **severity** — rough impact, to help prioritize later.

## Worked example

Suppose, while editing a Word document, you assumed `python-docx` could set a page background color directly, wrote code that silently did nothing, and the user pointed it out.

```bash
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
mkdir -p "$ROOT/.claude/learnings"
TS="$(date +"%Y-%m-%d_%H%M%S")"
# write to: $ROOT/.claude/learnings/${TS}_docx-page-background-not-supported.md
```

```markdown
---
title: "python-docx cannot set page background color directly"
date: "2026-06-03 16:05:11 IST"
tags: [docx, python-docx, formatting]
related_skills: [docx]
status: unprocessed
severity: low
---

## What happened
Set a page background fill via python-docx; the document opened with a plain
white background and no error was raised.

## Root cause
python-docx has no high-level API for page background; the property has to be
written into the document XML directly.

## Correct approach
Edit the underlying XML (add a `w:background` element and the matching
`w:displayBackgroundShape` setting) rather than expecting a Python method.

## How to recognize this next time
Reaching for a python-docx method to style something page-level (background,
watermark) — check whether it actually exists before assuming it does.
```

Confirm to the user with a single line, e.g. "Logged that lesson to `.claude/learnings/`," and carry on.

## Principles

- **Lightweight and immediate.** A learning file is a quick note, not a report. The value is in capturing it now, before the detail fades.
- **One lesson per file.** Don't batch several unrelated mistakes into one file — the folding step works best when each file is a single, self-contained lesson.
- **Root cause over symptom.** "The test failed" is a symptom. "I edited the fixture but not the snapshot it's compared against" is a cause you can learn from.
- **Write for a future stranger.** The agent reading this later has none of today's context. Make "what happened" and "how to recognize this next time" stand on their own.
