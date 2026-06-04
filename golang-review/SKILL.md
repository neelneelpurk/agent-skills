---
name: golang-review
description: >-
  Writes and reviews production-grade Go, with deep support for Kubernetes
  controllers and operators (controller-runtime, Kubebuilder, CRDs, reconcilers,
  admission webhooks). Use when writing Go, reviewing Go code, or being asked to
  "review this PR", "check this against the style guide", or work on a
  reconciler, operator, controller, or CRD. Covers errors, concurrency,
  interfaces, logging/observability, testing, project layout, and the
  reconcile-loop/status/finalizer/requeue rules. Do NOT use for non-Go languages.
metadata:
  tags: go, golang, code-review, kubernetes, kubebuilder, controller-runtime, operator, reconciler, crd
  version: 2.0.0
---

# Writing and reviewing production-grade Go

Use this skill whenever you are **writing or reviewing Go**, and especially when the code
touches **Kubernetes** — operators, controllers, custom resources (CRDs), admission
webhooks, or anything scaffolded with **Kubebuilder** / **controller-runtime**.

Two operating modes:

- **Writing** — apply the defaults below as you produce code. Where a genuine tradeoff
  exists (logging library, assertion library, options vs config struct, layout), pick the
  recommended default but stay open to the project's existing choice.
- **Reviewing** — produce a focused, high-signal review. Flag real correctness bugs and
  clear idiom violations; do **not** nitpick what `gofmt`/`golangci-lint` already fix.

## Tone and stance

Two classes of rule, and they are phrased differently on purpose:

- **Kubernetes-controller rules are hard requirements ("must").** They are near-universally
  agreed and safety-critical (idempotent level-based reconcile, `IgnoreNotFound`, status
  subresource + conditions + `observedGeneration`, requeue/backoff semantics, owner refs,
  finalizers, read-from-cache, never block the loop).
- **General Go-style rules are defaults with rationale.** For contested areas, present a
  **Tradeoff:** — both sides plus a recommended default. Mirror Google's framing: clarity >
  simplicity > concision > maintainability > consistency, and "not intended to be absolute."

## Version awareness (check this first)

Before applying version-specific guidance, **read the `go` directive in `go.mod`.**

- **Go 1.22+**: loop variables are per-iteration. The old `x := x` copy idiom inside loops
  is **no longer needed** for goroutine/closure capture. On `< 1.22`, that copy is still
  **required** — flag its absence.
- **Go 1.21+**: `log/slog`, `slices`/`maps`/`cmp`, built-in `min`/`max` are available.
- **Go 1.20+**: `errors.Join`.
- **Go 1.24/1.25**: `testing/synctest` (experimental in 1.24, stable in 1.25) for
  deterministic concurrent/time-based tests.

For controller-runtime specifics (deprecated `Requeue`, metric names, `Metrics` options
struct), confirm against the **imported version**, not memory.

## How to run a review

1. **Identify the surface area** — plain Go, a Kubernetes API type, a controller/reconciler,
   or a webhook. Load the matching `references/` file(s).
2. **Read the diff in context** — open the surrounding functions and the types being mutated.
   Controller bugs (status vs spec, conflict handling, cache coherence) are invisible in an
   isolated hunk.
3. **Check against the rules** below and in `references/REVIEW-CHECKLIST.md`.
4. **Report findings** grouped by severity: **Bug** (will misbehave) → **Risk** (misbehaves
   under load/edge cases) → **Idiom** (works but non-idiomatic) → **Nit** (style). For each:
   cite `file:line`, explain *why*, give a concrete fix.
5. **Close with the "Final PR questions"** from `references/REVIEW-CHECKLIST.md`.

## The non-negotiable baseline

- `gofmt`/`gofumpt` clean; `goimports` with 3 import blocks (stdlib / external / internal).
- `go vet` and `staticcheck` (or `golangci-lint`) pass.
- Tests run with `-race` in CI.
- Go modules for dependency management (default since 1.16); `dep`/`glide` are obsolete.

## The seven highest-leverage rule clusters

These live in the core because they apply to almost every change. Depth and tradeoffs are
in `references/`.

### 1. Errors → `references/ERRORS.md`
- Wrap with `fmt.Errorf("...: %w", err)` to preserve the chain; use `%v` only to
  deliberately break it. `errors.Join` (1.20+) for multiple failures.
- Match with `errors.Is` (sentinel `Err...` vars) / `errors.As` (typed `...Error`).
- **Handle an error once** — do not both log and return the same error.
- **No panics in library code.** Panic only on the truly irrecoverable; `template.Must`-style
  init is the documented exception. `os.Exit`/`log.Fatal*` only in `main()`; `t.Fatal` in tests.

### 2. Interfaces & API → `references/INTERFACES-AND-API.md`
- **Accept interfaces, return structs.** Keep interfaces small; define them at the
  **consumer**, not the producer. Don't create an interface just to have one ("this is Go,
  not Java"). Prefer `any` over `interface{}` (1.18+). Make the zero value useful.

### 3. Concurrency → `references/CONCURRENCY.md`
- `context.Context` is the **first parameter** of any I/O or long-running function; always
  `defer cancel()` after `WithCancel`/`WithTimeout`; respect `ctx.Done()` in loops.
- **Every goroutine has a clear exit/cancellation path** — goroutine leaks are the dominant
  concurrency bug. No unbounded goroutine creation.
- Channels for communication, mutexes for protecting state. Don't copy a `sync.Mutex` by
  value. Use `errgroup` for fallible parallel work.

### 4. Logging & observability → `references/LOGGING-OBSERVABILITY.md`
- Structured logging always: `slog` in general Go, `logr` (`log.FromContext(ctx)`) in
  controllers. No `fmt.Println`/`log.Printf` outside `main`/CLI.
- Non-library packages get an **injected** logger; they don't reach for a global.

### 5. Testing → `references/TESTING.md`
- Table-driven tests with subtests (`t.Run`), run with `-race`, `t.Parallel()` where safe.
- Coverage is a signal, not a target. Fuzz parsers/validators/untrusted input.

### 6. Project layout → `references/PROJECT-LAYOUT.md`
- Start flat (`main.go` + `go.mod`). Add `cmd/` for multiple binaries, `internal/` when you
  need enforced privacy. `internal/` is the only compiler-enforced rule. Don't cargo-cult
  `pkg/`. Match the existing repo's convention over imposing a new one.

### 7. Kubernetes controllers → `references/CONTROLLERS.md` (largest reference)
These are **must** rules:
- Reconcile to **desired state**: level-based, **not** edge/event-keyed. **Idempotent** —
  same input, same result; check existence before create, compare before update.
- Fetch first and handle NotFound: `client.IgnoreNotFound(err)`, return `nil` on NotFound.
- **One controller per Kind.** Don't store reconcile state in memory. **Never block the loop.**
- **Requeue/backoff:** returning an **error** or bare **`Requeue: true`** triggers
  rate-limited exponential backoff; **`RequeueAfter` does not**. Use `RequeueAfter` for
  expected "not ready yet" states; reserve errors for genuine failures. `TerminalError`
  skips requeuing.
- **Status vs spec:** status subresource (`r.Status().Update`), `[]metav1.Condition` via
  `meta.SetStatusCondition`, and set `observedGeneration` so GitOps tools see stale status.
- **Owner refs** (`SetControllerReference`) for GC + owner re-reconcile; **finalizers** for
  cleanup (remove via `r.Update`, not Status).
- Reads come from the **cache** (no read-after-write guarantee); use `retry.RetryOnConflict`
  for update conflicts. Expose metrics and emit Events.

## Reference map — load only what the task needs

| File | Read when… |
|------|-----------|
| `references/ERRORS.md` | any Go code touches error handling |
| `references/CONCURRENCY.md` | goroutines, channels, context, sync, graceful shutdown |
| `references/INTERFACES-AND-API.md` | designing types, interfaces, constructors, options |
| `references/LOGGING-OBSERVABILITY.md` | logging, metrics, tracing |
| `references/TESTING.md` | tests, benchmarks, fuzzing, envtest vs fake client |
| `references/PROJECT-LAYOUT.md` | package/module structure decisions |
| `references/CONTROLLERS.md` | **any** Kubernetes controller/operator/CRD/webhook code |
| `references/REVIEW-CHECKLIST.md` | running a review (both Go + controller red-flag lists) |
| `references/IDIOMS.md` | need a copy-pasteable canonical skeleton |

Start here; open only the specific reference files needed for the current task.
