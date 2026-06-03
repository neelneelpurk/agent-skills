# Trigger definitions

When any trigger below fires, invoke `keep-me-in-the-loop` and write one check-in entry. Pick
the matching trigger label for the script argument. When unsure whether something qualifies,
write the entry — a missed check-in costs more than an extra one.

## Contents
- `timer` — recurring tick
- `decision` — critical implementation / architecture decision
- `big-change` — massive code change
- `test-added` — new test written (TDD red)
- `test-pass` — failing test goes green (TDD pass)
- `manual` — explicit user request

## `timer` — recurring tick
Fired by the `/loop` skill on the configured interval (default 5 minutes). Always write an
entry, even if little changed — "no change since last check-in, still working on X" is itself
useful signal. This is the heartbeat that proves work is progressing.

## `decision` — critical implementation / architecture decision
A choice that is **hard to reverse** or that **shapes downstream work**. Examples that qualify:
- Choosing a data model, schema, or API/interface shape.
- Selecting a library, framework, protocol, or external service.
- Picking a concurrency model, error-handling strategy, or transaction boundary.
- Defining a public contract other code will depend on.
- A security/auth approach, a migration strategy, or a backwards-compatibility decision.

Does **not** qualify: routine, local choices with no ripple effect (a variable name, a small
helper's internal structure). The test: *would the user want a say, or want to know, before
this becomes load-bearing?* If yes, log it — and record the alternatives you rejected and why.

## `big-change` — massive code change
A change large or sweeping enough that the user should know it happened:
- A multi-file refactor or a cross-cutting rename.
- A new module, package, or service.
- Deleting or replacing a significant chunk of existing code.
- A dependency upgrade or migration touching many call sites.
- Generated/scaffolded code that adds substantial surface area.

Rough heuristic: many files touched, a whole subsystem moved, or behavior changed broadly.
A one-line fix is not a big change.

## `test-added` — new test written (TDD red)
A new test (or test file) is added, especially the failing test written **before** the
implementation in a red-green-refactor cycle. Record what behavior the test pins down and that
it is currently red. Capturing the red step documents intent before code exists.

## `test-pass` — failing test goes green (TDD pass)
A previously failing test or suite now passes. This is the "green" milestone — record which
tests passed and what implementation made them pass. If a refactor follows while staying green,
that can be a `big-change` entry.

## `manual` — explicit user request
The user invoked `/keep-me-in-the-loop` directly, or asked for a status update. Write a full
check-in reflecting the current state.

## Avoiding noise
- Don't fire `decision` for trivial local choices, or `big-change` for small edits.
- Batch tightly-coupled events: if one action is simultaneously a big change *and* a decision,
  write a single entry and note both aspects rather than two near-identical files.
- Each entry should be a **delta** from the previous one — read the last entry first.
