---
name: controller-anomaly-axes
description: "Controller anomaly axes: typed detectors, recurrence signatures, a time-graded escalation ladder. Use for recurring controller errors."
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
is kept whole below as one section.

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

> Until 2026-10-01 the standalone skill `controller-detection-axis` (version 0.1.1): Turns a controller bug class into a typed ConflictDetector plus planner. Use for cryptic recurring controller errors. Original title: *controller-detection-axis — The four-step bug-class loop*.

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

### The fundamental shape (Rust)

The codified primitives live in `pangea-operator/pangea-ruby-eval/src/evaluator.rs` (repo / crate / path):

```rust
// 1. The detector trait (open for new bug classes).
pub trait ConflictDetector: Send + Sync {
    fn name(&self) -> &'static str;
    fn detect(&self, ctx: &CompileContext, existing_load_path: &[PathBuf])
        -> Vec<Conflict>;
}

// 2. The typed shape every detector emits.
pub struct Conflict {
    pub detector: &'static str,           // metric/event label
    pub category: String,                 // the subject (logical name)
    pub message: String,                  // human-readable
    pub evidence: serde_json::Value,      // structured for sinks
}

// 3. The audit container (dual-surface: text + typed).
pub struct ContextWarnings {
    pub messages: Vec<String>,    // flat for tracing + legacy
    pub conflicts: Vec<Conflict>, // typed for status/events/GraphQL
}
```

Mirror this shape verbatim for new detectors in adjacent crates — the consumers stay simple because every detector speaks one schema.

### Recipe — adding a new detector

#### Step 1: Define the detector struct

```rust
pub struct <BugClass>Detector { /* config fields */ }

impl <BugClass>Detector {
    pub fn <reasonable_default>() -> Self { Self { /* ... */ } }
}

impl ConflictDetector for <BugClass>Detector {
    fn name(&self) -> &'static str { "<bug_class>" }
    fn detect(&self, ctx: &CompileContext, existing: &[PathBuf]) -> Vec<Conflict> {
        // Pure scan. No mutation of Ruby state, no I/O beyond inputs.
        // Each finding → one Conflict with detector="<bug_class>".
    }
}
```

`<bug_class>` is the stable label that appears in tracing + status + metric labels. Pick once, never change.

#### Step 2: Register in default detector set

In `CompileContext::default_detectors()`:

```rust
pub fn default_detectors() -> Vec<Box<dyn ConflictDetector>> {
    vec![
        Box::new(LoadPathConflictDetector::pangea()),
        Box::new(<BugClass>Detector::reasonable_default()),  // ← add
    ]
}
```

For per-CR custom detector sets, pass via `compile_in_context_with_detectors` instead.

#### Step 3: Pure unit tests

```rust
#[test]
fn detects_<bug_class>_when_<condition>() {
    // TempDir + filesystem layout + assert.
    // No Ruby needed — detector is pure.
}
```

#### Step 4: (Slice 4) wire the structured surface

When slice 4 lands `.status.anomalies[]`:

* CRD `InfrastructureTemplateStatus.anomalies: Option<Vec<Anomaly>>` where `Anomaly` is the on-wire shape of `Conflict`.
* `pangea-operator/pangea-operator/src/controller/template/status.rs` carries `ContextWarnings.conflicts` → `status.anomalies`.
* k8s `Event` with `reason = c.detector`, `message = c.message`, fingerprint by `(template, c.detector, c.category)` for deduplication.
* Prometheus `pangea_compile_conflicts_total{detector="<bug_class>"}`.

#### Step 5: The fix step — planner at the right layer

The detector NAMES the bug class; the planner ELIMINATES it. The planner pattern (see `plan_load_paths` for the canonical example):

```rust
// Inputs labeled by source — caller knows the shape.
pub enum <Surface>Source { /* tiers */ }
pub struct <Surface>Entry { /* path + source */ }

// Pure planner — labels in, plan out.
pub fn plan_<surface>(entries: &[<Surface>Entry], cfg: &Config) -> <Surface>Plan;

// Manifest from plan — drops hardcoded values in the controller.
impl CompileContext { pub fn from_plan(plan: &<Surface>Plan) -> Self; }
```

The planner is pure. The controller layer labels inputs by source. The manifest applies the plan transactionally. Hardcoded values in the controller (the `"/var/pangea/gems/pangea-architectures-main/"` purge prefix in `owner.rs`) become derivable — adding a new producer doesn't need an edit.

### The case study (load-path double load — codified 2026-05-28)

**Symptom**: `pleme-io-opensource` stuck at `Compiling` with `consecutiveCompileFailures: 104`. Error: `Attribute :cluster_name has already been defined`.

**Detect**: `LoadPathConflictDetector` walks every `.rb` file under each `$LOAD_PATH` entry × `["pangea/"]`; groups by logical require name; flags any name with >1 absolute path. O(L × F), ~µs warm cache.

**Expose**: `compile_in_context` runs the detector → `ContextWarnings.conflicts`. `owner.rs::execute_compile` emits `tracing::warn!(template, warning, "compile-context warning")` per message.

**Visualize**: deployed 2026-05-28 — every shadowed file appeared as one structured log line naming workspace + logical path + winner + shadowed paths. Diagnosis time: hours → seconds.

**Fix**: `LoadPathPlanner` consumes `LoadPathEntry { path, source: WorkspaceRepo | GemBroadcast { gem_name } | Other }`, derives install order (workspace > gem > other) + purge_feature_prefixes from overlap detection. `CompileContext::from_plan(&plan)` builds the manifest. owner.rs's hardcoded purge prefix becomes derivable.

The detector now functions as the regression test: any new gem broadcast site that introduces a logical conflict trips it on day 1.

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

### Anti-patterns to flag

| Anti-pattern | Why bad | Right move |
|---|---|---|
| Detector that mutates state | Not pure; can't run in plan context; can't run in tests | Pure scan only. State mutation belongs in apply step. |
| Hardcoded path/value in controller "to fix" the detected condition | Hardcoded values are anti-derivation; new producers force an edit | Planner with labeled-source inputs derives the value. |
| New ad-hoc warning type per bug class | Sinks (status, events, metrics) branch on shape | One `Conflict` shape; `detector` field labels the bug class. |
| Detector emits when EVERYTHING is fine (just to "log progress") | Drowns the signal | Detector emits ONLY when conflict found; empty Vec means clean. |
| Detector that lives in the controller layer | Couples the bug class to the controller; can't reuse from other entrypoints | Detector belongs in `pangea-ruby-eval` (or appropriate primitive crate). |
| Wiring fix into `status.anomalies[]` BEFORE the slice-4 CRD change | Type churn across the schema | Wait for slice 4 schema; until then, `tracing::warn!` is the audit surface. |

### Related knowledge notes

In the operator's private knowledge base (found by filename; they were agent
memories until 2026-10-01):

* `project_controller_detection_axis.md` — the durable note.
* `project_compile_isolation_shield.md` — the `CompileContext` primitive the detector hangs off.
* `project_ruby_pool_double_load_fix.md` — the bug class that drove the codification.
* `project_operator_observability_backlog.md` — the slice-4 status/events/metrics consumers.

### Triggers

Invoke when:
- User adds a new preprocessing or DSL or setup step in pangea-operator (or any similar controller).
- A cryptic downstream error surfaces in production and the root cause is structural (multiple producers, ordering, global state).
- Designing a new typed signal surface (metrics, events, status fields, GraphQL subs).
- Asked "how do we detect / surface / fix the X bug class?".

DO NOT invoke for:
- Single-shot bug fixes with no recurrence risk.
- Pure I/O bugs (network, disk).
- UI-only concerns.
- Bug classes that already have a working detector — improve it in place, don't re-codify the axis.

---

## Axis 2 — known unknowns: the recurrence axis

> Until 2026-10-01 the standalone skill `anomaly-recurrence` (version 0.1.1): Turns opaque recurring controller errors into stable signatures and recurrence counts. Use for an unclassified repeating error. Original title: *anomaly-recurrence — Known unknowns made structured*.

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

### Wire-out (slice-4+)

* `.status.anomalies[].signature` — surface the recurrence shape in CRD status.
* `pangea_anomaly_recurrences_total{namespace, name, signature}` counter.
* `Conflict { detector: "anomaly_recurrence", category: signature, evidence: { count, age_s } }` — joins the typed audit stream.

### Promotion path: known unknown → known known

When a recurring unknown signature shows a pattern, the upgrade is:

1. Write a typed `ConflictDetector` for the bug class (see Axis 1 — detection, above).
2. Replace the recurrence-based emission with the typed detector's emission.
3. The signature stays the same (compat); audit consumers gain typed evidence.

This is the FEEDBACK LOOP: opaque-recurring → named-recurring → typed-detected.

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

### Workflow when invoking

1. **Identify the failure site** — wherever the controller catches an Err and bails.
2. **Pick the recurrence key** — typical: `format!("{}/{}", namespace, name)` for per-template tracking.
3. **Wire signature + observe + emit** — 5-line block (see recipe above).
4. **(Slice-4) wire to status** — feed Recurrence into `Conflict.evidence`.
5. **Tune strip rules** — if the canonical form is still too granular for production errors, add a strip rule (file `strip_variable_parts` in anomaly_tracker.rs, add a unit test).

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

---

## Axis 3 — unknown unknowns: the escalation ladder

> Until 2026-10-01 the standalone skill `escalation-ladder` (version 0.1.1): Applies a time-graded recovery ladder, Retry to PauseAndAlert, to stuck reconcilers. Use when a failure persists for minutes. Original title: *escalation-ladder — Time-graded recovery*.

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

### Two classes covered

* **Known knowns** — typed `Conflict` from a detector named the bug class. Ladder picks action proportional to persistence.
* **Known unknowns / unknown unknowns** — controller saw an error it can't classify. Ladder still applies because the gate is TIME, not error shape. Rung 4 forces human attention before infinite cycle waste.

### Codified API

`pangea-operator/pangea-operator/src/controller/escalation.rs` (repo / crate / path):

```rust
pub enum EscalationAction { Retry, RefreshSource, ReloadGems, RecycleWorkers, PauseAndAlert }
impl EscalationAction { fn label(&self) -> &'static str; fn depth(&self) -> u8; }

pub struct EscalationRung { pub min_duration_unready: Duration, pub action: EscalationAction }
pub struct EscalationLadder { /* sorted Vec<EscalationRung> */ }
impl EscalationLadder {
    pub fn pangea_default() -> Self;
    pub fn from_rungs(rungs: Vec<EscalationRung>) -> Self;       // sort-on-construct
    pub fn pick(&self, duration_unready: Duration) -> EscalationAction;
    pub fn rungs(&self) -> &[EscalationRung];
}
```

7 unit tests pass. PURE — no async, no I/O, no global state.

### Wire-in recipe

Call from any controller arm that handles a failure. The minimum useful wire is **surface-only** (log + status), valuable immediately even before action handlers ship:

```rust
let now = chrono::Utc::now();
let duration_unready = template.status.as_ref()
    .and_then(|s| s.phase_entered_at.as_ref())
    .map(|t| (now - *t).to_std().unwrap_or(Duration::ZERO))
    .unwrap_or(Duration::ZERO);
let action = EscalationLadder::pangea_default().pick(duration_unready);

tracing::info!(
    template = %name,
    duration_unready_s = duration_unready.as_secs(),
    recommended_action = action.label(),
    depth = action.depth(),
    "escalation ladder recommendation"
);

// Bake into lastError / Event message:
let msg = format!(
    "{} (recovery ladder recommends '{}' at depth {}, {}s unready)",
    original_msg, action.label(), action.depth(), duration_unready.as_secs(),
);
```

Then a slice-5 follow-up wires the action handlers:

```rust
match action {
    Retry => { /* no extra */ }
    RefreshSource => invalidate_workspace_cache(&template).await?,
    ReloadGems => state.compiler_backend.reload_all_gems().await?,
    RecycleWorkers => state.ruby_pool.recycle_all().await?,
    PauseAndAlert => set_autosuspended_with_event(&template, &state).await?,
}
```

Each handler is its own primitive — add one variant at a time. The ladder doesn't block on handlers being present.

### Anti-patterns to flag

| Anti-pattern | Why bad | Right move |
|---|---|---|
| Hard-coding the actions in the controller arm | Doesn't compose; new arms duplicate the logic | Use the `EscalationLadder` primitive everywhere |
| Skipping `pause_and_alert` because "we should always retry" | Burns cycles forever on unrecoverable conditions | The deepest rung exists exactly for unknown-unknowns |
| Using cycle-count instead of duration | Doesn't honor "long enough to act" semantics | `Duration::from_secs(...)` is the gate; cycle-count is the orthogonal `settlingPolicy` signal |
| Making the action non-idempotent | Hazardous if rung fires twice across restarts | Every action MUST be idempotent (test it) |
| Surfacing the action only in logs (no status) | Operators can't see it via kubectl | Bake into `status.lastError` text + emit Event |

### Per-CR override (future / slice 4)

`spec.recoveryPolicy.rungs[]` lets a template override the default ladder. Production-aggressive workspaces shorten timings; production-tolerant lengthen. `from_rungs(...)` sorts on construction so CR ordering doesn't matter.

```yaml
spec:
  recoveryPolicy:
    rungs:
      - afterSeconds: 60
        action: RefreshSource
      - afterSeconds: 600
        action: PauseAndAlert
```

### Composes with

* **Axis 1 (detection)** — the detection axis NAMES the anomaly via `ConflictDetector`; this skill TAKES ACTION over time. Same `Conflict` shape, different axis.
* `pangea-operator/pangea-operator/src/controller/settling.rs` — provides stuck signals (cycle-count + fingerprint). Orthogonal to time-graded depth.
* `pangea-operator/pangea-operator/src/controller/error_policy.rs` — categorizes errors. Pre-step to the ladder.

### Workflow when invoking

1. **Smell-check**: does the failure recur, with no scalar fix? If yes, ladder applies.
2. **Map persistence to depth**: how long should X persist before each rung? Use the default unless the user names different timings.
3. **Pick the wire-in arm**: which `handle_<X>_failure` function adds the ladder call?
4. **Surface-first**: log + status + Event. Handlers later.
5. **Pure tests**: TempDir-free; just `Duration::from_secs(...)` inputs and `EscalationAction` assertions.

### Related knowledge notes

In the operator's private knowledge base (found by filename; they were agent
memories until 2026-10-01):

* `project_escalation_ladder.md` — durable knowledge.
* `project_controller_detection_axis.md` — the detect sibling axis.
* `project_operator_observability_backlog.md` — slice-4 status field consumer.

### Triggers

Invoke when:
- User describes a recurring failure the motor can't recover from.
- User asks "how should the controller respond when X persists for N minutes".
- Adding a new failure-handling arm to a controller.
- Designing recovery policy for a new bug class.
- A template is stuck at a non-Ready phase with high consecutive failure counts.

DO NOT invoke for:
- One-shot bug fixes.
- Bugs already handled by settlingPolicy + retryPolicy alone.
- Bugs where the structural fix is obvious + immediate (just fix it).
