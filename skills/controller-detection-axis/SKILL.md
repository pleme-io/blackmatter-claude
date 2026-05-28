---
name: controller-detection-axis
description: Treat any controller bug class — global-state accumulation, ordering-dependent semantics, multiple producers collapsing into one shared collector — as an instance of the Detect → Expose → Visualize → Fix axis. Use when adding preprocessing / DSL / setup steps to a controller, when diagnosing a cryptic downstream error in production, or when designing a new typed signal surface. Codified end-to-end in pangea-ruby-eval (ConflictDetector trait + LoadPathConflictDetector + LoadPathPlanner + ContextWarnings dual surface).
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "0.1.0"
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
---

# controller-detection-axis — The four-step bug-class loop

Every preprocessing / DSL / setup step in a controller is a candidate for a **bug class**: an entire family of cryptic downstream errors that share a structural cause. This skill names the pattern that turns each bug class into a controlled four-step loop and gives you the apply-or-skip checklist + concrete plumbing recipes.

## The pattern in one breath

```
1. Detect    — pure ConflictDetector scans inputs → emits typed Conflicts.
2. Expose    — same Conflict shape flows: tracing → .status.anomalies[]
                → k8s Events → Prometheus → GraphQL subscriptions.
3. Visualize — humans + dashboards + on-call query the structured stream.
4. Fix       — planner-layer change at the right layer; detector becomes
                the regression test for the bug class going forward.
```

Same typed `Conflict` flows through all four steps so consumers don't branch on which step emitted.

## When to invoke (the smell check)

Apply the axis when the controller adds a step with ANY of these smells:

| Smell | Example |
|---|---|
| Global-state accumulation | CRuby's `$LOAD_PATH`, `$LOADED_FEATURES`, module constants accumulate across compiles. |
| String-based logical IDs → physical addresses | Ruby require names → file paths; Terraform addresses → state slots; env var names → process env. |
| Multiple producers → one collector | Multiple gems prepending to `$LOAD_PATH`; multiple modules synthesizing into one TF config. |
| Ordering-dependent semantics not reified anywhere | "Load order matters but isn't a type"; "this env var must be set before that one". |
| Cryptic downstream error | The prior occurrence is THE signal — every "huh, weird error" is a candidate. |

If NONE apply, the preprocessing is scalar; the axis is overhead, skip it.

## The fundamental shape (Rust)

The codified primitives live in `~/code/github/pleme-io/pangea-operator/pangea-ruby-eval/src/evaluator.rs`:

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

## Recipe — adding a new detector

### Step 1: Define the detector struct

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

### Step 2: Register in default detector set

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

### Step 3: Pure unit tests

```rust
#[test]
fn detects_<bug_class>_when_<condition>() {
    // TempDir + filesystem layout + assert.
    // No Ruby needed — detector is pure.
}
```

### Step 4: (Slice 4) wire the structured surface

When slice 4 lands `.status.anomalies[]`:

* CRD `InfrastructureTemplateStatus.anomalies: Option<Vec<Anomaly>>` where `Anomaly` is the on-wire shape of `Conflict`.
* `controller/template/status.rs` carries `ContextWarnings.conflicts` → `status.anomalies`.
* k8s `Event` with `reason = c.detector`, `message = c.message`, fingerprint by `(template, c.detector, c.category)` for deduplication.
* Prometheus `pangea_compile_conflicts_total{detector="<bug_class>"}`.

### Step 5: The fix step — planner at the right layer

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

## The case study (load-path double load — codified 2026-05-28)

**Symptom**: `pleme-io-opensource` stuck at `Compiling` with `consecutiveCompileFailures: 104`. Error: `Attribute :cluster_name has already been defined`.

**Detect**: `LoadPathConflictDetector` walks every `.rb` file under each `$LOAD_PATH` entry × `["pangea/"]`; groups by logical require name; flags any name with >1 absolute path. O(L × F), ~µs warm cache.

**Expose**: `compile_in_context` runs the detector → `ContextWarnings.conflicts`. `owner.rs::execute_compile` emits `tracing::warn!(template, warning, "compile-context warning")` per message.

**Visualize**: deployed 2026-05-28 — every shadowed file appeared as one structured log line naming workspace + logical path + winner + shadowed paths. Diagnosis time: hours → seconds.

**Fix**: `LoadPathPlanner` consumes `LoadPathEntry { path, source: WorkspaceRepo | GemBroadcast { gem_name } | Other }`, derives install order (workspace > gem > other) + purge_feature_prefixes from overlap detection. `CompileContext::from_plan(&plan)` builds the manifest. owner.rs's hardcoded purge prefix becomes derivable.

The detector now functions as the regression test: any new gem broadcast site that introduces a logical conflict trips it on day 1.

## Workflow when invoking this skill

When the user describes a new preprocessing / DSL / setup step OR a cryptic downstream error in a controller:

1. **Smell-check**: does the situation hit any row of the smell table above? If not, advise the axis is overhead and propose the scalar fix instead.

2. **Name the bug class**: pick a stable `<bug_class>` label. This appears in tracing prefixes, metric labels, event reasons. Pick once, never change.

3. **Sketch the detector**: what's the pure-function scan? What are the inputs (config, existing state, candidate inputs)? What's the per-finding evidence shape (which fields will status consumers query)?

4. **Sketch the planner (if applicable)**: is there a planner-layer fix that pulls the decision UP into a pure function? If yes, the labeled-source pattern (`<Surface>Source` enum + `<Surface>Entry` struct + `plan_<surface>` fn + `CompileContext::from_plan`) is the recipe. If no, document why the detector is informational only.

5. **Open files in order**:
   - `pangea-ruby-eval/src/evaluator.rs` — detector + planner go here for compile-isolation bug classes.
   - `pangea-operator/src/ruby/owner.rs` — for `tracing::warn!` wiring.
   - (Slice 4) `pangea-operator/src/controller/template/status.rs` — for `.status.anomalies[]`.

6. **Tests first**: pure unit tests for the detector + planner. TempDir + filesystem layout + assert. No Ruby needed for pure-function tests.

7. **Commit boundary**: detector + tests is one commit. Planner is one commit. Wire-up in owner.rs is one commit. Each lands independently.

## Anti-patterns to flag

| Anti-pattern | Why bad | Right move |
|---|---|---|
| Detector that mutates state | Not pure; can't run in plan context; can't run in tests | Pure scan only. State mutation belongs in apply step. |
| Hardcoded path/value in controller "to fix" the detected condition | Hardcoded values are anti-derivation; new producers force an edit | Planner with labeled-source inputs derives the value. |
| New ad-hoc warning type per bug class | Sinks (status, events, metrics) branch on shape | One `Conflict` shape; `detector` field labels the bug class. |
| Detector emits when EVERYTHING is fine (just to "log progress") | Drowns the signal | Detector emits ONLY when conflict found; empty Vec means clean. |
| Detector that lives in the controller layer | Couples the bug class to the controller; can't reuse from other entrypoints | Detector belongs in `pangea-ruby-eval` (or appropriate primitive crate). |
| Wiring fix into `status.anomalies[]` BEFORE the slice-4 CRD change | Type churn across the schema | Wait for slice 4 schema; until then, `tracing::warn!` is the audit surface. |

## Related memories

* `~/.claude/projects/-Users-luis-d-code-github-akeylesslabs/memory/project_controller_detection_axis.md` — the durable memory.
* `~/.claude/projects/-Users-luis-d-code-github-akeylesslabs/memory/project_compile_isolation_shield.md` — the `CompileContext` primitive the detector hangs off.
* `~/.claude/projects/-Users-luis-d-code-github-akeylesslabs/memory/project_ruby_pool_double_load_fix.md` — the bug class that drove the codification.
* `~/.claude/projects/-Users-luis-d-code-github-akeylesslabs/memory/project_operator_observability_backlog.md` — the slice-4 status/events/metrics consumers.

## Triggers

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
