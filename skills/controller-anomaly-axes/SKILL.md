---
name: controller-anomaly-axes
description: "Typed detectors and escalation for recurring controller errs"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "0.2.0"
  domain_keywords:
    - "controller"
    - "operator"
    - "detector"
    - "bug-class"
    - "conflict"
    - "preprocessing"
    - "DSL"
    - "global-state"
    - "load-path"
    - "compile-isolation"
    - "anomaly"
    - "pangea-operator"
    - "recurrence"
    - "signature"
    - "error-classification"
    - "stable-hash"
    - "blake3"
    - "audit"
    - "known-unknowns"
    - "escalation"
    - "recovery"
    - "stuck"
    - "settling"
    - "reconciliation"
    - "recovery-policy"
    - "pause-and-alert"
---

# controller-anomaly-axes — three axes of controller anomaly handling

A reconciling controller meets three kinds of failure, and each gets its own
axis. All three emit the same typed `Conflict` shape, so every audit consumer
(tracing, `.status.anomalies[]`, k8s Events, Prometheus, GraphQL) reads one
schema whichever axis fired. Until 2026-10-01 each axis was its own skill
(`controller-detection-axis`, `anomaly-recurrence`, `escalation-ladder`); each
is kept below as one section, with its detail in `references/`.

## The three axes

| Axis | Handles | Primitive |
|---|---|---|
| Known knowns | Named bug classes | `ConflictDetector` (load_path_double_load, …) |
| **Known unknowns** | **Unclassified-but-recurring errors** | **`error_signature` + `RecurrenceObserver`** |
| Unknown unknowns | Anything-else that persists | `EscalationLadder` (TIME gate) |

Three axes, same `Conflict` typed shape. Same audit consumers.

| Axis | Section | Reach for it when |
|---|---|---|
| 1 — known knowns | [Axis 1 — detection](#axis-1--known-knowns-the-detection-axis) | a preprocessing/DSL/setup step with a structural smell, or a cryptic downstream error whose bug class can be named |
| 2 — known unknowns | [Axis 2 — recurrence](#axis-2--known-unknowns-the-recurrence-axis) | an opaque error string keeps repeating and no typed detector names it yet |
| 3 — unknown unknowns | [Axis 3 — escalation ladder](#axis-3--unknown-unknowns-the-escalation-ladder) | a failure persists for minutes and the controller must respond with progressively deeper recovery |

**The feedback loop between them:** an opaque recurring signature (axis 2) that
shows a pattern is promoted to a typed `ConflictDetector` (axis 1), keeping the
signature for compat; whatever neither axis classifies is still bounded by time
(axis 3), whose deepest rung forces human attention.

---

## Axis 1 — known knowns: the detection axis

Every preprocessing / DSL / setup step in a controller is a candidate for a **bug class**: an entire family of cryptic downstream errors that share a structural cause. This skill names the pattern that turns each bug class into a controlled four-step loop and gives you the apply-or-skip checklist + concrete plumbing recipes.

### The pattern in one breath

```
1. Detect    — pure ConflictDetector scans inputs → emits typed Conflicts.
2. Expose    — same Conflict shape flows: tracing → .status.anomalies[]
                → k8s Events → Prometheus → GraphQL subscriptions.
3. Visualize — humans + dashboards + on-call query the structured stream.
4. Fix       — planner-layer change at the right layer; detector becomes
                the regression test for the bug class going forward.
```

Same typed `Conflict` flows through all four steps so consumers don't branch on which step emitted.

### When to invoke (the smell check)

Apply the axis when the controller adds a step with ANY of these smells:

| Smell | Example |
|---|---|
| Global-state accumulation | CRuby's `$LOAD_PATH`, `$LOADED_FEATURES`, module constants accumulate across compiles. |
| String-based logical IDs → physical addresses | Ruby require names → file paths; Terraform addresses → state slots; env var names → process env. |
| Multiple producers → one collector | Multiple gems prepending to `$LOAD_PATH`; multiple modules synthesizing into one TF config. |
| Ordering-dependent semantics not reified anywhere | "Load order matters but isn't a type"; "this env var must be set before that one". |
| Cryptic downstream error | The prior occurrence is THE signal — every "huh, weird error" is a candidate. |

If NONE apply, the preprocessing is scalar; the axis is overhead, skip it.

The Rust shape every detector mirrors, the step-by-step recipe for adding one, the load-path double-load case study, the anti-patterns to flag and the related notes: `references/detection-axis.md`.

### Workflow when invoking this skill

When the user describes a new preprocessing / DSL / setup step OR a cryptic downstream error in a controller:

1. **Smell-check**: does the situation hit any row of the smell table above? If not, advise the axis is overhead and propose the scalar fix instead.

2. **Name the bug class**: pick a stable `<bug_class>` label. This appears in tracing prefixes, metric labels, event reasons. Pick once, never change.

3. **Sketch the detector**: what's the pure-function scan? What are the inputs (config, existing state, candidate inputs)? What's the per-finding evidence shape (which fields will status consumers query)?

4. **Sketch the planner (if applicable)**: is there a planner-layer fix that pulls the decision UP into a pure function? If yes, the labeled-source pattern (`<Surface>Source` enum + `<Surface>Entry` struct + `plan_<surface>` fn + `CompileContext::from_plan`) is the recipe. If no, document why the detector is informational only.

5. **Open files in order** (repo-qualified: `pangea-operator/<crate>/src/…`):
   - `pangea-operator/pangea-ruby-eval/src/evaluator.rs` — detector + planner go here for compile-isolation bug classes.
   - `pangea-operator/pangea-operator/src/ruby/owner.rs` — for `tracing::warn!` wiring.
   - (Slice 4) `pangea-operator/pangea-operator/src/controller/template/status.rs` — for `.status.anomalies[]`.

6. **Tests first**: pure unit tests for the detector + planner. TempDir + filesystem layout + assert. No Ruby needed for pure-function tests.

7. **Commit boundary**: detector + tests is one commit. Planner is one commit. Wire-up in owner.rs is one commit. Each lands independently.

---

## Axis 2 — known unknowns: the recurrence axis

The third axis of controller anomaly handling. The detection axis names KNOWN bug classes; the escalation ladder gates ALL unknowns by time. This skill is the middle layer: errors the controller can't classify still become structured signal via stable signatures + recurrence counts.

The composition table that defines all three axes is at the top of this skill (§The three axes).

### When to invoke

| Situation | Apply? |
|---|---|
| Opaque error string showing up repeatedly | Yes — signature + recurrence is the right surfacing. |
| Dashboards need "which bug class is hammering us right now" | Yes — `error_signature` produces the join key. |
| Adding a new failure path that emits free-form error strings | Yes — wire `error_signature` at the failure site. |
| Bridging an unclassified error to the typed audit surface | Yes. |
| Bug class is named (typed detector exists) | No — promote to typed detector (see Axis 1 — detection, above). |
| Single-shot error you'll never see again | No — overhead for no gain. |

### Wire-in recipe

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

### Promotion path: known unknown → known known

When a recurring unknown signature shows a pattern, the upgrade is:

1. Write a typed `ConflictDetector` for the bug class (see Axis 1 — detection, above).
2. Replace the recurrence-based emission with the typed detector's emission.
3. The signature stays the same (compat); audit consumers gain typed evidence.

This is the FEEDBACK LOOP: opaque-recurring → named-recurring → typed-detected.

### Workflow when invoking

1. **Identify the failure site** — wherever the controller catches an Err and bails.
2. **Pick the recurrence key** — typical: `format!("{}/{}", namespace, name)` for per-template tracking.
3. **Wire signature + observe + emit** — 5-line block (see recipe above).
4. **(Slice-4) wire to status** — feed Recurrence into `Conflict.evidence`.
5. **Tune strip rules** — if the canonical form is still too granular for production errors, add a strip rule (file `strip_variable_parts` in anomaly_tracker.rs, add a unit test).

The `error_signature` API, the strip rules, the slice-4 wire-out, the anti-patterns to flag and the related notes: `references/recurrence-axis.md`.

---

## Axis 3 — unknown unknowns: the escalation ladder

The reconciliation motor needs progressively deeper corrective actions when a template can't reach Ready. This skill names the pattern, the production-default ladder, and the wire-in shape so any new failure surface gets recovery semantics by default.

### The default ladder (pangea-operator)

| Rung | After | Action | Handles |
|---|---|---|---|
| 0 | 0s | `Retry` | normal reconcile path |
| 1 | 5 min | `RefreshSource` | "source moved, our clone is stale" |
| 2 | 15 min | `ReloadGems` | "in-process Ruby state is wedged; FS is fine" |
| 3 | 30 min | `RecycleWorkers` | "the CRuby VM is irrecoverable; kill pool" |
| 4 | 60 min | `PauseAndAlert` | "we tried everything; human required" |

Each action is **idempotent**. Each label is **stable** (locked by test). `depth()` orders for comparison + dashboards.

### When to invoke

| Situation | Apply? | Why |
|---|---|---|
| A new bug class with recurring failures | Yes | Surface the right rung from day 1; future handlers slot in. |
| A new template type / controller arm | Yes | Wire the ladder into its failure path so recovery is automatic. |
| "How should the controller respond to X persistent for N minutes?" | Yes | Map N to the right rung. |
| A one-shot bug fix | No | The ladder is overhead — fix it and move on. |
| Errors fixed by configuration retry alone | No | settlingPolicy + retryPolicy handle that; the ladder is for time-graded depth. |

### Workflow when invoking

1. **Smell-check**: does the failure recur, with no scalar fix? If yes, ladder applies.
2. **Map persistence to depth**: how long should X persist before each rung? Use the default unless the user names different timings.
3. **Pick the wire-in arm**: which `handle_<X>_failure` function adds the ladder call?
4. **Surface-first**: log + status + Event. Handlers later.
5. **Pure tests**: TempDir-free; just `Duration::from_secs(...)` inputs and `EscalationAction` assertions.

The codified `EscalationLadder` API, the surface-only and action-handler wire-in, the per-CR `recoveryPolicy` override, the anti-patterns to flag and the related notes: `references/escalation-ladder.md`.

---

## References

- `references/detection-axis.md`: axis 1, writing a new `ConflictDetector` or planner; the Rust primitives, the recipe, the 2026-05-28 load-path case study, anti-patterns, triggers
- `references/recurrence-axis.md`: axis 2, the `anomaly_tracker` API and strip rules, wiring recurrence into status/metrics, anti-patterns, triggers
- `references/escalation-ladder.md`: axis 3, the `escalation.rs` API, wiring the ladder and its action handlers into a failure arm, per-CR overrides, anti-patterns, triggers
