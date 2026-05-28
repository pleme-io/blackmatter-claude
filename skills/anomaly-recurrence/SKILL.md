---
name: anomaly-recurrence
description: Turn opaque recurring errors into structured signal via stable signatures + recurrence counts. Use when the user describes an unclassified error repeating in production, when dashboards need to aggregate "how many times has THIS error happened across pods", or when designing the bridge between unknown-shape errors and the typed audit surface. Closes the known-unknowns axis (sibling of controller-detection-axis + escalation-ladder). Codified in pangea-operator/src/controller/anomaly_tracker.rs.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "0.1.0"
  domain_keywords:
    - "anomaly"
    - "recurrence"
    - "signature"
    - "error-classification"
    - "stable-hash"
    - "blake3"
    - "audit"
    - "known-unknowns"
    - "pangea-operator"
---

# anomaly-recurrence — Known unknowns made structured

The third axis of controller anomaly handling. The detection axis names KNOWN bug classes; the escalation ladder gates ALL unknowns by time. This skill is the middle layer: errors the controller can't classify still become structured signal via stable signatures + recurrence counts.

## The three-axis composition

| Axis | Handles | Primitive |
|---|---|---|
| Known knowns | Named bug classes | `ConflictDetector` (load_path_double_load, …) |
| **Known unknowns** | **Unclassified-but-recurring errors** | **`error_signature` + `RecurrenceObserver`** |
| Unknown unknowns | Anything-else that persists | `EscalationLadder` (TIME gate) |

Three axes, same `Conflict` typed shape. Same audit consumers.

## When to invoke

| Situation | Apply? |
|---|---|
| Opaque error string showing up repeatedly | Yes — signature + recurrence is the right surfacing. |
| Dashboards need "which bug class is hammering us right now" | Yes — `error_signature` produces the join key. |
| Adding a new failure path that emits free-form error strings | Yes — wire `error_signature` at the failure site. |
| Bridging an unclassified error to the typed audit surface | Yes. |
| Bug class is named (typed detector exists) | No — promote to typed detector (see controller-detection-axis). |
| Single-shot error you'll never see again | No — overhead for no gain. |

## API (pangea-operator/src/controller/anomaly_tracker.rs)

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

## Strip rules

| Variable part | Pattern | Placeholder |
|---|---|---|
| Nix-store hash | `/nix/store/<32-base32>-<name>` | `/nix/store/<HASH>` |
| Workspace path | `/var/pangea/workspaces/<name>/…` | `/var/pangea/workspaces/<NAME>` |
| Gem cache path | `/var/pangea/gems/<name>-<ref>/…` | `/var/pangea/gems/<GEM>` |
| Hex address | `0x<hex>` | `0x<HEX>` |

What's preserved: module names, error verbs, logical Ruby require paths.

## Wire-in recipe

At every failure site that has a free-form error string:

```rust
let signature = anomaly_tracker::error_signature(err_msg);
let recurrence_key = format!("{}/{}", namespace, name);
let recurrence = state.anomaly_tracker.observe(&recurrence_key, &signature);
tracing::info!(
    error_signature = %signature,
    recurrence_count = recurrence.count,
    recurrence_age_s = recurrence.age.as_secs(),
    "anomaly recurrence observed"
);
```

ControllerState carries `anomaly_tracker: Arc<dyn RecurrenceObserver>`; default impl `InMemoryRecurrenceTracker` is per-process; slice-N swaps for sqlx-backed at the trait boundary.

## Wire-out (slice-4+)

* `.status.anomalies[].signature` — surface the recurrence shape in CRD status.
* `pangea_anomaly_recurrences_total{namespace, name, signature}` counter.
* `Conflict { detector: "anomaly_recurrence", category: signature, evidence: { count, age_s } }` — joins the typed audit stream.

## Promotion path: known unknown → known known

When a recurring unknown signature shows a pattern, the upgrade is:

1. Write a typed `ConflictDetector` for the bug class (see controller-detection-axis skill).
2. Replace the recurrence-based emission with the typed detector's emission.
3. The signature stays the same (compat); audit consumers gain typed evidence.

This is the FEEDBACK LOOP: opaque-recurring → named-recurring → typed-detected.

## Anti-patterns to flag

| Anti-pattern | Why bad | Right move |
|---|---|---|
| Skipping signature, just emitting raw error string | Dashboards can't aggregate | Always signature first |
| Using `format!("{:?}", err)` as the signature input | Includes addresses / unstable Display | Use the err's `Display`/`to_string()`; strip step handles paths |
| Re-implementing strip rules per call site | Drift across audit sites | Single source: `error_signature` in `anomaly_tracker` |
| Persisting raw error strings in metric labels | Cardinality explosion | Signature → bounded label cardinality |
| Per-template global locks for recurrence | Contention | Per-(key, signature) entry; `Mutex<HashMap>` is fine |
| Adding `&mut self` to the trait | Forces callers to own a write-locked tracker | `&self` + interior Mutex; lets ControllerState hold `Arc<dyn …>` |

## Composes with

* **controller-detection-axis** — the typed-detector axis; signature → bug class promotion path.
* **escalation-ladder** — TIME-gated actions; recurrence count is the COMPLEMENTARY signal.

## Workflow when invoking

1. **Identify the failure site** — wherever the controller catches an Err and bails.
2. **Pick the recurrence key** — typical: `format!("{}/{}", namespace, name)` for per-template tracking.
3. **Wire signature + observe + emit** — 5-line block (see recipe above).
4. **(Slice-4) wire to status** — feed Recurrence into `Conflict.evidence`.
5. **Tune strip rules** — if the canonical form is still too granular for production errors, add a strip rule (file `strip_variable_parts` in anomaly_tracker.rs, add a unit test).

## Related memories

* `memory/project_anomaly_recurrence.md` — durable knowledge.
* `memory/project_controller_detection_axis.md` — sibling typed-detector axis.
* `memory/project_escalation_ladder.md` — sibling time-gated axis.

## Triggers

Invoke when:
- User describes a recurring opaque error in production.
- Adding a new error-handling arm.
- Dashboards need cross-pod aggregation of error types.
- Designing the bridge between unstructured errors and the typed audit surface.

DO NOT invoke for:
- Single-shot errors with no recurrence risk.
- Errors already covered by a typed `ConflictDetector`.
- Errors where the bug class is structurally fixable (just fix it).
