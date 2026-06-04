# Errors

High community consensus. Primary sources: [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments),
[Google Go Style Guide — Best Practices](https://google.github.io/styleguide/go/best-practices),
[Uber Go Style Guide](https://github.com/uber-go/guide).

## Creating errors

- **Static string** → `errors.New("...")`. Export as an `Err...` variable when callers must
  match it: `var ErrNotFound = errors.New("not found")`.
- **Dynamic/contextual** → `fmt.Errorf(...)`.
- **Callers need structured data** → a typed error with the `...Error` suffix, matched via
  `errors.As`:

```go
type ValidationError struct {
    Field string
    Msg   string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("field %q: %s", e.Field, e.Msg)
}
```

## Wrapping and matching

- Wrap to preserve the chain: `fmt.Errorf("loading config: %w", err)`. Use `%w` — **not**
  `%s`/`%v` — unless you are *deliberately* hiding the underlying error from callers.
- Match wrapped sentinels with `errors.Is(err, ErrNotFound)`.
- Extract typed errors with `errors.As(err, &target)`.
- Combine multiple failures with `errors.Join(err1, err2)` (Go 1.20+) — useful for
  validation that should report everything wrong at once, or cleanup that may fail in
  multiple steps.

```go
var errs error
for _, c := range closers {
    if err := c.Close(); err != nil {
        errs = errors.Join(errs, err)
    }
}
return errs
```

## Handle an error once

Do **not** both log and return the same error — the caller will log it again and you get
duplicate, confusingly-stacked log lines. Decide at each layer: either handle it (log,
recover, default) **or** propagate it with context. Not both.

```go
// BAD
if err != nil {
    log.Printf("query failed: %v", err) // logged here…
    return err                          // …and again by the caller
}

// GOOD
if err != nil {
    return fmt.Errorf("query users: %w", err)
}
```

## Panic discipline

> "A program must panic only when something irrecoverable happens such as a nil dereference."

- **No panics in library code** as an error strategy. Return errors.
- Documented exception: **program initialization** that cannot meaningfully continue —
  `template.Must`, `regexp.MustCompile`, compiling embedded assets at startup.
- In tests, prefer `t.Fatal` / `t.FailNow` over panic.
- `os.Exit` and `log.Fatal*` call `os.Exit`, skipping deferred functions — use them **only
  in `main()`**, never in libraries.
- If you `recover`, do it at a well-defined boundary (e.g. a request handler turning a panic
  into a 500), and convert it back into an error.

Google explicitly warns against error-handling **frameworks**: "prefer established error
handling practices." Don't introduce an errors library that hides `%w`/`Is`/`As`.

## Review red flags

- Ignored errors (`_ = doThing()` or no check at all) where the error is actionable.
- `%s`/`%v` where `%w` was intended (chain broken; `errors.Is`/`As` will fail downstream).
- Log-and-return of the same error.
- `panic` in non-`main`, non-init library code.
- `os.Exit`/`log.Fatal` outside `main()` (silently skips defers).
- Sentinel errors that aren't exported but callers clearly need to match.
