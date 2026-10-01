# Axis 2 — recurrence: API, strip rules, wire-out

Detail for the recurrence axis of `controller-anomaly-axes`; when to invoke, the wire-in recipe, the promotion path and the workflow stay in `SKILL.md`.

> Until 2026-10-01 the standalone skill `anomaly-recurrence` (version 0.1.1): Turns opaque recurring controller errors into stable signatures and recurrence counts. Use for an unclassified repeating error. Original title: *anomaly-recurrence — Known unknowns made structured*.

### API (pangea-operator/pangea-operator/src/controller/anomaly_tracker.rs)

```rust
// Pure: strip variable parts + BLAKE3 hash. 12 hex chars.
pub fn error_signature(err_msg: &str) -> String;

// Inspectable canonical-form derivation (for tests + debugging).
pub fn strip_variable_parts(err_msg: &str) -> String;

pub trait RecurrenceObserver: Send + Sync {
    fn observe(&self, key: &str, signature: &str) -> Recurrence;
    fn peek(&self, key: &str, signature: &str) -> Option<Recurrence>;
}

pub struct Recurrence { signature, count: u32, age: Duration }
pub struct InMemoryRecurrenceTracker { /* per-process */ }
```

14 unit tests. Pure (no async / no I/O / no global state).

### Strip rules

| Variable part | Pattern | Placeholder |
|---|---|---|
| Nix-store hash | `/nix/store/<32-base32>-<name>` | `/nix/store/<HASH>` |
| Workspace path | `/var/pangea/workspaces/<name>/…` | `/var/pangea/workspaces/<NAME>` |
| Gem cache path | `/var/pangea/gems/<name>-<ref>/…` | `/var/pangea/gems/<GEM>` |
| Hex address | `0x<hex>` | `0x<HEX>` |

What's preserved: module names, error verbs, logical Ruby require paths.

### Wire-out (slice-4+)

* `.status.anomalies[].signature` — surface the recurrence shape in CRD status.
* `pangea_anomaly_recurrences_total{namespace, name, signature}` counter.
* `Conflict { detector: "anomaly_recurrence", category: signature, evidence: { count, age_s } }` — joins the typed audit stream.

### Anti-patterns to flag

| Anti-pattern | Why bad | Right move |
|---|---|---|
| Skipping signature, just emitting raw error string | Dashboards can't aggregate | Always signature first |
| Using `format!("{:?}", err)` as the signature input | Includes addresses / unstable Display | Use the err's `Display`/`to_string()`; strip step handles paths |
| Re-implementing strip rules per call site | Drift across audit sites | Single source: `error_signature` in `anomaly_tracker` |
| Persisting raw error strings in metric labels | Cardinality explosion | Signature → bounded label cardinality |
| Per-template global locks for recurrence | Contention | Per-(key, signature) entry; `Mutex<HashMap>` is fine |
| Adding `&mut self` to the trait | Forces callers to own a write-locked tracker | `&self` + interior Mutex; lets ControllerState hold `Arc<dyn …>` |

### Composes with

* **Axis 1 (detection)** — the typed-detector axis; signature → bug class promotion path.
* **Axis 3 (escalation ladder)** — TIME-gated actions; recurrence count is the COMPLEMENTARY signal.

### Related knowledge notes

In the operator's private knowledge base (found by filename; they were agent
memories until 2026-10-01):

* `project_anomaly_recurrence.md` — durable knowledge.
* `project_controller_detection_axis.md` — sibling typed-detector axis.
* `project_escalation_ladder.md` — sibling time-gated axis.

### Triggers

Invoke when:
- User describes a recurring opaque error in production.
- Adding a new error-handling arm.
- Dashboards need cross-pod aggregation of error types.
- Designing the bridge between unstructured errors and the typed audit surface.

DO NOT invoke for:
- Single-shot errors with no recurrence risk.
- Errors already covered by a typed `ConflictDetector`.
- Errors where the bug class is structurally fixable (just fix it).
