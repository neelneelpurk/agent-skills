---
name: keep-me-in-the-loop
description: Keeps the user in the loop by writing timestamped Markdown progress check-ins to a `.loop/` directory. Use automatically right after a critical implementation decision, a large/massive code change, adding a new test (TDD red), or tests turning green (TDD pass) — and on a recurring timer (default 5 minutes, customizable). Each entry records where the work has reached, what is done, and the critical decisions made with their rationale.
when_to_use: Invoke after critical implementation/architecture decisions, large refactors or multi-file changes, when a new test is added, when a previously failing test passes, and on each timer tick when run under /loop. Also invoke directly with /keep-me-in-the-loop to write a check-in now.
allowed-tools: Write, Edit, Read, Bash(bash *), Bash(date *), Bash(mkdir *), Bash(ls *), Bash(cat *)
argument-hint: "[interval e.g. 5m | trigger label]"
---

# Keep me in the loop

Maintain a running, append-only journal so the user can step away and still know exactly
where the work stands. Every check-in is one timestamped Markdown file under `.loop/`.

The journal is driven by **two things**:

1. **Events** — write a check-in immediately after any trigger fires (see
   [references/triggers.md](references/triggers.md)).
2. **A timer** — write a check-in on a fixed cadence, **default every 5 minutes**,
   customizable.

## Triggers (write an entry when any of these happen)

Invoke this skill and write one entry right after:

- **Critical implementation / architecture decision** — a choice that's hard to reverse or
  shapes later work (data model, API shape, library/framework, concurrency model, schema).
- **Massive code change** — a large refactor, a multi-file change, a new module/package, or
  a sweeping rename/migration.
- **TDD: a test added** — a new failing test written before the implementation (red step).
- **TDD: tests pass** — a previously failing test (or suite) now goes green.

Full definitions and edge cases are in [references/triggers.md](references/triggers.md). When in
doubt, write the entry — a missed check-in is worse than an extra one.

## Cadence (the timer)

The timer is delivered by the bundled `/loop` skill, which re-invokes this skill on an
interval. The user controls the interval; **default is 5 minutes**.

- **Start the timed loop (default 5 min):**
  ```
  /loop 5m /keep-me-in-the-loop
  ```
- **Custom interval** (any value `/loop` accepts, e.g. 2m, 10m, 30m):
  ```
  /loop 10m /keep-me-in-the-loop
  ```
- **Stop** the timed loop the same way you stop any `/loop`.

If this skill is invoked with an interval argument (e.g. `/keep-me-in-the-loop 10m`) and no
loop is currently running, tell the user the exact `/loop <interval> /keep-me-in-the-loop`
command to arm the timer, then write a check-in now. Treat a bare number as minutes.

Event-triggered check-ins happen **in addition to** the timer — don't wait for the next tick
to record something important.

## Workflow (every check-in)

Copy this checklist and work through it each time:

```
Check-in:
- [ ] 1. Determine the trigger (timer tick, decision, big-change, test-added, test-pass)
- [ ] 2. Read the previous entry to know what was already reported
- [ ] 3. Create the new entry file (run the script)
- [ ] 4. Fill every section honestly (reached / done / decisions / tests / next)
- [ ] 5. Confirm to the user in one line, with the file path
```

**Step 1 — Trigger.** Pick the label: `timer`, `decision`, `big-change`, `test-added`,
`test-pass`, or `manual`.

**Step 2 — Read the last entry.** So the new one is a *delta*, not a repeat:
```bash
ls -t .loop/*.md 2>/dev/null | head -1   # newest entry, if any
```

**Step 3 — Create the file.** The script generates the correct `.loop/<date-time>.md` path,
scaffolds the sections, and updates the index. Run it from the project root:
```bash
bash "${CLAUDE_SKILL_DIR}/scripts/loop-entry.sh" <trigger>
```
It prints the path of the file it created. Open that file and fill it in (do **not**
hand-format timestamps — let the script own naming).

**Step 4 — Fill it in.** Use the section guide in
[references/entry-template.md](references/entry-template.md). Every entry must answer:
- **Where I've reached** — the current phase / overall progress.
- **What's done since last check-in** — concrete, verifiable items (not "made progress").
- **Critical decisions** — for each: the decision, *why*, alternatives considered, tradeoffs.
  On a `decision` trigger this is the heart of the entry; on a `timer` tick it may be "none
  since last check-in."
- **Test status** — TDD state: tests added, passing, failing, and what they cover.
- **Next steps** — what happens next, so the user can redirect before it does.

Keep entries short and skimmable — bullets over prose. The point is to keep the user
informed, not to write an essay.

**Step 5 — Confirm.** One line back to the user, e.g.
`Logged check-in → .loop/2026-06-03_14-22-09.md (trigger: decision)`.

## Where entries live

```
.loop/
├── INDEX.md                       # newest-first list of all check-ins (maintained by the script)
├── 2026-06-03_14-05-11.md         # one file per check-in
├── 2026-06-03_14-10-27.md
└── ...
```

Filenames are `YYYY-MM-DD_HH-MM-SS.md` so they sort chronologically. Never overwrite an
existing entry — the journal is append-only history.

## Notes

- If `.loop/` is committed to git, the journal becomes a shared, reviewable history. If it
  should stay local, add `.loop/` to `.gitignore` (ask the user once).
- This skill only records state; it never changes the cadence on its own. The user owns the
  interval via `/loop`.

## References

- [references/triggers.md](references/triggers.md) — precise definitions of each trigger and
  examples of what does / doesn't qualify.
- [references/entry-template.md](references/entry-template.md) — the canonical entry format
  and what to put in each section.
