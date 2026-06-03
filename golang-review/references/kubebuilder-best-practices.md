# Kubebuilder & controller-runtime Best Practices (review reference)

For reviewing operators/controllers scaffolded with [Kubebuilder](https://book.kubebuilder.io/)
and built on `sigs.k8s.io/controller-runtime`. Pair with `kubernetes-api-spec.md` for the
API-type rules.

## Reconciler design

- **Idempotent and level-triggered.** `Reconcile` may be called any number of times for the
  same object, in any order, with stale caches. Each call must compute desired state from the
  *current* observed world and converge — never rely on having seen a specific prior event.
- **Start by fetching the object; handle NotFound as success:**
  ```go
  if err := r.Get(ctx, req.NamespacedName, &obj); err != nil {
      return ctrl.Result{}, client.IgnoreNotFound(err)
  }
  ```
  A `NotFound` means the object was deleted and (with owner refs) children are being GC'd;
  there's nothing to do.
- **No side effects in `Reconcile` that you can't re-do safely** — it will run again.
- **Don't block.** Never `time.Sleep` to wait; return `ctrl.Result{RequeueAfter: d}`. Keep
  reconciles short; offload nothing to unmanaged goroutines.

## Return values & requeueing

- **`return ctrl.Result{}, err`** — controller-runtime logs and requeues with exponential
  backoff. Use for transient failures (including `Conflict`).
- **`return ctrl.Result{}, nil`** — done; no requeue (until the next watch event).
- **`return ctrl.Result{RequeueAfter: d}, nil`** — re-run after `d` (periodic resync / waiting
  on external state).
- **Don't both return an error and set `RequeueAfter`** — the error path already requeues;
  setting both is redundant/confusing.
- **Don't return an error for expected conditions** (e.g. "dependency not ready yet") if it
  spams logs — prefer `RequeueAfter` with a clear status condition instead.

## Client, cache, and reads

- **Reads go through the manager's cache** (informers), so they can be **stale**. Design
  reconciliation to tolerate reading a slightly old object; the next event corrects it.
- **The cache only holds watched types.** Reading an unwatched/uncached type, or doing an
  unindexed field lookup, may error or fall back to the API server — set up field indexers
  (`mgr.GetFieldIndexer().IndexField`) for `List` filters you rely on.
- **Writes go straight to the API server** and won't be reflected in the cache until the watch
  catches up — don't read-after-write expecting your change.
- **Use `client.ObjectKey`/`req.NamespacedName`**; scope `List` calls with
  `client.InNamespace(...)` and `client.MatchingLabels{...}` rather than listing the world.

## Creating/updating owned resources

- **Prefer `controllerutil.CreateOrUpdate` / `CreateOrPatch`,** or **server-side apply**
  (`client.Apply`), over blind `Create` (which 409s on the second reconcile). With
  `CreateOrUpdate`, mutate the object **inside the mutate func** and make it idempotent —
  only set fields you own, or you'll fight other writers in an infinite update loop.
- **Set owner references** with `controllerutil.SetControllerReference(owner, child, scheme)`
  so children are garbage-collected when the owner is deleted, and so the controller's
  `Owns(&Child{})` watch maps child events back to the owner.
- **Watch what you own and what you depend on:**
  ```go
  ctrl.NewControllerManagedBy(mgr).
      For(&v1.MyApp{}).
      Owns(&appsv1.Deployment{}).
      Watches(&v1.Dependency{}, handler.EnqueueRequestsFromMapFunc(r.mapToOwner)).
      Complete(r)
  ```

## Status updates

- **Update status via the status subresource:** `r.Status().Update(ctx, &obj)` or
  `r.Status().Patch(...)`. A plain `r.Update` won't persist status (and vice versa).
- **Only write status when it changed** — compare against what you read to avoid write
  amplification and needless `resourceVersion` churn (which re-triggers reconciles).
- **Expect `Conflict` on status updates** under churn; return the error to requeue, or use a
  patch. Use `RetryOnConflict` sparingly for tight read-modify-write loops.
- **Record `observedGeneration`** so users can tell whether the controller has caught up to
  the latest spec. Manage conditions with `meta.SetStatusCondition`.

## Finalizers

- **Add the finalizer before creating external resources** (cloud infra, external DB, etc.),
  so deletion is intercepted:
  ```go
  if obj.DeletionTimestamp.IsZero() {
      if !controllerutil.ContainsFinalizer(&obj, myFinalizer) {
          controllerutil.AddFinalizer(&obj, myFinalizer)
          // update, return, requeue
      }
  } else {
      // being deleted: clean up, then RemoveFinalizer + update
  }
  ```
- **Cleanup must be idempotent and tolerate "already gone"** — deletion can be retried.
- **Remove the finalizer only after cleanup succeeds.** If you can't reach the external system,
  return an error/requeue and leave the finalizer in place; don't strand resources.
- **Don't add finalizers you never remove** — that wedges deletion forever.

## RBAC, scheme, and markers

- **Keep `// +kubebuilder:rbac` markers in sync** with what the controller actually does.
  Every verb on every resource the reconciler touches must be granted, or it fails at runtime
  with `Forbidden`. Regenerate (`make manifests`) after changes.
- **Grant least privilege** — don't `*` resources/verbs out of convenience.
- **Register every type the manager touches in the scheme** (`utilruntime.Must(AddToScheme)`),
  or client calls fail with "no kind is registered."

## Webhooks & validation

- **Validation webhooks must be deterministic and side-effect-free** (or declare side effects).
  They run on every write; keep them fast.
- **Defaulting webhooks set defaults only**; don't reject in a mutating webhook.
- **Prefer CRD schema validation** (`+kubebuilder:validation:...` markers — `Required`,
  `Enum`, `Minimum`, `MaxLength`, `Pattern`, etc.) over webhook code when the rule is
  expressible declaratively; it's cheaper and can't be bypassed.
- Webhooks need a serving cert and the API server must reach the service — review failurePolicy
  (`Fail` vs `Ignore`) for the blast radius if the webhook is down.

## Manager & startup

- **Enable leader election** for HA so only one replica reconciles
  (`LeaderElection: true`); otherwise multiple replicas fight.
- **Set up health/readiness probes** (`AddHealthzCheck`/`AddReadyzCheck`).
- **Bound concurrency** with `MaxConcurrentReconciles` when throughput matters, but remember
  the same object is never reconciled concurrently (work-queue dedup per key).
- **Tune resync period** intentionally — a low `SyncPeriod` causes mass re-reconciles.

## Common review red flags

- Mutating `spec` from the controller.
- `Create` without handling `AlreadyExists`, or `Update` without handling `Conflict`.
- Reading the object back immediately after writing and trusting the cache.
- `time.Sleep` inside `Reconcile`.
- Unbounded `List` with no namespace/label scope.
- Status written via `r.Update` instead of `r.Status().Update`.
- Finalizer added but cleanup path can leave it on forever (no error handling), or removed
  before cleanup.
- RBAC markers not matching the client calls.
- Goroutines launched from `Reconcile` outside the manager's lifecycle.
- Logging an error *and* returning it (double reporting through controller-runtime).
