---
name: cost-anomaly
description: Detect, triage, and root-cause cost anomalies — sudden spend spikes, slow drift, missing-spend cliffs. Use when an anomaly alert fires, when authoring a new detection rule, when investigating a billing surprise, or when designing the next monthly review's anomaly section. Powered by the `anomaly-forge` Rust binary.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "0.1.0"
  domain_keywords:
    - "anomaly"
    - "cost-spike"
    - "drift"
    - "anomaly-forge"
    - "finops"
    - "alert"
    - "regression"
---

# cost-anomaly — Cost-anomaly detection &amp; investigation

This skill wraps the `anomaly-forge` Rust binary with workflow guidance
for four canonical situations: investigating an alert, authoring a new
detection rule, doing a backfill / monthly anomaly review, and tuning
sensitivity.

The strategic philosophy lives in the FinOps Strategy doc on Confluence
(*FinOps — Strategy, Architecture &amp; Continuous Practice (2026+)*).
Strategic Play **P7 — Anomaly-driven optimization** is the directive:
alert on deltas, not absolutes. A service running $50K/month is fine if
it's been that for a year; it's a problem if it was $40K last month. Catch
the delta within hours, not when the bill closes.

The K8S_CLIENT_QPS bottleneck is the canonical reference: it shipped to
production and lived for months before anyone noticed, because nothing
was watching for behavioral / cost deltas continuously. This tool exists
so the next one of those gets caught in days.

## When to invoke

- An anomaly alert fired in Slack / ntfy and someone needs to triage it.
- A billing surprise hit the monthly review — "$X was unexpected,
  what happened?"
- A new dimension or workload class is going live and needs a tuned
  detection rule.
- Authoring the monthly anomaly section of the program review.
- Quarterly rule-bundle review — are existing rules tuned right? Are
  any silently never firing? Any over-firing?

## Tools used

- **`anomaly-forge`** — the binary.
  - `anomaly-forge detect &lt;events.jsonl&gt; --rules &lt;rules.yaml&gt;` — run
    all rules, emit anomalies, set exit code by severity.
  - `anomaly-forge rules list --rules &lt;rules.yaml&gt;` — list rule IDs +
    severities.
  - `anomaly-forge rules print --rules &lt;rules.yaml&gt; &lt;id&gt;` — describe
    one rule.
- **`attribution-forge`** (separate skill: `cost-attribution`) — produces
  the JSONL events this tool reads.
- **`tag-forge`** (separate skill: `tag-architecture`) — if anomalies
  cluster in `(missing)` buckets, the upstream is a tagging gap.

## Workflow

### A) Triaging an alert

When an anomaly fires:

1. **Read the message.** It includes the rule id, dimension value, the
   current cost, the baseline mean (with stddev for sigma rules), and
   the percent delta.
2. **Confirm the data plane is healthy first.**
   - `attribution-forge verify` on the events file. If tag coverage
     dropped overnight, the anomaly is in the data, not the workload.
   - If verify is clean, the anomaly is real.
3. **Find the day-over-day or hour-over-hour breakdown.**
   ```bash
   attribution-forge query events.jsonl --by &lt;dimension&gt;,service
   ```
   This shows which service inside the dimension drove the jump.
4. **Cross-reference change events** — deploys, capacity changes, traffic
   shifts. The anomaly's bucket timestamp is the search window.
5. **Choose a disposition:**
   - **Real and expected** (planned launch, expected traffic) →
     document; consider a temporary silence rule.
   - **Real and unexpected** → open an incident or follow-up ticket;
     the anomaly was useful.
   - **False positive** → the rule is too tight for this dimension's
     natural variance; tune (workflow D).
   - **Data quality** → fix upstream in `cost-attribution` or
     `tag-architecture`.

### B) Authoring a new detection rule

1. **Pick the dimension.** What axis are you watching? `cost_center`,
   `tenant`, `product`, `region`, or the literal `__total__` for whole-
   stream watch.
2. **Pick the bucket + baseline window.** General guidance:
   - Daily bucket + 28-day baseline = stable monthly business signal.
   - Hourly bucket + 7-day baseline = fast catch on traffic shifts;
     more noisy.
   - 1-bucket bucket = nothing baseline; always fires.
3. **Pick the threshold type:**
   - `percent_change` — best when you know roughly what variance is
     acceptable in business terms (e.g., "25% jump is worth a look").
   - `stddev` (sigma) — best when natural variance is hard to estimate
     by intuition; let the data set the threshold. 3σ is the usual
     starting point; 2σ is noisy; 4σ+ misses real outliers.
4. **Pick the severity:**
   - `info` — log only, no exit-code impact under default fail-on.
   - `warn` (default) — exit 1 under default fail-on; routes to team channel.
   - `critical` — exit 1 even under `--fail-on critical`; routes to on-call.
5. **Backfill against existing data** to see what the rule would have
   fired on:
   ```bash
   anomaly-forge detect historical-events.jsonl --rules just-new-rule.yaml
   ```
   If it would have over-fired, loosen the threshold. If it would have
   missed real incidents, tighten.
6. **Land the rule** in the private rules overlay (not the public
   `pleme-io/anomaly-forge/configs/default.yaml`).

### C) Monthly anomaly review

Part of the monthly cadence review:

1. `anomaly-forge detect` over the past month's events.
2. `rules list` to confirm the active bundle.
3. Cluster anomalies by rule id and by dimension value. The
   distribution tells you:
   - Top 1-3 firing rules → are these signaling real change or noise?
   - Top 1-3 firing dimension values → are these the same teams /
     services every month? If so, that's a chronic-condition, not an
     anomaly — consider moving them to a different tier.
4. Write the review section: "N anomalies this month, M new, K
   chronic."

### D) Tuning sensitivity

Symptoms a rule is mis-tuned:

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Same rule fires daily on same dim values | Natural variance higher than threshold | Loosen percent threshold OR switch to sigma |
| Rule never fires in months of data | Threshold too loose | Tighten |
| Fires on weekends, never weekdays | Day-of-week not modeled | Move to longer baseline window OR add weekly periodicity to rule (v0.2) |
| Fires immediately after a new dim value appears | Zero-fill baseline + sudden value = infinite delta | Acknowledge as a "new dimension" pattern; consider a silence in the first N days (v0.2) |
| Fires on Mondays only | Cost batch posting; not a real anomaly | Move bucket to weekly or align baseline |

## Common patterns

- **Detection is cheap; routing is expensive.** v0.1 emits to stdout —
  routing to Slack / ntfy / PagerDuty is v0.2 territory. Until then,
  read the JSON output, fan out manually.
- **Cost-weighted thinking compounds.** The cost-weighted view from
  `attribution-forge verify` plus per-dimension anomaly detection
  here = a Pareto-front of "where would investment of one hour pay
  back fastest."
- **Sparse series get zero-filled.** A dimension value appearing for
  the first time produces an "infinite percent change" — that's the
  literal `f64::INFINITY` in the output, and the rule fires. Treat
  this as a "new entity" signal, not a bug.
- **Insufficient baseline → no anomaly.** The first N buckets of a
  new dimension series can't fire any rule. This is intentional;
  premature firing is worse than late firing.

## Anti-patterns

- **Setting thresholds by guess.** Tune against historical data with
  backfill; don't ship a rule that hasn't run against real history.
- **One rule covering everything.** Multiple narrow rules with
  different severities beat one broad rule. The `tenant_tail_outlier`
  catches per-tenant statistical surprises while `total_daily_critical`
  catches org-wide page-able spikes; both are needed.
- **Treating every anomaly as a problem.** Many anomalies are real
  but expected (planned launches, traffic days, customer onboarding).
  The discipline is the disposition, not the absence of anomalies.
- **Letting anomalies pile up without disposition.** An undispositioned
  alert is a noise generator. Either close it or note why it's
  expected.

## Related skills

- `cost-attribution` — the upstream data plane. If attribution coverage
  drops, anomalies start firing on data drift, not workload drift.
- `tag-architecture` — `(missing)` bucket anomalies usually trace back
  to a tagging gap.
- `lifecycle-policy` — recurring anomalies on snapshot / EIP /
  log-bucket costs often mean a missing lifecycle policy.
- `cadence-review` (TBD) — the monthly review consumes anomaly data
  via `cadence-forge` once that ships.
