---
name: agent-skill-retro
description: Run a structured retrospective on an existing agent skill and fold the findings back into it. Use this whenever the user wants to review, critique, debug, refine, tune, or improve a skill they have been using — phrasings like "let's do a retro on my X skill", "this skill keeps mis-firing", "the skill ignored its own instructions", "update my skill based on how it went", "my skill is stale / too long", or "why isn't my skill triggering". The skill facilitates a guided interview across the common ways skills fail (triggering, instruction-following, coverage gaps, stale facts, bloat, repeated work), folds in real usage evidence when the user provides it, then proposes a prioritized changelog and applies the edits in place after the user approves. Trigger even when the user only says they want to "go over" or "reflect on" how a skill performed, or hands you a SKILL.md and says it needs work.
---

# Agent Skill Retro

This skill runs a retrospective on another agent skill and then improves that skill from what the retro surfaces. Think of it as two connected phases: first you *facilitate* a structured reflection on how the skill has actually been performing, then you *act* on it by proposing and applying concrete edits.

The reason this is its own skill — rather than just "edit the file" — is that skills fail in specific, recurring ways (it didn't fire when it should have; it fired and then got ignored; it carried a stale API fact; it was so long the agent wasted time). A good retro probes those failure modes deliberately instead of asking a vague "so how'd it go?". The structure is what turns a fuzzy "this skill is annoying" into a precise, fixable change.

## The workflow at a glance

1. **Locate and load** the skill being retro'd — read its SKILL.md and inventory its bundled resources so you understand what you're critiquing.
2. **Run the retro interview** — a guided, conversational pass across the common failure modes. Use real usage evidence if the user has it; don't block on it if they don't.
3. **Synthesize** the pain points into concrete, prioritized changes, each mapped to a specific part of the skill.
4. **Propose a changelog** and get the user's sign-off before touching anything.
5. **Apply the edits** in place, show the diff, and optionally repackage the skill.

Work through these in order, but stay flexible — if the user already knows exactly what's wrong, fast-forward to phase 3.

## Phase 1 — Locate and load the skill

The target skill is installed, so find it rather than asking the user to paste it.

- If the user gave a path, read the `SKILL.md` there. If they only named the skill, look for it under the usual skills locations (e.g. `/mnt/skills/`, a project's `skills/` or `.claude/skills/` directory, or wherever this environment keeps them) and confirm you've got the right one before going further.
- Read the **whole** `SKILL.md`, not just the description. Then inventory bundled resources — `scripts/`, `references/`, `assets/` — and note which the body actually points to. A reference file that nothing points to, or a script the body never mentions, is itself a finding.
- Build a quick mental model you can say back to the user in a sentence or two: *"This skill helps with X, triggers on Y, and bundles a script for Z."* Getting this reflected back early catches the case where you're even looking at the wrong skill.

Keep this phase light. You're orienting, not yet critiquing.

## Phase 2 — Run the retro interview

This is the heart of the skill. Lead a focused conversation across the dimensions below. Don't fire all of them at once like a form — that's exhausting and gets shallow answers. Take one theme at a time, ask a real question, listen, and follow the thread where it's alive before moving on. Two or three sharp questions per turn is plenty.

Open with something that surfaces lived experience, e.g. *"Tell me about the last couple of times you used this — what worked, and where did it get in your way?"* Then steer through the dimensions, prioritizing whichever the user's pain points point at.

**The dimensions to probe** (compact form — the expanded question bank with examples is in `references/retro-dimensions.md`; read it when you want depth or the user wants a thorough retro):

- **Triggering** — Did it fire when it should have, and stay quiet when it shouldn't? Undertriggering (the skill exists but the agent didn't reach for it) is the most common skill failure, and it almost always traces back to the `description`. Ask for examples of both misses and false-fires.
- **Instruction adherence** — When it did fire, did the agent follow it? Or did it follow some rigid rule so literally that it wasted effort or produced something stilted? Both "ignored the guidance" and "obeyed a bad rule too well" are findings.
- **Coverage gaps** — Was there a case the skill simply didn't speak to — an edge case, a new sub-task, an input shape it didn't anticipate? These become new or extended sections.
- **Accuracy & freshness** — Anything in the skill that's now wrong or stale? Changed APIs, renamed tools, outdated paths, advice that no longer holds. Skills rot quietly.
- **Conciseness & dead weight** — Is anything not pulling its weight? Sections the agent skims past, boilerplate, or instructions that send the agent down unproductive detours. Cutting is as valuable as adding.
- **Repeated work** — Does the agent keep re-deriving the same thing every run — rewriting a near-identical helper script, repeating the same multi-step setup? That's a strong signal to bundle it into `scripts/` once.
- **Resources & pointers** — Are bundled files actually used? Is anything referenced that's missing, or present but never pointed to? Are the "go read this next" pointers clear?
- **Output quality** — Did the outputs match what the user actually wanted in format, length, and tone? Mismatches usually mean the output spec needs tightening (or loosening).

**Using evidence.** If the user can share transcripts, example outputs, or specific past runs, ask for them and ground your findings in them — quote the moment where the skill mis-fired or the agent went sideways. It makes the diagnosis far sharper. But evidence is a bonus, not a gate: if the user is working from impression alone, run the retro on their recollection and just be honest that some findings are hypotheses to verify later.

**Capture as you go.** Keep a running list of pain points in the user's own words. Don't paraphrase the sting out of them — "it kept asking me dumb confirmation questions" is more useful to revise against than "minor UX friction."

## Phase 3 — Synthesize findings into proposed changes

Turn the retro into a concrete edit plan. For each finding, work out: **what changes, where, and why.**

- **Map each change to a location.** Triggering problems → the `description` frontmatter. Adherence problems → the relevant body section. Coverage gaps → a new/extended section. Stale facts → the specific lines. Repeated work → a new file in `scripts/`. Be specific about where so the user can picture it.
- **Categorize and prioritize.** Group changes (triggering / instructions / coverage / freshness / pruning / bundling) and lead with the ones that fix the loudest pain. Not every retro comment needs a code change — some are one-offs, not patterns.

When you actually write the revisions, a few principles make the difference between a patch that helps once and one that helps every future run:

- **Generalize; don't overfit.** The user is reasoning from a handful of remembered cases, but the skill will run across thousands. Resist fiddly fixes pinned to one example. If an issue is stubborn, it's often better to reframe with a different metaphor or recommend a different working pattern than to bolt on another narrow rule.
- **Explain the why.** Today's models follow reasoning better than they follow edicts. If you catch yourself writing ALWAYS or NEVER in all caps, or a rigid template, treat it as a yellow flag — usually you can explain *why* the thing matters and get better, more humane adherence than a bare command.
- **Keep it lean.** Prefer cutting dead weight over piling on. A shorter skill that the agent actually reads beats a thorough one it skims.
- **Bundle genuinely repeated work.** If the retro shows the agent rewriting the same script every time, write it once, drop it in `scripts/`, and have the body point to it.

## Phase 4 — Propose the changelog, get approval

Before editing anything, show the user a clear, readable changelog so they can steer. Editing a skill they rely on without sign-off is exactly the kind of surprise to avoid.

For each proposed change, show enough to judge it — a short before/after for edits to existing text, or the gist of new content. Group by category, note the *why* in a line, and let the user accept all, reject some, or tweak. Wait for an explicit go-ahead, and feel free to apply only the subset they approved.

## Phase 5 — Apply the edits (and optionally repackage)

- **Preserve identity.** Keep the skill's directory name and its `name` frontmatter field exactly as they were — you're revising this skill, not forking a `-v2`.
- **Mind read-only locations.** The installed skill may live somewhere you can't write (e.g. a mounted, read-only skills directory). If so, copy the whole skill folder to a writeable location first, edit there, and work from the copy.
- **Make the approved edits**, then show the actual diff so the user sees precisely what changed. If you added a `scripts/` file or new reference, mention it explicitly.
- **Repackage if useful.** If the environment installs skills from a `.skill` bundle, you can zip the folder (e.g. `cd <parent> && zip -r <skill-name>.skill <skill-name> -x '*/__pycache__/*' '*.pyc'`) and hand back the path. If the `skill-creator` skill is available, its `scripts/package_skill.py` validates and packages in one step — prefer it. Validate before shipping: name is kebab-case, the `description` has no angle brackets, and there's exactly one `SKILL.md`.

Close by summarizing what changed and what the user should watch for next time they use the skill — that watch-list becomes the seed for the next retro.

## When to hand off to skill-creator

This skill is the retro-driven improvement loop: reflect on lived usage, then patch. If the user wants the heavier machinery — running the skill against test prompts, quantitative benchmarking, or the automated description-optimization loop for triggering accuracy — that lives in the `skill-creator` skill. Point them there rather than reinventing it. The two compose well: retro to decide *what* to change, skill-creator's eval tooling to *verify* the change helped.

## A few principles to keep in mind

- A retro is reflection, not interrogation. Keep it conversational and let the user's real frustrations lead.
- The goal is a skill that works on the next thousand tasks, not one patched to satisfy the last three.
- Cutting and clarifying usually beat adding.
- Always show changes before applying them, and preserve the skill's name.

## Reference

- `references/retro-dimensions.md` — the expanded interview question bank for each failure mode, with concrete examples of findings and the edits they map to. Read it for a deep or unfamiliar retro.
