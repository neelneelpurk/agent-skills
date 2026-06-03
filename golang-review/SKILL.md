---
name: golang-review
description: Reviews Go code for correctness, idioms, and Kubernetes/controller-runtime correctness. Use when reviewing or writing Go, especially Kubernetes operators, controllers, CRDs, and Kubebuilder projects.
metadata:
  tags: go, golang, code-review, kubernetes, kubebuilder, controller-runtime, operator
---

## When to use

Use this skill whenever you are **reviewing or writing Go code**, and especially when the
code touches **Kubernetes** — operators, controllers, custom resources (CRDs), admission
webhooks, or any project scaffolded with **Kubebuilder** / **controller-runtime**.

The goal is a focused, high-signal review: flag real correctness bugs and clear idiom
violations, not stylistic nitpicks that `gofmt`/`golangci-lint` already handle.

## How to run a review

1. **Identify the surface area.** Determine whether the change is plain Go, a Kubernetes
   API type, a controller/reconciler, or a webhook. Load the matching reference file(s)
   from `references/` for the relevant rules.
2. **Read the diff in context.** Open the surrounding functions and the types being
   mutated — Kubernetes bugs (status vs. spec, conflict handling) are invisible in an
   isolated hunk.
3. **Check against the reference rules** below and in `references/`.
4. **Report findings** grouped by severity: **Bug** (will misbehave), **Risk** (likely to
   misbehave under load/edge cases), **Idiom** (works but non-idiomatic), **Nit** (style).
   For each, cite `file:line`, explain *why*, and give a concrete fix.

## Reference material

Pull in the file that matches what you're reviewing:

- **`references/go-best-practices.md`** — Effective Go idioms: error handling and wrapping,
  context propagation, concurrency/goroutine lifecycle, interfaces, slices/maps gotchas,
  naming, testing. Use for any Go code.
- **`references/kubernetes-api-spec.md`** — Kubernetes API conventions: spec vs. status,
  ObjectMeta, optional/required fields, defaulting, validation, list/label/selector
  semantics, status conditions, resource versioning and optimistic concurrency. Use when
  the change defines or consumes API types.
- **`references/kubebuilder-best-practices.md`** — Kubebuilder & controller-runtime:
  reconciler design (idempotency, level-triggered logic), client cache vs. live reads,
  owner references and garbage collection, finalizers, status updates and conflicts,
  requeue/error semantics, RBAC markers, webhooks, manager/leader-election setup. Use for
  controllers and operators.

## Top review rules (quick reference)

These are the highest-frequency, highest-impact issues. The reference files expand each.

### General Go
- **Errors are values, not exceptions.** Every returned `error` must be checked. Wrap with
  `fmt.Errorf("...: %w", err)` to preserve the chain; check with `errors.Is`/`errors.As`,
  never string matching.
- **`context.Context` is the first argument** and must be propagated, never stored in a
  struct, never `context.Background()` deep in a call tree.
- **Goroutines need a defined lifecycle** — a way to stop (context/channel) and, where the
  caller waits, a `sync.WaitGroup` or `errgroup`. A goroutine with no exit path is a leak.
- **Loop-variable capture & append aliasing.** Be wary of capturing loop variables in
  closures/goroutines (pre-Go 1.22) and of `append` mutating a shared backing array.
- **`defer` in loops** accumulates until function return — close inside the loop instead.

### Kubernetes / controllers
- **Spec is desired state (user-owned); status is observed state (controller-owned).** A
  controller must not mutate `spec`; status changes go through the **status subresource**
  (`Status().Update`/`Status().Patch`), not a plain `Update`.
- **Reconcile must be idempotent and level-triggered.** Never assume you see every event or
  the order of events. Compute desired state from the current world each call; use
  `CreateOrUpdate`/server-side apply rather than blind creates.
- **Handle `Conflict` (409) and `NotFound` (404) explicitly.** Use `apierrors.IsNotFound`,
  `apierrors.IsConflict`; on conflict, return the error to requeue rather than forcing.
- **Return values drive requeueing.** Returning an error requeues with backoff; returning
  `ctrl.Result{}` with no error stops. Don't `time.Sleep` inside Reconcile — use
  `RequeueAfter`.
- **Reads come from a cache.** The controller-runtime client is cache-backed and may be
  stale; design for it. Don't `List` without a selector/namespace when you can avoid it.
- **Finalizers** must be added before external resources are created and removed only after
  cleanup succeeds — and cleanup must tolerate the resource already being gone.
- **Set owner references** for garbage collection unless you intentionally manage lifecycle
  yourself.

Always defer to the reference files for the full rationale and edge cases before writing a
finding.
