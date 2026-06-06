# Agent skills

A small collection of [Claude Code Agent Skills](https://code.claude.com/docs/en/skills).
Each skill is a folder with a `SKILL.md` (plus optional `references/` and `scripts/`),
following the [Agent Skills](https://agentskills.io) open standard and progressive
disclosure: only the `name` + `description` load up front; the body loads when the skill
triggers; `references/` load on demand.

## The skills

| Skill | What it does |
|-------|--------------|
| [`capture-learning`](capture-learning/) | Logs a mistake the moment it happens to `.claude/learnings/` so the lesson isn't lost. Fires proactively, not only on request. |
| [`update-skills-from-learnings`](update-skills-from-learnings/) | Reads accumulated `.claude/learnings/` files and folds each lesson back into the relevant skill(s) as approved diffs. |
| [`agent-skill-retro`](agent-skill-retro/) | Runs a structured retrospective on one existing skill (triggering, adherence, coverage, freshness, bloat) and applies the agreed fixes. |
| [`keep-me-in-the-loop`](keep-me-in-the-loop/) | Writes timestamped progress check-ins to `.loop/` on key events and on a `/loop` timer, so the user can step away and stay oriented. |
| [`golang-review`](golang-review/) | Writes and reviews production-grade Go, with a deep focus on Kubernetes controllers/operators (controller-runtime, Kubebuilder, CRDs). |

## How they fit together

Three of these form a **self-improvement loop**:

```
mistake happens ─▶ capture-learning ─▶ .claude/learnings/*.md
                                              │
                       update-skills-from-learnings  ─▶ edits the relevant SKILL.md
                                              │
                          (the skill is now permanently better)

agent-skill-retro ─▶ interactive deep-dive + fixes on a single skill
```

- Reach for **`update-skills-from-learnings`** when the input is a pile of captured mistakes
  to fold across many skills at once.
- Reach for **`agent-skill-retro`** when you want to sit with *one* skill and work through
  how it's been behaving.

The other two stand alone: **`keep-me-in-the-loop`** is a progress journal, and
**`golang-review`** is a domain reviewer/writer.

## Installing

Copy (or symlink) a skill folder into a skills directory:

- **Personal** (all projects): `~/.claude/skills/<name>/`
- **Project** (this repo only): `<repo>/.claude/skills/<name>/`

A skill is then available automatically when its `description` matches the task, or
directly via `/<name>`.
