# Entry template and section guide

Each check-in is one file at `.loop/<YYYY-MM-DD_HH-MM-SS>.md`, created by
`scripts/loop-entry.sh`. The script writes the scaffold below; fill in every section. Keep it
skimmable — bullets over paragraphs. The reader is someone catching up on the work, fast.

## The scaffold

```markdown
---
timestamp: 2026-06-03T14:22:09-0700
trigger: decision
---

# Check-in — 2026-06-03_14-22-09

**Trigger:** decision

## Where I've reached
## What's done since last check-in
## Critical decisions
## Test status
## Next steps
```

## What each section must contain

### Where I've reached
The current phase and overall progress in one or two lines. Orient the reader: what part of
the task is active right now, and roughly how far along the whole effort is.
> e.g. "Building the auth layer — token issuance done, validation middleware in progress.
> ~60% through the auth milestone."

### What's done since last check-in
Concrete, verifiable items completed **since the previous entry** — a delta, not a cumulative
list. Prefer specifics over "made progress."
> e.g. "- Added `POST /login` returning a signed JWT. - Wired the user repository to Postgres.
> - Deleted the legacy session cookie path."

### Critical decisions
The most important section. For **each** decision:
- **Decision** — what was chosen.
- **Why** — the reasoning.
- **Alternatives considered** — what was rejected.
- **Tradeoffs** — what this costs or risks.

If nothing was decided this interval, write `None since last check-in.` On a `decision`
trigger, this section is the reason the entry exists — be thorough here.
> e.g. "**Decision:** JWT access tokens, no server-side session store. **Why:** stateless
> horizontal scaling. **Alternatives:** server sessions in Redis (rejected: extra infra),
> opaque tokens (rejected: needs introspection endpoint). **Tradeoffs:** revocation is harder;
> mitigated with short 15-min expiry + refresh tokens."

### Test status
The TDD state:
- Tests **added** (and what behavior they pin down) — the red step.
- Tests now **passing** — the green step.
- Tests **failing** and why.
- Coverage or gaps worth noting.
> e.g. "- Added `TestLogin_RejectsBadPassword` (red). - `TestLogin_IssuesToken` now green. -
> Refresh-token flow still untested."

### Next steps
What happens next, concrete enough that the user can redirect before it happens.
> e.g. "- Implement refresh-token rotation. - Add rate limiting to `/login`. - Then write the
> integration test for the full login→refresh cycle."

## Style
- Bullets, short lines, present/past tense facts — not narration.
- Be honest: if tests fail or a step was skipped, say so plainly.
- Don't repeat unchanged context from earlier entries; link by referring to the prior
  timestamp if needed.
