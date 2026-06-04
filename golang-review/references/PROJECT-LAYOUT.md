# Project layout

This is a **genuinely contested** area — present both sides; don't cargo-cult.

## The key fact

[`golang-standards/project-layout`](https://github.com/golang-standards/project-layout) is
popular but its own README states verbatim:

> "This is NOT an official standard defined by the core Go dev team. This is a set of common
> historical and emerging project layout patterns in the Go ecosystem."

The Go team does not endorse a project structure; figures including Russ Cox have publicly
criticized treating it as standard. So: **match the repo you're in**, and for new code,
start small.

## Recommended default

1. **Start flat** — a `main.go` + `go.mod` is a perfectly good Go project.
2. Add **`cmd/<binary>/`** when you have **multiple binaries**.
3. Add **`internal/`** when you want **enforced privacy** — it's the **only
   compiler-enforced** layout rule (packages under `internal/` cannot be imported from
   outside the module subtree). Promotion out of `internal/` is opt-in.
4. Be skeptical of **`pkg/`** — the Go team does not recommend it (stdlib dropped its `pkg/`
   in Go 1.4); it adds a path segment without semantic benefit. Some teams use it to signal
   "safe to import" or to group Go away from many non-Go files — fine if deliberate, not by
   reflex.

## Organize by domain, not by technical layer

Many CNCF projects group by domain, not by `controllers/`/`models/`/`utils/`:

- Prometheus: `promql/`, `tsdb/`, `scrape/`.
- Helm: documents that "code inside of cmd/ is not designed for library re-use."
- Terraform: ~all implementation under `internal/`.
- Kubernetes uses `cmd/` + `pkg/` + `staging/` for historical reasons — a large-project
  exception, not a template for your service.

Avoid a `utils`/`common`/`helpers` grab-bag package — it becomes an import magnet and a
dependency cycle hazard. Name packages for what they provide.

## Package naming (Kubernetes/Google conventions)

- Package names: **lowercase, no underscores, no camelCase**; match the directory name.
- **Avoid stutter**: `storage.Interface`, not `storage.StorageInterface`; `chart.New`, not
  `chart.NewChart`.
- Flags use dashes (`--max-concurrent-reconciles`).
- Imports in 3 blocks (stdlib / external / internal), enforced by `goimports`.

## Review red flags

- `pkg/` or deep `cmd/internal/pkg` scaffolding on a small/new project that doesn't need it.
- A `utils`/`common` dumping-ground package.
- Package names that stutter or use underscores/camelCase.
- Genuinely private code placed where any module can import it (should be `internal/`).
- Restructuring an existing repo to a different convention without reason — consistency wins.
