# Kubernetes API Conventions (review reference)

Distilled from the Kubernetes [API Conventions](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md)
and apimachinery semantics. Use when reviewing code that **defines** API types (CRDs) or
**consumes** the API.

## Spec vs. Status

- **`spec` = desired state**, written by the user/client. **`status` = observed state**,
  written by the controller. These are separate top-level fields on every object.
- **Controllers must not write `spec`;** users (or higher-level controllers) own it. A
  controller reconciles toward `spec` and reports through `status`.
- **Status must be reconstructible.** If status were lost, the controller should be able to
  rebuild it by observing the world. Don't store data in status that exists nowhere else.
- Both `spec` and `status` are objects (structs), not scalars, so they can grow fields
  compatibly.

## Object metadata (`ObjectMeta`)

- Standard fields: `name`, `namespace`, `labels`, `annotations`, `resourceVersion`, `uid`,
  `generation`, `creationTimestamp`, `deletionTimestamp`, `ownerReferences`, `finalizers`.
- **`resourceVersion`** is an opaque optimistic-concurrency token — never parse, compare
  ordering, or do arithmetic on it. Pass it back unchanged on update.
- **`generation`** increments on spec changes; controllers record `status.observedGeneration`
  to signal "I've processed this spec version."
- **Labels** are for identifying/selecting objects (indexed, queryable, ≤63 chars, constrained
  charset). **Annotations** are for arbitrary non-identifying metadata (large, free-form,
  not selectable).
- **`uid`** uniquely identifies an object across space and time; a name reused after deletion
  gets a new uid.

## Field conventions

- **Optional fields** are pointers or have `omitempty`, with `// +optional`. Use a pointer
  when you must distinguish "unset" from the zero value (`*int32`, `*bool`).
- **Required fields** are non-pointer and validated; document them.
- **Defaulting** happens server-side (or via webhook/CRD schema defaults), not by the client
  reading the object. Don't assume a field is populated client-side just because it has a
  default.
- **No "soft" enums as plain strings without validation** — constrain with
  `// +kubebuilder:validation:Enum=...` (CRDs) or validation logic.
- **Durations/quantities:** use `metav1.Duration` and `resource.Quantity`, not raw ints, so
  values are human-readable and unit-safe.
- **Booleans are hard to evolve** (only two states, awkward to add a third). Prefer a string
  enum when more states are plausible.
- **Timestamps** use `metav1.Time` (RFC 3339). Avoid storing rapidly-changing timestamps in
  status — they cause constant writes and version churn.

## Lists, labels, selectors

- **List types** (`FooList`) embed `metav1.ListMeta` and a `Items []Foo`. List responses carry
  a `resourceVersion` and optional `continue` token for pagination.
- **Filter server-side** with label selectors / field selectors rather than listing everything
  and filtering in code — it's cheaper and cache-friendly.
- **Selectors are AND-ed**; an empty selector matches everything (be careful — `List` with no
  selector can return the whole namespace/cluster).
- **Watch semantics:** clients are level-triggered. You may miss intermediate states and must
  tolerate replays and out-of-order-looking deliveries (`ADDED/MODIFIED/DELETED`). Never
  assume exactly-once edge delivery.

## Status conditions

- **Conditions are the standard way to express status**, as `[]metav1.Condition`. Each has:
  - `type` (CamelCase, e.g. `Ready`, `Available`),
  - `status` (`"True"`/`"False"`/`"Unknown"`),
  - `reason` (CamelCase machine token),
  - `message` (human-readable),
  - `lastTransitionTime`, `observedGeneration`.
- Conditions are **additive and orthogonal** — don't treat them as a state machine where one
  implies the absence of another. Use `meta.SetStatusCondition` / `meta.IsStatusConditionTrue`
  to manage them so `lastTransitionTime` is handled correctly.
- Avoid flapping: only bump `lastTransitionTime` when `status` actually changes.

## Concurrency & writes

- **Optimistic concurrency:** updates include the `resourceVersion` you read; a mismatch
  returns **`409 Conflict`**. The correct response is to re-read and retry (or requeue), not
  to force-overwrite.
- **Idempotency:** treat `Create` returning **`409 AlreadyExists`** and `Delete`/`Get`
  returning **`404 NotFound`** as normal, handleable outcomes.
- **Patch vs. Update:** prefer patches (strategic-merge, JSON-merge, or **server-side apply**)
  for partial changes to reduce conflicts. Server-side apply tracks field ownership and is the
  modern way for controllers to assert desired state.
- **The status subresource** (when enabled) means spec and status are updated through separate
  endpoints; writing status via the main update path is rejected or ignored.

## Naming & compatibility

- **API changes must be backward compatible** within a version: don't remove or repurpose
  fields, don't tighten validation on existing fields, don't change defaults in ways that
  alter behavior of stored objects.
- Field names are `camelCase` in JSON/YAML (Go struct tags), Go fields are `PascalCase`.
- Group/Version/Kind (GVK) identifies a type; promote through versions (`v1alpha1` →
  `v1beta1` → `v1`) with conversion, never by mutating an existing version.
