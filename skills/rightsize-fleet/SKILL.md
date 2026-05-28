---
name: rightsize-fleet
description: Produce, review, and act on rightsizing recommendations across a fleet. Use when running the periodic rightsizing pass, when investigating a specific resource's sizing, when tuning the policy (headroom vs target utilization tradeoffs), or when wiring rightsizing as a continuous CI gate. Powered by the `rightsize-forge` Rust binary.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "0.1.0"
  domain_keywords:
    - "rightsize"
    - "rightsizing"
    - "downsize"
    - "sizing"
    - "utilization"
    - "rightsize-forge"
    - "finops"
---

# rightsize-fleet — Continuous, multi-signal rightsizing

This skill wraps the `rightsize-forge` Rust binary with workflow guidance
for four canonical situations: running a periodic rightsizing pass,
investigating a specific resource, tuning the policy, and wiring
rightsizing into CI.

The strategic philosophy lives in the FinOps Strategy doc on Confluence
(*FinOps — Strategy, Architecture &amp; Continuous Practice (2026+)*).
**Strategic Play P3** is the directive: continuous rightsizing, not one-off
projects. Workloads drift, demand shifts, instance classes evolve. The
discipline isn't "right-size the fleet once" — it's "the fleet's
rightsizing drifts ≤5% off optimal at any moment."

## When to invoke

- Periodic (weekly / monthly) rightsizing pass — what does the fleet look
  like, and where are the safe downsize candidates?
- A specific resource is suspected over-provisioned — confirm and produce
  the proposed change.
- Tuning the policy — burst headroom vs target utilization vs savings
  threshold. Trade-offs are not obvious; understand them deliberately.
- Wiring rightsize-forge into CI so every change against the IaC repos
  is checked against the latest utilization profile.

## Tools used

- **`rightsize-forge`** — the binary.
  - `rightsize-forge analyze --observations &lt;jsonl&gt; --inventory &lt;yaml&gt;
    --shapes &lt;yaml&gt; --policy &lt;yaml&gt;` — produce recommendations.
  - `rightsize-forge shapes list --shapes &lt;yaml&gt;` — list catalog.
  - `rightsize-forge shapes print --shapes &lt;yaml&gt; &lt;id&gt;` — describe one.
  - `rightsize-forge schema` — print canonical Observation schema.
- **Phase C profiler output** (in flight) — utilization source.
- **`attribution-forge`** (separate skill: `cost-attribution`) — when
  estimating real savings, the attribution data can credit savings back
  to the resource's cost_center.

## Workflow

### A) Running a periodic pass

1. **Refresh the observation stream.** Whether it's a Prometheus dump, an
   OpenCost export, or Phase C profiler output, make sure the window
   covers at least the policy's `min_observations` worth of samples.
2. **Refresh the inventory.** A drift in current_shape (someone resized
   without updating the inventory) will produce wrong baseline costs.
3. **Run analyze:**
   ```bash
   rightsize-forge analyze \
     --observations latest-utilization.jsonl \
     --inventory    inventory.yaml \
     --shapes       catalog.yaml \
     --policy       sizing-policy.yaml
   ```
4. **Read the output:**
   - Top recommendations by `monthly_savings_usd`. Sanity-check the
     biggest ones manually before opening PRs.
   - `skipped` list with reasons. Confirm preservation rules are firing
     where expected; investigate "insufficient observations" entries
     (could mean a resource isn't being scraped).
5. **Open PRs against IaC** for the recommendations you accept. Apply
   mode (auto-PR) is a v0.2 feature; v0.1 is plan-only.
6. **Track the trend** — total_monthly_savings_usd over weeks. If it's
   trending up sharply, the fleet is drifting; if trending to zero,
   you're at the rightsizing-flat-line and can lengthen the cadence.

### B) Investigating a specific resource

When someone says "is svc-foo over-provisioned?":

1. Confirm svc-foo has enough observations: `jq 'select(.resource_id ==
   "svc-foo")' observations.jsonl | wc -l`. Want at least the policy's
   `min_observations`.
2. Run analyze and grep for svc-foo in JSON output:
   ```bash
   rightsize-forge analyze ... --format json --no-fail \
     | jq '.recommendations + .skipped | .[] | select(.resource_id == "svc-foo")'
   ```
3. If recommended: open the PR. If skipped: read the reason. Common
   shapes:
   - **"insufficient observations"** — needs more profiling time, or
     the scrape isn't capturing it.
   - **"master_region"** — preserved; if you disagree, deliberate
     policy change, not a one-off override.
   - **"criticality TX preserved"** — same shape.
   - **"already on smallest fitting shape"** — the resource IS
     correctly sized; that's the answer.
   - **"no shape in catalog satisfies headroom-adjusted demand"** —
     the resource is on the smallest available shape; if it's still
     too small, that's an upsize signal (not in v0.1 yet).

### C) Tuning the policy

Trade-offs to understand:

| Knob | Effect of increasing | Effect of decreasing |
| --- | --- | --- |
| `peak_percentile` (default 99) | More conservative sizing; fewer recommendations; preserves true peak | More aggressive; recommends downsizes that don't survive p99 burst |
| `burst_headroom_pct` (default 20) | More conservative; preserves room for unobserved bursts | More aggressive; recommends shapes that have no spare capacity |
| `target_cpu_pct` / `target_mem_pct` (default 70) | More aggressive — proposes shapes that will run hotter | More conservative — proposes shapes with more headroom |
| `min_observations` (default 100) | Fewer recommendations (some skipped for thin data); more confident those that fire | More recommendations from less data — risk of bad calls |
| `min_savings_usd_per_month` (default 0) | Fewer recommendations; focus on big wins; ignores long-tail $1/mo savings | Reports everything; useful for reviews, noisy for PRs |

The combinations matter. A common safe tune: **p99 + 20% headroom + 70%
target** preserves real burst capacity. If recommendations land safely
for a quarter, you can tighten one of these dials (typically headroom)
and see if the next pass still produces credible recommendations.

**The discipline:** change one dial at a time, run analyze, review the
new recommendations qualitatively before pushing the dial further.

### D) Wiring rightsize-forge into CI

```yaml
# .github/workflows/rightsize.yml (sketch)
- name: rightsize check
  run: |
    rightsize-forge analyze \
      --observations s3://obs/latest.jsonl \
      --inventory    infra/inventory.yaml \
      --shapes       infra/catalog.yaml \
      --policy       infra/sizing-policy.yaml \
      --format json \
      --no-fail > rightsize-report.json
    cat rightsize-report.json | jq '.total_monthly_savings_usd'
```

The `--no-fail` flag keeps CI green; the JSON artifact is the surface for
a dashboard or review. Without `--no-fail` the job exits 1 whenever any
recommendation exists — useful for "block PRs that worsen the fleet's
sizing drift."

## Common patterns

- **The recommendation embeds its reason.** The output's `reason` field
  shows the peak utilization, the headroom multiplier, and the projected
  utilization on the new shape. A reviewer should be able to validate
  without re-running the analyzer.
- **Skipped is informative, not a failure.** A long skipped list with
  reasons tells you about your fleet — preservation rules firing, data
  thinness, master regions.
- **Multi-signal beats single-signal.** A workload at 30% CPU / 85% memory
  is at memory's edge — don't downsize.
- **Apply mode is human-gated.** v0.1 is plan-only by design. When apply
  mode lands in v0.2, it opens PRs (not direct API calls). Engineering
  reviews the PR; the analyzer just authored the diff.

## Anti-patterns

- **Rightsizing once a year.** Workloads drift continuously; rightsizing
  must too. Quarterly minimum; weekly is normal for mature fleets.
- **CPU-only sizing.** Decade-old failure mode. Memory pressure is the
  thing that crashes nodes, not 50% CPU.
- **Ignoring the burst headroom.** Tight rightsizing that doesn't survive
  a real spike erodes trust in the program faster than anything.
- **Auto-applying recommendations.** Always human-reviewed. The cost of
  a bad recommendation is real, the cost of a missed one is small.
- **Treating "no recommendations" as failure.** A fleet that produces no
  recommendations is one of two things: optimally sized (success) or
  poorly observed (data problem). Investigate which, don't tune dials
  until you know.

## Related skills

- `cost-attribution` — credit projected savings back to the cost_center.
- `unit-economics` — recommendations change unit economics; refresh after
  applying.
- `lifecycle-policy` — sometimes the right move is to delete the
  resource entirely, not resize it. Check lifecycle policies before
  rightsizing.
- `cadence-review` (TBD) — rightsizing trend is a standing line in the
  monthly review.
