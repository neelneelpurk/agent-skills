# Kubernetes controllers & operators

The rules here are **hard requirements ("must")** — they are tightly converged across the
ecosystem and safety-critical. Sources: the [Kubebuilder book](https://book.kubebuilder.io/)
("Good Practices"), [controller-runtime godoc](https://pkg.go.dev/sigs.k8s.io/controller-runtime),
[kubernetes/community API conventions](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md).

> **Version caveat.** controller-runtime evolves. Bare `Requeue` is deprecated;
> `MetricsBindAddress` moved into a `Metrics` options struct; rate-limiter constants and
> metric names have shifted. Confirm against the **imported version**, not memory.

## 1. Reconciliation model — level-based, idempotent

- Reconcile to **desired state**. The loop is **level-based, not edge-based** — act on the
  *current observed state*, never on "which event fired." Keying logic to specific event
  types breaks the operator pattern and can leave resources stuck.
- **Idempotency is mandatory.** Running `Reconcile` repeatedly with the same cluster state
  must converge to the same result. **Check existence before create, compare before update**,
  never assume event ordering or that you see every event.
- **One controller per Kind** (Kubebuilder's "Golden Rule"). No `install_all_controller.go` —
  it kills scalability, error isolation, and concurrency safety.
- **Don't store reconcile state in memory** across invocations — "no guarantees are made
  about parallel access… if you need it, write it into a Kubernetes object." Use status.
- **Never block the reconcile loop** (no long sleeps, no synchronous waits). Break work into
  small idempotent subroutines; use `RequeueAfter` to poll.

### Skeleton

```go
func (r *WidgetReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    log := log.FromContext(ctx)

    var widget appv1.Widget
    if err := r.Get(ctx, req.NamespacedName, &widget); err != nil {
        // Object may have been deleted between enqueue and reconcile.
        return ctrl.Result{}, client.IgnoreNotFound(err)
    }

    // --- Finalizer / deletion handling ---
    if !widget.DeletionTimestamp.IsZero() {
        if controllerutil.ContainsFinalizer(&widget, widgetFinalizer) {
            if err := r.cleanupExternal(ctx, &widget); err != nil {
                return ctrl.Result{}, err // retry cleanup
            }
            controllerutil.RemoveFinalizer(&widget, widgetFinalizer)
            if err := r.Update(ctx, &widget); err != nil { // Update, not Status
                return ctrl.Result{}, err
            }
        }
        return ctrl.Result{}, nil
    }
    if controllerutil.AddFinalizer(&widget, widgetFinalizer) {
        if err := r.Update(ctx, &widget); err != nil {
            return ctrl.Result{}, err
        }
    }

    // --- Reconcile owned resources (idempotent apply) ---
    deploy := desiredDeployment(&widget)
    if err := controllerutil.SetControllerReference(&widget, deploy, r.Scheme); err != nil {
        return ctrl.Result{}, err
    }
    op, err := controllerutil.CreateOrUpdate(ctx, r.Client, deploy, func() error {
        deploy.Spec.Replicas = widget.Spec.Replicas
        // set immutable fields (e.g. Selector) only on create:
        if deploy.CreationTimestamp.IsZero() {
            deploy.Spec.Selector = desiredSelector(&widget)
        }
        return nil
    })
    if err != nil {
        return ctrl.Result{}, err
    }
    _ = op

    // --- Status (subresource) + conditions + observedGeneration ---
    meta.SetStatusCondition(&widget.Status.Conditions, metav1.Condition{
        Type:               "Ready",
        Status:             metav1.ConditionTrue,
        Reason:             "Reconciled",
        Message:            "All resources are in the desired state",
        ObservedGeneration: widget.Generation,
    })
    widget.Status.ObservedGeneration = widget.Generation
    if err := r.Status().Update(ctx, &widget); err != nil {
        return ctrl.Result{}, err
    }

    // Expected "not ready yet" → RequeueAfter (NOT an error, NOT bare Requeue):
    if !ready {
        return ctrl.Result{RequeueAfter: 30 * time.Second}, nil
    }
    return ctrl.Result{}, nil
}
```

## 2. NotFound handling

Always fetch first, and return `client.IgnoreNotFound(err)` so a delete between enqueue and
reconcile doesn't cause an error/backoff. Returning `nil` on NotFound is **critical**.

## 3. Requeue / backoff semantics (subtle, high-value)

controller-runtime applies the **workqueue rate limiter (exponential backoff)** when
`Reconcile`:

- returns a **non-nil error**, or
- returns bare **`Requeue: true`** (deprecated — prefer `RequeueAfter`).

It does **NOT** rate-limit **`RequeueAfter: d`**. Watch events and `RequeueAfter` polls
bypass the limiter.

The default limiter (`DefaultControllerRateLimiter`) is:

```go
NewMaxOfRateLimiter(
    NewItemExponentialFailureRateLimiter(5*time.Millisecond, 1000*time.Second),
    &BucketRateLimiter{Limiter: rate.NewLimiter(rate.Limit(10), 100)}, // 10 qps, 100 burst
)
```

→ per-item delay grows exponentially from 5ms to ~16 min until the object reconciles
successfully, combined with an overall token bucket.

**How to choose:**
- **Expected, transient "not ready yet"** (waiting on a Deployment to roll out) →
  `RequeueAfter` with a sensible interval. Not an error.
- **Genuine transient failure** (API blip) → return the error; let backoff handle it.
- **Permanent / un-retryable** (bad spec that will never succeed) → wrap in
  `reconcile.TerminalError(err)` so it is **not** requeued (surface via status/condition +
  Event instead).

**Pitfall:** controllers that stabilize via `RequeueAfter` never call `Forget`, so on objects
that *also* error intermittently the failure count can build and inflate backoff. Design
backoff deliberately; don't return errors for normal steady-state polling.

## 4. Status vs spec + conditions

- Enable the status subresource: `//+kubebuilder:subresource:status`. Update status via
  `r.Status().Update(ctx, obj)` — **never** the normal client (which would clobber spec and
  not go through the status endpoint).
- Use `[]metav1.Condition` with `meta.SetStatusCondition` / `meta.FindStatusCondition` /
  `meta.IsStatusConditionTrue`. Standard types: `Ready`, `Progressing`, `Available`,
  `Degraded`. Each carries `Type`, `Status` (True/False/Unknown), `Reason`, `Message`,
  `LastTransitionTime`, `ObservedGeneration`.
- **Set `status.observedGeneration = metadata.generation`** (and per-condition
  `ObservedGeneration`) so GitOps tools (Argo CD, Flux) know whether status reflects the
  latest spec. If `observedGeneration < metadata.generation`, the status is stale.

## 5. Finalizers, owner refs, GC

- `controllerutil.AddFinalizer` / `RemoveFinalizer`. On deletion (`DeletionTimestamp` set),
  run cleanup, **then** remove the finalizer. Persist finalizer changes with `r.Update`
  (**not** `Status`). A finalizer never removed = stuck deletion.
- `controllerutil.SetControllerReference(owner, controlled, scheme)` — sets the controller
  owner ref, used for **GC** of the controlled object and to **re-reconcile the owner** on
  child changes (with a `Watch` + `EnqueueRequestForOwner`). Only one controller owner is
  allowed (else `AlreadyOwnedError`).
- Owner refs are **same-namespace only**, and don't work for cluster-scoped → namespaced
  ownership. For cross-namespace/cluster-scoped deps, use **labels** + a mapping watch.
- `controllerutil.CreateOrUpdate` / `CreateOrPatch` with a `MutateFn` implement apply-like
  reconcile. Set **immutable fields only on create** (`obj.CreationTimestamp.IsZero()`).

## 6. Watches / predicates / caching

- Builder: `For(&Owner{})`, `Owns(&Child{})` (triggers on owned objects with a controller
  owner ref), `Watches(...)` with `handler.EnqueueRequestForOwner` or
  `handler.EnqueueRequestsFromMapFunc` for arbitrary mappings. Filter with predicates (e.g.
  `predicate.GenerationChangedPredicate{}` to ignore status-only updates).
- **Reads go through the manager cache** (informers/listers) to spare the API server; writes
  go direct. The split client does **not** guarantee read-after-write coherence — "code
  should not assume a get immediately following a create/update returns the updated
  resource." Don't build logic that depends on it.
- Use `FieldIndexer` (`mgr.GetFieldIndexer().IndexField(...)`) for indexed lookups instead of
  listing-and-filtering in memory.
- `MaxConcurrentReconciles` (default 1) controls parallelism **across different objects**;
  the same key is never reconciled concurrently.

## 7. Optimistic concurrency

Updates can fail with "the object has been modified" (resourceVersion conflict). Wrap
status/spec updates in `retry.RetryOnConflict`, **re-Getting** the latest object inside the
closure:

```go
err := retry.RetryOnConflict(retry.DefaultRetry, func() error {
    var latest appv1.Widget
    if err := r.Get(ctx, req.NamespacedName, &latest); err != nil {
        return err
    }
    latest.Status.ObservedGeneration = latest.Generation
    meta.SetStatusCondition(&latest.Status.Conditions, cond)
    return r.Status().Update(ctx, &latest)
})
```

## 8. Manager setup / leader election / probes / shutdown

```go
mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
    Scheme:                 scheme,
    Metrics:                metricsserver.Options{BindAddress: ":8080"},
    HealthProbeBindAddress: ":8081",
    LeaderElection:         true,
    LeaderElectionID:       "widget-operator.example.com",
})
// ...
_ = mgr.AddHealthzCheck("healthz", healthz.Ping)
_ = mgr.AddReadyzCheck("readyz", healthz.Ping)
if err := mgr.Start(ctrl.SetupSignalHandler()); err != nil { // wires SIGTERM/SIGINT
    os.Exit(1)
}
```

- Leader election defaults: LeaseDuration 15s, RenewDeadline 10s, RetryPeriod 2s.
- `ctrl.SetupSignalHandler()` gives graceful shutdown of all runnables with a timeout.
- Health/HTTP servers start before the cache is populated. (Edge case: leader-for-life vs
  probe interaction can deadlock on rollout — be aware.)

## 9. Observability

See `LOGGING-OBSERVABILITY.md` for `logr` conventions, auto-exposed reconcile metrics, custom
metric registration, and Events.

## Controller review red flags

- Edge/event-driven logic instead of level-based reconcile.
- Non-idempotent create-without-check; assuming event ordering.
- Missing `client.IgnoreNotFound` (or not returning `nil` on NotFound).
- Blocking/slow reconcile (sleeps, synchronous waits).
- Returning an **error** for an expected "not ready" state → backoff storms (use
  `RequeueAfter`); or never resetting backoff.
- Permanent failures retried forever instead of `TerminalError` + status.
- In-memory state carried across reconciles.
- Missing owner references; finalizer added but never removed (stuck deletion).
- Status written via the normal client instead of `r.Status()`.
- Missing `observedGeneration` (status appears current when it's stale).
- Logic that assumes read-after-write cache coherence.
- One controller reconciling many Kinds.
- No metrics / no Events for important transitions.
- Goroutines spawned in `Reconcile`/manager without a cancellation path (leaks).
- Immutable fields (Selector) set on update, not just create.
