# Review checklist

Use this when **reviewing**. Skip anything `gofmt`/`golangci-lint` already enforces. Group
findings by severity — **Bug → Risk → Idiom → Nit** — and for each cite `file:line`, explain
*why*, and give a concrete fix.

## First: orient

- [ ] Read the `go` directive in `go.mod` (loopvar/slog/synctest guidance is version-gated).
- [ ] Identify the surface: plain Go / API type / controller / webhook → load the matching
      reference(s).
- [ ] Read the diff **in context** — open surrounding functions and the mutated types.

## General Go red flags

**Errors**
- [ ] Ignored errors that are actionable.
- [ ] `%s`/`%v` where `%w` was meant (chain broken; `errors.Is`/`As` fail downstream).
- [ ] Log-and-return of the same error.
- [ ] `panic` in library code; `os.Exit`/`log.Fatal` outside `main()`.

**Interfaces & types**
- [ ] Producer-side / premature interfaces (single impl, defined with implementation).
- [ ] Returning an interface where a concrete struct would serve.
- [ ] `interface{}`/`any` overuse hiding real types.
- [ ] Stringly-typed APIs and boolean params.
- [ ] Constructors that don't validate / set defaults.

**Concurrency**
- [ ] Goroutine with no cancellation/exit path → leak.
- [ ] Unbounded goroutine creation.
- [ ] Missing `defer cancel()` after `WithCancel`/`WithTimeout`.
- [ ] `sync.Mutex`/`WaitGroup` copied by value.
- [ ] Shared state mutated without synchronization.
- [ ] On Go `< 1.22`: loop variable captured in closure/goroutine without `x := x`.
- [ ] Send on a channel with no guaranteed receiver.

**Logging / observability**
- [ ] `fmt.Println`/`log.Printf` outside `main`/CLI; unstructured logs.
- [ ] Library packages logging instead of returning errors.
- [ ] Missing correlation IDs / metrics on production services.

**Testing**
- [ ] No `-race` in CI.
- [ ] Sleeps/timer-races instead of synchronization; asserting on log output.
- [ ] Shared mutable state between parallel tests.
- [ ] Coverage chased without behavioural assertions.

**Layout**
- [ ] `pkg/`/deep scaffolding on a project that doesn't need it.
- [ ] `utils`/`common` grab-bag package.
- [ ] Stuttering/underscored package names.
- [ ] Genuinely private code importable module-wide (should be `internal/`).

## Kubernetes controller red flags (hard requirements)

- [ ] Edge/event-driven logic instead of level-based reconcile.
- [ ] Non-idempotent create-without-check; assuming event ordering.
- [ ] Missing `client.IgnoreNotFound` / not returning `nil` on NotFound.
- [ ] Blocking/slow reconcile (sleeps, sync waits).
- [ ] Returning an **error** for an expected "not ready" state (backoff storm) — should be
      `RequeueAfter`; or never resetting backoff.
- [ ] Permanent failure retried forever instead of `TerminalError` + status.
- [ ] In-memory state carried across reconciles.
- [ ] Missing owner references; finalizer never removed (stuck deletion).
- [ ] Status written via the normal client instead of `r.Status()`.
- [ ] Missing `observedGeneration` (stale status looks current).
- [ ] Logic assuming read-after-write cache coherence.
- [ ] One controller reconciling many Kinds.
- [ ] No metrics / no Events for important transitions.
- [ ] Goroutines leaked from `Reconcile`/manager.
- [ ] Immutable fields set on update rather than only on create.

## Final PR questions (closing block)

- Does this make the code **easier to understand** than before?
- Is each error **handled once** and surfaced with enough context to debug from logs alone?
- For controllers: is `Reconcile` **idempotent** and safe to run twice in a row right now?
- Can the **next engineer extend this safely** without re-reading every call site?
- Are the tests asserting **behaviour**, and would they catch the bug this change fixes?
