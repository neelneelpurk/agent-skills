# Logging & observability

Sources: Go blog [Structured Logging with slog](https://go.dev/blog/slog) (Jonathan
Amsterdam); [kubernetes/community logging conventions](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-instrumentation/logging.md);
controller-runtime godoc.

## General Go: `log/slog` (Go 1.21+)

Structured, leveled (DEBUG/INFO/WARN/ERROR). Three core types: `Logger` (frontend),
`Handler` (backend — `TextHandler`, `JSONHandler`, or custom), `Record`. Common pattern:
text handler in dev, JSON in prod.

```go
logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
logger.Info("request handled", "method", r.Method, "status", status, "dur", elapsed)
```

- Prefer strongly-typed attrs (`slog.String`, `slog.Int`) or `slog.LogAttrs` on hot paths —
  the alternating key/value form is a foot-gun (a `vet` check catches mismatches). Over 95%
  of real log calls pass ≤5 attributes, so this stays readable.
- Use `InfoContext`/`WarnContext`/… to carry context; the `otelslog` bridge extracts
  trace/span IDs.
- `logger.With("request_id", id)` derives a child logger that stamps every line — the way to
  propagate **correlation IDs**.

### Global logger vs dependency injection — Tradeoff

- **Inject** a logger into services/structs (testable, explicit, no hidden global state) —
  the default for non-trivial packages.
- A **global** (`slog.SetDefault`) is acceptable for small programs and CLIs.
- **Non-app/library packages should not log directly** — return errors and let the caller
  (which owns the logger) decide. `sloglint` can enforce a chosen style.

### slog vs zap/zerolog — Tradeoff

- **slog**: stdlib, no dependency, standard API, OTel-friendly — **best default for new code.**
- **zap/zerolog**: keep when logging is genuinely on a hot path (zap's speed) or you need
  advanced features (custom encoders, sampling, hooks). Don't rewrite working zap logging
  for low ROI — bridge with an adapter and put new code on slog.

## No `fmt.Println` / `log.Printf` outside `main`/CLI

Throwaway prints in library/service code are a review red flag. Use the structured logger.

## Kubernetes controllers: `logr` (different conventions!)

Controllers use `logr` via `log.FromContext(ctx)`, conventionally backed by zap
(`sigs.k8s.io/controller-runtime/pkg/log/zap`). **K8s logging conventions differ from
general Go:**

- Messages are **Capitalized**, **no trailing punctuation**, **past tense** for completed
  actions.
- Always include structured key/value **object identifiers**:

```go
log := log.FromContext(ctx).WithValues("deployment", req.NamespacedName)
log.Info("Created Deployment", "name", deploy.Name)
```

- Use verbosity levels (`log.V(1)`, klog-style) for chatty debug output.
- **ERROR is expensive** (causes a flush) and should be actionable — don't log expected
  states (object not ready yet) at ERROR.

## Metrics

- controller-runtime auto-exposes Prometheus metrics:
  `controller_runtime_reconcile_total{result=...}`,
  `controller_runtime_reconcile_errors_total`,
  `controller_runtime_reconcile_time_seconds` (histogram), plus `workqueue_depth` and queue
  latency/retries.
- Key SLIs: sustained `workqueue_depth > 0` = falling behind; p99 reconcile latency via
  `histogram_quantile(0.99, ...reconcile_time_seconds_bucket)`; reconcile error rate.
- Register custom metrics on `sigs.k8s.io/controller-runtime/pkg/metrics`.`Registry`
  (`metrics.Registry.MustRegister(...)`). If you emit a metric per condition, remove it on
  object delete so you don't leak series.
- For general services: expose RED/USE metrics; structured logs + metrics + traces together.

## Events (controllers)

`recorder := mgr.GetEventRecorderFor("widget-controller")`, then
`recorder.Event(obj, corev1.EventTypeNormal, "Created", "...")`. Only `EventTypeNormal` and
`EventTypeWarning` are valid. Events are user-facing; use them for state transitions, not
debug spam.

## Review red flags

- `fmt.Println`/`log.Printf` outside `main`/CLI.
- Unstructured / string-concatenated log messages.
- Library packages logging instead of returning errors.
- Controllers logging expected "not ready" states at ERROR.
- Missing object identifiers in controller logs.
- Production service with no metrics; per-object metric series never cleaned up.
