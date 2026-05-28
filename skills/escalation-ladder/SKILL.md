---
name: escalation-ladder
description: Time-graded recovery escalation for the reconciliation motor — Retry → RefreshSource → ReloadGems → RecycleWorkers → PauseAndAlert as durations grow without reaching Ready. Use when the user describes a recurring failure the motor can't recover from, when asked how the controller should respond when X persists for N minutes, or when designing recovery policy for a new bug class. Fix-axis sibling of controller-detection-axis; codified in pangea-operator/src/controller/escalation.rs.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "0.1.0"
  domain_keywords:
    - "escalation"
    - "recovery"
    - "stuck"
    - "settling"
    - "anomaly"
    - "controller"
    - "reconciliation"
    - "recovery-policy"
    - "pause-and-alert"
    - "pangea-operator"
---

# escalation-ladder — Time-graded recovery

The reconciliation motor needs progressively deeper corrective actions when a template can't reach Ready. This skill names the pattern, the production-default ladder, and the wire-in shape so any new failure surface gets recovery semantics by default.

## The default ladder (pangea-operator)

| Rung | After | Action | Handles |
|---|---|---|---|
| 0 | 0s | `Retry` | normal reconcile path |
| 1 | 5 min | `RefreshSource` | "source moved, our clone is stale" |
| 2 | 15 min | `ReloadGems` | "in-process Ruby state is wedged; FS is fine" |
| 3 | 30 min | `RecycleWorkers` | "the CRuby VM is irrecoverable; kill pool" |
| 4 | 60 min | `PauseAndAlert` | "we tried everything; human required" |

Each action is **idempotent**. Each label is **stable** (locked by test). `depth()` orders for comparison + dashboards.

## When to invoke

| Situation | Apply? | Why |
|---|---|---|
| A new bug class with recurring failures | Yes | Surface the right rung from day 1; future handlers slot in. |
| A new template type / controller arm | Yes | Wire the ladder into its failure path so recovery is automatic. |
| "How should the controller respond to X persistent for N minutes?" | Yes | Map N to the right rung. |
| A one-shot bug fix | No | The ladder is overhead — fix it and move on. |
| Errors fixed by configuration retry alone | No | settlingPolicy + retryPolicy handle that; the ladder is for time-graded depth. |

## Two classes covered

* **Known knowns** — typed `Conflict` from a detector named the bug class. Ladder picks action proportional to persistence.
* **Known unknowns / unknown unknowns** — controller saw an error it can't classify. Ladder still applies because the gate is TIME, not error shape. Rung 4 forces human attention before infinite cycle waste.

## Codified API

`pangea-operator/src/controller/escalation.rs`:

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

## Wire-in recipe

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

## Anti-patterns to flag

| Anti-pattern | Why bad | Right move |
|---|---|---|
| Hard-coding the actions in the controller arm | Doesn't compose; new arms duplicate the logic | Use the `EscalationLadder` primitive everywhere |
| Skipping `pause_and_alert` because "we should always retry" | Burns cycles forever on unrecoverable conditions | The deepest rung exists exactly for unknown-unknowns |
| Using cycle-count instead of duration | Doesn't honor "long enough to act" semantics | `Duration::from_secs(...)` is the gate; cycle-count is the orthogonal `settlingPolicy` signal |
| Making the action non-idempotent | Hazardous if rung fires twice across restarts | Every action MUST be idempotent (test it) |
| Surfacing the action only in logs (no status) | Operators can't see it via kubectl | Bake into `status.lastError` text + emit Event |

## Per-CR override (future / slice 4)

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

## Composes with

* **controller-detection-axis** skill — the detection axis NAMES the anomaly via `ConflictDetector`; this skill TAKES ACTION over time. Same `Conflict` shape, different axis.
* `settling.rs` — provides stuck signals (cycle-count + fingerprint). Orthogonal to time-graded depth.
* `error_policy.rs` — categorizes errors. Pre-step to the ladder.

## Workflow when invoking

1. **Smell-check**: does the failure recur, with no scalar fix? If yes, ladder applies.
2. **Map persistence to depth**: how long should X persist before each rung? Use the default unless the user names different timings.
3. **Pick the wire-in arm**: which `handle_<X>_failure` function adds the ladder call?
4. **Surface-first**: log + status + Event. Handlers later.
5. **Pure tests**: TempDir-free; just `Duration::from_secs(...)` inputs and `EscalationAction` assertions.

## Related memories

* `memory/project_escalation_ladder.md` — durable knowledge.
* `memory/project_controller_detection_axis.md` — the detect sibling axis.
* `memory/project_operator_observability_backlog.md` — slice-4 status field consumer.

## Triggers

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
