# Retro Dimensions — Expanded Question Bank

This is the deep version of the interview themes summarized in `SKILL.md`. Use it when running a thorough retro, when the skill under review is unfamiliar, or when the user's pain is vague and you need sharper questions to locate it.

Each dimension below has: **the symptom** to listen for, **probing questions** to draw it out, **where the fix lives**, and a **worked example** showing a finding turning into an edit. The examples are illustrative — adapt them; don't pattern-match them onto the user's actual skill.

## Contents

1. Triggering
2. Instruction adherence
3. Coverage gaps
4. Accuracy & freshness
5. Conciseness & dead weight
6. Repeated work
7. Resources & pointers
8. Output quality

---

## 1. Triggering

**Symptom.** The skill exists but doesn't get used when it should (undertriggering — by far the most common), or it fires on tasks it has no business handling (overtriggering). Triggering is decided almost entirely by the `description` frontmatter, since that's what the model sees when deciding whether to consult the skill.

**Probing questions:**
- Can you think of a time you expected this skill to kick in and it didn't? What did you ask, in your words?
- Are there tasks where it fires but shouldn't — where it pulls the conversation somewhere you didn't want?
- When it misses, are you usually naming the skill explicitly, or describing the task in your own way?
- Are there phrasings, file types, or contexts you use a lot that the description never mentions?

**Check the frontmatter levers before touching the prose.** Triggering is decided mostly by the `description`, but several frontmatter fields can block a skill outright — and when one of these is the cause, no wording change will ever fix it:
- `disable-model-invocation: true` — the model can't auto-load the skill at all; only the user can invoke it with `/name`. If the complaint is "it never fires on its own," this is the first thing to rule out.
- `user-invocable: false` — hidden from the `/` menu (it can still auto-trigger). The opposite complaint: "I can't call it manually."
- `paths` — scopes auto-activation to matching files; if the user works outside those globs, it stays quiet.
- The combined `description` + `when_to_use` text is truncated at ~1536 characters in the skill listing, so triggers buried past that cap are effectively invisible — put the key use case first.

**Where the prose fix lives.** The `description` (plus `when_to_use`). Two failure shapes, two fixes:
- *Undertriggering* → broaden and make the description a little "pushy." Add the real phrasings, synonyms, file types, and contexts the user actually uses, including cases where they don't name the skill outright. Spell out "use this even when…" situations.
- *Overtriggering* → tighten. Name the adjacent tasks it should *not* handle, and sharpen the boundary against whatever neighboring skill should win those.

Remember the mechanism quirk: the model tends to skip skills for tasks it can already do in one trivial step. A description can be perfect and still not fire on "read this file." That's expected, not a bug to fix.

**Worked example.**
Finding: *"It never triggers when I paste a stack trace and say 'this broke after the deploy' — I have to literally say 'use the debug skill'."*
Edit (to description): add the lived phrasing and intent — e.g. "...trigger when the user pastes an error or stack trace, says something broke after a deploy or release, or describes behavior diverging from expectations, even if they don't name debugging explicitly."

---

## 2. Instruction adherence

**Symptom.** The skill fires, but the agent doesn't follow it — or follows it *too* literally. Both directions matter. Ignored guidance points to instructions that are buried, unclear, or unmotivated. Over-literal obedience (e.g. rigidly filling a template that didn't fit, or asking confirmation at a step where it was obviously unnecessary) points to a rule stated as a bare command without the reasoning that would let the agent apply judgment.

**Probing questions:**
- When it fired, did it do the thing the way you wanted, or did you have to correct it?
- Was there a step where it did exactly what the skill said but the result was wrong or clumsy for the situation?
- Did it ever feel robotic — following the letter of an instruction past the point of sense?
- Which parts of the skill's guidance seem to get dropped?

**Where the fix lives.** The relevant body section.
- Dropped guidance → move it earlier, state it more plainly, or explain *why* it matters so it carries weight.
- Over-literal behavior → reframe the rigid rule. Replace "ALWAYS do X" with the reasoning ("X matters because…, so prefer it when…") so the agent knows when the rule bends. Heavy all-caps MUST/NEVER blocks are a yellow flag worth softening into explained intent.

**Worked example.**
Finding: *"It always asks me to confirm the output format even when I already told it. Annoying."*
Edit: replace the unconditional "confirm the format before generating" with "if the user already specified a format, use it; only ask when the format is genuinely ambiguous and the wrong guess would waste real work." The agent now applies judgment instead of asking reflexively.

---

## 3. Coverage gaps

**Symptom.** A real case the skill simply doesn't address — an edge case, a new sub-task the user started doing, an input shape it never anticipated. The agent improvises (sometimes fine, sometimes not) because the skill is silent.

**Probing questions:**
- Was there a situation where you wished the skill had said something and it just… didn't?
- Have your tasks evolved since the skill was written? Any new variant you keep running into?
- Are there input shapes (a weird file, a new data layout, an unusual request) it doesn't seem ready for?
- When the agent improvised, did it land somewhere good, or somewhere you had to fix?

**Where the fix lives.** A new section, or an extension of an existing one. If the gap is a whole sub-domain, consider a new reference file rather than bloating the body.

**Worked example.**
Finding: *"Half my files now come as .tsv, and the skill only ever talks about .csv. It fumbles the delimiter."*
Edit: generalize the relevant section from "CSV" to "delimited text (CSV/TSV)" and add a line on detecting or asking about the delimiter — fixing the class of problem, not just the one extension.

---

## 4. Accuracy & freshness

**Symptom.** Something in the skill is now wrong or stale — a changed API, a renamed tool or flag, an outdated path, a default that shifted, advice that no longer holds. Skills rot silently because nothing forces them to update.

**Probing questions:**
- Is anything in here that you know is now out of date or just incorrect?
- Have any tools, APIs, libraries, or paths it references changed since it was written?
- Does any of its advice contradict what you've actually learned works?
- Are version numbers, model names, or endpoints current?

**Where the fix lives.** The specific lines. Be surgical — correct the fact and check whether the same stale fact appears elsewhere in the skill or its references.

**Worked example.**
Finding: *"It tells the agent to call `old_endpoint/v1`, but that was deprecated months ago — it's `/v2` now with a different field name."*
Edit: update the endpoint and the field name everywhere they appear, and if the body shows example payloads, fix those too so nothing reintroduces the stale call.

---

## 5. Conciseness & dead weight

**Symptom.** Parts of the skill aren't earning their place. Sections the agent skims past, restated boilerplate, or — worse — instructions that actively send the agent down unproductive detours and burn time. A long skill the agent half-reads is weaker than a tight one it fully absorbs.

**Probing questions:**
- Does the skill ever make the agent do busywork — steps that don't move the task forward?
- Are there parts you suspect it just ignores, or that feel like filler?
- Is it longer than it needs to be? Anything you'd be glad to see gone?
- Did following it ever feel slower than just doing the task directly?

**Where the fix lives.** Cut or compress. If transcripts are available, read them (not just the final outputs) to spot where the skill caused wasted motion, and remove whatever prompted it. Cutting is a real improvement, not a consolation prize.

**Worked example.**
Finding: *"It spends ages 'analyzing the repo structure' before every tiny change and most of that is pointless."*
Edit: remove or scope down the mandatory analysis step — e.g. "for small, localized edits, go straight to the change; reserve a full structure pass for genuinely cross-cutting work." Less ceremony, faster results.

---

## 6. Repeated work

**Symptom.** Across runs, the agent keeps re-deriving the same thing — rewriting a near-identical helper script, repeating the same multi-step setup, reconstructing the same boilerplate. Each invocation reinvents the wheel because the skill describes the work in prose instead of bundling it.

**Probing questions:**
- Does the agent write basically the same script every time you use this?
- Is there a setup or sequence it redoes from scratch on each run?
- If you watched several runs back to back, what would look identical across all of them?

**Where the fix lives.** `scripts/`. Write the repeated thing once as a real script, drop it in `scripts/`, and have the body point to it ("run `scripts/foo.py` to do X") instead of describing how to rebuild it. This saves every future run the rework and removes a source of inconsistency.

**Worked example.**
Finding: *"Every single time, it writes its own little Python to flatten the JSON before charting — slightly differently each run."*
Edit: extract a `scripts/flatten.py` that does the flattening canonically, and replace the prose instructions with a pointer to run it. One implementation, consistent every time.

---

## 7. Resources & pointers

**Symptom.** Bundled files are out of sync with the body. A reference or asset exists but nothing points to it (so it's never read), or the body references a file that's missing or mis-pathed, or the "read this next" pointers are vague enough that the agent doesn't know when to follow them.

**Probing questions:**
- Does the skill bundle files (references, scripts, templates)? Do they actually get used?
- Has the agent ever seemed to miss a bundled reference it should have read?
- Are there pointers to other files that are unclear about *when* to follow them?

**Where the fix lives.** Reconcile body and resources. Add a clear pointer for an orphaned file, fix a broken path, delete a truly dead resource, or sharpen a vague "see X" into "when you need Y, read X." Progressive disclosure only works if the pointers are good.

**Worked example.**
Finding: *"There's a whole `references/advanced.md` but the agent never opens it."*
Edit: in the body, add an explicit, conditional pointer — "for multi-region setups or custom auth, read `references/advanced.md` before proceeding" — so the agent knows the trigger for loading it.

---

## 8. Output quality

**Symptom.** The skill fires and is followed, but the *output* misses what the user wanted — wrong format, too long or too terse, off in tone, missing a section the user always needs, or including one they never want.

**Probing questions:**
- When the output's right, what does it look like? When it's wrong, what's off — format, length, tone, structure?
- Is there a section you always have to add by hand, or one you always delete?
- Does the format match how you actually use the result downstream?

**Where the fix lives.** The output spec. Tighten it (add the missing structure, pin the format) or loosen it (if a rigid template is forcing bad fits). A concrete output template or a worked input→output example often fixes this faster than more prose.

**Worked example.**
Finding: *"The reports it makes are walls of text — I need a short exec summary up top and I always have to write it myself."*
Edit: add an output template that leads with a 3–4 line executive summary, and show one brief input→output example so the shape is unmistakable.

---

## Putting it together

After probing the relevant dimensions, you should have a list of pain points in the user's own words. Take each back to its dimension to find where the fix lives and what shape it takes, then carry that into Phase 3 of the main workflow (synthesize → prioritize → propose). Lead with the changes that fix the loudest pain, generalize beyond the specific examples that surfaced them, and prefer explaining the *why* over stacking on new rules.
