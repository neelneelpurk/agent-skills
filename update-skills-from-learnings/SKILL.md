---
name: update-skills-from-learnings
description: Fold accumulated learnings back into the agent's skills so lessons become permanent. Use this skill when the user wants to consolidate, review, or apply what the agent has learned - phrases like "update my skills from the learnings", "fold in the lessons", "improve my skills based on what went wrong", or during periodic cleanup. Reads the unprocessed learning files in the current project's .claude/learnings/ directory, maps each to the most relevant skill(s) under ~/.claude/skills/, and proposes concrete edits as diffs. Always proposes and waits for explicit approval before changing any skill, then applies only the approved edits and marks those learnings as folded-in. Can also propose creating a brand-new skill when a lesson fits nowhere. Pairs with the capture-learning skill that records the lessons in the first place.
---

# Update Skills From Learnings

Close the loop on self-improvement. The `capture-learning` skill records mistakes as small Markdown files inside a project; this skill reads those files and turns the lessons into permanent edits to the agent's skills, so the same mistake can't recur.

**This skill never edits a skill without approval.** It always presents a proposal first — a summary plus the exact diffs — and applies only what the user explicitly approves. Surfacing the changes and waiting is a hard requirement, not a nicety: skill files are the user's own, and silent edits would erode their trust in what their skills actually say.

## Inputs

- **Learnings** (input): `.claude/learnings/*.md` at the root of the current project, written by `capture-learning`. Learnings are per-project, so run this skill from inside the project whose lessons you want to fold in. The user may also point you at a specific directory.
- **Skills** (target of edits): the agent's personal skills under `~/.claude/skills/`, each a folder containing a `SKILL.md`.

## Procedure

### 1. Collect unprocessed learnings

```bash
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ls "$ROOT/.claude/learnings/"*.md 2>/dev/null
```

Read each file and parse its frontmatter. Process only those with `status: unprocessed`. Skip `folded-in` (already applied) and `wont-fold` (the user previously declined). If a learning has no frontmatter (e.g. hand-written), treat it as unprocessed and infer its fields from the prose.

If there are no unprocessed learnings, say so and stop — there's nothing to fold in.

### 2. Inventory the skills

List the skill folders and read each `SKILL.md`'s frontmatter `name` and `description`; skim the body enough to know what each skill covers and how it's organized.

```bash
ls ~/.claude/skills/
```

Build a quick mental map of `skill name -> what it's responsible for`. You'll match learnings against this.

### 3. Map each learning to a target

For every unprocessed learning, decide where the lesson belongs:

1. **Honor the hint.** If the learning's `related_skills` names a skill, start there.
2. **Match on tags and content.** Otherwise pick the skill whose responsibility most directly covers the situation in the learning.
3. **One, many, or none.** A lesson may touch more than one skill (propose an edit to each), exactly one, or none of the existing skills.
4. **None → propose a new skill.** If a lesson fits nowhere, flag it as a candidate for a brand-new skill rather than forcing it into an unrelated one (see "When a learning needs a new skill").

### 4. Draft the minimal edit for each target

For each (learning → skill) pair, write the smallest change that would have prevented the mistake. Favor precision over volume:

- Add a single rule, step, or guardrail to the section where it belongs (e.g. a checklist item, a "do this first" note).
- If the skill has a pitfalls/gotchas section, add a tight bullet there; if it doesn't and several lessons point the same way, propose adding one short "Common pitfalls" section.
- Phrase it as durable guidance ("Confirm the venv is active before any pip command"), not as a narrative of this one incident.
- **Don't bloat.** If the guidance is already present in the skill, note that and propose no edit. Don't restate existing rules. Keep `SKILL.md` coherent and readable.
- Preserve the file's existing structure, heading style, and frontmatter. Never alter the `name`; keep any `description` within its limits (max 1024 characters, no angle brackets).

### 5. Present the proposal and wait

Show the user a single consolidated proposal before changing anything:

1. A short summary table: each learning, its target skill (or "new skill"), and a one-line description of the proposed change.
2. The exact diffs for every target skill, so the user sees precisely what would change.

Then ask for approval and **stop**. Accept partial approval gracefully — "apply 1 and 3, skip 2", "yes to all", "edit the wording on 2 first". Do not apply anything until the user responds.

Suggested summary format:

```
| # | Learning                                   | Target skill          | Proposed change                                |
|---|--------------------------------------------|-----------------------|------------------------------------------------|
| 1 | Forgot to activate venv before pip install | (new skill: python-env)| Create skill with a "verify venv first" rule  |
| 2 | python-docx can't set page background      | docx                  | Add pitfall: page background needs raw XML     |
```

### 6. Apply only what was approved

For each approved edit, make the precise change to the skill's `SKILL.md` (or other skill files). Use exact, surgical edits — match the surrounding text and change only what's needed. Leave un-approved targets untouched.

If a tooling check is available, validate edited skills before finishing:

```bash
python /path/to/skill-creator/scripts/quick_validate.py ~/.claude/skills/<edited-skill>
```

(If `quick_validate.py` isn't present in this environment, just re-read the edited `SKILL.md` to confirm the frontmatter is still well-formed and the file reads cleanly.)

### 7. Mark the learnings

Update the frontmatter `status` of each learning according to the outcome:

- **Approved and applied →** `status: folded-in`. Also append a one-line trailer noting where it went, so the trail is auditable:
  ```markdown

  <!-- folded-in 2026-06-03: docx (Common pitfalls) -->
  ```
- **User permanently declined →** `status: wont-fold` (with a brief reason if given). It won't be re-proposed.
- **Just skipped for now →** leave `status: unprocessed` so it resurfaces next time.

### 8. Summarize

Report what changed: which skills were edited, which learnings were folded in, which were deferred, and any new-skill candidates still outstanding. Keep it brief.

## When a learning needs a new skill

If a lesson is valuable but fits no existing skill, don't shoehorn it in. In the proposal, flag it as a new-skill candidate with a suggested name and a one-line scope. If the user approves creating it, use the **skill-creator** skill to build it properly rather than dropping a thin `SKILL.md` by hand. Until it's created, leave the learning `unprocessed`.

## Worked example

Two unprocessed learnings exist in `.claude/learnings/`: one about forgetting to activate a Python venv (`related_skills: []`), one about python-docx page backgrounds (`related_skills: [docx]`).

1. Inventory shows skills: `docx`, `pdf`, `frontend-design`. No Python-environment skill exists.
2. Mapping: the docx lesson → `docx`; the venv lesson → no match → new-skill candidate (`python-env`).
3. Proposal shown to the user:
   - **docx** — add to a "Common pitfalls" bullet: setting page-level styling (background, watermark) often needs raw XML; verify the python-docx method exists first. *(diff shown)*
   - **new skill `python-env`** — proposed scope: "Verify and activate the project virtualenv before running any package manager." *(awaiting go-ahead)*
4. User replies: "Apply the docx one. Yes, create python-env."
5. Apply the `docx` edit; set that learning to `folded-in` with a trailer. Then invoke skill-creator for `python-env`; once built, fold in and mark that learning `folded-in` too.
6. Summary: "Edited `docx` (1 pitfall added). Created `python-env` and folded in the venv lesson. Nothing deferred."

## Principles

- **Approval is mandatory.** Propose, show diffs, wait. Never auto-apply.
- **Minimal, durable edits.** Add the smallest rule that prevents recurrence; write it as general guidance, not incident retelling.
- **Keep skills clean.** Don't duplicate existing guidance or let `SKILL.md` files sprawl. A skill that's bloated stops being read.
- **Leave an audit trail.** Folded-in learnings record where they went, so the path from mistake to fix stays visible.
- **Idempotent.** Re-running should pick up only what's still `unprocessed`; already-applied lessons are never re-proposed.
