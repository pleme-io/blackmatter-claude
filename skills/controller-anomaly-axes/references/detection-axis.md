# Axis 1 — detection: primitives, recipe, case study

Detail for the detection axis of `controller-anomaly-axes`; the smell check and workflow stay in `SKILL.md`.

> Until 2026-10-01 the standalone skill `controller-detection-axis` (version 0.1.1): Turns a controller bug class into a typed ConflictDetector plus planner. Use for cryptic recurring controller errors. Original title: *controller-detection-axis — The four-step bug-class loop*.

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
