# Concurrency

Sources: Rob Pike, [Go Concurrency Patterns](https://go.dev/talks/2012/concurrency.slide)
(Google I/O 2012); the Go blog [Pipelines and cancellation](https://go.dev/blog/pipelines);
Uber Go Style Guide. Philosophy: *"Concurrency is not parallelism"* and *"Don't communicate
by sharing memory; share memory by communicating."*

## Context

- `context.Context` is the **first parameter** of any function that does I/O, blocks, or may
  run long: `func Fetch(ctx context.Context, id string) (...)`.
- Always `defer cancel()` after `context.WithCancel`/`WithTimeout`/`WithDeadline` — a missed
  cancel **leaks** the context (and its timer/goroutine).
- Respect cancellation in loops and blocking selects:

```go
select {
case <-ctx.Done():
    return ctx.Err()
case v := <-ch:
    // ...
}
```

- Don't store a `Context` in a struct; pass it explicitly. Don't pass `nil` — use
  `context.TODO()` if you genuinely don't have one yet.

## Goroutine lifecycle — the dominant bug source

**Every goroutine must have a clear exit path.** Before writing `go f()`, answer: *what
stops this, and who waits for it?* A goroutine blocked forever on a channel/lock with no
cancellation path is a leak.

- No **unbounded** goroutine creation (e.g. `go handle(x)` per item in an unbounded stream).
  Use a worker pool or a semaphore channel to bound concurrency.
- Use `sync.WaitGroup` (or `errgroup`) so the parent waits for children before returning.

## errgroup for fallible parallel work

Cleaner than a raw `WaitGroup` when subtasks can fail: first error is returned and the
shared context is cancelled, stopping siblings.

```go
g, ctx := errgroup.WithContext(ctx)
for _, u := range urls {
    g.Go(func() error {        // Go 1.22+: u is per-iteration; on <1.22 add `u := u`
        return fetch(ctx, u)
    })
}
if err := g.Wait(); err != nil {
    return err
}
```

`g.SetLimit(n)` bounds concurrency.

## Channels vs mutexes — Tradeoff

> "Use channels for communication, mutexes for protecting state."

- **Channels** when ownership/data moves between goroutines, or for signalling (done,
  pipeline stages).
- **Mutexes** when several goroutines read/write *shared in-place state*. Prefer
  `sync.RWMutex` for read-heavy state. Keep critical sections small; `defer mu.Unlock()` so
  the lock is released even on a panic path.
- Don't reach for channels just because they're idiomatic — a mutex around a map is often
  simpler and faster than a goroutine-owned channel.

## sync primitives

- `sync.Once` for one-time init.
- `sync.Pool` reuses allocations on hot paths, but adds complexity — **measure first**.
- `sync/atomic` for simple counters/flags (Uber suggests `go.uber.org/atomic` for type
  safety).
- **Never copy a `sync.Mutex`/`WaitGroup`/`sync.Once` by value** — it's a struct; copying
  makes two distinct locks (a documented Uber data-race pattern). `go vet` catches some of
  this. Keep them in structs accessed by pointer.

## Common patterns

- **Generator**: function returns a receive-only channel it owns and closes.
- **Fan-out**: multiple workers read one input channel.
- **Fan-in**: merge N channels into one.
- **Pipeline**: chained stages, each closing its output channel when done; downstream
  cancellation via `ctx`/done channel propagates upstream.
- **Worker pool**: bounded goroutines reading a job channel.

## Graceful shutdown (canonical)

```go
ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
defer stop()

g, gCtx := errgroup.WithContext(ctx)
g.Go(func() error {
    return srv.ListenAndServe()
})
g.Go(func() error {
    <-gCtx.Done()
    shutdownCtx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
    defer cancel()
    return srv.Shutdown(shutdownCtx)
})
if err := g.Wait(); err != nil && !errors.Is(err, http.ErrServerClosed) {
    return err
}
```

Shutdown must finish within Kubernetes `terminationGracePeriodSeconds` (default 30s) before
SIGKILL. A readiness-drain delay plus an `isShuttingDown atomic.Bool` that fails the
readiness probe lets load balancers stop sending traffic before you tear down.

## Detection

`go test -race` (catches data races; ~2–10× overhead — run in CI), `go.uber.org/goleak` for
leak assertions in tests, `runtime.NumGoroutine()` monitoring, and pprof block/mutex
profiles in production.

## Review red flags

- `go func()` with no cancellation/exit path → leak.
- Unbounded goroutine creation.
- Missing `defer cancel()`.
- `sync.Mutex`/`WaitGroup` copied by value (passed by value, embedded then copied).
- Shared state mutated without synchronization.
- On Go `< 1.22`: loop variable captured by a closure/goroutine without `x := x`.
- Sending on a channel with no guaranteed receiver (deadlock/leak).
