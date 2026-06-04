# Copy-pasteable idioms

Canonical skeletons. Treat as illustrative — adapt names and confirm APIs against the
imported library version.

## Functional options

```go
type Client struct {
    timeout time.Duration
    retries int
}

type Option func(*Client)

func WithTimeout(d time.Duration) Option { return func(c *Client) { c.timeout = d } }
func WithRetries(n int) Option           { return func(c *Client) { c.retries = n } }

func New(opts ...Option) *Client {
    c := &Client{timeout: 30 * time.Second, retries: 3} // defaults
    for _, opt := range opts {
        opt(c)
    }
    return c
}
```

## Graceful shutdown (signal.NotifyContext + errgroup)

```go
func run() error {
    ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
    defer stop()

    srv := &http.Server{Addr: ":8080", Handler: mux}

    g, gCtx := errgroup.WithContext(ctx)
    g.Go(func() error {
        if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
            return err
        }
        return nil
    })
    g.Go(func() error {
        <-gCtx.Done()
        shutdownCtx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
        defer cancel()
        return srv.Shutdown(shutdownCtx)
    })
    return g.Wait()
}
```

## Bounded parallel work (errgroup with limit)

```go
g, ctx := errgroup.WithContext(ctx)
g.SetLimit(8)
for _, item := range items {
    g.Go(func() error { // Go 1.22+: item is per-iteration
        return process(ctx, item)
    })
}
if err := g.Wait(); err != nil {
    return err
}
```

## Table-driven test

```go
func TestThing(t *testing.T) {
    tests := map[string]struct {
        in   string
        want int
    }{
        "basic": {in: "ab", want: 2},
        "empty": {in: "", want: 0},
    }
    for name, tc := range tests {
        t.Run(name, func(t *testing.T) {
            t.Parallel()
            if got := Len(tc.in); got != tc.want {
                t.Errorf("Len(%q) = %d, want %d", tc.in, got, tc.want)
            }
        })
    }
}
```

## Reconcile loop (controller)

See the full annotated skeleton in `CONTROLLERS.md` — Get → `IgnoreNotFound` → finalizer/
deletion → `CreateOrUpdate` + `SetControllerReference` → status/conditions +
`observedGeneration` → `RequeueAfter`.

## Status update with conflict retry

```go
err := retry.RetryOnConflict(retry.DefaultRetry, func() error {
    var latest appv1.Widget
    if err := r.Get(ctx, key, &latest); err != nil {
        return err
    }
    latest.Status.ObservedGeneration = latest.Generation
    meta.SetStatusCondition(&latest.Status.Conditions, metav1.Condition{
        Type:               "Ready",
        Status:             metav1.ConditionTrue,
        Reason:             "Reconciled",
        Message:            "desired state reached",
        ObservedGeneration: latest.Generation,
    })
    return r.Status().Update(ctx, &latest)
})
```
