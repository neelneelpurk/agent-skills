# Interfaces & API design

Sources: Go Code Review Comments, Google & Uber style guides, Rob Pike & Dave Cheney on
functional options.

## Accept interfaces, return structs

- **Accept** the smallest interface you actually use; **return** concrete structs so callers
  keep full access and you can add methods without breaking them.
- **Define interfaces at the consumer**, not the producer. The package that *needs* the
  behaviour declares the interface; the package that *provides* it just returns a concrete
  type. This keeps interfaces small and avoids forcing dependencies.
- **Don't create an interface just to have one.** "This is Go, not Java." A single-implementation
  interface defined next to its only implementation is usually premature. Add it when you
  have a real second implementation or a real test seam.
- Small interfaces compose: prefer `io.Reader`/`io.Writer`-sized contracts (1–3 methods).

```go
// Consumer declares only what it needs:
type userStore interface {
    User(ctx context.Context, id string) (*User, error)
}

func NewService(s userStore) *Service { return &Service{store: s} }
```

## Type discipline

- Prefer **`any`** over `interface{}` (Go 1.18+, identical type, clearer intent).
- Avoid `any`/`interface{}` as a way to dodge real types — it pushes errors to runtime.
- **Generics**: "Write code, don't design types" (Griesemer/Taylor). Use a shared interface
  if one already fits. Reach for generics over `any` + type-switching only when you have
  genuine parametric behaviour (containers, `Map`/`Filter`-style helpers, constraints).
- Make the **zero value useful** (`bytes.Buffer`, `sync.Mutex` work unconstructed). Don't
  force a constructor when a usable zero value is possible.
- Don't pass pointers just to "save bytes" — pass by value unless you need to mutate the
  receiver or the struct is genuinely large; let escape analysis decide.
- Avoid **stringly-typed** APIs and **boolean parameters** (`Create(true, false)` is
  unreadable). Use named types / enums / option structs instead.

## Constructors and options — Tradeoff

**Config struct in → struct out** (good default for most packages):

```go
type Config struct {
    Timeout time.Duration
    Retries int
}

func New(cfg Config) (*Client, error) { /* validate, apply defaults */ }
```

Simple, explicit, fast, easy to read. The default for app/internal packages.

**Functional options** (for libraries / extensible public APIs with many optional knobs):

```go
type Option func(*Client)

func WithTimeout(d time.Duration) Option { return func(c *Client) { c.timeout = d } }

func New(opts ...Option) *Client {
    c := &Client{timeout: 30 * time.Second} // defaults
    for _, opt := range opts {
        opt(c)
    }
    return c
}
```

- **Use options when**: a public/extensible API, many optional settings, you want to add
  knobs without breaking the signature, and you want immutable-after-construction objects.
- **Use a config struct when**: performance-sensitive (options add allocations + non-inlinable
  calls), or the API is simple. Functional options are *not* the universal default.

## Review red flags

- Producer-side / premature interfaces (one impl, defined with its implementation).
- Returning an interface where a concrete struct would serve.
- `interface{}`/`any` overuse hiding real types.
- Boolean params and stringly-typed APIs.
- Constructors that don't validate input or set defaults.
- Generics used where a plain interface or concrete type was clearer.
