# Testing

Sources: Go blog & docs; Google Go Style Guide; controller-runtime `envtest` docs.

## Table-driven tests + subtests (the canonical form)

```go
func TestParse(t *testing.T) {
    tests := map[string]struct {
        in      string
        want    int
        wantErr bool
    }{
        "valid":   {in: "42", want: 42},
        "empty":   {in: "", wantErr: true},
        "nonint":  {in: "x", wantErr: true},
    }
    for name, tc := range tests {
        t.Run(name, func(t *testing.T) { // Go 1.22+: tc is per-iteration
            got, err := Parse(tc.in)
            if (err != nil) != tc.wantErr {
                t.Fatalf("err = %v, wantErr = %v", err, tc.wantErr)
            }
            if got != tc.want {
                t.Errorf("got %d, want %d", got, tc.want)
            }
        })
    }
}
```

- Run with **`-race`** in CI — it catches data races.
- Use `t.Parallel()` where tests are independent and don't share mutable global state.
- Use `t.Cleanup(...)` instead of manual teardown; `t.Helper()` in assertion helpers.

## Other techniques

- **Fuzzing** (`testing.F`, Go 1.18+) for parsers, validators, anything taking untrusted
  input. Failing inputs are saved to `testdata/fuzz/` and become permanent regression tests.
- **Golden files** for complex/serialized output, with a `-update` flag to regenerate.
- **Coverage is a signal, not a target.** High coverage of trivial code proves little; aim
  tests at behaviour and edge cases.
- **`testing/synctest`** (stable Go 1.25, experimental 1.24) for deterministic concurrent /
  time-based tests without real sleeps.

## testify vs stdlib — Tradeoff

- **stdlib-first.** The Go team recommends table-driven tests and is wary of assertion
  libraries that "result in less useful test failures." Google: "be especially wary of
  introducing assertion libraries or frameworks."
- **testify** (`require`/`assert`/`mock`/`suite`) is acceptable **when it adds value** —
  readable assertions on complex structs, or mocking — but don't over-complicate simple
  tests. `require` stops on failure; `assert` continues. Match the project's existing choice.

## Testing Kubernetes controllers — Tradeoff

- **`envtest`** spins up a real (pared-down) etcd + kube-apiserver. Recommended by
  controller-runtime for realistic API behaviour including cache syncs and latency. Works
  with Ginkgo/Gomega (`Eventually(...)` for async assertions) **or** plain `go test`. Set
  `KUBEBUILDER_ASSETS` (via `setup-envtest`).
- **Fake client** (`sigs.k8s.io/controller-runtime/pkg/client/fake`): faster, fine for
  unit-testing reconcile logic limited to status updates. But controller-runtime warns fake
  clients "gradually re-implement poorly-written impressions of a real API server" — they
  don't enforce admission, defaulting, or the cache/read-after-write semantics that bite in
  production.
- **Best practice — layer**: unit-test pure idempotent subroutines with the fake client (or
  no client at all); use `envtest` for integration behaviour (watches, owner-ref GC,
  conflicts, status round-trips).

```go
// envtest async assertion
Eventually(func() bool {
    var got appsv1.Deployment
    if err := k8sClient.Get(ctx, key, &got); err != nil {
        return false
    }
    return *got.Spec.Replicas == 3
}, time.Second*10, time.Millisecond*250).Should(BeTrue())
```

## Review red flags

- No `-race` in CI.
- Tests that assert on log output or sleep on timers instead of synchronizing.
- Shared mutable state between parallel tests.
- Controller tested only with the fake client where real API semantics matter (conflicts,
  cache, GC, webhooks).
- Coverage chased as a number with no behavioural assertions.
