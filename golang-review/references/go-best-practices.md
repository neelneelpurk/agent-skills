# Go Best Practices (review reference)

Idioms and pitfalls drawn from *Effective Go*, the *Go Code Review Comments* wiki, the
standard library, and `go vet`/`staticcheck` rules. When reviewing, prefer flagging issues
that tooling can't catch.

## Errors

- **Always check returned errors.** An ignored error (`_ = f()` or no assignment) needs an
  explicit justification. `errcheck`/`go vet` catch some, not all (e.g. deferred `Close`).
- **Wrap to preserve context and the chain:** `fmt.Errorf("reading config %q: %w", path, err)`.
  Use `%w` (not `%v`) when callers may want to unwrap. Wrap at boundaries, not at every
  level — avoid `failed to: failed to: failed to`.
- **Inspect with `errors.Is` / `errors.As`,** never `strings.Contains(err.Error(), ...)`.
  Define sentinel errors (`var ErrNotFound = errors.New("not found")`) or typed errors for
  callers that branch.
- **Don't log *and* return** the same error — that double-reports. Decide who owns it.
- **Error strings:** lowercase, no trailing punctuation (they get wrapped):
  `errors.New("connection refused")`, not `errors.New("Connection refused.")`.
- **`panic` is for programmer errors / unrecoverable invariants,** not control flow. Library
  code should return errors. Recover only at well-defined boundaries (e.g. a request handler).

## Context

- **`ctx context.Context` is the first parameter,** named `ctx`. Never store it in a struct;
  pass it through call chains.
- **Don't pass `nil` context.** Use `context.TODO()` only as a temporary placeholder.
- **Respect cancellation:** check `ctx.Err()` / `<-ctx.Done()` in loops and before expensive
  work; thread `ctx` into every blocking call (HTTP, DB, gRPC).
- **`context.WithCancel/Timeout` returns a `cancel` func that must be called** (usually
  `defer cancel()`), even on the success path, to release resources.
- **Context values are for request-scoped data** (trace IDs, auth), not optional function
  params. Use typed, unexported keys.

## Concurrency

- **Every goroutine needs an exit path.** Tie its lifetime to a `ctx`, a `done` channel, or a
  `WaitGroup`. A `go func()` with no way to stop and no one waiting is a leak.
- **Don't start a goroutine you don't synchronize.** Use `sync.WaitGroup` or
  `golang.org/x/sync/errgroup` (which also propagates the first error and cancels siblings).
- **Channels:** the sender closes, never the receiver; closing a closed channel panics.
  Sending on a closed channel panics. Prefer `select` with `ctx.Done()` for cancellable
  sends/receives.
- **Protect shared state** with `sync.Mutex`/`RWMutex` or confine it to one goroutine and
  communicate via channels. Run tests with `-race`.
- **Don't copy a struct containing a `sync.Mutex`** (or `WaitGroup`, `atomic` types) — `go vet`
  catches some cases. Pass by pointer.
- **`sync.WaitGroup`:** `Add` before launching the goroutine, `wg.Done()` via `defer` inside.

## Slices, maps, and the loop-variable trap

- **Loop variable capture:** before Go 1.22 a single variable was reused across iterations, so
  capturing `&v` or referencing `v` in a closure/goroutine inside `for ... range` was a
  classic bug. Even on 1.22+, be explicit when the code may build on older toolchains.
- **`append` aliasing:** `append` may return a slice sharing the original backing array;
  mutating the result can clobber the original (and vice versa). When you slice and then
  append, consider `slices.Clone` or a 3-index slice `s[a:b:b]` to force a copy.
- **`nil` slices vs. empty slices** are usually interchangeable for reads; ranging over `nil`
  is fine. But a `nil` map panics on write — initialize with `make`.
- **Map iteration order is randomized;** never rely on it. Sort keys for deterministic output.
- **Pre-size when the length is known:** `make([]T, 0, n)` / `make(map[K]V, n)` avoids
  reallocation.

## Resource management

- **`defer` runs at function return, not block end** — in a loop, deferred `Close`/`Unlock`
  pile up. Close inside the loop body, or extract the body into a function.
- **Check the error from deferred closers that flush** (files opened for writing, gzip
  writers): `defer func() { err = errors.Join(err, w.Close()) }()`.
- **Always `defer resp.Body.Close()`** after a successful `http.Do`, and drain the body if you
  want connection reuse.

## API & style

- **Accept interfaces, return concrete types.** Define interfaces at the consumer, keep them
  small (1–3 methods). Don't create an interface "just in case" with one implementation.
- **Naming:** mixedCaps not snake_case; exported names get doc comments starting with the
  name; no stutter (`http.Server` not `http.HTTPServer`); acronyms keep case (`URL`, `ID`).
- **Receivers:** be consistent (all pointer or all value per type); use pointer receivers when
  the method mutates or the struct is large.
- **Zero values should be useful** where practical (`sync.Mutex`, `bytes.Buffer`).
- **Return early** to reduce nesting; keep the happy path at minimal indentation.
- **Avoid naked returns** in non-trivial functions; named returns are for documentation and
  `defer`-based error decoration, not brevity.

## Testing

- **Table-driven tests** with subtests (`t.Run`) and, when independent, `t.Parallel()`.
- **Use `t.Helper()`** in assertion helpers so failures point at the caller.
- **Don't assert on `err.Error()` strings;** use `errors.Is`/`As` or sentinel checks.
- **`t.Cleanup`** over manual teardown; `t.TempDir()` for filesystem tests.
- **Run with `-race`** for anything concurrent. Avoid sleeps; synchronize explicitly.
